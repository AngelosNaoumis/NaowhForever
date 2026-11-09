-- Run with Lua 5.1 from the repository root: Professions' Reagents rules: what each reagent goes
-- into across every profession, who knows each recipe, what crafting gains over selling the
-- materials, how many the bags make, the verdict per reagent, the search and the waypoint.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local PEACEBLOOM, SILVERLEAF, VIAL, LINEN, STRANGE_DUST, HEARTHSTONE = 2447, 765, 3371, 2589, 10940, 6948
local HEALING, MANA, ELIXIR, ARROWS = 118, 2455, 5997, 2512
local ALCHEMY, ENCHANTING = 171, 333
local ME, ALT, FAR = "Player-11-0001", "Player-11-0002", "Player-22-0003"

local learned = { [2330] = true }
local scan = { [PEACEBLOOM] = 20, [SILVERLEAF] = 10, [HEALING] = 100, [MANA] = 30, [ELIXIR] = 200, [ARROWS] = 1 }
local sell = { [PEACEBLOOM] = 1, [SILVERLEAF] = 2 }
local counts = { [PEACEBLOOM] = 7, [SILVERLEAF] = 3 }
local names = { [PEACEBLOOM] = "Peacebloom", [SILVERLEAF] = "Silverleaf", [VIAL] = "Empty Vial" }
local bag = { PEACEBLOOM, HEARTHSTONE, SILVERLEAF, PEACEBLOOM }
local skill, cap = 30, 75
local placed
local describedWith

local TRAINER = { 1, "Ford", "A", 1429, 40, 50 }
local NOWHERE = { 2, "Gone", "A", 0, 0, 0 }
local account = {
    profMakes = {
        [ME] = {},
        [ALT] = { [MANA] = { recipe = 2331, made = 1, need = { [SILVERLEAF] = 2, [VIAL] = 1 }, prof = ALCHEMY } },
        [FAR] = { [ELIXIR] = { recipe = 7183, made = 1, need = { [PEACEBLOOM] = 2 }, prof = ALCHEMY } },
    },
}

local ns = {
    Lower = string.lower,
    RecipeData = {
        [ALCHEMY] = { skillSpell = 2259, recipes = {
            { spell = 2330, item = HEALING, skill = 1, source = "trainer" },
            { spell = 2331, item = MANA, skill = 25, source = "trainer" },
            { spell = 7183, item = ELIXIR, skill = 50, source = "trainer" },
            { spell = 9999, item = ARROWS, skill = 1, source = "trainer" },
        } },
        [ENCHANTING] = { skillSpell = 7411, recipes = {
            { spell = 7418, skill = 1, source = "drop" },
        } },
    },
    RecipeFinder = {
        Learned = function(spell) return learned[spell] == true end,
        Skill = function(r) return r.skill end,
        Describe = function(r, st)
            describedWith = st
            if r.spell == 7418 then return { { text = "A world drop." } } end
            return { { text = "Trainer:", para = true }, { text = "Gone", npc = NOWHERE }, { text = "Ford", npc = TRAINER } }
        end,
    },
    AccountSettings = function() return account end,
    AuctionPrice = function(item) return scan[item] end,
    PlaceWaypoint = function(...) placed = { ... } return true end,
}
ns.Professions = {
    C = { NPC_NAME = 2, NPC_FACTION = 3, NPC_MAP = 4, NPC_X = 5, NPC_Y = 6 },
    Vendors = {
        IsVendorItem = function(item) return item == VIAL end,
        Price = function(item) return item == VIAL and 4 or nil end,
    },
    Prices = { AfterCut = function(each, made) return math.floor(each * made * 0.95) end },
    RecipeReagents = {
        [2330] = { PEACEBLOOM, 1, SILVERLEAF, 1, VIAL, 1 },
        [2331] = { SILVERLEAF, 2, VIAL, 1 },
        [7183] = { PEACEBLOOM, 2, VIAL, 1 },
        [9999] = { LINEN, 1, made = 200 },
        [7418] = { PEACEBLOOM, 1, STRANGE_DUST, 1 },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    NUM_BAG_SLOTS = 0,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitGUID = function() return ME end,
    GetProfessions = function() return 1, nil, nil, nil, nil, nil end,
    GetProfessionInfo = function() return "Alchemy", nil, skill, cap, nil, nil, ALCHEMY, 0 end,
    C_Item = {
        GetItemCount = function(item) return counts[item] or 0 end,
        GetItemInfo = function(item) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, sell[item] end,
        GetItemNameByID = function(item) return names[item] end,
        GetItemIconByID = function() return 1 end,
    },
    C_Spell = {
        GetSpellName = function(id) return ({ [2259] = "Alchemy", [7411] = "Enchanting", [7418] = "Enchant Bracer" })[id] end,
        GetSpellTexture = function() return 2 end,
    },
    C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
        GetContainerItemID = function(_, slot) return bag[slot] end,
    },
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/ReagentUses.lua" }, env)
local Uses = ns.Professions.ReagentUses

Uses.Begin()
local list = Uses.Of(PEACEBLOOM)
Check("a reagent lists every recipe it goes into, in every profession", #list == 3)
Check("yours first, then the ones you have not learned, best gain first, an enchant last",
    list[1].spell == 2330 and list[2].spell == 7183 and list[3].spell == 7418)

local healing, elixir, enchant = list[1], list[2], list[3]
Check("a recipe you know is yours", healing.rank == Uses.YOU)
Check("it sells for its price after the cut", healing.sale == 95)
Check("its materials count at what they sell for, a vendor one at its price", healing.raw == 19 + 9 + 4)
Check("crafting gains the difference", healing.gain == 95 - 32)
Check("the bags make as many as their scarcest material allows, vendor ones aside", healing.can == 3)
Check("an alt on another realm does not count", elixir.rank == Uses.NEW and elixir.alt == nil)
Check("a recipe with no item to sell has no gain", enchant.sale == nil and enchant.gain == nil)

local mana = Uses.Of(SILVERLEAF)[2]
Check("an alt on your realm who saved the recipe knows it", mana.rank == Uses.ALT and mana.alt == ALT)
Check("and its bags count is yours", mana.can == 1)

local arrows = Uses.Of(LINEN)[1]
Check("a craft that makes many sells for all of them", arrows.made == 200 and arrows.sale == 190)

local info = Uses.Read(PEACEBLOOM, {})
Check("a reagent reads its count and what one sells for", info.count == 7 and info.each == 19)
Check("the best craft is one you or an alt know, not the one you would have to learn",
    info.best == healing and info.bestEach == 63)
info = Uses.Read(SILVERLEAF, info)
Check("the best craft weighs its gain by how many of the reagent it takes", info.best == healing)

scan[HEALING] = 20
Uses.Begin()
info = Uses.Read(PEACEBLOOM, {})
Check("a fresh read prices again, and a craft that loses is no reason to craft", healing.gain < 0 and info.best == nil)
info = Uses.Read(SILVERLEAF, info)
Check("an alt's craft can be the best", info.best == mana and info.bestEach == 3)

local carried = Uses.Carried({})
Check("your bags list each reagent once, and nothing that is no reagent", #carried == 2
    and carried[1] == PEACEBLOOM and carried[2] == SILVERLEAF)

local missing = {}
local found = Uses.Search("leaf", {}, missing)
Check("a search finds any reagent by name, carried or not", #found == 1 and found[1] == SILVERLEAF)
found = Uses.Search("vial", found, missing)
Check("one you do not carry too", #found == 1 and found[1] == VIAL)
Check("names not loaded yet are handed back to ask for", #missing > 0)

Check("a recipe at your skill is ready", select(1, Uses.Status(healing)) == "ready")
Check("one above it waits", Uses.Status(elixir) == "later")
cap = 40
Uses.Begin()
Check("one past your cap needs the next rank", Uses.Status(elixir) == "rank")
Check("a profession you do not have says so", Uses.Status(enchant) == "none")

Uses.Where(elixir)
Check("where to learn it is read for its own profession", describedWith.data == ns.RecipeData[ALCHEMY]
    and describedWith.skill == 30 and describedWith.max == 40)
Uses.Where(enchant)
Check("a profession you do not have gets no rank step", describedWith.skill == 0
    and describedWith.max == math.huge)

Check("a waypoint goes to the first place on the map", Uses.Waypoint(elixir) and placed[1] == "Ford"
    and placed[2] == 1429 and placed[3] == 40 and placed[4] == 50)
placed = nil
Check("no place, no waypoint", Uses.Waypoint(enchant) == false and placed == nil)

print(("test-profession-reagent-uses: %d checks passed"):format(checks))
