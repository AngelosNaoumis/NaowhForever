-- Optional Polestar guide target feed for the Waypoint Pin, against a stubbed Polestar.Nav.API.
-- Run from the repo root: lua Tools/regression/test-polestar-waypoint.lua
local checks = 0
local function Check(value, label) assert(value, label); checks = checks + 1 end
local frames, setHooks = {}, 0
local settings = { enabled = true, waypoints = true, waypointPolestar = false, waypointPolestarStops = true,
    waypointNav = true }
local current, writes, refreshes, tracking, available = nil, 0, 0, true, true
local loggedIn = true
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local ns = { QoLSettings = S, L = function(s) return s end, Apply = function() end,
    WaypointPinOn = function() return settings.waypoints end,
    GuideWaypointIsCurrent = function() return tracking and current ~= nil and current.details.guide == true end,
    ClearGuideWaypoint = function(d)
        if tracking and current and current.details.guide and (d == nil or d == current.details) then current = nil end
    end,
    RefreshWaypointPin = function() refreshes = refreshes + 1 end,
    DismissGuideWaypoint = function() current = nil end,
}
ns.SetGuideWaypoint = function(title, map, x, y, details)
    if not available then return false end
    tracking = true
    writes = writes + 1
    current = { title = title, map = map, x = x, y = y, details = details }
    return true
end

-- Polestar's public API, minor 1: one target, followers called by hand (Polestar calls them the next frame).
local target
local followed, dismissed, followCalls = {}, 0, 0
local api = { version = 1, minor = 1 }
function api.Target() return target end
function api.Follow(owner, fn, opts)
    followCalls = followCalls + 1
    followed[owner] = { fn = fn, opts = opts }
    return true
end
function api.Unfollow(owner) local was = followed[owner] ~= nil; followed[owner] = nil; return was end
function api.Dismiss(owner) if followed[owner] then dismissed = dismissed + 1; target = nil; return true end return false end
local function Tell() for _, f in pairs(followed) do f.fn() end end

local env = setmetatable({ NaowhForever = ns,
    IsLoggedIn = function() return loggedIn end,
    CreateFrame = function()
        local f = { events = {} }
        function f:SetScript(_, fn) self.handler = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(t, key, fn)
        if t == S and key == "Set" then setHooks = setHooks + 1 end
        local old = t[key]
        t[key] = function(...) old(...); fn(...) end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("Core/Integrations/Polestar/Waypoint.lua")); setfenv(chunk, env); chunk()
local function Fire(event, ...)
    for _, f in ipairs(frames) do if f.events[event] then f.handler(f, event, ...) end end
end

ns.Apply()
Check(#frames == 0 and next(followed) == nil and writes == 0, "off: no frames, no follow, no pin")
S.Set("waypointPolestar", true)
Check(frames[1].events.ADDON_LOADED and next(followed) == nil, "Polestar absent: waits for it without errors")
local ok, why = ns.PolestarFollowable()
Check(ok == false and why == "Polestar is not loaded", "the settings can say Polestar is not loaded")
env.Polestar = { Nav = { API = { version = 1 } } }
Fire("ADDON_LOADED", "Polestar")
Check(next(followed) == nil and frames[1].events.ADDON_LOADED, "an older Polestar without minor 1 is left alone")
ok, why = ns.PolestarFollowable()
Check(ok == false and why == "Needs a newer Polestar", "and the settings can say it needs a newer one")
env.Polestar.Nav.API = api
Check(ns.PolestarFollowable() == true, "minor 1: followable")
loggedIn = false
Fire("ADDON_LOADED", "Polestar")
Check(next(followed) == nil and frames[1].events.PLAYER_LOGIN, "before login it waits for the login")
loggedIn = true
Fire("PLAYER_LOGIN")
local f = followed.NaowhForever
Check(f and f.opts.pin and f.opts.shows and next(frames[1].events) == nil, "follows once logged in, pinning and showing")
S.Set("waypointNav", false)
Check(followed.NaowhForever.opts.pin and not followed.NaowhForever.opts.shows,
    "Navigator Bar off: Polestar is told the target is not shown, so its arrow stays")
S.Set("waypointNav", true)
Check(followed.NaowhForever.opts.shows, "and on again: shown")
local callsBeforeProfile = followCalls
settings.waypointNav = false
ns.Apply()
Check(followed.NaowhForever.opts.pin and not followed.NaowhForever.opts.shows,
    "a profile with Navigator Bar off refreshes the existing follower")
settings.waypointNav = true
ns.Apply()
Check(followed.NaowhForever.opts.pin and followed.NaowhForever.opts.shows,
    "a profile with Navigator Bar on refreshes the existing follower")
Check(followCalls == callsBeforeProfile + 2, "each changed profile updates the follower once")
ns.Apply()
Check(followCalls == callsBeforeProfile + 2, "an unchanged profile does not follow again")

target = { map = 1429, x = 0.4, y = 0.6, title = "|cffffd100Kill|r Kobold Vermin", kind = "kill", quest = 7 }
Tell()
Check(current and current.map == 1429 and math.abs(current.x - 40) < 1e-9 and math.abs(current.y - 60) < 1e-9,
    "the target in map percent")
Check(current.title == "Kill Kobold Vermin" and current.details.quest == 7 and current.details.guide,
    "a plain title, the quest for its objectives, marked a guide pin")
Tell()
Check(writes == 1, "the same target again is not placed again")

current = nil
Tell()
Check(writes == 1 and current == nil, "reached (the game cleared it): not placed again for the same target")
target = { map = 1429, x = 0.45, y = 0.6, title = "Kill Kobold Vermin", kind = "kill", quest = 7 }
Tell()
Check(writes == 2 and current and math.abs(current.x - 45) < 1e-9, "the next spot is placed")

target.next = { map = 1429, x = 0.3, y = 0.3, kind = "walk", title = "Walk to the flight master" }
Tell()
Check(current.title == "Walk to the flight master" and math.abs(current.x - 30) < 1e-9 and current.details.quest == nil,
    "Next Stop: the leg the arrow is on, without the quest")
S.Set("waypointPolestarStops", false)
Check(current.title == "Kill Kobold Vermin" and math.abs(current.x - 45) < 1e-9 and current.details.quest == 7,
    "Next Stop off: the end of the trip at once")
S.Set("waypointPolestarStops", true)

local placed = current.details
ns.DismissGuideWaypoint({ guide = true })
Check(dismissed == 0, "a clear of another guide's pin is not Polestar's")
ns.DismissGuideWaypoint(placed)
Check(dismissed == 1, "the navigator's clear of ours tells Polestar")
Tell()
Check(current == nil, "no target: no pin")

target = { map = 1429, x = 0.5, y = 0.5, title = "Handed", handedOff = true }
Tell()
Check(current == nil, "handed to Shortest Path Forever: no pin")
target = { map = 1429, x = 1.5, y = 0.5, title = "Bad" }
Tell()
Check(current == nil, "a point off the map: no pin")
target = { map = 1429, x = 0.5, y = 0.5, title = "Inside" }
available = false
Tell()
Check(current == nil, "a map without waypoints: no pin, no error")
available = true
Tell()
Check(current and current.title == "Inside", "and placed once it can be")

ns.ClearGuideWaypoint({ guide = true })
Check(current and current.title == "Inside", "another guide feed's clear leaves ours")
current = { title = "RestedXP's", details = { guide = true } }
local writesBefore = writes
S.Set("waypointRestedXP", true)
Check(current.title == "RestedXP's" and writes == writesBefore, "Follow RestedXP turned on: its destination is left to it")
S.Set("waypointRestedXP", false)
Check(current and current.title == "Inside", "and turned off: ours is placed again")
local order = {}
local realClear, realUnfollow = ns.ClearGuideWaypoint, api.Unfollow
ns.ClearGuideWaypoint = function(...) order[#order + 1] = "clear"; return realClear(...) end
api.Unfollow = function(...) order[#order + 1] = "unfollow"; return realUnfollow(...) end
S.Set("waypointPolestar", false)
ns.ClearGuideWaypoint, api.Unfollow = realClear, realUnfollow
Check(current == nil and followed.NaowhForever == nil, "off: the pin goes and Polestar is unfollowed")
Check(order[1] == "clear" and order[2] == "unfollow", "ours is cleared before Polestar takes the game pin back")
local before = writes
Tell()
Check(writes == before, "no work while off")
S.Set("waypointPolestar", true)
Check(followed.NaowhForever and current and current.title == "Inside", "on again: follows and pins at once")
S.Set("waypoints", false)
Check(followed.NaowhForever == nil and current == nil, "the Waypoint Pin off turns the feed off")
-- Polestar turned off in the addon list, Follow Polestar left on: the next login has none.
S.Set("waypoints", true)
S.Set("waypointPolestar", false)
env.Polestar, current = nil, nil
S.Set("waypointPolestar", true)
Check(current == nil and followed.NaowhForever == nil and frames[1].events.PLAYER_LOGIN, "no Polestar: no pin, no error")
Fire("PLAYER_LOGIN")
Check(next(frames[1].events) == nil, "and after login it stops waiting for one")
Check(setHooks == 1, "one settings hook, however often it is turned on")

-- Exercise failed replacement against the real core's map check and identity-based cleanup.
env.CreateFromMixins = function() return {} end
env.MapCanvasPinMixin = {}
env.UiMapPoint = { CreateFromCoordinates = function(map, x, y)
    return { uiMapID = map, position = { x = x, y = y } }
end }
env.C_Map = {
    CanSetUserWaypointOnMap = function(map) return map ~= 0 end,
    SetUserWaypoint = function(point) current = point end,
    GetUserWaypoint = function() return current end,
    ClearUserWaypoint = function() current = nil end,
}
env.C_SuperTrack = {
    IsSuperTrackingUserWaypoint = function() return tracking end,
    SetSuperTrackedUserWaypoint = function(on) tracking = on end,
    ClearAllSuperTracked = function() tracking = false end,
}
local core = assert(loadfile("Core/Waypoint.lua")); setfenv(core, env); core()
env.Polestar = { Nav = { API = api } }
target = { map = 1429, x = 0.4, y = 0.6, title = "Before unsupported map" }
ns.Apply()
Check(current and ns.placedWaypoint.details.guide, "real core: a guide pin exists before replacement")
local previousDetails = ns.placedWaypoint.details
local clearToken, coreClear = nil, ns.ClearGuideWaypoint
ns.ClearGuideWaypoint = function(d) clearToken = d; return coreClear(d) end
target = { map = 0, x = 0.5, y = 0.5, title = "Unsupported map" }
Tell()
Check(clearToken == previousDetails and current == nil,
    "failed replacement clears the previous real pin with its original ownership token")
S.Set("waypointPolestar", false)
Check(current == nil and followed.NaowhForever == nil, "disabling after failed replacement leaves no old pin")

local journeyDetails
ns.JourneyDetails = function() return journeyDetails end
ns.JourneyCancel = function() journeyDetails = nil end
ns.JourneyTo = function(title, stops, _, d)
    journeyDetails = d
    ns.ShowJourneyStep(title, stops[1][2], stops[1][3], stops[1][4], nil, nil, d)
    return true
end
target = { map = 1429, x = 0.3, y = 0.4, title = "Journey before unsupported map" }
S.Set("waypointPolestar", true)
Check(current and journeyDetails == ns.placedWaypoint.details, "real core: a guide journey owns its step")
previousDetails = journeyDetails
target = { map = 0, x = 0.5, y = 0.5, title = "Unsupported journey replacement" }
Tell()
Check(clearToken == previousDetails and journeyDetails == nil and current == nil,
    "failed replacement cancels the previous journey and clears its step with the original token")
S.Set("waypointPolestar", false)
Check(journeyDetails == nil and current == nil and followed.NaowhForever == nil,
    "disabling after failed replacement leaves no old journey or pin")
print(("test-polestar-waypoint: %d checks passed"):format(checks))
