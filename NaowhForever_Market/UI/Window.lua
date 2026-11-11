-- Window.lua: The Market's own window: its title bar with the scan line, and the Farm, Reagents and Prices pages (ns.Market.Window).
local ns = _G.NaowhForever

local Market = ns.Market
local Parts = ns.Shared.Parts
local St = Market.Style

local W, H = St.WINDOW_W, St.WINDOW_H
local HEADER, PAD, FOOTER, BAR_GAP = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.BAR_GAP
local TABS_BOTTOM = FOOTER + PAD / 2
local BODY_BOTTOM = TABS_BOTTOM + St.TAB_H + PAD
local TAB_W = 150
local SCAN_TICK = 60
local FRESH = 3600
local DOT, DOT_GAP = 7, 8
local DOT_TEXTURE = "Interface\\AddOns\\NaowhForever\\Core\\Media\\circle_mask.tga"
local COG = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\settings.tga"
local POSITION = "marketWindow"
local PAGE = "The Market"
local TEXT_TITLE = "The Market"
local TEXT_ABOUT = ns.L("Where to farm, what your reagents make, and every item's price over time.")
local TEXT_SETTINGS = ns.L("Settings")
local TEXT_SETTINGS_TIP = ns.L("The Market's settings.")
local TEXT_OFF = ns.L("Turn on The Market in its settings to open it.")
local PAGES = {
    { key = "farm", label = "Farm", tip = "Where your skills gather the most, priced from your last scan, and a loop through it." },
    { key = "reagents", label = "Reagents", tip = "What the reagents in your bags make, and whether to craft or sell them." },
    { key = "prices", label = "Prices", tip = "Any item's lowest price each day over the past two weeks." },
}

local window, body, tabs, ticker
local shown = "farm"
local built = {}

Market.Pages = {}
local Window = {}
Market.Window = Window

local function ScanLine()
    if not window then return end
    local summary = ns.AuctionScanSummary and ns.AuctionScanSummary()
    local at = ns.AuctionScanTime and ns.AuctionScanTime()
    local dot = at and GetServerTime() - at < FRESH and St.HAVE_RGB or St.WARN_RGB
    window.dot:SetVertexColor(dot.r, dot.g, dot.b)
    window.dot:SetShown(summary ~= nil)
    window.status:SetText(summary or "")
end

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

local function OnHidden()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if built[shown] then Market.Pages[shown].Hide() end
end

local function OpenSettings()
    ns.OpenOptionsWindow(PAGE)
end

local function Build()
    window = Parts.Window(W, H, POSITION)
    window:HookScript("OnHide", OnHidden)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    window.cog = Parts.BarButton(window, COG, TEXT_SETTINGS, TEXT_SETTINGS_TIP, OpenSettings)
    window.cog:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    window.status = ns.Font(window, St.SMALL_SIZE, nil, ns.THEME.muted)
    window.status:SetPoint("RIGHT", window.cog, "LEFT", -BAR_GAP, 0)
    window.dot = window:CreateTexture(nil, "ARTWORK")
    window.dot:SetTexture(DOT_TEXTURE, nil, nil, "TRILINEAR")
    window.dot:SetSize(DOT, DOT)
    window.dot:SetPoint("RIGHT", window.status, "LEFT", -DOT_GAP, 0)
    window.subtitle:SetPoint("RIGHT", window.dot, "LEFT", -BAR_GAP, 0)
    tabs = Market.Tabs.Build(window, TAB_W * #PAGES, PAGES, ShowPage)
    tabs:SetPoint("BOTTOMLEFT", PAD, TABS_BOTTOM)
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    body:SetPoint("BOTTOMRIGHT", -PAD, BODY_BOTTOM)
    Parts.FooterBrand(window, PAGE)
end

function Window.Open(page)
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window.backdrop:Paint(1)
    window:Show()
    ScanLine()
    if not ticker then ticker = C_Timer.NewTicker(SCAN_TICK, ScanLine) end
    ShowPage(page or shown)
end

function ns.ToggleMarketWindow()
    if not Market.On() then return ns.Print(TEXT_OFF) end
    if Window.Shown() then return window:Hide() end
    Window.Open()
end

function Window.Hide()
    if window then window:Hide() end
end

function Window.Shown()
    return window ~= nil and window:IsShown()
end

function Window.Refresh()
    if not Window.Shown() then return end
    ScanLine()
    Market.Tabs.Paint(tabs, shown)
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

function ns.MarketRefresh()
    if Market.On() then
        Market.History.Record()
        Market.BagWorth.Changed()
        Market.Crafts.Changed()
        Market.Farm.Changed()
    end
    Window.Refresh()
    Market.Dock.Refresh()
end
