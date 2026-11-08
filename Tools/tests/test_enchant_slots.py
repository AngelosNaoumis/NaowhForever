import importlib.util
import json
import sys
import unittest
from pathlib import Path


BUILD = Path(__file__).parents[1] / "build"
sys.path.insert(0, str(BUILD))
SPEC = importlib.util.spec_from_file_location("enchant_slots", BUILD / "enchant_slots.py")
enchant_slots = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(enchant_slots)

BRACER_MINOR_HEALTH = "7418"


def ability(spell, line=333):
    return {"Spell": str(spell), "SkillLine": str(line)}


def equipped(spell, item_class, inv, sub):
    return {"SpellID": str(spell), "EquippedItemClass": str(item_class), "EquippedItemInvTypes": str(inv),
            "EquippedItemSubclass": str(sub)}


class EnchantSlotsTest(unittest.TestCase):
    def test_keeps_enchanting_abilities_limited_to_gear(self):
        abilities = [ability(10), ability(20), ability(30, line=164)]
        rows = [equipped(10, 4, 512, 31), equipped(30, 2, 0, 1378), equipped(40, 4, 0, 64)]
        self.assertEqual({"10": [4, 512, 31]}, enchant_slots.read_rows(abilities, rows))

    def test_renders_sorted_by_spell(self):
        text = enchant_slots.render({"200": [2, 0, 1378], "30": [4, 65536, 0]})
        self.assertIn("    [30] = { 4, 65536, 0 },\r\n    [200] = { 2, 0, 1378 },\r\n}", text)

    def test_checked_in_slots_are_current(self):
        rows = json.loads(enchant_slots.CACHE.read_text(encoding="utf-8"))
        checked_in = enchant_slots.OUT.read_bytes().decode("utf-8")
        self.assertEqual(enchant_slots.render(rows), checked_in)
        self.assertEqual([4, 512, 31], rows[BRACER_MINOR_HEALTH])


if __name__ == "__main__":
    unittest.main()
