-- Buy.lua: the panel's Buy page: your watch list, and any item in your scans to add to it.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Finder, Watch = Market.Finder, Market.Watch

local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP, GAP = 40, 32, 15, 8, 3, 10
local BUTTON_W, BUTTON_H = 86, 24
local TEXT_LIST = ns.L("Watch List: %d, %d at or under your price")
local TEXT_EMPTY = ns.L("Nothing on your watch list. Search an item to watch it.")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")

local page, head, watch, finder
local watched = {}

local Page = {}
Market.Pages.buy = Page

local function FromList(found)
    wipe(found)
    for _, id in ipairs(Watch.Items(watched)) do found[#found + 1] = id end
    if #found == 0 then return TEXT_EMPTY end
    return TEXT_LIST:format(#found, Watch.UnderCount())
end

local function DrawHead(itemID)
    head:SetShown(itemID ~= nil)
    Finder.PaintWatch(watch, itemID)
    if not itemID then return end
    head.icon.texture:SetTexture(C_Item.GetItemIconByID(itemID))
    local color = Items.QualityColor(itemID) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(Items.Name(itemID))
    local scan = Finder.Scan(itemID)
    head.sub:SetText(scan and TEXT_SCAN_SUB:format(Parts.Coins(scan)) or TEXT_NO_SCAN_SUB)
end

function Page.Draw()
    Finder.Draw(finder)
    DrawHead(finder.picked)
end

local function BuildHead()
    head = CreateFrame("Frame", nil, page)
    head:SetPoint("TOPLEFT")
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
    watch:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    watch:SetPoint("RIGHT")
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildHead()
    finder = Finder.New(page, St.DOCK_W - St.DOCK_PAD * 2, FromList, Page.Draw, true)
    finder.frame:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -GAP)
    finder.frame:SetPoint("BOTTOMRIGHT")
end

function Page.Show()
    page:Show()
    Page.Draw()
end

function Page.Refresh()
    Page.Draw()
end

function Page.ShowList()
    if not finder then return end
    Finder.Reset(finder)
end

function Page.Hide()
    page:Hide()
end
