"""Build the Field Journal's data: every fish you can catch, herb you can pick and dish you can cook,
and where to find each.

  - Fish: each zone's catches as Tools/build/market_gather.py blends them from data/market_gather.json,
    and the fishing pools' loot from the CMaNGOS classic database (github.com/cmangos/classic-db,
    GPL-3.0), downloaded as scout.py does, or --dump FILE. A catch is a fish when the game's Item table
    files it as meat, other trade goods, food or a quest item, less NOT_FISH. Its zones are the ZONES it
    is caught in most, at MIN_CHANCE or more; its skill the lowest Fishing skill that fishes in any of
    those (NaowhForever_QoL/Interface/FishingLevelsData.lua). A fish most of a pool's loot is comes from
    schools too; the database has too few pool spawns to say where they are, so a fish only schools
    give has no zones and no skill.
  - Herbs: Glimmer's herb nodes (NaowhForever_QoL/Glimmer/Data/Nodes.lua) and where they grow
    (data/glimmer_spots.json), each node's item from Professions' GatherNodes, kept unless the Item table
    files it as a quest item (Doom Weed, Serpentbloom). A herb's skill is its lowest node's; its zones the
    ones with the most spots; its nodes the object IDs that yield it, which the journal counts picks from.
  - Dishes: Professions' cooking recipes that make an item (NaowhForever_Professions/Data/RecipeData.lua)
    and how each is learned: from a trainer, the first vendor or quest giver for each side, the first
    boss that drops it, or a world drop.

The pools' loot and the item classes read are kept in data/field_journal.json, an item the Item table
lacks as null so it is not asked for again; pass --dump to read the pools again, or delete the file.

Writes NaowhForever_Discovery/Data/FieldJournal.lua.

Usage: python Tools/build/field_journal.py [--dump FILE]
"""
import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import scout  # noqa: E402
import wago  # noqa: E402
import market_gather  # noqa: E402
from journal import ROOT, header, lua_string, write  # noqa: E402
from quest_chains import ZONE_MAP  # noqa: E402

OUT = ROOT / "NaowhForever_Discovery" / "Data" / "FieldJournal.lua"
CACHE = paths.DATA / "field_journal.json"
FISHING_LEVELS = ROOT / "NaowhForever_QoL" / "Interface" / "FishingLevelsData.lua"
NODES = ROOT / "NaowhForever_QoL" / "Glimmer" / "Data" / "Nodes.lua"
GATHER_NODES = ROOT / "NaowhForever_Professions" / "Data" / "GatherNodes.lua"
SPOTS = paths.DATA / "glimmer_spots.json"
RECIPES = ROOT / "NaowhForever_Professions" / "Data" / "RecipeData.lua"
COOKING = 185
FISH_CLASSES = {(7, 8), (7, 11), (0, 5), (12, 0)}
QUEST_CLASS = 12
NOT_FISH = {
    20709: "Rumsey Rum Light, a drink",
    19807: "Tastyfish, caught only for the Stranglethorn Fishing Extravaganza",
}
MIN_CHANCE = 0.5
SCHOOL_SHARE = 50
ZONES = 3
SIDES = {"A": "A", "H": "H", "AH": "B", "-": "B"}
DECIMALS = 1


def load():
    return json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}


def save(cache):
    CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def read_pools(sql):
    """{ pool object ID: [[item, chance], ...] }: each open-world fishing pool's loot, as
    market_gather.py picks the pools."""
    def by_entry(table):
        found = collections.defaultdict(list)
        for row in scout.rows(sql, table):
            found[row["entry"]].append(row)
        return found

    refs = by_entry("reference_loot_template")
    loot = by_entry("gameobject_loot_template")
    holes = {row["entry"]: row["data1"] for row in scout.rows(sql, "gameobject_template")
             if row["type"] == market_gather.FISHING_HOLE and row["data1"] in loot}
    maps = collections.defaultdict(set)
    for row in scout.rows(sql, "gameobject"):
        if row["id"] in holes:
            maps[row["id"]].add(row["map"])
    return {pool: sorted([item, round(v[0], 2)] for item, v in market_gather.flatten(loot[loot_id], refs).items())
            for pool, loot_id in sorted(holes.items(), key=lambda p: int(p[0]))
            if not maps[pool] or maps[pool] & market_gather.OPEN_WORLD}


def item_classes(cache, wanted):
    """{ item: (class, subclass) }, reading the game's Item table for any not kept yet."""
    kept = cache.setdefault("items", {})
    missing = {i for i in wanted if str(i) not in kept}
    if missing:
        for i in missing:
            kept[str(i)] = None
        for row in wago.table("Item"):
            if int(row["ID"]) in missing:
                kept[row["ID"]] = [int(row["ClassID"]), int(row["SubclassID"])]
        save(cache)
    return {i: tuple(kept[str(i)]) for i in wanted if kept.get(str(i))}


def fishing_levels():
    text = FISHING_LEVELS.read_text(encoding="ascii")
    return {int(m): int(low) for m, low in re.findall(r"\[(\d+)\] = \{ (\d+), \d+ \}", text)}


def fish(cache):
    catches, _ = market_gather.fishing(market_gather.load())
    schools = set()
    caught = set()
    for loot in cache["pools"].values():
        for item, chance in loot:
            caught.add(item)
            if chance >= SCHOOL_SHARE:
                schools.add(item)
    where = collections.defaultdict(list)
    for ui_map, table in catches.items():
        for item, chance in table:
            caught.add(item)
            if chance >= MIN_CHANCE:
                where[item].append((ui_map, chance))
    classes = item_classes(cache, caught)
    levels = fishing_levels()
    out = []
    for item in sorted(caught):
        if classes.get(item) not in FISH_CLASSES or item in NOT_FISH:
            continue
        zones = sorted(where[item], key=lambda z: (-z[1], z[0]))[:ZONES]
        if not zones and item not in schools:
            continue
        skills = [levels[m] for m, _ in zones if m in levels]
        out.append({"item": item, "skill": min(skills) if skills else None, "zones": zones,
                    "schools": item in schools})
    return sorted(out, key=lambda f: (f["skill"] is None, f["skill"] or 0, f["item"]))


def herbs(cache):
    names = {}
    for name, item in re.findall(r'\["(.+?)"\] = \{ "herb", \d+, (\d+) \}', GATHER_NODES.read_text(encoding="ascii")):
        names[name] = int(item)
    nodes = {int(o): (int(skill), name) for o, skill, name in
             re.findall(r'\[(\d+)\] = \{ "herb", (\d+), "(.+?)" \}', NODES.read_text(encoding="ascii"))}
    spots = json.loads(SPOTS.read_text(encoding="utf-8"))
    zones = set(ZONE_MAP.values())
    skill, counts, objects = {}, collections.defaultdict(collections.Counter), collections.defaultdict(list)
    for obj, (need, name) in nodes.items():
        item = names.get(name)
        if item is None:
            print(f"  herb node {obj} ({name}) has no item in GatherNodes", file=sys.stderr)
            continue
        skill[item] = min(need, skill.get(item, need))
        objects[item].append(obj)
        for ui_map, coords in spots.get(str(obj), {}).items():
            if int(ui_map) in zones:
                counts[item][int(ui_map)] += len(coords)
    classes = item_classes(cache, set(skill))
    out = []
    for item in sorted(skill, key=lambda i: (skill[i], i)):
        if item not in classes:
            print(f"  herb {item} is not in the game's Item table, left out", file=sys.stderr)
            continue
        if classes[item][0] == QUEST_CLASS:
            continue
        out.append({"item": item, "skill": skill[item], "nodes": sorted(objects[item]),
                    "zones": [m for m, _ in sorted(counts[item].items(), key=lambda c: (-c[1], c[0]))[:ZONES]]})
    return out


TOKEN = re.compile(r'\s*(?:(-?\d+(?:\.\d+)?)|"((?:[^"\\]|\\.)*)"|([A-Za-z_]\w*)|(\S))')


def lua_table(text, pos):
    """The Lua table literal starting at text[pos] ("{") as a list or dict, and the position after it."""
    def value(pos):
        m = TOKEN.match(text, pos)
        number, string, name, punct = m.groups()
        if number is not None:
            return (float(number) if "." in number else int(number)), m.end()
        if string is not None:
            return json.loads('"' + string + '"'), m.end()
        if name is not None:
            return {"true": True, "false": False, "nil": None}.get(name, name), m.end()
        if punct == "{":
            return table(m.end())
        raise ValueError(f"unexpected {punct!r} at {m.start()}")

    def table(pos):
        items, keyed = [], {}
        while True:
            m = TOKEN.match(text, pos)
            if m.group(4) == "}":
                return (keyed if keyed else items), m.end()
            if m.group(4) == ",":
                pos = m.end()
                continue
            if m.group(4) == "[":
                key, pos = value(m.end())
                pos = TOKEN.match(text, pos).end()
                pos = TOKEN.match(text, pos).end()
                keyed[key], pos = value(pos)
                continue
            after = TOKEN.match(text, m.end())
            if m.group(3) and after.group(4) == "=":
                keyed[m.group(3)], pos = value(after.end())
                continue
            v, pos = value(pos)
            items.append(v)

    return value(pos)


def dishes():
    text = RECIPES.read_text(encoding="ascii")
    start = text.index(f"    [{COOKING}] = {{")
    profession, _ = lua_table(text, text.index("{", start))
    out = []
    for recipe in profession["recipes"]:
        if "item" not in recipe:
            continue
        dish = {"spell": recipe["spell"], "item": recipe["item"], "skill": recipe["skill"]}
        how = "world" if recipe.get("world") else recipe["source"]
        dish["how"] = how
        if how == "vendor":
            for npc in recipe.get("vendors", []):
                dish.setdefault(SIDES[npc[2]], [npc[1], npc[3], npc[4], npc[5]])
        elif how == "quest":
            for quest in recipe["quests"]:
                npc = quest.get("npc")
                dish.setdefault(SIDES[quest["side"]], [quest["name"]] + (npc[3:6] + [npc[1]] if npc else []))
        elif how == "drop":
            dish["B"] = [recipe["bosses"][0][0]]
        out.append(dish)
    return sorted(out, key=lambda d: (d["skill"], d["spell"]))


def number(value):
    return f"{round(value, DECIMALS):g}"


def lua_value(value):
    return lua_string(value) if isinstance(value, str) else number(value)


def lua_list(values):
    return "{ " + ", ".join(values) + " }"


def write_journal(fishes, plants, cooked):
    lines = header(OUT.name, "every fish, herb and dish the Field Journal lists, and where each is found, "
                   "generated by Tools/build/field_journal.py")
    lines.append("ns.FieldJournal = {")
    lines.append("    fish = {")
    for f in fishes:
        fields = [f"item = {f['item']}"]
        if f["skill"] is not None:
            fields.append(f"skill = {f['skill']}")
        if f["zones"]:
            fields.append("zones = " + lua_list(f"{m}, {number(c)}" for m, c in f["zones"]))
        if f["schools"]:
            fields.append("schools = true")
        lines.append("        { " + ", ".join(fields) + " },")
    lines += ["    },", "    herbs = {"]
    for h in plants:
        lines.append(f"        {{ item = {h['item']}, skill = {h['skill']}, zones = {lua_list(str(m) for m in h['zones'])}, "
                     f"nodes = {lua_list(str(o) for o in h['nodes'])} }},")
    lines += ["    },", "    dishes = {"]
    for d in cooked:
        fields = [f"spell = {d['spell']}", f"item = {d['item']}", f"skill = {d['skill']}", f'how = "{d["how"]}"']
        for side in ("A", "H", "B"):
            if side in d:
                fields.append(f"{side} = " + lua_list(lua_value(v) for v in d[side]))
        lines.append("        { " + ", ".join(fields) + " },")
    lines += ["    },", "}"]
    write(OUT, lines)
    print(f"wrote {OUT.relative_to(ROOT)}: {len(fishes)} fish, {len(plants)} herbs, {len(cooked)} dishes")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dump", type=Path, help="the CMaNGOS classic database dump (.sql.gz)")
    args = parser.parse_args()
    cache = load()
    if args.dump or "pools" not in cache:
        cache["pools"] = read_pools(scout.dump_text(args.dump or scout.DUMP))
        save(cache)
    write_journal(fish(cache), herbs(cache), dishes())


if __name__ == "__main__":
    main()
