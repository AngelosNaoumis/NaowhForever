-- Run with Lua 5.1 from the repository root: ship timings heard from ForeverTransport's and NauticusClassic's
-- users, and asked of them at login, in a group and at a dock.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end

local now, clock = 1700000000, 0
local ns = { Shared = { Places = dofile("Tools/regression/shared_places.lua") },
    QoLConstants = dofile("Tools/regression/qol_constants.lua") }
_G.NaowhForever = ns
local account = {}
ns.AccountSettings = function() return account end
_G.GetRealmName = function() return "Realm" end
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }
_G.GetServerTime = function() return now end
_G.GetTime = function() return clock end
dofile("NaowhForever_QoL/Travel/TransportData.lua")
dofile("NaowhForever_QoL/Travel/TransportRoutes.lua")
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
local Routes = ns.TransportRoutes
local function Row(name) return account.transportRides and account.transportRides.Realm[name] end

local frames, sent, prefixes = {}, {}, {}
_G.CreateFrame = function()
    local f = { events = {}, scripts = {} }
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(key) self.events[key] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) prefixes[#prefixes + 1] = prefix end,
    SendAddonMessage = function(prefix, message, channel) sent[#sent + 1] = { prefix, message, channel } end,
}
local SECRET = {}
_G.issecretvalue = function(value) return value == SECRET end
_G.GetNetStats = function() return 0, 0, 50 end
local guild, party, instance, map = true, false, false, 1411
_G.IsInGuild = function() return guild end
_G.IsInRaid = function() return false end
_G.IsInGroup = function() return party end
_G.IsInInstance = function() return instance end
_G.LE_PARTY_CATEGORY_HOME = 1
_G.IsLoggedIn = function() return true end
_G.C_Map = { GetBestMapForUnit = function() return map end }
_G.hooksecurefunc = function(target, key, fn)
    local original = target[key]
    target[key] = function(...) original(...); fn(...) end
end
ns.Apply = function() end
local listeners = {}
local settings = { enabled = true, transportTimers = true, transportShare = false }
ns.QoLSettings = {
    Get = function(key) return settings[key] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Set = function(key, value)
        settings[key] = value
        for _, fn in ipairs(listeners) do fn(key) end
    end,
}

-- NauticusClassic's codec and StringHash, as its NautComms.lua (MIT, psynct) has them.
local DIGITS = "0123456789ABCDEFGHIJKLMNOPQRTUVWXYZabcdefghijklmnopqrtuvwxyz!\"#$&'()*+-./;<=>?@[\\]^_`{}~"
    .. "\001\002\003\004\005\006\007\008\011\012"
    .. "\014\015\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031\127"
local function Crunch(n)
    local s = ""
    repeat
        local r = n % #DIGITS
        s = s .. DIGITS:sub(r + 1, r + 1)
        n = (n - r) / #DIGITS
    until n == 0
    return s
end
local function Hash(text)
    local counter, len = 1, #text
    for i = 1, len, 3 do
        counter = (counter * 8161) % 4294967279 + (text:byte(i) * 16776193)
            + ((text:byte(i + 1) or (len - i + 256)) * 8372226) + ((text:byte(i + 2) or (len - i + 256)) * 3932164)
    end
    return counter % 4294967291
end
local function Known(list) return "KWN4 4 " .. list .. " " .. Crunch(Hash(list)) end

dofile("NaowhForever_QoL/Travel/TransportPeers.lua")
Check(#frames == 0 and #prefixes == 0 and #sent == 0, "with Share Timings off it builds, registers and sends nothing")

ns.QoLSettings.Set("transportShare", true)
local events = frames[1]
Check(events and events.events.CHAT_MSG_ADDON and prefixes[1] == "FTrans2" and prefixes[2] == "NauticSync",
    "on, it listens on both addons' prefixes")
local function Sent(prefix, channel)
    for _, s in ipairs(sent) do
        if s[1] == prefix and s[3] == channel then return s[2] end
    end
end
local NAUTICUS_ASK = Known("1,2,3,4,6,7,8,B,C,D,E")
Check(Sent("FTrans2", "GUILD") == "Q|5" and Sent("NauticSync", "GUILD") == NAUTICUS_ASK,
    "turned on while logged in, it asks the guild: " .. tostring(Sent("NauticSync", "GUILD")))
Check(Sent("FTrans2", "YELL") == "Q|5" and Sent("NauticSync", "YELL") == NAUTICUS_ASK,
    "and those nearby, at a zeppelin tower")
local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end
local before = #sent
Fire("ZONE_CHANGED_NEW_AREA")
Check(#sent == before, "it asks each channel at most every two minutes")
clock = clock + 121
map = 1429
Fire("ZONE_CHANGED_NEW_AREA")
Check(Sent("FTrans2", "GUILD") and #sent == before + 2, "away from a dock it does not ask those nearby")
clock = clock + 121
map, instance = 1411, true
before = #sent
Fire("PLAYER_ENTERING_WORLD")
Check(#sent == before + 2, "nor in an instance")
clock = clock + 121
instance, party = false, true
before = #sent
Fire("GROUP_ROSTER_UPDATE")
Check(#sent == before + 2 and sent[#sent][3] == "PARTY", "joining a group asks the party, and only the party")
map = 2665
clock = clock + 121
Fire("ZONE_CHANGED_NEW_AREA")
Check(sent[#sent][3] == "YELL", "Zephras Isle's second map counts as the island's dock zone")

-- ForeverTransport: A|route|dock|arrival|observed|quality, one dock's arrival on the server clock.
local SHIP = "The Thundercaller"
local ship = Routes[SHIP]
local arrival = now - 1000
local start = arrival - ship.docks[2].arrive
local expected = start + math.floor((now - 10 - start) / ship.period) * ship.period
Fire("CHAT_MSG_ADDON", "FTrans2", ("A|1|2|%.3f|%.3f|5"):format(arrival, now - 10), "SAY", "Someone")
Check(Row(SHIP) == nil, "a timing on a channel it does not take is ignored")
Fire("CHAT_MSG_ADDON", "FTrans2", ("A|1|3|%.3f|%.3f|5"):format(arrival, now - 10), "WHISPER", "Someone")
Check(Row(SHIP) == nil, "a dock the ship does not have is ignored")
Fire("CHAT_MSG_ADDON", "FTrans2", ("A|99|1|%.3f|%.3f|5"):format(arrival, now - 10), "WHISPER", "Someone")
Fire("CHAT_MSG_ADDON", "FTrans2", SECRET, "WHISPER", "Someone")
Check(Row(SHIP) == nil, "an unknown ship or a secret message is ignored")
Fire("CHAT_MSG_ADDON", "FTrans2", ("A|1|2|%.3f|%.3f|5"):format(arrival, now - 10), "WHISPER", "Someone")
Check(Row(SHIP) and math.abs(Row(SHIP).at - expected) < 1e-3 and Row(SHIP).shared,
    "a ForeverTransport arrival at Undercity times the ship from its last cycle start before it was seen")

-- NauticusClassic: KWN4 4 id:since,... hash, since in ms since a cycle start, plus the sender's lag.
local MOON, BRAVERY = "The Moonspray", "The Bravery"
local since = 123456789
Fire("CHAT_MSG_ADDON", "NauticSync", "KWN4 4 7:" .. Crunch(since) .. " " .. Crunch(Hash("7:" .. Crunch(since)) + 1),
    "YELL", "Someone")
Check(Row(MOON) == nil, "a wrong hash is ignored")
Fire("CHAT_MSG_ADDON", "NauticSync", Known("5:" .. Crunch(since)), "GUILD", "Someone")
Check(Row(BRAVERY) == nil, "the Bravery is ignored: the original NauticusClassic sends its two-dock cycle under that id")
Fire("CHAT_MSG_ADDON", "NauticSync", Known("7:" .. Crunch(since) .. ",E"), "YELL", "Someone")
Check(Row(MOON) and math.abs(Row(MOON).at - (now - ((since + 50) / 1000) % Routes[MOON].period)) < 1e-6
    and Row(MOON).shared, "a NauticusClassic timing of the Moonspray is kept as shared")
Check(Row("Powderfuse Port - Steamwheedle Port") == nil, "a ship it was only asked about times nothing")

ns.QoLSettings.Set("transportShare", false)
Check(next(events.events) == nil, "Share Timings off stops listening")
print("transport peers: " .. checks .. " checks passed")
