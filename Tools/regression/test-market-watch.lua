-- Run with Lua 5.1 from the repository root: The Market's watch list. Items are added and removed, the list is capped,
-- a scan tells you once about each watched item at or under your price and never about one above it, a listing search
-- tells you once per price, and Watch Alerts off keeps it quiet.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local settings = { watchAlerts = true }
local account = {}
local prices = {}
local printed = {}

local ns = {
    L = function(s) return s end,
    AccountSettings = function() return account end,
    AuctionPrice = function(id) return prices[id] end,
    Print = function(msg) printed[#printed + 1] = msg end,
    Shared = {
        Items = { Name = function(id) return "Item " .. id end },
        Parts = { Coins = function(copper) return tostring(copper) end },
    },
    Market = { Settings = { Get = function(key) return settings[key] end } },
}

local fn = assert(loadfile("NaowhForever_Market/Watch.lua"))
setfenv(fn, setmetatable({
    _G = { NaowhForever = ns },
    C_Item = { GetItemInfo = function() return nil end },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G }))
fn()
local Watch = ns.Market.Watch

check("nothing is watched at first", Watch.Count() == 0 and Watch.UnderCount() == 0)
check("a price of nothing is not watched", Watch.Set(1, 0) == false and Watch.Count() == 0)
check("an item is watched at its price", Watch.Set(1, 500) == true and Watch.Target(1) == 500)
check("the list is kept for the account", account.marketWatch[1] == 500)
check("watching it again changes its price", Watch.Set(1, 400) and Watch.Target(1) == 400 and Watch.Count() == 1)

prices[1] = 450
check("above your price it is not under", not Watch.Under(1) and Watch.UnderCount() == 0)
check("a scan says nothing about an item above your price", Watch.Scanned() == 0 and #printed == 0)

prices[1] = 400
check("at your price it counts as under", Watch.Under(1) and Watch.UnderCount() == 1)
check("a scan tells you once about it", Watch.Scanned() == 1 and #printed == 1)
check("the line names the item and both prices", printed[1]:find("Item 1", 1, true) and printed[1]:find("400", 1, true))
check("the next scan tells you again", Watch.Scanned() == 1 and #printed == 2)

Watch.Set(2, 100)
prices[2] = 90
prices[1] = 999
local list = Watch.Items({})
check("an item under your price lists before one above it", list[1] == 2 and list[2] == 1)

check("a listing at your price tells you", Watch.Listed(2, 95) == true and #printed == 3)
check("the same listing price does not tell you twice", Watch.Listed(2, 95) == false and #printed == 3)
check("a lower listing price tells you again", Watch.Listed(2, 80) == true and #printed == 4)
check("a listing above your price says nothing", Watch.Listed(2, 150) == false and #printed == 4)
check("a listing of an item you do not watch says nothing", Watch.Listed(3, 1) == false)

settings.watchAlerts = false
check("with Watch Alerts off a scan is quiet", Watch.Scanned() == 0 and #printed == 4)
check("and so is a listing", Watch.Listed(2, 10) == false and #printed == 4)
settings.watchAlerts = true

Watch.Remove(2)
check("an item can be taken off", Watch.Target(2) == nil and Watch.Count() == 1)

for id = 100, 100 + Watch.MAX do Watch.Set(id, 1) end
check("the list stops at its cap", Watch.Count() == Watch.MAX)
check("a new item past the cap is refused", Watch.Set(5000, 1) == false and Watch.Target(5000) == nil)
check("an item already on a full list can still change its price", Watch.Set(1, 7) == true and Watch.Target(1) == 7)

print(("test-market-watch: %d checks passed"):format(checks))
