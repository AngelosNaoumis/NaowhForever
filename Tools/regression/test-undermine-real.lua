-- Run with Lua 5.1 from the repository root: the Undermine Real reminder: the boss list, the daily first kill,
-- what clears the reminder, and how its text is drawn.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local ns = {
    FEATURES = { undermineReal = { enabled = false } },
    UI = { ModuleSettings = function(_, defaults)
        local saved = {}
        return { Get = function(key) if saved[key] ~= nil then return saved[key] end return defaults[key] end,
            Set = function(key, value) saved[key] = value end, OnChange = function() end }
    end },
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

-- The text: "Loot Real", its font from the card, and the side of the icon it sits on.
local function Frame()
    local f = { points = {} }
    function f.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    function f.ClearAllPoints(self) self.points = {} end
    function f.SetSize(self, w, h) self.w, self.h = w, h end
    function f.SetAllPoints() end
    function f.SetTexCoord() end
    function f.SetTexture(self, t) self.texture = t end
    function f.SetText(self, t) self.text = t end
    function f.CreateTexture() return Frame() end
    function f.RegisterEvent() end
    function f.UnregisterAllEvents() end
    function f.SetScript() end
    return f
end
local fonts = {}
ns.THEME = { accentSoft = {} }
ns.L = function(text) return text end
ns.Border = function() end
ns.Font = function() return Frame() end
ns.Shared.Style = { ICON_CROP = 0.07 }
ns.Shared.Parts = { HudFont = function(fs, font, size, outline) fonts[fs] = { font, size, outline } end }
env.CreateFrame = Frame
env.hooksecurefunc = function() end
env.C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
Load("NaowhForever_Utilities/UndermineReal/UI/Reminder.lua")

local S, Look = UR.Settings, UR.Look
local shot = Frame()
Look.New(shot)
Look.Fill(shot)
check("the text is Loot Real", shot.label.text == "Loot Real")
check("the icon is the real's", shot.icon.texture == "icon" .. UR.ITEM)
check("the icon takes its size", shot.w == S.Get("iconSize") and shot.h == S.Get("iconSize"))
check("the text is a size larger than it was", S.Get("undermineRealFontSize") == 16)
local font = fonts[shot.label]
check("the font, size and outline come from the card", font[1] == "" and font[2] == 16 and font[3] == "OUTLINE")
local at = shot.label.points[1]
check("by default the text sits below the icon", #shot.label.points == 1 and at[1] == "TOP" and at[3] == "BOTTOM"
    and at[5] < 0)

local SIDES = { TOP = { "BOTTOM", "TOP" }, LEFT = { "RIGHT", "LEFT" }, RIGHT = { "LEFT", "RIGHT" } }
for side, want in pairs(SIDES) do
    S.Set("undermineRealTextPos", side)
    Look.Fill(shot)
    at = shot.label.points[1]
    check("the text moves to " .. side, #shot.label.points == 1 and at[1] == want[1] and at[3] == want[2])
end
S.Set("undermineRealFontSize", 20)
S.Set("undermineRealOutline", "NONE")
Look.Fill(shot)
check("a new size and outline take", fonts[shot.label][2] == 20 and fonts[shot.label][3] == "NONE")

print(("test-undermine-real: %d checks passed"):format(checks))
