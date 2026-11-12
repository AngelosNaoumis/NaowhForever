-- DestroyCheapestPopup.lua: the bags-full popup, its ignore list and its settings card.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo

local D = ns.DestroyCheapest
local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local Coins = Parts.Coins
local TEXT = D.TEXT

local PAD, GAP, HEADER, CARD_H, ICON = 10, 8, 36, 124, 36
local QTY_IN, QTY_SIZE, QTY_LEVEL = 2, 12, 4
local CARD_ALPHA = 0.45
local POPUP_W = St.PANEL_W
local CARD_W = (POPUP_W - PAD * 2 - GAP) / 2
local BUTTON_H, NOTE_H, ANYWAY_H = 24, 40, 18
local PAGER_W, PAGER_H = 22, 18
local FONT_CAPTION, FONT_NOTE, FONT_NAME = 10, 11, 12
local CARD_INSET, PAGER_PAD, NAME_DROP, NAME_NUDGE, LINE_GAP = 2, 4, 4, 2, 1
local PASS_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local PASS_GLOW = "Interface\\Buttons\\UI-GroupLoot-Pass-Highlight"
local HOME_Y, OVER_LOOT = 140, 20
local ANCHOR = {
    top = { "BOTTOMLEFT", "TOPLEFT", 0, 1 },
    bottom = { "TOPLEFT", "BOTTOMLEFT", 0, -1 },
    left = { "TOPRIGHT", "TOPLEFT", -1, 0 },
    right = { "TOPLEFT", "TOPRIGHT", 1, 0 },
}
local LIST = {
    w = 440, h = 480, row = 30, icon = 24, inset = 2, remove = 22, gap = 8,
    text = 12, head = 14, side = 16, top = 72, right = 36, bottom = 52,
    searchY = 40, searchH = 24, buttonW = 110, buttonH = 24, buttonY = 16,
}

local popup, destroyCard, lootCard, note, action, anywayBtn, ignorePanel, placing

local function SavedPos()
    local pos = S.Get("destroyCheapestPos")
    if type(pos) ~= "table" or type(pos.point) ~= "string" then return end
    return pos
end

local function Place(center)
    if placing or not popup then return end
    placing = true
    popup:ClearAllPoints()
    local pos = SavedPos()
    if pos then
        popup:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        placing = false
        return
    end
    if not center and D.LootShown() then
        popup:SetFrameLevel(LootFrame:GetFrameLevel() + OVER_LOOT)
        local side = ANCHOR[S.Get("destroyCheapestSide")] or ANCHOR.top
        popup:SetPoint(side[1], LootFrame, side[2], side[3] * GAP, side[4] * GAP)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
    placing = false
end

local function ClearLoot()
    for i = #D.loots, 1, -1 do D.loots[i] = nil end
    D.lootUsed = 0
    D.lootIndex = 1
    if lootCard then
        lootCard.entry = nil
        lootCard:Hide()
    end
    if D.pending then D.pending.lootSlot = nil end
end

local function Settle(lootEnded)
    if not D.Opened() and not D.pending then
        if lootEnded and D.lootUsed > 0 then ClearLoot() end
        return
    end
    if lootEnded or not D.LootShown() then ClearLoot() end
    if not D.Opened() then return end
    local lootOpen = not lootEnded and D.LootShown()
    if D.pending or lootOpen or D.TransferShown() then
        if not lootOpen and not SavedPos() and not D.dragging then Place(true) end
        if lootOpen and not D.pending then D.ReadLoot() end
        D.Paint()
        return
    end
    popup:Hide()
end

local function FollowLoot()
    if placing or D.dragging or not D.Opened() or SavedPos() then return end
    Place()
end

function D.HookLoot()
    if D.lootHooked then return end
    D.lootHooked = true
    LootFrame:HookScript("OnShow", FollowLoot)
    LootFrame:HookScript("OnHide", function() Settle(true) end)
end

function D.HookTransfers()
    if not S.Get("destroyCheapestTransfers") then return end
    local frames = D.TRANSFER_FRAMES
    for i = 1, #frames do
        local name = frames[i]
        local frame = not D.transferHooks[name] and _G[name]
        if type(frame) == "table" and frame.HookScript then
            D.transferHooks[name] = true
            frame:HookScript("OnHide", function() Settle(false) end)
        end
    end
end

local function StepDestroy(delta)
    if D.pending or #D.picks < 2 then return end
    D.armed = false
    D.index = D.index + delta
    if D.index < 1 then D.index = #D.picks end
    if D.index > #D.picks then D.index = 1 end
    D.Paint()
end

local function StepLoot(delta)
    if D.pending or #D.loots < 2 then return end
    D.lootIndex = D.lootIndex + delta
    if D.lootIndex < 1 then D.lootIndex = #D.loots end
    if D.lootIndex > #D.loots then D.lootIndex = 1 end
    D.Paint()
end

local function NewCard(parent, caption, step)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    if card.SetClipsChildren then card:SetClipsChildren(true) end
    ns.Solid(card, "BACKGROUND", T.bg, CARD_ALPHA):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    card.caption = ns.Font(card, FONT_CAPTION, nil, T.muted, true)
    card.caption:SetPoint("TOPLEFT", PAD - CARD_INSET, -(GAP - CARD_INSET))
    card.caption:SetText(caption)
    card.icon = Parts.ItemIcon(card, ICON)
    card.icon:SetPoint("TOPLEFT", PAD - CARD_INSET, -BUTTON_H)
    local qty = CreateFrame("Frame", nil, card.icon)
    qty:SetAllPoints()
    qty:SetFrameLevel(card.icon:GetFrameLevel() + QTY_LEVEL)
    card.qty = ns.Font(qty, QTY_SIZE, "OUTLINE", T.fg)
    card.qty:SetJustifyH("RIGHT")
    card.qty:SetPoint("BOTTOMRIGHT", -QTY_IN, QTY_IN)
    card.qty:Hide()
    card.name = ns.Font(card, FONT_NAME, nil, T.fg)
    card.name:SetJustifyH("LEFT")
    card.value = ns.Font(card, FONT_NAME, nil, T.fg)
    card.value:SetJustifyH("LEFT")
    card.market = ns.Font(card, FONT_NOTE, nil, T.muted)
    card.market:SetJustifyH("LEFT")
    card.market:SetWordWrap(false)
    card.market:Hide()
    card.prev = ns.Button(card, "<", PAGER_W, PAGER_H, function() step(-1) end)
    card.next = ns.Button(card, ">", PAGER_W, PAGER_H, function() step(1) end)
    card.count = ns.Font(card, FONT_NOTE, nil, T.muted)
    card.prev:SetPoint("BOTTOMLEFT", GAP - CARD_INSET, GAP - PAGER_PAD)
    card.next:SetPoint("BOTTOMRIGHT", -(GAP - CARD_INSET), GAP - PAGER_PAD)
    card.count:SetPoint("BOTTOM", 0, GAP - CARD_INSET)
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        local e = self.entry
        if not (e and (e.bag or e.link)) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.bag then GameTooltip:SetBagItem(e.bag, e.slot) else GameTooltip:SetHyperlink(e.link) end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        if self.ignore and self.ignore:IsMouseOver() then return end
        GameTooltip:Hide()
    end)
    return card
end

local function FillCard(card, e, blank, at, total)
    card.entry = e
    local many = e and total > 1
    card.prev:SetShown(many == true)
    card.next:SetShown(many == true)
    card.count:SetShown(many == true)
    if many then card.count:SetText(TEXT.COUNT:format(at, total)) end
    card.name:ClearAllPoints()
    card.value:ClearAllPoints()
    card.market:ClearAllPoints()
    card.market:Hide()
    if not e then
        card.icon:Hide()
        card.qty:Hide()
        card.name:SetPoint("TOPLEFT", PAD - CARD_INSET, -(BUTTON_H + NAME_DROP))
        card.name:SetPoint("RIGHT", card, "RIGHT", -(PAD - CARD_INSET), 0)
        card.name:SetWordWrap(true)
        card.name:SetText(blank)
        card.name:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        card.value:Hide()
        if card.ignore then card.ignore:Hide() end
        return
    end
    card.icon:Show()
    card.icon.texture:SetTexture(e.icon)
    local count = e.count or 1
    card.qty:SetShown(count > 1)
    if count > 1 then card.qty:SetText(count) end
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", GAP - CARD_INSET, NAME_NUDGE)
    card.name:SetPoint("RIGHT", card, "RIGHT", -(PAD - CARD_INSET), 0)
    card.name:SetWordWrap(false)
    card.name:SetText(e.name or "")
    local c = ITEM_QUALITY_COLORS[e.quality]
    if c then
        card.name:SetTextColor(c.r, c.g, c.b)
    else
        card.name:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
        c = St.BORDER_RGB
    end
    card.icon.edge:SetColor(c.r, c.g, c.b, 1)
    local anchor = card.name
    if e.value and e.value > 0 then
        card.value:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -LINE_GAP)
        card.value:SetPoint("RIGHT", card, "RIGHT", -(PAD - CARD_INSET), 0)
        card.value:SetText(Coins(e.value))
        card.value:Show()
        anchor = card.value
    else
        card.value:Hide()
    end
    if D.UseMarket() and e.itemID and not e.marketChecked then
        e.marketChecked = true
        local price, age, fresh = D.Quote(e.itemID)
        if price then
            e.market = price * (e.count or 1)
            e.marketAge, e.marketFresh = age, fresh
        end
    end
    if D.UseMarket() and e.market then
        local age = type(e.marketAge) == "number" and ns.AuctionAge and ns.AuctionAge(e.marketAge)
        local coins = Coins(e.market)
        card.market:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -LINE_GAP)
        card.market:SetPoint("RIGHT", card, "RIGHT", -(PAD - CARD_INSET), 0)
        card.market:SetText(age and TEXT.MARKET_OLD:format(coins, age) or TEXT.MARKET:format(coins))
        local tint = e.marketFresh and T.fg or T.muted
        card.market:SetTextColor(tint.r, tint.g, tint.b)
        card.market:Show()
    end
    if not card.ignore then return end
    local show = total ~= 0
    card.ignore:SetShown(show)
    card.next:ClearAllPoints()
    if show then
        card.next:SetPoint("BOTTOMRIGHT", card.ignore, "BOTTOMLEFT", -(GAP - CARD_INSET), 0)
    else
        card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -(GAP - CARD_INSET), GAP - PAGER_PAD)
    end
end

local function ConfirmLabel(pick)
    local name = pick and (pick.link or pick.name)
    if type(name) == "string" and name ~= "" then return TEXT.CONFIRM .. " " .. name end
    return TEXT.CONFIRM
end

local function ButtonLabel(loot, pick)
    if D.armed then return ConfirmLabel(pick) end
    if loot then return TEXT.DESTROY_LOOT end
    return TEXT.DESTROY_ONLY
end

local function Layout(noteText, showButton, showAnyway)
    local y = HEADER + CARD_H + GAP
    if noteText then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", PAD, -y)
        note:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
        note:SetText(noteText)
        note:Show()
        y = y + NOTE_H
    else
        note:Hide()
    end
    action:Hide()
    anywayBtn:Hide()
    if showButton then
        action:ClearAllPoints()
        action:SetPoint("TOPLEFT", PAD, -y)
        action:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
        action:SetHeight(BUTTON_H)
        action:Show()
        y = y + BUTTON_H + GAP
    elseif showAnyway then
        anywayBtn:ClearAllPoints()
        anywayBtn:SetPoint("TOPLEFT", PAD, -y)
        anywayBtn:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
        anywayBtn:SetHeight(ANYWAY_H)
        anywayBtn:Show()
        y = y + ANYWAY_H + GAP
    end
    popup:SetHeight(y + PAD)
end

local function FitCards(showLoot)
    lootCard:SetShown(showLoot)
    destroyCard:ClearAllPoints()
    destroyCard:SetPoint("TOPLEFT", PAD, -HEADER)
    if showLoot then
        destroyCard:SetWidth(CARD_W)
        lootCard:SetWidth(CARD_W)
        lootCard:ClearAllPoints()
        lootCard:SetPoint("TOPLEFT", destroyCard, "TOPRIGHT", GAP, 0)
        return
    end
    destroyCard:SetWidth(POPUP_W - PAD * 2)
end

local function RememberArmed(pick)
    if not (pick and pick.bag == D.armedBag and pick.slot == D.armedSlot and pick.itemID == D.armedID) then
        D.armed = false
    end
    if D.armed and pick then
        D.armedBag, D.armedSlot, D.armedID = pick.bag, pick.slot, pick.itemID
    else
        D.armedBag, D.armedSlot, D.armedID = nil, nil, nil
    end
end

function D.Paint()
    if not popup then return end
    local pick, loot = D.picks[D.index], D.loots[D.lootIndex]
    RememberArmed(pick)
    local showLoot = loot ~= nil
    FitCards(showLoot)
    FillCard(destroyCard, pick, TEXT.BLANK_DESTROY, D.index, D.pending and 0 or #D.picks)
    if showLoot then
        FillCard(lootCard, loot, nil, D.lootIndex, D.pending and 0 or #D.loots)
    end
    local noteText, showButton, showAnyway
    if D.pending then
        if D.pending.mode == "dialog" then noteText = TEXT.DIALOG
        elseif D.pending.mode == "cursor" then noteText = TEXT.STUCK
        else noteText = TEXT.WAITING
        end
    elseif not pick then
        noteText = TEXT.NONE
    else
        if loot and not D.WorthIt(pick, loot) then
            noteText = TEXT.NOT_WORTH
            if S.Get("destroyCheapestAnyway") then
                showAnyway = true
                ns.SetButtonText(anywayBtn, D.armed and ConfirmLabel(pick) or TEXT.ANYWAY)
            end
        else
            showButton = true
            ns.SetButtonText(action, ButtonLabel(loot, pick))
            if not loot and D.TransferShown() then noteText = TEXT.AGAIN end
        end
    end
    Layout(noteText, showButton, showAnyway)
end

local function TintAnyway(btn)
    if btn.redArt then
        for i = 1, #btn.redArt do btn.redArt[i]:Hide() end
    end
    if btn.redRim then btn.redRim:Hide() end
    if btn._bg then btn._bg:Show() end
    local function paint(hot)
        if not btn._bg then return end
        local fill = hot and T.fg or T.muted
        btn._bg:SetColorTexture(fill.r, fill.g, fill.b, 1)
        if btn.label then btn.label:SetTextColor(T.bg.r, T.bg.g, T.bg.b, 1) end
        if btn._border and not btn._forever and btn._border.SetColor then
            btn._border:SetColor(T.fg.r, T.fg.g, T.fg.b, 1)
        end
    end
    paint(false)
    btn:SetScript("OnEnter", function() paint(true) end)
    btn:SetScript("OnLeave", function() paint(false) end)
    btn:SetScript("OnMouseDown", nil)
    btn:SetScript("OnMouseUp", nil)
end

local function OnIgnore()
    if D.pending or not D.On() then return end
    local pick = D.picks[D.index]
    if not pick then return end
    D.IgnoreAdd(pick.itemID)
    D.armed = false
    ns.Print(TEXT.IGNORED:format(pick.link or pick.name or pick.itemID))
    if ignorePanel and ignorePanel:IsShown() then D.FillIgnore() end
    D.Refresh()
end

function D.Build()
    popup = Parts.Panel("Bags Are Full", true)
    D.popup = popup
    popup:Hide()
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self)
        if not S.Get("destroyCheapestMovable") then return end
        D.dragging = true
        self:StartMoving()
    end)
    popup:SetScript("OnDragStop", function(self)
        if not D.dragging then return end
        D.dragging = false
        self:StopMovingOrSizing()
        local pos = UI.CenterPosition(self)
        if pos then S.Set("destroyCheapestPos", pos) end
    end)
    popup.backdrop:Paint(1)
    destroyCard = NewCard(popup, TEXT.DESTROY, StepDestroy)
    lootCard = NewCard(popup, TEXT.LOOT, StepLoot)
    lootCard:Hide()
    destroyCard:SetPoint("TOPLEFT", PAD, -HEADER)
    destroyCard:SetWidth(POPUP_W - PAD * 2)
    note = ns.Font(popup, FONT_NOTE, nil, T.muted)
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    action = ns.Button(popup, TEXT.DESTROY_LOOT, POPUP_W - PAD * 2, BUTTON_H, D.OnDestroy)
    ns.PrimaryButton(action)
    anywayBtn = ns.Button(popup, TEXT.ANYWAY, POPUP_W - PAD * 2, ANYWAY_H, D.OnAnyway)
    destroyCard.ignore = CreateFrame("Button", nil, destroyCard)
    destroyCard.ignore:SetSize(St.ACTION, St.ACTION)
    destroyCard.ignore:SetPoint("BOTTOMRIGHT", -(GAP - CARD_INSET), GAP - PAGER_PAD)
    destroyCard.ignore:SetFrameLevel(destroyCard:GetFrameLevel() + 2)
    destroyCard.ignore:SetNormalTexture(PASS_ICON)
    destroyCard.ignore:SetHighlightTexture(PASS_GLOW, "ADD")
    destroyCard.ignore:SetScript("OnClick", OnIgnore)
    destroyCard.ignore:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L("Ignore Item"))
        GameTooltip:Show()
    end)
    destroyCard.ignore:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local card = self:GetParent()
        if not card:IsMouseOver() then return end
        local enter = card:GetScript("OnEnter")
        if enter then enter(card) end
    end)
    destroyCard.ignore:Hide()
    anywayBtn:Hide()
    TintAnyway(anywayBtn)
    popup:HookScript("OnHide", function()
        GameTooltip:Hide()
        if D.dragging then
            D.dragging = false
            popup:StopMovingOrSizing()
        end
        if not D.LootShown() then ClearLoot() end
        if not D.pending then
            D.armed = false
            wipe(D.requested)
            wipe(D.waitingInfo)
            D.Listen(false)
        end
    end)
end

function D.Refresh()
    if D.pending or D.scanning then
        if D.scanning then D.scanAgain = true end
        return
    end
    if not D.Opened() then return end
    if D.PlainFree() > 0 or not (D.LootShown() or D.TransferShown()) then
        popup:Hide()
        return
    end
    D.Listen(true)
    D.Scan()
    D.ReadLoot()
    D.FlushLoads()
    D.Paint()
end

local function Show()
    if not D.On() or ns.GamepadStandDown() then return end
    if D.PlainFree() > 0 then
        if D.Opened() then popup:Hide() end
        return
    end
    D.HookTransfers()
    if not popup then D.Build() end
    local was = D.Opened()
    if not was then wipe(D.requested) end
    D.Listen(true)
    if not was then Place() end
    popup:Show()
    D.Scan()
    D.ReadLoot()
    D.FlushLoads()
    D.Paint()
end

function D.Listen(open)
    D.watch:UnregisterAllEvents()
    if not D.On() then
        if D.held then D.watch:RegisterEvent("PLAYER_REGEN_ENABLED") end
        return
    end
    D.watch:RegisterEvent("UI_ERROR_MESSAGE")
    if open or D.pending then
        D.watch:RegisterEvent("BAG_UPDATE_DELAYED")
        D.watch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        D.watch:RegisterEvent("LOOT_OPENED")
        D.watch:RegisterEvent("LOOT_CLOSED")
        D.watch:RegisterEvent("LOOT_SLOT_CLEARED")
    end
    if D.held then D.watch:RegisterEvent("PLAYER_REGEN_ENABLED") end
end

local function OnEvent(_, event, a, b)
    if event == "PLAYER_REGEN_ENABLED" then
        local held = D.held
        D.held = nil
        if held and D.CursorHolds(held.itemID) then D.ReturnCursor(held) end
        D.Listen(D.Opened())
        return
    end
    if event == "UI_ERROR_MESSAGE" then
        if not D.BagsFull(a, b) or D.pending then return end
        if not (D.LootShown() or D.TransferShown()) then return end
        return Show()
    end
    if event == "BAG_UPDATE_DELAYED" then
        if D.pending then return D.Resolve() end
        if D.Opened() then D.Refresh() end
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not D.waitingInfo[a] then return end
        D.waitingInfo[a] = nil
        if D.pending or not D.Opened() then return end
        return D.Refresh()
    end
    if event == "LOOT_CLOSED" then return Settle(not D.LootShown()) end
    if D.pending or not D.Opened() then return end
    D.ReadLoot()
    D.Paint()
end

D.watch:SetScript("OnEvent", OnEvent)

local function Apply()
    if not D.On() then
        local p = D.pending
        if p and D.CursorHolds(p.itemID) and InCombatLockdown() then
            D.held = { bag = p.bag, slot = p.slot, itemID = p.itemID }
        else
            D.ReleaseCursor()
            D.held = nil
        end
        D.pending = nil
        D.armed = false
        D.Listen(false)
        if popup then popup:Hide() end
        return
    end
    D.HookLoot()
    D.HookTransfers()
    D.Listen(D.Opened())
end

local function SettingChanged(key)
    if key == "enabled" or key == "destroyCheapest" then
        Apply()
        return
    end
    if not D.pending and (key == "destroyCheapestMarketRank"
        or key == "destroyCheapestMarketStale" or key == "destroyCheapestMarketDays") then
        D.index = 0
    end
    if not D.Opened() then return end
    if key == "destroyCheapestSide" or key == "destroyCheapestPos" then
        Place()
        return
    end
    if type(key) == "string" and key:find("^destroyCheapest", 1, true) and not D.pending then
        if key == "destroyCheapestTransfers" then D.HookTransfers() end
        D.Refresh()
    end
end

hooksecurefunc(S, "Set", SettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local function Newer(a, b)
    if a.when ~= b.when then return a.when > b.when end
    return a.id < b.id
end

local function SortedIgnored()
    local db = S.DB()
    local list = db and db.destroyCheapestIgnore
    local out = {}
    if type(list) ~= "table" then return out end
    for id, when in pairs(list) do
        if type(id) == "number" then
            out[#out + 1] = { id = id, when = type(when) == "number" and when or 0 }
        end
    end
    table.sort(out, Newer)
    return out
end

local function RemoveIgnored(itemID)
    local db = S.DB()
    local list = db and db.destroyCheapestIgnore
    if list then list[itemID] = nil end
    if ignorePanel and ignorePanel:IsShown() then D.FillIgnore() end
    if D.Opened() and not D.pending then D.Refresh() end
end

local function ClearIgnored()
    local db = S.DB()
    if type(db.destroyCheapestIgnore) == "table" then wipe(db.destroyCheapestIgnore) end
    if ignorePanel and ignorePanel:IsShown() then D.FillIgnore() end
    if D.Opened() and not D.pending then D.Refresh() end
end

local function AskClearIgnored()
    ns.Confirm(TEXT.CLEAR_ASK, ClearIgnored)
end

local function NewIgnoreRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(LIST.row)
    row:EnableMouse(true)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(LIST.icon, LIST.icon)
    row.icon:SetPoint("LEFT", row, "LEFT", LIST.inset, 0)
    row.icon:SetTexCoord(St.ICON_CROP, St.ICON_CROP_HIGH, St.ICON_CROP, St.ICON_CROP_HIGH)
    row.remove = ns.Button(row, "x", LIST.remove, LIST.remove, function() RemoveIgnored(row.id) end)
    row.remove:SetPoint("RIGHT", row, "RIGHT", -LIST.inset, 0)
    row.text = ns.Font(row, LIST.text, nil, T.fg)
    row.text:SetPoint("LEFT", row.icon, "RIGHT", LIST.gap, 0)
    row.text:SetPoint("RIGHT", row.remove, "LEFT", -LIST.gap, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.id)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function FillIgnoreRow(row, entry, name, quality)
    row.id = entry.id
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
    row.icon:SetTexture(icon)
    if name then
        local c = ITEM_QUALITY_COLORS[quality]
        if c then row.text:SetTextColor(c.r, c.g, c.b) else row.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b) end
        row.text:SetText(name)
        return
    end
    row.text:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    row.text:SetText(TEXT.ITEM .. entry.id)
    local items = ns.Shared and ns.Shared.Items
    if items and items.OnLoaded then
        local id = entry.id
        items.OnLoaded({ id }, function()
            if ignorePanel and ignorePanel:IsShown() then D.FillIgnore() end
        end)
    end
end

function D.FillIgnore()
    if not (ignorePanel and ignorePanel.scroll) then return end
    local content = ignorePanel.scroll.content
    UI.BeginReusableRows(content)
    local items = SortedIgnored()
    ignorePanel.head:SetText(TEXT.LIST_HEAD:format(#items))
    local filter = strtrim(ignorePanel.search:GetText() or ""):lower()
    local y, shown = 0, 0
    for i = 1, #items do
        local entry = items[i]
        local name, _, quality = GetItemInfo(entry.id)
        local hay = name and name:lower() or tostring(entry.id)
        if filter == "" or hay:find(filter, 1, true) then
            local row = UI.Keep(content, "row", NewIgnoreRow)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            FillIgnoreRow(row, entry, name, quality)
            y = y - LIST.row
            shown = shown + 1
        end
    end
    if shown == 0 then
        local empty = UI.KeepFont(content, "note", LIST.text, nil, T.muted)
        empty:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        empty:SetWidth(LIST.w - LIST.top)
        empty:SetJustifyH("LEFT")
        empty:SetText(#items == 0 and TEXT.LIST_EMPTY or TEXT.LIST_NONE)
        y = y - LIST.row * 2
    end
    content:SetHeight(math.max(1, -y))
end

local function NewIgnoreScroll(parent)
    local scroll = UI.SlimScroll(parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(LIST.w - LIST.top, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    return scroll
end

local function SearchChanged()
    if ignorePanel and ignorePanel:IsShown() then D.FillIgnore() end
end

local function NewIgnoreSearch(parent)
    return ns.NewSearchBox(parent, "Search", SearchChanged)
end

local function PlaceIgnore(panel)
    panel.head:SetPoint("TOP", 0, -LIST.side)
    panel.close:SetPoint("TOPRIGHT", -St.CLOSE_IN, -St.CLOSE_IN)
    panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST.side, -LIST.top)
    panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -LIST.right, LIST.bottom)
    panel.search:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST.side, -LIST.searchY)
    panel.search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -LIST.side, -LIST.searchY)
    panel.search:SetHeight(LIST.searchH)
    panel.clear:SetPoint("BOTTOM", panel, "BOTTOM", 0, LIST.buttonY)
end

local function ShowIgnoreList()
    local dimmer, panel = ns.MakeModal(LIST.w, LIST.h, "destroyCheapestIgnore")
    ignorePanel = panel
    panel.head = UI.KeepFont(panel, "head", LIST.head, "OUTLINE")
    panel.scroll = UI.Keep(panel, "scroll", NewIgnoreScroll)
    panel.search = UI.Keep(panel, "search", NewIgnoreSearch)
    panel.clear = UI.KeepButton(panel, "clear", "Clear All", LIST.buttonW, LIST.buttonH, AskClearIgnored)
    panel.close = UI.KeepButton(panel, "close", "x", St.CLOSE_SIZE, St.CLOSE_SIZE, function() dimmer:Hide() end)
    PlaceIgnore(panel)
    panel.search:SetText("")
    D.FillIgnore()
    dimmer:Show()
end

local function ResetPosition()
    S.Set("destroyCheapestPos", nil)
end

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local SIDES = {
    { top = "Top", right = "Right", bottom = "Bottom", left = "Left" },
    { "top", "right", "bottom", "left" },
}

Settings.Page("QoL/Loot & Items", S):Card({
    id = "destroyCheapest", name = "Destroy Cheapest Item", order = 62, switch = "destroyCheapest",
    help = "When loot does not fit in your bags, offers the cheapest safe item to destroy so you can make room.",
    rows = {
        Settings.Group("Qualities"),
        { key = "destroyCheapestPoor", label = "Poor", toggle = true,
          help = "Offers poor (gray) items." },
        { key = "destroyCheapestCommon", label = "Common", toggle = true,
          help = "Offers common (white) items." },
        { key = "destroyCheapestUncommon", label = "Uncommon", toggle = true,
          help = "Offers uncommon (green) items." },
        { key = "destroyCheapestRare", label = "Rare", toggle = true,
          help = "Offers rare (blue) items." },
        { key = "destroyCheapestEpic", label = "Epic", toggle = true,
          help = "Offers epic (purple) items." },
        { key = "destroyCheapestLegendary", label = "Legendary", toggle = true,
          help = "Offers legendary items." },
        { key = "destroyCheapestArtifact", label = "Artifact", toggle = true,
          help = "Offers artifact items." },
        { key = "destroyCheapestHeirloom", label = "Heirloom", toggle = true,
          help = "Offers heirloom items." },
        { key = "destroyCheapestConsumable", label = "Consumables", toggle = true,
          help = "Also offers consumables a vendor will not buy. Ones with a vendor price are offered anyway." },
        { key = "destroyCheapestAll", label = "All Items", toggle = true,
          help = "Offers every item in your bags except ones on the ignore list." },
        Settings.Group("Popup"),
        { key = "destroyCheapestSide", label = "Beside the Loot Window", choice = SIDES,
          help = "Where the popup sits beside the loot window, until you drag it." },
        { key = "destroyCheapestMovable", label = "Movable", toggle = true,
          help = "Drag the popup, and keep that place until you reset it." },
        { key = "destroyCheapestAnyway", label = "Destroy Anyway", toggle = true,
          help = "When the loot is worth less, a smaller button can still destroy the item." },
        { label = "Reset Position", button = ResetPosition, buttonText = "Reset", always = true,
          help = "Clears a dragged place and uses Beside the Loot Window again." },
        Settings.Group("Prices"),
        { key = "destroyCheapestMarket", label = "Market Prices", toggle = true,
          help = "Shows the auction house price next to the vendor price when one is known." },
        { key = "destroyCheapestMarketRank", label = "Rank by Market Value", toggle = true,
          help = "Sorts by auction price times stack, cheapest first, and uses the vendor price when no auction price is known." },
        { key = "destroyCheapestMarketStale", label = "Ignore Old Scans", toggle = true,
          help = "An auction price older than Older Than is left out, and the vendor price is used." },
        { key = "destroyCheapestMarketDays", label = "Older Than (days)", slider = D.STALE_RANGE,
          needs = "destroyCheapestMarketStale",
          help = "How many days an auction price can be before it is left out." },
        Settings.Group("Full Bags"),
        { key = "destroyCheapestTransfers", label = "Bank and Other Transfers", toggle = true,
          help = "Also opens when the bank, mail, a trade, a vendor or a quest reward will not fit." },
        Settings.Group("Ignore List"),
        { label = "Ignored Items", button = ShowIgnoreList, buttonText = "Ignore List", always = true,
          help = "Items this popup never offers. Ignore Item on the popup adds the one you are looking at." },
    },
})
