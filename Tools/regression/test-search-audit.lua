-- Every setting search can reach, run against every module's real settings: its own name finds it first
-- among the names typed, on the page Categories.lua places it, with no two results that read the same; with
-- every module turned off, the generated index finds each one on the same page. Run with Lua 5.1 from the
-- repository root, with Libs/.
local TocFiles = dofile("Tools/regression/toc_files.lua")

local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    local v = Stub()
    rawset(t, k, v)
    return v
end
stubMeta.__call = function() return Stub() end
stubMeta.__tostring = function() return "" end
stubMeta.__concat = function(a, b)
    return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "")
end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
    stubMeta[op] = function() return 0 end
end
stubMeta.__lt = function() return false end
stubMeta.__le = function() return false end
function Stub() return setmetatable({}, stubMeta) end

local off = {}
local env = setmetatable({}, { __index = function(t, k)
    local v = _G[k]
    if v ~= nil then return v end
    if k:find("^NaowhForever") then return nil end
    v = Stub()
    rawset(t, k, v)
    return v
end })
env._G = env
env.GetLocale = function() return "enUS" end
env.C_AddOns = { IsAddOnLoaded = function(name) return not off[name] end,
    DoesAddOnExist = function(name) return io.open(name .. "/" .. name .. ".toc") ~= nil end,
    GetAddOnMetadata = function() return "" end, GetAddOnEnableState = function() return 2 end,
    LoadAddOn = function() return true end }
env.C_Item = { GetItemNameByID = function() return nil end }
env.MAX_PARTY_MEMBERS, env.MAX_RAID_MEMBERS = 4, 40
env.MerchantFrame = { IsShown = function() return false end }
env.ClassTrainerFrame = { IsShown = function() return false end }
env.C_ClassColor = { GetClassColor = function()
    return { WrapTextInColorCode = function(_, text) return text end }
end }
env.LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, class)
    return class:sub(1, 1) .. class:sub(2):lower()
end })
env.UnitClass = function() return "Paladin", "PALADIN" end

for _, path in ipairs(TocFiles("%.lua$")) do
    local skip = path:find("^Libs/") or path:find("SearchIndex%.lua$") or (path:find("Locales/") and path ~= "Core/Locales/enUS.lua")
    if not skip then
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk(path:match("^(NaowhForever_[^/]+)/") or "NaowhForever", rawget(env, "NaowhForever"))
    end
end

local ns = rawget(env, "NaowhForever")
local UI, O, Settings = ns.UI, ns.Options, ns.Shared.Settings
local Find = UI.Search.Find

local failures, checks = {}, 0
local function Check(ok, why)
    checks = checks + 1
    if not ok and #failures < 20 then failures[#failures + 1] = why end
end

local function Shown(t)
    return table.concat({ ns.L(t.label or t.tag), t.tag, t.trail or "" }, " | ")
end

local function NoTwins(matches, query)
    local seen = {}
    for _, m in ipairs(matches) do
        local shown = Shown(m)
        Check(not seen[shown], "'" .. query .. "' lists '" .. shown .. "' twice")
        seen[shown] = true
    end
end

-- Every module on: each card and setting by its own name.
local list = UI.Search.Collect()
local entries = 0
for _, page in ipairs(UI.SearchPages()) do
    Settings.Index(page.key, function(card, label)
        if type(label) ~= "string" then return end
        entries = entries + 1
        local matches = Find(list, label)
        local at
        for i, m in ipairs(matches) do
            if m.card == card and m.label == label and m.page == page.key then at = i break end
        end
        Check(at ~= nil, "'" .. label .. "' is not found on " .. page.key)
        Check(not at or matches[at].named == 2, "'" .. label .. "' is not ranked as its own name")
        Check(O.IsModuleCard(card) or O.NavPage(card) == page.key,
            card .. " is shown on " .. page.key .. " but a jump lands on " .. tostring((O.NavPage(card))))
        NoTwins(matches, label)
    end)
end
Check(entries > 1500, "every module's settings are searched, " .. entries .. " found")

for _, cat in ipairs(O.CATEGORIES) do
    for _, page in ipairs(cat.pages) do
        local found = false
        for _, m in ipairs(Find(list, cat.name .. " " .. page.name)) do found = found or m.page == page.key end
        Check(found, page.key .. " is not found by its name")
    end
end
for _, mod in ipairs(O.MODULES) do
    Check(#Find(list, O.DisplayName(mod)) > 0, O.DisplayName(mod) .. " is not found by its name")
end

-- A plural finds what is named in the singular.
Check(#Find(list, "minimap buttons") > 0 and #Find(list, "reminders") > 0, "a plural finds the singular")

-- Every module off: the generated index, one result per setting, on the page it is placed on.
local index = assert(loadstring(dofile("Tools/build/search_index.lua"), "SearchIndex.lua"))
setfenv(index, env)
index()
for _, mod in ipairs(O.MODULES) do
    if mod.addon then off[mod.host or mod.addon] = true end
end
list = UI.Search.Collect()
local offEntries = 0
for _, mod in ipairs(O.MODULES) do
    for _, tab in ipairs(mod.tabs) do
        for _, e in ipairs(ns.SEARCH_INDEX[tab.key] or {}) do
            offEntries = offEntries + 1
            local label, page = e[2] or e[4], O.NavPage(tab.key .. ":" .. e[1])
            Check(page ~= nil, tab.key .. ":" .. e[1] .. " is placed on no page")
            local matches, found = Find(list, label), false
            for _, m in ipairs(matches) do
                found = found or (m.page == page and m.card == O.ModuleCardUid(mod) and m.label == label)
            end
            Check(found, "'" .. label .. "' of " .. mod.name .. ", turned off, is not found on " .. tostring(page))
            NoTwins(matches, label)
        end
    end
end
Check(offEntries > 1000, "every turned-off module's settings are searched, " .. offEntries .. " found")

assert(#failures == 0, table.concat(failures, "\n"))
print(("PASS search audit: %d checks, %d settings on, %d off"):format(checks, entries, offEntries))
