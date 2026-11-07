-- SkillThresholds.lua: the selected recipe's difficulty boundaries and current-skill marker.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local SkillUps = P.SkillUps
local Parts = ns.Shared.Parts
local Style = P.Style

local HALF = 0.5
local PERCENT = 100
local TEXT_CHANCE = "%d%%"

local Thresholds = {}
P.SkillThresholds = Thresholds

function Thresholds.Read(info)
    if not S.Get("enabled") or not S.Get("skillThresholds") or W.linked then return nil end
    local learn, yellow, grey = SkillUps.Range(info.recipeID, info.maxTrivialLevel)
    if not learn or learn >= grey then return nil end
    return learn, math.max(learn, yellow), math.max(learn, math.floor((yellow + grey) * HALF)), grey, yellow
end

function Thresholds.Render(parent, info)
    local first, yellow, green, grey, rawYellow = Thresholds.Read(info)
    local line = parent.skillThresholds
    if not first then
        if line then line:Hide() end
        return nil
    end
    if not line then
        line = Parts.ThresholdLine(parent)
        line:SetPoint("TOPLEFT", parent.icon, "BOTTOMLEFT", 0, -Style.SKILL_BAR_GAP)
        line:SetWidth(Style.PANE_INNER_W)
        parent.skillThresholds = line
    end
    local skill = SkillUps.Skill()
    local chance = skill and skill >= first and SkillUps.Chance(skill, rawYellow, grey)
    local text = chance and TEXT_CHANCE:format(math.floor(chance * PERCENT + HALF)) or nil
    line:Fill(first, yellow, green, grey, skill, Style.DIFFICULTY_RGB, text)
    line:Show()
    return line
end
