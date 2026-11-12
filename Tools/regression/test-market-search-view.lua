-- Run with Lua 5.1 from the repository root: the panel's Buy page with its two views. It opens on the Watch List;
-- Searches lists Recent or a saved list, runs a search on a click, keeps the search in Blizzard's window with Save
-- Search, and saves a recent one to a list from its +. A saved search's right-click menu renames it, sets Exact Name
-- and a max price, moves and deletes it; the list button's menu makes, renames, deletes, imports and exports lists.
-- Nothing of the Searches view is built until it is first picked.
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local made = 0
local function Frame(kind, parent)
    made = made + 1
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, children = {} }
    if parent then parent.children[#parent.children + 1] = f end
    return setmetatable(f, { __index = function(_, k)
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "IsVisible" then return function(self)
            local at = self
            while at do
                if not at.shown then return false end
                at = at.parent
            end
            return true
        end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
        if k == "GetParent" then return function(self) return self.parent end end
        if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
        if k == "SetText" then return function(self, text)
            self.text = text
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
        end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "HasFocus" then return function() return false end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local FILTER = { ExactMatch = 5, PoorQuality = 6, CommonQuality = 7, UncommonQuality = 8, RareQuality = 9,
    EpicQuality = 10, LegendaryQuality = 11 }
local ALL = { 6, 7, 8, 9, 10, 11 }
local WHITE = { r = 1, g = 1, b = 1 }
local account, printed, buttons = {}, {}, {}
local menu, prompt, confirm, copied, tips
local ready = true

local ah = { sent = {} }
local categories = {}
function categories:SetSelectedCategory(a, b, c) self.picked = { a, b, c } end
function categories:GetSelectedCategory() return unpack(self.picked or {}, 1, 3) end
function ah:GetCategoriesList() return categories end
function ah:SetDisplayMode() end
ah.SearchBar = { SearchBox = { GetSearchString = function() return ah.typed or "" end },
    FilterButton = { CalculateFiltersArray = function() return ALL end } }
function ah.SearchBar:SetSearchText(text) ah.typed = text end
function ah.SearchBar:GetLevelFilterRange() return ah.min or 0, 0 end
function ah:SendBrowseQuery(text) self.sent[#self.sent + 1] = text end

local function Menu(owner, generator)
    menu = { owner = owner, items = {} }
    local function Item(kind, text, a, b, data)
        local item = { kind = kind, text = text, enabled = true }
        function item:SetEnabled(on) self.enabled = on end
        if kind == "button" then
            item.pick = function() a(data) end
        else
            item.pick = function() a(data) end
            item.on = function() return b(data) end
        end
        menu.items[#menu.items + 1] = item
        return item
    end
    function menu:CreateButton(text, callback, data) return Item("button", text, callback, nil, data) end
    function menu:CreateRadio(text, isSelected, setSelected, data) return Item("radio", text, setSelected, isSelected, data) end
    function menu:CreateCheckbox(text, isSelected, setSelected, data)
        return Item("checkbox", text, setSelected, isSelected, data)
    end
    function menu:CreateDivider() end
    generator(owner, menu)
end

local function MenuItem(text)
    for _, item in ipairs(menu.items) do
        if item.text == text then return item end
    end
    error("no menu item " .. text)
end

local ns = {
    THEME = { fg = WHITE, muted = WHITE, accent = WHITE },
    FEATURES = { market = { enabled = true } },
    AccountSettings = function() return account end,
    AuctionPrice = function() return nil end,
    AuctionPriceList = function() return {} end,
    L = function(text, ...) if select("#", ...) > 0 then return text:format(...) end return text end,
    Lower = string.lower,
    Font = function(parent) return Frame("FontString", parent) end,
    Solid = function(parent) return Frame("Texture", parent) end,
    Border = function() end,
    Tooltip = function(frame, title, body) frame.tip, frame.tipBody = title, body end,
    Print = function(text) printed[#printed + 1] = text end,
    SetButtonText = function(button, text) button.label = text end,
    PrimaryButton = function(button) return button end,
    Button = function(parent, text, _, _, onClick)
        local b = Frame("Button", parent)
        b.label, b.click = text, onClick
        buttons[#buttons + 1] = b
        return b
    end,
    UI = { SlimScroll = function(parent) return Frame("ScrollFrame", parent) end },
    ContextMenu = Menu,
    PromptText = function(title, text, maxLetters, onAccept)
        prompt = { title = title, text = text, maxLetters = maxLetters, accept = onAccept }
    end,
    Confirm = function(text, onYes) confirm = { text = text, yes = onYes } end,
    ShowCopyBox = function(title, text) copied = { title = title, text = text } end,
}
ns.Shared = {
    Items = { Name = function() return "" end, QualityColor = function() return nil end },
    Parts = {
        SearchBox = function(parent, _, onChange)
            local box = Frame("EditBox", parent)
            box.text = ""
            box:SetScript("OnTextChanged", function() onChange() end)
            return box
        end,
        RowBands = function(row) row.stripe, row.hover = Frame("Texture", row), Frame("Texture", row) end,
        ItemIcon = function(parent)
            local icon = Frame("Frame", parent)
            icon.texture = Frame("Texture", icon)
            return icon
        end,
        Coins = function(copper) return copper .. "c" end,
        MoneyBox = function(parent)
            local money = Frame("Frame", parent)
            money.boxes = {}
            function money.SetAmount() end
            function money.GetAmount() return 0 end
            function money.HasFocus() return false end
            return money
        end,
        Tabs = function(parent, _, items, onPick)
            tips = Frame("Frame", parent)
            tips.items, tips.pick = items, onPick
            return tips
        end,
        PaintTabs = function(bar, key) bar.picked = key end,
    },
}
ns.Market = {
    C = { SILVER = 100 },
    Style = { TEXT_SIZE = 12, SMALL_SIZE = 11, SEARCH_H = 24, SCROLLBAR = 6, PANEL_FILL = 0.1, PICKED_FILL = 0.2,
        BORDER_RGB = WHITE, HAVE_RGB = WHITE, DOCK_W = 380, DOCK_PAD = 10 },
    Settings = { Get = function() return true end },
    Pages = {},
    Dock = { Refresh = function() end },
    On = function() return true end,
}

local readyFrames, order = {}, {}
local env = setmetatable({
    NaowhForever = ns,
    AuctionHouseFrame = ah,
    AuctionHouseFrameDisplayMode = { Buy = 1 },
    AuctionCategories = { { name = "Weapons", subCategories = { { name = "Swords" } } } },
    Enum = { AuctionHouseFilter = FILTER },
    ITEM_QUALITY2_DESC = "Uncommon", ITEM_QUALITY3_DESC = "Rare",
    CreateFrame = function(kind, _, parent)
        local f = Frame(kind, parent)
        if kind == "Frame" and not parent then
            rawset(f, "RegisterEvent", function() readyFrames[f] = true end)
            rawset(f, "UnregisterAllEvents", function() readyFrames[f] = nil end)
        elseif kind == "Button" then
            rawset(f, "SetPoint", function(row, point, _, y)
                if point == "TOPLEFT" and type(y) == "number" then order[row] = -y end
            end)
        end
        return f
    end,
    C_Item = { GetItemNameByID = function() return "" end, IsItemDataCachedByID = function() return true end,
        GetItemIconByID = function() return 1 end },
    C_AuctionHouse = { IsThrottledMessageSystemReady = function() return ready end },
    GameTooltip = Frame("GameTooltip"),
    hooksecurefunc = function(target, name, fn)
        local original = target[name]
        target[name] = function(...) original(...) fn(...) end
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
env._G = env
for _, path in ipairs({ "Shared/Decode.lua", "Shared/Encode.lua", "NaowhForever_Market/Watch.lua",
    "NaowhForever_Market/Searches.lua", "NaowhForever_Market/View/Finder.lua", "NaowhForever_Market/UI/Searches.lua",
    "NaowhForever_Market/UI/Buy.lua" }) do
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn()
end
local Searches, Buy = ns.Market.Searches, ns.Market.Pages.buy

local function Click(label)
    for i = #buttons, 1, -1 do
        local b = buttons[i]
        if b.label == label and b.shown then return b.click() end
    end
    error("no button " .. label)
end

local root = Frame("Frame")
local function Rows()
    local found = {}
    local function Walk(f)
        if f.kind == "Button" and f.search and f.shown then found[#found + 1] = f end
        for _, child in ipairs(f.children) do Walk(child) end
    end
    Walk(root)
    table.sort(found, function(a, b) return order[a] < order[b] end)
    return found
end
local function Names()
    local names = {}
    for i, row in ipairs(Rows()) do names[i] = row.name.text end
    return table.concat(names, ",")
end

Buy.Build(root)
Buy.Show()
local page = root.children[1]
local finderFrame, pick
check("Buy has two views, Watch List first", #tips.items == 2 and tips.items[1].label == "Watch List"
    and tips.items[2].label == "Searches" and tips.picked == "watch")
for _, child in ipairs(page.children) do
    for _, c in ipairs(child.children) do
        if c.kind == "EditBox" then finderFrame = child end
    end
end
check("the Watch List's search list shows", finderFrame ~= nil and finderFrame.shown)
local before = made
ah:SendBrowseQuery("Copper Ore")
check("a search in Blizzard's window is noted from the first visit, with nothing of Searches built",
    #Searches.Recent() == 1 and made == before)

tips.pick("searches")
check("picking Searches builds its view and puts the Watch List away", made > before and tips.picked == "searches"
    and not finderFrame.shown)
for _, b in ipairs(buttons) do
    if b.tip == "Pick a list, or make, rename, delete and share one." then pick = b end
end
check("with no list yet it opens on Recent", pick ~= nil and pick.label == "Recent" and Names() == "Copper Ore")
local row = Rows()[1]
check("a recent search says it has no filters and offers +", row.line.text == "No filters" and row.act.label == "+"
    and row.act.tip == "Save to a List")
ah:SendBrowseQuery("Linen Cloth")
check("a new search shows at the top at once", Names() == "Linen Cloth,Copper Ore")

row = Rows()[2]
row.scripts.OnClick(row, "LeftButton")
check("clicking a search runs it in Blizzard's window", ah.sent[#ah.sent] == "Copper Ore" and ah.typed == "Copper Ore"
    and Names() == "Copper Ore,Linen Cloth")
menu = nil
row.scripts.OnClick(row, "RightButton")
check("a recent search has no right-click menu", menu == nil)

row = Rows()[1]
row.act.click()
check("+ with no list offers only New List", menu.owner == row.act and #menu.items == 1
    and menu.items[1].text == "New List")
menu.items[1].pick()
check("which asks for a name within the limit", prompt.title == "Name the list" and prompt.maxLetters == Searches.MAX_NAME)
prompt.accept("Ores")
check("then makes the list, saves the search to it and shows it", #Searches.Lists() == 1
    and Searches.Lists()[1].name == "Ores" and pick.label == "Ores" and Names() == "Copper Ore"
    and printed[#printed] == "Saved to Ores.")
check("a saved search offers x", Rows()[1].act.label == "x" and Rows()[1].act.tip == "Delete")

ah.typed, ah.min = "Iron Ore", 20
categories.picked = { 1, 1 }
Click("Save Search")
check("Save Search keeps the search in Blizzard's window on the list shown", Names() == "Copper Ore,Iron Ore")
row = Rows()[2]
check("with its filters under its name", row.line.text == "Weapons > Swords, Level 20 and up"
    and row.tip == "Iron Ore" and row.tipBody == row.line.text)
Click("Save Search")
check("the same search again is not kept twice", Names() == "Copper Ore,Iron Ore"
    and printed[#printed] == "That search is already on the list.")
ah.typed, ah.min, categories.picked = "", 0, nil
Click("Save Search")
check("an empty window saves nothing", printed[#printed] == "Type a search or pick a category in the auction house first.")

row.scripts.OnClick(row, "RightButton")
check("a saved search's right-click menu renames, sets Exact Name and Max Price, moves and deletes",
    menu.owner == row and #menu.items == 6 and MenuItem("Move Down").enabled == false and MenuItem("Move Up").enabled)
MenuItem("Max Price").pick()
check("Max Price asks in gold", prompt.title == "Max price for Iron Ore, in gold (0 for none)" and prompt.text == "0")
prompt.accept("2,5")
check("and takes a decimal comma", Searches.Lists()[1].searches[2].price == 25000
    and Rows()[2].line.text == "Weapons > Swords, Level 20 and up, Up to 25000c")
MenuItem("Max Price").pick()
check("the prompt opens on the price it has", prompt.text == "2.5")
prompt.accept("cheap")
check("text that is not a price changes nothing", Searches.Lists()[1].searches[2].price == 25000
    and printed[#printed] == "That is not a price.")
prompt.accept("0")
check("0 takes the max price off", Searches.Lists()[1].searches[2].price == nil)
check("Exact Name starts off", not MenuItem("Exact Name").on())
MenuItem("Exact Name").pick()
check("and ticks on", MenuItem("Exact Name").on() and Rows()[2].line.text:find("^Exact Name, ") ~= nil)
MenuItem("Exact Name").pick()
check("and off again", Searches.Lists()[1].searches[2].exact == nil)
MenuItem("Rename").pick()
check("Rename asks with the name it has", prompt.title == "Search for" and prompt.text == "Iron Ore"
    and prompt.maxLetters == Searches.MAX_TEXT)
prompt.accept("Mithril Ore")
MenuItem("Move Up").pick()
check("it is renamed and moved up", Names() == "Mithril Ore,Copper Ore")
Rows()[2].act.click()
check("x deletes a saved search", Names() == "Mithril Ore")

pick.click()
check("the list button lists Recent and each list with its count", menu.owner == pick
    and menu.items[1].text == "Recent" and menu.items[2].text == "Ores (1)" and menu.items[2].on()
    and not menu.items[1].on())
check("and can rename, delete and export the list shown", MenuItem("Rename List").enabled
    and MenuItem("Delete List").enabled and MenuItem("Export List").enabled)
MenuItem("Export List").pick()
check("Export List shows its string to copy", copied.title == "Search list: Ores" and copied.text:find("^!NFMS1!") ~= nil)
MenuItem("Rename List").pick()
prompt.accept("Metals")
check("Rename List renames it", pick.label == "Metals")
MenuItem("Import List").pick()
prompt.accept("not a list")
check("Import List refuses what is not a list", #Searches.Lists() == 1 and printed[#printed] == "That is not a search list.")
prompt.accept(copied.text)
check("and adds a good one as a new list, shown", #Searches.Lists() == 2 and pick.label == "Ores"
    and Names() == "Mithril Ore")
MenuItem("Delete List").pick()
check("Delete List asks first", confirm.text == "Delete the list Ores and its 1 searches?" and #Searches.Lists() == 2)
confirm.yes()
check("then deletes it and goes back to Recent", #Searches.Lists() == 1 and pick.label == "Recent")
pick.click()
check("on Recent there is no list to rename, delete or export", not MenuItem("Rename List").enabled
    and not MenuItem("Delete List").enabled and not MenuItem("Export List").enabled)
Rows()[1].act.click()
check("+ on a recent search lists your lists, then New List", #menu.items == 2 and menu.items[1].text == "Metals"
    and menu.items[2].text == "New List")
menu.items[1].pick()
check("and saves it to the one picked, staying on Recent", #Searches.Lists()[1].searches == 2 and pick.label == "Recent")
pick.click()
MenuItem("New List").pick()
prompt.accept("Empty")
check("New List from the list button makes an empty list", pick.label == "Empty" and Names() == ""
    and #Searches.Lists()[2].searches == 0)

ready = false
pick.click()
menu.items[1].pick()
row = Rows()[1]
local sent = #ah.sent
row.scripts.OnClick(row, "LeftButton")
check("a search waits while the auction house is busy", #ah.sent == sent and next(readyFrames) ~= nil)
Buy.Hide()
check("and leaving the page drops it", next(readyFrames) == nil)
ready = true

Buy.Show()
Buy.ShowList()
check("the panel's watch line brings Buy back to the Watch List", tips.picked == "watch" and finderFrame.shown)
tips.pick("searches")
check("and Searches comes back as it was left", tips.picked == "searches" and not finderFrame.shown
    and pick.label == "Recent")

print(("test-market-search-view: %d checks passed"):format(checks))
