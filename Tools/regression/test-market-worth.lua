-- Run with Lua 5.1 from the repository root: The Market's price history and what your bags are worth.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local START = 20000 * DAY + 3600

local t = World.Setup({ vendor = { [2589] = 3, [4306] = 50, [6948] = 0 } })
local H = t.M.History

Check("no scan, nothing recorded", not H.Record())

t.scan, t.scanAt = { [2770] = 100, [2589] = 20 }, START
Check("a scan is recorded", H.Record())
Check("and only once", not H.Record())
t.scan, t.scanAt = { [2770] = 90 }, START + 600
H.Record()
t.scan, t.scanAt = { [2770] = 120 }, START + 1200
H.Record()
local house = t.account.marketHistory["Realm-Horde"]
Check("each day keeps its lowest price", house.days[20000][2770] == 90 and house.days[20000][2589] == 20)
Check("no change from one day alone", H.Change(2770, 7) == nil)

t.scan, t.scanAt = { [2770] = 99 }, START + DAY
H.Record()
local change, days = H.Change(2770, 7)
Check("a day later it is the change since yesterday", days == 1 and math.abs(change - 10) < 0.001)
Check("a past day is packed into one string", type(house.days[20000]) == "string"
    and type(house.days[20001]) == "table")

t.scan, t.scanAt = { [2770] = 45 }, START + 7 * DAY
H.Record()
change, days = H.Change(2770, 7)
Check("a week later it is the change over the week", days == 7 and math.abs(change + 50) < 0.001)
Check("an item missing today has no change", H.Change(2589, 7) == nil)

local series, found, last = H.Series(2770, {})
Check("the series is two weeks, oldest first, with gaps", #series == 14 and found == 3 and series[14] == 45
    and series[7] == 90 and series[8] == 99 and series[9] == false)
Check("and says which day its last one is", last == 20007)

t.scan, t.scanAt = { [2770] = 50 }, START + 14 * DAY
H.Record()
Check("days older than two weeks are dropped", house.days[20000] == nil and house.days[20001] ~= nil)

t.now = START + 14 * DAY + 60
t.scan = { [2770] = 40, [2589] = 7 }
H.Seen({ 2770, 2589, 4306 }, 2)
Check("a price seen at the auction house lowers its day without a scan", house.days[20014][2770] == 40
    and house.days[20014][2589] == 7 and house.days[20014][4306] == nil)
t.scan[2770] = 60
H.Seen({ 2770 }, 1)
Check("and a higher one leaves the day's lowest", house.days[20014][2770] == 40)
t.now = START + 15 * DAY
t.scan[2770] = 70
H.Seen({ 2770 }, 1)
series, found, last = H.Series(2770, {})
Check("a price seen on a later day starts that day, which is the chart's last", found == 3 and last == 20015 and series[14] == 70
    and series[13] == 40 and type(house.days[20014]) == "string")
t.scanAt = START + 14 * DAY + 30
Check("a scan from before the last price seen is not recorded over it", not H.Record())
t.scan, t.scanAt = { [2770] = 50 }, START + 14 * DAY

local W = t.M.Worth
t.scan = { [2770] = 100, [4306] = 400, [2589] = 2 }
t.bags[0] = {
    World.Stack(2770, 20),
    World.Stack(2589, 10),
    World.Stack(2770, 5),
    World.Stack(4306, 2, { isBound = true }),
    World.Stack(6948, 1),
    World.Stack(5000, 1, { hasNoValue = true }),
}
local items = W.Read()
Check("stacks of one item are counted together", items[1].itemID == 2770 and items[1].count == 25)
Check("the auction price is taken after the cut when it beats the vendor", items[1].each == 95 and items[1].auction)
Check("a bound item counts at its vendor price", items[2].itemID == 4306 and items[2].each == 50
    and not items[2].auction)
Check("the vendor wins when the auction pays less", items[3].itemID == 2589 and items[3].each == 3)
Check("worthless items are left out", #items == 3)
Check("the bags' total", W.total == 25 * 95 + 2 * 50 + 10 * 3 and W.auction == 25 * 95)
Check("the most valuable is first", W.Rank(2770) == 1 and W.Rank(2589) == 3 and W.Rank(6948) == nil)
Check("the rank is drawn on its first slot only", W.First(2770, 0, 1) and not W.First(2770, 0, 3))

t.bags[0] = { World.Stack(2589, 4) }
items = W.Read()
Check("reading again starts over", #items == 1 and items[1].count == 4 and W.Rank(2770) == nil
    and W.total == 12)

local best, margin, second, complete = W.Best(10, 95, false)
Check("the auction house after its cut beats a vendor", best == "auction" and margin == 85 and second == "vendor"
    and complete)
best, margin, second = W.Best(95, 95, false)
Check("a vendor wins a tie with the auction house", best == "vendor" and margin == 0 and second == "auction")
best, margin, second, complete = W.Best(20, 95, 120)
Check("disenchanting wins when its materials fetch more", best == "disenchant" and margin == 25
    and second == "auction" and complete)
best = W.Best(0, 95, 95)
Check("the auction house wins a tie with disenchanting", best == "auction")
best, margin, second, complete = W.Best(20, false, 50)
Check("a bound item weighs only a vendor and disenchanting, and says so in full", best == "disenchant"
    and margin == 30 and second == "vendor" and complete)
best, margin, second, complete = W.Best(20, nil, 50)
Check("with no auction price the verdict is only what it beat", best == "disenchant" and margin == 30
    and second == "vendor" and complete == false)
best, margin, second, complete = W.Best(20, 95, nil)
Check("an unpriced disenchant leaves the verdict partial", best == "auction" and margin == 75
    and second == "vendor" and complete == false)
Check("one priced way to sell is no verdict", W.Best(5, nil, false) == nil and W.Best(0, 95, false) == nil
    and W.Best(nil, nil, nil) == nil)

local S = t.M.Settings
S.Set("tooltipBestMargin", 0)
best, margin, second = W.Best(94, 95, false)
Check("with no margin a copper over the vendor is enough", best == "auction" and margin == 1 and second == "vendor")
S.Set("tooltipBestMargin", 10)
best, margin, second, complete = W.Best(90, 95, false)
Check("under the margin the vendor is best, and the auction's lead shows as less than nothing",
    best == "vendor" and margin == -5 and second == "auction" and complete)
best, margin, second = W.Best(85, 95, false)
Check("exactly the margin is still the vendor's", best == "vendor" and margin == -10 and second == "auction")
best, margin, second = W.Best(84, 95, false)
Check("past the margin the auction house wins by its whole lead", best == "auction" and margin == 11
    and second == "vendor")
best, margin, second = W.Best(95, 95, false)
Check("a tie is still the vendor's", best == "vendor" and margin == 0 and second == "auction")
best, margin, second = W.Best(90, 95, 92)
Check("an auction held under the margin falls below a disenchant that beats the vendor", best == "disenchant"
    and margin == 2 and second == "vendor")
best, margin, second = W.Best(20, 95, 90)
Check("the margin weighs only the vendor, not disenchanting", best == "auction" and margin == 5
    and second == "disenchant")
best, margin, second = W.Best(0, 5, 3)
Check("with no vendor price there is no margin to meet", best == "auction" and margin == 2
    and second == "disenchant")
best, margin, second, complete = W.Best(90, 95, nil)
Check("an unpriced disenchant still leaves the vendor's verdict partial", best == "vendor" and margin == -5
    and second == "auction" and complete == false)
S.Set("tooltipBestMargin", 0)

local q = World.Setup()
local Q = q.M.History
q.scan, q.listed, q.scanAt = { [2770] = 100, [2589] = 20 }, { [2770] = 300 }, START
Q.Record()
local kept = q.account.marketHistory["Realm-Horde"]
Check("a scan keeps how many were listed that day, where it is known", kept.listed[20000][2770] == 300
    and kept.listed[20000][2589] == nil)
q.scan, q.listed, q.scanAt = { [2770] = 120 }, { [2770] = 250 }, START + 600
Q.Record()
Check("a later scan the same day keeps the day's lowest price and the newer count", kept.days[20000][2770] == 100
    and kept.listed[20000][2770] == 250)
q.now = START + 900
q.scan, q.listed = { [2770] = 90, [2589] = 20 }, { [2770] = 240, [2589] = 8 }
Q.Seen({ 2770, 2589 }, 2)
Check("a price seen at the auction house brings its count", kept.days[20000][2770] == 90
    and kept.listed[20000][2770] == 240 and kept.listed[20000][2589] == 8)
q.listed = {}
Q.Seen({ 2770 }, 1)
Check("and one seen without a count leaves the day's", kept.listed[20000][2770] == 240)
q.scan, q.listed, q.scanAt = { [2770] = 95, [4306] = 7 }, { [2770] = 10 }, START + DAY
Q.Record()
Check("a past day is packed with its counts, and without where there was none",
    kept.days[20000]:find(",2770:90:240,", 1, true) and kept.days[20000]:find(",2589:20:8,", 1, true)
    and kept.listed[20000] == nil and kept.listed[20001][2770] == 10)
local prices, counts = {}, {}
Q.Series(2770, prices, counts)
Check("the series gives each day's count beside its price", prices[13] == 90 and counts[13] == 240
    and prices[14] == 95 and counts[14] == 10 and counts[12] == false)
Q.Series(4306, prices, counts)
Check("and no count for a price that had none", prices[14] == 7 and counts[14] == false)
Check("the series without a count list is as it was", #Q.Series(2770, {}) == 14)
q.scan, q.listed, q.scanAt = { [2770] = 95 }, {}, START + 15 * DAY
Q.Record()
Check("a day's counts go when its prices do", kept.days[20000] == nil and kept.days[20001] == nil
    and kept.listed[20001] == nil)

q = World.Setup()
Q = q.M.History
q.account.marketHistory = { ["Realm-Horde"] = { at = START + DAY, days = {
    [20000] = ",2770:100,2589:20,",
    [20001] = { [2770] = 110 },
} } }
Q.Series(2770, prices, counts)
Check("history saved before the counts reads as it did, with no counts", prices[13] == 100 and prices[14] == 110
    and counts[13] == false and counts[14] == false)
local moved, ago = Q.Change(2770, 7)
Check("and still gives the change", ago == 1 and math.abs(moved - 10) < 0.001)
q.scan, q.listed, q.scanAt = { [2770] = 105, [27701] = 1 }, { [2770] = 44 }, START + 2 * DAY
Q.Record()
kept = q.account.marketHistory["Realm-Horde"]
Q.Series(2770, prices, counts)
Check("a new scan adds to it without dropping a day", prices[12] == 100 and prices[13] == 110 and prices[14] == 105
    and counts[14] == 44 and kept.days[20001] == ",2770:110,")
Q.Series(27701, prices, counts)
Check("an item whose ID starts with another's is not read as it", prices[14] == 1 and prices[13] == false)
Q.Series(277, prices, counts)
Check("nor one whose ID another's starts with", prices[14] == false and prices[12] == false)

q = World.Setup()
Q = q.M.History
Check("with no history there is no average", Q.Average(2770, 7) == nil)
q.scan, q.scanAt = { [2770] = 100, [2589] = 7 }, START
Q.Record()
q.scan, q.scanAt = { [2770] = 101 }, START + DAY
Q.Record()
Check("nor from two days of prices", q.M.C.AVERAGE_MIN_DAYS == 3 and Q.Average(2770, 7) == nil)
q.scan, q.scanAt = { [2770] = 104 }, START + 2 * DAY
Q.Record()
local average, over = Q.Average(2770, 7)
Check("three days give the average of each day's lowest, to the nearest copper", average == 102 and over == 3)
Check("an item priced on fewer of them has none", Q.Average(2589, 7) == nil)
q.scan, q.scanAt = { [2770] = 110 }, START + 3 * DAY
Q.Record()
average, over = Q.Average(2770, 7)
Check("a new day's price moves it", average == 104 and over == 4)
q.now = START + 3 * DAY + 60
q.scan[2770] = 90
Q.Seen({ 2770 }, 1)
Check("a lower price seen the same day moves it too", Q.Average(2770, 7) == 99)
Check("a shorter window counts only its days", Q.Average(2770, 3) == 98 and Q.Average(2770, 2) == nil)
q.scan, q.scanAt = { [2770] = 120 }, START + 10 * DAY
Q.Record()
Check("days older than the window drop out, here leaving too few", Q.Average(2770, 7) == nil)
q.scan, q.scanAt = { [2770] = 130 }, START + 11 * DAY
Q.Record()
q.scan, q.scanAt = { [2770] = 141 }, START + 12 * DAY
Q.Record()
average, over = Q.Average(2770, 7)
Check("and it comes back with three days inside it", average == 130 and over == 3)

print("market worth: " .. checks .. " checks passed")
