-- Bags.lua: what in your bags the auction house takes, one entry per item (ns.Market.Bags).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo

local Market = ns.Market

local FIRST_BAG = 0
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local COMMODITY = Enum.ItemCommodityStatus.Commodity
local UNKNOWN = Enum.ItemCommodityStatus.Unknown

local entries, byKey, spare = {}, {}, {}
local here = ItemLocation:CreateEmpty()
local loading

local Bags = { entries = entries }
Market.Bags = Bags

local function Entry(key)
    local entry = byKey[key]
    if entry then return entry end
    entry = table.remove(spare) or {}
    entry.key, entry.count = key, 0
    byKey[key] = entry
    entries[#entries + 1] = entry
    return entry
end

local function AddSlot(bag, slot, info)
    here:SetBagAndSlot(bag, slot)
    if not C_AuctionHouse.IsSellItemValid(here, false) then return end
    local status = C_AuctionHouse.GetItemCommodityStatus(here)
    if status == UNKNOWN then
        loading = true
        C_Item.RequestLoadItemData(here)
        return
    end
    local commodity = status == COMMODITY
    local entry = Entry(commodity and info.itemID or info.hyperlink)
    if entry.count == 0 then
        entry.itemID, entry.link, entry.icon, entry.quality = info.itemID, info.hyperlink, info.iconFileID, info.quality
        entry.commodity, entry.bag, entry.slot = commodity, bag, slot
    end
    entry.count = entry.count + info.stackCount
end

local function Holds(entry, info)
    return info and info.itemID == entry.itemID and not info.isLocked
        and (entry.commodity or info.hyperlink == entry.link)
end

local function Find(entry)
    if Holds(entry, GetContainerItemInfo(entry.bag, entry.slot)) then return entry.bag, entry.slot end
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            if Holds(entry, GetContainerItemInfo(bag, slot)) then return bag, slot end
        end
    end
end

function Bags.Read()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        byKey[entry.key] = nil
        entries[i] = nil
        spare[#spare + 1] = entry
    end
    loading = false
    for bag = FIRST_BAG, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info and not info.isBound then AddSlot(bag, slot, info) end
        end
    end
    return entries, loading
end

function Bags.Get(key)
    return key and byKey[key]
end

function Bags.KeyAt(location)
    if not (location and location:IsValid()) then return end
    local key = C_AuctionHouse.GetItemCommodityStatus(location) == COMMODITY and C_Item.GetItemID(location)
    return key or C_Item.GetItemLink(location)
end

function Bags.Location(entry, keep)
    local bag, slot = Find(entry)
    if not bag then return end
    if keep then return ItemLocation:CreateFromBagAndSlot(bag, slot) end
    here:SetBagAndSlot(bag, slot)
    return here
end
