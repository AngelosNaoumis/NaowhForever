-- Run with Lua 5.1 from the repository root: opening a profession does not flash Blizzard's
-- window. Ours takes over on the next frame and Blizzard's is put back to full alpha whenever it
-- closes, so its OnShow hook takes it to zero alpha at once, before it is drawn.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_Professions/UI/Takeover.lua")
local first = assert(source:find("local function OnBlizzardShow()", 1, true))
local last = assert(source:find("\nend\n", first, true))
local chunk = source:sub(first, last + 4) .. "return OnBlizzardShow"

local on = true
local queued = 0
local pf = { alpha = 1 }
function pf:SetAlpha(a) self.alpha = a end
local env = {
    On = function() return on end,
    Queue = function() queued = queued + 1 end,
    ProfessionsFrame = pf,
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local OnBlizzardShow = fn()

OnBlizzardShow(pf)
check("with our window on, Blizzard's goes transparent as it shows", pf.alpha == 0)
check("and ours is still queued to take over", queued == 1)

on, pf.alpha = false, 1
OnBlizzardShow(pf)
check("with ours off (or the Gamepad style), Blizzard's is left as it is", pf.alpha == 1)
check("and the takeover is still asked to settle", queued == 2)

local hook = assert(source:find("local function HookBlizzard()", 1, true))
local hookEnd = assert(source:find("\nend\n", hook, true))
check("Blizzard's OnShow runs it", source:sub(hook, hookEnd):find('HookScript("OnShow", OnBlizzardShow)', 1, true))

print(checks .. " profession open flash checks passed")
