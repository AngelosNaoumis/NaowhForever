-- Columns.lua: a list's column labels; a click sorts the list by that column, a second click turns it round (Market.Columns).
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style

local ARROW = "auctionhouse-ui-sortarrow"
local ARROW_GAP, HIT_H = 3, 20
local UP, DOWN = "up", "down"
local SAVED = "^(%w+):(%a+)$"

local Columns = {}
Market.Columns = Columns

-- A value-less entry goes last either way; ties keep the order the list came in, which is its default.
function Columns.SortBy(list, value, up)
    local keys, rank = {}, {}
    for i, entry in ipairs(list) do keys[entry], rank[entry] = value(entry), i end
    table.sort(list, function(a, b)
        local x, y = keys[a], keys[b]
        if x == nil or y == nil or x == y then
            if (x == nil) ~= (y == nil) then return y == nil end
            return rank[a] < rank[b]
        end
        if up then return x < y end
        return x > y
    end)
    return list
end

function Columns.Current(header)
    local key, way = (header.settings.Get(header.setting) or ""):match(SAVED)
    if key and header.byKey[key] then return key, way == UP end
    local column = header.byKey[header.default]
    return header.default, column and column.up
end

local function Paint(header)
    local current, up = Columns.Current(header)
    for _, column in ipairs(header.list) do
        local on = column.key == current
        local c = on and T.accent or column.button:IsMouseOver() and T.fg or T.muted
        column.label:SetTextColor(c.r, c.g, c.b)
        column.arrow:SetShown(on)
        if on then
            if up then column.arrow:SetTexCoord(0, 1, 1, 0) else column.arrow:SetTexCoord(0, 1, 0, 1) end
        end
    end
end

local function Place(column)
    local width = column.label:GetStringWidth()
    column.arrow:ClearAllPoints()
    if column.left then
        column.arrow:SetPoint("LEFT", column.label, "LEFT", width + ARROW_GAP, 0)
        column.button:SetWidth(width + ARROW_GAP + column.arrow:GetWidth())
    else
        column.arrow:SetPoint("RIGHT", column.label, "RIGHT", -(width + ARROW_GAP), 0)
    end
end

function Columns.Pick(header, key)
    local current, up = Columns.Current(header)
    if key == current then up = not up else up = header.byKey[key].up end
    header.settings.Set(header.setting, key .. ":" .. (up and UP or DOWN))
    Paint(header)
    header.onSort()
end

function Columns.Sort(header, list)
    local key, up = Columns.Current(header)
    return Columns.SortBy(list, header.byKey[key].value, up)
end

function Columns.SetDefault(header, key)
    header.default = key
    Paint(header)
end

function Columns.SetText(header, key, text)
    local column = header.byKey[key]
    column.label:SetText(text)
    Place(column)
end

-- A column: key, text, value(entry) to sort by, up for a first click that sorts low to high (or A to Z),
-- and its place as the rows have it: left, or right and width.
function Columns.Add(header, spec)
    local parent = header.parent
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(HIT_H)
    local label = ns.Font(button, St.SMALL_SIZE, nil, T.muted)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlas(ARROW, true)
    if spec.left then
        button:SetPoint("LEFT", parent, spec.left < 0 and "RIGHT" or "LEFT", spec.left, 0)
        label:SetPoint("LEFT")
        label:SetJustifyH("LEFT")
    else
        button:SetPoint("RIGHT", parent, "RIGHT", -spec.right, 0)
        button:SetWidth(spec.width)
        label:SetPoint("RIGHT")
        label:SetWidth(spec.width)
        label:SetJustifyH("RIGHT")
    end
    local column = { key = spec.key, value = spec.value, up = spec.up, left = spec.left,
        button = button, label = label, arrow = arrow }
    header.list[#header.list + 1] = column
    header.byKey[spec.key] = column
    button:SetScript("OnClick", function() Columns.Pick(header, spec.key) end)
    button:SetScript("OnEnter", function() Paint(header) end)
    button:SetScript("OnLeave", function() Paint(header) end)
    Columns.SetText(header, spec.key, spec.text)
    Paint(header)
    return column
end

-- A label that does not sort, in the same place and look as the others.
function Columns.Label(header, text, left)
    local label = ns.Font(header.parent, St.SMALL_SIZE, nil, T.muted)
    label:SetPoint("LEFT", left, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

-- settings.Get(setting) keeps the choice, "worth:down"; default is the column the list comes sorted by.
function Columns.New(parent, settings, setting, default, onSort)
    return { parent = parent, settings = settings, setting = setting, default = default, onSort = onSort,
        list = {}, byKey = {} }
end
