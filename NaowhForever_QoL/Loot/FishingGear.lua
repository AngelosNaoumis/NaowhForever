-- FishingGear.lua: the fishing gear One-Key Fishing puts on first, and putting back what it replaced (ns.FishingGear).
local ns = _G.NaowhForever

local S = ns.QoLSettings

local FIRST_SLOT, LAST_SLOT = 1, 19
local MAIN_HAND, OFF_HAND = 16, 17
local POLE_SLOTS = { [MAIN_HAND] = true, [OFF_HAND] = true }
local WEAPON_SLOTS = { [MAIN_HAND] = true, [OFF_HAND] = true, [18] = true }
local SET_EQUIPPED = 4
local ITEM = "item:%d"
local SAVED = "fishingReturn"
local KEYS = { enabled = true, fishingKey = true, fishingGear = true }
local TEXT_BEST_POLE = ns.L("Your Best Fishing Pole")
local TEXT_NOTHING = ns.L("No fishing gear to put back.")
local TEXT_AFTER_COMBAT = ns.L("Your gear goes back when combat ends.")
local TEXT_MISSING = ns.L("%s is not in your bags, so it was not put back.")

local events, afterCombat, asked, dressing, returning

local function On()
    return S.Get("enabled") and S.Get("fishingKey") and S.Get("fishingGear")
end

local function IsPole(id)
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    return class == Enum.ItemClass.Weapon and subclass == Enum.ItemWeaponSubclass.Fishingpole
end

local function PoleWorn()
    local id = GetInventoryItemID("player", MAIN_HAND)
    return id ~= nil and IsPole(id)
end

local function Store(create)
    local account = ns.AccountSettings()
    if create and not account[SAVED] then account[SAVED] = {} end
    return account[SAVED], UnitGUID("player")
end

local function Kept()
    local store, key = Store()
    return store and store[key]
end

local function Forget()
    local store, key = Store()
    if store then store[key] = nil end
    dressing, returning = false, false
end

local function SetID()
    local name = S.Get("fishingGearSet")
    if name == "" then return end
    return C_EquipmentSet.GetEquipmentSetID(name)
end

local function BestPole()
    local best, bestLevel
    local myLevel = UnitLevel("player")
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and IsPole(id) then
                local _, _, _, level, needs = C_Item.GetItemInfo(id)
                level = level or 0
                if (needs or 0) <= myLevel and (not best or level > bestLevel) then best, bestLevel = id, level end
            end
        end
    end
    return best
end

local function PutBack(weaponsOnly)
    if InCombatLockdown() then return end
    local kept = Kept()
    if not kept then return end
    for slot = FIRST_SLOT, LAST_SLOT do
        local link = kept[slot]
        if link ~= nil and (not weaponsOnly or WEAPON_SLOTS[slot]) then
            if not link or GetInventoryItemLink("player", slot) == link then
                kept[slot] = nil
            elseif C_Item.GetItemCount(link) == 0 then
                kept[slot] = nil
                ns.Print(TEXT_MISSING:format(link))
            else
                C_Item.EquipItemByName(link, slot)
            end
        end
    end
    if next(kept) == nil then Forget() end
end

local function OnEquipmentChanged(slot)
    asked = false
    local kept = Kept()
    if not kept then return end
    if PoleWorn() then
        dressing = false
    elseif slot == MAIN_HAND and not (dressing or returning or afterCombat) then
        return Forget()
    end
    if kept[slot] and GetInventoryItemLink("player", slot) == kept[slot] then kept[slot] = nil end
    if next(kept) == nil then Forget() end
end

local Listen

local function OnEvent(_, event, slot)
    if event == "BAG_UPDATE_DELAYED" then
        asked = false
        return
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        OnEquipmentChanged(slot)
    elseif event == "PLAYER_REGEN_DISABLED" then
        PutBack(true)
        afterCombat = Kept() ~= nil
    elseif afterCombat then
        afterCombat, returning = false, Kept() ~= nil
        PutBack(false)
    end
    Listen()
end

function Listen()
    local kept = Kept() ~= nil
    if not (On() or kept or afterCombat) then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:UnregisterAllEvents()
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    if On() then events:RegisterEvent("BAG_UPDATE_DELAYED") end
    if kept or afterCombat then
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local Gear = {}
ns.FishingGear = Gear

Gear.PoleWorn = PoleWorn

function Gear.Next()
    if not S.Get("fishingGear") or asked then return end
    local set = SetID()
    if set then
        if select(SET_EQUIPPED, C_EquipmentSet.GetEquipmentSetInfo(set)) or (Kept() and PoleWorn()) then return end
        return "equipmentset", S.Get("fishingGearSet")
    end
    if PoleWorn() then return end
    local pole = BestPole()
    if pole then return "item", ITEM:format(pole) end
end

function Gear.Note()
    asked = true
    local store, key = Store(true)
    if store[key] then return end
    local set = SetID()
    local ignored = set and C_EquipmentSet.GetIgnoredSlots(set)
    local kept = {}
    for slot = FIRST_SLOT, LAST_SLOT do
        if POLE_SLOTS[slot] or (ignored and not ignored[slot]) then
            kept[slot] = GetInventoryItemLink("player", slot) or false
        end
    end
    store[key] = kept
    dressing, returning = true, false
    Listen()
end

function Gear.PutBack()
    if not Kept() then return ns.Print(TEXT_NOTHING) end
    if InCombatLockdown() then
        afterCombat = true
        ns.Print(TEXT_AFTER_COMBAT)
    else
        returning = true
        PutBack(false)
    end
    Listen()
end

function Gear.Choices()
    local values, order = { [""] = TEXT_BEST_POLE }, {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(id)
        if name then
            values[name] = name
            order[#order + 1] = name
        end
    end
    table.sort(order)
    table.insert(order, 1, "")
    return values, order
end

function NaowhForever_FishingGearOff()
    Gear.PutBack()
end

local function OnSettingChanged(key)
    if KEYS[key] then Listen() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Listen)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Listen()
end)
