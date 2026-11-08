-- Run with Lua 5.1 from the repository root: the Training Planner's Demon Books (Data/TrainingGrimoires.lua,
-- Grimoires.lua, UI/DemonTrainer.lua) against stubs: the data's shape, off and free by default, what a
-- summoned demon's spellbook records, and the marks and tooltip lines at the demon trainer.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local PET_BANK = 1
local SECRET = {}
local WHITE = { r = 1, g = 1, b = 1 }

-- A warlock (or `class`) of `level`, with `settings` saved, whose pet is `pet` ({ family, known }), at a
-- merchant selling `merchant` (item IDs by index). Every file loads as the game would; Login fires
-- PLAYER_LOGIN on the boot frames.
local function Fixture(o)
    local state = { level = o.level or 20, guid = "Player-1-Me", pet = o.pet, gamepad = false,
        merchant = o.merchant or {}, settings = o.settings or {} }
    local frames, hooks, postCalls, listeners = {}, {}, {}, {}
    local changes = 0
    local account = {}
    local S = {}
    function S.Get(key)
        local v = state.settings[key]
        if v == nil then return S.defaults[key] end
        return v
    end
    function S.Set(key, v)
        state.settings[key] = v
        for _, fn in ipairs(listeners) do fn(key) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        THEME = { accent = WHITE, muted = WHITE, fg = WHITE },
        AccountSettings = function() return account end,
        GamepadStandDown = function() return state.gamepad end,
        Apply = function() end,
        UI = {
            ModuleSettings = function(_, defaults) S.defaults = defaults; return S end,
            RefreshPage = function() changes = changes + 1 end,
        },
    }
    local items = {}
    for i = 1, 10 do items[i] = { ItemButton = { name = "button " .. i } } end
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function()
            local f = { scripts = {}, events = {} }
            function f:SetScript(k, fn) self.scripts[k] = fn end
            function f:RegisterEvent(e) self.events[e] = true end
            function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
            function f:UnregisterAllEvents() self.events = {} end
            frames[#frames + 1] = f
            return f
        end,
        hooksecurefunc = function(target, name, fn)
            if type(target) == "string" then
                hooks[target] = name
            else
                local old = target[name]
                target[name] = function(...) old(...); fn(...) end
            end
        end,
        TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind, fn } end },
        Enum = { SpellBookSpellBank = { Player = 0, Pet = PET_BANK }, TooltipDataType = { Item = 0 } },
        C_SpellBook = { IsSpellKnown = function(spell, bank)
            return bank == PET_BANK and state.pet ~= nil and state.pet.known[spell] == true
        end },
        UnitCreatureFamily = function(unit)
            if unit ~= "pet" or not state.pet then return nil end
            return "Demon", state.pet.family
        end,
        issecretvalue = function(v) return v == SECRET end,
        UnitClass = function() return "Warlock", o.class or "WARLOCK", 9 end,
        UnitLevel = function() return state.level end,
        UnitGUID = function() return state.guid end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        MERCHANT_ITEMS_PER_PAGE = 10,
        MerchantFrame = { page = 1, selectedTab = 1, IsShown = function() return state.open ~= false end },
        GetMerchantItemID = function(i) return state.merchant[i] end,
    }, { __index = _G })
    for i = 1, 10 do env["MerchantItem" .. i] = items[i] end
    env._G = env
    Load({ "Core/Features.lua", "Shared/Shared.lua", "Shared/Style.lua" }, env)
    local badges = {}
    ns.Shared.Parts.ItemBadge = function(set, corner, atlas, color)
        local badge = { set = set, corner = corner, atlas = atlas, color = color, shown = false }
        function badge.SetShown(self, v) self.shown = v and true or false end
        badges[#badges + 1] = badge
        return badge
    end
    local dir = "NaowhForever_Training/"
    Load({ dir .. "Training.lua", dir .. "Constants.lua", dir .. "Data/TrainingGrimoires.lua", dir .. "Grimoires.lua",
        dir .. "UI/DemonTrainer.lua" }, env)
    local Training = ns.Training
    Training.OnChange(function() changes = changes + 1 end)
    local t = { ns = ns, Training = Training, G = Training.Grimoires, state = state, account = account, hooks = hooks,
        postCalls = postCalls, items = items, merchantFrame = env.MerchantFrame, S = S }
    function t.Login()
        for _, f in ipairs(frames) do
            if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
        end
    end
    function t.Fire(event, unit)
        for _, f in ipairs(frames) do
            if f.events[event] then f.scripts.OnEvent(f, event, unit) end
        end
    end
    function t.Listening()
        local out = {}
        for _, f in ipairs(frames) do
            for e in pairs(f.events) do out[#out + 1] = e end
        end
        table.sort(out)
        return table.concat(out, " ")
    end
    function t.Changes() return changes end
    function t.Book(item) return (t.G.Book(item)) end
    function t.State(item) return t.G.State(t.Book(item), state.level) end
    function t.Shown(i)
        for _, badge in ipairs(badges) do
            if badge.set == items[i].ItemButton and badge.shown then return badge.atlas end
        end
    end
    function t.Badges() return #badges end
    function t.Paint() hooks.MerchantFrame_Update() end
    function t.Tip(id)
        local lines = {}
        local tooltip = { AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text, r, g, b } end }
        for _, call in ipairs(postCalls) do call[2](tooltip, { id = id }) end
        return lines[1] and lines[1][1], lines[1]
    end
    return t
end

-------------------------------------------------------------------------------
--  The data
-------------------------------------------------------------------------------
do
    local ns = {}
    local env = setmetatable({ NaowhForever = ns }, { __index = _G })
    env._G = env
    Load({ "NaowhForever_Training/Data/TrainingGrimoires.lua" }, env)
    local english = Read("Core/Locales/enUS.lua")
    local items, families, books, taught = {}, {}, 0, {}
    for _, demon in ipairs(ns.TrainingGrimoires) do
        for _, book in ipairs(demon.books) do taught[book[2]] = true end
    end
    for _, demon in ipairs(ns.TrainingGrimoires) do
        check("demon name is in enUS: " .. demon.name, english:find('L["' .. demon.name .. '"]', 1, true))
        check(demon.name .. " has its families", #demon.families > 0)
        for _, family in ipairs(demon.families) do
            check("family " .. family .. " is one demon's", not families[family])
            families[family] = true
        end
        local spells, last = {}, 0
        for _, book in ipairs(demon.books) do
            books = books + 1
            local level, spell, cost = book[1], book[2], book[3]
            check(("%s book %d: a level from 1 to 60"):format(demon.name, spell), level >= 1 and level <= 60)
            check(("%s book %d: a price"):format(demon.name, spell), cost > 0)
            check(demon.name .. "'s books are in level order", level >= last)
            check(("item %d is listed once"):format(book.item), not items[book.item])
            check(("%s book %d: the rank before is an earlier book or none of them"):format(demon.name, spell),
                book.needs == nil or spells[book.needs] or not taught[book.needs])
            items[book.item], spells[spell], last = true, true, level
        end
    end
    check("every demon with books is listed: Imp, Voidwalker, Succubus or Incubus, Felhunter",
        #ns.TrainingGrimoires == 4 and books == 59)
end

-------------------------------------------------------------------------------
--  Off and free by default
-------------------------------------------------------------------------------
do
    local t = Fixture({})
    t.Login()
    check("off by default", t.S.Get("demonBooks") == false and not t.G.On())
    check("off: nothing listens", t.Listening() == "")
    check("off: the merchant and tooltips are not hooked", t.hooks.MerchantFrame_Update == nil and #t.postCalls == 0)
    t.Training.Changed()
    check("off: a planner change paints nothing", t.Badges() == 0)

    t = Fixture({ class = "MAGE", settings = { demonBooks = true } })
    t.Login()
    check("on for a mage: nothing listens or hooks", t.Listening() == "" and t.hooks.MerchantFrame_Update == nil)
end

-------------------------------------------------------------------------------
--  What a summoned demon records
-------------------------------------------------------------------------------
local FIREBOLT_1, FIREBOLT_3, BLOOD_PACT_1, LASH_1 = 3110, 7800, 6307, 7814
local BOOK_FIREBOLT_2, BOOK_FIREBOLT_3, BOOK_FIREBOLT_4 = 16302, 16316, 16317
local BOOK_BLOOD_PACT_2, BOOK_SACRIFICE_1, BOOK_LASH_2 = 16322, 16351, 16368
local BOOK_FIREBOLT_7 = 16320
local IMP, SUCCUBUS, INCUBUS = 23, 17, 302
local NOT_A_BOOK = 4565

do
    local t = Fixture({ settings = { demonBooks = true } })
    t.Login()
    check("on: it listens for the pet and its spellbook",
        t.Listening() == "PET_BAR_UPDATE SPELLS_CHANGED UNIT_PET" and t.hooks.MerchantFrame_Update ~= nil
            and #t.postCalls == 1)
    local imp = t.G.Demons()[1]
    check("a demon never summoned is not seen", not t.G.Seen(imp))
    check("its books you are old enough for read unknown", t.State(BOOK_FIREBOLT_2) == "unknown")
    check("and the rest later", t.State(BOOK_FIREBOLT_7) == "later")

    t.state.pet = { family = IMP, known = {} }
    t.Fire("UNIT_PET", "player")
    check("a pet spellbook that has none of the demon's spells yet records nothing", not t.G.Seen(imp))

    t.state.pet = { family = SECRET, known = { [FIREBOLT_1] = true } }
    t.Fire("SPELLS_CHANGED")
    check("a secret family records nothing", not t.G.Seen(imp))

    local before = t.Changes()
    t.state.pet = { family = IMP, known = { [FIREBOLT_1] = true, [FIREBOLT_3] = true, [BLOOD_PACT_1] = true } }
    t.Fire("SPELLS_CHANGED")
    check("summoning the Imp records what it knows", t.G.Seen(imp) and t.Changes() > before)
    check("its rank 3 book is learned", t.State(BOOK_FIREBOLT_3) == "learned")
    check("a later rank known counts the rank before as learned", t.State(BOOK_FIREBOLT_2) == "learned")
    check("a book you are old enough for and it lacks is ready", t.State(BOOK_BLOOD_PACT_2) == "now")
    check("one above your level is later", t.State(BOOK_FIREBOLT_4) == "later")
    t.state.level = 30
    check("until you reach it", t.State(BOOK_FIREBOLT_4) == "now")
    t.state.level = 20

    before = t.Changes()
    t.Fire("PET_BAR_UPDATE")
    check("the same spells again change nothing", t.Changes() == before)

    t.state.pet = { family = INCUBUS, known = { [LASH_1] = true } }
    t.Fire("UNIT_PET", "player")
    local succubus = select(2, t.G.Book(BOOK_LASH_2))
    check("the Incubus learns from the Succubus's books", t.G.Seen(succubus) and succubus.families[1] == SUCCUBUS)
    check("and the Imp's are still remembered while it is away", t.State(BOOK_FIREBOLT_2) == "learned")

    t.state.guid = "Player-1-Alt"
    check("each character keeps its own", not t.G.Seen(imp) and t.State(BOOK_FIREBOLT_2) == "unknown")
    t.state.guid = "Player-1-Me"

    -- At the demon trainer.
    t.state.merchant = { BOOK_FIREBOLT_2, BOOK_FIREBOLT_4, BOOK_BLOOD_PACT_2, NOT_A_BOOK, BOOK_SACRIFICE_1 }
    t.Paint()
    local St = t.ns.Shared.Style
    check("a learned book is ticked", t.Shown(1) == "common-icon-checkmark")
    check("one above your level gets the clock", t.Shown(2) == St.CLOCK_ATLAS)
    check("one you can learn now gets the green arrow", t.Shown(3) == St.UPGRADE_ATLAS)
    check("anything else gets nothing", t.Shown(4) == nil)
    check("nor does a book for a demon never summoned", t.Shown(5) == nil)
    t.merchantFrame.selectedTab = 2
    t.Paint()
    check("the buyback tab shows no marks", t.Shown(1) == nil and t.Shown(3) == nil)
    t.merchantFrame.selectedTab = 1
    t.merchantFrame.page = 2
    t.state.merchant = { [11] = BOOK_BLOOD_PACT_2 }
    t.Paint()
    check("page two marks its own items", t.Shown(1) == St.UPGRADE_ATLAS and t.Shown(2) == nil)
    t.merchantFrame.page = 1
    t.state.merchant = { BOOK_FIREBOLT_2 }
    t.state.open = false
    t.Training.Changed()
    check("a planner change with the merchant closed shows no marks", t.Shown(1) == nil)
    t.state.open = true
    t.Paint()

    local text, line = t.Tip(BOOK_FIREBOLT_2)
    check("a learned book's tooltip says so, in green", text == "Your Imp knows this already" and line[2] == St.HAVE_RGB.r)
    check("one above your level names the level", t.Tip(BOOK_FIREBOLT_4) == "Your Imp can learn this at level 28")
    check("one you can learn now says so", t.Tip(BOOK_BLOOD_PACT_2) == "Your Imp can learn this now")
    check("a demon never summoned asks for it", t.Tip(BOOK_SACRIFICE_1) == "Summon your Voidwalker once to check")
    check("other items get no line", t.Tip(NOT_A_BOOK) == nil and t.Tip(SECRET) == nil)

    t.state.gamepad = true
    t.ns.Apply()
    check("under the gamepad style the marks stand down", t.Shown(1) == nil)
    check("and the tooltip line stays", t.Tip(BOOK_FIREBOLT_2) ~= nil)
    t.state.gamepad = false
    t.ns.Apply()
    check("and come back after it", t.Shown(1) == "common-icon-checkmark")

    t.S.Set("demonBooks", false)
    check("off again: nothing listens", t.Listening() == "")
    check("the marks go", t.Shown(1) == nil)
    check("and so does the tooltip line", t.Tip(BOOK_FIREBOLT_2) == nil)
end

print(("test-training-grimoires: %d checks passed"):format(checks))
