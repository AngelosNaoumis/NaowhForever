-- Market.lua: The Market's settings and its module table (ns.Market).
local ns = _G.NaowhForever

local F = ns.FEATURES.market

local S = ns.UI.ModuleSettings("market", { enabled = F.enabled, duration = 1, postKeys = true })
ns.MarketSettings = S

local Market = { Settings = S }
ns.Market = Market

function Market.On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end
