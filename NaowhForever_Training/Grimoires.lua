-- Grimoires.lua: a warlock's demon books, and the ranks each demon knows, read while it is out.
local ns = _G.NaowhForever

local CharacterData = ns.Shared.CharacterData

local Training = ns.Training
local S = Training.Settings
local Changed = Training.Changed

local LEVEL, SPELL = Training.C.ENTRY_LEVEL, Training.C.ENTRY_SPELL
local WARLOCK = "WARLOCK"
local KNOWN = "trainingDemonBooks"
local EVENTS = { "SPELLS_CHANGED", "PET_BAR_UPDATE" }

local byFamily, byItem, demonOf, after
local seen = {}
local events

local function Warlock()
    return select(2, UnitClass("player")) == WARLOCK
end

local function On()
    return Training.On() and S.Get("demonBooks") and Warlock()
end

local function Index()
    if byItem then return end
    byFamily, byItem, demonOf, after = {}, {}, {}, {}
    for _, demon in ipairs(ns.TrainingGrimoires) do
        for _, family in ipairs(demon.families) do byFamily[family] = demon end
        for _, book in ipairs(demon.books) do
            byItem[book.item] = book
            demonOf[book] = demon
            if book.needs then after[book.needs] = book[SPELL] end
        end
    end
end

local function PetKnows(spell)
    return spell ~= nil and C_SpellBook.IsSpellKnown(spell, Enum.SpellBookSpellBank.Pet)
end

local function Read(demon)
    wipe(seen)
    local any = false
    for _, book in ipairs(demon.books) do
        if PetKnows(book[SPELL]) then
            seen[book[SPELL]] = true
            any = true
        end
        if PetKnows(book.needs) then any = true end
    end
    return any
end

local function Same(saved)
    for spell in pairs(saved) do
        if not seen[spell] then return false end
    end
    for spell in pairs(seen) do
        if not saved[spell] then return false end
    end
    return true
end

local function Record()
    local _, family = UnitCreatureFamily("pet")
    if not family or issecretvalue(family) then return end
    local demon = byFamily[family]
    if not demon or not Read(demon) then return end
    local all = CharacterData(KNOWN, true)
    if not all or all[demon.line] and Same(all[demon.line]) then return end
    local copy = {}
    for spell in pairs(seen) do copy[spell] = true end
    all[demon.line] = copy
    Changed()
end

local function Saved(demon)
    local all = CharacterData(KNOWN)
    return all and all[demon.line]
end

local function Knows(saved, spell)
    if not spell then return false end
    return saved[spell] == true or Knows(saved, after[spell])
end

local Grimoires = { On = On, Warlock = Warlock }
Training.Grimoires = Grimoires

function Grimoires.Demons()
    Index()
    return ns.TrainingGrimoires
end

function Grimoires.Book(item)
    Index()
    local book = byItem[item]
    return book, book and demonOf[book]
end

function Grimoires.Name(demon)
    return ns.L(demon.name)
end

function Grimoires.Seen(demon)
    return Saved(demon) ~= nil
end

function Grimoires.State(book, level)
    Index()
    local saved = Saved(demonOf[book])
    if saved and Knows(saved, book[SPELL]) then return "learned" end
    if book[LEVEL] > level then return "later" end
    if not saved then return "unknown" end
    return "now"
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    Index()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Record)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    events:RegisterUnitEvent("UNIT_PET", "player")
    Record()
end

local function OnSettingChanged(key)
    if key == "enabled" then
        Apply()
    elseif key == "demonBooks" then
        Apply()
        Changed()
    end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
