-- Searches.lua: your searches kept in named lists and the last ones you ran, run in Blizzard's Buy tab, and a list as a string to share (Market.Searches).
local ns = _G.NaowhForever

local Market = ns.Market
local Decode, Encode = ns.Shared.Decode, ns.Shared.Encode

local STORE = "marketSearchLists"
local MAX_LISTS, MAX_SEARCHES, MAX_RECENT = 20, 100, 30
local MAX_NAME, MAX_TEXT = 24, 63
local MAX_LEVEL, MAX_PRICE = 999, 9999999999
local MAX_PATH, MAX_INDEX = 3, 99
local QUALITIES = 6
local ALL_QUALITIES = { 0, 1, 2, 3, 4, 5 }
local PATH_JOIN = " > "
local UTF8_LAST = "[\192-\255][\128-\191]*$"
local UTF8_FOUR, UTF8_THREE = 240, 224
local SHARE = "!NFMS1!"
local SHARE_PATTERN = "^%s*" .. SHARE .. "(%S+)%s*$"
local VERSION = 1
local SHARE_FIELDS = { v = true, name = true, searches = true }
local SEARCH_FIELDS = { text = true, exact = true, cat = true, min = true, max = true, quality = true, price = true }
local SEARCH_VALUES, SHARE_VALUES = 16, 3
local LIMITS = { maxChars = 100000, maxBytes = 262144, maxDepth = 3, maxValues = MAX_SEARCHES * SEARCH_VALUES + SHARE_VALUES }
local READY = "AUCTION_HOUSE_THROTTLED_SYSTEM_READY"
local FILTER = Enum.AuctionHouseFilter
local QUALITY_FILTERS = { [0] = FILTER.PoorQuality, FILTER.CommonQuality, FILTER.UncommonQuality,
    FILTER.RareQuality, FILTER.EpicQuality, FILTER.LegendaryQuality }
local NONE = {}

local names, on = {}, {}
local pending, events, hooked

local Searches = { MAX_LISTS = MAX_LISTS, MAX_SEARCHES = MAX_SEARCHES, MAX_NAME = MAX_NAME, MAX_TEXT = MAX_TEXT,
    MAX_PRICE = MAX_PRICE }
Market.Searches = Searches

local function Changed()
    if Searches.onChange then Searches.onChange() end
end

local function Store(create)
    local account = ns.AccountSettings()
    if not account[STORE] and create then account[STORE] = { lists = {}, recent = {} } end
    return account[STORE]
end

local function Whole(value, low, high)
    return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
end

local function Numbers(list, most, low, high, rising)
    if type(list) ~= "table" or #list < 1 or #list > most then return nil end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    if count ~= #list then return nil end
    local out = {}
    for i, n in ipairs(list) do
        if not Whole(n, rising and i > 1 and out[i - 1] + 1 or low, high) then return nil end
        out[i] = n
    end
    return out
end

local function Text(text, max)
    text = Decode.Text(text, max)
    local at = text and text:find(UTF8_LAST)
    if not at then return text end
    local lead = text:byte(at)
    local length = lead >= UTF8_FOUR and 4 or lead >= UTF8_THREE and 3 or 2
    if #text - at + 1 >= length then return text end
    return (text:sub(1, at - 1):gsub("%s+$", ""))
end

local function Clean(search)
    if type(search) ~= "table" or type(search.text) ~= "string" then return nil end
    for field in pairs(search) do
        if not SEARCH_FIELDS[field] then return nil end
    end
    local out = { text = Text(search.text, MAX_TEXT) }
    if search.exact ~= nil then
        if search.exact ~= true then return nil end
        out.exact = true
    end
    if search.cat ~= nil then
        out.cat = Numbers(search.cat, MAX_PATH, 1, MAX_INDEX)
        if not out.cat then return nil end
    end
    if search.quality ~= nil then
        out.quality = Numbers(search.quality, QUALITIES - 1, 0, QUALITIES - 1, true)
        if not out.quality then return nil end
    end
    if search.min ~= nil and not Whole(search.min, 1, MAX_LEVEL) then return nil end
    if search.max ~= nil and not Whole(search.max, search.min or 1, MAX_LEVEL) then return nil end
    if search.price ~= nil and not Whole(search.price, 1, MAX_PRICE) then return nil end
    out.min, out.max, out.price = search.min, search.max, search.price
    if out.text == "" and not out.cat then return nil end
    return out
end

local function Key(search)
    return table.concat({ ns.Lower(search.text), search.exact and 1 or 0, table.concat(search.cat or NONE, "."),
        search.min or 0, search.max or 0, table.concat(search.quality or NONE, ".") }, "|")
end

local function Find(searches, search)
    local key = Key(search)
    for i, old in ipairs(searches) do
        if Key(old) == key then return i end
    end
end

local function FromQuery(text, min, max, filters, category, sub, subSub)
    local search = { text = text or "" }
    if (min or 0) > 0 then search.min = min end
    if (max or 0) > 0 then search.max = max end
    if category then search.cat = { category, sub, subSub } end
    wipe(on)
    for _, filter in ipairs(filters or NONE) do on[filter] = true end
    local quality = {}
    for _, q in ipairs(ALL_QUALITIES) do
        if on[QUALITY_FILTERS[q]] then quality[#quality + 1] = q end
    end
    if #quality > 0 and #quality < QUALITIES then search.quality = quality end
    if on[FILTER.ExactMatch] then search.exact = true end
    return Clean(search)
end

local function Path(search)
    wipe(names)
    local nodes = AuctionCategories
    for i, index in ipairs(search.cat or NONE) do
        local node = nodes and nodes[index]
        if not node then return nil end
        names[i] = node.name
        nodes = node.subCategories
    end
    return search.cat
end

local function Filters(search)
    local filters = {}
    for i, q in ipairs(search.quality or ALL_QUALITIES) do filters[i] = QUALITY_FILTERS[q] end
    if search.exact then filters[#filters + 1] = FILTER.ExactMatch end
    return filters
end

local function Send(search)
    local ah = _G.AuctionHouseFrame
    local path = Path(search) or NONE
    ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
    ah:GetCategoriesList():SetSelectedCategory(path[1], path[2], path[3])
    ah.SearchBar:SetSearchText(search.text)
    ah:SendBrowseQuery(search.text, search.min or 0, search.max or 0, Filters(search))
end

local function OnReady()
    local search = pending
    Searches.Stop()
    if search then Send(search) end
end

local function OnBrowse(ah, text, min, max, filters)
    if not Market.On() then return end
    local search = FromQuery(text, min, max, filters, ah:GetCategoriesList():GetSelectedCategory())
    if search then Searches.Note(search) end
end

function Searches.Lists()
    local store = Store()
    return store and store.lists or NONE
end

function Searches.Recent()
    local store = Store()
    return store and store.recent or NONE
end

function Searches.CategoryName(search)
    if not (search.cat and Path(search)) then return nil end
    return table.concat(names, PATH_JOIN)
end

function Searches.Current()
    local ah = _G.AuctionHouseFrame
    local bar = ah.SearchBar
    local min, max = bar:GetLevelFilterRange()
    return FromQuery(bar.SearchBox:GetSearchString(), min, max, bar.FilterButton:CalculateFiltersArray(),
        ah:GetCategoriesList():GetSelectedCategory())
end

function Searches.Note(search)
    local recent = Store(true).recent
    local at = Find(recent, search)
    if at then table.remove(recent, at) end
    table.insert(recent, 1, search)
    recent[MAX_RECENT + 1] = nil
    Changed()
end

function Searches.NewList(name)
    name = Text(name, MAX_NAME)
    local lists = Store(true).lists
    if not name or name == "" or #lists >= MAX_LISTS then return nil end
    lists[#lists + 1] = { name = name, searches = {} }
    Changed()
    return #lists
end

function Searches.RenameList(index, name)
    name = Text(name, MAX_NAME)
    if not name or name == "" then return false end
    Searches.Lists()[index].name = name
    Changed()
    return true
end

function Searches.DeleteList(index)
    table.remove(Searches.Lists(), index)
    Changed()
end

function Searches.Add(index, search)
    local searches = Searches.Lists()[index].searches
    search = Clean(search)
    if not search then return false end
    if #searches >= MAX_SEARCHES then return false, "full" end
    if Find(searches, search) then return false, "have" end
    searches[#searches + 1] = search
    Changed()
    return true
end

function Searches.Remove(index, at)
    table.remove(Searches.Lists()[index].searches, at)
    Changed()
end

function Searches.Move(index, at, by)
    local searches = Searches.Lists()[index].searches
    local to = at + by
    if not (searches[at] and searches[to]) then return false end
    searches[at], searches[to] = searches[to], searches[at]
    Changed()
    return true
end

function Searches.Change(index, at, field, value)
    local searches = Searches.Lists()[index].searches
    local changed = {}
    for k, v in pairs(searches[at]) do changed[k] = v end
    changed[field] = value
    changed = Clean(changed)
    if not changed then return false end
    searches[at] = changed
    Changed()
    return true
end

function Searches.Export(index)
    local list = Searches.Lists()[index]
    return Encode.String(SHARE, { v = VERSION, name = list.name, searches = list.searches })
end

function Searches.Import(text)
    local body = type(text) == "string" and text:match(SHARE_PATTERN)
    local data = body and Decode.String(body, LIMITS)
    if type(data) ~= "table" or data.v ~= VERSION or type(data.searches) ~= "table" then return nil, "damaged" end
    for field in pairs(data) do
        if not SHARE_FIELDS[field] then return nil, "damaged" end
    end
    local name = Text(data.name, MAX_NAME)
    if not name or name == "" or #data.searches > MAX_SEARCHES then return nil, "damaged" end
    local count = 0
    for _ in pairs(data.searches) do count = count + 1 end
    if count ~= #data.searches then return nil, "damaged" end
    local searches = {}
    for _, shared in ipairs(data.searches) do
        local search = Clean(shared)
        if not search then return nil, "damaged" end
        if not Find(searches, search) then searches[#searches + 1] = search end
    end
    local lists = Store(true).lists
    if #lists >= MAX_LISTS then return nil, "full" end
    lists[#lists + 1] = { name = name, searches = searches }
    Changed()
    return #lists
end

function Searches.Run(search)
    if C_AuctionHouse.IsThrottledMessageSystemReady() then
        Searches.Stop()
        return Send(search)
    end
    pending = search
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnReady)
    end
    events:RegisterEvent(READY)
end

function Searches.Stop()
    pending = nil
    if events then events:UnregisterAllEvents() end
end

function Searches.Watch()
    if hooked then return end
    hooked = true
    hooksecurefunc(_G.AuctionHouseFrame, "SendBrowseQuery", OnBrowse)
end
