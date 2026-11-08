-- Window.lua: The Market's window: its title bar with the scan line, its pages, and the button to Blizzard's window (ns.Market.Window).
local ns = _G.NaowhForever

local Market = ns.Market
local Parts = ns.Shared.Parts
local St = Market.Style

local W, H = St.WINDOW_W, St.WINDOW_H
local HEADER, PAD, FOOTER, TAB_H, BAR_GAP = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.TAB_H, St.BAR_GAP
local SCAN_TICK = 60
local BLIZZARD_TABS = 40
local NEXT_FRAME = 0
local PAGE = "The Market"
local TEXT_TITLE = "The Market"
local TEXT_ABOUT = ns.L("Your bags, priced from the auction house's own listings.")
local TEXT_SCAN = ns.L("Scan Prices")
local TEXT_SCAN_TIP = ns.L("Reads every listing for the prices your bags are sorted by. Blizzard allows one full scan every 15 minutes.")
local TEXT_BLIZZARD = ns.L("Blizzard's Auction House")
local TEXT_BLIZZARD_TIP = ns.L("Blizzard's own window, until you leave the auctioneer.")
local PAGES = {
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, posted one key press at a time." },
}

local window, tabs, body, ticker
local shown = "sell"
local built = {}

Market.Pages = {}
local Window = {}
Market.Window = Window

local function ScanLine()
    if not window then return end
    window.subtitle:SetText(ns.AuctionScanSummary and ns.AuctionScanSummary() or TEXT_ABOUT)
end

local function ShowPage(key)
    if built[shown] and shown ~= key then Market.Pages[shown].Hide() end
    shown = key
    local page = Market.Pages[key]
    if not built[key] then
        page.Build(body)
        built[key] = true
    end
    Parts.PaintTabs(tabs, key)
    page.Show()
end

local function PassKeysOn()
    if window and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end

local function OnKeyDown(self, key)
    local page = Market.Pages[shown]
    local action = not InCombatLockdown() and not IsModifierKeyDown() and page.KeyAction and page.KeyAction(key)
    if not action then return ns.UI.CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    action()
    C_Timer.After(NEXT_FRAME, PassKeysOn)
end

local function OnHidden()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if built[shown] then Market.Pages[shown].Hide() end
    if Window.onHide then Window.onHide(window.stepAside) end
end

local function StepAside()
    Window.StepAside()
end

local function Build()
    window = Parts.Window(W, H, "marketWindow")
    window:SetMovable(false)
    window:SetScript("OnDragStart", nil)
    window:SetScript("OnDragStop", nil)
    window:SetScript("OnKeyDown", OnKeyDown)
    window:HookScript("OnHide", OnHidden)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    local blizzard = Parts.BarButton(window, St.EYE, TEXT_BLIZZARD, TEXT_BLIZZARD_TIP, StepAside)
    blizzard:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    if ns.AuctionScan then
        local scan = Parts.BarButton(window, St.RESET, TEXT_SCAN, TEXT_SCAN_TIP, ns.AuctionScan, TEXT_SCAN)
        scan:SetPoint("RIGHT", blizzard, "LEFT", -BAR_GAP, 0)
    end
    tabs = Parts.Tabs(window, St.TABS_W, PAGES, ShowPage)
    tabs:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", PAD, -(HEADER + PAD + TAB_H + PAD))
    body:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + PAD)
    Parts.FooterBrand(window, PAGE)
end

function Window.Show(ah, strata)
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:SetFrameStrata(strata)
    local scale = ah:GetEffectiveScale() / window:GetEffectiveScale()
    window:SetSize(math.max(W, ah:GetWidth() * scale), math.max(H, ah:GetHeight() * scale + BLIZZARD_TABS))
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", ah, "TOPLEFT", 0, 0)
    window.backdrop:Paint(1)
    window:Show()
    ScanLine()
    if not ticker then ticker = C_Timer.NewTicker(SCAN_TICK, ScanLine) end
    ShowPage(shown)
end

function Window.Hide(stepAside)
    if not window then return end
    window.stepAside = stepAside
    window:Hide()
    window.stepAside = nil
end

function Window.Shown()
    return window ~= nil and window:IsShown()
end

function Window.ShowPage(key)
    if Window.Shown() then ShowPage(key) end
end

function Window.Refresh()
    if not Window.Shown() then return end
    ScanLine()
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

ns.MarketRefresh = Window.Refresh
