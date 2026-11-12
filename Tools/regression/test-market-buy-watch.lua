-- Run with Lua 5.1 from the repository root: the panel's Buy page and The Market's Prices page share one search
-- list and Watch box. Buy lists only the Watch List, under your price first; typing searches your scans; Watch,
-- a row's x and Stop Watching change the list. Prices lists your bags and keeps the Watch box, and its filter lists
-- only the Craftsman's Writs in your scans, all of them or one profession's.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Frame(kind, parent)
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, children = {} }
    if parent then parent.children[#parent.children + 1] = f end
    return setmetatable(f, { __index = function(_, k)
        if k == "IsShown" then return function(self) return self.shown end end
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
        if k == "SetTextColor" then return function(self, r) self.r = r end end
        if k == "HasFocus" then return function() return false end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local function Text(parent) return Frame("FontString", parent) end

local prices = { [101] = 500, [102] = 2000, [103] = 90, [104] = 70, [201] = 300, [202] = 400, [203] = 250 }
local itemNames = { [101] = "Black Lotus", [102] = "Arcanite Bar", [103] = "Blue Lotus Petal", [104] = "Peacebloom",
    [201] = "Writ: Mana Potion", [202] = "Writ: Runecloth Bag", [203] = "Writ: Ogre Suit", [204] = "Writ: Elixir" }
local ALCHEMY, TAILORING = 171, 197
local professionNames = { [ALCHEMY] = "Alchemy", [TAILORING] = "Tailoring" }
local menu, lastChart
local bags = { { itemID = 104 }, { itemID = 102 } }
local account = {}
local refreshed, buttons, moneyBoxes = 0, {}, {}
local GREEN, WHITE = { r = 0, g = 1, b = 0 }, { r = 1, g = 1, b = 1 }

local ns = {
    THEME = { fg = WHITE, muted = WHITE, accent = WHITE },
    FEATURES = { market = { enabled = true } },
    AccountSettings = function() return account end,
    AuctionPrice = function(id) return prices[id] end,
    AuctionPriceList = function() return prices end,
    L = function(text, ...) if select("#", ...) > 0 then return text:format(...) end return text end,
    Lower = string.lower,
    Font = function(parent) return Text(parent) end,
    Solid = function(parent) return Frame("Texture", parent) end,
    Border = function() end,
    Tooltip = function() end,
    Print = function() end,
    SetButtonText = function(button, text) button.label = text end,
    PrimaryButton = function(button) return button end,
    Button = function(parent, text, _, _, onClick)
        local b = Frame("Button", parent)
        b.label, b.click = text, onClick
        buttons[#buttons + 1] = b
        return b
    end,
    UI = { SlimScroll = function(parent) return Frame("ScrollFrame", parent) end },
    ContextMenu = function(owner, generator)
        menu = { owner = owner, radios = {} }
        function menu.CreateRadio(_, text, isSelected, setSelected, data)
            menu.radios[#menu.radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
        end
        function menu.CreateTitle() end
        function menu.CreateDivider() end
        generator(owner, menu)
    end,
}
ns.Shared = {
    Items = { Name = function(id) return itemNames[id] end, QualityColor = function() return nil end,
        OnLoaded = function() end },
    Parts = {
        SearchBox = function(parent, _, onChange)
            local box = Frame("EditBox", parent)
            box.text = ""
            box:SetScript("OnTextChanged", function() onChange() end)
            return box
        end,
        RowBands = function(row)
            row.stripe, row.hover = Frame("Texture", row), Frame("Texture", row)
        end,
        ItemIcon = function(parent)
            local icon = Frame("Frame", parent)
            icon.texture = Frame("Texture", icon)
            return icon
        end,
        Coins = function(copper) return tostring(copper) end,
        MoneyBox = function(parent)
            local money = Frame("Frame", parent)
            money.boxes = {}
            function money.SetAmount(_, v) money.amount = v end
            function money.GetAmount() return money.amount end
            function money.HasFocus() return false end
            moneyBoxes[#moneyBoxes + 1] = money
            return money
        end,
    },
}
ns.Market = {
    C = { SILVER = 100 },
    Style = { TEXT_SIZE = 12, SMALL_SIZE = 11, SEARCH_H = 24, SCROLLBAR = 6, PANEL_FILL = 0.1, PICKED_FILL = 0.2,
        BORDER_RGB = WHITE, HAVE_RGB = GREEN, DOCK_W = 380, DOCK_PAD = 10 },
    Settings = { Get = function() return true end },
    Pages = {},
    WRITS = { [ALCHEMY] = { 201, 203, 204 }, [TAILORING] = { 202, 203 } },
    Dock = { Refresh = function() refreshed = refreshed + 1 end },
    Worth = { Read = function() return bags end },
    Chart = { New = function(parent)
        local chart = Frame("Frame", parent)
        lastChart = chart
        function chart.Paint(_, id) chart.painted = id end
        return chart
    end },
}

local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = function(kind, _, parent) return Frame(kind, parent) end,
    C_Item = { GetItemNameByID = function(id) return itemNames[id] end, IsItemDataCachedByID = function() return true end,
        GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_TradeSkillUI = { GetTradeSkillDisplayName = function(id) return professionNames[id] end },
    GameTooltip = Frame("GameTooltip"),
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
for _, path in ipairs({ "NaowhForever_Market/Watch.lua", "NaowhForever_Market/View/Finder.lua",
    "NaowhForever_Market/UI/Buy.lua", "NaowhForever_Market/UI/Prices.lua" }) do
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn()
end
local Market, Watch = ns.Market, ns.Market.Watch
local Buy, Prices = Market.Pages.buy, Market.Pages.prices

local function RowsOf(page)
    local found = {}
    local function Walk(f)
        if f.kind == "Button" and f.itemID and f.shown then found[#found + 1] = f end
        for _, child in ipairs(f.children) do Walk(child) end
    end
    Walk(page)
    table.sort(found, function(a, b) return a.order < b.order end)
    return found
end

local root = Frame("Frame")
local function RowPoint(row, point, _, y)
    if point == "TOPLEFT" and type(y) == "number" then row.order = -y end
end
env.CreateFrame = function(kind, _, parent)
    local f = Frame(kind, parent)
    if kind == "Button" then rawset(f, "SetPoint", RowPoint) end
    return f
end

Buy.Build(root)
Buy.Show()
local buyMoney = moneyBoxes[1]
local search
for _, child in ipairs(root.children[1].children) do
    for _, c in ipairs(child.children) do if c.kind == "EditBox" then search = c end end
end
check("Buy has a search box", search ~= nil)
check("with nothing watched, Buy's list is empty", #RowsOf(root) == 0)

search:SetText("lotus")
local rows = RowsOf(root)
check("typing searches your scans by name", #rows == 2 and rows[1].itemID == 101 and rows[2].itemID == 103)
check("and the first is picked into the Watch box, a silver under its price", buyMoney.amount == 400)

local function Click(label, from)
    for i = #buttons, 1, -1 do
        local b = buttons[i]
        if b.label == label and b.shown and (not from or b.parent == from) then return b.click() end
    end
    error("no button " .. label)
end

buyMoney.amount = 600
Click("Watch")
check("Watch adds the picked item at your price", Watch.Target(101) == 600)
check("and redraws the panel", refreshed > 0)
rows[2].scripts.OnClick(rows[2])
buyMoney.amount = 50
Click("Watch")
check("a second item joins it", Watch.Target(103) == 50)

search:SetText("")
rows = RowsOf(root)
check("cleared, Buy lists only the Watch List", #rows == 2)
check("under your price first", rows[1].itemID == 101 and rows[2].itemID == 103)
check("its price in green when at or under yours", rows[1].price.r == GREEN.r and rows[2].price.r == WHITE.r)
local stop
for _, c in ipairs(rows[2].children) do if c.kind == "Button" and c.label == "x" then stop = c end end
check("a watched row has an x", stop and stop.shown)
stop.click()
rows = RowsOf(root)
check("which takes it off the list", Watch.Target(103) == nil and #rows == 1 and rows[1].itemID == 101)

rows[1].scripts.OnClick(rows[1])
Click("Stop Watching")
check("Stop Watching takes the picked item off", Watch.Target(101) == nil and #RowsOf(root) == 0)

local window = Frame("Frame")
Prices.Build(window)
Prices.Show()
rows = RowsOf(window)
check("Prices lists your bags with a scan price, not the Watch List", #rows == 2 and rows[1].itemID == 104
    and rows[2].itemID == 102)
local pricesMoney = moneyBoxes[#moneyBoxes]
pricesMoney.amount = 65
Click("Watch")
check("Prices keeps the Watch box for the item it shows", Watch.Target(104) == 65)
Buy.Draw()
rows = RowsOf(root)
check("and what it watches shows on Buy", #rows == 1 and rows[1].itemID == 104)

local filter
for _, b in ipairs(buttons) do if b.label == "All Items" then filter = b end end
check("Prices has a filter beside its search, on All Items", filter ~= nil)
local function Pick(text)
    filter.click()
    for _, radio in ipairs(menu.radios) do
        if radio.text == text then return radio.setSelected(radio.data) end
    end
    error("no filter " .. text)
end
filter.click()
local names = {}
for _, radio in ipairs(menu.radios) do names[#names + 1] = radio.text end
check("the filter offers all items, all writs, then each profession by its client name",
    table.concat(names, ",") == "All Items,All Writs,Alchemy,Tailoring")
check("All Items is the one picked at first", menu.radios[1].isSelected(menu.radios[1].data)
    and not menu.radios[2].isSelected(menu.radios[2].data))

local function IDs()
    local ids = {}
    for _, row in ipairs(RowsOf(window)) do ids[#ids + 1] = row.itemID end
    return table.concat(ids, ",")
end
Pick("All Writs")
check("All Writs lists every writ in your scans by name, each once", IDs() == "201,203,202")
check("the button names the filter", filter.label == "All Writs")
Pick("Tailoring")
check("a profession lists only the writs it fills, a shared one too", IDs() == "203,202")
check("and the button names the profession", filter.label == "Tailoring")
check("the first of them is picked for the chart", lastChart.painted == 203)
Pick("Alchemy")
check("a writ that is not in your scans is left out", IDs() == "201,203")
local pricesSearch
for _, child in ipairs(window.children[1].children) do
    for _, c in ipairs(child.children) do if c.kind == "EditBox" then pricesSearch = c end end
end
pricesSearch:SetText("mana")
check("typing searches within the filter", IDs() == "201")
pricesSearch:SetText("lotus")
check("so an item outside it is not found", IDs() == "")
pricesSearch:SetText("")
Pick("All Items")
check("All Items goes back to your bags", IDs() == "104,102" and filter.label == "All Items")

print(("test-market-buy-watch: %d checks passed"):format(checks))
