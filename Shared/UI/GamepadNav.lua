-- GamepadNav.lua: Naowh's windows with the gamepad's buttons under the Gamepad interface style (ns.PadWindow, ns.PadFocus): the newest open window reads them through a frame of Naowh's, with a focus ring and a button legend under its lower left.
local ns = _G.NaowhForever
local T = ns.THEME
local St = ns.Shared.Style

local NAV_KEYS = {
    PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true,
    PAD1 = true, PAD2 = true, PAD3 = true, PADLSHOULDER = true, PADRSHOULDER = true,
}
local REPEATS = { PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true }
local REPEAT_WAIT, REPEAT_EVERY = 0.35, 0.08
local OFF_LINE = 2
local MIN_STEP = 1
local MIN_ALPHA = 0.05
local RING_OUT = 2
local REVEAL_PAD = 8
local LEGEND_GAP, LEGEND_PAD, LEGEND_ICON, LEGEND_SPACE, LEGEND_INNER = 6, 10, 24, 18, 6
local LEGEND_TEXT = 13
local LEGEND_H = LEGEND_ICON + 2 * LEGEND_PAD
local STRATA = "FULLSCREEN_DIALOG"
local HINTS = {
    { keys = { "DIRPAD" }, text = ns.L("Move") },
    { keys = { "PAD1" }, text = ns.L("Select") },
    { keys = { "PAD2" }, text = ns.L("Back") },
    { keys = { "PAD3" }, text = ns.L("Toggle") },
    { keys = { "PADLSHOULDER", "PADRSHOULDER" }, text = ns.L("Tabs") },
}
local KEY_TEXT = {
    DIRPAD = "+", PAD1 = "A", PAD2 = "B", PAD3 = "X", PADLSHOULDER = "LB",
    PADRSHOULDER = "RB",
}

local specs = setmetatable({}, { __mode = "k" })
local stack = {}
local held, input, ring, legend, fighting, pressing
local eaten, repeatKey, repeatWait = {}, nil, 0

local function Fighting()
    return fighting or InCombatLockdown()
end

local function BindingSets()
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    return manager and manager.bindingSetStack
end

local function Snapshot()
    local seen = {}
    local sets = BindingSets()
    if sets then
        for _, set in ipairs(sets) do seen[set] = true end
    end
    return seen
end

local function GamePrompt(e)
    local sets = BindingSets()
    local top = sets and sets[#sets]
    return top ~= nil and not top.treatBindsAsCore and not e.sets[top]
end

local function Propagate(on)
    if input and not Fighting() then input:SetPropagateKeyboardInput(on) end
end

local function EntryOf(frame)
    for i, e in ipairs(stack) do
        if e.frame == frame then return e, i end
    end
end

local function Target(f)
    if f:IsProtected() then return false end
    if f.padClick or f.padStep then return true end
    local kind = f:GetObjectType()
    if kind ~= "Button" and kind ~= "CheckButton" then return false end
    return f:GetScript("OnClick") ~= nil
end

local function Usable(f)
    if not f:IsVisible() or not f:IsMouseEnabled() or (f:GetAlpha() or 1) <= MIN_ALPHA then return false end
    return not f.IsEnabled or f:IsEnabled()
end

local function CollectFrom(out, ...)
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        if f:IsShown() and not f.padSkip then
            if Target(f) and Usable(f) then out[#out + 1] = f end
            CollectFrom(out, f:GetChildren())
        end
    end
end

local function Within(f, frame)
    while f do
        if f == frame then return true end
        f = f:GetParent()
    end
    return false
end

local function Targets(e)
    local out = {}
    CollectFrom(out, e.frame:GetChildren())
    local nav = e.spec.nav
    if not nav then return out end
    local kept = {}
    for _, f in ipairs(out) do
        if Within(f, nav) == e.inNav then kept[#kept + 1] = f end
    end
    return kept
end

local function Rect(f)
    local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
    if not (l and b and w and h) then return nil end
    local s = f:GetEffectiveScale()
    return l * s, b * s, w * s, h * s
end

local function Contains(list, f)
    for _, g in ipairs(list) do
        if g == f then return true end
    end
    return false
end

local function Nearest(list, cur, dx, dy)
    local l, b, w, h = Rect(cur)
    if not l then return nil end
    local cx, cy = l + w / 2, b + h / 2
    local inLine, inLineAlong, best, bestScore, far, farScore
    for _, o in ipairs(list) do
        local ol, ob, ow, oh = Rect(o)
        if o ~= cur and ol then
            local ox, oy = ol + ow / 2, ob + oh / 2
            local along, off
            if dy ~= 0 then
                along = dy > 0 and oy - cy or cy - oy
                off = math.max(0, math.max(l, ol) - math.min(l + w, ol + ow))
            else
                along = dx > 0 and ox - cx or cx - ox
                off = math.max(0, math.max(b, ob) - math.min(b + h, ob + oh))
            end
            if along > MIN_STEP and off == 0 then
                if not inLineAlong or along < inLineAlong then inLine, inLineAlong = o, along end
            elseif along > MIN_STEP then
                local score = along + off * OFF_LINE
                if along >= off then
                    if not bestScore or score < bestScore then best, bestScore = o, score end
                elseif not farScore or score < farScore then
                    far, farScore = o, score
                end
            end
        end
    end
    return inLine or best or far
end

local function TabBar(frame)
    for _, f in ipairs({ frame:GetChildren() }) do
        if f:IsVisible() then
            if f.padTabs then return f end
            local bar = TabBar(f)
            if bar then return bar end
        end
    end
end

local function ShownTab(frame)
    local bar = TabBar(frame)
    if not bar then return nil end
    local first
    for _, b in ipairs(bar.buttons) do
        if b:IsShown() then
            if b.key == bar.shown then return b end
            first = first or b
        end
    end
    return first
end

local function First(e, list)
    if e.inNav and e.spec.navFocus then
        local pick = e.spec.navFocus()
        if pick and Contains(list, pick) then return pick end
    end
    if e.spec.initial then
        local pick = e.spec.initial(list)
        if pick then return pick end
    end
    local tab = not e.inNav and ShownTab(e.frame)
    if tab and Contains(list, tab) then return tab end
    local content = not e.inNav and e.spec.content
    if content then
        local inside = {}
        for _, f in ipairs(list) do
            if Within(f, content) then inside[#inside + 1] = f end
        end
        if #inside > 0 then list = inside end
    end
    local top = e.spec.header and e.frame:GetTop()
    local below = top and (top - e.spec.header) * e.frame:GetEffectiveScale()
    local best, bestTop, bestLeft
    for pass = 1, 2 do
        for _, f in ipairs(list) do
            local l, b, _, h = Rect(f)
            if l and (pass == 2 or not below or b + h <= below) then
                local t = b + h
                if not best or t > bestTop + MIN_STEP or (math.abs(t - bestTop) <= MIN_STEP and l < bestLeft) then
                    best, bestTop, bestLeft = f, t, l
                end
            end
        end
        if best then return best end
    end
end

local function Reveal(f)
    local p = f:GetParent()
    while p do
        if p:GetObjectType() == "ScrollFrame" then
            local top, bottom, st, sb = f:GetTop(), f:GetBottom(), p:GetTop(), p:GetBottom()
            if top and st then
                local at, range = p:GetVerticalScroll(), p:GetVerticalScrollRange()
                if top > st then
                    at = at - (top - st) - REVEAL_PAD
                elseif bottom < sb then
                    at = at + (sb - bottom) + REVEAL_PAD
                end
                at = math.max(0, math.min(range, at))
                if p._gliding then p._glideTo = at end
                p:SetVerticalScroll(at)
            end
        end
        p = p:GetParent()
    end
end

local function Script(f, name)
    local fn = f and f:GetScript(name)
    if fn then fn(f, false) end
end

local Paint

local function Focus(e, f)
    if e.focus == f then return end
    if e.focus and e.focus:IsVisible() then Script(e.focus, "OnLeave") end
    e.focus = f
    if f then
        Reveal(f)
        Script(f, "OnEnter")
    end
end

local function Validate(e)
    local list = Targets(e)
    if not (e.focus and Contains(list, e.focus)) then
        e.focus = nil
        Focus(e, First(e, list))
    end
    return list
end

local function StepTab(e, dir)
    local bar = TabBar(e.frame)
    if not bar then return end
    local shown, at = {}, nil
    for _, b in ipairs(bar.buttons) do
        if b:IsShown() then
            shown[#shown + 1] = b
            if b.key == bar.shown then at = #shown end
        end
    end
    local pick = shown[(at or 0) + dir]
    if pick then
        pick:Click("LeftButton")
        e.focus = nil
    end
end

local function Activate(f)
    if not f then return end
    if f.padClick then return f.padClick(f) end
    if f.Click then f:Click("LeftButton") end
end

local function Switch(f)
    local t = f and f.padToggle
    if t and Usable(t) then return t end
end

local function Back(e)
    if e.spec.back then return e.spec.back() end
    e.frame:Hide()
end

local function Adjusting(e, key, f)
    if key == "PADDLEFT" or key == "PADDRIGHT" then
        f.padStep(f, key == "PADDLEFT" and -1 or 1)
    elseif key == "PAD1" or key == "PAD2" then
        e.adjusting = nil
    end
end

local function SwitchArea(e, inNav)
    Focus(e, nil)
    e.inNav = inNav
end

local function Press(key)
    local e = held
    if not e then return end
    local list = Validate(e)
    local f = e.focus
    if e.adjusting and e.adjusting ~= f then e.adjusting = nil end
    if e.adjusting then
        Adjusting(e, key, f)
    elseif key == "PADDUP" or key == "PADDDOWN" then
        if f then Focus(e, Nearest(list, f, 0, key == "PADDUP" and 1 or -1) or f) end
    elseif key == "PADDLEFT" or key == "PADDRIGHT" then
        if f then Focus(e, Nearest(list, f, key == "PADDLEFT" and -1 or 1, 0) or f) end
    elseif key == "PAD1" then
        if f and f.padStep then
            e.adjusting = f
        else
            Activate(f)
            if e.inNav and held == e then SwitchArea(e, false) end
        end
    elseif key == "PAD2" then
        if e.spec.nav and not e.inNav then SwitchArea(e, true) else Back(e) end
    elseif key == "PAD3" then
        Activate(Switch(f))
    elseif not e.inNav then
        StepTab(e, key == "PADLSHOULDER" and -1 or 1)
    end
    if held == e then
        Validate(e)
        Paint(e)
    end
end

local function OnUpdate(_, elapsed)
    if not repeatKey then return end
    repeatWait = repeatWait - elapsed
    if repeatWait > 0 then return end
    repeatWait = REPEAT_EVERY
    Press(repeatKey)
end

local function StopRepeat()
    repeatKey = nil
    if input then input:SetScript("OnUpdate", nil) end
end

local function OnButtonDown(_, key)
    if not held or not NAV_KEYS[key] or Fighting() or GamePrompt(held) then return Propagate(true) end
    Propagate(false)
    eaten[key] = true
    if REPEATS[key] then
        repeatKey, repeatWait = key, REPEAT_WAIT
        input:SetScript("OnUpdate", OnUpdate)
    end
    pressing = true
    Press(key)
    pressing = false
    Propagate(false)
end

local function OnButtonUp(_, key)
    if not eaten[key] then return Propagate(true) end
    eaten[key] = nil
    if repeatKey == key then StopRepeat() end
    Propagate(false)
end

local Refresh

local function OnEvent(_, event)
    fighting = event == "PLAYER_REGEN_DISABLED"
    Refresh()
end

local function Input()
    if input then return input end
    input = CreateFrame("Frame")
    input:SetParent(UIParent)
    input:SetAllPoints(UIParent)
    input:SetFrameStrata(STRATA)
    input:SetScript("OnGamePadButtonDown", OnButtonDown)
    input:SetScript("OnGamePadButtonUp", OnButtonUp)
    input:SetScript("OnEvent", OnEvent)
    input:RegisterEvent("PLAYER_REGEN_DISABLED")
    input:RegisterEvent("PLAYER_REGEN_ENABLED")
    input:Hide()
    return input
end

local function Pads(on)
    if input.EnableGamePadButton then input:EnableGamePadButton(on) end
end

local function Ring()
    if ring then return ring end
    ring = CreateFrame("Frame")
    ring.edge = ns.Border(ring, T.accent)
    ring:Hide()
    return ring
end

local function Atlas(key)
    local U, S = InputIconTextureSetUtility, InputIconTextureState
    if not (U and U.GetActiveInputIconButtonTextures and S) then return nil end
    local set = U.GetActiveInputIconButtonTextures(key)
    return type(set) == "table" and set[S.Normal] or nil
end

local function Legend()
    if legend then return legend end
    legend = CreateFrame("Frame")
    legend:SetClampedToScreen(true)
    local Parts = ns.Shared.Parts
    if ns.foreverSkin then
        Parts.Backdrop(legend):Paint(1)
    else
        ns.Solid(legend, "BACKGROUND", T.bg, 1):SetAllPoints()
    end
    Parts.Shadow(legend)
    legend.edge = ns.Border(legend, St.BORDER_RGB)
    legend.icons, legend.labels = {}, {}
    legend:Hide()
    return legend
end

local function LegendIcon(i)
    local icon = legend.icons[i]
    if icon then return icon end
    icon = legend:CreateTexture(nil, "ARTWORK")
    icon:SetSize(LEGEND_ICON, LEGEND_ICON)
    icon.text = ns.Font(legend, LEGEND_TEXT, nil, T.fg, true)
    legend.icons[i] = icon
    return icon
end

local function LegendLabel(i)
    local label = legend.labels[i]
    if label then return label end
    label = ns.Font(legend, LEGEND_TEXT, nil, ns.foreverSkin and T.accent or T.fg)
    legend.labels[i] = label
    return label
end

local function PlaceKey(icon, key, x)
    icon:ClearAllPoints()
    icon.text:ClearAllPoints()
    local atlas = Atlas(key)
    if atlas then
        icon:SetAtlas(atlas)
        icon:SetPoint("LEFT", legend, "LEFT", x, 0)
        icon:Show()
        icon.text:Hide()
        return x + LEGEND_ICON
    end
    icon:Hide()
    icon.text:SetText(KEY_TEXT[key] or key)
    icon.text:SetPoint("LEFT", legend, "LEFT", x, 0)
    icon.text:Show()
    return x + math.ceil(icon.text:GetStringWidth())
end

local function PaintLegend(e)
    Legend()
    legend:SetParent(e.frame)
    legend:SetFrameStrata(STRATA)
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", e.frame, "BOTTOMLEFT", 0, -LEGEND_GAP)
    local x, icons, labels = LEGEND_PAD, 0, 0
    for _, hint in ipairs(HINTS) do
        for _, key in ipairs(hint.keys) do
            icons = icons + 1
            x = PlaceKey(LegendIcon(icons), key, x) + LEGEND_INNER
        end
        labels = labels + 1
        local label = LegendLabel(labels)
        label:ClearAllPoints()
        label:SetPoint("LEFT", legend, "LEFT", x, 0)
        label:SetText(hint.text)
        label:Show()
        x = x + math.ceil(label:GetStringWidth()) + LEGEND_SPACE
    end
    for i = icons + 1, #legend.icons do
        legend.icons[i]:Hide()
        legend.icons[i].text:Hide()
    end
    for i = labels + 1, #legend.labels do legend.labels[i]:Hide() end
    legend:SetSize(x - LEGEND_SPACE + LEGEND_PAD, LEGEND_H)
    legend:Show()
end

function Paint(e)
    local f = e.focus
    Ring()
    if f then
        ring:SetParent(f)
        ring:SetFrameLevel(f:GetFrameLevel() + 1)
        ring:ClearAllPoints()
        ring:SetPoint("TOPLEFT", f, "TOPLEFT", -RING_OUT, RING_OUT)
        ring:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", RING_OUT, -RING_OUT)
        local c = e.adjusting and T.fg or T.accent
        ring.edge:SetColor(c.r, c.g, c.b, 1)
        ring:Show()
    else
        ring:Hide()
    end
    PaintLegend(e)
end

local function Unpaint()
    if ring then ring:Hide() end
    if legend then legend:Hide() end
end

local function Newest()
    for i = #stack, 1, -1 do
        if stack[i].frame:IsVisible() then return stack[i] end
    end
end

function Refresh()
    local top = not Fighting() and Newest() or nil
    if held and held ~= top then
        if held.focus and held.focus:IsVisible() then Script(held.focus, "OnLeave") end
        Unpaint()
    end
    local was = held
    held = top
    if not top then
        StopRepeat()
        eaten = {}
        if input and input:IsShown() then
            if not InCombatLockdown() then Pads(false) end
            input:Hide()
        end
        return
    end
    Input()
    if not input:IsShown() then
        eaten = {}
        input:Show()
        Pads(true)
        Propagate(true)
    end
    if was ~= top and top.focus and top.focus:IsVisible() then Script(top.focus, "OnEnter") end
    Validate(top)
    Paint(top)
end

local function Open(frame)
    Input()
    local e, i = EntryOf(frame)
    if e then table.remove(stack, i) end
    e = e or { frame = frame, spec = specs[frame], inNav = specs[frame].nav ~= nil }
    e.sets = Snapshot()
    stack[#stack + 1] = e
    Refresh()
end

local function Close(frame)
    local e, i = EntryOf(frame)
    if not e then return end
    table.remove(stack, i)
    if held == e then
        held = nil
        e.focus = nil
        Unpaint()
    end
    Refresh()
end

function ns.PadWindow(frame, spec)
    if not ns.GamepadStandDown() or specs[frame] then return end
    specs[frame] = spec or {}
    local watch = CreateFrame("Frame")
    watch:SetParent(frame)
    watch:SetScript("OnShow", function() Open(frame) end)
    watch:SetScript("OnHide", function() Close(frame) end)
    if frame:IsVisible() then Open(frame) end
end

function ns.PadFocus()
    return held and held.focus or nil
end

function ns.PadPressFocus()
    return pressing and ns.PadFocus() or nil
end
