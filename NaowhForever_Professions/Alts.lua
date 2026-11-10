-- Alts.lua: Your Alts' Professions: each character's profession links, saved when it opens its own, and opening one from another character (P.Alts).
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings

local STORE = "profLinks"
local SKILL_LINE_INDEX = P.C.SKILL_LINE_INDEX
local OPEN_WAIT = 5
local LINK_TARGET = "|H(.-)|h"
local NAME = "^[^-]+"
local REALM_JOIN = "-"
local CLICK = "LeftButton"
local LIST_UPDATE = "TRADE_SKILL_LIST_UPDATE"
local EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_DATA_SOURCE_CHANGED", LIST_UPDATE }
local TEXT_NOT_OPENED = ns.L("%s's %s did not open.")

local list = {}
local events, waiting
local waits = 0

local Alts = {}
P.Alts = Alts

local function All()
    local all = ns.AccountSettings()[STORE]
    if type(all) == "table" then return all end
end

local function OwnList()
    if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild()
        or C_TradeSkillUI.IsTradeSkillGuildMember() or C_TradeSkillUI.IsNPCCrafting() then
        return false
    end
    return C_TradeSkillUI.CanTradeSkillListLink()
end

local function Forget(links)
    local have = {}
    for _, index in pairs({ GetProfessions() }) do
        local line = select(SKILL_LINE_INDEX, GetProfessionInfo(index))
        if line then have[line] = true end
    end
    for id in pairs(links) do
        if not have[id] then links[id] = nil end
    end
end

local function Save()
    if not OwnList() then return end
    local base = C_TradeSkillUI.GetBaseProfessionInfo()
    local id = base and base.professionID
    if not (id and id > 0) then return end
    local link = C_TradeSkillUI.GetTradeSkillListLink()
    local mine = link and ns.Shared.CharacterData(STORE, true)
    if not mine then return end
    mine.name, mine.class = GetUnitName("player", true):match(NAME), select(2, UnitClass("player"))
    mine.realm, mine.faction = GetRealmName(), UnitFactionGroup("player")
    mine.links = mine.links or {}
    local saved = mine.links[id]
    if saved and saved.link == link then return end
    mine.links[id] = { link = link, name = base.professionName }
    Forget(mine.links)
end

local function OnEvent(_, event)
    if event ~= LIST_UPDATE and waiting and C_TradeSkillUI.IsTradeSkillLinked() then waiting = nil end
    Save()
end

local function Theirs(guid, alt, me, realm, faction)
    return guid ~= me and alt.realm == realm and alt.faction == faction and alt.links ~= nil
end

local function Before(a, b)
    if a.who ~= b.who then return a.who < b.who end
    return a.prof < b.prof
end

local function Showing(guid)
    return C_TradeSkillUI.IsTradeSkillLinked() and P.Links.Viewing() and P.Links.GUID() == guid
end

local function NotOpened(wait)
    if wait ~= waits or not waiting then return end
    local alt = waiting
    waiting = nil
    if Showing(alt.guid) then return end
    ns.Print(TEXT_NOT_OPENED:format(alt.who, alt.prof))
    P.Links.End()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

function Alts.On()
    return S.Get("enabled") and S.Get("altProfessions") and not ns.GamepadStandDown()
end

function Alts.Is(guid)
    local all = All()
    return guid ~= nil and all ~= nil and all[guid] ~= nil
end

function Alts.Any()
    local all = All()
    if not all then return false end
    local me, realm, faction = UnitGUID("player"), GetRealmName(), UnitFactionGroup("player")
    for guid, alt in pairs(all) do
        if Theirs(guid, alt, me, realm, faction) and next(alt.links) then return true end
    end
    return false
end

function Alts.List()
    wipe(list)
    local all = All()
    if not all then return list end
    local me, realm, faction = UnitGUID("player"), GetRealmName(), UnitFactionGroup("player")
    for guid, alt in pairs(all) do
        if Theirs(guid, alt, me, realm, faction) then
            for _, saved in pairs(alt.links) do
                list[#list + 1] = { guid = guid, who = alt.name, class = alt.class, prof = saved.name,
                    link = saved.link }
            end
        end
    end
    table.sort(list, Before)
    return list
end

function Alts.Open(alt)
    if IsModifiedClick() then return end
    local target = alt.link:match(LINK_TARGET)
    if not target then return end
    waits = waits + 1
    local wait = waits
    waiting = alt
    SetItemRef(target, alt.link, CLICK)
    C_Timer.After(OPEN_WAIT, function() NotOpened(wait) end)
end

function ns.ForgetAltProfessions(realmKey, name)
    local all = All()
    if not all then return end
    for guid, alt in pairs(all) do
        if alt.name == name and alt.realm .. REALM_JOIN .. (alt.faction or "") == realmKey then all[guid] = nil end
    end
end

local function Apply()
    if not Alts.On() then
        if events then events:UnregisterAllEvents() end
        waiting = nil
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

S.OnChange(function(key)
    if key == "enabled" or key == "altProfessions" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
