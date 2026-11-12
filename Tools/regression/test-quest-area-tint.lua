-- Run with Lua 5.1 from the repository root: Quest Area Tint. While on, the world map's quest
-- blob pin takes the chosen color's fill and edge textures and the fill opacity; turned off, it
-- gets the game's own textures and alphas back; never turned on, the pin is not touched. Only
-- the blob's own setters are called and nothing is written into the pin's table.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, mapQuestTint = false, mapQuestTintColor = "blue", mapQuestTintFill = 0.4 }
local hooks = {}
local S = { Get = function(key) return settings[key] end }
function S.Set(key, value) settings[key] = value end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, QoLSettings = S, Apply = function() end }
ns.Shared = { Style = dofile("Tools/regression/shared_style.lua"), MapPins = {} }

local calls = {}
local pin = setmetatable({}, { __newindex = function(_, k) error("wrote " .. tostring(k) .. " into the pin") end })
for _, method in ipairs({ "SetFillTexture", "SetBorderTexture", "SetFillAlpha", "SetBorderAlpha" }) do
    rawset(pin, method, function(self, value)
        assert(self == pin)
        calls[#calls + 1] = method
        calls[method] = value
    end)
end
local template
local boot
local env = setmetatable({
    _G = { NaowhForever = ns },
    WorldMapFrame = {
        EnumeratePinsByTemplate = function(_, name)
            template = name
            local done
            return function()
                if done then return nil end
                done = true
                return pin
            end
        end,
    },
    hooksecurefunc = function(owner, name, fn)
        hooks[#hooks + 1] = { owner = owner, name = name }
        local original = owner[name]
        owner[name] = function(...)
            original(...)
            fn(...)
        end
    end,
    CreateFrame = function()
        boot = { RegisterEvent = function() end }
        function boot:SetScript(_, fn) self.handler = fn end
        return boot
    end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/QuestAreaTint.lua")))
setfenv(chunk, env)
chunk()

boot.handler(boot, "PLAYER_LOGIN")
Check(#calls == 0, "off at login: the pin is left alone")
S.Set("mapQuestTintColor", "green")
S.Set("mapQuestTintFill", 0.6)
Check(#calls == 0, "changing its options while off does nothing")

S.Set("mapQuestTint", true)
Check(template == "QuestBlobPinTemplate", "it finds the game's quest blob pin")
Check(calls.SetFillTexture == "Interface\\AddOns\\NaowhForever_QoL\\Media\\QuestArea\\green_fill"
    and calls.SetBorderTexture == "Interface\\AddOns\\NaowhForever_QoL\\Media\\QuestArea\\green_edge",
    "on: the chosen color's fill and edge")
Check(calls.SetFillAlpha == 153 and calls.SetBorderAlpha == 255, "the fill at the chosen opacity, the edge in full")

S.Set("mapQuestTintColor", "violet")
Check(calls.SetFillTexture:find("violet_fill$") and calls.SetBorderTexture:find("violet_edge$"), "a new color applies at once")

S.Set("mapQuestTint", false)
Check(calls.SetFillTexture == "Interface\\WorldMap\\UI-QuestBlob-Inside"
    and calls.SetBorderTexture == "Interface\\WorldMap\\UI-QuestBlob-Outside"
    and calls.SetFillAlpha == 128 and calls.SetBorderAlpha == 192, "off: the game's own look comes back")
local count = #calls
S.Set("mapQuestTintFill", 0.3)
Check(#calls == count, "and stays untouched until it is turned on again")

S.Set("mapQuestTint", true)
S.Set("enabled", false)
Check(calls.SetFillTexture == "Interface\\WorldMap\\UI-QuestBlob-Inside", "turning QoL off puts the game's look back too")

local section = ns.Shared.MapPins[1]
Check(section and section.map and section.switch == "mapQuestTint" and section.store == S,
    "a Map Options row on Map & Pins")
local names, order = section.rows[2].choice[1], section.rows[2].choice[2]
for _, colour in ipairs(order) do
    Check(names[colour], "a name for " .. colour)
    for _, part in ipairs({ "_fill.tga", "_edge.tga" }) do
        local f = io.open("NaowhForever_QoL/Media/QuestArea/" .. colour .. part, "rb")
        Check(f, "a texture for " .. colour .. part)
        f:close()
    end
end
Check(section.rows[2].needs == "mapQuestTint" and section.rows[3].needs == "mapQuestTint"
    and section.rows[3].slider[1] > 0, "its color and opacity wait for the switch, never fully clear")
Check(Read("Core/Features.lua"):find("mapQuestTint = false,", 1, true)
    and Read("Core/Settings.lua"):find('mapQuestTint = F.mapQuestTint, mapQuestTintColor = "blue", mapQuestTintFill = 0.4,', 1, true),
    "Quest Area Tint starts off, blue at 40%")
for _, hook in ipairs(hooks) do
    Check(hook.owner == S or hook.owner == ns, "it hooks only its own settings, never the map")
end

print(("test-quest-area-tint: %d checks passed"):format(checks))
