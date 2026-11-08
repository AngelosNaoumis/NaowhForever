-- Worth.lua: what everything in your bags would fetch at your last scan, and the most valuable of it (Market.Worth).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemInfo = C_Item.GetItemInfo

local Market = ns.Market
local C = Market.C

local FIRST_BAG = 0
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local VENDOR_PRICE = 11

local items, byID, spare, ranks = {}, {}, {}, {}

local Worth = { items = items, total = 0, auction = 0 }
Market.Worth = Worth

local function Each(info)
    local vendor = select(VENDOR_PRICE, GetItemInfo(info.hyperlink)) or 0
    local scan = not info.isBound and ns.AuctionPrice and ns.AuctionPrice(info.itemID)
    local net = scan and Market.AfterCut(scan)
    if net and net > vendor then return net, true end
    return vendor, false
end

local function Entry(info, bag, slot)
    local entry = byID[info.itemID]
    if entry then return entry end
    entry = table.remove(spare) or {}
    entry.itemID, entry.link, entry.icon, entry.quality = info.itemID, info.hyperlink, info.iconFileID, info.quality
    entry.bag, entry.slot, entry.count, entry.worth = bag, slot, 0, 0
    entry.each, entry.auction = Each(info)
    byID[info.itemID] = entry
    items[#items + 1] = entry
    return entry
end

local function Richer(a, b)
    if a.worth ~= b.worth then return a.worth > b.worth end
    return a.itemID < b.itemID
end

function Worth.Read()
    for i = #items, 1, -1 do
        byID[items[i].itemID] = nil
        spare[#spare + 1] = items[i]
        items[i] = nil
    end
    wipe(ranks)
    local total, auction = 0, 0
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info and not info.hasNoValue then
                local entry = Entry(info, bag, slot)
                local worth = entry.each * info.stackCount
                entry.count, entry.worth = entry.count + info.stackCount, entry.worth + worth
                total = total + worth
                if entry.auction then auction = auction + worth end
            end
        end
    end
    for i = #items, 1, -1 do
        if items[i].worth == 0 then
            byID[items[i].itemID] = nil
            spare[#spare + 1] = table.remove(items, i)
        end
    end
    table.sort(items, Richer)
    for i = 1, math.min(C.WORTH_TOP, #items) do ranks[items[i].itemID] = i end
    Worth.total, Worth.auction = total, auction
    return items
end

function Worth.Rank(itemID)
    return itemID and ranks[itemID]
end

function Worth.First(itemID, bag, slot)
    local entry = byID[itemID]
    return entry ~= nil and entry.bag == bag and entry.slot == slot
end
