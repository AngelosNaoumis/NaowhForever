-- Run with Lua 5.1 from the repository root: Bag Worth's Include Bank. The bank is kept per character as it was
-- when last open (Bank.lua), priced as the bags are, and shown on the Bag Worth card with its age.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local LINEN, ORE, RING, HEARTH, JUNK = 2589, 2770, 7000, 6948, 5000
local TAB, TAB_TWO = 6, 7
local NOW = 500000

local t = World.Setup({ vendor = { [LINEN] = 3, [ORE] = 10, [RING] = 250 } })
local ns, env, S = t.ns, t.env, t.ns.MarketSettings
local Bank = t.M.Bank
t.now = NOW
t.scan = { [LINEN] = 2, [ORE] = 100, [RING] = 9000 }
t.bags[0] = { World.Stack(ORE, 5) }
t.bags[TAB] = { World.Stack(ORE, 20), World.Stack(LINEN, 10), World.Stack(RING, 1, { isBound = true }),
    World.Stack(JUNK, 1, { hasNoValue = true }) }
t.bags[TAB_TWO] = { World.Stack(ORE, 4), World.Stack(HEARTH, 1) }
local changes = 0
Bank.onChange = function() changes = changes + 1 end

local function Events()
    return t.Listening("BANKFRAME_OPENED"), t.Listening("PLAYERBANKSLOTS_CHANGED")
end

ns.Apply()
local visits, slots = Events()
Check("with The Market off nothing listens for the bank", not visits and not slots)
S.Set("enabled", true)
S.Set("bagWorth", true)
ns.Apply()
visits = Events()
Check("nor with Bag Worth on and Include Bank off, its default", S.Get("bagWorthBank") == false and not visits)
t.Fire("BANKFRAME_OPENED")
Check("so a visit to the bank keeps nothing", t.char.marketBank == nil and Bank.Worth() == nil)

S.Set("bagWorthBank", true)
ns.Apply()
visits, slots = Events()
Check("Include Bank listens for the bank opening and closing, and for nothing else until it is open",
    visits and t.Listening("BANKFRAME_CLOSED") and not slots and not t.Listening("BAG_UPDATE_DELAYED"))
Check("a bank never seen has no worth", Bank.Worth() == nil)

t.Fire("BANKFRAME_OPENED")
local kept = t.char.marketBank
Check("opening the bank keeps what it holds, an item's stacks together across its tabs",
    kept.items[ORE] == 24 and kept.items[LINEN] == 10 and kept.items[HEARTH] == 1 and kept.at == NOW)
Check("a bound item is kept apart, and one with no value is left out", kept.bound[RING] == 1
    and kept.items[RING] == nil and kept.items[JUNK] == nil and kept.bound[JUNK] == nil)
Check("and Bag Worth is told", changes == 1)
local worth, at = Bank.Worth()
Check("it is priced as the bags are: the auction price after the cut when it beats a vendor, a bound item at the vendor's",
    worth == 24 * 95 + 10 * 3 + 250 and at == NOW)
Check("while it is open, changes to it are listened for", t.Listening("PLAYERBANKSLOTS_CHANGED")
    and t.Listening("BAG_UPDATE_DELAYED"))

t.bags[TAB][2] = World.Stack(LINEN, 4)
t.Fire("PLAYERBANKSLOTS_CHANGED", 2)
t.Fire("PLAYERBANKSLOTS_CHANGED", 3)
t.Fire("BAG_UPDATE_DELAYED")
Check("a burst of changes is read once, a frame later", #t.timers == 1 and kept.items[LINEN] == 10)
t.RunTimers()
Check("and then kept", kept.items[LINEN] == 4 and changes == 2 and t.char.marketBank == kept)

t.now = NOW + 60
t.Fire("BANKFRAME_CLOSED")
Check("closing the bank dates what is kept and stops listening for changes", kept.at == NOW + 60
    and not t.Listening("PLAYERBANKSLOTS_CHANGED")
    and kept.items[ORE] == 24 and changes == 3)
t.Fire("BANKFRAME_CLOSED")
Check("the game's second close changes nothing", changes == 3)

t.Fire("BANKFRAME_OPENED")
t.Fire("BAG_UPDATE_DELAYED")
t.Fire("BANKFRAME_CLOSED")
t.bags[TAB], t.bags[TAB_TWO] = nil, nil
t.RunTimers()
Check("a change still waiting when the bank closes is never read from a bank that can no longer be seen",
    kept.items[ORE] == 24 and kept.bound[RING] == 1)

Check("Sell's queue and the bags' own worth never read the bank", #t.M.Bags.Read() == 1 and t.M.Bags.Read()[1].count == 5
    and #t.M.Worth.Read() == 1 and t.M.Worth.total == 5 * 95)

local many = {}
for i = 1, 600 do many[i] = World.Stack(10000 + i, 1) end
many[601] = World.Stack(10001, 3)
t.bags[TAB] = many
t.Fire("BANKFRAME_OPENED")
local count = 0
for _ in pairs(kept.items) do count = count + 1 end
Check("what is kept stops at its limit of items, and still counts more of one it holds", count == 500
    and kept.items[10001] == 4 and kept.items[10600] == nil)
t.Fire("BANKFRAME_CLOSED")

S.Set("bagWorthBank", false)
ns.Apply()
visits, slots = Events()
Check("turned off, nothing listens for the bank again", not visits and not slots)

local function Widget(parent)
    local w = { parent = parent, shown = true, points = {} }
    return setmetatable(w, { __index = function(_, k)
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
        if k == "IsShown" or k == "IsVisible" then return function(self) return self.shown end end
        if k == "SetText" then return function(self, text) self.text = text end end
        if k == "SetHeight" then return function(self, height) self.height = height end end
        if k == "SetPoint" then return function(self, point, ...) self.points[point] = { ... } end end
        if k == "GetFrameStrata" then return function() return "MEDIUM" end end
        if k == "CreateTexture" then return function(self) return Widget(self) end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local fonts = {}
ns.THEME = { fg = {}, muted = {}, accentSoft = {} }
ns.Market.Style = { TEXT_SIZE = 12, SMALL_SIZE = 11, PANEL_FILL = 0.1, BORDER_RGB = {}, GOLD_RGB = {}, BADGE_TEXT_RGB = {} }
ns.Market.Dock = { AtAuction = function() return false end, Pick = function() end }
ns.Font = function(parent)
    local font = Widget(parent)
    fonts[#fonts + 1] = font
    return font
end
ns.Solid = function(parent) return Widget(parent) end
ns.Border = function() end
ns.Shared.Ago = function(when) return (t.now - when) .. "s ago" end
ns.Shared.Parts = {
    Coins = function(copper) return copper .. "c" end,
    ItemIcon = function(parent)
        local icon = Widget(parent)
        icon.texture = Widget(icon)
        return icon
    end,
    Backdrop = function() return { Paint = function() end } end,
}
ns.Shared.Bags = { OnGameUpdate = function() end, RepaintGame = function() end, Ellesmere = function() end,
    RefreshEllesmere = function() end }
local makeFrame = env.CreateFrame
env.CreateFrame = function(kind, _, parent)
    if parent then return Widget(parent) end
    return makeFrame(kind)
end
env.UIParent = Widget()
env.ContainerFrameCombinedBags = Widget()
env.ITEM_QUALITY_COLORS = {}
env.BACKPACK_CONTAINER = 0
Load({ "NaowhForever_Market/UI/BagWorth.lua" }, env)

local function Text(start)
    for _, font in ipairs(fonts) do
        if font.shown and font.parent.shown and type(font.text) == "string" and font.text:find(start, 1, true) == 1 then
            return font
        end
    end
end

local function Worth(label)
    for _, font in ipairs(fonts) do
        if font.parent == label.parent and font ~= label then return font.text end
    end
end

t.bags[TAB], t.bags[TAB_TWO] = nil, nil
t.char.marketBank = nil
ns.Apply()
local card = Text("Most Valuable").parent
local ROW_H = 22
local plain = card.height
Check("with Include Bank off the card is as it was", Text("Bags worth").text == "Bags worth 475c" and Text("Bank") == nil)

S.Set("bagWorthBank", true)
ns.Apply()
Check("on, a bank not yet seen says so, on a line of its own under the items",
    Text("Bank").text == "Bank not seen yet: open it once" and Text("Bags and bank") == nil
    and card.height == plain + ROW_H)

t.bags[TAB] = { World.Stack(ORE, 20), World.Stack(LINEN, 10) }
t.Fire("BANKFRAME_OPENED")
t.now = NOW + 7200
t.Fire("BANKFRAME_CLOSED")
t.now = NOW + 7260
t.RunTimers()
local line = Text("Bank as of")
Check("once seen, the card says how old the bank it counts is and what that bank would fetch, to the copper",
    line.text == "Bank as of 60s ago" and Worth(line) == "1930c")
Check("and under it what your bags and bank fetch together", Worth(Text("Bags and bank")) == "2405c"
    and card.height == plain + 2 * ROW_H)
Check("the bags' own total and their most valuable items stay the bags'", Text("Bags worth").text == "Bags worth 475c")

t.scan[ORE] = 200
ns.Market.BagWorth.Changed()
t.RunTimers()
Check("a new price reprices the bank as it does the bags", Worth(Text("Bank as of")) == "3830c"
    and Worth(Text("Bags and bank")) == "4780c")

S.Set("bagWorthBank", false)
ns.Apply()
Check("turned off, the bank's lines go and the card is its old height", Text("Bank") == nil
    and Text("Bags and bank") == nil and card.height == plain)

print("market bank: " .. checks .. " checks passed")
