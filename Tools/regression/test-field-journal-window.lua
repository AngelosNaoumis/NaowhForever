-- Run with Lua 5.1 from the repository root: the Field Journal tab of Discovery's window, built on the
-- Shared kit, opened and drawn against stubs. Each page is drawn with its card, its rank sections and
-- a row for every entry, the page switch shows only on its tab, and a row's tooltip, pin and Shift-click
-- are tried once, so a missing field or a bad call fails here instead of in game.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn)
        local old = f.scripts[script]
        f.scripts[script] = old and function(...) old(...); fn(...) end or fn
    end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTextColor = function(f, r, g, b) f.color = { r, g, b } end,
    GetStringWidth = function() return 40 end,
    GetFrameLevel = function() return 1 end,
    GetStatusBarTexture = function(f) return Frame(f) end,
    GetStringHeight = function() return 12 end,
    Show = function(f)
        local was = rawget(f, "shown")
        f.shown = true
        if was == false and f.scripts.OnShow then f.scripts.OnShow(f) end
    end,
    Hide = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = false
        if was and f.scripts.OnHide then f.scripts.OnHide(f) end
    end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    SetScrollChild = function(f, child) f.child = child end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, parent = parent }, META)
end

local function Click(f, button)
    assert(f.scripts.OnClick, "clickable")(f, button or "LeftButton")
end

local WHITE = { r = 1, g = 1, b = 1 }
local account, settings, listeners, scrolls, tip, copied, waypoint = {}, {}, {}, {}, {}, nil, nil
local shift = false
local UI = {
    Keep = function(parent, key, make)
        local kept = rawget(parent, key)
        if not kept then kept = make(parent); parent[key] = kept end
        return kept
    end,
    RefreshPage = NOTHING,
    CloseOnEscape = NOTHING,
    SlimScroll = function(parent)
        local scroll = Frame(parent)
        scrolls[#scrolls + 1] = scroll
        return scroll
    end,
    ModuleSettings = function(_, defaults)
        local S = {}
        function S.Get(k) if settings[k] == nil then return defaults[k] end return settings[k] end
        function S.Raw(k) return settings[k] end
        function S.Set(k, v)
            settings[k] = v
            for _, fn in ipairs(listeners) do fn(k, v) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        return S
    end,
}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    GamepadStandDown = function() return false end,
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = UI,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function(parent) return { SetColor = NOTHING, _frame = Frame(parent) } end,
    AllowOffscreen = NOTHING,
    AccentBorder = function(b) return b end,
    Button = function(parent, _, _, _, onClick)
        local b = Frame(parent)
        b.label, b._border, b._rest, b._onClick = Frame(b), { SetColor = NOTHING }, WHITE, onClick
        b.scripts.OnClick = function() if b._onClick then b._onClick() end end
        return b
    end,
    SetButtonText = NOTHING,
    Tooltip = NOTHING,
    MenuOpen = function() return false end,
    Hairline = NOTHING,
    PixelInset = NOTHING,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return account end,
    ShowCopyCard = function(kind, _, id) copied = { kind, id } end,
    PlaceWaypoint = function(name, map) waypoint = { name, map } return true end,
    Apply = NOTHING,
}
local env = setmetatable({
    NaowhForever = ns,
    UIParent = Frame(),
    GameTooltip = setmetatable({ scripts = {},
        SetItemByID = function(_, item) tip = { item = item } end,
        AddLine = function(_, text) tip[#tip + 1] = text end,
        AddDoubleLine = function(_, left, right) tip[#tip + 1] = left .. ": " .. tostring(right) end,
    }, META),
    GameTooltip_Hide = NOTHING,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    CreateColor = function() return { SetRGBA = NOTHING } end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    hooksecurefunc = NOTHING,
    InCombatLockdown = function() return false end,
    IsShiftKeyDown = function() return shift end,
    IsControlKeyDown = function() return false end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitFactionGroup = function() return "Alliance" end,
    UnitGUID = function() return "Player-1-Me" end,
    UnitLevel = function() return 20 end,
    ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return WHITE end }),
    GetQuestDifficultyColor = function() return WHITE end,
    C_Item = {
        GetItemInfo = function(id) return "Item " .. id end,
        GetItemInfoInstant = function() end,
        GetItemIconByID = function() return 1 end,
        GetItemCount = function() return 0 end,
        GetItemNameByID = function(id) return "Item " .. id end,
        GetItemQualityByID = function() return 1 end,
        IsItemDataCachedByID = function() return true end,
    },
    C_QuestLog = { IsQuestFlaggedCompleted = function() return false end },
    C_Map = { GetMapInfo = function(id) return { name = "Zone " .. id } end },
    C_Timer = { After = function(_, fn) fn() end },
    PixelUtil = { SetPoint = NOTHING, SetSize = NOTHING },
    MenuUtil = { CreateContextMenu = NOTHING },
}, { __index = _G })
env._G = env

Load({
    "Shared/Shared.lua", "Shared/Data/Forever.lua", "Shared/Style.lua", "Shared/Game/Items.lua",
    "Shared/Game/Places.lua", "Shared/UI/Parts.lua", "Shared/UI/GamepadNav.lua", "Shared/UI/Marks.lua",
    "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Share.lua", "Shared/UI/Panels.lua", "Shared/UI/Window.lua",
    "Shared/UI/Tabs.lua", "Shared/UI/Tracker.lua", "Shared/View/View.lua", "Shared/View/Kinds.lua",
    "Core/Features.lua",
}, env)
ns.Completo = { Tabs = { Build = function(host) return Frame(host) end, Show = NOTHING, Hide = NOTHING } }
local xml = assert(io.open("NaowhForever_Discovery/Discovery.xml", "rb")):read("*a"):gsub("<!%-%-.-%-%->", "")
local files = {}
for file in xml:gmatch("<Script%s+file=\"([^\"]+)\"") do
    if not file:find("Tracker") and not file:find("Pins") and not file:find("Settings") and not file:find("Nearby") then
        files[#files + 1] = "NaowhForever_Discovery/" .. file:gsub("\\", "/")
    end
end
Load(files, env)

local Field = ns.Discovery.Field
local data = ns.FieldJournal

local function View()
    for _, scroll in ipairs(scrolls) do
        if rawget(scroll, "child") then return scroll.child end
    end
end

local function Rows(view, kind)
    local pool, out = view.pools[kind], {}
    for i = 1, pool and pool.used or 0 do out[i] = pool[i] end
    return out
end

local function Sections(view)
    local out = {}
    for i, row in ipairs(Rows(view, "section")) do out[i] = row.text:GetText() end
    return out
end

local function Find(rows, key, id)
    for _, row in ipairs(rows) do
        if row.entry[key] == id then return row end
    end
end

settings.enabled = true
ns.OpenDiscoveryWindow("journal")
local view = View()
check("the journal tab draws on Discovery's scroll", view ~= nil)
local window = view:GetParent():GetParent()
check("its page switch shows on its tab", window.pages and window.pages:IsShown())
check("its footer says the journal is this character's", window.note.text:GetText() == "Kept for this character.")

local hero = Rows(view, "fieldHero")[1]
check("the fish page opens first, with its card", hero and hero.count:GetText() == "0 / " .. #data.fish)
check("the card says how to turn it on while it is off", hero.about:GetText():find("Turn on Field Journal", 1, true))
local fish = Rows(view, "field")
check("a row for every fish", #fish == #data.fish)
local sections = Sections(view)
check("ranks first, the fish only schools give last", sections[1]:find("^APPRENTICE")
    and sections[#sections]:find("^SCHOOLS OF FISH"))
local mackerel = Find(fish, "item", 6303)
check("a fish row: its name, skill, zones and status", mackerel.title:GetText() == "Item 6303"
    and mackerel.level:GetText() == 1 and mackerel.where:GetText():find("Zone 1411 97%", 1, true)
    and mackerel.status:GetText() == "Not caught" and not mackerel.pin:IsShown() and not mackerel.tick:IsShown())

mackerel.scripts.OnEnter(mackerel)
check("its tooltip is the item's, with status, skill, where and the hints", tip.item == 6303
    and tip[2] == "Status: Not caught" and tip[3] == "Skill: 1" and tip[#tip - 1] == "Shift-click: tick it off")
mackerel.scripts.OnMouseUp(mackerel, "RightButton")
check("a right-click copies its Wowhead link", copied and copied[1] == "item" and copied[2] == 6303)
shift = true
mackerel.scripts.OnMouseUp(mackerel, "LeftButton")
shift = false
mackerel = Find(Rows(view, "field"), "item", 6303)
check("a Shift-click ticks it off and the page redraws", Field.Had("fish", mackerel.entry)
    and mackerel.status:GetText() == "Caught" and mackerel.tick:IsShown())
check("the card counts it", Rows(view, "fieldHero")[1].count:GetText() == "1 / " .. #data.fish)

ns.DiscoverySettings.Set("fieldJournal", true)
check("turning it on redraws the open card", Rows(view, "fieldHero")[1].about:GetText():find("Each fish you catch", 1, true))
account.discoveryField["Player-1-Me"].herbs[2447] = 5
Click(window.pages.buttons[2])
local herbs = Rows(view, "field")
check("the herbs page: a row for every herb", #herbs == #data.herbs and herbs[1].entry.item == data.herbs[1].item)
local peacebloom = Find(herbs, "item", 2447)
check("a herb picked shows how many", peacebloom.status:GetText() == "5 picked" and peacebloom.tick:IsShown())
peacebloom.scripts.OnEnter(peacebloom)
check("its tooltip offers no Shift-click", tip[#tip - 1] ~= "Shift-click: untick it" and tip[#tip - 1] ~= "Shift-click: tick it off")
shift = true
peacebloom.scripts.OnMouseUp(peacebloom, "LeftButton")
shift = false
check("and a Shift-click leaves its count", Field.Count("herbs", Find(Rows(view, "field"), "item", 2447).entry) == 5)
check("the card tells what the page writes in once it is on",
    Rows(view, "fieldHero")[1].about:GetText():find("Each herb you pick", 1, true))

Click(window.pages.buttons[3])
local dishes = Rows(view, "field")
check("the cooking page: a row for every dish", #dishes == #data.dishes)
local sold = Find(dishes, "spell", 7751)
check("a dish sold for your side: who sells it, with a pin", sold.where:GetText() == "Sold by Tharynn Bouden, Zone 1429"
    and sold.pin:IsShown() and sold.pin.hint == "Right-click to share it in chat.")
settings.openMap = false
Click(sold.pin)
check("its pin is a waypoint to the vendor", waypoint and waypoint[1] == "Tharynn Bouden" and waypoint[2] == 1429)
check("a trainer's dish has no pin", not Find(dishes, "spell", 2539).pin:IsShown())
local sections3 = Sections(view)
check("dishes are sectioned by rank, Artisan last", sections3[#sections3]:find("^ARTISAN"))

ns.DiscoverySettings.Set("enabled", false)
check("with Discovery off the card says to turn Discovery on", Rows(view, "fieldHero")[1].about:GetText() == "Turn on Discovery")
Click(window.filters.buttons[1])
check("on Library Books the page switch hides", not window.pages:IsShown())
check("and the footer counts the books again", window.note.text:GetText():find("books for your faction", 1, true))

print("test-field-journal-window: " .. checks .. " checks passed")
