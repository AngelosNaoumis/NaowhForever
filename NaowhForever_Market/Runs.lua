-- Runs.lua: your gathering runs: each herb and vein you loot, when and where, and what each node yields on average (Market.Runs).
local ns = _G.NaowhForever

local GetItemInfoInstant = C_Item.GetItemInfoInstant

local Market = ns.Market
local C = Market.C

local STORE = "marketRuns"
local YIELDS = "marketYields"
local KIND = 1
local SECONDS_PER_HOUR = 3600
local LOOT_EVENTS = { "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED" }

local events, lastGUID
local opened, taken = {}, {}
local takenGUID, takenID, takenKind

local Runs = {}
Market.Runs = Runs

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Mine()
    local mine = ns.Shared.CharacterData(STORE, true)
    if not mine then return end
    mine.runs = mine.runs or {}
    return mine
end

local function Yields()
    local account = ns.AccountSettings()
    account[YIELDS] = account[YIELDS] or {}
    return account[YIELDS]
end

local function Net(item)
    local scan = ns.AuctionPrice and ns.AuctionPrice(item)
    return scan and Market.AfterCut(scan) or 0
end

function Runs.Node(guid)
    local G = ns.Glimmer
    if not (G and type(guid) == "string" and Plain(guid)) then return end
    local id = tonumber(guid:match(G.C.GUID_OBJECT) or "")
    local node = id and G.NODES[id]
    if node and (node[KIND] == "herb" or node[KIND] == "ore") then return id, node[KIND] end
end

local function Skills()
    local Farm = Market.Farm
    return { herb = Farm.Skill("herb"), ore = Farm.Skill("ore") }
end

local function Learn(id, guid, items)
    local yields = Yields()
    local y = yields[id] or { n = 0, items = {} }
    yields[id] = y
    if guid ~= lastGUID then y.n = y.n + 1 end
    for item, qty in pairs(items) do y.items[item] = (y.items[item] or 0) + qty end
end

local function Where()
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local same = map and ns.Shared.Places.SameMap(map)
    if not pos then return same end
    local x, y = pos:GetXY()
    return same, x, y
end

function Runs.Record(id, kind, guid, items)
    local mine = Mine()
    if not mine then return end
    local now = time()
    local map, x, y = Where()
    local run = mine.runs[1]
    if not run or now - run.last > C.RUN_IDLE then
        lastGUID = nil
        run = { start = now, last = now, map = map, nodes = 0, events = {}, items = {}, from = Skills() }
        table.insert(mine.runs, 1, run)
        while #mine.runs > C.RUN_KEEP do table.remove(mine.runs) end
    end
    Learn(id, guid, items)
    run.last, run.to = now, Skills()
    if guid ~= lastGUID then run.nodes = run.nodes + 1 end
    lastGUID = guid
    for item, qty in pairs(items) do run.items[item] = (run.items[item] or 0) + qty end
    if #run.events < C.RUN_EVENTS then
        run.events[#run.events + 1] = { t = now - run.start, id = id, kind = kind, items = items, map = map, x = x, y = y }
    end
    Market.Farm.Changed()
    if Runs.onChange then Runs.onChange() end
end

local function Opened()
    wipe(opened)
    for slot = 1, GetNumLootItems() do
        local source = GetLootSourceInfo(slot)
        local node, kind = Runs.Node(source)
        local link = node and GetLootSlotLink(slot)
        local item = link and GetItemInfoInstant(link)
        local _, _, quantity = GetLootSlotInfo(slot)
        if item and quantity and quantity > 0 then
            opened[slot] = { guid = source, id = node, kind = kind, item = item, qty = quantity }
        end
    end
end

local function Cleared(slot)
    local loot = opened[slot]
    if not loot then return end
    opened[slot] = nil
    taken[loot.item] = (taken[loot.item] or 0) + loot.qty
    takenGUID, takenID, takenKind = loot.guid, loot.id, loot.kind
end

local function Closed()
    wipe(opened)
    if not next(taken) then return end
    local items = {}
    for item, qty in pairs(taken) do items[item] = qty end
    wipe(taken)
    Runs.Record(takenID, takenKind, takenGUID, items)
end

local function OnLoot(_, event, slot)
    if event == "LOOT_OPENED" then
        Opened()
    elseif event == "LOOT_SLOT_CLEARED" then
        Cleared(slot)
    else
        Closed()
    end
end

function Runs.List()
    local mine = Mine()
    return mine and mine.runs or {}
end

function Runs.Value(run)
    local total = 0
    for item, qty in pairs(run.items) do total = total + Net(item) * qty end
    return total
end

function Runs.Hours(run)
    return math.max(C.GATHER_SECONDS, run.last - run.start) / SECONDS_PER_HOUR
end

function Runs.EventValue(event)
    local total = 0
    for item, qty in pairs(event.items) do total = total + Net(item) * qty end
    return total
end

local function ByWorth(a, b)
    if a.worth ~= b.worth then return a.worth > b.worth end
    return a.item < b.item
end

function Runs.Haul(run, out)
    wipe(out)
    for item, qty in pairs(run.items) do
        local each = Net(item)
        out[#out + 1] = { item = item, qty = qty, each = each, worth = each * qty }
    end
    table.sort(out, ByWorth)
    return out
end

function Runs.NodeValue(id)
    local y = Yields()[id]
    if not (y and y.n >= C.YIELD_MIN) then return end
    local total = 0
    for item, qty in pairs(y.items) do total = total + Net(item) * qty end
    return total / y.n
end

function Runs.PerHour(map)
    local value, hours = 0, 0
    for _, run in ipairs(Runs.List()) do
        if run.map == map and run.last - run.start >= C.RUN_MIN then
            value, hours = value + Runs.Value(run), hours + Runs.Hours(run)
        end
    end
    if hours > 0 then return math.floor(value / hours) end
end

local function Apply()
    local on = Market.On()
    if on and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnLoot)
    end
    if not events then return end
    if not on then return events:UnregisterAllEvents() end
    for _, event in ipairs(LOOT_EVENTS) do events:RegisterEvent(event) end
end

Market.Settings.OnChange(function(key)
    if key == "enabled" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
