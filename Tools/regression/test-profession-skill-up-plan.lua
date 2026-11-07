-- Run with Lua 5.1 from the repository root: the Skill-up Plan's choice of crafts from your skill to your cap.
local checks = 0
local function Check(label, condition) assert(condition, label); checks = checks + 1 end

local prof = { id = 197, skill = 30, max = 50, modifier = 0 }
local net, learned, unlearned, status, train = {}, {}, {}, {}, {}
local scan = 1
local ns = {
    AuctionScanTime = function() return scan end,
    Professions = {
        Recipes = { Profession = function() return prof end },
        Prices = { NetCost = function(id) return net[id] end },
        CooldownRecipes = { [99] = true },
        Entries = {
            Learned = function() return { { recipes = learned } } end,
            Unlearned = function() return unlearned end,
            Count = function() return #learned end,
        },
    },
    RecipeData = { [197] = { recipes = {} } },
    RecipeFinder = {
        Status = function(r) return status[r.spell] or "ready" end,
        Cost = function(r) return train[r.spell] end,
    },
}
_G.NaowhForever = ns
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
dofile("NaowhForever_Professions/SkillUps.lua")
dofile("NaowhForever_Professions/SkillUpPlan.lua")
local Plan = ns.Professions.SkillUpPlan

local function Recipe(id, skill, yellow, grey, cost)
    local r = { spell = id, skill = skill, yellow = yellow, grey = grey, source = "trainer" }
    local data = ns.RecipeData[197].recipes
    data[#data + 1] = r
    net[id] = cost
    return r
end

local function Learn(id) learned[#learned + 1] = { recipeID = id } end

local function Reset()
    for _, t in ipairs({ net, learned, unlearned, status, train }) do wipe(t) end
    prof.skill, prof.max = 30, 50
end

local function Fresh()
    Plan.Invalidate()
    return Plan.Get()
end

local function Ids(plan)
    local out = {}
    for i, step in ipairs(plan.steps) do out[i] = step.info and step.info.recipeID or step.r.spell end
    return table.concat(out, ",")
end

Recipe(1, 1, 40, 60, 100)
Learn(1)
local plan = Fresh()
Check("one recipe carries the plan to the cap", Ids(plan) == "1" and plan.reach == 50)
local expected = 10
for skill = 40, 49 do expected = expected + 20 / (60 - skill) end
Check("its crafts are the expected ones, rounded up", plan.steps[1].count == math.ceil(expected))
Check("from the skill to the cap", plan.steps[1].from == 30 and plan.steps[1].to == 50)
Check("the total is its crafts at their net cost", plan.total == plan.steps[1].count * 100 and plan.priced)
Check("the plan is kept until something changes", Plan.Get() == plan)
prof.skill = 31
Check("a skill-up plans again", Plan.Get() ~= plan)
prof.skill = 30

Reset()
Recipe(11, 1, 40, 50, 50)
Recipe(12, 1, 45, 80, 100)
Learn(11)
Learn(12)
plan = Fresh()
Check("the cheaper recipe goes first, the dearer once it costs less a point", Ids(plan) == "11,12")
Check("the switch comes once the first costs a tenth more a point", plan.steps[1].to == 46)

net[12] = 51
Recipe(14, 1, 40, 50, 50)
Learn(14)
plan = Fresh()
Check("near-equal recipes do not take turns", #plan.steps <= 2)

Reset()
Recipe(21, 1, 40, 60, 100)
Learn(21)
unlearned[1] = Recipe(23, 20, 60, 80, 10)
train[23] = 100000
plan = Fresh()
Check("a trainable recipe that costs more to learn than it saves is left out", Ids(plan) == "21")
Check("so the plan needs no trainer", not Plan.NeedsTraining(plan))
train[23] = 50
plan = Fresh()
Check("one that saves more than it costs is planned", Ids(plan) == "23")
Check("and the plan says to train it", Plan.NeedsTraining(plan))
Check("its training is in the total", plan.total == plan.steps[1].count * 10 + 50)
status[23] = "later"
plan = Fresh()
Check("a recipe not learnable yet is not planned", Ids(plan) == "21")
status[23] = nil
wipe(unlearned)

Reset()
Recipe(31, 1, 35, 60, nil)
Recipe(32, 1, 32, 70, nil)
Learn(31)
Learn(32)
plan = Fresh()
Check("with no prices the most likely recipe goes first", plan.steps[1].info.recipeID == 31 and plan.total == nil)
Check("and the plan is marked unpriced", not plan.priced)
net[32] = 140
plan = Fresh()
Check("a priced recipe goes before an unpriced one", plan.steps[1].info.recipeID == 32)

prof.max = 75
plan = Fresh()
Check("past every recipe's grey the plan stops short", plan.reach == 70 and plan.to == 75)
prof.max = 50

Recipe(99, 1, 45, 90, 1)
Learn(99)
plan = Fresh()
Check("a recipe on a cooldown is never planned", not Ids(plan):find("99"))

prof.skill = 50
plan = Fresh()
Check("at the cap there is nothing to plan", plan.atCap and #plan.steps == 0)

print(("test-profession-skill-up-plan: %d checks passed"):format(checks))
