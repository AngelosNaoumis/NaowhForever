-- Market.lua: The Market's settings and its module table (ns.Market).
local ns = _G.NaowhForever

local F = ns.FEATURES.market
local REALM_JOIN = "-"
local DURATION_CVAR = "auctionHouseDurationDropdown"

local S = ns.UI.ModuleSettings("market", { enabled = F.enabled,
    duration = tonumber(C_CVar.GetCVarDefault(DURATION_CVAR)), postKeys = false, askBadPost = true,
    bagWorth = false, bagWorthBank = false,
    aheadAllowed = 0,
    tooltip = true, tooltipStyle = "detailed", tooltipStack = "both", tooltipShift = false, tooltipBest = false, tooltipBestMargin = 0,
    tooltipOther = false, tooltipMail = false, tooltipAverage = false,
    farmHerbs = true, farmVeins = true, farmSkins = true, farmFish = true, farmLocked = false, farmPlan = false,
    sortRun = "", sortCrafts = "", sortMine = "", undercut = "step", undercutPercent = 5, undercutAmount = 100,
    startingBid = false, watchAlerts = true,
    sellQuantityTrade = 0, sellQuantityConsumable = 0, sellQuantityRecipe = 0, sellQuantityOther = 0,
    sellNumberTrade = 20, sellNumberConsumable = 20, sellNumberRecipe = 20, sellNumberOther = 20 })
ns.MarketSettings = S

local Market = { Settings = S }
ns.Market = Market

function Market.On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end

function Market.AfterCut(price)
    return math.floor(price * (1 - Market.C.AH_CUT))
end

function Market.HouseKey()
    return GetRealmName() .. REALM_JOIN .. (UnitFactionGroup("player") or "")
end

function Market.HouseData(store, create)
    local account = ns.AccountSettings()
    local all = account[store]
    if not all then
        if not create then return end
        all = {}
        account[store] = all
    end
    local key = ns.AuctionHouseKey and ns.AuctionHouseKey() or Market.HouseKey()
    if not all[key] and create then all[key] = {} end
    return all[key]
end
