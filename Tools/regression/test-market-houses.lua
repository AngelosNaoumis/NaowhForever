-- Run with Lua 5.1 from the repository root: the other auction house The Market reads beside yours (Houses.lua),
-- and the per-house data following the house you are at.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local START = 20000 * DAY + 3600

local t = World.Setup()
local Houses = t.M.Houses

Check("the other house is Blackwater, by its translated name", Houses.Name() == "Blackwater")
t.otherHouse = "Horde"
Check("at Blackwater it is your faction's, named by the game", Houses.Name() == "The Horde")
t.otherHouse = nil
Check("an item with no price there has none", Houses.Price(2589) == nil)
t.other, t.otherAt = { [2589] = 240 }, START
local price, at = Houses.Price(2589)
Check("its price and when it was read come from Auction Prices", price == 240 and at == START)

Check("the same price both ways gains nothing", Houses.Gain(100, 100) == nil)
Check("under a tenth more after the cut is not clearly higher", Houses.Gain(100, 109) == nil)
Check("a tenth more is, by what one makes after the cut each way", Houses.Gain(100, 111) == 105 - 95)
Check("clearly less there is a loss", Houses.Gain(200, 100) == 95 - 190)
Check("a copper against a copper is no gain", Houses.Gain(1, 1) == nil)
Check("the gain is exact to the copper, never rounded up", Houses.Gain(1001, 2003) == 1902 - 950)

t.ns.AuctionOtherPrice, t.ns.AuctionOtherHouse = nil, nil
Check("without Auction Prices there is no other house", Houses.Name() == nil and Houses.Price(2589) == nil)

local H = t.M.History
t.scan, t.scanAt = { [2770] = 100 }, START
H.Record()
Check("away from Blackwater, what a house keeps is your faction's", t.account.marketHistory["Realm-Horde"].days[20000][2770] == 100)
t.ns.AuctionHouseKey = function() return "Realm-Blackwater" end
t.scan, t.scanAt = { [2770] = 300 }, START + 600
H.Record()
Check("at Blackwater it is kept as Blackwater's, apart from your faction's",
    t.account.marketHistory["Realm-Blackwater"].days[20000][2770] == 300
    and t.account.marketHistory["Realm-Horde"].days[20000][2770] == 100)
Check("your characters are still told apart by realm and faction", t.M.HouseKey() == "Realm-Horde")

print("market houses: " .. checks .. " checks passed")
