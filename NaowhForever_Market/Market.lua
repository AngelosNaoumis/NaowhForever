-- Market.lua: The Market's settings and its module table (ns.Market).
local ns = _G.NaowhForever

local F = ns.FEATURES.market
local REALM_JOIN = "-"
local DURATION_CVAR = "auctionHouseDurationDropdown"

local S = ns.UI.ModuleSettings("market", { enabled = F.enabled,
    duration = tonumber(C_CVar.GetCVarDefault(DURATION_CVAR)), openAtAuctioneer = true, postKeys = false,
    bagWorth = false,
    tooltip = true, tooltipStyle = "detailed", tooltipStack = "both", tooltipBest = false,
    farmHerbs = true, farmVeins = true, farmSkins = true, farmFish = true, farmLocked = false,
    sortRun = "", sortCrafts = "", sortMine = "", sortBuy = "", undercut = "step" })
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
    local key = Market.HouseKey()
    if not all[key] and create then all[key] = {} end
    return all[key]
end
