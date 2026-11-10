-- EnchantSlot.lua: an Enchanting recipe's item slot under its description: pick the item in it and Create enchants that item, with no targeting cursor.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local R = P.Recipes
local W = P.State
local Popup = P.Popup
local Style = P.Style
local Widgets = P.Widgets

local SLOT = 36
local SLOT_GAP = 12
local LABEL_GAP = 8
local PLUS_SIZE = 20
local PICKER_DROP = 4
local MAX_ROWS = Style.SIDE_PANEL_ROWS
local TEXT_LABEL = ns.L("Item to enchant")
local TEXT_EMPTY = ns.L("Choose an item")
local TEXT_SELECT = ns.L("Select")
local TEXT_NONE = ns.L("None of your items take this enchant.")
local TEXT_MORE = ns.L("%d items: scroll for more.")
local TIP_SLOT_HELP = ns.L("Click to choose the item this enchant goes on. Create then enchants it "
    .. "straight away. Right-click to clear it and pick the item with the cursor instead.")

local EnchantSlot = {}
P.EnchantSlot = EnchantSlot

local win, slot, picker
local chosen, pickerRecipe
local offset = 0
local items = {}

local function ByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.guid < b.guid
end

local function ClosePicker()
    if picker and picker:IsShown() then picker:Hide() end
    pickerRecipe = nil
end

local function Clear()
    chosen = nil
    ClosePicker()
end

local function Valid(recipeID)
    return chosen ~= nil and chosen.recipeID == recipeID
        and C_TradeSkillUI.IsEnchantTargetValid(recipeID, chosen.guid)
end

local function Fill(info)
    local d = win.detail
    local icon, label = slot.icon, slot.label
    if not Valid(info.recipeID) then Clear() end
    if chosen then
        local item = Item:CreateFromItemGUID(chosen.guid)
        icon:SetTexture(item:GetItemIcon())
        icon:Show()
        slot.plus:Hide()
        label:SetText(item:GetItemLink() or item:GetItemName() or "")
        label:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    else
        icon:Hide()
        slot.plus:Show()
        label:SetText(TEXT_EMPTY)
        label:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    end
    d.enchantTitle:Show()
    slot:Show()
end

local function Choose(row)
    chosen = { guid = row.guid, recipeID = pickerRecipe }
    ClosePicker()
    P.Detail.Render()
end

local function FillRows()
    local n = #items
    offset = math.max(0, math.min(offset, n - MAX_ROWS))
    local shown = math.min(n, MAX_ROWS)
    for i = 1, shown do
        local entry = items[i + offset]
        local row = Popup.Row(picker, i, TEXT_SELECT, Choose)
        row.guid, row.item = entry.guid, entry.itemID
        row.icon:SetTexture(entry.icon)
        row.name:SetText(entry.link)
        row:Show()
    end
    local note = n == 0 and TEXT_NONE or n > MAX_ROWS and TEXT_MORE:format(n) or ""
    picker.note:SetText(note)
    Popup.Fit(picker, shown, note ~= "")
end

local function OnWheel(_, delta)
    offset = offset - delta
    FillRows()
end

local function LoadItems(recipeID)
    wipe(items)
    for _, guid in ipairs(C_TradeSkillUI.GetEnchantItems(recipeID)) do
        local item = Item:CreateFromItemGUID(guid)
        items[#items + 1] = { guid = guid, itemID = item:GetItemID(), icon = item:GetItemIcon(),
            link = item:GetItemLink() or item:GetItemName() or "", name = item:GetItemName() or "" }
    end
    table.sort(items, ByName)
end

local function OpenPicker(info)
    if not picker then
        picker = Popup.New(TEXT_LABEL)
        picker:EnableMouseWheel(true)
        picker:SetScript("OnMouseWheel", OnWheel)
    end
    pickerRecipe, offset, picker.dismissed = info.recipeID, 0, nil
    LoadItems(info.recipeID)
    FillRows()
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -PICKER_DROP)
    picker:Show()
end

local function OnClick(_, button)
    local info = R.SelectedInfo()
    if not info then return end
    if button == "RightButton" then
        Clear()
        return P.Detail.Render()
    end
    if picker and picker:IsShown() then return ClosePicker() end
    OpenPicker(info)
end

-- Returns the room the slot takes under the description, 0 when this recipe has none.
function EnchantSlot.Render(info, below)
    local d = win.detail
    if chosen and chosen.recipeID ~= info.recipeID then Clear() end
    local on = not W.linked and not W.orders and R.Own() and info.learned and P.EnchantSlots[info.recipeID] ~= nil
    if not on then
        d.enchantTitle:Hide()
        slot:Hide()
        return 0
    end
    d.enchantTitle:ClearAllPoints()
    d.enchantTitle:SetPoint("TOPLEFT", d.desc, "BOTTOMLEFT", 0, -SLOT_GAP - below)
    Fill(info)
    return SLOT_GAP + d.enchantTitle:GetStringHeight() + LABEL_GAP + SLOT
end

-- The chosen item's location for this recipe, or nil to cast with the targeting cursor.
function EnchantSlot.Location(recipeID)
    if not Valid(recipeID) then
        Clear()
        return nil
    end
    return C_Item.GetItemLocation(chosen.guid)
end

function EnchantSlot.Build(frame, d)
    win = frame
    d.enchantTitle = ns.Font(d, Style.FONT, nil, Style.GOLD_RGB)
    d.enchantTitle:SetText(TEXT_LABEL)
    d.enchantTitle:Hide()
    slot = CreateFrame("Button", nil, d)
    slot:SetSize(SLOT, SLOT)
    slot:SetPoint("TOPLEFT", d.enchantTitle, "BOTTOMLEFT", 0, -LABEL_GAP)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.Solid(slot, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(slot, Style.BORDER_RGB)
    slot.icon = Widgets.Crop(slot:CreateTexture(nil, "ARTWORK"))
    slot.icon:SetAllPoints()
    slot.plus = ns.Font(slot, PLUS_SIZE, nil, T.muted)
    slot.plus:SetPoint("CENTER")
    slot.plus:SetText("+")
    slot.label = ns.Font(slot, Style.FONT, nil)
    slot.label:SetPoint("LEFT", slot, "RIGHT", LABEL_GAP, 0)
    slot.label:SetJustifyH("LEFT")
    slot:SetScript("OnClick", OnClick)
    slot:HookScript("OnHide", ClosePicker)
    ns.Tooltip(slot, TEXT_LABEL, TIP_SLOT_HELP)
    slot:Hide()
end
