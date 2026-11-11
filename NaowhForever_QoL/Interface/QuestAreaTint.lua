-- QuestAreaTint.lua: Quest Area Tint, the world map's quest objective areas drawn in a chosen color with a glowing edge.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local TEMPLATE = "QuestBlobPinTemplate"
local MEDIA = "Interface\\AddOns\\NaowhForever_QoL\\Media\\QuestArea\\"
local GAME_FILL = "Interface\\WorldMap\\UI-QuestBlob-Inside"
local GAME_EDGE = "Interface\\WorldMap\\UI-QuestBlob-Outside"
local GAME_FILL_ALPHA, GAME_EDGE_ALPHA = 128, 192
local ALPHA_MAX = 255
local FILL_RANGE = { 10, 90, 5 }
local PERCENT_SCALE = ns.Shared.Style.PERCENT_SCALE
local SECTION_ORDER = 14
local COLOURS = {
    { blue = "Blue", violet = "Violet", green = "Green", gold = "Gold", red = "Red" },
    { "blue", "violet", "green", "gold", "red" },
}
local TEXT_OFF = ns.L("Quest Area Tint off")

local tinted

local function On()
    return S.Get("enabled") and S.Get("mapQuestTint")
end

local function Paint(pin, fill, edge, fillAlpha, edgeAlpha)
    pin:SetFillTexture(fill)
    pin:SetBorderTexture(edge)
    pin:SetFillAlpha(fillAlpha)
    pin:SetBorderAlpha(edgeAlpha)
end

local function Apply()
    local on = On()
    if not (on or tinted) then return end
    local colour = S.Get("mapQuestTintColor")
    local fillAlpha = math.floor(S.Get("mapQuestTintFill") * ALPHA_MAX + 0.5)
    for pin in WorldMapFrame:EnumeratePinsByTemplate(TEMPLATE) do
        if on then
            Paint(pin, MEDIA .. colour .. "_fill", MEDIA .. colour .. "_edge", fillAlpha, ALPHA_MAX)
        else
            Paint(pin, GAME_FILL, GAME_EDGE, GAME_FILL_ALPHA, GAME_EDGE_ALPHA)
        end
    end
    tinted = on
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^mapQuestTint") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

table.insert(ns.Shared.MapPins, {
    map = true,
    order = SECTION_ORDER, store = S, switch = "mapQuestTint",
    rows = {
        { key = "mapQuestTint", label = "Quest Area Tint", toggle = true, store = S,
          help = "Colors the quest objective areas on the world map, with a glowing edge." },
        { key = "mapQuestTintColor", label = "Quest Area Color", choice = COLOURS, store = S,
          needs = "mapQuestTint", why = TEXT_OFF },
        { key = "mapQuestTintFill", label = "Quest Area Opacity", slider = FILL_RANGE, unit = "%",
          scale = PERCENT_SCALE, store = S, needs = "mapQuestTint", why = TEXT_OFF },
    },
})
