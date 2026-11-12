-- Chart.lua: an item's lowest price each day over the past two weeks as a chart you can hover, for the Prices page (Market.Chart).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local C = Market.C
local Parts = ns.Shared.Parts
local History = Market.History

local HEAD_H, IN, GAP = 24, 10, 6
local PLOT_LEFT, PLOT_RIGHT, PLOT_BOTTOM = 76, 14, 20
local LINE_THICK, GRID_ALPHA, DOT = 2, 0.35, 5
local GRID_LINES = 2
local GOLD = 10000
local TEXT_TITLE = ns.L("Lowest price each day")
local TEXT_NONE = ns.L("Its prices show here after scans on two days.")
local TEXT_TODAY = ns.L("Today")
local TEXT_YESTERDAY = ns.L("Yesterday")
local TEXT_AGO = ns.L("%d days ago")
local TEXT_DAY = ns.L("Since yesterday")
local TEXT_DAYS = ns.L("Over %d days")
local TEXT_CHANGE = "%s  %+.0f%%"

local Chart = {}
Market.Chart = Chart

local function Axis(copper)
    if copper >= GOLD then copper = math.floor(copper / C.SILVER + 0.5) * C.SILVER end
    return Parts.Coins(copper)
end

local function DayText(chart, i)
    local ago = math.floor(GetServerTime() / C.SECONDS_PER_DAY) - (chart.today - C.HISTORY_DAYS + i)
    if ago <= 0 then return TEXT_TODAY end
    if ago == 1 then return TEXT_YESTERDAY end
    return TEXT_AGO:format(ago)
end

local function X(chart, i)
    return (i - 1) * chart.plot:GetWidth() / (C.HISTORY_DAYS - 1)
end

local function Y(chart, price)
    local height = chart.plot:GetHeight()
    if chart.hi == chart.lo then return height / 2 end
    return (price - chart.lo) / (chart.hi - chart.lo) * height
end

local function Segment(chart, n)
    local line = chart.lines[n]
    if not line then
        local gold = St.GOLD_RGB
        line = chart.plot:CreateLine(nil, "ARTWORK")
        line:SetThickness(LINE_THICK)
        line:SetColorTexture(gold.r, gold.g, gold.b, 1)
        chart.lines[n] = line
    end
    line:Show()
    return line
end

local function Dot(chart, n)
    local dot = chart.dots[n]
    if not dot then
        local gold = St.GOLD_RGB
        dot = chart.plot:CreateTexture(nil, "OVERLAY")
        dot:SetSize(DOT, DOT)
        dot:SetTexture(St.ROUND)
        dot:SetVertexColor(gold.r, gold.g, gold.b, 1)
        chart.dots[n] = dot
    end
    dot:Show()
    return dot
end

local function DrawGrid(chart)
    local plot, flat = chart.plot, chart.hi == chart.lo
    for i = 0, GRID_LINES do
        local line, label = chart.grid[i], chart.prices[i]
        local shown = not flat or i == GRID_LINES / 2
        line:SetShown(shown)
        label:SetShown(shown)
        if shown then
            local price = chart.lo + (chart.hi - chart.lo) * i / GRID_LINES
            local y = Y(chart, price)
            line:SetStartPoint("BOTTOMLEFT", plot, 0, y)
            line:SetEndPoint("BOTTOMRIGHT", plot, 0, y)
            label:ClearAllPoints()
            label:SetPoint("RIGHT", plot, "BOTTOMLEFT", -GAP, y)
            label:SetText(Axis(math.floor(price + 0.5)))
        end
    end
end

local function DrawLine(chart)
    local plot = chart.plot
    local n, prevX, prevY = 0, nil, nil
    for i, price in ipairs(chart.series) do
        if price then
            local x, y = X(chart, i), Y(chart, price)
            n = n + 1
            local dot = Dot(chart, n)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
            if prevX then
                local line = Segment(chart, n - 1)
                line:SetStartPoint("BOTTOMLEFT", plot, prevX, prevY)
                line:SetEndPoint("BOTTOMLEFT", plot, x, y)
            end
            prevX, prevY = x, y
        end
    end
    for i = n, #chart.lines do chart.lines[i]:Hide() end
    for i = n + 1, #chart.dots do chart.dots[i]:Hide() end
end

local function Paint(chart, itemID)
    chart.item = itemID
    local series, found, today = History.Series(itemID, chart.series)
    local drawn = found > 1
    chart.plot:SetShown(drawn)
    chart.note:SetShown(not drawn)
    chart.status:SetText("")
    if not drawn then return end
    chart.today, chart.at = today, nil
    local lo, hi
    for _, price in ipairs(series) do
        if price then lo, hi = math.min(lo or price, price), math.max(hi or price, price) end
    end
    chart.lo, chart.hi = lo, hi
    DrawGrid(chart)
    DrawLine(chart)
    chart.first:SetText(DayText(chart, 1))
    chart.last:SetText(DayText(chart, C.HISTORY_DAYS))
    local change, days = History.Change(itemID, C.CHANGE_DAYS)
    if not change then return end
    local tint = change >= 0 and St.HAVE_RGB or St.RED_RGB
    chart.status:SetTextColor(tint.r, tint.g, tint.b)
    chart.status:SetText(TEXT_CHANGE:format(days == 1 and TEXT_DAY or TEXT_DAYS:format(days), change))
end

local function Nearest(chart, x)
    local want = x / chart.plot:GetWidth() * (C.HISTORY_DAYS - 1) + 1
    local pick, gap
    for i, price in ipairs(chart.series) do
        local off = math.abs(i - want)
        if price and (not gap or off < gap) then pick, gap = i, off end
    end
    return pick
end

local function PlotUpdate(plot)
    local chart = plot.chart
    local i = Nearest(chart, GetCursorPosition() / plot:GetEffectiveScale() - plot:GetLeft())
    if i == chart.at then return end
    chart.at = i
    chart.cursor:ClearAllPoints()
    chart.cursor:SetPoint("TOP", plot, "TOPLEFT", X(chart, i), 0)
    chart.cursor:SetPoint("BOTTOM", plot, "BOTTOMLEFT", X(chart, i), 0)
    chart.cursor:Show()
    GameTooltip:SetOwner(plot, "ANCHOR_CURSOR")
    GameTooltip:SetText(DayText(chart, i), 1, 1, 1)
    GameTooltip:AddLine(Parts.Coins(chart.series[i]), 1, 1, 1)
    GameTooltip:Show()
end

local function PlotEnter(plot)
    plot:SetScript("OnUpdate", PlotUpdate)
end

local function PlotLeave(plot)
    plot:SetScript("OnUpdate", nil)
    plot.chart.at = nil
    plot.chart.cursor:Hide()
    if GameTooltip:IsOwned(plot) then GameTooltip:Hide() end
end

function Chart.New(parent)
    local chart = CreateFrame("Frame", nil, parent)
    ns.Solid(chart, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(chart, St.BORDER_RGB)
    local head = ns.Font(chart, St.SMALL_SIZE, nil, T.muted)
    head:SetPoint("TOPLEFT", IN, -(HEAD_H - St.SMALL_SIZE) / 2)
    head:SetText(TEXT_TITLE)
    chart.status = ns.Font(chart, St.SMALL_SIZE, nil, T.muted)
    chart.status:SetPoint("TOPRIGHT", -IN, -(HEAD_H - St.SMALL_SIZE) / 2)
    chart.note = ns.Font(chart, St.TEXT_SIZE, nil, T.muted)
    chart.note:SetPoint("LEFT", IN, -HEAD_H / 2)
    chart.note:SetPoint("RIGHT", -IN, -HEAD_H / 2)
    chart.note:SetText(TEXT_NONE)
    local plot = CreateFrame("Frame", nil, chart)
    plot:SetPoint("TOPLEFT", PLOT_LEFT, -HEAD_H)
    plot:SetPoint("BOTTOMRIGHT", -PLOT_RIGHT, PLOT_BOTTOM)
    plot.chart, chart.plot = chart, plot
    chart.lines, chart.dots, chart.series, chart.grid, chart.prices = {}, {}, {}, {}, {}
    for i = 0, GRID_LINES do
        local line = plot:CreateLine(nil, "BACKGROUND")
        line:SetThickness(1)
        line:SetColorTexture(T.line.r, T.line.g, T.line.b, GRID_ALPHA)
        chart.grid[i] = line
        chart.prices[i] = ns.Font(plot, St.SMALL_SIZE, nil, T.muted)
    end
    chart.first = ns.Font(plot, St.SMALL_SIZE, nil, T.muted)
    chart.first:SetPoint("TOPLEFT", plot, "BOTTOMLEFT", 0, -GAP)
    chart.last = ns.Font(plot, St.SMALL_SIZE, nil, T.muted)
    chart.last:SetPoint("TOPRIGHT", plot, "BOTTOMRIGHT", 0, -GAP)
    chart.cursor = ns.Solid(plot, "ARTWORK", T.accentSoft, GRID_ALPHA)
    chart.cursor:SetWidth(1)
    chart.cursor:Hide()
    plot:EnableMouse(true)
    plot:SetScript("OnEnter", PlotEnter)
    plot:SetScript("OnLeave", PlotLeave)
    plot:SetScript("OnHide", PlotLeave)
    plot:SetScript("OnSizeChanged", function() if chart.item then Paint(chart, chart.item) end end)
    chart.Paint = Paint
    return chart
end
