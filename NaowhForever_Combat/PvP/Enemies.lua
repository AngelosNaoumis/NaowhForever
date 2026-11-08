-- Enemies.lua: Nearby Enemies' list: the enemy players seen around you, and your Kill on Sight list (P.Enemies).
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local Readable = P.Readable

local FORGET_AFTER = 300
local MAX_ENEMIES = 8
local KEYS = { enabled = true, nearbyEnemies = true }
local SEEN_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }

local list, byKey, plates, lastSeen = {}, {}, {}, {}
local events, ours, listener

local Enemies = { list = list }
P.Enemies = Enemies

local function On()
    return S.Get("enabled") == true and S.Get("nearbyEnemies") == true
end

local function Kills()
    local account = ns.AccountSettings()
    if type(account.pvpKillOnSight) ~= "table" then account.pvpKillOnSight = {} end
    return account.pvpKillOnSight
end

local function Newer(a, b)
    if a.kill ~= b.kill then return a.kill end
    if a.near ~= b.near then return a.near end
    return a.seen > b.seen
end

local function Remove(i)
    byKey[list[i].key] = nil
    table.remove(list, i)
end

local function Expire(now)
    for _, key in pairs(plates) do lastSeen[key] = now end
    for key, at in pairs(lastSeen) do
        if now - at >= FORGET_AFTER then lastSeen[key] = nil end
    end
    for i = #list, 1, -1 do
        local enemy = list[i]
        if not enemy.near and now - enemy.seen >= FORGET_AFTER then Remove(i) end
    end
end

local function IsEnemy(unit)
    local player = UnitIsPlayer(unit)
    if not (Readable(player) and player) then return false end
    local faction = UnitFactionGroup(unit)
    return Readable(faction) and faction ~= ours
end

local function Fill(enemy, unit, name)
    enemy.name = name
    local level = UnitLevel(unit)
    if Readable(level) then enemy.level = level end
    local _, class = UnitClass(unit)
    if Readable(class) then enemy.class = class end
    local guild = GetGuildInfo(unit)
    if Readable(guild) and guild ~= "" then enemy.guild = guild end
end

local function Add(key)
    if #list >= MAX_ENEMIES then
        table.sort(list, Newer)
        Remove(#list)
    end
    local enemy = { key = key, near = false }
    byKey[key] = enemy
    list[#list + 1] = enemy
    return enemy
end

local function Note(unit, plate)
    if not IsEnemy(unit) then return end
    local key, name = UnitGUID(unit), UnitName(unit)
    if not (Readable(key) and Readable(name)) then return end
    local now = time()
    Expire(now)
    local fresh = lastSeen[key] == nil
    lastSeen[key] = now
    local enemy = byKey[key] or Add(key)
    Fill(enemy, unit, name)
    enemy.seen, enemy.kill = now, Kills()[key] ~= nil
    if plate then
        enemy.near = true
        plates[plate] = key
    end
    listener(fresh and enemy or nil)
end

local function Gone(plate)
    local key = plates[plate]
    if not key then return end
    local now = time()
    plates[plate], lastSeen[key] = nil, now
    local enemy = byKey[key]
    if not enemy then return end
    enemy.near, enemy.seen = false, now
    listener(nil)
end

local function Forget()
    wipe(list)
    wipe(byKey)
    wipe(plates)
end

local function Listen()
    events:UnregisterAllEvents()
    if not On() then
        Forget()
        wipe(lastSeen)
    elseif IsInInstance() then
        Forget()
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        ours = UnitFactionGroup("player")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        for _, event in ipairs(SEEN_EVENTS) do events:RegisterEvent(event) end
    end
    listener(nil)
end

local function OnEvent(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if Readable(unit) then Note(unit, unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if Readable(unit) then Gone(unit) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Note("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Note("mouseover")
    else
        Forget()
        Listen()
    end
end

local function Apply()
    if not (On() or events) then return end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    Listen()
end

Enemies.On = On

function Enemies.OnChange(fn)
    listener = fn
end

function Enemies.Sorted()
    table.sort(list, Newer)
    return list
end

function Enemies.Expire()
    Expire(time())
end

function Enemies.SetKill(enemy, on)
    Kills()[enemy.key] = on and enemy.name or nil
    enemy.kill = on
    listener(nil)
end

function Enemies.KillCount()
    local count = 0
    for _ in pairs(Kills()) do count = count + 1 end
    return count
end

function Enemies.ClearKills()
    wipe(Kills())
    for _, enemy in ipairs(list) do enemy.kill = false end
    listener(nil)
end

local function OnSet(key)
    if KEYS[key] then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
