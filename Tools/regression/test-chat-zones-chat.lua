-- Run with Lua 5.1 from the repository root: Chat Zones' Zones in Chat switch. With the card on
-- and Zones in Chat off, the Group Finder zones still run but nothing touches chat: no message
-- filters, no [Where?] link handler, no guild roster refresh on guild chat.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local values = { enabled = true, chatZones = true, chatZonesChat = false, chatZonesFinder = true,
    chatZonesMaxAge = 15 }
local S = {}
function S.Get(key) return values[key] end
function S.Set(key, value) values[key] = value end

local function Hook(owner, name, after)
    if type(owner) == "string" then return end
    local before = owner[name]
    owner[name] = function(...)
        before(...)
        after(...)
    end
end

local card
local ns = {
    QoLSettings = S,
    QoLConstants = { SECONDS_PER_MINUTE = 60 },
    L = function(s) return s end,
    GamepadStandDown = function() return false end,
    Apply = function() end,
    Shared = { Settings = {
        Group = function(name) return { group = name } end,
        Page = function() return { Card = function(_, c) card = c end } end,
    } },
}

local filters, callbacks, frames = {}, {}, {}
local function Frame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() for event in pairs(self.events) do self.events[event] = nil end end
    function frame:SetScript(_, fn) self.script = fn end
    frames[#frames + 1] = frame
    return frame
end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    hooksecurefunc = Hook,
    ChatFrameUtil = {
        AddMessageEventFilter = function(event) filters[event] = true end,
        RemoveMessageEventFilter = function(event) filters[event] = nil end,
    },
    EventRegistry = {
        RegisterCallback = function(_, event) callbacks[event] = true end,
        UnregisterCallback = function(_, event) callbacks[event] = nil end,
    },
    C_ChatInfo = { RegisterAddonMessagePrefix = function() end },
    C_LFGList = { GetSearchResultPlayerInfo = function() end },
    C_FriendList = { GetNumFriends = function() return 0 end },
    BNGetNumFriends = function() return 0 end,
    GetNumGroupMembers = function() return 0 end,
    IsInGuild = function() return false end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
}, { __index = _G })
env._G = env
local fn = assert(loadstring(Read("NaowhForever_QoL/Interface/ChatZones.lua"), "ChatZones"))
setfenv(fn, env)
fn()

local events = frames[1].events
local function Filtered()
    return filters.CHAT_MSG_CHANNEL and filters.CHAT_MSG_GUILD and filters.CHAT_MSG_OFFICER
        and filters.CHAT_MSG_WHISPER
end
local function Untouched()
    return next(filters) == nil and not callbacks.SetItemRef and not events.CHAT_MSG_GUILD
        and not events.CHAT_MSG_OFFICER
end

ns.Apply()
check("the card on with Zones in Chat off reads the Group Finder", events.LFG_LIST_SEARCH_RESULTS_RECEIVED)
check("and leaves chat alone", Untouched())

S.Set("chatZonesChat", true)
check("Zones in Chat on filters every tagged channel", Filtered())
check("and listens for [Where?] clicks and guild chat",
    callbacks.SetItemRef and events.CHAT_MSG_GUILD and events.CHAT_MSG_OFFICER)

S.Set("chatZonesChat", false)
check("turning it off removes the filters and listeners", Untouched())
check("and keeps the Group Finder going", events.LFG_LIST_SEARCH_RESULTS_RECEIVED)

S.Set("chatZonesChat", true)
S.Set("chatZones", false)
check("the card off stops everything, Zones in Chat or not", Untouched() and next(events) == nil)

local chatOnly = { chatZonesLevel = true, chatZonesClassColour = true, chatZonesWhere = true, chatZonesAsk = true }
for _, row in ipairs(card.rows) do
    if chatOnly[row.key] then
        check(row.key .. " needs Zones in Chat", row.needs == "chatZonesChat")
        chatOnly[row.key] = nil
    end
end
check("every chat-only row was found", next(chatOnly) == nil)

print(("chat zones chat: %d checks passed"):format(checks))
