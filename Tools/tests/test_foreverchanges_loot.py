"""Tests for Tools/build/foreverchanges_loot.py: reading the drops ForeverChanges' players have seen
out of a dungeon page, whose data comes in pushed string chunks, and what changed since the file
was written. Offline, made-up pages. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import foreverchanges_loot as fc  # noqa: E402

DUNGEON = ('2:["$","$L9",null,{"bosses":[{"name":"Commander Springvale","kind":"boss","display":3223,"items":['
           '{"i":273643,"n":"Worgenbane Talisman","t":"new","w":1},'
           '{"i":6320,"n":"Commander\'s Crest","t":"changed","w":1},'
           '{"i":273105,"n":"Blueprint: Toxin Study","t":"new"}]},'
           '{"name":"Trash mobs","kind":"trash","display":0,"items":['
           '{"i":5943,"n":"Rift Bracers","t":"changed","w":1}]}]}]\n'
           '3:["$","p",null,{"className":"it-foot","children":["","Drops seen in game are as of 2026-10-03. '
           'Other items are read from the game clients through wago.tools."]}]\n')


def push(text):
    return f"<script>self.__next_f.push([1,{json.dumps(text)}])</script>"


def page(name, bosses, seen="2026-10-03"):
    return {"name": name, "seen": seen, "bosses": [
        {"name": boss, "kind": "boss", "items": [{"id": i, "name": n} for i, n in items]}
        for boss, items in bosses.items()]}


class Parse(unittest.TestCase):
    def test_a_classic_dungeon_takes_only_new_items_seen(self):
        found = fc.parse(push(DUNGEON[:80]) + push(DUNGEON[80:]), new_dungeon=False)
        self.assertEqual(found, {"seen": "2026-10-03", "bosses": [
            {"name": "Commander Springvale", "kind": "boss",
             "items": [{"id": 273643, "name": "Worgenbane Talisman"}]}]},
            "who drops a Classic item there is Classic's; the blueprint is not seen yet")

    def test_a_new_dungeon_takes_every_drop_seen(self):
        found = fc.parse(push(DUNGEON), new_dungeon=True)
        self.assertEqual([(b["kind"], [i["id"] for i in b["items"]]) for b in found["bosses"]],
                         [("boss", [273643, 6320]), ("trash", [5943])])

    def test_a_page_with_no_bosses_yet(self):
        self.assertEqual(fc.parse(push('1:["$","div",null,{}]\n'), new_dungeon=True), {"seen": None, "bosses": []})


OLD = {"shadowfang-keep": page("Shadowfang Keep", {"Commander Springvale": [(273643, "Worgenbane Talisman")]})}


class Changes(unittest.TestCase):
    def test_a_new_date_alone_is_no_change(self):
        new = copy.deepcopy(OLD)
        new["shadowfang-keep"]["seen"] = "2026-11-10"
        self.assertEqual(fc.changes(OLD, new), [("New", []), ("Gone", [])])

    def test_a_drop_seen_and_one_no_longer_listed(self):
        new = {"shadowfang-keep": page("Shadowfang Keep", {"Odo the Blindwatcher": [(273645, "Blindwatcher's Sight")]})}
        found = fc.changes(OLD, new)
        self.assertEqual(found, [
            ("New", ["- Shadowfang Keep / Odo the Blindwatcher: Blindwatcher's Sight (273645)"]),
            ("Gone", ["- Shadowfang Keep / Commander Springvale: Worgenbane Talisman (273643)"])])
        text = fc.report(new, found)
        self.assertIn("lists 1 drops seen in game: 1 new, 1 gone.", text)
        self.assertIn("**New:**\n\n- Shadowfang Keep / Odo the Blindwatcher", text)

    def test_a_long_list_is_counted(self):
        new = {"shadowfang-keep": page("Shadowfang Keep", {"Trash mobs": [(i, f"Item {i}") for i in range(60)]})}
        text = fc.report(new, fc.changes({}, new))
        self.assertIn(f"- and {60 - fc.REPORT_ROWS} more", text)


class Links(unittest.TestCase):
    """Every page in foreverchanges_loot.json is one a dungeon in journal_bosses.json names
    ("foreverchanges"), every page named is in it (journal.py reads it by those names), and every
    name foreverchangesNames maps to is one of that dungeon's bosses."""

    def test_every_page_is_linked_to_a_dungeon(self):
        pages = json.loads(fc.OUT.read_text(encoding="utf-8"))
        dungeons = json.loads((paths.DATA / "journal_bosses.json").read_text(encoding="utf-8"))["dungeons"]
        linked = set()
        for dungeon in dungeons:
            slugs = dungeon.get("foreverchanges") or {}
            linked.update([slugs] if isinstance(slugs, str) else slugs.values())
        self.assertEqual(sorted(set(pages) - linked), [],
                         'add "foreverchanges": "<slug>" to the dungeon in Tools/data/journal_bosses.json')
        self.assertEqual(sorted(linked - set(pages)), [], "a linked page foreverchanges_loot.json does not have")

    def test_their_names_map_to_our_bosses(self):
        for dungeon in json.loads((paths.DATA / "journal_bosses.json").read_text(encoding="utf-8"))["dungeons"]:
            ours = {b for w in dungeon["wings"] for b in w["bosses"] + w.get("rare", []) + w.get("optional", [])}
            for theirs, name in dungeon.get("foreverchangesNames", {}).items():
                self.assertIn(name, ours, f"{theirs} ({dungeon['name']})")


if __name__ == "__main__":
    unittest.main()
