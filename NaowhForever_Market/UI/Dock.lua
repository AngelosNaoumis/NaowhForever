-- Dock.lua: The Market's panel docked beside Blizzard's auction house, with Sell and My Auctions, and the way to The Market's window (Market.Dock).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local Parts = ns.Shared.Parts

local AH_ADDON = "Blizzard_AuctionHouseUI"
local DOCK_W, DOCK_GAP, PAD, HEAD_H = 380, 4, 10, 34
local BACK_W, BACK_H, BACK_GAP = 120, 22, 4
local NEXT_FRAME = 0
local TEXT_TITLE = "The Market"
local TEXT_OPEN = ns.L("Farm, Reagents and Prices")
local TEXT_OPEN_TIP = ns.L("Opens The Market's own window.")
local PAGES = {
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, priced and posted." },
    { key = "mine", label = "My Auctions", tip = "Your auctions, and the ones someone is selling for less." },
}

local dock, body, tabs, back, events, ah
local shown = "sell"
local built = {}
local closed = false

local Dock = {}
Market.Dock = Dock

local function ShowPage(key)
    if built[shown] and shown ~= key then Market.Pages[shown].Hide() end
    shown = key
    Market.Tabs.Paint(tabs, key)
    local page = Market.Pages[key]
    if not built[key] then
        page.Build(body)
        built[key] = true
    end
    page.Show()
end

local function PassKeysOn()
    if dock and not InCombatLockdown() then dock:SetPropagateKeyboardInput(true) end
end

local function OnKeyDown(self, key)
    local page = Market.Pages[shown]
    local action = not InCombatLockdown() and not IsModifierKeyDown() and page.KeyAction and page.KeyAction(key)
    if not action then return end
    self:SetPropagateKeyboardInput(false)
    action()
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function OnHidden()
    if built[shown] then Market.Pages[shown].Hide() end
end

local function OpenWindow()
    Market.Window.Open()
end

local Activate

local function Reopen()
    closed = false
    Activate()
end

local function Close()
    closed = true
    dock:Hide()
    if not back then
        back = ns.Button(ah, TEXT_TITLE, BACK_W, BACK_H, Reopen)
        back:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", 0, BACK_GAP)
    end
    back:Show()
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Build()
    dock = Parts.Panel(TEXT_TITLE, true)
    dock:SetWidth(DOCK_W)
    dock.backdrop:Paint(1)
    dock.close:SetScript("OnClick", Close)
    dock:SetScript("OnKeyDown", OnKeyDown)
    dock:HookScript("OnHide", OnHidden)
    local open = Parts.BarButton(dock, St.COINS, TEXT_OPEN, TEXT_OPEN_TIP, OpenWindow)
    open:SetPoint("RIGHT", dock.close, "LEFT", -St.BAR_GAP, 0)
    dock.title:SetPoint("RIGHT", open, "LEFT", -St.BAR_GAP, 0)
    tabs = Market.Tabs.Build(dock, DOCK_W - PAD * 2, PAGES, ShowPage)
    tabs:SetPoint("TOPLEFT", PAD, -HEAD_H)
    body = CreateFrame("Frame", nil, dock)
    body:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -PAD)
    body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

function Activate()
    if closed or not (Market.On() and ah and ah:IsShown()) then return end
    if not dock then Build() end
    dock:SetScale(ah:GetScale())
    dock:SetFrameStrata(ah:GetFrameStrata())
    dock:ClearAllPoints()
    dock:SetPoint("TOPLEFT", ah, "TOPRIGHT", DOCK_GAP, 0)
    dock:SetPoint("BOTTOMLEFT", ah, "BOTTOMRIGHT", DOCK_GAP, 0)
    if not InCombatLockdown() then
        dock:EnableKeyboard(S.Get("postKeys"))
        dock:SetPropagateKeyboardInput(true)
    end
    if back then back:Hide() end
    dock:Show()
    ShowPage(shown)
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Deactivate()
    if dock then dock:Hide() end
    if back then back:Hide() end
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function OnBlizzardShow()
    closed = false
    Activate()
end

local function OnBlizzardHide()
    closed = false
    Deactivate()
    Market.Sell.Reset()
end

function Dock.Shown()
    return dock ~= nil and dock:IsShown()
end

function Dock.Pick(location)
    if not Dock.Shown() then return end
    ShowPage("sell")
    Market.Pages.sell.PickLocation(location)
end

function Dock.Refresh()
    if not Dock.Shown() then return end
    Market.Tabs.Paint(tabs, shown)
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

function ns.MarketAuctionWindow()
    if Dock.Shown() then return dock end
end

local function OnPostItem(_, location)
    Dock.Pick(location)
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
        closed = false
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
    if key == "enabled" or key == "postKeys" then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()
