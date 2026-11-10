-- Run with Lua 5.1 from the repository root: Prices for Other Addons, Auctionator's price API answered from
-- Auction Prices while Auctionator is not installed.
local Load = dofile("Tools/regression/load_files.lua")
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local NOW = 100 * DAY
local HERB, OLD, GEAR, TRADE, DUST, NEW = 10, 20, 30, 40, 11, 50
local ARMOR, TRADE_GOODS = 4, 7
local GUID = "Player-1-00000001"
local reported = {}

local function Setup(on, opts)
    opts = opts or {}
    local values = { ahShare = on }
    local S = { Get = function(key) return values[key] end }
    function S.Set(key, value) values[key] = value end
    local prices = { [HERB] = { 150, NOW - 2 * DAY - 5 }, [OLD] = { 90, NOW - 22 * DAY },
        [GEAR] = { 5000, NOW }, [DUST] = { 400, NOW }, [NEW] = { 60, NOW + 30 } }
    local ns = {
        QoLSettings = S,
        QoLConstants = { SECONDS_PER_DAY = DAY },
        AuctionPrice = function(id)
            local p = id and prices[id]
            if p then return p[1], p[2] end
        end,
        AuctionPriceList = function()
            local list = {}
            for id, p in pairs(prices) do list[id] = p[1] end
            return list
        end,
        Apply = function() end,
    }
    if opts.professions ~= false then
        ns.Professions = {
            Vendors = { Price = function(id) return id == TRADE and 25 or nil end },
            DisenchantValues = {
                ItemTakes = function(id) return id == GEAR end,
                Expected = function(_, _, level, list) return level * 10 + list[DUST], "outcomes" end,
            },
        }
    end
    local env = setmetatable({
        NaowhForever = ns,
        Auctionator = opts.existing,
        GetServerTime = function() return NOW end,
        UnitGUID = function() return GUID end,
        geterrorhandler = function() return function(message) reported[#reported + 1] = message end end,
        Enum = { ItemClass = { Weapon = 2, Armor = ARMOR } },
        C_AddOns = {
            DoesAddOnExist = function(name) return name == "Auctionator" and opts.installed ~= nil end,
            IsAddOnLoadable = function(name, character)
                assert(character == GUID, "asks for this character")
                return name == "Auctionator" and opts.installed == true
            end,
        },
        C_Item = {
            GetItemInfoInstant = function(item)
                local id = type(item) == "number" and item or tonumber(item:match("item:(%d+)"))
                return id, nil, nil, nil, nil, id == GEAR and ARMOR or TRADE_GOODS
            end,
            GetItemInfo = function(item)
                if item == GEAR or type(item) == "string" and item:match("item:30") then
                    return "Gear", "|Hitem:30|h[Gear]|h", 2, 25, nil, nil, nil, nil, "INVTYPE_CHEST", nil, nil, ARMOR
                end
            end,
            GetDetailedItemLevelInfo = function() return 27 end,
        },
        hooksecurefunc = function(target, key, hook)
            local original = target[key]
            target[key] = function(...)
                original(...)
                hook(...)
            end
        end,
    }, { __index = _G })
    env._G = env
    Load({ "NaowhForever_QoL/Loot/PriceShare.lua" }, env)
    return env, ns, S
end

local function Fails(fn, ...)
    local ok, message = pcall(fn, ...)
    return not ok and message
end

local env, ns, S = Setup(true)
local api = env.Auctionator and env.Auctionator.API and env.Auctionator.API.v1
Check("on, with no Auctionator installed, Auctionator.API.v1 is there", api ~= nil)
Check("price by item ID is Auction Prices' price", api.GetAuctionPriceByItemID("Test", HERB) == 150)
Check("price by link reads the link's item", api.GetAuctionPriceByItemLink("Test", "|Hitem:10::::|h[Herb]|h") == 150)
Check("an item with no price has none", api.GetAuctionPriceByItemID("Test", 999) == nil)
Check("age is whole days since the price", api.GetAuctionAgeByItemID("Test", HERB) == 2)
Check("age by link too", api.GetAuctionAgeByItemLink("Test", "|Hitem:10|h[Herb]|h") == 2)
Check("no age past 21 days, though the price stays", api.GetAuctionAgeByItemID("Test", OLD) == nil
    and api.GetAuctionPriceByItemID("Test", OLD) == 90)
Check("no age without a price", api.GetAuctionAgeByItemID("Test", 999) == nil)
Check("a price stamped a little ahead of the realm's clock is today's, not -1 days",
    api.GetAuctionAgeByItemID("Test", NEW) == 0)
Check("a priced item is exact", api.IsAuctionDataExactByItemID("Test", HERB) == true
    and api.IsAuctionDataExactByItemLink("Test", "|Hitem:10|h[Herb]|h") == true)
Check("an unpriced one is not", api.IsAuctionDataExactByItemID("Test", 999) == false)
Check("a gear link is never exact: its price is the item's, not that link's",
    api.IsAuctionDataExactByItemLink("Test", "|Hitem:30::::::1234|h[Gear]|h") == false
    and api.IsAuctionDataExactByItemID("Test", GEAR) == true)
Check("the setting can be turned on while Auctionator is not installed", ns.PriceShareFree() == true)
Check("vendor price is Professions' merchant price", api.GetVendorPriceByItemID("Test", TRADE) == 25
    and api.GetVendorPriceByItemLink("Test", "|Hitem:40|h[Cloth]|h") == 25)
Check("an item no merchant sells has no vendor price", api.GetVendorPriceByItemID("Test", HERB) == nil)
Check("disenchant price is the expected value at its item level",
    api.GetDisenchantPriceByItemLink("Test", "|Hitem:30|h[Gear]|h") == 27 * 10 + 400)
Check("by item ID too", api.GetDisenchantPriceByItemID("Test", GEAR) == 27 * 10 + 400)
Check("an item that cannot be disenchanted has none", api.GetDisenchantPriceByItemID("Test", HERB) == nil)

local message = Fails(api.GetAuctionPriceByItemID, nil, HERB)
Check("a missing callerID is an error naming the call", message and message:find("GetAuctionPriceByItemID", 1, true))
message = Fails(api.GetAuctionPriceByItemID, "Test", "10")
Check("an item ID that is not a number is an error", message and message:find("itemID must be a number", 1, true))
message = Fails(api.GetAuctionPriceByItemLink, "Test", 10)
Check("a link that is not a string is an error", message and message:find("itemLink must be a string", 1, true))
message = Fails(api.RegisterForDBUpdate, "Test", "callback")
Check("a callback that is not a function is an error", message and message:find("callback must be a function", 1, true))

local fired = 0
api.RegisterForDBUpdate("Test", function() fired = fired + 1 end)
ns.AuctionPricesChanged()
Check("a registered callback runs when the prices change", fired == 1)
api.RegisterForDBUpdate("Broken", function() error("broken callback") end)
local after = 0
api.RegisterForDBUpdate("After", function() after = after + 1 end)
ns.AuctionPricesChanged()
Check("a callback that errors is reported, and the ones after it still run",
    fired == 2 and after == 1 and #reported == 1 and reported[1]:find("broken callback", 1, true))

S.Set("ahShare", false)
Check("turning it off clears the global", env.Auctionator == nil)
ns.AuctionPricesChanged()
Check("and callbacks no longer run", fired == 2)
Check("an addon that kept the API table gets nothing from it either",
    api.GetAuctionPriceByItemID("Test", HERB) == nil and api.GetAuctionAgeByItemID("Test", HERB) == nil
    and api.IsAuctionDataExactByItemID("Test", HERB) == false and api.GetVendorPriceByItemID("Test", TRADE) == nil
    and api.GetDisenchantPriceByItemID("Test", GEAR) == nil)
S.Set("ahShare", true)
Check("turning it back on sets the same table", env.Auctionator and env.Auctionator.API.v1 == api)
ns.AuctionPricesChanged()
Check("with its callbacks", fired == 3)
Check("and its prices", api.GetAuctionPriceByItemID("Test", HERB) == 150)

env, ns, S = Setup(false)
Check("off by default, nothing is set", env.Auctionator == nil)
S.Set("ahShare", true)
Check("a click turns it on", env.Auctionator ~= nil)
S.Set("ahShare", false)
S.Get = function(key) return key == "ahShare" end
ns.Apply()
Check("a profile with it on turns it on", env.Auctionator ~= nil)

env, ns = Setup(true, { installed = true })
Check("not set while Auctionator is installed and enabled", env.Auctionator == nil)
Check("and the setting says it cannot be turned on", ns.PriceShareFree() == false)

env = Setup(true, { installed = false })
Check("set while Auctionator is installed but disabled", env.Auctionator ~= nil)

local theirs = { API = { v1 = {} } }
env, ns, S = Setup(true, { existing = theirs })
Check("someone else's Auctionator is left alone", env.Auctionator == theirs)
Check("and a scan finishing beside it is fine", pcall(ns.AuctionPricesChanged))
S.Set("ahShare", false)
Check("and turning it off does not clear theirs", env.Auctionator == theirs)

env = Setup(true, { professions = false })
api = env.Auctionator.API.v1
Check("without Professions there is no vendor price", api.GetVendorPriceByItemID("Test", TRADE) == nil)
Check("or disenchant price", api.GetDisenchantPriceByItemID("Test", GEAR) == nil)
Check("but the auction price still answers", api.GetAuctionPriceByItemID("Test", HERB) == 150)

print("price share: " .. checks .. " checks passed")
