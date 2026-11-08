-- Farm.lua: where to gather for your skills: each zone's herbs and veins priced from your last scan, and a loop through one (Market.Farm).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C
local S = Market.Settings
local Runs = Market.Runs

local KIND, NEED, NAME = 1, 2, 3
local GATHER_ITEM = 3
local SECONDS_PER_MINUTE, MINUTES_PER_HOUR = 60, 60
local PERCENT = 100

local itemOf = {}
local zones, spots, loop = {}, {}, {}
local zonePool, spotPool = {}, {}
local cachedZones, cachedMap

local Farm = { zones = zones, spots = spots, loop = loop }
Market.Farm = Farm

local function Glimmer()
    local G = ns.Glimmer
    if not (G and G.Spots and G.Spots.Load()) then return end
    return G
end

function Farm.Ready()
    local P = ns.Professions
    return Glimmer() ~= nil and P ~= nil and P.GatherNodes ~= nil
end

local function Item(objectID, node)
    local item = itemOf[objectID]
    if item == nil then
        local P = ns.Professions
        local entry = P and P.GatherNodes and P.GatherNodes[node[NAME]]
        item = entry and entry[GATHER_ITEM] or false
        itemOf[objectID] = item
    end
    return item or nil
end

local function Net(item)
    local scan = item and ns.AuctionPrice and ns.AuctionPrice(item)
    return scan and Market.AfterCut(scan) or 0
end

local function Value(objectID, kind, item)
    return Runs.NodeValue(objectID) or Net(item) * (C.YIELD[kind] or 1)
end

local function Wanted(kind)
    if kind == "herb" then return S.Get("farmHerbs") end
    if kind == "ore" then return S.Get("farmVeins") end
    return false
end

function Farm.Skill(kind)
    local G = ns.Glimmer
    return G and G.Target and G.Target.Skill(kind) or 0
end

function Farm.NodeValue(objectID)
    local G = ns.Glimmer
    local node = G and G.NODES[objectID]
    if not node then return 0 end
    return Value(objectID, node[KIND], Item(objectID, node))
end

local function Hours(yards, stops)
    local seconds = yards / C.TRAVEL_SPEED + stops * C.OCCUPANCY * C.GATHER_SECONDS
    return seconds / SECONDS_PER_MINUTE / MINUTES_PER_HOUR
end

local function PerHour(value, yards, stops)
    local hours = Hours(yards, stops)
    return hours > 0 and math.floor(value * C.OCCUPANCY / hours) or 0
end

local function Tally(zone, item, value)
    for _, top in ipairs(zone.items) do
        if top.item == item then
            top.value = top.value + value
            return
        end
    end
    zone.items[#zone.items + 1] = { item = item, value = value }
end

local function ByValue(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.item < b.item
end

local function ReadZone(G, mapID, all, skill)
    local zone = table.remove(zonePool) or { items = {} }
    wipe(zone.items)
    zone.map, zone.stops, zone.value = mapID, 0, 0
    for i = 1, #all, 3 do
        local node = G.NODES[all[i]]
        local kind = node and node[KIND]
        if kind and Wanted(kind) and skill[kind] >= node[NEED] then
            local item = Item(all[i], node)
            local value = Value(all[i], kind, item)
            zone.stops, zone.value = zone.stops + 1, zone.value + value
            if item and value > 0 then Tally(zone, item, value) end
        end
    end
    if zone.stops == 0 then
        zonePool[#zonePool + 1] = zone
        return
    end
    local width, height = C_Map.GetMapWorldSize(mapID)
    local yards = C.TOUR_FACTOR * math.sqrt(zone.stops * width * height)
    zone.minutes = Hours(yards, zone.stops) * MINUTES_PER_HOUR
    zone.perHour = PerHour(zone.value, yards, zone.stops)
    zone.measured = Runs.PerHour(mapID)
    zone.rank = zone.measured or zone.perHour
    table.sort(zone.items, ByValue)
    local info = C_Map.GetMapInfo(mapID)
    zone.name = info and info.name or ""
    zones[#zones + 1] = zone
end

local function Richer(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    return a.map < b.map
end

local function Key()
    local at = ns.AuctionScanTime and ns.AuctionScanTime() or 0
    return table.concat({ at, Farm.Skill("herb"), Farm.Skill("ore"), tostring(S.Get("farmHerbs")),
        tostring(S.Get("farmVeins")) }, ":")
end

function Farm.Zones()
    local G = Glimmer()
    local byMap = ns.GlimmerSpots
    if not byMap then return zones end
    local key = Key()
    if key == cachedZones then return zones end
    cachedZones = key
    for i = #zones, 1, -1 do zonePool[#zonePool + 1] = table.remove(zones, i) end
    local skill = { herb = Farm.Skill("herb"), ore = Farm.Skill("ore") }
    for mapID, all in pairs(byMap) do ReadZone(G, mapID, all, skill) end
    table.sort(zones, Richer)
    return zones
end

local function Gathered(G, mapID)
    local picked = {}
    for _, entry in pairs(G.Spots.Gathered(mapID) or {}) do
        picked[entry.id .. ":" .. entry.x .. ":" .. entry.y] = entry.last
    end
    return picked
end

local function Distance(width, height, a, b)
    local dx, dy = (a.x - b.x) * width, (a.y - b.y) * height
    return math.sqrt(dx * dx + dy * dy)
end

local function Here(mapID)
    local map = C_Map.GetBestMapForUnit("player")
    if not map or ns.Shared.Places.SameMap(map) ~= mapID then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    return { x = x, y = y }
end

local function Tour(mapID, width, height)
    wipe(loop)
    local left = {}
    for _, spot in ipairs(spots) do
        if spot.can and spot.wanted then left[#left + 1] = spot end
    end
    if #left == 0 then return 0 end
    local at, yards = Here(mapID), 0
    local first = 1
    if at then
        local best
        for i, spot in ipairs(left) do
            local d = Distance(width, height, at, spot)
            if not best or d < best then best, first = d, i end
        end
    end
    local current = table.remove(left, first)
    loop[1] = current
    while #left > 0 do
        local best, pick
        for i, spot in ipairs(left) do
            local d = Distance(width, height, current, spot)
            if not best or d < best then best, pick = d, i end
        end
        yards = yards + best
        current = table.remove(left, pick)
        loop[#loop + 1] = current
    end
    return yards + Distance(width, height, current, loop[1])
end

function Farm.Zone(mapID)
    local G = Glimmer()
    for i = #spots, 1, -1 do spotPool[#spotPool + 1] = table.remove(spots, i) end
    wipe(loop)
    cachedMap = mapID
    local byMap = ns.GlimmerSpots
    local all = G and byMap and byMap[mapID]
    if not all then return end
    local picked, scale = Gathered(G, mapID), G.C.SPOT_SCALE
    local now = time()
    local skill = { herb = Farm.Skill("herb"), ore = Farm.Skill("ore") }
    local most = 0
    for i = 1, #all, 3 do
        local id = all[i]
        local node = G.NODES[id]
        local kind = node and node[KIND]
        if kind == "herb" or kind == "ore" then
            local spot = table.remove(spotPool) or {}
            spot.id, spot.kind, spot.need = id, kind, node[NEED]
            spot.x, spot.y = all[i + 1] / scale, all[i + 2] / scale
            spot.item = Item(id, node)
            spot.value = Value(id, kind, spot.item)
            spot.can, spot.wanted = skill[kind] >= node[NEED], Wanted(kind)
            local last = picked[id .. ":" .. all[i + 1] .. ":" .. all[i + 2]]
            spot.picked = last and now - last < C.PICKED_FADE and last or nil
            most = math.max(most, spot.value)
            spots[#spots + 1] = spot
        end
    end
    local width, height = C_Map.GetMapWorldSize(mapID)
    local yards = Tour(mapID, width, height)
    local value = 0
    for _, spot in ipairs(loop) do value = value + spot.value end
    Farm.most, Farm.loopYards, Farm.loopValue = most, yards, value
    Farm.loopMinutes = Hours(yards, #loop) * MINUTES_PER_HOUR
    Farm.loopPerHour = PerHour(value, yards, #loop)
end

function Farm.Stops(title)
    local G = ns.Glimmer
    local stops = {}
    for _, spot in ipairs(loop) do
        local node = G and G.NODES[spot.id]
        local name = node and ns.L(node[NAME]) or title
        stops[#stops + 1] = { name, cachedMap, spot.x * PERCENT, spot.y * PERCENT }
    end
    return stops
end

function Farm.Changed()
    cachedZones = nil
end
