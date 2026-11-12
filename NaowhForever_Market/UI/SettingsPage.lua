-- SettingsPage.lua: The Market's settings page, declared as cards.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Settings = ns.Shared.Settings

local ORDER_SELLING, ORDER_AUCTIONS, ORDER_BAGS, ORDER_PRICES, ORDER_WATCH, ORDER_KEYS = 10, 15, 20, 30, 40, 80
local TEXT_OFF = ns.L("Turn on The Market")
local TEXT_PROFESSIONS_OFF = "Turn on Professions"
local TEXT_NEEDS_TOOLTIP = ns.L("Needs Tooltip Lines")
local TEXT_NEEDS_BAG_WORTH = ns.L("Needs Bag Worth")
local TEXT_NEEDS_BEST = ns.L("Needs Best Way to Sell")
local TEXT_NEEDS_PERCENT = ns.L("Needs Undercut on Percent")
local TEXT_NEEDS_AMOUNT = ns.L("Needs Undercut on Fixed Amount")
local MARGIN_RANGE = { 0, 100, 1 }
local UNDERCUT_PERCENT_RANGE = { 1, 50, 1 }
local UNDERCUT_AMOUNT_RANGE = { 1, 500, 1 }
local AHEAD_RANGE = { 0, 200, 1 }
local DURATIONS = { Market.C.DURATION_LABELS, Market.C.DURATIONS }
local UNDERCUTS = { { match = "Match the Cheapest", step = "Smallest Step", silver = "One Silver",
    percent = "Percent", amount = "Fixed Amount" }, { "match", "step", "silver", "percent", "amount" } }
local STYLES = { { detailed = "Detailed", compact = "Compact" }, { "detailed", "compact" } }
local STACKS = { { each = "Each Item", stack = "Whole Stack", both = "Both" }, { "each", "stack", "both" } }
local QUANTITY_ALL = 0
local QUANTITIES = { { class = Enum.ItemClass.Tradegoods, key = "sellQuantityTrade" },
    { class = Enum.ItemClass.Consumable, key = "sellQuantityConsumable" },
    { class = Enum.ItemClass.Recipe, key = "sellQuantityRecipe" }, { key = "sellQuantityOther" } }
local TEXT_QUANTITY, TEXT_QUANTITY_JOIN = "%s %s", ", "
local TEXT_ALL, TEXT_OTHER = ns.L("All"), ns.L("Other Items")

local function On()
    return Market.On()
end

local function Why()
    return ns.GamepadWhy() or TEXT_OFF
end

local function BagWorthOn()
    return On() and S.Get("bagWorth")
end

local function BagWorthWhy()
    if not On() then return Why() end
    return TEXT_NEEDS_BAG_WORTH
end

local function TooltipOn()
    return On() and S.Get("tooltip")
end

local function TooltipWhy()
    if not On() then return Why() end
    return TEXT_NEEDS_TOOLTIP
end

local function BestOn()
    return TooltipOn() and S.Get("tooltipBest")
end

local function BestWhy()
    if not TooltipOn() then return TooltipWhy() end
    return TEXT_NEEDS_BEST
end

local function PercentOn()
    return On() and S.Get("undercut") == "percent"
end

local function PercentWhy()
    if not On() then return Why() end
    return TEXT_NEEDS_PERCENT
end

local function AmountOn()
    return On() and S.Get("undercut") == "amount"
end

local function AmountWhy()
    if not On() then return Why() end
    return TEXT_NEEDS_AMOUNT
end

local function QuantityNote()
    local parts = {}
    for i, kind in ipairs(QUANTITIES) do
        local quantity = S.Get(kind.key)
        parts[i] = TEXT_QUANTITY:format(kind.class and C_Item.GetItemClassInfo(kind.class) or TEXT_OTHER,
            quantity == QUANTITY_ALL and TEXT_ALL or quantity)
    end
    return table.concat(parts, TEXT_QUANTITY_JOIN)
end

local function ResetQuantities()
    for _, kind in ipairs(QUANTITIES) do S.Set(kind.key, QUANTITY_ALL) end
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
    local rows = {}
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
        { key = "undercutPercent", label = "Undercut Percent", slider = UNDERCUT_PERCENT_RANGE, unit = "%",
          needs = PercentOn, why = PercentWhy,
          help = "How many percent under the cheapest listing your price goes." },
        { key = "undercutAmount", label = "Undercut Amount", slider = UNDERCUT_AMOUNT_RANGE, unit = "s",
          scale = Market.C.SILVER, needs = AmountOn, why = AmountWhy,
          help = "How much under the cheapest listing your price goes." },
        { key = "askBadPost", label = "Ask Before a Bad Post", toggle = true, needs = On, why = Why,
          help = "Asks before posting for less than a vendor pays, or far under the going price." },
        { key = "startingBid", label = "Starting Bid", toggle = true, needs = On, why = Why,
          help = "Adds a Starting Bid box to Sell for items that are not commodities." },
        { label = "Default Quantity", button = ResetQuantities, buttonText = "Reset", note = QuantityNote,
          needs = On, why = Why, search = "stack amount how many post",
          help = "Puts how many Sell offers to post back to all you have, for every type of item." },
    },
})

page:Card({
    id = "auctions", name = "My Auctions", order = ORDER_AUCTIONS,
    help = "When one of your auctions counts as undercut.",
    search = "undercut cancel ahead cheaper tolerance",
    rows = {
        { key = "aheadAllowed", label = "Items Ahead Allowed", slider = AHEAD_RANGE, needs = On, why = Why,
          help = "An auction is undercut only when more than this many items are listed for less." },
    },
})

page:Card({
    id = "bags", name = "Bags & Tooltips", order = ORDER_BAGS,
    help = "What your items are worth, away from the auction house too.",
    rows = {
        { key = "bagWorth", label = "Bag Worth", toggle = true, needs = On, why = Why,
          help = "A card on your bags with what they would fetch at your last scan, and their five most "
              .. "valuable items, numbered on their slots." },
        { key = "bagWorthBank", label = "Include Bank", toggle = true, needs = BagWorthOn, why = BagWorthWhy,
          help = "Bag Worth also counts your bank, as it was when you last had it open." },
        { key = "tooltip", label = "Tooltip Lines", toggle = true, needs = On, why = Why,
          help = "Item tooltips show what your stack fetches, how its price moved over the past week, and "
              .. "what disenchanting it gives." },
        { key = "tooltipStyle", label = "Tooltip Style", choice = STYLES, needs = TooltipOn, why = TooltipWhy,
          help = "Compact keeps only the auction, vendor and disenchant prices, one line each." },
        { key = "tooltipStack", label = "Stack Prices", choice = STACKS, needs = TooltipOn, why = TooltipWhy,
          help = "On a stack in your bags, prices read for each item, the whole stack, or both." },
        { key = "tooltipShift", label = "Shift Swaps Stack Prices", toggle = true, needs = TooltipOn,
          why = TooltipWhy, search = "modifier hold each whole stack",
          help = "While Shift is held, a stack's tooltip swaps each item's price and the whole stack's." },
        { key = "tooltipOther", label = "Blackwater Price", toggle = true, needs = TooltipOn, why = TooltipWhy,
          search = "neutral other house faction booty bay",
          help = "Item tooltips also show the price at the other auction house you can reach." },
        { key = "tooltipAverage", label = "Average Price", toggle = true, needs = TooltipOn, why = TooltipWhy,
          search = "mean week 7 day history",
          help = "Item tooltips show the item's average lowest price over the past week." },
        { key = "tooltipMail", label = "Mailbox Total", toggle = true, needs = TooltipOn, why = TooltipWhy,
          search = "mailbox inbox letter total value",
          help = "Hovering a mail in your inbox adds what its attachments would fetch at auction." },
        { key = "tooltipBest", label = "Best Way to Sell", toggle = true, needs = TooltipOn, why = TooltipWhy,
          help = "Says whether the auction house, a vendor or disenchanting pays you the most." },
        { key = "tooltipBestMargin", label = "Auction Margin", slider = MARGIN_RANGE, unit = "s",
          scale = Market.C.SILVER, needs = BestOn, why = BestWhy,
          help = "A vendor stays best unless the auction house pays more than this over it, per item." },
    },
})

page:Card({
    id = "prices", name = "Disenchant Deals", order = ORDER_PRICES,
    help = "Disenchant Deals, the same settings as on Professions.",
    search = "disenchant deals enchanting",
    rows = PriceRows,
})

page:Card({
    id = "watch", name = "Watch List", order = ORDER_WATCH,
    help = "Items you watch on the Buy tab beside the auction house, and when you hear about them.",
    search = "watch list price alert cheap below under",
    rows = {
        { key = "watchAlerts", label = "Watch Alerts", toggle = true, needs = On, why = Why,
          help = "A chat line after each scan for every watched item at or under your price." },
    },
})

page:Card({
    id = "keys", name = "Key Binding", order = ORDER_KEYS,
    help = "The Market's keys.",
    rows = {
        { label = "Open The Market", binding = "NAOWHFOREVER_MARKET",
          help = "Press this key to open The Market, and again to close it." },
        { label = "Cancel Next Undercut Auction", binding = "NAOWHFOREVER_MARKET_CANCEL",
          help = "On My Auctions, each press cancels your next undercut auction." },
    },
})
