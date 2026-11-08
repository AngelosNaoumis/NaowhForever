"""Offline checks for the lockbox Lockpicking data generator."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import lockboxes  # noqa: E402

ORNATE_BRONZE, REINFORCED_STEEL, FAMILY_JEWELS = 4632, 4638, 12033
TEST_STRONGBOX, SUPER_STRONG, ROGUES_DIARY, THIEVEN_KIT = 3746, 241233, 24282, 7868
ENTRY = re.compile(r"^    \[(\d+)\] = (\d+),$")


def lock(lock_id, *entries):
    row = {"ID": str(lock_id)}
    for i in range(lockboxes.SLOTS):
        kind, index, skill = entries[i] if i < len(entries) else (0, 0, 0)
        row[f"Type_{i}"], row[f"_Index_{i}"], row[f"Skill_{i}"] = str(kind), str(index), str(skill)
    return row


def item(item_id, lock_id, flags=4):
    return {"ID": str(item_id), "LockID": str(lock_id), "Flags_0": str(flags)}


LOCKS = [
    lock(5, (2, 1, 1), (2, 5, 0), (2, 6, 0)),
    lock(62, (2, 1, 225), (2, 5, 0)),
    lock(319, (1, 7208, 0), (2, 1, 1)),
    lock(57, (2, 5, 0), (2, 6, 0)),
    lock(1620, (2, 1, 5000)),
    lock(4050, (2, 1, 305)),
]


class LockboxTests(unittest.TestCase):
    def test_a_pick_lock_entry_is_found_in_any_slot(self):
        self.assertEqual({5: 1, 62: 225, 319: 1, 1620: 5000, 4050: 305}, lockboxes.pick_skills(LOCKS))

    def test_only_pickable_items_a_rogue_can_reach_are_kept(self):
        items = [
            item(10, 5), item(11, 62), item(12, 319, flags=0),
            item(20, 57), item(21, 0), item(22, ""),
            item(30, 5, flags=0x14), item(31, 1620, flags=0), item(32, 4050),
        ]
        self.assertEqual({10: 1, 11: 225, 12: 1}, lockboxes.lockboxes(items, LOCKS))

    def test_a_lock_at_the_top_skill_is_kept(self):
        self.assertEqual({10: 300}, lockboxes.lockboxes([item(10, 9)], [lock(9, (2, 1, 300))]))

    def test_renders_sorted_crlf_lua(self):
        text = lockboxes.render({20: 70, 10: 1}, "1.60.1.1")
        self.assertTrue(text.startswith("-- LockboxData.lua: "))
        self.assertIn("from build 1.60.1.1.\r\n", text)
        self.assertIn("ns.LockboxSkills = {\r\n    [10] = 1,\r\n    [20] = 70,\r\n}\r\n", text)
        self.assertNotIn("\n", text.replace("\r\n", ""))

    def test_checked_in_data_follows_the_rule(self):
        raw = lockboxes.OUT.read_bytes()
        self.assertEqual(raw.count(b"\n"), raw.count(b"\r\n"))
        self.assertTrue(raw.isascii())
        found = {}
        for line in raw.decode("ascii").split("\r\n"):
            m = ENTRY.match(line)
            if m:
                found[int(m[1])] = int(m[2])
        self.assertEqual(1, found[ORNATE_BRONZE])
        self.assertEqual(225, found[REINFORCED_STEEL])
        self.assertEqual(275, found[FAMILY_JEWELS])
        for left_out in (TEST_STRONGBOX, SUPER_STRONG, ROGUES_DIARY, THIEVEN_KIT):
            self.assertNotIn(left_out, found)
        self.assertTrue(all(1 <= skill <= lockboxes.TOP_SKILL for skill in found.values()))


if __name__ == "__main__":
    unittest.main()
