-- Look.lua: the Blessings bar's look, the same on the bar and on the settings preview (B.Look).
local ns = _G.NaowhForever

local B = ns.Blessings
local S = B.Settings
local T = ns.THEME
local Parts = ns.Shared.Parts
local ItemBar = ns.Shared.ItemBar

local RED = { r = 0.97, g = 0.27, b = 0.27 }
local YELLOW = { r = 1, g = 0.85, b = 0.3 }
local BLUE = { r = 0.35, g = 0.6, b = 1 }
local ICON_BORDER = { r = 0, g = 0, b = 0 }
local DEEP_SHADE = 0.6
local ICON_CROP = ns.Shared.Style.ICON_CROP
local MARK_SIZE, LABEL_SIZE, LABEL_MIN, TIMER_SIZE = 14, 10, 7, 10
local SHORT_LETTERS = 3
local LABEL_DROP, LABEL_SIDE, TIMER_Y = 2, 3, 1
local CLASS_ICON_PATH = "Interface\\Icons\\ClassIcon_"
local CLASS_ICON_MIN, CLASS_ICON_MAX = 12, 24
local CLASS_ICON_SHARE = 2 / 3
local BADGE_MIN, BADGE_MAX, BADGE_SHARE, BADGE_INSET = 10, 18, 0.4, 1
local BADGE_EDGE_LEVEL, BADGE_LEVEL = 1, 2
local LABEL_COLUMN = 46
local STATUS_PIXELS = 2
local SECONDS = 60
local ROUND = B.ROUND
local MINUTES = "m"
local MARK = "!"
local BACKDROP_PAD = 4
local CORNER = { RIGHT = "BOTTOMLEFT", LEFT = "BOTTOMRIGHT", DOWN = "TOPLEFT", UP = "BOTTOMLEFT" }
local FLIPPED_CORNER = { RIGHT = "TOPLEFT", LEFT = "TOPRIGHT", DOWN = "TOPRIGHT", UP = "BOTTOMRIGHT" }
local TOWARD = { RIGHT = 1, LEFT = -1, DOWN = -1, UP = 1 }
local SPOT = { TOPLEFT = { -1, 1 }, TOP = { 0, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { -1, 0 }, CENTER = { 0, 0 },
    RIGHT = { 1, 0 }, BOTTOMLEFT = { -1, -1 }, BOTTOM = { 0, -1 }, BOTTOMRIGHT = { 1, -1 } }
local CENTER = "CENTER"

local tints = { [RED] = RED, [YELLOW] = YELLOW, [BLUE] = BLUE }
local deepAccent

local Look = { RED = RED, YELLOW = YELLOW, BLUE = BLUE, ICON_BORDER = ICON_BORDER,
    ICON_CROP = ICON_CROP, CLASS_ICON_PATH = CLASS_ICON_PATH, rows = 1 }
B.Look = Look

local function Shorten(text, n)
    local count = 0
    for at in text:gmatch("()[^\128-\191]") do
        count = count + 1
        if count > n then return text:sub(1, at - 1) end
    end
    return text
end

local function FitLabel(label, text, width, font, outline)
    Parts.HudFont(label, font, LABEL_SIZE, outline)
    label:SetWidth(0)
    label:SetText(text)
    local full = label:GetUnboundedStringWidth()
    if full <= width then return end
    Parts.HudFont(label, font, math.max(LABEL_MIN, math.floor(LABEL_SIZE * width / full)), outline)
    if label:GetUnboundedStringWidth() <= width then return end
    label:SetText(Shorten(text, SHORT_LETTERS))
    if label:GetUnboundedStringWidth() > width then label:SetWidth(width) end
end

local function ClassIcon(frame)
    local icon = frame.classIcon
    if icon then return icon end
    icon = CreateFrame("Frame", nil, frame)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    icon.tex:SetTexture(CLASS_ICON_PATH .. frame.class)
    icon.tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(icon, ICON_BORDER)
    frame.classIcon = icon
    return icon
end

local function BadgeSize()
    return math.max(BADGE_MIN, math.min(BADGE_MAX, math.floor(Look.size * BADGE_SHARE + ROUND)))
end

local function Badge(frame)
    local badge = frame.badge
    if badge then return badge end
    badge = frame:CreateTexture(nil, "ARTWORK", nil, BADGE_EDGE_LEVEL)
    badge:SetColorTexture(ICON_BORDER.r, ICON_BORDER.g, ICON_BORDER.b)
    badge.icon = frame:CreateTexture(nil, "ARTWORK", nil, BADGE_LEVEL)
    badge.icon:SetTexture(CLASS_ICON_PATH .. frame.class)
    badge.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.PixelInset(badge.icon, 1, badge)
    frame.badge = badge
    return badge
end

local function Hang(region, frame)
    region:ClearAllPoints()
    if Look.vertical then
        region:SetPoint("LEFT", frame, "RIGHT", LABEL_SIDE, 0)
    else
        region:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_DROP)
    end
end

local function NameRoom(size)
    if not Look.vertical then return size + Look.gap end
    if Look.rows > 1 then return LABEL_COLUMN end
    return math.huge
end

local function PlaceLabel(frame, size)
    local icon, badge = Look.labels and Look.icons, Look.labels and Look.badge
    local name = Look.labels and not (icon or badge)
    frame.label:SetShown(name)
    if name then
        Hang(frame.label, frame)
        FitLabel(frame.label, frame.labelText, NameRoom(size), Look.font, Look.outline)
    end
    if icon then
        local classIcon, side = ClassIcon(frame), Look.IconSize()
        classIcon:SetSize(side, side)
        Hang(classIcon, frame)
        classIcon:Show()
    elseif frame.classIcon then
        frame.classIcon:Hide()
    end
    if badge then
        local classBadge, side = Badge(frame), BadgeSize()
        classBadge:SetSize(side, side)
        classBadge:ClearAllPoints()
        classBadge:SetPoint("TOPLEFT", frame, "TOPLEFT", BADGE_INSET, -BADGE_INSET)
    end
    if frame.badge then
        frame.badge:SetShown(badge)
        frame.badge.icon:SetShown(badge)
    end
end

function Look.Icon(frame)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(frame.icon, 1)
    frame.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    frame.border = ns.Border(frame, ICON_BORDER)
    frame.mark = ns.Font(frame, MARK_SIZE, "OUTLINE", RED)
    frame.mark:SetPoint("CENTER")
    frame.timer = ns.Font(frame, TIMER_SIZE, "OUTLINE")
    frame.timer:SetPoint("BOTTOM", 0, TIMER_Y)
end

function Look.Border(frame)
    local border = frame.border
    if not border then return end
    local style = S.Get("blessBorder")
    border._frame:SetShown(style ~= "none")
    border:SetPixels(style == "status" and frame.class and STATUS_PIXELS or 1)
    local color = style == "accent" and T.accent or ICON_BORDER
    border:SetColor(color.r, color.g, color.b)
end

function Look.Backdrop(bar)
    local name = S.Get("blessBackground")
    local back = bar.backdrop
    if name == "none" then
        if back then back:Hide() end
        return
    end
    if not back then
        back = bar:CreateTexture(nil, "BACKGROUND")
        bar.backdrop = back
    end
    back:ClearAllPoints()
    back:SetPoint("TOPLEFT", bar, "TOPLEFT", -BACKDROP_PAD, BACKDROP_PAD)
    back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", BACKDROP_PAD, -BACKDROP_PAD)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local path = LSM and LSM:Fetch("statusbar", name, true)
    if path then back:SetTexture(path) else back:SetColorTexture(1, 1, 1) end
    back:SetVertexColor(T.bg.r, T.bg.g, T.bg.b, S.Get("blessBackgroundAlpha"))
    back:Show()
end

function Look.Label(cell, class, text)
    cell.label = ns.Font(cell, LABEL_SIZE, "OUTLINE")
    cell.label:SetPoint("TOP", cell, "BOTTOM", 0, -LABEL_DROP)
    cell.label:SetWordWrap(false)
    cell.labelText = text or B.ClassName(class)
    cell.label:SetText(cell.labelText)
end

function Look.Read()
    Look.size, Look.gap, Look.groupGap = S.Get("blessBarSize"), S.Get("blessSpacing"), S.Get("blessGroupSpacing")
    Look.timerSize, Look.labels = S.Get("blessTimerSize"), S.Get("blessShowLabels")
    local style, flip = S.Get("blessLabelStyle"), S.Get("blessFlipRows")
    Look.icons, Look.badge = style == "icon", style == "button"
    Look.status = S.Get("blessBorder") == "status"
    Look.font, Look.outline = S.Get("blessFont"), S.Get("blessOutline")
    Look.grow = ItemBar.GrowOf(S.Get("blessLayout"))
    Look.vertical = ItemBar.Vertical(Look.grow)
    Look.perRow, Look.rows = math.max(1, S.Get("blessPerRow")), 1
    Look.across = flip and -1 or 1
    Look.corner = (flip and FLIPPED_CORNER or CORNER)[Look.grow]
    if S.Get("blessThemeColors") then
        deepAccent = deepAccent or { r = T.accent.r * DEEP_SHADE, g = T.accent.g * DEEP_SHADE, b = T.accent.b * DEEP_SHADE }
        tints[RED], tints[YELLOW], tints[BLUE] = T.accent, T.accentSoft, deepAccent
    else
        tints[RED], tints[YELLOW], tints[BLUE] = S.Get("blessColorMissing"), S.Get("blessColorExpiring"),
            S.Get("blessColorOwn")
    end
end

function Look.Tint(colour)
    return tints[colour]
end

function Look.Place(frame, row, x, y)
    local size = Look.size
    frame:SetSize(size, size)
    local font, outline, missing = Look.font, Look.outline, tints[RED]
    Parts.HudFont(frame.timer, font, Look.timerSize, outline)
    if frame.watchText then Parts.HudFont(frame.watchText, font, Look.timerSize, outline) end
    Parts.HudFont(frame.mark, font, MARK_SIZE, outline)
    frame.mark:SetTextColor(missing.r, missing.g, missing.b)
    if frame.label then PlaceLabel(frame, size) end
    Look.Border(frame)
    Look.Pin(frame, row, x, y)
    frame:Show()
    return x + size + Look.gap
end

function Look.Pin(frame, row, x, y)
    local corner, along, across = Look.corner, TOWARD[Look.grow] * x, Look.across * (y or 0)
    frame:ClearAllPoints()
    if Look.vertical then
        frame:SetPoint(corner, row, corner, across, along)
    else
        frame:SetPoint(corner, row, corner, along, across)
    end
end

function Look.LabelRoom()
    if not Look.labels or Look.badge then return 0 end
    if Look.vertical then return LABEL_SIDE + (Look.icons and Look.IconSize() or LABEL_COLUMN) end
    return LABEL_DROP + (Look.icons and Look.IconSize() or LABEL_SIZE)
end

local function RowStep()
    return Look.size + Look.gap + Look.LabelRoom()
end

function Look.Grid(start, count)
    Look.rows = math.max(1, math.ceil(count / Look.perRow))
    return start + math.min(count, Look.perRow) * (Look.size + Look.gap)
end

function Look.Slot(start, i)
    local perRow = Look.perRow
    return start + i % perRow * (Look.size + Look.gap), math.floor(i / perRow) * RowStep()
end

function Look.IconSize()
    return math.max(CLASS_ICON_MIN, math.min(CLASS_ICON_MAX, math.floor(Look.size * CLASS_ICON_SHARE + ROUND)))
end

function Look.Shift()
    local spot = SPOT[Look.corner]
    return spot[1] * Look.size / 2, spot[2] * Look.size / 2
end

function Look.Hold()
    if Look.perRow < #B.CLASSES then return Look.corner end
    return Look.grow
end

function Look.ToCorner(pos, w, h)
    local corner = Look.corner
    local p, r, c = SPOT[pos.point], SPOT[pos.relPoint], SPOT[corner]
    if not (p and r) then return end
    return { point = corner, relPoint = CENTER,
        x = r[1] * UIParent:GetWidth() / 2 + pos.x + (c[1] - p[1]) * w / 2,
        y = r[2] * UIParent:GetHeight() / 2 + pos.y + (c[2] - p[2]) * h / 2 }
end

function Look.Gap(x)
    if x > 0 then return x + Look.groupGap end
    return x
end

function Look.Width(x)
    return math.max(x - Look.gap, Look.size)
end

function Look.Fit(frame, x)
    local across = Look.size + (Look.rows - 1) * RowStep()
    if Look.vertical then
        frame:SetSize(across, Look.Width(x))
    else
        frame:SetSize(Look.Width(x), across)
    end
end

function Look.Minutes(seconds)
    if not (seconds and seconds > 0 and S.Get("blessTimers")) then return "" end
    return math.ceil(seconds / SECONDS) .. MINUTES
end

function Look.Class(cell, colour, reachable, missing, shortest)
    colour = colour and tints[colour]
    local tint = not Look.status and colour
    cell.icon:SetDesaturated(not reachable)
    cell.icon:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1, tint and tint.b or 1)
    if Look.status then
        local edge = colour or ICON_BORDER
        cell.border:SetColor(edge.r, edge.g, edge.b)
    end
    cell.mark:SetText(missing > 0 and missing or "")
    cell.timer:SetText(Look.Minutes(shortest))
end

function Look.Self(frame, missing, remaining)
    local c = tints[RED]
    frame.icon:SetVertexColor(missing and c.r or 1, missing and c.g or 1, missing and c.b or 1)
    frame.mark:SetText(missing and MARK or "")
    frame.timer:SetText(Look.Minutes(remaining))
end

function Look.State(frame, key, has, remaining)
    local missing = key ~= nil and (frame.watch ~= nil or has == false)
    Look.Self(frame, missing, not frame.watch and remaining)
end
