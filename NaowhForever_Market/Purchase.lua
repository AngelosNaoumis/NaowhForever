-- Purchase.lua: buying a listing from a click: an item at its buyout, a commodity at the price the game quotes, and the game's answer (ns.Market.Purchase).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local EVENTS = { "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED",
    "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR" }
local QUOTE_STATES = { quoting = true, quoted = true }

local buy = {}
local events
local gen = 0

local Purchase = {}
Market.Purchase = Purchase

local function End()
    if buy.itemID then C_AuctionHouse.CancelCommoditiesPurchase() end
    buy.state = nil
    gen = gen + 1
    events:UnregisterAllEvents()
end

local function Done(ok)
    if not buy.state then return end
    End()
    if Purchase.onDone then Purchase.onDone(ok, buy.quantity) end
end

local function TimedOut(buyGen)
    if buyGen == gen then Done(false) end
end

local function Begin(state)
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Purchase.OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    buy.state = state
    gen = gen + 1
    local buyGen = gen
    C_Timer.After(C.BUY_TIMEOUT, function() TimedOut(buyGen) end)
end

function Purchase.OnEvent(_, event, a, b)
    local state = buy.state
    if event == "COMMODITY_PRICE_UPDATED" then
        if not QUOTE_STATES[state] then return end
        buy.state = "quoted"
        gen = gen + 1
        if Purchase.onQuote then Purchase.onQuote(buy.itemID, buy.quantity, b) end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if state == "buying" and buy.itemID then Done(true) end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if state == "buying" and a == buy.auctionID then Done(true) end
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if state == "buying" then Done(false) end
    elseif buy.itemID then
        Done(false)
    end
end

function Purchase.Busy()
    return buy.state ~= nil
end

function Purchase.Quote(itemID, quantity)
    if buy.state then return false end
    buy.itemID, buy.quantity, buy.auctionID = itemID, quantity, nil
    Begin("quoting")
    C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
    return true
end

function Purchase.Confirm()
    if buy.state ~= "quoted" then return false end
    Begin("buying")
    C_AuctionHouse.ConfirmCommoditiesPurchase(buy.itemID, buy.quantity)
    return true
end

function Purchase.Item(auctionID, price)
    if buy.state then return false end
    buy.itemID, buy.quantity, buy.auctionID = nil, 1, auctionID
    Begin("buying")
    C_AuctionHouse.PlaceBid(auctionID, price)
    return true
end

function Purchase.Drop()
    if buy.state then End() end
end
