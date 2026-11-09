-- FieldSettings.lua: Discovery's Field Journal settings page (Discovery/Field Journal), declared as cards.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local S = Discovery.Settings
local Field = Discovery.Field
local Settings = ns.Shared.Settings

local ORDER_JOURNAL = 10
local TEXT_HEADLINE = ns.L("%d of %d fish, %d of %d herbs, %d of %d dishes")
local TEXT_KEPT = ns.L("Kept for this character.")

local function Headline()
    local fish, fishTotal = Field.Progress("fish")
    local herbs, herbsTotal = Field.Progress("herbs")
    local dishes, dishesTotal = Field.Progress("dishes")
    return TEXT_HEADLINE:format(fish, fishTotal, herbs, herbsTotal, dishes, dishesTotal)
end

local function Detail()
    return TEXT_KEPT
end

local function OpenJournal()
    ns.OpenDiscoveryWindow("journal")
end

local page = Settings.Page("Discovery/Field Journal", S)

page:Window({
    text = "Open Field Journal",
    open = OpenJournal,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "journal", name = "Field Journal", order = ORDER_JOURNAL, switch = "fieldJournal",
    help = "Writes in each fish you catch, herb you pick and dish you cook, with how many.",
    search = "fishing fish herbalism herb herbs cooking cook dish dishes apothecary cookbook catch",
})
