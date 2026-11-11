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

print("market worth: " .. checks .. " checks passed")
