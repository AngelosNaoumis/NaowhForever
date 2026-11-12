-- Quantity.lua: the chips over Sell's quantity box: one, a number and all, each picked for this post and kept as the default for that type of item (Market.Quantity).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local Parts = ns.Shared.Parts
local Sell = Market.Sell

local CHIP_SIZE, CHIP_GAP, CHIP_MIN_W = 10, 4, 22
local NUMBER_LETTERS, NUMBER_MIN = 4, 2
local ALL, ONE = 0, 1
local TEXT_ONE = "1"
local TEXT_ALL = ns.L("All")
local TEXT_DEFAULT = ns.L("Default for %s")
local TEXT_DEFAULT_OTHER = ns.L("Default for other items")
local TEXT_CHANGE = ns.L("Right-click to change the number.")
local TEXT_PROMPT = ns.L("How many to post")

local row, redraw
local one, number, all

local Quantity = {}
Market.Quantity = Quantity

local function NumberTyped(text)
    local entry, typed = Sell.Focus(), tonumber(text)
    if not (entry and typed and typed >= NUMBER_MIN and typed == math.floor(typed)) then return end
    Sell.SetQuantityNumber(entry, typed)
    redraw()
end

local function ChipClicked(chip, button)
    local entry = Sell.Focus()
    if not entry then return end
    if chip == number and button == "RightButton" then
        return ns.PromptText(TEXT_PROMPT, tostring(Sell.QuantityNumber(entry)), NUMBER_LETTERS, NumberTyped)
    end
    Sell.SetDefaultQuantity(entry, chip.value)
    redraw()
end

local function ChipEnter(chip)
    local entry = Sell.Focus()
    if not entry then return end
    local class = Sell.QuantityClass(entry)
    GameTooltip:SetOwner(chip, "ANCHOR_TOP")
    GameTooltip:AddLine(class and TEXT_DEFAULT:format(C_Item.GetItemClassInfo(class)) or TEXT_DEFAULT_OTHER, T.fg.r,
        T.fg.g, T.fg.b)
    if chip == number then GameTooltip:AddLine(TEXT_CHANGE, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function Chip(right)
    local chip = Parts.Pill(row, CHIP_SIZE, T.muted)
    if right then chip:SetPoint("RIGHT", right, "LEFT", -CHIP_GAP, 0) else chip:SetPoint("RIGHT") end
    chip:EnableMouse(true)
    chip:SetScript("OnMouseUp", ChipClicked)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", GameTooltip_Hide)
    return chip
end

local function PaintChip(chip, text, value, picked)
    chip.value = value
    Parts.ColorPill(chip, picked == value and T.accent or T.muted)
    chip:SetWidth(math.max(CHIP_MIN_W, Parts.SetPill(chip, text)))
end

local function Paint(_, entry)
    local count = Sell.QuantityNumber(entry)
    local picked = not Sell.QuantityTyped(entry) and Sell.DefaultQuantity(entry)
    PaintChip(all, TEXT_ALL, ALL, picked)
    PaintChip(number, tostring(count), count, picked)
    PaintChip(one, TEXT_ONE, ONE, picked)
end

function Quantity.New(parent, onChange)
    row, redraw = CreateFrame("Frame", nil, parent), onChange
    all = Chip()
    number = Chip(all)
    one = Chip(number)
    row:SetSize(1, all:GetHeight())
    row.Paint = Paint
    return row
end
