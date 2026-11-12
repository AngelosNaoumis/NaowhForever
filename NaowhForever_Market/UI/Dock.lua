-- Dock.lua: The Market at Blizzard's auction house: its panel docked to the right with Buy, Sell, My Auctions and Shopping List, and the Farm, Price Graph and Reagents tabs that dock The Market's window there instead (Market.Dock).
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local Parts = ns.Shared.Parts

local AH_ADDON = "Blizzard_AuctionHouseUI"
local AH_TABS = "LibAHTab-1-0"
local DOCK_W, PAD = St.DOCK_W, St.DOCK_PAD
local DOCK_GAP, HEAD_H = 4, 34
local NEXT_FRAME = 0
local WATCH_H = 20
local DRAG_BUTTON = "LeftButton"
local TEXT_TITLE = "The Market"
local TEXT_WATCH_ONE = ns.L("%d on your watch list is at or under your price")
local TEXT_WATCH_MANY = ns.L("%d on your watch list are at or under your price")
local PAGES = {
    { key = "buy", label = "Buy", tip = "Your watch list: the items you want, and when they are at or under your price." },
    { key = "sell", label = "Sell", tip = "Your bags, most valuable first, priced and posted." },
    { key = "mine", label = "My Auctions", tip = "Your auctions, and the ones someone is selling for less." },
    { key = "shop", label = "Shopping List", tip = "What your Shopping List and your alts' still need.", shopping = true },
}
local WINDOW_PAGES = { "farm", "prices", "reagents" }

local BLIZZARD_PAGES = { Buy = "buy", ItemBuy = "buy", CommoditiesBuy = "buy", WoWTokenBuy = "buy",
    ItemSell = "sell", CommoditiesSell = "sell", WoWTokenSell = "sell", Auctions = "mine" }

local dock, body, tabs, events, ah, watchLine, row
local shown = "buy"
local blizzardPage, docked
local built = {}
local closed = false

local Dock = {}
Market.Dock = Dock

local PaintWatch

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
    PaintWatch()
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

local function OpenWatch()
    Market.Pages.buy.ShowList()
    ShowPage("buy")
end

function PaintWatch()
    local n = shown ~= "buy" and Market.Watch.UnderCount() or 0
    watchLine:SetShown(n > 0)
    watchLine.text:SetText((n == 1 and TEXT_WATCH_ONE or TEXT_WATCH_MANY):format(n))
    body:SetPoint("TOPLEFT", n > 0 and watchLine or tabs, "BOTTOMLEFT", 0, -PAD)
end

local Activate

local function Changed()
    if ns.AuctionWindowChanged then ns.AuctionWindowChanged() end
end

local function Close()
    closed = true
    dock:Hide()
    Changed()
end

local function HasShopping()
    local P = ns.Professions
    return P ~= nil and P.Shopping ~= nil
end

local function Build()
    dock = Parts.Panel(TEXT_TITLE, true)
    dock:SetWidth(DOCK_W)
    dock.backdrop:Paint(1)
    dock.close:SetScript("OnClick", Close)
    dock:SetScript("OnKeyDown", OnKeyDown)
    dock:HookScript("OnHide", OnHidden)
    dock:RegisterForDrag(DRAG_BUTTON)
    dock:SetScript("OnDragStart", Market.Move.Start)
    dock:SetScript("OnDragStop", Market.Move.Stop)
    local pages = {}
    for _, page in ipairs(PAGES) do
        if not page.shopping or HasShopping() then pages[#pages + 1] = page end
    end
    tabs = Market.Tabs.Build(dock, DOCK_W - PAD * 2, pages, ShowPage)
    tabs:SetPoint("TOPLEFT", PAD, -HEAD_H)
    watchLine = CreateFrame("Button", nil, dock)
    watchLine:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, -PAD)
    watchLine:SetPoint("RIGHT", -PAD, 0)
    watchLine:SetHeight(WATCH_H)
    watchLine.text = ns.Font(watchLine, St.TEXT_SIZE, nil, St.HAVE_RGB)
    watchLine.text:SetPoint("LEFT")
    watchLine:SetScript("OnClick", OpenWatch)
    body = CreateFrame("Frame", nil, dock)
    body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

local function WindowPicked(key)
    docked = key
    Market.HouseTabs.Paint(row, key)
end

local function WindowClosed()
    docked, closed = nil, false
    Market.HouseTabs.Paint(row, nil)
    Activate()
end

local function TabClicked(key)
    if key == docked then return Market.Window.Hide() end
    docked = key
    if dock then dock:Hide() end
    Market.Window.DockTo(ah, key, DOCK_GAP, WindowPicked, WindowClosed)
    Changed()
end

local function LastTab()
    local lib = LibStub and LibStub(AH_TABS, true)
    local added = lib and lib.internalState and lib.internalState.Tabs
    if added and #added > 0 then return added[#added] end
    return ah.AuctionsTab
end

local function StyleRow()
    if not (row and row:IsShown()) then return end
    Market.HouseTabs.Style(row, LastTab(), ah.Tabs)
    Market.HouseTabs.Paint(row, docked)
end

local function ShowRow()
    if not row then
        local pages = {}
        for i, key in ipairs(WINDOW_PAGES) do
            for _, page in ipairs(Market.Window.PAGES) do
                if page.key == key then pages[i] = page end
            end
        end
        row = Market.HouseTabs.New(ah, pages, TabClicked)
    end
    row:Show()
    StyleRow()
end

function Activate()
    if not (Market.On() and ah and ah:IsShown()) then return end
    ShowRow()
    if closed or docked then return end
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
    dock:Show()
    ShowPage(shown)
    Changed()
end

local function Deactivate()
    if dock then dock:Hide() end
    docked = nil
    Market.Window.Undock()
    if row then row:Hide() end
    Changed()
end

local function OnBlizzardShow()
    closed = false
    Activate()
    C_Timer.After(NEXT_FRAME, StyleRow)
end

local function OnBlizzardHide()
    closed = false
    blizzardPage = nil
    Market.Move.Stop()
    Deactivate()
    Market.Sell.Reset()
end

function Dock.Shown()
    return dock ~= nil and dock:IsShown()
end

function Dock.AtAuction()
    return Dock.Shown() or docked ~= nil
end

function Dock.Pick(location)
    if not Dock.AtAuction() then return end
    if docked then Market.Window.Hide() end
    ShowPage("sell")
    Market.Pages.sell.PickLocation(location)
end

function Dock.Refresh()
    if not Dock.Shown() then return end
    PaintWatch()
    Market.Tabs.Paint(tabs, shown)
    local page = Market.Pages[shown]
    if page.Refresh then page.Refresh() else page.Show() end
end

function ns.MarketAuctionWindow()
    if Dock.Shown() then return dock end
    return Market.Window.Docked()
end

function ns.MarketAuctionTabs()
    if row and row:IsShown() then return row.buttons[#row.buttons] end
end

local function OnPostItem(_, location)
    if Dock.AtAuction() then C_Item.UnlockItem(location) end
    Dock.Pick(location)
end

local function PageOf(mode)
    for name, key in pairs(BLIZZARD_PAGES) do
        if AuctionHouseFrameDisplayMode[name] == mode then return key end
    end
end

local function OnDisplayMode()
    local key = PageOf(ah:GetDisplayMode())
    if not key or key == blizzardPage then return end
    blizzardPage = key
    if Dock.Shown() then
        ShowPage(key)
    else
        shown = key
    end
end

local function Hook()
    ah = _G.AuctionHouseFrame
    ah:HookScript("OnShow", OnBlizzardShow)
    ah:HookScript("OnHide", OnBlizzardHide)
    hooksecurefunc(ah, "SetPostItem", OnPostItem)
    hooksecurefunc(ah, "SetDisplayMode", OnDisplayMode)
    Market.Move.Hook(ah)
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
