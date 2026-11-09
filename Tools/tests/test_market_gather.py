"""Offline checks for The Market's skinning and fishing data generator: how it flattens CMaNGOS's loot tables,
reads the database dump, the entity export and EG Link's files, groups spawns into camps and blends the
fishing sources."""
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import paths  # noqa: E402,F401
import market_gather as mg  # noqa: E402


def row(item, chance, group=0, low=1, high=1, condition=0):
    return {"item": str(item), "ChanceOrQuestChance": str(chance), "groupid": str(group),
            "mincountOrRef": str(low), "maxcount": str(high), "condition_id": str(condition)}


LOOT_COLUMNS = "  `entry` int,\n  `item` int,\n  `ChanceOrQuestChance` float,\n  `groupid` int,\n" \
    "  `mincountOrRef` int,\n  `maxcount` int,\n  `condition_id` int,\n"
DUMP = (
    "CREATE TABLE `creature_template` (\n  `Entry` int,\n  `Name` varchar(100),\n  `MinLevel` int,\n"
    "  `MaxLevel` int,\n  `SkinningLootId` int,\n  PRIMARY KEY (`Entry`)\n) ENGINE=InnoDB;\n"
    "INSERT INTO `creature_template` VALUES (113,'Stonetusk Boar',5,6,113),(448,'Hogger',11,11,0),"
    "(1125,'Crag Boar',5,6,113);\n"
    f"CREATE TABLE `skinning_loot_template` (\n{LOOT_COLUMNS}) ENGINE=InnoDB;\n"
    "INSERT INTO `skinning_loot_template` VALUES (113,2318,40,1,1,1,0),(113,2934,0,1,1,1,0),"
    "(113,5000,-50,0,1,1,0);\n"
    f"CREATE TABLE `fishing_loot_template` (\n{LOOT_COLUMNS}) ENGINE=InnoDB;\n"
    "INSERT INTO `fishing_loot_template` VALUES (12,11000,100,1,-11000,1,0);\n"
    f"CREATE TABLE `reference_loot_template` (\n{LOOT_COLUMNS}) ENGINE=InnoDB;\n"
    "INSERT INTO `reference_loot_template` VALUES (11000,6289,40,1,1,1,0),(11000,6291,0,1,1,1,0);\n"
    f"CREATE TABLE `gameobject_loot_template` (\n{LOOT_COLUMNS}) ENGINE=InnoDB;\n"
    "INSERT INTO `gameobject_loot_template` VALUES (17440,6358,100,0,1,1,0),(17321,19975,100,0,1,1,0);\n"
    "CREATE TABLE `gameobject_template` (\n  `entry` int,\n  `type` int,\n  `name` varchar(100),\n"
    "  `data1` int,\n  PRIMARY KEY (`entry`)\n) ENGINE=InnoDB;\n"
    "INSERT INTO `gameobject_template` VALUES (180582,25,'Oily Blackmouth School',17440),"
    "(180369,25,'Muddy Churning Waters',17321),(182959,25,'Bluefish School',0),(1731,3,'Copper Vein',2);\n"
    "CREATE TABLE `gameobject` (\n  `guid` int,\n  `id` int,\n  `map` int,\n  PRIMARY KEY (`guid`)\n"
    ") ENGINE=InnoDB;\n"
    "INSERT INTO `gameobject` VALUES (1,180369,309),(2,1731,0);\n"
)


class Flatten(unittest.TestCase):
    def test_a_group_shares_what_its_chances_leave(self):
        loot = mg.flatten([row(1, 40, group=1), row(2, 0, group=1), row(3, 0, group=1, high=2)], {})
        self.assertEqual(loot, {1: [40.0, 1, 1], 2: [30.0, 1, 1], 3: [30.0, 1, 2]})

    def test_ungrouped_rows_roll_on_their_own_and_quest_and_conditional_rows_drop(self):
        loot = mg.flatten([row(1, 100, group=1), row(2, 10), row(3, -20), row(4, 50, condition=322)], {})
        self.assertEqual(loot, {1: [100.0, 1, 1], 2: [10.0, 1, 1]})

    def test_a_reference_scales_its_table_by_its_chance_and_rolls(self):
        refs = {"900": [row(7, 50, group=1), row(8, 0, group=1)]}
        loot = mg.flatten([{**row(900, 20, low=-900, high=2)}], refs)
        self.assertEqual(loot, {7: [20.0, 1, 1], 8: [20.0, 1, 1]})


class Cmangos(unittest.TestCase):
    def test_reads_skinnables_their_loot_the_zone_catches_and_the_open_world_pools(self):
        db = mg.read_cmangos(DUMP)
        self.assertEqual(db["skinnable"], {"113": [5, 6, 113], "1125": [5, 6, 113]})
        self.assertEqual(db["skin_loot"], {"113": [[2318, 40.0, 1, 1], [2934, 60.0, 1, 1]]})
        self.assertEqual(db["fishing"], {"12": [[6289, 40.0], [6291, 60.0]]})
        self.assertEqual(db["pools"], [180582])


EXPORT = {
    "version": 1, "edition": "forever", "coordinate_space": "forever", "source": "test", "build": "1",
    "entities": {"npcs": {
        "113": {"name": "Stonetusk Boar", "minLevel": 5, "maxLevel": 6,
                "spawns": {"12": {"1": {"1": 40.0, "2": 60.0}, "2": [41.0, 61.0], "3": [50.0, 50.0, 1],
                                  "4": [40.0, 60.0], "5": None},
                           "2159": [[10.0, 10.0]], "1": [[-1, 50.0]]}},
        "448": {"name": "Hogger", "minLevel": 11, "maxLevel": 11, "spawns": {"12": [[30.0, 30.0]]}},
    }},
}


class Export(unittest.TestCase):
    def test_keeps_wanted_creatures_on_known_maps_without_phases_repeats_or_off_map_spots(self):
        found = mg.read_export(EXPORT, {"113", "999"})
        self.assertEqual(found["asked"], ["113", "999"])
        self.assertEqual(found["npcs"], {"113": {"name": "Stonetusk Boar", "levels": [5, 6],
                                                 "spawns": {"1429": [[40.0, 60.0], [41.0, 61.0]]}}})

    def test_refuses_an_export_in_other_coordinates(self):
        with self.assertRaises(ValueError):
            mg.read_export({**EXPORT, "coordinate_space": "classic"}, {"113"})


def eg_files(build, name):
    loot = {
        "a": {"sources": {
            "npc:251245|spell:8613": {"windows": 3, "items": {"2934": {"drops": 2, "quantity": 2},
                                                              "2318": {"drops": 1, "quantity": 2}}},
            "npc:251245|spell:8617|bountifulHarvest:1": {"windows": 50, "items": {"2934": {"drops": 50}}},
            "npc:113": {"windows": 9, "items": {"117": {"drops": 9}}},
            "fishing:1429": {"windows": 4, "items": {"6291": {"drops": 3}, "6289": {"drops": 1}}},
        }},
        "b": {"sources": {
            "npc:251245|spell:8618|group": {"windows": 1, "items": {"2934": {"drops": 1, "quantity": 1}}},
            "fishing:1429|group": {"windows": 6, "items": {"6291": {"drops": 6}}},
        }},
    }
    creatures = {"a": {"creatures": {"251245": {"name": "Prideclaw", "levels": {"5": 3},
                                                "positions": [{"uiMap": 2521, "mapX": 0.4, "mapY": 0.5}]}}},
                 "b": {"creatures": {"251245": {"name": "Prideclaw", "levels": {"6": 1},
                                                "positions": [{"uiMap": 2521, "mapX": 0.4, "mapY": 0.5}]}}}}
    details = {"creatures": {"251245": {"name": "Prideclaw", "type": 1}}}
    return {"loot.json": loot, "creatures.json": creatures}.get(name, {"a": details, "b": details})[build]


class EgLink(unittest.TestCase):
    def test_sums_skinning_and_fishing_over_the_builds_without_talent_windows(self):
        with mock.patch.object(mg, "EG_BUILDS", ("a", "b")):
            eg = mg.read_eglink(eg_files)
        self.assertEqual(eg["skins"], {"251245": {"windows": 4, "items": {"2934": [3, 3], "2318": [1, 2]}}})
        self.assertEqual(eg["fishing"], {"1429": {"windows": 10, "items": {"6291": 9, "6289": 1}}})
        self.assertEqual(eg["creatures"], {"251245": {"name": "Prideclaw", "levels": [5, 6],
                                                      "positions": {"2521": [[40.0, 50.0]]}}})


class Camps(unittest.TestCase):
    def test_groups_close_spawns_at_their_centre_biggest_first(self):
        points = [[10, 10], [11, 10], [12, 11], [50, 50], [50.5, 50]]
        self.assertEqual(mg.camps(points, 3), [(11.0, 31 / 3, 3), (50.25, 50.0, 2)])

    def test_a_long_line_of_spawns_splits_into_camps_no_wider_than_the_radius_each_way(self):
        found = mg.camps([[x, 20] for x in range(0, 30)], 3)
        self.assertEqual(sum(c[2] for c in found), 30)
        self.assertTrue(all(c[2] <= 7 for c in found))

    def test_a_camp_counts_no_more_than_real_camps_hold(self):
        found = mg.camps([[10 + i / 100, 10] for i in range(200)], 3)
        self.assertEqual(found, [(10.995, 10.0, mg.CAMP_MOST)])


CACHE = {
    "cmangos": {"skinnable": {"113": [5, 6, 113], "1125": [5, 6, 113], "3": [1, 2, 3]},
                "skin_loot": {"113": [[2318, 40.0, 1, 1], [2934, 60.0, 1, 1]], "3": [[2934, 100.0, 1, 1]]},
                "fishing": {"12": [[6289, 40.0], [6291, 60.0]], "14": [[6303, 100.0]]}, "pools": [180582]},
    "export": {"asked": ["113", "1125", "3", "251245"], "npcs": {
        "113": {"name": "Stonetusk Boar", "levels": [5, 7], "spawns": {"1429": [[40.0, 60.0], [41.0, 61.0]]}},
        "3": {"name": "Flesh Eater", "levels": None, "spawns": {}},
    }},
    "eglink": {"skins": {"251245": {"windows": 4, "items": {"2934": [3, 3], "2318": [1, 2]}}},
               "fishing": {"1429": {"windows": 100, "items": {"6291": 100}}, "1": {"windows": 2, "items": {}}},
               "creatures": {"251245": {"name": "Prideclaw", "levels": [5, 6],
                                        "positions": {"2521": [[40.0, 50.0]]}}}},
}


class Skinning(unittest.TestCase):
    def setUp(self):
        self.creatures, self.loot, self.spawns = mg.skinning(CACHE)

    def test_keeps_database_skinnables_forever_knows_with_its_levels_and_name(self):
        self.assertEqual(self.creatures[113], [5, 7, 113, "Stonetusk Boar"])
        self.assertEqual(self.creatures[3], [1, 2, 3, "Flesh Eater"])
        self.assertNotIn(1125, self.creatures)

    def test_a_creature_only_eg_link_saw_skinned_gets_its_observed_loot(self):
        self.assertEqual(self.creatures[251245], [5, 6, 251245, "Prideclaw"])
        self.assertEqual(self.loot[251245], [[2318, 25.0, 2, 2], [2934, 75.0, 1, 1]])
        self.assertEqual(sorted(self.loot), [3, 113, 251245])

    def test_camps_are_quads_in_tenths_of_a_map_percent(self):
        self.assertEqual(self.spawns, {1429: [113, 405, 605, 2], 2521: [251245, 400, 500, 1]})


class Fishing(unittest.TestCase):
    def test_blends_the_database_with_what_players_caught_and_names_the_source(self):
        catches, sources = mg.fishing(CACHE)
        self.assertEqual(sources, {1429: "both", 1411: "cmangos"})
        self.assertEqual(catches[1411], [[6303, 100.0]])
        self.assertEqual(catches[1429], [[6291, 80.0], [6289, 20.0]])


if __name__ == "__main__":
    unittest.main()
