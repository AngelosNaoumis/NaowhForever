-- Bank.lua: what your bank held when you last had it open, kept for each character, and what it would fetch (Market.Bank).
local ns = _G.NaowhForever

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo

local Market = ns.Market
local S = Market.Settings
local Worth = Market.Worth

local STORE = "marketBank"
local FIRST_TAB, LAST_TAB = Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9
local MAX_ITEMS = 500
local VISIT_EVENTS = { "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }
local CHANGE_EVENTS = { "PLAYERBANKSLOTS_CHANGED", "BAG_UPDATE_DELAYED" }

local events, open, pending

local Bank = {}
Market.Bank = Bank

local function On()
    return Market.On() and S.Get("bagWorth") and S.Get("bagWorthBank")
end

local function Emptied(data, key)
    local list = data[key]
    if type(list) ~= "table" then
        list = {}
        data[key] = list
    end
    return wipe(list)
end

local function Seen(data)
    data.at = time()
    if Bank.onChange then Bank.onChange() end
end

local function Snapshot()
    local data = ns.Shared.CharacterData(STORE, true)
    local items, bound, kept = Emptied(data, "items"), Emptied(data, "bound"), 0
    for bag = FIRST_TAB, LAST_TAB do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info and not info.hasNoValue then
                local list, id = info.isBound and bound or items, info.itemID
                if list[id] or kept < MAX_ITEMS then
                    if not list[id] then kept = kept + 1 end
                    list[id] = (list[id] or 0) + info.stackCount
                end
            end
        end
    end
    Seen(data)
end

local function Later()
    pending = false
    if open then Snapshot() end
end

local function OnEvent(_, event)
    if event == "BANKFRAME_OPENED" then
        open = true
        for _, name in ipairs(CHANGE_EVENTS) do events:RegisterEvent(name) end
        Snapshot()
    elseif event == "BANKFRAME_CLOSED" then
        if not open then return end
        open = false
        for _, name in ipairs(CHANGE_EVENTS) do events:UnregisterEvent(name) end
        Seen(ns.Shared.CharacterData(STORE))
    elseif not pending then
        pending = true
        C_Timer.After(0, Later)
    end
end

function Bank.Worth()
    local data = ns.Shared.CharacterData(STORE)
    if not (data and data.at) then return end
    local total = 0
    for id, count in pairs(data.items) do total = total + Worth.Each(id) * count end
    for id, count in pairs(data.bound) do total = total + Worth.Each(id, true) * count end
    return total, data.at
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        open = false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, name in ipairs(VISIT_EVENTS) do events:RegisterEvent(name) end
end

S.OnChange(function(key)
    if key == "enabled" or key == "bagWorth" or key == "bagWorthBank" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
