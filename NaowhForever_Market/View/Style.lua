-- Style.lua: The Market's own look, on top of the house look in Shared/Style.lua.
local ns = _G.NaowhForever

ns.Market.Style = setmetatable({
    WINDOW_W = 940,
    WINDOW_H = 600,
    TAB_W = 110,
    TITLE_SIZE = 16,
    COINS = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\coins.tga",
    QUEUE_W = 290,
    PANEL_FILL = 0.025,
    PICKED_FILL = 0.16,
    DISABLED_ALPHA = 0.45,
    BUTTON_H = 28,
    GOLD_RGB = { r = 1, g = 0.82, b = 0 },
    BADGE_TEXT_RGB = { r = 0.1, g = 0.075, b = 0 },
    HERB_RGB = { r = 0.36, g = 0.78, b = 0.36 },
    ORE_RGB = { r = 0.87, g = 0.6, b = 0.34 },
}, { __index = ns.Shared.Style })
