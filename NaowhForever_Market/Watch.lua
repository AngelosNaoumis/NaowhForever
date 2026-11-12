-- Watch.lua: the items you watch for a price, and the chat line when one is at or under it (Market.Watch).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Items = ns.Shared.Items

local STORE = "marketWatch"
local MAX_ITEMS = 100
local NONE = {}
local TEXT_ALERT = ns.L("Watch List: %s is %s, at or under your %s.")

local told = {}
local names = {}

local Watch = { MAX = MAX_ITEMS }
Market.Watch = Watch

local function List(create)
    local account = ns.AccountSettings()
    if not account[STORE] and create then account[STORE] = {} end
    return account[STORE]
end

local function Lowest(itemID)
    return ns.AuctionPrice and ns.AuctionPrice(itemID)
end

local function Link(itemID)
    return select(2, C_Item.GetItemInfo(itemID)) or Items.Name(itemID)
end

local function Tell(itemID, price, target)
    ns.Print(TEXT_ALERT:format(Link(itemID), ns.Shared.Parts.Coins(price), ns.Shared.Parts.Coins(target)))
end

local function UnderFirst(a, b)
    local au, bu = Watch.Under(a), Watch.Under(b)
    if au ~= bu then return au end
    return names[a] < names[b]
end

function Watch.Target(itemID)
    local list = List()
    return list and list[itemID]
end

function Watch.Count()
    local n = 0
    for _ in pairs(List() or NONE) do n = n + 1 end
    return n
end

function Watch.Set(itemID, target)
    if not (itemID and target and target > 0) then return false end
    local list = List(true)
    if not list[itemID] and Watch.Count() >= MAX_ITEMS then return false end
    list[itemID] = target
    told[itemID] = nil
    return true
end

function Watch.Remove(itemID)
    local list = List()
    if list then list[itemID] = nil end
    told[itemID] = nil
end

function Watch.Under(itemID)
    local target = Watch.Target(itemID)
    local price = Lowest(itemID)
    return target ~= nil and price ~= nil and price <= target
end

function Watch.UnderCount()
    local n = 0
    for id in pairs(List() or NONE) do
        if Watch.Under(id) then n = n + 1 end
    end
    return n
end

function Watch.Items(out)
    wipe(out)
    wipe(names)
    for id in pairs(List() or NONE) do
        out[#out + 1] = id
        names[id] = Items.Name(id)
    end
    table.sort(out, UnderFirst)
    return out
end

function Watch.Scanned()
    if not S.Get("watchAlerts") then return 0 end
    local n = 0
    for id, target in pairs(List() or NONE) do
        local price = Lowest(id)
        if price and price <= target then
            Tell(id, price, target)
            n = n + 1
        end
    end
    return n
end

function Watch.Listed(itemID, price)
    local target = itemID and Watch.Target(itemID)
    if not (target and price and price <= target and S.Get("watchAlerts")) then return false end
    if told[itemID] == price then return false end
    told[itemID] = price
    Tell(itemID, price, target)
    return true
end
