-- Finder.lua: an item list searched by name across your scans, and the price box that watches the picked item (Market.Finder).
local ns = _G.NaowhForever

local GetItemNameByID, IsItemDataCachedByID = C_Item.GetItemNameByID, C_Item.IsItemDataCachedByID

local T = ns.THEME
local Market = ns.Market
local St = Market.Style
local Parts = ns.Shared.Parts
local Items = ns.Shared.Items
local Watch = Market.Watch

local LIST_GAP, NOTE_H, SCROLL_IN = 8, 18, 4
local ROW_H, ROW_ICON, ROW_IN, ICON_GAP, GAP, MARK_W = 30, 22, 8, 8, 6, 3
local STOP_W = 22
local MIN_LETTERS, MAX_RESULTS = 2, 50
local WATCH_LABEL_H, WATCH_GAP = 16, 12
local TEXT_SEARCH = ns.L("Search your scans by name")
local TEXT_FOUND = ns.L("%d found")
local TEXT_MORE = ns.L("The first %d found; type more to narrow it")
local TEXT_NOTHING = ns.L("Nothing in your scans by that name.")
local TEXT_NO_SCAN = ns.L("Scan prices at an auctioneer to fill this page.")
local TEXT_NONE = ns.L("None of these are in your scans.")
local TEXT_WATCH_BELOW = ns.L("Watch for This Price or Less")
local TEXT_WATCH = ns.L("Watch")
local TEXT_UPDATE = ns.L("Update")
local TEXT_STOP = ns.L("Stop Watching")
local TEXT_STOP_GLYPH = "x"
local TEXT_UNDER = ns.L("At or under your price")
local TEXT_ABOVE = ns.L("Above your price")
local TEXT_FULL = ns.L("Your watch list is full: %d items.")

local Finder = {}
Market.Finder = Finder

function Finder.Scan(itemID)
    return ns.AuctionPrice and ns.AuctionPrice(itemID)
end

local function Step(price)
    local step = price > Market.C.SILVER and Market.C.SILVER or 1
    return math.max(step, price - step)
end

local function FromScans(finder, text)
    local found, names, only = finder.found, finder.names, finder.only
    wipe(found)
    local prices = ns.AuctionPriceList and ns.AuctionPriceList()
    if not prices then return TEXT_NO_SCAN end
    local want = ns.Lower(text)
    local more = false
    for id in pairs(prices) do
        local name = (not only or only[id]) and IsItemDataCachedByID(id) and GetItemNameByID(id)
        if name and ns.Lower(name):find(want, 1, true) then
            if #found >= MAX_RESULTS then
                more = true
                break
            end
            found[#found + 1] = id
            names[id] = name
        end
    end
    table.sort(found, finder.byName)
    if more then return TEXT_MORE:format(MAX_RESULTS) end
    return #found > 0 and TEXT_FOUND:format(#found) or TEXT_NOTHING
end

local function FromOnly(finder)
    local found, names = finder.found, finder.names
    wipe(found)
    local prices = ns.AuctionPriceList and ns.AuctionPriceList()
    if not prices then return TEXT_NO_SCAN end
    for id in pairs(finder.only) do
        if prices[id] then
            found[#found + 1] = id
            names[id] = Items.Name(id)
        end
    end
    table.sort(found, finder.byName)
    return #found > 0 and TEXT_FOUND:format(#found) or TEXT_NONE
end

local function RowClicked(row)
    local finder = row.finder
    finder.picked, finder.at = row.itemID, row.index
    finder.redraw()
end

local function RowEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.itemID)
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function StopClicked(row)
    Watch.Remove(row.itemID)
    row.finder.redraw()
    Market.Dock.Refresh()
end

local function NewRow(finder)
    local row = CreateFrame("Button", nil, finder.list)
    row.finder = finder
    row:SetHeight(ROW_H)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.mark = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(MARK_W)
    row.icon = Parts.ItemIcon(row, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    local right = row
    if finder.stop then
        row.stop = ns.Button(row, TEXT_STOP_GLYPH, STOP_W, STOP_W, function() StopClicked(row) end)
        row.stop:SetPoint("RIGHT", -ROW_IN, 0)
        ns.Tooltip(row.stop, TEXT_STOP)
        right = row.stop
    end
    row.price = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.price:SetPoint("RIGHT", right, right == row and "RIGHT" or "LEFT", right == row and -ROW_IN or -GAP, 0)
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.price, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function DrawRows(finder)
    local found, rows, list = finder.found, finder.rows, finder.list
    local at = finder.at
    local one = at ~= nil and found[at] == finder.picked
    local side = finder.listed and finder.side
    for i, id in ipairs(found) do
        local row = rows[i] or NewRow(finder)
        rows[i] = row
        row.itemID, row.index = id, i
        row.stripe:SetShown(i % 2 == 0)
        row.picked:SetShown(id == finder.picked and (not one or at == i))
        row.icon.texture:SetTexture(C_Item.GetItemIconByID(id))
        local color = Items.QualityColor(id) or T.fg
        row.name:SetTextColor(color.r, color.g, color.b)
        row.name:SetText(finder.names[id] or Items.Name(id))
        local scan = Finder.Scan(id)
        local note = side and side(i)
        row.price:SetText(note or scan and Parts.Coins(scan) or "")
        local pc = note and T.muted or Watch.Under(id) and St.HAVE_RGB or T.fg
        row.price:SetTextColor(pc.r, pc.g, pc.b)
        local watched = Watch.Target(id) ~= nil
        row.mark:SetShown(watched)
        if row.stop then row.stop:SetShown(watched) end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", list, "RIGHT")
        row:Show()
    end
    for i = #found + 1, #rows do rows[i]:Hide() end
    list:SetHeight(math.max(1, #found * ROW_H))
end

function Finder.Draw(finder)
    local text = finder.search:GetText() or ""
    wipe(finder.names)
    finder.listed = #text < MIN_LETTERS
    if not finder.listed then
        finder.note:SetText(FromScans(finder, text))
    elseif finder.only then
        finder.note:SetText(FromOnly(finder))
    else
        finder.note:SetText(finder.empty(finder.found))
    end
    if not finder.picked then finder.picked, finder.at = finder.found[1], 1 end
    DrawRows(finder)
end

function Finder.Reset(finder)
    finder.picked, finder.at = nil, nil
    finder.search:SetText("")
end

function Finder.New(parent, width, empty, redraw, stop)
    local finder = { found = {}, names = {}, rows = {}, empty = empty, redraw = redraw, stop = stop }
    local names = finder.names
    finder.byName = function(a, b) return names[a] < names[b] end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(width)
    finder.frame = frame
    finder.search = Parts.SearchBox(frame, TEXT_SEARCH, function()
        finder.scroll:SetVerticalScroll(0)
        redraw()
    end)
    finder.search:SetPoint("TOPLEFT")
    finder.search:SetSize(width, St.SEARCH_H)
    finder.note = ns.Font(frame, St.SMALL_SIZE, nil, T.muted)
    finder.note:SetPoint("TOPLEFT", finder.search, "BOTTOMLEFT", 0, -LIST_GAP)
    finder.note:SetWidth(width)
    finder.note:SetJustifyH("LEFT")
    finder.note:SetWordWrap(false)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", finder.search, "BOTTOMLEFT", 0, -(LIST_GAP + NOTE_H))
    pane:SetPoint("BOTTOMRIGHT")
    ns.Solid(pane, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(pane, St.BORDER_RGB)
    finder.scroll = ns.UI.SlimScroll(pane)
    finder.scroll:SetPoint("TOPLEFT")
    finder.scroll:SetPoint("BOTTOMRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    finder.list = CreateFrame("Frame", nil, finder.scroll)
    finder.list:SetSize(width - St.SCROLLBAR - SCROLL_IN, 1)
    finder.scroll:SetScrollChild(finder.list)
    return finder
end

local function Changed(watch)
    for _, box in ipairs(watch.money.boxes) do box:ClearFocus() end
    watch.onChange()
    Market.Dock.Refresh()
end

local function WatchClicked(watch)
    local amount = watch.money:GetAmount()
    if not (watch.itemID and amount and amount > 0) then return end
    if not Watch.Set(watch.itemID, amount) then ns.Print(TEXT_FULL:format(Watch.MAX)) end
    Changed(watch)
end

local function StopWatchClicked(watch)
    Watch.Remove(watch.itemID)
    Changed(watch)
end

function Finder.Watch(parent, buttonW, buttonH, onChange)
    local watch = CreateFrame("Frame", nil, parent)
    watch.onChange = onChange
    watch:SetHeight(WATCH_LABEL_H + buttonH)
    local label = ns.Font(watch, St.SMALL_SIZE, nil, T.muted)
    label:SetPoint("TOPLEFT")
    label:SetText(TEXT_WATCH_BELOW)
    watch.state = ns.Font(watch, St.SMALL_SIZE, nil, T.muted)
    watch.state:SetPoint("TOPRIGHT")
    watch.money = Parts.MoneyBox(watch)
    watch.money:SetPoint("TOPLEFT", 0, -WATCH_LABEL_H)
    watch.add = ns.PrimaryButton(ns.Button(watch, TEXT_WATCH, buttonW, buttonH, function() WatchClicked(watch) end))
    watch.add:SetPoint("LEFT", watch.money, "RIGHT", WATCH_GAP, 0)
    watch.stop = ns.Button(watch, TEXT_STOP, buttonW, buttonH, function() StopWatchClicked(watch) end)
    watch.stop:SetPoint("LEFT", watch.add, "RIGHT", GAP, 0)
    return watch
end

function Finder.PaintWatch(watch, itemID)
    watch.itemID = itemID
    watch:SetShown(itemID ~= nil)
    if not itemID then return end
    local target = Watch.Target(itemID)
    local scan = Finder.Scan(itemID)
    if not watch.money:HasFocus() then watch.money:SetAmount(target or (scan and Step(scan)) or 0) end
    ns.SetButtonText(watch.add, target and TEXT_UPDATE or TEXT_WATCH)
    watch.stop:SetShown(target ~= nil)
    local under = Watch.Under(itemID)
    local c = under and St.HAVE_RGB or T.muted
    watch.state:SetTextColor(c.r, c.g, c.b)
    watch.state:SetText(target and (under and TEXT_UNDER or TEXT_ABOVE) or "")
end
