-- Run with Lua 5.1 from the repository root: Trade Enchants (TradeEnchants.lua, UI/TradeEnchants.lua).
-- While trading, the item in the Will not be traded slot gets a panel of the learned enchants that go
-- on it, by the game's own item class, subclass and inventory type masks (Data/EnchantSlots.lua). Each
-- Enchant button is a secure click on the trade window's slot: its PreClick starts the enchant
-- (CraftRecipe) and the click puts it on the item. Enchants the trade partner linked in a whisper or
-- party chat come first. Off, it listens to nothing and builds nothing; the panel holds secure
-- buttons, so it closes when combat starts and never shows in combat.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Noop() end
local SECRET = {}
local ENCHANTING = 333
local SLOT = 7
local PARTNER = "Player-1-PARTNER"

local registry, timers, frames = {}, {}, {}
local methods = {}
for _, name in ipairs({ "SetSize", "SetFrameStrata", "EnableMouse", "EnableMouseWheel", "SetClampedToScreen",
    "SetAllPoints", "SetJustifyH", "SetWordWrap", "SetTexCoord", "SetTexture", "SetAlpha", "RegisterForClicks" }) do
    methods[name] = Noop
end
local widgetMeta = { __index = methods }

local function Widget(parent, template)
    local w = setmetatable({ shown = true, scripts = {}, hooks = {}, attributes = {}, points = {},
        enabled = true, parent = parent, template = template }, widgetMeta)
    frames[#frames + 1] = w
    return w
end

function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.GetScript(self, name) return self.scripts[name] end
function methods.HookScript(self, name, fn) self.hooks[name] = fn end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetAttribute(self, key, value) self.attributes[key] = value end
function methods.GetAttribute(self, key) return self.attributes[key] end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetTextColor(self, r, g, b) self.color = { r = r, g = g, b = b } end
function methods.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
function methods.ClearAllPoints(self) self.points = {} end
function methods.SetHeight(self, h) self.height = h end
function methods.CreateTexture(self) return Widget(self) end
function methods.CreateFontString(self) return Widget(self) end
function methods.RegisterEvent(self, event)
    registry[event] = registry[event] or {}
    registry[event][self] = true
end
function methods.UnregisterEvent(self, event)
    if registry[event] then registry[event][self] = nil end
end
function methods.UnregisterAllEvents(self)
    for _, set in pairs(registry) do set[self] = nil end
end

local function Listening(event)
    return registry[event] ~= nil and next(registry[event]) ~= nil
end

local function Fire(event, ...)
    local set = registry[event]
    if not set then return end
    for frame in pairs(set) do frame.scripts.OnEvent(frame, event, ...) end
end

local function Flush()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

local function hooksecurefunc(tbl, name, fn)
    local orig = tbl[name]
    tbl[name] = function(...)
        local a, b, c = orig(...)
        fn(...)
        return a, b, c
    end
end

local settings = { enabled = true, tradeEnchants = false }
local color = { r = 1, g = 1, b = 1 }
local muted = { r = 0.5, g = 0.5, b = 0.5 }
local accent = { r = 0, g = 0.57, b = 0.93 }
local own, profession, known = true, ENCHANTING, true
local craftable = {}

local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = { fg = color, muted = muted, accent = accent, bg = color, line = color, panel = color },
    Shared = { Style = dofile("Tools/regression/shared_style.lua") },
    Apply = Noop,
    GamepadStandDown = function() return false end,
    Font = function(parent) return Widget(parent) end,
    Solid = function(parent) return Widget(parent) end,
    Border = function(parent) return Widget(parent) end,
    Tooltip = Noop,
    Button = function(parent, text, _, _, onClick, template)
        local b = Widget(parent, template)
        b.label = text
        if not template then b.scripts.OnClick = onClick end
        return b
    end,
    Professions = {
        Settings = {
            Get = function(key) return settings[key] end,
            Set = function(key, value) settings[key] = value end,
        },
        Recipes = {
            Own = function() return own end,
            Profession = function() return { id = profession } end,
            Craftable = function(info) return craftable[info.recipeID] or 0 end,
        },
        Disenchant = { ENCHANTING = ENCHANTING, Known = function() return known end },
    },
}

local ITEMS = {
    bracer = { 4, 2, 9 }, plainBracer = { 4, 0, 9 }, robe = { 4, 1, 20 }, sword2h = { 2, 8, 17 },
    dagger = { 2, 15, 13 }, shield = { 4, 6, 14 }, offhand = { 4, 0, 23 }, cloak = { 4, 1, 16 },
}
local recipes = {}
local recipeIDs = {}
local crafted = {}
local tradeLink
local inCombat, targeting, modified = false, false, false

local function Learn(id, name, trivial, learned)
    recipeIDs[#recipeIDs + 1] = id
    recipes[id] = { recipeID = id, name = name, icon = id, maxTrivialLevel = trivial, learned = learned ~= false }
end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent, template) return Widget(parent, template) end,
    CreateColor = function() return {} end,
    hooksecurefunc = hooksecurefunc,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function(v) return v == SECRET end,
    InCombatLockdown = function() return inCombat end,
    SpellIsTargeting = function() return targeting end,
    IsModifiedClick = function() return modified end,
    UnitGUID = function(unit) return unit == "NPC" and PARTNER or nil end,
    GetTradeTargetItemLink = function(slot) return slot == SLOT and tradeLink or nil end,
    TRADE_ENCHANT_SLOT = SLOT,
    UIParent = Widget(),
    TradeFrame = Widget(),
    TradeRecipientItem7ItemButton = Widget(),
    ProfessionsFrame = Widget(),
    GameTooltip = Widget(),
    GameTooltip_Hide = Noop,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = {
        GetItemInfoInstant = function(link)
            local item = ITEMS[link]
            if item then return 1, nil, nil, nil, nil, item[1], item[2] end
        end,
        GetItemInventoryTypeByID = function(link) return ITEMS[link] and ITEMS[link][3] end,
    },
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() return recipeIDs end,
        GetRecipeInfo = function(id) return recipes[id] end,
        CraftRecipe = function(id) crafted[#crafted + 1] = id end,
    },
}, { __index = _G })
env._G = env

Load({
    "Core/Features.lua",
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/EnchantSlots.lua",
    "NaowhForever_Professions/TradeEnchants.lua",
    "NaowhForever_Professions/View/Style.lua",
    "NaowhForever_Professions/View/Widgets.lua",
    "NaowhForever_Professions/View/Popup.lua",
    "NaowhForever_Professions/UI/TradeEnchants.lua",
}, env)

local P = ns.Professions
local TE = P.TradeEnchants
local S = P.Settings

local function Ids(list)
    local out = {}
    for i, info in ipairs(list) do out[i] = info.recipeID end
    return table.concat(out, ",")
end

local function Fitting(link)
    local set = {}
    for _, info in ipairs(TE.List(link)) do set[info.recipeID] = true end
    return set
end

Learn(7418, "Enchant Bracer - Minor Health", 40)
Learn(13642, "Enchant Bracer - Spirit", 205)
Learn(7428, "Enchant Bracer - Minor Deflect", 100, false)
Learn(7420, "Enchant Chest - Minor Health", 35)
Learn(7745, "Enchant 2H Weapon - Minor Impact", 140)
Learn(7788, "Enchant Weapon - Minor Striking", 130)
Learn(13378, "Enchant Shield - Minor Stamina", 145)
Learn(13464, "Enchant Shield - Lesser Protection", 155)
Learn(1219577, "Enchant Off-Hand - Superior Intellect", 300)
Learn(7771, "Enchant Cloak - Minor Protection", 110)
Learn(13421, "Enchant Cloak - Lesser Protection", 155)
Learn(7421, "Runed Copper Rod", 5)

local fit = Fitting("bracer")
check("a leather bracer takes both learned bracer enchants", fit[7418] and fit[13642])
check("but not one not yet learned", not fit[7428])
check("nor a chest, cloak or weapon enchant", not (fit[7420] or fit[7771] or fit[7788]))
check("and no recipe that makes an item", not fit[7421])
fit = Fitting("plainBracer")
check("a bracer of no armor type takes only the enchant whose subclass mask has it", fit[7418] and not fit[13642])
fit = Fitting("robe")
check("a robe takes a chest enchant", fit[7420] and not fit[7418])
fit = Fitting("sword2h")
check("a two-handed sword takes 2H and weapon enchants", fit[7745] and fit[7788])
fit = Fitting("dagger")
check("a dagger takes a weapon enchant but not a 2H one", fit[7788] and not fit[7745])
fit = Fitting("shield")
check("a shield takes shield enchants by subclass and by slot", fit[13378] and fit[13464])
check("but not an off-hand enchant", not fit[1219577])
fit = Fitting("offhand")
check("a held off-hand takes the off-hand enchant only", fit[1219577] and not fit[13378] and not fit[13464])
fit = Fitting("cloak")
check("a cloak takes cloak enchants of any subclass mask", fit[7771] and fit[13421])
check("an item the game cannot place fits nothing", #TE.List("unknown") == 0)
check("the best enchants come first", Ids(TE.List("bracer")) == "13642,7418")

local frameCount = #frames
check("Trade Enchants is off by default", settings.tradeEnchants == ns.FEATURES.professions.tradeEnchants
    and ns.FEATURES.professions.tradeEnchants == false)
ns.Apply()
check("off, it listens to no trade or chat event", not Listening("TRADE_SHOW") and not Listening("CHAT_MSG_WHISPER"))
check("and builds nothing", #frames == frameCount)

S.Set("tradeEnchants", true)
check("on, it listens for trades", Listening("TRADE_SHOW") and Listening("TRADE_CLOSED")
    and Listening("TRADE_TARGET_ITEM_CHANGED"))
check("and for enchants asked for in whispers and party chat", Listening("CHAT_MSG_WHISPER")
    and Listening("CHAT_MSG_PARTY") and Listening("CHAT_MSG_INSTANCE_CHAT"))
check("but not for bags, crafts or combat outside a trade", not Listening("BAG_UPDATE_DELAYED")
    and not Listening("TRADE_SKILL_LIST_UPDATE") and not Listening("PLAYER_REGEN_DISABLED"))

local LINK = "|cffffd000|Henchant:%d|h[Enchanting: %s]|h|r"
local function Say(event, text, guid)
    Fire(event, text, "Someone", "", "", "Someone", "", 0, 0, "", 0, 1, guid)
end
Say("CHAT_MSG_WHISPER", "Could you craft 1x " .. LINK:format(7418, "Enchant Bracer - Minor Health") .. " for me?", PARTNER)
check("an enchant linked in a whisper is remembered for its sender", TE.Asked(PARTNER, 7418))
check("and for nobody else", not TE.Asked("Player-1-OTHER", 7418))
Say("CHAT_MSG_PARTY", LINK:format(7421, "Runed Copper Rod"), PARTNER)
check("a linked recipe that enchants nothing is not", not TE.Asked(PARTNER, 7421))
Say("CHAT_MSG_WHISPER", SECRET, PARTNER)
Say("CHAT_MSG_WHISPER", LINK:format(7788, "Enchant Weapon - Minor Striking"), SECRET)
check("a secret line or sender is not read", not TE.Asked(PARTNER, 7788))
check("a request comes first in the list", Ids(TE.List("bracer", PARTNER)) == "7418,13642")

local function FindPanel()
    for _, f in ipairs(frames) do
        if rawget(f, "title") and rawget(f, "rows") then return f end
    end
end

Fire("TRADE_SHOW")
check("a trade listens for profession, bag and combat changes", Listening("TRADE_SKILL_LIST_UPDATE")
    and Listening("BAG_UPDATE_DELAYED") and Listening("PLAYER_REGEN_DISABLED"))
Flush()
check("an empty Will not be traded slot builds no panel", FindPanel() == nil)

craftable[7418] = 1
tradeLink = "bracer"
Fire("TRADE_TARGET_ITEM_CHANGED", 1)
check("another slot changing does nothing", #timers == 0)
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
local panel = FindPanel()
check("their item in the slot shows the panel", panel ~= nil and panel.shown)
check("beside the trade window", panel.points[1][2] == env.TradeFrame and panel.points[1][3] == "TOPRIGHT")
local first, second = panel.rows[1], panel.rows[2]
check("one row per fitting enchant, the asked one first", first.shown and second.shown
    and first.button.recipeID == 7418 and second.button.recipeID == 13642)
check("marked as asked for", first.note.text == "Asked for" and second.note.text == "")
check("an enchant you lack reagents for is greyed", first.button.enabled and not second.button.enabled
    and second.name.color.r == muted.r)
local button = first.button
check("its button is a secure click on the trade window's slot",
    button.template == "SecureActionButtonTemplate"
    and button.attributes.clickbutton == env.TradeRecipientItem7ItemButton
    and button.attributes.useOnKeyDown == false)
check("which does nothing until clicked", button.attributes.type == nil)

local PreClick = button.scripts.PreClick
PreClick(button, "LeftButton", true)
check("the press down starts nothing", #crafted == 0 and button.attributes.type == nil)
PreClick(button, "LeftButton", false)
check("the click starts the enchant and passes the click to their item", crafted[1] == 7418
    and button.attributes.type == "click")
targeting = true
PreClick(button, "LeftButton", false)
check("with a spell already on the cursor it does nothing", #crafted == 1 and button.attributes.type == nil)
targeting, modified = false, true
PreClick(button, "LeftButton", false)
check("nor on a modified click", #crafted == 1 and button.attributes.type == nil)
modified = false

profession = 164
Fire("TRADE_SKILL_SHOW")
Flush()
check("another profession open lists nothing and says to open Enchanting",
    not panel.rows[1].shown and panel.note.text == "Open Enchanting to list your enchants for this item.")
PreClick(button, "LeftButton", false)
check("and an old button starts nothing", #crafted == 1 and button.attributes.type == nil)
profession = ENCHANTING
env.ProfessionsFrame.shown = false
Fire("TRADE_SKILL_CLOSE")
Flush()
check("so does Enchanting closed", panel.note.text == "Open Enchanting to list your enchants for this item.")
env.ProfessionsFrame.shown = true

tradeLink = "dagger"
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("a new item lists its own enchants", panel.rows[1].button.recipeID == 7788 and not panel.rows[2].shown)
tradeLink = "robe"
recipes[7420].learned = false
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("an item none of yours goes on says so", panel.note.text == "None of your enchants go on this item.")
recipes[7420].learned = true

for i = 1, 10 do Learn(40000 + i, "Enchant Bracer - Test " .. i, 10 + i) end
local slots = P.EnchantSlots
for i = 1, 10 do slots[40000 + i] = slots[7418] end
tradeLink = "bracer"
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("more than eight show eight and say how many", panel.rows[8].shown and panel.rows[9] == nil
    and panel.note.text == "12 enchants: scroll for more.")
check("the asked enchant and the best come first", panel.rows[1].button.recipeID == 7418
    and panel.rows[2].button.recipeID == 13642 and panel.rows[3].button.recipeID == 40010)
panel.scripts.OnMouseWheel(panel, -1)
check("the wheel scrolls the list", panel.rows[1].button.recipeID == 13642)
for _ = 1, 20 do panel.scripts.OnMouseWheel(panel, -1) end
check("and stops at its end", panel.rows[8].button.recipeID == 40001)
for i = 1, 10 do slots[40000 + i] = nil end

Fire("PLAYER_REGEN_DISABLED")
check("combat starting closes the panel and lets go of the trade window", not panel.shown and #panel.points == 0)
inCombat = true
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("in combat it stays closed", not panel.shown)
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Flush()
check("and comes back after", panel.shown)

panel.dismissed = true
panel.shown = false
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("closed with its X it stays closed for this trade", not panel.shown)

Fire("TRADE_CLOSED")
check("the trade ending closes it", not panel.shown)
check("stops its trade-time events", not Listening("TRADE_SKILL_LIST_UPDATE") and not Listening("BAG_UPDATE_DELAYED")
    and not Listening("PLAYER_REGEN_DISABLED"))
check("but keeps what that player asked for", TE.Asked(PARTNER, 7418))
Fire("TRADE_SHOW")
Flush()
check("the next trade opens it again", panel.shown and not panel.dismissed)
check("with a cancelled trade's request still asked for, and first", panel.rows[1].button.recipeID == 7418
    and panel.rows[1].note.text == "Asked for")
Fire("TRADE_CLOSED")

for i = 1, 19 do Say("CHAT_MSG_WHISPER", LINK:format(7418, "x"), "Player-1-" .. i) end
check("twenty askers are remembered", TE.Asked(PARTNER, 7418) and TE.Asked("Player-1-19", 7418))
Say("CHAT_MSG_WHISPER", LINK:format(7418, "x"), "Player-1-20")
check("one more starts the list over, so it stays small", not TE.Asked(PARTNER, 7418)
    and not TE.Asked("Player-1-19", 7418) and TE.Asked("Player-1-20", 7418))

known = false
Fire("TRADE_SHOW")
Fire("TRADE_TARGET_ITEM_CHANGED", SLOT)
Flush()
check("a character without Enchanting sees no panel", not panel.shown)
known = true
Fire("TRADE_CLOSED")

S.Set("tradeEnchants", false)
check("turned off, it listens to nothing", not Listening("TRADE_SHOW") and not Listening("CHAT_MSG_WHISPER")
    and not Listening("TRADE_SKILL_LIST_UPDATE"))

print(("test-profession-trade-enchants: %d checks passed"):format(checks))
