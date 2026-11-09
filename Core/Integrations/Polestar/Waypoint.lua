-- Waypoint.lua: an optional guide destination feed for the Waypoint Pin, from Polestar.
local ns = _G.NaowhForever

local ADDON = "Polestar"
local OWNER = "NaowhForever"
local MINOR = 1
local PERCENT = 100
local SAME_SPOT = 0.05
local TEXT_GUIDE = ns.L("Guide destination")
local PIN_OPTIONS = { pin = true, shows = false }
local SHOWN_OPTIONS = { pin = true, shows = true }

local settingsHooked, dismissHooked, following, showing, active
local events
local last, details
local OnSetting, OnEvent

local function On()
    local S = ns.QoLSettings
    return S and S.Get("enabled") and S.Get("waypoints") and S.Get("waypointPolestar")
        and ns.WaypointPinOn and ns.WaypointPinOn()
end

local function API()
    local P = _G.Polestar
    local A = type(P) == "table" and type(P.Nav) == "table" and P.Nav.API
    if type(A) == "table" and type(A.minor) == "number" and A.minor >= MINOR
        and type(A.Follow) == "function" and type(A.Target) == "function" then return A end
end

function ns.PolestarFollowable()
    if API() then return true end
    if type(_G.Polestar) == "table" then return false, "Needs a newer Polestar" end
    return false, "Polestar is not loaded"
end

local function Plain(text)
    if issecretvalue and issecretvalue(text) then return end
    if type(text) ~= "string" then return end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if text ~= "" then return text end
end

local function Stop()
    if details then ns.ClearGuideWaypoint(details) end
    last, details = nil, nil
end

local function Same(map, x, y, title)
    return last ~= nil and last.map == map and math.abs(last.x - x) < SAME_SPOT
        and math.abs(last.y - y) < SAME_SPOT and last.title == title
end

local function Fraction(v)
    return type(v) == "number" and v == v and v >= 0 and v <= 1
end

local function Sync()
    if not On() then return end
    local A = API()
    local target = A and A.Target()
    if type(target) ~= "table" or target.handedOff then Stop() return end
    local point, quest = target, target.quest
    local S = ns.QoLSettings
    if S.Get("waypointPolestarStops") and type(target.next) == "table" then point, quest = target.next, nil end
    local map, x, y = point.map, point.x, point.y
    if type(map) ~= "number" or not (Fraction(x) and Fraction(y)) then Stop() return end
    x, y = x * PERCENT, y * PERCENT
    if type(quest) ~= "number" or quest <= 0 then quest = nil end
    local title = Plain(point.title) or TEXT_GUIDE
    if Same(map, x, y, title) then
        if details.quest ~= quest then
            details.quest = quest
            if ns.RefreshWaypointPin then ns.RefreshWaypointPin() end
        end
        return
    end
    local replacement = { guide = true, quest = quest, title = title }
    if not ns.SetGuideWaypoint(title, map, x, y, replacement) then Stop() return end
    details = replacement
    last = { map = map, x = x, y = y, title = title }
end

local function Follow()
    local shows = ns.QoLSettings.Get("waypointNav") and true or false
    if following and showing == shows then return true end
    local A = API()
    if not (A and IsLoggedIn()) then return false end
    following = A.Follow(OWNER, Sync, shows and SHOWN_OPTIONS or PIN_OPTIONS) and true or false
    showing = shows
    return following
end

local function Unfollow()
    if not following then return end
    following, showing = false, nil
    local A = API()
    if A and A.Unfollow then A.Unfollow(OWNER) end
end

local function OnDismiss(dismissed)
    if not (active and following and dismissed ~= nil and dismissed == details) then return end
    last, details = nil, nil
    local A = API()
    if A and A.Dismiss then A.Dismiss(OWNER) end
end

local function Apply()
    local S = ns.QoLSettings
    if S and not settingsHooked then
        settingsHooked = true
        hooksecurefunc(S, "Set", OnSetting)
    end
    if not On() then
        if events then events:UnregisterAllEvents() end
        if active then Stop() end
        Unfollow()
        active = false
        return
    end
    if not dismissHooked then
        dismissHooked = true
        hooksecurefunc(ns, "DismissGuideWaypoint", OnDismiss)
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    active = true
    if Follow() then
        events:UnregisterAllEvents()
        Sync()
    else
        events:RegisterEvent("ADDON_LOADED")
        events:RegisterEvent("PLAYER_LOGIN")
    end
end

function OnSetting(key)
    if key == "enabled" or key == "waypoints" or key == "waypointPolestar" then
        Apply()
    elseif key == "waypointPolestarStops" and active then
        last = nil
        Sync()
    elseif key == "waypointRestedXP" and active and not ns.QoLSettings.Get("waypointRestedXP") then
        last = nil
        Sync()
    elseif key == "waypointNav" and following then
        Follow()
    end
end

function OnEvent(_, event, name)
    if event == "ADDON_LOADED" and name ~= ADDON then return end
    if Follow() then
        events:UnregisterAllEvents()
        Sync()
    elseif event == "PLAYER_LOGIN" then
        events:UnregisterAllEvents()
    end
end

hooksecurefunc(ns, "Apply", Apply)
