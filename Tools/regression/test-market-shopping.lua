-- Run with Lua 5.1 from the repository root: the panel's Shopping List page. It lists what your Shopping List still
-- needs, then each alt's on this realm and faction, by name, on the Watch List's search list; a commodity bought in
-- Blizzard's buy dialog while a row is picked counts on that row's character's list.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Frame(kind, parent)
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, children = {} }
    if parent then parent.children[#parent.children + 1] = f end
    return setmetatable(f, { __index = function(_, k)
        if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
        if k == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
        if k == "SetText" then return function(self, text)
            self.text = text
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
        end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "SetTextColor" then return function(self, r) self.r = r end end
        if k == "HasFocus" then return function() return false end end
        if k == "RegisterEvent" then return function(self, event)
            self.events = self.events or {}
            self.events[event] = true
        end end
        if k == "UnregisterAllEvents" then return function(self) self.events = {} end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local LINEN, WOOL, SILK = 2589, 2592, 4306
local itemNames = { [LINEN] = "Linen Cloth", [WOOL] = "Wool Cloth", [SILK] = "Silk Cloth" }
local prices = { [LINEN] = 10, [WOOL] = 40, [SILK] = 90 }
local mine = { { item = LINEN, qty = 30, name = "Linen Cloth" } }
local lists = { ["Player-2"] = { { item = LINEN, qty = 5, name = "Linen Cloth" } },
    ["Player-3"] = { { item = WOOL, qty = 2, name = "Wool Cloth" } },
    ["Player-4"] = { { item = SILK, qty = 1, name = "Silk Cloth" } },
    ["Player-6"] = { { item = SILK, qty = 9, name = "Silk Cloth" } } }
local bought, redraws, listeners = {}, 0, {}
local account = { marketCharacters = {
    ["Player-1"] = { name = "Me", house = "Realm-Horde" },
    ["Player-2"] = { name = "Zed", house = "Realm-Horde" },
    ["Player-3"] = { name = "Abe", house = "Realm-Horde" },
    ["Player-4"] = { name = "Far", house = "Other-Horde" },
    ["Player-5"] = { name = "Bob", house = "Realm-Horde" },
    ["Player-6"] = { name = "Me", house = "Realm-Horde" },
} }
local Shopping = {
    Materials = function() return mine end,
    HasList = function(guid) return lists[guid] ~= nil end,
    MaterialsOf = function(guid) return lists[guid] end,
    Bought = function(item, qty) bought[#bought + 1] = { item = item, qty = qty } end,
    BoughtFor = function(guid, name, item, qty) bought[#bought + 1] = { owner = guid, who = name, item = item, qty = qty } end,
    Redraw = function()
        redraws = redraws + 1
        for _, fn in ipairs(listeners) do fn() end
    end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
}
local WHITE, MUTED = { r = 1, g = 1, b = 1 }, { r = 0.5, g = 0.5, b = 0.5 }
local ns = {
    THEME = { fg = WHITE, muted = MUTED, accent = WHITE },
    Professions = { Shopping = Shopping },
    AccountSettings = function() return account end,
    AuctionPrice = function(id) return prices[id] end,
    AuctionPriceList = function() return prices end,
    L = function(text) return text end,
    Lower = string.lower,
    Font = function(parent) return Frame("FontString", parent) end,
    Solid = function(parent) return Frame("Texture", parent) end,
    Border = function() end,
    Tooltip = function() end,
    SetButtonText = function(button, text) button.label = text end,
    PrimaryButton = function(button) return button end,
    Button = function(parent, text, _, _, onClick)
        local b = Frame("Button", parent)
        b.label, b.click = text, onClick
        return b
    end,
    UI = { SlimScroll = function(parent) return Frame("ScrollFrame", parent) end },
}
ns.Shared = {
    Items = { Name = function(id) return itemNames[id] end, QualityColor = function() return nil end },
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
        Coins = function(copper) return tostring(copper) end,
        MoneyBox = function(parent)
            local money = Frame("Frame", parent)
            money.boxes = {}
            function money.SetAmount(_, v) money.amount = v end
            function money.GetAmount() return money.amount end
            function money.HasFocus() return false end
            return money
        end,
    },
}
ns.Market = {
    C = { SILVER = 100 },
    Style = { TEXT_SIZE = 12, SMALL_SIZE = 11, SEARCH_H = 24, SCROLLBAR = 6, PANEL_FILL = 0.1, PICKED_FILL = 0.2,
        BORDER_RGB = WHITE, HAVE_RGB = WHITE, DOCK_W = 380, DOCK_PAD = 10 },
    Settings = { Get = function() return true end },
    Pages = {},
    Dock = { Refresh = function() end },
    HouseKey = function() return "Realm-Horde" end,
}

local dialog = { BuyNow = function() end }
local frames = {}
local function RowPoint(row, point, _, y)
    if point == "TOPLEFT" and type(y) == "number" then row.order = -y end
end
local env = setmetatable({
    _G = { NaowhForever = ns, AuctionHouseFrame = { BuyDialog = dialog } },
    CreateFrame = function(kind, _, parent)
        local f = Frame(kind, parent)
        if kind == "Button" then rawset(f, "SetPoint", RowPoint) end
        frames[#frames + 1] = f
        return f
    end,
    C_Item = { GetItemNameByID = function(id) return itemNames[id] end, IsItemDataCachedByID = function() return true end,
        GetItemIconByID = function() return 1 end },
    GameTooltip = Frame("GameTooltip"),
    UnitGUID = function() return "Player-1" end,
    UnitName = function() return "Me" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    hooksecurefunc = function(t, name, fn)
        local old = t[name]
        t[name] = function(...) old(...); fn(...) end
    end,
}, { __index = _G })
for _, path in ipairs({ "NaowhForever_Market/Watch.lua", "NaowhForever_Market/View/Finder.lua",
    "NaowhForever_Market/UI/Shopping.lua" }) do
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn()
end
local Page = ns.Market.Pages.shop

local entries = Page.Entries()
check("your list first, then your alts' by name", #entries == 3 and entries[1].owner == nil and entries[1].qty == 30
    and entries[2].owner == "Player-3" and entries[2].who == "Abe" and entries[3].owner == "Player-2"
    and entries[3].who == "Zed" and entries[3].qty == 5)
check("an alt on another realm or faction, without a list, or with your name is left out", not entries[4])

local root = Frame("Frame")
Page.Build(root)
Page.Show()
local page = root.children[1]

local function Rows()
    local found = {}
    local function Walk(f)
        if f.kind == "Button" and f.itemID and f.shown then found[#found + 1] = f end
        for _, child in ipairs(f.children) do Walk(child) end
    end
    Walk(page)
    table.sort(found, function(a, b) return a.order < b.order end)
    return found
end

local rows = Rows()
check("each row is an item to buy, on the Watch List's search list", #rows == 3 and rows[1].itemID == LINEN
    and rows[2].itemID == WOOL and rows[3].itemID == LINEN)
check("saying how many more, and for whom", rows[1].price.text == "30 more" and rows[2].price.text == "2 more for Abe"
    and rows[3].price.text == "5 more for Zed" and rows[3].price.r == MUTED.r)
check("the first is picked, yours", Page.Picked() == entries[1] and rows[1].picked.shown and not rows[3].picked.shown)

rows[3].scripts.OnClick(rows[3])
rows = Rows()
check("picking an alt's row picks only that row, though you need the same item", rows[3].picked.shown
    and not rows[1].picked.shown and Page.Picked().owner == "Player-2")

local events
for _, f in ipairs(frames) do if f.scripts.OnEvent then events = f end end
local function Fire(event)
    if events.events and events.events[event] then events.scripts.OnEvent(events, event) end
end
dialog.itemID, dialog.quantity = LINEN, 5
dialog:BuyNow()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("bought in Blizzard's buy dialog, it counts on that alt's list", #bought == 1 and bought[1].owner == "Player-2"
    and bought[1].who == "Zed" and bought[1].item == LINEN and bought[1].qty == 5)
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("once, and only while a purchase is waiting", #bought == 1 and not next(events.events))

rows[1].scripts.OnClick(rows[1])
dialog.itemID, dialog.quantity = LINEN, 10
dialog:BuyNow()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("bought from your own row, it counts on your list and redraws it", #bought == 2 and bought[2].owner == nil
    and bought[2].qty == 10 and redraws == 1)

dialog.itemID = WOOL
dialog:BuyNow()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("another item than the picked row's counts on no list", #bought == 2)

dialog.itemID = LINEN
dialog:BuyNow()
Fire("COMMODITY_PURCHASE_FAILED")
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("a failed purchase counts on no list", #bought == 2)

dialog:BuyNow()
dialog.itemID = WOOL
Page.Hide()
dialog:BuyNow()
Fire("COMMODITY_PURCHASE_SUCCEEDED")
check("with the page closed, a purchase counts on no list, even after one was waiting", #bought == 2)
Page.Show()

local search
local function FindSearch(f)
    if f.kind == "EditBox" then search = f end
    for _, child in ipairs(f.children) do FindSearch(child) end
end
FindSearch(page)
search:SetText("cloth")
rows = Rows()
check("typing searches your scans, with their prices", #rows == 3 and rows[1].price.text ~= nil
    and not rows[1].price.text:find("more"))
check("and an item picked there is on no one's list", (function()
    rows[1].scripts.OnClick(rows[1])
    return Page.Picked() == nil
end)())
search:SetText("")

mine = {}
Shopping.Redraw()
rows = Rows()
check("a change to your list redraws the page", #rows == 2 and rows[1].itemID == WOOL)

ns.Professions = nil
check("without Professions the list is empty", #Page.Entries() == 0)

print(("test-market-shopping: %d checks passed"):format(checks))
