-- Move.lua: Shift + drag moves Blizzard's auction house, and the panel docked to it, and keeps it where you left it (Market.Move).
local ns = _G.NaowhForever

local Market = ns.Market

local POSITION = "marketAuctionHouse"
local DRAG_BUTTON = "LeftButton"

local ah, moving

local Move = {}
Market.Move = Move

function Move.Place()
    if moving or not (Market.On() and ah:IsShown()) then return end
    local saved = ns.AccountSettings()[POSITION]
    if saved then
        ah:ClearAllPoints()
        ah:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    end
    Market.Window.FitDock()
end

function Move.Start()
    if moving or not (IsShiftKeyDown() and Market.On() and ah:IsShown()) then return end
    moving = true
    ah:SetMovable(true)
    ah:StartMoving()
end

function Move.Stop()
    if not moving then return end
    moving = false
    ah:StopMovingOrSizing()
    ah:SetUserPlaced(false)
    local point, _, relativePoint, x, y = ah:GetPoint()
    ns.AccountSettings()[POSITION] = { point, relativePoint, x, y }
    Market.Window.FitDock()
end

function Move.Hook(frame)
    ah = frame
    ah:SetClampedToScreen(true)
    ah:RegisterForDrag(DRAG_BUTTON)
    ah:HookScript("OnDragStart", Move.Start)
    ah:HookScript("OnDragStop", Move.Stop)
    hooksecurefunc("ShowUIPanel", Move.Place)
    hooksecurefunc("HideUIPanel", Move.Place)
    hooksecurefunc("UpdateUIPanelPositions", Move.Place)
end
