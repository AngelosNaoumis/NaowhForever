-- History.lua: each item's lowest price per day and how many were listed, from your scans and the listings you see, two weeks of them per realm and faction, and the items whose price moved most between the last two days (Market.History).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C

local STORE = "marketHistory"
local PERCENT = 100
local ENTRY = "%d:%d"
local COUNTED = "%d:%d:%d"
local SEP = ","
local NO_COUNTS = {}

local movers = { dropped = {}, rose = {}, price = {}, change = {} }
local moversOf, moversAt, sorting
local averageOf, averageAt, averageItem, averageDays, average, averaged

local History = {}
Market.History = History

local function Day(when)
    return math.floor(when / C.SECONDS_PER_DAY)
end

local function House(create)
    local house = Market.HouseData(STORE, create)
    if house and not house.days then house.days = {} end
    if house and not house.listed then house.listed = {} end
    return house
end

local function Pack(day, listed)
    local parts = {}
    for id, price in pairs(day) do
        local count = listed and listed[id]
        parts[#parts + 1] = count and COUNTED:format(id, price, count) or ENTRY:format(id, price)
    end
    return SEP .. table.concat(parts, SEP) .. SEP
end

local function Price(house, d, itemID)
    local day = house.days[d]
    if type(day) == "table" then
        local listed = house.listed[d]
        return day[itemID], listed and listed[itemID]
    end
    if not day then return end
    local price, listed = day:match(SEP .. itemID .. ":(%d+):?(%d*)")
    return tonumber(price), tonumber(listed)
end

local function Today(house, at)
    house.at = at
    local today = Day(at)
    for d, day in pairs(house.days) do
        if d <= today - C.HISTORY_DAYS then
            house.days[d], house.listed[d] = nil, nil
        elseif d < today and type(day) == "table" then
            house.days[d], house.listed[d] = Pack(day, house.listed[d]), nil
        end
    end
    local day, listed = house.days[today] or {}, house.listed[today] or {}
    house.days[today], house.listed[today] = day, listed
    return day, listed
end

function History.Record()
    local list = ns.AuctionPriceList
    if not list then return false end
    local prices, at = list()
    if not (prices and at) then return false end
    local house = House(true)
    local last = house.recorded or house.at
    if last and last >= at or house.at and Day(at) < Day(house.at) then return false end
    house.recorded = at
    local day, listed = Today(house, math.max(at, house.at or 0))
    local Listed = ns.AuctionListed
    for id, price in pairs(prices) do
        if not day[id] or price < day[id] then day[id] = price end
        listed[id] = Listed and Listed(id) or listed[id]
    end
    return true
end

function History.Seen(ids, count)
    History.Record()
    local list = ns.AuctionPriceList
    local prices = list and list()
    if not prices then return end
    local house = House(true)
    house.recorded = house.recorded or house.at or 0
    local day, listed = Today(house, math.max(GetServerTime(), house.at or 0))
    local Listed = ns.AuctionListed
    for i = 1, count do
        local id = ids[i]
        local price = prices[id]
        if price and (not day[id] or price < day[id]) then day[id] = price end
        listed[id] = price and Listed and Listed(id) or listed[id]
    end
end

local function Latest(house, itemID)
    local today = Day(house.at)
    return (Price(house, today, itemID)), today
end

function History.Change(itemID, days)
    local house = House()
    if not (house and house.at) then return end
    local now, today = Latest(house, itemID)
    if not now then return end
    for back = days, 1, -1 do
        local past = Price(house, today - back, itemID)
        if past and past > 0 then return (now - past) / past * PERCENT, back end
    end
end

function History.Average(itemID, days)
    local house = House()
    if not (house and house.at) then return end
    if averageOf ~= house or averageAt ~= house.at or averageItem ~= itemID or averageDays ~= days then
        local today, sum, found = Day(house.at), 0, 0
        for back = 0, days - 1 do
            local price = Price(house, today - back, itemID)
            if price then sum, found = sum + price, found + 1 end
        end
        averageOf, averageAt, averageItem, averageDays = house, house.at, itemID, days
        average, averaged = found > 0 and math.floor(sum / found + 0.5) or nil, found
    end
    if averaged >= C.AVERAGE_MIN_DAYS then return average, averaged end
end

function History.Series(itemID, out, listed)
    wipe(out)
    if listed then wipe(listed) end
    local house = House()
    if not (house and house.at) then return out, 0 end
    local today, found = Day(house.at), 0
    for i = 1, C.HISTORY_DAYS do
        local price, count = Price(house, today - C.HISTORY_DAYS + i, itemID)
        out[i] = price or false
        if listed then listed[i] = count or false end
        if price then found = found + 1 end
    end
    return out, found, today
end

local function Unpack(house, d)
    local day = house.days[d]
    if type(day) == "table" then return day, house.listed[d] or NO_COUNTS end
    local prices, listed = {}, {}
    for id, price, count in day:gmatch("(%d+):(%d+):?(%d*)") do
        id = tonumber(id)
        prices[id], listed[id] = tonumber(price), tonumber(count)
    end
    return prices, listed
end

local function DayBefore(house, today)
    for back = 1, C.HISTORY_DAYS - 1 do
        if house.days[today - back] then return today - back end
    end
end

local function Thick(count)
    return not count or count >= C.MOVERS_MIN_LISTED
end

local function ByChange(a, b)
    if sorting[a] ~= sorting[b] then return sorting[a] < sorting[b] end
    return a < b
end

local function Keep(list, id, price, change)
    list[#list + 1] = id
    movers.price[id], movers.change[id] = price, change
end

local function FindMovers(house, today, before)
    local now, nowListed = Unpack(house, today)
    local past, pastListed = Unpack(house, before)
    local ids, changes = {}, {}
    for id, price in pairs(now) do
        local was = past[id]
        if was and was ~= price and math.min(was, price) >= C.MOVERS_MIN_PRICE and Thick(nowListed[id])
            and Thick(pastListed[id]) then
            ids[#ids + 1] = id
            changes[id] = (price - was) / was * PERCENT
        end
    end
    sorting = changes
    table.sort(ids, ByChange)
    sorting = nil
    for i = 1, math.min(C.MOVERS_TOP, #ids) do
        local id = ids[i]
        if changes[id] > 0 then break end
        Keep(movers.dropped, id, now[id], changes[id])
    end
    for i = #ids, math.max(1, #ids - C.MOVERS_TOP + 1), -1 do
        local id = ids[i]
        if changes[id] < 0 then break end
        Keep(movers.rose, id, now[id], changes[id])
    end
end

function History.Movers()
    local house = House()
    if not (house and house.at) then return end
    local today = Day(house.at)
    local before = DayBefore(house, today)
    if not before then return end
    if moversOf ~= house or moversAt ~= house.at then
        moversOf, moversAt = house, house.at
        wipe(movers.dropped)
        wipe(movers.rose)
        wipe(movers.price)
        wipe(movers.change)
        FindMovers(house, today, before)
    end
    return movers
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if Market.On() then History.Record() end
end)
