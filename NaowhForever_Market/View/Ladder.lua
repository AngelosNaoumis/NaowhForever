-- Ladder.lua: an item's listings drawn as a ladder, cheapest first, each rung's count as a bar (Market.Ladder).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts

local ROWS, HEAD_H, ROW_H = 6, 24, 22
local IN, PRICE_W, COUNT_W, BAR_IN, BAR_THICK = 10, 170, 80, 12, 8

local Ladder = { ROWS = ROWS, HEIGHT = HEAD_H + ROWS * ROW_H }
Market.Ladder = Ladder

local function NewRow(ladder, i)
    local row = CreateFrame("Frame", nil, ladder)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(HEAD_H + (i - 1) * ROW_H))
    row:SetPoint("RIGHT")
    row.fill = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.fill:SetAllPoints()
    row.price = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.price:SetPoint("LEFT", IN, 0)
    row.price:SetWidth(PRICE_W)
    row.price:SetJustifyH("LEFT")
    row.price:SetWordWrap(false)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetHeight(BAR_THICK)
    row.bar:SetPoint("LEFT", PRICE_W + BAR_IN, 0)
    row.count = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.count:SetPoint("RIGHT", -IN, 0)
    row.count:SetWidth(COUNT_W)
    row.count:SetJustifyH("RIGHT")
    return row
end

local function PaintRow(row, rung, most)
    local color = rung.lit and T.accent or T.fg
    row.price:SetTextColor(color.r, color.g, color.b)
    row.price:SetText(Parts.Coins(rung.price) .. (rung.label or ""))
    row.count:SetText(rung.countText or rung.count)
    row.fill:SetShown(rung.lit == true)
    local room = row:GetWidth() - PRICE_W - COUNT_W - BAR_IN * 2
    row.bar:SetWidth(math.max(1, room * rung.count / most))
    local tint = rung.lit and T.accent or T.muted
    row.bar:SetColorTexture(tint.r, tint.g, tint.b, 1)
    row:Show()
end

local function Paint(ladder, rungs, n)
    local most = 1
    for i = 1, n do most = math.max(most, rungs[i].count) end
    for i = 1, ROWS do
        if i <= n then PaintRow(ladder.rows[i], rungs[i], most) else ladder.rows[i]:Hide() end
    end
end

local function SetStatus(ladder, text)
    ladder.status:SetText(text)
end

function Ladder.New(parent, title)
    local ladder = CreateFrame("Frame", nil, parent)
    ladder:SetHeight(Ladder.HEIGHT)
    ns.Solid(ladder, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(ladder, St.BORDER_RGB)
    local head = ns.Font(ladder, St.SMALL_SIZE, nil, T.muted)
    head:SetPoint("TOPLEFT", IN, -(HEAD_H - St.SMALL_SIZE) / 2)
    head:SetText(title)
    ladder.status = ns.Font(ladder, St.SMALL_SIZE, nil, T.muted)
    ladder.status:SetPoint("TOPRIGHT", -IN, -(HEAD_H - St.SMALL_SIZE) / 2)
    ladder.rows = {}
    for i = 1, ROWS do ladder.rows[i] = NewRow(ladder, i) end
    ladder.Paint, ladder.SetStatus = Paint, SetStatus
    return ladder
end

function Ladder.Rung(rungs, n)
    local rung = rungs[n]
    if not rung then
        rung = {}
        rungs[n] = rung
    end
    rung.label, rung.countText, rung.lit = nil, nil, false
    return rung
end
