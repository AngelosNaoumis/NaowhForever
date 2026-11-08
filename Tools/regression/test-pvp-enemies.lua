-- PvP Nearby Enemies: the list of enemy players seen around you and the Kill on Sight list. Loads
-- NaowhForever_Combat/PvP's settings, Enemies.lua, the list and its settings card on stubs: nothing made or
-- listened to while off, who is listed and how they are keyed, in range and seen ago, expiry, the cap,
-- Kill on Sight and its alerts, instances, the HUD Editor and the ticker. Secret values are a userdata that
-- raises on concatenation, comparison and indexing. Does not emulate taint, rendering or the game's events.
-- From the repo root: lua5.1 Tools/regression/test-pvp-enemies.lua
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local SECRET = newproxy(true)
do
    local mt = getmetatable(SECRET)
    local function Raise() error("a secret value was used", 2) end
    mt.__concat, mt.__index, mt.__lt, mt.__le, mt.__len, mt.__call = Raise, Raise, Raise, Raise, Raise, Raise
end

local function Frame(kind)
    local f = { kind = kind, shown = true, events = {} }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:IsShown() return self.shown end
    function f:SetScript(k, fn) self[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    return f
end

local function Store(values)
    local S = { Get = function(k) return values[k] end }
    function S.Set(k, v) values[k] = v end
    function S.OnChange() end
    return S
end

local function Fixture()
    local s = { frames = {}, panels = {}, tickers = {}, sounds = {}, flashes = 0, printed = {}, menus = {},
        tip = {}, confirms = {}, units = {}, now = 1000, inside = false, account = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.CreateFrame = function(kind)
        local f = Frame(kind)
        s.frames[#s.frames + 1] = f
        return f
    end
    env.hooksecurefunc = function(t, key, fn)
        local old = t[key]
        t[key] = function(...) local r = old(...); fn(...); return r end
    end
    env.time = function() return s.now end
    env.wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    env.issecretvalue = function(v) return v == SECRET end
    env.C_AddOns = { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end }
    env.C_Timer = { NewTicker = function(seconds, fn)
        local t = { seconds = seconds, fn = fn }
        function t:Cancel() self.cancelled = true end
        s.tickers[#s.tickers + 1] = t
        return t
    end }
    env.SOUNDKIT = { MAP_PING = 3175, RAID_WARNING = 8959 }
    env.PlaySound = function(kit, channel) s.sounds[#s.sounds + 1] = kit; s.channel = channel end
    env.FlashClientIcon = function() s.flashes = s.flashes + 1 end
    env.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.GameTooltip = { SetText = function(_, text, r) s.tip = { text = text, r = r } end,
        AddLine = function(_, text) s.tip[#s.tip + 1] = text end }
    env.MenuUtil = { CreateContextMenu = function(owner, generate)
        local menu = { owner = owner, buttons = {} }
        local root = { CreateTitle = function(_, title) menu.title = title end,
            CreateButton = function(_, text, fn, data) menu.buttons[#menu.buttons + 1] = { text = text, fn = fn, data = data } end }
        generate(owner, root)
        s.menus[#s.menus + 1] = menu
    end }
    env.IsInInstance = function() return s.inside end

    local function Unit(token)
        if token == SECRET then error("a secret unit token was passed to the game", 3) end
        return s.units[token] or {}
    end
    env.UnitIsPlayer = function(token) return Unit(token).player end
    env.UnitFactionGroup = function(token)
        if token == "player" then return "Alliance" end
        return Unit(token).faction
    end
    env.UnitGUID = function(token) return Unit(token).guid end
    env.UnitName = function(token) return Unit(token).name, Unit(token).realm end
    env.UnitLevel = function(token) return Unit(token).level end
    env.UnitClass = function(token) return "Class", Unit(token).class end
    env.GetGuildInfo = function(token) return Unit(token).guild end

    local pvp = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        PvPSpells = { crowdControl = {}, debuffs = {} },
        THEME = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accentSoft = { r = 0, g = 0, b = 1 } },
        Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end }
    ns.AccountSettings = function() return s.account end
    ns.Print = function(text) s.printed[#s.printed + 1] = text end
    ns.Confirm = function(text, yes) s.confirms[#s.confirms + 1] = { text = text, yes = yes } end
    ns.UI = {
        ModuleSettings = function(key, defaults)
            assert(key == "pvp", "the PvP module's own store")
            for k, v in pairs(defaults) do pvp[k] = v end
            return Store(pvp)
        end,
        AttachMover = function(frame, label, onMoved, page, feature)
            local m = Frame("Mover")
            m.shown, m.frame, m.label, m.onMoved, m.page, m.feature = false, frame, label, onMoved, page, feature
            return m
        end,
    }
    ns.Shared = { Style = dofile("Tools/regression/shared_style.lua"),
        Ago = function(when) return ("%ds ago"):format(s.now - when) end,
        Parts = { TrackerPanel = function(title, opts)
            local p = Frame("Tracker")
            p.title, p.opts, p.rows = title, opts, {}
            p.mover = opts.mover(p, function(pos) opts.save(pos.point, pos.relPoint, pos.x, pos.y) end)
            function p:Place() self.at = { opts.load() } end
            function p:Paint() end
            function p:SetRows(entries)
                self.rows = {}
                for i, e in ipairs(entries) do self.rows[i] = e end
                return #entries
            end
            function p:Fit(height) self.height = height end
            s.panels[#s.panels + 1] = p
            return p
        end },
        Settings = { Page = function(key) return { Card = function(_, card) s.page, s.card = key, card end } end } }
    env.NaowhForever = ns
    Load({ "Core/Features.lua", "NaowhForever_Combat/PvP/PvP.lua", "NaowhForever_Combat/PvP/View/Style.lua",
        "NaowhForever_Combat/PvP/Enemies.lua", "NaowhForever_Combat/PvP/UI/EnemyList.lua",
        "NaowhForever_Combat/PvP/UI/EnemiesPage.lua" }, env)
    s.env, s.ns, s.S, s.pvp = env, ns, ns.PvPSettings, pvp
    s.Enemies = ns.PvP.Enemies
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    function s.Listening(event)
        for _, f in ipairs(s.frames) do
            if f.events[event] then return true end
        end
        return false
    end
    function s.Panel() return s.panels[1] end
    function s.Ticker()
        local t = s.tickers[#s.tickers]
        if t and not t.cancelled then return t end
    end
    function s.Tick(seconds)
        s.now = s.now + seconds
        local t = s.Ticker()
        if t then t.fn(t) end
    end
    function s.Row(i)
        local p = s.Panel()
        return p and p.rows[i]
    end
    function s.Click(i)
        local entry = s.Row(i)
        entry.click({ entry = entry }, "RightButton")
        return s.menus[#s.menus]
    end
    s.Fire("PLAYER_LOGIN")
    return s
end

local function Enemy(guid, name, extra)
    local u = { player = true, faction = "Horde", guid = guid, name = name, level = 60, class = "WARRIOR" }
    for k, v in pairs(extra or {}) do u[k] = v end
    return u
end

local function On(s)
    s.S.Set("enabled", true)
    s.S.Set("nearbyEnemies", true)
end

do -- off: nothing made, nothing heard
    local s = Fixture()
    Check(s.ns.FEATURES.pvp.nearbyEnemies == false and s.pvp.nearbyEnemies == false, "off by default")
    Check(s.pvp.enemiesAlert == false and s.pvp.enemiesKillAlert == true and s.pvp.enemiesPos == false,
        "the new enemy alert starts off, the Kill on Sight alert on, no position")
    Check(#s.frames == 1 and not s.Listening("PLAYER_LOGIN"), "off: only the login frame, done once logged in")
    s.S.Set("enabled", true)
    s.ns.Apply()
    s.ns.ShowUnlockMode()
    s.ns.HideUnlockMode()
    Check(#s.frames == 1 and #s.panels == 0 and #s.tickers == 0, "PvP on, Nearby Enemies off: no frame, list or ticker")
    Check(s.page == "PvP/Nearby Enemies" and s.card.id == "nearbyEnemies" and s.card.switch == "nearbyEnemies",
        "the card is on its own page, switched by nearbyEnemies")
end

do -- on: who is listed, and how
    local s = Fixture()
    On(s)
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
        "UPDATE_MOUSEOVER_UNIT", "PLAYER_ENTERING_WORLD" }) do
        Check(s.Listening(event), "on: listens to " .. event)
    end
    Check(#s.panels == 0, "on with nobody seen: no list yet")

    s.units.nameplate1 = { player = false, faction = "Horde", name = "Kobold", guid = "Creature-0-1" }
    s.units.nameplate2 = Enemy("Player-1-00A", "Fairfax", { faction = "Alliance" })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Check(#s.Enemies.list == 0 and #s.panels == 0, "a creature and a player of your own faction are not listed")

    s.units.nameplate3 = Enemy("Player-1-00B", "Grimtusk", { guild = "Red Fang" })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    local p = s.Panel()
    Check(#s.Enemies.list == 1 and p and p.shown, "an enemy player is listed, and the list shows")
    local row = s.Row(1)
    Check(row.text == "Grimtusk" and row.color == s.env.RAID_CLASS_COLORS.WARRIOR, "their name in their class colour")
    Check(row.sub:find("Level 60", 1, true) and row.sub:find("<Red Fang>", 1, true) and row.sub:find("in range", 1, true),
        "their level, guild and in range while their nameplate is up")
    Check(s.Enemies.list[1].key == "Player-1-00B", "kept by GUID")
    Check(#s.sounds == 0 and s.flashes == 0, "no alert while Alert on New Enemies is off")
    Check(p.mover.page == "PvP/Nearby Enemies" and p.mover.feature == "PvP/Nearby Enemies:nearbyEnemies"
        and not p.mover.shown, "movable in the HUD Editor, its mover hidden outside it")
    Check(p.opts.settings.page == "PvP/Nearby Enemies" and p.opts.settings.card == "nearbyEnemies",
        "the cog opens its card")

    s.units.nameplate4 = Enemy("Player-1-00C", "Vex", { level = -1, class = "MAGE" })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    local vex
    for i = 1, 2 do if s.Row(i).enemy.name == "Vex" then vex = s.Row(i) end end
    Check(vex and vex.sub:find("Level ??", 1, true) and not vex.sub:find("<", 1, true), "far above you: Level ??, no guild")

    -- Seen by target or mouseover, without a nameplate: seen now, not in range.
    s.units.target = Enemy("Player-1-00D", "Thrall")
    s.Fire("PLAYER_TARGET_CHANGED")
    s.units.mouseover = Enemy("Player-1-00E", "Mork")
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    Check(#s.Enemies.list == 4, "your target and mouseover are listed too")
    local mork
    for i = 1, 4 do if s.Row(i).enemy.name == "Mork" then mork = s.Row(i) end end
    Check(mork.sub:find("0s ago", 1, true), "without a nameplate: seen just now, not in range")
    Check(s.Row(1).enemy.near and s.Row(2).enemy.near and not s.Row(3).enemy.near, "those in range first")

    -- Their nameplate goes: the time seen starts then.
    s.now = s.now + 30
    s.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    s.now = s.now + 20
    s.Tick(0)
    local grim
    for i = 1, 4 do if s.Row(i).enemy.name == "Grimtusk" then grim = s.Row(i) end end
    Check(grim and not grim.enemy.near and grim.sub:find("20s ago", 1, true), "out of range: seen since the nameplate went")
    s.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    Check(true, "a nameplate never listed going is ignored")

    -- Seen again: kept, not listed twice.
    s.units.nameplate5 = s.units.nameplate3
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    Check(#s.Enemies.list == 4 and s.Enemies.list[1].name == "Grimtusk" and s.Enemies.list[1].near,
        "seen again: the same entry, back in range")
end

do -- secret values are never used
    local s = Fixture()
    On(s)
    s.Fire("NAME_PLATE_UNIT_ADDED", SECRET)
    s.Fire("NAME_PLATE_UNIT_REMOVED", SECRET)
    s.units.nameplate1 = Enemy("Player-1-001", "Hidden", { player = SECRET })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    s.units.nameplate2 = Enemy("Player-1-002", "Hidden", { faction = SECRET })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    s.units.nameplate3 = Enemy("Player-1-003", SECRET)
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    s.units.nameplate4 = Enemy(SECRET, "Zug", { realm = "Firemaw" })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    Check(#s.Enemies.list == 0, "a secret token, player check, faction, name or GUID: nobody listed")
    s.units.nameplate5 = Enemy("Player-1-005", "Zog", { level = SECRET, class = SECRET, guild = SECRET })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    local enemy = s.Enemies.list[1]
    Check(enemy and enemy.key == "Player-1-005", "kept by GUID")
    Check(enemy.level == nil and enemy.class == nil and enemy.guild == nil, "a secret level, class or guild is left out")
    Check(s.Row(1).color == s.ns.THEME.fg and s.Row(1).sub:find("Level ??", 1, true), "drawn without them")
end

do -- one key per player: Kill on Sight never misses them or lists them twice
    local s = Fixture()
    On(s)
    s.units.mouseover = Enemy("Player-1-001", "Grimtusk", { realm = "Firemaw" })
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    s.Enemies.SetKill(s.Enemies.list[1], true)
    Check(s.account.pvpKillOnSight["Player-1-001"] == "Grimtusk", "on Kill on Sight by GUID")
    s.units.target = Enemy(SECRET, "Grimtusk", { realm = "Firemaw" })
    s.Fire("PLAYER_TARGET_CHANGED")
    Check(#s.Enemies.list == 1 and s.Enemies.list[1].kill, "seen with a secret GUID: no second, unmarked row")
    s.units.mouseover = Enemy("Player-1-002", "Grimtusk", { realm = "Firemaw" })
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    local marked = 0
    for _, other in ipairs(s.Enemies.list) do
        if other.kill then marked = marked + 1 end
    end
    Check(#s.Enemies.list == 2 and marked == 1, "another Grimtusk of the same realm is someone else, not on the list")
    s.now = s.now + 400
    s.units.nameplate1 = Enemy("Player-1-001", "Grimtusk", { realm = "Firemaw" })
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(#s.printed == 1 and s.sounds[1] == 8959, "back after a while: Kill on Sight matches them, once")
end

do -- a crowd past the cap: each enemy alerts once until they go unseen for five minutes
    local s = Fixture()
    On(s)
    s.S.Set("enemiesAlert", true)
    s.account.pvpKillOnSight = { ["Player-1-020"] = "Zug" }
    for _ = 1, 3 do
        for i = 1, 12 do
            s.now = s.now + 5
            s.units.mouseover = Enemy(("Player-1-%03d"):format(i), "Enemy" .. i)
            s.Fire("UPDATE_MOUSEOVER_UNIT")
        end
        s.now = s.now + 5
        s.units.mouseover = Enemy("Player-1-020", "Zug")
        s.Fire("UPDATE_MOUSEOVER_UNIT")
    end
    Check(#s.Enemies.list == 8, "the list keeps eight")
    local pings, warnings = 0, 0
    for _, kit in ipairs(s.sounds) do
        if kit == 3175 then pings = pings + 1 elseif kit == 8959 then warnings = warnings + 1 end
    end
    Check(pings == 12 and warnings == 1 and #s.printed == 1,
        "dropped and seen again within five minutes: no new alert, Kill on Sight's included")

    s.units.nameplate1 = Enemy("Player-1-030", "Vex")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    for i = 1, 8 do
        s.now = s.now + 1
        s.units["nameplate" .. (i + 1)] = Enemy(("Player-1-%03d"):format(40 + i), "Other" .. i)
        s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. (i + 1))
    end
    local listed = false
    for _, enemy in ipairs(s.Enemies.list) do listed = listed or enemy.name == "Vex" end
    local before = #s.sounds
    s.now = s.now + 400
    s.units.mouseover = s.units.nameplate1
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    Check(not listed and #s.sounds == before, "dropped while still in range: seen all along, no new alert")

    local quiet = #s.sounds
    s.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    s.now = s.now + 299
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    Check(#s.sounds == quiet, "seen again within five minutes of their nameplate going: quiet")
    s.now = s.now + 300
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    Check(#s.sounds == quiet + 1, "unseen for five minutes: they alert again")
end

do -- expiry, the ticker and closing the list
    local s = Fixture()
    On(s)
    s.units.mouseover = Enemy("Player-1-001", "Grimtusk")
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    local t = s.Ticker()
    Check(t and t.seconds == 10, "a ticker for the times while the list shows names")
    s.Tick(290)
    Check(#s.Enemies.list == 1 and s.Panel().shown, "still listed before five minutes")
    s.Tick(10)
    Check(#s.Enemies.list == 0 and not s.Panel().shown and t.cancelled and not s.Ticker(),
        "five minutes unseen: dropped, the list hides and its ticker stops")

    s.units.nameplate1 = Enemy("Player-1-002", "Vex")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    s.Tick(600)
    Check(#s.Enemies.list == 1, "in range never expires")

    s.Panel().opts.onClose()
    Check(not s.Panel().shown and not s.Ticker(), "closed: hidden, no ticker")
    s.units.target = s.units.nameplate1
    s.Fire("PLAYER_TARGET_CHANGED")
    Check(not s.Panel().shown, "closed: someone already listed does not bring it back")
    s.units.target = Enemy("Player-1-003", "Mork")
    s.Fire("PLAYER_TARGET_CHANGED")
    Check(s.Panel().shown and s.Ticker(), "a new enemy brings it back")
end

do -- the cap
    local s = Fixture()
    On(s)
    for i = 1, 8 do
        s.now = s.now + 1
        s.units.mouseover = Enemy("Player-1-00" .. i, "Enemy" .. i)
        s.Fire("UPDATE_MOUSEOVER_UNIT")
    end
    for _, enemy in ipairs(s.Enemies.list) do
        if enemy.name == "Enemy1" then s.Enemies.SetKill(enemy, true) end
    end
    s.now = s.now + 1
    s.units.mouseover = Enemy("Player-1-009", "Enemy9")
    s.Fire("UPDATE_MOUSEOVER_UNIT")
    local names = {}
    for _, enemy in ipairs(s.Enemies.list) do names[enemy.name] = true end
    Check(#s.Enemies.list == 8 and names.Enemy9 and names.Enemy1 and not names.Enemy2,
        "at most eight: the one seen longest ago goes, Kill on Sight kept")
end

do -- Kill on Sight
    local s = Fixture()
    On(s)
    s.units.nameplate1 = Enemy("Player-1-001", "Grimtusk")
    s.units.nameplate2 = Enemy("Player-1-002", "Vex")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    local vexAt
    for i = 1, 2 do if s.Row(i).enemy.name == "Vex" then vexAt = i end end
    s.Row(vexAt).tip({ entry = s.Row(vexAt) })
    Check(s.tip.text == "Vex" and s.tip[1] and s.tip[1]:find("Kill on Sight", 1, true), "the row's tip says how")
    local menu = s.Click(vexAt)
    Check(menu.title == "Vex" and #menu.buttons == 1 and menu.buttons[1].text == "Add to Kill on Sight",
        "its menu offers Kill on Sight")
    menu.buttons[1].fn(menu.buttons[1].data)
    Check(s.account.pvpKillOnSight["Player-1-002"] == "Vex", "saved account-wide by GUID, with their name")
    Check(s.Row(1).enemy.name == "Vex" and s.Row(1).text:find("KoS", 1, true) and s.Row(1).text:find("Vex", 1, true),
        "on the list: marked and first")
    Check(s.Enemies.KillCount() == 1, "counted")
    menu = s.Click(1)
    Check(menu.buttons[1].text == "Remove from Kill on Sight", "and it can be taken off")
    menu.buttons[1].fn(menu.buttons[1].data)
    Check(s.account.pvpKillOnSight["Player-1-002"] == nil and not s.Row(1).text:find("KoS", 1, true)
        and not s.Row(2).text:find("KoS", 1, true), "taken off: unmarked")
    Check(s.Enemies.KillCount() == 0, "none left")

    -- The alerts: once, as an enemy joins the list.
    s.account.pvpKillOnSight["Player-1-009"] = "Zug"
    s.units.nameplate3 = Enemy("Player-1-009", "Zug")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    Check(s.sounds[1] == 8959 and s.channel == "Master" and s.flashes == 1 and s.printed[1]
        and s.printed[1]:find("Zug", 1, true), "Kill on Sight: a raid warning, a flash and a line in chat")
    s.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    Check(#s.sounds == 1 and #s.printed == 1, "back in range: no second alert")
    s.units.nameplate4 = Enemy("Player-1-010", "Mork")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    Check(#s.sounds == 1 and s.flashes == 1, "a new enemy: nothing while Alert on New Enemies is off")
    s.S.Set("enemiesAlert", true)
    s.units.nameplate5 = Enemy("Player-1-011", "Thrall")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
    Check(s.sounds[2] == 3175 and s.flashes == 2 and #s.printed == 1, "with it on: a ping and a flash")
    s.S.Set("enemiesKillAlert", false)
    s.account.pvpKillOnSight["Player-1-012"] = "Garrosh"
    s.units.nameplate6 = Enemy("Player-1-012", "Garrosh")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate6")
    Check(s.sounds[3] == 3175 and #s.printed == 1, "Kill on Sight Alert off: the plain alert instead")

    -- Cleared from the settings card, after asking.
    local clear = s.card.rows[3]
    Check(clear.needs() == true, "the Clear button is there while someone is on the list")
    clear.button()
    Check(#s.confirms == 1 and s.confirms[1].text:find("2", 1, true), "it asks first, with how many")
    s.confirms[1].yes()
    Check(s.Enemies.KillCount() == 0 and not clear.needs(), "cleared")
    for _, enemy in ipairs(s.Enemies.list) do Check(not enemy.kill, enemy.name .. " unmarked") end
end

do -- instances, loading screens and switching off
    local s = Fixture()
    On(s)
    s.S.Set("enemiesAlert", true)
    s.units.nameplate1 = Enemy("Player-1-001", "Grimtusk")
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    s.ns.Apply()
    Check(#s.Enemies.list == 1 and s.Panel().shown, "a profile or spec change keeps the list")
    s.inside = true
    s.Fire("PLAYER_ENTERING_WORLD")
    Check(#s.Enemies.list == 0 and not s.Panel().shown and not s.Ticker(), "into an instance: emptied and hidden")
    Check(s.Listening("PLAYER_ENTERING_WORLD") and not s.Listening("NAME_PLATE_UNIT_ADDED")
        and not s.Listening("PLAYER_TARGET_CHANGED"), "inside: only the loading screen is heard")
    s.inside = false
    s.Fire("PLAYER_ENTERING_WORLD")
    Check(s.Listening("NAME_PLATE_UNIT_ADDED"), "back out: listening again")
    s.now = s.now + 60
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(#s.Enemies.list == 1 and #s.sounds == 1, "the same enemy within five minutes of a loading screen: listed, no second alert")
    s.S.Set("nearbyEnemies", false)
    Check(#s.Enemies.list == 0 and not s.Panel().shown and not s.Ticker(), "switched off: emptied, hidden, no ticker")
    Check(not s.Listening("NAME_PLATE_UNIT_ADDED") and not s.Listening("PLAYER_ENTERING_WORLD"), "off: nothing heard")
    s.S.Set("nearbyEnemies", true)
    s.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    Check(#s.sounds == 2, "switched off and on again: they alert afresh")
end

do -- the HUD Editor
    local s = Fixture()
    On(s)
    s.ns.ShowUnlockMode()
    local p = s.Panel()
    Check(p and p.shown and p.mover.shown, "in the HUD Editor: shown with its mover")
    Check(s.Row(1).text:find("show up here", 1, true) and s.Row(1).color == s.ns.THEME.muted and not s.Ticker(),
        "empty: a muted line in its place, and no ticker")
    p.mover.onMoved({ point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -20 })
    Check(s.pvp.enemiesPos.point == "TOPLEFT" and s.pvp.enemiesPos.x == 10, "dragged: its place is saved")
    s.ns.HideUnlockMode()
    Check(not p.shown, "out of it, empty: hidden")
    s.ns.Apply()
    Check(p.at[1] == "TOPLEFT" and p.at[3] == 10, "a profile change places it again")
    s.units.target = Enemy("Player-1-001", "Grimtusk")
    s.Fire("PLAYER_TARGET_CHANGED")
    Check(p.shown and not p.mover.shown, "an enemy seen later: shown, its mover hidden")
end

print("PASS pvp enemies: " .. checks .. " checks")
