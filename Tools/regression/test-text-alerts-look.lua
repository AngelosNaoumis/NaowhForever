-- Run with Lua 5.1 from the repository root: the QoL text alerts' look settings (Combat Alert,
-- Combat Timer, Stealth Reminder, Talent Points, Durability, Restock, Pet Tracker, Flight Point Reminder), loaded from
-- the real Shared files against stubs and shown through the HUD Editor. Each draws today's look
-- until a setting is touched: its font and size, outlined text, no background. Font, Font Size,
-- Outline and Background then apply at once; a background fits the frame to its words. Combat
-- Timer's old on/off background is saved as Card (its black panel) and None; Talent Points and
-- Durability can take the theme's accent colour. Each card shows the new rows.

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Width(text, size) return #text * size * 0.5 end

local function Fixture(saved)
    local state = { frames = {}, named = {}, movers = {}, legacyConfigReads = 0, legacyCurrencyReads = 0 }
    local NOTHING = function() end
    local Frame
    local METHODS = {
        SetScript = function(f, script, fn) f.scripts[script] = fn end,
        HookScript = NOTHING,
        RegisterEvent = function(f, event) f.events[event] = true end,
        RegisterUnitEvent = function(f, event) f.events[event] = true end,
        UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
        SetWidth = function(f, w) f.w = w end,
        SetHeight = function(f, h) f.h = h end,
        SetSize = function(f, w, h) f.w, f.h = w, h end,
        GetWidth = function(f) return rawget(f, "w") or 0 end,
        GetHeight = function(f) return rawget(f, "h") or 0 end,
        GetEffectiveScale = function() return 1 end,
        GetFrameLevel = function() return 1 end,
        SetPoint = function(f, a, rel, _, x) f.pt[a], f.rel[a] = x or 0, rel end,
        ClearAllPoints = function(f) f.pt, f.rel = {}, {} end,
        SetFont = function(f, path, size, outline) f.font, f.size, f.outline = path, size, outline end,
        SetShadowColor = function(f, _, _, _, a) f.shadow = a end,
        SetText = function(f, text) f.text = text end,
        GetStringWidth = function(f) return Width(rawget(f, "text") or "", rawget(f, "size") or 12) end,
        GetStringHeight = function(f) return rawget(f, "size") or 12 end,
        SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
        SetColorTexture = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        Show = function(f) f.shown = true end,
        Hide = function(f) f.shown = false end,
        SetShown = function(f, on) f.shown = on and true or false end,
        IsShown = function(f) return rawget(f, "shown") ~= false end,
        CreateTexture = function(f) return Frame(f) end,
        CreateFontString = function(f) return Frame(f) end,
        CreateAnimationGroup = function()
            local group = setmetatable({}, { __index = function() return NOTHING end })
            group.CreateAnimation = function() return setmetatable({}, { __index = function() return NOTHING end }) end
            return group
        end,
    }
    setmetatable(METHODS, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
    local META = { __index = METHODS }
    function Frame(parent, name)
        local f = setmetatable({ scripts = {}, events = {}, parent = parent, pt = {}, rel = {} }, META)
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end

    local T = { fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        accent = { r = 0, g = 0.5, b = 0.9 }, accentSoft = { r = 0.3, g = 0.7, b = 0.9 },
        line = { r = 0.2, g = 0.2, b = 0.2 }, panel = { r = 0.1, g = 0.1, b = 0.1 },
        bg = { r = 0.05, g = 0.05, b = 0.05 }, grey = { r = 0.2, g = 0.2, b = 0.2 } }
    local values, defaults, listeners = saved or {}, {}, {}
    local S = {
        DB = function() return values end,
        Get = function(k)
            local v = values[k]
            if v == nil then return defaults[k] end
            return v
        end,
        Raw = function(k) return values[k] end,
        Default = function(k) return defaults[k] end,
    }
    function S.Set(k, v)
        values[k] = v
        for _, fn in ipairs(listeners) do fn(k, v) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        THEME = T,
        Color = function(_, text) return text end,
        Font = function(parent, size, flags, color)
            local fs = Frame(parent)
            fs.flags, fs.size = flags, size
            local c = color or T.fg
            fs.r, fs.g, fs.b = c.r, c.g, c.b
            return fs
        end,
        Solid = function(parent, _, color, alpha)
            local t = Frame(parent)
            t.color, t.alpha = color, alpha
            return t
        end,
        ThemeTint = function(_, literal) return literal end,
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        OnePixel = function() return 1 end,
        Border = function(frame) return { _frame = Frame(frame), SetColor = NOTHING } end,
        AccentBorder = function() return { SetColor = NOTHING } end,
        Button = function(parent) return Frame(parent) end,
        UIFontPath = function() return "font" end,
        AccountSettings = function() return {} end,
        Print = NOTHING,
        TTSVoiceChoices = function() return {}, {} end,
        Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
        UI = {
            Keep = function(parent, key, make)
                local kept = rawget(parent, key)
                if not kept then kept = make(parent); parent[key] = kept end
                return kept
            end,
            AttachMover = function(frame, label, _, page, feature)
                local mover = Frame(frame)
                mover.shown = false
                state.movers[label] = { frame = frame, page = page, feature = feature }
                mover.label = label
                return mover
            end,
            SetMoverChoices = function(mover, choices) state.movers[mover.label].choices = choices end,
            ModuleSettings = function(_, given)
                for key, value in pairs(given) do defaults[key] = value end
                return S
            end,
            FontPath = function(name) return name and name ~= "" and "lsm:" .. name or "font" end,
            _PlayLSMSound = NOTHING, SoundPathFor = NOTHING,
        },
    }
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function(_, name, parent) return Frame(parent, name) end,
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
        UnitClass = function() return "Warrior", "WARRIOR" end,
        UnitAffectingCombat = function() return state.inCombat == true end,
        UnitIsDeadOrGhost = function() return false end,
        UnitOnTaxi = function() return false end,
        IsMounted = function() return false end,
        IsResting = function() return false end,
        IsInInstance = function() return false end,
        InCombatLockdown = function() return false end,
        GetTime = function() return 100 end,
        GetShapeshiftFormID = function() return nil end,
        INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_LAST_EQUIPPED = 19,
        GetInventoryItemDurability = function() return nil end,
        C_Timer = { After = NOTHING, NewTicker = function() return { Cancel = NOTHING } end },
        C_ClassTalents = { HasUnspentTalentPoints = function() return false end },
        Constants = { LegacyConsts = { LEGACY_TREE_PROFESSIONS_ID = 1187,
            LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225, LEGACY_REWARD_TRACK_FACTION_ID = 2802 } },
        C_MajorFactions = { GetCurrentRenownLevel = function(faction)
            assert(faction == 2802)
            return state.legacyRenown or 1
        end },
        C_Traits = {
            GetConfigIDByTreeID = function(tree)
                assert(tree == 1187, "read the shared balance from one Legacy tree")
                state.legacyConfigReads = state.legacyConfigReads + 1
                return state.legacyConfig
            end,
            GetTreeCurrencyInfo = function(config, tree, excludeStaged)
                assert(config == state.legacyConfig and tree == 1187 and excludeStaged == false,
                    "the Legacy balance includes staged spending")
                state.legacyCurrencyReads = state.legacyCurrencyReads + 1
                return state.legacyCurrencies
            end,
        },
        C_CurveUtil = { CreateCurve = function()
            return setmetatable({}, { __index = function() return NOTHING end })
        end },
        C_ClassColor = { GetClassColor = function()
            return { WrapTextInColorCode = function(_, name) return name end }
        end },
        LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Rogue", WARRIOR = "Warrior", HUNTER = "Hunter" },
        C_Item = { RequestLoadItemDataByID = NOTHING },
        C_SpellBook = { IsSpellKnown = function() return false end },
        Enum = { LuaCurveType = { Step = 1 }, UIMapType = { Zone = 3, Continent = 2 },
            FlightPathFaction = { Neutral = 0, Horde = 1, Alliance = 2 },
            FlightPathState = { Unreachable = 2 } },
        C_Map = { GetBestMapForUnit = function() return nil end, GetMapInfo = function() return nil end,
            GetPlayerMapPosition = function() return nil end, GetWorldPosFromMapPos = function() return nil end },
        C_TaxiMap = { GetTaxiNodesForMap = function() return {} end },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        GameTooltip = Frame(),
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    for _, path in ipairs({ "Core/Features.lua", "Core/Settings.lua", "Core/AlertStack.lua",
        "NaowhForever_QoL/Combat/CombatAlert.lua", "NaowhForever_QoL/Combat/CombatTimer.lua",
        "NaowhForever_QoL/Combat/StealthReminder.lua", "NaowhForever_QoL/Questing/TalentPoints.lua",
        "NaowhForever_QoL/Questing/LegacyPoints.lua",
        "NaowhForever_QoL/Loot/LootCard.lua", "NaowhForever_QoL/Loot/Durability.lua", "NaowhForever_QoL/Loot/Restock.lua",
        "NaowhForever_QoL/Combat/PetTracker.lua", "NaowhForever_QoL/Travel/FlightPoint.lua" }) do
        files[#files + 1] = path
    end
    Load(files, env)
    state.ns, state.S, state.T, state.values, state.St = ns, S, T, values, ns.Shared.Style
    function state.fire(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
        end
    end
    function state.rows(page, id)
        local card = ns.Shared.Settings.pages[page].cards[id]
        local keys = {}
        for _, row in ipairs(ns.Shared.Settings.Rows(card)) do
            if row.key then keys[row.key] = row end
        end
        return keys
    end
    return state
end

local ON = { combatAlert = true, combatTimer = true, stealthReminder = true, talentPoints = true, legacyPoints = true,
    durability = true, restock = true, petTracker = true, flightPoint = true }

local function Shown(saved)
    local values = {}
    for k, v in pairs(ON) do values[k] = v end
    for k, v in pairs(saved or {}) do values[k] = v end
    local s = Fixture(values)
    s.fire("PLAYER_LOGIN")
    s.ns.ShowUnlockMode()
    return s
end

-- name, prefix, frame, today's size, the frame's width and its height over that size, card.
local ELEMENTS = {
    { "Combat Alert", "combatAlert", function(s) return s.named.NaowhForeverCombatAlert end, 32, 300, 16,
      "QoL/Combat", "combatAlert" },
    { "Combat Timer", "combatTimer", function(s) return s.named.NaowhForeverCombatTimer end, 32, 32 * 7, 16,
      "QoL/Combat", "combatTimer" },
    { "Stealth Reminder", "stealth", function(s) return s.movers["Stealth Reminder"].frame end, 22, 300, 12,
      "QoL/Combat", "stealthReminder" },
    { "Talent Points", "talentPoints", function(s) return s.named.NaowhForeverTalentPoints end, 22, 300, 10,
      "QoL/XP", "talentPoints" },
    { "Unspent Legacy Points", "legacyPoints", function(s) return s.named.NaowhForeverLegacyPoints end, 22, 300, 10,
      "QoL/XP", "legacyPoints" },
    { "Durability", "durability", function(s) return s.named.NaowhForeverDurability end, 22, 300, 10,
      "QoL/Combat", "durability" },
    { "Pet Tracker", "pet", function(s) return s.named.NaowhForeverPetTracker end, 20, 220, 16,
      "QoL/Combat", "petTracker" },
    { "Flight Point Reminder", "flightPoint", function(s) return s.named.NaowhForeverFlightPoint end, 12, 300, 10,
      "QoL/Travel", "flightPoint" },
}

for _, e in ipairs(ELEMENTS) do
    local name, prefix, Get, size, width, room, page, id = unpack(e)
    local s = Shown()
    local f = Get(s)
    check(name .. ": today's look by default, the addon font outlined at its size, no background", f
        and f.shown and f.text.font == "font" and f.text.size == size and f.text.outline == "OUTLINE"
        and f.text.shadow == 0 and f.backdrop.mode == "none" and f.w == width and f.h == size + room)

    s.S.Set(prefix .. "Font", "Friz")
    s.S.Set(prefix .. "FontSize", size + 6)
    s.ns.ShowUnlockMode()
    check(name .. ": Font and Font Size apply at once", f.text.font == "lsm:Friz" and f.text.size == size + 6
        and f.h == size + 6 + room)

    s.S.Set(prefix .. "Outline", "")
    s.ns.ShowUnlockMode()
    check(name .. ": no outline, the shadow for no background", f.text.outline == ""
        and f.text.shadow == s.St.HUD_BARE_SHADOW_ALPHA)

    s.S.Set(prefix .. "Background", "card")
    s.ns.ShowUnlockMode()
    check(name .. ": Card puts the card behind it, the text with the card's shadow", f.backdrop.mode == "card"
        and f.backdrop.fill.shown ~= false and f.text.shadow == s.St.HUD_SHADOW_ALPHA)
    s.S.Set(prefix .. "Background", "soft")
    s.ns.ShowUnlockMode()
    check(name .. ": Soft fades in behind it", f.backdrop.mode == "soft" and f.backdrop.fill.shown == false)

    local rows = s.rows(page, id)
    check(name .. ": its card has Font, Font Size, Outline and Background", rows[prefix .. "Font"]
        and rows[prefix .. "FontSize"] and rows[prefix .. "Outline"] and rows[prefix .. "Background"])
end

-- A background fits the frame to its words; without one the frame keeps its width, so what is
-- anchored to it stays put.
do
    local s = Shown({ combatAlertBackground = "card", stealthBackground = "soft", talentPointsBackground = "card",
        durabilityBackground = "card", flightPointBackground = "card" })
    local pad = s.St.CARD_PAD
    local alert = s.named.NaowhForeverCombatAlert
    check("Combat Alert: the card fits its text", alert.w == Width("+Combat", 32) + 2 * pad)
    local stealth = s.movers["Stealth Reminder"].frame
    check("Stealth Reminder: the soft fade fits its text", stealth.w == Width("RESTEALTH", 22) + 2 * pad)
    local talent = s.named.NaowhForeverTalentPoints
    check("Talent Points: the card fits its text", talent.w == Width("2 Unspent Talent Points", 22) + 2 * pad)
    local dura = s.named.NaowhForeverDurability
    check("Durability: the card fits its text", dura.w == Width("Low Durability: 20%", 22) + 2 * pad)
    local flight = s.named.NaowhForeverFlightPoint
    check("Flight Point Reminder: the card fits its text", flight.w == Width("Learn the Ratchet flight point", 12) + 2 * pad)
end

do
    local s = Shown({ petBackground = "card" })
    local pet, pad = s.named.NaowhForeverPetTracker, s.St.CARD_PAD
    check("Pet Tracker with a card: the icon inside its edge, the card round icon and text", pet.icon.pt.LEFT == pad
        and pet.w == Width("Pet Missing", 20) + pet.icon.w + 8 + 2 * pad)
    s = Shown()
    pet = s.named.NaowhForeverPetTracker
    check("Pet Tracker by default: the icon at the frame's edge", pet.icon.pt.LEFT == 0)
end

-- Combat Timer: the old Show Background toggle becomes Card (the same black panel) or None.
do
    local s = Shown({ combatTimerBackground = true })
    local f = s.named.NaowhForeverCombatTimer
    check("Combat Timer: Show Background on is saved as Card", s.values.combatTimerBackground == "card")
    check("Combat Timer: its card is the black panel it always had, the timer's size",
        f.backdrop.mode == "card" and f.backdrop.fill.alpha == 0.8 and f.backdrop.fill.color.r == 0
        and f.backdrop.fill.color.g == 0 and f.backdrop.fill.color.b == 0 and f.w == 32 * 7)
    s = Shown({ combatTimerBackground = false })
    check("Combat Timer: Show Background off is saved as None", s.values.combatTimerBackground == "none"
        and s.named.NaowhForeverCombatTimer.backdrop.mode == "none")
    s = Shown()
    check("Combat Timer: an untouched profile stays untouched", s.values.combatTimerBackground == nil)
end

-- Restock: one size for the list, the title a step larger, as today at 16 and 22.
do
    local s = Shown()
    local r = s.named.NaowhForeverRestock
    check("Restock: today's sizes, outlined, the title in the accent", r.title.size == 22 and r.text.size == 16
        and r.title.outline == "OUTLINE" and r.text.outline == "OUTLINE" and r.backdrop.mode == "none"
        and r.title.r == s.T.accent.r and r.title.b == s.T.accent.b)
    s.S.Set("restockFontSize", 20)
    s.S.Set("restockFont", "Friz")
    s.S.Set("restockBackground", "card")
    s.ns.ShowUnlockMode()
    check("Restock: Font Size sets the list, the title follows", r.text.size == 20 and r.title.size == 26
        and r.text.font == "lsm:Friz" and r.backdrop.mode == "card")
    local rows = s.rows("QoL/Loot & Items", "restock")
    check("Restock: its card has the look rows", rows.restockFont and rows.restockFontSize
        and rows.restockOutline and rows.restockBackground)
end

-- Apply Theme where the colour was fixed.
do
    local s = Shown()
    s.S.Set("durabilityBelow", 25)
    local talent = s.named.NaowhForeverTalentPoints
    check("Talent Points: gold by default", talent.text.r == 1 and talent.text.g == 0.82 and talent.text.b == 0)
    s.S.Set("talentPointsTheme", true)
    s.ns.ShowUnlockMode()
    check("Talent Points: Apply Theme shows it in the accent", talent.text.r == s.T.accent.r
        and talent.text.g == s.T.accent.g and talent.text.b == s.T.accent.b)

    local flight = s.named.NaowhForeverFlightPoint
    check("Flight Point Reminder: the accent by default", flight.text.r == s.T.accent.r
        and flight.text.g == s.T.accent.g and flight.text.b == s.T.accent.b)
    local flightRows = s.rows("QoL/Travel", "flightPoint")
    local swatch = s.S.Default("flightPointColor")
    check("Flight Point Reminder: Custom Color off hides Text Color, and the swatch starts on the theme accent",
        flightRows.flightPointCustom and s.ns.Shared.Settings.Off(flightRows.flightPointColor)
        and swatch.r == s.T.accent.r and swatch.g == s.T.accent.g and swatch.b == s.T.accent.b)
    s.S.Set("flightPointColor", { r = 0.2, g = 0.4, b = 0.6 })
    s.S.Set("flightPointCustom", true)
    check("Flight Point Reminder: Custom Color paints the saved color", flight.text.r == 0.2
        and flight.text.g == 0.4 and flight.text.b == 0.6
        and not s.ns.Shared.Settings.Off(flightRows.flightPointColor))

    -- 20% with Warn Below 25 sits halfway from red to the top colour.
    local dura = s.named.NaowhForeverDurability
    check("Durability: pink shading to red by default", dura.text.r == 1 and math.abs(dura.text.g - 0.205) < 1e-9
        and math.abs(dura.text.b - 0.355) < 1e-9)
    s.S.Set("durabilityTheme", true)
    s.ns.ShowUnlockMode()
    check("Durability: Apply Theme shades from the accent instead", math.abs(dura.text.r - 0.5) < 1e-9
        and math.abs(dura.text.g - 0.25) < 1e-9 and math.abs(dura.text.b - 0.45) < 1e-9)
end

-- The Alerts group's Settings opens a card.
do
    local s = Shown()
    local mover = s.movers.Alerts
    check("Alerts group: HUD Editor > Settings opens Durability", mover.page == "QoL/Combat"
        and mover.feature == "QoL/Combat:durability"
        and s.ns.Shared.Settings.pages["QoL/Combat"].cards.durability ~= nil)
    local listed = {}
    for _, choice in ipairs(mover.choices) do
        local page, id = choice.feature:match("^(.+):([^:]+)$")
        listed[#listed + 1] = choice.page == page and s.ns.Shared.Settings.pages[page].cards[id] ~= nil and choice.name
    end
    check("its Settings lists each loaded alert, each opening a card that exists",
        table.concat(listed, ",") == "Talent Points,Unspent Legacy Points,Durability,Restock Reminder,Pet Tracker,Flight Point Reminder")
end

do
    local s = Fixture()
    s.ns.Apply()
    s.fire("PLAYER_LOGIN")
    check("Legacy Points: off by default without a frame or trait reads", s.S.Default("legacyPoints") == false
        and s.named.NaowhForeverLegacyPoints == nil and s.legacyConfigReads == 0)
    local listening = false
    for _, f in ipairs(s.frames) do listening = listening or f.events.TRAIT_CONFIG_CREATED end
    check("Legacy Points: no trait events registered while off", not listening)
    s.S.Set("legacyPoints", true)
    local alert = s.named.NaowhForeverLegacyPoints
    check("Legacy Points: enabling before Legacy is unlocked stays hidden", alert and not alert:IsShown()
        and s.legacyCurrencyReads == 0)
    s.legacyConfig = 101
    s.legacyCurrencies = { { traitCurrencyID = 1, quantity = 99 }, { traitCurrencyID = 4225, quantity = 3 } }
    s.legacyRenown = 0
    local lockedReads = s.legacyConfigReads
    s.fire("TRAIT_CONFIG_LIST_UPDATED")
    check("Legacy Points: a config alone does not bypass the Legacy unlock", not alert:IsShown()
        and s.legacyConfigReads == lockedReads)
    s.legacyRenown = 1
    s.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    check("Legacy Points: unlocking Legacy refreshes it", alert:IsShown()
        and alert.text.text == "3 Unspent Legacy Points")
    local reads = s.legacyCurrencyReads
    s.fire("TRAIT_CONFIG_CREATED")
    check("Legacy Points: config creation shows the shared balance once", alert:IsShown()
        and alert.text.text == "3 Unspent Legacy Points" and s.legacyCurrencyReads == reads + 1)
    s.legacyCurrencies[2].quantity = 1
    s.fire("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    check("Legacy Points: a point spent updates the singular text", alert.text.text == "1 Unspent Legacy Point")
    s.legacyCurrencies[2].quantity = 0
    s.fire("TRAIT_CONFIG_UPDATED")
    check("Legacy Points: spending the last point hides it", not alert:IsShown())
    s.legacyCurrencies[2].quantity = 4
    s.fire("CURRENCY_DISPLAY_UPDATE")
    check("Legacy Points: earning or refunding points shows it again", alert.text.text == "4 Unspent Legacy Points"
        and alert:IsShown())
    s.inCombat = true
    reads = s.legacyConfigReads
    s.fire("PLAYER_REGEN_DISABLED")
    s.fire("TRAIT_TREE_CURRENCY_INFO_UPDATED")
    check("Legacy Points: combat hides it and stops trait reads", not alert:IsShown()
        and s.legacyConfigReads == reads)
    s.legacyCurrencies[2].quantity = 2
    s.inCombat = false
    s.fire("PLAYER_REGEN_ENABLED")
    check("Legacy Points: leaving combat refreshes the balance", alert:IsShown()
        and alert.text.text == "2 Unspent Legacy Points")
    s.S.Set("legacyPointsTheme", true)
    check("Legacy Points: its theme setting applies independently", alert.text.r == s.T.accent.r
        and alert.text.g == s.T.accent.g and s.S.Get("talentPointsTheme") == false)
    s.legacyCurrencies = nil
    s.fire("TRAIT_CONFIG_UPDATED")
    check("Legacy Points: temporarily unavailable currency data stays hidden", not alert:IsShown())
    s.legacyCurrencies = { { traitCurrencyID = 1, quantity = 99 } }
    s.fire("TRAIT_CONFIG_UPDATED")
    check("Legacy Points: other trait currencies are ignored", not alert:IsShown())
    s.ns.ShowUnlockMode()
    check("Legacy Points: HUD Editor previews it without an available balance", alert:IsShown()
        and alert.text.text == "2 Unspent Legacy Points")
    s.ns.HideUnlockMode()
    check("Legacy Points: leaving HUD Editor restores the real state", not alert:IsShown())
    s.S.Set("legacyPoints", false)
    reads = s.legacyConfigReads
    s.fire("TRAIT_CONFIG_CREATED")
    s.fire("CURRENCY_DISPLAY_UPDATE")
    check("Legacy Points: disabling unregisters its events and stops reads", not alert:IsShown()
        and s.legacyConfigReads == reads)
    for _, f in ipairs(s.frames) do
        check("Legacy Points: no polling is installed", f.scripts.OnUpdate == nil)
    end
    s.S.Set("legacyPoints", true)
    s.S.Set("enabled", false)
    reads = s.legacyConfigReads
    s.fire("PLAYER_ENTERING_WORLD")
    check("Legacy Points: disabling QoL also stops reads", not alert:IsShown() and s.legacyConfigReads == reads)
end

do
    local s = Fixture({ legacyPoints = true })
    s.legacyConfig = 101
    s.legacyCurrencies = { { traitCurrencyID = 4225, quantity = 5 } }
    s.ns.Apply()
    check("Legacy Points: a saved enabled setting works on login or reload", s.named.NaowhForeverLegacyPoints:IsShown()
        and s.named.NaowhForeverLegacyPoints.text.text == "5 Unspent Legacy Points")
    check("Legacy Points: its toggle does not require the normal talent reminder", s.S.Get("talentPoints") == false)
end

print(checks .. " text alert look checks passed")
