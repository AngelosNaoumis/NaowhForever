-- Takeover.lua: The Market's window over Blizzard's auction house: when it shows, how it covers Blizzard's, and the way back to it.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Window = Market.Window

local AH_ADDON = "Blizzard_AuctionHouseUI"
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local FALLBACK_STRATA = "HIGH"
local BACK_W, BACK_H, BACK_GAP = 120, 22, 4
local TEXT_BACK = "The Market"

local events, ah, stepped, back

local function NextStrata(strata)
    for i, s in ipairs(STRATA) do
        if s == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return FALLBACK_STRATA
end

local function Activate()
    if stepped or not (Market.On() and ah:IsShown()) then return end
    ah:SetAlpha(0)
    if back then back:Hide() end
    Window.Show(ah, NextStrata(ah:GetFrameStrata()))
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Deactivate()
    Window.Hide(true)
    if ah then ah:SetAlpha(1) end
    if back then back:Hide() end
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Return()
    stepped = false
    Activate()
end

local function ReturnHere()
    if not (ah and ah:IsShown()) then return false end
    Return()
    return true
end

local function StepAside()
    stepped = true
    Deactivate()
    if not back then
        back = ns.Button(ah, TEXT_BACK, BACK_W, BACK_H, Return)
        back:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", 0, BACK_GAP)
    end
    back:Show()
end

local function WindowHidden(stepAside)
    if stepAside or not (ah and ah:IsShown()) then return end
    if S.Get("openAtAuctioneer") then return C_AuctionHouse.CloseAuctionHouse() end
    StepAside()
end

local function OnBlizzardShow()
    if S.Get("openAtAuctioneer") or not Market.On() then return Activate() end
    StepAside()
end

local function OnBlizzardHide()
    stepped = false
    Deactivate()
    Market.Sell.Reset()
end

local function OnPostItem(_, location)
    if not Window.Shown() then return end
    Window.ShowPage("sell")
    Market.Pages.sell.PickLocation(location)
end

local function Hook()
    ah = _G.AuctionHouseFrame
    ah:HookScript("OnShow", OnBlizzardShow)
    ah:HookScript("OnHide", OnBlizzardHide)
    hooksecurefunc(ah, "SetPostItem", OnPostItem)
end

local function OnEvent(_, _, name)
    if name ~= AH_ADDON then return end
    events:UnregisterEvent("ADDON_LOADED")
    Hook()
end

local function Apply()
    if not Market.On() then
        if events then events:UnregisterAllEvents() end
        stepped = false
        return Deactivate()
    end
    if ah then return Activate() end
    if C_AddOns.IsAddOnLoaded(AH_ADDON) then
        Hook()
        return Activate()
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:RegisterEvent("ADDON_LOADED")
end

local function OnSetting(key)
    if key == "enabled" then Apply() end
end

Window.StepAside = StepAside
Window.Return = ReturnHere
Window.onHide = WindowHidden

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()
