-- Run with Lua 5.1 from the repository root: Lockpicking Skill (NaowhForever_QoL/Loot/Lockboxes.lua).
-- A lockbox's tooltip gets the game's "Requires Lockpicking (N)" line: yellow without the skill, red below the
-- lock's skill, green at or above it, a modifier counting. The skill is named by the rogue's own skill line, else
-- the game's skill line name, else the catalog's "Lockpicking" when both are empty, read with the skill and never
-- per tooltip. Off by default, it hooks no tooltip and listens to
-- nothing until it is switched on; switched off again it stops listening and its hook adds nothing.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local frames, hooks, skillReads, nameReads = {}, 0, 0, 0
local tooltipHook, setHook, boot, card
local skill
local displayName = "Game Lockpicking"

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event)
        f.events[event] = true
        if event == "PLAYER_LOGIN" then boot = f end
    end,
    UnregisterAllEvents = function(f) f.events = {} end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local function CreateFrame()
    local f = setmetatable({ events = {} }, frameMeta)
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true, lockboxSkill = false }
local S = { Get = function(k) return settings[k] end, Set = Noop }
local YELLOW, RED, GREEN = { r = 1, g = 0.8, b = 0 }, { r = 1, g = 0.2, b = 0.2 }, { r = 0.3, g = 0.8, b = 0.4 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    QoLSettings = S,
    Apply = Noop,
    Shared = {
        Style = { TIME_LOW_RGB = YELLOW, TIME_OUT_RGB = RED, HAVE_RGB = GREEN },
        Settings = { Page = function(page)
            return { Card = function(_, spec) spec.page = page; card = spec end }
        end },
    },
}

local secret = {}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = CreateFrame,
    ITEM_MIN_SKILL = "Requires %s (%d)",
    issecretvalue = function(value) return value == secret end,
    C_SkillInfo = { GetSkillLineInfoByID = function(id)
        skillReads = skillReads + 1
        if id ~= 633 or not skill then return nil end
        return { skillID = id, name = skill.name, rank = skill.rank, modifier = skill.modifier, maxRank = 300 }
    end },
    C_TradeSkillUI = { GetTradeSkillDisplayName = function(id)
        nameReads = nameReads + 1
        return id == 633 and displayName or ""
    end },
    Enum = { TooltipDataType = { Item = 0 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        if kind == 0 then
            hooks = hooks + 1
            tooltipHook = fn
        end
    end },
    hooksecurefunc = function(target, name, fn)
        if target == S and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({ "NaowhForever_QoL/Loot/LockboxData.lua", "NaowhForever_QoL/Loot/Lockboxes.lua" }, env)

local function Events()
    for _, f in ipairs(frames) do
        if f ~= boot then return f end
    end
end

local tooltip = { added = {} }
function tooltip.AddLine(self, text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end

local function Hover(data)
    tooltip.added = {}
    if tooltipHook then tooltipHook(tooltip, data) end
    return tooltip.added
end

local function Is(line, c) return line ~= nil and line.r == c.r and line.g == c.g and line.b == c.b end

local STEEL, IRON, JEWELS, LINEN = 4637, 4634, 12033, 2589

check("its card joins the Loot & Items card", card and card.page == "QoL/Loot & Items" and card.into == "lootTrade")
local row = card.rows[1]
check("as one toggle on lockboxSkill", #card.rows == 1 and row.key == "lockboxSkill" and row.toggle)
check("with one short sentence of help", #row.help < 100 and not row.help:find("%.%s"))

boot.OnEvent(boot, "PLAYER_LOGIN")
check("logging in with it off hooks no tooltip", tooltipHook == nil and hooks == 0)
check("builds nothing past its login frame", #frames == 1)
check("and reads no skill", skillReads == 0)

settings.lockboxSkill = true
setHook("lockboxSkill")
local events = Events()
check("switching it on hooks item tooltips once", hooks == 1 and tooltipHook ~= nil)
check("and listens for skill changes", events and events.events.SKILL_LINES_CHANGED == true)

local added = Hover({ id = STEEL })
check("a Steel Lockbox says the Lockpicking it needs, in the game's name for the skill",
    #added == 1 and added[1].text == "Requires Game Lockpicking (175)")
check("in yellow without Lockpicking", Is(added[1], YELLOW))
local reads = nameReads
Hover({ id = STEEL })
Hover({ id = IRON })
check("the name is not looked up again per tooltip", nameReads == reads)

displayName = ""
events.OnEvent(events, "SKILL_LINES_CHANGED")
added = Hover({ id = STEEL })
check("an empty game name falls back to the catalog's Lockpicking", added[1].text == "Requires Lockpicking (175)")
check("still yellow", Is(added[1], YELLOW))

skill = { rank = 150, modifier = 0, name = "" }
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("an empty skill line name falls back too", Hover({ id = STEEL })[1].text == "Requires Lockpicking (175)")
displayName = "Game Lockpicking"
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("to the game's name when it has one", Hover({ id = STEEL })[1].text == "Requires Game Lockpicking (175)")

skill = { rank = 150, modifier = 0, name = "Lockpicking" }
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("red at Lockpicking 150", Is(Hover({ id = STEEL })[1], RED))
check("an Iron Lockbox (70) is green at 150", Is(Hover({ id = IRON })[1], GREEN))
check("Thaurissan Family Jewels need 275, named by the rogue's own skill line",
    Hover({ id = JEWELS })[1].text == "Requires Lockpicking (275)")

skill = { rank = 170, modifier = 5, name = "Lockpicking" }
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("a modifier counts: 170 plus 5 opens 175", Is(Hover({ id = STEEL })[1], GREEN))

check("an item without a lock gets no line", #Hover({ id = LINEN }) == 0)
check("nor a secret ID", #Hover({ id = secret }) == 0)
check("nor a tooltip without data", #Hover(nil) == 0 and #Hover({}) == 0)

settings.lockboxSkill = false
setHook("lockboxSkill")
check("switching it off stops listening", next(events.events) == nil)
check("and the hook adds nothing", #Hover({ id = STEEL }) == 0)

settings.lockboxSkill = true
setHook("lockboxSkill")
check("switching it on again listens again", events.events.SKILL_LINES_CHANGED == true)
check("without hooking the tooltip twice or building again", hooks == 1 and #frames == 2)

settings.enabled = false
setHook("enabled")
check("QoL off: no events", next(events.events) == nil)
check("and no tooltip line", #Hover({ id = STEEL }) == 0)

for id, need in pairs(ns.LockboxSkills) do
    check(id .. " needs a skill a rogue can reach", type(need) == "number" and need >= 1 and need <= 300)
end

local f = assert(io.open("Core/Features.lua", "rb"))
local features = f:read("*a"); f:close()
check("Lockpicking Skill is off by default", features:find("\n%s*lockboxSkill = false,") ~= nil)

print(("test-lockboxes: %d checks passed"):format(checks))
