-- Run with Lua 5.1 from the repository root: Shared/UI/GamepadNav.lua, Naowh's windows with the gamepad's buttons,
-- on stubs. With keyboard and mouse nothing is made. Under the Gamepad interface style the newest open Naowh window
-- holds the gamepad through a frame of Naowh's (the game's bindings untouched): the D-pad moves the focus to the
-- nearest target in line (a column, a row) or else that way. A selects (presses, opens a dropdown, moves from a side
-- panel into its page, picks a slider for left/right until A or B), B goes back or closes, X flips a switch, LB/RB
-- switch tabs, a scrolled list follows the focus, other buttons go on to the game, a fight hands the gamepad back,
-- and a legend of every button, the same everywhere, sits under the window's lower left. Actual menus share the
-- navigation lifecycle, including initial focus and reused rows.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end

local Frame
local made = {}

local function Visible(f)
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end

local function Fire(f, name)
    if not f.shown then return end
    if f.scripts[name] then f.scripts[name](f) end
    for _, c in ipairs(f.children) do Fire(c, name) end
end

local function Region(kind)
    local r = { kind = kind, shown = true, parent = false, scripts = {}, children = {}, x = 0, y = 0, w = 0, h = 0,
        alpha = 1 }
    function r:GetObjectType() return self.kind end
    function r:Show()
        if self.shown then return end
        local was = Visible(self.parent)
        self.shown = true
        if was then Fire(self, "OnShow") end
    end
    function r:Hide()
        if not self.shown then return end
        local was = Visible(self)
        self.shown = false
        if was then
            for _, c in ipairs(self.children) do Fire(c, "OnHide") end
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
    end
    function r:SetShown(on) if on then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:IsVisible() return Visible(self) end
    function r:SetScript(name, fn) self.scripts[name] = fn end
    function r:GetScript(name) return self.scripts[name] end
    function r:SetParent(p)
        if self.parent then
            for i, c in ipairs(self.parent.children) do
                if c == self then table.remove(self.parent.children, i) break end
            end
        end
        self.parent = p or false
        if p then p.children[#p.children + 1] = self end
    end
    function r:GetParent() return self.parent or nil end
    function r:GetChildren() return unpack(self.children) end
    function r:Place(x, y, w, h) self.x, self.y, self.w, self.h = x, y, w, h; return self end
    function r:GetLeft() return self.x end
    function r:GetBottom() return self.y end
    function r:GetTop() return self.y + self.h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetSize(w, h) self.sw, self.sh = w, h end
    function r:GetEffectiveScale() return 1 end
    function r:GetAlpha() return self.alpha end
    function r:IsEnabled() return self.enabled ~= false end
    function r:IsMouseEnabled() return self.mouse ~= false end
    function r:IsProtected() return self.protected == true end
    function r:GetFrameLevel() return 1 end
    function r:SetPoint(...) self.point = { ... } end
    function r:ClearAllPoints() self.point = nil end
    function r:SetText(t) self.text = t end
    function r:GetStringWidth() return #(rawget(self, "text") or "") * 6 end
    function r:SetAtlas(a) self.atlas = a end
    function r:SetPropagateKeyboardInput(on) self.propagate = on end
    function r:EnableGamePadButton(on) self.pads = on end
    function r:RegisterEvent(e) self.events = rawget(self, "events") or {}; self.events[e] = true end
    function r:Click(button)
        self.clicked = (rawget(self, "clicked") or 0) + 1
        if self.scripts.OnClick then self.scripts.OnClick(self, button) end
    end
    function r:CreateTexture() return Region("Texture") end
    function r:CreateFontString() return Region("FontString") end
    function r:GetVerticalScroll() return rawget(self, "scroll") or 0 end
    function r:SetVerticalScroll(v) self.scroll = v end
    function r:GetVerticalScrollRange() return rawget(self, "range") or 0 end
    -- Methods the file calls that do nothing here; a field it reads (padClick, padSkip, ...) is nil.
    return setmetatable(r, { __index = function(_, k) if k:find("^%u") then return NOTHING end end })
end

local UIParent = Region("Frame")
local lockdown = false
local gamepad = false
local iconSets, padUtil

local env = setmetatable({
    UIParent = UIParent,
    InCombatLockdown = function() return lockdown end,
    GetCursorPosition = function() return 0, 0 end,
    CreateFrame = function(kind, _, parent)
        local f = Region(kind)
        made[#made + 1] = { frame = f, parent = parent }
        return f
    end,
}, { __index = function(_, k)
    if k == "InputIconTextureSetUtility" then return iconSets end
    if k == "GamepadSharedUtility" then return padUtil end
    if k == "InputIconTextureState" then return iconSets and { Normal = 1 } end
    return _G[k]
end })

local T = { bg = {}, fg = {}, muted = {}, accent = {} }
local ns = {
    THEME = T, L = function(s) return s end,
    GamepadStandDown = function() return gamepad end,
    Font = function(parent) return parent:CreateFontString() end,
    Solid = function(parent) return parent:CreateTexture() end,
    Border = function() return { SetColor = NOTHING } end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { Shadow = NOTHING } },
}
env._G = { NaowhForever = ns }
local chunk = assert(loadfile("Shared/UI/GamepadNav.lua"))
setfenv(chunk, env)
chunk()

Frame = function(kind, parent, x, y, w, h)
    local f = Region(kind)
    f:SetParent(parent)
    return f:Place(x or 0, y or 0, w or 0, h or 0)
end

local function Button(parent, x, y, onClick)
    local b = Frame("Button", parent, x, y, 100, 20)
    b:SetScript("OnClick", onClick or NOTHING)
    return b
end

-- Keyboard and mouse: nothing.
local win = Frame("Frame", UIParent, 0, 0, 400, 300)
win:Hide()
ns.PadWindow(win)
check("nothing is made with keyboard and mouse", #made == 0 and ns.PadFocus() == nil)

-- Under the Gamepad interface style.
gamepad = true
local log = {}
local logo = Button(win, 10, 270)
local a = Button(win, 10, 200, function() log[#log + 1] = "a" end)
local b = Button(win, 150, 200)
local c = Button(win, 10, 150)
local d = Button(win, 160, 100)
local hidden = Button(win, 10, 120); hidden:Hide()
local off = Button(win, 10, 110); off.enabled = false
local faded = Button(win, 10, 105); faded.alpha = 0
local skipped = Button(win, 10, 101); skipped.padSkip = true
local dimmed = Button(win, 10, 103); dimmed.mouse = false
local secure = Button(win, 10, 102); secure.protected = true
Frame("Frame", win, 10, 50, 100, 20)
ns.PadWindow(win, { header = 52 })
for _, m in ipairs(made) do check("every frame of Naowh's is made parentless", m.parent == nil) end
check("registering makes only the watcher while the window is closed", #made == 1 and ns.PadFocus() == nil)

win:Show()
local input
for _, m in ipairs(made) do
    if m.frame.scripts.OnGamePadButtonDown then input = m.frame end
end
check("an open window holds the gamepad through a frame of Naowh's", input and input:IsShown() and input.pads == true)
check("the focus starts on the first target under the title bar", ns.PadFocus() == a and ns.PadFocus() ~= logo)

local function Press(key)
    input.scripts.OnGamePadButtonDown(input, key)
    input.scripts.OnGamePadButtonUp(input, key)
end

Press("PADDRIGHT")
check("right goes to the nearest target that way", ns.PadFocus() == b)
check("a pressed button of the window stays Naowh's", input.propagate == false)
Press("PADDDOWN")
check("down prefers the target nearest the line", ns.PadFocus() == d)
Press("PADDUP"); Press("PADDLEFT")
check("up and left come back", ns.PadFocus() == a)
Press("PADDDOWN")
check("hidden, disabled, dimmed, faded, skipped and secure widgets and plain frames are not targets", ns.PadFocus() == c)
Press("PADDDOWN")
check("down past the last target moves on to the one beside it", ns.PadFocus() == d)
Press("PADDLEFT")
check("left skips a target further off the line than that way", ns.PadFocus() == c)
Press("PADDUP")
check("back at the first", ns.PadFocus() == a)
Press("PAD3")
check("X leaves a plain button alone", #log == 0)
Press("PAD1")
check("A presses it", log[1] == "a" and a.clicked == 1)
input.scripts.OnGamePadButtonDown(input, "PADRTRIGGER")
check("any other button goes on to the game", input.propagate == true)
check("nothing to say for a button that never pressed in the window",
    (function() input.scripts.OnGamePadButtonUp(input, "PADRTRIGGER"); return input.propagate == true end)())

-- The legend: under the window's lower left, the game's icons, or the button's short name without them.
local legend
for _, m in ipairs(made) do
    if m.frame.labels then legend = m.frame end
end
check("the legend hangs under the window's lower left", legend and legend.parent == win and legend:IsShown()
    and legend.point[1] == "TOPLEFT" and legend.point[2] == win and legend.point[3] == "BOTTOMLEFT")
local function Says(text)
    for _, l in ipairs(legend.labels) do
        if l.shown and l.text == text then return true end
    end
    return false
end
local function Static()
    return Says("Move") and Says("Select") and Says("Back") and Says("Toggle") and Says("Tabs")
end
check("the legend names every button the window reads", Static())
check("without the game's icons a button shows its short name", legend.icons[2].text.text == "A")
iconSets = { GetActiveInputIconButtonTextures = function(key) return { "icon-" .. key } end }
Press("PADDDOWN")
check("with them it shows the gamepad's own icon", legend.icons[2].atlas == "icon-PAD1" and legend.icons[2].shown)

-- A dropdown (padClick) and a slider (padStep).
local opened = 0
local drop = Frame("Button", win, 150, 150, 80, 20)
drop.padClick = function() opened = opened + 1 end
local steps = {}
local slider = Frame("Frame", win, 150, 125, 80, 20)
slider.padStep = function(_, dir) steps[#steps + 1] = dir end
Press("PADDRIGHT")
check("a dropdown is a target", ns.PadFocus() == drop)
Press("PAD3")
check("X leaves a dropdown alone", opened == 0)
Press("PAD1")
check("A opens a dropdown through its padClick", opened == 1)
Press("PADDDOWN")
check("a slider is a target", ns.PadFocus() == slider)
Press("PADDRIGHT")
check("left and right pass a slider by until A picks it", #steps == 0 and ns.PadFocus() ~= slider)
Press("PADDLEFT")
Press("PAD1")
check("A picks the slider, the legend stays the same", ns.PadFocus() == slider and Static())
Press("PADDLEFT"); Press("PADDRIGHT"); Press("PADDUP")
check("then left and right step it, and up stays on it", steps[1] == -1 and steps[2] == 1 and ns.PadFocus() == slider)
Press("PAD2")
check("B lets it go, and keeps the window open", win:IsShown())
Press("PADDRIGHT")
check("left and right move on again", #steps == 2)
Press("PADDLEFT")

-- X flips a switch: a switch's own, or the one a row carries; the switch itself is no stop then.
local flips = 0
local head = Button(win, 10, 30)
local switch = Button(head, 300, 30, function() flips = flips + 1 end)
switch.padSkip = true
head.padToggle = switch
local folded = 0
head:SetScript("OnClick", function() folded = folded + 1 end)
local plain = Button(win, 10, 5, function() flips = flips + 10 end)
plain.padToggle = plain
local function Visit(target)
    for _ = 1, 12 do
        if ns.PadFocus() == target then return true end
        Press("PADDDOWN")
    end
end
check("down reaches a row with a switch", Visit(head))
Press("PAD3")
check("X flips the row's switch", flips == 1 and folded == 0)
Press("PAD1")
check("A folds the card, the switch stays", folded == 1 and flips == 1)
switch.mouse = false
Press("PAD3")
check("X leaves a switch the card holds", flips == 1)
switch.mouse = nil
check("the row's switch is no stop of its own", (function()
    Press("PADDRIGHT"); return ns.PadFocus() ~= switch
end)())
check("down reaches a switch", Visit(plain))
Press("PAD3")
check("X flips a switch", flips == 11)
head:Hide(); plain:Hide()
Press("PADDUP")

-- Columns: up and down keep to a column, left and right cross to the next.
local colWin = Frame("Frame", UIParent, 0, 0, 400, 400)
colWin:Hide()
local l1, l2 = Button(colWin, 10, 300), Button(colWin, 10, 250)
local r1, r2 = Button(colWin, 200, 290), Button(colWin, 200, 240)
local stray = Button(colWin, 120, 275)
stray.w = 20
ns.PadWindow(colWin)
colWin:Show()
check("a new window starts top left", ns.PadFocus() == l1)
Press("PADDDOWN")
check("down keeps to the column", ns.PadFocus() == l2)
Press("PADDRIGHT")
check("right crosses to the next column's row", ns.PadFocus() == r2)
Press("PADDUP")
check("up keeps to that column", ns.PadFocus() == r1)
colWin:Hide()
stray:Hide()

-- A side panel: the focus starts there, A opens a page and moves into it, B comes back, B again closes.
local navWin = Frame("Frame", UIParent, 0, 0, 600, 400)
navWin:Hide()
local side = Frame("Frame", navWin, 0, 0, 150, 400)
local page1, page2 = Button(side, 10, 350), Button(side, 10, 320)
local shown = "page1"
page1:SetScript("OnClick", function() shown = "page1" end)
page2:SetScript("OnClick", function() shown = "page2" end)
local topBar = Button(navWin, 500, 380)
local pageArea = Frame("Frame", navWin, 150, 0, 450, 360)
local body1 = Button(pageArea, 200, 350)
local body2 = Button(pageArea, 200, 300)
ns.PadWindow(navWin, { nav = side, navFocus = function() return shown == "page1" and page1 or page2 end,
    content = pageArea })
navWin:Show()
check("the focus starts on the side panel's page", ns.PadFocus() == page1)
Press("PADDRIGHT")
check("right does not leave the side panel", ns.PadFocus() == page1)
Press("PADDDOWN"); Press("PAD1")
check("A opens the page and moves into its first control, not the bar above it", shown == "page2"
    and ns.PadFocus() == body1)
Press("PADDUP")
check("the bar above is a press up away", ns.PadFocus() == topBar)
Press("PADDDOWN")
Press("PADDDOWN"); Press("PADDLEFT")
check("in the page the focus keeps to it", ns.PadFocus() == body2)
Press("PAD2")
check("B comes back to the side panel, on the page shown", ns.PadFocus() == page2 and navWin:IsShown())
local strip = Frame("Frame", pageArea, 160, 370, 300, 20)
strip.padTabs, strip.buttons, strip.shown = true, {}, "b"
for i, key in ipairs({ "a", "b" }) do
    strip.buttons[i] = Button(strip, 100 + i * 100, 370)
    strip.buttons[i].key = key
end
Press("PAD1")
check("A from the side panel lands on the page's tab shown", ns.PadFocus() == strip.buttons[2])
Press("PAD2")
Press("PAD2")
check("B on the side panel closes the window", not navWin:IsShown())

-- Tabs.
local bar = Frame("Frame", win, 10, 240, 300, 20)
bar.padTabs = true
bar.buttons = {}
local picked
for i, key in ipairs({ "one", "two", "three" }) do
    local t = Button(bar, i * 90, 240, function(self) picked = self.key; bar.shown = self.key end)
    t.key = key
    bar.buttons[i] = t
end
bar.shown = "two"
Press("PADRSHOULDER")
check("RB picks the next tab", picked == "three")
Press("PADRSHOULDER")
check("RB on the last tab stays", picked == "three")
Press("PADLSHOULDER")
check("LB picks the one before", picked == "two")
check("and the focus moves onto the tab shown", ns.PadFocus() == bar.buttons[2])

-- A scrolled list follows the focus.
local scroll = Frame("ScrollFrame", win, 0, 0, 400, 80)
scroll.range = 500
local child = Frame("Frame", scroll, 0, -200, 400, 280)
local deep = Button(child, 10, -40)
Press("PADDDOWN"); Press("PADDDOWN"); Press("PADDDOWN"); Press("PADDDOWN"); Press("PADDDOWN")
check("down reaches a target scrolled out of view", ns.PadFocus() == deep)
check("and the list scrolls it into view", scroll:GetVerticalScroll() > 40)

-- A second window: the newest holds the gamepad, the first gets it back with its focus.
local second = Frame("Frame", UIParent, 500, 0, 200, 200)
second:Hide()
local inner = Button(second, 520, 100)
local closedBy
ns.PadWindow(second, { back = function() closedBy = "back"; second:Hide() end })
local before = ns.PadFocus()
second:Show()
check("the newest window holds the gamepad", ns.PadFocus() == inner)
check("the legend follows it", legend.parent == second and Static())
Press("PAD2")
check("B runs the window's back", closedBy == "back" and not second:IsShown())
check("the window under it gets the gamepad back, focus kept", ns.PadFocus() == before and legend.parent == win)

-- A fight: the gamepad goes back to the game before the lockdown, and comes back after.
input.scripts.OnEvent(input, "PLAYER_REGEN_DISABLED")
check("a fight hands the gamepad back", not input:IsShown() and input.pads == false and ns.PadFocus() == nil)
lockdown = true
second:Show()
check("nothing is taken in a fight", not input:IsShown())
second:Hide()
lockdown = false
input.scripts.OnEvent(input, "PLAYER_REGEN_ENABLED")
check("after it, the open window takes the gamepad again", input:IsShown() and input.pads == true
    and ns.PadFocus() == before)
lockdown = true
input.scripts.OnEvent(input, "PLAYER_REGEN_DISABLED")
check("a fight that is already locked down still hands the gamepad back", not input:IsShown())
lockdown = false
input.scripts.OnEvent(input, "PLAYER_REGEN_ENABLED")

-- The game's own prompts (popups, ready checks) bind the gamepad's buttons through its binding stack: one that
-- shows after the window gets them, one that was there before it does not.
local older, prompt = {}, {}
padUtil = { InputBindingManager = { bindingSetStack = { older } } }
win:Hide()
win:Show()
local stack = padUtil.InputBindingManager.bindingSetStack
local at = ns.PadFocus()
Press("PADDDOWN")
check("a binding set of the game's from before the window leaves the buttons to it", ns.PadFocus() ~= at)
stack[2] = prompt
at = ns.PadFocus()
input.scripts.OnGamePadButtonDown(input, "PADDDOWN")
check("a prompt of the game's shown over the window gets the buttons", input.propagate == true and ns.PadFocus() == at)
input.scripts.OnGamePadButtonUp(input, "PADDDOWN")
stack[2] = { treatBindsAsCore = true }
Press("PADDUP")
check("a set the game treats as core does not", ns.PadFocus() ~= at)
stack[2] = nil
at = ns.PadFocus()
Press("PADDDOWN")
check("once the prompt closes the window has them again", ns.PadFocus() ~= at and input.propagate == false)
padUtil = nil

local pressed, pressFocus = ns.PadFocus(), nil
local onClick = pressed:GetScript("OnClick")
pressed:SetScript("OnClick", function() pressFocus = ns.PadPressFocus() end)
Press("PAD1")
pressed:SetScript("OnClick", onClick)
check("while A is pressed the focus is the press's, for a menu it opens", pressFocus == pressed)
check("and only then", ns.PadPressFocus() == nil and ns.PadFocus() == pressed)

-- B on a plain window closes it, and the game has the gamepad again.
Press("PAD2")
check("B closes the window", not win:IsShown())
check("with no window open the frame lets go", not input:IsShown() and input.pads == false and ns.PadFocus() == nil)

-- Menus are filled before their OnShow gives the gamepad to their selected row, even when rows are reused.
env.GameTooltip = Region("GameTooltip")
ns.Hairline = NOTHING
ns.Shared.Parts.Arrow = function(parent) return parent:CreateTexture() end
local menus = assert(loadfile("Shared/UI/Menus.lua"))
setfenv(menus, env)
menus()
local menuWindow = Frame("Frame", UIParent, 0, 0, 400, 300)
local owner = Button(menuWindow, 10, 200)
ns.PadWindow(menuWindow)
local chosen
local function OpenChoices(first, other, selected)
    return ns.ContextMenu(owner, function(_, root)
        for _, name in ipairs({ first, other }) do
            root:CreateRadio(name, function(value) return value == selected end,
                function(value) chosen = value end, name)
        end
    end)
end
local menuHandle = OpenChoices("A", "B", "B")
check("a newly opened menu immediately focuses its selected option",
    ns.PadFocus() and ns.PadFocus().element.text == "B")
menuHandle:Close()
check("closing a menu restores the owning window's focus", ns.PadFocus() == owner)
OpenChoices("C", "D", "C")
check("reopening a menu focuses the new selection, not the previous row",
    ns.PadFocus() and ns.PadFocus().element.text == "C")
Press("PAD1")
check("A selects the current menu's selected choice and closes it", chosen == "C" and ns.PadFocus() == owner)
menuWindow:Hide()

print(("test-gamepad-nav: %d checks passed"):format(checks))
