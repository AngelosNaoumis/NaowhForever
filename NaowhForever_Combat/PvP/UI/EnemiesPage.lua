-- EnemiesPage.lua: the Nearby Enemies card on the PvP/Nearby Enemies settings page.
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local Enemies = P.Enemies
local Settings = ns.Shared.Settings

local TEXT_EMPTY = ns.L("No one is on your Kill on Sight list")
local TEXT_CLEAR_ASK = ns.L("Clear your Kill on Sight list (%d)?")

local function HasKills()
    return Enemies.KillCount() > 0
end

local function AskClear()
    ns.Confirm(TEXT_CLEAR_ASK:format(Enemies.KillCount()), Enemies.ClearKills)
end

if P.OLD_COPY then return end

Settings.Page("PvP/Nearby Enemies", S):Card({
    id = "nearbyEnemies", name = "Nearby Enemies", order = 10, switch = "nearbyEnemies",
    help = "Enemy players seen on their nameplates around you, in a small list with Kill on Sight alerts.",
    rows = {
        { key = "enemiesAlert", label = "Alert on New Enemies", toggle = true,
          help = "Pings and flashes the game's icon when an enemy player first shows up." },
        { key = "enemiesKillAlert", label = "Kill on Sight Alert", toggle = true,
          help = "A raid warning and a line in chat when someone on your Kill on Sight list shows up." },
        { label = "Kill on Sight List", buttonText = "Clear", button = AskClear, needs = HasKills, why = TEXT_EMPTY,
          help = "Click a name in the Nearby Enemies list to add or remove it." },
    },
})
