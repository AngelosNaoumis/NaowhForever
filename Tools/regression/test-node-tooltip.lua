-- Run with Lua 5.1 from the repository root: Minimap Node Tooltips (NodeScan.lua, UI/NodeTooltip.lua).
-- Hovering a herb or vein on the minimap adds the skill it needs to the game's tooltip: red below it, then
-- in its skill-up colour, a gear bonus counting, each line named when two nodes are under the mouse. It never
-- drives the minimap itself, as Forever stopped answering a probe away from the real cursor. Switched off it
-- adds nothing and listens to nothing, and on a client whose node names are not English it stays off. The
-- data table matches Glimmer's herbs and veins, name for name and skill for skill.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local locale = "enUS"
local tooltipHook, setHook, boot
local hooks, minimapCalls = 0, 0
local frames = {}

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

local Minimap = setmetatable({}, { __index = function()
    return function() minimapCalls = minimapCalls + 1 end
end })

local profession = { herb = nil, ore = 50, oreBonus = 0 }
local settings = { enabled = true, nodeIcons = true }
local RED = { r = 1, g = 0.3, b = 0.3 }
local ORANGE, YELLOW = { r = 1, g = 0.5, b = 0.25 }, { r = 1, g = 1, b = 0 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    Apply = Noop,
    Professions = {
        Settings = { Get = function(k) return settings[k] end, Set = Noop },
        Style = {
            RED_RGB = RED,
            DIFFICULTY_RGB = { [0] = ORANGE, [1] = YELLOW, [2] = { r = 0.25, g = 0.75, b = 0.25 },
                [3] = { r = 0.55, g = 0.55, b = 0.55 } },
        },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    Minimap = Minimap,
    CreateFrame = CreateFrame,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    GetLocale = function() return locale end,
    GetProfessions = function() return profession.ore and 1 or nil, profession.herb and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, profession.ore, 300, nil, nil, 186, profession.oreBonus end
        return "Herbalism", nil, profession.herb, 300, nil, nil, 182, 0
    end,
    Enum = { TooltipDataType = { MinimapMouseover = 22 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn)
        hooks = hooks + 1
        tooltipHook = fn
    end },
    hooksecurefunc = function(target, name, fn)
        if target == ns.Professions.Settings and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeTooltip.lua",
}, env)

local function Events()
    for _, f in ipairs(frames) do
        if f ~= boot and f.events.SKILL_LINES_CHANGED then return f end
    end
end

boot.OnEvent(boot, "PLAYER_LOGIN")
local events = Events()
check("logging in with it on hooks the minimap tooltip", tooltipHook ~= nil and hooks == 1)
check("and listens for skill changes", events ~= nil and events.events.PLAYER_ENTERING_WORLD == true)

local tooltip = { added = {}, shown = 0 }
function tooltip.AddLine(self, text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end
function tooltip.Show(self) self.shown = self.shown + 1 end

local function Hover(...)
    local lines = {}
    for i = 1, select("#", ...) do lines[i] = { leftText = select(i, ...) } end
    tooltip.added, tooltip.shown = {}, 0
    tooltipHook(tooltip, { lines = lines })
    return tooltip.added
end

local function Is(line, c) return line ~= nil and line.r == c.r and line.g == c.g and line.b == c.b end

local added = Hover("Tin Vein")
check("hovering Tin Vein says the Mining it needs", added[1] and added[1].text == "Requires Mining 65")
check("in red, as Mining 50 is too low", Is(added[1], RED))
check("and the tooltip is redrawn to fit it", tooltip.shown == 1)

added = Hover("|cffffffffCopper Vein|r")
check("a coloured name is read", added[1] and added[1].text == "Requires Mining 1")
check("Copper Vein (1) at Mining 50 is yellow", Is(added[1], YELLOW))

profession.oreBonus = 20
events.OnEvent(events, "SKILL_LINES_CHANGED")
check("a Mining bonus counts: Tin Vein (65) is orange at 50 plus 20", Is(Hover("Tin Vein")[1], ORANGE))
profession.oreBonus = 0
events.OnEvent(events, "SKILL_LINES_CHANGED")

added = Hover("Copper Vein\nPeacebloom")
check("two nodes under the mouse each name their own need", #added == 2
    and added[1].text == "Copper Vein: Requires Mining 1"
    and added[2].text == "Peacebloom: Requires Herbalism 1")
check("Peacebloom is red with no Herbalism", Is(added[2], RED))
added = Hover("Tin Vein", "Tin Vein")
check("the same node twice is one unnamed line", #added == 1 and added[1].text == "Requires Mining 65")
added = Hover("Kobold Tunneler")
check("a creature on the minimap gets no skill line", #added == 0 and tooltip.shown == 0)
check("it never drives the minimap itself", minimapCalls == 0)

settings.nodeIcons = false
setHook("nodeIcons")
check("turning it off stops every event", next(events.events) == nil)
check("and the tooltip line", #Hover("Tin Vein") == 0)
settings.nodeIcons = true
setHook("nodeIcons")
check("turning it on again listens again", events.events.SKILL_LINES_CHANGED == true)
check("without hooking the tooltip twice", hooks == 1)
check("and the line is back", #Hover("Tin Vein") == 1)

settings.enabled = false
setHook("enabled")
check("Professions off: no events", next(events.events) == nil)
check("and no tooltip line", #Hover("Tin Vein") == 0)
settings.enabled = true
setHook("enabled")

locale = "deDE"
tooltipHook = nil
local built = #frames
Load({ "NaowhForever_Professions/NodeScan.lua", "NaowhForever_Professions/UI/NodeTooltip.lua" }, env)
boot.OnEvent(boot, "PLAYER_LOGIN")
check("a German client cannot read the English node names", ns.Professions.NodeScan.Usable() == false)
check("so even switched on it hooks nothing", tooltipHook == nil)
check("and builds nothing past its login frame", #frames == built + 1)
locale = "enGB"
check("a British client reads them", ns.Professions.NodeScan.Usable() == true)

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local nodes = ns.Professions.GatherNodes
for name, node in pairs(nodes) do
    check(name .. " is a herb or vein", node[1] == "herb" or node[1] == "ore")
    check(name .. " needs a skill", type(node[2]) == "number" and node[2] >= 1)
    check(name .. " has an item or none", node[3] == nil or type(node[3]) == "number")
end
local glimmer = Read("NaowhForever_QoL/Glimmer/Data/Nodes.lua")
local listed = 0
for kind, need, name in glimmer:gmatch('{ "(%a+)", (%d+), "([^"]+)" }') do
    if kind == "herb" or kind == "ore" then
        listed = listed + 1
        check(name .. " from Glimmer is in GatherNodes", nodes[name] ~= nil)
        check(name .. " needs the same skill as in Glimmer", nodes[name][2] == tonumber(need)
            and nodes[name][1] == kind)
    end
end
check("Glimmer's herbs and veins were read", listed > 50)

local features = Read("Core/Features.lua")
check("Minimap Node Tooltips is off by default", features:find("\n%s*nodeIcons = false,") ~= nil)

print(("test-node-tooltip: %d checks passed"):format(checks))
