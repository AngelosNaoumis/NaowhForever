import importlib.util
import json
import sys
import unittest
from pathlib import Path


BUILD = Path(__file__).parents[1] / "build"
sys.path.insert(0, str(BUILD))
SPEC = importlib.util.spec_from_file_location("recipe_reagents", BUILD / "recipe_reagents.py")
recipe_reagents = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(recipe_reagents)

MINOR_MANA_POTION, PEACEBLOOM, ANTI_VENOM = 2331, 2447, 7934


def reagent_row(spell, *pairs):
    row = {"SpellID": str(spell)}
    for i in range(recipe_reagents.SLOTS):
        item, count = pairs[i] if i < len(pairs) else (0, 0)
        row[f"Reagent_{i}"], row[f"ReagentCount_{i}"] = str(item), str(count)
    return row


class RecipeReagentsTest(unittest.TestCase):
    def test_reads_the_recipe_spells_from_recipe_data(self):
        source = "{ spell = 30, item = 1, skill = 5 },\n            { spell = 10, item = 2 },\n{ spell = 30 }"
        self.assertEqual([10, 30], recipe_reagents.recipe_spells(source))

    def test_keeps_wanted_spells_and_their_filled_slots(self):
        rows = [reagent_row(10, (100, 2), (0, 0), (200, 1)), reagent_row(20, (300, 1)),
                reagent_row(30, (0, 0)), reagent_row(40, (400, 0))]
        self.assertEqual({"10": [100, 2, 200, 1]}, recipe_reagents.read_reagents([10, 30, 40], rows))

    def test_made_counts_only_create_item_effects_past_one(self):
        rows = [
            {"SpellID": "10", "Effect": "24", "EffectBasePointsF": "200"},
            {"SpellID": "20", "Effect": "24", "EffectBasePointsF": "0"},
            {"SpellID": "30", "Effect": "24", "EffectBasePointsF": "1"},
            {"SpellID": "40", "Effect": "6", "EffectBasePointsF": "5"},
            {"SpellID": "50", "Effect": "24", "EffectBasePointsF": "3"},
        ]
        self.assertEqual({"10": 200}, recipe_reagents.read_made([10, 20, 30, 40], rows))

    def test_renders_by_spell_with_made_past_one(self):
        text = recipe_reagents.render({"reagents": {"20": [5, 1], "3": [7, 2, 8, 1]}, "made": {"20": 200}})
        self.assertIn("    [3] = { 7, 2, 8, 1 },\r\n    [20] = { 5, 1, made = 200 },\r\n}", text)

    def test_checked_in_reagents_are_current(self):
        data = json.loads(recipe_reagents.CACHE.read_text(encoding="utf-8"))
        self.assertEqual(recipe_reagents.render(data), recipe_reagents.OUT.read_bytes().decode("utf-8"))
        self.assertIn(PEACEBLOOM, data["reagents"][str(MINOR_MANA_POTION)][::2])
        self.assertEqual(3, data["made"][str(ANTI_VENOM)])
        spells = recipe_reagents.recipe_spells(recipe_reagents.RECIPES.read_bytes().decode("ascii"))
        self.assertTrue(set(map(int, data["reagents"])) <= set(spells))


if __name__ == "__main__":
    unittest.main()
