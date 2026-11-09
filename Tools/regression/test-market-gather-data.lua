-- Run with Lua 5.1 from the repository root: The Market's skinning and fishing data (NaowhForever_Market/Data,
-- from Tools/build/market_gather.py), the camps unpacked the way the client does (Tools/regression/encoding_util.lua
-- stands in for C_EncodingUtil). Every camp is a known creature inside its map, every creature has its loot, and
-- the catches and pools are plain lists.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local SPOT_MAX = 1000
local PACKED_MAX = 200 * 1024
local MIN_CREATURES, MIN_MAPS, MIN_FISH_MAPS = 900, 40, 40
local ELWYNN, ZEPHRAS = 1429, 2521
local STONETUSK_BOAR, PRIDECLAW = 113, 251245
local LIGHT_LEATHER, RUINED_SCRAPS, BRILLIANT_SMALLFISH, OILY_BLACKMOUTH_SCHOOL = 2318, 2934, 6291, 180582

local ns = { Market = {} }
local env = setmetatable({ NaowhForever = ns }, { __index = _G })
env._G = env
for _, path in ipairs({ "NaowhForever_Market/Data/Skinning.lua", "NaowhForever_Market/Data/Fishing.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end
local M = ns.Market

local packed = ns.MarketSkinningPacked
check("the camps ship as one ASCII string", type(packed) == "string" and not packed:find("[\128-\255]")
    and #packed < PACKED_MAX)
local u = dofile("Tools/regression/encoding_util.lua")()
local flat = u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(packed), 0))
check("the camps unpack to map, camps, map, camps", type(flat) == "table" and #flat % 2 == 0)

local camps, maps, valid = {}, 0, true
for i = 1, #flat, 2 do
    local map, list = flat[i], flat[i + 1]
    maps = maps + 1
    camps[map] = list
    if type(map) ~= "number" or type(list) ~= "table" or #list == 0 or #list % 4 ~= 0 then valid = false end
    for j = 1, #list, 4 do
        local npc, x, y, count = list[j], list[j + 1], list[j + 2], list[j + 3]
        if not M.SKIN_CREATURES[npc] or x < 0 or x > SPOT_MAX or y < 0 or y > SPOT_MAX or count < 1 then
            valid = false
        end
    end
end
check("every camp is a skinnable creature inside its map with at least one spawn", valid)
check(("camps on many maps (%d)"):format(maps), maps >= MIN_MAPS)

local function CampsOf(map, npc)
    local n = 0
    local list = camps[map] or {}
    for j = 1, #list, 4 do if list[j] == npc then n = n + 1 end end
    return n
end
check("Stonetusk Boars camp in Elwynn Forest", CampsOf(ELWYNN, STONETUSK_BOAR) > 0)
check("Prideclaws, Forever's own, camp on Zephras Isle", CampsOf(ZEPHRAS, PRIDECLAW) > 0)

local creatures, named = 0, true
for _, c in pairs(M.SKIN_CREATURES) do
    creatures = creatures + 1
    local low, high, loot, name = c[1], c[2], c[3], c[4]
    if not (low >= 1 and low <= high and M.SKIN_LOOT[loot] and type(name) == "string" and name ~= "") then
        named = false
    end
end
check(("many creatures (%d), each with levels, its loot and a name"):format(creatures),
    creatures >= MIN_CREATURES and named)
check("the boar is named and level 5 to 6", M.SKIN_CREATURES[STONETUSK_BOAR][4] == "Stonetusk Boar"
    and M.SKIN_CREATURES[STONETUSK_BOAR][1] == 5 and M.SKIN_CREATURES[STONETUSK_BOAR][2] == 6)

local loots = true
for _, list in pairs(M.SKIN_LOOT) do
    if #list == 0 or #list % 4 ~= 0 then loots = false end
    for j = 1, #list, 4 do
        local chance, low, high = list[j + 1], list[j + 2], list[j + 3]
        if not (chance > 0 and chance <= 100 and low >= 1 and low <= high) then loots = false end
    end
end
check("every loot table is item, chance, least and most", loots)

local function Gives(list, item)
    for j = 1, #list, 4 do if list[j] == item then return true end end
    return false
end
check("the boar gives Light Leather", Gives(M.SKIN_LOOT[M.SKIN_CREATURES[STONETUSK_BOAR][3]], LIGHT_LEATHER))
check("Prideclaw's loot is what players skinned", M.SKIN_CREATURES[PRIDECLAW][3] == PRIDECLAW
    and Gives(M.SKIN_LOOT[PRIDECLAW], RUINED_SCRAPS))

local fishMaps, pairsOk = 0, true
for _, list in pairs(M.FISH_CATCHES) do
    fishMaps = fishMaps + 1
    if #list == 0 or #list % 2 ~= 0 then pairsOk = false end
    for j = 1, #list, 2 do
        if not (list[j] > 0 and list[j + 1] > 0 and list[j + 1] <= 100) then pairsOk = false end
    end
end
check(("catches on many maps (%d), each item and chance"):format(fishMaps), fishMaps >= MIN_FISH_MAPS and pairsOk)
local elwynn = M.FISH_CATCHES[ELWYNN]
check("Elwynn Forest's water gives Raw Brilliant Smallfish", elwynn and elwynn[1] == BRILLIANT_SMALLFISH)
check("an Oily Blackmouth School is a pool", M.FISH_POOLS[OILY_BLACKMOUTH_SCHOOL] == true)

print(("test-market-gather-data: %d checks passed"):format(checks))
