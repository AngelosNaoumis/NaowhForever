-- Run with Lua 5.1 from the repository root: QoL's fishing cards (NaowhForever_QoL/Loot/Fishing*.lua).
-- Off by default and silent while off; the fishing key puts on gear, then a lure, then casts, one per press,
-- and never twice over gear or a lure the game would not take; it reels in only while the bobber is the soft
-- target, with the soft target settings raised for the channel alone; noted gear follows what you wear and
-- comes back after combat; double right-click casts with a pole equipped; Louder Splash raises the sound for
-- the channel only, and a /reload never leaves it loud; Auto Loot While Fishing holds auto loot on from the
-- cast until the catch is looted.
local checks = 0
local function Check(label, got, want)
    if got ~= want then error(("%s: got %s, want %s"):format(label, tostring(got), tostring(want)), 2) end
    checks = checks + 1
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local NOTHING = function() end
local frames, named = {}, {}
local function Frame(_, name)
    local f = { scripts = {}, events = {}, attributes = {}, name = name }
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    frames[#frames + 1] = f
    if name then named[name] = f end
    return f
end

local BOBBER_GUID = "GameObject-0-1-2-3-35591-0000AAAA"
local HERB_GUID = "GameObject-0-1-2-3-1617-0000BBBB"
local SWORD, SHIELD, HAT, OLD_HAT = "|Hitem:2488|h", "|Hitem:2129|h", "|Hitem:7996|h", "|Hitem:3000|h"
local POLE, NEW_SWORD = "|Hitem:6365|h", "|Hitem:9999|h"
local TEMPORARY, IMBUE = 2, 3
local state = {
    combat = false, now = 100, level = 20, known = { [7620] = true, [7731] = true }, keys = { "F", "SHIFT-F" },
    worn = { [16] = 2488, [17] = 2129, [1] = 3000 }, links = { [16] = SWORD, [17] = SHIELD, [1] = OLD_HAT },
    bags = { [0] = { 6256, 6365, 6367, 6533, 6530 } },
    counts = { [6533] = 1, [6530] = 5, [SWORD] = 1, [SHIELD] = 1, [OLD_HAT] = 1, [HAT] = 1 },
    usable = { [6533] = true, [6530] = true },
    levels = { [6256] = 5, [6365] = 20, [6367] = 35 }, needs = { [6367] = 40 }, enchants = {}, soft = nil,
    gamepad = false,
    cvars = { SoftTargetInteract = "1", SoftTargetInteractArc = "0", SoftTargetInteractRange = "10",
        Sound_MasterVolume = "0.5", Sound_SFXVolume = "0.5", Sound_MusicVolume = "0.4", Sound_AmbienceVolume = "0.6",
        autoLootDefault = "0" },
    temps = {}, overrides = {}, equipped = {}, printed = {}, foci = nil, mouseover = false, tooltip = false,
    timers = {},
    sets = { [7] = { name = "Fishing", equipped = false, ignored = { [16] = false, [1] = false } } },
}
local POLES = { [6256] = true, [6365] = true, [6367] = true }

local account, root = {}, {}
local cards = {}
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, accentSoft = { r = 1, g = 1, b = 1 }, muted = { r = 1, g = 1, b = 1 } },
    SettingsRoot = function() return root end,
    AccountSettings = function() return account end,
    GamepadStandDown = function() return state.gamepad end,
    Print = function(text) state.printed[#state.printed + 1] = text end,
    Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
    Glimmer = { Plain = function(v) return not (type(v) == "table" and v.secret) end },
    Shared = { Settings = { Page = function(page) return { Card = function(_, c) c.page = page; cards[c.id] = c end } end } },
}
ns.UI = {
    ModuleSettings = function(key, defaults)
        local S = {}
        function S.DB()
            if type(root[key]) ~= "table" then root[key] = {} end
            return root[key]
        end
        function S.Get(k)
            local v = S.DB()[k]
            if v == nil then return defaults[k] end
            return v
        end
        function S.Set(k, v) S.DB()[k] = v end
        return S
    end,
}

local function CVar(name)
    if state.temps[name] ~= nil then return state.temps[name] end
    return state.cvars[name]
end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    UIParent = {}, WorldFrame = { world = true },
    GameTooltip = { IsShown = function() return state.tooltip end },
    BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = 4,
    Enum = { ItemClass = { Weapon = 2 }, ItemWeaponSubclass = { Fishingpole = 20 },
        ItemEnchantType = { Temporary = TEMPORARY, Imbue = IMBUE } },
    C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
    InCombatLockdown = function() return state.combat end,
    GetTime = function() return state.now end,
    GetBindingKey = function() return unpack(state.keys) end,
    SetOverrideBinding = function(owner, priority, key, action)
        state.overrides[owner] = state.overrides[owner] or {}
        state.overrides[owner][key] = { action = action, priority = priority }
    end,
    SetOverrideBindingClick = function(owner, priority, key, button)
        state.overrides[owner] = state.overrides[owner] or {}
        state.overrides[owner][key] = { click = button, priority = priority }
    end,
    ClearOverrideBindings = function(owner) state.overrides[owner] = nil end,
    GetInventoryItemID = function(_, slot) return state.worn[slot] end,
    GetInventoryItemLink = function(_, slot) return state.links[slot] end,
    UnitGUID = function(unit)
        if unit == "player" then return "Player-1-00000001" end
        if unit == "softinteract" then return state.soft end
    end,
    UnitLevel = function() return state.level end,
    UnitExists = function() return state.mouseover end,
    UnitCastingInfo = function() return state.casting end,
    UnitChannelInfo = function() return state.channel end,
    GetMouseFoci = function() return { state.foci } end,
    C_CVar = {
        GetCVar = CVar,
        SetTempCVar = function(name, value) state.temps[name] = value end,
        RemoveTempCVar = function(name) state.temps[name] = nil end,
    },
    C_SpellBook = { IsSpellKnown = function(id) return state.known[id] == true end },
    C_Container = {
        GetContainerNumSlots = function(bag) return state.bags[bag] and #state.bags[bag] or 0 end,
        GetContainerItemID = function(bag, slot) return state.bags[bag] and state.bags[bag][slot] end,
    },
    C_Item = {
        GetItemInfoInstant = function(id)
            if POLES[id] then return id, nil, nil, nil, nil, 2, 20 end
            return id, nil, nil, nil, nil, 4, 0
        end,
        GetItemInfo = function(id) return "x", "x", 1, state.levels[id], state.needs[id] or 1 end,
        GetItemCount = function(item) return state.counts[item] or 0 end,
        IsUsableItem = function(id) return state.usable[id] == true end,
        GetWeaponEnchantInfo = function(slot) return slot == 0 and state.enchants or {} end,
        EquipItemByName = function(item, slot) state.equipped[#state.equipped + 1] = { item = item, slot = slot } end,
    },
    C_EquipmentSet = {
        GetEquipmentSetIDs = function() return { 7 } end,
        GetEquipmentSetID = function(name)
            for id, set in pairs(state.sets) do if set.name == name then return id end end
        end,
        GetEquipmentSetInfo = function(id)
            local set = state.sets[id]
            return set.name, 0, id, set.equipped
        end,
        GetIgnoredSlots = function(id)
            local out = {}
            for slot = 1, 19 do out[slot] = state.sets[id].ignored[slot] == nil end
            return out
        end,
    },
    hooksecurefunc = function(t, name, fn)
        local orig = t[name]
        t[name] = function(...) orig(...); fn(...) end
    end,
}, { __index = _G })
env._G = env

local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end

_G.NaowhForever = ns
Load("Core/Features.lua")
Load("Core/Settings.lua")
Load("NaowhForever_QoL/Glimmer/Constants.lua")
local S = ns.QoLSettings

Check("One-Key Fishing starts off", ns.FEATURES.qol.fishingKey, false)
Check("Louder Splash starts off", ns.FEATURES.qol.fishingSounds, false)
Check("Auto Loot While Fishing starts off", ns.FEATURES.qol.fishingAutoLoot, false)
Check("double right-click starts off", S.Get("fishingDoubleClick"), false)
Check("the lure step starts off", S.Get("fishingLure"), false)
Check("the gear step starts off", S.Get("fishingGear"), false)
Check("no gear set is picked", S.Get("fishingGearSet"), "")

Load("NaowhForever_QoL/Loot/FishingData.lua")
local first = #frames
Load("NaowhForever_QoL/Loot/FishingGear.lua")
local gearBoot = frames[first + 1]
first = #frames
Load("NaowhForever_QoL/Loot/Fishing.lua")
local keyEvents, keyBoot = frames[first + 1], frames[first + 2]
first = #frames
Load("NaowhForever_QoL/Loot/FishingSounds.lua")
local loudEvents, loudBoot = frames[first + 1], frames[first + 2]
first = #frames
Load("NaowhForever_QoL/Loot/FishingLoot.lua")
local lootEvents, lootBoot = frames[first + 1], frames[first + 2]

local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function Fire(frame, event, ...)
    frame.scripts.OnEvent(frame, event, ...)
end

local function FrameWith(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f ~= keyEvents and f ~= loudEvents and f ~= lootEvents then return f end
    end
end

local function Kept()
    return account.fishingReturn and account.fishingReturn["Player-1-00000001"]
end

gearBoot.scripts.OnEvent(gearBoot, "PLAYER_LOGIN")
keyBoot.scripts.OnEvent(keyBoot, "PLAYER_LOGIN")
loudBoot.scripts.OnEvent(loudBoot, "PLAYER_LOGIN")
lootBoot.scripts.OnEvent(lootBoot, "PLAYER_LOGIN")
Check("off, no secure button is built", named.NaowhForeverFish, nil)
Check("off, the key listens to nothing", Count(keyEvents.events), 0)
Check("off, Louder Splash listens to nothing", Count(loudEvents.events), 0)
Check("off, Auto Loot While Fishing listens to nothing", Count(lootEvents.events), 0)
Check("off, the gear listens to nothing", FrameWith("PLAYER_EQUIPMENT_CHANGED"), nil)
Check("off, nothing is saved", Count(account), 0)
Check("the key's card is on Loot & Items", cards.fishingKey.page, "QoL/Loot & Items")
Check("after Gear Reminders", cards.fishingKey.order, 56)
Check("its switch is One-Key Fishing's", cards.fishingKey.switch, "fishingKey")
Check("its first row is the key binding", cards.fishingKey.rows[1].binding, "CLICK NaowhForeverFish:LeftButton")
Check("Put Gear Back is the gear binding", cards.fishingKey.rows[6].binding, "NAOWHFOREVER_FISHING_GEAR")
Check("Louder Splash has its own card and switch", cards.fishingSounds.switch, "fishingSounds")
Check("beside it", cards.fishingSounds.page == "QoL/Loot & Items" and cards.fishingSounds.order == 57, true)
Check("Auto Loot While Fishing has its own card and switch", cards.fishingAutoLoot.switch, "fishingAutoLoot")
Check("after Louder Splash", cards.fishingAutoLoot.page == "QoL/Loot & Items" and cards.fishingAutoLoot.order == 58,
    true)
Check("the bindings exist", Read("Bindings.xml"):find('name="CLICK NaowhForeverFish:LeftButton"', 1, true) ~= nil
    and Read("Bindings.xml"):find("NaowhForever_FishingGearOff()", 1, true) ~= nil, true)
Check("Gear Sets renames the fishing gear set with its own picks",
    Read("NaowhForever_Combat/GearSets/GearSets.lua"):find('"fishingGearSet" }', 1, true) ~= nil, true)

S.Set("fishingKey", true)
local key, click = named.NaowhForeverFish, named.NaowhForeverFishClick
Check("on, the key's button is built", key ~= nil and click ~= nil, true)
Check("the key acts on the press", key.attributes.useOnKeyDown == true and key.clicks[1] == "AnyDown", true)
Check("the double-click button acts on the release", click.attributes.useOnKeyDown == false and click.clicks[1] == "AnyUp", true)
Check("on, it hears the Fishing channel", keyEvents.events.UNIT_SPELLCAST_CHANNEL_START, "player")
Check("and combat", keyEvents.events.PLAYER_REGEN_DISABLED, true)
Check("not the mouse, while double-click is off", keyEvents.events.GLOBAL_MOUSE_DOWN, nil)

local function Press(button)
    button = button or key
    button.scripts.PreClick(button)
    return button.attributes
end

local a = Press()
Check("with no gear step, the key casts", a.type, "spell")
Check("the highest Fishing you know", a.spell, 7731)
state.channel = "Fishing"
a = Press()
Check("a channel still running is never recast over", a.type, nil)
state.channel = nil

S.Set("fishingGear", true)
local gearEvents = FrameWith("PLAYER_EQUIPMENT_CHANGED")
Check("the gear step hears your equipment", gearEvents ~= nil, true)
Check("and your bags", gearEvents.events.BAG_UPDATE_DELAYED, true)
Check("not combat while nothing is noted", gearEvents.events.PLAYER_REGEN_DISABLED, nil)

local function Wear(slot, id, link)
    state.worn[slot], state.links[slot] = id, link
    Fire(gearEvents, "PLAYER_EQUIPMENT_CHANGED", slot, id ~= nil)
end

a = Press()
Check("with no pole worn, the key equips one", a.type, "item")
Check("the best one your level can equip", a.item, "item:6365")
local kept = Kept()
Check("what it replaces is noted", kept[16] == SWORD and kept[17] == SHIELD, true)
Check("only the hands for a pole", kept[1], nil)
Check("noted gear listens for combat", gearEvents.events.PLAYER_REGEN_DISABLED, true)
a = Press()
Check("a pole the game did not put on is not asked for again", a.type, "spell")
Fire(gearEvents, "BAG_UPDATE_DELAYED")
a = Press()
Check("until your bags change", a.item, "item:6365")
Wear(17, nil, nil)
Wear(16, 6365, POLE)
a = Press()
Check("once the pole is on, the key casts", a.type, "spell")
Check("the first noted gear is kept", Kept()[16], SWORD)

S.Set("fishingLure", true)
a = Press()
Check("with the lure step and a bare pole, the key puts on a lure", a.type, "item")
Check("the best lure you have", a.item, "item:6533")
Check("onto the main hand", a["target-slot"], 16)
Check("and hears how its cast ends", keyEvents.events.UNIT_SPELLCAST_SUCCEEDED, "player")
state.casting = "Aquadynamic Fish Attractor"
a = Press()
Check("while the lure goes on, the key does nothing", a.type, nil)
state.casting = nil
state.now = state.now + 3
Fire(keyEvents, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-l1", 8532)
Check("its cast ending stops the hearing", keyEvents.events.UNIT_SPELLCAST_SUCCEEDED, nil)
a = Press()
Check("the wait for the lure to show starts when its cast succeeds", a.type, "spell")
state.now = state.now + 5
state.enchants = { { hasEnchant = true, enchantType = TEMPORARY } }
a = Press()
Check("a lured pole casts", a.type, "spell")
Check("and leaves the target slot clear", a["target-slot"], nil)
state.enchants = { { hasEnchant = true, enchantType = IMBUE } }
state.now = state.now + 5
a = Press()
Check("an imbue is not a lure", a.item, "item:6533")
Fire(keyEvents, "UNIT_SPELLCAST_INTERRUPTED", "player", "cast-l2", 8532)
state.now = state.now + 5
a = Press()
Check("an interrupted lure is not held against it", a.item, "item:6533")
Fire(keyEvents, "UNIT_SPELLCAST_FAILED", "player", "cast-l3", 8532)
state.now = state.now + 5
a = Press()
Check("one miss is not enough to give up on it", a.item, "item:6533")
state.now = state.now + 5
a = Press()
Check("a second miss passes it over", a.item, "item:6530")
state.now = state.now + 5
state.enchants = { { hasEnchant = true, enchantType = TEMPORARY } }
Press()
state.enchants = {}
state.usable[6530] = false
state.now = state.now + 60
a = Press()
Check("a lure you cannot use yet is passed over", a.type, "spell")
state.enchants = { { hasEnchant = true, enchantType = TEMPORARY } }

local keyOwner
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", 7731)
Check("the channel raises Enable Interact Key for itself", state.temps.SoftTargetInteract, "3")
Check("the arc to in front of you", state.temps.SoftTargetInteractArc, "1")
Check("and the range", state.temps.SoftTargetInteractRange, "20")
Check("those temp values are noted", Count(account.fishingReelTemps), 3)
Check("it waits for the bobber", next(state.overrides), nil)
Check("it hears the soft target", keyEvents.events.PLAYER_SOFT_INTERACT_CHANGED, true)
a = Press()
Check("while the line is out and no bobber, the key does nothing", a.type, nil)
Fire(keyEvents, "PLAYER_SOFT_INTERACT_CHANGED", nil, BOBBER_GUID)
for owner, binds in pairs(state.overrides) do keyOwner = owner; Check("the key reels in", binds.F.action, "INTERACTTARGET") end
Check("on every key bound to it", state.overrides[keyOwner]["SHIFT-F"].action, "INTERACTTARGET")
Check("ahead of other bindings", state.overrides[keyOwner].F.priority, true)
Fire(keyEvents, "PLAYER_SOFT_INTERACT_CHANGED", BOBBER_GUID, HERB_GUID)
Check("another soft target takes the reel away", state.overrides[keyOwner], nil)
Fire(keyEvents, "PLAYER_SOFT_INTERACT_CHANGED", HERB_GUID, BOBBER_GUID)
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-1", 7731)
Check("the catch ends the reel", state.overrides[keyOwner], nil)
Check("and puts the soft target settings back", next(state.temps), nil)
Check("and forgets them", account.fishingReelTemps, nil)
Check("and stops hearing the soft target", keyEvents.events.PLAYER_SOFT_INTERACT_CHANGED, nil)

Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-2", 12051)
Check("another channel is not fishing", next(state.temps), nil)
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3", { secret = true })
Check("a secret spell is not fishing", next(state.temps), nil)
state.cvars.SoftTargetInteract, state.cvars.SoftTargetInteractArc, state.cvars.SoftTargetInteractRange = "3", "2", "25"
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4", 7731)
Check("settings already high enough are left alone", next(state.temps), nil)
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-4", 7731)
state.cvars.SoftTargetInteract, state.cvars.SoftTargetInteractArc, state.cvars.SoftTargetInteractRange = "1", "0", "10"
state.gamepad = true
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-5", 7731)
Check("under the gamepad style the game's own values are left alone", next(state.temps), nil)
Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-5", 7731)
state.gamepad = false

Fire(keyEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-6", 7731)
Fire(keyEvents, "PLAYER_SOFT_INTERACT_CHANGED", nil, BOBBER_GUID)
Fire(keyEvents, "PLAYER_REGEN_DISABLED")
Fire(gearEvents, "PLAYER_REGEN_DISABLED")
Check("combat takes the reel away", state.overrides[keyOwner], nil)
Check("and the soft target settings", next(state.temps), nil)
Check("and empties the key", key.attributes.type, nil)
Check("combat puts the weapons back as it starts", #state.equipped, 2)
Check("the sword into the main hand", state.equipped[1].item == SWORD and state.equipped[1].slot == 16, true)
Check("the shield into the off hand", state.equipped[2].item == SHIELD and state.equipped[2].slot == 17, true)
Check("they stay noted until they are on", Kept()[16], SWORD)
state.combat = true
a = Press()
Check("in combat the key does nothing", a.type, nil)
Wear(16, 2488, SWORD)
Check("the pole coming off for our own put back keeps the rest", Kept()[17], SHIELD)
Wear(17, 2129, SHIELD)
state.combat = false
Fire(gearEvents, "PLAYER_REGEN_ENABLED")
Check("nothing is left to put back", Kept(), nil)
Check("so combat is no longer heard", gearEvents.events.PLAYER_REGEN_DISABLED, nil)
state.equipped = {}

S.Set("fishingGearSet", "Fishing")
a = Press()
Check("a picked gear set is put on", a.type, "equipmentset")
Check("by its name", a.equipmentset, "Fishing")
kept = Kept()
Check("the slots the set changes are noted", kept[1], OLD_HAT)
Check("and both hands", kept[16] == SWORD and kept[17] == SHIELD, true)
Check("not the slots it ignores", kept[5], nil)
Wear(1, 7996, HAT)
Wear(17, nil, nil)
Wear(16, 6365, POLE)
a = Press()
Check("a set with a piece missing counts as on once the pole is in hand", a.type, "spell")
state.combat = true
env.NaowhForever_FishingGearOff()
Check("Put Gear Back in combat equips nothing in the lockdown", #state.equipped, 0)
Check("and says it waits", state.printed[#state.printed], "Your gear goes back when combat ends.")
state.combat = false
Fire(gearEvents, "PLAYER_REGEN_ENABLED")
Check("after combat everything goes back", #state.equipped, 3)
Check("the hat too", state.equipped[1].item == OLD_HAT and state.equipped[1].slot == 1, true)
Wear(16, 2488, SWORD)
Check("the sword coming back is ours, so the rest stays noted", Kept()[1], OLD_HAT)
Wear(17, 2129, SHIELD)
Wear(1, 3000, OLD_HAT)
Check("all back, nothing is noted", Kept(), nil)
env.NaowhForever_FishingGearOff()
Check("with nothing noted, Put Gear Back says so", state.printed[#state.printed], "No fishing gear to put back.")
state.equipped = {}

S.Set("fishingGearSet", "")
Press()
Wear(17, nil, nil)
Wear(16, 6365, POLE)
state.counts[SWORD] = 0
env.NaowhForever_FishingGearOff()
Check("a noted item no longer in your bags is let go", Kept()[16], nil)
Check("with a line in chat", state.printed[#state.printed], SWORD .. " is not in your bags, so it was not put back.")
Check("the rest is put back", state.equipped[1].item == SHIELD and state.equipped[1].slot == 17, true)
env.NaowhForever_FishingGearOff()
Check("one the game did not put on stays noted for the next try", state.equipped[2].item, SHIELD)
state.counts[SWORD] = 1
Wear(17, 2129, SHIELD)
Wear(16, 2488, SWORD)
state.equipped = {}
a = Press()
Check("the pole goes on again", a.item, "item:6365")
Wear(17, nil, nil)
Wear(16, 6365, POLE)
Wear(16, 9999, NEW_SWORD)
Check("taking the pole off yourself ends it", Kept(), nil)
Fire(gearEvents, "PLAYER_REGEN_DISABLED")
Check("and nothing old goes back over what you put on", #state.equipped, 0)
S.Set("fishingGear", false)

local values, order = cards.fishingKey.rows[5].choice()
Check("the gear choice starts with the best pole", order[1], "")
Check("then your sets", values[order[2]], "Fishing")

state.worn[16] = 6365
S.Set("fishingDoubleClick", true)
Check("double-click listens to the mouse", keyEvents.events.GLOBAL_MOUSE_DOWN, true)
local clickOwner
state.foci = env.WorldFrame
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("one right-click binds nothing", next(state.overrides), nil)
state.now = state.now + 0.2
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
for owner, binds in pairs(state.overrides) do clickOwner = owner; Check("a double right-click binds the release", binds.BUTTON2.click, "NaowhForeverFishClick") end
a = Press(click)
Check("which casts", a.type, "spell")
click.scripts.PostClick(click)
Check("for that one release", state.overrides[clickOwner], nil)
state.timers[#state.timers]()
Check("and its hold timer is spent", state.overrides[clickOwner], nil)
state.now = state.now + 0.2
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
state.now = state.now + 0.2
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("a second double-click binds it again", state.overrides[clickOwner].BUTTON2.click, "NaowhForeverFishClick")
state.timers[#state.timers]()
Check("a release that never came lets go of the right button", state.overrides[clickOwner], nil)
state.now = state.now + 0.2
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
state.now = state.now + 1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("two slow clicks are not a double-click", next(state.overrides), nil)
state.tooltip = true
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("a double-click on something with a tooltip is left to the game", next(state.overrides), nil)
state.tooltip = false
state.foci = {}
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("clicks on a window are not cast", next(state.overrides), nil)
state.foci = env.WorldFrame
state.worn[16] = 2488
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
state.now = state.now + 0.1
Fire(keyEvents, "GLOBAL_MOUSE_DOWN", "RightButton")
Check("without a pole, double-click is left to the game", next(state.overrides), nil)

S.Set("fishingKey", false)
Check("turned off, the key listens to nothing", Count(keyEvents.events), 0)
a = Press()
Check("and does nothing", a.type, nil)

S.Set("fishingSounds", true)
Check("Louder Splash hears the channel", loudEvents.events.UNIT_SPELLCAST_CHANNEL_START, "player")
Fire(loudEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-7", 12051)
Check("not for other channels", next(state.temps), nil)
Fire(loudEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-8", 7620)
Check("game sounds to full", state.temps.Sound_SFXVolume, "1")
Check("music off", state.temps.Sound_MusicVolume, "0")
Check("ambience off", state.temps.Sound_AmbienceVolume, "0")
Check("master volume is left as you set it", state.temps.Sound_MasterVolume, nil)
Check("the saved volumes are untouched", state.cvars.Sound_MusicVolume, "0.4")
Fire(loudEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-8", 7620)
Check("the catch puts the sound back", next(state.temps), nil)
Check("and forgets it", account.fishingLoudTemps, nil)
state.cvars.Sound_SFXVolume = "1.0"
Fire(loudEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-9", 7620)
Check("a volume already full is left alone", state.temps.Sound_SFXVolume, nil)
Check("a /reload mid-cast leaves it noted", account.fishingLoudTemps ~= nil, true)
loudBoot.scripts.OnEvent(loudBoot, "PLAYER_LOGIN")
Check("and the next login puts it back", next(state.temps), nil)
Check("and forgets it", account.fishingLoudTemps, nil)

S.Set("fishingSounds", false)
state.timers = {}
local function Timers()
    local due = state.timers
    state.timers = {}
    for _, fn in ipairs(due) do fn() end
end
S.Set("fishingAutoLoot", true)
Check("Auto Loot While Fishing hears the channel and the loot window",
    lootEvents.events.UNIT_SPELLCAST_CHANNEL_START == "player" and lootEvents.events.LOOT_CLOSED == true, true)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-10", 12051)
Check("not for other channels", state.temps.autoLootDefault, nil)
Fire(lootEvents, "LOOT_OPENED", false, false)
Fire(lootEvents, "LOOT_CLOSED")
Check("nor for other loot", state.temps.autoLootDefault, nil)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-11", 7620)
Check("the cast turns auto loot on", state.temps.autoLootDefault, "1")
Check("your own setting is untouched", state.cvars.autoLootDefault, "0")
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-11", 7620)
Check("the bobber click leaves it on", state.temps.autoLootDefault, "1")
Fire(lootEvents, "LOOT_OPENED", true, false)
Timers()
Check("while the catch is looted", state.temps.autoLootDefault, "1")
Fire(lootEvents, "LOOT_CLOSED")
Check("and the looted catch turns it off", state.temps.autoLootDefault, nil)
Check("and forgets it", account.fishingAutoLootTemp, nil)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-12", 7620)
Fire(lootEvents, "LOOT_OPENED", true, false)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-12", 7620)
Timers()
Check("loot that comes before the channel ends still holds it", state.temps.autoLootDefault, "1")
Fire(lootEvents, "LOOT_CLOSED")
Check("until it closes", state.temps.autoLootDefault, nil)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-13", 7620)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-13", 7620)
Check("a fish that got away leaves it on a moment", state.temps.autoLootDefault, "1")
Timers()
Check("then turns it off", state.temps.autoLootDefault, nil)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-14", 7620)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-14", 7620)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-15", 7620)
Timers()
Check("an old wait does not end a new cast", state.temps.autoLootDefault, "1")
Check("a /reload mid-cast leaves it noted", account.fishingAutoLootTemp, true)
lootBoot.scripts.OnEvent(lootBoot, "PLAYER_LOGIN")
Check("and the next login puts it back", state.temps.autoLootDefault, nil)
Check("and forgets it", account.fishingAutoLootTemp, nil)
state.cvars.autoLootDefault = "1"
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-16", 7620)
Check("auto loot already on is left alone", state.temps.autoLootDefault == nil and account.fishingAutoLootTemp == nil,
    true)
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-16", 7620)
Fire(lootEvents, "LOOT_OPENED", true, false)
Fire(lootEvents, "LOOT_CLOSED")
Check("and stays on after the catch", state.cvars.autoLootDefault, "1")
state.cvars.autoLootDefault = "0"
Fire(lootEvents, "UNIT_SPELLCAST_CHANNEL_START", "player", "cast-17", 7620)
S.Set("fishingAutoLoot", false)
Check("turned off mid-cast, auto loot goes back", state.temps.autoLootDefault, nil)
Check("and it listens to nothing", Count(lootEvents.events), 0)

print(("PASS fishing: %d checks"):format(checks))
