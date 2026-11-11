-- Run with Lua 5.1 from the repository root: The Market at an auctioneer. Ours opens first, unless Open at
-- the Auctioneer is off, when Blizzard's window opens with The Market button above it; closing ours ends the
-- visit when ours opened first, or steps back to Blizzard's window. Post With Keys and Bag Worth start off.
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
check("Open at the Auctioneer starts on", defaults.openAtAuctioneer == true)
check("Post With Keys starts off", defaults.postKeys == false)
check("Bag Worth starts off", defaults.bagWorth == false)

local settings = { openAtAuctioneer = false }
local marketOn = true
local closes = 0

local function Frame()
    local f = { shown = false, alpha = 1, scripts = {} }
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetPoint() end
    return f
end

local ah = Frame()
function ah:GetFrameStrata() return "MEDIUM" end
function ah:HookScript(name, fn) self.scripts[name] = fn end
function ah:SetPostItem() end
function ah:Open() self.shown = true; self.scripts.OnShow(self) end
function ah:Close() self.shown = false; self.scripts.OnHide(self) end

local Window = { shown = false }
function Window.Show() Window.shown = true end
function Window.Hide(stepAside)
    if not Window.shown then return end
    Window.shown = false
    Window.onHide(stepAside)
end
function Window.Shown() return Window.shown end

local back
local ns = {
    Market = {
        Settings = { Get = function(k) return settings[k] end, OnChange = function() end },
        On = function() return marketOn end,
        Sell = { Reset = function() end },
        Window = Window,
    },
    Button = function(_, _, _, _, onClick)
        back = Frame()
        back.click = onClick
        return back
    end,
    Apply = function() end,
}

Load("NaowhForever_Market/UI/Takeover.lua", {
    _G = { NaowhForever = ns, AuctionHouseFrame = ah },
    C_AddOns = { IsAddOnLoaded = function() return true end },
    C_AuctionHouse = { CloseAuctionHouse = function() closes = closes + 1; ah:Close() end },
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) if old then old(...) end; fn(...) end
    end,
})

ah:Open()
check("off: Blizzard's window shows", ah.alpha == 1 and not Window.shown)
check("off: The Market button shows above it", back and back.shown)

back.click()
check("the button opens ours over Blizzard's", Window.shown and ah.alpha == 0 and not back.shown)

Window.Hide()
check("off: closing ours steps back to Blizzard's window", ah.shown and ah.alpha == 1 and back.shown)
check("off: closing ours keeps the visit", closes == 0)

ns.Apply()
check("another setting applying leaves Blizzard's window in front", not Window.shown and back.shown)

ah:Close()
check("leaving the auctioneer hides the button", not back.shown)

settings.openAtAuctioneer = true
ah:Open()
check("on: ours opens first", Window.shown and ah.alpha == 0 and not back.shown)
Window.Hide()
check("on: closing ours ends the visit", closes == 1 and not ah.shown)

marketOn, settings.openAtAuctioneer = false, false
ns.Apply()
ah:Open()
check("with The Market off, Blizzard's window is left alone", ah.alpha == 1 and not back.shown and not Window.shown)

print(checks .. " market takeover checks passed")
