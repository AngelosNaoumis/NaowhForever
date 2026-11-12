-- Sell.lua: the dock's Sell page: the item in front of you, its price against the cheapest listing, the post line, and what comes after it.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local C = Market.C
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Sell, Listings, Post = Market.Sell, Market.Listings, Market.Post

local GAP, TEXT_SIZE, SMALL_SIZE = St.GAP, St.TEXT_SIZE, St.SMALL_SIZE
local BORDER_RGB, BUTTON_H = St.BORDER_RGB, St.BUTTON_H
local HEAD_ICON, NAME_SIZE, HEAD_H, NAME_GAP, SUB_GAP = 32, 14, 36, 8, 3
local SECTION_GAP = 8
local REASON_H, INFO_SIZE, INFO_GAP = 30, 14, 6
local FIELD_GAP, FORM_H = 16, 40
local QTY_BOX_W, QTY_LETTERS, OF_GAP = 50, 5, 6
local DURATION_W = 250
local SKIP_W, POST_GAP, NET_GAP, NET_H = 70, 8, 6, 14
local PAST_H = 18
local FOCUS_H = HEAD_H + REASON_H + FORM_H + St.TAB_H + BUTTON_H + NET_GAP + NET_H + SECTION_GAP * 4
local BAR_H, PROGRESS_H, PROGRESS_GAP = 16, 4, 10
local QUEUE_HEAD_H, QUEUE_ROW_H, QUEUE_ICON, SECTION_H = 34, 34, 24, 22
local ROW_IN, ROW_TEXT_GAP, ROW_LINE_IN = 6, 6, 3
local MARKER_W, SCROLL_IN = 2, 4
local STAR_SIZE, STAR_IN, FOLD_SIZE = 10, 2, 10
local EMPTY_SIZE, EMPTY_GAP = 14, 6
local NEXT_FRAME = 0
local TEXT_SEARCHING = ns.L("Searching")
local TEXT_NONE = ns.L("Nobody is selling this")
local TEXT_LISTED = ns.L("%s listed")
local TEXT_POST = ns.L("Post %d for %s")
local TEXT_POSTING = ns.L("Posting")
local TEXT_SKIP = ns.L("Skip")
local TEXT_PRICE = ns.L("Price Each")
local TEXT_QUANTITY = ns.L("Quantity")
local TEXT_OF = ns.L("of %d")
local TEXT_DURATION = ns.L("Duration")
local TEXT_BID = ns.L("Starting Bid")
local TEXT_BID_HIGH = AUCTION_HOUSE_SELL_FRAME_ERROR_BUYOUT
local TEXT_PAST = ns.L("Last post: %s x%d (%s)")
local TEXT_PAST_ALL = ns.L("All %d")
local TEXT_PAST_ROW = "%s x%d, %s (%s)"
local TEXT_TODAY = ns.L("Today")
local TEXT_YESTERDAY = ns.L("Yesterday")
local TEXT_DAYS_AGO = ns.L("%d days ago")
local TEXT_NET = ns.L("You get %s after the 5%% cut.")
local TEXT_SHORT = ns.L("You need %s for the deposit.")
local TEXT_UP_NEXT = ns.L("Up Next")
local TEXT_LEFT = ns.L("%d to post, %s at your prices")
local TEXT_ALL_POSTED = ns.L("Everything is posted")
local TEXT_VENDOR_SECTION = ns.L("For a Vendor")
local TEXT_POSTED_SECTION = ns.L("Posted This Visit")
local TEXT_HIDDEN_SECTION = ns.L("Hidden (%d)")
local TEXT_FAVOURITE = ns.L("Favourite")
local TEXT_UNFAVOURITE = ns.L("Remove Favourite")
local TEXT_HIDE = ns.L("Hide from Sell")
local TEXT_UNHIDE = ns.L("Show in Sell")
local TEXT_ROW_HINT = ns.L("Right-click to favourite or hide it.")
local TEXT_EACH = ns.L("%s each")
local TEXT_POSTED_EACH = ns.L("Posted %d at %s each")
local TEXT_VENDOR_EACH = ns.L("A vendor pays %s each")
local TEXT_NO_PRICE = ns.L("No price yet")
local TEXT_TOTAL = ns.L("%s posted of %s")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")
local TEXT_COUNT = "%s x%d"
local TEXT_EMPTY = ns.L("Nothing in your bags the auction house takes.")
local TEXT_EMPTY_SUB = ns.L("Right-click an item in your bags to sell it here.")
local TEXT_DONE = ns.L("Everything is posted.")
local TEXT_DONE_SUB = ns.L("%s listed this visit.")
local TEXT_POST_ANYWAY = ns.L("Post Anyway")
local TEXT_CANCEL = ns.L("Cancel")
local ASKS = {
    vendor = ns.L("%s at %s each makes no more than a vendor pays, %s each, after the auction house cut. Post it anyway?"),
    listing = ns.L("%s at %s each is far under the cheapest listing, %s each. Post it anyway?"),
    scan = ns.L("%s at %s each is far under your last scan's price, %s each. Post it anyway?"),
}
local ASK_KEYS = { SPACE = true, S = true, UP = true, DOWN = true }
local REASONS = {
    under = ns.L("%s under the cheapest listing, %s."),
    match = ns.L("Matches the cheapest listing, %s."),
    yours = ns.L("Yours is already the cheapest, at %s, so this matches it."),
    scan = ns.L("Nobody is selling this right now. Priced at your last scan, %s."),
    vendor = ns.L("Nobody is selling this and your scans have no price for it. Check the price before you post."),
    hand = ns.L("Your price, set by hand."),
    searching = ns.L("Asking the auction house for its listings."),
    waiting = ns.L("Waiting for the auction house to take another search."),
    noanswer = ns.L("No answer from the auction house, so this is your last scan's price. Check it before you post."),
    failed = ns.L("The auction house did not take that post."),
    vendorBetter = ns.L("A vendor pays %s each, more than this makes after the auction house cut."),
}
local EVENTS = { "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "PLAYER_MONEY", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_CANCELED" }
local THROTTLE_EVENTS = { AUCTION_HOUSE_THROTTLED_SYSTEM_READY = true, AUCTION_HOUSE_THROTTLED_MESSAGE_SENT = true }

local page, focusPane, content, message, listPane, queuePane, scroll, list, bar
local head, reason, money, quantity, quantityOf, durations, netText, skip, post
local form, bidRow, bid, durationRow, pastRow
local bidShown, pastShown
local queueRows, lines = {}, {}
local events
local active, loading, failed, reread = false, false, false, false
local ask = {}
local asking
local hiddenOpen = false

local Page = {}
Market.Pages.sell = Page

local function Coins(copper)
    return Parts.Coins(copper)
end

local function ItemName(entry)
    return GetItemInfo(entry.link) or Items.Name(entry.itemID)
end

local Enable = St.Enable

local function Panel(frame)
    ns.Solid(frame, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(frame, BORDER_RGB)
end

local function ShowTip(frame, hint)
    local link = frame.link
    if not link then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    if hint then GameTooltip:AddLine(hint, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function CanPost(entry)
    if not entry or not Post.Ready() then return false end
    local _, why = Sell.Price(entry)
    local state = Listings.state
    if why ~= "hand" and state ~= "listed" and state ~= "noanswer" then return false end
    local deposit = Post.Deposit(entry, Sell.Quantity(entry), Sell.Duration())
    return Sell.Quantity(entry) > 0 and (deposit or 0) <= GetMoney() and Sell.BidFits(entry)
end

local function Reason(entry, price, why, ref)
    if failed then return REASONS.failed end
    if entry.vendorBetter then return REASONS.vendorBetter:format(Coins(entry.vendor)) end
    if why == "hand" then return REASONS.hand end
    local state = Listings.state
    if state == "noanswer" then return REASONS.noanswer end
    if state ~= "listed" then return REASONS[state or "searching"] end
    if why == "under" then return REASONS.under:format(Coins(ref - price), Coins(ref)) end
    if why == "vendor" then return REASONS.vendor end
    return REASONS[why]:format(Coins(ref))
end

local function ListedText()
    local state = Listings.state
    if state == "noanswer" then return "" end
    if state ~= "listed" then return TEXT_SEARCHING end
    local total = 0
    for i = 1, Listings.count do total = total + Listings.rows[i].quantity end
    return total > 0 and TEXT_LISTED:format(BreakUpLargeNumbers(total)) or TEXT_NONE
end

local function Layout(showBid, showPast)
    if showBid == bidShown and showPast == pastShown then return end
    bidShown, pastShown = showBid, showPast
    bidRow:SetShown(showBid)
    pastRow:SetShown(showPast)
    durationRow:SetPoint("TOPLEFT", showBid and bidRow or form, "BOTTOMLEFT", 0, -SECTION_GAP)
    focusPane:SetHeight(FOCUS_H + (showBid and bidRow:GetHeight() + SECTION_GAP or 0)
        + (showPast and PAST_H + NET_GAP or 0))
end

local function When(at)
    local days = math.floor((time() - at) / C.SECONDS_PER_DAY)
    if days < 1 then return TEXT_TODAY end
    if days == 1 then return TEXT_YESTERDAY end
    return TEXT_DAYS_AGO:format(days)
end

local function DrawPast(entry)
    local count = Sell.PastCount(entry.itemID)
    if count == 0 then return end
    local price, each, _, at = Sell.Past(entry.itemID, 1)
    Parts.SetLink(pastRow.last, TEXT_PAST:format(Coins(price), each, When(at)))
    pastRow.all:SetShown(count > 1)
    Parts.SetLink(pastRow.all, TEXT_PAST_ALL:format(count))
end

local function DrawForm(entry, price)
    money:ShowCopper(Sell.Copper(entry))
    if not money:HasFocus() then money:SetAmount(price) end
    Layout(S.Get("startingBid") and not entry.commodity, Sell.PastCount(entry.itemID) > 0)
    if bidShown and not bid:HasFocus() then bid:SetAmount(Sell.Bid(entry) or 0) end
    DrawPast(entry)
    if not quantity:HasFocus() then quantity:SetText(Sell.Quantity(entry)) end
    form.chips:Paint(entry)
    quantityOf:SetText(TEXT_OF:format(entry.count))
    Parts.PaintTabs(durations, Sell.Duration())
end

local function DrawPost(entry, price)
    local count = Sell.Quantity(entry)
    local deposit = Post.Deposit(entry, count, Sell.Duration())
    if not Sell.BidFits(entry) then
        netText:SetText(TEXT_BID_HIGH)
    elseif deposit and deposit > GetMoney() then
        netText:SetText(TEXT_SHORT:format(Coins(deposit)))
    else
        netText:SetText(TEXT_NET:format(Coins(Market.AfterCut(price * count))))
    end
    ns.SetButtonText(post, Post.Waiting() and TEXT_POSTING or TEXT_POST:format(count, Coins(price * count)))
    Enable(post, CanPost(entry))
end

local function DrawFocus()
    local entry = Sell.Focus()
    content:SetShown(entry ~= nil)
    message:SetShown(entry == nil)
    listPane:SetShown(entry ~= nil)
    queuePane:SetPoint("TOPLEFT", entry and listPane or focusPane, "BOTTOMLEFT", 0, -SECTION_GAP)
    if not entry then
        local done = #Sell.postedOrder > 0
        message.title:SetText(done and TEXT_DONE or TEXT_EMPTY)
        message.sub:SetText(done and TEXT_DONE_SUB:format(Coins((Sell.Totals()))) or TEXT_EMPTY_SUB)
        return
    end
    local price, why, ref = Sell.Price(entry)
    head.icon.texture:SetTexture(entry.icon)
    head.link = entry.link
    local color = Items.QualityColor(entry.itemID) or T.fg
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(TEXT_COUNT:format(ItemName(entry), entry.count))
    head.sub:SetText(entry.scan and TEXT_SCAN_SUB:format(Coins(entry.scan)) or TEXT_NO_SCAN_SUB)
    head.listed:SetText(entry.vendorBetter and "" or ListedText())
    reason.text:SetText(Reason(entry, price, why, ref))
    DrawForm(entry, price)
    DrawPost(entry, price)
    listPane:SetHeight(listPane:Paint(entry, price))
end

local function Line(n, kind, entry, text)
    local line = lines[n]
    if not line then
        line = {}
        lines[n] = line
    end
    line.kind, line.entry, line.text = kind, entry, text
    return n
end

local function Lines()
    local n = 0
    local hidden = 0
    for _, entry in ipairs(Sell.queue) do
        if entry.hidden then
            hidden = hidden + 1
        elseif not entry.vendorBetter then
            n = Line(n + 1, "item", entry)
        end
    end
    local vendorHead = false
    for _, entry in ipairs(Sell.queue) do
        if entry.vendorBetter and not entry.hidden then
            if not vendorHead then
                n = Line(n + 1, "section", nil, TEXT_VENDOR_SECTION)
                vendorHead = true
            end
            n = Line(n + 1, "item", entry)
        end
    end
    if #Sell.postedOrder > 0 then n = Line(n + 1, "section", nil, TEXT_POSTED_SECTION) end
    for _, done in ipairs(Sell.postedOrder) do n = Line(n + 1, "posted", done) end
    if hidden == 0 then return n end
    n = Line(n + 1, "fold", nil, TEXT_HIDDEN_SECTION:format(hidden))
    if not hiddenOpen then return n end
    for _, entry in ipairs(Sell.queue) do
        if entry.hidden then n = Line(n + 1, "item", entry) end
    end
    return n
end

local function Remark()
    local focus = Sell.Focus()
    loading = Sell.Read()
    if focus and Sell.Hidden(focus.itemID) then Sell.Pick(nil) end
    Sell.Keep()
    Page.Draw()
end

local function ToggleFavourite(itemID)
    Sell.SetFavourite(itemID, not Sell.Favourite(itemID))
    Remark()
end

local function ToggleHidden(itemID)
    Sell.SetHidden(itemID, not Sell.Hidden(itemID))
    Remark()
end

local function RowMenu(row, root)
    local itemID = row.entry.itemID
    root:CreateButton(Sell.Favourite(itemID) and TEXT_UNFAVOURITE or TEXT_FAVOURITE, ToggleFavourite, itemID)
    root:CreateButton(Sell.Hidden(itemID) and TEXT_UNHIDE or TEXT_HIDE, ToggleHidden, itemID)
end

local function QueueClicked(row, button)
    if row.kind == "fold" then
        hiddenOpen = not hiddenOpen
        return Page.Draw()
    end
    if row.kind ~= "item" then return end
    if button == "RightButton" then return ns.ContextMenu(row, RowMenu) end
    failed = false
    Sell.Pick(row.entry.key)
    Page.Draw()
end

local function QueueEnter(row)
    if row.kind == "section" then return end
    row.hover:Show()
    ShowTip(row, row.kind == "item" and TEXT_ROW_HINT or nil)
end

local function QueueLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function NewQueueRow()
    local row = CreateFrame("Button", nil, list)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.marker = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.marker:SetPoint("TOPLEFT")
    row.marker:SetPoint("BOTTOMLEFT")
    row.marker:SetWidth(MARKER_W)
    row.icon = Parts.ItemIcon(row, QUEUE_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.star = row.icon:CreateTexture(nil, "OVERLAY")
    row.star:SetTexture(St.STAR, nil, nil, "TRILINEAR")
    row.star:SetSize(STAR_SIZE, STAR_SIZE)
    row.star:SetPoint("CENTER", row.icon, "TOPLEFT", STAR_IN, -STAR_IN)
    row.star:SetVertexColor(St.GOLD_RGB.r, St.GOLD_RGB.g, St.GOLD_RGB.b, 1)
    row.worth = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.worth:SetPoint("TOPRIGHT", -ROW_IN, -ROW_LINE_IN)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", ROW_TEXT_GAP, 0)
    row.name:SetPoint("RIGHT", row.worth, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.sub = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", ROW_TEXT_GAP, 0)
    row.sub:SetPoint("RIGHT", -ROW_IN, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.section = ns.Font(row, SMALL_SIZE, nil, T.muted, true)
    row.section:SetPoint("LEFT", ROW_IN, 0)
    row.fold = Parts.Arrow(row, FOLD_SIZE, T.muted)
    row.fold:SetPoint("RIGHT", -ROW_IN, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", QueueClicked)
    row:SetScript("OnEnter", QueueEnter)
    row:SetScript("OnLeave", QueueLeave)
    return row
end

local function ItemSub(entry)
    if entry.vendorBetter then return TEXT_VENDOR_EACH:format(Coins(entry.vendor)) end
    local each, focus = entry.scan, Sell.Focus()
    if focus and focus.key == entry.key then each = (Sell.Price(entry)) end
    return each and TEXT_EACH:format(Coins(each)) or TEXT_NO_PRICE
end

local function PaintQueueRow(row, line, focusKey, index)
    local fold = line.kind == "fold"
    local section = fold or line.kind == "section"
    row.kind, row.entry = line.kind, line.entry
    row.fold:SetShown(fold)
    row.fold:SetRotation(hiddenOpen and St.OPEN_TURN or 0)
    row.star:SetShown(line.kind == "item" and line.entry.favourite)
    row:SetHeight(section and SECTION_H or QUEUE_ROW_H)
    row.section:SetShown(section)
    row.icon:SetShown(not section)
    row.name:SetShown(not section)
    row.worth:SetShown(not section)
    row.sub:SetShown(not section)
    row.stripe:SetShown(not section and index % 2 == 0)
    local picked = line.kind == "item" and line.entry.key == focusKey
    row.picked:SetShown(picked)
    row.marker:SetShown(picked)
    if section then
        row.section:SetText(line.text)
        row.link = nil
        row:SetAlpha(1)
        return
    end
    local entry = line.entry
    row.link = entry.link
    row.icon.texture:SetTexture(entry.icon)
    local color = Items.QualityColor(entry.itemID) or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    if line.kind == "posted" then
        row.name:SetText(GetItemInfo(entry.link) or Items.Name(entry.itemID))
        row.worth:SetText(Coins(entry.quantity * entry.price))
        row.sub:SetText(TEXT_POSTED_EACH:format(entry.quantity, Coins(entry.price)))
        row:SetAlpha(St.DISABLED_ALPHA)
        return
    end
    row:SetAlpha(1)
    row.name:SetText(TEXT_COUNT:format(ItemName(entry), entry.count))
    row.worth:SetText(entry.worth > 0 and Parts.Coins(entry.worth) or "")
    row.sub:SetText(ItemSub(entry))
end

local function DrawQueue()
    local n = Lines()
    local focus = Sell.Focus()
    local focusKey = focus and focus.key
    local y = 0
    for i = 1, n do
        local row = queueRows[i] or NewQueueRow()
        queueRows[i] = row
        PaintQueueRow(row, lines[i], focusKey, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + row:GetHeight()
    end
    for i = n + 1, #queueRows do queueRows[i]:Hide() end
    list:SetHeight(math.max(1, y))
    local left = Sell.Left()
    local postedTotal, total = Sell.Totals()
    queuePane.sub:SetText(left > 0 and TEXT_LEFT:format(left, Parts.Coins(total - postedTotal))
        or TEXT_ALL_POSTED)
end

local function DrawBar()
    local postedTotal, total = Sell.Totals()
    bar.total:SetText(TEXT_TOTAL:format(Parts.Coins(postedTotal), Parts.Coins(total)))
    bar.progress:SetProgress(total > 0 and postedTotal / total or 0)
end

function Page.Draw()
    if not active then return end
    DrawFocus()
    DrawQueue()
    DrawBar()
end

local function Reread()
    reread = false
    if not active then return end
    loading = Sell.Read()
    Sell.Keep()
    Page.Draw()
end

local function QueueReread()
    if reread then return end
    reread = true
    C_Timer.After(NEXT_FRAME, Reread)
end

local function OnEvent(_, event)
    if event == "PLAYER_MONEY" then return Page.Draw() end
    if event == "AUCTION_CANCELED" then
        Listings.Again()
        return Page.Draw()
    end
    if THROTTLE_EVENTS[event] then
        local entry = Sell.Focus()
        if entry then Enable(post, CanPost(entry)) end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" and not loading then return end
    QueueReread()
end

local function Send(entry, count, price, startBid)
    failed = false
    Post.Send(entry, count, price, Sell.Duration(), startBid)
    Page.Draw()
end

local function AskClosed()
    asking = nil
end

local function PostAsked()
    asking = nil
    local entry = Market.Bags.Get(ask.key)
    if not (entry and Post.Ready() and ask.count <= entry.count) then return Page.Draw() end
    Send(entry, ask.count, ask.price, ask.bid)
end

local function AcceptAsk()
    asking.onClose = nil
    asking:Hide()
    PostAsked()
end

local function Idle() end

local function DoPost()
    local entry = Sell.Focus()
    if asking or listPane:Asking() or not CanPost(entry) then return end
    local count, price, startBid = Sell.Quantity(entry), (Sell.Price(entry)), Sell.Bid(entry)
    local risk, ref = Sell.Risk(entry, price)
    if not risk then return Send(entry, count, price, startBid) end
    ask.key, ask.count, ask.price, ask.bid = entry.key, count, price, startBid
    local _, dimmer = ns.Confirm(ASKS[risk]:format(ItemName(entry), Coins(price), Coins(ref)), PostAsked, AskClosed,
        TEXT_POST_ANYWAY, TEXT_CANCEL)
    asking = dimmer
end

local function Skip()
    failed = false
    Sell.Next()
    Page.Draw()
end

local function PriceUp()
    local entry = Sell.Focus()
    if entry and Sell.StepPrice(entry, true) then Page.Draw() end
end

local function PriceDown()
    local entry = Sell.Focus()
    if entry and Sell.StepPrice(entry, false) then Page.Draw() end
end

local function Posted(key, count, price, ok, itemID, duration)
    if not ok then
        failed = true
        return Page.Draw()
    end
    Sell.Posted(key, count, price, itemID, duration)
    local focus = Sell.Focus()
    if focus and focus.key == key then Sell.Next() end
    Page.Draw()
end

local function PriceTyped(_, amount)
    local entry = Sell.Focus()
    if not entry then return end
    Sell.SetPrice(entry.key, amount)
    Page.Draw()
end

local function TakePast(price)
    local entry = Sell.Focus()
    if not entry then return end
    failed = false
    Sell.SetPrice(entry.key, price)
    Page.Draw()
end

local function TakeLast()
    local entry = Sell.Focus()
    if entry then TakePast((Sell.Past(entry.itemID, 1))) end
end

local function PastMenu(_, root)
    local entry = Sell.Focus()
    if not entry then return end
    local key = entry.key
    for i = 1, Sell.PastCount(entry.itemID) do
        local price, count, duration, at = Sell.Past(entry.itemID, i)
        root:CreateButton(TEXT_PAST_ROW:format(Coins(price), count, C.DURATION_LABELS[duration], When(at)), function()
            local focus = Sell.Focus()
            if focus and focus.key == key then TakePast(price) end
        end)
    end
end

local function ShowPast(link)
    ns.ContextMenu(link, PastMenu)
end

local function BidTyped(_, amount)
    local entry = Sell.Focus()
    if not entry then return end
    Sell.SetBid(entry.key, amount)
    Page.Draw()
end

local function QuantityTyped(box, userInput)
    if not userInput then return end
    local entry = Sell.Focus()
    local count = tonumber(box:GetText())
    if not (entry and count) then return end
    Sell.SetQuantity(entry.key, math.max(1, math.min(count, entry.count)))
    Page.Draw()
end

local function DurationPicked(key)
    S.Set("duration", key)
    Page.Draw()
end

local function Label(parent, text)
    local label = ns.Font(parent, SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT")
    label:SetText(text)
    return label
end

local function BuildHead()
    head = CreateFrame("Frame", nil, content)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head.icon = Parts.ItemIcon(head, HEAD_ICON)
    head.icon:SetPoint("LEFT")
    head.icon:EnableMouse(true)
    head.icon:SetScript("OnEnter", function() ShowTip(head) end)
    head.icon:SetScript("OnLeave", GameTooltip_Hide)
    head.listed = ns.Font(head, SMALL_SIZE, nil, T.muted)
    head.listed:SetPoint("TOPRIGHT", 0, -SUB_GAP)
    head.name = ns.Font(head, NAME_SIZE, nil, T.fg, true)
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", NAME_GAP, 0)
    head.name:SetPoint("RIGHT", head.listed, "LEFT", -GAP, 0)
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.sub = ns.Font(head, SMALL_SIZE, nil, T.muted)
    head.sub:SetPoint("TOPLEFT", head.name, "BOTTOMLEFT", 0, -SUB_GAP)
end

local function BuildReason()
    reason = CreateFrame("Frame", nil, content)
    reason:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SECTION_GAP)
    reason:SetPoint("RIGHT")
    reason:SetHeight(REASON_H)
    local icon = reason:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(St.INFO, nil, nil, "TRILINEAR")
    icon:SetSize(INFO_SIZE, INFO_SIZE)
    icon:SetPoint("TOPLEFT")
    icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
    reason.text = ns.Font(reason, SMALL_SIZE, nil, T.fg)
    reason.text:SetPoint("TOPLEFT", icon, "TOPRIGHT", INFO_GAP, 0)
    reason.text:SetPoint("RIGHT")
    reason.text:SetJustifyH("LEFT")
    reason.text:SetJustifyV("TOP")
end

local function BuildForm()
    form = CreateFrame("Frame", nil, content)
    form:SetPoint("TOPLEFT", reason, "BOTTOMLEFT", 0, -SECTION_GAP)
    form:SetPoint("RIGHT")
    form:SetHeight(FORM_H)
    money = Parts.MoneyBox(form, PriceTyped)
    money:SetPoint("BOTTOMLEFT")
    Label(form, TEXT_PRICE)
    local count = CreateFrame("Frame", nil, form)
    count:SetPoint("BOTTOMLEFT", money.boxes[3], "BOTTOMRIGHT", FIELD_GAP, 0)
    count:SetSize(QTY_BOX_W, FORM_H)
    Label(count, TEXT_QUANTITY)
    quantity = ns.NewEditBox(count)
    quantity:SetSize(QTY_BOX_W, money:GetHeight())
    quantity:SetPoint("BOTTOMLEFT")
    quantity:SetNumeric(true)
    quantity:SetMaxLetters(QTY_LETTERS)
    quantity:SetJustifyH("CENTER")
    quantity:SetScript("OnTextChanged", QuantityTyped)
    quantity:SetScript("OnEnterPressed", quantity.ClearFocus)
    quantity:SetScript("OnEscapePressed", quantity.ClearFocus)
    quantityOf = ns.Font(form, TEXT_SIZE, nil, T.muted)
    quantityOf:SetPoint("LEFT", quantity, "RIGHT", OF_GAP, 0)
    form.chips = Market.Quantity.New(form, Page.Draw)
    form.chips:SetPoint("TOPRIGHT")
    bidRow = CreateFrame("Frame", nil, content)
    bidRow:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -SECTION_GAP)
    bidRow:SetPoint("RIGHT")
    bidRow:SetHeight(money:GetHeight())
    bid = Parts.MoneyBox(bidRow, BidTyped)
    bid:ShowCopper(false)
    bid:SetPoint("RIGHT")
    local bidLabel = ns.Font(bidRow, SMALL_SIZE, nil, T.muted)
    bidLabel:SetPoint("LEFT")
    bidLabel:SetText(TEXT_BID)
    bidRow:Hide()
    durationRow = CreateFrame("Frame", nil, content)
    durationRow:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -SECTION_GAP)
    durationRow:SetPoint("RIGHT")
    durationRow:SetHeight(St.TAB_H)
    local items = {}
    for i, duration in ipairs(C.DURATIONS) do items[i] = { key = duration, label = C.DURATION_LABELS[duration] } end
    durations = Parts.Tabs(durationRow, DURATION_W, items, DurationPicked, nil, nil, true)
    durations:SetPoint("RIGHT")
    local label = ns.Font(durationRow, SMALL_SIZE, nil, T.muted)
    label:SetPoint("LEFT")
    label:SetText(TEXT_DURATION)
    return durationRow
end

local function BuildPostRow(above)
    post = ns.Button(content, "", 1, BUTTON_H, DoPost)
    ns.PrimaryButton(post)
    post:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -SECTION_GAP)
    post:SetPoint("LEFT", content, "LEFT", SKIP_W + POST_GAP, 0)
    skip = ns.Button(content, TEXT_SKIP, SKIP_W, BUTTON_H, Skip)
    skip:SetPoint("RIGHT", post, "LEFT", -POST_GAP, 0)
    netText = ns.Font(content, SMALL_SIZE, nil, T.muted)
    netText:SetPoint("TOPLEFT", skip, "BOTTOMLEFT", 0, -NET_GAP)
    netText:SetPoint("RIGHT")
    netText:SetJustifyH("LEFT")
    pastRow = CreateFrame("Frame", nil, content)
    pastRow:SetPoint("TOPLEFT", skip, "BOTTOMLEFT", 0, -(NET_GAP + NET_H + NET_GAP))
    pastRow:SetPoint("RIGHT")
    pastRow:SetHeight(PAST_H)
    pastRow.last = Parts.Link(pastRow, TakeLast)
    pastRow.last:SetPoint("LEFT")
    pastRow.all = Parts.Link(pastRow, ShowPast)
    pastRow.all:SetPoint("RIGHT")
    pastRow:Hide()
end

local function BuildMessage()
    message = CreateFrame("Frame", nil, focusPane)
    message:SetAllPoints()
    message.title = ns.Font(message, EMPTY_SIZE, nil, T.fg, true)
    message.title:SetPoint("BOTTOM", message, "CENTER", 0, EMPTY_GAP / 2)
    message.title:SetWidth(DURATION_W)
    message.sub = ns.Font(message, SMALL_SIZE, nil, T.muted)
    message.sub:SetPoint("TOP", message, "CENTER", 0, -EMPTY_GAP / 2)
    message.sub:SetWidth(DURATION_W)
end

local function BuildQueue(top)
    queuePane = CreateFrame("Frame", nil, page)
    queuePane:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -SECTION_GAP)
    queuePane:SetPoint("BOTTOMRIGHT", 0, BAR_H + SECTION_GAP)
    Panel(queuePane)
    local title = ns.Font(queuePane, TEXT_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    title:SetText(TEXT_UP_NEXT)
    queuePane.sub = ns.Font(queuePane, SMALL_SIZE, nil, T.muted)
    queuePane.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    scroll = ns.UI.SlimScroll(queuePane)
    scroll:SetPoint("TOPLEFT", 0, -QUEUE_HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    scroll:HookScript("OnSizeChanged", function(_, width) list:SetWidth(width) end)
end

local function BuildBar()
    bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(BAR_H)
    bar.total = ns.Font(bar, SMALL_SIZE, nil, T.fg)
    bar.total:SetPoint("LEFT")
    bar.progress = Parts.ProgressLine(bar, PROGRESS_H)
    bar.progress:SetPoint("LEFT", bar.total, "RIGHT", PROGRESS_GAP, 0)
    bar.progress:SetPoint("RIGHT")
    bar.progress:Paint(St.GOLD_RGB)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    focusPane = CreateFrame("Frame", nil, page)
    focusPane:SetPoint("TOPLEFT")
    focusPane:SetPoint("TOPRIGHT")
    focusPane:SetHeight(FOCUS_H)
    content = CreateFrame("Frame", nil, focusPane)
    content:SetAllPoints()
    BuildHead()
    BuildReason()
    BuildPostRow(BuildForm())
    BuildMessage()
    BuildBar()
    listPane = Market.Listed.New(page, Page.Draw)
    listPane:SetPoint("TOPLEFT", focusPane, "BOTTOMLEFT", 0, -SECTION_GAP)
    listPane:SetPoint("RIGHT")
    BuildQueue(focusPane)
    Post.onDone = Posted
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function Page.Show()
    page:Show()
    list:SetWidth(scroll:GetWidth())
    if not active then
        active, failed = true, false
        Listings.Start()
        Listings.onChange = Page.Draw
        Post.Start()
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        loading = Sell.Read()
        Sell.Resume()
    end
    Page.Draw()
end

function Page.Refresh()
    QueueReread()
end

function Page.Hide()
    page:Hide()
    if not active then return end
    active = false
    if asking then asking:Hide() end
    listPane:Close()
    events:UnregisterAllEvents()
    Listings.Stop()
    Post.Stop()
end

function Page.PickLocation(location)
    local key = Market.Bags.KeyAt(location)
    if not (active and key and Market.Bags.Get(key)) then return end
    failed = false
    Sell.Pick(key)
    Page.Draw()
end

function Page.KeyAction(key)
    if not (active and S.Get("postKeys")) then return end
    if asking then return key == "ENTER" and AcceptAsk or ASK_KEYS[key] and Idle or nil end
    if listPane:Asking() then return ASK_KEYS[key] and Idle or nil end
    if not Sell.Focus() then return end
    if key == "SPACE" then return DoPost end
    if key == "S" then return Skip end
    if key == "UP" then return PriceUp end
    if key == "DOWN" then return PriceDown end
end
