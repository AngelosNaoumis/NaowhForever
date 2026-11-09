-- Regression test for Discovery's Field Journal (NaowhForever_Discovery/Data/FieldJournal.lua and
-- NaowhForever_Discovery/Field.lua): its switch starts off and its files load in their layers; the
-- data has every cooking recipe that makes a dish, no entry twice and its skills in order; nothing
-- is listened to while it is off; a fish, a herb and a dish are counted when they are really looted
-- or cooked, and nothing else is; the cast event is heard only while a profession window is open;
-- secret values are left alone; ticking one off by hand, progress, ranks, where-lines, its settings
-- page and turning it off again.
--   lua5.1 Tools/regression/test-field-journal.lua

local checks = 0
local function Check(ok, label)
    checks = checks + 1
    assert(ok, label)
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return text
end

-- The switch and the load order.
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper }
_G.NaowhForever = ns
assert(loadstring(Read("Core/Features.lua"), "Features"))()
Check(ns.FEATURES.discovery.fieldJournal == false, "the Field Journal starts off")
Check(Read("NaowhForever_Discovery/Discovery.lua"):find("fieldJournal = F.fieldJournal", 1, true),
    "Discovery's store reads its default")
local xml = Read("NaowhForever_Discovery/Discovery.xml")
local function At(file) return assert(xml:find(file, 1, true), file) end
Check(At('"Data\\FieldJournal.lua"') < At('"Field.lua"'), "the data loads before the rules")
Check(At('"Library.lua"') < At('"Field.lua"') and At('"Field.lua"') < At('"View\\FieldRow.lua"')
    and At('"View\\FieldRow.lua"') < At('"UI\\Window.lua"') and At('"UI\\Window.lua"') < At('"UI\\FieldSettings.lua"'),
    "the rules after the book rules they use, then the rows, the window and the settings page")

-- The data.
assert(loadstring(Read("NaowhForever_Discovery/Data/FieldJournal.lua"), "FieldJournal"))()
local data = ns.FieldJournal
local cooking = Read("NaowhForever_Professions/Data/RecipeData.lua")
cooking = cooking:sub((assert(cooking:find("    [185] = {", 1, true))))
cooking = cooking:sub(1, (cooking:find("\n    %[%d+%] = {", 2)) or #cooking)
local recipes = {}
for spell, rest in cooking:gmatch("\n%s*{ spell = (%d+)([^\n]*)") do
    local item, skill = rest:match("item = (%d+), skill = (%d+)")
    if item then recipes[tonumber(spell)] = { tonumber(item), tonumber(skill) } end
end
local dishes = 0
for _, dish in ipairs(data.dishes) do
    local recipe = recipes[dish.spell]
    Check(recipe and recipe[1] == dish.item and recipe[2] == dish.skill, "dish " .. dish.spell .. " is RecipeData's")
    recipes[dish.spell] = nil
    dishes = dishes + 1
end
Check(next(recipes) == nil and dishes > 100, "every cooking recipe that makes a dish is in, once")
for page, key in pairs({ fish = "item", herbs = "item", dishes = "spell" }) do
    local seen, last = {}, 0
    for _, entry in ipairs(data[page]) do
        Check(not seen[entry[key]], page .. ": " .. entry[key] .. " once")
        seen[entry[key]] = true
        if entry.skill then
            Check(entry.skill >= last, page .. ": in order of skill at " .. entry[key])
            last = entry.skill
        end
    end
end
assert(loadstring(Read("NaowhForever_QoL/Interface/FishingLevelsData.lua"), "FishingLevelsData"))()
for _, fish in ipairs(data.fish) do
    Check(fish.zones or fish.schools, "fish " .. fish.item .. " is caught somewhere")
    Check((fish.skill == nil) == (fish.zones == nil), "fish " .. fish.item .. " has a skill when it has zones")
    local lowest
    for i = 1, #(fish.zones or {}), 2 do
        local levels = ns.FishingLevels[fish.zones[i]]
        if levels and (not lowest or levels[1] < lowest) then lowest = levels[1] end
    end
    Check(fish.skill == lowest, "fish " .. fish.item .. ": its skill is the lowest of the zones it names")
end
local herbs = {}
for _, herb in ipairs(data.herbs) do
    herbs[herb.item] = herb
    Check(#herb.nodes > 0, "herb " .. herb.item .. " has the nodes that yield it")
end
Check(herbs[2447] and herbs[2447].skill == 1 and herbs[13468] and herbs[13468].skill == 300,
    "Peacebloom at 1 and Black Lotus at 300")
Check(herbs[13702] == nil and herbs[5339] == nil, "quest herbs such as Doom Weed and Serpentbloom are left out")

-- The rules, against a stub world.
local settings = { enabled = true, fieldJournal = false }
local listeners = {}
local S = { Get = function(key) return settings[key] end }
function S.Set(key, value)
    settings[key] = value
    for _, fn in ipairs(listeners) do fn(key, value) end
end
function S.OnChange(fn) listeners[#listeners + 1] = fn end

local frames, side, waypoint = {}, "A", nil
local function NewFrame()
    local frame = { events = {}, unit = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event, unit) self.events[event], self.unit[event] = true, unit end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = frame
    return frame
end
local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local saved = {}
ns.Shared = { CharacterData = function(key, create)
    if not saved[key] and create then saved[key] = {} end
    return saved[key]
end }
ns.Apply = function() end
local Library = {
    Side = function() return side end,
    ZoneName = function(map) return "map " .. map end,
    Waypoint = function(name, map, x, y) waypoint = { name, map, x, y } end,
}
ns.Discovery = { Settings = S, Library = Library }

local loot, fishing, secrets = {}, false, {}
local env = setmetatable({
    CreateFrame = NewFrame,
    C_Item = {
        GetItemInfoInstant = function(link) return tonumber(link:match("item:(%d+)")) end,
        GetItemIconByID = function() return 1 end,
    },
    IsFishingLoot = function() return fishing end,
    GetNumLootItems = function() return #loot end,
    GetLootSlotLink = function(slot) return loot[slot].link end,
    GetLootSlotInfo = function(slot) return 1, "x", loot[slot].qty end,
    GetLootSourceInfo = function(slot) return loot[slot].source, loot[slot].qty end,
    issecretvalue = function(v) return secrets[v] == true end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    hooksecurefunc = function(t, name, fn)
        local orig = t[name]
        t[name] = function(...) orig(...) fn(...) end
    end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_Discovery/Field.lua"), "Field.lua"))
setfenv(chunk, env)
chunk()
local Field = ns.Discovery.Field

Check(#frames == 0, "off: no frame is made at load")
ns.Apply()
Check(#frames == 0, "nor once the addon applies its settings")
Check(not Field.On() and Field.Progress("fish") == 0, "nothing is had")

local changed = {}
Field.OnChange(function(page) changed[#changed + 1] = page or "all" end)
S.Set("fieldJournal", true)
Check(changed[#changed] == "all", "turning it on tells the window, to redraw its card")
local events = frames[1]
Check(#frames == 1 and events.events.LOOT_OPENED and events.events.LOOT_SLOT_CLEARED and events.events.LOOT_CLOSED
    and events.events.TRADE_SKILL_SHOW and events.events.TRADE_SKILL_CLOSE, "on: loot and profession windows are heard")
Check(not events.events.UNIT_SPELLCAST_SUCCEEDED, "but no casts while no profession window is open")

local function Fire(event, ...) events.onEvent(events, event, ...) end
local function Link(item) return "|Hitem:" .. item .. "::|h[x]|h" end
local OBJECT, CREATURE, CHEST = "GameObject-0-1-2-3-1618-0000", "Creature-0-1-2-3-299-0000",
    "GameObject-0-1-2-3-2843-0000"
local function Has(page, id) return saved.discoveryField and saved.discoveryField[page][id] end

fishing = true
loot = { { link = Link(6291), qty = 1, source = OBJECT }, { link = Link(6292), qty = 1, source = OBJECT },
    { link = Link(3820), qty = 1, source = OBJECT }, { link = Link(6303), qty = 1, source = OBJECT } }
Fire("LOOT_OPENED")
Check(saved.discoveryField == nil, "opening the loot writes nothing yet")
Fire("LOOT_SLOT_CLEARED", 1)
Fire("LOOT_SLOT_CLEARED", 2)
Fire("LOOT_SLOT_CLEARED", 3)
Check(Has("fish", 6291) == 1, "a fish taken from a catch is counted")
Check(Has("fish", 6292) == nil, "a trophy fish is not one of the journal's")
Check(Has("herbs", 3820) == nil and Has("fish", 3820) == nil, "Stranglekelp fished up is neither a fish nor a picked herb")
Fire("LOOT_SLOT_CLEARED", 1)
Check(Has("fish", 6291) == 1, "a slot counts once")
Fire("LOOT_CLOSED")
Fire("LOOT_SLOT_CLEARED", 4)
Check(Has("fish", 6303) == nil, "a fish left in the water is not")
Check(changed[#changed] == "fish", "the page that changed is told")

fishing = false
loot = { { link = Link(2447), qty = 3, source = OBJECT }, { link = Link(2447), qty = 2, source = CREATURE },
    { link = Link(785), qty = 1, source = OBJECT }, { link = Link(2447), qty = 4, source = CHEST } }
secrets[loot[3].link] = true
Fire("LOOT_OPENED")
Fire("LOOT_SLOT_CLEARED", 1)
Fire("LOOT_SLOT_CLEARED", 2)
Fire("LOOT_SLOT_CLEARED", 3)
Fire("LOOT_SLOT_CLEARED", 4)
Check(Has("herbs", 2447) == 3, "a herb picked from its node counts each one picked, not one from a creature or a chest")
Check(Has("herbs", 785) == nil, "a secret link is left alone")
loot = { { link = Link(6291), qty = 1, source = OBJECT } }
Fire("LOOT_OPENED")
Fire("LOOT_SLOT_CLEARED", 1)
Check(Has("fish", 6291) == 1, "a fish looted any other way is no catch")
Fire("LOOT_CLOSED")

Fire("TRADE_SKILL_SHOW")
Check(events.events.UNIT_SPELLCAST_SUCCEEDED and events.unit.UNIT_SPELLCAST_SUCCEEDED == "player",
    "a profession window open: your own casts are heard")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2538)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 2538)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 3276)
secrets[2540] = true
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 2540)
Check(Has("dishes", 2538) == 2, "each dish cooked counts")
Check(Has("dishes", 3276) == nil, "another profession's craft does not")
Check(Has("dishes", 2540) == nil, "a secret spell is left alone")
Fire("TRADE_SKILL_CLOSE")
Check(not events.events.UNIT_SPELLCAST_SUCCEEDED, "the window closed: casts are not heard")

-- Ticking off, progress and ranks.
local herb = herbs[2447]
Check(Field.Count("herbs", herb) == 3 and Field.Had("herbs", herb), "a herb's count is read back")
Field.SetHad("herbs", herb, false)
Check(Field.Count("herbs", herb) == 3, "unticking by hand never clears a real count")
Check(not Field.Had("herbs", herbs[765]), "a herb never picked is not had")
Field.SetHad("fish", data.fish[#data.fish], true)
Check(Field.Count("fish", data.fish[#data.fish]) == 0, "ticked off by hand: had, with no count")
local done, total = Field.Progress("fish")
Check(done == 2 and total == #data.fish, "progress counts the ones had")
Field.SetHad("fish", data.fish[#data.fish], false)
Check(not Field.Had("fish", data.fish[#data.fish]), "and unticked again")
Check(Field.Rank(1) == 1 and Field.Rank(75) == 1 and Field.Rank(76) == 2 and Field.Rank(150) == 2
    and Field.Rank(225) == 3 and Field.Rank(226) == 4 and Field.Rank(330) == 4 and Field.Rank(nil) == nil,
    "ranks: Apprentice to 75, Journeyman to 150, Expert to 225, Artisan above")

-- Where to find them.
local function Entry(page, key, id)
    for _, entry in ipairs(data[page]) do
        if entry[key] == id then return entry end
    end
end
Check(Field.Where("fish", Entry("fish", "item", 6303)) == "map 1411 97%, map 1413 25%, map 1439 19%",
    "a fish: its best zones and its chance in each")
Check(Field.Where("fish", Entry("fish", "item", 6358)):find("and from schools of fish", 1, true),
    "and schools when they give it too")
Check(Field.Where("fish", Entry("fish", "item", 21071)) == "Caught from schools of fish", "a fish only schools give")
Check(Field.Where("herbs", herb):find("^map %d+, map %d+") ~= nil, "a herb: the zones it grows in most")
local vendor = Entry("dishes", "spell", 7751)
Check(Field.Where("dishes", vendor) == "Sold by Tharynn Bouden, map 1429", "a dish: the vendor for your side")
local taught = Entry("dishes", "spell", 6412)
Check(Field.Where("dishes", taught) == "From the quest Recipe of the Kaldorei" and Field.Spot(taught) == "Zarrin",
    "a quest's dish: the quest by name, its pin to who gives it")
side = "H"
Check(Field.Where("dishes", vendor) == "Sold by Sewa Mistrunner, map 1456", "the other side's for the other side")
Check(Field.Where("dishes", Entry("dishes", "spell", 2795)) == "Only for the other faction",
    "a vendor only the other side has")
Check(Field.Where("dishes", Entry("dishes", "spell", 2539)) == "Taught by cooking trainers", "a trainer's")
Check(Field.Where("dishes", Entry("dishes", "spell", 2538)) == "Where to learn it is not known yet", "one not known")
Field.Waypoint(vendor)
Check(waypoint and waypoint[1] == "Sewa Mistrunner" and waypoint[2] == 1456, "its pin is a waypoint to the vendor")
Check(Field.Spot(Entry("dishes", "spell", 2539)) == nil, "a trainer's has no pin")

-- Off again.
S.Set("fieldJournal", false)
Check(Count(events.events) == 0, "off again: nothing is heard")
S.Set("fieldJournal", true)
S.Set("enabled", false)
Check(Count(events.events) == 0, "nor with Discovery off")

-- Its settings page and window tab.
local page = Read("NaowhForever_Discovery/UI/FieldSettings.lua")
Check(page:find('Settings.Page("Discovery/Field Journal", S)', 1, true) and page:find('switch = "fieldJournal"', 1, true),
    "a Discovery/Field Journal page with its switch")
Check(Read("Core/Options/Modules.lua"):find('{ name = "Field Journal", reuse = true }', 1, true),
    "listed among Discovery's pages")
for help in page:gmatch('help = "([^"]+)"') do Check(#help < 100, "short help: " .. help) end
Check(Read("NaowhForever_Discovery/UI/Window.lua"):find('{ key = "journal", label = "Field Journal"', 1, true),
    "a tab in Discovery's window")

print("test-field-journal: " .. checks .. " checks passed")
