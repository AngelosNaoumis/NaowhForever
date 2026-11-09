-- Window.lua: The Market's window: its title bar with the scan line, its pages, and the button to Blizzard's window (ns.Market.Window).
local ns = _G.NaowhForever

local Market = ns.Market
local Parts = ns.Shared.Parts
local St = Market.Style

local W, H = St.WINDOW_W, St.WINDOW_H
local HEADER, PAD, FOOTER, BAR_GAP = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.BAR_GAP
local SCAN_TICK = 60
local SECONDS_PER_MINUTE = 60
local FRESH = 3600
local DOT, DOT_GAP = 7, 8
local DOT_TEXTURE = "Interface\\AddOns\\NaowhForever\\Core\\Media\\circle_mask.tga"
local COG = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Navigation\\settings.tga"
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
local TEXT_SCAN_IN = ns.L("Scan in %dm")
local TEXT_SETTINGS = ns.L("Settings")
local TEXT_SETTINGS_TIP = ns.L("The Market's settings.")
local TEXT_BLIZZARD = ns.L("Blizzard's Auction House")
local TEXT_BLIZZARD_TIP = ns.L("Blizzard's own window, until you leave the auctioneer.")
local TEXT_AWAY = ns.L("At an auctioneer")
local TEXT_AWAY_BODY = ns.L("Sell, Buy and My Auctions open over the auction house. Talk to an auctioneer to use them.")
local TEXT_OFF = ns.L("Turn on The Market in its settings to open it.")
local PAGES = {
    { key = "farm", label = "Farm", icon = "map", tip = "Where your skills gather the most, priced from your last scan, and a loop through it." },
    { key = "run", label = "Last Run", icon = "bars", tip = "Your last gathering run: its gold over time and its haul." },
    { key = "sell", label = "Sell", icon = "coins", tip = "Your bags, most valuable first, posted one key press at a time.",
      auction = true },
    { key = "crafts", label = "Crafts", icon = "hammer", tip = "What your characters' recipes make from your bags, priced from your last scan." },
    { key = "buy", label = "Buy", icon = "search", tip = "Search by name, or pick from your Shopping List, and buy it.", auction = true },
    { key = "mine", label = "My Auctions", icon = "notes", tip = "Your auctions, and the ones someone is selling for less.",
      auction = true },
}
local AUCTION_ONLY = {}
for _, page in ipairs(PAGES) do AUCTION_ONLY[page.key] = page.auction == true end

local window, body, ticker, away
local shown = "sell"
local atAuction = false
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
    if not window.scan then return end
    local wait = ns.AuctionScanWait and ns.AuctionScanWait()
    local ready = not (wait and wait > 0)
    window.scan.label:SetText(ready and TEXT_SCAN or TEXT_SCAN_IN:format(math.ceil(wait / SECONDS_PER_MINUTE)))
    St.Enable(window.scan, ready)
end

local function ShowPage(key)
    if built[shown] and shown ~= key then Market.Pages[shown].Hide() end
    shown = key
    Market.Rail.Paint(key, atAuction)
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

local function OpenSettings()
    ns.OpenOptionsWindow(PAGE)
end

local function Scan()
    if ns.AuctionScan then ns.AuctionScan() end
    ScanLine()
end

local function PlaceStatus()
    local left = window.scan and window.scan:IsShown() and window.scan
        or window.blizzard:IsShown() and window.blizzard or window.cog
    window.status:ClearAllPoints()
    window.status:SetPoint("RIGHT", left, "LEFT", -BAR_GAP, 0)
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
    window.cog = Parts.BarButton(window, COG, TEXT_SETTINGS, TEXT_SETTINGS_TIP, OpenSettings)
    window.cog:SetPoint("RIGHT", close, "LEFT", -BAR_GAP, 0)
    window.blizzard = Parts.BarButton(window, St.EYE, TEXT_BLIZZARD, TEXT_BLIZZARD_TIP, StepAside)
    window.blizzard:SetPoint("RIGHT", window.cog, "LEFT", -BAR_GAP, 0)
    if ns.AuctionScan then
        window.scan = Parts.BarButton(window, St.RESET, TEXT_SCAN, TEXT_SCAN_TIP, Scan, TEXT_SCAN)
        window.scan:SetPoint("RIGHT", window.blizzard, "LEFT", -BAR_GAP, 0)
    end
    window.status = ns.Font(window, St.SMALL_SIZE, nil, ns.THEME.muted)
    window.dot = window:CreateTexture(nil, "ARTWORK")
    window.dot:SetTexture(DOT_TEXTURE, nil, nil, "TRILINEAR")
    window.dot:SetSize(DOT, DOT)
    window.dot:SetPoint("RIGHT", window.status, "LEFT", -DOT_GAP, 0)
    window.subtitle:SetPoint("RIGHT", window.dot, "LEFT", -BAR_GAP, 0)
    local rail = Market.Rail.Build(window, PAGES, ShowPage)
    rail:SetPoint("TOPLEFT", 0, -HEADER)
    rail:SetPoint("BOTTOMLEFT", 0, FOOTER)
    body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", rail, "TOPRIGHT", PAD, -PAD)
    body:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + PAD)
    BuildAway()
    Parts.FooterBrand(window, PAGE)
end

local function Present(page)
    window.blizzard:SetShown(atAuction)
    if window.scan then window.scan:SetShown(atAuction) end
    PlaceStatus()
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

function ns.MarketAuctionWindow()
    if Window.AtAuction() then return window end
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
    Market.Rail.Paint(shown, atAuction)
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
