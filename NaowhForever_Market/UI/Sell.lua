-- Sell.lua: the Sell page: the item in front of you with its listings and price, the post line, and what comes after it.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local C = Market.C
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Sell, Listings, Post, Ladder = Market.Sell, Market.Listings, Market.Post, Market.Ladder

local GAP, TEXT_SIZE, SMALL_SIZE = St.GAP, St.TEXT_SIZE, St.SMALL_SIZE
local BORDER_RGB, QUEUE_W, BUTTON_H = St.BORDER_RGB, St.QUEUE_W, St.BUTTON_H
local PANE_GAP = 12
local HEAD_ICON, NAME_SIZE, HEAD_H, NAME_GAP, SUB_GAP = 40, 18, 44, 10, 4
local SECTION_GAP = 12
local LADDER_ROWS = Ladder.ROWS
local REASON_H, INFO_SIZE, INFO_GAP = 20, 14, 6
local FIELD_LABEL_H, FIELD_GAP, FORM_H = 16, 28, 42
local QTY_BOX_W, QTY_LETTERS, OF_GAP = 60, 5, 6
local DURATION_W = 270
local POST_W, SKIP_W, POST_GAP = 260, 90, 8
local BAR_H, PROGRESS_H, PROGRESS_GAP, HINT_W = 26, 4, 12, 300
local QUEUE_HEAD_H, QUEUE_ROW_H, QUEUE_ICON, SECTION_H = 46, 42, 28, 24
local ROW_IN, ROW_TEXT_GAP, ROW_LINE_IN = 8, 8, 4
local MARKER_W, SCROLL_IN = 2, 4
local EMPTY_SIZE, EMPTY_GAP = 16, 6
local NEXT_FRAME = 0
local TEXT_LADDER = ns.L("Listings now, cheapest first")
local TEXT_SEARCHING = ns.L("Searching")
local TEXT_NONE = ns.L("Nobody is selling this")
local TEXT_LISTED = ns.L("%s listed")
local TEXT_YOURS = ns.L(" yours")
local TEXT_YOUR_POST = ns.L(" your post")
local TEXT_POST = ns.L("Post %d for %s")
local TEXT_POSTING = ns.L("Posting")
local TEXT_SKIP = ns.L("Skip")
local TEXT_PRICE = ns.L("Price Each")
local TEXT_QUANTITY = ns.L("Quantity")
local TEXT_OF = ns.L("of %d")
local TEXT_DURATION = ns.L("Duration")
local TEXT_DEPOSIT = ns.L("Deposit %s, back if it sells.")
local TEXT_NET = ns.L("You get %s after the 5%% cut.")
local TEXT_SHORT = ns.L("You need %s for the deposit.")
local TEXT_UP_NEXT = ns.L("Up Next")
local TEXT_LEFT = ns.L("%d to post, %s at your prices")
local TEXT_ALL_POSTED = ns.L("Everything is posted")
local TEXT_VENDOR_SECTION = ns.L("For a Vendor")
local TEXT_POSTED_SECTION = ns.L("Posted This Visit")
local TEXT_EACH = ns.L("%s each")
local TEXT_POSTED_EACH = ns.L("Posted %d at %s each")
local TEXT_VENDOR_EACH = ns.L("A vendor pays %s each")
local TEXT_NO_PRICE = ns.L("No price yet")
local TEXT_TOTAL = ns.L("%s posted of %s")
local TEXT_KEYS = ns.L("Space Post   S Skip   Up/Down Price step")
local TEXT_SCAN_SUB = ns.L("Your last scan: %s each")
local TEXT_NO_SCAN_SUB = ns.L("Not in your scans yet")
local TEXT_COUNT = "%s x%d"
local TEXT_EMPTY = ns.L("Nothing in your bags the auction house takes.")
local TEXT_EMPTY_SUB = ns.L("Right-click an item in your bags to sell it here.")
local TEXT_DONE = ns.L("Everything is posted.")
local TEXT_DONE_SUB = ns.L("%s listed this visit.")
local REASONS = {
    under = ns.L("%s under the cheapest listing, %s."),
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
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT" }
local THROTTLE_EVENTS = { AUCTION_HOUSE_THROTTLED_SYSTEM_READY = true, AUCTION_HOUSE_THROTTLED_MESSAGE_SENT = true }

local page, pane, content, message, queuePane, scroll, list, bar
local head, ladder, reason, money, quantity, quantityOf, durations, depositText, netText, skip, post
local queueRows, lines, display = {}, {}, {}
local events
local active, loading, failed, reread = false, false, false, false

local Page = {}
Market.Pages.sell = Page

local function Coins(copper)
    return Parts.Coins(copper)
end

local function ItemName(entry)
    return GetItemInfo(entry.link) or Items.Name(entry.itemID)
end

local function QualityColor(entry)
    return Items.QualityColor(entry.itemID) or T.fg
end

local Enable = St.Enable

local function Panel(frame)
    ns.Solid(frame, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(frame, BORDER_RGB)
end

local function ShowTip(frame)
    local link = frame.link
    if not link then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

local function CanPost(entry)
    if not entry or not Post.Ready() then return false end
    local _, why = Sell.Price(entry)
    local state = Listings.state
    if why ~= "hand" and state ~= "listed" and state ~= "noanswer" then return false end
    local deposit = Post.Deposit(entry, Sell.Quantity(entry), Sell.Duration())
    return Sell.Quantity(entry) > 0 and (deposit or 0) <= GetMoney()
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

local function Fill(n, price, count, own, mine)
    local rung = Ladder.Rung(display, n)
    rung.price, rung.count, rung.lit = price, count, mine
    rung.label = mine and TEXT_YOUR_POST or (own > 0 and TEXT_YOURS or nil)
end

local function LadderRows(price, count)
    local n, placed = 0, false
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        if not placed and price <= row.price and n < LADDER_ROWS then
            n = n + 1
            Fill(n, price, count, 0, true)
            placed = true
        end
        if n >= LADDER_ROWS then break end
        n = n + 1
        Fill(n, row.price, row.quantity, row.own, false)
    end
    if not placed then
        n = math.min(n, LADDER_ROWS - 1) + 1
        Fill(n, price, count, 0, true)
    end
    return n
end

local function DrawLadder(entry, price, count)
    local state = Listings.state
    local total = 0
    for i = 1, Listings.count do total = total + Listings.rows[i].quantity end
    if state == "listed" then
        ladder:SetStatus(total > 0 and TEXT_LISTED:format(BreakUpLargeNumbers(total)) or TEXT_NONE)
    else
        ladder:SetStatus(state == "noanswer" and "" or TEXT_SEARCHING)
    end
    ladder:Paint(display, entry.vendorBetter and 0 or LadderRows(price, count))
end

local function DrawForm(entry, price)
    if not money:HasFocus() then money:SetAmount(price) end
    if not quantity:HasFocus() then quantity:SetText(Sell.Quantity(entry)) end
    quantityOf:SetText(TEXT_OF:format(entry.count))
    Parts.PaintTabs(durations, Sell.Duration())
end

local function DrawPost(entry, price)
    local count = Sell.Quantity(entry)
    local deposit = Post.Deposit(entry, count, Sell.Duration())
    if deposit and deposit > GetMoney() then
        depositText:SetText(TEXT_SHORT:format(Coins(deposit)))
    else
        depositText:SetText(deposit and TEXT_DEPOSIT:format(Coins(deposit)) or "")
    end
    netText:SetText(TEXT_NET:format(Coins(Market.AfterCut(price * count))))
    ns.SetButtonText(post, Post.Waiting() and TEXT_POSTING or TEXT_POST:format(count, Coins(price * count)))
    Enable(post, CanPost(entry))
end

local function DrawFocus()
    local entry = Sell.Focus()
    content:SetShown(entry ~= nil)
    message:SetShown(entry == nil)
    if not entry then
        local done = #Sell.postedOrder > 0
        message.title:SetText(done and TEXT_DONE or TEXT_EMPTY)
        message.sub:SetText(done and TEXT_DONE_SUB:format(Coins((Sell.Totals()))) or TEXT_EMPTY_SUB)
        return
    end
    local price, why, ref = Sell.Price(entry)
    local count = Sell.Quantity(entry)
    head.icon.texture:SetTexture(entry.icon)
    head.link = entry.link
    local color = QualityColor(entry)
    head.name:SetTextColor(color.r, color.g, color.b)
    head.name:SetText(TEXT_COUNT:format(ItemName(entry), entry.count))
    head.sub:SetText(entry.scan and TEXT_SCAN_SUB:format(Coins(entry.scan)) or TEXT_NO_SCAN_SUB)
    DrawLadder(entry, price, count)
    reason.text:SetText(Reason(entry, price, why, ref))
    DrawForm(entry, price)
    DrawPost(entry, price)
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
    for _, entry in ipairs(Sell.queue) do
        if not entry.vendorBetter then n = Line(n + 1, "item", entry) end
    end
    local vendorHead = false
    for _, entry in ipairs(Sell.queue) do
        if entry.vendorBetter then
            if not vendorHead then
                n = Line(n + 1, "section", nil, TEXT_VENDOR_SECTION)
                vendorHead = true
            end
            n = Line(n + 1, "item", entry)
        end
    end
    if #Sell.postedOrder > 0 then n = Line(n + 1, "section", nil, TEXT_POSTED_SECTION) end
    for _, done in ipairs(Sell.postedOrder) do n = Line(n + 1, "posted", done) end
    return n
end

local function QueueClicked(row)
    if row.kind ~= "item" then return end
    failed = false
    Sell.Pick(row.entry.key)
    Page.Draw()
end

local function QueueEnter(row)
    if row.kind == "section" then return end
    row.hover:Show()
    ShowTip(row)
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
    local section = line.kind == "section"
    row.kind, row.entry = line.kind, line.entry
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
    row.worth:SetText(entry.worth > 0 and Parts.Coins(entry.worth, true) or "")
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
    queuePane.sub:SetText(left > 0 and TEXT_LEFT:format(left, Parts.Coins(total - postedTotal, true))
        or TEXT_ALL_POSTED)
end

local function DrawBar()
    local postedTotal, total = Sell.Totals()
    bar.total:SetText(TEXT_TOTAL:format(Parts.Coins(postedTotal, true), Parts.Coins(total, true)))
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
    if THROTTLE_EVENTS[event] then
        local entry = Sell.Focus()
        if entry then Enable(post, CanPost(entry)) end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" and not loading then return end
    QueueReread()
end

local function DoPost()
    local entry = Sell.Focus()
    if not CanPost(entry) then return end
    failed = false
    Post.Send(entry, Sell.Quantity(entry), (Sell.Price(entry)), Sell.Duration())
    Page.Draw()
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

local function Posted(key, count, price, ok)
    if not ok then
        failed = true
        return Page.Draw()
    end
    Sell.Posted(key, count, price)
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

local function Label(parent, text, anchor)
    local label = ns.Font(parent, SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
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
    head.name = ns.Font(head, NAME_SIZE, nil, T.fg, true)
    head.name:SetPoint("TOPLEFT", head.icon, "TOPRIGHT", NAME_GAP, 0)
    head.name:SetPoint("RIGHT")
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.sub = ns.Font(head, SMALL_SIZE, nil, T.muted)
    head.sub:SetPoint("TOPLEFT", head.name, "BOTTOMLEFT", 0, -SUB_GAP)
end

local function BuildLadder()
    ladder = Ladder.New(content, TEXT_LADDER)
    ladder:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -SECTION_GAP)
    ladder:SetPoint("RIGHT")
end

local function BuildReason()
    reason = CreateFrame("Frame", nil, content)
    reason:SetPoint("TOPLEFT", ladder, "BOTTOMLEFT", 0, -SECTION_GAP)
    reason:SetPoint("RIGHT")
    reason:SetHeight(REASON_H)
    local icon = reason:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(St.INFO, nil, nil, "TRILINEAR")
    icon:SetSize(INFO_SIZE, INFO_SIZE)
    icon:SetPoint("LEFT")
    icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
    reason.text = ns.Font(reason, TEXT_SIZE, nil, T.fg)
    reason.text:SetPoint("LEFT", icon, "RIGHT", INFO_GAP, 0)
    reason.text:SetPoint("RIGHT")
    reason.text:SetJustifyH("LEFT")
end

local function BuildForm()
    local form = CreateFrame("Frame", nil, content)
    form:SetPoint("TOPLEFT", reason, "BOTTOMLEFT", 0, -SECTION_GAP)
    form:SetPoint("RIGHT")
    form:SetHeight(FORM_H)
    money = Parts.MoneyBox(form, PriceTyped)
    money:SetPoint("BOTTOMLEFT")
    Label(form, TEXT_PRICE, form)
    local count = CreateFrame("Frame", nil, form)
    count:SetPoint("BOTTOMLEFT", money, "BOTTOMRIGHT", FIELD_GAP, 0)
    count:SetSize(QTY_BOX_W, FORM_H)
    Label(count, TEXT_QUANTITY, count)
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
    local items = {}
    for i, duration in ipairs(C.DURATIONS) do items[i] = { key = duration, label = C.DURATION_LABELS[duration] } end
    durations = Parts.Tabs(form, DURATION_W, items, DurationPicked)
    durations:SetPoint("BOTTOMRIGHT")
    local label = ns.Font(form, SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT", durations, "TOPLEFT", 0, FIELD_LABEL_H)
    label:SetText(TEXT_DURATION)
end

local function BuildPostRow()
    post = ns.Button(content, "", POST_W, BUTTON_H, DoPost)
    ns.PrimaryButton(post)
    post:SetPoint("BOTTOMRIGHT")
    skip = ns.Button(content, TEXT_SKIP, SKIP_W, BUTTON_H, Skip)
    skip:SetPoint("RIGHT", post, "LEFT", -POST_GAP, 0)
    netText = ns.Font(content, TEXT_SIZE, nil, T.muted)
    netText:SetPoint("BOTTOMLEFT")
    netText:SetPoint("RIGHT", skip, "LEFT", -GAP, 0)
    netText:SetJustifyH("LEFT")
    depositText = ns.Font(content, TEXT_SIZE, nil, T.fg)
    depositText:SetPoint("BOTTOMLEFT", netText, "TOPLEFT", 0, SUB_GAP)
    depositText:SetPoint("RIGHT", skip, "LEFT", -GAP, 0)
    depositText:SetJustifyH("LEFT")
end

local function BuildMessage()
    message = CreateFrame("Frame", nil, pane)
    message:SetAllPoints()
    message.title = ns.Font(message, EMPTY_SIZE, nil, T.fg, true)
    message.title:SetPoint("BOTTOM", message, "CENTER", 0, EMPTY_GAP / 2)
    message.sub = ns.Font(message, TEXT_SIZE, nil, T.muted)
    message.sub:SetPoint("TOP", message, "CENTER", 0, -EMPTY_GAP / 2)
end

local function BuildQueue()
    queuePane = CreateFrame("Frame", nil, page)
    queuePane:SetPoint("TOPRIGHT")
    queuePane:SetPoint("BOTTOMRIGHT", 0, BAR_H + PANE_GAP)
    queuePane:SetWidth(QUEUE_W)
    Panel(queuePane)
    local title = ns.Font(queuePane, TEXT_SIZE + 2, nil, T.fg, true)
    title:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    title:SetText(TEXT_UP_NEXT)
    queuePane.sub = ns.Font(queuePane, SMALL_SIZE, nil, T.muted)
    queuePane.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    scroll = ns.UI.SlimScroll(queuePane)
    scroll:SetPoint("TOPLEFT", 0, -QUEUE_HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetWidth(QUEUE_W - St.SCROLLBAR - SCROLL_IN)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
end

local function BuildBar()
    bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(BAR_H)
    bar.total = ns.Font(bar, TEXT_SIZE, nil, T.fg)
    bar.total:SetPoint("LEFT")
    local hints = ns.Font(bar, SMALL_SIZE, nil, T.muted)
    hints:SetPoint("RIGHT")
    hints:SetWidth(HINT_W)
    hints:SetJustifyH("RIGHT")
    hints:SetText(TEXT_KEYS)
    bar.hints = hints
    bar.progress = Parts.ProgressLine(bar, PROGRESS_H)
    bar.progress:SetPoint("LEFT", bar.total, "RIGHT", PROGRESS_GAP, 0)
    bar.progress:SetPoint("RIGHT", hints, "LEFT", -PROGRESS_GAP, 0)
    bar.progress:Paint(St.GOLD_RGB)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildQueue()
    BuildBar()
    pane = CreateFrame("Frame", nil, page)
    pane:SetPoint("TOPLEFT")
    pane:SetPoint("BOTTOMRIGHT", -(QUEUE_W + PANE_GAP), BAR_H + PANE_GAP)
    content = CreateFrame("Frame", nil, pane)
    content:SetAllPoints()
    BuildHead()
    BuildLadder()
    BuildReason()
    BuildForm()
    BuildPostRow()
    BuildMessage()
    Post.onDone = Posted
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

function Page.Show()
    page:Show()
    bar.hints:SetShown(S.Get("postKeys"))
    if not active then
        active, failed = true, false
        Listings.Start()
        Listings.onChange = Page.Draw
        Post.Start()
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        money:ShowCopper(C_AuctionHouse.SupportsCopperValues())
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
    if not (active and S.Get("postKeys") and Sell.Focus()) then return end
    if key == "SPACE" then return DoPost end
    if key == "S" then return Skip end
    if key == "UP" then return PriceUp end
    if key == "DOWN" then return PriceDown end
end
