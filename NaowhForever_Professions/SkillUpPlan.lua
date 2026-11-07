-- SkillUpPlan.lua: the cheapest crafts from your skill to your cap, step by step.
local ns = _G.NaowhForever

local P = ns.Professions
local R = P.Recipes
local Prices = P.Prices
local SkillUps = P.SkillUps
local Entries = P.Entries
local Cooldowns = P.CooldownRecipes

local STICKY = 0.1
local READY, TRAINER = "ready", "trainer"

local candidates = {}
local last = {}
local cached

local Plan = {}
P.SkillUpPlan = Plan

local function Score(c, chance)
    return c.net and c.net / chance
end

local function Better(a, aScore, aChance, b, bScore, bChance)
    if aScore and bScore then
        if aScore ~= bScore then return aScore < bScore end
    elseif aScore or bScore then
        return aScore ~= nil
    elseif aChance ~= bChance then
        return aChance > bChance
    end
    return a.id < b.id
end

local function Keep(current, score, chance, best, bestScore, bestChance)
    if score and bestScore then return score - bestScore <= math.abs(bestScore) * STICKY end
    if not score and not bestScore then return chance >= bestChance * (1 - STICKY) end
    return Better(current, score, chance, best, bestScore, bestChance)
end

local function Pick(skill, excluded, current)
    local best, bestScore, bestChance
    for _, c in ipairs(candidates) do
        if not excluded[c] then
            local chance = SkillUps.Chance(skill, c.yellow, c.grey)
            if chance > 0 then
                local score = Score(c, chance)
                if not best or Better(c, score, chance, best, bestScore, bestChance) then
                    best, bestScore, bestChance = c, score, chance
                end
            end
        end
    end
    if current and current ~= best and not excluded[current] then
        local chance = SkillUps.Chance(skill, current.yellow, current.grey)
        if chance > 0 and Keep(current, Score(current, chance), chance, best, bestScore, bestChance) then
            return current, chance
        end
    end
    return best, bestChance
end

local function Run(from, to, modifier, excluded)
    local run = { steps = {}, reach = from, crafts = 0, total = 0, priced = true, trained = {} }
    local step
    for skill = from, to - 1 do
        local c, chance = Pick(skill + modifier, excluded, step and step.c)
        if not c then break end
        if not step or step.c ~= c then
            local _, band = SkillUps.Chance(skill + modifier, c.yellow, c.grey)
            step = { c = c, from = skill, expected = 0, band = band }
            run.steps[#run.steps + 1] = step
        end
        step.expected = step.expected + 1 / chance
        step.to = skill + 1
        run.reach = skill + 1
    end
    for _, s in ipairs(run.steps) do
        s.count = math.ceil(s.expected)
        s.info, s.r = s.c.info, s.c.r
        s.cost = s.c.net and s.c.net * s.count
        run.crafts = run.crafts + s.count
        if s.cost then run.total = run.total + s.cost else run.priced = false end
        if s.c.r and not run.trained[s.c] then
            run.trained[s.c] = true
            run.total = run.total + s.c.train
        end
    end
    if not run.priced then run.total = nil end
    return run
end

local function Beats(a, b)
    if a.reach ~= b.reach then return a.reach > b.reach end
    if a.total and b.total then return a.total < b.total end
    return a.crafts < b.crafts
end

local function Optimise(from, to, modifier)
    local excluded = {}
    local best = Run(from, to, modifier, excluded)
    local changed = true
    while changed do
        changed = false
        for c in pairs(best.trained) do
            excluded[c] = true
            local without = Run(from, to, modifier, excluded)
            if Beats(without, best) then
                best, changed = without, true
                break
            end
            excluded[c] = nil
        end
    end
    return best
end

local function Add(id, yellow, grey, info, r, train)
    candidates[#candidates + 1] = { id = id, yellow = yellow, grey = grey, net = Prices.NetCost(id),
        info = info, r = r, train = train }
end

local function Collect(skill)
    wipe(candidates)
    for _, cat in ipairs(Entries.Learned()) do
        for _, info in ipairs(cat.recipes) do
            local id = info.recipeID
            local _, yellow, grey = SkillUps.Range(id, info.maxTrivialLevel)
            if yellow and grey > skill and not Cooldowns[id] then Add(id, yellow, grey, info) end
        end
    end
    local finder = ns.RecipeFinder
    for _, r in ipairs(Entries.Unlearned()) do
        if r.source == TRAINER and r.yellow and r.yellow <= r.grey and r.grey > skill and not Cooldowns[r.spell]
            and finder.Status(r) == READY then
            Add(r.spell, r.yellow, r.grey, nil, r, finder.Cost(r) or 0)
        end
    end
end

local function Changed(prof)
    local scan = ns.AuctionScanTime and ns.AuctionScanTime() or 0
    local recipes, unlearned = Entries.Count(), #Entries.Unlearned()
    if cached and last.id == prof.id and last.skill == prof.skill and last.max == prof.max
        and last.modifier == prof.modifier and last.recipes == recipes and last.unlearned == unlearned
        and last.scan == scan then
        return false
    end
    last.id, last.skill, last.max, last.modifier = prof.id, prof.skill, prof.max, prof.modifier
    last.recipes, last.unlearned, last.scan = recipes, unlearned, scan
    return true
end

function Plan.Get()
    local prof = R.Profession()
    if not prof then return nil end
    if not Changed(prof) then return cached end
    local plan
    if prof.skill >= prof.max then
        plan = { from = prof.skill, to = prof.max, steps = {}, reach = prof.skill, crafts = 0, total = 0,
            priced = true, trained = {}, atCap = true }
    else
        Collect(prof.skill + prof.modifier)
        plan = Optimise(prof.skill, prof.max, prof.modifier)
        plan.from, plan.to = prof.skill, prof.max
        wipe(candidates)
    end
    cached = plan
    return plan
end

function Plan.Invalidate()
    cached = nil
end

function Plan.NeedsTraining(plan)
    return next(plan.trained) ~= nil
end
