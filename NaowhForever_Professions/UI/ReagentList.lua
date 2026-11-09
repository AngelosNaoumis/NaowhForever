-- ReagentList.lua: the Reagents list the Reagents window and The Market share: a row per reagent with what to do with it, opening onto every recipe it goes into (P.ReagentList).
local ns = _G.NaowhForever

local GetItemNameByID = C_Item.GetItemNameByID

local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local P = ns.Professions
local Style = P.Style
local Uses = P.ReagentUses

local ROW_H, USE_H = 36, 32
local ROW_IN, SIGN_W, ICON, USE_IN, USE_ICON = 6, 14, 24, 34, 20
local NAME_GAP, LINE_GAP, VALUE_W, USE_VALUE_W, SCROLL_GAP = 8, 1, 190, 90, 4
local MAX_FOUND = 100
local REDRAW_DELAY = 0
local EVENTS = { "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }
local STATUS_RGB = { ready = Style.READY_RGB, rank = Style.RANK_RGB }
local TEXT_OPEN, TEXT_SHUT = "-", "+"
local TEXT_TIMES = "%s |cff808080x%d|r"
local TEXT_USED = ns.L("Used in %d recipes")
local TEXT_USED_ONE = ns.L("Used in 1 recipe")
local TEXT_CRAFT = ns.L("Craft %s")
local TEXT_OVER = ns.L("+%s a craft over selling")
local TEXT_NO_PRICE = ns.L("no price")
local TEXT_NEGATIVE = "-%s"
local TEXT_YOU = ns.L("You know it")
local TEXT_ALT = ns.L("An alt knows it")
local TEXT_ALT_NAMED = ns.L("%s knows it")
local TEXT_NEED = "%s %d, %s"
local TEXT_MAKE = ns.L("Make %d")
local TEXT_SALE = ns.L("Sells for")
local TEXT_RAW = ns.L("Its materials sell for")
local TEXT_GAIN = ns.L("Crafting gains")
local TEXT_NO_SALE = ns.L("No auction price for it yet.")
local TEXT_REQUIRES = ns.L("Requires %s %d")
local TEXT_YOURS = ns.L("You: %d/%d")
local TEXT_NOT_YOURS = ns.L("You have not learned %s.")
local TEXT_WAYPOINT = ns.L("Click to set a waypoint.")
local TEXT_EMPTY = ns.L("No reagents in your bags. Search above to look any reagent up.")
local TEXT_NO_MATCH = ns.L("No reagent matches that.")

local ReagentList = {}
P.ReagentList = ReagentList

local List = {}

local function Money(copper)
    if copper < 0 then return TEXT_NEGATIVE:format(Parts.Coins(-copper, true)) end
    return Parts.Coins(copper, true)
end

local function Tint(fs, copper)
    local c = copper > 0 and Style.PROFIT_RGB or copper < 0 and Style.RED_RGB or T.muted
    fs:SetTextColor(c.r, c.g, c.b)
end

local function ByWorth(a, b)
    local x, y = a.each * a.count, b.each * b.count
    if x ~= y then return x > y end
    return a.item < b.item
end

local function ByName(a, b)
    local x, y = GetItemNameByID(a) or "", GetItemNameByID(b) or ""
    if x ~= y then return x < y end
    return a < b
end

local function Font(row, size, color)
    local fs = ns.Font(row, size, nil, color or T.fg)
    fs:SetWordWrap(false)
    return fs
end

local function Lines(row, left, icon, valueW)
    row.name = Font(row, Style.FONT)
    row.name:SetPoint("BOTTOMLEFT", row, "LEFT", left + icon + NAME_GAP, LINE_GAP)
    row.name:SetJustifyH("LEFT")
    row.sub = Font(row, Style.FONT_SMALL, T.muted)
    row.sub:SetPoint("TOPLEFT", row, "LEFT", left + icon + NAME_GAP, -LINE_GAP)
    row.sub:SetJustifyH("LEFT")
    row.value = Font(row, Style.FONT)
    row.value:SetPoint("BOTTOMRIGHT", row, "RIGHT", -ROW_IN, LINE_GAP)
    row.value:SetWidth(valueW)
    row.value:SetJustifyH("RIGHT")
    row.note = Font(row, Style.FONT_SMALL, T.muted)
    row.note:SetPoint("TOPRIGHT", row, "RIGHT", -ROW_IN, -LINE_GAP)
    row.note:SetWidth(valueW)
    row.note:SetJustifyH("RIGHT")
    row.name:SetPoint("RIGHT", row.value, "LEFT", -NAME_GAP, 0)
    row.sub:SetPoint("RIGHT", row.note, "LEFT", -NAME_GAP, 0)
end

local function OnReagentClick(row)
    local list = row.list
    list.open[row.item] = not list.open[row.item] or nil
    list:Draw()
end

local function OnReagentEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.item)
    GameTooltip:Show()
end

local function OnLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function NewReagentRow(list)
    local row = CreateFrame("Button", nil, list.body)
    row:SetHeight(ROW_H)
    row.list = list
    Parts.RowBands(row, 0)
    row.sign = Font(row, Style.FONT_LARGE, T.muted)
    row.sign:SetPoint("LEFT", ROW_IN, 0)
    row.icon = Parts.ItemIcon(row, ICON)
    row.icon:SetPoint("LEFT", ROW_IN + SIGN_W, 0)
    Lines(row, ROW_IN + SIGN_W, ICON, VALUE_W)
    row:SetScript("OnClick", OnReagentClick)
    row:SetScript("OnEnter", OnReagentEnter)
    row:SetScript("OnLeave", OnLeave)
    return row
end

local function AddMoney(label, copper)
    GameTooltip:AddDoubleLine(label, Money(copper), T.muted.r, T.muted.g, T.muted.b, T.fg.r, T.fg.g, T.fg.b)
end

local function AddWhere(e)
    local status, skill, cap = Uses.Status(e)
    local c = STATUS_RGB[status] or T.muted
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(TEXT_REQUIRES:format(Uses.Profession(e) or "", Uses.Skill(e)),
        status == "none" and "" or TEXT_YOURS:format(skill, cap), c.r, c.g, c.b, T.muted.r, T.muted.g, T.muted.b)
    if status == "none" then GameTooltip:AddLine(TEXT_NOT_YOURS:format(Uses.Profession(e) or ""), c.r, c.g, c.b, true) end
    for _, line in ipairs(Uses.Where(e)) do
        if line.para then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(line.text, T.fg.r, T.fg.g, T.fg.b, true)
    end
    if Uses.Spot(e) then GameTooltip:AddLine(TEXT_WAYPOINT, T.accent.r, T.accent.g, T.accent.b) end
end

local function OnUseEnter(row)
    local e = row.use
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if e.output then GameTooltip:SetItemByID(e.output) else GameTooltip:SetSpellByID(e.spell) end
    GameTooltip:AddLine(" ")
    if e.sale then
        AddMoney(TEXT_SALE, e.sale)
        AddMoney(TEXT_RAW, e.raw)
        AddMoney(TEXT_GAIN, e.gain)
    else
        GameTooltip:AddLine(TEXT_NO_SALE, T.muted.r, T.muted.g, T.muted.b)
    end
    if e.rank == Uses.NEW then AddWhere(e) end
    GameTooltip:Show()
end

local function OnUseClick(row)
    if row.use.rank == Uses.NEW then Uses.Waypoint(row.use) end
end

local function NewUseRow(list)
    local row = CreateFrame("Button", nil, list.body)
    row:SetHeight(USE_H)
    row.list = list
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.ROW_HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = Parts.ItemIcon(row, USE_ICON)
    row.icon:SetPoint("LEFT", USE_IN, 0)
    Lines(row, USE_IN, USE_ICON, USE_VALUE_W)
    row:SetScript("OnClick", OnUseClick)
    row:SetScript("OnEnter", OnUseEnter)
    row:SetScript("OnLeave", OnLeave)
    return row
end

function List:Name(item)
    local name = GetItemNameByID(item)
    if name then return name end
    if not self.asked[item] then
        self.asked[item] = true
        C_Item.RequestLoadItemDataByID(item)
    end
    return ""
end

function List:Who(e)
    if e.rank == Uses.YOU then return TEXT_YOU, Style.PROFIT_RGB end
    if e.rank == Uses.ALT then
        local name = self.altName and self.altName(e.alt)
        return name and TEXT_ALT_NAMED:format(name) or TEXT_ALT, T.accent
    end
    local status = Uses.Status(e)
    return TEXT_NEED:format(Uses.Profession(e) or "", Uses.Skill(e), ns.RecipeFinder.Tag(e.r)),
        STATUS_RGB[status] or T.muted
end

function List:PaintReagent(row, info, i)
    row.item = info.item
    row.stripe:SetShown(i % 2 == 0)
    row.sign:SetText(self.open[info.item] and TEXT_OPEN or TEXT_SHUT)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(info.item))
    local quality = C_Item.GetItemQualityByID(info.item)
    local color = quality and ITEM_QUALITY_COLORS[quality] or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    local name = self:Name(info.item)
    row.name:SetText(info.count > 0 and TEXT_TIMES:format(name, info.count) or name)
    local n = #info.list
    row.sub:SetText(n == 1 and TEXT_USED_ONE or TEXT_USED:format(n))
    local best = info.best
    row.value:SetText(best and TEXT_CRAFT:format(Uses.Name(best) or "") or "")
    row.value:SetTextColor(Style.PROFIT_RGB.r, Style.PROFIT_RGB.g, Style.PROFIT_RGB.b)
    row.note:SetText(best and TEXT_OVER:format(Parts.Coins(best.gain, true)) or "")
end

function List:PaintUse(row, e)
    row.use = e
    row.icon.texture:SetTexture(Uses.Icon(e))
    local name = e.output and self:Name(e.output) or Uses.Name(e) or ""
    row.name:SetText(e.made > 1 and TEXT_TIMES:format(name, e.made) or name)
    local color = e.rank == Uses.NEW and T.muted or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    local who, c = self:Who(e)
    row.sub:SetText(who)
    row.sub:SetTextColor(c.r, c.g, c.b)
    if e.gain then
        row.value:SetText(Money(e.gain))
        Tint(row.value, e.gain)
    else
        row.value:SetText(TEXT_NO_PRICE)
        row.value:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    end
    row.note:SetText(e.can and e.can > 0 and TEXT_MAKE:format(e.can) or "")
end

function List:Place(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", self.body, "RIGHT")
    row:Show()
end

function List:Collect()
    Uses.Begin()
    wipe(self.missing)
    local items = self.items
    if self.query == "" then
        Uses.Carried(items)
    else
        Uses.Search(self.query, items, self.missing)
        for _, item in ipairs(self.missing) do self:Name(item) end
        table.sort(items, ByName)
        for i = #items, MAX_FOUND + 1, -1 do items[i] = nil end
    end
    wipe(self.shown)
    for i, item in ipairs(items) do
        self.infos[i] = Uses.Read(item, self.infos[i] or {})
        self.shown[i] = self.infos[i]
    end
    if self.query == "" then table.sort(self.shown, ByWorth) end
end

function List:Draw()
    if not self:IsVisible() then return end
    self:Collect()
    local y, rows, used = 0, 0, 0
    for i, info in ipairs(self.shown) do
        rows = rows + 1
        local row = self.rows[rows] or NewReagentRow(self)
        self.rows[rows] = row
        self:PaintReagent(row, info, i)
        self:Place(row, y)
        y = y + ROW_H
        if self.open[info.item] then
            for _, e in ipairs(info.list) do
                used = used + 1
                local use = self.useRows[used] or NewUseRow(self)
                self.useRows[used] = use
                self:PaintUse(use, e)
                self:Place(use, y)
                y = y + USE_H
            end
        end
    end
    for i = rows + 1, #self.rows do self.rows[i]:Hide() end
    for i = used + 1, #self.useRows do self.useRows[i]:Hide() end
    self.body:SetHeight(math.max(1, y))
    self.empty:SetShown(rows == 0)
    self.empty:SetText(self.query == "" and TEXT_EMPTY or TEXT_NO_MATCH)
end

function List:Search(text)
    self.query = ns.Lower(strtrim(text or ""))
    self.scroll:SetVerticalScroll(0)
    self:Draw()
end

local function OnEvent(events, event, item)
    local list = events.list
    if event == "ITEM_DATA_LOAD_RESULT" and not list.asked[item] then return end
    if list.pending then return end
    list.pending = true
    C_Timer.After(REDRAW_DELAY, list.flush)
end

local function OnShow(list)
    for _, event in ipairs(EVENTS) do list.events:RegisterEvent(event) end
    list.body:SetWidth(list.scroll:GetWidth())
    list:Draw()
end

local function OnHide(list)
    list.events:UnregisterAllEvents()
end

function ReagentList.New(parent)
    local list = Mixin(CreateFrame("Frame", nil, parent), List)
    list.query, list.open, list.asked = "", {}, {}
    list.rows, list.useRows, list.items, list.infos, list.shown, list.missing = {}, {}, {}, {}, {}, {}
    list.scroll = ns.UI.SlimScroll(list)
    list.scroll:SetPoint("TOPLEFT")
    list.scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_GAP), 0)
    list.body = CreateFrame("Frame", nil, list.scroll)
    list.body:SetHeight(1)
    list.scroll:SetScrollChild(list.body)
    list.scroll:HookScript("OnSizeChanged", function(_, width) list.body:SetWidth(width) end)
    list.empty = ns.Font(list, Style.FONT, nil, T.muted)
    list.empty:SetPoint("TOPLEFT", 0, -ROW_H)
    list.empty:SetPoint("TOPRIGHT", 0, -ROW_H)
    list.empty:SetJustifyH("CENTER")
    list.empty:SetWordWrap(true)
    list.events = CreateFrame("Frame")
    list.events.list = list
    list.events:SetScript("OnEvent", OnEvent)
    list.flush = function()
        list.pending = false
        list:Draw()
    end
    list:SetScript("OnShow", OnShow)
    list:SetScript("OnHide", OnHide)
    return list
end
