-- Run with Lua 5.1 from the repository root: Chat Zones with secret values. In an instance a chat
-- author, a Group Finder result and the measurements of a row or tooltip can come back secret;
-- each is checked before it is compared, looped over or measured, and a secret one is skipped.
-- The stand-in secret raises on what plain Lua lets it catch (ordering, arithmetic, index, concat,
-- a for limit). It cannot raise on == against a string or on a truth test, so the order of the
-- Secret checks before an == "" and the isDelisted check are not caught here.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local source = Read("NaowhForever_QoL/Interface/ChatZones.lua")
local first = assert(source:find("local PREFIX = ", 1, true))
local tooltip = assert(source:find("local function UpdateTooltip(", first, true))
local last = assert(source:find("\nend\n", tooltip, true))
local chunk = source:sub(first, last + 4)
    .. "return { Key = Key, Remember = Remember, Known = known, ReadGroupFinder = ReadGroupFinder,"
    .. " RowZoneWidth = RowZoneWidth, UpdateRow = UpdateRow, UpdateTooltip = UpdateTooltip,"
    .. " RowText = rowText, TipText = tipText }"

local secrets = setmetatable({}, { __mode = "k" })
local function Refuse() error("secret value touched", 2) end
local function Secret()
    local v = newproxy(true)
    local mt = getmetatable(v)
    for _, op in ipairs({ "__index", "__lt", "__le", "__add", "__sub", "__mul", "__div", "__unm",
        "__concat", "__len", "__call" }) do
        mt[op] = Refuse
    end
    secrets[v] = true
    return v
end

local lfg = { reads = 0 }
local env = {
    ns = {
        L = function(s) return s end,
        QoLConstants = { SECONDS_PER_MINUTE = 60 },
        GamepadStandDown = function() return false end,
        THEME = { muted = { r = 0.5, g = 0.5, b = 0.5 } },
    },
    S = { Get = function(key) return key == "chatZonesMaxAge" and 10 or true end },
    issecretvalue = function(v) return secrets[v] == true end,
    Ambiguate = function(name) return name end,
    GetTime = function() return 100 end,
    C_LFGList = {
        GetSearchResultInfo = function() return lfg.info end,
        GetSearchResultPlayerInfo = function()
            lfg.reads = lfg.reads + 1
            return lfg.player
        end,
        GetSearchResultLeaderInfo = function() return { areaName = lfg.leaderZone } end,
    },
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local api = fn()

check("a secret name has no key", api.Key(Secret()) == nil)
check("a plain name is keyed as Ambiguate gives it", api.Key("Thrall") == "Thrall")
api.Remember("Jaina", Secret(), 20)
check("a secret zone is not remembered", api.Known.Jaina == nil)
api.Remember("Jaina", "Stormwind", Secret())
check("a secret level is left out", api.Known.Jaina.zone == "Stormwind" and api.Known.Jaina.level == nil)

lfg.player = { name = "Thrall", areaName = "Orgrimmar", level = 30 }
lfg.info = { isDelisted = false, numMembers = Secret() }
api.ReadGroupFinder(1)
check("a result with a secret member count is skipped", lfg.reads == 0)
lfg.info = { isDelisted = Secret(), numMembers = 1 }
api.ReadGroupFinder(1)
check("a result with a secret delisted flag is skipped", lfg.reads == 0)
lfg.info = { isDelisted = false, numMembers = 1 }
api.ReadGroupFinder(1)
check("a plain result is read", lfg.reads == 1 and api.Known.Thrall.zone == "Orgrimmar")

local function FontString()
    local fs = {}
    function fs:SetJustifyH() end
    function fs:SetWordWrap() end
    function fs:SetFont() end
    function fs:SetTextColor() end
    function fs:ClearAllPoints() end
    function fs:SetPoint() end
    function fs:SetText(text) self.text = text end
    function fs:SetWidth(width) self.width = width end
    function fs:GetStringWidth() return 50 end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    return fs
end

local function Row(o)
    local icon = {
        IsVisible = function() return true end,
        GetLeft = function() return o.iconLeft end,
        GetEffectiveScale = function() return 1 end,
    }
    local entry = { resultID = 1 }
    entry.ActivityName = {
        GetRight = function() return o.start end,
        GetStringWidth = function() return o.nameWidth or 100 end,
        GetFont = function() return "font", 12, "" end,
    }
    entry.DataDisplay = {
        GetRegions = function() if o.iconLeft then return icon end end,
        GetChildren = function() end,
        SetScale = function() end,
    }
    function entry:GetEffectiveScale() return 1 end
    function entry:GetWidth() return 400 end
    function entry:IsShown() return true end
    function entry:CreateFontString() return FontString() end
    return entry
end

local function Shown(entry)
    local fs = api.RowText[entry]
    return fs and fs.shown and fs.width
end

lfg.leaderZone = "Westfall"
local plain = Row({ start = 100, iconLeft = 500 })
api.UpdateRow(plain)
check("a plain row shows the leader's zone up to the role icons", Shown(plain) == 500 - 100 - 16)
local secretStart = Row({ start = Secret(), iconLeft = 500 })
api.UpdateRow(secretStart)
check("a row whose activity name ends at a secret point shows no zone", not Shown(secretStart))
local secretIcon = Row({ start = 100, iconLeft = Secret() })
api.UpdateRow(secretIcon)
check("a row whose role icons sit at a secret point shows no zone", not Shown(secretIcon))
local secretWidth = Row({ start = 100, nameWidth = Secret() })
api.UpdateRow(secretWidth)
check("a row whose activity name has a secret width shows no zone", not Shown(secretWidth))
lfg.leaderZone = Secret()
local secretZone = Row({ start = 100, iconLeft = 500 })
api.UpdateRow(secretZone)
check("a secret leader zone is not shown", not Shown(secretZone))

lfg.reads = 0
lfg.info = { isDelisted = false, numMembers = Secret() }
api.UpdateTooltip({}, 1)
check("a tooltip for a result with a secret member count reads no members", lfg.reads == 0)

local function Tooltip(o)
    local row = {
        Name = { GetText = function() return o.name or "Thrall" end },
        Level = { IsShown = function() return true end, GetRight = function() return o.levelRight or 100 end },
    }
    function row:IsShown() return true end
    function row:GetLeft() return 10 end
    function row:CreateFontString() return FontString() end
    local tip = { Leader = row }
    function tip:GetLeft() return 0 end
    function tip:GetWidth() return o.tipWidth or 120 end
    function tip:SetWidth(width) self.width = width end
    return tip, row
end

local function TipShown(row)
    local fs = api.TipText[row]
    return fs and fs.shown and fs.text
end

lfg.info, lfg.player = { isDelisted = false, numMembers = 1 }, { name = "Thrall", areaName = "Orgrimmar" }
local tip, row = Tooltip({})
api.UpdateTooltip(tip, 1)
check("a plain tooltip shows the member's zone and widens to fit it",
    TipShown(row) == "Orgrimmar" and tip.width == 100 - 0 + 8 + 50 + 11)
tip, row = Tooltip({ levelRight = Secret() })
api.UpdateTooltip(tip, 1)
check("a tooltip whose level ends at a secret point shows no zones", not TipShown(row))
tip, row = Tooltip({ tipWidth = Secret() })
api.UpdateTooltip(tip, 1)
check("a tooltip of secret width shows the zone and is not resized", TipShown(row) == "Orgrimmar" and not tip.width)
tip, row = Tooltip({ name = Secret() })
api.UpdateTooltip(tip, 1)
check("a member with a secret name shows no zone", not TipShown(row))

print(("chat zones secrets: %d checks passed"):format(checks))
