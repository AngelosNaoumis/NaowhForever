"""Tests for Tools/build/writ_requests.py: how it reads the item a Craftsman's Writ asks for.
Offline: the quests are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import writ_requests as wr  # noqa: E402

WRIT, OTHER_WRIT, FIREWATER, POTION = 264124, 264125, 246948, 6048


def quest(name, started=(WRIT,), objectives=(WRIT, FIREWATER)):
    def items(ids):
        return {"3": {str(i + 1): {"1": item} for i, item in enumerate(ids)}}
    return {"name": name, "source_fields": {"startedBy": items(started), "objectives": items(objectives)}}


def catalog(**extra):
    found = {"94100": quest("Craftsman's Writ: Distilled Firewater"),
             "1013": quest("The Book of Ur", started=(), objectives=(6283,))}
    found.update(extra)
    return found


class WritRequestsTest(unittest.TestCase):
    def test_the_requested_item_is_the_objective_that_is_not_the_writ(self):
        self.assertEqual({WRIT: FIREWATER}, wr.requests(catalog()))

    def test_the_writ_may_be_listed_after_the_requested_item(self):
        found = wr.requests({"1": quest("Craftsman's Writ: Distilled Firewater", objectives=(FIREWATER, WRIT))})
        self.assertEqual({WRIT: FIREWATER}, found)

    def test_quests_that_are_no_writ_are_left_out(self):
        self.assertEqual([WRIT], list(wr.requests(catalog())))

    def test_a_writ_no_item_starts_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wr.requests(catalog(x=quest("Craftsman's Writ: Free Action Potion", started=())))

    def test_a_writ_asking_for_two_items_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wr.requests({"1": quest("Craftsman's Writ: Distilled Firewater",
                                    objectives=(WRIT, FIREWATER, POTION))})

    def test_a_writ_asking_for_nothing_but_itself_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wr.requests({"1": quest("Craftsman's Writ: Distilled Firewater", objectives=(WRIT,))})

    def test_one_writ_starting_two_quests_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wr.requests(catalog(x=quest("Craftsman's Writ: Shadow Protection Potion",
                                        objectives=(WRIT, POTION))))

    def test_writes_each_writ_with_its_item(self):
        lines = wr.lua({OTHER_WRIT: POTION, WRIT: FIREWATER})
        self.assertTrue(lines[0].startswith("-- WritRequestsData.lua: "))
        self.assertIn("ns.WritRequests = {", lines)
        self.assertLess(lines.index(f"    [{WRIT}] = {FIREWATER},"), lines.index(f"    [{OTHER_WRIT}] = {POTION},"))
        self.assertEqual("}", lines[-1])


if __name__ == "__main__":
    unittest.main()
