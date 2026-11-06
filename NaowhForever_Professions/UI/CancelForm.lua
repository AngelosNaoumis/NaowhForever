-- CancelForm.lua: a druid's Create, Create All and Start leave the shapeshift form first: a secure /cancelform layer over each, out of combat.
local ns = _G.NaowhForever

local P = ns.Professions

local DRUID = "DRUID"
local MACRO = "/cancelform"

local covered = {}
local events

local function Forward(self, script)
    local fn = self.button:GetScript(script)
    if fn then fn(self.button) end
end

local function OnMouseDown(self)
    Forward(self, "OnMouseDown")
end

local function OnMouseUp(self)
    Forward(self, "OnMouseUp")
end

local function OnPreClick(self, _, down)
    if down then return end
    self:SetAttribute("type", self.button:IsEnabled() and "macro" or nil)
end

local function OnPostClick(self, _, down)
    if down or not self.button:IsEnabled() then return end
    self.onClick()
end

local function NewLayer(entry)
    local layer = CreateFrame("Button", nil, entry.button, "SecureActionButtonTemplate")
    layer.button, layer.onClick = entry.button, entry.onClick
    layer:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    layer:SetAttribute("useOnKeyDown", false)
    layer:SetAttribute("macrotext", MACRO)
    layer:SetPropagateMouseMotion(true)
    layer:SetScript("PreClick", OnPreClick)
    layer:SetScript("PostClick", OnPostClick)
    layer:SetScript("OnMouseDown", OnMouseDown)
    layer:SetScript("OnMouseUp", OnMouseUp)
    return layer
end

local function Attach(entry)
    entry.layer = entry.layer or NewLayer(entry)
    local layer = entry.layer
    layer:SetParent(entry.button)
    layer:SetFrameLevel(entry.button:GetFrameLevel() + 1)
    layer:SetAllPoints(entry.button)
    layer:Show()
end

local function Detach(entry)
    local layer = entry.layer
    if not layer then return end
    layer:Hide()
    layer:ClearAllPoints()
    layer:SetParent(UIParent)
end

local function OnEvent(_, event)
    local Step = event == "PLAYER_REGEN_DISABLED" and Detach or Attach
    for _, entry in ipairs(covered) do Step(entry) end
end

local CancelForm = {}
P.CancelForm = CancelForm

function CancelForm.Cover(button, onClick)
    if select(2, UnitClass("player")) ~= DRUID then return end
    local entry = { button = button, onClick = onClick }
    covered[#covered + 1] = entry
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:SetScript("OnEvent", OnEvent)
    end
    if not InCombatLockdown() then Attach(entry) end
end
