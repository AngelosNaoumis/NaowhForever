-- Fishing.lua: One-Key Fishing, one key that casts, reels in your catch, and puts on a lure and fishing gear first.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Settings = ns.Shared.Settings
local D = ns.FishingData
local Gear = ns.FishingGear
local G = ns.Glimmer

local GetCVar, SetTempCVar, RemoveTempCVar = C_CVar.GetCVar, C_CVar.SetTempCVar, C_CVar.RemoveTempCVar

local KEY_BUTTON, CLICK_BUTTON = "NaowhForeverFish", "NaowhForeverFishClick"
local BINDING = "CLICK " .. KEY_BUTTON .. ":LeftButton"
local GEAR_BINDING = "NAOWHFOREVER_FISHING_GEAR"
local REEL = "INTERACTTARGET"
local MOUSE_KEY, MOUSE_BUTTON = "BUTTON2", "RightButton"
local MAIN_HAND, MAIN_HAND_ENCHANT = 16, 0
local DOUBLE_CLICK, CLICK_HOLD = 0.4, 1
local LURE_SETTLE, LURE_TRIES = 2, 2
local LURE_EVENTS = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }
local REEL_CVARS = {
    SoftTargetInteract = { 2, "3" },
    SoftTargetInteractArc = { 1, "1" },
    SoftTargetInteractRange = { 20, "20" },
}
local SAVED_TEMPS = "fishingReelTemps"
local PAGE = "QoL/Loot & Items"
local ORDER = 56
local KEYS = { enabled = true, fishingKey = true, fishingDoubleClick = true }

local keyButton, clickButton, keyOwner, clickOwner
local events = CreateFrame("Frame")
local fishing, reeling, pending
local lastClick
local clickRun = 0
local luredAt, triedLure = -LURE_SETTLE, nil
local missed = {}

local function On()
    return S.Get("enabled") and S.Get("fishingKey")
end

local function Point(button, kind, value, targetSlot)
    button:SetAttribute("type", kind)
    button:SetAttribute("spell", kind == "spell" and value or nil)
    button:SetAttribute("item", kind == "item" and value or nil)
    button:SetAttribute("equipmentset", kind == "equipmentset" and value or nil)
    button:SetAttribute("target-slot", targetSlot)
end

local function KnownSpell()
    local best, bestRank
    for id, rank in pairs(D.SPELLS) do
        if (not bestRank or rank > bestRank) and C_SpellBook.IsSpellKnown(id) then best, bestRank = id, rank end
    end
    return best
end

local function Lured()
    for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(MAIN_HAND_ENCHANT)) do
        if enchant.hasEnchant and enchant.enchantType == Enum.ItemEnchantType.Temporary then return true end
    end
    return false
end

local function LureEvents(on)
    for _, event in ipairs(LURE_EVENTS) do
        if on then events:RegisterUnitEvent(event, "player") else events:UnregisterEvent(event) end
    end
end

local function Missed()
    missed[triedLure] = (missed[triedLure] or 0) + 1
    triedLure = nil
end

local function BestLure()
    if not S.Get("fishingLure") or GetTime() - luredAt < LURE_SETTLE then return end
    if Lured() then
        if triedLure then missed[triedLure], triedLure = nil, nil end
        return
    end
    if triedLure then Missed() end
    local best, bestBonus
    for id, bonus in pairs(D.LURES) do
        if (missed[id] or 0) < LURE_TRIES and (not bestBonus or bonus > bestBonus) and C_Item.GetItemCount(id) > 0
            and C_Item.IsUsableItem(id) then
            best, bestBonus = id, bonus
        end
    end
    return best
end

local function Arm(button)
    if InCombatLockdown() then return end
    if not On() or fishing or UnitCastingInfo("player") or UnitChannelInfo("player") then return Point(button) end
    local kind, value = Gear.Next()
    if kind then
        Gear.Note()
        return Point(button, kind, value)
    end
    local lure = Gear.PoleWorn() and BestLure()
    if lure then
        luredAt, triedLure = GetTime(), lure
        LureEvents(true)
        return Point(button, "item", "item:" .. lure, MAIN_HAND)
    end
    local spell = KnownSpell()
    Point(button, spell and "spell" or nil, spell)
end

local function SetTemps(temps)
    local store = ns.AccountSettings()
    store[SAVED_TEMPS] = store[SAVED_TEMPS] or {}
    for name in pairs(temps) do store[SAVED_TEMPS][name] = true end
end

local function RemoveTemps()
    local store = ns.AccountSettings()
    local temps = store[SAVED_TEMPS]
    if not temps then return end
    for name in pairs(temps) do RemoveTempCVar(name) end
    store[SAVED_TEMPS] = nil
end

local function ReachBobber()
    if ns.GamepadStandDown() then return end
    local set = {}
    for name, want in pairs(REEL_CVARS) do
        if (tonumber(GetCVar(name)) or 0) < want[1] then
            SetTempCVar(name, want[2])
            set[name] = true
        end
    end
    if next(set) then SetTemps(set) end
end

local function IsBobber(guid)
    if type(guid) ~= "string" or not G.Plain(guid) then return false end
    return tonumber(guid:match(G.C.GUID_OBJECT)) == G.C.BOBBER
end

local function Reel(on)
    if on == reeling or InCombatLockdown() then return end
    reeling = on
    if not on then return ClearOverrideBindings(keyOwner) end
    for _, key in ipairs({ GetBindingKey(BINDING) }) do SetOverrideBinding(keyOwner, true, key, REEL) end
end

local function StartFishing()
    if InCombatLockdown() then return end
    fishing = true
    ReachBobber()
    events:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    Reel(IsBobber(UnitGUID("softinteract")))
end

local function StopFishing()
    fishing = false
    events:UnregisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    Reel(false)
    RemoveTemps()
end

local function ReleaseClick()
    clickRun = clickRun + 1
    if not InCombatLockdown() then ClearOverrideBindings(clickOwner) end
end

local function HoldClick()
    clickRun = clickRun + 1
    local run = clickRun
    SetOverrideBindingClick(clickOwner, true, MOUSE_KEY, CLICK_BUTTON)
    C_Timer.After(CLICK_HOLD, function()
        if run == clickRun then ReleaseClick() end
    end)
end

local function OnMouseDown(button)
    if button ~= MOUSE_BUTTON or fishing or InCombatLockdown() then return end
    local focus = GetMouseFoci()[1]
    if (focus and focus ~= WorldFrame) or UnitExists("mouseover") or GameTooltip:IsShown() or not Gear.PoleWorn() then
        lastClick = nil
        return
    end
    local now = GetTime()
    if lastClick and now - lastClick < DOUBLE_CLICK then
        lastClick = nil
        HoldClick()
    else
        lastClick = now
    end
end

local function OnLureCast(event)
    LureEvents(false)
    if not triedLure then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        luredAt = GetTime()
    elseif event == "UNIT_SPELLCAST_FAILED" then
        Missed()
    else
        triedLure = nil
    end
end

local function Build()
    keyOwner = CreateFrame("Frame")
    clickOwner = CreateFrame("Frame")
    keyButton = CreateFrame("Button", KEY_BUTTON, UIParent, "SecureActionButtonTemplate")
    keyButton:RegisterForClicks("AnyDown")
    keyButton:SetAttribute("useOnKeyDown", true)
    keyButton:SetScript("PreClick", Arm)
    clickButton = CreateFrame("Button", CLICK_BUTTON, UIParent, "SecureActionButtonTemplate")
    clickButton:RegisterForClicks("AnyUp")
    clickButton:SetAttribute("useOnKeyDown", false)
    clickButton:SetScript("PreClick", Arm)
    clickButton:SetScript("PostClick", ReleaseClick)
end

local function Apply()
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = false
    events:UnregisterAllEvents()
    if keyButton then
        StopFishing()
        ClearOverrideBindings(clickOwner)
        Point(keyButton)
        Point(clickButton)
    else
        RemoveTemps()
    end
    if not On() then return end
    if not keyButton then Build() end
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    if S.Get("fishingDoubleClick") then events:RegisterEvent("GLOBAL_MOUSE_DOWN") end
end

local function OnEvent(_, event, a, b, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if G.Plain(spellID) and D.SPELLS[spellID] then StartFishing() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if fishing then StopFishing() end
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        Reel(IsBobber(b))
    elseif event == "GLOBAL_MOUSE_DOWN" then
        OnMouseDown(a)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        OnLureCast(event)
    elseif event == "PLAYER_REGEN_DISABLED" then
        StopFishing()
        ClearOverrideBindings(clickOwner)
        Point(keyButton)
        Point(clickButton)
    elseif event == "PLAYER_REGEN_ENABLED" then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if pending then Apply() end
    end
end

events:SetScript("OnEvent", OnEvent)

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

Settings.Page(PAGE, S):Card({
    id = "fishingKey", name = "One-Key Fishing", order = ORDER, switch = "fishingKey",
    help = "One key casts Fishing, and the same key reels in your catch.",
    rows = {
        { label = "Fishing Key", binding = BINDING, help = "Press to cast, press again when the bobber splashes." },
        { key = "fishingDoubleClick", label = "Double Right-Click to Cast", toggle = true,
          help = "Casts when you double right-click the world with a fishing pole equipped." },
        { key = "fishingLure", label = "Put On a Lure First", toggle = true,
          help = "Puts your best lure on the pole when it has none." },
        { key = "fishingGear", label = "Put On Fishing Gear First", toggle = true,
          help = "Equips your fishing gear first, and combat puts your weapons back." },
        { key = "fishingGearSet", label = "Fishing Gear", choice = Gear.Choices, needs = "fishingGear",
          help = "A gear set to wear, or just your best fishing pole." },
        { label = "Put Gear Back", binding = GEAR_BINDING, needs = "fishingGear",
          help = "Puts back what your fishing gear replaced." },
    },
})
