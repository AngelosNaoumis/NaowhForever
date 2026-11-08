-- DemonTrainer.lua: Demon Books at the merchant: a mark on each demon book, learned, ready or not yet, and a line in its tooltip.
local ns = _G.NaowhForever

local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local Training = ns.Training
local S = Training.Settings
local Grimoires = Training.Grimoires

local LEVEL = Training.C.ENTRY_LEVEL
local LEARNED_ATLAS = "common-icon-checkmark"
local CORNER = "TOPRIGHT"
local MERCHANT_TAB = 1
local TEXT_LEARNED = ns.L("Your %s knows this already")
local TEXT_NOW = ns.L("Your %s can learn this now")
local TEXT_LATER = ns.L("Your %s can learn this at level %d")
local TEXT_UNKNOWN = ns.L("Summon your %s once to check")

local marks = {}
local installed = false

local function Marking()
    return Grimoires.On() and not ns.GamepadStandDown()
end

local function Marks(button)
    local set = marks[button]
    if set then return set end
    set = {
        learned = Parts.ItemBadge(button, CORNER, LEARNED_ATLAS),
        now = Parts.ItemBadge(button, CORNER, St.UPGRADE_ATLAS),
        later = Parts.ItemBadge(button, CORNER, St.CLOCK_ATLAS, St.WARN_RGB),
    }
    marks[button] = set
    return set
end

local function Mark(set, state)
    set.learned:SetShown(state == "learned")
    set.now:SetShown(state == "now")
    set.later:SetShown(state == "later")
end

local function HideAll()
    for _, set in pairs(marks) do Mark(set, nil) end
end

local function Paint()
    if not Marking() then return end
    local frame = MerchantFrame
    if not (frame:IsShown() and frame.selectedTab == MERCHANT_TAB) then return HideAll() end
    local first, level = (frame.page - 1) * MERCHANT_ITEMS_PER_PAGE, UnitLevel("player")
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. i].ItemButton
        local book = Grimoires.Book(GetMerchantItemID(first + i))
        if book then
            Mark(Marks(button), Grimoires.State(book, level))
        elseif marks[button] then
            Mark(marks[button], nil)
        end
    end
end

local function TipLine(state)
    if state == "learned" then return TEXT_LEARNED, St.HAVE_RGB end
    if state == "now" then return TEXT_NOW, T.accent end
    if state == "later" then return TEXT_LATER, St.WARN_RGB end
    return TEXT_UNKNOWN, T.muted
end

local function OnItem(tooltip, data)
    if not Grimoires.On() then return end
    local id = data and data.id
    if not id or issecretvalue(id) then return end
    local book, demon = Grimoires.Book(id)
    if not book then return end
    local text, c = TipLine(Grimoires.State(book, UnitLevel("player")))
    tooltip:AddLine(text:format(Grimoires.Name(demon), book[LEVEL]), c.r, c.g, c.b)
end

local function Apply()
    if not Marking() then HideAll() end
    if not Grimoires.On() then return end
    if not installed then
        installed = true
        hooksecurefunc("MerchantFrame_Update", Paint)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
    end
    Paint()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "demonBooks" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Training.OnChange(Paint)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
