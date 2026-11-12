-- Run with Lua 5.1 from the repository root: The Market's tab bars: one per window, each painting its picked page,
-- with Buy's, Sell's and My Auctions' counts after their labels, measured with them so a label is never covered.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local left, undercut, under = 3, 0, 0
local painted, fitted = {}, {}
local WARN = { r = 1, g = 0.5, b = 0 }
local HAVE = { r = 0, g = 1, b = 0 }
local ns = {
    THEME = { muted = { r = 1, g = 1, b = 1 } },
    Shared = { Parts = {
        Tabs = function(_, width, items)
            local bar = { buttons = {}, width = width }
            for i, item in ipairs(items) do bar.buttons[i] = { key = item.key } end
            return bar
        end,
        SetTabs = function(bar, items)
            fitted[bar] = items
            painted[bar] = bar.shown
            for i, item in ipairs(items) do bar.buttons[i].counted = item.note end
        end,
    } },
    Color = function(color, text) return "<" .. color.r .. ">" .. text end,
}
ns.Market = {
    Style = { WARN_RGB = WARN, HAVE_RGB = HAVE },
    Watch = { UnderCount = function() return under end },
    Sell = { Left = function() return left end },
    Auctions = { Counts = function() return undercut end, list = { 1, 2, 3, 4, 5 } },
}

local fn = assert(loadfile("NaowhForever_Market/UI/Tabs.lua"))
setfenv(fn, setmetatable({ _G = { NaowhForever = ns } }, { __index = _G }))
fn()

local Tabs = ns.Market.Tabs
local dock = Tabs.Build({}, 360, { { key = "buy" }, { key = "sell" }, { key = "mine" } }, function() end)
local window = Tabs.Build({}, 450, { { key = "farm" }, { key = "reagents" }, { key = "prices" } }, function() end)
local by = {}
for _, bar in ipairs({ dock, window }) do
    for _, b in ipairs(bar.buttons) do by[b.key] = b end
end
check("each bar has a button per page, at its own width", #dock.buttons == 3 and #window.buttons == 3
    and dock.width == 360 and window.width == 450)

Tabs.Paint(dock, "sell")
check("the picked page is painted on its own bar", painted[dock] == "sell" and painted[window] == nil)
check("the bar is fitted again with the counts, so they are measured with the labels", fitted[dock] ~= nil)
check("Sell shows what is left to post, after its label", by.sell.counted == " <1>3")
check("My Auctions shows its total", by.mine.counted == " <1>5")
check("Buy shows nothing while no watched item is at or under your price", by.buy.counted == nil)
under = 2
Tabs.Paint(dock, "sell")
check("Buy counts the watched items at or under your price, in green", by.buy.counted == " <" .. HAVE.r .. ">2")
under = 0

Tabs.Paint(window, "prices")
check("Farm, Reagents and Price Graph show no count", by.farm.counted == nil and by.reagents.counted == nil
    and by.prices.counted == nil)

left, undercut = 0, 2
Tabs.Paint(dock, "mine")
check("Sell shows nothing once posted", by.sell.counted == nil)
check("an undercut count shows in the warning colour", by.mine.counted == " <" .. WARN.r .. ">2")

print(("test-market-tabs: %d checks passed"):format(checks))
