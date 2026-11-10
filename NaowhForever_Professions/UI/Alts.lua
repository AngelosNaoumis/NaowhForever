-- Alts.lua: the Alts button on the profession window's title bar, with a menu of your other characters' professions.
local ns = _G.NaowhForever

local P = ns.Professions
local W = P.State
local Alts = P.Alts
local TitleButtons = P.TitleButtons

local OPEN_W, OPEN_H, OPEN_ORDER = 60, 22, 6
local TEXT_OPEN = ns.L("Alts")
local TEXT_TITLE = ns.L("Your Alts' Professions")
local TIP_OPEN_HELP = ns.L("Opens a profession of another of your characters on this realm.")
local TEXT_ENTRY = "%s - %s"

local opener

local function Who(alt)
    if ns.ClassColoredName then return ns.ClassColoredName(alt.who, alt.class) end
    return alt.who
end

local function Fill(_, root)
    root:CreateTitle(TEXT_TITLE)
    for _, alt in ipairs(Alts.List()) do
        root:CreateButton(TEXT_ENTRY:format(Who(alt), alt.prof), function() Alts.Open(alt) end)
    end
end

local function OpenMenu()
    ns.ContextMenu(opener, Fill)
end

local function PlaceOpener()
    local win = W.frame
    if not win then return end
    local on = Alts.On() and Alts.Any()
    if not opener then
        if not on then return end
        opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, OpenMenu)
        ns.Tooltip(opener, TEXT_TITLE, TIP_OPEN_HELP)
        opener:Hide()
        TitleButtons.Add(opener, OPEN_ORDER)
    end
    opener:SetShown(on)
end

hooksecurefunc(P.Window, "Render", PlaceOpener)
hooksecurefunc(P.Book, "Render", PlaceOpener)
