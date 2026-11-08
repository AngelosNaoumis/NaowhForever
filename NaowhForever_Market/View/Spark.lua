-- Spark.lua: an item's lowest price over the past two weeks as a small gold line, for Farm and Buy (Market.Spark).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local C = Market.C
local History = Market.History

local THICK = 1.5
local LABEL_GAP = 4
local TEXT_DAYS = ns.L("Last 14 days")

local Spark = {}
Market.Spark = Spark

local function Paint(spark, itemID)
    local series, found = History.Series(itemID, spark.series)
    local lo, hi
    for _, price in ipairs(series) do
        if price then lo, hi = math.min(lo or price, price), math.max(hi or price, price) end
    end
    local width, height = spark:GetSize()
    local span = hi and hi > lo and hi - lo or 1
    local step = width / (C.HISTORY_DAYS - 1)
    local gold = St.GOLD_RGB
    local n, prevX, prevY = 0, nil, nil
    for i, price in ipairs(series) do
        if price then
            local x, y = (i - 1) * step, (price - lo) / span * height
            if prevX then
                n = n + 1
                local line = spark.lines[n]
                if not line then
                    line = spark:CreateLine(nil, "ARTWORK")
                    line:SetThickness(THICK)
                    line:SetColorTexture(gold.r, gold.g, gold.b, 1)
                    spark.lines[n] = line
                end
                line:SetStartPoint("BOTTOMLEFT", spark, prevX, prevY)
                line:SetEndPoint("BOTTOMLEFT", spark, x, y)
                line:Show()
            end
            prevX, prevY = x, y
        end
    end
    for i = n + 1, #spark.lines do spark.lines[i]:Hide() end
    spark.label:SetShown(found > 1)
    return found
end

function Spark.New(parent, width, height, labelLeft)
    local spark = CreateFrame("Frame", nil, parent)
    spark:SetSize(width, height)
    spark.lines, spark.series = {}, {}
    spark.label = ns.Font(parent, St.SMALL_SIZE, nil, T.muted)
    if labelLeft then
        spark.label:SetPoint("RIGHT", spark, "LEFT", -LABEL_GAP, 0)
    else
        spark.label:SetPoint("BOTTOMLEFT", spark, "TOPLEFT", 0, LABEL_GAP)
    end
    spark.label:SetText(TEXT_DAYS)
    spark.Paint = Paint
    return spark
end
