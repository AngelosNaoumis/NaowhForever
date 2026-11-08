-- Key.lua: the game's Group Finder key opening this Group Finder instead, while Open With the Group Finder Key is on.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local S = GF.Settings

local GAME_ACTION = "TOGGLEGROUPFINDER"
local OUR_ACTION = "NAOWHFOREVER_LFG"

local owner
local taken = ""

local function On()
    return GF.On() and S.Get("gameKey") and not ns.GamepadStandDown()
end

local function Sync()
    local on = On()
    local keys = on and table.concat({ GetBindingKey(GAME_ACTION) }, " ") or ""
    if keys ~= taken then
        if InCombatLockdown() then
            owner:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        ClearOverrideBindings(owner)
        for key in keys:gmatch("%S+") do SetOverrideBinding(owner, false, key, OUR_ACTION) end
        taken = keys
    end
    owner:UnregisterAllEvents()
    if on then owner:RegisterEvent("UPDATE_BINDINGS") end
end

local function Apply()
    if not owner then
        if not On() then return end
        owner = CreateFrame("Frame")
        owner:SetScript("OnEvent", Sync)
    end
    Sync()
end

S.OnChange(function(key)
    if key == "enabled" or key == "gameKey" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
