-- Run with Lua 5.1 from the repository root: the edge the Professions panels at the auction house sit
-- beside: Blizzard's auction house window, or The Market's while it covers it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Frame()
    local f = { points = {} }
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(point, relative, relativePoint) self.points[#self.points + 1] = { point, relative, relativePoint } end
    function f:SetSize() end
    return f
end

local ah, market = Frame(), Frame()
local covering = false
local ns = { Professions = { Settings = {}, Recipes = {} } }
function ns.MarketAuctionWindow() if covering then return market end end
local env = setmetatable({ CreateFrame = function() return Frame() end, UIParent = Frame(), AuctionHouseFrame = ah },
    { __index = _G })
env._G = env
env.NaowhForever = ns
local fn = assert(loadfile("NaowhForever_Professions/AuctionHouse.lua"))
setfenv(fn, env)
fn()
local AH = ns.Professions.AH

ns.AuctionWindowChanged()
local edge = AH.Edge()
check("with no panel placed yet, a change does nothing", edge ~= nil)
check("the panels sit beside Blizzard's auction house", #edge.points == 1 and edge.points[1][2] == ah
    and edge.points[1][3] == "TOPRIGHT")
covering = true
ns.AuctionWindowChanged()
check("beside The Market while it covers it", #edge.points == 1 and edge.points[1][2] == market)
check("on the same edge, so every panel anchored to it follows", AH.Edge() == edge)
covering = false
ns.AuctionWindowChanged()
check("and back beside Blizzard's when The Market steps aside", edge.points[1][2] == ah)
ns.MarketAuctionWindow = nil
check("without The Market, Blizzard's window", AH.Edge().points[1][2] == ah)

print(("test-professions-ah-panels: %d checks passed"):format(checks))
