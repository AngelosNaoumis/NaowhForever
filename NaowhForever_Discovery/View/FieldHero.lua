-- FieldHero.lua: the Field Journal card: how many of a page's fish, herbs or dishes you have, as a count and a bar.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local S = Discovery.Settings
local Field = Discovery.Field
local V = Discovery.View

local BAR_H = 4
local DONE_GAP, DONE_DROP = 10, 3
local BAR_GAP = 12
local ABOUT_GAP = 10
local TEXT_COUNT = "%d / %d"
local KICKERS = { fish = ns.L("Fishing Journal"), herbs = ns.L("Apothecary"), dishes = ns.L("Cookbook") }
local DONE = { fish = ns.L("fish caught"), herbs = ns.L("herbs picked"), dishes = ns.L("dishes cooked") }
local ABOUT = {
    fish = ns.L("Each fish you catch is written in, with how many."),
    herbs = ns.L("Each herb you pick is written in, with how many."),
    dishes = ns.L("Each dish you cook is written in, with how many."),
}
local TEXT_BEFORE = ns.L(" Shift-click one you had before to tick it off.")
local TEXT_OFF = ns.L("Turn on Field Journal in Discovery's settings to start writing them in.")
local TEXT_DISCOVERY_OFF = ns.L("Turn on Discovery")

local function NewFieldHero(parent)
    local hero = CreateFrame("Frame", nil, parent)
    ns.Solid(hero, "BACKGROUND", T.fg, Style.CARD_FILL):SetAllPoints()
    ns.Border(hero, Style.BORDER_RGB)
    hero.kicker = ns.Font(hero, Style.KICKER_SIZE, nil, T.accentSoft)
    hero.kicker:SetPoint("TOPLEFT", Style.HERO_PAD, -Style.HERO_TOP)
    hero.count = ns.Font(hero, Style.COUNT_SIZE, nil, T.fg)
    hero.count:SetPoint("TOPLEFT", hero.kicker, "BOTTOMLEFT", 0, -Style.COUNT_GAP)
    hero.done = ns.Font(hero, Style.TEXT_SIZE, nil, T.muted)
    hero.done:SetPoint("BOTTOMLEFT", hero.count, "BOTTOMRIGHT", DONE_GAP, DONE_DROP)
    hero.bar = Parts.ProgressLine(hero, BAR_H)
    hero.bar:SetPoint("TOPLEFT", hero.count, "BOTTOMLEFT", 0, -BAR_GAP)
    hero.bar:SetPoint("RIGHT", -Style.HERO_PAD, 0)
    hero.about = ns.Font(hero, Style.SMALL_SIZE, nil, T.muted)
    hero.about:SetPoint("TOPLEFT", hero.bar, "BOTTOMLEFT", 0, -ABOUT_GAP)
    hero.about:SetPoint("RIGHT", -Style.HERO_PAD, 0)
    hero.about:SetJustifyH("LEFT")
    hero.about:SetWordWrap(true)
    return hero
end

local function SetFieldHero(hero, page)
    local done, total = Field.Progress(page)
    hero.kicker:SetText(ns.Upper(KICKERS[page]))
    hero.count:SetText(TEXT_COUNT:format(done, total))
    hero.done:SetText(DONE[page])
    hero.bar:SetProgress(total > 0 and done / total or 0)
    local on = Field.On()
    local off = S.Get("enabled") and TEXT_OFF or TEXT_DISCOVERY_OFF
    hero.about:SetText(on and ABOUT[page] .. TEXT_BEFORE or off)
    V.Paint(hero.about, on and T.muted or T.accentSoft)
    return Style.HERO_TOP + math.ceil(hero.kicker:GetStringHeight()) + Style.COUNT_GAP
        + math.ceil(hero.count:GetStringHeight()) + BAR_GAP + BAR_H + ABOUT_GAP
        + math.ceil(hero.about:GetStringHeight()) + Style.HERO_PAD
end

V.Kinds.fieldHero = { New = NewFieldHero, Set = SetFieldHero }
