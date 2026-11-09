-- Run with Lua 5.1 from the repository root: the Reagents list Professions' window and The Market
-- share: your reagents most valuable first, Craft beside one only when it beats selling, a click
-- opening every recipe one goes into, a waypoint from an unlearned one, the search, item names asked
-- for once, and the events it listens to only while shown. Loads ReagentUses.lua and UI/ReagentList.lua
-- against stubs.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local PEACEBLOOM, SILVERLEAF, VIAL, HEALING, ELIXIR = 2447, 765, 3371, 118, 5997
local ALCHEMY = 171
local TRAINER = { 1, "Ford", "A", 1429, 40, 50 }

local function Noop() end
local timers, requests, placed = {}, {}, nil
local names = { [PEACEBLOOM] = "Peacebloom", [SILVERLEAF] = "Silverleaf", [HEALING] = "Minor Healing Potion",
    [ELIXIR] = "Elixir of Minor Fortitude" }
local scan = { [PEACEBLOOM] = 20, [SILVERLEAF] = 10, [HEALING] = 100, [ELIXIR] = 200 }
local counts = { [PEACEBLOOM] = 7, [SILVERLEAF] = 3 }
local bag = { PEACEBLOOM, SILVERLEAF }

local methods = {}
local meta = { __index = function(_, key) return methods[key] or (key:match("^%u") and Noop or nil) end }
local function Widget(parent)
    return setmetatable({ up = parent or false, vis = true, scripts = {}, events = {} }, meta)
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn) self.scripts[name] = fn end
function methods:Show()
    if self.vis then return end
    self.vis = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    if not self.vis then return end
    self.vis = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self.vis end
function methods:IsVisible() return self.vis and (not self.up or self.up:IsVisible()) end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function methods:GetWidth() return 400 end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end
function methods:Click() self.scripts.OnClick(self) end

local function Fire(frame, event, ...) if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end end
local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

local frames = {}
local root = Widget()
local ns = {
    Lower = string.lower,
    L = dofile("Tools/regression/locale_stub.lua").L,
    THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = { r = 0, g = 0.5, b = 1 } },
    Font = function(parent) return Widget(parent) end,
    Solid = function(parent) return Widget(parent) end,
    UI = { SlimScroll = function(parent) return Widget(parent) end },
    Shared = {
        Style = { ROW_HOVER = 0.04, SCROLLBAR = 8 },
        Parts = {
            Coins = function(copper) return copper .. "c" end,
            RowBands = function(row) row.stripe, row.hover, row.divider = Widget(row), Widget(row), Widget(row) end,
            ItemIcon = function(parent)
                local icon = Widget(parent)
                icon.texture = Widget(icon)
                return icon
            end,
        },
    },
    RecipeData = {
        [ALCHEMY] = { skillSpell = 2259, recipes = {
            { spell = 2330, item = HEALING, skill = 1, source = "trainer" },
            { spell = 7183, item = ELIXIR, skill = 50, source = "trainer" },
        } },
    },
    RecipeFinder = {
        Learned = function(spell) return spell == 2330 end,
        Skill = function(r) return r.skill end,
        Tag = function(r) return r.source == "trainer" and "Trainer" or "?" end,
        Describe = function() return { { text = "Ford", npc = TRAINER } } end,
    },
    AccountSettings = function() return {} end,
    AuctionPrice = function(item) return scan[item] end,
    PlaceWaypoint = function(...) placed = { ... } return true end,
}
ns.Professions = {
    C = { NPC_NAME = 2, NPC_FACTION = 3, NPC_MAP = 4, NPC_X = 5, NPC_Y = 6 },
    Style = { FONT = 12, FONT_SMALL = 11, FONT_LARGE = 13, READY_RGB = {}, RANK_RGB = {},
        PROFIT_RGB = { r = 0, g = 1, b = 0 }, RED_RGB = { r = 1, g = 0, b = 0 } },
    Vendors = { IsVendorItem = function(item) return item == VIAL end, Price = function() return 4 end },
    Prices = { AfterCut = function(each, made) return math.floor(each * made * 0.95) end },
    RecipeReagents = {
        [2330] = { PEACEBLOOM, 1, SILVERLEAF, 1, VIAL, 1 },
        [7183] = { PEACEBLOOM, 2, VIAL, 1 },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    NUM_BAG_SLOTS = 0,
    ITEM_QUALITY_COLORS = {},
    GameTooltip = Widget(),
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    Mixin = function(object, mixin) for k, v in pairs(mixin) do object[k] = v end return object end,
    CreateFrame = function(_, _, parent)
        local frame = Widget(parent)
        frames[#frames + 1] = frame
        return frame
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    UnitGUID = function() return "Player-1-0001" end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "Alchemy", nil, 30, 75, nil, nil, ALCHEMY, 0 end,
    C_Item = {
        GetItemCount = function(item) return counts[item] or 0 end,
        GetItemInfo = function() end,
        GetItemNameByID = function(item) return names[item] end,
        GetItemIconByID = function() return 1 end,
        GetItemQualityByID = function() end,
        RequestLoadItemDataByID = function(item) requests[item] = (requests[item] or 0) + 1 end,
    },
    C_Spell = { GetSpellName = function(id) return id == 2259 and "Alchemy" or nil end },
    C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
        GetContainerItemID = function(_, slot) return bag[slot] end,
    },
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/ReagentUses.lua", "NaowhForever_Professions/UI/ReagentList.lua" }, env)

local list = ns.Professions.ReagentList.New(root)
local events = frames[#frames]

local function Shown(pool)
    local out = {}
    for _, row in ipairs(pool) do
        if row.vis then out[#out + 1] = row end
    end
    return out
end

list:Hide()
list:Show()
Check("shown, it listens to bag changes and item loads", events.events.BAG_UPDATE_DELAYED
    and events.events.ITEM_DATA_LOAD_RESULT)
local rows = Shown(list.rows)
Check("your bags' reagents, most valuable first", #rows == 2 and rows[1].item == PEACEBLOOM
    and rows[2].item == SILVERLEAF)
Check("a reagent says how many you carry", rows[1].name.text:find("x7", 1, true) ~= nil)
Check("and to craft the recipe you know that gains most", rows[1].value.text == "Craft Minor Healing Potion"
    and rows[1].note.text == "+63c a craft over selling")
Check("closed, it lists no recipes", #Shown(list.useRows) == 0)
scan[HEALING] = 20
list:Draw()
rows = Shown(list.rows)
Check("with nothing worth crafting the right side is empty; the tooltip has the price",
    rows[1].value.text == "" and rows[1].note.text == "")
scan[HEALING] = 100
list:Draw()
rows = Shown(list.rows)

rows[1]:Click()
local uses = Shown(list.useRows)
Check("a click opens every recipe it goes into", #uses == 2)
Check("yours says so, with what it gains and how many your bags make", uses[1].sub.text == "You know it"
    and uses[1].value.text == "63c" and uses[1].note.text == "Make 3")
Check("one you have not learned names its profession, skill and source", uses[2].sub.text == "Alchemy 50, Trainer")
uses[2]:Click()
Check("clicking it sets a waypoint to where you learn it", placed and placed[1] == "Ford" and placed[2] == 1429)
placed = nil
uses[1]:Click()
Check("clicking one you know sets none", placed == nil)
rows[1]:Click()
Check("a second click closes it", #Shown(list.useRows) == 0)

Fire(events, "BAG_UPDATE_DELAYED")
Fire(events, "BAG_UPDATE_DELAYED")
Check("bag changes in a burst redraw once", #timers == 1)
RunTimers()

list:Search("LEAF ")
rows = Shown(list.rows)
Check("a search finds a reagent by name, any case", #rows == 1 and rows[1].item == SILVERLEAF)
Check("the Empty Vial's name is asked for once", requests[VIAL] == 1)
list:Search("vi")
Check("and not again while it is on its way", requests[VIAL] == 1)
Fire(events, "ITEM_DATA_LOAD_RESULT", 99999, true)
Check("another item loading redraws nothing", #timers == 0)
Fire(events, "ITEM_DATA_LOAD_RESULT", VIAL, false)
RunTimers()
Check("one that never loads is not asked for again", requests[VIAL] == 1)
names[VIAL] = "Empty Vial"
Fire(events, "ITEM_DATA_LOAD_RESULT", VIAL, true)
RunTimers()
rows = Shown(list.rows)
Check("once its name loads it is found, carried or not", #rows == 1 and rows[1].item == VIAL
    and rows[1].name.text == "Empty Vial")
list:Search("nothing like it")
Check("no match says so", #Shown(list.rows) == 0 and list.empty.vis and list.empty.text == "No reagent matches that.")
list:Search("")
Check("an empty search is your bags again", #Shown(list.rows) == 2)

list:Hide()
Check("hidden, it listens to nothing", next(events.events) == nil)

print(("test-profession-reagent-list: %d checks passed"):format(checks))
