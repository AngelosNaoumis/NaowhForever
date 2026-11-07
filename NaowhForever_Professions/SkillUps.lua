-- SkillUps.lua: each recipe's skill-up range, its chance at your skill, and what a skill-up costs.
local ns = _G.NaowhForever

local P = ns.Professions
local R = P.Recipes
local Prices = P.Prices

local HALF = 0.5
local OPTIMAL, MEDIUM, EASY, TRIVIAL = 0, 1, 2, 3

local index = {}

local SkillUps = {}
P.SkillUps = SkillUps

local function IndexLine(data)
    for _, r in ipairs(data.recipes) do index[r.spell] = r end
end

function SkillUps.Entry(spell)
    local r = index[spell]
    if r ~= nil then return r or nil end
    for _, data in pairs(ns.RecipeData) do
        for _, e in ipairs(data.recipes) do
            if e.spell == spell then
                IndexLine(data)
                return e
            end
        end
    end
    index[spell] = false
end

function SkillUps.Range(spell, liveGrey)
    local r = SkillUps.Entry(spell)
    if not (r and r.yellow) then return nil end
    local grey = r.grey
    if type(liveGrey) == "number" and liveGrey > 0 then grey = liveGrey end
    if r.yellow > grey then return nil end
    return r.skill, r.yellow, grey
end

function SkillUps.Chance(skill, yellow, grey)
    if skill >= grey then return 0, TRIVIAL end
    if skill < yellow then return 1, OPTIMAL end
    local band = skill < math.floor((yellow + grey) * HALF) and MEDIUM or EASY
    return (grey - skill) / (grey - yellow), band
end

function SkillUps.Skill()
    local profession = R.Profession()
    return profession and profession.skill + profession.modifier
end

function SkillUps.ForRecipe(info, skill)
    local difficulty = info.relativeDifficulty
    if difficulty == OPTIMAL then return 1, OPTIMAL end
    if difficulty == TRIVIAL then return 0, TRIVIAL end
    local _, yellow, grey = SkillUps.Range(info.recipeID, info.maxTrivialLevel)
    if not (yellow and skill) then return nil end
    local chance, band = SkillUps.Chance(skill, yellow, grey)
    return chance, difficulty or band
end

function SkillUps.ForUnlearned(r, skill)
    if not (r.yellow and skill) or r.yellow > r.grey then return nil end
    return SkillUps.Chance(skill, r.yellow, r.grey)
end

function SkillUps.CostPerPoint(recipeID, chance)
    if not chance or chance <= 0 then return nil end
    local net = Prices.NetCost(recipeID)
    return net and net / chance
end
