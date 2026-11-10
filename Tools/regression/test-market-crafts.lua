-- Run with Lua 5.1 from the repository root: The Market's Crafts: your characters' recipes, priced, and what your bags make.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local LINEN, BOLT, THREAD, SHIRT, BANDAGE, WOOL, HAT = 2589, 2996, 2320, 2576, 1251, 2592, 4000

local t = World.Setup({ vendor = { [LINEN] = 3, [WOOL] = 5 }, counts = { [LINEN] = 7 } })
local Cr = t.M.Crafts
Check("without Professions there is nothing to read", Cr.Read() == false and #Cr.rows == 0)

local makes = {
    ["Player-1"] = {
        [BOLT] = { recipe = 2963, made = 1, need = { [LINEN] = 2 }, prof = 197 },
        [SHIRT] = { recipe = 2386, made = 1, need = { [BOLT] = 1, [THREAD] = 1 }, prof = 197 },
        [HAT] = { recipe = 5000, made = 1, need = { [LINEN] = 1 }, prof = 197 },
    },
    ["Player-2"] = {
        [BOLT] = { recipe = 2963, made = 1, need = { [LINEN] = 2 }, prof = 197 },
        [BANDAGE] = { recipe = 3275, made = 2, need = { [LINEN] = 1 }, prof = 129 },
    },
    ["Player-3"] = { [WOOL] = { recipe = 1, made = 1, need = { [LINEN] = 1 }, prof = 197 } },
}
local buy = { [LINEN] = 20, [THREAD] = 10 }
local queued, listed = {}, {}
local craftQueue, shoppingList, professionsOn, hasNeeds = true, true, true, true
local switches = { craftQueue = function() return craftQueue end, shoppingList = function() return shoppingList end }
t.ns.Professions = {
    On = function() return professionsOn end,
    Shopping = {
        Makes = function() return makes["Player-1"] end,
        MakesOf = function(guid) return makes[guid] end,
        BuyPrice = function(item) return buy[item] end,
        VendorPrice = function(item) return item == THREAD and 10 or nil end,
        HasNeeds = function(recipeID, need) return hasNeeds and recipeID ~= nil and need ~= nil end,
        Add = function(info, count)
            listed[#listed + 1] = { info = info, count = count }
            return true
        end,
    },
    CraftQueue = { AddWithShopping = function(info, count) queued[#queued + 1] = { info = info, count = count } end },
    Settings = { Get = function(key) return switches[key] and switches[key]() end },
}
t.account.marketCharacters = {
    ["Player-2"] = { name = "Alt", house = "Realm-Horde" },
    ["Player-3"] = { name = "Far", house = "Other-Horde" },
}
t.scan = { [BOLT] = 100, [LINEN] = 20, [SHIRT] = 300, [BANDAGE] = 15, [WOOL] = 999 }

Check("Professions' recipes are read", Cr.Read() == true)
local byOutput = {}
for _, row in ipairs(Cr.rows) do byOutput[row.output] = row end
local bolt = byOutput[BOLT]
Check("a craft sells for its price after the cut", bolt.sale == 95)
Check("it gains over selling its materials as they are", bolt.gain == 95 - 2 * 19)
Check("and profits over buying them", bolt.cost == 40 and bolt.profit == 55)
Check("your bags make as many as their materials allow", bolt.can == 3)
Check("a recipe two characters know is yours", bolt.who == nil and bolt.guid == "Player-1")

local shirt = byOutput[SHIRT]
Check("a vendor material counts at its price and never limits", shirt.gain == 285 - 95 - 10 and shirt.can == 0)
Check("an output with no price is left out", byOutput[HAT] == nil)

local bandage = byOutput[BANDAGE]
Check("an alt's recipe on this realm and faction is theirs", bandage.who == "Alt" and bandage.sale == 2 * 14)
Check("and makes from your bags too", bandage.can == 7 and bandage.gain == 28 - 19)
Check("a character on another realm is left out", byOutput[WOOL] == nil)

buy[LINEN] = nil
Cr.Read()
for _, row in ipairs(Cr.rows) do byOutput[row.output] = row end
Check("a material with no price to buy leaves no profit", byOutput[BOLT].profit == nil and byOutput[BOLT].gain == 57)
buy[LINEN] = 20
Cr.Read()

local view = Cr.View(true, {})
Check("From My Bags lists only what the bags make, most gained first", #view == 2 and view[1].output == BOLT
    and view[2].output == BANDAGE)
view = Cr.View(false, view)
Check("All Recipes lists every one, most profit first", #view == 3 and view[1].output == BOLT)
local total, n = Cr.Total()
Check("crafting the bags first shares their materials, best gain first", total == 57 * 3 + 9 * 1 and n == 2)

Check("a tooltip finds what makes an item", Cr.Made(BOLT).who == nil)
Check("and the best craft its material goes into", Cr.Into(LINEN).output == BOLT)
t.scan[BOLT] = 30
Check("tooltips keep what they read until the prices change", Cr.Into(LINEN).output == BOLT)
Cr.Changed()
Check("and read again after a scan", Cr.Into(LINEN).output == BANDAGE)
t.scan[BOLT] = 100
Check("the page keeps its read until something changes", Cr.Fresh() and Cr.Into(LINEN).output == BANDAGE)

for _, row in ipairs(Cr.rows) do byOutput[row.output] = row end
bolt, bandage = byOutput[BOLT], byOutput[BANDAGE]
Check("an alt's craft cannot be queued", not Cr.CanQueue(bandage) and not Cr.Queue(bandage, 7))
Check("yours goes to Professions' Craft Queue", Cr.Queue(bolt, 3) and queued[1].info.recipeID == 2963
    and queued[1].count == 3 and queued[1].info.need[LINEN] == 2)
craftQueue = false
Check("not while its Craft Queue is off", not Cr.Queue(bolt, 3) and #queued == 1)
Check("your own craft is queued, not listed", not Cr.CanList(bolt) and not Cr.List(bolt) and #listed == 0)
Check("an alt's craft puts one craft's materials on your Shopping List", Cr.CanList(bandage) and Cr.List(bandage)
    and listed[1].count == 1 and listed[1].info.recipeID == 3275 and listed[1].info.need[LINEN] == 1
    and listed[1].info.name == "Item " .. BANDAGE)
shoppingList = false
Check("not while the Shopping List is off", not Cr.CanList(bandage) and not Cr.List(bandage) and #listed == 1)
shoppingList, professionsOn = true, false
Check("nor while Professions is off", not Cr.CanList(bandage) and not Cr.List(bandage) and #listed == 1)
professionsOn, hasNeeds = true, false
Check("nor when the craft has nothing left to buy", not Cr.CanList(bandage) and not Cr.List(bandage) and #listed == 1)
hasNeeds = true

Cr.NoteMe()
Check("logging in notes this character for its alts", t.account.marketCharacters["Player-1"].name == "Me"
    and t.account.marketCharacters["Player-1"].house == "Realm-Horde")

local Outlet = Cr.Outlet
Check("a vendor wins a tie with the auction house, as on Sell", Outlet(95, nil, 95) == "vendor")
Check("the auction house wins a tie with disenchanting", Outlet(95, 95, nil) == "sell")
Check("a vendor wins a tie with disenchanting", Outlet(nil, 50, 50) == "vendor")
local outlet, best = Outlet(12, 13, 11)
Check("otherwise the outlet that pays most wins", outlet == "disenchant" and best == 13)
outlet, best = Outlet(5, nil, 0)
Check("a vendor price of nothing is no outlet", outlet == "sell" and best == 5 and Outlet(nil, nil, 0) == nil)

-- Level 20 Uncommon armor: 75% 2-3 Strange Dust, 20% 1-2 Greater Magic Essence, 5% a Small Glimmering Shard.
local DUST, ESSENCE, SHARD = 10940, 10939, 10978
local GLOVES, CLOAK, GREEN_SHIRT, STEW = 7001, 7002, 7003, 7004
local ARMOR, UNCOMMON, GREEN_LEVEL = 4, 2, 20
local DISENCHANTED = 481
local s = World.Setup({ scanAt = 1, counts = { [LINEN] = 12 }, vendor = { [GLOVES] = 30, [STEW] = 60 }, info = {
    [GLOVES] = { quality = UNCOMMON, level = GREEN_LEVEL, class = ARMOR, equip = "INVTYPE_HAND" },
    [CLOAK] = { quality = UNCOMMON, level = GREEN_LEVEL, class = ARMOR, equip = "INVTYPE_CLOAK" },
    [GREEN_SHIRT] = { quality = UNCOMMON, level = GREEN_LEVEL, class = ARMOR, equip = "INVTYPE_BODY" },
} })
local shuffles = {
    [BOLT] = { recipe = 2963, made = 1, need = { [LINEN] = 2 }, prof = 197 },
    [GLOVES] = { recipe = 7101, made = 1, need = { [LINEN] = 4 }, prof = 197 },
    [CLOAK] = { recipe = 7102, made = 1, need = { [LINEN] = 3 }, prof = 197 },
    [GREEN_SHIRT] = { recipe = 7103, made = 1, need = { [LINEN] = 5 }, prof = 197 },
    [STEW] = { recipe = 7104, made = 2, need = { [LINEN] = 1 }, prof = 185 },
}
s.ns.Professions = { Shopping = { Makes = function() return shuffles end, MakesOf = function() end,
    BuyPrice = function(item) return buy[item] end, VendorPrice = function() end } }
local professionsEnv = setmetatable({ NaowhForever = s.ns }, { __index = _G })
professionsEnv._G = professionsEnv
Load({ "NaowhForever_Professions/Data/DisenchantValues.lua" }, professionsEnv)
s.scan = { [LINEN] = 20, [BOLT] = 100, [GLOVES] = 50, [GREEN_SHIRT] = 200, [STEW] = 40,
    [DUST] = 100, [ESSENCE] = 1000, [SHARD] = 400 }
local Sh = s.M.Crafts

local function ReadShuffles()
    Sh.Changed()
    Sh.Read()
    local by = {}
    for _, row in ipairs(Sh.rows) do by[row.output] = row end
    return by
end

local by = ReadShuffles()
Check("a craft that sells best is sold", by[BOLT].outlet == "sell" and by[BOLT].sale == 95)
Check("a green worth more disenchanted is disenchanted, at its value after the cut", by[GLOVES].outlet == "disenchant"
    and by[GLOVES].sale == DISENCHANTED)
Check("and its gain and profit come from disenchanting", by[GLOVES].gain == DISENCHANTED - 4 * 19
    and by[GLOVES].profit == DISENCHANTED - 4 * 20)
Check("a green with no auction price is listed by its disenchant value", by[CLOAK].outlet == "disenchant"
    and by[CLOAK].profit == DISENCHANTED - 3 * 20)
Check("a shirt never disenchants", by[GREEN_SHIRT].outlet == "sell" and by[GREEN_SHIRT].sale == 190)
Check("a craft a vendor pays more for is vendored, times what it makes", by[STEW].outlet == "vendor"
    and by[STEW].sale == 2 * 60 and by[STEW].profit == 120 - 20)

view = Sh.View(false, {})
Check("All Recipes sorts by the best outlet's profit", view[1].output == CLOAK and view[2].output == GLOVES
    and view[3].output == STEW and view[5].output == BOLT)
view = Sh.View(false, view, "disenchant")
Check("Disenchant lists only the crafts best disenchanted, most profit first", #view == 2 and view[1].output == CLOAK
    and view[2].output == GLOVES)
total, n = Sh.Total()
Check("crafting the bags shares them out by the best outlet's gain", total == (DISENCHANTED - 3 * 19) * 4 and n == 1)
Check("a material's tooltip names the craft that gains most by its best outlet", Sh.Into(LINEN).output == CLOAK
    and Sh.Made(GLOVES).outlet == "disenchant")

local values = s.ns.Professions.DisenchantValues
s.ns.Professions.DisenchantValues = nil
by = ReadShuffles()
Check("without Professions' disenchant values a green is only sold", by[GLOVES].outlet == "sell"
    and by[GLOVES].sale == 47 and by[CLOAK] == nil)
s.ns.Professions.DisenchantValues = values
s.scanAt = nil
by = ReadShuffles()
Check("and without a full price list", by[GLOVES].outlet == "sell" and by[CLOAK] == nil)

print("market crafts: " .. checks .. " checks passed")
