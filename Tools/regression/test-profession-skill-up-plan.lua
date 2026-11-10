-- Run with Lua 5.1 from the repository root: the Skill-up Plan's choice of crafts from your skill to your cap.
local checks = 0
local function Check(label, condition) assert(condition, label); checks = checks + 1 end

local prof = { id = 197, skill = 30, max = 50, modifier = 0 }
local net, bestNet, learned, unlearned, status, train, need = {}, {}, {}, {}, {}, {}, {}
local settings = {}
local scan = 1
local enchanting
local ns = {
    AuctionScanTime = function() return scan end,
    Professions = {
        Settings = { Get = function(key) return settings[key] end },
        Recipes = { Profession = function() return prof end },
        Prices = { NetCost = function(id, best)
            if best and bestNet[id] then return bestNet[id] end
            return net[id]
        end },
        CooldownRecipes = { [99] = true },
        DisenchantDeals = { Skill = function() return enchanting end },
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
        Skill = function(r) return need[r.spell] or r.skill end,
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
    for _, t in ipairs({ net, bestNet, learned, unlearned, status, train, need }) do wipe(t) end
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
Recipe(41, 1, 40, 60, 100)
Learn(41)
plan = Fresh()
local alone = ("%s %d %d"):format(Ids(plan), plan.total, plan.crafts)
unlearned[1] = Recipe(43, 40, 40, 80, 10)
status[43], train[43] = "later", 50
plan = Fresh()
Check("off, a recipe you can train later leaves the plan as it was",
    ("%s %d %d"):format(Ids(plan), plan.total, plan.crafts) == alone)
settings.skillUpPlanLater = true
local before = plan
plan = Plan.Get()
Check("turning it on plans again", plan ~= before)
Check("on, it is planned from the skill it is trained at, not before",
    Ids(plan) == "41,43" and plan.steps[1].to == 40 and plan.steps[2].from == 40 and plan.steps[2].trainAt == 40)
Check("its training is in the total", plan.total == plan.steps[1].count * 100 + plan.steps[2].count * 10 + 50)
Check("the steps before it are the ones to do now", Plan.Doable(plan) == 1 and not Plan.NeedsTraining(plan))
need[43] = 45
plan = Fresh()
Check("its skill is the trainer's, as the recipe list reads it", plan.steps[2].from == 45 and plan.steps[2].trainAt == 45)
need[43] = nil
prof.modifier = 5
plan = Fresh()
Check("a skill bonus does not train it sooner", Ids(plan) == "41,43" and plan.steps[2].from == 40)
prof.modifier = 0
train[43] = 100000
plan = Fresh()
Check("one that costs more to learn than it saves is left out", Ids(plan) == "41")
train[43] = 50
unlearned[2] = Recipe(44, 35, 35, 90, 1)
status[44], train[44] = "rank", 0
plan = Fresh()
Check("a recipe that needs the next rank stays out, however cheap", not Ids(plan):find("44"))
settings.skillUpPlanLater = nil
plan = Plan.Get()
Check("turning it off plans as before", Ids(plan) == "41")
wipe(unlearned)

Reset()
Recipe(51, 1, 40, 60, 100)
Recipe(52, 1, 40, 60, 90)
Learn(51)
Learn(52)
bestNet[51] = 20
plan = Fresh()
Check("off, crafts are costed at their vendor sale", Ids(plan) == "52")
settings.skillUpPlanBest = true
before = plan
plan = Plan.Get()
Check("turning best sale on plans again", plan ~= before)
Check("on, a craft that sells well costs less and goes first", Ids(plan) == "51" and plan.total == plan.steps[1].count * 20)
before = plan
enchanting = 25
plan = Plan.Get()
Check("on, a new Enchanting skill plans again, as it can change what disenchanting pays", plan ~= before)
before = plan
Check("and an unchanged one keeps the plan", Plan.Get() == before)
enchanting = nil
settings.skillUpPlanBest = nil
plan = Plan.Get()
Check("turning it off plans by the vendor sale again", Ids(plan) == "52")

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
