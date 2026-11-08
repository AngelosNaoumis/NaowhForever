-- Auctions.lua: the My Auctions page: your auctions with the cheapest listing that is not yours, and cancelling the undercut ones.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Auctions = Market.Auctions

local TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local HEAD_H, TITLE_SIZE, SUB_GAP = 44, 16, 4
local COLUMNS_H, ROW_H, ROW_ICON, ROW_IN, ICON_GAP = 24, 36, 24, 8, 8
local COLUMN_GAP, CANCEL_W, TIME_W, STATUS_W, MONEY_W, QTY_W = 16, 70, 70, 150, 110, 40
local ROW_BUTTON_H, PILL_SIZE = 22, 11
local UNDERCUT_SMALL = 0.03
local PERCENT = 100
local SECONDS_PER_HOUR, SECONDS_PER_MINUTE = 3600, 60
local NEXT_W, SCROLL_IN = 220, 4
local TIME_RIGHT = ROW_IN + CANCEL_W + COLUMN_GAP
local STATUS_LEFT = TIME_RIGHT + TIME_W + COLUMN_GAP + STATUS_W
local LOWEST_RIGHT = STATUS_LEFT + COLUMN_GAP
local PRICE_RIGHT = LOWEST_RIGHT + MONEY_W + COLUMN_GAP
local QTY_RIGHT = PRICE_RIGHT + MONEY_W + COLUMN_GAP
local NAME_RIGHT = QTY_RIGHT + QTY_W + COLUMN_GAP
local NAME_LEFT = ROW_IN + ROW_ICON + ICON_GAP
local TEXT_TITLE = ns.L("My Auctions")
local TEXT_SUB = ns.L("%d auctions, %d undercut, %s listed")
local TEXT_NONE = ns.L("You have no auctions up.")
local TEXT_NEXT = ns.L("Cancel Undercut (%d)")
local TEXT_CANCEL = ns.L("Cancel")
local TEXT_CANCEL_ASK = ns.L("Cancel %s? It costs %s, and the items come back by mail.")
local TEXT_CANCEL_FREE = ns.L("Cancel %s? The items come back by mail.")
local TEXT_ITEM, TEXT_QTY, TEXT_PRICE = ns.L("Item"), ns.L("Qty"), ns.L("Your Price")
local TEXT_LOWEST, TEXT_STATUS, TEXT_TIME = ns.L("Lowest Now"), ns.L("Status"), ns.L("Time Left")
local TEXT_HOURS, TEXT_MINUTES = "%dh %02dm", "%dm"
local TEXT_BANDS = { [0] = ns.L("Under 30m"), ns.L("30m to 2h"), ns.L("2h to 12h"), ns.L("12h to 48h") }
local STATUS_TEXT = {
    lowest = ns.L("Lowest"),
    sold = ns.L("Sold"),
    checking = ns.L("Checking"),
    noanswer = ns.L("No answer"),
    small = ns.L("Undercut by %s"),
    large = ns.L("Undercut %d%%"),
}

local page, header, scroll, list, empty, nextButton
local rows = {}
local active = false

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
    if status == "lowest" then return STATUS_TEXT.lowest, St.HAVE_RGB end
    if status == "sold" then return STATUS_TEXT.sold, T.accent end
    return STATUS_TEXT[status], T.muted
end

local function CancelNow(auctionID)
    Auctions.Cancel(auctionID)
end

local function CancelClicked(row)
    local auction = row.auction
    if not auction then return end
    local id, name, cost = auction.auctionID, row.name:GetText(), Auctions.CancelCost(auction)
    local text = cost and cost > 0 and TEXT_CANCEL_ASK:format(name, Coins(cost)) or TEXT_CANCEL_FREE:format(name)
    ns.Confirm(text, function() CancelNow(id) end)
end

local function NextClicked()
    local auction = Auctions.NextUndercut()
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

local function Cell(parent, right, width, color)
    local text = ns.Font(parent, TEXT_SIZE, nil, color or T.fg)
    text:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
    text:SetWidth(width)
    text:SetJustifyH("RIGHT")
    text:SetWordWrap(false)
    return text
end

local function NewRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    Parts.RowBands(row, 0)
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", NAME_LEFT, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -NAME_RIGHT, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.qty = Cell(row, QTY_RIGHT, QTY_W)
    row.price = Cell(row, PRICE_RIGHT, MONEY_W)
    row.lowest = Cell(row, LOWEST_RIGHT, MONEY_W, T.muted)
    row.status = Parts.Pill(row, PILL_SIZE, T.muted)
    row.status:SetPoint("LEFT", row, "RIGHT", -STATUS_LEFT, 0)
    row.time = Cell(row, TIME_RIGHT, TIME_W, T.muted)
    row.cancel = ns.Button(row, TEXT_CANCEL, CANCEL_W, ROW_BUTTON_H, function() CancelClicked(row) end)
    row.cancel:SetPoint("RIGHT", -ROW_IN, 0)
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
    row.name:SetText(auction.link and GetItemInfo(auction.link) or Items.Name(auction.itemID))
    row.qty:SetText(auction.quantity)
    row.price:SetText(auction.price and Coins(auction.price) or "")
    local _, low = Auctions.Status(auction)
    row.lowest:SetText(low and Coins(low) or "")
    local text, tint = StatusLook(auction)
    Parts.ColorPill(row.status, tint)
    Parts.SetPill(row.status, text)
    row.time:SetText(TimeLeft(auction))
    row.cancel:SetShown(Auctions.CanCancel(auction))
end

local function DrawList()
    local y = 0
    for i, auction in ipairs(Auctions.list) do
        local row = rows[i] or NewRow()
        rows[i] = row
        PaintRow(row, auction, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + ROW_H
    end
    for i = #Auctions.list + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, y))
    empty:SetShown(#Auctions.list == 0)
end

function Page.Draw()
    if not active then return end
    local undercut, listed = Auctions.Counts()
    header.sub:SetText(TEXT_SUB:format(#Auctions.list, undercut, Parts.Coins(listed, true)))
    ns.SetButtonText(nextButton, TEXT_NEXT:format(undercut))
    nextButton:SetEnabled(undercut > 0)
    nextButton:SetAlpha(undercut > 0 and 1 or St.DISABLED_ALPHA)
    DrawList()
end

local function ColumnLabel(parent, text, right, width, left)
    local label = ns.Font(parent, SMALL_SIZE, nil, T.muted)
    if left then
        label:SetPoint("LEFT", parent, left < 0 and "RIGHT" or "LEFT", left, 0)
        label:SetJustifyH("LEFT")
    else
        label:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
        label:SetWidth(width)
        label:SetJustifyH("RIGHT")
    end
    label:SetText(text)
end

local function BuildHeader()
    header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEAD_H)
    local title = ns.Font(header, TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT")
    title:SetText(TEXT_TITLE)
    header.sub = ns.Font(header, SMALL_SIZE, nil, T.muted)
    header.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    nextButton = ns.Button(header, "", NEXT_W, BUTTON_H, NextClicked)
    ns.PrimaryButton(nextButton)
    nextButton:SetPoint("RIGHT")
    local columns = CreateFrame("Frame", nil, page)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    columns:SetHeight(COLUMNS_H)
    ColumnLabel(columns, TEXT_ITEM, nil, nil, NAME_LEFT)
    ColumnLabel(columns, TEXT_QTY, QTY_RIGHT, QTY_W)
    ColumnLabel(columns, TEXT_PRICE, PRICE_RIGHT, MONEY_W)
    ColumnLabel(columns, TEXT_LOWEST, LOWEST_RIGHT, MONEY_W)
    ColumnLabel(columns, TEXT_STATUS, nil, nil, -STATUS_LEFT)
    ColumnLabel(columns, TEXT_TIME, TIME_RIGHT, TIME_W)
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
    empty:SetText(TEXT_NONE)
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
