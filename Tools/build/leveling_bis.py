"""Build NaowhForever_BiS/BiS/Data/Leveling.lua: each spec's gear at levels 30, 40, 50 and 60, for
the Alliance and the Horde, and where each item comes from.

Each spec page (PAGES) carries its whole gear window as data in the page: "picks" has a list per
level and side ("30a", "30h"), seventeen item IDs or nulls in the order of SLOTS, and "items" each
item's name, quality, icon, required level, tooltip lines and sources. A source is
[kind, who, where, side, id]: a quest (q), a dungeon boss (d), a craft (c), a vendor (v) or a named
mob (n); an item with none gets no source. The BiS List loads a level's list as a list of the player's (Lists.lua).

Usage: python Tools/build/leveling_bis.py
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wowhead  # noqa: E402

SITE = "https://timesaver.gg/tools/wow-forever/leveling-gear"
OUT = paths.ROOT / "NaowhForever_BiS" / "BiS" / "Data" / "Leveling.lua"
LEVELS = (30, 40, 50, 60)
SIDES = (("a", "Alliance"), ("h", "Horde"))
# Their page for each spec -> our specs; their one Feral list is for cat and bear both.
PAGES = {
    "druid/balance": ["balance-druid"],
    "druid/feral": ["feral-dps-druid", "feral-tank-druid"],
    "druid/restoration": ["restoration-druid"],
    "hunter/beast-mastery": ["beast-mastery-hunter"],
    "hunter/marksmanship": ["marksmanship-hunter"],
    "hunter/survival": ["survival-hunter"],
    "mage/arcane": ["arcane-mage"],
    "mage/fire": ["fire-mage"],
    "mage/frost": ["frost-mage"],
    "paladin/holy": ["holy-paladin"],
    "paladin/protection": ["protection-paladin"],
    "paladin/retribution": ["retribution-paladin"],
    "priest/discipline": ["discipline-priest"],
    "priest/holy": ["holy-priest"],
    "priest/shadow": ["shadow-priest"],
    "rogue/assassination": ["assassination-rogue"],
    "rogue/combat": ["combat-rogue"],
    "rogue/subtlety": ["subtlety-rogue"],
    "shaman/elemental": ["elemental-shaman"],
    "shaman/enhancement": ["enhancement-shaman"],
    "shaman/restoration": ["restoration-shaman"],
    "warlock/affliction": ["affliction-warlock"],
    "warlock/demonology": ["demonology-warlock"],
    "warlock/destruction": ["destruction-warlock"],
    "warrior/arms": ["arms-warrior"],
    "warrior/fury": ["fury-warrior"],
    "warrior/protection": ["protection-warrior"],
}
# Their slot order -> inventory slots: head to feet, two rings, two trinkets, the hands, ranged.
SLOTS = (1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18)
QUEST = {"a": "Quest (Alliance)", "h": "Quest (Horde)", "b": "Quest"}
SEP = wowhead.SEP
PUSH = re.compile(r"self\.__next_f\.push\((\[.*?\])\)</script>", re.S)


def gear(page):
    """The gear window's data, {"picks": ..., "items": ...}, from the payload the page streams in."""
    text = ""
    for chunk in PUSH.findall(page):
        part = json.loads(chunk)
        if len(part) > 1 and isinstance(part[1], str):
            text += part[1]
    start = text.find('{"picks":')
    if start < 0:
        raise ValueError("no gear window on the page")
    return json.JSONDecoder().raw_decode(text, start)[0]


def lists(picks):
    """{level: {side: {inventory slot: item ID}}} for LEVELS, empty slots left out."""
    out = {}
    for level in LEVELS:
        out[level] = {}
        for key, side in SIDES:
            ids = picks[f"{level}{key}"]
            if len(ids) != len(SLOTS):
                raise ValueError(f"{level}{key} has {len(ids)} slots, not {len(SLOTS)}")
            out[level][side] = {inv: i for inv, i in zip(SLOTS, ids) if i}
    return out


def source(sources):
    """An item's source as bis_data.py writes them, from the first of its sources: a quest's name
    and its side, a profession, or a boss, mob or vendor and their place. A reward of quests on both
    sides with different names is just Quest."""
    kind, who, where, side = sources[0][:4]
    if kind == "q":
        quests = [s for s in sources if s[0] == "q"]
        sides = {s[3] for s in quests}
        if "b" in sides or sides == {"a", "h"}:
            return who + SEP + "Quest" if len({s[1] for s in quests}) == 1 else "Quest"
        return who + SEP + QUEST[side]
    if kind == "c":
        return who + SEP + "Crafted"
    if kind in ("d", "v", "n") and where:
        return who + SEP + where
    raise ValueError(f"a source not known: {sources[0]!r}")


def lua_string(s):
    """s as a Lua string in ASCII: any other letter as its UTF-8 bytes in decimal escapes."""
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + "".join(c if ord(c) < 128 else "".join(f"\\{b}" for b in c.encode("utf-8")) for c in s) + '"'


def render(specs, sources):
    lines = [
        "-- Leveling.lua: each spec's gear at levels 30, 40, 50 and 60 for each side, and where it comes from"
        " (Tools/build/leveling_bis.py).",
        "local ns = _G.NaowhForever",
        "",
        "ns.BiSLeveling = {",
        f"    levels = {{ {', '.join(str(level) for level in LEVELS)} }},",
        "    specs = {",
    ]
    for key in sorted(specs):
        lines.append(f"        [{lua_string(key)}] = {{")
        for level in LEVELS:
            lines.append(f"            [{level}] = {{")
            for _, side in SIDES:
                slots = specs[key][level][side]
                picks = ", ".join(f"[{inv}] = {slots[inv]}" for inv in SLOTS if inv in slots)
                lines.append(f"                {side} = {{ {picks} }},")
            lines.append("            },")
        lines.append("        },")
    lines += ["    },", "    sources = {"]
    for item_id in sorted(sources):
        lines.append(f"        [{item_id}] = {lua_string(sources[item_id])},")
    lines += ["    },", "}"]
    return "\r\n".join(lines) + "\r\n"


def main():
    specs, sources = {}, {}
    for path, keys in PAGES.items():
        data = gear(wowhead.fetch(f"{SITE}/{path}"))
        found = lists(data["picks"])
        for level in found.values():
            for slots in level.values():
                for item_id in slots.values():
                    item = data["items"][str(item_id)]
                    if item[5]:
                        sources[item_id] = source(item[5])
        for key in keys:
            specs[key] = found
        print(f"{path}: {sum(len(s) for level in found.values() for s in level.values())} picks", file=sys.stderr)
    OUT.write_text(render(specs, sources), encoding="utf-8", newline="")
    print(f"{len(specs)} specs, {len(sources)} items -> {OUT.name}", file=sys.stderr)


if __name__ == "__main__":
    main()
