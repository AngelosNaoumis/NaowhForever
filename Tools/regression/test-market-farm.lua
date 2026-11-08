-- Run with Lua 5.1 from the repository root: The Market's Farm: zones ranked for your skills, and a loop through one.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local SILVERLEAF, PEACEBLOOM, COPPER, KELP = 1617, 1618, 1731, 2045
local t = World.Setup()
local F = t.M.Farm
Check("without Glimmer's map Farm is not ready", not F.Ready() and #F.Zones() == 0)

local skill = { herb = 50, ore = 0 }
local gathered = {}
t.ns.Glimmer = {
    C = { SPOT_SCALE = 1000 },
    NODES = { [SILVERLEAF] = { "herb", 1, "Silverleaf" }, [PEACEBLOOM] = { "herb", 1, "Peacebloom" },
        [COPPER] = { "ore", 1, "Copper Vein" }, [KELP] = { "herb", 85, "Stranglekelp" } },
    Spots = { Load = function() return true end, Gathered = function(map) return gathered[map] end },
    Target = { Skill = function(kind) return skill[kind] end },
}
t.ns.GlimmerSpots = {
    [1] = { SILVERLEAF, 100, 100, PEACEBLOOM, 200, 100, COPPER, 900, 900 },
    [2] = { KELP, 500, 500, SILVERLEAF, 600, 500 },
}
Check("and without Professions' node items", not F.Ready())
t.ns.Professions = { GatherNodes = { Silverleaf = { "herb", 1, 765 }, Peacebloom = { "herb", 1, 2447 },
    ["Copper Vein"] = { "ore", 1, 2770 }, Stranglekelp = { "herb", 85, 3820 } } }
t.scan = { [765] = 10, [2447] = 20, [2770] = 100, [3820] = 500 }
Check("with both it is", F.Ready())

local zones = F.Zones()
Check("zones with something you can gather are listed, the richest first", #zones == 2 and zones[1].map == 1
    and zones[2].map == 2)
Check("a zone's worth counts only what your skills gather", zones[1].stops == 2 and zones[1].value == 2 * 9 + 2 * 19
    and zones[2].stops == 1)
Check("its best items come first", zones[1].items[1].item == 2447 and zones[1].items[2].item == 765)
Check("each has an hourly estimate", zones[1].perHour > zones[2].perHour and zones[2].perHour > 0)
Check("and its name", zones[1].name == "Map 1")

Check("the list is kept until something changes", F.Zones() == zones and #zones == 2)
skill.ore = 10
zones = F.Zones()
Check("a skill-up reads it again", zones[1].stops == 3 and zones[1].value == 56 + 95 * 1.5)
t.ns.MarketSettings.Set("farmHerbs", false)
zones = F.Zones()
Check("turning Herbs off leaves only veins", #zones == 1 and zones[1].stops == 1)
t.ns.MarketSettings.Set("farmHerbs", true)

t.now = 10000
gathered[1] = {
    a = { id = PEACEBLOOM, x = 200, y = 100, last = 10000 - 60 },
    b = { id = SILVERLEAF, x = 100, y = 100, last = 10000 - 7200 },
}
t.playerMap = 1
t.playerAt = { GetXY = function() return 0.85, 0.85 end }
F.Zone(1)
Check("a zone's map has every herb and vein", #F.spots == 3)
local byID = {}
for _, spot in ipairs(F.spots) do byID[spot.id] = spot end
Check("each at its place on the map", byID[COPPER].x == 0.9 and byID[COPPER].y == 0.9)
Check("priced per node", byID[COPPER].value == 95 * 1.5 and F.most == 95 * 1.5)
Check("one gathered a minute ago is marked", byID[PEACEBLOOM].picked == 10000 - 60)
Check("one gathered two hours ago is not", byID[SILVERLEAF].picked == nil)
Check("the loop starts at the stop nearest you", F.loop[1].id == COPPER)
Check("and goes to the nearest next", F.loop[2].id == PEACEBLOOM and F.loop[3].id == SILVERLEAF)
local hop = math.sqrt(0.7 ^ 2 + 0.8 ^ 2) * 1000 + 100 + math.sqrt(0.8 ^ 2 + 0.8 ^ 2) * 1000
Check("its length closes the loop", math.abs(F.loopYards - hop) < 0.01)
Check("its worth and time", F.loopValue == 9 * 2 + 19 * 2 + 95 * 1.5 and F.loopMinutes > 0 and F.loopPerHour > 0)

skill.ore = 0
F.Zone(1)
Check("a vein you cannot mine is shown but kept off the loop", #F.spots == 3 and #F.loop == 2)
local stops = F.Stops("Map 1 loop")
Check("the loop's waypoints are named for their node, in percent", #stops == 2 and stops[1][2] == 1
    and math.abs(stops[1][3] - 20) < 1e-9 and stops[1][1] == "Peacebloom")

t.sameMap, t.playerMap = { [99] = 1 }, 99
F.Zone(1)
Check("on a map that is the zone's under another ID, the loop still starts nearest you", F.loop[1].id == PEACEBLOOM)

t.playerMap = 5
F.Zone(2)
Check("away from the zone the loop starts at its first stop", #F.loop == 1 and F.loop[1].id == SILVERLEAF)

print("market farm: " .. checks .. " checks passed")
