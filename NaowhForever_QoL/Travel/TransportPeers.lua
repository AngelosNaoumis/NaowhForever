-- TransportPeers.lua: ship timings heard from ForeverTransport's and NauticusClassic's users, and asked of them at a dock.
local ns = _G.NaowhForever

local GetServerTime, GetTime = GetServerTime, GetTime
local S = ns.QoLSettings
local Times = ns.TransportTimes
local Routes = ns.TransportRoutes
local SameMap = ns.Shared.Places.SameMap

local FOREVER_PREFIX, NAUTICUS_PREFIX = "FTrans2", "NauticSync"
local FOREVER_ASK = "Q|5"
local FOREVER_TIMING = "^A|(%d+)|(%d+)|(%d+%.?%d*)|(%d+%.?%d*)|"
local NAUTICUS_HEAD = "KWN4 4 "
local NAUTICUS_TIMING = "^KWN4 4 ([^ ]+) ([^ ]+)$"
local NAUTICUS_ENTRY = "^([^:]+):([^:]+)"
local NAUTICUS_DIGITS = "0123456789ABCDEFGHIJKLMNOPQRTUVWXYZabcdefghijklmnopqrtuvwxyz!\"#$&'()*+-./;<=>?@[\\]^_`{}~"
    .. "\001\002\003\004\005\006\007\008\011\012"
    .. "\014\015\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031\127"
local NAUTICUS_FIELD = 8
local NAUTICUS_MAX_SINCE = 3.2e10
local HASH_START, HASH_STEP, HASH_WRAP, HASH_PRIME = 1, 8161, 4294967279, 4294967291
local HASH_FIRST, HASH_SECOND, HASH_THIRD, HASH_PAD = 16776193, 8372226, 3932164, 256
local LEGACY_BRAVERY = 5
local MS = 1000
local ASK_GAP = 120
local GUILD, YELL, PARTY, RAID, PLAYER = "GUILD", "YELL", "PARTY", "RAID", "player"
local HEARD = { PARTY = true, RAID = true, GUILD = true, YELL = true, WHISPER = true }
local EVENTS = { "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }

local events
local asked = {}
local named, docked, digit = {}, {}, {}
for name, route in pairs(Routes) do
    named[route.nauticus] = name
    for _, dock in ipairs(route.docks) do docked[ns.TransportData[dock.stop].map] = true end
end
local base = #NAUTICUS_DIGITS
for i = 1, base do digit[NAUTICUS_DIGITS:byte(i)] = i - 1 end

local function Uncrunch(text)
    if not text or #text > NAUTICUS_FIELD then return nil end
    local number, place = 0, 1
    for i = 1, #text do
        local value = digit[text:byte(i)]
        if not value then return nil end
        number, place = number + value * place, place * base
    end
    return number
end

local function Crunch(number)
    local text = ""
    repeat
        local remain = number % base
        text = text .. NAUTICUS_DIGITS:sub(remain + 1, remain + 1)
        number = (number - remain) / base
    until number == 0
    return text
end

local function Hash(text)
    local counter, length = HASH_START, #text
    for i = 1, length, 3 do
        counter = (counter * HASH_STEP) % HASH_WRAP + text:byte(i) * HASH_FIRST
            + (text:byte(i + 1) or length - i + HASH_PAD) * HASH_SECOND
            + (text:byte(i + 2) or length - i + HASH_PAD) * HASH_THIRD
    end
    return counter % HASH_PRIME
end

local nauticusAsk
do
    local ids = {}
    for id in pairs(named) do
        if id ~= LEGACY_BRAVERY then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for i, id in ipairs(ids) do ids[i] = Crunch(id) end
    local list = table.concat(ids, ",")
    nauticusAsk = NAUTICUS_HEAD .. list .. " " .. Crunch(Hash(list))
end

local function On()
    return S.Get("enabled") == true and S.Get("transportTimers") == true and S.Get("transportShare") == true
end

local function Before(name, start, moment)
    local period = Routes[name].period
    return start + math.floor((moment - start) / period) * period
end

local function HeardForever(message, now)
    local id, index, arrival, observed = message:match(FOREVER_TIMING)
    local name = named[tonumber(id)]
    local dock = name and Routes[name].docks[tonumber(index)]
    if dock then Times.Shared(name, Before(name, tonumber(arrival) - dock.arrive, tonumber(observed)), nil, now) end
end

local function HeardNauticus(message, now)
    local list, hash = message:match(NAUTICUS_TIMING)
    if not list or Uncrunch(hash) ~= Hash(list) then return end
    local _, _, lag = GetNetStats()
    for entry in list:gmatch("[^,]+") do
        local id, since = entry:match(NAUTICUS_ENTRY)
        id, since = Uncrunch(id), Uncrunch(since)
        local name = id ~= LEGACY_BRAVERY and named[id]
        if name and since and since <= NAUTICUS_MAX_SINCE then
            Times.Shared(name, now - ((since + lag) / MS) % Routes[name].period, nil, now)
        end
    end
end

local function Ask(channel)
    if asked[channel] and GetTime() - asked[channel] < ASK_GAP then return end
    asked[channel] = GetTime()
    C_ChatInfo.SendAddonMessage(FOREVER_PREFIX, FOREVER_ASK, channel)
    C_ChatInfo.SendAddonMessage(NAUTICUS_PREFIX, nauticusAsk, channel)
end

local function OnEvent(_, event, prefix, message, channel)
    if event == "CHAT_MSG_ADDON" then
        if issecretvalue(prefix) or issecretvalue(message) or issecretvalue(channel) or not HEARD[channel] then return end
        if prefix == FOREVER_PREFIX then return HeardForever(message, GetServerTime()) end
        if prefix == NAUTICUS_PREFIX then return HeardNauticus(message, GetServerTime()) end
        return
    end
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        Ask(RAID)
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        Ask(PARTY)
    end
    if event == "GROUP_ROSTER_UPDATE" then return end
    if IsInGuild() then Ask(GUILD) end
    local map = C_Map.GetBestMapForUnit(PLAYER)
    if map and docked[SameMap(map)] and not IsInInstance() then Ask(YELL) end
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
            C_ChatInfo.RegisterAddonMessagePrefix(FOREVER_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(NAUTICUS_PREFIX)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        if IsLoggedIn() then OnEvent(nil, "PLAYER_ENTERING_WORLD") end
    elseif events then
        events:UnregisterAllEvents()
    end
end

local function OnSetting(key)
    if key == "enabled" or key == "transportTimers" or key == "transportShare" then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()
