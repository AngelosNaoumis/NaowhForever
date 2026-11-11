"""Give the Professions recipes whose source is unknown the one ForeverChanges lists: builds
Tools/data/foreverchanges_recipes.json, then writes those sources into
NaowhForever_Professions/Data/RecipeData.lua.

Their profession pages (/professions/<trade>) list each recipe by its spell, with its recipe item
and where that comes from: who sells it (zone, side, price in copper), the mobs it drops from,
or the quest it rewards. Their dungeon pages (/dungeons/<id>) list each boss's drops, recipes
among them, for a recipe the profession pages give no source. Only a recipe RecipeData has as
"unknown" is written; every other source in it stays as it is.

- A seller RecipeData already has an NPC row for keeps that row's ID and spot. The others are
  written as sellers, { name, faction, areaID [, price] }: the pages name only their zone, and
  the game has no map of a dungeon's inside to put a spot on.
- A drop from more mobs than the page names is a world drop; otherwise the mobs it names, or
  the dungeon bosses that drop it, are its bosses.
- Zones are the game's AreaTable IDs (through wago.py), kept in the JSON with the pages' answers;
  0 where the table has no area of that name, as RecipeData has for an unknown area.
- Names that are not ASCII are left out: their pages carry some sellers twice, the second
  time in another language.

--offline reads nothing and writes sources from the JSON. --learn instead reads
learn requirements directly from the profession pages and updates only skill.
Use --learn --check to preview; --report FILE also saves the proposed unified diff.
The learn preview does not update RecipeData or the source cache.
Increases need trainer confirmation and are skipped, as are values that erase an
existing orange range or exceed grey. Skipped values are reported in the preview.
After changing cooking learn requirements, rebuild their derived Field Journal entries
with Tools/build/field_journal.py.

Usage: python Tools/build/foreverchanges_recipes.py [--offline]
"""
import argparse
import difflib
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
import wowhead  # noqa: E402

SITE = "https://foreverchanges.pro"
OUT = paths.DATA / "foreverchanges_recipes.json"
RECIPES = paths.ROOT / "NaowhForever_Professions" / "Data" / "RecipeData.lua"
GAP = 1
TRADES = ("alchemy", "blacksmithing", "camping", "cooking", "enchanting", "engineering", "first-aid",
          "fishing", "herbalism", "leatherworking", "mining", "skinning", "tailoring")
RECIPE_CLASS = 9   # a dungeon page item's class ("c") for a recipe
SIDES = {"a": "A", "h": "H", "": "AH"}
# The page's data comes as React Server Component chunks, JSON strings pushed in order.
PUSH = re.compile(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)')
ROW = re.compile(r'\{"spell":\d+,"id":')
NPC = re.compile(r'\{ (\d+), ("(?:[^"\\]|\\.)*"), "[AH-]+", (\d+, [\d.]+, [\d.]+)')
UNKNOWN = re.compile(r'^( *)(\{ spell = (\d+),.*?), source = "unknown" \},', re.M)
LEARN_TRADES = ("alchemy", "blacksmithing", "cooking", "enchanting", "engineering",
                "first-aid", "leatherworking", "mining", "tailoring")
SKILL = re.compile(r"^([ \t]*\{ spell = (\d+),[^\r\n]*?\bskill = )(\d+)\b", re.M)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": wowhead.AGENT})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def page_data(page):
    return "".join(json.loads(m.group(1)) for m in PUSH.finditer(page))


def listed(data, key):
    """The first list under key in a page's data; None where it has none."""
    at = data.find(f'"{key}":[')
    if at < 0:
        return None
    return json.JSONDecoder().raw_decode(data, at + len(key) + 3)[0]


def recipe_rows(data):
    decoder = json.JSONDecoder()
    return [decoder.raw_decode(data, m.start())[0] for m in ROW.finditer(data)]


def trade_recipes(data):
    """[(spell, recipe item, its source)] for each recipe a profession page lists with an item.
    Enchanting's rods, oils and blueprints name their item as taught_by, with no source."""
    found = []
    for row in recipe_rows(data):
        item = row["formula"]["id"] if row.get("formula") else row.get("taught_by")
        if item:
            found.append((row["spell"], item, row.get("source") or {}))
    return found


def trade_learns(data):
    """Every recipe's learn requirement, including trainer recipes with no formula item."""
    values = {}
    for row in recipe_rows(data):
        if row.get("learn") is None:
            continue
        spell, learn = row["spell"], row["learn"]
        if type(spell) is not int or spell <= 0 or type(learn) is not int or learn < 0:
            raise ValueError(f"Invalid spell/learn value: {spell!r}, {learn!r}")
        if spell in values and values[spell] != learn:
            raise ValueError(f"Conflicting learn requirements for spell {spell}")
        values[spell] = learn
    return values


def read_learns(trades):
    values = {}
    for index, trade in enumerate(dict.fromkeys(trades)):
        if index:
            time.sleep(GAP)
        found = trade_learns(page_data(fetch(f"{SITE}/professions/{trade}")))
        if not found:
            raise ValueError(f"No learn requirements on the {trade} page; catalog unchanged")
        for spell, learn in found.items():
            if spell in values and values[spell] != learn:
                raise ValueError(f"Conflicting learn requirements for spell {spell}")
            values[spell] = learn
        print(f"{trade}: {len(found)} recipe learn requirements")
    return values


def checked_learns(text, values, report=False):
    accepted = {}
    for line in text.splitlines():
        match = SKILL.match(line)
        if not match:
            continue
        spell, current = int(match[2]), int(match[3])
        learn = values.get(spell)
        if learn is None:
            continue
        thresholds = {key: int(value) for key, value in re.findall(r"\b(yellow|grey) = (\d+)", line)}
        yellow, grey = thresholds.get("yellow"), thresholds.get("grey")
        reason = None
        if grey is not None and learn > grey:
            reason = f"above grey {grey}"
        elif yellow is not None and current < yellow <= learn:
            reason = f"at or above yellow {yellow}, removing the orange range"
        elif learn > current:
            reason = "increase needs trainer confirmation"
        if reason:
            if report:
                print(f"Spell {spell}: skipped skill {current} -> {learn}: {reason}")
        else:
            accepted[spell] = learn
    return accepted


def fill_learns(text, values):
    values = checked_learns(text, values)
    def one(match):
        learn = values.get(int(match[2]))
        return match[0] if learn is None else match[1] + str(learn)
    return SKILL.sub(one, text)


def preview_learns(text, values):
    old = {int(m[2]): int(m[3]) for m in SKILL.finditer(text)}
    matched = old.keys() & values.keys()
    if not matched:
        raise ValueError("No imported spell IDs match the recipe catalog")
    accepted = checked_learns(text, values, report=True)
    changed = [(spell, old[spell], accepted[spell]) for spell in sorted(accepted) if old[spell] != accepted[spell]]
    for spell, before, after in changed:
        print(f"Spell {spell}: skill {before} -> {after}")
    print(f"{len(matched)} matched recipes; {len(matched) - len(accepted)} values skipped; "
          f"{len(changed)} learn requirements differ; "
          f"{len(old.keys() - values.keys())} unlisted recipes retained unchanged")
    return fill_learns(text, accepted)


def boss_recipes(data, dungeon):
    """{recipe item: [[boss, dungeon], ...]} for the recipes a dungeon page's bosses drop; none
    on a page for a dungeon not out yet, which lists no bosses."""
    out = {}
    for boss in listed(data, "bosses") or []:
        for item in boss["items"]:
            if item.get("c") == RECIPE_CLASS:
                out.setdefault(item["i"], []).append([boss["name"], dungeon])
    return out


def source(found, dropped):
    """A recipe's source as the JSON keeps it, from its profession page's source and the dungeon
    bosses that drop it; None where neither names one."""
    vendors = [[v["npc"], v["zone"], v["side"], v.get("price")] for v in found.get("vendors") or []
               if v["npc"].isascii()]
    if vendors:
        return {"vendors": vendors}
    drops = found.get("drops") or []
    if sum(place["n"] for place in found.get("places") or []) > len(drops):
        return {"world": True}
    bosses = [[d["npc"], d["zone"]] for d in drops if d["npc"].isascii()]
    if bosses:
        return {"bosses": bosses}
    quests = [[q["name"], q["side"], q["level"], q.get("id")] for q in found.get("quests") or []]
    if quests:
        return {"quests": quests}
    if dropped:
        return {"bosses": dropped}
    return None


def read():
    """{spell: {"recipe": item, and its source}} for every recipe ForeverChanges gives a source."""
    recipes = {}
    for trade in TRADES:
        for spell, item, found in trade_recipes(page_data(fetch(f"{SITE}/professions/{trade}"))):
            recipes[spell] = (item, found)
        time.sleep(GAP)
    if not recipes:
        raise ValueError("no recipes on ForeverChanges' profession pages")
    dungeons = listed(page_data(fetch(f"{SITE}/dungeons")), "dungeons")
    if not dungeons:
        raise ValueError("no dungeons on ForeverChanges' dungeons page")
    dropped = {}
    for dungeon in dungeons:
        time.sleep(GAP)
        page = page_data(fetch(f"{SITE}/dungeons/{dungeon['id']}"))
        for item, bosses in boss_recipes(page, dungeon["name"]).items():
            dropped.setdefault(item, []).extend(bosses)
    out = {}
    for spell, (item, found) in recipes.items():
        known = source(found, dropped.get(item))
        if known:
            out[str(spell)] = {"recipe": item, **known}
    return out


def areas(rows, names):
    """Zone name -> its AreaTable ID: the zone or dungeon of that name before a subzone, the
    lower ID of two; 0 for a name the table lacks."""
    ids = {}
    for row in sorted(rows, key=lambda r: (r["ParentAreaID"] != "0", int(r["ID"]))):
        ids.setdefault(row["AreaName_lang"], int(row["ID"]))
    return {name: ids.get(name, 0) for name in sorted(names)}


def block(field, rows, indent):
    return f"{field} = {{\r\n" + "".join(f"{indent}    {row},\r\n" for row in rows) + f"{indent}}}"


def lua_source(entry, npcs, zones, indent):
    """The RecipeData fields for a recipe's source, from source = on."""
    if entry.get("world"):
        return 'source = "drop", world = 1'
    if "bosses" in entry:
        rows = [f"{{ {wowhead.lua_string(name)}, {zones[zone]} }}" for name, zone in entry["bosses"]]
        return 'source = "drop", ' + block("bosses", list(dict.fromkeys(rows)), indent)
    if "quests" in entry:
        rows = []
        for name, side, level, quest in entry["quests"]:
            given = "" if quest is None else f"id = {quest}, "
            rows.append(f'{{ {given}name = {wowhead.lua_string(name)}, side = "{SIDES[side]}", level = {level} }}')
        return 'source = "quest", ' + block("quests", rows, indent)
    spotted, sellers = [], []
    for name, zone, side, price in entry["vendors"]:
        name, cost = wowhead.lua_string(name), "" if price is None else f", {price}"
        if name in npcs:
            npc, spot = npcs[name]
            spotted.append(f'{{ {npc}, {name}, "{SIDES[side]}", {spot}{cost} }}')
        else:
            sellers.append(f'{{ {name}, "{SIDES[side]}", {zones[zone]}{cost} }}')
    lists = [block("vendors", spotted, indent)] if spotted else []
    lists += [block("sellers", sellers, indent)] if sellers else []
    return 'source = "vendor", ' + ", ".join(lists)


def fill(text, recipes, zones):
    """RecipeData's text with each unknown recipe ForeverChanges knows given its source, and its
    recipe item where the row has none."""
    npcs = {}
    for npc, name, spot in NPC.findall(text):
        npcs.setdefault(name, (npc, spot))

    def one(m):
        entry = recipes.get(m[3])
        if not entry:
            return m[0]
        head = m[2] if "recipe = " in m[2] else f"{m[2]}, recipe = {entry['recipe']}"
        return f"{m[1]}{head}, {lua_source(entry, npcs, zones, m[1])} }},"
    return UNKNOWN.sub(one, text)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--learn", action="store_true", help="Import only learn requirements, not sources")
    parser.add_argument("--check", action="store_true", help="Preview without changing the catalog or cache")
    parser.add_argument("--profession", action="append", choices=LEARN_TRADES)
    parser.add_argument("--report", type=Path, help="Save the proposed unified diff (requires --check)")
    args = parser.parse_args(argv)
    if args.offline and args.learn:
        parser.error("--offline cache contains sources, not learn requirements")
    if args.profession and not args.learn:
        parser.error("--profession requires --learn")
    if args.report and (not args.check or not args.learn or args.report.exists()
                        or args.report.resolve() in {RECIPES.resolve(), OUT.resolve()}):
        parser.error("--report requires --learn --check and a new file distinct from the catalog/cache")
    text = RECIPES.read_bytes().decode("ascii")
    if args.learn:
        filled = preview_learns(text, read_learns(args.profession or LEARN_TRADES))
        if args.report:
            diff = difflib.unified_diff(text.splitlines(keepends=True), filled.splitlines(keepends=True),
                                       fromfile="RecipeData.lua (current)", tofile="RecipeData.lua (ForeverChanges learn)")
            args.report.write_bytes("".join(diff).encode("ascii"))
            print(f"Proposed diff: {args.report}")
        if args.check:
            print("Preview only; recipe catalog and source cache unchanged")
        elif filled != text:
            RECIPES.write_bytes(filled.encode("ascii"))
            print(f"Updated learn requirements: {RECIPES}")
        return
    if args.offline:
        data = json.loads(OUT.read_text(encoding="utf-8"))
    else:
        recipes = read()
        rows = [row for entry in recipes.values() for row in entry.get("vendors", []) + entry.get("bosses", [])]
        data = {"recipes": recipes, "areas": areas(wago.table("AreaTable"), {row[1] for row in rows})}
        if not args.check:
            OUT.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    filled = fill(text, data["recipes"], data["areas"])
    if not args.check:
        RECIPES.write_bytes(filled.encode("ascii"))
    before, after = (len(UNKNOWN.findall(t)) for t in (text, filled))
    print(f"{len(data['recipes'])} recipes with a source on ForeverChanges; {before - after} of {before} "
          f"unknown recipes given one, {after} left: {RECIPES.relative_to(paths.ROOT)}")


if __name__ == "__main__":
    main()
