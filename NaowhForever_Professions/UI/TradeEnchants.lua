-- TradeEnchants.lua: Trade Enchants: beside the trade window, your enchants for the item in its Will not be traded slot, each cast on it in one click.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local D = P.Disenchant
local TE = P.TradeEnchants
local Popup = P.Popup
local Style = P.Style
local Widgets = P.Widgets

local MAX_ROWS = Style.SIDE_PANEL_ROWS
local PANEL_GAP = Style.SIDE_PANEL_GAP
local QUEUE_DELAY = P.C.QUEUE_DELAY
local PARTNER = "NPC"
local TRADE_EVENTS = { "TRADE_SHOW", "TRADE_CLOSED", "TRADE_TARGET_ITEM_CHANGED" }
local OPEN_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local TEXT_TITLE = ns.L("Trade Enchants")
local TEXT_ENCHANT = ns.L("Enchant")
local TEXT_ENCHANT_TIP = ns.L("Casts this enchant on the item they put in the trade window.")
local TEXT_ASKED = ns.L("Asked for")
local TEXT_OPEN = ns.L("Open Enchanting to list your enchants for this item.")
local TEXT_NONE = ns.L("None of your enchants go on this item.")
local TEXT_MORE = ns.L("%d enchants: scroll for more.")

local panel, events, trading, partner
local pending = false
local offset = 0

local function On()
    return S.Get("enabled") and S.Get("tradeEnchants") and not ns.GamepadStandDown()
end

local function Hide()
    if panel and panel:IsShown() then panel:Hide() end
end

local function OnEnchantPreClick(self, _, down)
    if down then return end
    local go = self.recipeID ~= nil and not IsModifiedClick() and not SpellIsTargeting() and TE.EnchantingOpen()
    self:SetAttribute("type", go and "click" or nil)
    if go then C_TradeSkillUI.CraftRecipe(self.recipeID) end
end

local function Row(i)
    local row = panel.rows[i]
    if row then return row end
    row = Popup.Row(panel, i, TEXT_ENCHANT, nil, nil, "SecureActionButtonTemplate")
    row.note:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
    local button = row.button
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("clickbutton", TradeRecipientItem7ItemButton)
    button:SetScript("PreClick", OnEnchantPreClick)
    ns.Tooltip(button, TEXT_ENCHANT, TEXT_ENCHANT_TIP)
    return row
end

local function FillRow(i, info)
    local row = Row(i)
    row.spell = info.recipeID
    row.button.recipeID = info.recipeID
    row.icon:SetTexture(info.icon)
    row.name:SetText(info.name)
    row.note:SetText(TE.Asked(partner, info.recipeID) and TEXT_ASKED or "")
    local ready = R.Craftable(info) > 0
    local color = ready and T.fg or T.muted
    row.name:SetTextColor(color.r, color.g, color.b)
    Widgets.EnableButton(row.button, ready)
    row:Show()
end

local Render

local function OnWheel(_, delta)
    offset = offset - delta
    Render()
end

local function Build()
    panel = Popup.New(TEXT_TITLE)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", OnWheel)
end

function Render()
    pending = false
    local link = trading and GetTradeTargetItemLink(TRADE_ENCHANT_SLOT)
    if not (link and On() and D.Known()) or InCombatLockdown() then return Hide() end
    if not panel then Build() end
    if panel.dismissed then return end
    local list = TE.EnchantingOpen() and TE.List(link, partner)
    local n = list and #list or 0
    offset = math.max(0, math.min(offset, n - MAX_ROWS))
    local shown = math.min(n, MAX_ROWS)
    for i = 1, shown do FillRow(i, list[i + offset]) end
    local note = not list and TEXT_OPEN or n == 0 and TEXT_NONE or n > MAX_ROWS and TEXT_MORE:format(n) or ""
    panel.note:SetText(note)
    Popup.Fit(panel, shown, note ~= "")
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", PANEL_GAP, 0)
    panel:Show()
end

local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(QUEUE_DELAY, Render)
end

local function StartTrade()
    trading, partner, offset = true, UnitGUID(PARTNER), 0
    if panel then panel.dismissed = nil end
    for _, event in ipairs(OPEN_EVENTS) do events:RegisterEvent(event) end
end

local function EndTrade()
    trading, partner = false, nil
    for _, event in ipairs(OPEN_EVENTS) do events:UnregisterEvent(event) end
    Hide()
end

local function OnEvent(_, event, slot)
    if event == "TRADE_SHOW" then
        StartTrade()
    elseif event == "TRADE_CLOSED" then
        return EndTrade()
    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
        if slot ~= TRADE_ENCHANT_SLOT then return end
        offset = 0
    elseif event == "PLAYER_REGEN_DISABLED" then
        if panel then
            panel:Hide()
            panel:ClearAllPoints()
        end
        return
    end
    Queue()
end

local function Apply()
    local on = On()
    TE.Listen(on)
    if not on then
        if not events then return end
        EndTrade()
        return events:UnregisterAllEvents()
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(TRADE_EVENTS) do events:RegisterEvent(event) end
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "tradeEnchants" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
