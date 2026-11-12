-- Style.lua: The Market's own look, on top of the house look in Shared/Style.lua.
local ns = _G.NaowhForever

ns.Market.Style = setmetatable({
    WINDOW_W = 1144,
    WINDOW_H = 650,
    TITLE_SIZE = 16,
    COINS = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\coins.tga",
    QUEUE_W = 290,
    DOCK_W = 380,
    DOCK_PAD = 10,
    PANEL_FILL = 0.025,
    PICKED_FILL = 0.16,
    DISABLED_ALPHA = 0.45,
    BUTTON_H = 28,
    GOLD_RGB = { r = 1, g = 0.82, b = 0 },
    BADGE_TEXT_RGB = { r = 0.1, g = 0.075, b = 0 },
    HERB_RGB = { r = 0.36, g = 0.78, b = 0.36 },
    ORE_RGB = { r = 0.87, g = 0.6, b = 0.34 },
    SKIN_RGB = { r = 0.69, g = 0.52, b = 0.87 },
    FISH_RGB = { r = 0.45, g = 0.62, b = 0.98 },
}, { __index = ns.Shared.Style })

-- Faded, a primary button's dark label on its blue can't be read, so it turns light.
function ns.Market.Style.Enable(button, on)
    button:SetEnabled(on)
    button:SetAlpha(on and 1 or ns.Market.Style.DISABLED_ALPHA)
    if button._primary then
        local c = on and ns.THEME.bg or ns.THEME.fg
        button.label:SetTextColor(c.r, c.g, c.b, 1)
    end
end
