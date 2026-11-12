-- Run with Lua 5.1 from the repository root: shared replication results, the page by page scan, settings lifecycle,
-- crate prices and the release's prices.
local Load = dofile("Tools/regression/load_files.lua")
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local function Setup(buttonOn, captureOn, withFrame, cratesOn, tooltipOn, feed, region)
    local values = { ahPrices = buttonOn, ahCapture = captureOn, ahCrates = cratesOn, ahTooltip = tooltipOn,
        ahAutoScanMinutes = 15 }
    local account, registered, timers, messages, posts = {}, {}, {}, {}, {}
    local now, requests, refreshes, total = 10000, 0, 0, 1001
    local allInfo = true
    local replicateHooks, reloads = 0, 0
    local browses, mores, ready, full, rows, query = 0, 0, true, false, {}, nil
    local loads, skew, faction = 0, 0, "Alliance"
    local npc, decodes, territory = nil, 0, "contested"
    local card, button
    local frame = {}
    function frame:RegisterEvent(event) registered[event] = true end
    function frame:UnregisterEvent(event) registered[event] = nil end
    function frame:SetScript(_, fn) self.handler = fn end
    local S = { Get = function(key) return values[key] end,
        Set = function(key, value) values[key] = value end }
    local ns = {
        QoLSettings = S,
        QoLConstants = { SECONDS_PER_MINUTE = 60, SECONDS_PER_HOUR = 3600,
            SECONDS_PER_DAY = 86400, PERCENT = 100, WHITE_RGB = { r = 1, g = 1, b = 1 } },
        L = function(text) return text end,
        Color = function(_, text) return text end,
        AccountSettings = function() return account end,
        ConfirmReload = function() reloads = reloads + 1 end,
        GamepadStandDown = function() return false end,
        Print = function(text) messages[#messages + 1] = text end,
        ProfWindowRefresh = function() refreshes = refreshes + 1 end,
        Apply = Noop,
        THEME = { accent = { r = 0, g = 0.57, b = 0.93 } },
        Tooltip = Noop,
        Font = function() return { SetPoint = Noop, SetText = Noop } end,
        Button = function(_, _, _, _, click)
            button = { click = click, label = { SetText = Noop },
                ClearAllPoints = Noop, SetPoint = function(self, ...) self.at = { ... } end,
                SetShown = function(self, on) self.shown = on end }
            return button
        end,
        Shared = { Settings = { Page = function()
            return { Card = function(_, spec) card = spec end }
        end }, Items = { Name = function(id) return "item" .. id end } },
    }
    local env = setmetatable({
        NaowhForever = ns,
        AuctionHouseFrame = withFrame and { AuctionsTab = {} } or nil,
        CreateFrame = function() return frame end,
        GetRealmName = function() return "Realm" end,
        GetCurrentRegion = function() return region or 1 end,
        C_AddOns = { LoadAddOn = function(name)
            if name == "NaowhForever_AuctionData" then
                loads = loads + 1
                ns.AuctionFeed = feed
            end
        end },
        UnitFactionGroup = function(unit)
            if unit == "npc" then return npc or nil end
            return faction
        end,
        UnitExists = function() return npc ~= nil end,
        C_PvP = { GetZonePVPInfo = function() return territory end },
        time = function() return now + skew end,
        GetServerTime = function() return now end,
        -- Lua 5.1's tonumber with a base stops at 2^32 - 1 on Windows, as strtoul does there.
        tonumber = function(text, base)
            if base then decodes = decodes + 1 end
            local n = tonumber(text, base)
            if base and n and n > 4294967295 then return 4294967295 end
            return n
        end,
        BreakUpLargeNumbers = tostring,
        C_CurrencyInfo = { GetCoinTextureString = function(amount) return amount .. "c" end },
        C_Timer = {
            After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end,
            NewTicker = function() return { Cancel = Noop } end,
        },
        C_AuctionHouse = {
            ReplicateItems = function() requests = requests + 1 end,
            IsThrottledMessageSystemReady = function() return ready end,
            SendBrowseQuery = function(sent)
                browses = browses + 1
                query = sent
            end,
            SearchForFavorites = Noop,
            RequestMoreBrowseResults = function() mores = mores + 1 end,
            HasFullBrowseResults = function() return full end,
            GetBrowseResults = function() return rows end,
            GetNumReplicateItems = function() return total end,
            GetReplicateItemInfo = function(i)
                local count, buyout, id = 2, 101, 10
                if i == 1 then buyout = 99 end
                if i == 2 then count = 0 end
                if i == 3 then buyout = 0 end
                if i == 1000 then id, buyout = 20, 200 end
                return nil, nil, count, nil, nil, nil, nil, nil, nil, buyout,
                    nil, nil, nil, nil, nil, nil, id, allInfo
            end,
        },
        hooksecurefunc = function(target, key, hook)
            if key == "ReplicateItems" then replicateHooks = replicateHooks + 1 end
            local original = target[key]
            target[key] = function(...)
                original(...)
                hook(...)
            end
        end,
        TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) posts[#posts + 1] = fn end },
        Enum = { TooltipDataType = { Item = 0 }, AuctionHouseSortOrder = { Price = 0, Name = 1 },
            AuctionHouseFilter = { PoorQuality = 2, CommonQuality = 3, UncommonQuality = 4, RareQuality = 5,
                EpicQuality = 6, LegendaryQuality = 7 } },
    }, { __index = _G })
    env._G = env
    Load({ "NaowhForever_QoL/Loot/WaylaidCratesData.lua", "NaowhForever_QoL/Loot/WritRequestsData.lua",
        "NaowhForever_QoL/Loot/AuctionPrices.lua" }, env)
    local t = { ns = ns, settings = S, messages = messages, card = card, frame = env.AuctionHouseFrame, env = env }
    function t.Fire(event, ...)
        if registered[event] then frame.handler(frame, event, ...) end
    end
    function t.Browses() return browses end
    function t.Mores() return mores end
    function t.Query() return query end
    function t.Ready(value) ready = value end
    function t.Paging() return registered.AUCTION_HOUSE_BROWSE_RESULTS_UPDATED end
    function t.Page(page, whole, added)
        full = whole
        if not added then
            rows = page
            return t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        end
        for _, row in ipairs(page) do rows[#rows + 1] = row end
        t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", page)
    end
    function t.ExternalScan() env.C_AuctionHouse.ReplicateItems() end
    function t.Listening() return registered.REPLICATE_ITEM_LIST_UPDATE end
    function t.Requests() return requests end
    function t.Refreshes() return refreshes end
    function t.Button() return button end
    function t.Reloads() return reloads end
    function t.ReplicateHooks() return replicateHooks end
    function t.Flush() for _ = 1, 20 do t.Run(0) end end
    function t.AllInfo(value) allInfo = value end
    function t.Total(value) total = value end
    function t.Advance(seconds) now = now + seconds end
    function t.PostCalls() return #posts end
    function t.Loads() return loads end
    function t.Now() return now end
    function t.Clock(seconds) skew = seconds end
    function t.Faction(value) faction = value end
    function t.Npc(value) npc = value end
    function t.Territory(value) territory = value end
    function t.Decodes() return decodes end
    function t.House(key) return account.ahPrices and account.ahPrices[key] end
    function t.PricedAt(key, prices, ago)
        account.ahPrices = account.ahPrices or {}
        account.ahPrices[key] = { prices = prices, time = now - ago }
    end
    function t.Profile(key, value) values[key] = value end
    function t.Priced(prices, ago, listed)
        account.ahPrices = { ["Realm-Alliance"] = { prices = prices, listed = listed, time = now - ago } }
    end
    function t.Tooltip(id)
        local tooltip = { lines = {} }
        function tooltip:AddDoubleLine(left, right, r, g, b)
            self.lines[#self.lines + 1] = { left = left, right = right, r = r, g = g, b = b }
        end
        for _, post in ipairs(posts) do post(tooltip, { id = id }) end
        return tooltip.lines
    end
    function t.Run(delay)
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if timer.delay == delay then timer.fn() else timers[#timers + 1] = timer end
        end
    end
    return t
end

local t = Setup(true, true, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("enabled capture hooks once but opening does not listen or request", not t.Listening()
    and t.Requests() == 0 and t.ReplicateHooks() == 1)
t.AllInfo(false)
t.ExternalScan()
Check("external request arms results", t.Listening())
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
Check("reading unsubscribes immediately", not t.Listening())
t.Button().click()
Check("click during read does not request", t.Requests() == 1)
t.Flush()
Check("capture finishes without waiting on unused item data", t.Refreshes() == 1 and #t.messages == 1 and not t.Listening())
local prices, when = t.ns.AuctionPriceList()
Check("minimum unit prices preserved", prices[10] == 49 and prices[20] == 100 and when == 10000)
Check("and how many auctions listed each at a price, a stack counting once",
    t.ns.AuctionListed(10) == 998 and t.ns.AuctionListed(20) == 1)
for _ = 1, 100 do t.Fire("REPLICATE_ITEM_LIST_UPDATE"); t.Flush() end
Check("late Auctionator cache events do not repeat completion", t.Refreshes() == 1 and #t.messages == 1 and t.ns.AuctionScanTime() == when)
t.Button().click()
Check("capture retains cooldown", t.Requests() == 1 and #t.messages == 2)
Check("so the click reads page by page instead", t.Browses() == 1 and t.Paging()
    and t.messages[2]:find("page by page", 1, true))
t.Advance(901)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("next external request captures in same visit", t.Refreshes() == 2 and not t.Listening())
Check("and takes over from the page by page scan", not t.Paging())
t.Advance(901)
t.Button().click()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
t.Run(60)
Check("manual request completes once and stale timeout is ignored", t.Refreshes() == 3 and not t.Listening())
t.Advance(901)
local printed = #t.messages
t.ExternalScan()
t.Run(60)
Check("external unanswered request times out silently and keeps listening", #t.messages == printed and t.Listening())
t.Total(0)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
Check("empty capture preserves prices silently", t.ns.AuctionPrice(10) == 49 and #t.messages == printed and not t.Listening())
t.Total(1001)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Fire("AUCTION_HOUSE_CLOSED")
t.Flush()
Check("closing cancels unfinished batches silently", t.Refreshes() == 3 and #t.messages == printed and not t.Listening())
t.ExternalScan()
Check("closed house does not arm capture", not t.Listening())

t = Setup(true, false, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("capture defaults install no hook", t.ReplicateHooks() == 0)
t.ExternalScan()
Check("button alone ignores external scans", not t.Listening())
t.Button().click()
Check("manual scan requests and listens", t.Requests() == 2 and t.Listening())
Check("and asks you to wait in chat", t.messages[#t.messages] == "Naowh AH: please wait while the auction house scan completes.")
t.Run(60)
Check("manual unanswered request reports timeout and keeps listening", t.messages[#t.messages]:find("no answer", 1, true) and t.Listening())
Check("and reads page by page instead of giving up", t.Browses() == 1 and t.Paging()
    and t.messages[#t.messages]:find("page by page", 1, true))
printed = #t.messages
t.Button().click()
Check("a click while it pages asks for nothing more", t.Requests() == 2 and t.Browses() == 1 and #t.messages == printed)
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("answer after the timeout is still read", t.Refreshes() == 1 and t.ns.AuctionScanTime() and not t.Listening())
Check("in place of the pages", not t.Paging())
t.Advance(901)
t.Button().click()
t.Run(60)
printed = #t.messages
t.Fire("AUCTION_HOUSE_CLOSED")
Check("closing after a timeout stops listening, and says the page by page scan stopped", #t.messages == printed + 1
    and t.messages[#t.messages] == "Naowh AH: scan stopped: the auction house closed."
    and not t.Listening() and not t.Paging())
t.Fire("AUCTION_HOUSE_SHOW")
t.Advance(901)
printed = #t.messages
t.Button().click()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Run(60)
t.Flush()
Check("timeout during a read neither stops it nor reports no answer", t.Refreshes() == 2
    and #t.messages == printed + 2 and not t.messages[#t.messages]:find("no answer", 1, true))

t = Setup(false, false, true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("disabled defaults install no hook", t.ReplicateHooks() == 0 and not t.Listening())
Check("Auction Prices is a card of its own, placed on Auction House", t.card.id == "auctionPrices" and t.card.into == nil)
Check("crate prices sit under the item price", t.card.rows[2].key == "ahTooltip" and t.card.rows[3].key == "ahCrates")
Check("and writ prices under them", t.card.rows[4].key == "ahWrits")
local capture = t.card.rows[5]
Check("capture row always shown", capture.key == "ahCapture" and capture.label == "Capture Other Addons' Scans" and capture.hidden == nil)
t.settings.Set("ahCapture", true)
Check("first enable installs hook without arming results", t.ReplicateHooks() == 1 and not t.Listening() and not t.Button().shown)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.settings.Set("ahCapture", false)
t.Flush()
Check("disable during read lets it finish", t.Refreshes() == 1 and not t.Listening())
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("installed hook ignores requests after disabling", t.Refreshes() == 1 and not t.Listening())
t.settings.Set("ahCapture", true)
Check("reenabling does not install duplicate hooks", t.ReplicateHooks() == 1)
t.Advance(901)
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("capture works with the button hidden", t.Refreshes() == 2 and not t.Button().shown)
t.settings.Set("ahPrices", true)
t.settings.Set("ahPrices", false)
t.settings.Set("ahCapture", false)
Check("toggling never asks for a reload", t.Reloads() == 0)

t = Setup(true, true, false)
t.Fire("AUCTION_HOUSE_SHOW")
t.ExternalScan()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("capture works without visual AH frame", t.Refreshes() == 1)

local HERBS, PEACEBLOOM, SILVERLEAF, EARTHROOT = 248682, 2447, 765, 2449
local function Headers(lines)
    local n = 0
    for _, line in ipairs(lines) do
        if line.left == "Market Price" then n = n + 1 end
    end
    return n
end

t = Setup(true, false, true)
Check("both tooltip options off install no tooltip hook", t.PostCalls() == 0)
t.Priced({ [HERBS] = 50, [PEACEBLOOM] = 10, [SILVERLEAF] = 8, [EARTHROOT] = 20 }, 300)
t.settings.Set("ahCrates", true)
t.settings.Set("ahCrates", false)
t.settings.Set("ahCrates", true)
t.settings.Set("ahTooltip", true)
t.ns.Apply()
Check("either option hooks the one item tooltip post-call, once", t.PostCalls() == 1)
local lines = t.Tooltip(HERBS)
Check("with both on, a priced crate has one header: its own price", #lines == 4 and Headers(lines) == 1
    and lines[1].right == "50c |cff808080each, 5m ago|r")
Check("and its priced bundles under it", lines[2].left == "20 item2447" and lines[2].right == "200c"
    and lines[4].left == "10 item2449")
Check("the cheapest bundle is marked in the accent and in words", lines[3].left == "20 item765"
    and lines[3].right == "160c cheapest" and lines[3].b == 0.93 and lines[2].b == 1 and lines[4].b == 1)
t.settings.Set("ahTooltip", false)
lines = t.Tooltip(HERBS)
Check("crate prices alone head the bundles with the scan's age", #lines == 4 and Headers(lines) == 1
    and lines[1].right == "Last scan 5m ago" and lines[3].right == "160c cheapest")
Check("an item that is no crate gets nothing from crate prices alone", #t.Tooltip(PEACEBLOOM) == 0)
t.settings.Set("ahTooltip", true)
t.settings.Set("ahCrates", false)
lines = t.Tooltip(HERBS)
Check("the item price alone leaves the bundles off", #lines == 1 and lines[1].right == "50c |cff808080each, 5m ago|r")
lines = t.Tooltip(PEACEBLOOM)
Check("the item price alone still prices any item", #lines == 1 and lines[1].right == "10c |cff808080each, 5m ago|r")
t.settings.Set("ahTooltip", false)
Check("the hook stays inert once both are off", t.PostCalls() == 1 and #t.Tooltip(HERBS) == 0)
t.settings.Set("ahCrates", true)
t.Priced({ [HERBS] = 50 }, 300)
Check("a crate none of whose bundles is priced gets nothing from crate prices alone", #t.Tooltip(HERBS) == 0)

t = Setup(true, false, true, true)
Check("crate prices on at load hook the tooltip", t.PostCalls() == 1 and #t.Tooltip(HERBS) == 0)
t = Setup(true, false, true, nil, true)
Check("the item price on at load hooks the tooltip", t.PostCalls() == 1)
t = Setup(true, false, true)
t.Profile("ahTooltip", true)
t.ns.Apply()
Check("a profile with the item price on hooks it on apply", t.PostCalls() == 1)

t = Setup(true, false, true, true, true)
t.Priced({ [HERBS] = 50, [PEACEBLOOM] = 10, [SILVERLEAF] = 8, [EARTHROOT] = 20 }, 300)
local asked
t.ns.Market = { ShowsPrice = function(_, id) asked = id; return true end }
Check("the item price is left to The Market while its lines show it", #t.Tooltip(PEACEBLOOM) == 0
    and asked == PEACEBLOOM)
lines = t.Tooltip(HERBS)
Check("a crate's bundles stay, headed by the prices' age", #lines == 4 and lines[1].right == "Last scan 5m ago")
t.ns.Market.ShowsPrice = function() return false end
lines = t.Tooltip(PEACEBLOOM)
Check("otherwise the item price shows as before", #lines == 1 and lines[1].right == "10c |cff808080each, 5m ago|r")

local WRIT, FIREWATER = 264124, 246948
t = Setup(true, false, true)
t.Priced({ [WRIT] = 30, [FIREWATER] = 250 }, 300)
t.settings.Set("ahWrits", true)
Check("writ prices alone hook the item tooltip", t.PostCalls() == 1)
lines = t.Tooltip(WRIT)
Check("a writ shows the item it asks for and what one costs, headed by the prices' age", #lines == 2
    and Headers(lines) == 1 and lines[1].right == "Last scan 5m ago"
    and lines[2].left == "Requested: item246948" and lines[2].right == "250c")
t.settings.Set("ahTooltip", true)
lines = t.Tooltip(WRIT)
Check("with the item price on, the writ's own price heads it", #lines == 2
    and lines[1].right == "30c |cff808080each, 5m ago|r" and lines[2].right == "250c")
Check("an item that is no writ gets no requested line", #t.Tooltip(FIREWATER) == 1)
t.settings.Set("ahTooltip", false)
t.settings.Set("ahWrits", false)
Check("writ prices off leave the writ alone", #t.Tooltip(WRIT) == 0)
t.settings.Set("ahWrits", true)
t.Priced({ [WRIT] = 30 }, 300)
Check("a writ whose item has no price gets nothing from writ prices alone", #t.Tooltip(WRIT) == 0)
t = Setup(true, false, true)
t.Profile("ahWrits", true)
t.ns.Apply()
Check("a profile with writ prices on hooks it on apply", t.PostCalls() == 1)

local function Base36(n)
    local digits, text = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    repeat
        local d = n % 36
        text = digits:sub(d + 1, d + 1) .. text
        n = (n - d) / 36
    until n == 0
    return text
end

local function Encode(each, listed)
    local ids, parts, last = {}, {}, 0
    for id in pairs(each) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local part = Base36(id - last) .. ":" .. Base36(each[id])
        if listed and listed[id] then part = part .. ":" .. Base36(listed[id]) end
        parts[#parts + 1] = part
        last = id
    end
    return table.concat(parts, ",")
end

local FEED_TIME = 10000 - 3600
local function Feed(houses)
    local region = {}
    for id, house in pairs(houses) do region[id] = { faction = house[1], prices = Encode(house[2], house[3]) } end
    return { time = FEED_TIME, regions = { [1] = region } }
end

local WAILING = {}
for i = 1, 25 do WAILING[1000 + i] = 100 + i end
local OTHER = {}
for i = 1, 25 do OTHER[1000 + i] = 500 + i end
local houses = {
    [110] = { "Alliance", { [10] = 40, [11] = 7, [1001] = 101 } },
    [111] = { "Alliance", WAILING },
    [113] = { "Horde", { [10] = 1, [11] = 1 } },
    [119] = { "Alliance", { [10] = 60, [11] = 9 } },
    [112] = { "Alliance", {} },
}
houses[111][2][10] = 50
houses[111][2][11] = 8

t = Setup(true, false, true, nil, nil, Feed(houses))
Check("nothing loads the release's prices until a price is asked for", t.Loads() == 0)
local price, at = t.ns.AuctionPrice(10)
Check("with no scan of your own, an item's price is the middle of your faction's houses", t.Loads() == 1
    and price == 50 and at == FEED_TIME)
Check("the other faction's house and an empty house never count", t.ns.AuctionPrice(11) == 8)
Check("the release's prices load once", t.Loads() == 1)
Check("and are let go once read", t.ns.AuctionFeed == nil)
Check("their time stands for the scan time, and the summary names them", t.ns.AuctionScanTime() == FEED_TIME
    and t.ns.AuctionScanSummary() == "Prices from 1h ago: 27 items priced.")
local list, listAt = t.ns.AuctionPriceList()
Check("and the price list is theirs", list[10] == 50 and listAt == FEED_TIME)

t = Setup(true, false, true, nil, nil, Feed(houses))
t.Priced({ [10] = 999, [12] = 30 }, 7200)
Check("a scan of your own that matches no house beats their middle, however old", t.ns.AuctionPrice(10) == 999
    and t.ns.AuctionScanTime() == t.Now() - 7200 and t.ns.AuctionScanSummary() == "Last scan 2h ago: 2 items priced.")
Check("which still prices what the scan does not list", t.ns.AuctionPrice(11) == 8)
list, listAt = t.ns.AuctionPriceList()
Check("and the price list holds both the same way", list[10] == 999 and list[11] == 8 and list[12] == 30
    and listAt == FEED_TIME)
Check("the same list comes back until a price changes", t.ns.AuctionPriceList() == list)
t.Priced({ [10] = 999 }, 60)
Check("a newer scan of your own wins", t.ns.AuctionPrice(10) == 999 and t.ns.AuctionScanTime() == t.Now() - 60)
Check("and makes a new list", t.ns.AuctionPriceList() ~= list)

local scan = {}
for id, each in pairs(WAILING) do scan[id] = each end
scan[10], scan[12] = 55, 30
t = Setup(true, false, true, nil, nil, Feed(houses))
t.Priced(scan, 7200)
Check("a scan of your own finds your house among the faction's, whose newer prices win",
    t.ns.AuctionPrice(10) == 50 and t.ns.AuctionPrice(1001) == 101 and t.ns.AuctionScanTime() == FEED_TIME)
list = t.ns.AuctionPriceList()
Check("and the price list keeps what only your scan has", list[10] == 50 and list[12] == 30)
for id, each in pairs(OTHER) do scan[id] = each end
houses[119][2] = OTHER
houses[119][2][10] = 70
t = Setup(true, false, true, nil, nil, Feed(houses))
t.Priced(scan, 7200)
Check("the house that matches the most of your prices is yours", t.ns.AuctionPrice(10) == 70)

t = Setup(true, false, true, nil, true, Feed(houses))
lines = t.Tooltip(1001)
Check("the item price tooltip shows the release's price and its age", #lines == 1
    and lines[1].right == "101c |cff808080each, 1h ago|r")

t = Setup(true, false, true, nil, nil, Feed(houses), 3)
Check("another region's prices are never used", t.ns.AuctionPrice(10) == nil and t.ns.AuctionScanTime() == nil)

t = Setup(true, false, true, nil, nil, { time = 0, regions = {} })
Check("the placeholder prices nothing", t.ns.AuctionPrice(10) == nil and t.Loads() == 1)

t = Setup(true, false, true, nil, nil, Feed(houses))
t.Faction(nil)
Check("before your faction is known nothing loads", t.ns.AuctionPrice(10) == nil and t.Loads() == 0)
t.Faction("Alliance")
Check("and the release's prices load once it is", t.ns.AuctionPrice(10) == 50 and t.Loads() == 1)

t = Setup(true, false, true)
t.Priced({ [10] = 77 }, 60)
t.Faction(nil)
Check("a price asked for before your faction is known finds none", t.ns.AuctionPrice(10) == nil)
t.Faction("Alliance")
Check("and the realm alone is not kept as your house: your scan's price reads once it is known",
    t.ns.AuctionPrice(10) == 77)

t = Setup(true, false, true, nil, nil, Feed({ [110] = { "Alliance", { [10] = 5000000000 } } }))
Check("a price past 32 bits reads whole on Windows", t.ns.AuctionPrice(10) == 5000000000)

t = Setup(true, false, true, true, nil, Feed({ [110] = { "Alliance", { [PEACEBLOOM] = 10, [SILVERLEAF] = 8 } } }))
lines = t.Tooltip(HERBS)
Check("crate prices alone from the release name them, not a scan", Headers(lines) == 1
    and lines[1].right == "Prices from 1h ago")

t = Setup(true, false, true, nil, nil, Feed({
    [110] = { "Alliance", { [10] = 40, [11] = 7 }, { [10] = 3 } },
    [111] = { "Alliance", { [10] = 50 }, { [10] = 12 } },
    [119] = { "Alliance", { [10] = 60, [11] = 9 }, { [10] = 30 } },
}))
Check("how many are listed comes from the house whose price is the middle",
    t.ns.AuctionPrice(10) == 50 and t.ns.AuctionListed(10) == 12)
Check("an entry from a release built before the counts still prices, and lists none",
    t.ns.AuctionPrice(11) == 7 and t.ns.AuctionListed(11) == nil)
Check("an item nobody sells lists none", t.ns.AuctionListed(12) == nil and t.ns.AuctionListed(nil) == nil)

local wailingListed = {}
for i = 1, 25 do wailingListed[1000 + i] = i end
local counted = { [111] = { "Alliance", WAILING, wailingListed }, [119] = { "Alliance", OTHER } }
scan = {}
for id, each in pairs(WAILING) do scan[id] = each end
scan[12] = 30
t = Setup(true, false, true, nil, nil, Feed(counted))
t.Priced(scan, 7200, { [12] = 4 })
Check("once your house is found, its newer count is the one read", t.ns.AuctionListed(1003) == 3)
Check("what only your scan prices takes your scan's count", t.ns.AuctionListed(12) == 4)
t.Priced(scan, 60)
Check("a newer scan of your own from before the counts lists none", t.ns.AuctionPrice(1003) == scan[1003]
    and t.ns.AuctionListed(1003) == nil)

t = Setup(true, false, true)
t.Clock(-3 * 3600)
t.Fire("AUCTION_HOUSE_SHOW")
t.Button().click()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("a scan carries the realm's time, so a PC clock hours off still compares right with the release's",
    t.ns.AuctionScanTime() == t.Now())

t = Setup(true, false, true)
local changed = 0
t.ns.AuctionPricesChanged = function() changed = changed + 1 end
t.Fire("AUCTION_HOUSE_SHOW")
t.Button().click()
Check("Prices for Other Addons hears nothing before a scan finishes", changed == 0)
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("and hears once when it does", changed == 1)

t = Setup(true, false, true)
local marketTab = {}
local marketShown = true
t.ns.MarketAuctionTabs = function() if marketShown then return marketTab end end
t.Fire("AUCTION_HOUSE_SHOW")
Check("Scan Prices follows The Market's tabs on the auction house", t.Button().at[2] == marketTab)
marketShown = false
t.Run(0)
Check("and Blizzard's Auctions tab without them", t.Button().at[2] == t.frame.AuctionsTab)

local function Row(id, each, quantity, suffix)
    return { itemKey = { itemID = id, itemLevel = 0, itemSuffix = suffix or 0 }, minPrice = each,
        totalQuantity = quantity, containsOwnerItem = false }
end

local function Paged()
    local p = Setup(true, false, true)
    p.Fire("AUCTION_HOUSE_SHOW")
    p.Button().click()
    p.Fire("REPLICATE_ITEM_LIST_UPDATE")
    p.Flush()
    return p
end

t = Paged()
local fastAt = t.Now()
t.Advance(120)
printed = #t.messages
t.Button().click()
Check("inside the fast scan's 15 minutes, Scan Prices reads page by page and says so", t.Requests() == 1
    and t.Browses() == 1 and #t.messages == printed + 1
    and t.messages[#t.messages] == "Naowh AH: the fast scan is free again in 13m, so this one reads the auction house page by page.")
asked = t.Query()
Check("it asks for everything: no name, every quality, cheapest first", asked.searchString == ""
    and #asked.filters == 6 and #asked.sorts == 2 and asked.itemClassFilters == nil and asked.minLevel == nil)
t.Page({ Row(10, 300, 5), Row(20, 0, 1) }, false)
Check("a page that is not the last asks for the next", t.Mores() == 1 and t.Refreshes() == 1)
t.Ready(false)
t.Page({ Row(10, 250, 2, 588), Row(30, 70, 40) }, false, true)
Check("but waits while the auction house throttles", t.Mores() == 1)
t.Ready(true)
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("and goes on when it is ready", t.Mores() == 2)
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("once", t.Mores() == 2)
t.Advance(30)
t.Page({ Row(40, 9, 1) }, true, true)
t.Flush()
Check("the last page ends it", t.Refreshes() == 2 and not t.Paging() and t.Mores() == 2)
Check("with each item's lowest price across its variants", t.ns.AuctionPrice(10) == 250 and t.ns.AuctionPrice(30) == 70
    and t.ns.AuctionPrice(40) == 9)
Check("how many are up for sale", t.ns.AuctionListed(10) == 7 and t.ns.AuctionListed(30) == 40)
Check("and nothing for a row without a price, or an item no longer listed", t.ns.AuctionPrice(20) == nil
    and t.ns.AuctionPrice(15) == nil)
Check("it is the last scan", t.ns.AuctionScanTime() == t.Now()
    and t.messages[#t.messages] == "Naowh AH: Last scan 1m ago: 3 items priced.")
t.Run(30)
Check("no page's timeout outlives it", t.messages[#t.messages] == "Naowh AH: Last scan 1m ago: 3 items priced.")
t.Button().click()
Check("it does not use up the fast scan: the next click still pages", t.Browses() == 2 and t.Requests() == 1)
t.Page({}, true)
Check("an empty answer says so and keeps the prices", t.messages[#t.messages]
    == "Naowh AH: The auction house returned no listings. Try again in a moment."
    and t.ns.AuctionPrice(30) == 70 and not t.Paging())
t.Advance(901 - (t.Now() - fastAt))
t.Button().click()
Check("and the fast scan is back 15 minutes after the last one", t.Requests() == 2 and t.Browses() == 2)

t = Paged()
t.Button().click()
t.Page({ Row(10, 300, 5) }, false)
t.env.C_AuctionHouse.SendBrowseQuery({ searchString = "linen" })
Check("a search of your own takes the list, so the scan stops and says so", not t.Paging()
    and t.messages[#t.messages] == "Naowh AH: scan stopped: another search took its place.")
t.Page({ Row(10, 1, 1) }, true)
t.Flush()
Check("and its results are not read as a scan", t.Refreshes() == 1 and t.ns.AuctionPrice(10) == 49)
t.Button().click()
t.env.C_AuctionHouse.SearchForFavorites({})
Check("a favourites search does the same", not t.Paging())

t = Paged()
t.Button().click()
t.Page({ Row(10, 300, 5) }, false)
t.Run(30)
Check("a page that never comes ends it with a reason", not t.Paging()
    and t.messages[#t.messages] == "Naowh AH: scan stopped: no answer from the auction house. Try again in a moment.")
t.Button().click()
t.Fire("AUCTION_HOUSE_BROWSE_FAILURE")
Check("so does the auction house failing", not t.Paging() and t.messages[#t.messages]:find("no answer", 1, true))
t.Button().click()
t.Page({ Row(10, 300, 5) }, false)
printed = #t.messages
t.Fire("AUCTION_HOUSE_CLOSED")
t.Run(30)
Check("leaving the auctioneer stops it, once", not t.Paging() and #t.messages == printed + 1
    and t.messages[#t.messages] == "Naowh AH: scan stopped: the auction house closed.")
Check("and a scan that stopped wrote nothing", t.ns.AuctionPrice(10) == 49 and t.Refreshes() == 1)

t = Paged()
t.Ready(false)
t.Button().click()
Check("a throttled auction house is not asked yet", t.Browses() == 0 and t.Paging())
t.Page({ Row(10, 1, 1) }, true)
t.Flush()
Check("and a list that came before the question is no answer", t.Refreshes() == 1 and t.Paging())
t.Ready(true)
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("the question goes when it is ready", t.Browses() == 1)

t = Setup(true, false, true)
Check("Scan on Opening and its age follow the capture row", t.card.rows[6].key == "ahAutoScan"
    and t.card.rows[7].key == "ahAutoScanMinutes" and t.card.rows[7].needs() == false)
t.Fire("AUCTION_HOUSE_SHOW")
t.Run(1)
Check("off, opening the auction house scans nothing", t.Requests() == 0 and t.Browses() == 0)
t.settings.Set("ahAutoScan", true)
Check("on, its age row is free", t.card.rows[7].needs() == true)
t.Fire("AUCTION_HOUSE_SHOW")
Check("on, opening waits a moment", t.Requests() == 0)
t.Run(1)
Check("then scans with no scan yet, and says so", t.Requests() == 1
    and t.messages[#t.messages] == "Naowh AH: please wait while the auction house scan completes.")
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
t.Fire("AUCTION_HOUSE_CLOSED")
t.Advance(600)
t.Fire("AUCTION_HOUSE_SHOW")
t.Run(1)
Check("a scan younger than its minutes is left alone", t.Requests() == 1 and t.Browses() == 0)
t.Fire("AUCTION_HOUSE_CLOSED")
t.Advance(300)
t.Fire("AUCTION_HOUSE_SHOW")
t.Run(1)
Check("an older one is scanned again", t.Requests() == 2)
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
t.Fire("AUCTION_HOUSE_CLOSED")
t.settings.Set("ahAutoScanMinutes", 5)
t.Advance(400)
t.Fire("AUCTION_HOUSE_SHOW")
t.Run(1)
Check("inside the fast scan's 15 minutes it pages", t.Requests() == 2 and t.Browses() == 1)
t.Fire("AUCTION_HOUSE_CLOSED")
t.Advance(901)
t.Fire("AUCTION_HOUSE_SHOW")
t.Fire("AUCTION_HOUSE_CLOSED")
t.Run(1)
Check("closing before the moment is up scans nothing", t.Requests() == 2 and t.Browses() == 1)

local BAY = {}
for i = 1, 25 do BAY[2000 + i] = 300 + i end
BAY[10] = 120
local realm = {
    [110] = { "Alliance", { [10] = 40, [11] = 7 } },
    [113] = { "Horde", { [10] = 1 } },
    [120] = { "Blackwater", { [10] = 80, [11] = 12 } },
    [121] = { "Blackwater", BAY },
    [122] = { "Blackwater", { [10] = 100 } },
    [123] = { "Blackwater", {} },
}
t = Setup(true, false, true, nil, nil, Feed(realm))
Check("the other house you can reach is the realm's Blackwater house", t.ns.AuctionOtherHouse() == "Blackwater"
    and t.ns.AuctionHouseKey() == "Realm-Alliance")
local there, thereAt, known = t.ns.AuctionOtherPrice(10)
Check("its price is the middle of the region's Blackwater houses until one is known to be this realm's",
    there == 100 and thereAt == FEED_TIME and known == false)
Check("your own house still reads its own price", t.ns.AuctionPrice(10) == 40 and t.ns.AuctionPrice(11) == 7)
Check("an item no Blackwater house lists has no price there", t.ns.AuctionOtherPrice(1001) == nil
    and t.ns.AuctionOtherPrice(nil) == nil)
local decodes = t.Decodes()
Check("reading one house never throws away the other's decoded prices", t.ns.AuctionPrice(10) == 40
    and t.ns.AuctionOtherPrice(11) == 12 and t.ns.AuctionPrice(11) == 7 and t.Decodes() == decodes)

t.Npc("Alliance")
t.Fire("AUCTION_HOUSE_SHOW")
Check("at your faction's auctioneer nothing changes", t.ns.AuctionHouseKey() == "Realm-Alliance"
    and t.ns.AuctionPrice(10) == 40 and t.ns.AuctionOtherPrice(10) == 100)
t.Fire("AUCTION_HOUSE_CLOSED")
t.Npc(false)
t.Territory("friendly")
t.Fire("AUCTION_HOUSE_SHOW")
Check("an auctioneer who reads as neither faction in your faction's own territory is still your faction's",
    t.ns.AuctionHouseKey() == "Realm-Alliance" and t.ns.AuctionOtherHouse() == "Blackwater"
    and t.ns.AuctionPrice(10) == 40)
t.Fire("AUCTION_HOUSE_CLOSED")
t.Territory("contested")
t.Fire("AUCTION_HOUSE_SHOW")
Check("at an auctioneer of neither faction the house is Blackwater, and the other one your faction's",
    t.ns.AuctionHouseKey() == "Realm-Blackwater" and t.ns.AuctionOtherHouse() == "Alliance"
    and t.ns.AuctionPrice(10) == 100 and t.ns.AuctionOtherPrice(10) == 40)
t.Button().click()
t.Fire("REPLICATE_ITEM_LIST_UPDATE")
t.Flush()
Check("a scan there is kept as Blackwater's and never as your faction's", t.House("Realm-Blackwater").prices[10] == 49
    and t.House("Realm-Alliance") == nil and t.ns.AuctionPrice(10) == 49)
t.Fire("AUCTION_HOUSE_CLOSED")
there, thereAt, known = t.ns.AuctionOtherPrice(10)
Check("away from it your faction's house is yours again, and Blackwater reads your scan there, a house now known",
    t.ns.AuctionHouseKey() == "Realm-Alliance" and t.ns.AuctionPrice(10) == 40 and there == 49
    and thereAt == t.Now() and known == true)
Check("which still leaves the release's middle for what the scan does not list", t.ns.AuctionOtherPrice(11) == 12)

local bay = {}
for id, each in pairs(BAY) do bay[id] = each end
bay[10] = 119
t = Setup(true, false, true, nil, nil, Feed(realm))
t.PricedAt("Realm-Blackwater", bay, 7200)
there, thereAt = t.ns.AuctionOtherPrice(10)
Check("a scan at Blackwater finds this realm's Blackwater house, whose newer price is then read",
    there == 120 and thereAt == FEED_TIME)
Check("and your faction's house is found on its own, from your scans there", t.ns.AuctionPrice(10) == 40)

t = Setup(true, false, true)
Check("with no release prices and no scan there, the other house prices nothing",
    t.ns.AuctionOtherPrice(10) == nil and t.ns.AuctionOtherHouse() == "Blackwater")
t = Setup(true, false, true)
t.Faction(nil)
Check("before your faction is known there is no other house", t.ns.AuctionOtherHouse() == nil
    and t.ns.AuctionOtherPrice(10) == nil)

print("auction prices: " .. checks .. " checks passed")
