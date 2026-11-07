-- Run with Lua 5.1 from the repository root: a Food Maximum Required Level of 0, which the Installer's
-- Naowh profile shipped and which counts no food or drink, goes back to the default once per profile.
-- Any other value is kept, and a 0 set after the fix stays.
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/Restock.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

local function Migrate(db)
    local env = setmetatable({ S = { DB = function() return db end } }, { __index = _G })
    local chunk = assert(loadstring(Slice("local function MigrateFoodLevel()", "\nlocal function Apply()")
        .. "\nreturn MigrateFoodLevel"))
    setfenv(chunk, env)
    chunk()()
    return db
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("a saved 0 goes back to the default", function()
    local db = Migrate({ restockFoodMaxLevel = 0, restockBagsBelow = 12 })
    assert(db.restockFoodMaxLevel == nil and db.restockFoodLevelMigrated == true)
    assert(db.restockBagsBelow == 12)
end)
Case("any other saved value, or none, is kept", function()
    assert(Migrate({ restockFoodMaxLevel = 45 }).restockFoodMaxLevel == 45)
    local db = Migrate({})
    assert(db.restockFoodMaxLevel == nil and db.restockFoodLevelMigrated == true)
end)
Case("it runs once: a 0 chosen afterwards stays", function()
    local db = Migrate({})
    db.restockFoodMaxLevel = 0
    assert(Migrate(db).restockFoodMaxLevel == 0)
end)
Case("Apply runs it first, so a profile switch or import is covered too", function()
    assert(Slice("local function Apply()", "\nend\n"):find("^local function Apply%(%)\n    MigrateFoodLevel%(%)\n"))
end)
print(count .. " total restock food level regressions passed")
