"""Tests for Tools/build/waylaid_crates.py: how it reads a crate's bundles from the game's tables.
Offline: wago.tools is never asked; the rows are made up here. From the repo root:

    python -m unittest discover -s Tools/tests
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import waylaid_crates as wc  # noqa: E402

CRATE, UNLABELLED, SUPPLIES = 100, 101, 102
STOCK, READ_LABEL, REPLACE = 900, 901, 902
PEACEBLOOM, SILVERLEAF, OLD_ORE, ORE = 10, 11, 12, 13


def item(item_id, name, flags=0):
    return {"ID": str(item_id), "Display_lang": name, "Flags_0": str(flags)}


def effect(spell, index, base, difficulty=0):
    return {"SpellID": str(spell), "EffectIndex": str(index), "EffectBasePointsF": str(base),
            "DifficultyID": str(difficulty)}


def tables(description="$@spelldesc1|cnIQ1:\n- $M3 Peacebloom\n- $M4 Silverleaf|r", items=()):
    return {
        "ItemSparse": [item(CRATE, "Waylaid Crate: Apprentice Herbs"), item(UNLABELLED, "Waylaid Crate"),
                       item(SUPPLIES, "Waylaid Supplies: Peacebloom"), item(PEACEBLOOM, "Peacebloom"),
                       item(SILVERLEAF, "Silverleaf"), item(OLD_ORE, "Dark Iron Ore", wc.DEPRECATED),
                       item(ORE, "Dark Iron Ore")] + list(items),
        "ItemXItemEffect": [{"ItemID": str(CRATE), "ItemEffectID": "1"},
                            {"ItemID": str(UNLABELLED), "ItemEffectID": "2"},
                            {"ItemID": str(SUPPLIES), "ItemEffectID": "3"}],
        "ItemEffect": [{"ID": "1", "SpellID": str(STOCK)}, {"ID": "2", "SpellID": str(READ_LABEL)},
                       {"ID": "3", "SpellID": str(REPLACE)}],
        "Spell": [{"ID": str(STOCK), "Description_lang": description},
                  {"ID": str(READ_LABEL), "Description_lang": "Read the label to identify the shipment."},
                  {"ID": str(REPLACE), "Description_lang": "Add $q2 Peacebloom to complete the shipment."}],
        "SpellEffect": [effect(STOCK, 0, 0), effect(STOCK, 1, 0), effect(STOCK, 2, 20), effect(STOCK, 3, 10),
                        effect(STOCK, 4, 5), effect(STOCK, 3, 99, difficulty=1)],
    }


class WaylaidCratesTest(unittest.TestCase):
    def test_counts_are_the_base_points_of_the_named_effect(self):
        self.assertEqual({CRATE: [(PEACEBLOOM, 20), (SILVERLEAF, 10)]}, wc.crates(tables()))

    def test_leaves_out_the_unlabelled_crate_and_the_supplies(self):
        self.assertEqual([CRATE], list(wc.crates(tables())))

    def test_a_deprecated_item_of_the_same_name_is_not_a_bundle(self):
        found = wc.crates(tables("- $M5 Dark Iron Ore"))
        self.assertEqual({CRATE: [(ORE, 5)]}, found)

    def test_a_name_of_two_items_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wc.crates(tables(items=[item(14, "Silverleaf")]))

    def test_a_name_of_no_item_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wc.crates(tables("- $M3 Mageroyal"))

    def test_a_line_it_cannot_read_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wc.crates(tables("- 20 Peacebloom"))

    def test_an_effect_with_no_count_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wc.crates(tables("- $M7 Peacebloom"))

    def test_a_labelled_crate_with_no_bundles_stops_the_build(self):
        with self.assertRaises(SystemExit):
            wc.crates(tables("Fill the crate."))

    def test_writes_each_crate_with_its_bundles_in_order(self):
        lines = wc.lua({CRATE: [(PEACEBLOOM, 20), (SILVERLEAF, 10)]}, "1.60.1.1")
        self.assertTrue(lines[0].startswith("-- WaylaidCratesData.lua: "))
        self.assertIn("ns.WaylaidCrates = {", lines)
        self.assertIn(f"    [{CRATE}] = {{ {{ {PEACEBLOOM}, 20 }}, {{ {SILVERLEAF}, 10 }} }},", lines)
        self.assertEqual("}", lines[-1])


if __name__ == "__main__":
    unittest.main()
