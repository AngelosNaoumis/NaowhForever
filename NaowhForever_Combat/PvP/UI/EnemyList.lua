-- EnemyList.lua: Nearby Enemies on screen: the list, its alerts and the Kill on Sight menu, movable in the HUD Editor.
local ns = _G.NaowhForever

local T = ns.THEME
local P = ns.PvP
local S = P.Settings
local St = P.Style
local Enemies = P.Enemies
local Parts = ns.Shared.Parts
local Ago = ns.Shared.Ago

local PAGE, CARD, FEATURE = "PvP/Nearby Enemies", "nearbyEnemies", "PvP/Nearby Enemies:nearbyEnemies"
local MOVER_LABEL = "Nearby Enemies"
local PLACE = { "LEFT", "LEFT", 40, 120 }
local REFRESH = 10
local CHANNEL = "Master"
local PLACE_DOT = St.PLACE_DOT
local TEXT_TITLE = ns.L("NEARBY ENEMIES")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_HIGH = ns.L("Level ??")
local TEXT_GUILD = "<%s>"
local TEXT_IN_RANGE = ns.L("in range")
local TEXT_KILL_MARK = St.RED_CODE .. ns.L("KoS") .. "|r "
local TEXT_KILL_SEEN = ns.L("Kill on Sight: %s is nearby.")
local TEXT_ADD = ns.L("Add to Kill on Sight")
local TEXT_REMOVE = ns.L("Remove from Kill on Sight")
local TEXT_HINT = ns.L("Click to add or remove them from Kill on Sight.")
local TEXT_NONE = ns.L("Enemy players you see show up here.")
local TEXT_SETTINGS = ns.L("Nearby Enemies settings")
local TEXT_SETTINGS_HINT = ns.L("Opens the Nearby Enemies settings.")

local NONE = { text = TEXT_NONE, color = T.muted }

local panel, ticker, unlocked, dismissed
local pool, rows = {}, {}

local function LoadPosition()
    local pos = S.Get("enemiesPos")
    if pos then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("enemiesPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return ns.UI.AttachMover(frame, MOVER_LABEL, onMoved, PAGE, FEATURE)
end

local function RowTip(row)
    local entry, hint = row.entry, T.accentSoft
    GameTooltip:SetText(entry.enemy.name, entry.color.r, entry.color.g, entry.color.b)
    GameTooltip:AddLine(TEXT_HINT, hint.r, hint.g, hint.b)
end

local function ToggleKill(enemy)
    Enemies.SetKill(enemy, not enemy.kill)
end

local function KillMenu(row)
    local enemy = row.entry.enemy
    ns.ContextMenu(row, function(_, root)
        root:CreateTitle(enemy.name)
        root:CreateButton(enemy.kill and TEXT_REMOVE or TEXT_ADD, ToggleKill, enemy)
    end)
end

local function Fill(i, enemy)
    local row = pool[i]
    if not row then
        row = { tip = RowTip, click = KillMenu }
        pool[i] = row
    end
    local level = enemy.level and enemy.level > 0 and TEXT_LEVEL:format(enemy.level) or TEXT_HIGH
    local guild = enemy.guild and PLACE_DOT .. TEXT_GUILD:format(enemy.guild) or ""
    row.enemy = enemy
    row.text = enemy.kill and TEXT_KILL_MARK .. enemy.name or enemy.name
    row.color = enemy.class and RAID_CLASS_COLORS[enemy.class] or T.fg
    row.sub = level .. guild .. PLACE_DOT .. (enemy.near and TEXT_IN_RANGE or Ago(enemy.seen))
    rows[i] = row
end

local function Render()
    wipe(rows)
    for i, enemy in ipairs(Enemies.Sorted()) do Fill(i, enemy) end
    if not rows[1] then rows[1] = NONE end
    panel:Fit(panel:SetRows(rows))
end

local function Alert(enemy)
    if enemy.kill and S.Get("enemiesKillAlert") then
        PlaySound(SOUNDKIT.RAID_WARNING, CHANNEL)
        FlashClientIcon()
        ns.Print(TEXT_KILL_SEEN:format(enemy.name))
    elseif S.Get("enemiesAlert") then
        PlaySound(SOUNDKIT.MAP_PING, CHANNEL)
        FlashClientIcon()
    end
end

local Refresh

local function Close()
    dismissed = true
    Refresh()
end

local function Build()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onClose = Close,
        settings = { page = PAGE, card = CARD, tip = TEXT_SETTINGS, hint = TEXT_SETTINGS_HINT },
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
    })
    panel:Place()
    panel:Paint()
end

function Refresh()
    Enemies.Expire()
    local any = Enemies.list[1] ~= nil
    local show = Enemies.On() and (unlocked or (any and not dismissed))
    if show and any then
        ticker = ticker or C_Timer.NewTicker(REFRESH, Refresh)
    elseif ticker then
        ticker:Cancel()
        ticker = nil
    end
    if not show then
        if panel then panel:Hide() end
        return
    end
    if not panel then Build() end
    Render()
    panel.mover:SetShown(unlocked == true)
    panel:Show()
end

local function OnChange(added)
    if added then
        dismissed = false
        Alert(added)
    end
    Refresh()
end

local function Replace()
    if panel then panel:Place() end
end

local function OnUnlock()
    unlocked = true
    Refresh()
end

local function OnLock()
    unlocked = false
    Refresh()
end

Enemies.OnChange(OnChange)
hooksecurefunc(ns, "Apply", Replace)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)
