-- Crafts.lua: the Crafts page: your characters' recipes priced from your last scan, what your bags can make, queueing yours and listing an alt's materials.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Crafts, Columns = Market.Crafts, Market.Columns

local TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local HEAD_H, SUMMARY_H, COLUMNS_H, ROW_H = 44, 30, 22, 40
local SUB_GAP, ROW_IN, ICON, MAT_ICON, MAT_GAP, MAT_W, MATS_SHOWN = 4, 8, 28, 18, 2, 48, 4
local VIEW_W, ACTION_W, SCROLL_IN = 390, 100, 4
local NAME_W, WHO_W, MONEY_W, BAGS_W = 190, 104, 80, 92
local WHO_LEFT = ROW_IN + NAME_W
local MATS_LEFT = WHO_LEFT + WHO_W
local ACTION_RIGHT = ROW_IN
local BAGS_RIGHT = ACTION_RIGHT + ACTION_W + ROW_IN
local GAIN_RIGHT = BAGS_RIGHT + BAGS_W
local SALE_RIGHT = GAIN_RIGHT + MONEY_W
local VIEWS = {
    { key = "bags", label = "From My Bags", tip = "Only what your bags hold the materials for." },
    { key = "all", label = "All Recipes", tip = "Every recipe your characters know that has a price." },
    { key = "disenchant", label = "Disenchant", tip = "Only the recipes worth more disenchanted than sold or vendored." },
}
local TEXT_TITLE = ns.L("Crafts")
local TEXT_SUB = ns.L("Recipes you and your characters know, from Professions, priced from your last scan")
local TEXT_TOTAL = ns.L("Crafting what your bags hold adds about %s over selling the materials, across %d recipes.")
local TEXT_NO_GAIN = ns.L("Nothing your bags hold makes more crafted than sold as it is.")
local TEXT_NO_PROF = ns.L("Turn on Professions: Crafts reads the recipes it saves for each character.")
local TEXT_NONE = ns.L("No priced recipes yet. Open each profession once so Professions saves its recipes, and scan prices at an auctioneer.")
local TEXT_NONE_BAGS = ns.L("Nothing your bags can craft right now. All Recipes lists every one.")
local TEXT_NONE_DISENCHANT = ns.L("No recipe is worth more disenchanted than sold or vendored.")
local TEXT_RECIPE, TEXT_WHO, TEXT_MATS = ns.L("Recipe"), ns.L("Known by"), ns.L("Materials")
local TEXT_SALE, TEXT_GAIN, TEXT_PROFIT, TEXT_BAGS = ns.L("Sells for"), ns.L("Over raw"), ns.L("Profit"), ns.L("From bags")
local TEXT_YOU = ns.L("You")
local OUTLETS = { sell = ns.L("Sell"), disenchant = ns.L("Disenchant"), vendor = ns.L("Vendor") }
local TEXT_MADE = "%s |cff808080x%d|r"
local TEXT_HAVE = "%d/%d"
local TEXT_VENDOR = ns.L("vendor")
local TEXT_CAN = ns.L("%d, %s")
local TEXT_NO_BAGS = ns.L("none")
local TEXT_QUEUE = ns.L("Add to Queue")
local TEXT_QUEUE_TIP = ns.L("Adds %d to Professions' Craft Queue, and what it still needs to your Shopping List.")
local TEXT_QUEUED = ns.L("Queued")
local TEXT_LIST = ns.L("Add to List")
local TEXT_LIST_TITLE = ns.L("Add to Shopping List")
local TEXT_LIST_TIP = ns.L("Puts the materials for one craft on your Shopping List, to buy on this character.")
local TEXT_BUY = ns.L("Buy")
local TEXT_BUY_TIP = ns.L("Opens Buy with %d %s, what you are short of for one craft.")
local TEXT_NEGATIVE = "-%s"

local page, summary, scroll, list, empty, viewTabs, sorter
local rowPool, view, queued = {}, {}, {}
local fromBags = true
local outlet
local active = false
local events

local Page = {}
Market.Pages.crafts = Page

local function Money(copper)
    if copper < 0 then return TEXT_NEGATIVE:format(Parts.Coins(-copper, true)) end
    return Parts.Coins(copper, true)
end

local function Tint(fs, copper)
    local c = copper > 0 and St.HAVE_RGB or copper < 0 and St.RED_RGB or T.muted
    fs:SetTextColor(c.r, c.g, c.b)
end

local function ProfessionName(id)
    local info = id and C_TradeSkillUI.GetProfessionInfoBySkillLineID(id)
    return info and info.professionName or ""
end

local function Short(row)
    local P = ns.Professions
    local shop = P and P.Shopping
    if not shop then return end
    for part, per in pairs(row.need) do
        local have = C_Item.GetItemCount(part)
        if have < per and not shop.VendorPrice(part) then return part, per - have end
    end
end

local function Cell(row, width, right)
    local fs = ns.Font(row, TEXT_SIZE, nil, T.fg)
    fs:SetPoint("RIGHT", -right, 0)
    fs:SetWidth(width)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    return fs
end

local function NewMat(row, i)
    local mat = CreateFrame("Frame", nil, row)
    mat:SetSize(MAT_W, MAT_ICON)
    mat:SetPoint("LEFT", MATS_LEFT + (i - 1) * (MAT_W + MAT_GAP), 0)
    mat.icon = Parts.ItemIcon(mat, MAT_ICON)
    mat.icon:SetPoint("LEFT")
    mat.text = ns.Font(mat, SMALL_SIZE, nil, T.fg)
    mat.text:SetPoint("LEFT", mat.icon, "RIGHT", SUB_GAP, 0)
    mat:EnableMouse(true)
    mat:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    mat:SetScript("OnLeave", GameTooltip_Hide)
    return mat
end

local function ActionClicked(button)
    local row = button:GetParent().row
    if button.mode == "queue" then
        if Crafts.Queue(row, row.can) then queued[row.recipe] = true end
        Page.Draw()
    elseif button.mode == "list" then
        if Crafts.List(row) and ns.OpenShoppingList and not Market.Window.AtAuction() then ns.OpenShoppingList() end
    elseif button.mode == "buy" then
        local part, short = Short(row)
        if not part then return end
        Market.Window.ShowPage("buy")
        Market.Pages.buy.PickItem(part, short)
    end
end

local function NewRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    Parts.RowBands(row, 0)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row.icon = Parts.ItemIcon(row, ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.icon:EnableMouse(true)
    row.icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self:GetParent().row.output)
        GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", GameTooltip_Hide)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ROW_IN, 0)
    row.name:SetWidth(NAME_W - ICON - ROW_IN * 2)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.who = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.who:SetPoint("BOTTOMLEFT", row, "LEFT", WHO_LEFT, 1)
    row.prof = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.prof:SetPoint("TOPLEFT", row, "LEFT", WHO_LEFT, -1)
    row.mats = {}
    for i = 1, MATS_SHOWN do row.mats[i] = NewMat(row, i) end
    row.sale = Cell(row, MONEY_W, SALE_RIGHT)
    row.sale:ClearAllPoints()
    row.sale:SetPoint("BOTTOMRIGHT", row, "RIGHT", -SALE_RIGHT, 1)
    row.outlet = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.outlet:SetPoint("TOPRIGHT", row, "RIGHT", -SALE_RIGHT, -1)
    row.gain = Cell(row, MONEY_W, GAIN_RIGHT)
    row.bags = Cell(row, BAGS_W, BAGS_RIGHT)
    row.action = ns.Button(row, "", ACTION_W, BUTTON_H, ActionClicked)
    row.action:SetPoint("RIGHT", -ACTION_RIGHT, 0)
    return row
end

local function PaintMats(row, data)
    local i = 0
    local P = ns.Professions
    local shop = P and P.Shopping
    for part, per in pairs(data.need) do
        i = i + 1
        local mat = row.mats[i]
        if not mat then break end
        mat.item = part
        mat.icon.texture:SetTexture(C_Item.GetItemIconByID(part))
        if shop and shop.VendorPrice(part) then
            mat.text:SetText(TEXT_VENDOR)
            mat.text:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        else
            local have = C_Item.GetItemCount(part)
            mat.text:SetText(TEXT_HAVE:format(have, per))
            local c = have >= per and St.HAVE_RGB or St.RED_RGB
            mat.text:SetTextColor(c.r, c.g, c.b)
        end
        mat:Show()
    end
    for j = i + 1, MATS_SHOWN do row.mats[j]:Hide() end
end

local function PaintAction(row, data)
    local button = row.action
    button.mode = nil
    if queued[data.recipe] then
        ns.SetButtonText(button, TEXT_QUEUED)
        ns.Tooltip(button, nil, nil)
    elseif data.can > 0 and data.gain > 0 and Crafts.CanQueue(data) then
        button.mode = "queue"
        ns.SetButtonText(button, TEXT_QUEUE)
        ns.Tooltip(button, TEXT_QUEUE, TEXT_QUEUE_TIP:format(data.can))
    elseif Crafts.CanList(data) then
        button.mode = "list"
        ns.SetButtonText(button, TEXT_LIST)
        ns.Tooltip(button, TEXT_LIST_TITLE, TEXT_LIST_TIP)
    elseif Market.Window.AtAuction() and Short(data) then
        local part, short = Short(data)
        button.mode = "buy"
        ns.SetButtonText(button, TEXT_BUY)
        ns.Tooltip(button, TEXT_BUY, TEXT_BUY_TIP:format(short, C_Item.GetItemNameByID(part) or ""))
    end
    button:SetShown(button.mode ~= nil or queued[data.recipe] == true)
    St.Enable(button, button.mode ~= nil)
end

local function PaintRow(row, data, i)
    row.row = data
    row.stripe:SetShown(i % 2 == 0)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(data.output))
    local name = C_Item.GetItemNameByID(data.output) or ""
    local quality = C_Item.GetItemQualityByID(data.output)
    local color = quality and ITEM_QUALITY_COLORS[quality] or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(data.made > 1 and TEXT_MADE:format(name, data.made) or name)
    row.who:SetText(data.who or TEXT_YOU)
    row.prof:SetText(ProfessionName(data.prof))
    PaintMats(row, data)
    row.sale:SetText(Parts.Coins(data.sale, true))
    row.outlet:SetText(OUTLETS[data.outlet])
    local gain = fromBags and data.gain or data.profit
    row.gain:SetText(gain and Money(gain) or "")
    Tint(row.gain, gain or 0)
    if data.can > 0 then
        row.bags:SetText(TEXT_CAN:format(data.can, Money(data.gain * data.can)))
        Tint(row.bags, data.gain)
    else
        row.bags:SetText(TEXT_NO_BAGS)
        row.bags:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    end
    PaintAction(row, data)
end

local function DrawSummary(read)
    if not read then return summary:SetText("") end
    local total, n = Crafts.Total()
    summary:SetText(n > 0 and TEXT_TOTAL:format(Parts.Coins(total, true), n) or TEXT_NO_GAIN)
end

function Page.Draw()
    if not active then return end
    local read = Crafts.Fresh()
    Columns.Sort(sorter, Crafts.View(fromBags, view, outlet))
    local y = 0
    for i, data in ipairs(view) do
        local row = rowPool[i] or NewRow()
        rowPool[i] = row
        PaintRow(row, data, i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
        y = y + ROW_H
    end
    for i = #view + 1, #rowPool do rowPool[i]:Hide() end
    list:SetHeight(math.max(1, y))
    DrawSummary(read)
    empty:SetShown(#view == 0)
    if not read then
        empty:SetText(TEXT_NO_PROF)
    elseif #Crafts.rows == 0 then
        empty:SetText(TEXT_NONE)
    elseif outlet then
        empty:SetText(TEXT_NONE_DISENCHANT)
    else
        empty:SetText(TEXT_NONE_BAGS)
    end
end

local function ViewPicked(key)
    fromBags = key == "bags"
    outlet = key == "disenchant" and key or nil
    Parts.PaintTabs(viewTabs, key)
    Columns.SetText(sorter, "gain", fromBags and TEXT_GAIN or TEXT_PROFIT)
    Columns.SetDefault(sorter, fromBags and "bags" or "gain")
    Page.Draw()
end

local function Gain(data)
    if fromBags then return data.gain end
    return data.profit
end

local function BuildHeader()
    local header = CreateFrame("Frame", nil, page)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEAD_H)
    local title = ns.Font(header, St.TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT")
    title:SetText(TEXT_TITLE)
    local sub = ns.Font(header, SMALL_SIZE, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    sub:SetText(TEXT_SUB)
    viewTabs = Parts.Tabs(header, VIEW_W, VIEWS, ViewPicked)
    viewTabs:SetPoint("TOPRIGHT")
    Parts.PaintTabs(viewTabs, "bags")
    summary = ns.Font(page, TEXT_SIZE, nil, T.fg)
    summary:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    summary:SetPoint("RIGHT")
    summary:SetHeight(SUMMARY_H)
    summary:SetJustifyH("LEFT")
    local columns = CreateFrame("Frame", nil, page)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -SUMMARY_H)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), -SUMMARY_H)
    columns:SetHeight(COLUMNS_H)
    sorter = Columns.New(columns, Market.Settings, "sortCrafts", "bags", Page.Draw)
    Columns.Add(sorter, { key = "recipe", text = TEXT_RECIPE, left = ROW_IN, up = true,
        value = function(data) return (C_Item.GetItemNameByID(data.output) or ""):lower() end })
    Columns.Add(sorter, { key = "who", text = TEXT_WHO, left = WHO_LEFT, up = true,
        value = function(data) return (data.who or TEXT_YOU):lower() end })
    Columns.Label(sorter, TEXT_MATS, MATS_LEFT)
    Columns.Add(sorter, { key = "sale", text = TEXT_SALE, right = SALE_RIGHT, width = MONEY_W,
        value = function(data) return data.sale end })
    Columns.Add(sorter, { key = "gain", text = TEXT_GAIN, right = GAIN_RIGHT, width = MONEY_W, value = Gain })
    Columns.Add(sorter, { key = "bags", text = TEXT_BAGS, right = BAGS_RIGHT, width = BAGS_W,
        value = function(data) return math.max(0, data.gain) * data.can end })
    return columns
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local columns = BuildHeader()
    scroll = ns.UI.SlimScroll(page)
    scroll:SetPoint("TOPLEFT", columns, "BOTTOMLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    scroll:HookScript("OnSizeChanged", function(_, width) list:SetWidth(width) end)
    empty = ns.Font(page, TEXT_SIZE, nil, T.muted)
    empty:SetPoint("TOP", scroll, "TOP", 0, -ROW_H)
    empty:SetWidth(VIEW_W * 2)
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", function()
        Crafts.Changed()
        Page.Draw()
    end)
end

function Page.Show()
    page:Show()
    list:SetWidth(scroll:GetWidth())
    if not active then
        active = true
        events:RegisterEvent("BAG_UPDATE_DELAYED")
    end
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    if not active then return end
    active = false
    events:UnregisterAllEvents()
end
