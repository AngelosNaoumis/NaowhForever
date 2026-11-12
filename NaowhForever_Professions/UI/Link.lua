-- Link.lua: the Link button on the profession window's title bar, with a menu that posts your profession's trade link in chat.
local ns = _G.NaowhForever

local P = ns.Professions
local W = P.State
local R = P.Recipes
local TitleButtons = P.TitleButtons
local Parts = ns.Shared.Parts

local OPEN_W, OPEN_H, OPEN_ORDER = 50, 22, 7
local TEXT_OPEN = ns.L("Link")

local opener

local function OpenMenu()
    Parts.ShareMenu(opener, TRADESKILL_POST, C_TradeSkillUI.GetTradeSkillListLink, nil, nil, true)
end

local function PlaceOpener()
    local win = W.frame
    if not win then return end
    local on = R.Own() and R.Profession() ~= nil and C_TradeSkillUI.CanTradeSkillListLink()
    if not opener then
        if not on then return end
        opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, OpenMenu)
        ns.Tooltip(opener, TEXT_OPEN, LINK_TRADESKILL_TOOLTIP)
        opener:Hide()
        TitleButtons.Add(opener, OPEN_ORDER)
    end
    opener:SetShown(on)
end

local function HideOpener()
    if opener then opener:Hide() end
end

hooksecurefunc(P.Window, "Render", PlaceOpener)
hooksecurefunc(P.Book, "Render", HideOpener)
