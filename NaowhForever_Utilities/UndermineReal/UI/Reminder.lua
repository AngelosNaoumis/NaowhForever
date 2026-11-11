-- Reminder.lua: the blinking Tarnished Undermine Real icon, from a boss's kill until you loot it.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI
local St = ns.Shared.Style
local Parts = ns.Shared.Parts

local UR = ns.UndermineReal
local S = UR.Settings

local CROP = St.ICON_CROP
local LABEL_GAP = 4
local ANCHORS = {
    BOTTOM = { "TOP", "BOTTOM", 0, -LABEL_GAP },
    TOP = { "BOTTOM", "TOP", 0, LABEL_GAP },
    LEFT = { "RIGHT", "LEFT", -LABEL_GAP, 0 },
    RIGHT = { "LEFT", "RIGHT", LABEL_GAP, 0 },
}
local BLINK_LOW, BLINK_TIME = 0.25, 0.5
local HOME_X, HOME_Y = 0, 200
local FRAME_NAME = "NaowhForeverUndermineReal"
local MOVER_LABEL = "Undermine Real Reminder"
local CARD = UR.PAGE .. ":undermineReal"
local EVENTS = { "ENCOUNTER_END", "LOOT_OPENED", "PLAYER_ENTERING_WORLD" }
local OBJECT_ID_FIELD = 6
local TEXT_ITEM = ns.L("Tarnished Undermine Real")
local TEXT_LOOT = ns.L("Loot Real")
local TEXT_TIP = ns.L("Click to hide it until your next boss.")

local frame, unlocked
local events = CreateFrame("Frame")

local Look = {}
UR.Look = Look

function Look.New(f)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    ns.Border(f, St.BORDER_RGB)
    f.label = ns.Font(f, S.Get("undermineRealFontSize"), "OUTLINE", T.accentSoft)
end

function Look.Fill(f)
    local size = S.Get("iconSize")
    f:SetSize(size, size)
    f.icon:SetTexture(C_Item.GetItemIconByID(UR.ITEM))
    Parts.HudFont(f.label, S.Get("undermineRealFont"), S.Get("undermineRealFontSize"), S.Get("undermineRealOutline"))
    local at = ANCHORS[S.Get("undermineRealTextPos")] or ANCHORS.BOTTOM
    f.label:ClearAllPoints()
    f.label:SetPoint(at[1], f, at[2], at[3], at[4])
    f.label:SetText(TEXT_LOOT)
end

local function Place()
    local pos = S.Get("undermineRealPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", HOME_X, HOME_Y)
    end
end

local function Clicked()
    UR.Clear()
    frame:Hide()
end

local function Build()
    frame = CreateFrame("Button", FRAME_NAME, UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    Look.New(frame)
    local blink = frame:CreateAnimationGroup()
    blink:SetLooping("BOUNCE")
    local fade = blink:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(BLINK_LOW)
    fade:SetDuration(BLINK_TIME)
    frame.blink = blink
    frame:SetScript("OnClick", Clicked)
    ns.Tooltip(frame, TEXT_ITEM, TEXT_TIP)
    frame.mover = UI.AttachMover(frame, MOVER_LABEL, function(pos) S.Set("undermineRealPos", pos) end, UR.PAGE, CARD)
    frame:Hide()
end

local function Update()
    if UR.Name() or unlocked then
        Look.Fill(frame)
        frame:Show()
        frame.blink:Play()
    else
        frame.blink:Stop()
        frame:Hide()
    end
end

local function ReadLoot()
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if guid and not issecretvalue(guid) then
            local npc = tonumber((select(OBJECT_ID_FIELD, strsplit("-", guid))))
            if npc and UR.Looted(npc) then return Update() end
        end
    end
end

local function OnEvent(_, event, encounterID, name, _, _, success)
    if event == "ENCOUNTER_END" then
        if success == 1 and UR.Killed(encounterID, name) then Update() end
    elseif event == "LOOT_OPENED" then
        ReadLoot()
    elseif not IsInInstance() then
        UR.Clear()
        Update()
    end
end

local function Apply()
    events:UnregisterAllEvents()
    if not (UR.Enabled() or unlocked) then
        UR.Clear()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    for i = 1, #EVENTS do events:RegisterEvent(EVENTS[i]) end
    Update()
end

local function OnUnlock()
    unlocked = UR.Enabled()
    Apply()
end

local function OnLock()
    unlocked = false
    Apply()
end

events:SetScript("OnEvent", OnEvent)
S.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
