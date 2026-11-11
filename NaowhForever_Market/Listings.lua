-- Listings.lua: the auction house's listings of one item, cheapest first, asked for when you pick it (ns.Market.Listings).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local COMMODITY_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local ITEM_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false },
    { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false } }
local EVENTS = { "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }

local rows = {}
local wanted = {}
local events
local gen = 0

local Listings = { rows = rows, count = 0 }
Market.Listings = Listings

local function Changed()
    if Listings.onChange then Listings.onChange() end
end

local function Row(n, price, quantity, own, auctionID)
    local row = rows[n]
    if not row then
        row = {}
        rows[n] = row
    end
    row.price, row.quantity, row.own, row.auctionID = price, quantity, own, auctionID
end

local function ReadCommodities(itemID)
    local n = 0
    for i = 1, math.min(C_AuctionHouse.GetNumCommoditySearchResults(itemID), C.MAX_ROWS) do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if result then
            n = n + 1
            Row(n, result.unitPrice, result.quantity, result.numOwnerItems)
        end
    end
    return n
end

local function ReadItems(itemKey)
    local n = 0
    for i = 1, math.min(C_AuctionHouse.GetNumItemSearchResults(itemKey), C.MAX_ROWS) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        local price = result and result.buyoutAmount
        if price then
            local own = result.containsOwnerItem and result.quantity or 0
            local other = not result.containsOwnerItem and result.auctionID or nil
            local last = rows[n]
            if n > 0 and last.price == price then
                last.quantity, last.own = last.quantity + result.quantity, last.own + own
                last.auctionID = last.auctionID or other
            else
                n = n + 1
                Row(n, price, result.quantity, own, other)
            end
        end
    end
    return n
end

local function Listed(n)
    Listings.count, Listings.state = n, "listed"
    Market.Watch.Listed(wanted.itemID, (Listings.Cheapest()))
    Changed()
end

local function TimedOut(searchGen)
    if searchGen ~= gen or Listings.state ~= "searching" then return end
    Listings.state = "noanswer"
    Changed()
end

local Send

local function RetryWaiting(waitGen)
    if waitGen ~= gen or Listings.state ~= "waiting" then return end
    Send()
    Changed()
end

local function SendItem()
    if wanted.itemKey then
        C_AuctionHouse.SendSearchQuery(wanted.itemKey, ITEM_SORTS, true)
        return true
    end
    local location = Market.Bags.Location(wanted)
    if not location then return false end
    local key = C_AuctionHouse.GetItemKeyFromItem(location)
    if C_Item.IsEquippableItem(wanted.itemID) then
        key.itemLevel, key.itemSuffix = 0, 0
        C_AuctionHouse.SendSellSearchQuery(key, ITEM_SORTS, true)
    else
        C_AuctionHouse.SendSearchQuery(key, ITEM_SORTS, true)
    end
    return true
end

function Send()
    if not wanted.itemID then return end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        Listings.state = "waiting"
        gen = gen + 1
        local waitGen = gen
        C_Timer.After(C.SEARCH_RETRY, function() RetryWaiting(waitGen) end)
        return
    end
    gen = gen + 1
    local searchGen = gen
    if wanted.commodity then
        C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(wanted.itemID), COMMODITY_SORTS, true)
    elseif not SendItem() then
        return Listed(0)
    end
    Listings.state = "searching"
    C_Timer.After(C.SEARCH_TIMEOUT, function() TimedOut(searchGen) end)
end

local function OnEvent(_, event, arg)
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if Listings.state ~= "waiting" then return end
        Send()
        return Changed()
    end
    if not wanted.itemID or Listings.state == "waiting" then return end
    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        if wanted.commodity and arg == wanted.itemID then Listed(ReadCommodities(arg)) end
    elseif not wanted.commodity and arg.itemID == wanted.itemID then
        Listed(ReadItems(arg))
    end
end

function Listings.Want(entry)
    gen = gen + 1
    Listings.count, Listings.state = 0, nil
    wanted.itemID = entry and entry.itemID
    if not entry then return end
    wanted.commodity, wanted.link, wanted.bag, wanted.slot = entry.commodity, entry.link, entry.bag, entry.slot
    wanted.itemKey = entry.itemKey
    Send()
end

function Listings.Cheapest()
    local other, own
    for i = 1, Listings.count do
        local row = rows[i]
        if not own and row.own > 0 then own = row.price end
        if not other and row.quantity > row.own then other = row.price end
        if other and own then break end
    end
    return other, own
end

function Listings.Again()
    Send()
end

function Listings.Start()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

function Listings.Stop()
    if events then events:UnregisterAllEvents() end
    Listings.Want(nil)
end
