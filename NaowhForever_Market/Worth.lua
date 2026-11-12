-- Worth.lua: what everything in your bags would fetch at your last scan, the most valuable of it, and the best way to sell an item (Market.Worth).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemInfo = C_Item.GetItemInfo

local Market = ns.Market
local S = Market.Settings
local C = Market.C

local FIRST_BAG = 0
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local VENDOR_PRICE = 11
local OUTLETS = { "vendor", "auction", "disenchant" }

local items, byID, spare, ranks = {}, {}, {}, {}
local offers, scores = {}, {}

local Worth = { items = items, total = 0, auction = 0 }
Market.Worth = Worth

local function Each(item, itemID, bound)
    local vendor = select(VENDOR_PRICE, GetItemInfo(item)) or 0
    local scan = not bound and ns.AuctionPrice and ns.AuctionPrice(itemID)
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
    entry.each, entry.auction = Each(info.hyperlink, info.itemID, info.isBound)
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

function Worth.Each(itemID, bound)
    return (Each(itemID, itemID, bound))
end

function Worth.Rank(itemID)
    return itemID and ranks[itemID]
end

function Worth.First(itemID, bag, slot)
    local entry = byID[itemID]
    return entry ~= nil and entry.bag == bag and entry.slot == slot
end

function Worth.Best(vendor, auction, disenchant)
    offers.vendor, offers.auction, offers.disenchant = vendor, auction, disenchant
    scores.vendor, scores.auction, scores.disenchant = vendor, auction, disenchant
    if vendor and vendor > 0 and auction and auction > vendor and auction - vendor <= S.Get("tooltipBestMargin") then
        scores.auction = vendor
    end
    local best, second, complete = nil, nil, true
    for _, outlet in ipairs(OUTLETS) do
        local value = scores[outlet]
        if value == nil then
            complete = false
        elseif value and value > 0 then
            if not best or value > scores[best] then
                best, second = outlet, best
            elseif not second or value > scores[second] then
                second = outlet
            end
        end
    end
    if not second then return end
    return best, offers[best] - offers[second], second, complete
end
