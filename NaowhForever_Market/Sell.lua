-- Sell.lua: the sell queue: what your bags can post, most valuable first, each one priced from its listings, and what you posted this visit (ns.Market.Sell).
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local Market = ns.Market
local S = Market.Settings
local C = Market.C
local Bags, Listings = Market.Bags, Market.Listings

local VENDOR_PRICE = 11
local GOLD = 10000
local ASK_CHEAP, ASK_DEAR = GOLD, 50 * GOLD
local ASK_SHARE_CHEAP, ASK_SHARE_MID, ASK_SHARE_DEAR = 0.7, 0.5, 0.3
local HIDDEN, FAVOURITES = "marketSellHidden", "marketSellFavourites"
local PERCENT = 100
local POSTS = "marketPosts"
local POSTS_KEEP, POSTS_ITEMS = 10, 500
local POST_SAME, POST_PARTS, POST_TIME = "%d:%d:%d:", "^(%d+):(%d+):(%d+):(%d+)$", "(%d+)$"
local FIXED_UNDERCUTS = { silver = true, amount = true }
local DEFAULT_MULTIPLIER = Constants.AuctionConstants.DEFAULT_AUCTION_PRICE_MULTIPLIER
local CLASS_INDEX = 6
local QUANTITY_TYPES = {
    [Enum.ItemClass.Tradegoods] = { quantity = "sellQuantityTrade", number = "sellNumberTrade" },
    [Enum.ItemClass.Consumable] = { quantity = "sellQuantityConsumable", number = "sellNumberConsumable" },
    [Enum.ItemClass.Recipe] = { quantity = "sellQuantityRecipe", number = "sellNumberRecipe" },
}
local QUANTITY_OTHER = { quantity = "sellQuantityOther", number = "sellNumberOther" }

local queue, posted, postedOrder = {}, {}, {}
local priceSet, quantitySet, bidSet = {}, {}, {}
local postedTotal = 0
local focusKey

local Sell = { queue = queue, postedOrder = postedOrder }
Market.Sell = Sell

local function ScanPrice(itemID)
    return (ns.AuctionPrice and ns.AuctionPrice(itemID))
end

local function Rank(entry)
    if entry.hidden then return 5 end
    if entry.vendorBetter then return 4 end
    if entry.favourite then return 1 end
    return entry.scan and 2 or 3
end

local function Posts(entry)
    return not entry.vendorBetter and not entry.hidden
end

local function Marked(store, itemID)
    local marks = ns.AccountSettings()[store]
    return marks ~= nil and marks[itemID] == true
end

local function Mark(store, itemID, on)
    local account = ns.AccountSettings()
    if not account[store] then
        if not on then return end
        account[store] = {}
    end
    account[store][itemID] = on or nil
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

local function Step(entry)
    return Sell.Copper(entry) and 1 or C.SILVER
end

local function Floor(entry, price)
    local step = Step(entry)
    return math.max(step, math.floor(price / step) * step)
end

local function Undercut(entry, price)
    local undercut = S.Get("undercut")
    if undercut == "match" then return 0 end
    if undercut == "silver" then return C.SILVER end
    if undercut == "amount" then return S.Get("undercutAmount") end
    if undercut == "percent" then
        return math.max(Step(entry), math.floor(price * S.Get("undercutPercent") / PERCENT))
    end
    return Step(entry)
end

local function AskShare(going)
    if going < ASK_CHEAP then return ASK_SHARE_CHEAP end
    if going < ASK_DEAR then return ASK_SHARE_MID end
    return ASK_SHARE_DEAR
end

local function TrimPosts(posts)
    local count, oldest, oldestAt = 0
    for itemID, list in pairs(posts) do
        count = count + 1
        local at = tonumber(list[1]:match(POST_TIME))
        if not oldestAt or at < oldestAt then oldest, oldestAt = itemID, at end
    end
    if count > POSTS_ITEMS then posts[oldest] = nil end
end

local function Record(itemID, quantity, price, duration)
    local posts = Market.HouseData(POSTS, true)
    local list = posts[itemID]
    if not list then
        list = {}
        posts[itemID] = list
    end
    local known = #list > 0
    local same = POST_SAME:format(price, quantity, duration)
    for i = #list, 1, -1 do
        if list[i]:sub(1, #same) == same then table.remove(list, i) end
    end
    table.insert(list, 1, same .. time())
    list[POSTS_KEEP + 1] = nil
    if not known then TrimPosts(posts) end
end

local function QuantityClass(entry)
    local class = select(CLASS_INDEX, C_Item.GetItemInfoInstant(entry.itemID))
    return QUANTITY_TYPES[class or false] and class or nil
end

local function QuantityType(entry)
    return QUANTITY_TYPES[QuantityClass(entry) or false] or QUANTITY_OTHER
end

local function Default(entry)
    return Floor(entry, entry.vendor * DEFAULT_MULTIPLIER)
end

function Sell.Copper(entry)
    return entry.commodity and C_AuctionHouse.SupportsCopperValues()
end

function Sell.Read()
    local entries, loading = Bags.Read()
    wipe(queue)
    for _, entry in ipairs(entries) do
        entry.scan = ScanPrice(entry.itemID)
        entry.vendor = select(VENDOR_PRICE, GetItemInfo(entry.link)) or 0
        entry.vendorBetter = entry.scan ~= nil and entry.vendor > 0 and entry.vendor >= Market.AfterCut(entry.scan)
        entry.worth = entry.vendorBetter and entry.vendor * entry.count or Value(entry)
        entry.hidden, entry.favourite = Marked(HIDDEN, entry.itemID), Marked(FAVOURITES, entry.itemID)
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
        if Posts(entry) and entry.key ~= focusKey then return Sell.Pick(entry.key) end
    end
    if not Sell.Focus() then Sell.Pick(nil) end
end

function Sell.Hidden(itemID)
    return Marked(HIDDEN, itemID)
end

function Sell.Favourite(itemID)
    return Marked(FAVOURITES, itemID)
end

function Sell.SetHidden(itemID, on)
    Mark(HIDDEN, itemID, on)
    if on then Mark(FAVOURITES, itemID, false) end
end

function Sell.SetFavourite(itemID, on)
    Mark(FAVOURITES, itemID, on)
    if on then Mark(HIDDEN, itemID, false) end
end

function Sell.Resume()
    local focus = Sell.Focus()
    if focus then return Listings.Want(focus) end
    Sell.Keep()
end

function Sell.Keep()
    if Sell.Focus() then return end
    for _, entry in ipairs(queue) do
        if Posts(entry) then return Sell.Pick(entry.key) end
    end
    Sell.Pick(nil)
end

function Sell.Suggest(entry)
    local other, own = Listings.Cheapest()
    if other and not (own and own <= other) then
        local price = Floor(entry, other - Undercut(entry, other))
        return price, price < other and "under" or "match", other
    end
    if own then return own, "yours", own end
    if entry.scan then return Floor(entry, entry.scan), "scan", entry.scan end
    return Default(entry), "vendor", entry.vendor
end

function Sell.Price(entry)
    local set = priceSet[entry.key]
    if set then return set, "hand" end
    return Sell.Suggest(entry)
end

function Sell.Risk(entry, price)
    if not S.Get("askBadPost") then return end
    if entry.vendor > 0 and entry.vendor >= Market.AfterCut(price) then return "vendor", entry.vendor end
    local other = Listings.Cheapest()
    local going = other or entry.scan
    if not going or price >= (Sell.Suggest(entry)) and not FIXED_UNDERCUTS[S.Get("undercut")] then return end
    if price < going * AskShare(going) then return other and "listing" or "scan", going end
end

function Sell.SetPrice(key, price)
    priceSet[key] = price > 0 and price or nil
end

function Sell.TakePrice(entry, price)
    priceSet[entry.key] = Floor(entry, price)
end

function Sell.StepPrice(entry, up)
    local price = Sell.Price(entry)
    local best
    for i = 1, Listings.count do
        local row = Listings.rows[i]
        local rung = Floor(entry, row.price - Undercut(entry, row.price))
        if row.quantity > row.own and (up and rung > price or not up and rung < price) then
            if not best or (up and rung < best) or (not up and rung > best) then best = rung end
        end
    end
    if best then priceSet[entry.key] = best end
    return best ~= nil
end

function Sell.PriceAt(entry, i)
    local row = Listings.rows[i]
    priceSet[entry.key] = row.quantity > row.own and Floor(entry, row.price - Undercut(entry, row.price)) or row.price
end

function Sell.QuantityClass(entry)
    return QuantityClass(entry)
end

function Sell.DefaultQuantity(entry)
    return S.Get(QuantityType(entry).quantity)
end

function Sell.SetDefaultQuantity(entry, quantity)
    S.Set(QuantityType(entry).quantity, quantity)
    quantitySet[entry.key] = nil
end

function Sell.QuantityNumber(entry)
    return S.Get(QuantityType(entry).number)
end

function Sell.SetQuantityNumber(entry, number)
    S.Set(QuantityType(entry).number, number)
    Sell.SetDefaultQuantity(entry, number)
end

function Sell.QuantityTyped(entry)
    return quantitySet[entry.key] ~= nil
end

function Sell.Quantity(entry)
    local quantity = quantitySet[entry.key] or Sell.DefaultQuantity(entry)
    if quantity == 0 then quantity = entry.count end
    return math.min(quantity, entry.count)
end

function Sell.SetQuantity(key, quantity)
    quantitySet[key] = quantity
end

function Sell.Bid(entry)
    if entry.commodity or not S.Get("startingBid") then return end
    return bidSet[entry.key]
end

function Sell.SetBid(key, bid)
    bidSet[key] = bid > 0 and bid or nil
end

function Sell.BidFits(entry)
    local bid = Sell.Bid(entry)
    return bid == nil or bid < (Sell.Price(entry))
end

function Sell.Duration()
    return S.Get("duration")
end

function Sell.PastCount(itemID)
    local posts = Market.HouseData(POSTS)
    return posts and posts[itemID] and #posts[itemID] or 0
end

function Sell.Past(itemID, i)
    local posts = Market.HouseData(POSTS)
    local post = posts and posts[itemID] and posts[itemID][i]
    if not post then return end
    local price, quantity, duration, at = post:match(POST_PARTS)
    return tonumber(price), tonumber(quantity), tonumber(duration), tonumber(at)
end

function Sell.Posted(key, quantity, price, itemID, duration)
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
    if itemID then Record(itemID, quantity, price, duration) end
    priceSet[key], quantitySet[key], bidSet[key] = nil, nil, nil
end

function Sell.Totals()
    local left = 0
    for _, entry in ipairs(queue) do
        if Posts(entry) then left = left + Value(entry) end
    end
    return postedTotal, postedTotal + left
end

function Sell.Left()
    local count = 0
    for _, entry in ipairs(queue) do
        if Posts(entry) then count = count + 1 end
    end
    return count
end

function Sell.Reset()
    wipe(posted)
    wipe(postedOrder)
    wipe(priceSet)
    wipe(quantitySet)
    wipe(bidSet)
    postedTotal, focusKey = 0, nil
end
