-- Run with Lua 5.1 from the repository root: the Dalaran skycutter timed from its dockmasters' arrival calls,
-- heard only on their maps, each dockmaster's first line counted and the rest until the ship has left ignored.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end

local now, clock = 1700000000, 500
local ns = { Shared = { Places = dofile("Tools/regression/shared_places.lua") },
    QoLConstants = dofile("Tools/regression/qol_constants.lua") }
_G.NaowhForever = ns
local account = {}
ns.AccountSettings = function() return account end
_G.GetRealmName = function() return "Realm" end
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }
_G.GetServerTime = function() return now end
_G.GetTime = function() return clock end
local SECRET = {}
_G.issecretvalue = function(value) return value == SECRET end
local frames = {}
_G.CreateFrame = function()
    local f = { events = {}, scripts = {} }
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(key) self.events[key] = true end
    function f:UnregisterEvent(key) self.events[key] = nil end
    frames[#frames + 1] = f
    return f
end
dofile("NaowhForever_QoL/Travel/TransportData.lua")
dofile("NaowhForever_QoL/Travel/TransportRoutes.lua")
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
dofile("NaowhForever_QoL/Travel/TransportCalls.lua")
local Calls = ns.TransportCalls
local SHIP = "Zephras Isle - Dalaran"
local ship = ns.TransportRoutes[SHIP]
local function Row() return account.transportRides and account.transportRides.Realm[SHIP] end

Calls.Watch(1429)
Check(#frames == 0, "away from a dockmaster it builds nothing")
Calls.Watch(2665)
local events = frames[1]
Check(events and events.events.CHAT_MSG_MONSTER_SAY and events.events.CHAT_MSG_MONSTER_YELL
    and events.events.CHAT_MSG_MONSTER_EMOTE and events.events.CHAT_MSG_RAID_BOSS_EMOTE,
    "on Zephras Isle, its second map included, it listens to what NPCs say")
local function Says(guid)
    events.scripts.OnEvent(events, "CHAT_MSG_MONSTER_YELL", "text", "name", "", "", "", "", 0, 0, "", 0, 1, guid)
end
local HIGH_ORDER, LAURAIN = "Creature-0-1-2-3-275269-00004A2B1C", "Creature-0-1-2-3-256306-00004A2B1D"
Says("Creature-0-1-2-3-12345-00004A2B1C")
Says("Player-1234-0000AAAA")
Says(SECRET)
Check(Row() == nil, "another NPC, a player or a secret GUID times nothing")
local arrived, heard = now, clock
local start = arrived - ship.docks[1].arrive
Says(HIGH_ORDER)
Check(Row() and Row().at == start, "the High Order Dockmaster's call is the skycutter's arrival")
now, clock = arrived + 5, heard + 5
Says(HIGH_ORDER)
Check(Row().at == start, "the next line before the ship has left is not another arrival")
local wait = ship.docks[1].leave - ship.docks[1].arrive
now, clock = arrived + wait, heard + wait
Says(HIGH_ORDER)
Check(Row().at == start, "nor one as it leaves")
now, clock = arrived + ship.period, heard + ship.period
Says(HIGH_ORDER)
Check(Row().at == start + ship.period, "the next arrival a cycle on is")

Calls.Watch(1416)
now, clock = now + 200, clock + 200
Says(LAURAIN)
Check(Row().at == now - ship.docks[2].arrive, "Arcanist Laurain's call is its arrival at Dalaran")
Calls.Watch(1429)
Check(next(events.events) == nil, "leaving the dockmasters' maps stops listening")
print("transport calls: " .. checks .. " checks passed")
