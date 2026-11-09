-- Menus.lua: every Naowh right-click menu and dropdown (ns.ContextMenu, ns.DropdownMenu, ns.MenuOpen): the game's menus with keyboard and mouse, Naowh's own list under the Gamepad interface style.
local ns = _G.NaowhForever
local T = ns.THEME
local St = ns.Shared.Style

local ROW_H, PAD = 20, 6
local MARK, DOT, ARROW_SIZE = 12, 6, 10
local DIVIDER_H, COLUMN_GAP, MAX_COLUMNS = 9, 4, 3
local SCREEN_SHARE = 0.8
local DROP = 2
local STRATA = "FULLSCREEN_DIALOG"
local HOVER_ALPHA = 0.08
local TEXT_BACK = ns.L("Back")
local TEXT_MORE = ns.L("More")
local RESPONSE_DEFAULT = { checkbox = "refresh" }

local function Response(value)
    local R = MenuResponse
    if not R or value == nil then return nil end
    if value == R.Open then return "open" end
    if value == R.Refresh then return "refresh" end
    if value == R.Close then return "close" end
    return "all"
end

local Element = {}
Element.__index = Element

local function NewElement(kind, text, a, b, data)
    return setmetatable({ kind = kind, text = text, a = a, b = b, data = data, children = {} }, Element)
end

function Element:Add(kind, text, a, b, data)
    local e = NewElement(kind, text, a, b, data)
    e.parent = self
    self.children[#self.children + 1] = e
    return e
end

function Element:CreateButton(text, callback, data) return self:Add("button", text, callback, nil, data) end
function Element:CreateTitle(text) return self:Add("title", text) end
function Element:CreateDivider() return self:Add("divider") end
function Element:CreateRadio(text, isSelected, setSelected, data)
    return self:Add("radio", text, setSelected, isSelected, data)
end
function Element:CreateCheckbox(text, isSelected, setSelected, data)
    return self:Add("checkbox", text, setSelected, isSelected, data)
end
function Element:SetEnabled(enabled) self.enabled = enabled end
function Element:SetTooltip(fn) self.tooltip = fn end
function Element:SetScrollMode(height) self.height = height end

function Element:IsEnabled()
    local on = self.enabled
    if type(on) == "function" then return on(self) and true or false end
    return on ~= false
end

function Element:IsSelected()
    return self.b and self.b(self.data) and true or false
end

local list, rows, open

local function TopWindow(owner)
    local frame = owner
    while frame and frame.GetParent do
        local parent = frame:GetParent()
        if not parent or parent == UIParent then return frame end
        frame = parent
    end
    return UIParent
end

local Render

local function Close()
    if list then list:Hide() end
end

local function Respond(row, button)
    local e = row.element
    if not e or not e:IsEnabled() then return end
    if e.page then open.page = e.page; return Render() end
    if e.back then open.level, open.page = e.back, nil; return Render() end
    if e.kind == "button" and #e.children > 0 then open.level, open.page = e, nil; return Render() end
    if e.kind == "title" or e.kind == "divider" then return end
    local response = RESPONSE_DEFAULT[e.kind] or "all"
    local was = open
    if e.a then
        local returned = Response(e.a(e.data, { buttonName = button }, list))
        if returned then response = returned end
    end
    if open ~= was then return end
    if response == "all" then return Close() end
    if response == "close" then
        if open.level.parent then open.level, open.page = open.level.parent, nil; return Render() end
        return Close()
    end
    if response == "refresh" then Render() end
end

local function RowEnter(row)
    local e = row.element
    if not (e and e.tooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    e.tooltip(GameTooltip, e)
    GameTooltip:Show()
end

local function RowLeave()
    GameTooltip:Hide()
end

local function MakeRow()
    local row = CreateFrame("Button")
    row:SetParent(list)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hover = ns.Solid(row, "HIGHLIGHT", T.fg, HOVER_ALPHA)
    row.hover:SetAllPoints()
    row.text = ns.Font(row, St.TEXT_SIZE)
    row.text:SetJustifyH("LEFT")
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetSize(MARK, MARK)
    row.mark:SetPoint("LEFT", PAD, 0)
    row.box = CreateFrame("Frame")
    row.box:SetParent(row)
    row.box:SetAllPoints(row.mark)
    row.boxEdge = ns.Border(row.box, T.muted)
    row.dot = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.dot:SetSize(DOT, DOT)
    row.dot:SetPoint("CENTER", row.mark)
    row.line = ns.Solid(row, "ARTWORK", T.line, 1)
    row.line:SetPoint("LEFT", PAD, 0)
    row.line:SetPoint("RIGHT", -PAD, 0)
    ns.Hairline(row.line, "h")
    row.arrow = ns.Shared.Parts.Arrow(row, ARROW_SIZE, T.muted)
    row.arrow:SetPoint("RIGHT", -PAD, 0)
    row:SetScript("OnClick", Respond)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function ShowRow(row, e)
    row.element = e
    local kind = e.kind
    local on = e:IsEnabled()
    row.line:SetShown(kind == "divider")
    row.text:SetShown(kind ~= "divider")
    row.mark:Hide()
    row.box:SetShown(kind == "checkbox")
    row.dot:SetShown(kind == "radio" and e:IsSelected())
    row.arrow:SetShown(kind == "button" and #e.children > 0)
    row.hover:SetShown(kind ~= "title" and kind ~= "divider" and on)
    if kind == "checkbox" and e:IsSelected() then
        row.mark:SetTexture(St.CHECK)
        row.mark:Show()
    end
    if kind == "radio" then row.box:Show() end
    row:SetHeight(kind == "divider" and DIVIDER_H or ROW_H)
    local left = (kind == "radio" or kind == "checkbox") and PAD + MARK + PAD or PAD
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", left, 0)
    row.text:SetText(e.text or "")
    local color = (kind == "title" or not on) and T.muted or T.fg
    row.text:SetTextColor(color.r, color.g, color.b, 1)
    local width = left + math.ceil(row.text:GetStringWidth()) + PAD
    if row.arrow:IsShown() then width = width + ARROW_SIZE + PAD end
    row:Show()
    return width
end

local function PageOf(children, size)
    for i, e in ipairs(children) do
        if e.kind == "radio" and e:IsSelected() then return math.ceil(i / size) end
    end
    return 1
end

function Render()
    if not open then return end
    local level = open.level
    local maxH = open.root.height or (UIParent:GetHeight() * SCREEN_SHARE)
    local perColumn = math.max(1, math.floor((maxH - 2 * PAD) / ROW_H))
    local shown = {}
    if level.parent then
        shown[1] = NewElement("button", TEXT_BACK)
        shown[1].back = level.parent
    end
    local children = level.children
    local first, last, more = 1, #children
    local room = perColumn * MAX_COLUMNS - #shown
    if #children > room then
        local size = math.max(1, room - 1)
        local pages = math.ceil(#children / size)
        open.page = open.page or PageOf(children, size)
        if open.page > pages then open.page = 1 end
        first, last = (open.page - 1) * size + 1, math.min(open.page * size, #children)
        more = NewElement("button", TEXT_MORE)
        more.page = open.page % pages + 1
    end
    for i = first, last do shown[#shown + 1] = children[i] end
    if more then shown[#shown + 1] = more end
    local widths, columns = {}, math.ceil(#shown / perColumn)
    for i, e in ipairs(shown) do
        rows[i] = rows[i] or MakeRow()
        local w = ShowRow(rows[i], e)
        local c = math.ceil(i / perColumn)
        widths[c] = math.max(widths[c] or 0, w)
    end
    for i = #shown + 1, #rows do rows[i]:Hide() end
    local x, tallest = PAD, 0
    for c = 1, columns do
        local y = PAD
        for i = (c - 1) * perColumn + 1, math.min(c * perColumn, #shown) do
            local row = rows[i]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", x, -y)
            row:SetWidth(widths[c])
            y = y + row:GetHeight()
        end
        tallest = math.max(tallest, y)
        x = x + widths[c] + COLUMN_GAP
    end
    list:SetSize(x - COLUMN_GAP + PAD, tallest + PAD)
end

local function OnGlobalMouseDown()
    if not open then return end
    if list:IsMouseOver() then return end
    if open.owner and open.owner ~= UIParent and open.owner.IsMouseOver and open.owner:IsMouseOver() then return end
    Close()
end

local function OnHide()
    list:Hide()
    list:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    GameTooltip:Hide()
    open = nil
end

local function Build()
    list = CreateFrame("Frame")
    list:SetFrameStrata(STRATA)
    list:SetToplevel(true)
    list:SetClampedToScreen(true)
    list:EnableMouse(true)
    list.bg = ns.Solid(list, "BACKGROUND", T.bg, St.BACKDROP_ALPHA)
    list.bg:SetAllPoints()
    list.edge = ns.Border(list, T.line)
    list:Hide()
    list:SetScript("OnHide", OnHide)
    list:SetScript("OnEvent", OnGlobalMouseDown)
    rows = {}
end

local function Show(owner, root, place)
    if not list then Build() end
    list:Hide()
    list:SetParent(TopWindow(owner))
    list:SetFrameStrata(STRATA)
    open = { owner = owner, root = root, level = root }
    list:ClearAllPoints()
    place(list)
    list:Show()
    Render()
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    local token = {}
    open.handle = token
    function token.IsShown() return list:IsShown() and open ~= nil and open.handle == token end
    function token.Close() if token.IsShown() then Close() end end
    return token
end

local function AtCursor(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

function ns.ContextMenu(owner, generator)
    if not ns.GamepadStandDown() then return MenuUtil.CreateContextMenu(owner, generator) end
    local root = NewElement("root")
    generator(owner, root)
    return Show(owner, root, AtCursor)
end

function ns.DropdownMenu(owner, fill, height)
    if not ns.GamepadStandDown() then
        if not (MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants
            and Menu and Menu.GetManager and AnchorUtil) then return end
        local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultMenuMixin())
        if not desc then return end
        if height and desc.SetScrollMode then desc:SetScrollMode(height) end
        fill(desc)
        return Menu.GetManager():OpenMenu(owner, desc,
            AnchorUtil.CreateAnchor("TOPLEFT", owner, "BOTTOMLEFT", 0, -DROP))
    end
    local root = NewElement("root")
    root.height = height
    fill(root)
    return Show(owner, root, function(frame) frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -DROP) end)
end

function ns.MenuOpen()
    if list and list:IsShown() then return true end
    return Menu and Menu.GetManager and Menu.GetManager():IsAnyMenuOpen() or false
end
