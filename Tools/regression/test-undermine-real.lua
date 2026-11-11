-- Run with Lua 5.1 from the repository root: the Undermine Real reminder: the boss list, the daily first kill, and
-- what clears the reminder.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local ns = {
    FEATURES = { undermineReal = { enabled = false } },
    UI = { ModuleSettings = function(_, defaults) return { Get = function(key) return defaults[key] end } end },
    Shared = {},
}
local mine = {}
ns.Shared.CharacterData = function() return mine end

local now, untilReset = 1000, 3600
local env = setmetatable({
    _G = { NaowhForever = ns },
    time = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    C_DateAndTime = { GetSecondsUntilDailyReset = function() return untilReset end },
}, { __index = _G })

local function Load(path)
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn()
end

Load("NaowhForever_Utilities/UndermineReal/UndermineReal.lua")
Load("NaowhForever_Utilities/UndermineReal/Data/Bosses.lua")
local UR = ns.UndermineReal

check("the reminder starts off", ns.FEATURES.undermineReal.enabled == false)
check("the item is the Tarnished Undermine Real", UR.ITEM == 226404)

local count, npcs = 0, {}
for encounter, npc in pairs(UR.BOSSES) do
    count = count + 1
    check("an encounter and an NPC are numbers", type(encounter) == "number" and type(npc) == "number")
    check("no NPC is listed twice", not npcs[npc])
    npcs[npc] = true
end
check("56 bosses are listed", count == 56)

-- Every listed boss is the journal's boss for that encounter.
local FILES = { "BlackrockDepths", "LowerBlackrockSpire", "UpperBlackrockSpire", "DireMaul", "Scholomance", "Stratholme" }
local journal = {}
for _, file in ipairs(FILES) do
    local text = Read("NaowhForever_DungeonJournal/Data/Dungeons/" .. file .. ".lua")
    for line in text:gmatch("[^\n]+") do
        local npc, encounter = line:match("npc = (%d+), name = \"[^\"]+\".-encounters = { (%d+)")
        if npc then journal[tonumber(encounter)] = tonumber(npc) end
    end
end
for encounter, npc in pairs(UR.BOSSES) do
    check("encounter " .. encounter .. " is NPC " .. npc .. " in the journal", journal[encounter] == npc)
end

check("an unlisted encounter is ignored", UR.Killed(1, "Nobody") == false and UR.Name() == nil)

check("a listed boss's first kill of the day starts the reminder", UR.Killed(234, "Fineous Darkvire") == true)
check("it names the boss", UR.Name() == "Fineous Darkvire")
check("the kill is kept until the daily reset", mine.got[234] == now + untilReset)

UR.Clear()
check("clearing ends the reminder", UR.Name() == nil)
check("a second kill the same day does not start it", UR.Killed(234, "Fineous Darkvire") == false and UR.Name() == nil)

now = now + untilReset
check("after the daily reset the boss counts again", UR.Killed(234, "Fineous Darkvire") == true)
check("an old day's kills are dropped", next(mine.got) == 234 and mine.got[234] == now + untilReset)

check("looting another boss leaves the reminder", UR.Looted(npcs[9017] and 9017 or 0) == false and UR.Name() ~= nil)
check("looting the boss ends it", UR.Looted(UR.BOSSES[234]) == true and UR.Name() == nil)

print(("test-undermine-real: %d checks passed"):format(checks))
