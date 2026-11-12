-- Run with Lua 5.1 from the repository root: Shift + drag on Blizzard's auction house. The drag needs Shift and The
-- Market on; the spot is kept account-wide and out of the game's layout cache, and put back each time the panel
-- manager places the window, but not mid-drag, with the window closed or with The Market off. The window is kept on
-- the screen, so a spot saved at another resolution or UI scale cannot lose it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local screen = {}
local ah = { shown = false, scripts = {}, point = { "TOPLEFT", screen, "TOPLEFT", 36, -116 }, placed = 0 }
function ah:IsShown() return self.shown end
function ah:SetClampedToScreen(on) self.clamped = on end
function ah:RegisterForDrag(button) self.drag = button end
function ah:HookScript(name, fn) self.scripts[name] = fn end
function ah:SetMovable(on) self.movable = on end
function ah:StartMoving() self.moving = true end
function ah:StopMovingOrSizing() self.moving, self.userPlaced = false, true end
function ah:SetUserPlaced(on) self.userPlaced = on end
function ah:ClearAllPoints() self.point = nil end
function ah:SetPoint(...) self.point, self.placed = { ... }, self.placed + 1 end
function ah:GetPoint() return unpack(self.point) end

local function Blizzard() ah.point = { "TOPLEFT", screen, "TOPLEFT", 36, -116 } end
local function At(point, x, y)
    local p = ah.point
    return p[1] == point and p[2] == screen and p[3] == point and p[4] == x and p[5] == y
end

local account, on, shift, fits = {}, true, false, 0
local ns = {
    AccountSettings = function() return account end,
    Market = { On = function() return on end, Window = { FitDock = function() fits = fits + 1 end } },
}
local env
env = setmetatable({
    _G = { NaowhForever = ns },
    UIParent = screen,
    IsShiftKeyDown = function() return shift end,
    ShowUIPanel = Blizzard,
    HideUIPanel = Blizzard,
    UpdateUIPanelPositions = Blizzard,
    hooksecurefunc = function(name, fn)
        local old = env[name]
        env[name] = function(...) old(...); fn(...) end
    end,
}, { __index = _G })
local fn = assert(loadfile("NaowhForever_Market/UI/Move.lua"))
setfenv(fn, env)
fn()
local Move = ns.Market.Move

Move.Hook(ah)
check("Blizzard's window takes a left-button drag", ah.drag == "LeftButton" and ah.scripts.OnDragStart == Move.Start
    and ah.scripts.OnDragStop == Move.Stop)
check("and is kept on the screen", ah.clamped == true)

ah.shown = true
env.ShowUIPanel()
check("never moved, it stays where the panel manager puts it", At("TOPLEFT", 36, -116) and ah.placed == 0)
check("and what is docked is fitted to it", fits == 1)

ah.scripts.OnDragStart(ah)
check("a drag without Shift moves nothing", not ah.moving)
shift = true
ah.scripts.OnDragStart(ah)
check("Shift + drag moves it", ah.moving and ah.movable)
env.UpdateUIPanelPositions()
check("a panel placed mid-drag does not pull it from the cursor", ah.placed == 0)
ah.point = { "RIGHT", screen, "RIGHT", -200, 40 }
ah.scripts.OnDragStop(ah)
local saved = account.marketAuctionHouse
check("the spot is kept for the account", saved and saved[1] == "RIGHT" and saved[2] == "RIGHT" and saved[3] == -200
    and saved[4] == 40)
check("and kept out of the game's layout cache", ah.moving == false and ah.userPlaced == false)
ah.scripts.OnDragStop(ah)
check("a drag that never started saves nothing", account.marketAuctionHouse == saved)

env.ShowUIPanel()
check("another panel opening puts it back on its spot", At("RIGHT", -200, 40))
env.HideUIPanel()
check("and one closing", At("RIGHT", -200, 40))
env.UpdateUIPanelPositions()
check("and the panel manager placing them again", At("RIGHT", -200, 40))

ah.shown = false
local placed = ah.placed
env.ShowUIPanel()
check("closed, it is left alone", ah.placed == placed)

ah.shown, on = true, false
env.ShowUIPanel()
check("with The Market off it is back where Blizzard puts it", At("TOPLEFT", 36, -116) and ah.placed == placed)
ah.scripts.OnDragStart(ah)
check("and does not drag", not ah.moving)

print(("test-market-move: %d checks passed"):format(checks))
