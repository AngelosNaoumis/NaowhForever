-- UndermineReal.lua: the Undermine Real reminder's settings (ns.UndermineRealSettings) and module table (ns.UndermineReal).
local ns = _G.NaowhForever

local F = ns.FEATURES.undermineReal

local STORE = "undermineReal"

local S = ns.UI.ModuleSettings("undermineReal", {
    enabled = F.enabled,
    iconSize = 40,
    undermineRealPos = nil,
})
ns.UndermineRealSettings = S

local UR = {
    Settings = S,
    PAGE = "QoL/Interface",
}
ns.UndermineReal = UR

local pending = {}

local function Got()
    local mine = ns.Shared.CharacterData(STORE, true)
    mine.got = mine.got or {}
    return mine.got
end

function UR.Enabled()
    return S.Get("enabled") and true or false
end

-- A boss's first kill each day is the one that can drop the real.
function UR.Killed(encounterID, name)
    if not UR.BOSSES[encounterID] then return false end
    local got, now = Got(), time()
    for id, expires in pairs(got) do
        if expires <= now then got[id] = nil end
    end
    if got[encounterID] then return false end
    got[encounterID] = now + C_DateAndTime.GetSecondsUntilDailyReset()
    pending[encounterID] = name
    return true
end

function UR.Looted(npcID)
    local changed = false
    for id in pairs(pending) do
        if UR.BOSSES[id] == npcID then
            pending[id] = nil
            changed = true
        end
    end
    return changed
end

function UR.Clear()
    wipe(pending)
end

function UR.Name()
    local _, name = next(pending)
    return name
end
