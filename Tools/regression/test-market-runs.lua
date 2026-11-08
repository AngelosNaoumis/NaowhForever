-- Run with Lua 5.1 from the repository root: The Market's Last Run: recording what you gather, and what nodes yield.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local PEACEBLOOM, COPPER = 1618, 1731
local function Object(id, spawn) return "GameObject-0-1-2-3-" .. id .. "-" .. spawn end

local t = World.Setup()
local R, F = t.M.Runs, t.M.Farm
local function Loot()
    t.Fire("LOOT_OPENED")
    for slot = 1, #t.loot do t.Fire("LOOT_SLOT_CLEARED", slot) end
    t.Fire("LOOT_CLOSED")
end
local skill = { herb = 40, ore = 20 }
t.ns.Glimmer = {
    C = { SPOT_SCALE = 1000, GUID_OBJECT = "^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-" },
    NODES = { [PEACEBLOOM] = { "herb", 1, "Peacebloom" }, [COPPER] = { "ore", 1, "Copper Vein" },
        [32] = { "chest", 0, "Sunken Chest" } },
    Spots = { Load = function() return true end, Gathered = function() end },
    Target = { Skill = function(kind) return skill[kind] end },
}
t.ns.GlimmerSpots = { [12] = { PEACEBLOOM, 100, 100, COPPER, 500, 500 } }
t.ns.Professions = { GatherNodes = { Peacebloom = { "herb", 1, 2447 }, ["Copper Vein"] = { "ore", 1, 2770 } } }
t.scan = { [2447] = 20, [2770] = 100, [2835] = 10 }
t.playerMap = 12
t.playerAt = { GetXY = function() return 0.1, 0.1 end }

Check("a herb's GUID is a node", select(2, R.Node(Object(PEACEBLOOM, "A"))) == "herb")
Check("a chest's is not", R.Node(Object(32, "A")) == nil)
Check("nor a creature's", R.Node("Creature-0-1-2-3-299-A") == nil)

t.ns.MarketSettings.Set("enabled", true)
t.ns.Apply()
t.now = 1000
t.loot = { { source = Object(PEACEBLOOM, "A"), item = 2447, qty = 3 } }
Loot()
local run = R.List()[1]
Check("the first gather starts a run", run and run.start == 1000 and run.nodes == 1 and run.items[2447] == 3)
Check("in the zone you are in, with your skills", run.map == 12 and run.from.herb == 40)
Check("the event keeps its place and what it gave", run.events[1].x == 0.1 and run.events[1].items[2447] == 3
    and run.events[1].kind == "herb")

t.now = 1060
t.loot = { { source = Object(COPPER, "B"), item = 2770, qty = 2 }, { source = Object(COPPER, "B"), item = 2835, qty = 1 } }
Loot()
t.now = 1070
t.loot = { { source = Object(COPPER, "B"), item = 2770, qty = 1 } }
skill.ore = 21
Loot()
Check("mining a vein again is the same node", run.nodes == 2 and #run.events == 3 and run.items[2770] == 3)
Check("every item a vein gives counts", run.items[2835] == 1)
Check("skill-ups are kept", run.to.ore == 21 and run.from.ore == 20)
Check("the run's worth is at today's prices after the cut", R.Value(run) == 3 * 19 + 3 * 95 + 9)

t.loot = { { source = "Creature-0-1-2-3-299-A", item = 2589, qty = 2 } }
Loot()
Check("loot from anything else is not a gather", #run.events == 3)

local haul = R.Haul(run, {})
Check("the haul is most valuable first", haul[1].item == 2770 and haul[1].qty == 3 and haul[1].worth == 3 * 95)

local took, nodes = run.items[2447], run.nodes
t.loot = { { source = Object(PEACEBLOOM, "L"), item = 2447, qty = 2 } }
t.Fire("LOOT_OPENED")
t.Fire("LOOT_CLOSED")
Check("a loot window closed with its items left in it counts nothing", run.items[2447] == took)
Loot()
Check("taking them later counts them once", run.items[2447] == took + 2 and run.nodes == nodes + 1)
Check("a node's yield is not trusted from one gather", R.NodeValue(COPPER) == nil)
Check("so Farm prices it from the default", F.NodeValue(COPPER) == 95 * 1.5)
for i = 1, 2 do
    t.now = 1100 + i * 30
    t.loot = { { source = Object(COPPER, "C" .. i), item = 2770, qty = 2 } }
    Loot()
end
Check("after three it is the average of what they gave", R.NodeValue(COPPER) == (7 * 95 + 9) / 3)
Check("and Farm prices the node from it", F.NodeValue(COPPER) == R.NodeValue(COPPER))

Check("a short run is not a zone's measure", R.PerHour(12) == nil)
Check("Farm estimates the zone before then", F.Zones()[1].measured == nil)
t.now = 1000 + 600
t.loot = { { source = Object(PEACEBLOOM, "D"), item = 2447, qty = 2 } }
Loot()
Check("a run of ten minutes is", R.PerHour(12) == math.floor(R.Value(run) / (600 / 3600)))
Check("and Farm ranks the zone by it at once", F.Zones()[1].measured == R.PerHour(12))

t.now = 1600 + 601
t.sameMap, t.playerMap = { [77] = 12 }, 77
Loot()
Check("a run on a map's other ID is kept under the zone's own", R.List()[1].map == 12)
Check("ten idle minutes start a new run", #R.List() == 2 and R.List()[1].start == 2201 and R.List()[2] == run
    and R.List()[1].nodes == 1)
for i = 1, 12 do
    t.now = 3000 + i * 1000
    Loot()
end
Check("only the last ten runs are kept", #R.List() == 10)

t.ns.MarketSettings.Set("enabled", false)
t.ns.Apply()
local before = #R.List()[1].events
Loot()
Check("nothing is recorded with The Market off", #R.List()[1].events == before)

print("market runs: " .. checks .. " checks passed")
