"""Tests for Tools/build/leveling_bis.py: the gear window read from a page's streamed payload, a
level's seventeen slots for each side, where each item comes from, and the Lua it writes. Offline,
made-up data. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import leveling_bis as lb  # noqa: E402

SEP = " · "


def slots(**placed):
    """Seventeen entries in their order, the named positions filled."""
    out = [None] * 17
    for pos, item in placed.items():
        out[int(pos[1:])] = item
    return out


def picks():
    return {f"{level}{side}": slots(p0=level, p14=level + 1) for level in lb.LEVELS for side in "ah"}


def push(text):
    return f"<script>self.__next_f.push({json.dumps([1, text])})</script>"


class Gear(unittest.TestCase):
    def test_read_across_the_payload_chunks(self):
        data = json.dumps({"picks": {"30a": [1]}, "items": {"1": ["Helm"]}})
        page = push('2c:["$","div",' + data[:20]) + push(data[20:] + "]") + push("more")
        self.assertEqual(lb.gear(page), {"picks": {"30a": [1]}, "items": {"1": ["Helm"]}})

    def test_a_page_without_one_stops_it(self):
        with self.assertRaises(ValueError):
            lb.gear(push("nothing here"))


class Lists(unittest.TestCase):
    def test_each_level_and_side_in_inventory_slots_empty_left_out(self):
        found = lb.lists(picks())
        self.assertEqual(sorted(found), list(lb.LEVELS))
        self.assertEqual(found[30], {"Alliance": {1: 30, 16: 31}, "Horde": {1: 30, 16: 31}})

    def test_the_slot_order(self):
        found = lb.lists({**picks(), "40h": slots(p3=15, p10=11, p11=12, p13=14, p15=17, p16=18)})
        self.assertEqual(found[40]["Horde"], {15: 15, 11: 11, 12: 12, 14: 14, 17: 17, 18: 18})

    def test_a_level_of_another_length_stops_it(self):
        with self.assertRaises(ValueError):
            lb.lists({**picks(), "50a": [1, 2]})


class Source(unittest.TestCase):
    def test_each_kind(self):
        self.assertEqual(lb.source([["q", "Sweet Amber", "Westfall", "a", 53]]), "Sweet Amber" + SEP + "Quest (Alliance)")
        self.assertEqual(lb.source([["q", "Wanted", "Barrens", "h", 1]]), "Wanted" + SEP + "Quest (Horde)")
        self.assertEqual(lb.source([["q", "Both", "Duskwood", "b", 1]]), "Both" + SEP + "Quest")
        self.assertEqual(lb.source([["d", "Lady Sarevess", "Blackfathom Deeps", "b", 4831]]),
                         "Lady Sarevess" + SEP + "Blackfathom Deeps")
        self.assertEqual(lb.source([["c", "Tailoring", "", "b", 1]]), "Tailoring" + SEP + "Crafted")
        self.assertEqual(lb.source([["v", "Sergeant Ba'sha", "Orgrimmar", "h", 1]]), "Sergeant Ba'sha" + SEP + "Orgrimmar")
        self.assertEqual(lb.source([["n", "Fel Ancient", "Alterac Mountains", "b", 1]]),
                         "Fel Ancient" + SEP + "Alterac Mountains")

    def test_the_first_names_it(self):
        self.assertEqual(lb.source([["c", "Tailoring", "", "b", 1], ["q", "Later", "x", "a", 2]]),
                         "Tailoring" + SEP + "Crafted")

    def test_a_quest_on_both_sides(self):
        self.assertEqual(lb.source([["q", "Same", "x", "a", 1], ["q", "Same", "y", "h", 2]]), "Same" + SEP + "Quest")
        self.assertEqual(lb.source([["q", "Ours", "x", "a", 1], ["q", "Theirs", "y", "h", 2]]), "Quest")

    def test_a_kind_not_known_stops_it(self):
        with self.assertRaises(ValueError):
            lb.source([["x", "Who", "Where", "b", 1]])
        with self.assertRaises(ValueError):
            lb.source([["v", "Who", "", "b", 1]])


class Main(unittest.TestCase):
    def test_every_spec_of_a_page_and_an_item_with_no_source_left_unsourced(self):
        items = {str(level): ["Helm", 2, "x", level, [], [["c", "Tailoring", "", "b", 1]]] for level in lb.LEVELS}
        items.update({str(level + 1): ["Staff", 2, "x", level, [], []] for level in lb.LEVELS})
        page = push(json.dumps({"picks": picks(), "items": items}))
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(lb, "PAGES", {"druid/feral": ["feral-dps-druid", "feral-tank-druid"]}), \
                mock.patch.object(lb, "OUT", Path(tmp) / "Leveling.lua"), \
                mock.patch.object(lb.wowhead, "fetch", return_value=page) as fetch:
            lb.main()
            text = (Path(tmp) / "Leveling.lua").read_bytes().decode("ascii")
        fetch.assert_called_once_with(lb.SITE + "/druid/feral")
        self.assertIn('["feral-dps-druid"]', text)
        self.assertIn('["feral-tank-druid"]', text)
        self.assertIn('        [30] = "Tailoring \\194\\183 Crafted",', text)
        self.assertNotIn("        [31] = ", text)


class Render(unittest.TestCase):
    def test_ascii_lua_with_crlf(self):
        found = lb.lists(picks())
        text = lb.render({"arms-warrior": found}, {30: 'A "q" \\ ' + "Café" + SEP + "Quest"})
        self.assertTrue(text.isascii())
        self.assertNotIn("\n", text.replace("\r\n", ""))
        self.assertIn("ns.BiSLeveling = {", text)
        self.assertIn("    levels = { 30, 40, 50, 60 },", text)
        self.assertIn('        ["arms-warrior"] = {', text)
        self.assertIn("                Alliance = { [1] = 30, [16] = 31 },", text)
        self.assertIn('        [30] = "A \\"q\\" \\\\ Caf\\195\\169 \\194\\183 Quest",', text)


class CurrentPicks(unittest.TestCase):
    def test_a_levels_items_for_every_spec_and_side_not_its_sources(self):
        found = lb.lists({**picks(), "60h": slots(p0=60, p2=62)})
        other = lb.lists({**picks(), "60a": slots(p5=65)})
        text = lb.render({"arms-warrior": found, "fury-warrior": other}, {60: "Quest", 99: "Crafted"})
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(lb, "OUT", Path(tmp) / "Leveling.lua"):
            lb.OUT.write_text(text, encoding="utf-8", newline="")
            self.assertEqual(lb.current_picks(60), {60, 61, 62, 65})
            self.assertEqual(lb.current_picks(30), {30, 31})


if __name__ == "__main__":
    unittest.main()
