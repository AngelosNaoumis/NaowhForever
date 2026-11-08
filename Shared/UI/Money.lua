-- Money.lua: a price typed in gold, silver and copper, each box beside its coin (Parts.MoneyBox).
local ns = _G.NaowhForever
local Parts = ns.Shared.Parts

local GOLD, SILVER = 10000, 100
local BOX_H = 24
local GOLD_W, SMALL_W = 64, 34
local COIN, COIN_GAP, BOX_GAP = 12, 3, 8
local COIN_DROP = 1
local GOLD_LETTERS, SMALL_LETTERS = 6, 2
local COINS = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon" }

local function Amount(money)
    local gold = tonumber(money.boxes[1]:GetText()) or 0
    local silver = tonumber(money.boxes[2]:GetText()) or 0
    local copper = money.boxes[3]:IsShown() and tonumber(money.boxes[3]:GetText()) or 0
    return gold * GOLD + math.min(silver, SILVER - 1) * SILVER + math.min(copper, SILVER - 1)
end

local function SetAmount(money, copper)
    copper = math.max(0, math.floor(copper or 0))
    money.boxes[1]:SetText(math.floor(copper / GOLD))
    money.boxes[2]:SetText(math.floor(copper / SILVER) % SILVER)
    money.boxes[3]:SetText(copper % SILVER)
end

local function Typed(box, userInput)
    if not userInput then return end
    local money = box:GetParent()
    if money.onChange then money.onChange(money, Amount(money)) end
end

local function NextBox(box)
    local money = box:GetParent()
    local boxes = money.boxes
    local last = boxes[3]:IsShown() and 3 or 2
    local nextIndex = box.index % last + 1
    if IsShiftKeyDown() then nextIndex = (box.index - 2) % last + 1 end
    boxes[nextIndex]:SetFocus()
end

local function Box(money, index, width, letters)
    local box = ns.NewEditBox(money)
    box:SetSize(width, BOX_H)
    box:SetNumeric(true)
    box:SetMaxLetters(letters)
    box:SetJustifyH("RIGHT")
    box:SetTextInsets(0, COIN + COIN_GAP * 2, 0, 0)
    box.index = index
    local coin = box:CreateTexture(nil, "ARTWORK")
    coin:SetTexture(COINS[index])
    coin:SetSize(COIN, COIN)
    coin:SetPoint("RIGHT", -COIN_GAP, -COIN_DROP)
    box:SetScript("OnTextChanged", Typed)
    box:SetScript("OnTabPressed", NextBox)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

local function ShowCopper(money, shown)
    money.boxes[3]:SetShown(shown)
    money:SetWidth(GOLD_W + SMALL_W + BOX_GAP + (shown and SMALL_W + BOX_GAP or 0))
end

local function HasFocus(money)
    for _, box in ipairs(money.boxes) do
        if box:HasFocus() then return true end
    end
    return false
end

function Parts.MoneyBox(parent, onChange)
    local money = CreateFrame("Frame", nil, parent)
    money:SetHeight(BOX_H)
    money.onChange = onChange
    money.boxes = { Box(money, 1, GOLD_W, GOLD_LETTERS), Box(money, 2, SMALL_W, SMALL_LETTERS),
        Box(money, 3, SMALL_W, SMALL_LETTERS) }
    money.boxes[1]:SetPoint("LEFT")
    money.boxes[2]:SetPoint("LEFT", money.boxes[1], "RIGHT", BOX_GAP, 0)
    money.boxes[3]:SetPoint("LEFT", money.boxes[2], "RIGHT", BOX_GAP, 0)
    money.GetAmount, money.SetAmount, money.ShowCopper, money.HasFocus = Amount, SetAmount, ShowCopper, HasFocus
    ShowCopper(money, true)
    return money
end
