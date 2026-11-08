"""Tests for Tools/build/training_grimoires.py: which items are demon books, and what each one teaches.
Offline: the game's rows are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import training_grimoires as tg  # noqa: E402

WARLOCK_MASK = 31488   # the books' AllowableClass: the warlock's bit and classes Forever lacks
MAGE_MASK = 128
GENERIC = 270          # the hunter pets' shared skill line, the Imp's second

FAMILIES = [
    {"ID": "23", "Name_lang": "Imp", "SkillLine_0": "188", "SkillLine_1": str(GENERIC)},
    {"ID": "302", "Name_lang": "Incubus", "SkillLine_0": "205", "SkillLine_1": "0"},
    {"ID": "17", "Name_lang": "Succubus", "SkillLine_0": "205", "SkillLine_1": "0"},
    {"ID": "1", "Name_lang": "Wolf", "SkillLine_0": "208", "SkillLine_1": str(GENERIC)},
]


class Book:
    """One item and the rows that tie it to the spell it teaches."""

    def __init__(self, item, spell, target=tg.PET, mask=WARLOCK_MASK, level=8, price=100):
        self.sparse = {"ID": str(item), "AllowableClass": str(mask), "RequiredLevel": str(level),
                       "BuyPrice": str(price)}
        self.link = {"ItemID": str(item), "ItemEffectID": str(item + 1)}
        self.effect = {"ID": str(item + 1), "SpellID": str(item + 2)}
        self.spell = {"SpellID": str(item + 2), "Effect": tg.LEARN_SPELL, "ImplicitTarget_0": target,
                      "EffectTriggerSpell": str(spell)}


def run(books, abilities):
    return tg.grimoires([b.sparse for b in books], [b.link for b in books], [b.effect for b in books],
                        [b.spell for b in books], abilities, FAMILIES)


def ability(spell, line, before=0):
    return {"Spell": str(spell), "SkillLine": str(line), "SupercedesSpell": str(before)}


ABILITIES = [ability(3110, 188), ability(7799, 188, 3110), ability(7800, 188, 7799), ability(7814, 205),
             ability(7815, 205, 7814), ability(18728, GENERIC), ability(695, 593, 686)]


class Grimoires(unittest.TestCase):
    def test_a_book_that_teaches_the_pet_a_demon_spell_is_kept(self):
        found = run([Book(16302, 7799, level=8, price=100)], ABILITIES)
        self.assertEqual(found, [{"line": 188, "name": "Imp", "families": [23], "books": [
            {"level": 8, "spell": 7799, "cost": 100, "item": 16302, "needs": 3110}]}])

    def test_a_grimoire_that_teaches_the_warlock_is_left_out(self):
        self.assertEqual(run([Book(1231, 695, target="1")], ABILITIES), [])

    def test_a_spell_on_no_demons_own_line_is_left_out(self):
        self.assertEqual(run([Book(9000, 18728), Book(9100, 4511)], ABILITIES), [])

    def test_an_item_a_warlock_cannot_use_is_left_out(self):
        self.assertEqual(run([Book(16302, 7799, mask=MAGE_MASK)], ABILITIES), [])

    def test_families_on_one_line_share_its_books_and_demons_come_in_level_order(self):
        found = run([Book(16368, 7815, level=28), Book(16316, 7800, level=18), Book(16302, 7799, level=8)],
                    ABILITIES)
        self.assertEqual([(d["line"], d["name"], d["families"]) for d in found],
                         [(188, "Imp", [23]), (205, "Succubus or Incubus", [17, 302])])
        self.assertEqual([b["spell"] for b in found[0]["books"]], [7799, 7800])
        self.assertEqual(found[0]["books"][1]["needs"], 7799)


if __name__ == "__main__":
    unittest.main()
