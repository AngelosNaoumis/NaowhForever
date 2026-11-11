-- SettingsPage.lua: the Undermine Real reminder's settings page.
local ns = _G.NaowhForever

local UR = ns.UndermineReal
local S = UR.Settings
local Look = UR.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local ICON_RANGE = { 20, 64, 1 }
local ORDER_UNDERMINE = 46
local STAGE_H = 120
local STATES = {
    { key = "killed", label = "Boss Killed", tip = "What shows from a boss's kill until you loot it." },
}

local TEXT_OFF = "The Undermine Real Reminder is off"
local TEXT_ON = "On"
local TEXT_HELP = "Blinks a Tarnished Undermine Real after you kill a dungeon boss that drops one, until you loot it."
local TEXT_ICON = "How big the reminder icon is."
local TEXT_SAMPLE = "the boss"

local function Summary(store)
    return store.Get("enabled") and ns.L(TEXT_ON) or ns.L(TEXT_OFF)
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetPoint("CENTER")
    Look.New(shot)
    return shot
end

local function PaintPreview(shot)
    Look.Fill(shot, S.Get("iconSize"), ns.L(TEXT_SAMPLE))
end

local function Rows()
    return {
        Group("Size"),
        { key = "iconSize", label = "Icon Size", slider = ICON_RANGE, needs = UR.Enabled, why = TEXT_OFF,
          help = TEXT_ICON },
    }
end

Settings.Page(UR.PAGE):Card({
    id = "undermineReal", name = "Undermine Real Reminder", order = ORDER_UNDERMINE, switch = "enabled", store = S,
    help = TEXT_HELP,
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = Rows,
})
