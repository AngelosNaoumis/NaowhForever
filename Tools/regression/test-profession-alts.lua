-- Run with Lua 5.1 from the repository root: Your Alts' Professions. With it off nothing is built or
-- saved. With it on, opening your own profession saves its trade link for this character (never a
-- linked or guild view), a dropped profession's link goes, and another character on the same realm
-- and faction lists the first one's professions and opens one through its link the way a chat click
-- does, with a chat line and the link view ended when it does not open. A modified click does nothing,
-- an alt already open says nothing, and QoL's Forget a character drops its links. Recipes.lua treats
-- only a saved character's link as an alt's.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local LINK_TAILORING = "|cffffd000|Htrade:Player-1-AAAA:3908:197|h[Tailoring]|h|r"
local LINK_ALCHEMY = "|cffffd000|Htrade:Player-1-AAAA:2259:171|h[Alchemy]|h|r"
local TAILORING, ALCHEMY = 197, 171

local settings = { enabled = true, altProfessions = false, craftOrders = false }
local listeners = {}
local S = {
    Get = function(key) return settings[key] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
}
local function Set(key, value)
    settings[key] = value
    for _, fn in ipairs(listeners) do fn(key, value) end
end

local account = {}
local me = { guid = "Player-1-AAAA", name = "Mainalt Stone", class = "MAGE", realm = "Realm", faction = "Alliance" }
local professions = { TAILORING, ALCHEMY }
local view = { linked = false, guild = false, base = { professionID = TAILORING, professionName = "Tailoring" },
    link = LINK_TAILORING }
local baseReads = 0
local frames, printed, refs, timers = {}, {}, {}, {}
local applyHook
local viewing, viewedGUID = false, nil
local modified, ended, refreshed = false, 0, 0

local function Child(parent, key)
    parent[key] = parent[key] or {}
    return parent[key]
end

local ns = {
    L = function(text) return text end,
    Print = function(text) printed[#printed + 1] = text end,
    AccountSettings = function() return account end,
    GamepadStandDown = function() return false end,
    Shared = { CharacterData = function(key) return Child(Child(account, key), me.guid) end },
    Apply = function() end,
    ProfWindowRefresh = function() refreshed = refreshed + 1 end,
    Professions = {
        Settings = S,
        State = {},
        C = { SKILL_LINE_INDEX = 7 },
        Links = {
            Viewing = function() return viewing end,
            GUID = function() return viewedGUID end,
            End = function() ended = ended + 1; viewing = false end,
        },
    },
}
local P = ns.Professions

local env = setmetatable({
    NaowhForever = ns,
    UnitGUID = function() return me.guid end,
    GetUnitName = function() return me.name end,
    UnitFactionGroup = function() return me.faction end,
    IsModifiedClick = function() return modified end,
    UnitClass = function() return me.class, me.class end,
    GetRealmName = function() return me.realm end,
    GetProfessions = function() return professions[1], professions[2] end,
    GetProfessionInfo = function(line) return "Profession", nil, 1, 300, 0, 0, line end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    CreateFrame = function()
        local frame = { events = {} }
        function frame:SetScript(_, fn) self.onEvent = fn end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = frame
        return frame
    end,
    hooksecurefunc = function(owner, name, fn)
        if owner == ns and name == "Apply" then applyHook = fn end
    end,
    SetItemRef = function(link, text, button) refs[#refs + 1] = { link, text, button } end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_TradeSkillUI = {
        IsTradeSkillLinked = function() return view.linked end,
        IsTradeSkillGuild = function() return view.guild end,
        IsTradeSkillGuildMember = function() return false end,
        IsNPCCrafting = function() return false end,
        CanTradeSkillListLink = function() return not view.linked and not view.guild end,
        GetBaseProfessionInfo = function() baseReads = baseReads + 1; return view.base end,
        GetTradeSkillListLink = function() return view.link end,
        GetChildProfessionInfo = function() return view.base end,
    },
}, { __index = _G })
env._G = env

local function Load(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    local chunk = assert(loadstring(source, path))
    setfenv(chunk, env)
    chunk()
end

local function Fire(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.onEvent(frame, event) end
    end
end

local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

Load("NaowhForever_Professions/Alts.lua")
local Alts = P.Alts

-- Off: nothing is built, nothing is saved.
applyHook()
check("off, no event frame is built", #frames == 0)
check("off, no link is saved", account.profLinks == nil)

-- On: your own profession's link is saved when it opens.
Set("altProfessions", true)
check("on, one event frame listens", #frames == 1 and frames[1].events.TRADE_SKILL_SHOW)
Fire("TRADE_SKILL_SHOW")
local mine = account.profLinks and account.profLinks[me.guid]
check("opening your own profession saves its link", mine and mine.links[TAILORING].link == LINK_TAILORING)
check("with your full name, class, realm and faction", mine.name == "Mainalt Stone" and mine.class == "MAGE"
    and mine.realm == "Realm" and mine.faction == "Alliance")
check("and the profession's name", mine.links[TAILORING].name == "Tailoring")
view.link = LINK_TAILORING .. "skillup"
Fire("TRADE_SKILL_LIST_UPDATE")
check("a list update with the window open saves a newer link, after a skill-up or a new recipe",
    mine.links[TAILORING].link == LINK_TAILORING .. "skillup")
view.link = LINK_TAILORING
Fire("TRADE_SKILL_LIST_UPDATE")

-- Linked and guild views are someone else's: nothing of theirs is saved.
view.linked, view.base = true, { professionID = ALCHEMY, professionName = "Alchemy" }
view.link = "|cffffd000|Htrade:Player-1-ZZZZ:2259:171|h[Alchemy]|h|r"
Fire("TRADE_SKILL_SHOW")
check("a linked view is not saved", mine.links[ALCHEMY] == nil)
view.linked, view.guild = false, true
Fire("TRADE_SKILL_DATA_SOURCE_CHANGED")
check("nor a guild view", mine.links[ALCHEMY] == nil)
view.guild, view.link = false, LINK_ALCHEMY
Fire("TRADE_SKILL_LIST_UPDATE")
check("your own list after them is saved on its next update", mine.links[ALCHEMY].link == LINK_ALCHEMY)

-- A dropped profession's link goes the next time a profession is saved.
professions = { ALCHEMY }
view.link = LINK_ALCHEMY .. "x"
Fire("TRADE_SKILL_SHOW")
check("a profession you dropped is forgotten", mine.links[TAILORING] == nil and mine.links[ALCHEMY] ~= nil)
professions = { TAILORING, ALCHEMY }
view.base, view.link = { professionID = TAILORING, professionName = "Tailoring" }, LINK_TAILORING
Fire("TRADE_SKILL_SHOW")

-- Your own character is not an alt of itself.
check("no other character yet: no Alts button", not Alts.Any() and #Alts.List() == 0)

-- Another character on the same realm lists the first one's professions, by name.
account.profLinks["Player-1-CCCC"] = { name = "Elsewhere", class = "ROGUE", realm = "Other Realm", faction = "Alliance",
    links = { [TAILORING] = { link = LINK_TAILORING, name = "Tailoring" } } }
account.profLinks["Player-1-DDDD"] = { name = "Hordealt", class = "SHAMAN", realm = "Realm", faction = "Horde",
    links = { [ALCHEMY] = { link = LINK_ALCHEMY, name = "Alchemy" } } }
me = { guid = "Player-1-BBBB", name = "Bankalt", class = "PRIEST", realm = "Realm", faction = "Alliance" }
check("the first character is an alt here", Alts.Any())
local list = Alts.List()
check("its two professions are listed, sorted", #list == 2 and list[1].prof == "Alchemy"
    and list[2].prof == "Tailoring" and list[1].who == "Mainalt Stone")
check("with its GUID and class for the menu", list[1].guid == "Player-1-AAAA" and list[1].class == "MAGE")
check("a character on another realm is not listed", list[1].who ~= "Elsewhere" and list[2].who ~= "Elsewhere")
check("nor one of the other faction on the same realm", list[1].who ~= "Hordealt" and list[2].who ~= "Hordealt")
check("a saved character is known as yours", Alts.Is("Player-1-AAAA") and Alts.Is("Player-1-CCCC"))
check("a stranger is not", not Alts.Is("Player-1-ZZZZ") and not Alts.Is(nil))

-- A modified click opens nothing and waits for nothing.
modified = true
Alts.Open(list[2])
RunTimers()
check("a modified click does nothing", #refs == 0 and #timers == 0 and #printed == 0)
modified = false

-- Opening one goes through its link as a chat click does.
Alts.Open(list[2])
check("the link is clicked with its target and text", #refs == 1 and refs[1][1] == "trade:Player-1-AAAA:3908:197"
    and refs[1][2] == LINK_TAILORING and refs[1][3] == "LeftButton")
view.linked = true
Fire("TRADE_SKILL_SHOW")
RunTimers()
check("a link that opens prints nothing", #printed == 0)

-- Picking the alt that is already open fires no event, and says nothing.
viewing, viewedGUID = true, "Player-1-AAAA"
Alts.Open(list[2])
RunTimers()
check("an alt already open prints nothing and keeps its view", #printed == 0 and ended == 0)

view.linked = false
viewing = true
Alts.Open(list[1])
RunTimers()
check("a link that does not open says so once", #printed == 1 and printed[1] == "Mainalt Stone's Alchemy did not open.")
check("and ends the link view, so your own profession comes back", ended == 1 and not viewing and refreshed == 1)
RunTimers()
check("and only once", #printed == 1 and ended == 1)

Alts.Open(list[1])
Alts.Open(list[2])
RunTimers()
check("a newer click replaces the older one's wait",
    #printed == 2 and printed[2] == "Mainalt Stone's Tailoring did not open.")

-- QoL's Forget a character drops that character's links, by name and realm-faction.
ns.ForgetAltProfessions("Realm-Horde", "Mainalt Stone")
check("forgetting a name on another faction leaves the alt", Alts.Is("Player-1-AAAA"))
ns.ForgetAltProfessions("Realm-Alliance", "Mainalt Stone")
check("forgetting the alt drops its links", not Alts.Is("Player-1-AAAA") and Alts.Is("Player-1-DDDD"))
check("and no alt is left to list here", not Alts.Any())

-- Recipes.lua shows a saved character's link in the window as an alt's, a stranger's only for orders.
Load("NaowhForever_Professions/Recipes.lua")
local R = P.Recipes
account.profLinks["Player-1-AAAA"] = { name = "Mainalt Stone", realm = "Realm", faction = "Alliance", links = {} }
view.linked, viewing, viewedGUID = true, true, "Player-1-AAAA"
check("your alt's link is shown in the window", R.Alt() and R.Linked())
viewedGUID = "Player-1-ZZZZ"
check("a stranger's link is not, without Craft Orders", not R.Alt() and not R.Linked())
settings.craftOrders = true
check("with Craft Orders a stranger's link is", not R.Alt() and R.Linked())
settings.craftOrders = false
viewedGUID = "Player-1-AAAA"
Set("altProfessions", false)
check("with Your Alts' Professions off your alt's link is a stranger's", not R.Alt() and not R.Linked())
check("and nothing listens any more", next(frames[1].events) == nil)

print(("test-profession-alts: %d checks passed"):format(checks))
