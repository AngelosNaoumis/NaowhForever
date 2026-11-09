-- FieldRow.lua: a Field Journal entry: its skill or tick, its name and where to find it, how many you have, and a waypoint to a dish's teacher.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local T = ns.THEME
local Discovery = ns.Discovery
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Style = Discovery.Style
local Field = Discovery.Field
local V = Discovery.View

local STATUS = {
    fish = { ns.L("%d caught"), ns.L("Caught"), ns.L("Not caught") },
    herbs = { ns.L("%d picked"), ns.L("Picked"), ns.L("Not picked") },
    dishes = { ns.L("%d cooked"), ns.L("Cooked"), ns.L("Not cooked") },
}
local COUNTED, TICKED, NOT_YET = 1, 2, 3
local LEVEL_EXTRA = 8
local TEXT_STATUS = ns.L("Status")
local TEXT_SKILL = ns.L("Skill")
local TEXT_BY_HAND = ns.L("Ticked off by hand")
local TEXT_SHARE = ns.L("Share where it is")
local TEXT_PIN_TIP = ns.L("Pin: waypoint")
local TEXT_SHIFT_TICK = ns.L("Shift-click: tick it off")
local TEXT_SHIFT_UNTICK = ns.L("Shift-click: untick it")
local TEXT_WOWHEAD = ns.L("Right-click: Wowhead link")

local function Status(page, count)
    local words = STATUS[page]
    if count == nil then return words[NOT_YET], T.muted end
    if count == 0 then return words[TICKED], Style.HAVE_RGB end
    return words[COUNTED]:format(count), Style.HAVE_RGB
end

local function Share(owner, row)
    local name, map, x, y = Field.Spot(row.entry)
    if name then Parts.SharePlace(owner, TEXT_SHARE, name, map, x, y) end
end

local function PinClicked(button, mouse)
    local row = button:GetParent()
    if mouse == "RightButton" then return Share(button, row) end
    Field.Waypoint(row.entry)
end

local function FieldEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local page, entry, m = row.page, row.entry, T.muted
    GameTooltip:SetItemByID(entry.item)
    GameTooltip:AddLine(" ")
    local count = Field.Count(page, entry)
    local text, color = Status(page, count)
    if count == 0 then text = TEXT_BY_HAND end
    GameTooltip:AddDoubleLine(TEXT_STATUS, text, m.r, m.g, m.b, color.r, color.g, color.b)
    if entry.skill then GameTooltip:AddDoubleLine(TEXT_SKILL, entry.skill, m.r, m.g, m.b, 1, 1, 1) end
    GameTooltip:AddLine(Field.Where(page, entry), m.r, m.g, m.b, true)
    GameTooltip:AddLine(" ")
    if row.pin:IsShown() then GameTooltip:AddLine(TEXT_PIN_TIP, V.Soft()) end
    if count == nil then
        GameTooltip:AddLine(TEXT_SHIFT_TICK, V.Soft())
    elseif count == 0 then
        GameTooltip:AddLine(TEXT_SHIFT_UNTICK, V.Soft())
    end
    GameTooltip:AddLine(TEXT_WOWHEAD, V.Soft())
    GameTooltip:Show()
end

local function FieldMouseUp(row, button)
    if button == "RightButton" then
        Parts.CopyWowhead("item", row.entry.item, GetItemInfo(row.entry.item))
    elseif button == "LeftButton" and IsShiftKeyDown() then
        local count = Field.Count(row.page, row.entry)
        if count == nil or count == 0 then Field.SetHad(row.page, row.entry, count == nil) end
    end
end

local function NewField(parent)
    local row = V.NewRow(parent, PinClicked, FieldEnter)
    row.bag:Hide()
    row.level:SetWidth(Style.LEVEL_W + LEVEL_EXTRA)
    row:SetScript("OnMouseUp", FieldMouseUp)
    return row
end

local function SetName(row, item, had)
    local refused = Items.Refused(item)
    local name = not refused and GetItemInfo(item) or nil
    if not (name or refused) then row:GetParent().waitingFor[item] = true end
    row.title:SetText(name or Items.Name(item))
    V.Paint(row.title, had and T.muted or Items.QualityColor(item) or T.fg)
    return name == nil and not refused
end

local function SetField(row, page, entry, stripe)
    row.page, row.entry = page, entry
    V.Reset(row, stripe)
    local count = Field.Count(page, entry)
    local had = count ~= nil
    row.pin:SetShown(Field.Spot(entry) ~= nil)
    row.tick:SetShown(had)
    row.level:SetShown(not had)
    row.level:SetText(entry.skill or "")
    V.Paint(row.level, T.muted)
    local text, color = Status(page, count)
    row.status:SetText(text)
    V.Paint(row.status, color)
    local textW = V.TextWidth(row)
    row.title:SetWidth(textW)
    local waiting = SetName(row, entry.item, had)
    row.where:SetWidth(textW)
    row.where:SetText(Field.Where(page, entry))
    return V.Height(row), waiting
end

V.Kinds.field = { New = NewField, Set = SetField }
