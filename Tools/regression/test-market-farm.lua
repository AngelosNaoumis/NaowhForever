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

local BOAR, WOLF, CAT = 113, 69, 2042
local LEATHER, HIDE = 2318, 783
t.M.SKIN_CREATURES = { [BOAR] = { 5, 7, 100, "Stonetusk Boar" }, [WOLF] = { 18, 20, 200, "Timber Wolf" },
    [CAT] = { 14, 16, 100, "Nightsaber" } }
t.M.SKIN_LOOT = { [100] = { LEATHER, 100, 1, 1 }, [200] = { LEATHER, 50, 1, 3, HIDE, 50, 1, 1 } }
F.camps = { [1] = { BOAR, 300, 300, 4 }, [3] = { WOLF, 500, 500, 6, CAT, 100, 100, 2 } }
t.scan[LEATHER], t.scan[HIDE] = 40, 200
skill.herb, skill.ore, skill.skin = 50, 0, 0
F.Changed()
zones = F.Zones()
Check("beasts are left out until you can skin them", #zones == 2 and zones[1].stops == 2)
skill.skin = 59
F.Changed()
zones = F.Zones()
local one = {}
for _, zone in ipairs(zones) do one[zone.map] = zone end
Check("a camp adds its beasts at what one skinning is worth", one[1].stops == 3
    and one[1].value == 2 * 9 + 2 * 19 + 4 * 38)
Check("skinning needs one point up to level 10, ten a level to 20, then five times the level",
    one[3] == nil)
skill.skin = 60
F.Changed()
zones = F.Zones()
one = {}
for _, zone in ipairs(zones) do one[zone.map] = zone end
Check("so level 16 asks 60, and a zone of only camps is listed", one[3] and one[3].stops == 1
    and one[3].value == 2 * 38 and one[3].perHour > 0)
Check("a camp's most valuable drop stands for it", one[3].items[1].item == LEATHER)
skill.skin = 100
F.Changed()
zones = F.Zones()
one = {}
for _, zone in ipairs(zones) do one[zone.map] = zone end
local wolf = 0.5 * 38 * 2 + 0.5 * 190
Check("chances and counts make a skinning's worth", one[3].stops == 2 and one[3].value == 2 * 38 + 6 * wolf
    and one[3].items[1].item == HIDE)
t.ns.MarketSettings.Set("farmSkins", false)
zones = F.Zones()
Check("turning Beasts to skin off leaves the camps out", #zones == 2)
t.ns.MarketSettings.Set("farmSkins", true)

F.Zone(3)
Check("a camp is a spot on the map, with its beasts", #F.spots == 2 and F.spots[1].kind == "skin"
    and F.spots[1].count == 6 and F.spots[1].x == 0.5 and F.spots[1].value == 6 * wolf)
Check("both camps are on the loop", #F.loop == 2 and F.loopPerHour > 0)
t.M.C.LOOP_STOPS = 1
F.Zone(3)
Check("a loop keeps only its richest stops, while every spot stays on the map", #F.loop == 1
    and F.loop[1].id == WOLF and #F.spots == 2)
F.Changed()
one = {}
for _, zone in ipairs(F.Zones()) do
    if zone.kind == "gather" then one[zone.map] = zone end
end
Check("and a zone is rated on those same stops", one[3].stops == 1 and one[3].value == 6 * wolf)
t.M.C.LOOP_STOPS = 25
F.Changed()
F.Zone(3)
stops = F.Stops("Map 3 loop")
Check("its waypoints are named for the beast", stops[1][1] == "Timber Wolf" or stops[1][1] == "Nightsaber")
Check("and a camp gives its beasts' levels", select(2, F.CreatureLevels(WOLF)) == 20)
skill.skin = 60
F.Zone(3)
Check("a camp you cannot skin yet is shown but kept off the loop", #F.spots == 2 and #F.loop == 1
    and F.loop[1].id == CAT)

local C = t.M.C
local SMALLFISH, MUDSNAPPER, MACKEREL, SCHOOL = 6291, 6289, 6303, 180582
local function Object(id, spawn) return "GameObject-0-1-2-3-" .. id .. "-" .. spawn end
local function Rows()
    local gather, fish = {}, {}
    for _, zone in ipairs(F.Zones()) do (zone.kind == "fish" and fish or gather)[zone.map] = zone end
    return gather, fish
end
t.M.FISH_CATCHES = { [1] = { SMALLFISH, 60, MUDSNAPPER, 40 }, [4] = { MACKEREL, 100 } }
t.ns.FishingLevels = { [1] = { 1, 25 }, [4] = { 55, 150 } }
t.scan[SMALLFISH], t.scan[MUDSNAPPER], t.scan[MACKEREL] = 20, 40, 100
skill.fish = 0
F.Changed()
local gatherRows, fishRows = Rows()
Check("water is left out until you can fish there", next(fishRows) == nil and gatherRows[1] ~= nil)
skill.fish = 1
F.Changed()
gatherRows, fishRows = Rows()
local catch = 19 * 0.6 + 38 * 0.4
Check("a zone you can fish is its own row, beside its gathering row", fishRows[1] and gatherRows[1]
    and fishRows[4] == nil and fishRows[1].kind == "fish" and gatherRows[1].kind == "gather")
Check("one catch is worth its catches' chances at their prices", math.abs(fishRows[1].value - catch) < 1e-9)
Check("its most valuable catch comes first", fishRows[1].items[1].item == MUDSNAPPER
    and fishRows[1].items[2].item == SMALLFISH)
Check("at the zone's lowest skill some fish get away", fishRows[1].rate == C.FISH_LOW_CATCH)
Check("an hour is catches times the catch rate times a catch's worth",
    fishRows[1].perHour == math.floor(C.CATCHES_PER_HOUR * C.FISH_LOW_CATCH * catch))
skill.fish = 13
F.Changed()
fishRows = select(2, Rows())
Check("halfway to the zone's top skill, half the gap is closed",
    math.abs(fishRows[1].rate - (C.FISH_LOW_CATCH + (1 - C.FISH_LOW_CATCH) / 2)) < 1e-9)
skill.fish = 60
F.Changed()
fishRows = select(2, Rows())
Check("at its top skill nothing gets away, and a higher zone opens", fishRows[1].rate == 1 and fishRows[4]
    and math.abs(fishRows[4].rate - (C.FISH_LOW_CATCH + (1 - C.FISH_LOW_CATCH) * 5 / 95)) < 1e-9)
local ranked = F.Zones()
local sorted = true
for i = 2, #ranked do
    if ranked[i - 1].rank < ranked[i].rank then sorted = false end
end
Check("fish rows rank among the gathering rows by gold an hour", sorted and #ranked == 5)
t.ns.MarketSettings.Set("farmFish", false)
gatherRows, fishRows = Rows()
Check("turning Fishing off leaves the water out", next(fishRows) == nil and gatherRows[1] ~= nil)
t.ns.MarketSettings.Set("farmFish", true)

t.M.FISH_POOLS = { [SCHOOL] = true }
t.ns.Glimmer.C.GUID_OBJECT = "^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"
t.ns.MarketSettings.Set("enabled", true)
t.ns.Apply()
t.playerMap, t.playerAt = 1, { GetXY = function() return 0.3, 0.4 end }
t.now, t.fishing = 20000, true
t.loot = { { source = Object(SCHOOL, "A"), item = SMALLFISH, qty = 1 } }
t.Fire("LOOT_OPENED")
local pools = t.M.Runs.Pools(1)
Check("a catch from a school marks a pool where you stand", #pools == 1 and pools[1].id == SCHOOL
    and pools[1].x == 0.3 and pools[1].y == 0.4 and pools[1].last == 20000)
t.now, t.playerAt = 20500, { GetXY = function() return 0.31, 0.405 end }
t.Fire("LOOT_OPENED")
Check("one fished close by is the same pool, seen again", #pools == 1 and pools[1].last == 20500 and pools[1].x == 0.3)
t.playerAt = { GetXY = function() return 0.6, 0.6 end }
t.loot = { { source = Object(PEACEBLOOM, "B"), item = SMALLFISH, qty = 1 } }
t.Fire("LOOT_OPENED")
Check("a catch from anything but a pool marks nothing", #t.M.Runs.Pools(1) == 1)
t.loot, t.fishing = { { source = Object(SCHOOL, "C"), item = SMALLFISH, qty = 1 } }, false
t.Fire("LOOT_OPENED")
Check("nor does loot that is not a catch", #t.M.Runs.Pools(1) == 1)
t.fishing, t.now = true, 21000
t.Fire("LOOT_OPENED")
Check("a school farther off is a second pool", #t.M.Runs.Pools(1) == 2)
local most = C.POOLS_PER_MAP
C.POOLS_PER_MAP = 2
t.now, t.playerAt = 21500, { GetXY = function() return 0.9, 0.1 end }
t.Fire("LOOT_OPENED")
pools = t.M.Runs.Pools(1)
Check("past the most a map keeps, the pool seen longest ago goes", #pools == 2 and pools[1].x == 0.6
    and pools[2].x == 0.9)
C.POOLS_PER_MAP = most

skill.fish = 25
F.Changed()
t.now = 21600
F.Zone(1, "fish")
local pool = catch * C.CATCHES_PER_HOUR * C.POOL_SECONDS / 3600
Check("a fish row's map has its pools", #F.spots == 2 and F.spots[1].kind == "fish" and F.spots[1].x == 0.6)
Check("a pool is worth what you catch while fishing it", math.abs(F.spots[1].value - pool) < 1e-9
    and F.spots[1].work == C.POOL_SECONDS)
Check("one fished in the last minutes is marked", F.spots[2].picked == 21500 and F.spots[1].picked == nil)
Check("the loop runs through them", #F.loop == 2 and F.loopPerHour > 0 and F.loopMinutes > 0)
Check("its waypoints are pools", F.Stops("Map 1 loop")[1][1] == "Fishing pool")
Check("the strip has the zone's best catch, what a catch is worth and the skill it needs",
    F.catchItem == MUDSNAPPER and math.abs(F.catchWorth - catch) < 1e-9 and F.catchNeed == 1)
F.Zone(1)
local herbs = #F.spots > 0
for _, spot in ipairs(F.spots) do
    if spot.kind == "fish" then herbs = false end
end
Check("the same map's gathering row is picked apart from its fish row", herbs and F.kind == nil)
F.Zone(4, "fish")
Check("a zone with no pools learned has no pins and no loop", #F.spots == 0 and #F.loop == 0
    and F.catchItem == MACKEREL)

print("market farm: " .. checks .. " checks passed")
