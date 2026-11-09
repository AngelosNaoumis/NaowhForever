"""Build the names the addon's data has in English, for the player's language.

The game client answers in its language for a dungeon (GetRealZoneText) or an area
(C_Map.GetAreaInfo), but not for an NPC, an object or a faction it has not met. So, for each
language but English, NaowhForever_DungeonJournal/Data/Names/<code>.lua carries the Journal's
bosses (by NPC ID), its loot chests (by object ID) and its factions (by faction ID) in that
language, where it differs from the English name; the places the data names in English (the BiS
List's sources, its quests' zones, a faction's zone), by that name; and Scarlet Monastery's
subzones, each to its English name, which picks the wing you are in:

- a boss's or a chest's name, and a boss's title (the line under its name), is Wowhead Forever's
  in that language (its tooltip answer, what the game gave it), cached in
  Tools/data/game_names.json: delete an entry to ask again;
- a faction's is the game's own Faction table's, from wago.tools;
- a place's is the game's AreaTable's, the area of that English name (case and a leading "the"
  aside), the lowest ID where several share it;
- a subzone's is the game's WMOAreaTable's: GetSubZoneText answers from it inside a building, and
  no API reads it by ID.

Usage: python Tools/build/game_names.py
"""
import html
import json
import re
import sys
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import wago  # noqa: E402
from journal import OUT, ROOT, ascii_string, header, write  # noqa: E402
from wowhead import fetch  # noqa: E402

CACHE = paths.DATA / "game_names.json"
NAMES = OUT / "Data" / "Names"
BIS_SOURCES = (ROOT / "NaowhForever_BiS" / "BiS" / "Data" / "BiS.lua",
               ROOT / "NaowhForever_BiS" / "BiS" / "Data" / "Leveling.lua")
TOOLTIP = "https://nether.wowhead.com/forever/{}tooltip/{}/{}"
# Each language, Wowhead's code for it and its name, as the locale files name it.
LANGUAGES = {
    "deDE": ("de", "German"),
    "esES": ("es", "Spanish (Spain)"),
    "esMX": ("mx", "Spanish (Latin America)"),
    "frFR": ("fr", "French"),
    "itIT": ("it", "Italian"),
    "ptBR": ("pt", "Portuguese (Brazil)"),
    "ruRU": ("ru", "Russian"),
    "koKR": ("ko", "Korean"),
    "zhCN": ("cn", "Simplified Chinese"),
    "zhTW": ("tw", "Traditional Chinese"),
}
NOT_FOUND = 404   # Wowhead's answer for an NPC or object it has no page for
SAVE_EVERY = 50
LUA_STRING = r'"((?:[^"\\]|\\.)*)"'
BOSS = re.compile(r"\{ npc = (\w+), name = " + LUA_STRING + r"([^\n]*)")
CHEST = re.compile(r"chest = (\d+)")
FACTION = re.compile(r"id = (\d+), name = " + LUA_STRING)
FACTION_ZONE = re.compile(r"^    zone = " + LUA_STRING, re.M)
SUBZONE = re.compile(r"\[" + LUA_STRING + r'\] = "ScarletMonastery')
SOURCE_PLACE = re.compile("(?:\u00b7|\\\\194\\\\183) " + LUA_STRING[1:])
QUEST_ZONE = re.compile(r"^    \[\d+\] = " + LUA_STRING, re.M)
BOSS_TITLE = re.compile(r"^    \[(\d+)\] = \{ [^\"\n]*" + LUA_STRING + r" \},", re.M)
TOOLTIP_LINE = re.compile(r"<td>(.*?)</td>", re.S)
TAG = re.compile(r"<[^>]+>")

cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
asked = 0


def unescape(s):
    return re.sub(r"\\(.)", r"\1", s)


def journal_entities():
    """The Journal's bosses and chests: {("npc" or "object", ID): English name}."""
    found = {}
    for path in sorted((OUT / "Data" / "Dungeons").glob("*.lua")):
        for npc, name, rest in BOSS.findall(path.read_text(encoding="ascii")):
            chest = CHEST.search(rest)
            if npc != "nil":
                found[("npc", int(npc))] = unescape(name)
            elif chest:
                found[("object", int(chest.group(1)))] = unescape(name)
    return found


def journal_factions():
    """The Journal's factions: {faction ID: English name}."""
    found = {}
    for path in sorted((OUT / "Data" / "Factions").glob("*.lua")):
        match = FACTION.search(path.read_text(encoding="ascii"))
        found[int(match.group(1))] = unescape(match.group(2))
    return found


def english_places():
    """The places the data names in English: the BiS List's sources' places, its quests' zones and
    the factions' zones."""
    found = set()
    for path in BIS_SOURCES:
        text = path.read_text(encoding="utf-8")
        found |= {unescape(place) for place in SOURCE_PLACE.findall(text[text.index("sources = {"):])}
    quests = (OUT / "Data" / "BiSQuests.lua").read_text(encoding="ascii")
    found |= {unescape(zone) for zone in QUEST_ZONE.findall(quests[quests.index("J.BiSQuestZones = {"):])}
    for path in (OUT / "Data" / "Factions").glob("*.lua"):
        found |= {unescape(zone) for zone in FACTION_ZONE.findall(path.read_text(encoding="ascii"))}
    return found


def plain(name):
    return re.sub(r"^the ", "", name.lower())


def place_names(wanted, english_rows, locale):
    """{English place name the data uses: the game's name for that area in the locale}, where they
    differ."""
    names = {row["ID"]: row["AreaName_lang"] for row in wago.table("AreaTable", locale=locale)}
    areas = {}
    for row in sorted(english_rows, key=lambda row: int(row["ID"])):
        areas.setdefault(plain(row["AreaName_lang"]), row["ID"])
    found = {}
    for name in wanted:
        local = names.get(areas.get(plain(name)))
        if local and local != name:
            found[name] = local
    return found


def journal_subzones():
    """The English subzone names DungeonJournal.lua's SUBZONES tells Scarlet Monastery's wings by."""
    return {unescape(name) for name in SUBZONE.findall((OUT / "DungeonJournal.lua").read_text(encoding="ascii"))}


def subzone_names(wanted, english_rows, locale):
    """{subzone's name in the locale: its English name}, where they differ."""
    names = {row["ID"]: row["AreaName_lang"] for row in wago.table("WMOAreaTable", locale=locale)}
    found = {}
    for row in english_rows:
        name = names.get(row["ID"])
        if row["AreaName_lang"] in wanted and name and name != row["AreaName_lang"]:
            found.setdefault(name, row["AreaName_lang"])
    return found


def wowhead(code, kind, entity):
    """Wowhead Forever's tooltip answer for the NPC or object in the language ("" for English), or
    {} where it has none."""
    try:
        return json.loads(fetch(TOOLTIP.format(code and code + "/", kind, entity)))
    except urllib.error.HTTPError as e:
        if e.code != NOT_FOUND:
            raise
        return {}


def cached(key, get):
    global asked
    if key not in cache:
        cache[key] = get()
        asked += 1
        if asked % SAVE_EVERY == 0:
            save_cache()
    return cache[key]


def wowhead_name(code, kind, entity):
    """The name Wowhead Forever gives the NPC or object in the language, or None where it has
    none."""
    return cached(f"{kind}:{code}:{entity}", lambda: wowhead(code, kind, entity).get("name"))


def wowhead_lines(code, npc):
    """The NPC's tooltip lines in the language: its name, its title where it has one, its level."""
    def get():
        tooltip = wowhead(code, "npc", npc).get("tooltip", "")
        return [html.unescape(TAG.sub("", line)) for line in TOOLTIP_LINE.findall(tooltip)]
    return cached(f"lines:{code}:{npc}", get)


def boss_titles():
    """The bosses with a title: {NPC ID: English title}, from Data/BossInfo.lua."""
    text = (OUT / "Data" / "BossInfo.lua").read_text(encoding="ascii")
    return {int(npc): unescape(title) for npc, title in BOSS_TITLE.findall(text)}


def title_names(titles, code):
    """{NPC ID: its title in the language}, where Wowhead's English tooltip has the same title on
    its second line, its tooltip in the language has as many lines, and the title differs."""
    found = {}
    for npc, title in titles.items():
        english, lines = wowhead_lines("", npc), wowhead_lines(code, npc)
        if len(english) > 1 and english[1] == title and len(lines) == len(english) and lines[1] != title:
            found[npc] = lines[1]
    return found


def save_cache():
    CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")


def names_file(locale, title, entities, factions, titles, places, subzones):
    lines = header(f"{locale}.lua", f"the Dungeon Journal's bosses, chests, factions, places and subzones in "
                   f"{title}, generated by Tools/build/game_names.py")
    lines += [f'if ns.LOCALE ~= "{locale}" then return end', "", "ns.Journal.Names = {"]
    for field, names in (("npcs", entities["npc"]), ("objects", entities["object"]), ("factions", factions),
                         ("titles", titles)):
        lines.append(f"    {field} = {{")
        lines += [f"        [{key}] = {ascii_string(names[key])}," for key in sorted(names)]
        lines.append("    },")
    for field, names in (("places", places), ("subzones", subzones)):
        lines.append(f"    {field} = {{")
        lines += [f"        [{ascii_string(key)}] = {ascii_string(names[key])}," for key in sorted(names)]
        lines.append("    },")
    lines.append("}")
    return lines


def main():
    entities, factions, english_titles = journal_entities(), journal_factions(), boss_titles()
    wanted_places, wanted_subzones = english_places(), journal_subzones()
    english_areas, english_subzones = wago.table("AreaTable"), wago.table("WMOAreaTable")
    for locale, (code, title) in LANGUAGES.items():
        translated = {"npc": {}, "object": {}}
        for (kind, entity), english in entities.items():
            name = wowhead_name(code, kind, entity)
            if name and name != english:
                translated[kind][entity] = name
        faction_names = {int(row["ID"]): row["Name_lang"] for row in wago.table("Faction", locale=locale)}
        translated_factions = {faction: faction_names[faction] for faction, english in factions.items()
                               if faction_names.get(faction) and faction_names[faction] != english}
        titles = title_names(english_titles, code)
        places = place_names(wanted_places, english_areas, locale)
        subzones = subzone_names(wanted_subzones, english_subzones, locale)
        write(NAMES / f"{locale}.lua",
              names_file(locale, title, translated, translated_factions, titles, places, subzones))
        save_cache()
        print(f"{locale}: {len(translated['npc'])} NPCs, {len(translated['object'])} chests, "
              f"{len(translated_factions)} factions, {len(titles)} titles, {len(places)} places, "
              f"{len(subzones)} subzones", file=sys.stderr)


if __name__ == "__main__":
    main()
