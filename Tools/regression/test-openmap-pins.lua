-- Run with Lua 5.1 from the repository root: on OpenMap's seamless world map, a pin module places the
-- zones beside the map underneath too, each spot where OpenMap draws it, and keeps each map's own pins
-- as they are without OpenMap. Checks Shared/UI/OpenMap.lua against a stub of OpenMapAPI, then the
-- quest giver pins through it.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end
local function Near(a, b) return a and b and math.abs(a - b) < 1e-9 end

-- On OpenMap's world, 0 to 1 across and down, all one continent: zone 10, zone 11 beside it, zone 12 far
-- off, capital 13 sticking out past zone 10's top edge (as Stormwind and Orgrimmar do past their zones'),
-- and zone 14 inside zone 11's box (as Mulgore is inside the Barrens').
local ZONE, BESIDE, FAR, CAPITAL, INNER = 10, 11, 12, 13, 14
local RECTS = {
    [ZONE] = { 0.4, 0.4, 0.5, 0.5 },
    [BESIDE] = { 0.5, 0.4, 0.6, 0.5 },
    [FAR] = { 0.8, 0.8, 0.9, 0.9 },
    [CAPITAL] = { 0.44, 0.38, 0.47, 0.42 },
    [INNER] = { 0.52, 0.42, 0.55, 0.45 },
}
local OpenMap, globals, Stitch = dofile("Tools/regression/shared_openmap.lua")

local host = ZONE
local map = { GetMapID = function() return host end }
local function List(t)
    local out = {}
    for i, id in ipairs(t) do out[i] = tostring(id) end
    return table.concat(out, " ")
end

-- Without OpenMap: every map only its own pins, nothing converted.
Check(List(OpenMap.Maps(map)) == "10", "no OpenMap: only the map underneath")
local x, y = OpenMap.Spot(map, ZONE, 0.3, 0.7)
Check(x == 0.3 and y == 0.7, "no OpenMap: a spot on the map is where it was")
Check(OpenMap.Spot(map, BESIDE, 0.5, 0.5) == nil, "no OpenMap: another map's spot is left off")
Check(not OpenMap.On() and OpenMap.MapAtCursor() == nil, "no OpenMap: not stitched, no zone under the cursor")

globals.OpenMapAPI = { major = 2, IsStitched = function() return true end }
Check(List(OpenMap.Maps(map)) == "10" and not OpenMap.On(), "an OpenMap API of another major version is not used")

local api = Stitch(RECTS, { [CAPITAL] = true })
local CONTINENT = api.continent
api.stitched = false
Check(List(OpenMap.Maps(map)) == "10" and not OpenMap.On(), "OpenMap showing Blizzard's own map: as without it")
Check(OpenMap.Spot(map, BESIDE, 0.5, 0.5) == nil, "and another map's spot is still left off")

-- Stitched, a zone underneath.
api.stitched = true
Check(OpenMap.On(), "stitched")
Check(List(OpenMap.Maps(map)) == "10 11 14",
    "the zones beside it come, the one inside a neighbour's box too; the far zone and the capital do not")
Check(OpenMap.Maps(map) == OpenMap.Maps(map), "one list kept for the map underneath")
x, y = OpenMap.Spot(map, BESIDE, 0.1, 0.5)
Check(Near(x, 1.1) and Near(y, 0.5), "a spot in the zone beside it, on the map underneath where OpenMap draws it")
x, y = OpenMap.Spot(map, ZONE, 0.25, 0.75)
Check(x == 0.25 and y == 0.75, "a spot on the map underneath is where it was")
Check(OpenMap.Spot(map, FAR, 0.5, 0.5) == nil, "a spot too far off the map underneath is left off")
Check(OpenMap.Spot(map, CONTINENT, 0.1, 0.45) == nil, "and one too far off its other side")
Check(OpenMap.Spot(map, 99, 0.5, 0.5) == nil, "a map OpenMap does not have is left off")
local asked = api.childAsks
OpenMap.Maps(map)
Check(api.childAsks == asked, "a continent's zones are read once")

host = BESIDE
Check(List(OpenMap.Maps(map)) == "11 10 14", "beside the next zone the capital still waits")
host = CAPITAL
Check(List(OpenMap.Maps(map)) == "13 10", "zoomed into the capital: the zone round it comes too")
host = CONTINENT
Check(List(OpenMap.Maps(map)) == tostring(CONTINENT), "a continent underneath: only its own pins, as without OpenMap")
api.continentRect = { 0.3, 0.3, 0.7, 0.7 }
x, y = OpenMap.Spot(map, ZONE, 0.5, 0.5)
Check(Near(x, 0.375) and Near(y, 0.375), "a zone's spot on the continent underneath, where OpenMap draws it")
Check(OpenMap.Spot(map, FAR, 0.5, 0.5) == nil, "a spot past the continent's edge is left off there, as without OpenMap")
api.continentRect = nil
host = ZONE

api.cursorU, api.cursorV = 0.58, 0.47
Check(OpenMap.MapAtCursor() == BESIDE, "the zone under the cursor, though the map underneath is another")
api.cursorU, api.cursorV = 0.455, 0.39
Check(OpenMap.MapAtCursor() == CAPITAL, "the capital under the cursor, past its zone's edge")
api.cursorU, api.cursorV = 0.7, 0.2
Check(OpenMap.MapAtCursor() == CONTINENT, "over open water: the continent")
api.cursorU, api.cursorV = nil, nil
Check(OpenMap.MapAtCursor() == nil, "nothing when the cursor is off the map")
api.version = 2
api.cursorU, api.cursorV = 0.58, 0.47
Check(OpenMap.MapAtCursor() == nil, "an OpenMap without the cursor's position: nothing")
api.version = 4

-- The quest giver pins through it.
local settings = { enabled = true, mapPins = true, mapPinSize = 20 }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local GIVERS = {
    [ZONE] = { { x = 50, y = 50, quests = { 1 } } },
    [BESIDE] = { { x = 10, y = 50, quests = { 2 } } },
    [FAR] = { { x = 50, y = 50, quests = { 3 } } },
}
local askedFor = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    CompletoSettings = S, Apply = function() end, ThemeTint = function() end,
    Completo = { Settings = S, Style = {}, C = { PERCENT = 100 },
        Quests = { Refresh = function() end, Givers = function(mapID)
            askedFor[#askedFor + 1] = mapID
            return GIVERS[mapID] or {}
        end } } }
local acquired = {}
local provider
map.IsShown = function() return true end
map.AddDataProvider = function(_, p) provider = p end
map.RemoveAllPinsByTemplate = function() for i = #acquired, 1, -1 do acquired[i] = nil end end
map.AcquirePin = function(_, _, giver, px, py) acquired[#acquired + 1] = { giver.quests[1], px, py } end
local boot
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return { GetMap = function() return map end } end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = function()
        local f = {}
        function f:RegisterEvent() end
        function f:UnregisterAllEvents() end
        function f:SetScript(name, fn) self[name] = fn end
        boot = boot or f
        return f
    end,
    hooksecurefunc = function() end,
    WorldMapFrame = map,
}, { __index = _G })
ns.Shared = { OpenMap = OpenMap }
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/QuestPins.lua")))
setfenv(chunk, env)
chunk()
boot.OnEvent(boot)
Check(provider ~= nil, "the quest giver pins' provider is on the map")

provider.GetMap = function() return map end
askedFor = {}
provider:RefreshAllData()
Check(List(askedFor) == "10 11 14", "stitched: the givers of the map underneath and of the zones beside it")
Check(#acquired == 2 and acquired[1][1] == 1 and Near(acquired[1][2], 0.5) and Near(acquired[1][3], 0.5),
    "the map underneath's giver where it was")
Check(acquired[2][1] == 2 and Near(acquired[2][2], 1.1) and Near(acquired[2][3], 0.5),
    "the giver beside it, past the map underneath's edge where OpenMap draws it")

api.stitched = false
askedFor = {}
provider:RefreshAllData()
Check(List(askedFor) == "10" and #acquired == 1 and Near(acquired[1][2], 0.5),
    "OpenMap off: only the map's own givers, where they were")

print(("test-openmap-pins: %d checks passed"):format(checks))
