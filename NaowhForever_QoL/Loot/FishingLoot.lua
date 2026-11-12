-- FishingLoot.lua: Auto Loot While Fishing, auto loot on while your line is out and until your catch is looted.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings
local D = ns.FishingData
local G = ns.Glimmer

local GetCVar, SetTempCVar, RemoveTempCVar = C_CVar.GetCVar, C_CVar.SetTempCVar, C_CVar.RemoveTempCVar

local AUTO_LOOT = "autoLootDefault"
local LOOT_WAIT = 2
local SAVED_TEMP = "fishingAutoLootTemp"
local PAGE = "QoL/Loot & Items"
local ORDER = 58
local KEYS = { enabled = true, fishingAutoLoot = true }

local events = CreateFrame("Frame")
local line
local run = 0

local function On()
    return S.Get("enabled") and S.Get("fishingAutoLoot")
end

local function Restore()
    line = nil
    run = run + 1
    local store = ns.AccountSettings()
    if not store[SAVED_TEMP] then return end
    RemoveTempCVar(AUTO_LOOT)
    store[SAVED_TEMP] = nil
end

local function AutoLoot()
    line = "out"
    run = run + 1
    if GetCVar(AUTO_LOOT) == "1" then return end
    SetTempCVar(AUTO_LOOT, "1")
    ns.AccountSettings()[SAVED_TEMP] = true
end

local function Landed()
    line = "landed"
    local landed = run
    C_Timer.After(LOOT_WAIT, function()
        if run == landed and line == "landed" then Restore() end
    end)
end

local function OnEvent(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if G.Plain(spellID) and D.SPELLS[spellID] then AutoLoot() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if line == "out" then Landed() end
    elseif event == "LOOT_OPENED" then
        if line then line = "looting" end
    elseif event == "LOOT_CLOSED" then
        if line == "looting" then Restore() end
    end
end

events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    Restore()
    if not On() then return end
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    events:RegisterEvent("LOOT_OPENED")
    events:RegisterEvent("LOOT_CLOSED")
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

Settings.Page(PAGE, S):Card({
    id = "fishingAutoLoot", name = "Auto Loot While Fishing", order = ORDER, switch = "fishingAutoLoot",
    help = "Turns auto loot on while your line is out, and off again once your catch is looted.",
})
