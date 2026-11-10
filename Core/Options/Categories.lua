-- Categories.lua: the options window's categories, their pages and the cards each page shows, taken from the modules' own pages (ns.Options).
local ns = _G.NaowhForever
local O = ns.Options

local MODULES, PAGES = O.MODULES, O.PAGES
local Loaded = O.Loaded

local HOME, HOME_ICON = "Home", "infinity"
local OVERVIEW = "Overview"
local PAGE_KEY = "%s > %s"
local MODULE_CARD = "^@(.+)$"
local CARD_UID = "^(.-):[^:]+$"
local COMMAND = "/nf%s"
local NONE = {}
local TEXT_HOME_SUB = "Open a window, or pick what you are doing in the game on the left."
local TEXT_OTHER_CLASSES = "Other Classes"
local ERROR_NO_MODULE = "Categories: no module named "
local ERROR_NO_PAGE = "Categories: no module page for "
local ERROR_TWICE = "Categories: placed twice: "

local CATEGORIES = {
    { name = "Interface", navIcon = "window",
      subtitle = "The Top Bar, tooltips, names over heads and less clutter.",
      pages = {
          { name = "Top Bar", cards = { "QoL/Interface:topBar" } },
          { name = "Tooltips", cards = { "QoL/Interface:tooltips", "QoL/Interface:scout" } },
          { name = "Names & Badges", cards = { "QoL/Interface:unitNames", "QoL/Interface:supporterBadges" } },
          { name = "Declutter", cards = { "QoL/Interface:uiClutter" } },
          { name = "Advanced", cards = { "QoL/Interface:hdr", "QoL/Interface:consoleVariables" } },
      } },
    { name = "Character & Gear", band = "CHARACTER", navIcon = "shield",
      subtitle = "Your BiS list, your gear sets and the character panel.",
      pages = {
          { name = "BiS List", cards = { "@BiS List", "BiS List/Settings" } },
          { name = "Character & Inspect", cards = { "BiS List/Character" } },
          { name = "Gear Sets", cards = { "@Gear & Trinkets", "Gear & Trinkets/Settings" } },
          { name = "Upkeep", cards = { "QoL/Combat:durability", "QoL/Loot & Items:gearReminders" } },
      } },
    { name = "Leveling & Training", band = "CHARACTER", navIcon = "spark",
      subtitle = "Experience, trainers and talents on the way to 60.",
      pages = {
          { name = "Experience", cards = { "QoL/XP:xpBar", "QoL/XP:xpTicker", "QoL/XP:groupXP" } },
          { name = "Spells & Talents", cards = { "@Training Planner", "Training Planner/Settings", "QoL/XP:trainer",
              "QoL/XP:talentPoints" } },
      } },
    { name = "Action Bars & Macros", band = "CHARACTER", navIcon = "grid",
      subtitle = "Your action bars saved by name, and macros that keep themselves current.",
      pages = {
          { name = "Bar Sets", tab = "Action Bars/Bar Sets" },
          { name = "Bar Options", cards = { "@Action Bars", "Action Bars/Settings" } },
          { name = "My Macros", tab = "Macros/My Macros" },
          { name = "Smart Macros", tab = "Macros/Smart Macros" },
          { name = "Macro Library", tab = "Macros/Library" },
          { name = "Macro Options", cards = { "@Macros", "Macros/Settings" } },
      } },
    { name = "Buffs & Consumables", band = "CHARACTER", navIcon = "aura",
      subtitle = "Reminders for what is missing, and bars for what you carry.",
      pages = {
          { name = "Buff Reminders", cards = { "@AuraBuffs", "AuraBuffs/Settings:buffs", "AuraBuffs/Settings:lowHealth",
              "QoL/Interface:buffThanks" } },
          { name = "Consumable Bars", cards = { "@Consumable Bar", "Consumable Bar/Settings" } },
          { name = "Campfire", cards = { "AuraBuffs/Settings:campfire", "AuraBuffs/Settings:campNearby" } },
      } },
    { name = "Quests & Exploration", band = "WORLD", navIcon = "compass",
      subtitle = "Quest help, every quest and rare by zone, and Forever's collections.",
      pages = {
          { name = "Quest Helpers", cards = { "QoL/Questing & Group:quests", "QoL/Questing & Group:Open Saved Rewards",
              "QoL/Questing & Group:questProgress", "QoL/Questing & Group:gossip" } },
          { name = "Quest List", cards = { "@Discovery", "Discovery/Quest List" } },
          { name = "Rares", cards = { "Discovery/Rares" } },
          { name = "Collections", cards = { "Discovery/Library Books", "Discovery/Sleeping Bag",
              "Discovery/Field Journal" } },
      } },
    { name = "Map & Travel", band = "WORLD", navIcon = "map",
      subtitle = "The world map, its pins, and the fastest way anywhere.",
      pages = {
          { name = "World Map", cards = { "QoL/Map & Pins:mapOptions", "QoL/Map & Pins:zoneInfo" } },
          { name = "Map Pins", cards = { "QoL/Map & Pins:townMap" } },
          { name = "Routes & Waypoints", cards = { "@Journeys", "Journeys/Settings", "QoL/Interface:waypoints" } },
          { name = "Flights & Boats", cards = { "QoL/Travel:flightTimer", "QoL/Travel:flightPoint",
              "QoL/Travel:transportTimers" } },
          { name = "Object Highlights", cards = { "QoL/Glimmer" } },
          { name = "Flight Games", cards = { "QoL/Travel:flightGames", "QoL/Travel:quiz", "QoL/Travel:dailyWord",
              "QoL/Travel:aimTrainer" } },
      } },
    { name = "Professions", band = "WORLD", navIcon = "hammer",
      subtitle = "Crafting, gathering, fishing and enchanting.",
      pages = {
          { name = "Crafting", cards = { "@Professions", "Professions/Settings" } },
          { name = "Materials & Profit", cards = { "Professions/Settings:buying" } },
          { name = "Gathering", cards = { "Professions/Settings:gather", "Professions/Settings:nodeIcons",
              "Professions/Settings:nodeToast" } },
          { name = "Fishing", cards = { "QoL/Loot & Items:fishingKey", "QoL/Loot & Items:fishingSounds" } },
          { name = "Enchanting", cards = { "Professions/Settings:disenchant", "Professions/Settings:tradeEnchants",
              "Professions/Settings:disenchantDeals" } },
      } },
    { name = "Auction House", band = "WORLD", navIcon = "coins",
      subtitle = "The Market, and what your items are worth.",
      pages = {
          { name = "The Market", cards = { "@The Market", "The Market/Settings" } },
          { name = "Prices & Tooltips", cards = { "The Market/Settings:bags", "The Market/Settings:prices" } },
      } },
    { name = "Bags, Loot & Mail", band = "WORLD", navIcon = "checklist",
      subtitle = "Looting, junk, vendors and mail.",
      pages = {
          { name = "Loot", cards = { "QoL/Loot & Items:lootFeed", "QoL/Loot & Items:lootTrade" } },
          { name = "Bags & Junk", cards = { "QoL/Loot & Items:bagSpace", "QoL/Loot & Items:scrapMarker",
              "QoL/Loot & Items:Open Junk List", "QoL/Loot & Items:bankMarker" } },
          { name = "Restock", cards = { "QoL/Loot & Items:restock" } },
      } },
    { name = "Combat", band = "COMBAT & GROUPS", navIcon = "swords",
      subtitle = "Meters, timers and warnings for the fight.",
      pages = {
          { name = "Meters & Alerts", cards = { "@Threat Meter", "Threat Meter/Settings", "QoL/Damage Meter",
              "QoL/Combat:combatAlert", "QoL/Combat:combatTimer" } },
          { name = "Swings & Casts", cards = { "@Swing Timer", "Swing Timer/Settings", "QoL/Combat:gcdTracker",
              "QoL/Combat:focusCastBar", "QoL/Combat:spellQueue" } },
          { name = "Tank & Healer", cards = { "QoL/Combat:coTank", "QoL/Combat:healerMana", "@Raid Debuffs",
              "Raid Debuffs/Settings" } },
          { name = "Cursor & Crosshair", cards = { "QoL/Cursor & Crosshair" } },
          { name = "Your Class", cards = {
              { classes = { PALADIN = true }, "@Blessings", "Blessings/Settings" },
              { classes = { DRUID = true }, "@Druid Mana", "Druid Mana/Settings" },
              { classes = { ROGUE = true, DRUID = true }, "QoL/Combat:stealthReminder" },
              { classes = { HUNTER = true, WARLOCK = true }, "QoL/Combat:petTracker" },
              { classes = { HUNTER = true, DRUID = true, PALADIN = true, WARLOCK = true }, "QoL/Interface:tracking" },
          } },
      } },
    { name = "Dungeons & Groups", band = "COMBAT & GROUPS", navIcon = "group",
      subtitle = "Dungeon loot and quests, finding a group, and running one.",
      pages = {
          { name = "Dungeon Journal", cards = { "@Dungeon Journal", "Dungeon Journal/Journal", "Dungeon Journal/Map" } },
          { name = "Dungeon Quests", cards = { "Dungeon Journal/Quest Tracker" } },
          { name = "Instance Tracker", cards = { "@Instance Tracker", "Instance Tracker/Settings" } },
          { name = "Group Finder", cards = { "@Group Finder", "Group Finder/Settings", "QoL/Questing & Group:finderRoles",
              "QoL/Interface:chatZones" } },
          { name = "Group Tools", cards = { "@Group Inspect", "Group Inspect/Settings", "QoL/Questing & Group:groupButtons",
              "QoL/Questing & Group:freeForAll", "QoL/Questing & Group:layerSwap", "QoL/Questing & Group:layerTracker",
              "QoL/Questing & Group:playerHistory" } },
      } },
    { name = "PvP", band = "COMBAT & GROUPS", navIcon = "trophy",
      subtitle = "What your target is doing, battlegrounds and enemies nearby.",
      pages = {
          { name = "Target Auras", cards = { "@PvP", "PvP/Auras" } },
          { name = "Battlegrounds", cards = { "PvP/Battlegrounds", "PvP/Flag" } },
          { name = "Nearby Enemies", cards = { "PvP/Nearby Enemies" } },
      } },
}

local placed, whole, firstOf, moduleHome = {}, {}, {}, {}
local windows, classPages = {}, {}
local moduleCards = {}
local otherClasses = { heading = TEXT_OTHER_CLASSES }

local function ModuleNamed(name)
    for _, mod in ipairs(MODULES) do
        if mod.name == name then return mod end
    end
end

local function ModuleCard(mod)
    local card = moduleCards[mod]
    if card then return card end
    card = { id = mod.name, uid = "@" .. mod.name, name = mod.label or mod.name, help = mod.subtitle, rows = {},
        summary = mod.command and COMMAND:format(mod.command) or nil,
        switchGet = function() return O.ModuleOn(mod) end,
        switchSet = function(v) O.SetModuleOn(mod, v) end }
    moduleCards[mod] = card
    return card
end

local function Entries(cards)
    local out = {}
    for _, card in ipairs(cards) do
        if type(card) == "table" then
            for _, source in ipairs(card) do out[#out + 1] = { source = source, classes = card.classes } end
        else
            out[#out + 1] = { source = card }
        end
    end
    return out
end

local function AddModule(page, mod)
    for _, known in ipairs(page.modules) do
        if known == mod then return end
    end
    page.modules[#page.modules + 1] = mod
end

local function Place(page, source)
    local key = page.key
    local name = source:match(MODULE_CARD)
    if name then
        local mod = assert(ModuleNamed(name), ERROR_NO_MODULE .. name)
        assert(not moduleHome[mod], ERROR_TWICE .. source)
        moduleHome[mod] = key
        if mod.open then windows[#windows + 1] = mod end
        return AddModule(page, mod)
    end
    local pageKey = source:match(CARD_UID)
    local map = pageKey and placed or whole
    pageKey = pageKey or source
    assert(PAGES[pageKey] and PAGES[pageKey].module, ERROR_NO_PAGE .. source)
    assert(not map[source], ERROR_TWICE .. source)
    map[source] = key
    firstOf[pageKey] = firstOf[pageKey] or key
    AddModule(page, PAGES[pageKey].module)
end

local function AddCategory(cat)
    cat.overview = { name = OVERVIEW, category = cat, overview = true, reuse = true }
    cat.tabs = { cat.overview }
    for _, page in ipairs(cat.pages) do
        page.category, page.reuse = cat, true
        page.heading = { heading = page.name }
        if page.tab then
            local tab = assert(PAGES[page.tab], ERROR_NO_PAGE .. page.tab)
            page.build, page.arg, page.terms = tab.build, tab.arg, tab.terms
        else
            page.sources = Entries(page.cards)
        end
        cat.tabs[#cat.tabs + 1] = page
    end
    for _, page in ipairs(cat.tabs) do
        page.key, page.modules = PAGE_KEY:format(cat.name, page.name), {}
        PAGES[page.key] = page
        if page.tab then Place(page, page.tab) end
        for _, entry in ipairs(page.sources or NONE) do
            Place(page, entry.source)
            if entry.classes and classPages[#classPages] ~= page then classPages[#classPages + 1] = page end
        end
    end
end

local function Add(items, seen, item)
    if seen[item] then return end
    seen[item] = true
    items[#items + 1] = item
end

local function AddSource(items, seen, source)
    local name = source:match(MODULE_CARD)
    if name then return Add(items, seen, ModuleCard(ModuleNamed(name))) end
    local pageKey = source:match(CARD_UID) or source
    local mod = PAGES[pageKey].module
    if not Loaded(mod) then return Add(items, seen, ModuleCard(mod)) end
    local page = ns.Shared.Settings.pages[pageKey]
    for _, item in ipairs(page and page.items or NONE) do
        if item.uid == source or (pageKey == source and not placed[item.uid]) then Add(items, seen, item) end
    end
end

local function Mine(entry, class)
    return not entry.classes or entry.classes[class] == true
end

local function PageItems(page, mineOnly)
    local items, seen, others = {}, {}, false
    local class = select(2, UnitClass("player"))
    for _, entry in ipairs(page.sources) do
        if Mine(entry, class) then AddSource(items, seen, entry.source) else others = true end
    end
    if mineOnly or not others then return items end
    Add(items, seen, otherClasses)
    for _, entry in ipairs(page.sources) do
        if not Mine(entry, class) then AddSource(items, seen, entry.source) end
    end
    return items
end

local function OverviewItems(cat)
    local items = {}
    for _, page in ipairs(cat.pages) do
        local list = page.sources and PageItems(page, true) or NONE
        if #list > 0 then items[#items + 1] = page.heading end
        for _, item in ipairs(list) do items[#items + 1] = item end
    end
    return items
end

local function PageFor(key)
    if placed[key] then return placed[key] end
    local pageKey = key:match(CARD_UID) or key
    return whole[pageKey] or firstOf[pageKey]
end

local function ModuleHome(mod)
    if moduleHome[mod] then return moduleHome[mod] end
    for _, tab in ipairs(mod.tabs) do
        local key = PageFor(tab.key)
        if key then return key end
    end
end

for _, cat in ipairs(CATEGORIES) do AddCategory(cat) end
PAGES[HOME] = { key = HOME, name = HOME, title = HOME, subtitle = TEXT_HOME_SUB, navIcon = HOME_ICON,
    build = "BuildHomePage", reuse = true }

O.CATEGORIES, O.HOME = CATEGORIES, HOME

function O.Compose(page)
    local Settings = ns.Shared.Settings
    if page.overview then return Settings.Compose(page.key, OverviewItems(page.category)) end
    if page.sources then return Settings.Compose(page.key, PageItems(page)) end
    local mod = page.tab and PAGES[page.tab].module
    if mod and not Loaded(mod) then return Settings.Compose(page.key, { ModuleCard(mod) }) end
end

function O.NavPage(name)
    local page = PAGES[name]
    if page and not page.module then return name end
    local key = PageFor(name)
    if key then return key end
    for _, cat in ipairs(CATEGORIES) do
        if cat.name == name then return cat.overview.key end
    end
    for _, mod in ipairs(MODULES) do
        if mod.name == name then return ModuleHome(mod) end
        for _, tab in ipairs(mod.tabs) do
            if tab.name == name then return PageFor(tab.key) end
        end
    end
end

function O.ModuleCardUid(mod)
    return ModuleCard(mod).uid
end

function O.IsModuleCard(uid)
    return type(uid) == "string" and uid:match(MODULE_CARD) ~= nil
end

function O.Windows()
    local list = {}
    for _, mod in ipairs(windows) do
        if Loaded(mod) then list[#list + 1] = mod end
    end
    return list
end

function O.ClassItems()
    local items, seen = {}, {}
    local class = select(2, UnitClass("player"))
    for _, page in ipairs(classPages) do
        for _, entry in ipairs(page.sources) do
            if entry.classes and entry.classes[class] then AddSource(items, seen, entry.source) end
        end
    end
    return items
end
