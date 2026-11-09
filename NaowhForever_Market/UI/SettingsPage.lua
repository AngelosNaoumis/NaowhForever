-- SettingsPage.lua: The Market's settings page, declared as cards.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Settings = ns.Shared.Settings

local ORDER_SELLING, ORDER_BAGS = 10, 20
local TEXT_OFF = ns.L("Turn on The Market")
local DURATIONS = { Market.C.DURATION_LABELS, Market.C.DURATIONS }
local UNDERCUTS = { { match = "Match the Cheapest", step = "Smallest Step", silver = "One Silver" },
    { "match", "step", "silver" } }

local function On()
    return Market.On()
end

local function Why()
    return ns.GamepadWhy() or TEXT_OFF
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
    },
})
