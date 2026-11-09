-- Reagents.lua: the Reagents page: Professions' Reagents list, what each reagent in your bags makes and whether to craft or sell it.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style

local HEAD_H, SUB_GAP, SEARCH_W, LIST_GAP = 44, 4, 260, 8
local ROSTER = "marketCharacters"
local TEXT_TITLE = ns.L("Reagents")
local TEXT_SUB = ns.L("What the reagents in your bags make, and whether crafting beats selling them")
local TEXT_SEARCH = ns.L("Search any reagent")
local TEXT_NO_PROF = ns.L("Turn on Professions: the Reagents page reads its recipes.")

local page, list

local Page = {}
Market.Pages.reagents = Page

local function AltName(guid)
    local alt = (ns.AccountSettings()[ROSTER] or {})[guid]
    return alt and alt.house == Market.HouseKey() and alt.name or nil
end

local function OnSearch(text)
    list:Search(text)
end

local function BuildHeader()
    local title = ns.Font(page, St.TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT")
    title:SetText(TEXT_TITLE)
    local sub = ns.Font(page, St.SMALL_SIZE, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    sub:SetText(TEXT_SUB)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildHeader()
    local P = ns.Professions
    if not (P and P.On() and P.ReagentList) then
        local off = ns.Font(page, St.TEXT_SIZE, nil, T.muted)
        off:SetPoint("TOP", 0, -(HEAD_H + HEAD_H))
        off:SetText(TEXT_NO_PROF)
        return
    end
    local search = ns.Shared.Parts.SearchBox(page, TEXT_SEARCH, OnSearch)
    search:SetSize(SEARCH_W, St.SEARCH_H)
    search:SetPoint("TOPRIGHT")
    list = P.ReagentList.New(page)
    list.altName = AltName
    list:SetPoint("TOPLEFT", 0, -(HEAD_H + LIST_GAP))
    list:SetPoint("BOTTOMRIGHT")
end

function Page.Show()
    page:Show()
end

function Page.Hide()
    page:Hide()
end
