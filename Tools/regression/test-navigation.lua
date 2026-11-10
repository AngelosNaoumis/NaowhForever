-- Exercise the real window, widgets and search using addon-owned sample settings.
-- Geometry is a test double; this does not emulate the game's renderer or taint rules.
local frames, timers = {}, {}
local methods = {}
local NOTHING_NS = setmetatable({}, { __index = function() return function() end end })
local env = setmetatable({}, { __index = function(_, k)
    local v = _G[k]
    if v ~= nil then return v end
    if type(k) == "string" and k:find("^C_") then return NOTHING_NS end
end })
env._G = env
env.InputUtil = { IsGamepadUIEnabled = function() return false end }
env.IsLoggedIn = function() return true end
local function New(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, points = {}, scripts = {},
        children = {}, visible = true, width = 0, height = 0, level = parent and parent.level + 1 or 0 },
        { __index = methods })
    frames[#frames + 1] = f
    if parent then parent.children[#parent.children + 1] = f end
    if name then env[name] = f end
    return f
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then relative, relativePoint, x, y = self.parent, point, 0, 0
    elseif type(relativePoint) == "number" then x, y, relativePoint = relativePoint, x, point end
    self.points[point] = { relative or self.parent, relativePoint or point, x or 0, y or 0 }
end
function methods:ClearAllPoints() self.points = {}; self.all = nil end
function methods:SetAllPoints(f) self.all = f or self.parent end
function methods:GetWidth()
    if self.all then return self.all:GetWidth() end
    local left, right = self.points.TOPLEFT or self.points.BOTTOMLEFT or self.points.LEFT,
        self.points.TOPRIGHT or self.points.BOTTOMRIGHT or self.points.RIGHT
    if left and right and left[1] == right[1] then return left[1]:GetWidth() + right[3] - left[3] end
    if self.kind == "FontString" and self.width == 0 then return self:GetStringWidth() end
    return self.width
end
function methods:GetHeight()
    if self.all then return self.all:GetHeight() end
    local top, bottom = self.points.TOPLEFT or self.points.TOPRIGHT or self.points.TOP,
        self.points.BOTTOMLEFT or self.points.BOTTOMRIGHT or self.points.BOTTOM
    if top and bottom and top[1] == bottom[1] then return top[1]:GetHeight() + top[4] - bottom[4] end
    if self.kind == "FontString" and self.height == 0 then return self:GetStringHeight() end
    return self.height
end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k, v)
    local prior = self.scripts[k]
    self.scripts[k] = function(...) if prior then prior(...) end; v(...) end
end
function methods:Show()
    local was = self.visible; self.visible = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local was = self.visible; self.visible = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self.visible and (not self.parent or self.parent:IsShown()) end
function methods:SetParent(p) self.parent = p end
function methods:GetParent() return self.parent end
function methods:GetChildren() return unpack(self.children) end
function methods:CreateTexture() return New("Texture", nil, self) end
function methods:GetObjectType() return self.kind end
-- One unit is one screen pixel here, so ns.Hairline and ns.PixelInset keep the layout's numbers.
function methods:GetEffectiveScale() return 1 end
env.PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end,
    GetNearestPixelSize = function(v) return math.floor(v + 0.5) end }
function methods:IsVisible() return self:IsShown() end
function methods:IsMouseOver() return false end
function methods:CreateFontString() return New("FontString", nil, self) end
function methods:SetFont(path, size, flags) self.font, self.size, self.flags = path, size, flags end
function methods:SetText(t)
    self.text = tostring(t or "")
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text or "" end
function methods:GetStringWidth() return #(self.text or "") * (self.size or 12) * 0.52 end
function methods:GetStringHeight() return self.size or 12 end
function methods:SetTextColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
methods.SetColorTexture = methods.SetTextColor
methods.SetVertexColor = methods.SetTextColor
function methods:SetTexture(path) self.texture = path end
function methods:SetAlpha(a) self.alpha = a end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:SetRotation(r) self.rotation = r end
function methods:SetJustifyH(j) self.justify = j end
function methods:SetFrameLevel(v) self.level = v end
function methods:GetFrameLevel() return self.level end
function methods:SetScrollChild(f) self.child = f; f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0) end
function methods:SetVerticalScroll(v)
    self.scroll = v
    if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, v) end
end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
function methods:GetPoint()
    local p, v = next(self.points)
    if p then return p, unpack(v) end
end
function methods:SetValue(v) self.value = v end
function methods:GetValue() return self.value or 0 end
function methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function methods:GetMinMaxValues() return self.min, self.max end
function methods:GetScale() return 1 end
function methods:EnableMouse(v) self.mouse = v end
function methods:ClearFocus() self.focus = false end
function methods:SetFocus() self.focus = true end
function methods:HasFocus() return self.focus == true end
for _, name in ipairs({ "RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "UnregisterAllEvents",
    "SetCursorPosition", "SetFontObject", "SetAutoFocus", "SetMultiLine", "SetMaxLetters", "SetNumeric", "SetTextInsets", "SetWordWrap", "SetSpacing",
    "SetFrameStrata", "SetScale", "SetMovable", "SetClampedToScreen", "EnableKeyboard", "SetPropagateKeyboardInput",
    "RegisterForDrag", "RegisterForClicks", "SetResizable", "SetResizeBounds", "SetNormalTexture", "SetHighlightTexture",
    "SetPushedTexture", "SetTexCoord", "SetTexelSnappingBias", "SetSnapToPixelGrid", "SetOrientation", "SetValueStep",
    "SetObeyStepOnDrag", "EnableMouseWheel", "UpdateScrollChildRect", "SetToplevel",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetHitRectInsets", "HighlightText",
    "StartMoving", "StopMovingOrSizing", "StartSizing" }) do methods[name] = function() end end
function methods:SetThumbTexture(t) self.thumbTexture = t end
env.CreateFrame = New
local VERBS = { "^Set", "^Get", "^Register", "^Unregister", "^Enable", "^Disable", "^Clear", "^Update",
    "^Start", "^Stop", "^Add", "^Remove", "^Play", "^Lock", "^Unlock" }
setmetatable(methods, { __index = function(_, k)
    if type(k) ~= "string" then return nil end
    for _, verb in ipairs(VERBS) do
        if k:find(verb) then return function() end end
    end
end })
env.UIParent = New("Frame"); env.UIParent:SetSize(1920, 1080)
env.C_Timer = { After = function(_, f) timers[#timers + 1] = f end,
    NewTicker = function() return { Cancel = function() end } end }
-- missingAddOns: not loaded this session. disabled: switched off for the next reload.
local missingAddOns, disabled = { NaowhForever_TopBar = true }, {}
local indexLoads = 0
local Load
env.C_AddOns = { GetAddOnMetadata = function() return "test" end,
    DoesAddOnExist = function(name) return not missingAddOns[name] end,
    IsAddOnLoaded = function(name) return not missingAddOns[name] end,
    GetAddOnEnableState = function(name) return (missingAddOns[name] or disabled[name]) and 0 or 2 end,
    DisableAddOn = function(name) disabled[name] = true end,
    EnableAddOn = function(name) disabled[name] = nil end,
    LoadAddOn = function(name)
        if name ~= "NaowhForever_SearchIndex" then return false end
        indexLoads = indexLoads + 1
        local index = assert(loadstring(dofile("Tools/build/search_index.lua"), "SearchIndex.lua"))
        setfenv(index, env)
        index()
        return true
    end }
env.SlashCmdList = {}
env.InCombatLockdown = function() return false end
env.LibStub = function() return nil end
env.strtrim = function(s) return s:match("^%s*(.-)%s*$") end
env.UnitName = function() return "Preview" end
env.UnitGUID = function() return "Player-1-00000001" end
env.UnitClass = function() return "Warrior", "WARRIOR", 1 end
env.GetRealmName = function() return "Preview" end
env.GetTime = function() return 0 end
env.UNKNOWNOBJECT = "Unknown"
env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function Load(path)
    local f = assert(loadfile(path)); setfenv(f, env); f("NaowhForever")
end
Load("Core/Core.lua")
Load("Core/Features.lua")
local ns = env.NaowhForever
local account, settings = {}, {}
ns.AccountSettings = function() return account end
ns.SettingsRoot = function() return settings end
ns.RegisterReapply = function() end
ns.QueueReapply = function() end
Load("Core/Options/Widgets.lua")
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Core/Unlock/.-%.lua$")) do Load(path) end
-- The options window is several files now: its modules and categories, the window, its Home and Settings pages,
-- commands and launchers.
local function LoadWindow()
    for _, name in ipairs({ "Options/Modules", "Options/Categories", "Options/Window", "Options/HomePage",
        "Options/SettingsPage", "Commands", "Options/Launchers" }) do
        Load("Core/" .. name .. ".lua")
    end
end
LoadWindow()
Load("Core/Options/Search.lua")
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Shared/.*%.lua$")) do Load(path) end
Load("Core/Settings.lua")
Load("Core/Onboarding/Setup.lua")
Load("Core/Onboarding/ModuleState.lua")
Load("NaowhForever_QoL/Constants.lua")
env.GameTooltip = New("Frame")
env.GameTooltip.GetOwner = function() return nil end
for _, name in ipairs({ "UnitGroupRolesAssigned", "GetShapeshiftFormID", "GetShapeshiftForm", "IsInGroup",
    "IsInRaid", "IsInInstance", "UnitExists", "UnitAffectingCombat", "IsStealthed", "IsResting", "IsMounted",
    "UnitOnTaxi", "UnitIsDeadOrGhost", "GetPartyAssignment", "GetPlayerAuraBySpellID", "UnitIsUnit" }) do
    env[name] = function() return nil end
end
env.GetNumGroupMembers = function() return 0 end
env.GetNumSubgroupMembers = function() return 0 end
env.GetNumShapeshiftForms = function() return 0 end
env.UnitHealth = function() return 1 end
env.UnitHealthMax = function() return 1 end
env.RegisterUnitWatch = function() end
env.RegisterStateDriver = function() end
env.UnregisterStateDriver = function() end
env.GetFramerate = function() return 60 end
env.GetNetStats = function() return 0, 0, 30, 30 end
env.IsInGuild = function() return false end
env.BNGetNumFriends = function() return 0, 0 end
env.date = os.date
env.UnregisterUnitWatch = function() end
env.Mixin = function(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
end
env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, SetRGBA = function() end } end
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.hooksecurefunc = function(target, key, fn)
    if type(target) == "table" then
        local prior = target[key]
        target[key] = function(...) if prior then prior(...) end; fn(...) end
    end
end
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_QoL/TopBar/.*%.lua$")) do Load(path) end
for _, path in ipairs({ "NaowhForever_QoL/Combat/StealthReminder.lua", "NaowhForever_QoL/Combat/CoTank.lua" }) do Load(path) end
local UI = ns.UI
ns.BuildQoLInterfacePage = function(parent, y) return y end
for _, name in ipairs({ "JournalSettings", "DiscoverySettings", "ProfessionSettings", "MacroSettings", "AuraBuffSettings",
    "ThreatMeterSettings", "SwingTimerSettings", "TopBarSettings", "ActionBarSettings", "TrainingSettings",
    "InstanceTrackerSettings", "CompletoSettings", "PvPSettings" }) do
    ns[name] = UI.ModuleSettings(name, { enabled = false })
end
ns.DB = function() return settings end
ns.SetEnabled = function(v) settings.enabled = v end
local function Flush()
    while #timers > 0 do local q = timers; timers = {}; for _, fn in ipairs(q) do fn() end end
end
local function Text(text)
    for _, f in ipairs(frames) do if f.text == text and f:IsShown() then return f end end
end
local function Button(text)
    local label = assert(Text(text), "missing visible label: " .. text)
    local f = label.parent
    while f and not f.scripts.OnClick do f = f.parent end
    return assert(f, "missing button: " .. text)
end
local cases = 0
local function Check(ok, why) assert(ok, why); cases = cases + 1 end
local function Click(button) button.scripts.OnClick(button) end
ns.OpenOptionsWindow()
local function Head(name)
    for _, f in ipairs(frames) do
        local head = f.text == name and f:IsShown() and f.parent
        if head and head.card then return head end
    end
end
Check(Text("Home") and Text("Open a Window") and Text("Dungeon Journal") and Text("Open"),
    "opens on Home, with a row for each module's window")
Check(Text("CHARACTER") and Text("WORLD") and Text("COMBAT & GROUPS"), "the categories, grouped in bands")
do
    -- The game draws a scroll frame's rows only once it has measured them; the sidebar must measure on show.
    local navScroll
    for _, f in ipairs(frames) do
        if f.text == "Interface" and f.parent and f.parent.cat and f.parent.scripts.OnClick then
            navScroll = f.parent.parent.parent
        end
    end
    local measured = 0
    navScroll.UpdateScrollChildRect = function() measured = measured + 1 end
    navScroll.scripts.OnShow(navScroll)
    navScroll.UpdateScrollChildRect = nil
    Check(navScroll.kind == "ScrollFrame" and measured > 0,
        "the sidebar measures its list when it shows, so its first row (Home) is drawn")
end
Check(not Text("Close") and Button("Reload UI") ~= nil, "no footer: Reload UI sits in the header, closing is the X")
Check(not Text("Custom Reminders"), "unfinished module is absent from navigation")
local damageMeterLabels = 0
for _, f in ipairs(frames) do if f.text == "Damage Meter" and f:IsShown() then damageMeterLabels = damageMeterLabels + 1 end end
Check(damageMeterLabels == 0, "the Damage Meter is not shipped as a module: nothing in the sidebar carries its name")
Check(Button("Combat").switch == nil, "navigation does not toggle anything")
Check(Button("Home").icon ~= nil, "Home is listed with its glyph")
for _, cat in ipairs(ns.Options.CATEGORIES) do
    Check(Button(cat.name).icon ~= nil, cat.name .. " is listed with its glyph")
end
do
    local listed = {}
    for _, cat in ipairs(ns.Options.CATEGORIES) do listed[#listed + 1] = (cat.band or "") .. ":" .. cat.name end
    Check(table.concat(listed, "|") == ":Interface|CHARACTER:Character & Gear|CHARACTER:Leveling & Training"
        .. "|CHARACTER:Action Bars & Macros|CHARACTER:Buffs & Consumables|WORLD:Quests & Exploration|WORLD:Map & Travel"
        .. "|WORLD:Professions|WORLD:Auction House|WORLD:Bags, Loot & Mail|COMBAT & GROUPS:Combat"
        .. "|COMBAT & GROUPS:Dungeons & Groups|COMBAT & GROUPS:PvP",
        "the thirteen categories in their bands, Interface on its own under Home")
end
local moduleList = Button("Map & Travel").parent
local navTopBar = false
for _, f in ipairs(frames) do
    if f.text == "Top Bar" and f.parent and f.parent.parent == moduleList then navTopBar = true end
end
Check(not navTopBar, "the Top Bar has no sidebar entry: it is a page of Interface")
local moduleScroll = moduleList.parent
local mainWindow = moduleScroll.parent.parent
local originalHeight = mainWindow:GetHeight()
-- Tall enough for every entry, to see the scrollbar go again.
local TALL_WINDOW = 1000
mainWindow:SetHeight(822)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
local lastModule
for _, f in ipairs(frames) do
    if f.parent == moduleList and f.points and f.points.TOPLEFT and f:IsShown()
        and (not lastModule or f.points.TOPLEFT[4] < lastModule.points.TOPLEFT[4]) then
        lastModule = f
    end
end
moduleScroll:SetVerticalScroll(moduleScroll:GetVerticalScrollRange())
Check(-lastModule.points.TOPLEFT[4] + lastModule:GetHeight()
    <= moduleScroll:GetVerticalScroll() + moduleScroll:GetHeight(),
    "scrolled to the end, the last entry is fully in view above the fixed footer")
moduleScroll:SetVerticalScroll(0)
mainWindow:SetHeight(620)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
Check(moduleScroll.bar:IsShown(), "short windows display a navigation scrollbar")
moduleScroll.scripts.OnMouseWheel(moduleScroll, -100)
Check(moduleScroll:GetVerticalScroll() == 0 and moduleScroll.scripts.OnUpdate, "the wheel glides instead of jumping")
for _ = 1, 100 do
    if not moduleScroll.scripts.OnUpdate then break end
    moduleScroll.scripts.OnUpdate(moduleScroll, 0.016)
end
Check(not moduleScroll.scripts.OnUpdate, "the glide stops once it lands")
Check(moduleScroll:GetVerticalScroll() == moduleScroll:GetVerticalScrollRange(), "wheel reaches the last category")
Check(moduleScroll.bar:GetValue() == moduleScroll:GetVerticalScroll(), "scrollbar follows wheel scrolling")
moduleScroll.bar.scripts.OnValueChanged(moduleScroll.bar, 20)
Check(moduleScroll:GetVerticalScroll() == 20, "dragging the scrollbar moves navigation")
mainWindow:SetHeight(TALL_WINDOW)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
Check(moduleScroll:GetVerticalScroll() == 0 and not moduleScroll.bar:IsShown(),
    "growing the window clears the scroll offset and hides the scrollbar")
mainWindow:SetHeight(originalHeight)
moduleScroll.scripts.OnSizeChanged(moduleScroll)

-- The page scrollbar drags itself: the thumb follows the cursor from where it was grabbed.
local pageScroll
for _, f in ipairs(frames) do if f.bar and f.parent == mainWindow then pageScroll = f end end
local pageBar = pageScroll.bar
local pageThumb = pageBar.thumbTexture
local grip
for _, f in ipairs(pageBar.children) do if f.scripts.OnMouseDown then grip = f end end
Check(pageBar.mouse == false and grip.mouse, "the page scrollbar's own Slider drag is off, its grip takes the mouse")
local cursorY, buttonDown = 0, true
env.GetCursorPosition = function() return 0, cursorY end
env.IsMouseButtonDown = function() return buttonDown end
local BAR_TOP, THUMB_H, RANGE = 1000, 100, 1000
local travel = pageBar:GetHeight() - THUMB_H
pageThumb:SetHeight(THUMB_H)
pageBar:SetMinMaxValues(0, RANGE)
pageBar:SetValue(0)
pageThumb.GetCenter = function() return 0, BAR_TOP - THUMB_H / 2 - pageBar:GetValue() / RANGE * travel end
pageScroll.child:SetHeight(pageScroll:GetHeight() + RANGE)
pageScroll.scripts.OnMouseWheel(pageScroll, -1)
Check(pageScroll.scripts.OnUpdate ~= nil, "the page wheel glides")
cursorY = BAR_TOP - THUMB_H / 2 + 10
grip.scripts.OnMouseDown(grip, "LeftButton")
Check(pageScroll.scripts.OnUpdate == nil, "grabbing the scrollbar stops a wheel glide")
Check(pageBar:GetValue() == 0, "grabbing the thumb does not move it")
cursorY = cursorY - travel / 2
grip.scripts.OnUpdate(grip)
Check(pageBar:GetValue() == RANGE / 2, "dragging down scrolls down, in step with the cursor")
cursorY = cursorY + travel / 4
grip.scripts.OnUpdate(grip)
Check(pageBar:GetValue() == RANGE / 4, "dragging up scrolls back up")
buttonDown = false
grip.scripts.OnUpdate(grip)
Check(grip.scripts.OnUpdate == nil, "letting go ends the drag")
buttonDown = true
cursorY = BAR_TOP - pageBar:GetHeight()
grip.scripts.OnMouseDown(grip, "LeftButton")
Check(pageBar:GetValue() == RANGE, "a press on the track brings the thumb to the cursor")
grip.scripts.OnMouseUp(grip, "LeftButton")
pageBar:SetValue(0)
pageScroll:SetVerticalScroll(0)

ns.OpenOptionsWindow("Interface > Top Bar"); Flush()
Check(Head("Top Bar").card.uid == "QoL/Interface:topBar", "the Top Bar's card, declared on QoL Interface, is on Interface > Top Bar")
ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
local S = ns.QoLSettings
Check(Head("Co-Tank Frame") and not Head("Stealth Reminder"),
    "each feature on the page is a card, and only the page's own")
Check(not Text("Out of Stealth Color") and not Text("Max Icons"), "cards start closed: their settings do not show")
local function Setting(label)
    local text = Text(label)
    return text and text.parent.setting and text.parent or nil
end
-- Walked through from Co-Tank off with its debuffs on, the original defaults.
S.Set("coTank", false); S.Set("coTankDebuffs", true); Flush()
local coTank = Head("Co-Tank Frame")
coTank.switch.scripts.OnClick(coTank.switch); Flush()
Check(S.Get("coTank") and Setting("Max Icons") ~= nil, "turning a card on opens it")
Check(Setting("Max Icons").label.alpha == 1, "its settings are on while it is on")
local debuffs = Setting("Co-Tank Debuffs")
debuffs.controls.toggle.scripts.OnClick(debuffs.controls.toggle); Flush()
Check(not S.Get("coTankDebuffs") and Setting("Max Icons").label.alpha < 1, "a setting is dimmed while what it needs is off")
Check(Setting("Max Icons").why.text == "Needs Co-Tank Debuffs", "and says what it needs")
Setting("Co-Tank Debuffs").controls.toggle.scripts.OnClick(Setting("Co-Tank Debuffs").controls.toggle); Flush()
Check(S.Get("coTankDebuffs") and Setting("Max Icons").label.alpha == 1, "on again, it is back")
S.Set("coTankWidth", 222); Flush()
Check(Setting("Width").dot.visible and Text("Reset Co-Tank Frame") ~= nil, "a changed setting has its dot, and its card a reset")
local reset = Text("Reset Co-Tank Frame").parent
local changedNote = reset.parent.text
Check(changedNote and changedNote.points.RIGHT and changedNote.points.RIGHT[1] == reset,
    "the changed note stops short of the reset link, so a narrow card does not overlap them")
reset.scripts.OnClick(reset); Flush()
Check(S.Get("coTankWidth") == S.Default("coTankWidth") and not Text("Reset Co-Tank Frame"),
    "the reset puts the card's settings back")
coTank = Head("Co-Tank Frame")
coTank.switch.scripts.OnClick(coTank.switch); Flush()
Check(not S.Get("coTank") and Setting("Width").label.alpha < 1, "turned off, the card stays open with its settings dimmed")
coTank = Head("Co-Tank Frame")
coTank.scripts.OnClick(coTank); Flush()
Check(not Text("Max Icons"), "a click on its head closes it")
Check(not S.Get("coTank"), "closing it keeps its settings")
UI.GoToSetting("QoL/Combat", "Out of Stealth Color", "QoL/Combat:stealthReminder"); Flush()
Check(Setting("Out of Stealth Color") ~= nil, "a jump to a setting opens its card and shows the setting")
ns.OpenOptionsWindow("QoL/Interface"); Flush()
local topBar = Head("Top Bar")
if not Text("24-Hour Clock") then Click(topBar); Flush() end
Check(not Text("Normal") and not Text("Faded") and not Text("In Combat"), "with nothing to compare, the studio shows no moments")
local barStore = topBar.card.store
barStore.Set("mouseover", true); barStore.Set("hideInCombat", true); Flush()
Check(Text("Normal") and Text("Faded") and Text("In Combat"), "an open card with a studio shows its moments")
Click(Button("Faded")); Flush()
-- A slider being dragged holds the page's redraw (it would hide the slider and end the drag),
-- and the page catches up once it is let go.
UI.sliderDrag = {}
barStore.Set("mouseoverAlpha", 30)
local held = timers; timers = {}
for _, fn in ipairs(held) do fn() end
Check(#timers > 0, "a slider being dragged holds the settings page's redraw")
UI.sliderDrag = nil
Flush()
Check(#timers == 0, "and the page draws again once it is let go")
barStore.Set("mouseoverAlpha", 40); Flush()
local studio
for _, f in ipairs(frames) do if f.previews and f:IsShown() then studio = f end end
local preview = studio and studio.previews[topBar.card]
Check(preview and preview.alpha == 0.4, "faded, the preview is at Faded Opacity, drawn again as the setting changes")
Check(Text("Drag to move, x to remove, + to add.") ~= nil, "the preview says how to edit the bar")
barStore.Set("hideInCombat", true)
Click(Button("In Combat")); Flush()
Check(preview.alpha == 0 and preview.sys.alpha == 1, "in combat it hides with Hide In Combat, its FPS / MS up")
barStore.Set("hideInCombat", false); barStore.Set("mouseover", false); Flush()
Click(Head("Top Bar")); Flush()
local found = 0
for _, target in ipairs(UI.Search.Collect()) do
    if target.page == "Interface > Top Bar" and target.label == "Faded Opacity" and target.card == "QoL/Interface:topBar" then
        found = found + 1
    end
end
Check(found == 1, "the search lists the declared settings, each once")
local strip = Button("Overview").parent
local tabs = 0
for _, child in ipairs(strip.children) do
    if child.scripts.OnClick then
        tabs = tabs + 1
        Check(child.points.LEFT and child.points.LEFT[4] == 0, "a category's pages share one row")
    end
end
Check(tabs == 6 and strip.buttons[1].text.text == "Overview" and strip.buttons[2].text.text == "Top Bar",
    "Interface has a tab for each page, after its Overview")
local qolTabs = {}
for _, tab in ipairs(ns.Options.MODULES[1].tabs) do qolTabs[#qolTabs + 1] = tab.name end
Check(table.concat(qolTabs, "|", #qolTabs - 2) == "Travel|Cursor & Crosshair|Damage Meter",
    "Cursor & Crosshair and Damage Meter are the last QoL tabs, after Travel")
Check(strip.buttons and strip:GetWidth() <= 1440 - 240 - 56, "the tabs are the boxed switch, inside the content width")
Click(Button("Tooltips")); Flush()
Check(Text("Interface / Tooltips") ~= nil, "page navigation works")
ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
local heldCard = ns.Shared.Settings.CardOf("QoL/Combat:coTank")
local wasOn, wasOpen = S.Get("coTank"), ns.Shared.Settings.IsOpen(heldCard)
S.Set("coTank", true); ns.Shared.Settings.SetOpen(heldCard, true)
heldCard.switchWhy = function() return "Held by another setting" end
S.Set("coTankDebuffs", S.Get("coTankDebuffs")); Flush()
Check(Setting("Width").label.alpha < 1 and Setting("Width").why.text == "Held by another setting",
    "its settings are greyed too, saying why, though its own switch is on")
local coTankHead = Head("Co-Tank Frame")
Check(coTankHead.summary.text == "Held by another setting" and coTankHead.switch.mouse == false and coTankHead.switch.alpha < 1,
    "a card switch held by another setting is greyed, saying why instead of Off")
heldCard.switchWhy = nil
S.Set("coTankDebuffs", S.Get("coTankDebuffs")); Flush()
Check(Setting("Width").label.alpha == 1, "let go, its settings work again")
S.Set("coTank", wasOn); ns.Shared.Settings.SetOpen(heldCard, wasOpen); Flush()
coTankHead = Head("Co-Tank Frame")
Check(coTankHead.switch.mouse ~= false and coTankHead.switch.alpha == 1, "let go, it is its own switch again")
local heldOff, heldWhy = ns.Shared.Settings.Off({ card = {}, needs = function() return false end,
    why = function() return "Held for this reason" end })
Check(heldOff and heldWhy == "Held for this reason", "a row held for more than one reason says the one that applies")
Click(Button("Map & Travel")); Flush()
Check(Text("Map & Travel / Overview") and Text("Object Highlights") and not Text("Interface / Tooltips"),
    "a category opens on its Overview, with its own tabs only")
Click(Button("Home")); Flush()
Check(Text("Open a Window") and not Text("Overview"), "Home shows no tab row")
Click(Button("Combat")); Flush()
Check(Text("Combat / Tank & Healer") ~= nil, "returning to a category remembers its page")
local count = #frames
for _ = 1, 8 do UI:RefreshPage(true); Flush() end
Check(#frames == count, "refreshes reuse controls without accumulating frames")
local root = env.NaowhForeverOptions
root:Hide(); UI:RefreshPage(true)
local hiddenCount = #frames
Check(#frames == hiddenCount, "hidden refresh does not build controls")
ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
Check(Text("Co-Tank Frame") ~= nil, "reopening rebuilds the visible page")
Check(not Text("Enable QoL") and not Text("Enable Threat Meter"), "the page header has no module switch")
ns.OpenOptionsWindow("Combat > Meters & Alerts"); Flush()
local function ModuleSwitch(name) return Head(name).switch end
Check(Head("Threat Meter") and ModuleSwitch("Threat Meter")._get() == false and Head("Threat Meter").summary.text == "Off",
    "a module's own card heads the page that holds its settings, its switch off with it")
ModuleSwitch("Threat Meter").scripts.OnClick(); Flush()
Check(ns.ThreatMeterSettings.Get("enabled") == true and ns.QoLSettings.Get("enabled") == true
    and ModuleSwitch("Threat Meter")._get() == true and Head("Threat Meter").summary.text == "/nfthreat",
    "its switch turns that module alone on, and its card names its command")
settings = { qol = { enabled = true, coTankWidth = 233 } }
UI:RefreshPage(true); Flush()
Check(ModuleSwitch("Threat Meter")._get() == false and ns.QoLSettings.Get("coTankWidth") == 233,
    "profile replacement refreshes controls against the new settings")
ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
local beforeWidth = Head("Co-Tank Frame"):GetWidth()
root:SetWidth(1640); UI:RefreshPage(true); Flush()
Check(Head("Co-Tank Frame"):GetWidth() > beforeWidth, "cards grow with the window")
root:SetWidth(1440); UI:RefreshPage(true); Flush()
Check(Head("Co-Tank Frame"):GetWidth() == beforeWidth, "and shrink with it")
local pages = UI.SearchPages
UI.SearchPages = function()
    local out = {}
    for _, page in ipairs(pages()) do
        if page.key == "Combat > Your Class" or page.key == "Combat > Tank & Healer" then out[#out + 1] = page end
    end
    return out
end
local hit = UI.Search.Find(UI.Search.Collect(), "Out of Stealth Color")[1]
Check(hit and hit.card == "QoL/Combat:stealthReminder" and hit.trail:find("Stealth Reminder", 1, true),
    "a setting is found in its card, the card named in its trail")
local debuffHit = UI.Search.Find(UI.Search.Collect(), "Co-Tank Debuffs")[1]
Check(debuffHit and debuffHit.card == "QoL/Combat:coTank", "a setting's card is the one it opens")
local iconHit = UI.Search.Find(UI.Search.Collect(), "Max Icons")[1]
UI.GoToSetting("QoL/Combat", "Max Icons", iconHit.card); Flush()
Check(Text("Co-Tank Debuffs") and Text("Max Icons"), "the jump opens its card")
UI.SearchPages = pages
for _, page in ipairs(UI.SearchPages()) do Check(not page.soon, "unfinished pages are not search results") end

-- The sidebar's search: Ctrl+F goes to its box, and typing trims the window to what matches.
-- Modules and tabs without a match dim, the rest count their matches, and the page keeps only
-- its matching cards and settings, the typed words lit. Escape brings it all back.
do
    local ctrl = false
    env.IsControlKeyDown = function() return ctrl end
    local function Plain(text)
        return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    -- A visible string that reads label once its colour codes are gone.
    local function Shown(label)
        for _, f in ipairs(frames) do
            if f:IsShown() and type(f.text) == "string" and Plain(f.text) == label then return f end
        end
    end
    local function Alpha(button) return button.label.color[4] end
    local note = "Nothing on this page matches the search."
    ns.OpenOptionsWindow("QoL/Interface"); Flush()
    Check(Text("Interface / Top Bar") ~= nil, "an old page key lands on the category page that holds its first card")
    local threatAlpha = Alpha(Button("PvP"))
    Check(not Text("Search  " .. ns.Color("muted", "Ctrl+F")), "the header has no Search button")
    local input = Text("Search settings").parent
    local sidebar = moduleScroll.parent
    Check(input.parent == sidebar, "the search box sits in the sidebar")
    Check(input.points.TOPLEFT[4] > moduleScroll.points.TOPLEFT[4], "above the module list")
    local row = Button("Home")
    Check(input.points.TOPLEFT[3] == row.points.TOPLEFT[3]
        and input.points.TOPRIGHT[3] == moduleScroll.points.BOTTOMRIGHT[3] + row.points.TOPRIGHT[3],
        "edge to edge with the module rows under it")
    local glass
    for _, f in ipairs(input.children) do if f.texture and f.points.LEFT then glass = f end end
    Check(glass and math.abs(glass.points.LEFT[3] + glass:GetWidth() / 2 - (row.icon.points.LEFT[3] + row.icon:GetWidth() / 2)) <= 0.5
        and Text("Search settings").points.LEFT[3] == row.label.points.LEFT[3],
        "its magnifier and text on the rows' glyph and label columns")
    ctrl = true
    root.scripts.OnKeyDown(root, "F"); Flush()
    ctrl = false
    Check(input:HasFocus() and root:IsShown(), "Ctrl+F puts the cursor in it")

    input:SetText("max icons"); Flush()
    Check(Text("Combat / Tank & Healer") ~= nil, "the page moves to the first one with a match")
    local icons = Shown("Max Icons")
    Check(icons and icons.parent.setting and Shown("Co-Tank Frame"), "the matching setting shows, its card open")
    Check(icons.text:find(ns.Color("accent", "Max"), 1, true) and icons.text:find(ns.Color("accent", "Icons"), 1, true),
        "the typed words are lit in its name")
    Check(not Shown("Width") and not Shown("Stealth Reminder"),
        "the rest of the page is left out")
    Check(Button("Combat").count.text == "1" and Alpha(Button("Combat")) == 1,
        "the category with the match counts it")
    Check(Alpha(Button("PvP")) < threatAlpha and Button("PvP").count.text == "",
        "a category without a match dims")
    Check(Button("Meters & Alerts").text.alpha < 1 and Button("Tank & Healer").text.alpha == 1, "and so does a tab")

    S.Set("coTankWidth", 222); Flush()
    Check(not Text("Reset Co-Tank Frame") and not Shown("1 setting changed from its default"),
        "part of a card shows no reset, which would reset what is left out")
    local heldHead = Head("Co-Tank Frame") or Shown("Co-Tank Frame").parent
    Check(heldHead.held and not heldHead.chevron:IsShown(), "a card the search holds open has no chevron")
    heldHead.scripts.OnClick(heldHead); Flush()
    Check(Shown("Max Icons") ~= nil, "and a click on its head does not fold it")
    S.Set("coTankWidth", S.Default("coTankWidth")); Flush()

    input:SetText("co-tank"); Flush()
    Check(Shown("Co-Tank Frame") and Shown("Width") and Shown("Max Icons"),
        "a card's name keeps all of the card")

    input:SetText("zzzz"); Flush()
    Check(Text(note) ~= nil and not Shown("Co-Tank Frame"), "nothing found, the page says so")
    Check(Alpha(Button("PvP")) < threatAlpha and Button("Combat").count.text == "",
        "and every category but the open one dims, none with a count")

    input:SetText("max icons"); Flush()
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(root:IsShown() and input:GetText() == "" and UI.filter == nil, "Escape clears the search, not the window")
    Check(Head("Co-Tank Frame") and not Text(note), "the whole page is back")
    Check(Setting("Max Icons") ~= nil, "the card the search found stays open")
    Check(Button("Combat").count.text == "" and Alpha(Button("PvP")) == threatAlpha
        and Button("Meters & Alerts").text.alpha == 1, "the counts go and nothing is dimmed")

    input:SetText("-"); Flush()
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(root:IsShown() and input:GetText() == "", "Escape clears text with no words in it before closing")

    input:SetText("max icons"); Flush()
    input.scripts.OnEscapePressed(input); Flush()
    Check(input:GetText() == "" and UI.filter == nil and root:IsShown(), "Escape in the box clears it too")
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(not root:IsShown(), "with no search, Escape closes the window")
    ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
    input:SetText("max icons"); Flush()
    root:Hide(); Flush()
    Check(input:GetText() == "" and UI.filter == nil, "closing the window clears the search")
    ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
    Check(Head("Co-Tank Frame") ~= nil, "and it reopens on the whole page")
    input:SetText("max icons"); Flush()
    UI.GoToSetting("QoL/Combat", "Out of Stealth Color", "QoL/Combat:stealthReminder"); Flush()
    Check(UI.filter == nil and Setting("Out of Stealth Color") ~= nil, "a jump to a setting clears the search first")
    local Settings = ns.Shared.Settings
    Settings.SetOpen(Settings.CardOf("QoL/Combat:stealthReminder"), false)
    UI:RefreshPage(true); Flush()
    input:SetText("color"); Flush()
    UI.GoToSetting("QoL/Interface", nil, "QoL/Interface:topBar"); Flush()
    Click(Button("Combat")); Flush()
    Check(not Text("Out of Stealth Color"), "a jump away does not leave the search's cards open on the page it left")

    -- A page its own builder draws can carry a declared settings page, as Profiles carries the
    -- Setups card: typing what only that card has lands on the page, counts it there, and the
    -- page draws the card with the typed words lit; cleared, the page is whole again.
    input:SetText(""); Flush()
    Settings.Page("Profiles/Setups", S):Card({ id = "setups", name = "Setups", help = "Naowh's setups for you.",
        rows = { { label = "Onboarding", buttonText = "Start", button = function() end,
            help = "Walks you through a profile, a skin and your modules." } } })
    UI.SearchCarries("Profiles", "Profiles/Setups")
    local drawnWith = {}
    ns.BuildProfileSettings = function(parent, y)
        local filter = UI.Search.Narrowed("Profiles")
        drawnWith[#drawnWith + 1] = filter or false
        return y - Settings.Render(parent, "Profiles/Setups", function() end, filter)
    end
    ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
    input:SetText("onboarding"); Flush()
    Check(Shown("Onboarding") and Shown("Setups") and not Shown("Co-Tank Frame"),
        "a setting only the carried card has moves the window to the Profiles page, at that card")
    Check(Button("Profiles").count.text == "1" and Button("Combat").count.text == "",
        "the Profiles page counts it")
    Check(Shown("Onboarding").text:find(ns.Color("accent", "Onboarding"), 1, true) and drawnWith[#drawnWith] ~= false,
        "drawn with the search, its words lit")
    input:SetText("skin"); Flush()
    Check(drawnWith[#drawnWith] == UI.filter, "the page draws again as the words change")
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(UI.filter == nil and drawnWith[#drawnWith] == false and Head("Setups") ~= nil and not Shown("Onboarding"),
        "cleared, the page is drawn whole again, its card folded as it started")

    -- A window card is found by its button and drawn on its page while the search holds it.
    Settings.Page("QoL/Cursor & Crosshair", S):Window({ text = "Open Test Log", open = function() end,
        headline = "Test Log", detail = "Every test, logged." })
    input:SetText("test log"); Flush()
    Check(Text("Combat / Cursor & Crosshair") and Shown("Test Log") and not Shown("Co-Tank Frame"),
        "a window card found shows on its page, the rest left out")

    -- The Settings page is drawn by its own builder and names what is on it.
    local function NavCount(name)
        for _, f in ipairs(frames) do
            if f.text == name and f:IsShown() and f.parent.count then return tonumber(f.parent.count.text) end
        end
    end
    for _, query in ipairs({ "minimap", "game menu", "window scale", "addon font", "skin", "theme", "modules" }) do
        input:SetText(query); Flush()
        Check(NavCount("Settings"), "'" .. query .. "' is counted on the Settings page")
    end

    -- A module that is off has no pages to search, so its name finds the Settings page, which says so.
    input:SetText(""); Flush()
    missingAddOns.NaowhForever_Training = true
    ns.OpenOptionsWindow("Settings"); Flush()
    input:SetText("training planner"); Flush()
    Check(Text("Training Planner is turned off, so its settings are hidden. Turn it on under Modules below.")
        and Text("MODULES") and NavCount("Settings") >= 1, "a module that is off is found on Settings, with how to turn it on")
    input:SetText(""); Flush()
    missingAddOns.NaowhForever_Training = nil
    input:SetText("training planner"); Flush()
    Check(not Text("Training Planner is turned off, so its settings are hidden. Turn it on under Modules below."),
        "on, it is not called off")

    -- A page its own builder draws says when nothing on it matches, as card pages do.
    input:SetText("zzzz"); Flush()
    Check(Text(note) and Text("MODULES"), "nothing found on the Settings page, it says so over the page")
    input:SetText(""); Flush()
    Check(not Text(note) and Text("MODULES"), "cleared, the note goes")

    -- Home opens a module's own window from its row, and Back brings the options window back.
    ns.OpenOptionsWindow("Home"); Flush()
    local journalRow = Text("Dungeon Journal").parent
    local opened
    ns.ToggleJournalWindow = function() opened = true end
    Click(journalRow._control); Flush()
    Check(opened and not root:IsShown(), "Home opens a module's window from its row")
    ns.ToggleJournalWindow = nil
    ns.BuildProfileSettings = nil
end

-- A confirm: No, Escape and a newer confirm taking its place all count as no; Yes does not.
do
    local yes, no = 0, 0
    local function Ask() ns.Confirm("Sure?", function() yes = yes + 1 end, function() no = no + 1 end) end
    Ask(); Click(Button("Yes")); Flush()
    Check(yes == 1 and no == 0, "Yes confirms without counting as no")
    Ask(); Click(Button("No")); Flush()
    Check(yes == 1 and no == 1, "No cancels")
    Ask()
    local dimmer = Text("Sure?").parent.parent
    dimmer.scripts.OnKeyDown(dimmer, "ESCAPE"); Flush()
    Check(yes == 1 and no == 2 and not dimmer:IsShown(), "Escape cancels")
    Ask(); Ask()
    Check(no == 3, "a confirm taking another's place cancels that one")
    Click(Button("No")); Flush()
    Check(no == 4 and yes == 1, "and the new one still answers once")
end

-- A module shipped as its own addon: switching it off disables the addon, with every module
-- linked to it, once the player confirms.
local confirmText, confirmYes, reloadText
ns.Confirm = function(text, yes) confirmText, confirmYes = text, yes end
ns.ConfirmReload = function(text) reloadText = text end
ns.OpenOptionsWindow("Dungeons & Groups > Dungeon Journal"); Flush()
ModuleSwitch("Dungeon Journal").scripts.OnClick(); Flush()
Check(ns.JournalSettings.Get("enabled") == true and confirmText == nil, "switching an addon module on needs no reload")
ModuleSwitch("Dungeon Journal").scripts.OnClick(); Flush()
Check(confirmText and confirmText:find("Dungeon Journal", 1, true) and not confirmText:find("BiS List", 1, true),
    "switching the journal off asks for the journal alone: the BiS List works without it")
Check(next(disabled) == nil, "nothing is disabled before the player confirms")
confirmYes()
Check(disabled.NaowhForever_DungeonJournal and not disabled.NaowhForever_BiS, "confirming disables the journal alone")
Check(reloadText and reloadText:find("reload", 1, true), "then offers the reload")
Check(ns.JournalSettings.Get("enabled") == false, "the profile's switch goes off with the addon, so another character follows it")
Check(ModuleSwitch("Dungeon Journal")._get() == false, "the switch reads off while the disable waits for its reload")
ModuleSwitch("Dungeon Journal").scripts.OnClick(); Flush()
Check(not disabled.NaowhForever_DungeonJournal and ModuleSwitch("Dungeon Journal")._get() == true,
    "switching it back on before the reload cancels the disable")
confirmText, reloadText = nil, nil
ns.OpenOptionsWindow("Combat > Swings & Casts"); Flush()
local swingWas = ns.SwingTimerSettings.Get("enabled")
ModuleSwitch("Swing Timer").scripts.OnClick(); Flush()
Check(confirmText == nil and reloadText == nil and ns.SwingTimerSettings.Get("enabled") == not swingWas,
    "a Combat module switches at once: no confirm, no reload")
ModuleSwitch("Swing Timer").scripts.OnClick(); Flush()
Check(ns.SwingTimerSettings.Get("enabled") == swingWas and confirmText == nil and reloadText == nil
    and not disabled.NaowhForever_Combat, "and back the same way, with Combat left on for the others")
ns.OpenOptionsWindow("Action Bars & Macros > Bar Options"); Flush()
local barsWas = ns.ActionBarSettings.Get("enabled")
ModuleSwitch("Action Bars").scripts.OnClick(); Flush()
Check(confirmText == nil and reloadText == nil and ns.ActionBarSettings.Get("enabled") == not barsWas,
    "a Utilities module switches at once too")
ModuleSwitch("Action Bars").scripts.OnClick(); Flush()
Check(ns.ActionBarSettings.Get("enabled") == barsWas and confirmText == nil and reloadText == nil
    and not disabled.NaowhForever_Utilities, "and back, with Utilities left on for the others")
confirmText = nil
ns.OpenOptionsWindow("Professions > Crafting"); Flush()
ModuleSwitch("Professions").scripts.OnClick(); Flush()
ModuleSwitch("Professions").scripts.OnClick(); Flush()
Check(confirmText and not confirmText:find("Training Planner", 1, true), "Professions leaves Training Planner alone")
confirmYes()
Check(disabled.NaowhForever_Professions and not disabled.NaowhForever_Training and not disabled.NaowhForever_BiS,
    "and only the modules that need it")
missingAddOns.NaowhForever_Professions = true
ns.OpenOptionsWindow("Professions/Settings"); Flush()
Check(Text("Professions / Crafting") and Head("Professions") and ModuleSwitch("Professions")._get() == false,
    "a link to a module that is off lands on its category page, where its own card turns it back on")
missingAddOns.NaowhForever_Professions = nil

missingAddOns.NaowhForever_Utilities = true
ns.OpenOptionsWindow("Instance Tracker"); Flush()
Check(Text("Dungeons & Groups / Instance Tracker") and ModuleSwitch("Instance Tracker")._get() == false,
    "Instance Tracker's card stays while the Utilities addon it ships in is not loaded, off")
missingAddOns.NaowhForever_Utilities = nil

-- The core owns Unlock Mode.
ns.ShowUnlockMode(); Flush()
Check(Text("HUD Editor") and Text("Exit Config") and not Text("Snap Elements"), "the core opens the HUD Editor")
Click(Button("Exit Config")); Flush()
Check(not Text("Exit Config") and not ns.IsUnlockModeActive(), "and Exit Config closes it")

ns.OpenOptionsWindow("Settings"); Flush()
Check(not Text("Top Bar"), "the Top Bar is a card under Quality of Life, not a row under Settings > Modules")
local function GroupInspectRows()
    local rows = 0
    for _, f in ipairs(frames) do
        if f.text == "Group Inspect" and f:IsShown() and f.parent and f.parent:IsShown() then rows = rows + 1 end
    end
    return rows
end
Check(GroupInspectRows() == 0, "Settings: Modules and Minimap Icons start closed")
local searchInput = Text("Search settings").parent
searchInput:SetText("group inspect"); Flush()
Check(GroupInspectRows() >= 2, "a search that matches a row opens its section")
searchInput:SetText(""); Flush()
Check(GroupInspectRows() == 0, "and clearing the search folds them again")
-- A disabled, unloaded module's description reveals its switch without loading or enabling it.
do
    local function ThreatSwitch()
        for _, f in ipairs(frames) do
            if f:IsShown() and f.parent and f.parent._cfg and f.parent._cfg.module
                and f.parent._cfg.module.name == "Threat Meter" and f.parent._control == f then return f end
        end
    end
    missingAddOns.NaowhForever_Combat = true
    local enabled = ns.ThreatMeterSettings.Get("enabled")
    local enable, load = env.C_AddOns.EnableAddOn, env.C_AddOns.LoadAddOn
    local calls = 0
    env.C_AddOns.EnableAddOn = function() calls = calls + 1 end
    env.C_AddOns.LoadAddOn = function() calls = calls + 1 end
    ns.OpenOptionsWindow("Settings"); Flush()
    Check(not ThreatSwitch(), "the unloaded Threat Meter switch starts folded")
    for _, query in ipairs({ "pull", "threat", "settings pull", "pull warning" }) do
        searchInput:SetText(query); Flush()
        Check(Text("Threat Meter is turned off, so its settings are hidden. Turn it on under Modules below."),
            "'" .. query .. "' finds the unloaded module")
        Check(ThreatSwitch(), "'" .. query .. "' reveals its module switch")
    end
    searchInput:SetText("zzzz"); Flush()
    Check(not ThreatSwitch(), "a nonmatching search restores the closed module fold")
    searchInput:SetText(""); Flush()
    Check(not ThreatSwitch(), "clearing search restores the closed module fold")
    Click(Text("MODULES").parent.hit); Flush()
    searchInput:SetText("pull"); Flush()
    searchInput:SetText(""); Flush()
    Check(ThreatSwitch(), "clearing search preserves a previously open module fold")
    Check(calls == 0 and missingAddOns.NaowhForever_Combat
        and ns.ThreatMeterSettings.Get("enabled") == enabled,
        "search never enables or loads the module or changes its profile switch")
    Click(Text("MODULES").parent.hit); Flush()
    env.C_AddOns.EnableAddOn, env.C_AddOns.LoadAddOn = enable, load
    missingAddOns.NaowhForever_Combat = nil
end
Click(Text("MODULES").parent.hit); Flush()
Click(Text("MINIMAP ICONS").parent.hit); Flush()
Check(GroupInspectRows() >= 2, "Group Inspect: under Settings > Modules and in Minimap Icons once opened")
local function FoldBox(title)
    local head = Text(title).parent
    for _, f in ipairs(frames) do
        if f.edge and f:IsShown() and f.points.TOPLEFT and f.points.TOPLEFT[1] == head then return f, head end
    end
end
local box, head = FoldBox("MINIMAP ICONS")
Check(box and head._sep.visible and box:GetHeight() > head:GetHeight(), "an open fold draws its rows in a box, under a rule")
local function TextCount(text)
    local n = 0
    for _, f in ipairs(frames) do
        if f.text == text and f:IsShown() and f.parent and f.parent:IsShown() then n = n + 1 end
    end
    return n
end
ns.OpenOptionsWindow("Settings"); Flush()
Click(Text("MODULES").parent.hit); Flush()
box, head = FoldBox("MODULES")
Check(box and not head._sep.visible and box:GetHeight() == head:GetHeight(), "a shut fold is its header alone, boxed")
Check(TextCount("Top Bar") == 0, "the Top Bar is part of QoL, so Settings > Modules has no row for it")
ns.OpenOptionsWindow("Group Inspect/Settings"); Flush()
Check(Text("Dungeons & Groups / Group Tools") ~= nil, "Group Inspect's settings are on Dungeons & Groups > Group Tools")
ns.OpenOptionsWindow("Blessings/Settings"); Flush()
Check(Text("Combat / Your Class") ~= nil, "existing module/tab deep links land on their category page")
ns.OpenOptionsWindow("Combat > Tank & Healer"); Flush()
local Settings = ns.Shared.Settings
local function American(text) return not (text and text:find("Colour", 1, true)) end
for key, page in pairs(Settings.pages) do
    for _, card in ipairs(page.items) do
        if not (card.window or card.heading) then
            local where = key .. " > " .. card.name
            Check(card.help and card.help ~= "", where .. " has its help")
            Check(American(card.name) and American(card.help), where .. " spells Color the house's way")
            if type(card.switch) == "string" then
                Check(card.store.Default(card.switch) ~= nil, where .. ": its switch has a default")
            end
            local labels = {}
            for _, row in ipairs(Settings.Rows(card)) do
                if row.kind ~= "group" then
                    local what = where .. " > " .. tostring(row.label)
                    Check(row.label and not labels[row.label], what .. " has a name of its own on the card")
                    labels[row.label] = true
                    Check(American(row.label) and American(row.help), what .. " spells Color the house's way")
                    if row.key and row.store == card.store then
                        Check(card.store.Default(row.key) ~= nil, what .. ": " .. row.key .. " has a default")
                    end
                    local needs = type(row.needs) == "string" and { row.needs } or type(row.needs) == "table" and row.needs or {}
                    for _, need in ipairs(needs) do
                        Check(row.store.Default(need) ~= nil, what .. " needs a real setting: " .. need)
                    end
                end
            end
        end
    end
end
-- Group Inspect ships in NaowhForever_Utilities but needs the BiS List, so while that is not loaded
-- only its card shows, off, where its settings would be.
Settings.Page("Group Inspect/Settings", S):Card({ id = "share", name = "Share Your Stats",
    help = "Sends your stats to your group." })
ns.OpenOptionsWindow("Dungeons & Groups > Group Tools"); UI:RefreshPage(true); Flush()
Check(Head("Group Inspect") and Head("Share Your Stats"), "loaded, Group Inspect's card heads its own cards")
missingAddOns.NaowhForever_BiS = true
UI:RefreshPage(true); Flush()
Check(Head("Group Inspect") and ModuleSwitch("Group Inspect")._get() == false and not Head("Share Your Stats"),
    "Group Inspect is only its card, off, while the BiS List it needs is not loaded")
missingAddOns.NaowhForever_BiS = nil

-- Quality of Life is its own addon, with the Top Bar inside it (its card sits on Interface > Top Bar);
-- while QoL is not loaded, its card stands in for its features on every page that holds them.
local qolMod
for _, mod in ipairs(ns.Options.MODULES) do
    if mod.addon == "NaowhForever_QoL" then qolMod = mod end
end
Check(qolMod and qolMod.name == "QoL", "Quality of Life is a module addon, NaowhForever_QoL")
local qolRow = false
for _, mod in ipairs(ns.ModuleAddons()) do
    if mod.addon == "NaowhForever_QoL" and mod.store == ns.QoLSettings and mod.key == "enabled" then qolRow = true end
end
Check(qolRow, "and has its own switch under Settings > Modules, on the core's QoL store")
Check(#ns.LinkedAddons("NaowhForever_QoL", false) == 1, "turning QoL off takes no other addon: the Top Bar is part of it")
confirmText, confirmYes = nil, nil
for addon in pairs(disabled) do disabled[addon] = nil end
ns.Options.SwitchModuleAddon(qolMod, false)
Check(confirmText and confirmText:find("Quality of Life", 1, true), "switching Quality of Life off asks first")
confirmYes()
Check(disabled.NaowhForever_QoL, "confirming disables QoL")
disabled.NaowhForever_QoL = nil
missingAddOns.NaowhForever_QoL = true
local built = #frames
LoadWindow()
ns.OpenOptionsWindow(); Flush()
Check(Text("Open a Window") ~= nil, "with QoL not loaded, the window still opens on Home")
ns.OpenOptionsWindow("Interface > Top Bar"); Flush()
Check(Head("Quality of Life") and ModuleSwitch("Quality of Life")._get() == false and not Head("Top Bar"),
    "and its card stands in for the Top Bar on Interface > Top Bar")

-- A module that is off is still searched, from the generated index: a setting is found on the page
-- that will hold it, at the module's own card.
local input, lootNav
for i = built + 1, #frames do
    local f = frames[i]
    if f.text == "Search settings" then input = f.parent end
    if f.text == "Bags, Loot & Mail" and f.parent and f.parent.cat then lootNav = f.parent end
end
input:SetText("auto repair"); Flush()
Check(ns.SEARCH_INDEX ~= nil and indexLoads == 1, "the first search with a module off loads the index, once")
Check(Text("Bags, Loot & Mail / Loot") and Head("Quality of Life") and tonumber(lootNav.count.text) >= 1,
    "a match in a module that is off lands on the page that will hold it, at the module's card")
input:SetText("auto rpair"); Flush()
Check(tonumber(lootNav.count.text) >= 1, "a letter left out still finds the setting")
-- Enter on its setting opens that page; the page changed, so the game must measure it again.
local measured
methods.UpdateScrollChildRect = function(self) if self.child and Head("Quality of Life") then measured = true end end
input:SetText("auto repair"); Flush()
input.scripts.OnEnterPressed(input)
methods.UpdateScrollChildRect = nil
Check(measured and Text("Bags, Loot & Mail / Loot") and not ns.UI.SearchTyped(),
    "Enter on a setting of a module that is off opens its page and measures its scroll area again")
input:SetText(""); Flush()
Check(Text("Bags, Loot & Mail / Loot") and Head("Quality of Life"), "cleared, the page stays, the module's card on it")
missingAddOns.NaowhForever_QoL = nil
-- The window was built while QoL was not loaded (something opened it before QoL loaded): once QoL
-- has loaded, opening the window again draws its cards in place of its module card.
local function OnPage(name, pageKey)
    for i = built + 1, #frames do
        local row = frames[i].text == name and frames[i]:IsShown() and frames[i].parent
        if row and row.card and row.parent.pageKey == pageKey then return row end
    end
end
ns.ToggleOptionsWindow()
ns.OpenOptionsWindow("QoL/Interface"); Flush()
Check(OnPage("Top Bar", "Interface > Top Bar") and not OnPage("Quality of Life", "Interface > Top Bar"),
    "loaded after the window was built, QoL's own cards are back on their pages")

do
    ns.BuildProfileSettings = function(parent, y)
        return y - ns.Shared.Settings.Render(parent, "Profiles/Setups", function() end, ns.UI.Search.Narrowed("Profiles"))
    end
    input:SetText("onboarding"); Flush()
    local result
    for _, frame in ipairs(frames) do
        if frame.entry and frame.entry.label == "Onboarding" and frame:IsShown() then result = frame break end
    end
    Check(result ~= nil, "search offers a direct Onboarding result")
    Click(result)
    Check(not ns.UI.SearchTyped() and not result:IsShown(), "choosing a result clears search and closes the popup")
    Check(Text("Start") ~= nil, "carried setting results open the actual Profiles setting")
    input:SetText("clock"); Flush()
    input.scripts.OnArrowPressed(input, "DOWN")
    local selected
    for _, frame in ipairs(frames) do
        if frame.entry and frame:IsShown() and frame.fill and frame.fill:IsShown() then selected = frame break end
    end
    Check(selected and selected.index == 2, "Down selects the next search result")
    input.scripts.OnEditFocusLost(input)
    Check(not selected:IsShown(), "leaving search closes its popup")
    input.scripts.OnEditFocusGained(input)
    Check(selected:IsShown(), "refocusing search restores its results")
    input.scripts.OnEnterPressed(input)
    Check(not ns.UI.SearchTyped(), "Enter navigates to the selected result")
    input:SetText("zzzzzzzzzzzzzz"); Flush()
    Check(Text("No matching settings.") ~= nil, "an empty result list explains that nothing matched")
    input.scripts.OnEscapePressed(input)
    Check(not ns.UI.SearchTyped(), "Escape clears the search")
    ns.BuildProfileSettings = nil
    ns.MarkReloadRequired("Changed the skin")
    Check(Text("Reload UI *") ~= nil, "reload-required feedback persists in the window button")
    local reload = ns.ReloadButton(env.UIParent, "Reload UI", 110, 26)
    Check(reload.label.text == "Reload UI *" and reload._tipBody() == "Changed the skin",
        "new reload buttons inherit the pending reason")
    reload:Hide()
end

print(cases .. " navigation checks passed")
-- Available only to an offline renderer that loads this test environment.
local capture = rawget(_G, "NAVIGATION_CAPTURE")
if capture then capture(env, frames, ns, Flush) end
