-- Run with Lua 5.1 from the repository root: Skip Grey Quests. While it is on, Accept Quests and Pick Quests
-- From NPCs leave grey quests alone and pick the first quest on offer that is not grey; hand-ins are unchanged.
-- While it is off, nothing changes and the grey flags are never asked for.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local features = { L = dofile("Tools/regression/locale_stub.lua").L }
_G.NaowhForever = features
assert(loadstring(Read("Core/Features.lua"), "Features"))()
check("Skip Grey Quests is off by default", features.FEATURES.qol.questSkipGrey == false)

local settings = {
    enabled = true, questAccept = true, questTurnIn = true, questGossip = true, questShare = false,
    questRewardPicks = false, questSkipGrey = false, questSkipModifier = "ALT", questModifierMode = "SKIP",
    gossipAuto = false,
}
local calls, asked
local activeQuests, availableQuests, greeting, greetingActive = {}, {}, {}, {}
local questID, trivialIDs, autoAccept = 1, {}, false

local frames = {}
local function Frame()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

local S = { Get = function(key) return settings[key] end, DB = function() return {} end }
local function Log(name) return function(...) calls[#calls + 1] = { name, ... } end end
local ns = { L = features.L, Upper = string.upper, Lower = string.lower, QoLSettings = S, Print = function() end, cards = {} }
ns.Shared = { Settings = { Page = function()
    return { Card = function(_, card) ns.cards[#ns.cards + 1] = card end }
end } }

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    hooksecurefunc = function() end,
    IsAltKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    IsShiftKeyDown = function() return false end,
    InCombatLockdown = function() return false end,
    IsInGroup = function() return false end,
    UnitIsPlayer = function() return false end,
    UnitClass = function() return "Druid", "DRUID" end,
    GetQuestID = function() return questID end,
    QuestGetAutoAccept = function() return autoAccept end,
    AcceptQuest = Log("AcceptQuest"),
    CloseQuest = Log("CloseQuest"),
    ConfirmAcceptQuest = Log("ConfirmAcceptQuest"),
    StaticPopup_Hide = function() end,
    IsQuestCompletable = function() return true end,
    GetQuestMoneyToGet = function() return 0 end,
    CompleteQuest = Log("CompleteQuest"),
    GetNumQuestChoices = function() return 0 end,
    GetQuestReward = Log("GetQuestReward"),
    GetNumActiveQuests = function() return #greetingActive end,
    GetActiveTitle = function(i) return "Active " .. i, greetingActive[i] end,
    SelectActiveQuest = Log("SelectActiveQuest"),
    GetNumAvailableQuests = function() return #greeting end,
    GetAvailableQuestInfo = function(i)
        asked = asked + 1
        return greeting[i]
    end,
    SelectAvailableQuest = Log("SelectAvailableQuest"),
    C_QuestLog = { IsQuestTrivial = function(id)
        asked = asked + 1
        return trivialIDs[id] == true
    end },
    C_GossipInfo = {
        GetActiveQuests = function() return activeQuests end,
        GetAvailableQuests = function() return availableQuests end,
        GetOptions = function() return {} end,
        SelectActiveQuest = Log("GossipActive"),
        SelectAvailableQuest = Log("GossipAvailable"),
    },
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/QuestAutomation.lua"))
setfenv(chunk, env)
chunk()

local events = frames[1]
local function Fire(event, ...)
    calls, asked = {}, 0
    events.onEvent(events, event, ...)
    return calls
end
local function Only(name)
    return #calls == 1 and calls[1][1] == name and (calls[1][2] or true)
end

availableQuests = { { questID = 11, isTrivial = true }, { questID = 12, isTrivial = false } }
greeting = { true, false }
trivialIDs = { [21] = true }

Fire("GOSSIP_SHOW")
check("off: the first gossip quest is opened, grey or not", Only("GossipAvailable") == 11)
check("off: the gossip grey flag is never read", asked == 0)
Fire("QUEST_GREETING")
check("off: the first greeting quest is opened, grey or not", Only("SelectAvailableQuest") == 1)
check("off: GetAvailableQuestInfo is never asked", asked == 0)
questID = 21
Fire("QUEST_DETAIL")
check("off: a grey quest is accepted as its text opens", Only("AcceptQuest"))
check("off: IsQuestTrivial is never asked", asked == 0)

settings.questSkipGrey = true
Fire("GOSSIP_SHOW")
check("on: the first gossip quest that is not grey is opened", Only("GossipAvailable") == 12)
Fire("QUEST_GREETING")
check("on: the first greeting quest that is not grey is opened", Only("SelectAvailableQuest") == 2)
Fire("QUEST_DETAIL")
check("on: a grey quest is left open for the player", #calls == 0 and asked == 1)
autoAccept = true
Fire("QUEST_DETAIL")
check("on: a grey quest the game accepted by itself keeps its window", #calls == 0)
questID = 22
Fire("QUEST_DETAIL")
check("on: a quest that is not grey is still accepted", Only("CloseQuest"))
autoAccept = false
Fire("QUEST_DETAIL")
check("on: and accepted by the addon when the game did not", Only("AcceptQuest"))

availableQuests = { { questID = 11, isTrivial = true }, { questID = 13, isTrivial = true } }
greeting = { true, true }
Fire("GOSSIP_SHOW")
check("on: an NPC with only grey quests is left alone", #calls == 0)
Fire("QUEST_GREETING")
check("on: a greeting with only grey quests is left alone", #calls == 0)

activeQuests = { { questID = 31, isComplete = true } }
Fire("GOSSIP_SHOW")
check("on: a finished quest is still handed in from gossip", Only("GossipActive") == 31)
greetingActive = { true }
Fire("QUEST_GREETING")
check("on: and from a greeting", Only("SelectActiveQuest") == 1)
questID = 21
Fire("QUEST_PROGRESS")
check("on: a grey quest's progress step still continues", Only("CompleteQuest"))
Fire("QUEST_COMPLETE")
check("on: and its reward is still taken", Only("GetQuestReward"))
activeQuests, greetingActive = {}, {}

settings.questAccept = false
availableQuests = { { questID = 12, isTrivial = false } }
Fire("GOSSIP_SHOW")
check("Accept Quests off: nothing is opened, Skip Grey Quests or not", #calls == 0)
Fire("QUEST_DETAIL")
check("Accept Quests off: nothing is accepted and no grey flag is read", #calls == 0 and asked == 0)
settings.questAccept = true

local row, before
for _, card in ipairs(ns.cards) do
    for i, r in ipairs(card.rows) do
        if r.key == "questSkipGrey" then row, before = r, card.rows[i - 1] end
    end
end
check("the Quests card has the Skip Grey Quests toggle", row and row.toggle and row.label == "Skip Grey Quests")
check("it sits beside Pick Quests From NPCs", before and before.key == "questGossip")
check("it waits for Accept Quests", row.needs == "questAccept")
check("its help is one short sentence", #row.help < 100 and not row.help:find("%. %u"))

print(("quest skip grey: %d checks passed"):format(checks))
