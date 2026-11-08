-- Window.lua: The Market's window: its title bar with the scan line, its pages, and the button to Blizzard's window (ns.Market.Window).
local ns = _G.NaowhForever

local Market = ns.Market
local Parts = ns.Shared.Parts
local St = Market.Style

local W, H, TAB_W = St.WINDOW_W, St.WINDOW_H, St.TAB_W
local HEADER, PAD, FOOTER, TAB_H, BAR_GAP = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.TAB_H, St.BAR_GAP
local SCAN_TICK = 60
local BLIZZARD_TABS = 40
local NEXT_FRAME = 0
local AWAY_STRATA = "HIGH"
local AWAY_PAGE = "farm"
local AWAY_W, AWAY_ICON, AWAY_GAP = 420, 40, 10
local POSITION = "marketWindow"
local PAGE = "The Market"
local TEXT_TITLE = "The Market"
local TEXT_ABOUT = ns.L("Your bags, priced from the auction house's own listings.")
local TEXT_SCAN = ns.L("Scan Prices")
local TEXT_SCAN_TIP = ns.L("Reads every listing for the prices your bags are sorted by. Blizzard allows one full scan every 15 minutes.")
local TEXT_BLIZZARD = ns.L("Blizzard's Auction House")
local TEXT_BLIZZARD_TIP = ns.L("Blizzard's own window, until you leave the auctioneer.")
local TEXT_AWAY = ns.L("At an auctioneer")
local TEXT_AWAY_BODY = ns.L("Sell, Buy and My Auctions open over the auction house. Talk to an auctioneer to use them.")
local TEXT_OFF = ns.L("Turn on The Market in its settings to open it.")
local PAGES = {
    { key = "farm", label = "Farm", tip = "Where your skills gather the most, priced from your last scan, and a loop through it." },
    { key = "run", label = "Last Run", tip = "Your last gathering run: its gold over time and its haul." },
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, posted one key press at a time.",
      auction = true },
    { key = "crafts", label = "Crafts", tip = "What your characters' recipes make from your bags, priced from your last scan." },
    { key = "buy", label = "Buy", tip = "Search by name, or pick from your Shopping List, and buy it.", auction = true },
    { key = "mine", label = "My Auctions", tip = "Your auctions, and the ones someone is selling for less.",
      auction = true },
}
local AUCTION_ONLY = {}
for _, page in ipairs(PAGES) do AUCTION_ONLY[page.key] = page.auction == true end

local window, tabs, body, ticker, away
local shown = "sell"
local atAuction = false
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
    Parts.PaintTabs(tabs, key)
    local blocked = AUCTION_ONLY[key] and not atAuction
    away:SetShown(blocked)
    if blocked then
        if built[key] then Market.Pages[key].Hide() end
        return
    end
    local page = Market.Pages[key]
    if not built[key] then
        page.Build(body)
        built[key] = true
    end
    page.Show()
end

local function PassKeysOn()
    if window and not InCombatLockdown() then window:SetPropagateKeyboardInput(true) end
end

local function OnKeyDown(self, key)
    local page = Market.Pages[shown]
    local action = atAuction and not InCombatLockdown() and not IsModifierKeyDown() and page.KeyAction
        and page.KeyAction(key)
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

local function BuildAway()
    away = CreateFrame("Frame", nil, body)
    away:SetAllPoints()
    away:Hide()
    local m = ns.THEME.muted
    local icon = away:CreateTexture(nil, "ARTWORK")
    icon:SetSize(AWAY_ICON, AWAY_ICON)
    icon:SetPoint("BOTTOM", away, "CENTER", 0, AWAY_GAP)
    icon:SetTexture(St.COINS)
    icon:SetVertexColor(m.r, m.g, m.b)
    local head = ns.Font(away, St.TITLE_SIZE, nil, ns.THEME.fg, true)
    head:SetPoint("TOP", away, "CENTER", 0, 0)
    head:SetText(TEXT_AWAY)
    local text = ns.Font(away, St.TEXT_SIZE, nil, m)
    text:SetPoint("TOP", head, "BOTTOM", 0, -AWAY_GAP)
    text:SetWidth(AWAY_W)
    text:SetText(TEXT_AWAY_BODY)
end

local function Build()
    window = Parts.Window(W, H, POSITION)
    window:SetScript("OnKeyDown", OnKeyDown)
    window:HookScript("OnHide", OnHidden)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    window.blizzard = Parts.BarButton(window, St.EYE, TEXT_BLIZZARD, TEXT_BLIZZARD_TIP, StepAside)
    window.blizzard:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    if ns.AuctionScan then
        window.scan = Parts.BarButton(window, St.RESET, TEXT_SCAN, TEXT_SCAN_TIP, ns.AuctionScan, TEXT_SCAN)
        window.scan:SetPoint("RIGHT", window.blizzard, "LEFT", -BAR_GAP, 0)
    end
    tabs = Parts.Tabs(window, TAB_W * #PAGES, PAGES, ShowPage)
    tabs:SetPoint("TOPLEFT", PAD, -(HEADER + PAD))
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", PAD, -(HEADER + PAD + TAB_H + PAD))
    body:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + PAD)
    BuildAway()
    Parts.FooterBrand(window, PAGE)
end

local function Present(page)
    window.blizzard:SetShown(atAuction)
    if window.scan then window.scan:SetShown(atAuction) end
    window.backdrop:Paint(1)
    window:Show()
    ScanLine()
    if not ticker then ticker = C_Timer.NewTicker(SCAN_TICK, ScanLine) end
    ShowPage(page)
end

function Window.Show(ah, strata)
    if not window then Build() end
    atAuction = true
    window:SetScale(ns.UIScale())
    window:SetFrameStrata(strata)
    window:RegisterForDrag()
    local scale = ah:GetEffectiveScale() / window:GetEffectiveScale()
    window:SetSize(math.max(W, ah:GetWidth() * scale), math.max(H, ah:GetHeight() * scale + BLIZZARD_TABS))
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", ah, "TOPLEFT", 0, 0)
    Present(shown)
end

function Window.Open(page)
    if not window then Build() end
    atAuction = false
    window:SetScale(ns.UIScale())
    window:SetFrameStrata(AWAY_STRATA)
    window:RegisterForDrag("LeftButton")
    window:SetSize(W, H)
    window:ClearAllPoints()
    Parts.Place(window, POSITION)
    page = page or shown
    Present(AUCTION_ONLY[page] and AWAY_PAGE or page)
end

function Window.AtAuction()
    return atAuction and Window.Shown()
end

function ns.ToggleMarketWindow()
    if not Market.On() then return ns.Print(TEXT_OFF) end
    if Window.Shown() then return window:Hide() end
    if Window.Return() then return end
    Window.Open()
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
    if AUCTION_ONLY[shown] and not atAuction then return end
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
end
