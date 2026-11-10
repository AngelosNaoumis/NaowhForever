-- Run with Lua 5.1 from the repository root: Professions crafting ROI and its colour thresholds, a craft's two sales,
-- and the Skill-up Plan's best sale.
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local settings = { craftProfit = true, craftROI = false, roiGreyBelow = 10, roiGreenFrom = 30 }
local prices = { [10] = 100, [20] = 250 }
local listed = {}
local vendorPrices = {}
local sellPrices = {}
local itemInfo = {}
local enchanting = 0
local makeOwn, madeCost, plans = false, {}, {}
_G.wipe = function(t) for key in pairs(t) do t[key] = nil end return t end
_G.C_Item = { GetItemInfo = function(item)
    local i = itemInfo[item] or {}
    return nil, nil, i.quality, i.level, nil, nil, nil, nil, i.equip, nil, sellPrices[item], i.classID
end, GetDetailedItemLevelInfo = function(item) return (itemInfo[item] or {}).ilvl end }
_G.NaowhForever = {
    L = function(text) return text end,
    AuctionScanTime = function() return 1 end,
    AuctionPrice = function(item) return prices[item] end,
    AuctionListed = function(item) return listed[item] end,
    AuctionPriceList = function() return prices end,
    Professions = {
        DisenchantValues = {
            ItemTakes = function(item) return itemInfo[item] ~= nil end,
            RequiredSkill = function(level) return level end,
            Expected = function() return 400 end,
            AfterCut = function(gross) return math.floor(gross * 0.95) end,
        },
        Settings = { Get = function(key) return settings[key] end },
        Recipes = {
            Owned = function() return {} end,
            Reagents = function() return { { itemID = 10, need = 2 } } end,
            OutputItem = function() return 20, 1 end,
            ItemName = function() end,
        },
        Vendors = { Price = function(item) return vendorPrices[item] end },
        Shopping = {
            MakeOwn = function() return makeOwn end,
            Cheapest = function(item, plan)
                plans[plan] = true
                return madeCost[item] or prices[item], madeCost[item] ~= nil
            end,
        },
    },
}
dofile("NaowhForever_Professions/Prices.lua")

local Prices = _G.NaowhForever.Professions.Prices
Check("ROI is profit divided by materials cost", Prices.ROI(25, 100) == 25)
Check("negative ROI is retained", Prices.ROI(-10, 50) == -20)
Check("zero crafting cost has no ROI", Prices.ROI(10, 0) == nil)
Check("negative ROI is red", Prices.ROIBand(-1) == "negative")
Check("ROI below 10% is grey", Prices.ROIBand(9.9) == "muted")
Check("ROI from 10% is yellow", Prices.ROIBand(10) == "yellow")
Check("ROI below 30% remains yellow", Prices.ROIBand(29.9) == "yellow")
Check("ROI from 30% is green", Prices.ROIBand(30) == "green")
Check("ROI text is rounded", Prices.ROIText(12.6) == "(13% ROI)")

settings.roiGreyBelow, settings.roiGreenFrom = 20, 50
Check("custom grey threshold is used", Prices.ROIBand(19) == "muted")
Check("custom yellow threshold is used", Prices.ROIBand(20) == "yellow")
Check("custom green threshold is used", Prices.ROIBand(50) == "green")
settings.roiGreyBelow, settings.roiGreenFrom = 40, 20
Check("green cannot fall below grey", Prices.ROIBand(40) == "green")

local price, from = Prices.BuyPrice(10)
Check("with no vendor price a reagent costs its buyout", price == 100 and from == "ah")
vendorPrices[10] = 10
price, from = Prices.BuyPrice(10)
Check("a cheaper vendor price beats the buyout", price == 10 and from == Prices.FROM_VENDOR)
vendorPrices[10] = 150
price, from = Prices.BuyPrice(10)
Check("a cheaper buyout beats the vendor price", price == 100 and from == "ah")
price, from = Prices.BuyPrice(30)
Check("a reagent with neither price has none", price == nil and from == nil)
vendorPrices[30] = 5
price, from = Prices.BuyPrice(30)
Check("a vendor price alone is used without a buyout", price == 5 and from == Prices.FROM_VENDOR)

prices[20], sellPrices[20] = 190, 300
local v = Prices.CraftValue(1, 20, 1, { parts = {} })
Check("a craft's value has its auction sale after the cut and its vendor sale", v.cost == 200 and v.sale == 180
    and v.vendor == 300)
Check("so the plan, which counts the vendor sale, can gain where the auction sale loses",
    Prices.NetCost(1) == -100 and v.sale - v.cost == -20)
sellPrices[20] = nil
Check("a vendor sale not loaded yet is left out", Prices.CraftValue(1, 20, 1, { parts = {} }).vendor == nil)

-- Make Your Own Reagents: a reagent the plan makes costs what its parts do.
makeOwn, madeCost[10], sellPrices[20] = true, 30, 100
Prices.ClearCache()
v = Prices.CraftValue(1, 20, 1, { parts = {} })
Check("a reagent you make is priced from its parts", v.cost == 60 and v.parts[1].from == Prices.FROM_MADE)
Check("the list's profit and the skill-up cost use it too", Prices.RecipeProfit(1, 20, 1) == 120
    and Prices.NetCost(1) == -40)
Check("one plan is shared until the cache is cleared", next(plans) ~= nil and next(plans, next(plans)) == nil)
madeCost[10] = nil
Prices.ClearCache()
v = Prices.CraftValue(1, 20, 1, { parts = {} })
Check("one the plan buys keeps its own price and source", v.cost == 200 and v.parts[1].from == "ah")
makeOwn, madeCost[10] = false, 30
Prices.ClearCache()
Check("off, nothing is priced as made", Prices.CraftValue(1, 20, 1, { parts = {} }).cost == 200)

sellPrices[20] = nil
Prices.ClearCache()
Check("at its best sale, a craft not loaded yet has no cost either", Prices.NetCost(1, enchanting) == nil)
sellPrices[20] = 50
Prices.ClearCache()
Check("at its best sale, an auction price whose count is unknown is left out", Prices.NetCost(1, enchanting) == 150)
listed[20] = Prices.LISTED_ENOUGH - 1
Prices.ClearCache()
Check("and so is one with too few listed", Prices.NetCost(1, enchanting) == 150)
listed[20] = Prices.LISTED_ENOUGH
Prices.ClearCache()
Check("with enough listed, the auction sale after the cut counts", Prices.NetCost(1, enchanting) == 20)
Check("while the vendor-only cost stays as it was", Prices.NetCost(1) == 150)
itemInfo[20] = { quality = 2, level = 20, equip = "INVTYPE_CHEST", classID = 4 }
Prices.ClearCache()
Check("disenchanting counts only with the Enchanting it needs", Prices.NetCost(1, enchanting) == 20)
enchanting = 50
Prices.ClearCache()
Check("with it, a better disenchant wins", Prices.NetCost(1, enchanting) == 200 - 380)
Check("a lower Enchanting skill values it again without clearing the cache", Prices.NetCost(1, 10) == 20)
itemInfo[20].ilvl = 60
Prices.ClearCache()
Check("the item's own level, not its base level, sets the Enchanting it needs", Prices.NetCost(1, enchanting) == 20)
itemInfo[20].ilvl = nil
prices[20], listed[20], enchanting = nil, nil, 0
Prices.ClearCache()
Check("with neither, the vendor sale is the best", Prices.NetCost(1, enchanting) == 150)
sellPrices[20] = 500
Check("a cached cost is kept until the cache is cleared", Prices.NetCost(1, enchanting) == 150)
Prices.ClearCache()
Check("and the vendor wins when it pays most", Prices.NetCost(1, enchanting) == -300)

print(("test-profession-roi: %d checks passed"):format(checks))
