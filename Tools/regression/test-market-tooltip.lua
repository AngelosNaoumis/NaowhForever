-- Run with Lua 5.1 from the repository root: The Market's tooltip lines, their Compact style, stack prices and the
-- best way to sell.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local CLOTH, GREEN, BOUND = 2589, 7000, 7001
local t = World.Setup({ vendor = { [CLOTH] = 10, [GREEN] = 20, [BOUND] = 20 } })
local ns, env, S = t.ns, t.env, t.ns.MarketSettings
local post
local skill, dust = 0, 1000
ns.THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 } }
ns.Market.Style = { HAVE_RGB = { r = 0.3, g = 0.82, b = 0.48 }, RED_RGB = { r = 0.97, g = 0.44, b = 0.44 } }
ns.Professions = {
    DisenchantValues = {
        ItemTakes = function(id) return id == GREEN or id == BOUND end,
        RequiredSkill = function() return 25 end,
        Expected = function() return dust end,
        AfterCut = function(gross) return math.floor(gross * 0.95) end,
    },
    DisenchantDeals = { MeetsSkill = function(required) return skill >= required end },
}
env.Enum.TooltipDataType = { Item = 0 }
env.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) post = fn end }
env.TooltipUtil = { GetDisplayedItem = function(tooltip) return nil, tooltip.link end }
env.C_CurrencyInfo = { GetCoinTextureString = function(copper) return copper .. "c" end }
env.C_Item.GetDetailedItemLevelInfo = function() return 30 end
Load({ "NaowhForever_Market/UI/Tooltip.lua" }, env)

t.scan, t.scanAt = { [CLOTH] = 100, [GREEN] = 900 }, 1
t.bags[0] = { World.Stack(CLOTH, 20), World.Stack(GREEN, 1), World.Stack(BOUND, 1, { isBound = true }) }

local function Tooltip(itemID, slot)
    local tooltip = { link = "item:" .. itemID, lines = {}, lefts = {} }
    function tooltip:GetOwner() return self.owner end
    function tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tooltip:AddDoubleLine(left, right, r)
        self.lines[#self.lines + 1] = left .. " | " .. right
        self.lefts[#self.lines] = r
    end
    if slot then tooltip.owner = { GetBagID = function() return 0 end, GetID = function() return slot end } end
    return tooltip
end

local function Hover(itemID, slot)
    local tooltip = Tooltip(itemID, slot)
    if post then post(tooltip, { id = itemID }) end
    return table.concat(tooltip.lines, "\n"), tooltip
end

local function Shows(itemID, slot)
    return ns.Market.ShowsPrice(Tooltip(itemID, slot), itemID)
end

Check("nothing hooks before The Market is on", post == nil and not Shows(CLOTH, 1))
S.Set("enabled", true)
t.Fire("PLAYER_LOGIN")
Check("turned on, the tooltip is hooked", post ~= nil)

Check("by default a stack reads as today: the header and the stack's worth",
    Hover(CLOTH, 1) == "The Market\nStack of 20 | 2000c" and not Shows(CLOTH, 1))
Check("and a green its disenchant value", Hover(GREEN, 2) == "The Market\nDisenchant | about 950c")
Check("away from your bags it is one item, with no stack line", Hover(CLOTH) == "")

S.Set("tooltipStack", "each")
Check("Each Item leaves the stack line off, so Auction Prices' each line stands alone",
    Hover(CLOTH, 1) == "" and not Shows(CLOTH, 1))
S.Set("tooltipStack", "stack")
Check("Whole Stack keeps the stack line and takes the price from Auction Prices on a stack",
    Hover(CLOTH, 1) == "The Market\nStack of 20 | 2000c" and Shows(CLOTH, 1))
Check("but not on a single item", not Shows(GREEN, 2) and not Shows(CLOTH))

S.Set("tooltipStyle", "compact")
S.Set("tooltipStack", "both")
Check("Compact prices a stack both ways on one line each, with no header",
    Hover(CLOTH, 1) == "Auction | 100c each, 2000c for 20\nVendor | 10c each, 200c for 20")
Check("and always takes the price from Auction Prices", Shows(CLOTH, 1) and Shows(GREEN, 2) and Shows(CLOTH))
local unlinked = Tooltip(CLOTH, 1)
unlinked.link = nil
Check("but not on a tooltip it cannot read the item from, which would leave it without a price",
    not ns.Market.ShowsPrice(unlinked, CLOTH))
S.Set("tooltipStack", "each")
Check("Compact with Each Item", Hover(CLOTH, 1) == "Auction | 100c each\nVendor | 10c each")
S.Set("tooltipStack", "stack")
Check("Compact with Whole Stack", Hover(CLOTH, 1) == "Auction | 2000c for 20\nVendor | 200c for 20")
Check("a single item reads plain", Hover(GREEN, 2) == "Auction | 900c\nVendor | 20c\nDisenchant | about 950c")

S.Set("tooltipBest", true)
local text, tooltip = Hover(CLOTH, 1)
Check("the verdict leads, after the cut, for the whole stack",
    text == "Best: Auction | +1700c over Vendor\nAuction | 2000c for 20\nVendor | 200c for 20"
        and tooltip.lefts[1] == ns.THEME.accent.r and tooltip.lefts[2] == ns.THEME.muted.r)
S.Set("tooltipStack", "each")
Check("and for one item with Each Item", Hover(CLOTH, 1):find("^Best: Auction | %+85c over Vendor\n") ~= nil)
Check("disenchanting is no way to sell for a character who cannot",
    Hover(GREEN, 2):find("^Best: Auction | %+835c over Vendor\n") ~= nil)
skill = 25
Check("and wins for one who can", Hover(GREEN, 2):find("^Best: Disenchant | %+95c over Auction\n") ~= nil)
Check("a bound item weighs a vendor against disenchanting",
    Hover(BOUND, 3) == "Best: Disenchant | +930c over Vendor\nVendor | 20c\nDisenchant | about 950c")
t.scan[GREEN] = nil
Check("with no auction price the verdict names only what it beat",
    Hover(GREEN, 2):find("^Better: Disenchant | %+930c over Vendor\n") ~= nil)
dust = nil
Check("with neither priced there is no verdict", Hover(GREEN, 2) == "Vendor | 20c")
dust, t.scan[GREEN] = 1000, 900

S.Set("tooltipStyle", "detailed")
S.Set("tooltipStack", "both")
Check("Detailed puts the verdict under the header, then today's lines",
    Hover(CLOTH, 1) == "The Market\nBest: Auction | +1700c over Vendor\nStack of 20 | 2000c")
S.Set("tooltipBest", false)
Check("and back to today's lines with it off", Hover(CLOTH, 1) == "The Market\nStack of 20 | 2000c")

S.Set("tooltipStyle", "compact")
S.Set("tooltip", false)
Check("Tooltip Lines off: nothing drawn, the price left to Auction Prices", Hover(CLOTH, 1) == ""
    and not Shows(CLOTH, 1))
S.Set("tooltip", true)
S.Set("enabled", false)
Check("The Market off: the same", Hover(CLOTH, 1) == "" and not Shows(CLOTH, 1))

print("market tooltip: " .. checks .. " checks passed")
