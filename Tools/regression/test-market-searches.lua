-- Run with Lua 5.1 from the repository root: The Market's saved searches. Lists are the account's and bounded; a
-- search keeps its text, exact name, category, level range, qualities and a max price; running one drives Blizzard's
-- own Buy tab (display mode, category, search text, then the browse query) and waits for the throttle; every browse
-- from Blizzard's window is kept in Recent, the last 30, newest first, each once; a list goes out as a string and
-- comes back only when every part of it is valid. On stubs with the real Shared files and libraries.
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")

local World = dofile("Tools/regression/market_world.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local FILTER = { UncollectedOnly = 1, UsableOnly = 2, ExactMatch = 5, PoorQuality = 6, CommonQuality = 7,
    UncommonQuality = 8, RareQuality = 9, EpicQuality = 10, LegendaryQuality = 11 }
local ALL = { 6, 7, 8, 9, 10, 11 }
local BUY, SELL = "buy", "sell"
local CATEGORIES = {
    { name = "Weapons", subCategories = { { name = "One-Handed Axes" }, { name = "Swords",
        subCategories = { { name = "One-Hand" } } } } },
    { name = "Armor" },
}

local function Setup()
    local t = World.Setup({ categories = CATEGORIES })
    local env = t.env
    env.Enum.AuctionHouseFilter = FILTER
    env.AuctionHouseFrameDisplayMode = { Buy = BUY }
    t.ns.Shared.Decode = nil
    t.ns.Lower = string.lower
    Load({ "Shared/Decode.lua", "Shared/Encode.lua" }, env)
    local ah = { mode = SELL, sent = {}, order = {} }
    local list = {}
    function list:SetSelectedCategory(a, b, c)
        self.picked = { a, b, c }
        ah.order[#ah.order + 1] = "category"
    end
    function list:GetSelectedCategory() return unpack(self.picked or {}, 1, 3) end
    function ah:GetCategoriesList() return list end
    function ah:SetDisplayMode(mode)
        self.mode = mode
        self.order[#self.order + 1] = "mode"
    end
    ah.SearchBar = { SearchBox = { GetSearchString = function() return ah.typed or "" end },
        FilterButton = { CalculateFiltersArray = function() return ah.filters or ALL end } }
    function ah.SearchBar:SetSearchText(text)
        ah.typed = text
        ah.order[#ah.order + 1] = "text"
    end
    function ah.SearchBar:GetLevelFilterRange() return ah.min or 0, ah.max or 0 end
    function ah:SendBrowseQuery(text, min, max, filters)
        self.sent[#self.sent + 1] = { text = text, min = min, max = max, filters = filters, mode = self.mode,
            category = list.picked }
        self.order[#self.order + 1] = "query"
    end
    env.AuctionHouseFrame = ah
    Load({ "NaowhForever_Market/Searches.lua" }, env)
    t.M.Settings.Set("enabled", true)
    return t, t.M.Searches, ah, list
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local t, S, ah, list = Setup()
local changes = 0
S.onChange = function() changes = changes + 1 end
Check("nothing is kept, or made in the saved data, until you save a search", #S.Lists() == 0 and #S.Recent() == 0
    and next(t.account) == nil)

local potions = S.NewList("  Potions  ")
Check("a new list is the account's, by its trimmed name", potions == 1 and S.Lists()[1].name == "Potions"
    and t.account.marketSearchLists.lists[1] == S.Lists()[1] and changes == 1)
Check("a list needs a name", S.NewList("   ") == nil and #S.Lists() == 1)
Check("a name is cut to its limit and loses colour codes", S.NewList("|cffff0000" .. string.rep("a", 40)) == 2
    and S.Lists()[2].name == "cffff0000" .. string.rep("a", S.MAX_NAME - 9))
local letter = "\208\150"
Check("a name cut at its limit never ends in half a letter", S.RenameList(2, letter:rep(11) .. "a" .. letter)
    and S.Lists()[2].name == letter:rep(11) .. "a" and S.RenameList(2, letter:rep(12))
    and S.Lists()[2].name == letter:rep(12))
local syllable = "\234\176\128"
Check("nor does a search's text", S.Add(potions, { text = syllable:rep(20) .. "a" .. syllable })
    and S.Lists()[potions].searches[1].text == syllable:rep(20) .. "a")
S.Remove(potions, 1)

Check("a search with just a name is kept", S.Add(potions, { text = "Healing Potion" }))
Check("so is one with every filter", S.Add(potions, { text = "sword", exact = true, cat = { 1, 2, 1 }, min = 30,
    max = 40, quality = { 2, 3 }, price = 50000 }))
Check("and a category with no name", S.Add(potions, { text = "", cat = { 2 } }))
local ok, why = S.Add(potions, { text = "HEALING potion" })
Check("the same search is not kept twice, whatever its case", not ok and why == "have")
Check("the same name with another filter is another search", S.Add(potions, { text = "Healing Potion", min = 10 }))
Check("a search with no name and no category is nothing", not S.Add(potions, { text = "" }))
Check("a level range the wrong way round is refused", not S.Add(potions, { text = "x", min = 40, max = 30 }))
Check("so is a quality that does not exist", not S.Add(potions, { text = "x", quality = { 2, 9 } }))
Check("and a field it does not know", not S.Add(potions, { text = "x", run = "print(1)" }))
Check("what is kept is a copy", (function()
    local mine = { text = "copy", cat = { 1 } }
    S.Add(potions, mine)
    mine.cat[1] = 2
    local kept = S.Lists()[potions].searches[5]
    return kept ~= mine and kept.cat[1] == 1
end)())

Check("a category is named by Blizzard's own list, step by step",
    S.CategoryName(S.Lists()[potions].searches[2]) == "Weapons > Swords > One-Hand"
    and S.CategoryName({ text = "", cat = { 2 } }) == "Armor")
Check("one that is no longer there has no name", S.CategoryName({ text = "", cat = { 1, 9 } }) == nil
    and S.CategoryName({ text = "x" }) == nil)

Check("a search moves up", S.Move(potions, 2, -1) and S.Lists()[potions].searches[1].text == "sword")
Check("and not past the ends", not S.Move(potions, 1, -1) and not S.Move(potions, 5, 1))
Check("its name, exact match and max price change", S.Change(potions, 1, "text", "axe")
    and S.Change(potions, 1, "exact", nil) and S.Change(potions, 1, "price", 120)
    and S.Lists()[potions].searches[1].text == "axe" and S.Lists()[potions].searches[1].exact == nil
    and S.Lists()[potions].searches[1].price == 120 and S.Lists()[potions].searches[1].min == 30)
Check("a change that makes it invalid is left out", not S.Change(potions, 1, "price", -5)
    and S.Lists()[potions].searches[1].price == 120)
S.Remove(potions, 5)
Check("a search is deleted", #S.Lists()[potions].searches == 4)
Check("a list is renamed", S.RenameList(2, "Gear") and S.Lists()[2].name == "Gear" and not S.RenameList(2, ""))

local full = S.NewList("Full")
for i = 1, S.MAX_SEARCHES do S.Add(full, { text = "item " .. i }) end
ok, why = S.Add(full, { text = "one more" })
Check("a list holds a bounded number of searches", #S.Lists()[full].searches == S.MAX_SEARCHES and not ok
    and why == "full")
S.DeleteList(full)
Check("a list is deleted", #S.Lists() == 2)
for i = 3, S.MAX_LISTS do S.NewList("List " .. i) end
Check("and there is a bounded number of lists", #S.Lists() == S.MAX_LISTS and S.NewList("Too many") == nil)

S.Run({ text = "sword", exact = true, cat = { 1, 2, 1 }, min = 30, max = 40, quality = { 2, 3 }, price = 50000 })
local sent = ah.sent[1]
Check("running a search goes to Blizzard's Buy tab first, then its category, its search box, then the query",
    table.concat(ah.order, ",") == "mode,category,text,query" and sent.mode == BUY and ah.typed == "sword")
Check("with its category picked in Blizzard's list", Same(list.picked, { 1, 2, 1 }))
Check("its level range", sent.text == "sword" and sent.min == 30 and sent.max == 40)
Check("and its qualities and exact match as Blizzard's filters", Same(sent.filters,
    { FILTER.UncommonQuality, FILTER.RareQuality, FILTER.ExactMatch }))
Check("The Market never sends the browse itself", #t.browses == 0)

S.Run({ text = "Linen Cloth" })
sent = ah.sent[2]
Check("a plain search clears the category and the levels and takes every quality", #list.picked == 0
    and sent.min == 0 and sent.max == 0 and Same(sent.filters, ALL))
Check("each run hands Blizzard a filter list of its own", ah.sent[1].filters ~= sent.filters)
S.Run({ text = "gone", cat = { 1, 9 } })
Check("a category that is no longer there is left out", #list.picked == 0 and ah.sent[3].text == "gone")

t.ready = false
S.Run({ text = "wait" })
Check("while the auction house is busy nothing is sent", #ah.sent == 3)
S.Run({ text = "newer" })
t.ready = true
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("when it is ready the last search asked for goes, once", #ah.sent == 4 and ah.sent[4].text == "newer")
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("and it stops listening", #ah.sent == 4)
t.ready = false
S.Run({ text = "dropped" })
S.Stop()
t.ready = true
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("leaving the page drops a search still waiting", #ah.sent == 4)

Check("searches run before the hook is on are not in Recent", #S.Recent() == 0)
S.Watch()
S.Watch()
local hooked = 0
for _, name in ipairs(t.hooks) do
    if name == "SendBrowseQuery" then hooked = hooked + 1 end
end
Check("Blizzard's browse is hooked once, after it, never replaced", hooked == 1)
list.picked = { 1, 2 }
ah:SendBrowseQuery("Blade", 20, 0, { 9, 10, FILTER.UsableOnly })
local recent = S.Recent()
Check("a search in Blizzard's window is kept in Recent with its filters", #recent == 1 and recent[1].text == "Blade"
    and recent[1].min == 20 and recent[1].max == nil and Same(recent[1].cat, { 1, 2 })
    and Same(recent[1].quality, { 3, 4 }) and recent[1].exact == nil)
list.picked = nil
ah:SendBrowseQuery("Copper Ore", 0, 0, ALL)
Check("every quality is no quality filter", S.Recent()[1].text == "Copper Ore" and S.Recent()[1].quality == nil
    and S.Recent()[1].cat == nil and #S.Recent() == 2)
ah:SendBrowseQuery("", 0, 0, ALL)
Check("an empty browse is not a search", #S.Recent() == 2)
list.picked = { 1, 2 }
ah:SendBrowseQuery("blade", 20, 0, { 9, 10 })
Check("a search run again moves to the top, once", #S.Recent() == 2 and S.Recent()[1].text == "blade")
list.picked = nil
for i = 1, 40 do ah:SendBrowseQuery("many " .. i, 0, 0, ALL) end
Check("Recent keeps the last 30, newest first", #S.Recent() == 30 and S.Recent()[1].text == "many 40"
    and S.Recent()[30].text == "many 11")
S.Run({ text = "from a list", price = 99 })
Check("a saved search you run is recent too, without its max price", S.Recent()[1].text == "from a list"
    and S.Recent()[1].price == nil)
t.M.Settings.Set("enabled", false)
ah:SendBrowseQuery("while off", 0, 0, ALL)
Check("with The Market off nothing is noted", S.Recent()[1].text == "from a list")
t.M.Settings.Set("enabled", true)

ah.typed, ah.min, ah.max, ah.filters = "  Wand ", 10, 20, { 8, 9, 10, 11 }
list.picked = { 1 }
local current = S.Current()
Check("the search in Blizzard's window is read from its box, level range, filters and category",
    current.text == "Wand" and current.min == 10 and current.max == 20 and Same(current.cat, { 1 })
    and Same(current.quality, { 2, 3, 4, 5 }))
ah.typed, ah.min, ah.max, ah.filters, list.picked = "", 0, 0, nil, nil
Check("an empty window is no search", S.Current() == nil)

S = select(2, Setup())
local gear = S.NewList("Gear")
S.Add(gear, { text = "sword", exact = true, cat = { 1, 2, 1 }, min = 30, max = 40, quality = { 2, 3 }, price = 50000 })
S.Add(gear, { text = "", cat = { 2 } })
local code = S.Export(gear)
Check("a list exports as one printable string", code:find("^!NFMS1!%S+$") ~= nil)
local index = S.Import("  " .. code .. "\n")
local got = S.Lists()[index]
Check("and imports as a new list, whitespace around it ignored", index == 2 and got.name == "Gear"
    and #got.searches == 2 and got ~= S.Lists()[gear])
local first = got.searches[1]
Check("with every search as it was", first.text == "sword" and first.exact == true and Same(first.cat, { 1, 2, 1 })
    and first.min == 30 and first.max == 40 and Same(first.quality, { 2, 3 }) and first.price == 50000
    and got.searches[2].text == "" and Same(got.searches[2].cat, { 2 }))
S.Add(S.NewList("Empty"), { text = "x" })
S.Remove(3, 1)
Check("an empty list goes out and comes back empty", #S.Lists()[S.Import(S.Export(3))].searches == 0)

local function Pack(value)
    return "!NFMS1!" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(value)))
end
local function Refused(label, text)
    local before = #S.Lists()
    local result, reason = S.Import(text)
    Check(label .. " is refused whole", result == nil and reason == "damaged" and #S.Lists() == before)
end
Refused("text that is not a string of ours", "hello")
Refused("another feature's string", "!NFCV1!" .. code:sub(8))
Refused("a damaged string", code:sub(1, #code - 6))
Refused("a string that is not text", 12)
Refused("another version", Pack({ v = 2, name = "x", searches = {} }))
Refused("a list with no name", Pack({ v = 1, name = "", searches = {} }))
Refused("a field it does not know", Pack({ v = 1, name = "x", searches = {}, extra = 1 }))
Refused("searches that are not a list", Pack({ v = 1, name = "x", searches = { a = { text = "x" } } }))
Refused("a search that is not a table", Pack({ v = 1, name = "x", searches = { "sword" } }))
Refused("a search with a field it does not know", Pack({ v = 1, name = "x",
    searches = { { text = "x", onRun = "RunScript" } } }))
Refused("a search whose name is not text", Pack({ v = 1, name = "x", searches = { { text = 5 } } }))
Refused("a level that is not a whole number", Pack({ v = 1, name = "x", searches = { { text = "x", min = 1.5 } } }))
Refused("a level out of range", Pack({ v = 1, name = "x", searches = { { text = "x", max = 100000 } } }))
Refused("a category that is not a short list of numbers", Pack({ v = 1, name = "x",
    searches = { { text = "x", cat = { 1, 2, 3, 4 } } } }))
Refused("a category with a table in it", Pack({ v = 1, name = "x", searches = { { text = "x", cat = { {} } } } }))
Refused("an exact match that is not true", Pack({ v = 1, name = "x", searches = { { text = "x", exact = "yes" } } }))
Refused("a negative max price", Pack({ v = 1, name = "x", searches = { { text = "x", price = -1 } } }))
Refused("one bad search among good ones", Pack({ v = 1, name = "x",
    searches = { { text = "good" }, { text = "x", quality = { 3, 2 } } } }))
local many = {}
for i = 1, S.MAX_SEARCHES + 1 do many[i] = { text = "item " .. i } end
Refused("more searches than a list holds", Pack({ v = 1, name = "x", searches = many }))
Refused("a decompression bomb", "!NFMS1!" .. LD:EncodeForPrint(LD:CompressDeflate(string.rep("A", 1024 * 1024))))

index = S.Import(Pack({ v = 1, name = "Twice |cffff0000red", searches = { { text = "Ore" }, { text = "ore" },
    { text = "a|Hlink|hb" } } }))
got = S.Lists()[index]
Check("a search listed twice comes in once, and names lose their codes", #got.searches == 2
    and got.name == "Twice cffff0000red" and got.searches[2].text == "aHlinkhb")
for _ = #S.Lists() + 1, S.MAX_LISTS do S.NewList("filler") end
local result, reason = S.Import(code)
Check("with every list taken an import says so and adds nothing", result == nil and reason == "full"
    and #S.Lists() == S.MAX_LISTS)

print("market searches: " .. checks .. " checks passed")
