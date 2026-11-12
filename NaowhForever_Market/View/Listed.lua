-- Listed.lua: the listings of the item on Sell, cheapest first, where your price lands among them, and Buy and Cancel on the row under the mouse (Market.Listed).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Listings, Purchase, Sell = Market.Listings, Market.Purchase, Market.Sell

local FOLDED = "marketListingsFolded"
local HEAD_H, ROW_H, MARK_H, ROWS = 22, 18, 12, 4
local VIEW_H = ROWS * ROW_H + MARK_H
local IN, FOLD_SIZE, SCROLL_IN = 6, 10, 4
local QUANTITY_LEFT, PILL_SIZE, MARK_SIZE = 150, 10, 10
local BUTTON_W, BUTTON_H, BUTTON_GAP = 56, 16, 4
local QUANTITY_LETTERS = 6
local TEXT_HEAD = ns.L("Listings")
local TEXT_HEAD_COUNT = ns.L("Listings (%d)")
local TEXT_QUANTITY = "x%s"
local TEXT_YOURS = ns.L("Yours")
local TEXT_MARK = ns.L("Your price")
local TEXT_EMPTY = ns.L("No listings: yours would be the only one.")
local TEXT_BUY = ns.L("Buy")
local TEXT_CANCEL = ns.L("Cancel")
local TEXT_TIP_TAKE = ns.L("Click to take this price.")
local TEXT_TIP_BUY = ns.L("Buy takes the %d listed up to this price, about %s.")
local TEXT_TIP_BUY_ITEM = ns.L("Buy takes this auction for %s.")
local TEXT_TIP_CANCEL = ns.L("Cancel takes your auction down.")
local TEXT_BUY_ASK = ns.L("Buy %d %s for %s?")
local TEXT_BUY_MANY = ns.L("Buy how many? Up to %d, cheapest first.")
local TEXT_QUOTING = ns.L("Getting the price")
local TEXT_BOUGHT = ns.L("Bought %d.")
local TEXT_BUY_FAILED = ns.L("The purchase did not go through.")
local TEXT_NO_MONEY = ERR_NOT_ENOUGH_MONEY
local TEXT_CANCEL_ASK = ns.L("Cancel %s? It costs %s, and the items come back by mail.")
local TEXT_CANCEL_FREE = ns.L("Cancel %s? The items come back by mail.")
local STATUS = { searching = ns.L("Checking"), waiting = ns.L("Checking"), noanswer = ns.L("No answer") }

local pane, redraw
local lines = {}
local bodyH = ROW_H
local asking
local note, noteKey

local Listed = {}
Market.Listed = Listed

local function Coins(copper)
    return Parts.Coins(copper)
end

local function Folded()
    return ns.AccountSettings()[FOLDED] == true
end

local function Name(entry, link)
    return link and C_Item.GetItemInfo(link) or C_Item.GetItemInfo(entry.link) or ns.Shared.Items.Name(entry.itemID)
end

local function Note(entry, text)
    note, noteKey = text, entry.key
    redraw()
end

local function CanBuy(row)
    return row.quantity > row.own and (pane.entry.commodity or row.auctionID ~= nil)
end

local function CanCancel(row)
    return row.ownID ~= nil and C_AuctionHouse.CanCancelAuction(row.ownID)
end

local function CloseAsk()
    if not asking then return end
    asking.onClose = nil
    asking:Hide()
    asking = nil
end

local function AskClosed()
    asking = nil
    Purchase.Drop()
end

local function BuyAsked()
    asking = nil
    Purchase.Confirm()
end

local function Quoted(itemID, count, total)
    local entry = Sell.Focus()
    CloseAsk()
    if not (entry and entry.commodity and entry.itemID == itemID) then return Purchase.Drop() end
    if total > GetMoney() then
        Purchase.Drop()
        return Note(entry, TEXT_NO_MONEY)
    end
    local _, dimmer = ns.Confirm(TEXT_BUY_ASK:format(count, Name(entry), Coins(total)), BuyAsked, AskClosed, TEXT_BUY,
        TEXT_CANCEL)
    asking = dimmer
end

local function Bought(ok, count)
    local entry = Sell.Focus()
    CloseAsk()
    if ok then Listings.Again() end
    if entry then return Note(entry, ok and TEXT_BOUGHT:format(count) or TEXT_BUY_FAILED) end
    redraw()
end

local function CostOf(count)
    local cost = 0
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        local take = math.min(count, row.quantity - row.own)
        count, cost = count - take, cost + take * row.price
    end
    return cost
end

local function BuySome(itemID, most, text)
    local entry, count = Sell.Focus(), tonumber(text)
    if not (entry and entry.itemID == itemID and count and count >= 1) or asking or Purchase.Busy() then return end
    count = math.min(most, math.floor(count))
    if CostOf(count) > GetMoney() then return Note(entry, TEXT_NO_MONEY) end
    Purchase.Quote(itemID, count)
    Note(entry, TEXT_QUOTING)
end

local function Buy(index)
    local entry = Sell.Focus()
    if not entry or asking or Purchase.Busy() then return end
    local row = Listings.rows[index]
    local count, cost = 1, row.price
    if entry.commodity then count, cost = Listings.Others(index) end
    if entry.commodity then
        if CostOf(1) > GetMoney() then return Note(entry, TEXT_NO_MONEY) end
        if count == 1 then return BuySome(entry.itemID, 1, 1) end
        local itemID = entry.itemID
        return ns.PromptText(TEXT_BUY_MANY:format(count), tostring(count), QUANTITY_LETTERS,
            function(text) BuySome(itemID, count, text) end, TEXT_BUY)
    end
    if cost > GetMoney() then return Note(entry, TEXT_NO_MONEY) end
    local auctionID = row.auctionID
    local _, dimmer = ns.Confirm(TEXT_BUY_ASK:format(count, Name(entry, row.link), Coins(cost)), function()
        asking = nil
        Purchase.Item(auctionID, cost)
    end, AskClosed, TEXT_BUY, TEXT_CANCEL)
    asking = dimmer
end

local function Cancel(index)
    local entry = Sell.Focus()
    if not entry or asking or Purchase.Busy() then return end
    local row = Listings.rows[index]
    local auctionID, name = row.ownID, Name(entry, row.ownLink)
    local cost = C_AuctionHouse.GetCancelCost(auctionID)
    local text = cost and cost > 0 and TEXT_CANCEL_ASK:format(name, Coins(cost)) or TEXT_CANCEL_FREE:format(name)
    local _, dimmer = ns.Confirm(text, function()
        asking = nil
        Market.Auctions.Cancel(auctionID)
    end, AskClosed)
    asking = dimmer
end

local function Action(line, key, text, onClick)
    local button = line[key]
    if button then return button end
    button = ns.Button(line, text, BUTTON_W, BUTTON_H, function() onClick(line.index) end)
    button:HookScript("OnLeave", function() line:GetScript("OnLeave")(line) end)
    line[key] = button
    return button
end

local function ShowActions(line)
    local row = Listings.rows[line.index]
    local right = -IN
    if line.buy then line.buy:Hide() end
    if line.cancel then line.cancel:Hide() end
    if CanCancel(row) then
        local cancel = Action(line, "cancel", TEXT_CANCEL, Cancel)
        cancel:SetPoint("RIGHT", right, 0)
        cancel:Show()
        right = right - BUTTON_W - BUTTON_GAP
    end
    if CanBuy(row) then
        local buy = Action(line, "buy", TEXT_BUY, Buy)
        buy:SetPoint("RIGHT", right, 0)
        buy:Show()
    end
    line.yours:Hide()
end

local function HideActions(line)
    if line.buy then line.buy:Hide() end
    if line.cancel then line.cancel:Hide() end
    line.yours:SetShown(Listings.rows[line.index].own > 0)
end

local function ShowTip(line)
    local row = Listings.rows[line.index]
    local m = T.muted
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TEXT_TIP_TAKE, T.fg.r, T.fg.g, T.fg.b)
    if CanBuy(row) then
        if pane.entry.commodity then
            local count, cost = Listings.Others(line.index)
            GameTooltip:AddLine(TEXT_TIP_BUY:format(count, Coins(cost)), m.r, m.g, m.b)
        else
            GameTooltip:AddLine(TEXT_TIP_BUY_ITEM:format(Coins(row.price)), m.r, m.g, m.b)
        end
    end
    if CanCancel(row) then GameTooltip:AddLine(TEXT_TIP_CANCEL, m.r, m.g, m.b) end
    GameTooltip:Show()
end

local function LineEnter(line)
    line.hover:Show()
    ShowActions(line)
    ShowTip(line)
end

local function LineLeave(line)
    if line:IsMouseOver() then return end
    line.hover:Hide()
    HideActions(line)
    GameTooltip:Hide()
end

local function LineClicked(line)
    local entry = Sell.Focus()
    if not entry then return end
    Sell.TakePrice(entry, Listings.rows[line.index].price)
    redraw()
end

local function NewLine()
    local line = CreateFrame("Button", nil, pane.list)
    line:SetHeight(ROW_H)
    Parts.RowBands(line, 0)
    line.price = ns.Font(line, St.TEXT_SIZE, nil, T.fg)
    line.price:SetPoint("LEFT", IN, 0)
    line.quantity = ns.Font(line, St.TEXT_SIZE, nil, T.muted)
    line.quantity:SetPoint("LEFT", QUANTITY_LEFT, 0)
    line.yours = Parts.Pill(line, PILL_SIZE, St.HAVE_RGB)
    line.yours:SetPoint("RIGHT", -IN, 0)
    Parts.SetPill(line.yours, TEXT_YOURS)
    line:SetScript("OnClick", LineClicked)
    line:SetScript("OnEnter", LineEnter)
    line:SetScript("OnLeave", LineLeave)
    return line
end

local function PaintLine(index, y, cheapest)
    local line = lines[index] or NewLine()
    lines[index] = line
    local row = Listings.rows[index]
    local color = index == cheapest and T.accent or T.fg
    line.index = index
    line.stripe:SetShown(index % 2 == 0)
    line.price:SetTextColor(color.r, color.g, color.b)
    line.price:SetText(Coins(row.price))
    line.quantity:SetText(TEXT_QUANTITY:format(BreakUpLargeNumbers(row.quantity)))
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 0, -y)
    line:SetPoint("RIGHT", pane.list, "RIGHT")
    line:Show()
    if line:IsMouseOver() then ShowActions(line) else HideActions(line) end
    return y + ROW_H
end

local function PlaceMark(y)
    pane.mark:ClearAllPoints()
    pane.mark:SetPoint("TOPLEFT", 0, -y)
    pane.mark:SetPoint("RIGHT", pane.list, "RIGHT")
    return y + MARK_H
end

local function Cheapest()
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        if row.quantity > row.own then return i end
    end
end

local function PaintLines(price)
    local cheapest = Cheapest()
    local y, marked = 0, false
    for i = 1, Listings.count do
        if not marked and Listings.rows[i].price > price then
            y, marked = PlaceMark(y), true
        end
        y = PaintLine(i, y, cheapest)
    end
    if not marked then y = PlaceMark(y) end
    for i = Listings.count + 1, #lines do lines[i]:Hide() end
    pane.list:SetSize(pane.scroll:GetWidth(), y)
    return math.min(y, VIEW_H)
end

local function Paint(_, entry, price)
    local state, count = Listings.state, Listings.count
    local listed = state == "listed"
    local open = not Folded()
    local rows = open and listed and count > 0
    pane.entry = entry
    pane.title:SetText(listed and TEXT_HEAD_COUNT:format(count) or TEXT_HEAD)
    pane.note:SetText(noteKey == entry.key and note or "")
    pane.fold:SetRotation(open and St.OPEN_TURN or 0)
    pane.scroll:SetShown(rows)
    pane.status:SetShown(open and not rows)
    if not open then return HEAD_H end
    if rows then
        bodyH = PaintLines(price)
    else
        pane.status:SetText(listed and TEXT_EMPTY or STATUS[state or "searching"])
        if listed then bodyH = ROW_H end
    end
    return HEAD_H + bodyH
end

local function Asking()
    return asking ~= nil
end

local function Close()
    if asking then asking:Hide() end
    Purchase.Drop()
    note, noteKey = nil, nil
end

local function HeadClicked()
    ns.AccountSettings()[FOLDED] = not Folded() or nil
    redraw()
end

local function BuildHead()
    local head = CreateFrame("Button", nil, pane)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    pane.head = head
    pane.title = ns.Font(head, St.SMALL_SIZE, nil, T.muted, true)
    pane.title:SetPoint("LEFT", IN, 0)
    pane.fold = Parts.Arrow(head, FOLD_SIZE, T.muted)
    pane.fold:SetPoint("RIGHT", -IN, 0)
    pane.note = ns.Font(head, St.SMALL_SIZE, nil, T.muted)
    pane.note:SetPoint("RIGHT", pane.fold, "LEFT", -IN, 0)
    head:SetScript("OnClick", HeadClicked)
end

local function BuildMark()
    local mark = CreateFrame("Frame", nil, pane.list)
    mark:SetHeight(MARK_H)
    local text = ns.Font(mark, MARK_SIZE, nil, T.muted)
    text:SetPoint("LEFT", IN, 0)
    text:SetText(TEXT_MARK)
    local line = ns.Solid(mark, "ARTWORK", T.accent, 1)
    line:SetPoint("LEFT", text, "RIGHT", IN, 0)
    line:SetPoint("RIGHT", -IN, 0)
    ns.Hairline(line, "h")
    pane.mark = mark
end

function Listed.New(parent, onChange)
    pane, redraw = CreateFrame("Frame", nil, parent), onChange
    ns.Solid(pane, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(pane, St.BORDER_RGB)
    BuildHead()
    pane.status = ns.Font(pane, St.SMALL_SIZE, nil, T.muted)
    pane.status:SetPoint("TOPLEFT", IN, -(HEAD_H + (ROW_H - St.SMALL_SIZE) / 2))
    pane.scroll = ns.UI.SlimScroll(pane)
    pane.scroll:SetPoint("TOPLEFT", 0, -HEAD_H)
    pane.scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    pane.list = CreateFrame("Frame", nil, pane.scroll)
    pane.list:SetHeight(1)
    pane.scroll:SetScrollChild(pane.list)
    pane.scroll:HookScript("OnSizeChanged", function(_, width) pane.list:SetWidth(width) end)
    BuildMark()
    pane.Paint, pane.Asking, pane.Close = Paint, Asking, Close
    Purchase.onQuote, Purchase.onDone = Quoted, Bought
    return pane
end
