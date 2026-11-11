-- Run with Lua 5.1 from the repository root: The Market's tab bars: one per window, each painting its picked page,
-- with Sell's and My Auctions' counts.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Button(key)
    local b = { key = key }
    b.count = { SetTextColor = function(_, ...) b.color = { ... } end, SetPoint = function() end,
        SetText = function(_, t) b.counted = t end }
    return b
end

local left, undercut = 3, 0
local painted = {}
local WARN = { r = 1, g = 0.5, b = 0 }
local ns = {
    THEME = { muted = { r = 1, g = 1, b = 1 } },
    Shared = { Parts = {
        Tabs = function(_, width, items)
            local bar = { buttons = {}, width = width }
            for i, item in ipairs(items) do bar.buttons[i] = Button(item.key) end
            return bar
        end,
        PaintTabs = function(bar, key) painted[bar] = key end,
    } },
}
ns.Market = {
    Style = { WARN_RGB = WARN },
    Sell = { Left = function() return left end },
    Auctions = { Counts = function() return undercut end, list = { 1, 2, 3, 4, 5 } },
}

local fn = assert(loadfile("NaowhForever_Market/UI/Tabs.lua"))
setfenv(fn, setmetatable({ _G = { NaowhForever = ns } }, { __index = _G }))
ns.Font = function(button) return button.count end
fn()

local Tabs = ns.Market.Tabs
local dock = Tabs.Build({}, 360, { { key = "sell" }, { key = "mine" } }, function() end)
local window = Tabs.Build({}, 450, { { key = "farm" }, { key = "reagents" }, { key = "prices" } }, function() end)
local by = {}
for _, bar in ipairs({ dock, window }) do
    for _, b in ipairs(bar.buttons) do by[b.key] = b end
end
check("each bar has a button per page, at its own width", #dock.buttons == 2 and #window.buttons == 3
    and dock.width == 360 and window.width == 450)

Tabs.Paint(dock, "sell")
check("the picked page is painted on its own bar", painted[dock] == "sell" and painted[window] == nil)
check("Sell shows what is left to post", by.sell.counted == 3)
check("My Auctions shows its total", by.mine.counted == 5)

Tabs.Paint(window, "prices")
check("Farm, Reagents and Prices show no count", by.farm.counted == "" and by.reagents.counted == ""
    and by.prices.counted == "")

left, undercut = 0, 2
Tabs.Paint(dock, "mine")
check("Sell shows nothing once posted", by.sell.counted == "")
check("an undercut count shows in the warning colour", by.mine.counted == 2 and by.mine.color[1] == WARN.r)

print(("test-market-tabs: %d checks passed"):format(checks))
