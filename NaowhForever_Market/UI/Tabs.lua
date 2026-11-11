-- Tabs.lua: The Market window's tab bar along the bottom: a tab per page, with its count (Market.Tabs).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts

local TAB_W, COUNT_SIZE, COUNT_IN = 150, 12, 8
local OFF_ALPHA = 0.55

local Tabs = {}
Market.Tabs = Tabs

local bar

local function Count(key)
    if key == "sell" then
        local left = Market.Sell.Left()
        return left > 0 and left or nil
    end
    if key == "mine" then
        local undercut = Market.Auctions.Counts()
        if undercut > 0 then return undercut, St.WARN_RGB end
        local total = #Market.Auctions.list
        return total > 0 and total or nil
    end
end

function Tabs.Build(parent, pages, onPick)
    bar = Parts.Tabs(parent, TAB_W * #pages, pages, onPick, true)
    for i, button in ipairs(bar.buttons) do
        button.auction = pages[i].auction
        button.count = ns.Font(button, COUNT_SIZE, nil, T.muted)
        button.count:SetPoint("RIGHT", -COUNT_IN, 0)
    end
    return bar
end

function Tabs.Paint(key, atAuction)
    Parts.PaintTabs(bar, key)
    for _, button in ipairs(bar.buttons) do
        local off = button.auction and not atAuction
        local count, color = nil, nil
        if not off then count, color = Count(button.key) end
        local c = color or T.muted
        button:SetAlpha(off and OFF_ALPHA or 1)
        button.count:SetTextColor(c.r, c.g, c.b)
        button.count:SetText(count or "")
    end
end
