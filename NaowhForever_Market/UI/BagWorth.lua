-- BagWorth.lua: Bag Worth, a card on your bags with what they would fetch and their most valuable items, numbered on their slots.
local ns = _G.NaowhForever

local T = ns.THEME
local Market = ns.Market
local S = Market.Settings
local St = Market.Style
local C = Market.C
local Parts = ns.Shared.Parts
local Bags = ns.Shared.Bags
local Worth = Market.Worth

local CARD_W, PAD, HEAD_H, ROW_H, ICON, GAP, CARD_GAP = 260, 8, 20, 22, 18, 6, 4
local BADGE, BADGE_OUT, BADGE_LEVEL, BADGE_SIZE = 15, 3, 5, 10
local REFRESH_DELAY = 0.2
local OVERLAY = "NaowhForeverMarketWorth"
local TEXT_TITLE = ns.L("Most Valuable")
local TEXT_TOTAL = ns.L("Bags worth %s")
local TEXT_SCANNED = ns.L("At your scan %s ago, after the auction house's cut")
local TEXT_NO_SCAN = ns.L("At vendor prices: no auction house scan yet")
local TEXT_SELL = ns.L("Click to sell it")
local TEXT_COUNT = "%s |cff808080x%d|r"

local card, title, total, note
local rows, badges = {}, {}
local dirty, pending, registered = true, false, false
local events

local function On()
    return Market.On() and S.Get("bagWorth")
end

local function Read()
    if dirty then
        Worth.Read()
        dirty = false
    end
end

local function Host()
    local eui = registered and _G.EUI_Bags
    if eui and eui:IsVisible() then return eui, true end
    local combined = ContainerFrameCombinedBags
    if combined and combined:IsShown() then return combined, true end
    local list = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    for i = 1, list and #list or 0 do
        if list[i]:IsShown() and list[i]:GetID() == BACKPACK_CONTAINER then return list[i], false end
    end
end

local function RowEnter(row)
    row.hover:Show()
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:SetBagItem(row.entry.bag, row.entry.slot)
    if Market.Window.AtAuction() then
        local c = T.accentSoft
        GameTooltip:AddLine(TEXT_SELL, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RowClick(row)
    if not Market.Window.AtAuction() then return end
    Market.Window.ShowPage("sell")
    Market.Pages.sell.PickLocation(ItemLocation:CreateFromBagAndSlot(row.entry.bag, row.entry.slot))
end

local function NewRow(i)
    local row = CreateFrame("Button", nil, card)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", PAD, -(PAD + HEAD_H + (i - 1) * ROW_H))
    row:SetPoint("RIGHT", -PAD, 0)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.PANEL_FILL)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.rank = CreateFrame("Frame", nil, row)
    row.rank:SetSize(BADGE, BADGE)
    row.rank:SetPoint("LEFT")
    row.rank.dot = row.rank:CreateTexture(nil, "ARTWORK")
    row.rank.dot:SetAllPoints()
    row.rank.dot:SetTexture(St.ROUND)
    row.rank.dot:SetVertexColor(St.GOLD_RGB.r, St.GOLD_RGB.g, St.GOLD_RGB.b)
    row.rank.text = ns.Font(row.rank, BADGE_SIZE, nil, St.BADGE_TEXT_RGB, true)
    row.rank.text:SetPoint("CENTER")
    row.icon = Parts.ItemIcon(row, ICON)
    row.icon:SetPoint("LEFT", row.rank, "RIGHT", GAP, 0)
    row.worth = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.worth:SetPoint("RIGHT")
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
    row.name:SetPoint("RIGHT", row.worth, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    rows[i] = row
    return row
end

local function Build()
    card = CreateFrame("Frame", nil, UIParent)
    card:SetWidth(CARD_W)
    card.backdrop = Parts.Backdrop(card)
    ns.Border(card, St.BORDER_RGB)
    title = ns.Font(card, St.TEXT_SIZE, nil, T.fg, true)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(TEXT_TITLE)
    total = ns.Font(card, St.TEXT_SIZE, nil, T.fg)
    total:SetPoint("TOPRIGHT", -PAD, -PAD)
    note = ns.Font(card, St.SMALL_SIZE, nil, T.muted)
    note:SetPoint("BOTTOMLEFT", PAD, PAD)
    note:SetPoint("RIGHT", -PAD, 0)
    note:SetJustifyH("LEFT")
end

local function PaintRow(row, entry, i)
    row.entry = entry
    row.rank.text:SetText(i)
    row.icon.texture:SetTexture(entry.icon)
    local color = ITEM_QUALITY_COLORS[entry.quality] or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    local name = C_Item.GetItemNameByID(entry.itemID) or ""
    row.name:SetText(entry.count > 1 and TEXT_COUNT:format(name, entry.count) or name)
    row.worth:SetText(Parts.Coins(entry.worth, true))
    row:Show()
end

local function Draw()
    local host, above = Host()
    if not (On() and host) then
        if card then card:Hide() end
        return
    end
    if not card then Build() end
    Read()
    local shown = math.min(C.WORTH_TOP, #Worth.items)
    for i = 1, shown do PaintRow(rows[i] or NewRow(i), Worth.items[i], i) end
    for i = shown + 1, #rows do rows[i]:Hide() end
    total:SetText(TEXT_TOTAL:format(Parts.Coins(Worth.total, true)))
    local at = ns.AuctionScanTime and ns.AuctionScanTime()
    local age = ns.AuctionAge
    note:SetText(at and age and TEXT_SCANNED:format(age(GetServerTime() - at)) or TEXT_NO_SCAN)
    card:SetHeight(PAD + HEAD_H + shown * ROW_H + GAP + St.SMALL_SIZE + PAD)
    card:SetParent(host)
    card:SetFrameStrata(host:GetFrameStrata())
    card:ClearAllPoints()
    if above then
        card:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, CARD_GAP)
    else
        card:SetPoint("TOPRIGHT", host, "TOPLEFT", -CARD_GAP, 0)
    end
    card.backdrop:Paint(1)
    card:Show()
end

local function Badge(button)
    local badge = CreateFrame("Frame", nil, button)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("TOPLEFT", -BADGE_OUT, BADGE_OUT)
    badge:SetFrameLevel(button:GetFrameLevel() + BADGE_LEVEL)
    badge.dot = badge:CreateTexture(nil, "ARTWORK")
    badge.dot:SetAllPoints()
    badge.dot:SetTexture(St.ROUND)
    badge.dot:SetVertexColor(St.GOLD_RGB.r, St.GOLD_RGB.g, St.GOLD_RGB.b)
    badge.text = ns.Font(badge, BADGE_SIZE, nil, St.BADGE_TEXT_RGB, true)
    badge.text:SetPoint("CENTER")
    badges[button] = badge
    return badge
end

local function Mark(button, itemID, bag, slot)
    local rank = On() and itemID and Worth.First(itemID, bag, slot) and Worth.Rank(itemID)
    local badge = badges[button]
    if not rank then
        if badge then badge:Hide() end
        return
    end
    badge = badge or Badge(button)
    badge.text:SetText(rank)
    badge:Show()
end

local function MarkGame(frame)
    Read()
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button:GetBagID(), button:GetID()
        Mark(button, C_Container.GetContainerItemID(bag, slot), bag, slot)
    end
end

local function Ran()
    pending = false
    if dirty and On() then
        Read()
        Bags.RepaintGame(MarkGame)
        if registered then Bags.RefreshEllesmere() end
    end
    Draw()
end

local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(REFRESH_DELAY, Ran)
end

local function GameBag(frame)
    if not On() then return end
    MarkGame(frame)
    Soon()
end

local function EllesmereSlot(button, data)
    Read()
    local info = data.info
    Mark(button, info and info.itemID, data.bag, data.slot)
    Soon()
end

local function Changed()
    dirty = true
    Soon()
end

local function OnEvent()
    Changed()
end

local function Apply()
    local on = On()
    if on and not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
        Bags.OnGameUpdate(GameBag)
    end
    if events then
        if on then events:RegisterEvent("BAG_UPDATE_DELAYED") else events:UnregisterAllEvents() end
    end
    local bags = Bags.Ellesmere()
    if bags and on ~= registered then
        registered = on
        if on then
            bags.RegisterItemOverlayIcon(OVERLAY, EllesmereSlot)
        else
            bags.UnregisterItemOverlayIcon(OVERLAY)
        end
    end
    if not on then
        for _, badge in pairs(badges) do badge:Hide() end
    end
    dirty = true
    if events then Bags.RepaintGame(MarkGame) end
    Draw()
end

Market.BagWorth = { Changed = Changed }

S.OnChange(function(key)
    if key == "enabled" or key == "bagWorth" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
