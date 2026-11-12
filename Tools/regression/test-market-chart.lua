-- Run with Lua 5.1 from the repository root: The Market's price chart (View/Chart.lua) over its real price history.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local START = 20000 * DAY + 3600
local W, H = 280, 100

local function Stub()
    local o = { scripts = {}, shown = true, points = {} }
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:SetShown(on) self.shown = on end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetText(text) self.text = text end
    function o:SetTextColor(r, g, b) self.color = { r = r, g = g, b = b } end
    function o:ClearAllPoints() self.points = {} end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:SetStartPoint(_, _, x, y) self.from = { x, y } end
    function o:SetEndPoint(_, _, x, y) self.to = { x, y } end
    function o:GetWidth() return W end
    function o:GetHeight() return H end
    function o:GetLeft() return 0 end
    function o:GetEffectiveScale() return 1 end
    function o:CreateTexture() return Stub() end
    function o:CreateLine() return Stub() end
    return setmetatable(o, { __index = function() return function() end end })
end

local t = World.Setup()
local ns, env = t.ns, t.env
local green, red = { r = 0, g = 1, b = 0 }, { r = 1, g = 0, b = 0 }
ns.THEME = { fg = {}, muted = {}, line = {}, accentSoft = {} }
ns.Market.Style = { GOLD_RGB = {}, HAVE_RGB = green, RED_RGB = red, SMALL_SIZE = 11, TEXT_SIZE = 12 }
ns.Shared.Parts = { Coins = function(copper) return copper .. "c" end }
ns.Font = function() return Stub() end
ns.Solid = function() return Stub() end
ns.Border = function() end
local tip = { lines = {} }
function tip:SetOwner(owner) self.owner, self.lines, self.shown = owner, {}, false end
function tip:SetText(text) self.lines[1] = text end
function tip:AddLine(text) self.lines[#self.lines + 1] = text end
function tip:Show() self.shown = true end
function tip:Hide() self.shown = false end
function tip:IsOwned(owner) return self.owner == owner end
local cursorX, now = 0, START
env.GameTooltip = tip
env.CreateFrame = function() return Stub() end
env.GetCursorPosition = function() return cursorX, 0 end
env.GetServerTime = function() return now end
env.BreakUpLargeNumbers = function(n) return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end
Load({ "NaowhForever_Market/View/Chart.lua" }, env)

local History = ns.Market.History
local chart = ns.Market.Chart.New(Stub())
local plot = chart.plot

local function Scan(day, prices, listed)
    t.scan, t.listed, t.scanAt = prices, listed, START + day * DAY
    History.Record()
    now = t.scanAt
end

local function Shown(pool)
    local n = 0
    for _, widget in ipairs(pool) do
        if widget.shown then n = n + 1 end
    end
    return n
end

chart:Paint(2770)
Check("with no history the note shows instead of the plot", chart.note.shown and not plot.shown)

Scan(0, { [2770] = 100, [2589] = 20 })
chart:Paint(2770)
Check("one day is not a line yet", chart.note.shown and not plot.shown)

Scan(1, { [2770] = 200, [2589] = 20 })
Scan(3, { [2770] = 150, [2589] = 20 })
chart:Paint(2770)
Check("two days or more draw the plot", plot.shown and not chart.note.shown)
Check("a dot for each day with a price, joined across the day without one", Shown(chart.dots) == 3
    and Shown(chart.lines) == 2)
Check("the axis runs from the lowest price to the highest", chart.prices[0].text == "100c"
    and chart.prices[1].text == "150c" and chart.prices[2].text == "200c")
local step = W / 13
Check("the last day is at the right edge, at its price's height", chart.lines[2].to[1] == 13 * step
    and chart.lines[2].to[2] == H / 2 and chart.lines[2].from[1] == 11 * step and chart.lines[2].from[2] == H)
Check("the days are named from today back", chart.last.text == "Today" and chart.first.text == "13 days ago")
Check("the change is the tooltip's, a rise in green", chart.status.text == "Over 3 days  +50%"
    and chart.status.color.g == 1)

now = START + 5 * DAY
chart:Paint(2770)
Check("a last scan two days old is not called today", chart.last.text == "2 days ago")

plot.scripts.OnEnter(plot)
cursorX = 12.4 * step
plot.scripts.OnUpdate(plot)
Check("hovering a day without a price names the nearest one that has", tip.shown and tip.lines[1] == "2 days ago"
    and tip.lines[2] == "150c" and chart.cursor.shown)
cursorX = 11 * step
plot.scripts.OnUpdate(plot)
Check("and the day before it", tip.lines[1] == "4 days ago" and tip.lines[2] == "200c")
plot.scripts.OnLeave(plot)
Check("leaving hides the tooltip and the line, and stops the update", not tip.shown and not chart.cursor.shown
    and plot.scripts.OnUpdate == nil)

tip:SetOwner("a row")
tip:Show()
chart:Paint(1)
plot.scripts.OnHide(plot)
Check("the plot going away leaves another frame's tooltip up", tip.shown and not plot.shown)

chart:Paint(2589)
Check("a price that never moved is one line across the middle", plot.shown and chart.prices[1].shown
    and chart.prices[1].text == "20c" and not chart.prices[0].shown and not chart.prices[2].shown
    and chart.lines[1].from[2] == H / 2 and chart.status.text == "Over 3 days  +0%")

Scan(6, { [2770] = 75 })
chart:Paint(2770)
Check("a fall is red", chart.status.text == "Over 6 days  -25%" and chart.status.color.r == 1)

Scan(7, { [2770] = 80 }, { [2770] = 1234 })
chart:Paint(2770)
plot.scripts.OnEnter(plot)
cursorX = 13 * step
plot.scripts.OnUpdate(plot)
Check("hovering a day says how many were listed, under its price", tip.lines[1] == "Today" and tip.lines[2] == "80c"
    and tip.lines[3] == "1,234 listed")
cursorX = 12 * step
plot.scripts.OnUpdate(plot)
Check("and nothing more for a day whose count is not known", tip.lines[2] == "75c" and tip.lines[3] == nil)
plot.scripts.OnLeave(plot)

print(("test-market-chart: %d checks passed"):format(checks))
