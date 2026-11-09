-- ReagentsWindow.lua: the Reagents window and its button beside Shopping List on the profession window.
local ns = _G.NaowhForever

local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local P = ns.Professions
local S = P.Settings
local W = P.State
local TitleButtons = P.TitleButtons

local PAGE = "Professions/Settings"
local WIDTH, HEIGHT = 460, 540
local MIN_W, MIN_H = 380, 320
local HEADER, PAD, FOOTER = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER
local INSET = St.CONTENT_INSET
local CARD_INSET = 6
local OPEN_W, OPEN_H, OPEN_ORDER = 80, 22, 3
local SETTINGS = { enabled = true, shoppingList = true, reagentUses = true }
local TEXT_TITLE = ns.L("Reagents")
local TEXT_SUBTITLE = ns.L("What your reagents make, and whether to craft or sell them.")
local TEXT_SEARCH = ns.L("Search any reagent")
local TEXT_OFF = ns.L("Turn on Reagents in the Professions settings first.")
local TIP_OPEN_HELP = ns.L("Lists your reagents, what each one makes and whether to craft or sell it.")

local window, list, opener

local function On()
    return S.Get("enabled") and S.Get("shoppingList") and S.Get("reagentUses")
end

local function OnSearch(text)
    list:Search(text)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "reagentsWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    Parts.FooterBrand(window, PAGE)
    local search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    search:SetHeight(St.SEARCH_H)
    search:SetPoint("TOPLEFT", INSET, -(HEADER + PAD))
    search:SetPoint("TOPRIGHT", -INSET, -(HEADER + PAD))
    list = P.ReagentList.New(window)
    list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -PAD)
    list:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    Parts.Resizable(window, "reagents", MIN_W, MIN_H)
end

function ns.OpenReagents()
    if not On() then return ns.Print(TEXT_OFF) end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
end

function ns.ToggleReagents()
    if window and window:IsShown() then window:Hide() else ns.OpenReagents() end
end

local function PlaceOpener()
    local win = W.frame
    if not win then return end
    local on = On()
    if not opener then
        if not on then return end
        opener = ns.Button(win, TEXT_TITLE, OPEN_W, OPEN_H, ns.ToggleReagents)
        ns.Tooltip(opener, TEXT_TITLE, TIP_OPEN_HELP)
        opener:Hide()
        TitleButtons.Add(opener, OPEN_ORDER)
    end
    opener:SetShown(on and true or false)
end

hooksecurefunc(P.Window, "Render", PlaceOpener)

S.OnChange(function(key)
    if SETTINGS[key] and window and not On() then window:Hide() end
end)
