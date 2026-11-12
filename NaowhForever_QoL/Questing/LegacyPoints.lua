-- LegacyPoints.lua: the optional unspent Legacy points alert, hidden in combat.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local LEGACY = Constants.LegacyConsts

local WIDTH, ROOM = 300, 10
local FONT_SIZE = 22
local STACK_ORDER = 2.5
local CARD_ORDER = 41
local PAGE = "QoL/XP"
local KEY = "legacyPoints"
local TEXT_ALERT = "Unspent Legacy Points"
local TEXT_HELP = "Shows your unspent Legacy points outside combat."
local TEXT_ONE = ns.L("1 Unspent Legacy Point")
local TEXT_MANY = ns.L("%d Unspent Legacy Points")
local SAMPLE_POINTS = 2
local TEXT_RANGE = { 10, 48, 1 }
local EVENTS = { "PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_CREATED", "TRAIT_CONFIG_UPDATED",
    "TRAIT_CONFIG_DELETED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
    "CURRENCY_DISPLAY_UPDATE", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local frame, events, unlocked, inCombat

local function On()
    return S.Get("enabled") and S.Get(KEY)
end

local function Points()
    if C_MajorFactions.GetCurrentRenownLevel(LEGACY.LEGACY_REWARD_TRACK_FACTION_ID) <= 0 then return nil end
    local tree = LEGACY.LEGACY_TREE_PROFESSIONS_ID
    local config = C_Traits.GetConfigIDByTreeID(tree)
    if not config then return nil end
    local currencies = C_Traits.GetTreeCurrencyInfo(config, tree, false)
    if not currencies then return nil end
    for _, currency in ipairs(currencies) do
        if currency.traitCurrencyID == LEGACY.LEGACY_POINTS_TRAIT_CURRENCY_ID then
            return currency.quantity
        end
    end
end

local function Update()
    if inCombat then frame:Hide(); return end
    local points = unlocked and SAMPLE_POINTS or Points()
    if type(points) ~= "number" or points <= 0 then frame:Hide(); return end
    frame.text:SetText(points == 1 and TEXT_ONE or TEXT_MANY:format(points))
    frame:SetWidth(frame.mode == "none" and WIDTH or frame.text:GetStringWidth() + 2 * St.CARD_PAD)
    frame:Show()
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    Update()
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverLegacyPoints", UIParent)
    frame:Hide()
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.text = ns.Font(frame, FONT_SIZE, "OUTLINE")
    frame.text:SetPoint("CENTER")
    frame.backdrop = Parts.HudBackdrop(frame, { mode = "none" })
    ns.AlertStack(frame, STACK_ORDER, TEXT_ALERT, PAGE, PAGE .. ":" .. KEY)
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
end

local function Restyle()
    local size = S.Get("legacyPointsFontSize")
    frame.mode = frame.backdrop:SetMode(S.Get("legacyPointsBackground"))
    Parts.HudFont(frame.text, S.Get("legacyPointsFont"), size, S.Get("legacyPointsOutline"), frame.mode)
    local color = S.Get("legacyPointsTheme") and T.accent or St.FOREVER_GOLD_RGB
    frame.text:SetTextColor(color.r, color.g, color.b, 1)
    frame:SetSize(WIDTH, size + ROOM)
end

local function Apply()
    if events then events:UnregisterAllEvents() end
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Restyle()
    inCombat = UnitAffectingCombat("player")
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Update()
end

S.OnChange(function(key)
    if key == "enabled" or key:find("^legacyPoints") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local Settings = ns.Shared.Settings

Settings.Page(PAGE, S):Card({
    id = "legacyPoints", name = TEXT_ALERT, order = CARD_ORDER, switch = KEY,
    help = TEXT_HELP,
    rows = {
        Settings.Look(KEY, { text = true, size = TEXT_RANGE, background = "card" }),
        Settings.Group("Colors"),
        { key = "legacyPointsTheme", label = "Apply Theme to Text Color", toggle = true,
          help = "The text in the theme's accent color instead of gold." },
    },
})
