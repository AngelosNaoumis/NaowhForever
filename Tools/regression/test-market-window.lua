-- Run with Lua 5.1 from the repository root: The Market's own window, free or docked beside the auction house. Free,
-- it opens at its saved spot, its own size and strata, and drags. Docked, it sits right of Blizzard's window, top to
-- bottom, on its strata, as wide as the screen leaves room for (never past its right edge, never under its minimum);
-- a drag needs Shift and moves Blizzard's window; its X closes it as its tab would, and it goes back to its free spot
-- afterwards.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Frame()
    local f = { shown = false, scripts = {}, points = {} }
    function f:IsShown() return self.shown end
    function f:Show()
        if self.shown then return end
        self.shown = true
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end; fn(...) end
    end
    function f:SetPoint(point, relative, relativePoint, x, y) self.points[point] = { relative, relativePoint, x, y } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetWidth(w) self.w = w end
    function f:SetClampRectInsets(left, right, top, bottom) self.insets = { left, right, top, bottom } end
    function f:GetWidth() return self.w end
    function f:GetRight() return self.right end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale or 1 end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return self.strata end
    function f:SetText() end
    function f:SetVertexColor() end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:SetTexture() end
    function f:CreateTexture() return Frame() end
    return f
end

local function Page()
    local page = { shows = 0 }
    function page.Build() end
    function page.Show() page.shown, page.shows = true, page.shows + 1 end
    function page.Hide() page.shown = false end
    return page
end

local placed, moves, freeStops = 0, {}, 0
local ns = {
    THEME = { muted = {} },
    L = function(text) return text end,
    UIScale = function() return 0.8 end,
    Font = function() return Frame() end,
    Market = {
        Style = { WINDOW_W = 1144, WINDOW_H = 650, WINDOW_HEADER = 50, WINDOW_PAD = 10, WINDOW_FOOTER = 20, BAR_GAP = 8,
            TAB_H = 26, SMALL_SIZE = 11, HAVE_RGB = {}, WARN_RGB = {} },
        Tabs = { Build = function() return Frame() end, Paint = function() end },
        Move = { Start = function() moves[#moves + 1] = "start" end, Stop = function() moves[#moves + 1] = "stop" end },
    },
    Shared = { Parts = {
        Window = function(w, h)
            local window = Frame()
            window:SetSize(w, h)
            window.strata = "HIGH"
            function window:StartMoving() self.moving = true end
            window.scripts.OnDragStart = window.StartMoving
            window.scripts.OnDragStop = function() freeStops = freeStops + 1 end
            window:SetClampRectInsets(1030, -1030, 0, 585)
            window.scripts.OnSizeChanged = function(self, width, height)
                self:SetClampRectInsets(width * 0.9, -width * 0.9, 0, height * 0.9)
            end
            window.backdrop = { Paint = function() end }
            window.subtitle = Frame()
            return window
        end,
        TitleBar = function() return Frame() end,
        BarButton = function() return Frame() end,
        FooterBrand = function() end,
        Place = function(window) placed = placed + 1; window:SetPoint("CENTER", "saved") end,
    } },
}
local screen = Frame()
screen.right, screen.scale = 1920, 1
local env = setmetatable({
    _G = { NaowhForever = ns },
    UIParent = screen,
    CreateFrame = function() return Frame() end,
    C_Timer = { NewTicker = function() return { Cancel = function() end } end },
    GetServerTime = function() return 0 end,
}, { __index = _G })
local fn = assert(loadfile("NaowhForever_Market/UI/Window.lua"))
setfenv(fn, env)
fn()
local Window, Pages = ns.Market.Window, ns.Market.Pages
Pages.farm, Pages.reagents, Pages.prices = Page(), Page(), Page()

check("its pages are offered to the auction house's tabs", #Window.PAGES == 3 and Window.PAGES[1].key == "farm")
check("the prices page is labelled Price Graph", Window.PAGES[3].key == "prices" and Window.PAGES[3].label == "Price Graph")

local ah = Frame()
ah.strata, ah.scale, ah.right = "MEDIUM", 1, 820
local picked, closed = {}, 0
local function OnPick(key) picked[#picked + 1] = key end
local function OnClose() closed = closed + 1 end

Window.DockTo(ah, "prices", 4, OnPick, OnClose)
local window = Window.Docked()
check("docked, it shows its page right of Blizzard's window", window and window.shown and Pages.prices.shown
    and window.points.TOPLEFT[1] == ah and window.points.TOPLEFT[2] == "TOPRIGHT" and window.points.TOPLEFT[3] == 4)
check("top to bottom, at Blizzard's window's height", window.points.BOTTOMLEFT[1] == ah
    and window.points.BOTTOMLEFT[2] == "BOTTOMRIGHT")
check("at its own width where the screen has room for it", window.w == 1144)
check("on Blizzard's strata", window.strata == "MEDIUM")
check("and says which page it shows", picked[1] == "prices")
ah.right = 1300
Window.DockTo(ah, "farm", 4, OnPick, OnClose)
check("narrowed to end at the screen's right edge, in its own scale", window.w == math.floor((1920 - 1300) / 0.8 - 4)
    and Pages.farm.shown and not Pages.prices.shown and picked[2] == "farm")
ah.right = 1500
local shows = Pages.farm.shows
Window.FitDock()
check("never under its minimum, where the pages still lay out", window.w == 700)
window.scripts.OnSizeChanged(window, 700, 538)
check("and wider than the room there is, it is kept whole on the screen, over Blizzard's window",
    window.insets[1] == 0 and window.insets[2] == 0 and window.insets[3] == 0 and window.insets[4] == 0)
check("and its page redrawn at the new width", Pages.farm.shows == shows + 1)
Window.FitDock()
check("a fit that changes nothing redraws nothing", Pages.farm.shows == shows + 1)
screen.scale, ah.scale = 2, 2
Window.FitDock()
check("Blizzard's window and the screen read in their own scales", window.w == math.floor((1920 - 1500) * 2 / 0.8 - 4))
screen.scale, ah.scale, ah.right = 1, 1, 820
Window.FitDock()
check("a move back gives it its full width again", window.w == 1144)

window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
check("a drag on it is the auction house's Shift + drag", moves[1] == "start" and moves[2] == "stop"
    and not window.moving and freeStops == 0)

window:Hide()
check("its X closes it as its tab would", closed == 1 and not Window.Docked())
check("and puts it back to its free spot, size and strata", placed == 1 and window.w == 1144 and window.h == 650
    and window.strata == "HIGH" and window.points.CENTER and not window.points.BOTTOMLEFT)
window.scripts.OnSizeChanged(window, 1144, 650)
check("free again, it may be dragged most of the way off the screen as before", window.insets[1] > 1000
    and window.insets[2] < -1000)
local fits = Pages.farm.shows
Window.FitDock()
check("free, a move of Blizzard's window leaves it alone", window.w == 1144 and Pages.farm.shows == fits)

ns.foreverSkin = true
ns.Market.Style.FOREVER_TITLE_H, ns.Market.Style.FOREVER_SIDE = 21, 2
ah.right = 1300
Window.DockTo(ah, "farm", 4, OnPick, OnClose)
check("with the Forever look, its frame's title bar and sides stay within Blizzard's window's height",
    window.points.TOPLEFT[3] == 4 + 2 and window.points.TOPLEFT[4] == -21 and window.points.BOTTOMLEFT[4] == 2
    and window.w == math.floor((1920 - 1300) / 0.8 - 4 - 2 * 2))
ns.foreverSkin, ah.right = nil, 820
Window.Undock()
check("put away by the auction house, it is not a close", closed == 1 and not window.shown and not Window.Docked())

Window.DockTo(ah, "reagents", 4, OnPick, OnClose)
Window.Open("prices")
check("opened from the key or /market while docked, it goes free and its tab lets go", closed == 2
    and not Window.Docked() and window.shown and window.points.CENTER and window.scale == 0.8)
window.scripts.OnDragStart(window)
window.scripts.OnDragStop(window)
check("free, it drags and keeps its spot", window.moving and freeStops == 1 and #moves == 2)
local count = #picked
window:Hide()
check("free, closing it tells no tab", closed == 2 and #picked == count)

-- The pages at the docked window's narrowest, from the numbers their files lay out with.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
local function Numbers(path)
    local found = {}
    for names, values in Read(path):gmatch("local ([%u_][%w_, ]-) = ([%d%., ]+)\r?\n") do
        local list = {}
        for v in values:gmatch("[%d%.]+") do list[#list + 1] = tonumber(v) end
        local i = 0
        for name in names:gmatch("[%u%d_]+") do
            i = i + 1
            found[name] = list[i]
        end
    end
    return found
end
local win, prices = Numbers("NaowhForever_Market/UI/Window.lua"), Numbers("NaowhForever_Market/UI/Prices.lua")
local farm, finder = Numbers("NaowhForever_Market/UI/Farm.lua"), Numbers("NaowhForever_Market/View/Finder.lua")
local money = Numbers("Shared/UI/Money.lua")
local pad = tonumber(Read("Shared/Style.lua"):match("WINDOW_PAD = (%d+)"))
local body = win.DOCK_MIN_W - pad * 2
check("at its narrowest, the window's three tabs fit along its bottom", win.TAB_W * 3 <= body)
local priceRoom = body - prices.LIST_W - prices.PANE_GAP
local moneyW = money.GOLD_W + (money.SMALL_W + money.BOX_GAP) * 2
check("Price Graph's Watch row, Stop Watching included, fits beside its list",
    moneyW + finder.WATCH_GAP + prices.BUTTON_W * 2 + finder.GAP <= priceRoom)
local strip = farm.ROW_IN * 2 + farm.STRIP_ICON
local map = body - farm.ZONES_W - farm.PANE_GAP
check("Farm's strip drops its 14 days of prices there", map < farm.STRIP_FULL_W)
check("and still leaves its item's name room", map - strip - farm.PANE_GAP * 2 - farm.KV_NARROW_W - farm.OPEN_W
    - farm.ROW_IN >= farm.STRIP_ICON * 2)
local full = tonumber(Read("NaowhForever_Market/View/Style.lua"):match("WINDOW_W = (%d+)")) - pad * 2
check("at the window's own width the strip has all of it", full - farm.ZONES_W - farm.PANE_GAP >= farm.STRIP_FULL_W)
check("the strip's full layout leaves its item's name room too", farm.STRIP_FULL_W - strip - farm.PANE_GAP * 3
    - farm.SPARK_W - farm.KV_W - farm.OPEN_W - farm.ROW_IN >= farm.STRIP_ICON * 2)

local told, on = {}, false
local M = ns.Market
M.On = function() return on end
M.History = { Seen = function(ids, n) told[#told + 1] = "history " .. ids[1] .. " " .. n end }
M.BagWorth = { Changed = function() told[#told + 1] = "bags" end }
M.Crafts = { Changed = function() told[#told + 1] = "crafts" end }
M.Farm = { Changed = function() told[#told + 1] = "farm" end }
ns.MarketPricesSeen({ 2589 }, 1)
check("prices seen at the auction house reach nothing with The Market off", #told == 0)
on = true
ns.MarketPricesSeen({ 2589 }, 1)
check("and with it on, the price history, Bag Worth, Crafts and Farm, without a redraw",
    table.concat(told, ", ") == "history 2589 1, bags, crafts, farm")

print(("test-market-window: %d checks passed"):format(checks))
