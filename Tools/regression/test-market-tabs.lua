-- Run with Lua 5.1 from the repository root: The Market's tab bar: Buy, Sell and My Auctions dim away from an
-- auctioneer, and Sell and My Auctions show their counts.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Button(key)
    local b = { key = key }
    b.count = { SetTextColor = function(_, ...) b.color = { ... } end, SetPoint = function() end,
        SetText = function(_, t) b.counted = t end }
    function b:SetAlpha(a) self.alpha = a end
    return b
end

local pages = {
    { key = "buy", auction = true }, { key = "sell", auction = true }, { key = "mine", auction = true },
    { key = "farm" }, { key = "reagents" },
}
local left, undercut = 3, 0
local painted
local WARN = { r = 1, g = 0.5, b = 0 }
local ns = {
    THEME = { muted = { r = 1, g = 1, b = 1 } },
    Font = function() return nil end,
    Shared = { Parts = {
        Tabs = function(_, _, items)
            local bar = { buttons = {} }
            for i, item in ipairs(items) do bar.buttons[i] = Button(item.key) end
            return bar
        end,
        PaintTabs = function(_, key) painted = key end,
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

local bar = ns.Market.Tabs.Build({}, pages, function() end)
local by = {}
for _, b in ipairs(bar.buttons) do by[b.key] = b end
check("one button per page", #bar.buttons == 5)
check("each page keeps its auction flag", by.buy.auction and by.sell.auction and by.mine.auction
    and not by.farm.auction and not by.reagents.auction)

ns.Market.Tabs.Paint("buy", false)
check("the picked page is painted", painted == "buy")
check("auction tabs dim away from an auctioneer", by.buy.alpha < 1 and by.sell.alpha < 1 and by.mine.alpha < 1)
check("Farm and Reagents stay lit", by.farm.alpha == 1 and by.reagents.alpha == 1)
check("a dimmed tab shows no count", by.sell.counted == "" and by.mine.counted == "")

ns.Market.Tabs.Paint("sell", true)
check("auction tabs light at an auctioneer", by.buy.alpha == 1 and by.sell.alpha == 1)
check("Sell shows what is left to post", by.sell.counted == 3)
check("My Auctions shows its total", by.mine.counted == 5)
check("Buy and Farm show no count", by.buy.counted == "" and by.farm.counted == "")

left, undercut = 0, 2
ns.Market.Tabs.Paint("mine", true)
check("Sell shows nothing once posted", by.sell.counted == "")
check("an undercut count shows in the warning colour", by.mine.counted == 2 and by.mine.color[1] == WARN.r)

print(("test-market-tabs: %d checks passed"):format(checks))
