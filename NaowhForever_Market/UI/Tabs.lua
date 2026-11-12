-- Tabs.lua: a tab bar for The Market's window and the panel beside the auction house, with Buy's, Sell's and My Auctions' counts (Market.Tabs).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts

local COUNT_GAP = " "

local Tabs = {}
Market.Tabs = Tabs

local function Count(key)
    if key == "buy" then
        local under = Market.Watch.UnderCount()
        if under > 0 then return under, St.HAVE_RGB end
        return nil
    end
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

function Tabs.Build(parent, width, pages, onPick)
    local bar = Parts.Tabs(parent, width, pages, onPick, true)
    bar.pages = pages
    return bar
end

function Tabs.Paint(bar, key)
    for _, page in ipairs(bar.pages) do
        local count, color = Count(page.key)
        page.note = count and COUNT_GAP .. ns.Color(color or T.muted, count) or nil
    end
    bar.shown = key
    Parts.SetTabs(bar, bar.pages)
end
