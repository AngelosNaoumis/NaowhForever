-- TransportCalls.lua: times a Zephras Isle skycutter from its dockmaster's arrival call (ns.TransportCalls).
local ns = _G.NaowhForever

local GetServerTime, GetTime = GetServerTime, GetTime
local Times = ns.TransportTimes
local Routes = ns.TransportRoutes
local SameMap = ns.Shared.Places.SameMap

local CALLERS = { [256306] = "1416:Zeppelin to Zephras Isle", [275269] = "2521:Zeppelin to Dalaran" }
local EVENTS = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_BOSS_EMOTE" }
local GUID_ARG = 12
local NPC_ID = "^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"
local ARRIVAL = "arrival"
local QUIET = 5

local Calls = {}
ns.TransportCalls = Calls

local maps, quietUntil = {}, {}
for _, stop in pairs(CALLERS) do maps[ns.TransportData[stop].map] = true end

local events

local function OnEvent(_, _, ...)
    local guid = select(GUID_ARG, ...)
    if not guid or issecretvalue(guid) then return end
    local stop = CALLERS[tonumber(guid:match(NPC_ID))]
    if not stop or quietUntil[stop] and GetTime() < quietUntil[stop] then return end
    local name, index = Times.RouteAt(stop)
    local dock = Routes[name].docks[index]
    quietUntil[stop] = GetTime() + dock.leave - dock.arrive + QUIET
    Times.Record(stop, ARRIVAL, GetServerTime())
end

function Calls.Watch(map)
    local wanted = map ~= nil and maps[SameMap(map)] == true
    if wanted and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    if not events then return end
    for _, event in ipairs(EVENTS) do
        if wanted then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
end
