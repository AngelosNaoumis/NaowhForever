-- BrowseBar.lua: the Browse screen's bar: the dungeon menu (your level, every dungeon or one, each a search), then a text filter and the sort (ns.GroupFinder.UI.BrowseBar).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local S = GF.Settings
local Listings, Search = GF.Listings, GF.Search
local Parts = ns.Shared.Parts

local St = UI.Style
local FILTER_GAP, SEARCH_H = St.FILTER_GAP, St.SEARCH_H
local MENU_H = 400

local TEXT_LEVEL, TEXT_ALL = ns.L("For your level"), ns.L("All")
local TEXT_DUNGEON = "%s %d-%d"
local TEXT_PICK = ns.L("Dungeon: %s")
local TEXT_FILTER = "Filter by dungeon, leader or note"
local SORTS = { { "newest", "Newest" }, { "score", "Gear Score" }, { "level", "Level" } }
local TEXT_SORT = ns.L("Sort: %s")
local SORT_LABELS = {}
for _, sort in ipairs(SORTS) do SORT_LABELS[sort[1]] = TEXT_SORT:format(ns.L(sort[2])) end

local activities = {}
local bar

local function DungeonText(id)
    local activity = Listings.Activity(id)
    return activity.max > 0 and TEXT_DUNGEON:format(activity.short, activity.min, activity.max) or activity.short
end

local function PickText(pick)
    if pick == Search.LEVEL then return TEXT_LEVEL end
    if pick == Search.ALL then return TEXT_ALL end
    return DungeonText(pick)
end

local function Paint()
    Parts.SetLink(bar.dungeon, TEXT_PICK:format(PickText(Search.pick)))
    Parts.SetLink(bar.sort, SORT_LABELS[S.Get("sort")] or SORT_LABELS.newest)
end

local function IsPick(pick)
    return Search.pick == pick
end

local function SetPick(pick)
    if Search.Run(pick) then Paint() end
end

local function DungeonMenu(_, root)
    root:SetScrollMode(MENU_H)
    root:CreateTitle(ns.L("Dungeon"))
    root:CreateRadio(TEXT_LEVEL, IsPick, SetPick, Search.LEVEL)
    root:CreateRadio(TEXT_ALL, IsPick, SetPick, Search.ALL)
    root:CreateDivider()
    for i = 1, Search.Activities(activities) do
        local id = activities[i]
        local text = DungeonText(id)
        root:CreateRadio(Search.Suits(id) and text or ns.Color("muted", text), IsPick, SetPick, id)
    end
end

local function DungeonClicked(link)
    MenuUtil.CreateContextMenu(link, DungeonMenu)
end

local function Filtered(text)
    bar.needle = text:lower()
    bar.onChange()
end

local function IsSort(key)
    return S.Get("sort") == key
end

local function SetSort(key)
    S.Set("sort", key)
end

local function SortMenu(_, root)
    root:CreateTitle(ns.L("Sort by"))
    for _, sort in ipairs(SORTS) do root:CreateRadio(ns.L(sort[2]), IsSort, SetSort, sort[1]) end
end

local function SortClicked(link)
    MenuUtil.CreateContextMenu(link, SortMenu)
end

function UI.BrowseBar(parent, onChange)
    bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(UI.CONTENT_W, SEARCH_H)
    bar.needle, bar.onChange = "", onChange
    bar.dungeon = Parts.Link(bar, DungeonClicked, true)
    bar.dungeon:SetPoint("LEFT")
    bar.sort = Parts.Link(bar, SortClicked, true)
    bar.sort:SetPoint("RIGHT")
    bar.search = Parts.SearchBox(bar, TEXT_FILTER, Filtered)
    bar.search:SetHeight(SEARCH_H)
    bar.search:SetPoint("LEFT", bar.dungeon, "RIGHT", FILTER_GAP, 0)
    bar.search:SetPoint("RIGHT", bar.sort, "LEFT", -FILTER_GAP, 0)
    bar.Paint = Paint
    return bar
end

S.OnChange(function(key)
    if key == "sort" and bar then
        Parts.SetLink(bar.sort, SORT_LABELS[S.Get("sort")] or SORT_LABELS.newest)
        bar.onChange()
    end
end)
