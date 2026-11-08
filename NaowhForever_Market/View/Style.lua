-- Style.lua: The Market's own look, on top of the house look in Shared/Style.lua.
local ns = _G.NaowhForever

ns.Market.Style = setmetatable({
    WINDOW_W = 940,
    WINDOW_H = 600,
    TABS_W = 330,
    QUEUE_W = 290,
    PANEL_FILL = 0.025,
    PICKED_FILL = 0.16,
    DISABLED_ALPHA = 0.45,
    BUTTON_H = 28,
    GOLD_RGB = { r = 1, g = 0.82, b = 0 },
}, { __index = ns.Shared.Style })
