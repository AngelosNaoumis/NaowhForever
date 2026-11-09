-- Run with Lua 5.1 from the repository root: The Market's sortable column labels (View/Columns.lua).
local Load = dofile("Tools/regression/load_files.lua")
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local function Stub()
    local o = { scripts = {}, shown = true }
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:SetShown(on) self.shown = on end
    function o:SetTexCoord(...) self.coords = { ... } end
    function o:SetTextColor(r, g, b) self.color = { r = r, g = g, b = b } end
    function o:SetText(text) self.text = text end
    function o:CreateTexture() return Stub() end
    return setmetatable(o, { __index = function(_, key)
        if key:find("^Get") then return function() return 0 end end
        return function() end
    end })
end

local accent, muted, fg = { r = 0, g = 0.5, b = 1 }, { r = 0.5, g = 0.5, b = 0.5 }, { r = 1, g = 1, b = 1 }
local saved = {}
local settings = { Get = function(key) return saved[key] end, Set = function(key, value) saved[key] = value end }
local ns = { THEME = { accent = accent, muted = muted, fg = fg }, Market = { Style = { SMALL_SIZE = 11 } },
    Font = function() return Stub() end }
local env = setmetatable({ NaowhForever = ns, CreateFrame = function() return Stub() end }, { __index = _G })
env._G = env
Load({ "NaowhForever_Market/View/Columns.lua" }, env)
local Columns = ns.Market.Columns

local function Ids(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry.id end
    return table.concat(out, ",")
end

local function Rows()
    return { { id = 1, name = "b", worth = 30 }, { id = 2, name = "a", worth = 10 }, { id = 3, name = "", worth = 30 },
        { id = 4, name = "c" }, { id = 5, name = "a", worth = 20 } }
end
local function Worth(entry) return entry.worth end
local function Is(fs, c) return fs.color.r == c.r and fs.color.g == c.g and fs.color.b == c.b end
local function Name(entry) return entry.name end

Check("money sorts high to low, a missing value last, and ties keep the order they came in",
    Ids(Columns.SortBy(Rows(), Worth, false)) == "1,3,5,2,4")
Check("turned round it sorts low to high, a missing value still last",
    Ids(Columns.SortBy(Rows(), Worth, true)) == "2,5,1,3,4")
Check("names sort A to Z, an uncached name first, ties in their order",
    Ids(Columns.SortBy(Rows(), Name, true)) == "3,2,5,1,4")

local sorted = 0
local header = Columns.New(Stub(), settings, "sortTest", "worth", function() sorted = sorted + 1 end)
local name = Columns.Add(header, { key = "name", text = "Name", left = 8, up = true, value = Name })
local worth = Columns.Add(header, { key = "worth", text = "Worth", right = 8, width = 100, value = Worth })
local label = Columns.Label(header, "Materials", 200)
Check("a plain label shows its text", label.text == "Materials")

local key, up = Columns.Current(header)
Check("with nothing picked the list's own order shows, its column lit", key == "worth" and not up
    and Is(worth.label, accent) and worth.arrow.shown and not name.arrow.shown and Is(name.label, muted))
Check("and the list keeps that order", Ids(Columns.Sort(header, Rows())) == "1,3,5,2,4")

name.button.scripts.OnClick()
key, up = Columns.Current(header)
Check("a click sorts by that column in its own direction and keeps the choice", key == "name" and up
    and saved.sortTest == "name:up" and sorted == 1)
Check("the arrow moves to it", name.arrow.shown and not worth.arrow.shown and Is(name.label, accent))
Check("A to Z points the arrow up, as the auction house does", name.arrow.coords[3] == 1 and name.arrow.coords[4] == 0)
name.button.scripts.OnClick()
key, up = Columns.Current(header)
Check("a second click turns it round", key == "name" and not up and saved.sortTest == "name:down"
    and name.arrow.coords[3] == 0 and Ids(Columns.Sort(header, Rows())) == "4,1,2,5,3")
worth.button.scripts.OnClick()
key, up = Columns.Current(header)
Check("another column starts in its own direction", key == "worth" and not up and saved.sortTest == "worth:down")

Columns.SetDefault(header, "name")
Check("a picked column outlasts a new default", (Columns.Current(header)) == "worth")
saved.sortTest = "gone:up"
Check("a saved column that no longer exists falls back to the default", (Columns.Current(header)) == "name")
saved.sortTest = ""
Columns.SetText(header, "worth", "Profit")
Check("a column's text can change", worth.label.text == "Profit")

print("market columns: " .. checks .. " checks passed")
