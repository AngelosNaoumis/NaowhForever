-- Sales.lua: what you sold, noted from your sold auctions whenever the auction house is open, per realm and faction (Market.Sales).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local STORE = "marketSales"
local SOLD = Enum.AuctionStatus.Sold
local OWNED_SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } }
local EVENTS = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "OWNED_AUCTIONS_UPDATED" }
local SEEN_KEY = "%d:%d"

local events
local wanted = false

local Sales = {}
Market.Sales = Sales

local function House(create)
    local house = Market.HouseData(STORE, create)
    if house and not house.list then house.list, house.seen, house.latest = {}, {}, {} end
    return house
end

local function Trim(house, now)
    local oldest = now - C.SALES_DAYS * C.SECONDS_PER_DAY
    while #house.list > C.SALES_KEEP or (house.list[#house.list] and house.list[#house.list].at < oldest) do
        table.remove(house.list)
    end
    local forget = now - C.SALE_SEEN_SECONDS
    for key, at in pairs(house.seen) do
        if at < forget then house.seen[key] = nil end
    end
end

function Sales.Note(auctionID, itemID, quantity, price, secondsLeft)
    if not (auctionID and quantity and price and price > 0) then return false end
    local house = House(true)
    local key = SEEN_KEY:format(auctionID, quantity)
    local now = time()
    if house.seen[key] then return false end
    house.seen[key] = now
    local left = secondsLeft and secondsLeft >= 0 and secondsLeft <= C.SALE_DELIVERY and secondsLeft or C.SALE_DELIVERY
    local sale = { item = itemID, qty = quantity, price = price, at = now - (C.SALE_DELIVERY - left) }
    table.insert(house.list, 1, sale)
    house.latest[itemID] = sale
    Trim(house, now)
    return true
end

function Sales.Since(seconds)
    local house = House()
    local total, count, from = 0, 0, time() - seconds
    for _, sale in ipairs(house and house.list or {}) do
        if sale.at >= from then
            total, count = total + Market.AfterCut(sale.price * sale.qty), count + 1
        end
    end
    return total, count
end

function Sales.Last(itemID)
    local house = House()
    return house and house.latest[itemID]
end

local function Read()
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info and info.status == SOLD then
            Sales.Note(info.auctionID, info.itemKey.itemID, info.quantity, info.buyoutAmount or info.bidAmount,
                info.timeLeftSeconds)
        end
    end
end

local function Ask()
    if not wanted or not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    wanted = false
    C_AuctionHouse.QueryOwnedAuctions(OWNED_SORTS)
end

local function OnEvent(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        wanted = true
        Ask()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        wanted = false
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        Read()
    else
        Ask()
    end
end

local function Apply()
    local on = Market.On()
    if on and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    if not events then return end
    if not on then return events:UnregisterAllEvents() end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

Market.Settings.OnChange(function(key)
    if key == "enabled" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
