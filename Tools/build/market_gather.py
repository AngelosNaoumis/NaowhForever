"""Build The Market's skinning and fishing data: the creatures you can skin, what each gives and where
it lives, what each zone's water catches, and the fishing pools.

Three sources, each read once into its own section of Tools/data/market_gather.json:
  - "cmangos", the CMaNGOS classic database (github.com/cmangos/classic-db, GPL-3.0), downloaded as
    scout.py does, or --dump FILE: each skinnable creature's levels and SkinningLootId, its
    skinning_loot_template, each AreaTable zone's fishing_loot_template with the reference tables it
    rolls, and the fishing pools (gameobject_template type 25 with a loot table, not only in instances);
  - "export", the permitted Forever entity export (--export FILE): each of those creatures' English
    name, levels and spawns, already in Forever map percentages, by AreaTable zone;
  - "eglink", EG Link's output (github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0), read from GitHub
    or --eglink DIR (a folder per build): what players skinned and fished on Forever's live builds
    (EG_BUILDS), and the creatures Forever added. Its windows with the Bountiful Harvest or Luremaster
    talent on are left out: those talents change what drops.
Pass a source's option again, or delete its section, to read it again.

A loot table is flattened to each item's chance per loot window: a grouped item drops at its own
chance, or the group's chance left over shared by its items with none; an item outside a group, or a
reference table, rolls on its own. Quest items (a negative chance) and rows behind a condition
(Winter Squid and Summer Bass, by season) are left out.

A creature is kept when CMaNGOS can skin it and Forever has it (the export or EG Link knows it), or
when EG Link saw it skinned; then its loot is what players got (lootID is its own ID). Its levels are
the export's widened by the levels EG Link saw, CMaNGOS's only when neither has any. Its spawns are the export's, EG Link's kill spots for a
creature the export lacks, grouped into camps: the spot with the most others within CAMP map percent,
and those others, make one camp at their centre, until none are left. Positions are tenths of a map
percent, as Glimmer's spots are.

A zone's catches are CMaNGOS's zone table (AreaTable zone to uiMapID by quest_chains.ZONE_MAP; a
subzone's own table is left out) and EG Link's fishing on that map, the two blended with the database
counting as DATABASE_CASTS casts. EG Link's catches include what its players fished from pools.

Writes NaowhForever_Market/Data/Skinning.lua (the camps packed as glimmer_nodes.pack does, decoded by
the client with C_EncodingUtil) and NaowhForever_Market/Data/Fishing.lua.

Usage: python Tools/build/market_gather.py [--dump FILE] [--export FILE] [--eglink DIR | --fetch-eglink]
"""
import argparse
import collections
import json
import math
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import scout  # noqa: E402
import wago  # noqa: E402
from glimmer_nodes import TENTHS, pack  # noqa: E402
from journal import ROOT, header, lua_string, write  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

SKINNING_OUT = ROOT / "NaowhForever_Market" / "Data" / "Skinning.lua"
FISHING_OUT = ROOT / "NaowhForever_Market" / "Data" / "Fishing.lua"
CACHE = paths.DATA / "market_gather.json"
EG_URL = "https://raw.githubusercontent.com/JIVESCORP/eg-link-output-wowf/main/data/wowf/{build}/{file}"
EG_BUILDS = ("1.60.1.70790", "1.60.1.70840", "1.60.1.70862")
SKINNING_SPELLS = {"spell:8613", "spell:8617", "spell:8618", "spell:10768"}
TALENT_KEYS = ("bountifulHarvest:", "luremaster:")
FISHING_HOLE = "25"
OPEN_WORLD = {"0", "1"}
CAMP = 3.0
# The export has some Forever beasts (Zephras Isle) at every place it saw them, thousands a creature,
# not where they spawn; 9 in 10 real camps hold 8 or fewer.
CAMP_MOST = 8
DATABASE_CASTS = 100
PERCENT = 100
DECIMALS = 2


def load():
    return json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}


def save(cache):
    CACHE.write_text(json.dumps(cache, separators=(",", ":"), sort_keys=True) + "\n", encoding="utf-8")


def flatten(rows, refs):
    """{ item: [chance, min, max] } for one loot window of a table's rows (dicts of string fields)."""
    out = {}

    def add(item, chance, low, high):
        have = out.get(item)
        out[item] = [have[0] + chance, min(have[1], low), max(have[2], high)] if have else [chance, low, high]

    groups = collections.defaultdict(list)
    for row in rows:
        if int(row["condition_id"]) or float(row["ChanceOrQuestChance"]) < 0:
            continue
        ref = int(row["mincountOrRef"])
        if ref < 0:
            share = float(row["ChanceOrQuestChance"]) / PERCENT * int(row["maxcount"])
            for item, (chance, low, high) in flatten(refs.get(str(-ref), []), refs).items():
                add(item, chance * share, low, high)
        elif row["groupid"] == "0":
            add(int(row["item"]), float(row["ChanceOrQuestChance"]), ref, int(row["maxcount"]))
        else:
            groups[row["groupid"]].append(row)
    for members in groups.values():
        equal = [r for r in members if float(r["ChanceOrQuestChance"]) == 0]
        left = max(0.0, PERCENT - sum(float(r["ChanceOrQuestChance"]) for r in members))
        for r in members:
            chance = float(r["ChanceOrQuestChance"]) or left / len(equal)
            add(int(r["item"]), chance, int(r["mincountOrRef"]), int(r["maxcount"]))
    return out


def read_cmangos(sql):
    def by_entry(table):
        found = collections.defaultdict(list)
        for row in scout.rows(sql, table):
            found[row["entry"]].append(row)
        return found

    refs = by_entry("reference_loot_template")
    skinnable = {row["Entry"]: [int(row["MinLevel"]), int(row["MaxLevel"]), int(row["SkinningLootId"])]
                 for row in scout.rows(sql, "creature_template") if row["SkinningLootId"] != "0"}
    tables = by_entry("skinning_loot_template")
    used = {str(c[2]) for c in skinnable.values()}
    skin_loot = {loot: sorted([item, *v] for item, v in flatten(tables[loot], refs).items())
                 for loot in sorted(used, key=int) if loot in tables}
    fishing = {area: sorted([item, v[0]] for item, v in flatten(rows, refs).items())
               for area, rows in by_entry("fishing_loot_template").items()}
    object_loot = by_entry("gameobject_loot_template")
    holes = {row["entry"] for row in scout.rows(sql, "gameobject_template")
             if row["type"] == FISHING_HOLE and row["data1"] in object_loot}
    maps = collections.defaultdict(set)
    for row in scout.rows(sql, "gameobject"):
        if row["id"] in holes:
            maps[row["id"]].add(row["map"])
    pools = sorted(int(p) for p in holes if not maps[p] or maps[p] & OPEN_WORLD)
    return {"skinnable": skinnable, "skin_loot": skin_loot, "fishing": fishing, "pools": pools}


def sequence(value):
    """A list, or the export's { "1": v, "2": v } form of one."""
    if isinstance(value, dict):
        return [value[k] for k in sorted(value, key=int)]
    return value or []


def read_export(document, wanted):
    """The export's name and build, the creatures asked for, and { id: { name, levels, spawns: { uiMapID:
    [[x, y], ...] } } } for those it has."""
    if document.get("coordinate_space") != "forever":
        raise ValueError("the export must be in Forever map coordinates")
    npcs = document["entities"]["npcs"]
    found = {}
    for npc in sorted(wanted, key=int):
        record = npcs.get(npc)
        if record is None:
            continue
        spawns = collections.defaultdict(list)
        for area, positions in (record.get("spawns") or {}).items():
            ui_map = ZONE_MAP.get(int(area))
            if not ui_map:
                continue
            for position in map(sequence, sequence(positions)):
                if len(position) < 2 or (len(position) > 2 and position[2]):
                    continue
                spot = position[:2]
                if all(isinstance(v, (int, float)) and 0 <= v <= PERCENT for v in spot) and spot not in spawns[ui_map]:
                    spawns[ui_map].append(spot)
        levels = [record.get("minLevel"), record.get("maxLevel")]
        found[npc] = {"name": record["name"], "levels": levels if None not in levels else None,
                      "spawns": {str(m): sorted(s) for m, s in sorted(spawns.items())}}
    return {"source": document["source"], "build": document["build"], "asked": sorted(wanted, key=int),
            "npcs": found}


def fetch_eglink(build, name):
    req = urllib.request.Request(EG_URL.format(build=build, file=name), headers={"User-Agent": wago.AGENT})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def read_eglink(files):
    """What EG Link's players skinned and fished, summed over the builds, and the creatures they skinned.
    files(build, name) is a file's parsed JSON."""
    skins = collections.defaultdict(lambda: {"windows": 0, "items": collections.defaultdict(lambda: [0, 0])})
    fishing = collections.defaultdict(lambda: {"windows": 0, "items": collections.Counter()})
    seen = collections.defaultdict(lambda: {"levels": set(), "positions": collections.defaultdict(list)})
    names = {}
    for build in EG_BUILDS:
        for key, source in files(build, "loot.json")["sources"].items():
            parts = key.split("|")
            if any(p.startswith(TALENT_KEYS) for p in parts):
                continue
            if parts[0].startswith("fishing:"):
                entry = fishing[parts[0][len("fishing:"):]]
                entry["windows"] += source.get("windows", 0)
                for item, got in source.get("items", {}).items():
                    entry["items"][item] += got.get("drops", 0)
            elif parts[0].startswith("npc:") and len(parts) > 1 and parts[1] in SKINNING_SPELLS:
                entry = skins[parts[0][len("npc:"):]]
                entry["windows"] += source.get("windows", 0)
                for item, got in source.get("items", {}).items():
                    entry["items"][item][0] += got.get("drops", 0)
                    entry["items"][item][1] += got.get("quantity", 0)
        for npc, record in files(build, "creatures.json")["creatures"].items():
            if npc in skins:
                seen[npc]["levels"] |= {int(level) for level in record.get("levels", {}) if int(level) > 0}
                for p in record.get("positions", []):
                    if p.get("uiMap"):
                        spot = [round(p["mapX"] * PERCENT, 2), round(p["mapY"] * PERCENT, 2)]
                        if spot not in seen[npc]["positions"][str(p["uiMap"])]:
                            seen[npc]["positions"][str(p["uiMap"])].append(spot)
        for npc, record in files(build, "creature_details.enUS.json")["creatures"].items():
            if npc in skins and record.get("name"):
                names[npc] = record["name"]
    creatures = {npc: {"name": names.get(npc), "levels": sorted(seen[npc]["levels"]),
                       "positions": {m: sorted(s) for m, s in sorted(seen[npc]["positions"].items())}}
                 for npc in skins}
    return {"builds": list(EG_BUILDS),
            "skins": {npc: {"windows": s["windows"], "items": dict(s["items"])} for npc, s in skins.items()},
            "fishing": {m: {"windows": f["windows"], "items": dict(f["items"])} for m, f in fishing.items()},
            "creatures": creatures}


def camps(points, radius=CAMP):
    """[(x, y, count)] for points in map percent: the point with the most others within radius, with
    them, is a camp at their centre; then the next, from what is left. Biggest first."""
    points = sorted({tuple(p) for p in points})
    near = [{j for j, q in enumerate(points) if math.dist(p, q) <= radius} for p in points]
    left = set(range(len(points)))
    found = []
    while left:
        seed = max(sorted(left), key=lambda i: len(near[i] & left))
        group = near[seed] & left
        left -= group
        found.append((sum(points[i][0] for i in group) / len(group),
                      sum(points[i][1] for i in group) / len(group), min(len(group), CAMP_MOST)))
    return sorted(found, key=lambda c: (-c[2], c[0], c[1]))


def levels(export, seen, database):
    """A creature's Forever levels: the export's widened by those EG Link saw, else the database's."""
    found = list(export or []) + list(seen or [])
    return [min(found), max(found)] if found else database[:2]


def skinning(cache):
    """({ id: [min, max, lootID, name] }, { lootID: [[item, chance, min, max], ...] }, { uiMapID: flat camps })."""
    db, export, eg = cache["cmangos"], cache["export"]["npcs"], cache["eglink"]
    creatures, loot, spawns = {}, {}, {}
    for npc, (low, high, loot_id) in db["skinnable"].items():
        record, seen = export.get(npc), eg["creatures"].get(npc)
        if not record and not seen:
            continue
        name = record["name"] if record else seen["name"]
        creatures[int(npc)] = [*levels(record and record["levels"], seen and seen["levels"], [low, high]),
                               loot_id, name]
        if str(loot_id) in db["skin_loot"]:
            loot[loot_id] = db["skin_loot"][str(loot_id)]
    for npc, source in eg["skins"].items():
        if int(npc) in creatures:
            continue
        if int(npc) in loot:
            raise ValueError(f"creature {npc}'s own loot ID is a CMaNGOS skinning table")
        record, seen = export.get(npc), eg["creatures"][npc]
        name = record["name"] if record else seen["name"]
        found = levels(record and record["levels"], seen["levels"], [])
        if not name or not found or not source["windows"]:
            print(f"  skipped skinned creature {npc}: no name, levels or windows", file=sys.stderr)
            continue
        creatures[int(npc)] = [*found, int(npc), name]
        loot[int(npc)] = []
        for item, (drops, quantity) in sorted(source["items"].items(), key=lambda e: int(e[0])):
            if drops:
                count = max(1, round(quantity / drops))
                loot[int(npc)].append([int(item), PERCENT * drops / source["windows"], count, count])
    for npc in sorted(creatures):
        record, seen = export.get(str(npc)), eg["creatures"].get(str(npc))
        where = (record and record["spawns"]) or (seen and seen["positions"]) or {}
        for ui_map, points in where.items():
            row = spawns.setdefault(int(ui_map), [])
            for x, y, count in camps(points):
                row += [npc, round(x * TENTHS), round(y * TENTHS), count]
    return creatures, loot, spawns


def fishing(cache):
    """({ uiMapID: [[item, chance], ...] }, { uiMapID: "cmangos" | "eglink" | "both" })."""
    db, eg = cache["cmangos"]["fishing"], cache["eglink"]["fishing"]
    catches, sources = {}, {}
    for area, ui_map in ZONE_MAP.items():
        table = {item: chance for item, chance in db.get(str(area), [])}
        seen = eg.get(str(ui_map))
        if not table and not seen:
            continue
        sources[ui_map] = "both" if table and seen else "cmangos" if table else "eglink"
        if seen:
            casts = seen["windows"]
            weight = DATABASE_CASTS if table else 0
            share = {int(i): PERCENT * n / casts for i, n in seen["items"].items()}
            table = {i: (table.get(i, 0) * weight + share.get(i, 0) * casts) / (weight + casts)
                     for i in set(table) | set(share)}
        catches[ui_map] = sorted(([i, c] for i, c in table.items() if round(c, DECIMALS) > 0),
                                 key=lambda e: (-e[1], e[0]))
    for ui_map in eg:
        if int(ui_map) not in sources:
            print(f"  EG Link fished on map {ui_map}, which ZONE_MAP has no zone for", file=sys.stderr)
    return catches, sources


def number(value):
    return f"{round(value, DECIMALS):g}"


def write_skinning(creatures, loot, spawns):
    lines = header(SKINNING_OUT.name, "the creatures you can skin, what each gives and their camps by world "
                   "map, packed, generated by Tools/build/market_gather.py")
    lines.append(f'ns.MarketSkinningPacked = "{pack(spawns)}"')
    lines.append("ns.Market.SKIN_CREATURES = {")
    for npc in sorted(creatures):
        low, high, loot_id, name = creatures[npc]
        lines.append(f"    [{npc}] = {{ {low}, {high}, {loot_id}, {lua_string(name)} }},")
    lines += ["}", "ns.Market.SKIN_LOOT = {"]
    for loot_id in sorted(loot):
        fields = ", ".join(f"{item}, {number(chance)}, {low}, {high}" for item, chance, low, high in loot[loot_id])
        lines.append(f"    [{loot_id}] = {{ {fields} }},")
    lines.append("}")
    write(SKINNING_OUT, lines)
    camps_total = sum(len(row) // 4 for row in spawns.values())
    print(f"wrote {SKINNING_OUT.relative_to(ROOT)}: {len(creatures)} creatures, {len(loot)} loot tables, "
          f"{camps_total} camps on {len(spawns)} maps, {SKINNING_OUT.stat().st_size} bytes")


def write_fishing(catches, sources, pools):
    lines = header(FISHING_OUT.name, "what each zone's water catches and the fishing pools, generated by "
                   "Tools/build/market_gather.py")
    lines.append("ns.Market.FISH_CATCHES = {")
    for ui_map in sorted(catches):
        fields = ", ".join(f"{item}, {number(chance)}" for item, chance in catches[ui_map])
        lines.append(f"    [{ui_map}] = {{ {fields} }},")
    lines += ["}", "ns.Market.FISH_POOLS = {"]
    lines += [f"    [{pool}] = true," for pool in pools]
    lines.append("}")
    write(FISHING_OUT, lines)
    counts = collections.Counter(sources.values())
    print(f"wrote {FISHING_OUT.relative_to(ROOT)}: {len(catches)} maps ({dict(counts)}), {len(pools)} pools")
    for ui_map in sorted(sources):
        print(f"  {ui_map}: {sources[ui_map]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dump", type=Path, help="the CMaNGOS classic database dump (.sql.gz)")
    parser.add_argument("--export", type=Path, help="the permitted Forever entity export (JSON)")
    eg = parser.add_mutually_exclusive_group()
    eg.add_argument("--eglink", type=Path, help="EG Link's files, a folder per build")
    eg.add_argument("--fetch-eglink", action="store_true", help="read EG Link's files from GitHub again")
    args = parser.parse_args()
    cache = load()
    if args.dump or "cmangos" not in cache:
        cache["cmangos"] = read_cmangos(scout.dump_text(args.dump or scout.DUMP))
        save(cache)
    if args.eglink or args.fetch_eglink or "eglink" not in cache:
        files = ((lambda b, n: json.loads((args.eglink / b / n).read_text(encoding="utf-8"))) if args.eglink
                 else fetch_eglink)
        cache["eglink"] = read_eglink(files)
        save(cache)
    wanted = set(cache["cmangos"]["skinnable"]) | set(cache["eglink"]["skins"])
    if args.export:
        cache["export"] = read_export(json.loads(args.export.read_text(encoding="utf-8")), wanted)
        save(cache)
    elif "export" not in cache:
        parser.error("no export section in the cache yet: pass --export FILE")
    if wanted - set(cache["export"]["asked"]):
        parser.error("the cached export was read for fewer creatures than now wanted: pass --export FILE")
    write_skinning(*skinning(cache))
    write_fishing(*fishing(cache), cache["cmangos"]["pools"])


if __name__ == "__main__":
    main()
