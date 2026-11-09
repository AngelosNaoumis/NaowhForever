-- Top Bar text: the clock keeps its own font with no outline, the FPS / MS readout and the online
-- counts keep the outlined Addon Font, until Font, Outline or Clock Outline is picked; and the card's
-- rows in the standard groups. Its look (NaowhForever_QoL/TopBar/View/Look.lua) is loaded and the card's rows cut out
-- of NaowhForever_QoL/TopBar/UI/SettingsPage.lua, run on stubs. Run from the repo root.

-- The Top Bar's files as TopBar.xml lists them, read as one source.
local parts = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_QoL/TopBar/.*%.lua$")) do
    local f = assert(io.open(path, "rb"))
    parts[#parts + 1] = f:read("*a"):gsub("\r\n", "\n")
    f:close()
end
local source = table.concat(parts, "\n")
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Slice(a, b)
    local first = assert(source:find(a, 1, true), a)
    return source:sub(first, assert(source:find(b, first + #a, true), b) - 1)
end

local code = table.concat({
    "local S, Parts, UI, ns, Group, ResetLayout = ...",
    Slice("local ROWS = {", "\nif C_AddOns.DoesAddOnExist("),
    "return { ROWS = ROWS }",
}, "\n")

local defaults = {}
for key, value in source:match("UI%.ModuleSettings%(\"topBar\", (%b{})"):gmatch("(%w+) = (\"[^\"]*\")") do
    defaults[key] = loadstring("return " .. value)()
end
defaults.iconSize, defaults.sysSize, defaults.clockSize = 22, 13, 27
defaults.iconColor = { r = 1, g = 1, b = 1 }
defaults.clockColor = { r = 1, g = 1, b = 1 }
local settings = {}
local S = { Get = function(k) if settings[k] == nil then return defaults[k] end return settings[k] end }

local OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
    { "NONE", "", "OUTLINE", "THICKOUTLINE" } }
local Parts = { HUD_OUTLINES = OUTLINES }
function Parts.HudText(fs, shadow) fs.shadow = shadow; return fs end
function Parts.HudFlags(outline) return (outline == "NONE" or type(outline) ~= "string") and "" or outline end
function Parts.HudFont(fs, font, size, outline, background)
    fs:SetFont("path:" .. font, size, outline)
    fs.shadow = outline == "" and (background or "card") or false
    return fs
end
local UI = { FontPath = function(name) return "path:" .. name end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, UIFontPath = function() return "path:" end,
    ThemeTint = function() return { r = 0, g = 0, b = 0 } end }

local function Text()
    return {
        SetFont = function(self, path, size, flags) self.path, self.size, self.flags = path, size, flags; return true end,
        SetTextColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end,
    }
end
local function Button()
    local b = { icon = { SetSize = function() end, SetVertexColor = function() end }, badge = Text() }
    function b.SetSize() end
    function b.ClearAllPoints() end
    function b.SetPoint() end
    function b.Show() end
    return b
end

local chunk = assert(loadstring(code))
local api = chunk(S, Parts, UI, ns, function(name) return { group = name } end, function() end)

-- The real look and its constants, on the stubs above.
ns.TopBar = { Settings = S }
ns.Shared = { Style = {}, Parts = Parts }
ns.THEME = { accent = { r = 0, g = 0, b = 0 } }
ns.UI = UI
do
    local env = setmetatable({ NaowhForever = ns }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "NaowhForever_QoL/TopBar/Constants.lua", "NaowhForever_QoL/TopBar/View/Style.lua", "NaowhForever_QoL/TopBar/View/Look.lua" }) do
        local fileChunk = assert(loadfile(path))
        setfenv(fileChunk, env)
        fileChunk()
    end
end
local Look = ns.TopBar.Look
local clock, sys = Text(), Text()
local group = { SetSize = function() end }
local friends, journal = Button(), Button()
journal.badge = nil
local function Paint()
    Look.ClockFont(clock)
    Look.SystemFont(sys)
    Look.Row(group, { friends, journal }, 2)
end

Paint()
check("today's clock: its own font, no outline", clock.path == "path:Gotham Narrow Ultra" and clock.size == 27
    and clock.flags == "")
check("today's readout: the Addon Font, outlined, no shadow", sys.path == "path:" and sys.size == 13
    and sys.flags == "OUTLINE" and sys.shadow == false)
check("today's counts: the Addon Font at 10, outlined", friends.badge.path == "path:" and friends.badge.size == 10
    and friends.badge.flags == "OUTLINE" and friends.badge.shadow == false)

settings.font, settings.outline = "Expressway", "THICKOUTLINE"
Paint()
check("Font and Outline reach the readout", sys.path == "path:Expressway" and sys.flags == "THICKOUTLINE")
check("and the counts", friends.badge.path == "path:Expressway" and friends.badge.flags == "THICKOUTLINE")
check("not the clock", clock.path == "path:Gotham Narrow Ultra" and clock.flags == "" and clock.shadow == false)
settings.outline = ""
Paint()
check("Shadow: the HUD shadow on the readout and counts", sys.flags == "" and sys.shadow == "card"
    and friends.badge.shadow == "card")
settings.clockOutline, settings.sysSize = "OUTLINE", 16
Paint()
check("Clock Outline outlines the clock", clock.flags == "OUTLINE")
check("FPS / MS Size sizes the readout", sys.size == 16)
check("the clock is white by default", clock.r == 1 and clock.g == 1 and clock.b == 1)
settings.clockColor = { r = 1, g = 0.5, b = 0 }
Paint()
check("Clock Color colours the clock", clock.r == 1 and clock.g == 0.5 and clock.b == 0)
check("not the readout", sys.g == 0)

local rows, groupOf, groups, current = {}, {}, {}, nil
for _, row in ipairs(api.ROWS) do
    if row.group then
        current = row.group
        groups[#groups + 1] = current
    elseif row.key then
        rows[row.key], groupOf[row.key] = row, current
    end
end
check("the standard groups after its own", table.concat(groups, ", ")
    == "Clock, Buttons, FPS / MS, Size, Text, Background, Colors, Visibility")
check("Font, Outline and the clock's under Text", groupOf.font == "Text" and groupOf.outline == "Text"
    and groupOf.clockFont == "Text" and groupOf.clockSize == "Text" and groupOf.clockOutline == "Text"
    and groupOf.sysSize == "Text")
check("Outline is the shared choice", rows.outline.choice == OUTLINES)
check("Clock Outline is the shared choice too", rows.clockOutline.choice == OUTLINES)
check("Hide In Combat and the mouseover fade under Visibility", groupOf.hideInCombat == "Visibility"
    and groupOf.mouseover == "Visibility" and groupOf.mouseoverAlpha == "Visibility")
check("Clock Color under Colors, only with the clock", groupOf.clockColor == "Colors"
    and rows.clockColor.colour and rows.clockColor.needs == "showClock")
check("the defaults are today's look", defaults.font == "" and defaults.outline == "OUTLINE"
    and defaults.clockOutline == "NONE")

-- Without the clock: one row centred as a whole, the two sides a button's gap apart in one pill.
local function Box(w)
    local b = { w = w, points = {} }
    function b.GetWidth(self) return self.w end
    function b.SetWidth(self, v) self.w = v end
    function b.ClearAllPoints(self) self.points = {} end
    function b.SetPoint(self, point, _, _, x) self.points[point] = x end
    return b
end
local frame, left, right = Box(0), Box(60), Box(90)
local clockText = { GetStringWidth = function() return 70 end }
local features = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, }
do
    local env = setmetatable({ NaowhForever = features }, { __index = _G })
    env._G = env
    local fileChunk = assert(loadfile("Core/Features.lua"))
    setfenv(fileChunk, env)
    fileChunk()
end
check("the clock is off by default", features.FEATURES.topBar.showClock == false
    and source:find("enabled = F.enabled,%s+showClock = F.showClock,") ~= nil)
Look.Fit(frame, left, right, clockText, 2, 3)
check("no clock: the row is both sides and a button's gap, no clock-sized hole", frame.w == 2 * 14 + 60 + 4 + 90
    and left.points.LEFT == 14 and right.points.RIGHT == -14)
Look.Fit(frame, left, Box(1), clockText, 2, 0)
check("no clock, one side empty: that side alone, centred", frame.w == 2 * 14 + 60 and left.points.LEFT == 14)
settings.showClock = true
Look.Fit(frame, left, right, clockText, 2, 3)
check("with the clock: both sides the widest's width round it", frame.w == 2 * (14 + 90 + 22) + 78
    and left.points.LEFT == 14 + 90 - 60 and right.points.RIGHT == -14)
settings.showClock = nil
local function Seg()
    local s = { line = {}, points = {} }
    function s.SetColorTexture() end
    function s.ClearAllPoints(self) self.points = {} end
    function s.SetPoint(self, point, rel) self.points[point] = rel end
    function s.SetShown(self, on) self.shown = on end
    function s.line.SetShown(self, on) self.shown = on end
    return s
end
defaults.bgAlpha = 85
local segs = { Seg(), Seg(), Seg() }
Look.PaintPills(frame, segs, left, right, clockText, 2, 3)
check("no clock: one pill from the left buttons to the right ones", segs[1].shown == true
    and segs[1].points.BOTTOMRIGHT == right and segs[3].shown == false and not segs[2].shown)
settings.showClock = true
Look.PaintPills(frame, segs, left, right, clockText, 2, 3)
check("with the clock: a pill each side of it", segs[1].points.BOTTOMRIGHT == left and segs[3].shown == true
    and segs[2].shown == true)
settings.showClock = nil
check("Show Clock heads the Clock group, its settings wait on it", groupOf.showClock == "Clock"
    and rows.use24h.needs == "showClock" and rows.clockFont.needs == "showClock"
    and rows.clockSize.needs == "showClock" and rows.clockOutline.needs == "showClock")

-- The Forever skin: the bar's look, picked under Bar Style (Classic, today's bar, by default).
do
    local gold = { r = 1, g = 0.82, b = 0 }
    local fns = { L = ns.L, Upper = string.upper, Lower = string.lower, UIFontPath = ns.UIFontPath,
        ThemeTint = function() return { r = 0.1, g = 0.1, b = 0.1 } end, foreverSkin = true,
        Hairline = function() end }
    local fParts = setmetatable({}, { __index = Parts })
    local boxes = {}
    function fParts.ForeverContainer()
        local box = { points = {}, SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
            ClearAllPoints = function(self) self.points = {} end, SetShown = function(self, v) self.shown = v end,
            SetAlpha = function(self, a) self.alpha = a end }
        boxes[#boxes + 1] = box
        return box
    end
    function fParts.ForeverMicroButton(b) b.micro = true return true end
    function fParts.ShowForeverMicro(b, shown, size) b.microShown, b.microSize = shown, size end
    fns.TopBar = { Settings = S }
    fns.Shared = { Style = { FOREVER_MICRO = { tall = 82 / 64, pad = 5 } }, Parts = fParts }
    fns.THEME = { accent = gold }
    fns.UI = UI
    local env = setmetatable({ NaowhForever = fns }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "NaowhForever_QoL/TopBar/Constants.lua", "NaowhForever_QoL/TopBar/View/Style.lua",
        "NaowhForever_QoL/TopBar/View/Look.lua" }) do
        local fileChunk = assert(loadfile(path))
        setfenv(fileChunk, env)
        fileChunk()
    end
    local FLook = fns.TopBar.Look
    local function Tex()
        local t = { points = {}, alpha = 1 }
        function t.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
        function t.ClearAllPoints(self) self.points = {} end
        function t.SetShown(self, v) self.shown = v and true or false end
        function t.IsShown(self) return self.shown ~= false end
        function t.SetColorTexture(self, r, g, b, a) self.color = { r, g, b, a } end
        function t.SetAlpha(self, a) self.alpha = a end
        return t
    end
    local bar = { CreateTexture = function() return Tex() end }
    local pills = FLook.NewPills(bar)
    local lbtn, rbtn = Button(), Button()
    local function Anchored(w)
        local t = Tex()
        function t.GetStringWidth() return w end
        return t
    end
    local fclock, fsys, readout = Anchored(40), Anchored(0), Text()
    bar.sys = fsys
    function readout.SetText(self, v) self.text = v end
    function readout.GetStringWidth() return 90 end
    local function PaintAll()
        FLook.SystemFont(readout)
        FLook.Row(group, { lbtn, rbtn }, 2)
        FLook.PaintPills(bar, pills, {}, {}, fclock, 1, 1)
    end
    settings.look, settings.showClock = nil, true
    PaintAll()
    local classicH = FLook.BarHeight()
    check("Forever: Classic by default, today's bar: no containers built, no micro buttons", FLook.Kind() == "classic"
        and #boxes == 0 and not pills.whole and not pills[1].box and pills[1].alpha == 1 and not lbtn.micro)
    check("Classic: the theme-tinted pills, the skin's accent line, a white hover", pills[1].color[1] == 0.1
        and pills[1].line.color[1] == gold.r and select(3, FLook.Accent()) == gold.b
        and select(3, FLook.HoverColor()) == 1)
    settings.look = "framed"
    PaintAll()
    check("Framed: its buttons in the micro menu's buttons", FLook.Kind() == "framed"
        and lbtn.micro and lbtn.microShown and lbtn.microSize == FLook.BtnSize())
    check("Framed: one container round the whole bar, the dark pills stood down", pills.whole.shown
        and not pills[1].box.shown and pills[1].alpha == 0 and pills[2].line.alpha == 0)
    check("Framed: the container at Bar Opacity", pills.whole.alpha == S.Get("bgAlpha") / 100)
    settings.bgAlpha = 0
    PaintAll()
    check("Bar Opacity at 0: the container gone too", pills.whole.alpha == 0 and pills[1].box.alpha == 0)
    settings.bgAlpha = nil
    check("the bar tall enough for the micro buttons, so nothing pokes off the top of the screen",
        FLook.BarHeight() >= FLook.BtnSize() * 82 / 64 + 2 * 5 and FLook.BarHeight() > classicH and pills.whole.points[1][1] == "TOPLEFT"
        and pills.whole.points[1][4] == nil)
    local plainH = FLook.BarHeight()
    settings.showSystem, settings.sysSize = true, 13
    PaintAll()
    check("with the clock on, the readout sits under it inside the bar, the clock lifted half its height",
        FLook.PlaceClock(bar, fclock, fsys) and fsys.points[1][1] == "TOP" and fsys.points[1][2] == fclock
        and fsys.points[1][3] == "BOTTOM" and fsys.points[1][4] == nil and fclock.points[1][5] == (13 + 3) / 2
        and pills.whole.points[2][5] == 0)
    check("the bar tall enough for the clock and the readout, the clock's hit stopping above the readout",
        FLook.BarHeight() == math.max(plainH, S.Get("clockSize") + 6 + 13 + 3)
        and FLook.ClockHitHeight(100) == 100 - (13 + 3))
    check("the clock's column as wide as the readout, measured on its widest numbers",
        readout.text:find("888", 1, true) and pills[2].points[1][1] == "LEFT" and pills[2].points[1][2] == fclock
        and pills[2].points[1][3] == "CENTER" and pills[2].points[1][4] == -(90 / 2 + 6 + 4))
    local function Side(w)
        local t = Anchored(0)
        function t.GetWidth() return w end
        return t
    end
    local wide = { SetWidth = function(self, w) self.w = w end }
    FLook.Fit(wide, Side(60), Side(60), fclock, 2, 2)
    check("the buttons 20px from the clock's column, room for Grouped's boxes not to touch",
        wide.w == 2 * (14 + 60 + 20) + 90 + 8)
    settings.showSystem = nil
    FLook.Fit(wide, Side(60), Side(60), fclock, 2, 2)
    check("20px with the readout off too", wide.w == 2 * (14 + 60 + 20) + 40 + 8)
    settings.showSystem = true
    settings.showClock = nil
    PaintAll()
    check("with the clock off, the readout stays under the bar and the container reaches down round it",
        not FLook.PlaceClock(bar, fclock, fsys) and fclock.points[1][5] == 0
        and pills.whole.points[2][5] == -(2 + 13 + 3))
    settings.showClock, settings.showSystem = true, nil
    PaintAll()
    check("and stops at the bar when the readout is off", pills.whole.points[2][5] == 0)
    settings.look = "retired"
    check("an unknown saved look falls back to Classic", FLook.Kind() == "classic")
    settings.look = "grouped"
    PaintAll()
    check("Framed Grouped: a container per group and round the clock, none round the bar",
        pills[1].box.shown and pills[2].box.shown and pills[3].box.shown and not pills.whole.shown
        and pills[1].box.points[1][2] == pills[1])
    settings.showSystem = true
    PaintAll()
    check("Grouped: the clock's container holds the readout inside the bar, the side ones hug their buttons",
        pills[2].box.points[2][5] == 0 and pills[2].box.points[1][5] == 0
        and pills[1].box.points[2][5] == -(FLook.BtnSize() * (82 / 64 - 1) / 2 + 5))
    settings.showClock = nil
    PaintAll()
    check("Grouped, clock off: the clock's pill hides, its container wraps the readout under the bar",
        pills[2].shown == false and pills[2].box.shown and pills[2].box.points[1][2] == fsys
        and pills[2].box.points[2][2] == fsys and pills[2].box.points[2][5] == -5)
    settings.showSystem = nil
    PaintAll()
    check("Grouped, clock and readout off: no container under the bar", not pills[2].box.shown)
    settings.showSystem = true
    settings.showClock = true
    settings.showSystem = nil
    settings.look = "classic"
    PaintAll()
    check("back to Classic: the pills back, no containers, the micro buttons hidden", pills[1].alpha == 1
        and not pills[1].box.shown and not pills.whole.shown and lbtn.microShown == false
        and FLook.BarHeight() == classicH)
    settings.look, settings.showClock = nil, nil
    local frows = assert(loadstring(code))(S, Parts, UI, fns, function(name) return { group = name } end,
        function() end).ROWS
    local at
    for i, row in ipairs(frows) do if row.key == "look" then at = i end end
    check("Forever: Bar Style under Background, right after Bar Opacity, its three looks",
        at and frows[at - 1].key == "bgAlpha" and frows[at].label == "Bar Style" and frows[at].choice == FLook.LOOKS
        and table.concat(FLook.LOOKS[2], ",") == "classic,framed,grouped" and FLook.LOOKS[1].classic == "Classic")
    check("Naowh skin: no Bar Style row", not rows.look)
end

print("PASS top bar look: " .. checks .. " checks")
