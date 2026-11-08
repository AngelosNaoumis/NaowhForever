-- Buy.lua: searching the auction house by name, and buying: a commodity at the price the game quotes, an item at its buyout (ns.Market.Buy).
local ns = _G.NaowhForever

local Market = ns.Market
local Listings = Market.Listings

local BROWSE_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
    { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
local NO_FILTERS = {}
local QUOTE_SLACK = 1.05
local EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_FAILURE", "ITEM_KEY_ITEM_INFO_RECEIVED",
    "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED",
    "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }

local results = {}
local picked, purchase = {}, {}
local query = { sorts = BROWSE_SORTS, filters = NO_FILTERS, itemClassFilters = NO_FILTERS }
local searchText, searchWaiting
local events

local Buy = { results = results, picked = picked, purchase = purchase }
Market.Buy = Buy

local function Changed()
    if Buy.onChange then Buy.onChange() end
end

local function Shopping()
    local P = ns.Professions
    return P and P.Shopping
end

local function SendSearch()
    if not searchText then return end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        searchWaiting = true
        return
    end
    searchWaiting = false
    query.searchString = searchText
    C_AuctionHouse.SendBrowseQuery(query)
    Buy.searching = true
end

local function ReadResults()
    Buy.searching = false
    wipe(results)
    for i, result in ipairs(C_AuctionHouse.GetBrowseResults()) do results[i] = result end
end

local function Want()
    local info = C_AuctionHouse.GetItemKeyInfo(picked.itemKey)
    picked.waiting = info == nil
    if picked.waiting then return Listings.Want(nil) end
    picked.commodity = info.isCommodity
    Listings.Want({ itemID = picked.itemID, commodity = info.isCommodity,
        itemKey = not info.isCommodity and picked.itemKey or nil })
end

local function CancelQuote()
    local state = purchase.state
    if state == "quoting" or state == "quoted" then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
end

local function Bought()
    purchase.state = "bought"
    local shopping = Shopping()
    if shopping and picked.commodity then shopping.Bought(picked.itemID, purchase.quantity) end
    Listings.Again()
end

local function OnEvent(_, event, a, b)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        ReadResults()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        Buy.searching = false
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if not searchWaiting then return end
        SendSearch()
    elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        if not (picked.waiting and a == picked.itemID) then return end
        Want()
    elseif event == "COMMODITY_PRICE_UPDATED" then
        if purchase.state ~= "quoting" then return end
        purchase.state, purchase.unit, purchase.total = "quoted", a, b
        purchase.over = purchase.expected ~= nil and a > purchase.expected * QUOTE_SLACK
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        if purchase.state == "quoting" then purchase.state = "unavailable" end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if purchase.state == "buying" then Bought() end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if purchase.state == "buying" and a == purchase.auctionID then Bought() end
    elseif purchase.state == "buying" then
        purchase.state = "failed"
    else
        return
    end
    Changed()
end

function Buy.Search(text)
    searchText = text ~= "" and text or nil
    wipe(results)
    SendSearch()
end

function Buy.Pick(itemKey, quantity)
    CancelQuote()
    wipe(purchase)
    picked.itemKey, picked.itemID, picked.commodity = itemKey, itemKey.itemID, nil
    picked.quantity = quantity
    Want()
end

function Buy.PickItem(itemID, quantity)
    Buy.Pick(C_AuctionHouse.MakeItemKey(itemID), quantity)
end

function Buy.Cost(quantity)
    local left, cost = quantity, 0
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        local take = math.min(left, row.quantity - row.own)
        if take > 0 then
            cost = cost + take * row.price
            left = left - take
        end
        if left == 0 then return cost, 0 end
    end
    return cost, left
end

function Buy.Cheapest()
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        if row.auctionID then return row end
    end
end

function Buy.ShoppingList()
    local shopping = Shopping()
    if not shopping then return end
    return (shopping.Materials())
end

function Buy.Purchase(quantity)
    if not picked.itemID or picked.waiting then return false end
    if picked.commodity then
        if purchase.state == "quoted" then
            purchase.state = "buying"
            C_AuctionHouse.ConfirmCommoditiesPurchase(picked.itemID, purchase.quantity)
            return true
        end
        local cost, short = Buy.Cost(quantity)
        if short > 0 or cost > GetMoney() then return false end
        wipe(purchase)
        purchase.state, purchase.quantity, purchase.expected = "quoting", quantity, cost / quantity
        C_AuctionHouse.StartCommoditiesPurchase(picked.itemID, quantity)
        return true
    end
    local row = Buy.Cheapest()
    if not row or row.price > GetMoney() then return false end
    wipe(purchase)
    purchase.state, purchase.quantity, purchase.auctionID, purchase.total = "buying", 1, row.auctionID, row.price
    C_AuctionHouse.PlaceBid(row.auctionID, row.price)
    return true
end

function Buy.Reset()
    CancelQuote()
    wipe(purchase)
end

function Buy.Open()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

function Buy.Close()
    if events then events:UnregisterAllEvents() end
    Buy.Reset()
    picked.itemID = nil
end
