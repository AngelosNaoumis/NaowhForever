-- Run with Lua 5.1 from the repository root: the Forever skin. Every part is built on the game's
-- own art when the client has it (atlases asked through C_Texture.GetAtlasInfo, frames through
-- NineSliceUtil) and drawn from Style.lua's tokens when it does not, so nothing ever shows a
-- missing texture. On Naowh nothing of it is made, and a saved Classic+ skin is moved to it.
-- Every Forever button is the game's one red button, a card's +/- is the Friends list header's at
-- its own size, and an off card's check boxes keep the game's dimmed box and disabled tick.
-- The options window is built for real on Forever: its header band, rails and bar navigation.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local ATLAS_W, ATLAS_H = 64, 32
local present, missingFiles, atlasCalls, layouts
local frames

-- Only buttons have a highlight texture in the game; a plain Frame (the Top Bar preview's samples) has none.
local LIT_KINDS = { Button = true, CheckButton = true }

local function New(kind, parent)
    local o = { kind = kind, parent = parent, points = {}, scripts = {}, events = {}, children = {},
        shown = true, w = 0, h = 0 }
    if parent and rawget(parent, "children") then table.insert(parent.children, o) end
    return setmetatable(o, { __index = function(t, k)
        if not k:match("^%u") then return nil end
        if k == "GetHighlightTexture" and not LIT_KINDS[t.kind] then return nil end
        return function(self, ...)
            local args = { ... }
            if k == "SetScript" then self.scripts[args[1]] = args[2]
            elseif k == "GetScript" then return self.scripts[args[1]]
            elseif k == "HookScript" then
                local old = self.scripts[args[1]]
                local fn = args[2]
                self.scripts[args[1]] = function(...) if old then old(...) end return fn(...) end
            elseif k == "SetPoint" then self.points[#self.points + 1] = args
            elseif k == "ClearAllPoints" then self.points = {}
            elseif k == "SetAllPoints" then self.points = { { "ALL", args[1] } }
            elseif k == "RegisterEvent" then self.events[args[1]] = true
            elseif k == "SetGradient" then self.gradient = { args[2], args[3] }
            elseif k == "SetColorTexture" or k == "SetTextColor" or k == "SetVertexColor" then self.color = args
            elseif k == "SetTexture" then
                self.texture = args[1]
                return not missingFiles[args[1]]
            elseif k == "SetAtlas" then
                atlasCalls[#atlasCalls + 1] = args[1]
                self.atlas = args[1]
                if args[2] then self.w, self.h = ATLAS_W, ATLAS_H end
            elseif k == "SetNormalAtlas" then atlasCalls[#atlasCalls + 1] = args[1]; self.normalAtlas = args[1]
            elseif k == "SetPushedAtlas" then atlasCalls[#atlasCalls + 1] = args[1]; self.pushedAtlas = args[1]
            elseif k == "SetHighlightAtlas" then atlasCalls[#atlasCalls + 1] = args[1]; self.highlightAtlas = args[1]
            elseif k == "SetHighlightTexture" then
                self.highlight = New("Texture", self)
                self.highlight.texture = args[1]
            elseif k == "GetHighlightTexture" then return self.highlight
            elseif k == "LockHighlight" then self.lockedLit = true
            elseif k == "UnlockHighlight" then self.lockedLit = false
            elseif k == "SetStatusBarColor" then self.barColor = args
            elseif k == "SetStatusBarTexture" then
                self.bar = self.bar or New("Texture", self)
                self.bar.texture = args[1]
            elseif k == "GetStatusBarTexture" then
                self.bar = self.bar or New("Texture", self)
                return self.bar
            elseif k == "SetTexCoord" then self.coords = args
            elseif k == "SetRotation" then self.rotation = args[1]
            elseif k == "SetShown" then self.shown = args[1] and true or false
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "IsShown" then return self.shown
            elseif k == "IsEnabled" then return true
            elseif k == "SetSize" then self.w, self.h = args[1], args[2]
            elseif k == "SetHeight" then self.h = args[1]
            elseif k == "SetWidth" then self.w = args[1]
            elseif k == "GetHeight" then return self.h
            elseif k == "GetWidth" then return self.w
            elseif k == "GetText" then return self.text or ""
            elseif k == "SetText" then self.text = args[1]
            elseif k == "SetFont" then self.font = args[1]
            elseif k == "GetTextColor" then return 1, 1, 1, 1
            elseif k == "SetAlpha" then self.alpha = args[1]
            elseif k == "EnableMouse" then self.mouse = args[1]
            elseif k == "SetFrameStrata" then self.strata = args[1]
            elseif k == "GetFrameLevel" then return rawget(self, "level") or 1
            elseif k == "GetPoint" then local p = self.points[1]; if p then return unpack(p) end
            elseif k == "SetNormalTexture" then self.normal = args[1]
            elseif k == "SetPushedTexture" then self.pushed = args[1]
            elseif k == "SetFrameLevel" then self.level = args[1]
            elseif k == "SetParent" then self.parent = args[1]
            elseif k == "GetParent" then return self.parent
            elseif k == "GetStringWidth" then return 20
            elseif k == "GetStringHeight" then return 12
            elseif k == "GetEffectiveScale" then return 1
            elseif k == "GetObjectType" then return self.kind
            elseif k == "AddMaskTexture" then self.mask = args[1]
            elseif k == "CreateTexture" then return New("Texture", self)
            elseif k == "CreateMaskTexture" then return New("MaskTexture", self)
            elseif k == "CreateFontString" then return New("FontString", self)
            end
        end
    end })
end

local SHARED = { "Core/Core.lua", "Shared/Shared.lua", "Shared/Style.lua", "Core/Options/Widgets.lua",
    "Shared/UI/Parts.lua", "Shared/UI/Menus.lua", "Shared/UI/GamepadNav.lua", "Shared/UI/Marks.lua", "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Timer.lua",
    "Shared/UI/Share.lua", "Shared/UI/Panels.lua", "Shared/UI/Window.lua", "Shared/UI/Forever.lua",
    "Shared/UI/Tabs.lua", "Shared/UI/SettingsCard.lua", "Shared/View/View.lua",
    "Shared/Settings/Settings.lua", "Shared/Settings/Style.lua", "Shared/Settings/Controls.lua",
    "Shared/Settings/Rows.lua", "Shared/Settings/Page.lua" }
local WINDOW = { "Core/Options/Modules.lua", "Core/Options/Categories.lua", "Core/Options/Window.lua",
    "Core/Options/HomePage.lua", "Core/Options/Search.lua" }
local timers = {}

local function Load(account, atlases, files, extra)
    frames, atlasCalls, layouts = {}, {}, {}
    present, missingFiles = atlases or {}, files or {}
    local env = setmetatable({
        NaowhForeverDB = { account = account, profiles = {}, charActive = {} },
        InputUtil = { IsGamepadUIEnabled = function() return false end }, IsLoggedIn = function() return true end,
        C_AddOns = { IsAddOnLoaded = function() return true end, GetAddOnMetadata = function() return "test" end,
            GetAddOnEnableState = function() return 2 end },
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        InCombatLockdown = function() return false end,
        UnitGUID = function() return "Player-1" end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        GameTooltip = New("Frame"),
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        Mixin = function(object, ...)
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do object[k] = v end
            end
            return object
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function(kind, _, parent)
            local f = New(kind, parent)
            frames[#frames + 1] = f
            return f
        end,
        CreateColor = function(r, g, b, a)
            return { r = r, g = g, b = b, a = a, SetRGBA = function(c, ...) c.r, c.g, c.b, c.a = ... end }
        end,
        PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end },
        UIParent = New("Frame"),
        GetCursorPosition = function() return 100, 100 end,
        C_Texture = { GetAtlasInfo = function(name) return present[name] and { width = ATLAS_W, height = ATLAS_H,
            file = name, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 } or nil end },
        NineSliceUtil = { ApplyLayoutByName = function(container, name)
            container.layout = name
            layouts[#layouts + 1] = name
        end },
    }, { __index = _G })
    env._G = env
    local made = {}
    local paths = {}
    for _, path in ipairs(SHARED) do paths[#paths + 1] = path end
    for _, path in ipairs(extra or {}) do paths[#paths + 1] = path end
    for _, path in ipairs(paths) do
        local before = #frames
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk("NaowhForever", env.NaowhForever)
        made[path] = #frames - before
    end
    for _, f in ipairs(frames) do
        if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "NaowhForever") end
    end
    return env.NaowhForever, made
end

local function Find(list, test)
    for _, x in ipairs(list) do if test(x) then return x end end
end

local function Holds(frame, test)
    for _, c in ipairs(frame.children) do
        if test(c) then return c end
        local deeper = Holds(c, test)
        if deeper then return deeper end
    end
end

local function AllAtlases(St)
    local set = {}
    local function Add(name) set[name] = true end
    for _, name in ipairs(St.FOREVER_FRAME_ATLASES) do Add(name) end
    for _, name in ipairs(St.FOREVER_INSET_ATLASES) do Add(name) end
    for _, name in ipairs(St.FOREVER_BARE_ATLASES) do Add(name) end
    for _, group in ipairs({ St.FOREVER_CLOSE_ATLAS, St.FOREVER_TAB_ATLAS, St.FOREVER_ACTIVE_TAB_ATLAS,
        St.FOREVER_SEARCH_ATLAS }) do
        for _, name in pairs(group) do Add(name) end
    end
    for _, group in ipairs({ St.FOREVER_DROPDOWN_ATLAS, St.FOREVER_SLIDER_ATLAS, St.FOREVER_LIST_ATLAS }) do
        for _, name in pairs(group) do Add(name) end
    end
    for _, name in pairs(St.FOREVER_SCROLL_ATLAS) do
        Add(name); Add(name .. St.FOREVER_SCROLL_OVER); Add(name .. St.FOREVER_SCROLL_PRESSED)
    end
    for _, name in ipairs({ St.FOREVER_BAR_ATLAS, St.FOREVER_PLUS_ATLAS, St.FOREVER_MINUS_ATLAS,
        St.FOREVER_GROUP_ATLAS, St.FOREVER_DIVIDER_ATLAS, St.FOREVER_WINDOW_ART, St.FOREVER_BAND_ART,
        St.FOREVER_RING_ATLAS, St.FOREVER_DRAGON_ATLAS,
        St.FOREVER_HUD_FRAME.atlas, St.FOREVER_ROW_PICK_ATLAS, St.FOREVER_CAST_BAR.frame, St.FOREVER_CAST_BAR.fill,
        St.FOREVER_CAST_BAR.track }) do Add(name) end
    local red = St.FOREVER_RED_BUTTON_ATLAS
    for _, suffix in ipairs(St.FOREVER_RED_BUTTON_STATES) do
        Add(red.left .. suffix); Add(red.center .. suffix); Add(red.right .. suffix)
    end
    Add(red.highlight)
    return set
end

-- The red button's three pieces, as Blizzard's ThreeSliceButtonMixin names them for a state.
local redAtlas
local function RedPieces(btn, suffix)
    local red, art = redAtlas, btn.redArt
    return art ~= nil and art[1].atlas == red.left .. suffix and art[2].atlas == red.center .. suffix
        and art[3].atlas == red.right .. suffix
end

local function Tip()
    return Find(frames, function(f) return rawget(f, "strata") == "TOOLTIP" end)
end

local function Head(ns, card)
    local view = New("Frame")
    local head = ns.Shared.Settings.kinds.cardHead.New(view)
    ns.Shared.Settings.kinds.cardHead.Set(head, card, false, false)
    return head, view
end

local function Navigable()
    local btn = New("Button")
    btn.fill = btn:CreateTexture()
    btn.marker = btn:CreateTexture()
    return btn
end

local function Controls(ns)
    local on = true
    local toggle = ns.UI.BuildToggleControl(New("Frame"), nil, function() return on end, function(v) on = v end)
    local dd = ns.UI.BuildDropdownControl(New("Frame"), 160, nil, { a = "A" }, { "a" }, function() return "a" end, function() end)
    local value = 50
    local slider = ns.UI.BuildSliderCore(New("Frame"), 200, 4, 12, 40, 20, 12, 1, 0, 100, 1,
        function() return value end, function(v) value = v end)
    local swatch = ns.UI.BuildColorSwatchControl(New("Frame"), function() return 1, 1, 1 end, function() end)
    return { toggle = toggle, dropdown = dd, slider = slider, swatch = swatch }
end

-- Naowh: nothing of Forever is made, and the house look stays.
local Probe = Load({})
local St = Probe.Shared.Style
redAtlas = St.FOREVER_RED_BUTTON_ATLAS
local ALL = AllAtlases(St)
do
    local ns, made = Load({}, ALL)
    check("Forever's file makes nothing at load", made["Shared/UI/Forever.lua"] == 0 and #atlasCalls == 0)
    check("Naowh: the skin is read as the default", ns.Skin() == "" and not ns.foreverSkin)
    local window = ns.Shared.Parts.Window(400, 300, "test")
    ns.Shared.Parts.TitleBar(window, "Title", "Sub")
    local btn = ns.Button(New("Frame"), "Go", 80, 20)
    local tabs = ns.Shared.Parts.Tabs(New("Frame"), 300, { { key = "a", label = "A" } }, function() end)
    local choice = ns.Shared.Parts.Tabs(New("Frame"), 300, { { key = "a", label = "A" } }, function() end, nil, nil, true)
    local c = Controls(ns)
    check("Naowh: no Forever frame, button, tab or check", window.forever == nil and not btn._forever
        and tabs.buttons[1].idleArt == nil and tabs.buttons[1].idleFill == nil and c.toggle.w == 40)
    check("Naowh: a strip asButtons is the same segments", not choice.asButtons and choice.buttons[1].mark
        and choice.buttons[1].redArt == nil)
    check("Naowh: the game's art is never asked for", #atlasCalls == 0 and #layouts == 0 and window.backdrop.pattern == nil)
end

-- Naowh segments preserve selection and fit long labels when a reused strip changes width.
do
    local ns = Load({})
    local Parts = ns.Shared.Parts
    local picked
    local items = { { key = "a", label = "A" }, { key = "b", label = "A much longer label" },
        { key = "c", label = "Another long category" } }
    local tabs = Parts.Tabs(New("Frame"), 180, items, function(key) picked = key end, true, true)
    for _, button in ipairs(tabs.buttons) do
        button.text.GetStringWidth = function(self) return #self.text * 7 end
    end
    Parts.SetTabs(tabs, items)
    Parts.PaintTabs(tabs, "a")
    local a, b = tabs.buttons[1], tabs.buttons[2]
    check("Naowh: selection has a fill and mark, with no underline", a.fill.shown and a.mark.shown and not a.line.shown)
    check("Naowh: other tabs start unfilled", not b.fill.shown and not b.mark.shown)
    local function TextX(button)
        local p = button.text.points
        return #p == 1 and p[1][1] == "CENTER" and p[1][2]
    end
    local markRoom = ns.Shared.Style.TAB_MARK_SIZE + ns.Shared.Style.TAB_MARK_GAP
    check("Naowh: the picked label moves right by half the diamond's room", TextX(a) == markRoom / 2)
    check("Naowh: other labels sit in the middle of their tab", TextX(b) == 0 and TextX(tabs.buttons[3]) == 0)
    b.scripts.OnEnter(b)
    check("Naowh: hovering does not move the selection", b.fill.shown and not b.mark.shown and tabs.shown == "a")
    b.scripts.OnLeave(b)
    check("Naowh: leaving clears the hover", not b.fill.shown and a.mark.shown)
    a.scripts.OnClick(a)
    check("Naowh: clicking the selection does nothing", picked == nil)
    b.scripts.OnClick(b)
    check("Naowh: another segment calls the page picker", picked == "b")
    local width = 0
    for _, button in ipairs(tabs.buttons) do
        width = width + button.w
        check("Naowh: compressed segments keep positive widths", button.w > 0 and button.text.w > 0)
    end
    check("Naowh: long labels fit inside the strip", width == 180 and b.cut and not a.cut)
    tabs:SetWidth(800)
    Parts.SetTabs(tabs, items)
    check("Naowh: widening restores full labels", not a.cut and not b.cut and not tabs.buttons[3].cut)
    items[1].note = " 5"
    Parts.SetTabs(tabs, items)
    check("Naowh: a tab's note follows its label and is measured with it", a.text.text == "A 5"
        and a.want == #"A 5" * 7 + markRoom)
    items[1].note = nil
    Parts.SetTabs(tabs, items)
    check("Naowh: and goes when cleared", a.text.text == "A")
    local measured = { ["Buy 2"] = 33, ["Sell 32"] = 40, ["My Auctions 5"] = 87, ["Shopping List"] = 85 }
    local dock = { { key = "buy", label = "Buy", note = " 2" }, { key = "sell", label = "Sell", note = " 32" },
        { key = "mine", label = "My Auctions", note = " 5" }, { key = "shop", label = "Shopping List" } }
    local panel = Parts.Tabs(New("Frame"), 360, dock, function() end, true)
    for _, button in ipairs(panel.buttons) do
        button.text.GetStringWidth = function(self) return measured[self.text] end
    end
    Parts.SetTabs(panel, dock)
    local whole = true
    for _, button in ipairs(panel.buttons) do whole = whole and not button.cut end
    check("Naowh: The Market's four panel tabs, with counts, fit its 380-wide panel whole", whole)
    Parts.SetTabs(tabs, { items[2], items[1] })
    check("Naowh: reused buttons follow keys after reordering", not a.mark.shown and b.mark.shown and not tabs.buttons[3].shown)
    check("Naowh: a label moves back to the middle once its tab is no longer picked", TextX(a) == 0 and TextX(b) == markRoom / 2)
    Parts.SetTabs(tabs, {})
    check("Naowh: an empty list hides old buttons", not a.shown and not b.shown)
    local backdrop = Parts.Backdrop(New("Frame"))
    backdrop:Paint(0.6)
    check("Naowh: the window surface is flat at its chosen opacity", backdrop.top.r == ns.THEME.bg.r
        and backdrop.top.g == backdrop.bottom.g and backdrop.top.b == backdrop.bottom.b
        and backdrop.top.a == 0.6 and backdrop.bottom.a == 0.6)
end

-- A picture of a Forever window (the onboarding's skin step) on the Naowh skin: the rock in the palette
-- it is given, the portrait frame, no drag strip and a close button that takes no clicks.
do
    local ns = Load({}, ALL)
    local Parts = ns.Shared.Parts
    local mini = New("Frame")
    local backdrop = Parts.Backdrop(mini, true)
    backdrop:Paint(1, ns.FOREVER_SKIN)
    local chrome = Parts.ForeverFrame(mini, { title = "Naowh Forever", preview = true })
    check("preview: the rock, painted in the palette it is given", backdrop.pattern.texture == St.FOREVER_ROCK
        and backdrop.top.r == ns.FOREVER_SKIN.panel.r and backdrop.top.g ~= ns.THEME.panel.g)
    check("preview: the portrait frame and its title", chrome.layout == St.FOREVER_FRAME_LAYOUT and chrome.portrait
        and chrome.title.text == "Naowh Forever")
    check("preview: it neither drags nor closes", chrome.strip == nil and chrome.close.mouse == false)
    local window = Parts.Window(400, 300, "test")
    check("Naowh: a real window still gets no rock", window.backdrop.pattern == nil)
end

-- Classic+ is retired: a player who had it gets Forever's frame.
do
    local ns = Load({ skin = "classic" }, ALL)
    local window = ns.Shared.Parts.Window(400, 300, "test")
    check("Classic+: saved as Forever and read as it", ns.AccountSettings().skin == "forever" and ns.Skin() == "forever"
        and ns.foreverSkin and window.forever ~= nil)
end

-- Forever, on a client with every atlas and file.
do
    local ns = Load({ skin = "forever" }, ALL)
    local Parts = ns.Shared.Parts
    check("Forever: the skin read as forever", ns.Skin() == "forever" and ns.foreverSkin)
    check("Forever: its own palette over any theme", ns.THEME.accent.r == ns.FOREVER_SKIN.accent.r
        and ns.THEME.panel.g == ns.FOREVER_SKIN.panel.g)
    local window = Parts.Window(400, 300, "test")
    local close = Parts.TitleBar(window, "Title", "Sub")
    local chrome = window.forever
    check("the window wears the game's portrait frame", chrome and chrome.art and chrome.layout == St.FOREVER_FRAME_LAYOUT
        and chrome.rings == nil)
    check("its title bar over the window, the title in gold", chrome.points[1][4] == -St.FOREVER_SIDE
        and chrome.points[1][5] == St.FOREVER_TITLE_H and chrome.title.text == "Naowh Forever"
        and chrome.title.color[1] == St.FOREVER_GOLD_RGB.r)
    check("the game's red close button", chrome.close.normalAtlas == St.FOREVER_CLOSE_ATLAS.normal
        and chrome.close.pushedAtlas == St.FOREVER_CLOSE_ATLAS.pushed and chrome.close.cross == nil)
    check("the logo in the portrait, the old close and logo stood down", chrome.portrait.logo.texture == St.LOGO
        and not close.shown and not window.logo.icon.shown and window.title.points[1][4] == St.FOREVER_PORTRAIT_ROOM)
    check("the logo fills the portrait, on a soft glow under the ring's shade", chrome.portrait.glow and chrome.portrait.glow.texture == St.ROUND
        and chrome.portrait.shade and chrome.portrait.shade.texture == St.RING)
    local portrait = chrome.portrait
    check("the logo in the game's minimap ring, its inside meeting the logo's disc", portrait.ringArt
        and portrait.ringArt.atlas == St.FOREVER_RING_ATLAS and portrait.ring == nil
        and math.abs(portrait.ringArt.w * St.FOREVER_RING_INNER - portrait.disc.w) < 0.01
        and portrait.ringArt.h == portrait.ringArt.w)
    check("its title bar drags it, its close takes clicks", chrome.strip and chrome.strip.window == window
        and chrome.close.mouse == nil)
    local dragged
    window:SetScript("OnDragStart", function(w) dragged = w end)
    chrome.strip.scripts.OnDragStart(chrome.strip)
    check("its title bar drags through the window's own drag script", dragged == window)
    chrome.close.scripts.OnClick(chrome.close)
    check("the red close button closes the window", window.shown == false)
    check("the game's rock behind it", window.backdrop.pattern.texture == St.FOREVER_ROCK
        and window.backdrop.patternShade == St.FOREVER_ROCK_SHADE)

    local btn = ns.Button(New("Frame"), "HUD Editor", 80, 20)
    check("a button: the game's red panel button, its highlight, gold text", btn._forever and RedPieces(btn, "")
        and btn.highlightAtlas == St.FOREVER_RED_BUTTON_ATLAS.highlight and not btn._bg.shown
        and not btn._border._frame.shown and btn.label.color[2] == St.FOREVER_GOLD_RGB.g)
    check("its pieces its art, so the Flight Timer fades them", btn._art == btn.redArt)
    check("its ends scaled to its height", btn.redArt[1].w == ATLAS_W * 20 / ATLAS_H
        and btn.redArt[3].w == ATLAS_W * 20 / ATLAS_H and btn.redArt[1].coords[2] == 1)
    btn.scripts.OnEnter(btn)
    check("hovered: white text", btn.label.color[1] == 1 and btn.label.color[2] == 1 and RedPieces(btn, ""))
    btn.scripts.OnLeave(btn)
    btn.scripts.OnMouseDown(btn)
    check("pressed: the pressed art", RedPieces(btn, "-Pressed"))
    btn.scripts.OnMouseUp(btn)
    check("let go: the plain art again", RedPieces(btn, ""))
    btn._border:SetColor(ns.THEME.accent.r, ns.THEME.accent.g, ns.THEME.accent.b, 1)
    check("a picked button pressed in and lit, no colored edge", RedPieces(btn, "-Pressed") and btn.lockedLit
        and not btn._border._frame.shown)
    btn.scripts.OnLeave(btn)
    check("and stays so when the mouse leaves", RedPieces(btn, "-Pressed") and btn.lockedLit)
    btn._border:SetColor(St.BORDER_RGB.r, St.BORDER_RGB.g, St.BORDER_RGB.b, 1)
    check("unpicked: the plain art, unlit, no edge", RedPieces(btn, "") and btn.lockedLit == false
        and not btn._border._frame.shown)
    rawset(btn, "IsEnabled", function() return false end)
    btn.scripts.OnDisable(btn)
    check("disabled: the grey art and grey text, as the quest log's Share", RedPieces(btn, "-Disabled")
        and btn.label.color[1] == St.FOREVER_DISABLED_TEXT_RGB.r)
    rawset(btn, "IsEnabled", nil)
    btn.scripts.OnEnable(btn)
    check("enabled again: the plain art, its text back", RedPieces(btn, "") and btn.label.color[1] == 1)
    local narrow = ns.Button(New("Frame"), "X", 60, 20)
    local share = 30 / (ATLAS_W * 20 / ATLAS_H)
    check("a narrow button crops its ends to fit, as the game's does", narrow.redArt[1].w == 30
        and narrow.redArt[1].coords[2] == share and narrow.redArt[3].coords[1] == 1 - share)
    local main = ns.AccentBorder(ns.Button(New("Frame"), "Reload UI", 80, 20))
    check("no golden or dark variant: the main action is the same red button", main._primary == nil
        and RedPieces(main, "") and main.label.color[2] == St.FOREVER_GOLD_RGB.g and Parts.ForeverPrimary == nil
        and St.FOREVER_PRIMARY_RGB == nil and St.FOREVER_BUTTON_RGB == nil)
    local windowCard = Parts.SettingsCardFrame(New("Frame"))
    check("a window card's button the red button too", RedPieces(windowCard.open, ""))
    check("a window card in the HUD's bronze frame, not a gold edge", windowCard.art
        and windowCard.art.pieces[1].texture == St.FOREVER_HUD_FRAME.atlas and not windowCard.edge._frame.shown)
    local hud = New("Frame")
    local backdrop = Parts.HudBackdrop(hud)
    local frame, pieces = St.FOREVER_HUD_FRAME, backdrop.art and backdrop.art.pieces
    local cornerShare = frame.corner / ATLAS_W
    check("a HUD card in a thin bronze frame, cut in eight so its corners stay whole", pieces and pieces[5] == nil
        and pieces[1].texture == frame.atlas and pieces[1].w == frame.size and pieces[9].h == frame.size
        and pieces[1].coords[2] == cornerShare and pieces[3].coords[1] == 1 - cornerShare
        and pieces[1].points[1][1] == "TOPLEFT" and pieces[1].points[1][2] == -frame.out
        and pieces[9].points[1][2] == frame.out and pieces[2].points[1][2] == pieces[1])
    check("its black edge stood down", not backdrop.border._frame.shown and backdrop.art.shown)
    backdrop:SetMode("soft")
    check("no frame on a soft background", not backdrop.art.shown and not backdrop.border._frame.shown)
    backdrop:SetMode("card")
    check("and back on a card", backdrop.art.shown)
    local cast = St.FOREVER_CAST_BAR
    local castLine = Parts.ProgressLine(New("Frame"), cast.h, true)
    check("a framed progress line on the game's cast bar: its track, gold fill and frame", castLine.foreverArt
        and castLine.track.atlas == cast.track and castLine.fill.bar.texture == cast.fill
        and castLine.castFrame.pieces[1].texture == cast.frame and castLine.castFrame.pieces[1].w == cast.cap)
    castLine:Paint(ns.THEME.accent)
    check("the gold fill left as the game draws it, not tinted", castLine.fill.bar.color[1] == 1
        and castLine.fill.bar.color[2] == 1 and castLine.fill.bar.gradient == nil)
    check("the part ahead (completed quests) the same gold, dimmed, not a flat yellow strip",
        castLine.ahead.bar.texture == cast.fill and castLine.ahead.barColor[1] == 1 and castLine.ahead.barColor[3] == 1
        and castLine.ahead.barColor[4] < 1)
    local thin = Parts.ProgressLine(New("Frame"), 2)
    check("a plain progress line (in list rows) stays thin and drawn", not thin.foreverArt and thin.castFrame == nil
        and thin.fill.bar.gradient ~= nil)
    local pick = Parts.ForeverRowPick(New("Frame"))
    check("a HUD list's current row on the Settings list's gold selection", pick and pick.atlas == St.FOREVER_ROW_PICK_ATLAS
        and pick.points[1][1] == "ALL" and not pick.shown)
    local micro, files = St.FOREVER_MICRO, St.FOREVER_ART_FILES
    local container = Parts.ForeverContainer(New("Frame"))
    local boxFile = files[micro.container]
    check("the micro menu's container, from its file, its dark middle filled, hidden until a look asks",
        container and container.pieces[5] and container.pieces[5].texture == boxFile.file and container.pieces[1].w == micro.edge
        and container.shown == false)
    local mb = New("Button")
    check("a micro menu button behind a Top Bar button", Parts.ForeverMicroButton(mb)
        and mb.micro.texture == files[micro.up].file and mb.microHover.texture == files[micro.hover].file)
    check("its hover inside the button's rim", mb.microHover.points[1][4] == micro.hoverIn
        and mb.microHover.points[2][4] == -micro.hoverIn)
    mb.scripts.OnMouseDown(mb)
    check("pressed: the pressed button", mb.micro.coords[3] == files[micro.down].t)
    mb.scripts.OnMouseUp(mb)
    check("let go: the plain button", mb.micro.coords[3] == files[micro.up].t)
    mb.highlight = New("Texture", mb)
    Parts.ShowForeverMicro(mb, true, 30)
    check("shown at the button's width and the art's height, the old highlight stood down", mb.micro.w == 30
        and math.abs(mb.micro.h - 30 * micro.tall) < 1e-9 and mb.highlight.alpha == 0 and mb.micro.shown)
    Parts.ShowForeverMicro(mb, false, 30)
    check("hidden again, the old highlight back", not mb.micro.shown and not mb.microHover.shown
        and mb.highlight.alpha == 1)
    local sample = New("Frame")
    Parts.ForeverMicroButton(sample)
    Parts.ShowForeverMicro(sample, true, 30)
    check("a plain Frame (the Top Bar preview's samples) has no highlight to stand down", sample.micro.shown
        and sample.micro.w == 30)
    local headLine = Parts.ForeverHeadLine(New("Frame"))
    check("a HUD card's header line the game's faint divider", headLine
        and headLine.atlas == St.FOREVER_DIVIDER_ATLAS)
    local preview = New("Frame")
    preview.w, preview.h = 64, 20
    check("the onboarding preview's button on the same art", Parts.ForeverButtonArt(preview) and RedPieces(preview, ""))

    local tabs = Parts.Tabs(New("Frame"), 300, { { key = "a", label = "A" }, { key = "b", label = "B" } }, function() end)
    Parts.PaintTabs(tabs, "a")
    local picked, other = tabs.buttons[1], tabs.buttons[2]
    check("tabs on the game's Settings tab art, upright and at its own size", picked.idleArt
        and picked.activeArt[1].atlas == St.FOREVER_ACTIVE_TAB_ATLAS.left and picked.idleArt[2].atlas == St.FOREVER_TAB_ATLAS.middle
        and picked.activeArt[1].coords == nil and picked.idleArt[1].h == ATLAS_H)
    check("its caps at the tab's own corners", #picked.idleArt[1].points[1] == 1
        and picked.idleArt[1].points[1][1] == "BOTTOMLEFT" and picked.activeArt[3].points[1][1] == "BOTTOMRIGHT")
    check("the picked tab lit, the others idle", picked.activeArt[1].shown and not picked.idleArt[1].shown
        and other.idleArt[1].shown and not other.activeArt[1].shown and picked.text.color[1] == St.FOREVER_TAB_ON_RGB.r
        and other.text.color[1] == St.FOREVER_MUTED_RGB.r)
    check("a tab is as wide as its label plus room for the art's caps", picked.capRoom >= 2 * St.FOREVER_TAB_PAD
        and picked.want == 20 + picked.capRoom)
    check("tabs keep their own width, side by side, not stretched to fill the row", picked.w == picked.want
        and other.w == other.want and other.points[1][2] == picked.want + St.FOREVER_TAB_GAP)
    check("the tab art's caps scale with its height", picked.idleArt[1].w ~= nil)
    check("a rail under the tabs, a little wider than the row", tabs.rail and tabs.rail.shown ~= false
        and tabs.rail.w == picked.want + St.FOREVER_TAB_GAP + other.want + 2 * St.FOREVER_TAB_RAIL_OUT
        and tabs.rail.points[1][4] == -St.FOREVER_TAB_RAIL_OUT)
    check("the label sits in the middle of the tab art, not of the taller button", picked.text.points[1][2] == picked.idleArt[2]
        and picked.text.points[1][1] == "CENTER")
    local three = { { key = "a", label = "A" }, { key = "b", label = "B" }, { key = "c", label = "C" } }
    local function RowW(tabW) return 3 * tabW + 2 * St.FOREVER_TAB_GAP end
    local tight = Parts.Tabs(New("Frame"), RowW(20 + 2 * St.FOREVER_TAB_TIGHT), three, function() end)
    check("a row too narrow for its tabs trims their padding first, keeping every label whole",
        tight.buttons[1].w == 20 + 2 * St.FOREVER_TAB_TIGHT and not tight.buttons[3].cut
        and tight.buttons[3].text.w == 0)
    local cut = Parts.Tabs(New("Frame"), RowW(30), three, function() end)
    check("then cuts the widest to one width, their labels ending short", cut.buttons[1].w == 30
        and cut.buttons[3].w == 30 and cut.buttons[2].cut and cut.buttons[2].text.w == 30 - 2 * St.FOREVER_TAB_TIGHT)
    cut:SetWidth(RowW(cut.buttons[1].want))
    Parts.SetTabs(cut, { { key = "a", label = "A" } })
    check("and gives a tab back its full width once the row has room", cut.buttons[1].w == cut.buttons[1].want
        and not cut.buttons[1].cut and cut.buttons[1].text.w == 0)
    local choice = Parts.Tabs(New("Frame"), 300, three, function() end, nil, nil, true)
    Parts.PaintTabs(choice, "b")
    local first, chosen, last = choice.buttons[1], choice.buttons[2], choice.buttons[3]
    check("a strip asButtons is red buttons with no rail, not tabs", choice.rail == nil and first.idleArt == nil
        and RedPieces(first, "") and first.highlightAtlas == St.FOREVER_RED_BUTTON_ATLAS.highlight)
    check("the picked one a picked red button: pressed in and lit, gold text, no tab fill",
        RedPieces(chosen, "-Pressed") and chosen.lockedLit and not first.lockedLit and not chosen.fill.shown
        and not chosen.line.shown and chosen.text.color[2] == St.FOREVER_GOLD_RGB.g)
    check("its buttons fill the strip, a tab gap apart", first.w > first.want and chosen.points[1][2] == first.w
        + St.FOREVER_TAB_GAP and last.points[1][2] + last.w == 300)
    first.scripts.OnMouseDown(first)
    check("pressed: the pressed art", RedPieces(first, "-Pressed"))
    first.scripts.OnMouseUp(first)
    check("let go: the plain art again", RedPieces(first, ""))
    Parts.PaintTabs(choice, "a")
    check("picking another lets the first back out", RedPieces(chosen, "") and chosen.lockedLit == false
        and RedPieces(first, "-Pressed") and first.lockedLit)

    local search = Parts.SearchBox(New("Frame"), "Search", function() end)
    check("its left end inside the box, never over the window's border", search.foreverArt
        and search.foreverArt[1].points[1][1] == "TOPLEFT" and search.foreverArt[1].points[1][2] == nil)
    check("the search box on the game's search art", search.foreverArt and search.foreverArt[1].atlas == St.FOREVER_SEARCH_ATLAS.left
        and search.foreverArt[3].atlas == St.FOREVER_SEARCH_ATLAS.right and not search._fill.shown)

    local c = Controls(ns)
    local tick = Holds(c.toggle, function(x) return x.texture == St.FOREVER_CHECK end)
    check("a check box on the game's beveled box, its yellow tick and its glow", tick and tick.shown
        and c.toggle.checkArt.texture == St.FOREVER_CHECKBOX.up and c.toggle.normal == c.toggle.checkArt
        and c.toggle.pushed == St.FOREVER_CHECKBOX.down and c.toggle.highlight.texture == St.FOREVER_CHECKBOX.highlight)
    check("every check box the same size", c.toggle.w == St.FOREVER_CHECK_SIZE and c.toggle.h == St.FOREVER_CHECK_SIZE
        and c.toggle.scripts.OnEnter == nil)
    c.toggle.scripts.OnClick(c.toggle)
    check("a click clears the tick", not tick.shown)
    local dd, ddArt = c.dropdown, St.FOREVER_DROPDOWN_ATLAS
    local field = Holds(dd, function(x) return x.atlas == ddArt.field end)
    local out = St.FOREVER_DROPDOWN_OUT
    check("a dropdown on the game's own box (WowStyle1), out past the button as the template lays it", field
        and field.points[1][1] == "TOPLEFT" and field.points[1][2] == -out.left and field.points[1][3] == out.top
        and field.points[2][2] == out.right and field.points[2][3] == -out.bottom)
    check("its arrow the game's button at its own size, no drawn plate, no glow", dd.arrow.atlas == ddArt.arrow
        and dd.arrow.w == ATLAS_W and dd.arrowPlate == nil and dd.glow == nil)
    check("no black edge round it", not Find(dd.children, function(x) return x.kind == "Frame" and x.shown ~= false end))
    dd.scripts.OnEnter(dd)
    check("under the mouse: the game's lit arrow", dd.arrow.atlas == ddArt.hover)
    dd.scripts.OnLeave(dd)
    check("and back when it leaves", dd.arrow.atlas == ddArt.arrow)
    local slider, sliderArt = c.slider, St.FOREVER_SLIDER_ATLAS
    check("a slider on the game's Settings groove and knob, our drawn rail and fill hidden", slider.grooveArt
        and slider.grooveArt[1].atlas == sliderArt.left and slider.grooveArt[2].atlas == sliderArt.middle
        and slider.grooveArt[3].atlas == sliderArt.right and slider.thumb.atlas == sliderArt.knob
        and not slider.rail.shown and not slider.fill.shown)
    local glow = slider.glow
    check("its knob glows while the mouse is on the slider, only then", glow and glow.atlas == sliderArt.knob
        and not glow.shown)
    slider.scripts.OnEnter(slider)
    check("glowing under the mouse", glow.shown)
    slider.scripts.OnLeave(slider)
    check("and not after", not glow.shown)
    local valueBox = slider.valueBox
    check("its number box the game's input box (InputBoxTemplate's art), at our own size", valueBox.foreverArt
        and valueBox.foreverArt[1].atlas == St.FOREVER_SEARCH_ATLAS.left
        and valueBox.foreverArt[1].points[1][2] == nil
        and not slider.valueFill.shown and not slider.valueBorder._frame.shown)
    local scroll = ns.UI.SlimScroll(New("Frame"))
    local bar, scrollArt = scroll.bar, St.FOREVER_SCROLL_ATLAS
    check("a scroll bar on the game's slim track and grip, our drawn track hidden", bar.trackArt
        and bar.trackArt[1].atlas == scrollArt.top and bar.trackArt[3].atlas == scrollArt.bottom
        and bar.thumbArt[2].atlas == scrollArt.thumbMiddle and not bar.track.shown)
    check("its step arrows the game's", bar.up.normalAtlas == scrollArt.up and bar.down.normalAtlas == scrollArt.down
        and bar.up.highlightAtlas == scrollArt.up .. St.FOREVER_SCROLL_OVER
        and bar.down.pushedAtlas == scrollArt.down .. St.FOREVER_SCROLL_PRESSED and bar.up.glyph == nil)
    local grip = Find(bar.children, function(x) return x.scripts.OnEnter ~= nil and x.delta == nil end)
    grip.scripts.OnEnter(grip)
    check("its grip lit under the mouse", bar.thumbArt[1].atlas == scrollArt.thumbTop .. St.FOREVER_SCROLL_OVER
        and bar.thumbArt[3].atlas == scrollArt.thumbBottom .. St.FOREVER_SCROLL_OVER)
    grip.scripts.OnLeave(grip)
    check("and plain again after", bar.thumbArt[2].atlas == scrollArt.thumbMiddle)
    check("a swatch in a bronze ring", Holds(c.swatch, function(x) return x.kind == "Frame" end) ~= nil)

    ns.UI.ShowWidgetTooltip(New("Frame"), "Help")
    local tip = Tip()
    check("the help card as the game's help tip, its pointer on the game's art", tip and tip.arrow.texture == St.FOREVER_TIP_ARROW
        and tip.arrow.shown)
    ns.UI.ShowWidgetTooltip(New("Frame"), "Help", { anchor = "cursor" })
    check("at the cursor it points at nothing", not tip.arrow.shown)

    local header = ns.UI.Widgets:SectionHeader(New("Frame"), "FONT", 0)
    local heading = Find(header.children, function(x) return x.text and x.text.text == "FONT" end)
    check("a section header in plain words over the game's Settings divider", heading and heading.line
        and heading.line.atlas == St.FOREVER_DIVIDER_ATLAS and heading.line.h == ATLAS_H and heading.line.color == nil)
    local fold = ns.UI.Widgets:FoldHeader(New("Frame"), "MODULES", 0)
    check("a header that folds is a list bar with the game's plus, as a card's", fold.bar and fold.bar.art
        and fold.bar.name.text == "MODULES" and fold.bar.sign.atlas == St.FOREVER_PLUS_ATLAS and not fold.arrow.shown)
    local page = New("Frame")
    page.w = 600
    local pair = ns.UI.Widgets:DualRow(page, -40, { type = "label", text = "Window Scale" },
        { type = "label", text = "Language" })
    local split = Find(pair.children, function(x) return x.kind == "Texture" and x.points[1]
        and x.points[1][1] == "TOP" end)
    check("a pair's divider runs the row's full height, meeting the heading's line above", split
        and #split.points[1] == 3 and #split.points[2] == 3 and split.shown ~= false)

    local inset = Parts.ForeverInset(New("Frame"))
    check("an inset on the game's inset frame", inset.art and inset.layout == St.FOREVER_INSET_LAYOUT)
    local nav = Parts.ForeverNavButton(Navigable())
    Parts.PaintForeverNav(nav, true)
    check("a page link is a list bar as light as a card's, lit amber and glowing gold when picked", nav.forever
        and nav.art and nav.barArt.atlas == St.FOREVER_BAR_ATLAS and nav.barArt.color == nil
        and nav.fill.atlas == St.FOREVER_BAR_ATLAS and nav.fill.color[2] == St.FOREVER_NAV_LIT_RGB.g
        and nav.glow.shown and nav.glow.texture == St.FOREVER_HIGHLIGHT and nav.pickEdge == nil
        and nav.glow.mask and nav.glow.mask.atlas == St.FOREVER_BAR_ATLAS)
    Parts.PaintForeverNav(nav, false)
    check("and plain when not", not nav.glow.shown)
    local line = Parts.ForeverNavLine(Navigable())
    local list = St.FOREVER_LIST_ATLAS
    check("a listed module on the game's Settings list art, no drawn lines", line.listArt and line.lines == nil
        and line.listArt.points[1][1] == "ALL" and not line.listArt.shown and not line.pickArt.shown)
    Parts.PaintForeverNav(line, true, false)
    local pickArt = St.FOREVER_PICK_ART
    check("picked: the quest tracker's header from its own file, past Forever's swap to its plainer twin",
        line.pickArt.shown and line.pickArt.texture == pickArt.file and line.pickArt.coords[1] == pickArt.coords[1]
        and line.pickArt.coords[4] == pickArt.coords[4] and not line.listArt.shown)
    check("taller than the row, at the header's own height, centred on it", line.pickArt.h == pickArt.h
        and line.pickArt.points[1][1] == "LEFT" and line.pickArt.points[2][1] == "RIGHT")
    Parts.PaintForeverNav(line, true, true)
    check("picked and under the mouse: the header alone", line.pickArt.shown and not line.listArt.shown)
    check("its cut the header's 80 tall, up to where its fade ends (548 of 600), so the line runs the row's length",
        math.abs((pickArt.coords[2] - pickArt.coords[1]) * 1024 - 548) < 1e-6
        and math.abs((pickArt.coords[4] - pickArt.coords[3]) * 512 - 80) < 1e-6)
    Parts.PaintForeverNav(line, false, true)
    check("under the mouse after being picked: its hover, filling the row, on its own texture so no cut of the "
        .. "header's file is left on it", line.listArt.shown and line.listArt.atlas == list.hover
        and line.listArt.points[1][1] == "ALL" and line.listArt ~= line.pickArt and line.listArt.texture == nil
        and line.listArt.coords == nil and not line.pickArt.shown)
    Parts.PaintForeverNav(line, false, false)
    check("and nothing at rest", not line.listArt.shown and not line.pickArt.shown)

    local switchOn = true
    local card = { name = "Tooltips", switchGet = function() return switchOn end, switchSet = function() end,
        rows = { {} }, summary = "IDs" }
    local head, view = Head(ns, card)
    check("a card is a list bar on the game's art, the bar its whole height", head.art
        and head.barArt.atlas == St.FOREVER_BAR_ATLAS and head.barArt.points[1][3] == 0
        and ns.Shared.Settings.kinds.cardHead.Set(head, card, false, false) == St.FOREVER_CARD_BAR_H)
    check("its switch the game's check box", head.switch.checkArt ~= nil and head.switch.w == St.FOREVER_CHECK_SIZE)
    check("its switch at the left, the Friends list header's plus at the far right", head.switch.points[1][1] == "LEFT"
        and head.sign.points[1][1] == "CENTER" and head.sign.points[1][3] == "RIGHT"
        and head.sign.points[1][4] == -St.FOREVER_SIGN_RIGHT and head.sign.atlas == St.FOREVER_PLUS_ATLAS
        and not head.chevron.shown)
    check("closed: its name in gold", head.name.color[1] == ns.THEME.accent.r and head.name.color[2] == ns.THEME.accent.g)
    ns.Shared.Settings.kinds.cardHead.Set(head, card, true, false)
    check("open: the game's minus at its own size, never a bare colored square", head.sign.atlas == St.FOREVER_MINUS_ATLAS
        and head.sign.w == ATLAS_W and head.sign.h == ATLAS_H and head.sign.color == nil and head.sign.texture == nil
        and head.sign.shown and not head.signText.shown)
    check("its glow the same minus", head.signGlow.atlas == St.FOREVER_MINUS_ATLAS and head.signGlow.shown)
    check("open: its name in gold", head.name.color[1] == ns.THEME.accent.r)
    local group = ns.Shared.Settings.kinds.group.New(view)
    ns.Shared.Settings.kinds.group.Set(group, "Copy")
    check("a group in its own words over the game's divider", group.heading and group.heading.text.text == "Copy"
        and group.heading.line.atlas == St.FOREVER_DIVIDER_ATLAS)
    local kind = ns.Shared.Settings.kinds.setting
    local rows = {}
    for i, top in ipairs({ 30, 66, 66, 102 }) do
        view.cursor = top
        local row = kind.New(view)
        kind.Set(row, { kind = "toggle", label = "Setting " .. i, card = card, get = function() return true end },
            i == 2)
        rows[i] = row
    end
    check("rows with no line under each and no bands, as on Naowh", rows[1].band == nil and rows[1].rule == nil
        and rows[4].rule == nil)
    check("their labels in gold", rows[1].label.color[1] == ns.THEME.accent.r)
    switchOn = false
    kind.Set(rows[2], { kind = "toggle", label = "Off", card = card, get = function() return true end }, false)
    local box = rows[2].controls.toggle
    check("a card off: its check box stays whole, the game's box dimmed and the disabled tick",
        box.alpha == 1 and box.checkArt.alpha == St.FOREVER_CHECK_DIM_ALPHA
        and box.checkTick.texture == St.FOREVER_CHECK_DISABLED and box.checkTick.alpha == 1
        and rows[2].label.alpha < 1)
    switchOn = true
    kind.Set(rows[2], { kind = "toggle", label = "On", card = card, get = function() return true end }, false)
    check("on again: the box and tick as before", box.alpha == 1 and box.checkArt.alpha == 1
        and box.checkTick.texture == St.FOREVER_CHECK and rows[2].label.alpha == 1)
    local outlined = false
    kind.Set(rows[3], { kind = "button", label = "Show the Cut-Out", card = card,
        button = function() outlined = not outlined end,
        buttonText = function() return outlined and "Hide" or "Show" end }, false)
    local go = rows[3].controls.button
    check("a button's text may be a function", go.label.text == "Show")
    go.scripts.OnClick(go)
    check("clicked: it reads its text again", outlined and go.label.text == "Hide")
    go.scripts.OnClick(go)
    check("and again, back as it was", not outlined and go.label.text == "Show")
end

-- Forever on a client without the disabled tick: the yellow tick, dimmed.
do
    local ns = Load({ skin = "forever" }, ALL, { [St.FOREVER_CHECK_DISABLED] = true })
    local c = Controls(ns)
    local row = New("Frame")
    row.label = New("FontString")
    ns.Shared.Settings.Control.Dim(row, c.toggle, true)
    check("no disabled tick: the yellow one, dimmed", c.toggle.alpha == 1 and c.toggle.checkTick.texture == St.FOREVER_CHECK
        and c.toggle.checkTick.alpha == St.FOREVER_CHECK_DIM_ALPHA and c.toggle.checkArt.alpha == St.FOREVER_CHECK_DIM_ALPHA)
end

-- Forever on a client missing all of it: everything drawn from the tokens, no missing texture.
do
    local files = { [St.FOREVER_CHECK] = true, [St.FOREVER_KNOB] = true, [St.FOREVER_TIP_ARROW] = true,
        [St.FOREVER_CHECKBOX.up] = true }
    local ns = Load({ skin = "forever" }, {}, files)
    ns.Shared.Style.FOREVER_ART_FILES = {}
    local Parts = ns.Shared.Parts
    local window = Parts.Window(400, 300, "test")
    local chrome = window.forever
    check("no atlas: a drawn rim of black, bronze and gold", chrome and not chrome.art and #chrome.rings == 5
        and #layouts == 0)
    check("a drawn red close button with a gold cross", chrome.close.cross and chrome.close.cross.texture == St.CROSS
        and chrome.close.cross.color[1] == St.FOREVER_CHECK_RGB.r and chrome.close.normalAtlas == nil)
    check("a drawn bronze portrait ring", #chrome.portrait.middle.children >= 5)
    local tabs = Parts.Tabs(New("Frame"), 300, { { key = "a", label = "A" } }, function() end)
    Parts.PaintTabs(tabs, "a")
    check("drawn tabs, gold when picked", tabs.buttons[1].idleArt == nil and tabs.buttons[1].idleFill
        and tabs.buttons[1].fill.gradient[2].r == St.FOREVER_TAB_ACTIVE_RGB[1].r)
    check("drawn tabs pad their label too", tabs.buttons[1].want == 20 + 2 * St.FOREVER_TAB_PAD)
    local search = Parts.SearchBox(New("Frame"), "Search", function() end)
    check("a drawn search field", search.foreverArt == nil)
    local c = Controls(ns)
    local tick = Holds(c.toggle, function(x) return x.texture == St.TICK end)
    check("a drawn check in the check color, the same size", tick and tick.color[1] == St.FOREVER_CHECK_RGB.r
        and c.toggle.w == St.FOREVER_CHECK_SIZE and c.toggle.checkArt == nil and c.toggle.scripts.OnEnter ~= nil)
    check("a drawn gold arrow button", c.dropdown.arrowPlate ~= nil and c.dropdown.glow ~= nil
        and c.dropdown.arrow == nil)
    check("a drawn bronze knob", c.slider.thumb.texture == St.ROUND and c.slider.thumb.color[1] == St.FOREVER_BRONZE_RGB.r)
    check("a drawn groove and number box", c.slider.grooveArt == nil and c.slider.rail.shown ~= false
        and c.slider.valueBox.foreverArt == nil and c.slider.glow.gradient ~= nil)
    local scroll = ns.UI.SlimScroll(New("Frame"))
    check("a scroll bar with drawn chevrons", scroll.bar.thumbArt == nil and scroll.bar.up.glyph ~= nil
        and scroll.bar.track.shown ~= false)
    local line = Parts.ForeverNavLine(Navigable())
    Parts.PaintForeverNav(line, true, false)
    check("a listed module picked between two drawn gold lines", line.listArt == nil and line.lines[1][1].shown
        and line.lineFill[1].shown)
    local heading = Parts.ForeverHeading(New("Frame"))
    check("a heading over a drawn brown line", heading.line.atlas == nil and heading.line.h == St.FOREVER_HEADING_LINE)
    local groupBar = New("Frame")
    groupBar.h = 28
    Parts.ForeverGroupBar(groupBar, "COMBAT")
    check("a drawn group bar", not groupBar.art and groupBar.barRim ~= nil)
    ns.UI.ShowWidgetTooltip(New("Frame"), "Help")
    local tip = Tip()
    check("the help tip's pointer drawn", tip.arrow.texture == St.ARROW and tip.arrow.color[1] == St.FOREVER_CHECK_RGB.r)
    local inset = Parts.ForeverInset(New("Frame"))
    check("a drawn inset", not inset.art and inset.rim ~= nil)
    local card = { name = "Card", rows = { {} } }
    local head = Head(ns, card)
    check("a drawn list bar with a gold plus", not head.art and head.signText.text == "+" and head.signText.shown
        and not head.sign.shown and head.barArt.gradient[2].r == St.FOREVER_BAR_RGB[1].r and head.signGlow == nil)
    ns.Shared.Settings.kinds.cardHead.Set(head, card, true, false)
    check("open: the drawn minus glyph, never a colored square", head.signText.text == "-" and head.signText.shown
        and not head.sign.shown and head.sign.atlas == nil and head.sign.color == nil)
    local btn = ns.Button(New("Frame"), "Go", 80, 20)
    check("a drawn red button in a bronze rim", btn.redArt == nil and btn.redFill == btn._bg
        and btn._bg.gradient[2].r == St.FOREVER_RED_RGB[1].r and btn.redRim ~= nil and btn._border._frame.shown
        and btn.highlightAtlas == nil and btn._art == nil)
    check("its rim on the edge's frame, fading with it", Holds(btn._border._frame, function(x)
        return x == btn.redRim._frame end) ~= nil)
    btn.scripts.OnEnter(btn)
    check("hovered: a brighter red", btn._bg.gradient[2].r == St.FOREVER_RED_HOVER_RGB[1].r)
    btn.scripts.OnLeave(btn)
    rawset(btn, "IsEnabled", function() return false end)
    btn.scripts.OnDisable(btn)
    check("disabled: drawn grey", btn._bg.gradient[2].r == St.FOREVER_RED_DISABLED_RGB[1].r
        and btn.label.color[1] == St.FOREVER_DISABLED_TEXT_RGB.r)
    local row = New("Frame")
    row.label = New("FontString")
    ns.Shared.Settings.Control.Dim(row, c.toggle, true)
    check("a drawn check box dimmed, not faded away", c.toggle.alpha == 1
        and c.toggle.checkBox.alpha == St.FOREVER_CHECK_DIM_ALPHA)
    local hudBackdrop = Parts.HudBackdrop(New("Frame"))
    check("no art: a HUD card keeps its black edge", hudBackdrop.art == nil and hudBackdrop.border._frame.shown)
    local framed = Parts.ProgressLine(New("Frame"), 11, true)
    check("no art: a framed progress line stays drawn", not framed.foreverArt and framed.castFrame == nil)
    check("no art: no row pick or header line", Parts.ForeverRowPick(New("Frame")) == nil
        and Parts.ForeverHeadLine(New("Frame")) == nil)
    local nav = Parts.ForeverNavButton(Navigable())
    Parts.PaintForeverNav(nav, true)
    check("a drawn module bar, its rim gold when picked", not nav.art and nav.glow == nil
        and nav.barArt.gradient[2].r == St.FOREVER_BAR_RGB[1].r)
    check("no atlas ever set that the client lacks", #atlasCalls == 0)
end

-- Forever: a settings page is bare list bars, a small gap apart; an open card's rows lie right under
-- its bar, and the page grows and shrinks with it.
do
    local ns = Load({ skin = "forever" }, ALL)
    local Settings = ns.Shared.Settings
    local values = {}
    local store = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end,
        Default = function() return nil end, OnChange = function() end }
    local page = Settings.Page("Test/Cards", store)
    local first = page:Card({ id = "a", name = "First", switch = "aOn", rows = { Settings.Group("Group"),
        { label = "One", toggle = true, key = "one" }, { label = "Two", toggle = true, key = "two" } } })
    page:Card({ id = "b", name = "Second", rows = { { label = "Three", toggle = true, key = "three" } } })
    local parent = New("Frame")
    parent.w = 700
    Settings.Render(parent, "Test/Cards", function() end)
    local view = parent.settingsView
    local bar, gap, body = St.FOREVER_CARD_BAR_H, St.FOREVER_CARD_GAP, St.FOREVER_BODY_GAP
    local heads = view.pools.cardHead
    local function OnlyBars()
        for _, child in ipairs(view.children) do
            if child.shown and child.sign == nil and child.setting == nil and child.heading == nil then return false end
        end
        return true
    end
    check("closed cards: two bars, a gap apart, nothing round them", heads.used == 2 and heads[1].top == 0
        and heads[2].top == bar + gap and heads[1].h == bar and view.h == 2 * (bar + gap) and OnlyBars())
    Settings.SetOpen(first, true)
    view:Redraw()
    local rows = view.pools.setting
    local group = view.pools.group[1]
    check("open: its rows right under its bar, still no box", group.top == bar + body and rows.used == 2
        and rows[1].top == group.top + group.h and rows[2].top == rows[1].top and OnlyBars())
    check("the next bar moves down by the rows", heads[2].top == rows[1].top + rows[1].h + body + gap
        and view.h == heads[2].top + bar + gap)
    Settings.SetOpen(first, false)
    view:Redraw()
    check("closed again, the page shrinks back", heads[2].top == bar + gap and view.h == 2 * (bar + gap))
end

-- Forever: the options window as the game's own (Legacy Challenges): a header band under the title
-- bar with the page's name and its buttons, a bronze rail under it and down the side, the category
-- list as list bars under the search box, no logo in the sidebar and no boxed content.
do
    local ns = Load({ skin = "forever" }, ALL, nil, WINDOW)
    ns.OpenOptionsWindow("Interface")
    local window = Find(frames, function(f) return rawget(f, "strata") == "DIALOG" end)
    window.scripts.OnShow(window)
    local band, rail, sideTop = St.FOREVER_BAND_H, St.FOREVER_RAIL, St.FOREVER_BAND_H + St.FOREVER_RAIL
    local panes = window.foreverPanes
    check("a header band under the title bar, a rail under it and down the side", panes
        and panes.band.h == band and panes.rail.points[1][3] == -band and panes.side.vertical
        and panes.side.points[1][2] == 240 and panes.side.points[1][3] == -sideTop)
    check("the content lighter in the middle", panes.light[1].gradient[2].a == St.FOREVER_LIGHT_ALPHA
        and panes.light[2].gradient[1].a == St.FOREVER_LIGHT_ALPHA)
    check("no logo in the sidebar, no old top bar or close button", not Holds(window, function(x)
        return x.texture == ns.MEDIA .. "BrandLogo.tga" end) and not Find(frames, function(f)
        return f.label and f.label.text == "X" end))
    local reload = Find(frames, function(f) return f.label and f.label.text == "Reload UI" end)
    local hud = Find(frames, function(f) return f.label and f.label.text == "HUD Editor" end)
    local header = reload.parent
    check("Reload UI and HUD Editor on the band, at its right, centred on it", header == hud.parent
        and header.h == band and header.points[1][1] == "TOPLEFT" and header.points[1][2] == window
        and reload.points[1][1] == "RIGHT" and reload.points[1][2] == header
        and hud.points[1][2] == reload and hud.points[1][3] == "LEFT")
    check("both the game's red button, neither set apart", RedPieces(reload, "") and RedPieces(hud, "")
        and reload._primary == nil and hud._primary == nil)
    local title = Find(header.children, function(x) return x.text == "Interface" end)
    local enable = Find(header.children, function(x) return x.text and x.text:find("^Enable") end)
    check("the category's name on the band, clear of the portrait", title and title.points[1][2]
        == St.FOREVER_PORTRAIT_ROOM)
    check("no module switch on the band: each module's switch is on its own card", enable == nil
        and not Find(header.children, function(x) return x.checkArt end))
    local search = Find(frames, function(f) return f.foreverArt ~= nil end)
    check("the search box at the top of the sidebar, under the rail", search and search.parent.points[1][3]
        == -sideTop and search.points[1][3] == -10)
    local journal = Find(frames, function(f) return f.label and f.label.text == "Map & Travel" end)
    check("each category plain text in the list, no bar and no icon", journal.forever and journal.listArt
        and journal.barArt == nil and journal.icon == nil)
    local group = Find(frames, function(f) return f.label and f.label.text == ns.L("CHARACTER") and f.barArt end)
    local art = St.FOREVER_GROUP_ART
    local scale = group and group.h / art.bar
    check("each group the game's Settings category header, its bar the group's row", group
        and group.barArt.atlas == St.FOREVER_GROUP_ATLAS and group.barArt.color == nil
        and group.barArt.h == art.h * scale and group.barArt.points[1][3] == art.top * scale
        and group.barArt.points[2][1] == "TOPRIGHT")
    local arrows = 0
    for _, f in ipairs(frames) do if f.delta then arrows = arrows + 1 end end
    check("chevron arrows on the category list and the content", arrows == 4)
    check("no boxed content: the only nine-slice is the window's frame", #layouts == 1
        and layouts[1] == St.FOREVER_FRAME_LAYOUT)
    local scroll = Find(frames, function(f) return f.kind == "ScrollFrame" and f.points[1]
        and f.points[1][2] == window end)
    local tabs = Find(frames, function(f) return f.buttons and f.shown and f.buttons[1].text.text == "Overview"
        and f.buttons[2].text.text == "Top Bar" end)
    check("the section tabs inside the content, the cards under them", tabs
        and tabs.points[1][4] == 240 + rail + 26 and tabs.points[1][5] == -(sideTop + 8)
        and scroll and scroll.points[1][4] == 240 + rail + 6 and scroll.points[1][5] == -(sideTop + 8 + 32 + 8))
    local tabRail = Find(frames, function(f) return f.core and f.points[1] and f.points[1][2] == window
        and f.points[1][5] == -(sideTop + 8 + St.TAB_H) end)
    check("the section tabs leave their line to the window's full-width rail", tabs.rail == nil)
    check("a rail under the section tabs, shown with them", tabRail and tabRail.shown
        and tabRail.points[1][4] == 240 + rail + 26 - 6)
    check("the tab rail still in the outer border's metal, light to dark",
        tabRail.core.gradient and tabRail.core.gradient[2].r == St.FOREVER_RAIL_RGB[1].r)
    check("every line in the window in the outer border's metal, light to dark", panes.side.core.gradient
        and panes.side.core.gradient[1].r == St.FOREVER_RAIL_RGB[1].r and panes.rail.core.shown ~= false
        and panes.side.lineArt == nil)
    check("the window on the Journeys art, cropped to cover it", panes.art and panes.art.texture == St.FOREVER_WINDOW_ART
        and #panes.art.coords == 4 and panes.art.coords[1] >= 0 and panes.art.coords[2] <= 1)
    check("the header band on the Legacy window's art, from its top", panes.bandArt
        and panes.band.texture == St.FOREVER_BAND_ART and panes.band.coords[3] == 0 and panes.band.gradient == nil)
    local before = panes.art.coords[2] - panes.art.coords[1]
    window:SetSize(window.w * 2, window.h)
    window.scripts.OnSizeChanged(window, window.w, window.h)
    check("a wider window crops the art again, so it never stretches", panes.art.coords[2] - panes.art.coords[1] ~= before)
    local rod = Find(frames, function(f) return rawget(f, "dragon") ~= nil end)
    check("the line above Settings the same drawn metal, from the frame to the side line", rod and rod.core
        and rod.h == St.FOREVER_RAIL and rod.points[1][1] == "LEFT" and rod.points[1][4] == nil
        and rod.points[2][1] == "RIGHT" and rod.points[2][4] == nil)
    local dragon = St.FOREVER_DRAGON
    check("the boss dragon sitting on it", rod.dragon.atlas == St.FOREVER_DRAGON_ATLAS and rod.dragon.w == dragon.w
        and rod.dragon.h == dragon.h and rod.dragon.points[1][1] == "BOTTOM" and rod.dragon.points[1][5] == -dragon.drop)
    local navList = journal.parent
    local lowest = 0
    for _, child in ipairs(navList.children) do
        local p = child.points[1]
        if child.label and p and p[1] == "TOPLEFT" and child.shown ~= false then lowest = math.min(lowest, p[3]) end
    end
    check("the category list scrolls past its last row by the dragon's room", navList.h
        >= -lowest + 28 + St.FOREVER_DRAGON.h + St.FOREVER_RAIL / 2)
    local utilityLine = Find(rod.parent.children, function(x) return x.kind == "Texture" and x ~= rod end)
    check("the plain line there hidden", utilityLine and utilityLine.shown == false)
    check("the window lines leave the Forever mark's text line alone", type(ns.Shared.Parts.ForeverLine()) == "string"
        and ns.Shared.Parts.ForeverDivider ~= ns.Shared.Parts.ForeverLine)
    local system = 0
    for _, name in ipairs({ "Settings", "Profiles", "Patch Notes", "Credits" }) do
        local btn = Find(frames, function(f) return f.label and f.label.text == name end)
        if btn and btn.forever and btn.icon == nil then system = system + 1 end
    end
    check("Settings, Profiles, Patch Notes and Credits list bars at the sidebar's foot, as on Naowh", system == 4)
end

-- Forever as the live client is: the Forever-only (-c60) art is not found by name, so each piece is
-- drawn from its file by ID and position (FOREVER_ART_FILES), never left to the drawn fallback.
do
    local plain = {}
    for name in pairs(ALL) do if not St.FOREVER_ART_FILES[name] then plain[name] = true end end
    local ns = Load({ skin = "forever" }, plain, nil, WINDOW)
    local files = ns.Shared.Style.FOREVER_ART_FILES
    ns.OpenOptionsWindow()
    local window = Find(frames, function(f) return rawget(f, "strata") == "DIALOG" end)
    window.scripts.OnShow(window)
    local ring = window.forever.portrait.ringArt
    local circle = files[ns.Shared.Style.FOREVER_RING_ATLAS]
    check("from the file: the logo ring at its size", ring and ring.texture == circle.file and ring.coords[1] == circle.l)
    local band = files[ns.Shared.Style.FOREVER_BAND_ART]
    check("from the file: the header band's art, cropped inside its own part of the file",
        window.foreverPanes.band.texture == band.file and window.foreverPanes.band.coords[1] >= band.l
        and window.foreverPanes.band.coords[2] <= band.r and window.foreverPanes.band.coords[3] == band.t)
    local hud = ns.Shared.Parts.HudBackdrop(New("Frame"))
    local frame = files[ns.Shared.Style.FOREVER_HUD_FRAME.atlas]
    check("from the file: a HUD card's bronze frame", hud.art and hud.art.pieces[1].texture == frame.file
        and hud.art.pieces[1].coords[1] == frame.l and not hud.border._frame.shown)
end

-- Forever on a client with none of the art: the same window, every part drawn.
do
    local ns = Load({ skin = "forever" }, {}, { [St.FOREVER_CHECKBOX.up] = true }, WINDOW)
    ns.Shared.Style.FOREVER_ART_FILES = {}
    ns.OpenOptionsWindow()
    local window = Find(frames, function(f) return rawget(f, "strata") == "DIALOG" end)
    window.scripts.OnShow(window)
    local settings = Find(frames, function(f) return f.label and f.label.text == "Settings" and f.forever end)
    check("no art: the band, rails and list bars drawn, no atlas asked for that is missing", window.foreverPanes
        and window.foreverPanes.side.core and settings.barRim ~= nil and #atlasCalls == 0 and #layouts == 0)
    local panes = window.foreverPanes
    check("no art: the drawn metal lines, the band's gradient, the rock left bare", panes.side.lineArt == nil
        and panes.side.core.shown ~= false and panes.rail.lineArt == nil and panes.art == nil
        and panes.band.gradient ~= nil and not panes.bandArt)
    check("no art: no dragon, the plain line kept", not Find(frames, function(f) return rawget(f, "dragon") ~= nil end))
    local chrome = window.forever
    check("no art: the drawn bronze ring round the logo", chrome.portrait.ring ~= nil and chrome.portrait.ringArt == nil)
end

print("forever skin: " .. checks .. " checks passed")
