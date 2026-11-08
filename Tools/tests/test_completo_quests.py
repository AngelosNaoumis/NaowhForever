"""Tests for Tools/build/completo_quests.py's hand-kept corrections (Tools/data/completo_fixes.json):
a quest's add joins the quests before it, its drop leaves them and its explicit groups, a fix naming
a quest the data lacks is skipped with a warning, an add or drop that changes nothing is warned of,
and a key starting with _ is a note; how it mends the race masks: a quest for both sides that names
only the High Order Skyborne is both Skyborne's, and other masks stay as given; where ForeverChanges
and the catalog agree: a class, level or side both give is taken, one alone is not, nor what both
write for a value they lack (side 3, level 0), and the build takes them for the quests ForeverChanges
lists, in the zone it files them under, before it writes their rows, reporting the ones Quests.lua did
not have yet; a class narrowed by the catalog's class or ForeverChanges' class quest sort, and races by
the catalog's race mask, one sharing none with it passed over, and written that way; a quest
ForeverChanges does not list kept when the fixes name it, warned of once it lists it; holiday and world
event quests left out, by their quest sort or the fixes; the gating it writes: a quest's versions the
game counts as one (one name, one completion bit), the camping quests of one name and the hand-kept
groups are exclusive, a quest in one group at most, and the breadcrumbs, professions and camp recipes
come from the fixes, an entry naming a quest the data lacks skipped with a warning; the catalog's
prerequisites where none are known, a version joining an explicit group; the catalog's gates
(reputation, skill rank, level, breadcrumbs, the quests that close one), a quest not waiting for its
breadcrumb; ForeverChanges' giver left out where its record is the other side's; and the race fixes.
Offline. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402
import completo_quests  # noqa: E402


class Corrected(unittest.TestCase):
    def setUp(self):
        self.known = {i: (40, {"name": str(i)})
                      for i in (19, 20, 98386, 98387, 92744, 92742, 94013, 94979, 94978, 94007)}

    def corrected(self, before, requires, fixes):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            out = completo_quests.corrected(before, requires, fixes, self.known)
        return out, err.getvalue()

    def test_add_and_drop(self):
        before = {19: [20, 98386, 98387]}
        fixes = {"19": {"drop": [98386]}, "92744": {"add": [92742]}}
        (after, _), warnings = self.corrected(before, {}, fixes)
        self.assertEqual(after, {19: [20, 98387], 92744: [92742]})
        self.assertEqual(before, {19: [20, 98386, 98387]})
        self.assertEqual(warnings, "")

    def test_drop_leaves_explicit_groups(self):
        before = {94013: [94007, 94978, 94979]}
        requires = {"94013": {"quests": [94979, 94007, 94978], "groups": [94979, [94007, 94978]]}}
        (after, fixed), warnings = self.corrected(before, requires, {"94013": {"drop": [94979, 94978]}})
        self.assertEqual(after, {94013: [94007]})
        self.assertEqual(fixed["94013"]["groups"], [94007])
        self.assertEqual(requires["94013"]["groups"], [94979, [94007, 94978]])
        self.assertEqual(completo_quests.requirements(after, self.known, fixed)[94013], [94007])
        self.assertEqual(warnings, "")

    def test_a_quest_left_with_nothing_has_no_requirement(self):
        (after, _), _ = self.corrected({19: [98386]}, {}, {"19": {"drop": [98386]}})
        self.assertEqual(after, {})

    def test_unknown_quest_warns_and_skips(self):
        fixes = {"1": {"add": [20]}, "19": {"add": [98387, 2]}, "92744": {"drop": [3]}}
        (after, _), warnings = self.corrected({19: [20]}, {}, fixes)
        self.assertEqual(after, {19: [20]})
        lines = warnings.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn("requires 1 names quest 1,", lines[0])
        self.assertIn("requires 19 names quest 2,", lines[1])
        self.assertIn("requires 92744 names quest 3,", lines[2])
        self.assertTrue(all(line.endswith("skipped") for line in lines))

    def test_add_present_or_drop_absent_warns(self):
        (after, _), warnings = self.corrected({19: [20, 98386]}, {}, {"19": {"add": [20, 98387], "drop": [92742]}})
        self.assertEqual(after, {19: [20, 98386, 98387]})
        self.assertIn("requires 19 adds 20, which it needs already", warnings)
        self.assertIn("requires 19 drops 92742, which it does not need", warnings)

    def test_notes_are_ignored(self):
        (after, _), warnings = self.corrected({19: [20, 98386]}, {}, {"_note": "x", "19": {"drop": [98386]}})
        self.assertEqual(after, {19: [20]})
        self.assertEqual(warnings, "")


class Races(unittest.TestCase):
    ALLIANCE_BUT_HUMAN, TAUREN = 4294967372, 1 << 5

    def test_both_skyborne(self):
        both = completo_quests.HIGH_ORDER | completo_quests.WINDSHAPER
        self.assertEqual(completo_quests.races(completo_quests.HIGH_ORDER, 3), both)
        self.assertEqual(completo_quests.races(completo_quests.HIGH_ORDER, 1), completo_quests.HIGH_ORDER)

    def test_other_masks_stay_as_the_sources_give_them(self):
        self.assertEqual(completo_quests.races(self.ALLIANCE_BUT_HUMAN, 1), self.ALLIANCE_BUT_HUMAN)
        self.assertEqual(completo_quests.races(self.TAUREN, 2), self.TAUREN)
        self.assertEqual(completo_quests.races(0, 1), 0)


class Agreed(unittest.TestCase):
    # Armaments of War, Warrior's: the zone page gives it no class.
    OURS = {"id": 8316, "name": "Armaments of War", "level": 60, "reqlevel": 58, "side": 3, "reqclass": 0}

    def test_what_both_say_is_taken(self):
        listed = {"quests": {"8316": {"level": 60, "reqlevel": 58, "side": 3, "reqclass": 1}}}
        catalog = {"8316": {"level": 60, "reqlevel": 58, "side": 3, "reqclass": 1}}
        self.assertEqual(completo_quests.agreed(self.OURS, listed, catalog), dict(self.OURS, reqclass=1))

    def test_one_source_alone_is_not(self):
        listed = {"quests": {"8316": {"level": 59, "reqlevel": 50, "side": 3, "reqclass": 1}}}
        catalog = {"8316": {"level": 60, "reqlevel": 55, "side": 3, "reqclass": 0}}
        self.assertEqual(completo_quests.agreed(self.OURS, listed, catalog), self.OURS)
        self.assertEqual(completo_quests.agreed(self.OURS, listed, {}), self.OURS)

    def test_what_both_write_for_a_missing_value_is_not(self):
        # Crocs of the Sky: the Alliance's giver, no race mask, so both sources say both sides.
        ours = {"id": 98072, "name": "Crocs of the Sky", "level": 27, "reqlevel": 19, "side": 1, "reqclass": 4}
        missing = {"level": 0, "reqlevel": 0, "side": 3, "reqclass": 0}
        self.assertEqual(completo_quests.agreed(ours, {"quests": {"98072": missing}}, {"98072": missing}), ours)


class AgreedWritten(unittest.TestCase):
    def write(self):
        quests = {
            98072: {"name": "Crocs of the Sky", "level": 27, "reqlevel": 19, "side": 1, "reqclass": 0},
            8316: {"name": "Armaments of War", "level": 60, "reqlevel": 58, "side": 3, "reqclass": 0},
            1: {"name": "Not Listed", "level": 10, "reqlevel": 5, "side": 1, "reqclass": 0},
        }
        zones = {"11": {"name": "Wetlands", "quests": [dict(q, id=i) for i, q in quests.items()]},
                 "40": {"name": "Westfall", "quests": []}}
        listed = {"quests": {"98072": dict(quests[98072], side=3, category=["zone", 11]),
                             "8316": dict(quests[8316], side=2, reqclass=1, category=["zone", 40])},
                  "starts": {}}
        catalog = {"98072": dict(quests[98072], side=3, zone=11, zone_name="Wetlands", start=None, repeatable=False,
                                  source_fields={}),
                   "8316": dict(quests[8316], side=2, reqclass=1, zone=11, zone_name="Wetlands", start=None,
                                repeatable=False, source_fields={})}
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()):
                taken = completo_quests.write(zones, {}, {}, {}, {}, {}, catalog, listed, {})
            return taken, out.read_text(), completo_quests.shipped(out)

    def test_taken_after_the_move_and_before_the_rows(self):
        taken, text, rows = self.write()
        self.assertIn('name = "Westfall", continent = 0, quests = { 8316 }', text)
        self.assertIn('    [8316] = { "Armaments of War", 60, 58, 2, 0, 1,', text)
        self.assertIn('    [98072] = { "Crocs of the Sky", 27, 19, 1, 0, 0,', text)
        self.assertNotIn("Not Listed", text)
        self.assertEqual(taken, [(8316, "Armaments of War", "reqclass", 0, 1), (8316, "Armaments of War", "side", 3, 2)])
        self.assertEqual(rows[8316], {"level": 60, "reqlevel": 58, "side": 2, "reqclass": 1})

    def test_report_names_what_is_new(self):
        taken, _, rows = self.write()
        self.assertIn("2 values are theirs instead of ours, 0 of them new.", completo_quests.taken_report(taken, rows))
        before = {8316: dict(rows[8316], side=3)}
        report = completo_quests.taken_report(taken, before)
        self.assertIn("2 values are theirs instead of ours, 1 of them new.", report)
        self.assertIn("- Armaments of War (8316): side 3 to 2", report)


class Narrowed(unittest.TestCase):
    SHAMAN, DRUID, ROGUE, HUNTER = 64, 1024, 8, 4
    ALLIANCE, HORDE = completo_quests.SIDE_RACES[1], completo_quests.SIDE_RACES[2]

    def quest(self, qid, reqclass):
        return {"id": qid, "name": "Call of Earth", "level": 4, "reqlevel": 3, "side": 2, "reqclass": reqclass}

    def test_the_catalog_names_the_class_the_zone_page_lacks(self):
        catalog = {"92466": {"reqclass": self.SHAMAN}}
        self.assertEqual(completo_quests.narrowed(self.quest(92466, 0), {}, catalog)["reqclass"], self.SHAMAN)

    def test_a_broader_class_is_cut_to_the_shared_one(self):
        catalog = {"92468": {"reqclass": self.SHAMAN}}
        quest = self.quest(92468, self.SHAMAN | self.DRUID)
        self.assertEqual(completo_quests.narrowed(quest, {}, catalog)["reqclass"], self.SHAMAN)

    def test_a_class_quest_sort_names_the_class(self):
        # The Horn of Xelthos: ForeverChanges files it under the rogues' quest sort, the catalog gives no class.
        listed = {"quests": {"78261": {"category": ["sort", 162]}}}
        quest = self.quest(78261, 0)
        self.assertEqual(completo_quests.narrowed(quest, listed, {"78261": {"reqclass": 0}})["reqclass"], self.ROGUE)

    def test_other_sorts_and_zones_name_none(self):
        quest = self.quest(96057, 0)
        for category in (["sort", 666], ["zone", 1537], None):
            listed = {"quests": {"96057": {"category": category, "reqclass": 400}}}
            self.assertIs(completo_quests.narrowed(quest, listed, {}), quest)

    def test_a_source_sharing_no_class_is_passed_over(self):
        # A Scribbled Letter: Hunter's on Wowhead and in the catalog, Warrior's on ForeverChanges.
        listed = {"quests": {"92479": {"category": ["sort", 81]}}}
        quest = self.quest(92479, self.HUNTER)
        self.assertIs(completo_quests.narrowed(quest, listed, {"92479": {"reqclass": self.HUNTER}}), quest)

    def test_the_catalog_names_the_races(self):
        # Rise and Be Recognized: both sides' on Wowhead, the Frostwolf's in the catalog.
        quest = dict(self.quest(7163, 0), side=3, reqrace=0)
        self.assertEqual(completo_quests.narrowed(quest, {}, {"7163": {"reqrace": self.HORDE}})["reqrace"], self.HORDE)
        # Desperate Prayer: the Humans' and Dwarves' on Wowhead, the Dwarves' alone in the catalog.
        quest = dict(self.quest(5634, 0), side=1, reqrace=5)
        self.assertEqual(completo_quests.narrowed(quest, {}, {"5634": {"reqrace": 4}})["reqrace"], 4)

    def test_races_the_side_gives_already_or_none_of_them_are_passed_over(self):
        quest = dict(self.quest(92466, 0), side=2, reqrace=0)
        self.assertIs(completo_quests.narrowed(quest, {}, {"92466": {"reqrace": self.HORDE}}), quest)
        self.assertIs(completo_quests.narrowed(quest, {}, {"92466": {"reqrace": self.ALLIANCE}}), quest)

    def test_written(self):
        quests = {92466: self.quest(92466, 0), 78261: dict(self.quest(78261, 0), name="The Horn of Xelthos")}
        zones = {"16593": {"name": "Zephras Isle", "quests": list(quests.values())}}
        listed = {"quests": {"92466": dict(quests[92466], category=["zone", 16593]),
                             "78261": dict(quests[78261], category=["sort", 162])}, "starts": {}}
        catalog = {"92466": dict(quests[92466], reqclass=self.SHAMAN, zone=16593, zone_name="Zephras Isle",
                                 start=None, repeatable=False, source_fields={})}
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()):
                taken = completo_quests.write(zones, {}, {}, {}, {}, {}, catalog, listed, {})
            rows = completo_quests.shipped(out)
        self.assertEqual(rows[92466]["reqclass"], self.SHAMAN)
        self.assertEqual(rows[78261]["reqclass"], self.ROGUE)
        self.assertEqual(taken, [])


class Unlisted(unittest.TestCase):
    def test_kept_though_the_list_leaves_it_out(self):
        zones = {"16591": {"name": "Riverglades", "quests": [
            {"id": 94532, "name": "Gnoll Infestation", "level": 38, "reqlevel": 36, "side": 2},
            {"id": 95161, "name": "Remember That I Love You", "level": 22, "reqlevel": 15, "side": 1},
            {"id": 8, "name": "Not Listed", "level": 2, "reqlevel": 1, "side": 1}]}}
        listed = {"quests": {"95161": {"name": "Remember That I Love You", "level": 22, "reqlevel": 15, "side": 1,
                                       "reqclass": 0, "category": ["zone", 16591]}}, "starts": {}}
        fixes = {"unlisted": [{"quests": [94532, 95161]}, {"quests": [1]}]}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, {}, {}, {}, {}, {}, listed, fixes)
            text = out.read_text()
        self.assertIn('map = 2548, name = "Riverglades", continent = 0, quests = { 94532, 95161 }', text)
        self.assertIn('    [94532] = { "Gnoll Infestation", 38, 36, 2, 0, 0, nil, nil, nil, nil },', text)
        self.assertNotIn("Not Listed", text)
        self.assertIn("unlisted [1] names quest 1, which the data does not have; skipped", err.getvalue())
        self.assertIn("unlisted names quest 95161, which ForeverChanges lists already", err.getvalue())


class Events(unittest.TestCase):
    SIGNET = {"name": "One Commendation Signet", "level": 60, "reqlevel": 1, "side": 2, "reqclass": 0}

    def write(self, fixes):
        listed = {"quests": {"8815": dict(self.SIGNET, category=["sort", 367]),
                             "6961": dict(self.SIGNET, name="Great-father Winter is Here!", category=["sort", 22])},
                  "starts": {}}
        elsewhere = {"8815": dict(self.SIGNET, reqrace=0, after=[], map=1454, x=30.8, y=73.7,
                                  giver="Orgrimmar Commendation Officer", dungeon=False, battleground=False)}
        zones = {"1637": {"name": "Orgrimmar", "quests": []}}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, {}, {}, {}, elsewhere, {}, listed, fixes)
            return out.read_text(), err.getvalue()

    def test_an_elsewhere_quest_is_left_out_too(self):
        text, _ = self.write({})
        self.assertIn("    [8815] = true,", text)
        text, err = self.write({"events": [{"quests": [8815]}]})
        self.assertNotIn("8815", text)
        self.assertEqual(err, "")

    def test_an_entry_the_data_lacks_or_the_sort_has_warns(self):
        text, err = self.write({"events": [{"quests": [8815, 1]}, {"quests": [6961]}]})
        self.assertIn("[8815] = true,", text)
        self.assertIn("events [8815, 1] names quest 1, which the data does not have; skipped", err)
        self.assertIn("events names quest 6961, which ForeverChanges files under an event's sort already", err)

    def test_holiday_and_event_quests_left_out(self):
        winter = {"name": "Great-father Winter is Here!", "level": 60, "reqlevel": 10, "reqclass": 0}
        zones = {"1637": {"name": "Orgrimmar", "quests": [
            dict(winter, id=6961, side=3),
            {"id": 172, "name": "Children's Week", "level": 60, "reqlevel": 10, "side": 2},
            {"id": 3861, "name": "CLUCK!", "level": 1, "reqlevel": 1, "side": 1},
            {"id": 936, "name": "Assisting Arch Druid Runetotem", "level": 50, "reqlevel": 47, "side": 2}]}}
        listed = {"quests": {
            "6961": dict(winter, side=2, category=["sort", 22]),
            "172": {"name": "Children's Week", "level": 60, "reqlevel": 10, "side": 2, "reqclass": 0,
                    "category": ["sort", 284]},
            "3861": {"name": "CLUCK!", "level": 1, "reqlevel": 1, "side": 1, "reqclass": 0, "category": ["sort", 284]},
            "936": {"name": "Assisting Arch Druid Runetotem", "level": 50, "reqlevel": 47, "side": 2, "reqclass": 0,
                    "category": ["zone", 1637]},
            "8677": {"name": "Darkhorn the Elder", "level": 60, "reqlevel": 1, "side": 3, "reqclass": 0,
                     "category": ["sort", 366]}},
            "starts": {"8677": [[1454, 41.1, 33.8, "Elder Darkhorn"]]}}
        catalog = {"6961": dict(winter, side=2, zone=1637, zone_name="Orgrimmar", start=None, repeatable=False,
                                 source_fields={})}
        fixes = {"events": [{"quests": [172]}]}
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()):
                taken = completo_quests.write(zones, {}, {}, {}, {}, {}, catalog, listed, fixes)
            text = out.read_text()
        self.assertIn('name = "Orgrimmar", continent = 0, quests = { 936, 3861 } }', text)
        for name in ("Great-father Winter", "Children's Week", "Darkhorn the Elder"):
            self.assertNotIn(name, text)
        self.assertEqual(taken, [])


class Gating(unittest.TestCase):
    CAMP = {"category": ["sort", 666]}

    def rows(self):
        names = {95998: "The Great Outdoors", 96608: "The Great Outdoors", 96627: "The Adventurer",
                 97915: "Camping 101: Alchemy", 96045: "Camping 101: Alchemy", 324: "The Lost Ingots",
                 526: "Lightforge Ingots", 19: "Tharil'zun"}
        return {q: (12, {"id": q, "name": n, "level": 6, "reqlevel": 4, "side": 1}) for q, n in names.items()}

    def listed(self):
        return {"quests": {str(q): dict(self.CAMP) for q in (95998, 96608, 96627, 97915, 96045)}}

    def test_camping_quests_of_one_name_and_the_fixes(self):
        groups = completo_quests.exclusive_groups(self.rows(), self.listed(), [{"quests": [526, 324]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])

    def test_only_the_camping_sort(self):
        listed = {"quests": {"95998": {"category": ["zone", 12]}, "96608": dict(self.CAMP)}}
        self.assertEqual(completo_quests.exclusive_groups(self.rows(), listed, []), [])

    def test_versions_the_game_counts_as_one(self):
        rows = {q: (12, {"id": q, "name": n}) for q, n in (
            (94773, "Divine Grace"), (94774, "Divine Grace"), (94780, "Divine Grace"), (3911, "The Last Element"),
            (4641, "Your Place in the World"), (95998, "The Great Outdoors"), (96608, "The Great Outdoors"))}
        bits = {"68258": [94773, 94774, 94999], "1330": [3911, 4641], "999": [95998, 96608]}
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            groups = completo_quests.exclusive_groups(rows, self.listed(), [{"quests": [95998, 96608]}], bits)
        self.assertEqual(groups, [[94773, 94774], [95998, 96608]])
        self.assertIn("exclusive [95998, 96608] names quest 95998, 96608, which is in a group already; skipped",
                      err.getvalue())

    def test_shared_bits(self):
        rows = [{"ID": "1", "UniqueBitFlag": "5"}, {"ID": "2", "UniqueBitFlag": "5"}, {"ID": "3", "UniqueBitFlag": "6"}]
        self.assertEqual(completo_quests.shared_bits(rows), {"5": [1, 2]})

    def exclusive_groups(self, fixes):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            groups = completo_quests.exclusive_groups(self.rows(), self.listed(), fixes)
        return groups, err.getvalue()

    def test_unknown_quest_warns_and_skips(self):
        groups, warnings = self.exclusive_groups([{"quests": [1, 324]}, {"quests": [526, 324]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])
        self.assertIn("exclusive [1, 324] names quest 1, which the data does not have; skipped", warnings)

    def test_a_quest_in_two_groups_warns_and_skips(self):
        groups, warnings = self.exclusive_groups([{"quests": [324, 526]}, {"quests": [526, 19]}, {"quests": [19, 95998]}])
        self.assertEqual(groups, [[324, 526], [95998, 96608], [96045, 97915]])
        self.assertIn("exclusive [19, 526] names quest 526, which is in a group already; skipped", warnings)
        self.assertIn("exclusive [19, 95998] names quest 95998, which is in a group already; skipped", warnings)

    def test_written(self):
        zones = {"12": {"name": "Elwynn Forest", "quests": [q for _, q in self.rows().values()]}}
        fixes = {"breadcrumbs": {"_note": "x", "96627": {"to": 95998}, "96628": {"to": 1}},
                 "professions": [{"skill": 171, "recipe": 1230564, "quests": [97915, 96045]},
                                 {"skill": 393, "quests": [19]}, {"skill": 164, "quests": [19, 2]}]}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, {}, {}, {}, {}, {}, None, fixes)
            text = out.read_text()
        self.assertIn("D.Breadcrumb = {\n    [96627] = 95998,\n}", text)
        self.assertIn("    [97915] = 171,\n", text)
        self.assertIn("    [19] = 393,\n", text)
        self.assertIn("D.Recipe = {\n    [96045] = 1230564,\n    [97915] = 1230564,\n}", text)
        self.assertIn("breadcrumbs 96628 names quest 96628, 1, which the data does not have; skipped", err.getvalue())
        self.assertIn("professions 164 names quest 2, which the data does not have; skipped", err.getvalue())


class CatalogGates(unittest.TestCase):
    def record(self, qid, side=2, start=None, **fields):
        return {"name": f"Quest {qid}", "level": 10, "reqlevel": 5, "side": side, "reqrace": 0, "reqclass": 0,
                "zone": 1637, "zone_name": "Orgrimmar", "start": start, "repeatable": False, "source_fields": fields}

    def test_prerequisites_where_none_are_known(self):
        catalog = {"46": self.record(46, preQuestSingle={"1": 39}), "990": self.record(990, preQuestSingle=[994, 995]),
                   "7795": self.record(7795, preQuestGroup={"1": 7791, "2": 7793}),
                   "1516": self.record(1516, preQuestSingle=[1516, 1519]),
                   "4964": self.record(4964, preQuestGroup=[4976, -4962]), "143": self.record(143, preQuestSingle=[121])}
        requires = completo_quests.catalog_requires({"46": None, "143": {"quests": [120]}}, catalog)
        self.assertEqual(requires["46"], {"quests": [39]})
        self.assertEqual(requires["990"], {"quests": [994, 995], "groups": [[994, 995]]})
        self.assertEqual(requires["7795"], {"quests": [7791, 7793]})
        self.assertEqual(requires["143"], {"quests": [120]})
        self.assertNotIn("1516", requires)
        self.assertNotIn("4964", requires)

    def test_another_version_joins_an_explicit_group(self):
        # Rabine Saturna: the catalog names three of The New Frontier's versions, its Series a fourth.
        known = {q: (17, {"name": "The New Frontier"}) for q in (1000, 1004, 1018, 6761)}
        requires = {"1123": {"quests": [1000, 1004, 1018], "groups": [[1000, 1004, 1018]]}}
        out = completo_quests.requirements({1123: [1000, 1004, 1018, 6761]}, known, requires)
        self.assertEqual(out[1123], [[1000, 1004, 1018, 6761]])

    def write(self, sides, catalog, listed=None, fixes=None, requires=None):
        zones = {"1637": {"name": "Orgrimmar", "quests": [
            {"id": q, "name": f"Quest {q}", "level": 10, "reqlevel": 5, "side": side} for q, side in sides.items()]}}
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "Quests.lua"
            with mock.patch.object(completo_quests, "ROOT", Path(folder)), mock.patch.object(completo_quests, "OUT", out), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                completo_quests.write(zones, {}, requires or {}, {}, {}, {}, catalog, listed, fixes or {})
            return out.read_text(), err.getvalue()

    def test_written(self):
        record = self.record
        catalog = {"1369": record(1369, requiredMinRep={"1": 93, "2": 3000}),
                   "1036": record(1036, requiredMaxRep={"1": 21, "2": -6000}),
                   "8368": record(8368, requiredMaxLevel=19), "3526": record(3526, requiredSkill={"1": 202, "2": 200}),
                   "163": record(163, breadcrumbForQuestId=5), "1462": record(1462, availableUntilCompleted=1521),
                   "808": record(808, disabledByQuest=805),
                   "5627": record(5627, preQuestSingle=[5628, 5629], exclusiveTo=[5628, 5629]),
                   "860": record(860, breadcrumbForQuestId=844)}
        ids = (1369, 1036, 8368, 3526, 163, 5, 1462, 1521, 805, 808, 5627, 5628, 5629, 860, 844)
        text, _ = self.write({q: 2 for q in ids}, catalog, requires={"844": {"quests": [860]}})
        self.assertIn("D.MinReputation = {\n    [1369] = { 93, 3000 },\n}", text)
        self.assertIn("D.MaxReputation = {\n    [1036] = { 21, -6000 },\n}", text)
        self.assertIn("D.MaxLevel = {\n    [8368] = 19,\n}", text)
        self.assertIn("D.Profession = {\n    [3526] = 202,\n}", text)
        self.assertIn("D.SkillRank = {\n    [3526] = 200,\n}", text)
        self.assertIn("D.Until = {\n    [1462] = 1521,\n}", text)
        self.assertIn("D.Breadcrumb = {\n    [163] = 5,\n    [860] = 844,\n}", text)
        # disabledByQuest names the breadcrumb the quest closes; Stars of Elune needs what it is exclusive to.
        self.assertIn("D.ClosedBy = {\n    [805] = { 808 },\n}", text)
        self.assertIn("    [5627] = { { 5628, 5629 } },\n", text)
        # Plainstrider Menace does not wait for Sergra Darkthorn, which only sends you to its giver.
        self.assertNotIn("    [844] = { 860 },", text)

    def test_a_swapped_giver_and_the_race_fixes(self):
        # A Lesson to Learn: ForeverChanges has the Horde version's side and giver, Wowhead and the catalog
        # the Alliance's. In Search of Menara Voidrender: every source but the catalog on the wrong side.
        darnassus = {"coord": [35.37, 8.4], "coordinate_space": "forever", "npc": "Mathrengyl Bearwalker", "zone": 1657}
        catalog = {"26": self.record(26, side=1, start=darnassus), "4736": self.record(4736, side=1)}
        listed = {"quests": {"26": {"name": "Quest 26", "side": 2, "category": ["zone", 1637]},
                             "4736": {"name": "Quest 4736", "side": 2, "category": ["zone", 1637]}},
                  "starts": {"26": [[1456, 76.5, 27.2, "Turak Runetotem"]], "4736": [[1454, 50.0, 50.0, "Briarthorn"]]}}
        fixes = {"races": [{"quests": [4736], "side": 1}, {"quests": [26], "side": 1}]}
        text, err = self.write({26: 1, 4736: 2}, catalog, listed, fixes)
        self.assertIn('    [26] = { "Quest 26", 10, 5, 1, 0, 0, 1457, 35.4, 8.4, "Mathrengyl Bearwalker" },', text)
        self.assertIn('    [4736] = { "Quest 4736", 10, 5, 1, 0, 0, 1454, 50.0, 50.0, "Briarthorn" },', text)
        self.assertIn("races names quest 26, which the sources give that already", err)


class FixesFile(unittest.TestCase):
    def test_every_fix_says_why(self):
        fixes = json.loads((paths.DATA / "completo_fixes.json").read_text(encoding="utf-8"))
        for qid, fix in fixes["requires"].items():
            if qid.startswith("_"):
                continue
            self.assertTrue(fix.get("why"), qid)
            self.assertTrue(fix.get("add") or fix.get("drop"), qid)
        breadcrumbs = [b for k, b in fixes["breadcrumbs"].items() if not k.startswith("_")]
        for entry in fixes["exclusive"] + breadcrumbs + fixes["professions"] + fixes["unlisted"] + fixes["events"] \
                + fixes["races"]:
            self.assertTrue(entry.get("why"), entry)


if __name__ == "__main__":
    unittest.main()
