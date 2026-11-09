-- Buy.lua: searching the auction house by name and category, and buying: a commodity at the price the game quotes, an item at its buyout (ns.Market.Buy).
local ns = _G.NaowhForever

local Market = ns.Market
local Listings = Market.Listings

local BROWSE_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
    { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
local NO_FILTERS = {}
local QUOTE_SLACK = 1.05
local FAVOURITES = "marketFavourites"
local TOKEN_FLAG = "WOW_TOKEN_FLAG"
local EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_FAILURE", "ITEM_KEY_ITEM_INFO_RECEIVED",
    "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED",
    "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }

local results = {}
local picked, purchase = {}, {}
local query = { sorts = BROWSE_SORTS, filters = NO_FILTERS, itemClassFilters = NO_FILTERS }
local searchText, searchWaiting, category, moreAsked
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
    if not (searchText or category) then return end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        searchWaiting = true
        return
    end
    searchWaiting = false
    query.searchString = searchText or ""
    query.itemClassFilters = category and category.filters or NO_FILTERS
    C_AuctionHouse.SendBrowseQuery(query)
    Buy.searching, Buy.searched = true, true
end

local function ReadResults()
    Buy.searching, moreAsked = false, false
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
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        moreAsked = false
        for _, result in ipairs(a) do results[#results + 1] = result end
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
    Buy.searched = false
    wipe(results)
    SendSearch()
end

function Buy.SetCategory(chosen)
    category = chosen
    Buy.category = chosen
end

function Buy.Categories(out)
    wipe(out)
    for _, c in ipairs(AuctionCategories) do
        if not c:HasFlag(TOKEN_FLAG) then out[#out + 1] = c end
    end
    return out
end

function Buy.More()
    if moreAsked or Buy.searching or not Buy.searched or C_AuctionHouse.HasFullBrowseResults() then return end
    moreAsked = true
    C_AuctionHouse.RequestMoreBrowseResults()
end

function Buy.Pick(itemKey, quantity)
    CancelQuote()
    wipe(purchase)
    picked.itemKey, picked.itemID, picked.commodity = itemKey, itemKey.itemID, nil
    picked.quantity = quantity
    Want()
end

local function Favourites(create)
    local account = ns.AccountSettings()
    if create and not account[FAVOURITES] then account[FAVOURITES] = {} end
    return account[FAVOURITES]
end

function Buy.IsFavourite(itemID)
    local saved = Favourites()
    return saved ~= nil and saved[itemID] ~= nil
end

function Buy.ToggleFavourite(itemKey)
    local saved = Favourites(true)
    if saved[itemKey.itemID] then
        saved[itemKey.itemID] = nil
    else
        saved[itemKey.itemID] = { level = itemKey.itemLevel, suffix = itemKey.itemSuffix,
            pet = itemKey.battlePetSpeciesID }
    end
end

function Buy.FavouriteKey(itemID)
    local key = Favourites()[itemID]
    return { itemID = itemID, itemLevel = key.level or 0, itemSuffix = key.suffix or 0,
        battlePetSpeciesID = key.pet or 0 }
end

local function ByName(a, b)
    local x, y = C_Item.GetItemNameByID(a) or "", C_Item.GetItemNameByID(b) or ""
    if x ~= y then return x < y end
    return a < b
end

function Buy.Favourites(out)
    wipe(out)
    for itemID in pairs(Favourites() or {}) do out[#out + 1] = itemID end
    table.sort(out, ByName)
    return out
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

function Buy.WatchShopping(fn)
    local shopping = Shopping()
    if not shopping then return false end
    shopping.OnChange(fn)
    return true
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
