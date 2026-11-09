-- SettingsPage.lua: The Market's settings page, declared as cards.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Settings = ns.Shared.Settings

local ORDER_SELLING, ORDER_BAGS, ORDER_PRICES, ORDER_KEYS = 10, 20, 30, 80
local TEXT_OFF = ns.L("Turn on The Market")
local TEXT_PROFESSIONS_OFF = "Turn on Professions"
local TEXT_NEEDS_TOOLTIP = ns.L("Needs Tooltip Lines")
local DURATIONS = { Market.C.DURATION_LABELS, Market.C.DURATIONS }
local UNDERCUTS = { { match = "Match the Cheapest", step = "Smallest Step", silver = "One Silver" },
    { "match", "step", "silver" } }
local STYLES = { { detailed = "Detailed", compact = "Compact" }, { "detailed", "compact" } }
local STACKS = { { each = "Each Item", stack = "Whole Stack", both = "Both" }, { "each", "stack", "both" } }

local function On()
    return Market.On()
end

local function Why()
    return ns.GamepadWhy() or TEXT_OFF
end

local function TooltipOn()
    return On() and S.Get("tooltip")
end

local function TooltipWhy()
    if not On() then return Why() end
    return TEXT_NEEDS_TOOLTIP
end

local function ProfessionsOn()
    local P = ns.Professions
    return P ~= nil and P.On() == true
end

local function Deal(key)
    local deals = ns.ProfessionSettings
    return deals ~= nil and deals.Get(key) == true
end

local function DealsOn()
    return ProfessionsOn() and Deal("disenchantDeals")
end

local function DealTooltipsOn()
    return DealsOn() and Deal("disenchantDealsTooltip")
end

local function PriceRows()
    local qol = ns.QoLSettings
    local rows = {
        { key = "ahPrices", label = "Scan Prices Button", toggle = true, store = qol,
          needs = ns.GamepadFree, why = ns.GamepadWhy,
          help = "A Scan Prices button on the auction house. It reads every listing and keeps the "
              .. "lowest buyout for each item, for this realm and faction. Blizzard allows one full "
              .. "scan every 15 minutes." },
        { key = "ahTooltip", label = "Auction House Price", toggle = true, store = qol,
          help = "Item tooltips show an item's auction house price and how old it is." },
        { key = "ahCrates", label = "Waylaid Crate Prices", toggle = true, store = qol,
          help = "Waylaid Crate tooltips show what each filling costs on the auction house." },
        { key = "ahCapture", label = "Capture Other Addons' Scans", toggle = true, store = qol,
          help = "Also keeps the prices from full auction house scans that other addons start, "
              .. "such as Auctionator or TSM." },
    }
    local deals = ns.ProfessionSettings
    if not deals then return rows end
    rows[#rows + 1] = { key = "disenchantDeals", label = "Disenchant Deals", toggle = true, store = deals,
        needs = ProfessionsOn, why = TEXT_PROFESSIONS_OFF,
        help = "Finds profitable or low-cost disenchant purchases from your last Scan Prices." }
    rows[#rows + 1] = { key = "disenchantDealsTooltip", label = "Detailed Deal Tooltips", toggle = true,
        store = deals, needs = DealsOn, why = "Needs Disenchant Deals",
        help = "Shows possible materials, expected value, required skill and profit on deal tooltips." }
    rows[#rows + 1] = { key = "disenchantDealsTooltipAllCharacters", label = "Show on All Characters",
        toggle = true, store = deals, needs = DealTooltipsOn, why = "Needs Detailed Deal Tooltips",
        help = "Shows detailed deal tooltips on characters without Enchanting." }
    rows[#rows + 1] = { key = "disenchantDealsTooltipAuctionOnly", label = "Only At Auction House",
        toggle = true, store = deals, needs = DealTooltipsOn, why = "Needs Detailed Deal Tooltips",
        help = "Only shows detailed deal tooltips while the auction house is open." }
    rows[#rows + 1] = { key = "disenchantDealsTooltipWorthOnly", label = "Only When Worth Disenchanting",
        toggle = true, store = deals, needs = DealTooltipsOn, why = "Needs Detailed Deal Tooltips",
        help = "Only shows detailed deal tooltips when disenchanting beats selling; Shift shows them anyway." }
    return rows
end

local function DurationSummary(store)
    return ns.L(DURATIONS[1][store.Get("duration")] or DURATIONS[1][1])
end

local page = Settings.Page("The Market/Settings", S)

page:Card({
    id = "selling", name = "Selling", order = ORDER_SELLING,
    help = "How The Market posts your items at an auctioneer.",
    summary = DurationSummary,
    rows = {
        { key = "postKeys", label = "Post With Keys", toggle = true, needs = On, why = Why,
          help = "Space posts the item in front of you, S skips it, Up and Down step its price." },
        { key = "duration", label = "Duration", choice = DURATIONS, needs = On, why = Why,
          help = "How long your auctions run." },
        { key = "undercut", label = "Undercut", choice = UNDERCUTS, needs = On, why = Why,
          help = "How far under the cheapest listing The Market prices your items." },
    },
})

page:Card({
    id = "bags", name = "Bags & Tooltips", order = ORDER_BAGS,
    help = "What your items are worth, away from the auction house too.",
    rows = {
        { key = "bagWorth", label = "Bag Worth", toggle = true, needs = On, why = Why,
          help = "A card on your bags with what they would fetch at your last scan, and their five most "
              .. "valuable items, numbered on their slots." },
        { key = "tooltip", label = "Tooltip Lines", toggle = true, needs = On, why = Why,
          help = "Item tooltips show what your stack fetches, how its price moved over the past week, and "
              .. "what disenchanting it gives." },
        { key = "tooltipStyle", label = "Tooltip Style", choice = STYLES, needs = TooltipOn, why = TooltipWhy,
          help = "Compact keeps only the auction, vendor and disenchant prices, one line each." },
        { key = "tooltipStack", label = "Stack Prices", choice = STACKS, needs = TooltipOn, why = TooltipWhy,
          help = "On a stack in your bags, prices read for each item, the whole stack, or both." },
        { key = "tooltipBest", label = "Best Way to Sell", toggle = true, needs = TooltipOn, why = TooltipWhy,
          help = "Says whether the auction house, a vendor or disenchanting pays you the most." },
    },
})

page:Card({
    id = "prices", name = "Prices & Deals", order = ORDER_PRICES,
    help = "Auction prices and Disenchant Deals, the same settings as in QoL and Professions.",
    search = "auction house scan prices tooltip waylaid crate capture disenchant deals enchanting",
    rows = PriceRows,
})

page:Card({
    id = "keys", name = "Key Binding", order = ORDER_KEYS,
    help = "The key that opens The Market.",
    rows = {
        { label = "Open The Market", binding = "NAOWHFOREVER_MARKET",
          help = "Press this key to open The Market, and again to close it." },
    },
})
