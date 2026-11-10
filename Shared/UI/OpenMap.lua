-- OpenMap.lua: map pins on OpenMap's seamless world map: the zones beside the map underneath, and where their spots go on it.
local ns = _G.NaowhForever

local CAPITALS = ns.TownCapitals

local API_MAJOR = 1
local CURSOR_VERSION = 3
local NEAR = 0.5
local EMPTY = {}

local OpenMap = {}
ns.Shared.OpenMap = OpenMap

local alone = {}
local beside = {}
local zonesIn = {}
local rects = {}

local function Stitched()
    local api = OpenMapAPI
    if api and api.major == API_MAJOR and api.IsStitched() then return api end
end

local function Rect(api, mapID)
    local rect = rects[mapID]
    if rect ~= nil then return rect end
    rect = false
    local left, top = api.WorldFromMap(mapID, 0, 0)
    if left then
        local right, bottom = api.WorldFromMap(mapID, 1, 1)
        rect = { left = left, top = top, right = right, bottom = bottom }
    end
    rects[mapID] = rect
    return rect
end

local function Zones(parent)
    local list = zonesIn[parent]
    if list then return list end
    list = {}
    for _, info in ipairs(C_Map.GetMapChildrenInfo(parent, Enum.UIMapType.Zone) or EMPTY) do list[#list + 1] = info.mapID end
    zonesIn[parent] = list
    return list
end

local function Neighbours(api, host)
    local info = C_Map.GetMapInfo(host)
    local own = info and info.mapType == Enum.UIMapType.Zone and Rect(api, host)
    if not own then return false end
    local list = { host }
    local w, h = (own.right - own.left) * NEAR, (own.bottom - own.top) * NEAR
    for _, zone in ipairs(Zones(info.parentMapID)) do
        local rect = zone ~= host and not CAPITALS[zone] and Rect(api, zone)
        if rect and rect.left < own.right + w and rect.right > own.left - w and rect.top < own.bottom + h
            and rect.bottom > own.top - h then
            list[#list + 1] = zone
        end
    end
    return list
end

local function Beside(api, host)
    local list = beside[host]
    if list == nil then
        list = Neighbours(api, host)
        beside[host] = list
    end
    return list
end

function OpenMap.On()
    return Stitched() ~= nil
end

function OpenMap.Maps(map)
    local host = map:GetMapID()
    if not host then return EMPTY end
    local api = Stitched()
    local list = api and Beside(api, host)
    if list then return list end
    list = alone[host]
    if not list then
        list = { host }
        alone[host] = list
    end
    return list
end

function OpenMap.Spot(map, mapID, x, y)
    local host = map:GetMapID()
    if mapID == host then return x, y end
    local api = Stitched()
    if not api then return nil end
    local u, v = api.WorldFromMap(mapID, x, y)
    if not u then return nil end
    local px, py = api.MapFromWorld(host, u, v)
    local near = Beside(api, host) and NEAR or 0
    if not px or px < -near or px > 1 + near or py < -near or py > 1 + near then return nil end
    return px, py
end

function OpenMap.MapAtCursor()
    local api = Stitched()
    if not (api and api.version >= CURSOR_VERSION) then return nil end
    local u, v = api.CursorPosition()
    return u and api.MapAt(u, v)
end
