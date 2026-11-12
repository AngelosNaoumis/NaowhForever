-- Run with Lua 5.1 from the repository root: Price Graph's movers, the items whose lowest price changed most
-- between the last two days The Market has prices for (History.Movers).
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local START = 20000 * DAY + 3600

local t = World.Setup()
local H, C = t.M.History, t.M.C

local function Scan(day, prices, listed, seconds)
    t.scan, t.listed, t.scanAt = prices, listed, START + day * DAY + (seconds or 0)
    H.Record()
end

local function List(ids)
    return table.concat(ids, ",")
end

Check("with no history there are no movers", H.Movers() == nil)
Scan(0, { [1] = 1000, [2] = 1000, [3] = 1000, [4] = 1000, [5] = 1000, [6] = 50, [7] = 1000, [8] = 1000, [9] = 99,
    [10] = 1000 }, { [1] = 40, [4] = 4, [5] = 40, [7] = 40 })
Check("nor with one day of it", H.Movers() == nil)

Scan(1, { [1] = 500, [2] = 1500, [3] = 1000, [4] = 100, [5] = 3000, [6] = 100, [7] = 900, [9] = 300, [10] = 990,
    [11] = 700 }, { [1] = 40, [2] = 5, [5] = 4, [7] = 40 })
local movers = H.Movers()
Check("the biggest drop is first, then the next", List(movers.dropped) == "1,7,10")
Check("and the biggest rise", List(movers.rose) == "2")
Check("each with today's price and its change in percent", movers.price[1] == 500 and movers.change[1] == -50
    and movers.price[2] == 1500 and movers.change[2] == 50 and movers.price[7] == 900
    and math.abs(movers.change[7] + 10) < 0.001)
Check("a price that did not move is no mover", movers.change[3] == nil)
Check("an item thinly listed on the day before is left out", C.MOVERS_MIN_LISTED == 5 and movers.change[4] == nil)
Check("and one thinly listed today", movers.change[5] == nil)
Check("an item whose count is not known still counts", movers.change[10] ~= nil)
Check("a price under the least on either day is noise, not a mover", C.MOVERS_MIN_PRICE == 100
    and movers.change[6] == nil and movers.change[9] == nil)
Check("an item priced on one of the days alone has nothing to compare", movers.change[8] == nil
    and movers.change[11] == nil)
Check("the same lists come back until the history changes", H.Movers() == movers)

t.now = START + DAY + 60
t.scan = { [3] = 400 }
H.Seen({ 3 }, 1)
movers = H.Movers()
Check("a price seen since moves the lists", List(movers.dropped) == "3,1,7,10" and movers.change[3] == -60)

Scan(4, { [1] = 250, [7] = 1800 }, {})
movers = H.Movers()
Check("the two days are the last two with prices, whatever lies between",
    List(movers.dropped) == "1" and movers.change[1] == -50 and List(movers.rose) == "7" and movers.change[7] == 100)
Check("and what moved before them is forgotten", movers.change[2] == nil and movers.price[3] == nil)

local q = World.Setup()
local Q = q.M.History
local first, second = {}, {}
for id = 1, 30 do
    first[id], second[id] = 10000, 10000 - id * 100
    first[100 + id], second[100 + id] = 10000, 10000 + id * 100
end
q.scan, q.scanAt = first, START
Q.Record()
q.scan, q.scanAt = second, START + DAY
Q.Record()
movers = Q.Movers()
Check("each list stops at its top few", q.M.C.MOVERS_TOP == 20 and #movers.dropped == 20 and #movers.rose == 20)
Check("which are the biggest moves, biggest first", movers.dropped[1] == 30 and movers.dropped[20] == 11
    and movers.rose[1] == 130 and movers.rose[20] == 111)
local kept = 0
for _ in pairs(movers.change) do kept = kept + 1 end
Check("and nothing is kept for the rest", kept == 40)

q = World.Setup()
Q = q.M.History
q.account.marketHistory = { ["Realm-Horde"] = { at = START + DAY, days = {
    [20000] = ",2770:1000,2589:200:9,",
    [20001] = { [2770] = 800, [2589] = 300 },
} } }
movers = Q.Movers()
Check("history saved before the counts still gives movers", List(movers.dropped) == "2770" and List(movers.rose) == "2589"
    and movers.change[2589] == 50)

q = World.Setup()
Q = q.M.History
q.scan, q.scanAt = { [1] = 1000, [2] = 1000 }, START
Q.Record()
q.now = START + DAY + 7200
q.scan = { [1] = 900, [2] = 1000 }
Q.Seen({ 1 }, 1)
q.scan, q.scanAt = { [1] = 900, [2] = 500 }, START + DAY + 3600
Check("prices from before the last sighting are still recorded, on the sighting's day",
    Q.Record() == true and Q.Change(2, 7) == -50 and Q.Change(1, 7) == -10)
Check("and only once", Q.Record() == false)
q.now = START + 2 * DAY
Q.Seen({ 1 }, 1)
q.scan, q.scanAt = { [1] = 100, [2] = 100 }, START + DAY + 7200
Check("but never on a later day than their own", Q.Record() == false and Q.Change(1, 7) == -10)

q = World.Setup()
Q = q.M.History
q.account.marketHistory = { ["Realm-Horde"] = { at = START, days = { [20000] = { [1] = 1000 } } } }
q.scan, q.scanAt = { [1] = 500 }, START
Check("history saved before sightings does not record its last prices again", Q.Record() == false)
q.now = START + 60
Q.Seen({ 1 }, 1)
Check("nor after a sighting", Q.Record() == false)

print("market movers: " .. checks .. " checks passed")
