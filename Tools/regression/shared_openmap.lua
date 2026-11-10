-- Returns ns.Shared.OpenMap as Shared/UI/OpenMap.lua makes it, without OpenMap loaded (each map shows
-- only its own pins), for a test whose stub ns builds its own ns.Shared rather than loading Shared.xml;
-- then the file's globals, and Stitch(rects, capitals): from then on OpenMap shows its stitched map,
-- each zone of `rects` ([uiMapID] = { left, top, right, bottom } on its world, 0 to 1) a zone of one
-- continent, which fills the world, and `capitals` ([uiMapID] = true) its capitals. Stitch returns
-- the stub OpenMapAPI, whose `continent` is that continent's uiMapID and whose `stitched`, `version`,
-- `cursorU`, `cursorV` and `continentRect` (the continent's box, the whole world when nil) a test may
-- change. OpenMap.lua
-- keeps what it works out for a map, so a test that needs another world loads the helper again.
-- Not a test itself (run-all.sh runs only test*.lua). Run from the repo root:
--
--   Shared = { OpenMap = dofile("Tools/regression/shared_openmap.lua"), ... }
local shared = {}
local globals = { _G = { NaowhForever = { Shared = shared, TownCapitals = {} } }, ipairs = ipairs }
local chunk = assert(loadfile("Shared/UI/OpenMap.lua"))
setfenv(chunk, globals)
chunk()
local CONTINENT, ZONE_TYPE, CONTINENT_TYPE = 9000, 3, 2
local function Stitch(rects, capitals)
    local api = { major = 1, version = 4, stitched = true, continent = CONTINENT }
    local function Rect(mapID) return mapID == CONTINENT and (api.continentRect or { 0, 0, 1, 1 }) or rects[mapID] end
    function api.IsStitched() return api.stitched end
    function api.WorldFromMap(mapID, x, y)
        local r = Rect(mapID)
        if not r then return nil end
        return r[1] + x * (r[3] - r[1]), r[2] + y * (r[4] - r[2])
    end
    function api.MapFromWorld(mapID, u, v)
        local r = Rect(mapID)
        if not r then return nil end
        return (u - r[1]) / (r[3] - r[1]), (v - r[2]) / (r[4] - r[2])
    end
    function api.CursorPosition() return api.cursorU, api.cursorV end
    function api.MapAt(u, v)
        local best, size = CONTINENT, 1
        for id, r in pairs(rects) do
            if u >= r[1] and u <= r[3] and v >= r[2] and v <= r[4] and r[3] - r[1] < size then best, size = id, r[3] - r[1] end
        end
        return best
    end
    local zones = {}
    for id in pairs(rects) do zones[#zones + 1] = { mapID = id } end
    table.sort(zones, function(a, b) return a.mapID < b.mapID end)
    api.childAsks = 0
    globals.Enum = { UIMapType = { Continent = CONTINENT_TYPE, Zone = ZONE_TYPE } }
    globals.C_Map = {
        GetMapInfo = function(id)
            if id == CONTINENT then return { mapID = id, mapType = CONTINENT_TYPE, parentMapID = 0 } end
            return { mapID = id, mapType = ZONE_TYPE, parentMapID = CONTINENT }
        end,
        GetMapChildrenInfo = function(id, mapType)
            api.childAsks = api.childAsks + 1
            if id ~= CONTINENT or mapType ~= ZONE_TYPE then return {} end
            return zones
        end,
    }
    for id in pairs(capitals or {}) do globals._G.NaowhForever.TownCapitals[id] = true end
    globals.OpenMapAPI = api
    return api
end

return shared.OpenMap, globals, Stitch
