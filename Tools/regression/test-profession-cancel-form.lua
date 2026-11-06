-- Run with Lua 5.1 from the repository root: a druid's craft buttons leave the shapeshift form
-- first. Forever refuses a craft in a form and only secure code may leave one, so a secure
-- /cancelform layer covers each button out of combat and runs the button's click in PostClick.
-- It is lifted off before combat locks it, so the windows are never protected in combat.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local SOURCE = "NaowhForever_Professions/UI/CancelForm.lua"

local frames = {}
local function Frame(parent, template)
    local f = { parent = parent, template = template, shown = true, level = 0, points = {},
        attributes = {}, scripts = {}, events = {} }
    function f:SetParent(p) self.parent = p end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetAllPoints(to) self.points = { to } end
    function f:ClearAllPoints() self.points = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:SetPropagateMouseMotion(on) self.motion = on end
    function f:RegisterEvent(e) self.events[#self.events + 1] = e end
    function f:IsEnabled() return self.enabled ~= false end
    frames[#frames + 1] = f
    return f
end

local state = { class = "WARRIOR", combat = false }
local ui = Frame()
local env = {
    NaowhForever = { Professions = {} },
    CreateFrame = function(_, _, parent, template) return Frame(parent, template) end,
    UnitClass = function() return "Class", state.class end,
    InCombatLockdown = function() return state.combat end,
    UIParent = ui,
}
env._G = env
local fn = assert(loadfile(SOURCE))
setfenv(fn, setmetatable(env, { __index = _G }))
fn()
local Cover = env.NaowhForever.Professions.CancelForm.Cover

local made = #frames
local clicked = 0
local function OnClick() clicked = clicked + 1 end

local warrior = Frame()
Cover(warrior, OnClick)
check("another class gets no layer and no events", #frames == made + 1)

state.class = "DRUID"
local create = Frame()
create.level = 4
made = #frames
Cover(create, OnClick)
local events, layer = frames[made + 1], frames[made + 2]
check("a druid's first button makes one event frame and one layer", #frames == made + 2)
check("it listens for combat starting and ending", #events.events == 2)
check("the layer is secure", layer.template == "SecureActionButtonTemplate")
check("its macro leaves the form", layer.attributes.macrotext == "/cancelform")
check("it acts on the mouse-up only", layer.attributes.useOnKeyDown == false and #layer.clicks == 2)
check("out of combat it sits on its button", layer.parent == create and layer.points[1] == create)
check("above it", layer.level > create.level and layer.shown)
check("hover passes through to the button", layer.motion == true)

layer.scripts.PreClick(layer, "LeftButton", true)
layer.scripts.PostClick(layer, "LeftButton", true)
check("the mouse-down crafts nothing", clicked == 0 and layer.attributes.type == nil)
layer.scripts.PreClick(layer, "LeftButton", false)
check("the mouse-up arms the macro", layer.attributes.type == "macro")
layer.scripts.PostClick(layer, "LeftButton", false)
check("and then runs the button's own click once", clicked == 1)

create.enabled = false
layer.scripts.PreClick(layer, "LeftButton", false)
layer.scripts.PostClick(layer, "LeftButton", false)
check("a disabled button neither leaves the form nor crafts", layer.attributes.type == nil and clicked == 1)
create.enabled = true

local pressed
create.scripts.OnMouseDown = function(self) pressed = self end
layer.scripts.OnMouseDown(layer)
check("the press is shown on the button", pressed == create)

made = #frames
local createAll = Frame()
Cover(createAll, OnClick)
local second = frames[made + 2]
check("a second button reuses the event frame", #frames == made + 2 and second.parent == createAll)

state.combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
check("as combat starts every layer comes off its button",
    layer.parent == ui and not layer.shown and #layer.points == 0
        and second.parent == ui and not second.shown and #second.points == 0)

state.combat = true
made = #frames
local start = Frame()
Cover(start, OnClick)
check("a button covered in combat waits for its layer", #frames == made + 1)

state.combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
local late = frames[made + 2]
check("after combat every layer is back on its button",
    layer.parent == create and layer.shown and layer.points[1] == create
        and second.parent == createAll and second.shown)
check("and the waiting one is made", late and late.parent == start and late.shown)

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end
local detail = Read("NaowhForever_Professions/UI/Detail.lua")
check("Create is covered", detail:find("CancelForm.Cover(create, OnCreate)", 1, true))
check("Create All is covered", detail:find("CancelForm.Cover(win.createAll, OnCreateAll)", 1, true))
check("the Crafting Queue's Start is covered",
    Read("NaowhForever_Professions/UI/CraftQueue.lua"):find("CancelForm.Cover(start, Queue.Click)", 1, true))
local xml = Read("NaowhForever_Professions/Professions.xml")
check("it loads before the buttons it covers",
    xml:find("UI\\CancelForm.lua", 1, true) < xml:find("UI\\Detail.lua", 1, true))

print(checks .. " profession cancel form checks passed")
