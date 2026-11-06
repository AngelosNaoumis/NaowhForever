-- Run with Lua 5.1 from the repository root: the Professions window can be dragged. Until it
-- has been, it opens on Blizzard's window as before; once it has, Blizzard's invisible window is
-- moved to where it was left, never in combat, and this one sits on it. Blizzard's window is never
-- anchored to this one, which would make it protected.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_Professions/UI/Takeover.lua")
local first = assert(source:find("local Drag = {}", 1, true))
local save = assert(source:find("function Drag.Save()", first, true))
local last = assert(source:find("\nend\n", save, true))
local chunk = "local win\n" .. source:sub(first, last + 4)
    .. "return function(w) win = w end, Drag"

local function Frame(name)
    local f = { name = name, points = {}, shown = true }
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:IsShown() return self.shown end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetEffectiveScale() return self.scale or 1 end
    return f
end

local settings, combat = {}, false
local pf, ui, win = Frame("pf"), Frame("UIParent"), Frame("win")
local env = {
    S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end },
    InCombatLockdown = function() return combat end,
    ProfessionsFrame = pf,
    UIParent = ui,
}
env._G = env
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local SetWin, Drag = fn()
SetWin(win)
local Follow, PlaceWindow, SavePosition = Drag.Follow, Drag.Place, Drag.Save
local function Pending() return Drag.pending end

-- Never dragged: on Blizzard's window, and Blizzard's window is left to the panel manager.
PlaceWindow()
check("undragged window sits on Blizzard's", win.points[1][2] == pf and win.points[1][1] == "TOPLEFT")
Follow()
check("undragged leaves Blizzard's window alone", #pf.points == 0)

-- Dragged: the position is kept, Blizzard's window moves there and the window sits on it.
win.left, win.top = 300, 700
SavePosition()
check("position saved", settings.windowPos.x == 300 and settings.windowPos.y == 700)
Follow()
check("Blizzard's window moved to the position",
    #pf.points == 1 and pf.points[1][2] == ui and pf.points[1][4] == 300 and pf.points[1][5] == 700)
check("window sits on Blizzard's", #win.points == 1 and win.points[1][2] == pf)

-- Blizzard's window at another scale is placed in its own units.
pf.scale, win.scale = 0.5, 1
Follow()
check("scaled position", pf.points[1][4] == 600 and pf.points[1][5] == 1400)
pf.scale = nil

-- In combat nothing moves; the pin waits for combat to end.
pf.points = { { "TOPLEFT", ui, "TOPLEFT", 16, -116 } }
combat = true
Follow()
check("no move in combat", pf.points[1][2] == ui)
check("move queued", Pending())
combat = false
Follow()
check("moved after combat", pf.points[1][4] == 300 and not Pending())
check("window back on Blizzard's after combat", win.points[1][2] == pf)

-- EllesmereUI's Shifter re-places Blizzard's window at its saved spot on every SetPoint, so the
-- dragged spot is written there too; with Shifter off its positions are left alone.
env.EllesmereUIDB = { shifterEnabled = false }
Follow()
check("Shifter off untouched", env.EllesmereUIDB.shifterPositions == nil)
env.EllesmereUIDB = { shifterEnabled = true, shifterPositions = { ProfessionsFrame = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 } } }
Follow()
local shifted = env.EllesmereUIDB.shifterPositions.ProfessionsFrame
check("Shifter spot follows the drag", shifted.point == "TOPLEFT" and shifted.relPoint == "BOTTOMLEFT"
    and shifted.x == 300 and shifted.y == 700)
env.EllesmereUIDB = { shifterEnabled = true }
Follow()
check("Shifter spot written when it had none", env.EllesmereUIDB.shifterPositions.ProfessionsFrame.x == 300)
env.EllesmereUIDB = nil

-- A hidden window (module off, or a profession it does not show) does not pull Blizzard's.
pf.points = { { "TOPLEFT", ui, "TOPLEFT", 16, -116 } }
win.shown = false
Follow()
check("hidden window leaves Blizzard's alone", pf.points[1][2] == ui)

-- With the overview docked the window is protected, so StopMovingOrSizing is blocked in combat.
-- A drag tried in combat is neither started nor stopped, and one still going on the protected
-- window when combat starts is ended on PLAYER_REGEN_DISABLED, which fires before the lockdown.
local stop = assert(source:find("local function OnDragStop(self)", first, true))
local stopEnd = assert(source:find("\nend\n", stop, true))
local dragFn = assert(loadstring("local win, tabsLeft\n" .. source:sub(first, stopEnd + 4)
    .. "return function(w) win = w end, Drag, OnDragStart, OnDragStop"))
setfenv(dragFn, getfenv(fn))
local SetDragWin, DragState, OnDragStart, OnDragStop = dragFn()
local moves, stops = 0, 0
function win:StartMoving() moves = moves + 1 end
function win:StopMovingOrSizing() stops = stops + 1 end
SetDragWin(win)
win.shown = true
combat = true
OnDragStart(win)
OnDragStop(win)
check("a drag tried in combat is not started", moves == 0)
check("a drag tried in combat is not stopped", stops == 0)
combat = false
OnDragStart(win)
check("a drag out of combat starts", moves == 1 and DragState.moving)
OnDragStop(win)
check("the drag is stopped once", stops == 1 and not DragState.moving)
OnDragStop(win)
check("a second stop does nothing", stops == 1)
check("combat start is listened for", source:match("local EVENTS = (%b{})"):find('"PLAYER_REGEN_DISABLED"', 1, true))

local onEvent = assert(source:find("local function OnEvent(", 1, true))
local onEventEnd = assert(source:find("\nend\n", onEvent, true))
local eventFn = assert(loadstring(source:sub(onEvent, onEventEnd + 4) .. "return OnEvent"))
local protected, ended, queued = true, 0, 0
setfenv(eventFn, setmetatable({
    ns = { ProfBagChanges = 0 }, waiting = {}, QUIET = {}, REREAD = {}, W = {}, hooked = true,
    win = { IsShown = function() return true end, IsProtected = function() return protected end },
    Drag = { moving = true },
    OnDragStop = function() ended = ended + 1 end,
    Queue = function() queued = queued + 1 end,
}, { __index = _G }))
local OnEvent = eventFn()
OnEvent(nil, "PLAYER_REGEN_DISABLED")
check("combat start ends a drag on the protected window", ended == 1 and queued == 0)
protected = false
OnEvent(nil, "PLAYER_REGEN_DISABLED")
check("a drag on an unprotected window carries on into combat", ended == 1 and queued == 0)

print(("profession window drag: %d checks passed"):format(checks))
