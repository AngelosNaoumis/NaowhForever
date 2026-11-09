-- Runs.lua: the Last Run page: a gathering run's gold over time, what it gathered and what that is worth now.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local C = Market.C
local Parts = ns.Shared.Parts
local Runs, History, Columns = Market.Runs, Market.History, Market.Columns

local TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local HEAD_H, CHART_H, COLUMNS_H, ROW_H, FOOT_H = 52, 170, 22, 32, 34
local CHART_LEFT, CHART_RIGHT, CHART_TOP, CHART_BOTTOM = 56, 12, 14, 22
local ROW_IN, GAP, SUB_GAP, ICON, PICK_W, SCROLL_IN = 8, 6, 4, 22, 28, 4
local QTY_W, MONEY_W, CHANGE_W, POST_W = 70, 100, 70, 200
local LINE_THICK, GRID_ALPHA, DOT = 2, 0.35, 5
local GRID_LINES, X_STEP_MINUTES = 3, 10
local SECONDS_PER_MINUTE = 60
local TOTAL_SIZE = 20
local TEXT_TITLE = ns.L("%s, %d minutes")
local TEXT_SUB = ns.L("%s to %s, %d nodes")
local TEXT_SKILL = { herb = ns.L(", Herbalism %d to %d"), ore = ns.L(", Mining %d to %d") }
local TEXT_PER_HOUR = ns.L("at your last scan's prices, %s an hour")
local TEXT_RUN = ns.L("Run %d of %d")
local TEXT_NONE = ns.L("No runs yet. Gather a herb or vein with The Market on, and your run shows here.")
local TEXT_HAUL, TEXT_GOT, TEXT_BAGS = ns.L("Haul"), ns.L("Gathered"), ns.L("In bags")
local TEXT_LOWEST, TEXT_WEEK, TEXT_WORTH = ns.L("Lowest now"), ns.L("7 days"), ns.L("Worth")
local TEXT_POST = ns.L("Sell These")
local TEXT_POST_AWAY = ns.L("Sell at an auctioneer")
local TEXT_FOOT = ns.L("%d items gathered, %s at your last scan's prices")
local TEXT_AT = ns.L("%s into the run")
local TEXT_SO_FAR = ns.L("Run so far")
local TEXT_MINUTES = "%dm"
local TEXT_CLOCK = "%d:%02d"
local TEXT_CHANGE = "%+.0f%%"
local TEXT_COUNT = "%s x%d"
local TIME_FORMAT = "%H:%M"

local page, head, title, sub, total, perHour, prev, nextButton, runText, chart, plot, cursor
local columns, sorter, scroll, list, empty, foot, footText, postButton
local rows, haul, gridLines, gridLabels, xLabels, steps, dots = {}, {}, {}, {}, {}, {}, {}
local at = 1
local active = false
local curve = {}

local Page = {}
Market.Pages.run = Page

local function Shown()
    return Runs.List()[at]
end

local function Label(pool, i)
    local label = pool[i]
    if not label then
        label = ns.Font(chart, SMALL_SIZE, nil, T.muted)
        pool[i] = label
    end
    label:Show()
    return label
end

local function Line(pool, i, layer)
    local line = pool[i]
    if not line then
        line = plot:CreateLine(nil, layer or "ARTWORK")
        pool[i] = line
    end
    line:Show()
    return line
end

local function HideFrom(pool, first)
    for i = first, #pool do pool[i]:Hide() end
end

local function Curve(run)
    wipe(curve)
    local sum = 0
    for i, event in ipairs(run.events) do
        sum = sum + Runs.EventValue(event)
        curve[i] = sum
    end
    return sum
end

local function DrawChart(run)
    local top = Curve(run)
    local width, height = plot:GetSize()
    local span = math.max(1, run.last - run.start)
    top = math.max(1, top)
    local function X(t) return t / span * width end
    local function Y(v) return v / top * height end
    for i = 0, GRID_LINES do
        local y = Y(top * i / GRID_LINES)
        local line = Line(gridLines, i + 1, "BACKGROUND")
        line:SetThickness(1)
        line:SetColorTexture(T.line.r, T.line.g, T.line.b, GRID_ALPHA)
        line:SetStartPoint("BOTTOMLEFT", plot, 0, y)
        line:SetEndPoint("BOTTOMLEFT", plot, width, y)
        local label = Label(gridLabels, i + 1)
        label:ClearAllPoints()
        label:SetPoint("RIGHT", plot, "BOTTOMLEFT", -GAP, y)
        label:SetText(Parts.Coins(math.floor(top * i / GRID_LINES), true))
    end
    local n = 0
    for minute = 0, span / SECONDS_PER_MINUTE, X_STEP_MINUTES do
        n = n + 1
        local label = Label(xLabels, n)
        label:ClearAllPoints()
        label:SetPoint("TOP", plot, "BOTTOMLEFT", X(minute * SECONDS_PER_MINUTE), -SUB_GAP)
        label:SetText(TEXT_MINUTES:format(minute))
    end
    HideFrom(xLabels, n + 1)
    local gold, s, lastX, lastY = St.GOLD_RGB, 0, 0, 0
    for i, event in ipairs(run.events) do
        local x, y = X(event.t), Y(curve[i])
        s = s + 1
        local flat = Line(steps, s)
        flat:SetThickness(LINE_THICK)
        flat:SetColorTexture(gold.r, gold.g, gold.b, 1)
        flat:SetStartPoint("BOTTOMLEFT", plot, lastX, lastY)
        flat:SetEndPoint("BOTTOMLEFT", plot, x, lastY)
        s = s + 1
        local rise = Line(steps, s)
        rise:SetThickness(LINE_THICK)
        rise:SetColorTexture(gold.r, gold.g, gold.b, 1)
        rise:SetStartPoint("BOTTOMLEFT", plot, x, lastY)
        rise:SetEndPoint("BOTTOMLEFT", plot, x, y)
        local dot = dots[i]
        if not dot then
            dot = plot:CreateTexture(nil, "OVERLAY")
            dot:SetSize(DOT, DOT)
            dot:SetTexture(St.ROUND)
            dots[i] = dot
        end
        local c = event.kind == "herb" and St.HERB_RGB or St.ORE_RGB
        dot:SetVertexColor(c.r, c.g, c.b, 1)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
        dot:Show()
        lastX, lastY = x, y
    end
    HideFrom(steps, s + 1)
    HideFrom(dots, #run.events + 1)
end

local function Nearest(run, x)
    local width = plot:GetWidth()
    local t = x / width * math.max(1, run.last - run.start)
    local pick
    for i, event in ipairs(run.events) do
        if event.t <= t then pick = i end
    end
    return pick
end

local function ChartUpdate()
    local run = Shown()
    local x = GetCursorPosition() / plot:GetEffectiveScale() - plot:GetLeft()
    local i = run and Nearest(run, x)
    if not i then
        cursor:Hide()
        GameTooltip:Hide()
        return
    end
    local event = run.events[i]
    cursor:ClearAllPoints()
    cursor:SetPoint("TOP", plot, "TOPLEFT", event.t / math.max(1, run.last - run.start) * plot:GetWidth(), 0)
    cursor:Show()
    GameTooltip:SetOwner(chart, "ANCHOR_CURSOR")
    local G = ns.Glimmer
    local node = G and G.NODES[event.id]
    GameTooltip:SetText(node and ns.L(node[3]) or "", 1, 1, 1)
    local m = T.muted
    local clock = TEXT_CLOCK:format(math.floor(event.t / SECONDS_PER_MINUTE), event.t % SECONDS_PER_MINUTE)
    GameTooltip:AddLine(TEXT_AT:format(clock), m.r, m.g, m.b)
    for item, qty in pairs(event.items) do
        GameTooltip:AddDoubleLine(TEXT_COUNT:format(C_Item.GetItemNameByID(item) or "", qty),
            Parts.Coins(Runs.EventValue({ items = { [item] = qty } }), true), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(TEXT_SO_FAR, Parts.Coins(curve[i] or 0, true), m.r, m.g, m.b, 1, 1, 1)
    GameTooltip:Show()
end

local function NewRow()
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H)
    Parts.RowBands(row, 0)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        if not Market.Window.AtAuction() then return end
        Market.Window.ShowPage("sell")
        local entry = Market.Bags.Get(self.item)
        if entry then Market.Pages.sell.PickLocation(Market.Bags.Location(entry, true)) end
    end)
    row.icon = Parts.ItemIcon(row, ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ROW_IN, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    local right = ROW_IN
    local function Cell(width)
        local fs = ns.Font(row, TEXT_SIZE, nil, T.fg)
        fs:SetPoint("RIGHT", -right, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("RIGHT")
        right = right + width + GAP
        return fs
    end
    row.worth = Cell(MONEY_W)
    row.week = Cell(CHANGE_W)
    row.lowest = Cell(MONEY_W)
    row.bags = Cell(QTY_W)
    row.got = Cell(QTY_W)
    row.name:SetPoint("RIGHT", row.got, "LEFT", -GAP, 0)
    return row
end

local function DrawHaul(run)
    Columns.Sort(sorter, Runs.Haul(run, haul))
    local y, count, worth = 0, 0, 0
    for i, entry in ipairs(haul) do
        local row = rows[i] or NewRow()
        rows[i] = row
        row.item = entry.item
        row.stripe:SetShown(i % 2 == 0)
        row.icon.texture:SetTexture(C_Item.GetItemIconByID(entry.item))
        local quality = C_Item.GetItemQualityByID(entry.item)
        local color = quality and ITEM_QUALITY_COLORS[quality] or T.fg
        row.name:SetTextColor(color.r, color.g, color.b)
        row.name:SetText(C_Item.GetItemNameByID(entry.item) or "")
        row.got:SetText(entry.qty)
        row.bags:SetText(C_Item.GetItemCount(entry.item))
        local scan = ns.AuctionPrice and ns.AuctionPrice(entry.item)
        row.lowest:SetText(scan and Parts.Coins(scan) or "")
        local change = History.Change(entry.item, C.CHANGE_DAYS)
        row.week:SetText(change and TEXT_CHANGE:format(change) or "")
        local c = change and (change >= 0 and St.HAVE_RGB or St.RED_RGB) or T.muted
        row.week:SetTextColor(c.r, c.g, c.b)
        row.worth:SetText(Parts.Coins(entry.worth, true))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + ROW_H
        count, worth = count + entry.qty, worth + entry.worth
    end
    HideFrom(rows, #haul + 1)
    list:SetHeight(math.max(1, y))
    footText:SetText(TEXT_FOOT:format(count, Parts.Coins(worth, true)))
end

local function SkillText(run)
    local text = ""
    for _, kind in ipairs({ "herb", "ore" }) do
        local from, to = run.from and run.from[kind] or 0, run.to and run.to[kind] or 0
        if to > 0 and to ~= from then text = text .. TEXT_SKILL[kind]:format(from, to) end
    end
    return text
end

function Page.Draw()
    if not active then return end
    local runs = Runs.List()
    at = math.max(1, math.min(at, #runs))
    local run = runs[at]
    head:SetShown(run ~= nil)
    chart:SetShown(run ~= nil)
    columns:SetShown(run ~= nil)
    scroll:SetShown(run ~= nil)
    foot:SetShown(run ~= nil)
    empty:SetShown(run == nil)
    if not run then return end
    local info = run.map and C_Map.GetMapInfo(run.map)
    local minutes = math.floor((run.last - run.start) / SECONDS_PER_MINUTE + 0.5)
    title:SetText(TEXT_TITLE:format(info and info.name or "", minutes))
    sub:SetText(TEXT_SUB:format(date(TIME_FORMAT, run.start), date(TIME_FORMAT, run.last), run.nodes) .. SkillText(run))
    local value = Runs.Value(run)
    total:SetText(Parts.Coins(value, true))
    perHour:SetText(TEXT_PER_HOUR:format(Parts.Coins(math.floor(value / Runs.Hours(run)), true)))
    runText:SetText(TEXT_RUN:format(at, #runs))
    prev:SetEnabled(at < #runs)
    nextButton:SetEnabled(at > 1)
    DrawChart(run)
    DrawHaul(run)
    local atAuction = Market.Window.AtAuction()
    St.Enable(postButton, atAuction)
    ns.SetButtonText(postButton, atAuction and TEXT_POST or TEXT_POST_AWAY)
end

local function Older()
    at = at + 1
    Page.Draw()
end

local function Newer()
    at = at - 1
    Page.Draw()
end

local function PostClicked()
    Market.Window.ShowPage("sell")
end

local function BuildHead()
    head = CreateFrame("Frame", nil, page)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    title = ns.Font(head, St.TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT")
    sub = ns.Font(head, SMALL_SIZE, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    prev = ns.Button(head, "<", PICK_W, BUTTON_H, Older)
    prev:SetPoint("BOTTOMLEFT")
    runText = ns.Font(head, SMALL_SIZE, nil, T.muted)
    runText:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
    nextButton = ns.Button(head, ">", PICK_W, BUTTON_H, Newer)
    nextButton:SetPoint("LEFT", runText, "RIGHT", GAP, 0)
    total = ns.Font(head, TOTAL_SIZE, nil, St.GOLD_RGB, true)
    total:SetPoint("TOPRIGHT")
    perHour = ns.Font(head, SMALL_SIZE, nil, T.muted)
    perHour:SetPoint("TOPRIGHT", total, "BOTTOMRIGHT", 0, -SUB_GAP)
end

local function BuildChart()
    chart = CreateFrame("Frame", nil, page)
    chart:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    chart:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -GAP)
    chart:SetHeight(CHART_H)
    ns.Solid(chart, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(chart, St.BORDER_RGB)
    plot = CreateFrame("Frame", nil, chart)
    plot:SetPoint("TOPLEFT", CHART_LEFT, -CHART_TOP)
    plot:SetPoint("BOTTOMRIGHT", -CHART_RIGHT, CHART_BOTTOM)
    cursor = ns.Solid(plot, "ARTWORK", T.accentSoft, GRID_ALPHA)
    cursor:SetWidth(1)
    cursor:SetPoint("BOTTOM", plot, "BOTTOMLEFT")
    cursor:SetHeight(CHART_H - CHART_TOP - CHART_BOTTOM)
    cursor:Hide()
    chart:EnableMouse(true)
    chart:SetScript("OnEnter", function() chart:SetScript("OnUpdate", ChartUpdate) end)
    chart:SetScript("OnLeave", function()
        chart:SetScript("OnUpdate", nil)
        cursor:Hide()
        GameTooltip:Hide()
    end)
end

local function BuildHaul()
    foot = CreateFrame("Frame", nil, page)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOT_H)
    footText = ns.Font(foot, TEXT_SIZE, nil, T.muted)
    footText:SetPoint("LEFT")
    postButton = ns.Button(foot, TEXT_POST, POST_W, BUTTON_H, PostClicked)
    ns.PrimaryButton(postButton)
    postButton:SetPoint("RIGHT")
    columns = CreateFrame("Frame", nil, page)
    columns:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -GAP)
    columns:SetPoint("TOPRIGHT", chart, "BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), -GAP)
    columns:SetHeight(COLUMNS_H)
    sorter = Columns.New(columns, Market.Settings, "sortRun", "worth", Page.Draw)
    Columns.Add(sorter, { key = "haul", text = TEXT_HAUL, left = ROW_IN, up = true,
        value = function(entry) return (C_Item.GetItemNameByID(entry.item) or ""):lower() end })
    local right = ROW_IN
    for _, column in ipairs({
        { "worth", TEXT_WORTH, MONEY_W, function(entry) return entry.worth end },
        { "week", TEXT_WEEK, CHANGE_W, function(entry) return (History.Change(entry.item, C.CHANGE_DAYS)) end },
        { "lowest", TEXT_LOWEST, MONEY_W, function(entry) return ns.AuctionPrice and (ns.AuctionPrice(entry.item)) end },
        { "bags", TEXT_BAGS, QTY_W, function(entry) return C_Item.GetItemCount(entry.item) end },
        { "got", TEXT_GOT, QTY_W, function(entry) return entry.qty end },
    }) do
        Columns.Add(sorter, { key = column[1], text = column[2], right = right, width = column[3], value = column[4] })
        right = right + column[3] + GAP
    end
    scroll = ns.UI.SlimScroll(page)
    scroll:SetPoint("TOPLEFT", columns, "BOTTOMLEFT")
    scroll:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -(St.SCROLLBAR + SCROLL_IN), GAP)
    list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    scroll:HookScript("OnSizeChanged", function(_, width) list:SetWidth(width) end)
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildHead()
    BuildChart()
    BuildHaul()
    empty = ns.Font(page, TEXT_SIZE, nil, T.muted)
    empty:SetPoint("CENTER")
    empty:SetWidth(St.WINDOW_W / 2)
    empty:SetText(TEXT_NONE)
end

function Page.Show()
    page:Show()
    list:SetWidth(scroll:GetWidth())
    if not active then
        active = true
        at = 1
        Runs.onChange = Page.Draw
    end
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    if not active then return end
    active = false
    Runs.onChange = nil
end
