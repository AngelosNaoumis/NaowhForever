-- The options window's categories (Core/Options/Categories.lua) against every module page's settings:
-- each card and window button a module declares is drawn on exactly one category page, each module's
-- own card once, and a module that is not loaded is drawn as its card. The settings come from the
-- search index the release builds, which loads every addon file against stubs.
-- Run with Lua 5.1 from the repository root.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local index = {}
local built = assert(loadstring(dofile("Tools/build/search_index.lua"), "SearchIndex.lua"))
setfenv(built, { _G = { NaowhForever = index } })
built()

local pages, declared = {}, {}
for pageKey, list in pairs(index.SEARCH_INDEX) do
    local items = {}
    for _, e in ipairs(list) do
        local uid = pageKey .. ":" .. e[1]
        if not declared[uid] then
            declared[uid] = pageKey
            items[#items + 1] = { uid = uid }
        end
    end
    pages[pageKey] = { key = pageKey, items = items }
end

local loaded, class = {}, "WARRIOR"
local composed = {}
local ns = { L = function(text) return text end, UI = {},
    Shared = { Settings = { pages = pages, Compose = function(key, items) composed[key] = items end } } }
local env = setmetatable({
    NaowhForever = ns,
    UnitClass = function() return "", class end,
    C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] ~= false end,
        GetAddOnEnableState = function() return 2 end },
}, { __index = _G })
env._G = env
for _, path in ipairs({ "Core/Options/Modules.lua", "Core/Options/Categories.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end
local O = ns.Options

local function Compose(page)
    composed[page.key] = nil
    O.Compose(page)
    return composed[page.key]
end

local function Holds(items, uid)
    for _, item in ipairs(items or {}) do
        if item.uid == uid then return true end
    end
    return false
end

-- Every category page, composed with every module loaded.
local drawn, moduleCards, total = {}, {}, 0
for _, cat in ipairs(O.CATEGORIES) do
    Check(#cat.pages >= 2 and #cat.pages <= 6, cat.name .. ": two to six pages")
    Check(cat.tabs[1].overview and #cat.tabs == #cat.pages + 1, cat.name .. ": an Overview first, then its pages")
    for _, page in ipairs(cat.pages) do
        Check(O.PAGES[page.key] == page and page.category == cat, page.key .. ": a page of the window")
        local items = Compose(page)
        Check(items ~= nil or page.tab ~= nil, page.key .. ": cards, or the module page it shows")
        for _, item in ipairs(items or {}) do
            if item.uid and item.uid:find("^@") then
                moduleCards[item.uid] = (moduleCards[item.uid] or 0) + 1
            elseif item.uid then
                drawn[item.uid] = drawn[item.uid] or {}
                table.insert(drawn[item.uid], page.key)
            end
        end
    end
end

for uid in pairs(declared) do
    total = total + 1
    local where = drawn[uid] or {}
    Check(#where == 1, uid .. " is drawn on exactly one category page, not " .. #where
        .. ": place it in Core/Options/Categories.lua")
end
Check(total > 150, "every module's cards are checked, " .. total .. " found")

for _, mod in ipairs(O.MODULES) do
    local count = moduleCards["@" .. mod.name] or 0
    if mod.name == "QoL" or #mod.tabs == 0 then
        Check(count == 0, mod.name .. ": no card of its own while loaded; its cards carry their own switches")
    else
        Check(count == 1, mod.name .. ": its own card, on one page")
    end
    for _, tab in ipairs(mod.tabs) do
        local key = O.NavPage(tab.key)
        Check(key and O.PAGES[key].category, tab.key .. ": an old link lands on a category page")
        if tab.build then
            Check(O.PAGES[key].tab == tab.key, tab.key .. ": a page drawn by its own builder is shown as it is")
        end
    end
    if #mod.tabs > 0 then Check(O.NavPage(mod.name) ~= nil, mod.name .. ": its name opens its page") end
end

local windows = {}
for _, mod in ipairs(O.Windows()) do windows[mod] = true end
for _, mod in ipairs(O.MODULES) do
    if mod.open then Check(windows[mod], mod.name .. ": Home opens its window") end
end

-- A module that is not loaded is drawn as its own card wherever its settings would be.
loaded.NaowhForever_Combat = false
local meters = Compose(O.PAGES["Combat > Meters & Alerts"])
Check(Holds(meters, "@Threat Meter") and not Holds(meters, "Threat Meter/Settings:meter")
    and Holds(meters, "QoL/Combat:combatAlert"), "Threat Meter off: its card alone, the page's other cards kept")
loaded.NaowhForever_Combat, loaded.NaowhForever_QoL = nil, false
local topBar = Compose(O.PAGES["Interface > Top Bar"])
Check(#topBar == 1 and topBar[1].uid == "@QoL", "QoL off: its card stands in for the Top Bar")
loaded.NaowhForever_QoL = nil

-- The Food & Drink Bar declares itself on the Loot page while the Consumable Bar is off, and is drawn beside it.
Check(O.NavPage("QoL/Loot & Items:foodBar") == O.NavPage("Consumable Bar/Settings:foodBar"),
    "the Food & Drink Bar is on the Consumable Bars page wherever it declares itself")

-- Your Class: this class's cards first, the others under a heading of their own.
local yours = O.PAGES["Combat > Your Class"]
class = "PALADIN"
local paladin = Compose(yours)
Check(paladin[1].uid == "@Blessings" and paladin[2].uid == "Blessings/Settings:Open Blessings",
    "a paladin's Blessings come first")
class = "MAGE"
local mage = Compose(yours)
Check(mage[1].heading and Holds(mage, "@Blessings"), "a mage sees every class's cards under Other Classes")
Check(#O.ClassItems() == 0, "and nothing for their class on Home")
class = "DRUID"
local druid = O.ClassItems()
Check(Holds(druid, "@Druid Mana") and Holds(druid, "QoL/Combat:stealthReminder") and not Holds(druid, "@Blessings"),
    "a druid's Home has Druid Mana and the Stealth Reminder")
local overview = Compose(O.PAGES["Combat > Overview"])
Check(Holds(overview, "@Druid Mana") and not Holds(overview, "@Blessings"), "the Overview lists only this class's")

-- The Market off: its card once on the Overview, and Auction Prices (QoL's own) still on its page.
loaded.NaowhForever_Market = false
local function Count(items, uid)
    local n = 0
    for _, item in ipairs(items or {}) do
        if item.uid == uid then n = n + 1 end
    end
    return n
end
local ahOverview = Compose(O.PAGES["Auction House > Overview"])
Check(Count(ahOverview, "@The Market") == 1, "The Market off: its card shows once on the Overview")
Check(Holds(ahOverview, "QoL/Loot & Items:auctionPrices"), "and Auction Prices stays on the Overview")
local tooltips = Compose(O.PAGES["Auction House > Prices & Tooltips"])
Check(Holds(tooltips, "QoL/Loot & Items:auctionPrices") and Holds(tooltips, "@The Market"),
    "The Market off: Prices & Tooltips keeps Auction Prices, with The Market's card for its own settings")
loaded.NaowhForever_Market = nil

print("test-categories: " .. checks .. " checks passed")
