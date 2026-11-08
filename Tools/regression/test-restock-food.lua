-- Run with Lua 5.1 from the repository root: the Restock Reminder counts food and drink filed under
-- Consumable: Food & Drink, and Forever's own cooking filed under Consumable: Other when its spell is
-- Food or Drink. Other consumables and raw fish (Trade Goods) are not counted. Items that restore health and
-- mana in one, such as the Enriched Manna Biscuit, count as food and as drink, and Forever's teas as drink.
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/Restock.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

-- Classes, subclasses, required levels and spell names from Forever's Item, ItemSparse and
-- SpellName tables (build 1.60.1.70862). OTHER_ITEM is synthetic.
local JERKY, PROWLER_STEAK, LEMONADE, WATER, RAW_SNAPPER, OTHER_ITEM = 117, 238637, 23161, 159, 6289, 900001
local BISCUIT, ROYAL_TEA = 13724, 249866
local ITEMS = {
    [JERKY] = { 0, 5, 1, "Food" },
    [PROWLER_STEAK] = { 0, 8, 55, "Food" },
    [LEMONADE] = { 0, 8, 45, "Drink" },
    [WATER] = { 0, 5, 1, "Drink" },
    [RAW_SNAPPER] = { 7, 8, 5, "Food" },
    [OTHER_ITEM] = { 0, 8, 1, "Something Else" },
    [BISCUIT] = { 0, 5, 45, "Enriched Manna Biscuit" },
    [ROYAL_TEA] = { 0, 5, 5, "Nutritious Drink" },
}
local SPELLS = { [433] = "Food", [430] = "Drink", [1249920] = "Nutritious Drink" }

local function Scan(bag, settings, uncached)
    local requests = {}
    local env = setmetatable({
        PLAIN_BAG = 0, MAX_LEVEL = 60, NUM_BAG_SLOTS = 0,
        Enum = { ItemQuality = { Poor = 0 } },
        S = { Get = function(key) return (settings or {})[key] end },
        RequestItem = function(id) requests[#requests + 1] = id end,
        ns = { IsFoodAndDrink = function(id) return id == BISCUIT end },
        C_Spell = { GetSpellName = function(id) return SPELLS[id] end },
        C_Item = {
            GetItemInfoInstant = function(id)
                return id, nil, nil, nil, nil, ITEMS[id][1], ITEMS[id][2]
            end,
            GetItemInfo = function(id)
                if uncached and uncached[id] then return end
                return nil, nil, nil, nil, ITEMS[id][3]
            end,
            GetItemSpell = function(id)
                if uncached and uncached[id] then return end
                return ITEMS[id][4]
            end,
        },
        C_Container = {
            GetContainerNumFreeSlots = function() return 10, 0 end,
            GetContainerNumSlots = function() return #bag end,
            GetContainerItemInfo = function(_, slot)
                return { itemID = bag[slot][1], stackCount = bag[slot][2], quality = 1 }
            end,
        },
    }, { __index = _G })
    local code = Slice("local FOOD_CLASS", "\nlocal PLAIN_BAG") .. "\n"
        .. Slice("local function FoodLevel(", "\nlocal function ReagentLines(")
        .. "\nreturn ScanBags"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local food, _, _, drink = chunk()()
    return food, drink, requests
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("Food & Drink items count as food or drink, as before", function()
    local food, drink = Scan({ { JERKY, 12 }, { WATER, 7 } })
    assert(food == 12 and drink == 7)
end)
Case("Forever's cooking filed under Other counts by its Food or Drink spell", function()
    local food, drink = Scan({ { PROWLER_STEAK, 15 }, { LEMONADE, 4 }, { JERKY, 2 } })
    assert(food == 17 and drink == 4)
end)
Case("other Other consumables and raw fish are not food", function()
    local food, drink = Scan({ { OTHER_ITEM, 20 }, { RAW_SNAPPER, 20 } })
    assert(food == 0 and drink == 0)
end)
Case("the required-level range applies to Other food too", function()
    local food = Scan({ { PROWLER_STEAK, 15 }, { JERKY, 3 } }, { restockFoodMaxLevel = 50 })
    assert(food == 3)
end)
Case("uncached Other food is requested and counted once it loads", function()
    local bag = { { PROWLER_STEAK, 15 } }
    local food, _, requests = Scan(bag, nil, { [PROWLER_STEAK] = true })
    assert(food == 0 and #requests == 1 and requests[1] == PROWLER_STEAK)
    assert(Scan(bag) == 15)
end)
Case("the Enriched Manna Biscuit counts as food and as drink", function()
    local food, drink = Scan({ { BISCUIT, 20 }, { JERKY, 3 }, { WATER, 5 } })
    assert(food == 23 and drink == 25)
end)
Case("Forever's teas count as drink, not food", function()
    local food, drink = Scan({ { ROYAL_TEA, 10 }, { JERKY, 3 } })
    assert(food == 3 and drink == 10)
end)
print(count .. " total restock food regressions passed")
