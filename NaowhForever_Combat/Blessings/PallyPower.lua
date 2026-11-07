-- PallyPower.lua: the plans of the group's paladins running PallyPower, read from its addon messages.
local ns = _G.NaowhForever

local B = ns.Blessings
local others = B.others

local PREFIX = "PLPWR"
local ASK = "REQ"
local UNKNOWN = "n"
local FREE = "FREEASSIGN YES"
local CLEAR, CLEAR_SKIP = "CLEAR", "CLEAR SKIP"
local CHANGES = { ASSIGN = true, PASSIGN = true, MASSIGN = true, AASSIGN = true, CLEAR = true }
local CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "DRUID", "PALADIN", "HUNTER", "MAGE", "WARLOCK", "SHAMAN" }
local BLESSINGS = { "wisdom", "might", "kings" }
local AURAS = { "devotion", "retribution", "concentration", "shadow", "frost", "fire", "sanctity" }
local MAX_SYMBOLS = 9999
local MAX_COOLDOWN = 7200

local asked = {}

local function RefreshPage()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Plan(who)
    local plan = others[who]
    if plan then return plan.pallyPower and plan or nil end
    plan = { classes = {}, known = {}, players = {}, choices = 0, pallyPower = true }
    others[who] = plan
    return plan
end

local function Known(plan, keys, ranks)
    for i, key in ipairs(keys) do
        local rank = ranks:sub(2 * i - 1, 2 * i - 1)
        plan.known[key] = rank ~= "" and rank ~= UNKNOWN or nil
    end
end

local function Pick(plan, keys, index)
    local key = keys[tonumber(index)]
    return key and plan.known[key] and key or nil
end

local function Classes(plan, given)
    plan.classes = {}
    for i, class in ipairs(CLASSES) do
        plan.classes[class] = Pick(plan, BLESSINGS, given:sub(i, i))
    end
end

local function Ends(left)
    left = tonumber(left)
    return left and left >= 0 and left <= MAX_COOLDOWN and GetTime() + left or nil
end

local function OnStatus(plan, msg, symbols)
    local loh, di = msg:match("COOLDOWNS:[^:]*:([^:]*):[^:]*:([^:]*)$")
    plan.free = msg:find(FREE, 1, true) == 1 or nil
    plan.status = { symbols = math.min(tonumber(symbols), MAX_SYMBOLS), loh = Ends(loh), di = Ends(di) }
end

local function Target(name, from)
    local member = B.Sender(name)
    local plan = member and others[member.who]
    if plan and plan.pallyPower and (member.guid == from.guid or B.CanAssign(from.unit) or plan.free) then
        return plan
    end
end

local function OnClear(from, auras)
    local lead = B.CanAssign(from.unit)
    for _, plan in pairs(others) do
        if plan.pallyPower and (lead or plan.free) then
            plan.classes = {}
            if auras then plan.aura = nil end
        end
    end
end

local function OnChange(msg, from)
    if msg == CLEAR or msg == CLEAR_SKIP then return OnClear(from, msg == CLEAR) end
    local name, class, index = msg:match("^ASSIGN (.+) (%d+) (%d+)$")
    if name then
        local plan, column = Target(name, from), CLASSES[tonumber(class)]
        if plan and column then plan.classes[column] = Pick(plan, BLESSINGS, index) end
        return
    end
    local given
    name, given = msg:match("^PASSIGN (.+)@([%dn]*)$")
    if name then
        local plan = Target(name, from)
        if plan then Classes(plan, given) end
        return
    end
    name, index = msg:match("^MASSIGN (.+) (%d+)$")
    if name then
        local plan = Target(name, from)
        if not plan then return end
        local key = Pick(plan, BLESSINGS, index)
        for _, column in ipairs(CLASSES) do plan.classes[column] = key end
        return
    end
    name, index = msg:match("^AASSIGN (.+) (%d+)$")
    local plan = name and Target(name, from)
    if plan then plan.aura = Pick(plan, AURAS, index) end
end

function B.OnPallyPower(msg, sender)
    local ranks, given = msg:match("^SELF ([%xn]*)@([%dn]*)$")
    local auraRanks, aura = msg:match("^ASELF ([%xn]*)@([%dn]*)$")
    local symbols = msg:match("SYMCOUNT (%d+)")
    local change = CHANGES[msg:match("^%u+")]
    if not (ranks or auraRanks or symbols or change) then return end
    local from = B.Sender(sender)
    if not from or from.guid == UnitGUID("player") then return end
    if change then
        OnChange(msg, from)
        return RefreshPage()
    end
    if from.class ~= "PALADIN" then return end
    local plan = Plan(from.who)
    if not plan then return end
    if ranks then
        Known(plan, BLESSINGS, ranks)
        Classes(plan, given)
    elseif auraRanks then
        Known(plan, AURAS, auraRanks)
        plan.aura = Pick(plan, AURAS, aura)
    else
        OnStatus(plan, msg, symbols)
    end
    RefreshPage()
end

function B.AskPallyPower()
    local channel = B.Channel()
    if not channel or InCombatLockdown() then return end
    local me, ask = UnitGUID("player"), false
    for _, member in ipairs(B.Roster()) do
        if member.class == "PALADIN" and member.guid ~= me and not others[member.who] and not asked[member.guid] then
            asked[member.guid] = true
            ask = true
        end
    end
    if ask then C_ChatInfo.SendAddonMessage(PREFIX, ASK, channel) end
end

function B.AskPallyPowerAgain()
    asked = {}
end

B.PALLYPOWER_PREFIX = PREFIX
