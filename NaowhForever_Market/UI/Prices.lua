-- Prices.lua: the Prices page: any item in your scans, found by name, picked from your bags or by a writ's profession, with its lowest price each day.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Chart, Worth, Finder = Market.Chart, Market.Worth, Market.Finder

local LIST_W, PANE_GAP = 300, 12
local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP = 48, 40, 18, 10, 4
local MAX_RESULTS = 50
local BUTTON_W, BUTTON_H = 110, 24
local FILTER_W, FILTER_GAP = 96, 6
local ALL_ITEMS, ALL_WRITS = -1, 0
local TEXT_BAGS = ns.L("In your bags")
local TEXT_ALL_ITEMS = ns.L("All Items")
local TEXT_ALL_WRITS = ns.L("All Writs")
local TEXT_BY_PROFESSION = ns.L("Writs by Profession")
local TEXT_PICK = ns.L("Pick an item to see its prices.")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")

local page, head, chart, empty, watch, finder, filter
local shown = ALL_ITEMS
local writSets = {}

local Page = {}
Market.Pages.prices = Page

local function FromBags(found)
    wipe(found)
    for _, entry in ipairs(Worth.Read()) do
        if #found >= MAX_RESULTS then break end
        if Finder.Scan(entry.itemID) then found[#found + 1] = entry.itemID end
    end
    return TEXT_BAGS
end

local function DrawHead(picked)
    head:SetShown(picked ~= nil)
    chart:SetShown(picked ~= nil)
    empty:SetShown(picked == nil)
    Finder.PaintWatch(watch, picked)
    if not picked then return end
    head.icon.texture:SetTexture(C_Item.GetItemIconByID(picked))
    local color = Items.QualityColor(picked) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(Items.Name(picked))
    local scan = Finder.Scan(picked)
    head.sub:SetText(scan and TEXT_SCAN_SUB:format(Parts.Coins(scan)) or TEXT_NO_SCAN_SUB)
    chart:Paint(picked)
end

function Page.Draw()
    Finder.Draw(finder)
    DrawHead(finder.picked)
end

local function ProfessionName(skillLine)
    return C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)
end

local function WritSet(key)
    if writSets[key] then return writSets[key] end
    local set, ids = {}, {}
    for skillLine, writs in pairs(Market.WRITS) do
        if key == ALL_WRITS or key == skillLine then
            for _, id in ipairs(writs) do
                set[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    writSets[key] = set
    Items.OnLoaded(ids, Page.Draw)
    return set
end

local function FilterLabel()
    if shown == ALL_ITEMS then return TEXT_ALL_ITEMS end
    return shown == ALL_WRITS and TEXT_ALL_WRITS or ProfessionName(shown)
end

local function IsShown(key) return shown == key end

local function Show(key)
    shown = key
    finder.only = key ~= ALL_ITEMS and WritSet(key) or nil
    finder.picked = nil
    finder.scroll:SetVerticalScroll(0)
    ns.SetButtonText(filter, FilterLabel())
    Page.Draw()
end

local function ByName(a, b) return ProfessionName(a) < ProfessionName(b) end

local function FilterMenu(_, root)
    root:CreateRadio(TEXT_ALL_ITEMS, IsShown, Show, ALL_ITEMS)
    root:CreateRadio(TEXT_ALL_WRITS, IsShown, Show, ALL_WRITS)
    root:CreateDivider()
    root:CreateTitle(TEXT_BY_PROFESSION)
    local professions = {}
    for skillLine in pairs(Market.WRITS) do professions[#professions + 1] = skillLine end
    table.sort(professions, ByName)
    for _, skillLine in ipairs(professions) do
        root:CreateRadio(ProfessionName(skillLine), IsShown, Show, skillLine)
    end
end

local function OpenFilter()
    ns.ContextMenu(filter, FilterMenu)
end

local function BuildHead()
    head = CreateFrame("Frame", nil, page)
    head:SetPoint("TOPLEFT", LIST_W + PANE_GAP, 0)
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head.icon = Parts.ItemIcon(head, HEAD_ICON)
    head.icon:SetPoint("LEFT")
    head.name = ns.Font(head, NAME_SIZE, nil, T.fg, true)
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", NAME_GAP, 0)
    head.name:SetPoint("RIGHT")
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.sub = ns.Font(head, St.SMALL_SIZE, nil, T.muted)
    head.sub:SetPoint("TOPLEFT", head.name, "BOTTOMLEFT", 0, -SUB_GAP)
    watch = Finder.Watch(page, BUTTON_W, BUTTON_H, Page.Draw)
    watch:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -PANE_GAP)
    watch:SetPoint("RIGHT")
    chart = Chart.New(page)
    chart:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -PANE_GAP)
    chart:SetPoint("BOTTOMRIGHT")
    empty = ns.Font(page, St.TEXT_SIZE, nil, T.muted)
    empty:SetPoint("CENTER", head, "BOTTOM", 0, -HEAD_H)
    empty:SetText(TEXT_PICK)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    finder = Finder.New(page, LIST_W, FromBags, Page.Draw)
    finder.frame:SetPoint("TOPLEFT")
    finder.frame:SetPoint("BOTTOMLEFT")
    finder.search:SetWidth(LIST_W - FILTER_W - FILTER_GAP)
    filter = ns.Button(finder.frame, TEXT_ALL_ITEMS, FILTER_W, St.SEARCH_H, OpenFilter)
    filter:SetPoint("LEFT", finder.search, "RIGHT", FILTER_GAP, 0)
    BuildHead()
end

function Page.Show()
    page:Show()
    Page.Draw()
end

function Page.Refresh()
    Page.Draw()
end

function Page.Hide()
    page:Hide()
end
