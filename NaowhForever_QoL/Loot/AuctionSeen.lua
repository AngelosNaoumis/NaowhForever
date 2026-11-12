-- AuctionSeen.lua: Auction Prices kept as you go, from the listings the auction house already sent you and your own posts.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local SEEN_ROWS = 50
local EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED" }

local events, hooked, watching
local postID, postPrice

local function On()
    local market = ns.Market
    return S.Get("ahPrices") or market ~= nil and market.On()
end

local function SeeBrowse(results)
    for i = 1, #results do
        local result = results[i]
        local key, price = result.itemKey, result.minPrice
        if price > 0 then
            local whole = key.itemSuffix == 0
            ns.AuctionSeen(key.itemID, price, whole and result.totalQuantity or nil, whole)
        end
    end
    ns.AuctionSeenDone()
end

local function SeeRows(itemID, count, Info, arg, field, whole, full)
    local shown = math.min(count, SEEN_ROWS)
    local lowest, last, quantity, rising = nil, nil, 0, true
    for i = 1, shown do
        local row = Info(arg, i)
        local price = row and row[field]
        if price and price > 0 then
            if last and price < last then rising = false end
            if not lowest or price < lowest then lowest = price end
            last = price
            quantity = quantity + row.quantity
        end
    end
    if not lowest then return end
    local all = full and shown == count
    ns.AuctionSeen(itemID, lowest, all and quantity or nil, whole and (all or rising and lowest < last))
    ns.AuctionSeenDone()
end

local function NotePost(location, price)
    postID, postPrice = nil, nil
    if not (watching and price and price > 0 and C_Item.DoesItemExist(location)) then return end
    postID, postPrice = C_Item.GetItemID(location), price
end

local function OnPostItem(location, _, _, _, buyout)
    NotePost(location, buyout)
end

local function OnPostCommodity(location, _, _, unitPrice)
    NotePost(location, unitPrice)
end

local function OnEvent(_, event, arg)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        SeeBrowse(C_AuctionHouse.GetBrowseResults())
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        SeeBrowse(arg)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        SeeRows(arg, C_AuctionHouse.GetNumCommoditySearchResults(arg), C_AuctionHouse.GetCommoditySearchResultInfo,
            arg, "unitPrice", true, C_AuctionHouse.HasFullCommoditySearchResults(arg))
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        SeeRows(arg.itemID, C_AuctionHouse.GetNumItemSearchResults(arg), C_AuctionHouse.GetItemSearchResultInfo,
            arg, "buyoutAmount", arg.itemSuffix == 0, C_AuctionHouse.HasFullItemSearchResults(arg))
    elseif postID then
        ns.AuctionSeen(postID, postPrice)
        ns.AuctionSeenDone()
        postID, postPrice = nil, nil
    end
end

local function Apply()
    watching = On()
    if not watching then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if hooked then return end
    hooked = true
    hooksecurefunc(C_AuctionHouse, "PostItem", OnPostItem)
    hooksecurefunc(C_AuctionHouse, "PostCommodity", OnPostCommodity)
end

local function OnSettingChanged(key)
    if key == "ahPrices" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
if ns.MarketSettings then ns.MarketSettings.OnChange(Apply) end
Apply()
