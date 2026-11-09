-- Farm.lua: where to gather for your skills: each zone's herbs, veins, beasts to skin and fishing priced from your last scan, and a loop through one (Market.Farm).
local ns = _G.NaowhForever

local Market = ns.Market
local C = Market.C
local S = Market.Settings
local Runs = Market.Runs

local KIND, NEED, NAME = 1, 2, 3
local GATHER_ITEM = 3
local MAX_LEVEL, LOOT, CREATURE_NAME = 2, 3, 4
local CAMP, LOOT_ENTRY, CATCH_ENTRY = 4, 4, 2
local FISH_MIN, FISH_MAX = 1, 2
local EMPTY = {}
local SECONDS_PER_MINUTE, MINUTES_PER_HOUR, SECONDS_PER_HOUR = 60, 60, 3600
local PERCENT = 100
local TEXT_POOL = ns.L("Fishing pool")

local itemOf, skinWorth, skinItem, catchWorth, catchItems = {}, {}, {}, {}, {}
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
    if kind == "skin" then return S.Get("farmSkins") end
    if kind == "fish" then return S.Get("farmFish") end
    return false
end

local function Camps()
    if Farm.camps then return Farm.camps end
    local packed = ns.MarketSkinningPacked
    if not packed or InCombatLockdown() then return end
    local u = C_EncodingUtil
    local flat = u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(packed), Enum.CompressionMethod.Deflate))
    if type(flat) ~= "table" then return end
    local all = {}
    for i = 1, #flat, 2 do all[flat[i]] = flat[i + 1] end
    Farm.camps, ns.MarketSkinningPacked = all, nil
    return all
end

local function SkinNeed(level)
    if level <= C.SKIN_LOW then return 1 end
    if level <= C.SKIN_MID then return (level - C.SKIN_LOW) * C.SKIN_MID_STEP end
    return level * C.SKIN_HIGH_STEP
end

-- What one skinning is worth after the cut, and its most valuable drop.
local function Skin(creatureID)
    if skinWorth[creatureID] == nil then
        local creature = Market.SKIN_CREATURES[creatureID]
        local loot = creature and Market.SKIN_LOOT[creature[LOOT]] or EMPTY
        local worth, best, most = 0, false, 0
        for i = 1, #loot, LOOT_ENTRY do
            local each = Net(loot[i]) * loot[i + 1] / PERCENT * (loot[i + 2] + loot[i + 3]) / 2
            worth = worth + each
            if each > most then best, most = loot[i], each end
        end
        skinWorth[creatureID], skinItem[creatureID] = worth, best
    end
    return skinWorth[creatureID], skinItem[creatureID] or nil
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

-- work: seconds spent at the stops. A node is up a third of the time; a camp's beasts are there to kill.
local function Hours(yards, work)
    return (yards / C.TRAVEL_SPEED + work) / SECONDS_PER_MINUTE / MINUTES_PER_HOUR
end

local function PerHour(gain, yards, work)
    local hours = Hours(yards, work)
    return hours > 0 and math.floor(gain / hours) or 0
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

local function FishLevels(mapID)
    local levels = ns.FishingLevels and ns.FishingLevels[mapID]
    if levels then return levels[FISH_MIN], levels[FISH_MAX] end
end

-- Some fish get away below the zone's top skill: from FISH_LOW_CATCH at its lowest to every one at its top.
local function CatchRate(skill, low, high)
    if skill >= high then return 1 end
    return C.FISH_LOW_CATCH + (1 - C.FISH_LOW_CATCH) * (skill - low) / (high - low)
end

-- What one catch on the map is worth after the cut, and each item's part of it, most valuable first.
local function Catch(mapID)
    local items = catchItems[mapID]
    if not items then
        items = {}
        local worth, catches = 0, Market.FISH_CATCHES[mapID]
        for i = 1, #catches, CATCH_ENTRY do
            local value = Net(catches[i]) * catches[i + 1] / PERCENT
            worth = worth + value
            if value > 0 then items[#items + 1] = { item = catches[i], value = value } end
        end
        table.sort(items, ByValue)
        catchItems[mapID], catchWorth[mapID] = items, worth
    end
    return catchWorth[mapID], items
end

local function Add(zone, item, value, gain, work)
    zone.stops, zone.value = zone.stops + 1, zone.value + value
    zone.gain, zone.work = zone.gain + gain, zone.work + work
    if item and value > 0 then Tally(zone, item, value) end
end

local found, foundPool = {}, {}

local function Found(item, value, gain, work)
    local stop = table.remove(foundPool) or {}
    stop.item, stop.value, stop.gain, stop.work = item, value, gain, work
    found[#found + 1] = stop
end

local function MoreGain(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    return (a.item or 0) < (b.item or 0)
end

-- A zone is rated on the stops its loop would take: its richest LOOP_STOPS.
local function KeepRichest(zone)
    if #found > C.LOOP_STOPS then table.sort(found, MoreGain) end
    for i, stop in ipairs(found) do
        if i <= C.LOOP_STOPS then Add(zone, stop.item, stop.value, stop.gain, stop.work) end
        foundPool[#foundPool + 1] = stop
    end
    wipe(found)
end

local function ReadZone(G, mapID, all, camps, skill)
    local zone = table.remove(zonePool) or { items = {} }
    wipe(zone.items)
    zone.map, zone.kind, zone.rate = mapID, "gather", nil
    zone.stops, zone.value, zone.gain, zone.work = 0, 0, 0, 0
    for i = 1, #all, 3 do
        local node = G.NODES[all[i]]
        local kind = node and node[KIND]
        if kind and Wanted(kind) and skill[kind] >= node[NEED] then
            local item = Item(all[i], node)
            local value = Value(all[i], kind, item)
            Found(item, value, value * C.OCCUPANCY, C.OCCUPANCY * C.GATHER_SECONDS)
        end
    end
    if Wanted("skin") then
        for i = 1, #camps, CAMP do
            local creature = Market.SKIN_CREATURES[camps[i]]
            if creature and skill.skin >= SkinNeed(creature[MAX_LEVEL]) then
                local each, item = Skin(camps[i])
                local value = each * camps[i + 3]
                Found(item, value, value, camps[i + 3] * C.SKIN_SECONDS)
            end
        end
    end
    KeepRichest(zone)
    if zone.stops == 0 then
        zonePool[#zonePool + 1] = zone
        return
    end
    local width, height = C_Map.GetMapWorldSize(mapID)
    local yards = C.TOUR_FACTOR * math.sqrt(zone.stops * width * height)
    zone.minutes = Hours(yards, zone.work) * MINUTES_PER_HOUR
    zone.perHour = PerHour(zone.gain, yards, zone.work)
    zone.measured = Runs.PerHour(mapID)
    zone.rank = zone.measured or zone.perHour
    table.sort(zone.items, ByValue)
    local info = C_Map.GetMapInfo(mapID)
    zone.name = info and info.name or ""
    zones[#zones + 1] = zone
end

local function ReadFish(mapID, skill)
    local low, high = FishLevels(mapID)
    if not low or skill < low then return end
    local zone = table.remove(zonePool) or { items = {} }
    wipe(zone.items)
    local worth, items = Catch(mapID)
    for i, entry in ipairs(items) do zone.items[i] = entry end
    zone.map, zone.kind, zone.rate = mapID, "fish", CatchRate(skill, low, high)
    zone.stops, zone.value, zone.gain, zone.work, zone.minutes = 0, worth, 0, 0, nil
    zone.perHour = math.floor(C.CATCHES_PER_HOUR * zone.rate * worth)
    zone.measured, zone.rank = nil, zone.perHour
    local info = C_Map.GetMapInfo(mapID)
    zone.name = info and info.name or ""
    zones[#zones + 1] = zone
end

local function Richer(a, b)
    if a.rank ~= b.rank then return a.rank > b.rank end
    if a.map ~= b.map then return a.map < b.map end
    return a.kind < b.kind
end

local function Key()
    local at = ns.AuctionScanTime and ns.AuctionScanTime() or 0
    return table.concat({ at, Farm.Skill("herb"), Farm.Skill("ore"), Farm.Skill("skin"), Farm.Skill("fish"),
        tostring(S.Get("farmHerbs")), tostring(S.Get("farmVeins")), tostring(S.Get("farmSkins")),
        tostring(S.Get("farmFish")) }, ":")
end

function Farm.Zones()
    local G = Glimmer()
    local byMap = ns.GlimmerSpots
    if not byMap then return zones end
    local key = Key()
    if key == cachedZones then return zones end
    cachedZones = key
    for i = #zones, 1, -1 do zonePool[#zonePool + 1] = table.remove(zones, i) end
    local skill = { herb = Farm.Skill("herb"), ore = Farm.Skill("ore"), skin = Farm.Skill("skin"),
        fish = Farm.Skill("fish") }
    local camps = Camps() or EMPTY
    for mapID, all in pairs(byMap) do ReadZone(G, mapID, all, camps[mapID] or EMPTY, skill) end
    for mapID, list in pairs(camps) do
        if not byMap[mapID] then ReadZone(G, mapID, EMPTY, list, skill) end
    end
    if Wanted("fish") then
        for mapID in pairs(Market.FISH_CATCHES) do ReadFish(mapID, skill.fish) end
    end
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

local function Richest(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
end

local function Tour(mapID, width, height)
    wipe(loop)
    local left = {}
    for _, spot in ipairs(spots) do
        if spot.can and spot.wanted then left[#left + 1] = spot end
    end
    if #left == 0 then return 0 end
    if #left > C.LOOP_STOPS then
        table.sort(left, Richest)
        for i = #left, C.LOOP_STOPS + 1, -1 do left[i] = nil end
    end
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

local function GatherZone(mapID)
    local G = Glimmer()
    local byMap = ns.GlimmerSpots
    local all = G and byMap and byMap[mapID]
    local camps = G and Camps()
    camps = camps and camps[mapID]
    if not (all or camps) then return end
    all, camps = all or EMPTY, camps or EMPTY
    local picked, scale = Gathered(G, mapID), G.C.SPOT_SCALE
    local now = time()
    local skill = { herb = Farm.Skill("herb"), ore = Farm.Skill("ore"), skin = Farm.Skill("skin") }
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
            spot.gain, spot.work, spot.count = spot.value * C.OCCUPANCY, C.OCCUPANCY * C.GATHER_SECONDS, nil
            spot.can, spot.wanted = skill[kind] >= node[NEED], Wanted(kind)
            local last = picked[id .. ":" .. all[i + 1] .. ":" .. all[i + 2]]
            spot.picked = last and now - last < C.PICKED_FADE and last or nil
            most = math.max(most, spot.value)
            spots[#spots + 1] = spot
        end
    end
    for i = 1, #camps, CAMP do
        local id, count = camps[i], camps[i + 3]
        local creature = Market.SKIN_CREATURES[id]
        if creature then
            local spot = table.remove(spotPool) or {}
            local each, item = Skin(id)
            spot.id, spot.kind, spot.need = id, "skin", SkinNeed(creature[MAX_LEVEL])
            spot.x, spot.y = camps[i + 1] / scale, camps[i + 2] / scale
            spot.item, spot.value, spot.count = item, each * count, count
            spot.gain, spot.work = spot.value, count * C.SKIN_SECONDS
            spot.can, spot.wanted, spot.picked = skill.skin >= spot.need, Wanted("skin"), nil
            most = math.max(most, spot.value)
            spots[#spots + 1] = spot
        end
    end
    Farm.most = most
    return true
end

local function FishZone(mapID)
    local low, high = FishLevels(mapID)
    local skill = Farm.Skill("fish")
    local worth, items = Catch(mapID)
    Farm.catchItem, Farm.catchWorth, Farm.catchNeed = items[1] and items[1].item, worth, low
    local value = worth * CatchRate(skill, low, high) * C.CATCHES_PER_HOUR * C.POOL_SECONDS / SECONDS_PER_HOUR
    local now = time()
    for _, pool in ipairs(Runs.Pools(mapID)) do
        local spot = table.remove(spotPool) or {}
        spot.id, spot.kind, spot.need, spot.x, spot.y = pool.id, "fish", low, pool.x, pool.y
        spot.item, spot.value, spot.count = Farm.catchItem, value, nil
        spot.gain, spot.work = value, C.POOL_SECONDS
        spot.can, spot.wanted = skill >= low, Wanted("fish")
        spot.picked = now - pool.last < C.PICKED_FADE and pool.last or nil
        spots[#spots + 1] = spot
    end
    Farm.most = value
end

function Farm.Zone(mapID, kind)
    for i = #spots, 1, -1 do spotPool[#spotPool + 1] = table.remove(spots, i) end
    wipe(loop)
    cachedMap, Farm.kind = mapID, kind
    if kind == "fish" then
        FishZone(mapID)
    elseif not GatherZone(mapID) then
        return
    end
    local width, height = C_Map.GetMapWorldSize(mapID)
    local yards = Tour(mapID, width, height)
    local value, gain, work = 0, 0, 0
    for _, spot in ipairs(loop) do
        value, gain, work = value + spot.value, gain + spot.gain, work + spot.work
    end
    Farm.loopYards, Farm.loopValue = yards, value
    Farm.loopMinutes = Hours(yards, work) * MINUTES_PER_HOUR
    Farm.loopPerHour = PerHour(gain, yards, work)
end

function Farm.CreatureName(creatureID)
    local creature = Market.SKIN_CREATURES[creatureID]
    return creature and creature[CREATURE_NAME] or ""
end

function Farm.CreatureLevels(creatureID)
    local creature = Market.SKIN_CREATURES[creatureID]
    if creature then return creature[1], creature[MAX_LEVEL] end
end

function Farm.SpotName(spot, fallback)
    if spot.kind == "fish" then return TEXT_POOL end
    if spot.kind == "skin" then return Farm.CreatureName(spot.id) end
    local G = ns.Glimmer
    local node = G and G.NODES[spot.id]
    return node and ns.L(node[NAME]) or fallback
end

function Farm.Stops(title)
    local stops = {}
    for _, spot in ipairs(loop) do
        stops[#stops + 1] = { Farm.SpotName(spot, title), cachedMap, spot.x * PERCENT, spot.y * PERCENT }
    end
    return stops
end

function Farm.Changed()
    cachedZones = nil
    wipe(skinWorth)
    wipe(skinItem)
    wipe(catchWorth)
    wipe(catchItems)
end
