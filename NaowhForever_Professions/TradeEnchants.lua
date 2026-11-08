-- TradeEnchants.lua: the enchants you know that go on the item someone puts in the trade window, and the ones they asked for (P.TradeEnchants).
local ns = _G.NaowhForever

local GetItemInfoInstant, GetItemInventoryTypeByID = C_Item.GetItemInfoInstant, C_Item.GetItemInventoryTypeByID

local P = ns.Professions
local R = P.Recipes
local D = P.Disenchant
local Slots = P.EnchantSlots

local CLASS, INV, SUB = 1, 2, 3
local LINK_START = "|Henchant:"
local LINK_ID = "|Henchant:(%d+)"
local MAX_ASKERS = 20
local CHAT_EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER" }

local asked = {}
local askers = 0
local list = {}
local sortGUID, events

local function Bit(mask, n)
    return math.floor(mask / 2 ^ n) % 2 == 1
end

local function Fits(slot, class, subclass, inv)
    if slot[CLASS] ~= class then return false end
    return (slot[SUB] == 0 or Bit(slot[SUB], subclass)) and (slot[INV] == 0 or Bit(slot[INV], inv))
end

local function Asked(guid, recipeID)
    local set = guid and asked[guid]
    return set ~= nil and set[recipeID] == true
end

local function AskedFirst(a, b)
    local x, y = Asked(sortGUID, a.recipeID), Asked(sortGUID, b.recipeID)
    if x ~= y then return x end
    if a.maxTrivialLevel ~= b.maxTrivialLevel then return a.maxTrivialLevel > b.maxTrivialLevel end
    return a.name < b.name
end

local function Remember(guid, recipeID)
    if not asked[guid] then
        if askers >= MAX_ASKERS then
            wipe(asked)
            askers = 0
        end
        asked[guid] = {}
        askers = askers + 1
    end
    asked[guid][recipeID] = true
end

local function OnChat(_, _, text, _, _, _, _, _, _, _, _, _, _, guid)
    if issecretvalue(text) or issecretvalue(guid) or not guid then return end
    if not text:find(LINK_START, 1, true) then return end
    for id in text:gmatch(LINK_ID) do
        id = tonumber(id)
        if Slots[id] then Remember(guid, id) end
    end
end

local TE = {}
P.TradeEnchants = TE
TE.Asked = Asked

function TE.EnchantingOpen()
    local frame = _G.ProfessionsFrame
    if not (frame and frame:IsShown() and R.Own()) then return false end
    local prof = R.Profession()
    return prof ~= nil and prof.id == D.ENCHANTING
end

function TE.List(link, guid)
    wipe(list)
    local _, _, _, _, _, class, subclass = GetItemInfoInstant(link)
    local inv = GetItemInventoryTypeByID(link)
    if not (class and inv) then return list end
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        local slot = Slots[id]
        if slot and Fits(slot, class, subclass, inv) then
            local info = C_TradeSkillUI.GetRecipeInfo(id)
            if info and info.learned then list[#list + 1] = info end
        end
    end
    sortGUID = guid
    table.sort(list, AskedFirst)
    return list
end

function TE.Listen(on)
    if not on then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnChat)
    end
    for _, event in ipairs(CHAT_EVENTS) do events:RegisterEvent(event) end
end
