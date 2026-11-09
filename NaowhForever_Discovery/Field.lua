-- Field.lua: the Field Journal's rules: the fish you catch, the herbs you pick and the dishes you cook, kept for each character (Discovery.Field).
local ns = _G.NaowhForever

local GetItemInfoInstant = C_Item.GetItemInfoInstant

local Discovery = ns.Discovery
local S = Discovery.Settings
local Library = Discovery.Library

local STORE = "discoveryField"
local PAGES = { "fish", "herbs", "dishes" }
local RANK_CAPS = { 75, 150, 225 }
local SPOT_NAME, SPOT_MAP, SPOT_X, SPOT_Y, SPOT_GIVER = 1, 2, 3, 4, 5
local ZONE_STRIDE = 2
local GUID_OBJECT = "^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"
local LOOT_EVENTS = { "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED" }
local CRAFT_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE" }
local CAST = "UNIT_SPELLCAST_SUCCEEDED"
local TEXT_LIST = ", "
local TEXT_CHANCE = "%s %d%%"
local TEXT_ALSO_SCHOOLS = ns.L("%s, and from schools of fish")
local TEXT_SCHOOLS_ONLY = ns.L("Caught from schools of fish")
local TEXT_TRAINER = ns.L("Taught by cooking trainers")
local TEXT_SOLD_BY = ns.L("Sold by %s, %s")
local TEXT_SOLD = ns.L("Sold by a vendor")
local TEXT_QUEST = ns.L("From the quest %s")
local TEXT_DROP = ns.L("Drops from %s")
local TEXT_WORLD = ns.L("A world drop")
local TEXT_UNKNOWN = ns.L("Where to learn it is not known yet")
local TEXT_OTHER_FACTION = ns.L("Only for the other faction")

local Field = {}
Discovery.Field = Field

local lookup, events
local lootPage, lootItem, lootQty = {}, {}, {}
local names = {}
local listeners = {}

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Lookup()
    if lookup then return lookup end
    lookup = { fish = {}, herbs = {}, dishes = {}, nodes = {} }
    for _, entry in ipairs(ns.FieldJournal.fish) do lookup.fish[entry.item] = entry end
    for _, entry in ipairs(ns.FieldJournal.herbs) do
        lookup.herbs[entry.item] = entry
        for _, node in ipairs(entry.nodes) do lookup.nodes[node] = true end
    end
    for _, entry in ipairs(ns.FieldJournal.dishes) do lookup.dishes[entry.spell] = entry end
    return lookup
end

local function Store(create)
    local mine = ns.Shared.CharacterData(STORE, create)
    if mine and create then
        for _, page in ipairs(PAGES) do mine[page] = mine[page] or {} end
    end
    return mine
end

local function Changed(page)
    for _, fn in ipairs(listeners) do fn(page) end
end

local function Add(page, id, n)
    local mine = Store(true)
    if not mine then return end
    mine[page][id] = (mine[page][id] or 0) + n
    Changed(page)
end

local function FromNode(guid)
    if type(guid) ~= "string" or not Plain(guid) then return false end
    return Lookup().nodes[tonumber(guid:match(GUID_OBJECT) or "")] == true
end

local function ItemIn(slot)
    local link = GetLootSlotLink(slot)
    if not (link and Plain(link)) then return end
    return (GetItemInfoInstant(link))
end

local function Forget()
    wipe(lootPage)
    wipe(lootItem)
    wipe(lootQty)
end

local function Opened()
    Forget()
    local fishing = IsFishingLoot()
    local known = Lookup()
    for slot = 1, GetNumLootItems() do
        local item = ItemIn(slot)
        local page
        if fishing and known.fish[item] then
            page = "fish"
        elseif not fishing and known.herbs[item] and FromNode(GetLootSourceInfo(slot)) then
            page = "herbs"
        end
        local _, _, quantity = GetLootSlotInfo(slot)
        if page and Plain(quantity) and quantity and quantity > 0 then
            lootPage[slot], lootItem[slot], lootQty[slot] = page, item, quantity
        end
    end
end

local function Cleared(slot)
    local page = lootPage[slot]
    if not page then return end
    lootPage[slot] = nil
    Add(page, lootItem[slot], lootQty[slot])
end

local function OnEvent(_, event, a, _, spellID)
    if event == "LOOT_OPENED" then
        Opened()
    elseif event == "LOOT_SLOT_CLEARED" then
        Cleared(a)
    elseif event == "LOOT_CLOSED" then
        Forget()
    elseif event == "TRADE_SKILL_SHOW" then
        events:RegisterUnitEvent(CAST, "player")
    elseif event == "TRADE_SKILL_CLOSE" then
        events:UnregisterEvent(CAST)
    elseif event == CAST and Plain(spellID) and Lookup().dishes[spellID] then
        Add("dishes", spellID, 1)
    end
end

function Field.On()
    return S.Get("enabled") == true and S.Get("fieldJournal") == true
end

function Field.Entries(page)
    return ns.FieldJournal[page]
end

function Field.Key(entry)
    return entry.spell or entry.item
end

function Field.Count(page, entry)
    local mine = Store(false)
    local done = mine and mine[page]
    return done and done[Field.Key(entry)]
end

function Field.Had(page, entry)
    return Field.Count(page, entry) ~= nil
end

function Field.SetHad(page, entry, had)
    local mine = Store(true)
    if not mine then return end
    local key = Field.Key(entry)
    if had then
        mine[page][key] = mine[page][key] or 0
    elseif mine[page][key] == 0 then
        mine[page][key] = nil
    end
    Changed(page)
end

function Field.Progress(page)
    local mine = Store(false)
    local had = mine and mine[page]
    local list = Field.Entries(page)
    local done = 0
    if had then
        for _, entry in ipairs(list) do
            if had[Field.Key(entry)] ~= nil then done = done + 1 end
        end
    end
    return done, #list
end

function Field.Rank(skill)
    if not skill then return nil end
    for i, cap in ipairs(RANK_CAPS) do
        if skill <= cap then return i end
    end
    return #RANK_CAPS + 1
end

local function Zones(entry, withChance)
    wipe(names)
    local zones = entry.zones or {}
    local stride = withChance and ZONE_STRIDE or 1
    for i = 1, #zones, stride do
        local name = Library.ZoneName(zones[i])
        if withChance then name = TEXT_CHANCE:format(name, math.max(1, math.floor(zones[i + 1] + 0.5))) end
        names[#names + 1] = name
    end
    return table.concat(names, TEXT_LIST)
end

function Field.Source(entry)
    return entry[Library.Side()] or entry.B
end

local function DishWhere(entry)
    local how, from = entry.how, Field.Source(entry)
    if how == "trainer" then return TEXT_TRAINER end
    if how == "world" then return TEXT_WORLD end
    if how == "unknown" then return TEXT_UNKNOWN end
    if not from then
        if how == "vendor" and not (entry.A or entry.H) then return TEXT_SOLD end
        return TEXT_OTHER_FACTION
    end
    if how == "vendor" then return TEXT_SOLD_BY:format(from[SPOT_NAME], Library.ZoneName(from[SPOT_MAP])) end
    if how == "quest" then return TEXT_QUEST:format(from[SPOT_NAME]) end
    return TEXT_DROP:format(from[SPOT_NAME])
end

function Field.Where(page, entry)
    if page == "dishes" then return DishWhere(entry) end
    if page == "herbs" then return Zones(entry, false) end
    if not entry.zones then return TEXT_SCHOOLS_ONLY end
    local zones = Zones(entry, true)
    return entry.schools and TEXT_ALSO_SCHOOLS:format(zones) or zones
end

function Field.Spot(entry)
    local from = Field.Source(entry)
    if from and from[SPOT_MAP] then
        return from[SPOT_GIVER] or from[SPOT_NAME], from[SPOT_MAP], from[SPOT_X], from[SPOT_Y]
    end
end

function Field.Waypoint(entry)
    local name, map, x, y = Field.Spot(entry)
    if name then Library.Waypoint(name, map, x, y, nil, C_Item.GetItemIconByID(entry.item)) end
end

function Field.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Apply()
    if not Field.On() then
        if events then events:UnregisterAllEvents() end
        Forget()
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(LOOT_EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(CRAFT_EVENTS) do events:RegisterEvent(event) end
end

S.OnChange(function(key)
    if key ~= "enabled" and key ~= "fieldJournal" then return end
    Apply()
    Changed()
end)
hooksecurefunc(ns, "Apply", Apply)
