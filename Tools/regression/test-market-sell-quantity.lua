-- Run with Lua 5.1 from the repository root: how many of an item The Market's Sell offers to post. It is all you
-- carry until a chip over the quantity box says otherwise: 1, a number or All, picked for this post and kept as the
-- default for that type of item (Trade Goods, Consumables, Recipes, everything else). Typing a quantity is for one
-- post only, and no quantity is ever more than you carry.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM

local ORE, BAR, POTION, RECIPE, GEAR = 2770, 2840, 118, 2553, 9999
local TRADE, CONSUMABLE, RECIPES = 7, 0, 9
local ACCENT = { r = 0, g = 0.5, b = 0.9 }

local t = Page.Setup({
    bags = { [0] = { Stack(ORE, 200), Stack(BAR, 12), Stack(POTION, 30), Stack(RECIPE, 3), Stack(GEAR, 1) } },
    status = { [ORE] = COMMODITY, [BAR] = COMMODITY, [POTION] = COMMODITY, [RECIPE] = ITEM, [GEAR] = ITEM },
    scan = { [ORE] = 500, [BAR] = 400, [POTION] = 300, [RECIPE] = 200 },
    vendor = { [ORE] = 5, [BAR] = 5, [POTION] = 5, [RECIPE] = 5, [GEAR] = 20 },
    info = { [ORE] = { class = TRADE }, [BAR] = { class = TRADE }, [POTION] = { class = CONSUMABLE },
        [RECIPE] = { class = RECIPES } },
})
t.ns.THEME.accent = ACCENT
local M = t.M
local Sell, S = M.Sell, M.Settings
t.page.Show()

local function Pick(key)
    Sell.Pick(key)
    t.page.Draw()
    return Sell.Focus()
end

local function Click(text, button)
    local chip = t.Chip(text)
    chip.scripts.OnMouseUp(chip, button or "LeftButton")
end

local function Lit(text)
    return t.Chip(text).color == ACCENT
end

local function Listed(itemID)
    t.results.commodity[itemID] = { { unitPrice = 500, quantity = 5, numOwnerItems = 0 } }
    t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", itemID)
end

local ore = Pick(ORE)
Check("until you say otherwise Sell offers all you carry, as before", Sell.Quantity(ore) == 200
    and S.Get("sellQuantityTrade") == 0)
Check("three chips sit over the quantity box: 1, a number and All", t.Chip("1") ~= nil and t.Chip("20") ~= nil
    and t.Chip("All") ~= nil)
Check("the one in use is lit", Lit("All") and not Lit("1") and not Lit("20"))

Click("20")
Check("the number chip sets the quantity now", Sell.Quantity(ore) == 20 and Lit("20") and not Lit("All"))
Check("and is kept as the default for that type of item", S.Get("sellQuantityTrade") == 20
    and S.Get("sellQuantityConsumable") == 0 and S.Get("sellQuantityRecipe") == 0 and S.Get("sellQuantityOther") == 0)
local bar = Pick(BAR)
Check("another item of the type takes it, never more than you carry", Sell.Quantity(bar) == 12 and Lit("20"))
local potion = Pick(POTION)
Check("another type keeps its own", Sell.Quantity(potion) == 30 and Lit("All"))
Click("1")
Check("1 is a chip of its own", Sell.Quantity(potion) == 1 and S.Get("sellQuantityConsumable") == 1 and Lit("1"))
local recipe = Pick("item:" .. RECIPE)
Click("1")
local gear = Pick("item:" .. GEAR)
Check("recipes and everything else are types too", Sell.Quantity(recipe) == 1 and S.Get("sellQuantityRecipe") == 1
    and Sell.Quantity(gear) == 1 and S.Get("sellQuantityOther") == 0 and Lit("All"))

ore = Pick(ORE)
Sell.SetQuantity(ORE, 7)
t.page.Draw()
Check("a quantity typed is for this post only: the default stays, and no chip is lit", Sell.Quantity(ore) == 7
    and S.Get("sellQuantityTrade") == 20 and not Lit("20") and not Lit("1") and not Lit("All"))
Sell.SetQuantity(ORE, 5000)
Check("typed, it is still never more than you carry", Sell.Quantity(ore) == 200)
Click("20")
Check("a chip puts the default back", Sell.Quantity(ore) == 20 and Lit("20"))
Sell.SetQuantity(ORE, 7)
Listed(ORE)
t.post.click()
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
Check("the typed quantity posts", #t.posts == 1 and t.posts[1].quantity == 7)
ore = Pick(ORE)
Check("and the next post of the item is back on the default", Sell.Quantity(ore) == 20)

local chip = t.Chip("20")
chip.scripts.OnEnter(chip)
Check("a chip's tooltip names the type, in the game's words", t.tips[1] == "Default for Class 7"
    and t.tips[2] == "Right-click to change the number.")
chip = t.Chip("All")
chip.scripts.OnEnter(chip)
Check("only the number chip can be changed", #t.tips == 1)
Pick("item:" .. GEAR)
chip.scripts.OnEnter(chip)
Check("an item of no listed type reads other items", t.tips[1] == "Default for other items")

Pick(ORE)
Click("20", "RightButton")
local prompt = t.prompts[1]
Check("a right-click on the number chip asks for a number, starting at the one it has", prompt ~= nil
    and prompt.title == "How many to post" and prompt.text == "20" and S.Get("sellQuantityTrade") == 20)
prompt.accept("40")
Check("the number typed is the chip's, and the default for the type", t.Chip("40") ~= nil and t.Chip("20") == nil
    and S.Get("sellNumberTrade") == 40 and S.Get("sellQuantityTrade") == 40 and Sell.Quantity(Sell.Focus()) == 40
    and Lit("40"))
Pick(POTION)
Check("another type's number is its own", t.Chip("20") ~= nil and S.Get("sellNumberConsumable") == 20)
Pick(ORE)
for _, bad in ipairs({ "", "0", "1", "x", "2.5" }) do
    t.prompts[1].accept(bad)
end
Check("nothing, zero, one and words are not a number for the chip", S.Get("sellNumberTrade") == 40)
Click("All")
Check("All is all you carry again", Sell.Quantity(Sell.Focus()) == 200 and S.Get("sellQuantityTrade") == 0
    and S.Get("sellNumberTrade") == 40)

local worth = Sell.Focus().worth
Click("1")
t.Fire("BAG_UPDATE_DELAYED")
t.RunTimers()
Check("Up Next still counts what all of the item would fetch", Sell.Focus().worth == worth)

print("market sell quantity: " .. checks .. " checks passed")
