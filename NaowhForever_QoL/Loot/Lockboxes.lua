-- Lockboxes.lua: Lockpicking Skill, the Lockpicking a lockbox needs on its tooltip, coloured by yours.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local St = ns.Shared.Style
local SKILLS = ns.LockboxSkills

local LOCKPICKING = 633
local PAGE = "QoL/Loot & Items"
local ORDER = 15
local KEYS = { enabled = true, lockboxSkill = true }
local NO_SKILL, TOO_LOW, ENOUGH = St.TIME_LOW_RGB, St.TIME_OUT_RGB, St.HAVE_RGB
local TEXT_LOCKPICKING = ns.L("Lockpicking")

local events, name, skill

local function On()
    return S.Get("enabled") and S.Get("lockboxSkill")
end

local function SkillName(info)
    local own = info and info.name
    if own and own ~= "" then return own end
    local game = C_TradeSkillUI.GetTradeSkillDisplayName(LOCKPICKING)
    if game and game ~= "" then return game end
    return TEXT_LOCKPICKING
end

local function ReadSkill()
    local info = C_SkillInfo.GetSkillLineInfoByID(LOCKPICKING)
    skill = info and info.rank + info.modifier
    name = SkillName(info)
end

local function OnItemTooltip(tooltip, data)
    if not On() then return end
    local id = data and data.id
    if not id or (issecretvalue and issecretvalue(id)) then return end
    local need = SKILLS[id]
    if not need then return end
    local c = not skill and NO_SKILL or skill < need and TOO_LOW or ENOUGH
    tooltip:AddLine(ITEM_MIN_SKILL:format(name, need), c.r, c.g, c.b)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", ReadSkill)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    end
    events:RegisterEvent("SKILL_LINES_CHANGED")
    ReadSkill()
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "lockboxes", name = "Lockboxes", order = ORDER, into = "lootTrade",
    rows = {
        { key = "lockboxSkill", label = "Lockpicking Skill", toggle = true,
          help = "Lockbox tooltips show the Lockpicking skill needed to open them." },
    },
})
