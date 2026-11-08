-- SettingsPage.lua: The Market's settings page, declared as cards.
local ns = _G.NaowhForever

local Market = ns.Market
local S = Market.Settings
local Settings = ns.Shared.Settings

local ORDER_SELLING = 10
local TEXT_OFF = ns.L("Turn on The Market")
local DURATIONS = { Market.C.DURATION_LABELS, Market.C.DURATIONS }

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
    },
})
