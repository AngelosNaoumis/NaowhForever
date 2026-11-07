-- FishingSounds.lua: Louder Splash, game sounds up and music and ambience down while your line is out.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings
local D = ns.FishingData
local G = ns.Glimmer

local GetCVar, SetTempCVar, RemoveTempCVar = C_CVar.GetCVar, C_CVar.SetTempCVar, C_CVar.RemoveTempCVar

local LOUD = { Sound_SFXVolume = "1", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0" }
local SAVED_TEMPS = "fishingLoudTemps"
local PAGE = "QoL/Loot & Items"
local ORDER = 57
local KEYS = { enabled = true, fishingSounds = true }

local events = CreateFrame("Frame")
local loud

local function On()
    return S.Get("enabled") and S.Get("fishingSounds")
end

local function Quiet()
    loud = false
    local store = ns.AccountSettings()
    local temps = store[SAVED_TEMPS]
    if not temps then return end
    for name in pairs(temps) do RemoveTempCVar(name) end
    store[SAVED_TEMPS] = nil
end

local function Loud()
    if loud then return end
    loud = true
    local temps = {}
    for name, value in pairs(LOUD) do
        if tonumber(GetCVar(name)) ~= tonumber(value) then
            SetTempCVar(name, value)
            temps[name] = true
        end
    end
    if next(temps) then ns.AccountSettings()[SAVED_TEMPS] = temps end
end

local function OnEvent(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if G.Plain(spellID) and D.SPELLS[spellID] then Loud() end
    elseif loud then
        Quiet()
    end
end

events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    Quiet()
    if not On() then return end
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
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
    id = "fishingSounds", name = "Louder Splash", order = ORDER, switch = "fishingSounds",
    help = "While your line is out, game sounds go up and music and ambience go quiet.",
})
