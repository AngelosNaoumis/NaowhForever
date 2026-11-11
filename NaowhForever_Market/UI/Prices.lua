-- Prices.lua: the Prices page: any item in your scans, found by name or picked from your bags, with its lowest price each day.
local ns = _G.NaowhForever

local GetItemNameByID, IsItemDataCachedByID = C_Item.GetItemNameByID, C_Item.IsItemDataCachedByID

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Chart, Worth = Market.Chart, Market.Worth

local LIST_W, PANE_GAP, LIST_GAP, NOTE_H = 300, 12, 8, 18
local ROW_H, ROW_ICON, ROW_IN, ICON_GAP, GAP = 30, 22, 8, 8, 6
local HEAD_H, HEAD_ICON, NAME_SIZE, NAME_GAP, SUB_GAP = 48, 40, 18, 10, 4
local MIN_LETTERS, MAX_RESULTS = 2, 50
local SCROLL_IN = 4
local TEXT_SEARCH = ns.L("Search your scans by name")
local TEXT_BAGS = ns.L("In your bags")
local TEXT_FOUND = ns.L("%d found")
local TEXT_MORE = ns.L("The first %d found; type more to narrow it")
local TEXT_NOTHING = ns.L("Nothing in your scans by that name.")
local TEXT_NO_SCAN = ns.L("Scan prices at an auctioneer to fill this page.")
local TEXT_PICK = ns.L("Pick an item to see its prices.")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")

local page, search, note, scroll, list, head, chart, empty
local rows, found, names = {}, {}, {}
local picked

local Page = {}
Market.Pages.prices = Page

local function ByName(a, b)
    return names[a] < names[b]
end

local function Prices()
    return ns.AuctionPriceList and ns.AuctionPriceList()
end

local function Scan(itemID)
    return ns.AuctionPrice and ns.AuctionPrice(itemID)
end

local function FromBags()
    wipe(found)
    for _, entry in ipairs(Worth.Read()) do
        if #found >= MAX_RESULTS then break end
        if Scan(entry.itemID) then found[#found + 1] = entry.itemID end
    end
    return TEXT_BAGS
end

local function FromScans(text)
    wipe(found)
    wipe(names)
    local prices = Prices()
    if not prices then return TEXT_NO_SCAN end
    local want = ns.Lower(text)
    local more = false
    for id in pairs(prices) do
        local name = IsItemDataCachedByID(id) and GetItemNameByID(id)
        if name and ns.Lower(name):find(want, 1, true) then
            if #found >= MAX_RESULTS then
                more = true
                break
            end
            found[#found + 1] = id
            names[id] = name
        end
    end
    table.sort(found, ByName)
    if more then return TEXT_MORE:format(MAX_RESULTS) end
    return #found > 0 and TEXT_FOUND:format(#found) or TEXT_NOTHING
end

local function DrawHead()
    head:SetShown(picked ~= nil)
    chart:SetShown(picked ~= nil)
    empty:SetShown(picked == nil)
    if not picked then return end
    head.icon.texture:SetTexture(C_Item.GetItemIconByID(picked))
    local color = Items.QualityColor(picked) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(Items.Name(picked))
    local scan = Scan(picked)
    head.sub:SetText(scan and TEXT_SCAN_SUB:format(Parts.Coins(scan)) or TEXT_NO_SCAN_SUB)
    chart:Paint(picked)
end

local function RowClicked(row)
    picked = row.itemID
    Page.Draw()
end

local function RowEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.itemID)
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function NewRow()
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.price = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.price:SetPoint("RIGHT", -ROW_IN, 0)
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.price, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function DrawList()
    for i, id in ipairs(found) do
        local row = rows[i] or NewRow()
        rows[i] = row
        row.itemID = id
        row.stripe:SetShown(i % 2 == 0)
        row.picked:SetShown(id == picked)
        row.icon.texture:SetTexture(C_Item.GetItemIconByID(id))
        local color = Items.QualityColor(id) or T.fg
        row.name:SetTextColor(color.r, color.g, color.b)
        row.name:SetText(names[id] or Items.Name(id))
        local scan = Scan(id)
        row.price:SetText(scan and Parts.Coins(scan) or "")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
    end
    for i = #found + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, #found * ROW_H))
end

function Page.Draw()
    local text = search:GetText() or ""
    if #text >= MIN_LETTERS then
        note:SetText(FromScans(text))
    else
        wipe(names)
        note:SetText(FromBags())
    end
    if not picked then picked = found[1] end
    DrawList()
    DrawHead()
end

local function OnSearch()
    scroll:SetVerticalScroll(0)
    Page.Draw()
end

local function BuildList()
    search = Parts.SearchBox(page, TEXT_SEARCH, OnSearch)
    search:SetPoint("TOPLEFT")
    search:SetSize(LIST_W, St.SEARCH_H)
    note = ns.Font(page, St.SMALL_SIZE, nil, T.muted)
    note:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -LIST_GAP)
    note:SetWidth(LIST_W)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(false)
    local pane = CreateFrame("Frame", nil, page)
    pane:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -(LIST_GAP + NOTE_H))
    pane:SetPoint("BOTTOMLEFT")
    pane:SetWidth(LIST_W)
    ns.Solid(pane, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(pane, St.BORDER_RGB)
    scroll = ns.UI.SlimScroll(pane)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetSize(LIST_W - St.SCROLLBAR - SCROLL_IN, 1)
    scroll:SetScrollChild(list)
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
    chart = Chart.New(page)
    chart:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -PANE_GAP)
    chart:SetPoint("BOTTOMRIGHT")
    empty = ns.Font(page, St.TEXT_SIZE, nil, T.muted)
    empty:SetPoint("CENTER", head, "BOTTOM", 0, -HEAD_H)
    empty:SetText(TEXT_PICK)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildList()
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
