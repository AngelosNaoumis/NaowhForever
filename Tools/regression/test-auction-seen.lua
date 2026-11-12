-- Run with Lua 5.1 from the repository root: Auction Prices kept as you go, from browse rows, an item's listings and
-- your own posts, without a scan.
local Load = dofile("Tools/regression/load_files.lua")
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Noop() end

local SCAN_AGO = 7200

local function Setup(opts)
    opts = opts or {}
    local values = { ahPrices = opts.button ~= false, ahTooltip = true }
    local account, registered, posts, hooks = {}, {}, {}, {}
    local now = 100000
    local changes, seen = 0, {}
    local browse, commodity, items, full = {}, {}, {}, true
    local marketOn, marketListeners = opts.market, {}
    local frames = 0
    local frame = {}
    function frame:RegisterEvent(event) registered[event] = self end
    function frame:UnregisterEvent(event) registered[event] = nil end
    function frame:UnregisterAllEvents()
        for event, owner in pairs(registered) do
            if owner == self then registered[event] = nil end
        end
    end
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
        GamepadStandDown = function() return false end,
        Print = Noop,
        Apply = Noop,
        THEME = { accent = { r = 0, g = 0.57, b = 0.93 } },
        Tooltip = Noop,
        Font = function() return { SetPoint = Noop, SetText = Noop } end,
        Button = function() return { label = { SetText = Noop }, ClearAllPoints = Noop, SetPoint = Noop, SetShown = Noop } end,
        Shared = { Settings = { Page = function() return { Card = Noop } end },
            Items = { Name = function(id) return "item" .. id end } },
        AuctionPricesChanged = function() changes = changes + 1 end,
        MarketPricesSeen = function(ids, count)
            seen = {}
            for i = 1, count do seen[i] = ids[i] end
        end,
    }
    if opts.market ~= nil then
        ns.Market = { On = function() return marketOn end, ShowsPrice = function() return false end }
        ns.MarketSettings = { OnChange = function(fn) marketListeners[#marketListeners + 1] = fn end }
    end
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function()
            frames = frames + 1
            return setmetatable({}, { __index = frame })
        end,
        GetRealmName = function() return "Realm" end,
        GetCurrentRegion = function() return 1 end,
        C_AddOns = { LoadAddOn = function() ns.AuctionFeed = opts.feed end },
        UnitFactionGroup = function() return "Alliance" end,
        GetServerTime = function() return now end,
        BreakUpLargeNumbers = tostring,
        C_CurrencyInfo = { GetCoinTextureString = function(amount) return amount .. "c" end },
        C_Timer = { After = Noop, NewTicker = function() return { Cancel = Noop } end },
        C_Item = {
            DoesItemExist = function(location) return location.itemID ~= nil end,
            GetItemID = function(location) return location.itemID end,
        },
        C_AuctionHouse = {
            ReplicateItems = Noop,
            GetBrowseResults = function() return browse end,
            GetNumCommoditySearchResults = function(id) return #(commodity[id] or {}) end,
            GetCommoditySearchResultInfo = function(id, i) return commodity[id][i] end,
            HasFullCommoditySearchResults = function() return full end,
            GetNumItemSearchResults = function(key) return #(items[key.itemID] or {}) end,
            GetItemSearchResultInfo = function(key, i) return items[key.itemID][i] end,
            HasFullItemSearchResults = function() return full end,
            PostItem = Noop,
            PostCommodity = Noop,
        },
        hooksecurefunc = function(target, key, hook)
            hooks[key] = (hooks[key] or 0) + 1
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
        "NaowhForever_QoL/Loot/AuctionPrices.lua", "NaowhForever_QoL/Loot/AuctionSeen.lua" }, env)
    local t = { ns = ns, settings = S, env = env, account = account }
    function t.Fire(event, ...)
        local owner = registered[event]
        if owner then owner.handler(owner, event, ...) end
    end
    function t.Listening(event) return registered[event or "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED"] ~= nil end
    function t.Hooks(key) return hooks[key] or 0 end
    function t.Frames() return frames end
    function t.Changes() return changes end
    function t.Seen() return seen end
    function t.Advance(seconds) now = now + seconds end
    function t.Now() return now end
    function t.Market(on)
        marketOn = on
        for _, fn in ipairs(marketListeners) do fn("enabled") end
    end
    function t.Scanned(prices, listed)
        account.ahPrices = { ["Realm-Alliance"] = { prices = prices, listed = listed, time = now - SCAN_AGO } }
    end
    function t.House() return account.ahPrices and account.ahPrices["Realm-Alliance"] end
    function t.Browse(rows)
        browse = rows
        t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    end
    function t.Commodity(id, rows, whole)
        commodity[id], full = rows, whole ~= false
        t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", id)
    end
    function t.Items(key, rows, whole)
        items[key.itemID], full = rows, whole ~= false
        t.Fire("ITEM_SEARCH_RESULTS_UPDATED", key)
    end
    function t.Tooltip(id)
        local tooltip = { lines = {} }
        function tooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { left = left, right = right } end
        for _, post in ipairs(posts) do post(tooltip, { id = id }) end
        return tooltip.lines
    end
    return t
end

local function Row(id, price, quantity, suffix)
    return { itemKey = { itemID = id, itemLevel = 0, itemSuffix = suffix or 0 }, minPrice = price,
        totalQuantity = quantity, containsOwnerItem = false }
end

local function Rows(field, ...)
    local rows = {}
    for i, price in ipairs({ ... }) do rows[i] = { [field] = price or nil, quantity = i } end
    return rows
end

local CLOTH, ORE, BELT, SWORD = 2589, 2770, 9775, 2488
local EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED" }

local t = Setup({ button = false })
local idle = t.Frames()
for _, event in ipairs(EVENTS) do Check("off registers no " .. event, not t.Listening(event)) end
Check("off makes no frame and hooks no post", t.Hooks("PostItem") == 0 and t.Hooks("PostCommodity") == 0)
t.settings.Set("ahPrices", true)
for _, event in ipairs(EVENTS) do Check("the Scan Prices switch registers " .. event, t.Listening(event)) end
Check("on its own frame, made then", t.Frames() == idle + 1)
Check("and hooks both posts once", t.Hooks("PostItem") == 1 and t.Hooks("PostCommodity") == 1)
t.settings.Set("ahPrices", false)
Check("turning it off drops every event", not t.Listening() and not t.Listening("ITEM_SEARCH_RESULTS_UPDATED"))
t.settings.Set("ahPrices", true)
Check("turning it on again hooks nothing twice", t.Hooks("PostItem") == 1 and t.Frames() == idle + 1)

t = Setup({ button = false, market = true })
Check("The Market on is enough to listen", t.Listening())
t.Market(false)
Check("and off with it", not t.Listening())
t.Market(true)
Check("and on again", t.Listening())

t = Setup()
t.Scanned({ [CLOTH] = 100, [ORE] = 500, [BELT] = 9000 }, { [CLOTH] = 40 })
local scanTime = t.ns.AuctionScanTime()
t.Advance(60)
t.Browse({ Row(CLOTH, 80, 300), Row(ORE, 600, 12), Row(SWORD, 0, 1) })
local price, at = t.ns.AuctionPrice(CLOTH)
Check("a browse row's lowest price replaces the scan's, dated when it was seen", price == 80 and at == t.Now())
Check("and its quantity is the listed count", t.ns.AuctionListed(CLOTH) == 300)
Check("a row can raise a price: it is the whole item", t.ns.AuctionPrice(ORE) == 600 and t.ns.AuctionListed(ORE) == 12)
Check("a row with no price is left out", t.ns.AuctionPrice(SWORD) == nil)
Check("the last scan's time does not move", t.ns.AuctionScanTime() == scanTime
    and t.ns.AuctionScanSummary() == "Last scan 2h ago: 3 items priced.")
Check("an item not seen keeps the scan's time", select(2, t.ns.AuctionPrice(BELT)) == scanTime)
Check("one event tells the others once, with the items that changed", t.Changes() == 1 and #t.Seen() == 2
    and t.Seen()[1] == CLOTH and t.Seen()[2] == ORE)
local lines = t.Tooltip(CLOTH)
Check("the tooltip dates the price from the sighting, not a scan", lines[1].right == "80c |cff808080each, 1m ago|r")
t.Advance(60)
t.Browse({ Row(CLOTH, 80, 300) })
Check("the same row again changes nothing and tells no one, but the price is fresh", t.Changes() == 1
    and select(2, t.ns.AuctionPrice(CLOTH)) == t.Now())

t.Browse({ Row(BELT, 9500, 1, 1183), Row(BELT, 7000, 2, 588) })
Check("a random-suffix row is only one variant: it lowers the price", t.ns.AuctionPrice(BELT) == 7000)
Check("never raises it, and leaves the count alone", t.ns.AuctionListed(BELT) == nil)
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { Row(SWORD, 250, 3) })
Check("rows added to the list are read from the event", t.ns.AuctionPrice(SWORD) == 250 and t.ns.AuctionListed(SWORD) == 3)

t.Commodity(CLOTH, Rows("unitPrice", 90, 95, 120))
Check("a commodity's listings give its lowest price and how many are up", t.ns.AuctionPrice(CLOTH) == 90
    and t.ns.AuctionListed(CLOTH) == 6)
local many = {}
for i = 1, 60 do many[i] = { unitPrice = 200 + i, quantity = 1 } end
t.Commodity(CLOTH, many)
Check("more rows than are read still price it when they rise, without a count", t.ns.AuctionPrice(CLOTH) == 201
    and t.ns.AuctionListed(CLOTH) == 6)
for i = 1, 60 do many[i] = { unitPrice = 900 - i, quantity = 1 } end
t.Commodity(CLOTH, many)
Check("rows in another order are not the lowest for sure: they never raise the price", t.ns.AuctionPrice(CLOTH) == 201)
for i = 1, 60 do many[i] = { unitPrice = 190 - i, quantity = 1 } end
t.Commodity(CLOTH, many)
Check("but may lower it", t.ns.AuctionPrice(CLOTH) == 140)
t.Commodity(ORE, Rows("unitPrice", 700, 800), false)
Check("listings still arriving price it without a count", t.ns.AuctionPrice(ORE) == 700 and t.ns.AuctionListed(ORE) == 12)
t.Commodity(ORE, {})
Check("no listings leave the last price", t.ns.AuctionPrice(ORE) == 700)

local key = { itemID = SWORD, itemLevel = 0, itemSuffix = 0 }
t.Items(key, Rows("buyoutAmount", false, 400, 300))
Check("an item's listings skip bids without a buyout", t.ns.AuctionPrice(SWORD) == 300 and t.ns.AuctionListed(SWORD) == 5)
t.Items({ itemID = BELT, itemLevel = 30, itemSuffix = 588 }, Rows("buyoutAmount", 8000))
Check("one variant's listings never raise the item's price", t.ns.AuctionPrice(BELT) == 7000)

local told = t.Changes()
t.env.C_AuctionHouse.PostCommodity({ itemID = CLOTH }, 2, 20, 130)
Check("a post alone writes nothing", t.ns.AuctionPrice(CLOTH) == 140 and t.Changes() == told)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
Check("your post under the lowest becomes the lowest once the auction is made", t.ns.AuctionPrice(CLOTH) == 130)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 2)
t.env.C_AuctionHouse.PostCommodity({ itemID = CLOTH }, 2, 20, 500)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 3)
Check("your post over the lowest changes nothing", t.ns.AuctionPrice(CLOTH) == 130)
t.env.C_AuctionHouse.PostItem({ itemID = SWORD }, 2, 1, 100, 280)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 4)
Check("an item's post is its buyout", t.ns.AuctionPrice(SWORD) == 280)
t.env.C_AuctionHouse.PostItem({ itemID = SWORD }, 2, 1, 100, nil)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 5)
t.env.C_AuctionHouse.PostItem({}, 2, 1, nil, 10)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 6)
Check("a bid-only post, or one whose item is gone, writes nothing", t.ns.AuctionPrice(SWORD) == 280)
t.settings.Set("ahPrices", false)
t.env.C_AuctionHouse.PostItem({ itemID = SWORD }, 2, 1, nil, 10)
t.settings.Set("ahPrices", true)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 7)
Check("the post hooks do nothing while it is off", t.ns.AuctionPrice(SWORD) == 280)

t = Setup()
Check("with no scan, nothing is priced", t.ns.AuctionPrice(CLOTH) == nil)
t.Browse({ Row(CLOTH, 80, 300) })
Check("a seen price reads without any scan", t.ns.AuctionPrice(CLOTH) == 80)
Check("but no scan is claimed", t.ns.AuctionScanTime() == nil
    and t.ns.AuctionScanSummary() == "No scan yet for this realm and faction.")
t.Advance(120)
Check("its tooltip still shows it, with its age", t.Tooltip(CLOTH)[1].right == "80c |cff808080each, 2m ago|r")
Check("the price list holds it", t.ns.AuctionPriceList()[CLOTH] == 80)

local FEED_TIME = 100000 - 3600
local DIGITS = "123456789abcdefghijklmnop"
local function Feed()
    local parts = {}
    for i = 1, 25 do parts[i] = (i == 1 and "rs" or "1") .. ":" .. DIGITS:sub(i, i) end
    return { time = FEED_TIME,
        regions = { [1] = { [110] = { faction = "Alliance", prices = table.concat(parts, ",") } } } }
end
local scan = {}
for i = 1, 25 do scan[999 + i] = i end
t = Setup({ feed = Feed() })
t.Scanned(scan)
Check("the release's newer prices of your house come before an older scan", select(2, t.ns.AuctionPrice(1000)) == FEED_TIME)
local list = t.ns.AuctionPriceList()
t.Browse({ Row(1000, 77, 4) })
price, at = t.ns.AuctionPrice(1000)
Check("a price seen since comes before them", price == 77 and at == t.Now() and t.ns.AuctionListed(1000) == 4)
Check("and is written into the price list in hand", t.ns.AuctionPriceList() == list and list[1000] == 77)
Check("the rest stay the release's", select(2, t.ns.AuctionPrice(1001)) == FEED_TIME)

t = Setup({ feed = Feed() })
t.Browse({ Row(1000, 77, 4) })
list = t.ns.AuctionPriceList()
Check("with no scan, the list is the release's with what you saw over it", list[1000] == 77 and list[1001] == 2)
t.Browse({ Row(1001, 55, 1) })
Check("and keeps up", t.ns.AuctionPriceList() == list and list[1001] == 55)

print("auction seen: " .. checks .. " checks passed")
