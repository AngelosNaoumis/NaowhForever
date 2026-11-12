-- Run with Lua 5.1 from the repository root: the panel's My Auctions page on The Market's real rules. A name filter
-- narrows the list, and Cancel Undercut and the Cancel Next Undercut Auction key then work on what is listed, one
-- auction a press, only while the page shows. An undercut row says how many items are listed for less; with Items
-- Ahead Allowed set, an auction with no more than that many ahead reads "N ahead" and is not cancelled.
local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local COPPER, LINEN, SILK = 2770, 2589, 4306
local NAMES = { [COPPER] = "Copper Ore", [LINEN] = "Linen Cloth", [SILK] = "Silk Cloth" }
local WHITE, GREEN, ORANGE, RED = { r = 1, g = 1, b = 1 }, { r = 0, g = 1, b = 0 }, { r = 1, g = 0.5, b = 0 },
    { r = 1, g = 0, b = 0 }

local function Key(itemID)
    return { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

local t = World.Setup({
    owned = {
        { auctionID = 1, itemKey = Key(COPPER), quantity = 20, buyoutAmount = 60, status = 0, timeLeftSeconds = 3600 },
        { auctionID = 2, itemKey = Key(LINEN), quantity = 5, buyoutAmount = 10, status = 0, timeLeftSeconds = 3600 },
        { auctionID = 3, itemKey = Key(SILK), quantity = 5, buyoutAmount = 100, status = 0, timeLeftSeconds = 3600 },
    },
    keyInfo = { [COPPER] = { isCommodity = true }, [LINEN] = { isCommodity = true }, [SILK] = { isCommodity = true } },
})
local env, ns, M = t.env, t.ns, t.M

local frames, order = {}, {}
local function Frame(kind, parent)
    local f = { kind = kind, parent = parent, shown = true }
    frames[#frames + 1] = f
    return setmetatable(f, { __index = function(_, k)
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, on) self.shown = on and true or false end end
        if k == "SetText" then return function(self, text) self.text = text end end
        if k == "GetText" then return function(self) return self.text end end
        if k == "SetHeight" then return function(self, height) self.height = height end end
        if k == "GetWidth" then return function() return 340 end end
        if k == "SetPoint" then return function(self, point, _, y)
            if point == "TOPLEFT" and type(y) == "number" then order[self] = -y end
        end end
        if type(k) == "string" and k:find("^%u") then return function() end end
    end })
end

local events = env.CreateFrame
env.CreateFrame = function(kind, _, parent)
    if not parent then return events() end
    return Frame(kind, parent)
end
env.GameTooltip = Frame("GameTooltip")
env.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end

local buttons, confirms, refreshes = {}, {}, 0
local search, onSetting
ns.THEME = { fg = WHITE, muted = WHITE, accent = WHITE }
ns.Lower = string.lower
ns.Font = function(parent) return Frame("FontString", parent) end
ns.Button = function(parent, text, _, _, onClick)
    local b = Frame("Button", parent)
    b.label, b.click = text, onClick
    buttons[#buttons + 1] = b
    return b
end
ns.PrimaryButton = function(button) return button end
ns.SetButtonText = function(button, text) button.label = text end
ns.Confirm = function(text, onYes) confirms[#confirms + 1] = { text = text, yes = onYes } end
ns.UI.SlimScroll = function(parent) return Frame("ScrollFrame", parent) end
ns.Shared.Items = { Name = function(id) return NAMES[id] end, QualityColor = function() return nil end }
ns.Shared.Parts = {
    RowBands = function(row) row.stripe, row.hover = Frame("Texture", row), Frame("Texture", row) end,
    ItemIcon = function(parent)
        local icon = Frame("Frame", parent)
        icon.texture = Frame("Texture", icon)
        return icon
    end,
    Pill = function(parent) return Frame("Frame", parent) end,
    SetPill = function(pill, text) pill.text = text end,
    ColorPill = function(pill, tint) pill.tint = tint end,
    Coins = function(copper) return tostring(copper) end,
    SearchBox = function(parent, hint, onSearch)
        search = Frame("EditBox", parent)
        search.hint, search.type = hint, onSearch
        return search
    end,
}
M.Pages = {}
M.Style = { TEXT_SIZE = 12, SMALL_SIZE = 11, BUTTON_H = 28, SCROLLBAR = 16, SEARCH_H = 24, WARN_RGB = ORANGE,
    RED_RGB = RED, HAVE_RGB = GREEN, Enable = function(button, on) button.enabled = on end }
M.Columns = { New = function() return {} end, Add = function() end, Sort = function() end }
M.Dock = { Refresh = function()
    refreshes = refreshes + 1
    M.Pages.mine.Show()
end }
M.Settings.OnChange = function(fn) onSetting = fn end
M.Settings.Set("enabled", true)
Load({ "NaowhForever_Market/UI/Auctions.lua" }, env)
local Page, A = M.Pages.mine, M.Auctions
local Press = env.NaowhForever_MarketCancelNext

local function Rows()
    local found = {}
    for _, f in ipairs(frames) do
        if f.auction and f.shown and f.name then found[#found + 1] = f end
    end
    table.sort(found, function(a, b) return order[a] < order[b] end)
    return found
end
local function Names()
    local names = {}
    for i, row in ipairs(Rows()) do names[i] = row.name.text end
    return table.concat(names, ",")
end
local function NextButton()
    for _, b in ipairs(buttons) do
        if b.label:find("^Cancel Undercut") then return b end
    end
end

Check("the key is in the game's bindings, unbound, and says The Market is off until it loads",
    Read("Bindings.xml"):find('<Binding name="NAOWHFOREVER_MARKET_CANCEL" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_MarketCancelNext()</Binding>", 1, true) ~= nil
    and Read("Core/Commands.lua"):find('NaowhForever_MarketCancelNext = SwitchedOff("The Market")', 1, true) ~= nil)
Press()
Check("before My Auctions has opened the key does nothing", #t.cancels == 0)

Page.Build(Frame("Frame"))
Page.Show()
t.Fire("OWNED_AUCTIONS_UPDATED")
t.results.commodity[COPPER] = { { unitPrice = 58, quantity = 4, numOwnerItems = 0 },
    { unitPrice = 59, quantity = 10, numOwnerItems = 4 }, { unitPrice = 60, quantity = 20, numOwnerItems = 20 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", COPPER)
t.results.commodity[LINEN] = { { unitPrice = 8, quantity = 3, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", LINEN)
t.results.commodity[SILK] = { { unitPrice = 100, quantity = 5, numOwnerItems = 5 },
    { unitPrice = 120, quantity = 9, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", SILK)

local rows = Rows()
Check("My Auctions lists every auction", Names() == "Copper Ore x20,Linen Cloth x5,Silk Cloth x5")
Check("it has a name filter box", search ~= nil and search.hint == "Filter your auctions by name")
Check("an undercut row says how many items are listed for less, not counting your own",
    rows[1].line.text == "Yours 60, lowest 58" and rows[1].more.text:find("^10 ahead, ") ~= nil
    and rows[2].more.text:find("^3 ahead, ") ~= nil)
Check("on a third line with its time left, in a taller row", rows[1].more.text ~= "10 ahead, " and rows[1].height == 52
    and rows[3].height == 38 and rows[3].more.text == "")
Check("and keeps its undercut pill", rows[1].status.text == "Undercut 3%" and rows[2].status.text == "Undercut 20%")
Check("an auction with nothing cheaper is the lowest, with its time left", rows[3].status.text == "Lowest"
    and rows[3].line.text == "Yours 100, lowest 120, 1h 00m")
local nextButton = NextButton()
Check("Cancel Undercut counts the undercut auctions", nextButton.label == "Cancel Undercut (2)" and nextButton.enabled)

search.type("  LINEN ")
Check("typing in the filter lists only the auctions with that in their name", Names() == "Linen Cloth x5")
Check("and Cancel Undercut counts only those", nextButton.label == "Cancel Undercut (1)")
Press()
Check("the key cancels the next undercut auction that is listed, one a press", #t.cancels == 1 and t.cancels[1] == 2)
Press()
Check("a second press does not go on to an auction the filter hides", #t.cancels == 1)
search.type("silk")
Check("with nothing undercut listed, Cancel Undercut is off", nextButton.label == "Cancel Undercut (0)"
    and nextButton.enabled == false)
nextButton.click()
Check("and cancels nothing", #t.cancels == 1)
search.type("dragon")
local empty
for _, f in ipairs(frames) do
    if f.text == "None of your auctions has that in its name." then empty = f end
end
Check("a filter nothing matches says so", Names() == "" and empty ~= nil and empty.shown)
search.type("")
Check("cleared, every auction is back", #Rows() == 3 and not empty.shown)
nextButton.click()
Check("Cancel Undercut cancels the next one too", #t.cancels == 2 and t.cancels[2] == 1)

t.Fire("AUCTION_CANCELED", 1)
table.remove(t.owned, 1)
table.remove(t.owned, 1)
t.owned[#t.owned + 1] = { auctionID = 4, itemKey = Key(COPPER), quantity = 20, buyoutAmount = 60, status = 0 }
t.owned[#t.owned + 1] = { auctionID = 5, itemKey = Key(LINEN), quantity = 5, buyoutAmount = 10, status = 0 }
t.owned[#t.owned + 1] = { auctionID = 6, itemKey = Key(COPPER), quantity = 5, buyoutAmount = 59, status = 0 }
t.Fire("OWNED_AUCTIONS_UPDATED")
Check("auctions read back keep each item's check", A.Status(A.list[2]) == "undercut" and A.list[2].ahead == 10
    and A.list[3].ahead == 3)
Check("a cheaper auction of the same item has fewer ahead", A.list[4].ahead == 4)

M.Settings.Set("aheadAllowed", 4)
onSetting("aheadAllowed")
Check("changing Items Ahead Allowed redraws the panel", refreshes == 1)
rows = Rows()
Check("an auction with no more than that many ahead is not undercut", A.Status(A.list[4]) == "ahead"
    and A.Status(A.list[3]) == "ahead" and A.Status(A.list[2]) == "undercut")
Check("its row reads how many are ahead, in green, with its time left", rows[3].status.text == "3 ahead"
    and rows[3].status.tint == GREEN and rows[3].line.text:find("^Yours 10, lowest 8, ") ~= nil)
Check("and only the ones over it count", nextButton.label == "Cancel Undercut (1)" and select(1, A.Counts()) == 1)
Press()
Check("the key cancels only an auction over it", #t.cancels == 3 and t.cancels[3] == 4)
Press()
Check("and then nothing", #t.cancels == 3)
onSetting("duration")
Check("another setting does not redraw it", refreshes == 1)

M.Settings.Set("aheadAllowed", 0)
Page.Hide()
Press()
Check("with My Auctions closed the key does nothing", #t.cancels == 3)
onSetting("aheadAllowed")
Check("and the setting redraws nothing", refreshes == 1)

print("market auctions page: " .. checks .. " checks passed")
