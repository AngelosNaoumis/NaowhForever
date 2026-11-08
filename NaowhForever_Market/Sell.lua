-- Sell.lua: the sell queue: what your bags can post, most valuable first, each one priced from its listings, and what you posted this visit (ns.Market.Sell).
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local Market = ns.Market
local S = Market.Settings
local C = Market.C
local Bags, Listings = Market.Bags, Market.Listings

local VENDOR_PRICE = 11
local DEFAULT_MULTIPLIER = Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER

local queue, posted, postedOrder = {}, {}, {}
local priceSet, quantitySet = {}, {}
local postedTotal = 0
local focusKey

local Sell = { queue = queue, postedOrder = postedOrder }
Market.Sell = Sell

local function ScanPrice(itemID)
    return (ns.AuctionPrice and ns.AuctionPrice(itemID))
end

local function Rank(entry)
    if entry.vendorBetter then return 3 end
    return entry.scan and 1 or 2
end

local function Before(a, b)
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    if a.worth ~= b.worth then return a.worth > b.worth end
    return a.itemID < b.itemID
end

local function Value(entry)
    local each = priceSet[entry.key] or entry.scan
    return each and each * entry.count or 0
end

local function Step()
    return C_AuctionHouse.SupportsCopperValues() and 1 or C.SILVER
end

local function Floor(price)
    local step = Step()
    return math.max(step, math.floor(price / step) * step)
end

local function Default(entry)
    local price = entry.vendor * DEFAULT_MULTIPLIER
    return math.max(C.SILVER, math.ceil(price / C.SILVER) * C.SILVER)
end

local function Cheapest()
    local other, own
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        if not own and row.own > 0 then own = row.price end
        if not other and row.quantity > row.own then other = row.price end
        if other and own then break end
    end
    return other, own
end

function Sell.Read()
    local entries, loading = Bags.Read()
    wipe(queue)
    for _, entry in ipairs(entries) do
        entry.scan = ScanPrice(entry.itemID)
        entry.vendor = select(VENDOR_PRICE, GetItemInfo(entry.link)) or 0
        entry.vendorBetter = entry.scan ~= nil and entry.vendor > 0 and entry.vendor >= entry.scan * (1 - C.AH_CUT)
        entry.worth = entry.vendorBetter and entry.vendor * entry.count or Value(entry)
        queue[#queue + 1] = entry
    end
    table.sort(queue, Before)
    return loading
end

function Sell.Focus()
    return Bags.Get(focusKey)
end

function Sell.Pick(key)
    focusKey = key
    Listings.Want(Bags.Get(key))
end

function Sell.Next()
    local start = 0
    for i, entry in ipairs(queue) do
        if entry.key == focusKey then start = i end
    end
    for k = 1, #queue do
        local entry = queue[(start + k - 1) % #queue + 1]
        if not entry.vendorBetter and entry.key ~= focusKey then return Sell.Pick(entry.key) end
    end
    if not Sell.Focus() then Sell.Pick(nil) end
end

function Sell.Resume()
    local focus = Sell.Focus()
    if focus then return Listings.Want(focus) end
    Sell.Keep()
end

function Sell.Keep()
    if Sell.Focus() then return end
    for _, entry in ipairs(queue) do
        if not entry.vendorBetter then return Sell.Pick(entry.key) end
    end
    Sell.Pick(nil)
end

function Sell.Suggest(entry)
    local other, own = Cheapest()
    if other and not (own and own <= other) then return Floor(other - Step()), "under", other end
    if own then return own, "yours", own end
    if entry.scan then return Floor(entry.scan), "scan", entry.scan end
    return Default(entry), "vendor", entry.vendor
end

function Sell.Price(entry)
    local set = priceSet[entry.key]
    if set then return set, "hand" end
    return Sell.Suggest(entry)
end

function Sell.SetPrice(key, price)
    priceSet[key] = price > 0 and price or nil
end

function Sell.StepPrice(entry, up)
    local price, step = Sell.Price(entry), Step()
    local best
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        local rung = Floor(row.price - step)
        if row.quantity > row.own and (up and rung > price or not up and rung < price) then
            if not best or (up and rung < best) or (not up and rung > best) then best = rung end
        end
    end
    if best then priceSet[entry.key] = best end
    return best ~= nil
end

function Sell.Quantity(entry)
    return math.min(quantitySet[entry.key] or entry.count, entry.count)
end

function Sell.SetQuantity(key, quantity)
    quantitySet[key] = quantity
end

function Sell.Duration()
    return S.Get("duration")
end

function Sell.Posted(key, quantity, price)
    local entry = Bags.Get(key)
    local done = posted[key]
    if not done then
        done = { key = key }
        posted[key] = done
        postedOrder[#postedOrder + 1] = done
    end
    if entry then done.itemID, done.link, done.icon = entry.itemID, entry.link, entry.icon end
    done.quantity, done.price = (done.quantity or 0) + quantity, price
    postedTotal = postedTotal + quantity * price
    priceSet[key], quantitySet[key] = nil, nil
end

function Sell.Totals()
    local left = 0
    for _, entry in ipairs(queue) do
        if not entry.vendorBetter then left = left + Value(entry) end
    end
    return postedTotal, postedTotal + left
end

function Sell.Left()
    local count = 0
    for _, entry in ipairs(queue) do
        if not entry.vendorBetter then count = count + 1 end
    end
    return count
end

function Sell.Reset()
    wipe(posted)
    wipe(postedOrder)
    wipe(priceSet)
    wipe(quantitySet)
    postedTotal, focusKey = 0, nil
end
