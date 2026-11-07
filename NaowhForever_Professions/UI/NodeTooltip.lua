-- NodeTooltip.lua: Minimap Node Tooltips: hovering a herb or vein on the minimap adds the skill it needs to its tooltip.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local Style = P.Style
local Scan = P.NodeScan
local C = P.C

local TIER_ORANGE, TIER_YELLOW, TIER_GREEN, TIER_GREY = 0, 1, 2, 3
local EVENTS = { "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD" }
local TEXT_REQUIRES = ns.L("Requires %s %d")
local TEXT_NAMED = "%s: %s"
local TEXT_PROFESSION = { herb = ns.L("Herbalism"), ore = ns.L("Mining") }

local events, hooked
local found, said = {}, {}

local function On()
    return S.Get("enabled") and S.Get("nodeIcons") and true or false
end

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Tier(over)
    if over < C.SKILL_ORANGE then return TIER_ORANGE end
    if over < C.SKILL_YELLOW then return TIER_YELLOW end
    if over < C.SKILL_GREEN then return TIER_GREEN end
    return TIER_GREY
end

local function AddNeed(tooltip, name, named)
    local node = Scan.Node(name)
    local kind, need = Scan.Kind(node), Scan.Need(node)
    local over = Scan.Skill(kind) - need
    local c = over < 0 and Style.RED_RGB or Style.DIFFICULTY_RGB[Tier(over)]
    local text = TEXT_REQUIRES:format(TEXT_PROFESSION[kind], need)
    if named then text = TEXT_NAMED:format(name, text) end
    tooltip:AddLine(text, c.r, c.g, c.b)
end

local function OnMinimapTooltip(tooltip, data)
    if not On() or not (data and Plain(data)) then return end
    local lines = data.lines
    if not (lines and Plain(lines)) then return end
    wipe(found)
    wipe(said)
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and Plain(text) then
            for _, name in ipairs(Scan.Known(text)) do
                if not said[name] then
                    said[name] = true
                    found[#found + 1] = name
                end
            end
        end
    end
    if #found == 0 then return end
    for _, name in ipairs(found) do AddNeed(tooltip, name, #found > 1) end
    tooltip:Show()
end

local function Apply()
    if not On() or not Scan.Usable() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Scan.ReadSkills)
    end
    if not hooked then
        hooked = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.MinimapMouseover, OnMinimapTooltip)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Scan.ReadSkills()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "nodeIcons" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)
