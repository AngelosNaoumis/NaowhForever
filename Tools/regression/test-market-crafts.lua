-- Run with Lua 5.1 from the repository root: The Market's Crafts: your characters' recipes, priced, and what your bags make.
local World = dofile("Tools/regression/market_world.lua")

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
local queued = {}
local craftQueue = true
t.ns.Professions = {
    Shopping = {
        Makes = function() return makes["Player-1"] end,
        MakesOf = function(guid) return makes[guid] end,
        BuyPrice = function(item) return buy[item] end,
        VendorPrice = function(item) return item == THREAD and 10 or nil end,
    },
    CraftQueue = { AddWithShopping = function(info, count) queued[#queued + 1] = { info = info, count = count } end },
    Settings = { Get = function(key) return key == "craftQueue" and craftQueue end },
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

Cr.NoteMe()
Check("logging in notes this character for its alts", t.account.marketCharacters["Player-1"].name == "Me"
    and t.account.marketCharacters["Player-1"].house == "Realm-Horde")

print("market crafts: " .. checks .. " checks passed")
