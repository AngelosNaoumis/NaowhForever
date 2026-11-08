-- History.lua: each item's lowest price per day from your scans, two weeks of them per realm and faction (Market.History).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local STORE = "marketHistory"
local PERCENT = 100
local ENTRY = "%d:%d"
local SEP = ","

local History = {}
Market.History = History

local function Day(when)
    return math.floor(when / C.SECONDS_PER_DAY)
end

local function House(create)
    local house = Market.HouseData(STORE, create)
    if house and not house.days then house.days = {} end
    return house
end

local function Pack(day)
    local parts = {}
    for id, price in pairs(day) do parts[#parts + 1] = ENTRY:format(id, price) end
    return SEP .. table.concat(parts, SEP) .. SEP
end

local function Price(day, itemID)
    if type(day) == "table" then return day[itemID] end
    if day then return tonumber(day:match(SEP .. itemID .. ":(%d+)" .. SEP)) end
end

function History.Record()
    local list = ns.AuctionPriceList
    if not list then return false end
    local prices, at = list()
    if not (prices and at) then return false end
    local house = House(true)
    if house.at and house.at >= at then return false end
    house.at = at
    local today = Day(at)
    for d, day in pairs(house.days) do
        if d <= today - C.HISTORY_DAYS then
            house.days[d] = nil
        elseif d < today and type(day) == "table" then
            house.days[d] = Pack(day)
        end
    end
    local day = house.days[today] or {}
    house.days[today] = day
    for id, price in pairs(prices) do
        if not day[id] or price < day[id] then day[id] = price end
    end
    return true
end

local function Latest(house, itemID)
    local today = Day(house.at)
    return Price(house.days[today], itemID), today
end

function History.Change(itemID, days)
    local house = House()
    if not (house and house.at) then return end
    local now, today = Latest(house, itemID)
    if not now then return end
    for back = days, 1, -1 do
        local past = Price(house.days[today - back], itemID)
        if past and past > 0 then return (now - past) / past * PERCENT, back end
    end
end

function History.Series(itemID, out)
    wipe(out)
    local house = House()
    if not (house and house.at) then return out, 0 end
    local today, found = Day(house.at), 0
    for i = 1, C.HISTORY_DAYS do
        local price = Price(house.days[today - C.HISTORY_DAYS + i], itemID)
        out[i] = price or false
        if price then found = found + 1 end
    end
    return out, found
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if Market.On() then History.Record() end
end)
