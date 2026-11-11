-- Run with Lua 5.1 from the repository root: The Market at an auctioneer. Blizzard's window is left as it is and
-- The Market's panel docks to its right with Sell first; its X closes only the panel, a button above Blizzard's window
-- brings it back, and leaving the auctioneer closes it. Post With Keys and Bag Worth start off.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Load(path, env)
    local fn = assert(loadfile(path))
    setfenv(fn, setmetatable(env, { __index = _G }))
    fn()
end

local defaults
Load("NaowhForever_Market/Market.lua", {
    _G = { NaowhForever = {
        FEATURES = { market = { enabled = false } },
        UI = { ModuleSettings = function(_, d) defaults = d; return {} end },
    } },
    C_CVar = { GetCVarDefault = function() return "2" end },
})
check("there is no setting to open The Market instead of Blizzard's window", defaults.openAtAuctioneer == nil)
check("Post With Keys starts off", defaults.postKeys == false)
check("Bag Worth starts off", defaults.bagWorth == false)

local function Frame()
    local f = { shown = false, alpha = 1, scripts = {}, points = {} }
    function f:IsShown() return self.shown end
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetPoint(point, relative, relativePoint) self.points[point] = { relative, relativePoint } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...) if old then old(...) end; fn(...) end
    end
    function f:SetWidth() end
    function f:SetScale(s) self.scale = s end
    function f:GetScale() return 1 end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return "MEDIUM" end
    function f:EnableKeyboard(on) self.keys = on end
    function f:SetPropagateKeyboardInput() end
    function f:UnregisterAllEvents() end
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    return f
end

local settings = { postKeys = false }
local marketOn = true
local closes, resets = 0, 0

local ah = Frame()
function ah:SetPostItem() end
function ah:Open() self:Show() end
function ah:Close() self:Hide() end

local function Page()
    local page = { shows = 0 }
    function page.Build() page.built = true end
    function page.Show() page.shows, page.shown = page.shows + 1, true end
    function page.Hide() page.shown = false end
    function page.PickLocation(location) page.picked = location end
    return page
end

local pickTab, back, panel, coin, opened
local ns = {
    Market = {
        Settings = { Get = function(k) return settings[k] end, OnChange = function() end },
        On = function() return marketOn end,
        Sell = { Reset = function() resets = resets + 1 end },
        Style = { COINS = "coins", BAR_GAP = 8 },
        Pages = { sell = Page(), mine = Page() },
        Tabs = {
            Build = function(_, _, _, onPick)
                pickTab = onPick
                return Frame()
            end,
            Paint = function() end,
        },
        Window = { Open = function() opened = true end },
    },
    Shared = { Parts = {
        Panel = function()
            panel = Frame()
            panel.close, panel.title = Frame(), Frame()
            panel.backdrop = { Paint = function() end }
            return panel
        end,
        BarButton = function(_, _, _, _, onClick)
            coin = Frame()
            coin.click = onClick
            return coin
        end,
    } },
    L = function(text) return text end,
    Button = function(_, _, _, _, onClick)
        back = Frame()
        back.click = onClick
        return back
    end,
    Apply = function() end,
}
local Pages = ns.Market.Pages

Load("NaowhForever_Market/UI/Dock.lua", {
    _G = { NaowhForever = ns, AuctionHouseFrame = ah },
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_AuctionHouse = { CloseAuctionHouse = function() closes = closes + 1 end },
    CreateFrame = function() return Frame() end,
    InCombatLockdown = function() return false end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) if old then old(...) end; fn(...) end
    end,
})
local Dock = ns.Market.Dock

check("nothing shows before the auction house opens", not Dock.Shown())

ah:Open()
check("Blizzard's window is left as it is", ah.shown and ah.alpha == 1)
check("The Market's panel shows beside it", Dock.Shown() and panel.points.TOPLEFT[1] == ah
    and panel.points.TOPLEFT[2] == "TOPRIGHT" and panel.points.BOTTOMLEFT[2] == "BOTTOMRIGHT")
check("on Blizzard's strata", panel.strata == "MEDIUM")
check("with Sell first", Pages.sell.shown and not Pages.mine.shown)
check("Professions' panels sit beside the panel", ns.MarketAuctionWindow() == panel)
check("with Post With Keys off, the panel takes no keys", panel.keys == false)

coin.click()
check("the coin button opens The Market's window", opened)

pickTab("mine")
check("My Auctions takes Sell's place", Pages.mine.shown and not Pages.sell.shown)

local location = {}
ah:SetPostItem(location)
check("right-clicking a bag item picks it on Sell", Pages.sell.shown and Pages.sell.picked == location)

panel.close.scripts.OnClick()
check("the X closes only the panel", not Dock.Shown() and ah.shown and closes == 0)
check("and stops its page", not Pages.sell.shown)
check("a button above Blizzard's window brings it back", back and back.shown)
check("Professions' panels go back beside Blizzard's window", ns.MarketAuctionWindow() == nil)

back.click()
check("the button opens the panel again", Dock.Shown() and not back.shown and Pages.sell.shown)

panel.close.scripts.OnClick()
ah:Close()
check("leaving the auctioneer hides the button", not back.shown and not Dock.Shown())
check("and forgets what you posted", resets == 1)

ah:Open()
check("the next visit opens the panel again", Dock.Shown())

ah:Close()
settings.postKeys = true
ah:Open()
check("with Post With Keys on, the panel takes keys", panel.keys == true)
ah:Close()

marketOn = false
ns.Apply()
ah:Open()
check("with The Market off, Blizzard's window is left alone", ah.alpha == 1 and not Dock.Shown()
    and not back.shown)

print(checks .. " market dock checks passed")
