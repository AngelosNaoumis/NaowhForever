-- Auctions.lua: the dock's My Auctions page: your auctions against the listings that are not yours, undercut first, filtered by name, and cancelling them.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local C = Market.C
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Auctions, Columns = Market.Auctions, Market.Columns

local TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local HEAD_H, SUB_GAP, HEAD_GAP, FILTER_GAP = 46, 4, 6, 6
local COLUMNS_H, ROW_H, ROW_TALL_H, ROW_ICON, ROW_IN, ICON_GAP, LINE_IN = 22, 38, 52, 24, 6, 6, 4
local CANCEL_W, ROW_BUTTON_H, PILL_SIZE, PILL_GAP = 56, 20, 11, 6
local LINE_GAP = 3
local UNDERCUT_SMALL = 0.03
local PERCENT = 100
local SECONDS_PER_HOUR, SECONDS_PER_MINUTE = 3600, 60
local STATUS_ORDER = { undercut = 1, checking = 2, noanswer = 3, ahead = 4, lowest = 5, sold = 6 }
local SCROLL_IN = 4
local NAME_LEFT = ROW_IN + ROW_ICON + ICON_GAP
local STATUS_RIGHT = ROW_IN + CANCEL_W + PILL_GAP
local TEXT_SUB = ns.L("%d auctions, %d undercut, %s listed")
local TEXT_SOLD = ns.L(", %s sold in the last %d days")
local TEXT_NONE = ns.L("You have no auctions up.")
local TEXT_NO_MATCH = ns.L("None of your auctions has that in its name.")
local TEXT_FILTER = ns.L("Filter your auctions by name")
local TEXT_NEXT = ns.L("Cancel Undercut (%d)")
local TEXT_CANCEL = ns.L("Cancel")
local TEXT_CANCEL_ASK = ns.L("Cancel %s? It costs %s, and the items come back by mail.")
local TEXT_CANCEL_FREE = ns.L("Cancel %s? The items come back by mail.")
local TEXT_ITEM, TEXT_STATUS = ns.L("Item"), ns.L("Status")
local TEXT_LINE = ns.L("Yours %s, lowest %s")
local TEXT_LINE_ONLY = ns.L("Yours %s")
local TEXT_LINE_TIME = "%s, %s"
local TEXT_COUNT = "%s x%d"
local TEXT_HOURS, TEXT_MINUTES = "%dh %02dm", "%dm"
local TEXT_BANDS = { [0] = ns.L("Under 30m"), ns.L("30m to 2h"), ns.L("2h to 12h"), ns.L("12h to 48h") }
local STATUS_TEXT = {
    lowest = ns.L("Lowest"),
    sold = ns.L("Sold"),
    checking = ns.L("Checking"),
    noanswer = ns.L("No answer"),
    small = ns.L("Undercut by %s"),
    large = ns.L("Undercut %d%%"),
    ahead = ns.L("%d ahead"),
}

local page, header, scroll, list, empty, nextButton, sorter
local rows, view = {}, {}
local active = false
local wanted = ""

local Page = {}
Market.Pages.mine = Page

local function Coins(copper)
    return Parts.Coins(copper)
end

local function TimeLeft(auction)
    local seconds = auction.seconds
    if not seconds then return TEXT_BANDS[auction.band] or "" end
    local hours = math.floor(seconds / SECONDS_PER_HOUR)
    local minutes = math.floor(seconds % SECONDS_PER_HOUR / SECONDS_PER_MINUTE)
    if hours > 0 then return TEXT_HOURS:format(hours, minutes) end
    return TEXT_MINUTES:format(minutes)
end

local function StatusLook(auction)
    local status, low = Auctions.Status(auction)
    if status == "undercut" then
        local under = auction.price - low
        if under / auction.price < UNDERCUT_SMALL then return STATUS_TEXT.small:format(Coins(under)), St.WARN_RGB end
        return STATUS_TEXT.large:format(math.floor(under / auction.price * PERCENT + 0.5)), St.RED_RGB
    end
    if status == "ahead" then return STATUS_TEXT.ahead:format(auction.ahead), St.HAVE_RGB end
    if status == "lowest" then return STATUS_TEXT.lowest, St.HAVE_RGB end
    if status == "sold" then return STATUS_TEXT.sold, T.accent end
    return STATUS_TEXT[status], T.muted
end

local function PriceLine(auction)
    if not auction.price then return TimeLeft(auction) end
    local status, low = Auctions.Status(auction)
    local prices = low and TEXT_LINE:format(Coins(auction.price), Coins(low)) or TEXT_LINE_ONLY:format(Coins(auction.price))
    if status == "undercut" then return prices, TEXT_LINE_TIME:format(STATUS_TEXT.ahead:format(auction.ahead), TimeLeft(auction)) end
    return TEXT_LINE_TIME:format(prices, TimeLeft(auction))
end

local function CancelClicked(row)
    local auction = row.auction
    if not auction then return end
    local id, name, cost = auction.auctionID, row.name:GetText(), Auctions.CancelCost(auction)
    local text = cost and cost > 0 and TEXT_CANCEL_ASK:format(name, Coins(cost)) or TEXT_CANCEL_FREE:format(name)
    ns.Confirm(text, function() Auctions.Cancel(id) end)
end

local function Name(auction)
    return auction.link and GetItemInfo(auction.link) or Items.Name(auction.itemID) or ""
end

local function Matches(auction)
    return wanted == "" or ns.Lower(Name(auction)):find(wanted, 1, true) ~= nil
end

local function NextClicked()
    local auction = Auctions.NextUndercut(Matches)
    if auction then Auctions.Cancel(auction.auctionID) end
end

local function RowEnter(row)
    row.hover:Show()
    if not row.auction.link then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.auction.link)
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function NewRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    Parts.RowBands(row, 0)
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.cancel = ns.Button(row, TEXT_CANCEL, CANCEL_W, ROW_BUTTON_H, function() CancelClicked(row) end)
    row.cancel:SetPoint("RIGHT", -ROW_IN, 0)
    row.status = Parts.Pill(row, PILL_SIZE, T.muted)
    row.status:SetPoint("TOPRIGHT", -STATUS_RIGHT, -LINE_IN)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("TOPLEFT", NAME_LEFT, -LINE_IN)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -PILL_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.line = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    row.line:SetPoint("RIGHT", row.cancel, "LEFT", -PILL_GAP, 0)
    row.line:SetJustifyH("LEFT")
    row.line:SetWordWrap(false)
    row.more = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.more:SetPoint("TOPLEFT", row.line, "BOTTOMLEFT", 0, -LINE_GAP)
    row.more:SetPoint("RIGHT", row.cancel, "LEFT", -PILL_GAP, 0)
    row.more:SetJustifyH("LEFT")
    row.more:SetWordWrap(false)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function PaintRow(row, auction, index)
    row.auction = auction
    row.stripe:SetShown(index % 2 == 0)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(auction.itemID))
    local color = Items.QualityColor(auction.itemID) or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    local name = Name(auction)
    row.name:SetText(auction.quantity > 1 and TEXT_COUNT:format(name, auction.quantity) or name)
    local line, more = PriceLine(auction)
    row.line:SetText(line)
    row.more:SetText(more or "")
    local text, tint = StatusLook(auction)
    Parts.ColorPill(row.status, tint)
    Parts.SetPill(row.status, text)
    row.cancel:SetShown(Auctions.CanCancel(auction))
    local height = more and ROW_TALL_H or ROW_H
    row:SetHeight(height)
    return height
end

local function DrawList()
    wipe(view)
    local undercut = 0
    for _, auction in ipairs(Auctions.list) do
        if Matches(auction) then
            view[#view + 1] = auction
            if Auctions.Status(auction) == "undercut" then undercut = undercut + 1 end
        end
    end
    Columns.Sort(sorter, view)
    local y = 0
    for i, auction in ipairs(view) do
        local row = rows[i] or NewRow()
        rows[i] = row
        local height = PaintRow(row, auction, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + height
    end
    for i = #view + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, y))
    empty:SetShown(#view == 0)
    empty:SetText(#Auctions.list == 0 and TEXT_NONE or TEXT_NO_MATCH)
    return undercut
end

function Page.Draw()
    if not active then return end
    local undercut, listed = Auctions.Counts()
    local sold = Market.Sales.Since(C.SALES_WINDOW_DAYS * C.SECONDS_PER_DAY)
    header.sub:SetText(TEXT_SUB:format(#Auctions.list, undercut, Parts.Coins(listed))
        .. (sold > 0 and TEXT_SOLD:format(Parts.Coins(sold), C.SALES_WINDOW_DAYS) or ""))
    local shown = DrawList()
    ns.SetButtonText(nextButton, TEXT_NEXT:format(shown))
    St.Enable(nextButton, shown > 0)
end

local function AuctionName(auction)
    return Name(auction):lower()
end

local function OnFilter(text)
    wanted = ns.Lower(strtrim(text))
    scroll:SetVerticalScroll(0)
    Page.Draw()
end

local function BuildHeader()
    header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEAD_H + FILTER_GAP + St.SEARCH_H)
    nextButton = ns.Button(header, "", 1, BUTTON_H, NextClicked)
    ns.PrimaryButton(nextButton)
    nextButton:SetPoint("TOPLEFT")
    nextButton:SetPoint("TOPRIGHT")
    header.sub = ns.Font(header, SMALL_SIZE, nil, T.muted)
    header.sub:SetPoint("TOPLEFT", nextButton, "BOTTOMLEFT", 0, -HEAD_GAP)
    header.sub:SetPoint("RIGHT")
    header.sub:SetJustifyH("LEFT")
    header.sub:SetWordWrap(false)
    local filter = Parts.SearchBox(header, TEXT_FILTER, OnFilter)
    filter:SetPoint("BOTTOMLEFT")
    filter:SetPoint("BOTTOMRIGHT")
    filter:SetHeight(St.SEARCH_H)
    local columns = CreateFrame("Frame", nil, page)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -SUB_GAP)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), -SUB_GAP)
    columns:SetHeight(COLUMNS_H)
    sorter = Columns.New(columns, Market.Settings, "sortMine", "status", Page.Draw)
    Columns.Add(sorter, { key = "item", text = TEXT_ITEM, left = NAME_LEFT, up = true, value = AuctionName })
    Columns.Add(sorter, { key = "status", text = TEXT_STATUS, right = STATUS_RIGHT, width = CANCEL_W, up = true,
        value = function(auction) return STATUS_ORDER[Auctions.Status(auction)] end })
    return columns
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local columns = BuildHeader()
    scroll = ns.UI.SlimScroll(page)
    scroll:SetPoint("TOPLEFT", columns, "BOTTOMLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    scroll:HookScript("OnSizeChanged", function(_, width) list:SetWidth(width) end)
    empty = ns.Font(page, TEXT_SIZE, nil, T.muted)
    empty:SetPoint("TOP", scroll, "TOP", 0, -HEAD_H)
end

function Page.Show()
    page:Show()
    list:SetWidth(scroll:GetWidth())
    if not active then
        active = true
        Auctions.onChange = Page.Draw
        Auctions.Start()
    end
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    if not active then return end
    active = false
    Auctions.Stop()
end

function NaowhForever_MarketCancelNext()
    if active then NextClicked() end
end

local function OnSetting(key)
    if key == "aheadAllowed" and active then Market.Dock.Refresh() end
end

Market.Settings.OnChange(OnSetting)
