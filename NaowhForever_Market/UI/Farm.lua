-- Farm.lua: the Farm page: zones ranked for your skills, the chosen zone's map with its herbs, veins, skinning camps and fishing pools priced, and its loop.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local Parts = ns.Shared.Parts
local Farm, Spark = Market.Farm, Market.Spark

local TEXT_SIZE, SMALL_SIZE, BUTTON_H = St.TEXT_SIZE, St.SMALL_SIZE, St.BUTTON_H
local ZONES_W, PANE_GAP, HEAD_H, ZONE_ROW_H, ZONE_ICON, ZONE_ICONS = 250, 12, 62, 52, 16, 5
local FILTER_H, FILTERS_H, TICK = 20, 132, 12
local MAP_HEAD_H, STRIP_H, STRIP_ICON, SPARK_W, SPARK_H = 44, 74, 40, 200, 40
local ROW_IN, GAP, SUB_GAP, BAR_H, SCROLL_IN = 8, 6, 4, 3, 4
local PIN_MIN, PIN_GROW, PIN_RING = 10, 12, 2
local LINE_THICK, LINE_ALPHA, LOCKED_ALPHA, PICKED_ALPHA = 2, 0.55, 0.35, 0.3
local LAYER = 1
local OPEN_W, LOOP_W = 110, 120
local KV_W = 150
local TEXT_BEST = ns.L("Best for You")
local TEXT_SKILLS = ns.L("Herbalism %d, Mining %d, Skinning %d, Fishing %d")
local TEXT_HOUR = ns.L("about %s an hour")
local TEXT_MADE = ns.L("you made %s an hour")
local TEXT_SUB = ns.L("Loop of %d stops, about %d minutes, about %s an hour, estimated")
local TEXT_NO_LOOP = ns.L("Nothing here you can gather yet.")
local TEXT_NO_POOLS = ns.L("Fish anywhere in this zone's water. Pools you fish from are added to this map.")
local TEXT_OPEN = ns.L("Open Map")
local TEXT_LOOP = ns.L("Start Loop")
local TEXT_LOOP_TIP = ns.L("Waypoints through the loop, nearest stop first, each placed when you reach the last.")
local TEXT_LOOP_TITLE = ns.L("%s loop")
local TEXT_HERBS, TEXT_VEINS, TEXT_LOCKED = ns.L("Herbs"), ns.L("Veins"), ns.L("Nodes I can't gather yet")
local TEXT_SKINS, TEXT_FISH = ns.L("Beasts to skin"), ns.L("Fishing")
local TEXT_PLAN = ns.L("Plan at max skill")
local TEXT_NOT_READY = ns.L("Farm needs Quality of Life (Glimmer's herb and vein map) and Professions turned on.")
local TEXT_NO_ZONES = ns.L("No zone has anything for your skills. Learn Herbalism, Mining, Skinning or Fishing, or turn on what you gather below.")
local TEXT_NEEDS = { herb = ns.L("Herbalism %d"), ore = ns.L("Mining %d"), skin = ns.L("Skinning %d"),
    fish = ns.L("Fishing %d") }
local TEXT_REQUIRES = { herb = ns.L("Requires Herbalism %d"), ore = ns.L("Requires Mining %d"),
    skin = ns.L("Requires Skinning %d"), fish = ns.L("Requires Fishing %d") }
local TEXT_CAMP = ns.L("%d here, level %d to %d")
local TEXT_NODE = ns.L("About %s a node")
local TEXT_PICKED = ns.L("Gathered %s")
local TEXT_SCAN_PRICE = ns.L("at your last scan")
local TEXT_NO_PRICE = ns.L("no scan price")
local TEXT_HAVE, TEXT_WORTH, TEXT_A_NODE = ns.L("You have"), ns.L("Worth"), ns.L("A node")
local TEXT_A = { skin = ns.L("A camp"), fish = ns.L("A catch") }
local FISH_ICON = "Interface\\Icons\\Trade_Fishing"
local TEXT_SELL = ns.L("Sell %d")

local page, zonePane, zoneScroll, zoneList, zoneNote, skillsText, main, mapHead, nameText, subText
local canvas, strip, openButton, loopButton
local filters = {}
local zoneRows, pins, tiles, lines = {}, {}, {}, {}
local picked = { map = nil, kind = nil, item = nil }
local active = false

local Page = {}
Market.Pages.farm = Page

local KIND_RGB = { herb = St.HERB_RGB, ore = St.ORE_RGB, skin = St.SKIN_RGB, fish = St.FISH_RGB }

local function KindColor(kind)
    return KIND_RGB[kind]
end

local Enable = St.Enable

local function ItemEnter(icon)
    if not icon.item then return end
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(icon.item)
    GameTooltip:Show()
end

-- Hover shows the item; a click still reaches the row or strip under it.
local function ItemTip(icon)
    icon:SetMouseMotionEnabled(true)
    icon:SetMouseClickEnabled(false)
    icon:SetScript("OnEnter", ItemEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
end

local function Panel(frame)
    ns.Solid(frame, "BACKGROUND", T.fg, St.PANEL_FILL):SetAllPoints()
    ns.Border(frame, St.BORDER_RGB)
end

local function Picked(zone)
    return zone.map == picked.map and zone.kind == picked.kind
end

local function ZoneClicked(row)
    picked.map, picked.kind, picked.item = row.zone.map, row.zone.kind, nil
    Page.Draw()
end

local function NewZoneRow()
    local row = CreateFrame("Button", nil, zoneList)
    row:SetHeight(ZONE_ROW_H)
    Parts.RowBands(row, 0)
    row.picked = ns.Solid(row, "BACKGROUND", T.accent, St.PICKED_FILL)
    row.picked:SetAllPoints()
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg, true)
    row.name:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    row.name:SetPoint("RIGHT", -ROW_IN, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.icons = {}
    for i = 1, ZONE_ICONS do
        local icon = Parts.ItemIcon(row, ZONE_ICON)
        icon:SetPoint("BOTTOMLEFT", ROW_IN + (i - 1) * (ZONE_ICON + SUB_GAP), ROW_IN + BAR_H)
        ItemTip(icon)
        row.icons[i] = icon
    end
    row.hour = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.hour:SetPoint("BOTTOMRIGHT", -ROW_IN, ROW_IN + BAR_H)
    row.bar = ns.Solid(row, "ARTWORK", St.GOLD_RGB, 1)
    row.bar:SetHeight(BAR_H)
    row.bar:SetPoint("BOTTOMLEFT", ROW_IN, SUB_GAP)
    row:SetScript("OnClick", ZoneClicked)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    return row
end

local function DrawZones()
    local zones = Farm.Zones()
    local best = zones[1] and zones[1].rank or 0
    local room = zoneList:GetWidth() - ROW_IN * 2
    local y = 0
    for i, zone in ipairs(zones) do
        local row = zoneRows[i] or NewZoneRow()
        zoneRows[i] = row
        row.zone = zone
        row.stripe:SetShown(i % 2 == 0)
        row.picked:SetShown(Picked(zone))
        row.name:SetText(zone.name)
        local shift = zone.kind == "fish" and 1 or 0
        for j, icon in ipairs(row.icons) do
            local top = zone.items[j - shift]
            icon.item = j > shift and top and top.item or nil
            if j <= shift then
                icon.texture:SetTexture(FISH_ICON)
            elseif top then
                icon.texture:SetTexture(C_Item.GetItemIconByID(top.item))
            end
            icon:SetShown(j <= shift or top ~= nil)
        end
        row.hour:SetText((zone.measured and TEXT_MADE or TEXT_HOUR):format(Parts.Coins(zone.rank, true)))
        row.bar:SetWidth(math.max(1, room * (best > 0 and zone.rank / best or 0)))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", zoneList, "RIGHT")
        row:Show()
        y = y + ZONE_ROW_H
    end
    for i = #zones + 1, #zoneRows do zoneRows[i]:Hide() end
    zoneList:SetHeight(math.max(1, y))
    zoneNote:SetShown(#zones == 0)
    zoneNote:SetText(Farm.Ready() and TEXT_NO_ZONES or TEXT_NOT_READY)
    skillsText:SetText(TEXT_SKILLS:format(Farm.Skill("herb"), Farm.Skill("ore"), Farm.Skill("skin"), Farm.Skill("fish")))
    return zones
end

local function Fit()
    local layers = C_Map.GetMapArtLayers(picked.map)
    local info = layers and layers[LAYER]
    if not info then return end
    local roomW, roomH = main:GetWidth(), main:GetHeight() - MAP_HEAD_H - STRIP_H - GAP * 2
    local scale = math.min(roomW / info.layerWidth, roomH / info.layerHeight)
    canvas:SetSize(info.layerWidth * scale, info.layerHeight * scale)
    return info, scale
end

local function DrawTiles(info, scale)
    local textures = C_Map.GetMapArtLayerTextures(picked.map, LAYER) or {}
    local cols = math.ceil(info.layerWidth / info.tileWidth)
    local rows = math.ceil(info.layerHeight / info.tileHeight)
    local w, h, n = info.tileWidth * scale, info.tileHeight * scale, 0
    for row = 1, rows do
        for col = 1, cols do
            n = n + 1
            local tile = tiles[n]
            if not tile then
                tile = canvas:CreateTexture(nil, "BACKGROUND")
                tiles[n] = tile
            end
            tile:SetTexture(textures[(row - 1) * cols + col], nil, nil, "TRILINEAR")
            tile:SetSize(w, h)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", (col - 1) * w, -(row - 1) * h)
            tile:Show()
        end
    end
    for i = n + 1, #tiles do tiles[i]:Hide() end
end

local function PinEnter(pin)
    local spot = pin.spot
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(Farm.SpotName(spot, ""), 1, 1, 1)
    if spot.count then
        local low, high = Farm.CreatureLevels(spot.id)
        GameTooltip:AddLine(TEXT_CAMP:format(spot.count, low, high), 1, 1, 1)
    end
    local need = (spot.can and TEXT_NEEDS or TEXT_REQUIRES)[spot.kind]:format(spot.need)
    local c = spot.can and T.muted or St.RED_RGB
    GameTooltip:AddLine(need, c.r, c.g, c.b)
    if spot.value > 0 then GameTooltip:AddLine(TEXT_NODE:format(Parts.Coins(spot.value, true)), 1, 1, 1) end
    if spot.picked then
        local m = T.muted
        GameTooltip:AddLine(TEXT_PICKED:format(ns.Shared.Ago(spot.picked)), m.r, m.g, m.b)
    end
    GameTooltip:Show()
end

local function PinClicked(pin)
    picked.item = pin.spot.item
    Page.DrawStrip()
end

local function NewPin()
    local pin = CreateFrame("Button", nil, canvas)
    pin.ring = pin:CreateTexture(nil, "ARTWORK")
    pin.ring:SetAllPoints()
    pin.ring:SetTexture(St.ROUND)
    pin.ring:SetVertexColor(0, 0, 0, 1)
    pin.dot = pin:CreateTexture(nil, "OVERLAY")
    pin.dot:SetPoint("TOPLEFT", PIN_RING, -PIN_RING)
    pin.dot:SetPoint("BOTTOMRIGHT", -PIN_RING, PIN_RING)
    pin.dot:SetTexture(St.ROUND)
    pin:SetScript("OnEnter", PinEnter)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnClick", PinClicked)
    return pin
end

local function DrawPins(width, height)
    local n, most = 0, Farm.most or 0
    local showLocked = S.Get("farmLocked")
    for _, spot in ipairs(Farm.spots) do
        if spot.wanted and (spot.reach or showLocked) then
            n = n + 1
            local pin = pins[n] or NewPin()
            pins[n] = pin
            pin.spot = spot
            local size = PIN_MIN + (most > 0 and math.sqrt(spot.value / most) * PIN_GROW or 0)
            pin:SetSize(size, size)
            local c = spot.can and KindColor(spot.kind) or T.muted
            pin.dot:SetVertexColor(c.r, c.g, c.b, 1)
            pin:SetAlpha(not spot.can and LOCKED_ALPHA or spot.picked and PICKED_ALPHA or 1)
            pin:SetFrameLevel(canvas:GetFrameLevel() + (spot.can and 2 or 1))
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", canvas, "TOPLEFT", spot.x * width, -spot.y * height)
            pin:Show()
        end
    end
    for i = n + 1, #pins do pins[i]:Hide() end
end

local function DrawLoop(width, height)
    local loop, n = Farm.loop, 0
    local gold = St.GOLD_RGB
    for i = 1, #loop do
        local a, b = loop[i], loop[i % #loop + 1]
        if #loop > 1 then
            n = n + 1
            local line = lines[n]
            if not line then
                line = canvas:CreateLine(nil, "ARTWORK")
                line:SetThickness(LINE_THICK)
                lines[n] = line
            end
            line:SetColorTexture(gold.r, gold.g, gold.b, LINE_ALPHA)
            line:SetStartPoint("TOPLEFT", canvas, a.x * width, -a.y * height)
            line:SetEndPoint("TOPLEFT", canvas, b.x * width, -b.y * height)
            line:Show()
        end
    end
    for i = n + 1, #lines do lines[i]:Hide() end
end

local function TopItem()
    if picked.item then return picked.item end
    if picked.kind == "fish" then return Farm.catchItem end
    local best
    for _, spot in ipairs(Farm.loop) do
        if spot.item and (not best or spot.value > best.value) then best = spot end
    end
    return best and best.item
end

local function NodeValueOf(item)
    for _, spot in ipairs(Farm.spots) do
        if spot.item == item then return spot.value, spot end
    end
    return 0
end

function Page.DrawStrip()
    local item = TopItem()
    strip:SetShown(item ~= nil)
    if not item then return end
    local value, spot = NodeValueOf(item)
    local kind, need = spot and spot.kind, spot and spot.need
    if picked.kind == "fish" then kind, need, value = "fish", Farm.catchNeed, Farm.catchWorth end
    strip.icon.texture:SetTexture(C_Item.GetItemIconByID(item))
    strip.icon.item = item
    strip.name:SetText(C_Item.GetItemNameByID(item) or "")
    strip.need:SetText(kind and TEXT_NEEDS[kind]:format(need) or "")
    local scan = ns.AuctionPrice and ns.AuctionPrice(item)
    strip.price:SetText(scan and Parts.Coins(scan) or "")
    strip.priceNote:SetText(scan and TEXT_SCAN_PRICE or TEXT_NO_PRICE)
    local have = C_Item.GetItemCount(item)
    strip.have:SetText(have)
    strip.worth:SetText(Parts.Coins(Market.AfterCut(scan or 0) * have, true))
    strip.node:SetText(Parts.Coins(value, true))
    strip.node.key:SetText(TEXT_A[kind] or TEXT_A_NODE)
    strip.spark:Paint(item)
    strip.sell:SetShown(Market.Dock.Shown() and have > 0)
    ns.SetButtonText(strip.sell, TEXT_SELL:format(have))
    strip.sell.item = item
end

local function DrawMap()
    local info, scale
    if picked.map then
        Farm.Zone(picked.map, picked.kind)
        info, scale = Fit()
    end
    canvas:SetShown(info ~= nil)
    mapHead:SetShown(picked.map ~= nil)
    if not info then
        strip:Hide()
        return
    end
    DrawTiles(info, scale)
    local width, height = canvas:GetSize()
    DrawPins(width, height)
    DrawLoop(width, height)
    local mapInfo = C_Map.GetMapInfo(picked.map)
    nameText:SetText(mapInfo and mapInfo.name or "")
    local stops = #Farm.loop
    subText:SetText(stops > 0 and TEXT_SUB:format(stops, math.floor(Farm.loopMinutes + 0.5),
        Parts.Coins(Farm.loopPerHour, true)) or picked.kind == "fish" and TEXT_NO_POOLS or TEXT_NO_LOOP)
    Enable(loopButton, stops > 0)
    Page.DrawStrip()
end

local function PickZone(zones)
    for _, zone in ipairs(zones) do
        if Picked(zone) then return end
    end
    local here = ns.Shared.Places.SameMap(C_Map.GetBestMapForUnit("player"))
    local pick = zones[1]
    for _, zone in ipairs(zones) do
        if zone.map == here then
            pick = zone
            break
        end
    end
    picked.map, picked.kind = pick and pick.map, pick and pick.kind
end

function Page.Draw()
    if not active then return end
    local zones = DrawZones()
    PickZone(zones)
    for _, row in ipairs(zoneRows) do
        if row:IsShown() then row.picked:SetShown(Picked(row.zone)) end
    end
    DrawMap()
end

local function OpenClicked()
    ns.Shared.Places.ShowMap(picked.map)
end

local function LoopClicked()
    local info = C_Map.GetMapInfo(picked.map)
    local title = TEXT_LOOP_TITLE:format(info and info.name or "")
    ns.PlaceWaypointRoute(title, Farm.Stops(title))
end

local function SellClicked(button)
    local entry = Market.Bags.Get(button.item)
    if entry then Market.Dock.Pick(Market.Bags.Location(entry, true)) end
end

local function PaintFilter(filter)
    local on = S.Get(filter.key)
    filter.tick:SetShown(on)
    local c = on and T.fg or T.muted
    filter.label:SetTextColor(c.r, c.g, c.b)
end

local function FilterClicked(filter)
    S.Set(filter.key, not S.Get(filter.key))
    PaintFilter(filter)
    Farm.Changed()
    picked.item = nil
    Page.Draw()
end

local function NewFilter(parent, key, text, i)
    local filter = CreateFrame("Button", nil, parent)
    filter:SetHeight(FILTER_H)
    filter:SetPoint("TOPLEFT", ROW_IN, -(ROW_IN + (i - 1) * FILTER_H))
    filter:SetPoint("RIGHT", -ROW_IN, 0)
    filter.key = key
    filter.box = ns.Solid(filter, "ARTWORK", T.fg, St.PANEL_FILL * 4)
    filter.box:SetSize(TICK, TICK)
    filter.box:SetPoint("LEFT")
    filter.tick = filter:CreateTexture(nil, "OVERLAY")
    filter.tick:SetAllPoints(filter.box)
    filter.tick:SetTexture(St.TICK)
    filter.tick:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
    filter.label = ns.Font(filter, TEXT_SIZE, nil, T.fg)
    filter.label:SetPoint("LEFT", filter.box, "RIGHT", GAP, 0)
    filter.label:SetText(text)
    filter:SetScript("OnClick", FilterClicked)
    filters[#filters + 1] = filter
    PaintFilter(filter)
end

local function BuildZones()
    zonePane = CreateFrame("Frame", nil, page)
    zonePane:SetPoint("TOPLEFT")
    zonePane:SetPoint("BOTTOMLEFT")
    zonePane:SetWidth(ZONES_W)
    Panel(zonePane)
    local title = ns.Font(zonePane, St.TITLE_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT", ROW_IN, -ROW_IN)
    title:SetText(TEXT_BEST)
    skillsText = ns.Font(zonePane, SMALL_SIZE, nil, T.muted)
    skillsText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -SUB_GAP)
    skillsText:SetPoint("RIGHT", -ROW_IN, 0)
    skillsText:SetJustifyH("LEFT")
    local box = CreateFrame("Frame", nil, zonePane)
    box:SetPoint("BOTTOMLEFT")
    box:SetPoint("BOTTOMRIGHT")
    box:SetHeight(FILTERS_H)
    NewFilter(box, "farmHerbs", TEXT_HERBS, 1)
    NewFilter(box, "farmVeins", TEXT_VEINS, 2)
    NewFilter(box, "farmSkins", TEXT_SKINS, 3)
    NewFilter(box, "farmFish", TEXT_FISH, 4)
    NewFilter(box, "farmLocked", TEXT_LOCKED, 5)
    NewFilter(box, "farmPlan", TEXT_PLAN, 6)
    zoneScroll = ns.UI.SlimScroll(zonePane)
    zoneScroll:SetPoint("TOPLEFT", 0, -HEAD_H)
    zoneScroll:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -(St.SCROLLBAR + SCROLL_IN), 0)
    zoneList = CreateFrame("Frame", nil, zoneScroll)
    zoneList:SetWidth(ZONES_W - St.SCROLLBAR - SCROLL_IN)
    zoneList:SetHeight(1)
    zoneScroll:SetScrollChild(zoneList)
    zoneNote = ns.Font(zonePane, SMALL_SIZE, nil, T.muted)
    zoneNote:SetPoint("TOPLEFT", ROW_IN, -HEAD_H)
    zoneNote:SetPoint("RIGHT", -ROW_IN, 0)
    zoneNote:SetJustifyH("LEFT")
end

local function KV(parent, label, row)
    local key = ns.Font(parent, SMALL_SIZE, nil, T.muted)
    key:SetPoint("TOPLEFT", 0, -(row - 1) * (SMALL_SIZE + SUB_GAP * 2))
    key:SetText(label)
    local value = ns.Font(parent, SMALL_SIZE, nil, T.fg)
    value:SetPoint("TOPRIGHT", 0, -(row - 1) * (SMALL_SIZE + SUB_GAP * 2))
    value.key = key
    return value
end

local function BuildStrip()
    strip = CreateFrame("Frame", nil, main)
    strip:SetPoint("BOTTOMLEFT")
    strip:SetPoint("BOTTOMRIGHT")
    strip:SetHeight(STRIP_H)
    Panel(strip)
    strip.icon = Parts.ItemIcon(strip, STRIP_ICON)
    strip.icon:SetPoint("LEFT", ROW_IN, 0)
    ItemTip(strip.icon)
    strip.name = ns.Font(strip, TEXT_SIZE, nil, T.fg, true)
    strip.name:SetPoint("TOPLEFT", strip.icon, "TOPRIGHT", ROW_IN, 0)
    strip.need = ns.Font(strip, SMALL_SIZE, nil, T.muted)
    strip.need:SetPoint("TOPLEFT", strip.name, "BOTTOMLEFT", 0, -SUB_GAP)
    strip.price = ns.Font(strip, TEXT_SIZE, nil, T.fg)
    strip.price:SetPoint("BOTTOMLEFT", strip.icon, "BOTTOMRIGHT", ROW_IN, 0)
    strip.priceNote = ns.Font(strip, SMALL_SIZE, nil, T.muted)
    strip.priceNote:SetPoint("LEFT", strip.price, "RIGHT", GAP, 0)
    strip.sell = ns.Button(strip, "", OPEN_W, BUTTON_H, SellClicked)
    ns.PrimaryButton(strip.sell)
    strip.sell:SetPoint("RIGHT", -ROW_IN, 0)
    local kv = CreateFrame("Frame", nil, strip)
    kv:SetSize(KV_W, STRIP_H - ROW_IN * 2)
    kv:SetPoint("RIGHT", strip.sell, "LEFT", -PANE_GAP, 0)
    strip.have = KV(kv, TEXT_HAVE, 1)
    strip.worth = KV(kv, TEXT_WORTH, 2)
    strip.node = KV(kv, TEXT_A_NODE, 3)
    strip.spark = Spark.New(strip, SPARK_W, SPARK_H)
    strip.spark:SetPoint("RIGHT", kv, "LEFT", -PANE_GAP, -SUB_GAP)
end

local function BuildMain()
    main = CreateFrame("Frame", nil, page)
    main:SetPoint("TOPLEFT", ZONES_W + PANE_GAP, 0)
    main:SetPoint("BOTTOMRIGHT")
    mapHead = CreateFrame("Frame", nil, main)
    mapHead:SetPoint("TOPLEFT")
    mapHead:SetPoint("TOPRIGHT")
    mapHead:SetHeight(MAP_HEAD_H)
    nameText = ns.Font(mapHead, St.TITLE_SIZE, nil, T.fg, true)
    nameText:SetPoint("TOPLEFT")
    subText = ns.Font(mapHead, SMALL_SIZE, nil, T.muted)
    subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -SUB_GAP)
    loopButton = ns.Button(mapHead, TEXT_LOOP, LOOP_W, BUTTON_H, LoopClicked)
    ns.PrimaryButton(loopButton)
    loopButton:SetPoint("TOPRIGHT")
    ns.Tooltip(loopButton, TEXT_LOOP, TEXT_LOOP_TIP)
    openButton = ns.Button(mapHead, TEXT_OPEN, OPEN_W, BUTTON_H, OpenClicked)
    openButton:SetPoint("RIGHT", loopButton, "LEFT", -GAP, 0)
    canvas = CreateFrame("Frame", nil, main)
    canvas:SetPoint("TOP", mapHead, "BOTTOM", 0, -GAP)
    canvas:SetClipsChildren(true)
    ns.Border(canvas, St.BORDER_RGB)
    BuildStrip()
end

function Page.Build(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    BuildZones()
    BuildMain()
end

function Page.Show()
    page:Show()
    active = true
    Page.Draw()
end

function Page.Hide()
    page:Hide()
    active = false
end
