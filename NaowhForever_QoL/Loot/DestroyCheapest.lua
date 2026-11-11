-- DestroyCheapest.lua: when loot does not fit, offer the cheapest safe item to destroy.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local T = ns.THEME
local S = ns.QoLSettings
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local Coins = Parts.Coins

local PAD, GAP, HEADER, CARD_H, ICON = 10, 8, 36, 108, 36
local POPUP_W = St.PANEL_W
local CARD_W = (POPUP_W - PAD * 2 - GAP) / 2
local PLAIN = ns.QoLConstants.PLAIN_BAG
local SELL = ns.QoLConstants.SELL_PRICE
local EPIC = 4
local FISHING = LE_ITEM_WEAPON_FISHINGPOLE or 20
local BIND_ON_ACQUIRE = Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire or LE_ITEM_BIND_ON_ACQUIRE or 1
local BIND_QUEST = Enum and Enum.ItemBind and Enum.ItemBind.Quest
local CLASS = { CONTAINER = 1, WEAPON = 2, ARMOR = 4, PROJECTILE = 6, RECIPE = 9, QUIVER = 11, QUEST = 12, KEY = 13 }
local KEEP_CLASS = {
    [CLASS.CONTAINER] = true, [CLASS.PROJECTILE] = true, [CLASS.RECIPE] = true,
    [CLASS.QUIVER] = true, [CLASS.QUEST] = true, [CLASS.KEY] = true,
}
local TOOLS = {
    [6948] = true, [5060] = true, [2901] = true, [7005] = true, [5956] = true, [6219] = true,
    [10498] = true, [9149] = true, [6217] = true, [6218] = true, [6338] = true, [6339] = true,
    [11128] = true, [11130] = true, [11144] = true, [11145] = true, [16206] = true, [16207] = true,
}
local DIALOGS = { "DELETE_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }
local TEXT = {
    BLANK_DESTROY = ns.L("Nothing safe to destroy"),
    BLANK_LOOT = ns.L("Loot it again"),
    DESTROY = ns.L("Destroy"),
    LOOT = ns.L("You get"),
    GROUND = ns.L("On your cursor. Click the ground to destroy it. The game will ask you to confirm."),
    WAITING = ns.L("Waiting for the bags to update."),
    NOT_WORTH = ns.L("Not worth it: this loot sells for less than the item that would be destroyed."),
    NONE = ns.L("Nothing here is safe to destroy. Quest items, books, recipes, tools and set pieces stay."),
    HOLDING = ns.L("put down what you are holding first."),
    MOVED = ns.L("that item changed in your bags. The list has been refreshed."),
    COMBAT = ns.L("leave combat, then destroy it."),
    DESTROYED = ns.L("destroyed %s (%s)."),
    LOOT_AGAIN = ns.L("made room. Loot it again."),
    LOOT_COMBAT = ns.L("made room. Loot it again once combat ends."),
    STACK = ns.L("x%d"),
    COUNT = ns.L("%d/%d"),
}

local books, setItems, waitingInfo, requested = nil, {}, {}, {}
local pool, picks, used = {}, {}, 0
local lootPool, loots, lootUsed = {}, {}, 0
local index, lootIndex = 1, 1
local armed, armedBag, armedSlot, armedID
local pending
local popup, destroyCard, lootCard, note, action
local Paint, Build, OnDestroy

local function On()
    return S.Get("enabled") and S.Get("destroyCheapest")
end

local function PlainFree()
    local free = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        local n, family = GetContainerNumFreeSlots(bag)
        if family == PLAIN then free = free + (n or 0) end
    end
    return free
end

local function BagsFull(a, b)
    return b == ERR_INV_FULL or b == ERR_BAG_FULL or a == ERR_INV_FULL or a == ERR_BAG_FULL
end

local function CursorHolds(itemID)
    local kind, id = GetCursorInfo()
    return kind == "item" and id == itemID
end

local function DialogOpen()
    if not StaticPopup_FindVisible then return false end
    for i = 1, #DIALOGS do
        if StaticPopup_FindVisible(DIALOGS[i]) then return true end
    end
    return false
end

local function SlotState(p)
    local info = GetContainerItemInfo(p.bag, p.slot)
    if not info or info.itemID ~= p.itemID then return "gone" end
    if info.isLocked then return "locked" end
    return "here"
end

local function StillThere(p)
    local info = GetContainerItemInfo(p.bag, p.slot)
    return info and info.itemID == p.itemID and (info.stackCount or 1) == p.count and not info.isLocked
end

local function IsBook(itemID)
    if not books and type(ns.LibraryBooks) == "table" then
        books = {}
        for i = 1, #ns.LibraryBooks do
            local id = ns.LibraryBooks[i].item
            if id then books[id] = true end
        end
    end
    return books and books[itemID] or false
end

local function ReadSets()
    wipe(setItems)
    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs) then return end
    local ids = C_EquipmentSet.GetEquipmentSetIDs()
    if not ids then return end
    for i = 1, #ids do
        local items = C_EquipmentSet.GetItemIDs(ids[i])
        if items then
            for _, itemID in pairs(items) do
                if type(itemID) == "number" and itemID > 0 then setItems[itemID] = true end
            end
        end
    end
end

local function Ignored(itemID)
    local db = S.DB()
    local list = db and db.bagSpaceIgnore
    return list and list[itemID] ~= nil
end

local function QuestSlot(bag, slot)
    local api = C_Container.GetContainerItemQuestInfo
    if not api then return false end
    local q = api(bag, slot)
    if type(q) == "table" then return (q.isQuestItem or q.questID) and true or false end
    return q and true or false
end

local function InSet(bag, slot, itemID)
    local api = C_Container.GetContainerItemEquipmentSetInfo
    if api and api(bag, slot) then return true end
    return setItems[itemID] or false
end

local function BoundGear(classID, info, bindType)
    if classID ~= CLASS.WEAPON and classID ~= CLASS.ARMOR then return false end
    if info.isBound then return true end
    return bindType == BIND_ON_ACQUIRE
end

local function Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID)
    if not quality or quality < 0 or quality >= EPIC then return true end
    if not vendor or vendor <= 0 or info.hasNoValue then return true end
    if KEEP_CLASS[classID] then return true end
    if setID and setID > 0 then return true end
    if classID == CLASS.WEAPON and subclassID == FISHING then return true end
    if TOOLS[info.itemID] or IsBook(info.itemID) or Ignored(info.itemID) then return true end
    if InSet(bag, slot, info.itemID) then return true end
    if ns.IsBisItem and ns.IsBisItem(info.itemID) then return true end
    if QuestSlot(bag, slot) then return true end
    if BIND_QUEST and bindType == BIND_QUEST then return true end
    return BoundGear(classID, info, bindType)
end

local function Cheaper(a, b)
    if a.value ~= b.value then return a.value < b.value end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

local function Take()
    used = used + 1
    local e = pool[used]
    if not e then
        e = {}
        pool[used] = e
    end
    return e
end

local function Remember(itemID)
    if not itemID then return end
    waitingInfo[itemID] = true
    if requested[itemID] then return end
    requested[itemID] = true
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
end

local function ScanSlot(bag, slot)
    local info = GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) or info.isLocked then return end
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(info.itemID)
    local name, _, itemQuality, _, _, _, _, _, _, _, vendor, _, _, bindType, _, setID = GetItemInfo(info.itemID)
    if vendor == nil then return Remember(info.itemID) end
    local quality = info.quality
    if itemQuality and (not quality or itemQuality > quality) then quality = itemQuality end
    if Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID) then return end
    local e = Take()
    local count = info.stackCount or 1
    e.bag, e.slot, e.itemID = bag, slot, info.itemID
    e.link, e.icon, e.name = info.hyperlink, info.iconFileID, name
    e.count, e.quality, e.value = count, quality, vendor * count
    picks[#picks + 1] = e
end

local function Scan()
    local keepBag, keepSlot, keepID
    local current = picks[index]
    if current then keepBag, keepSlot, keepID = current.bag, current.slot, current.itemID end
    for i = #picks, 1, -1 do picks[i] = nil end
    used = 0
    wipe(waitingInfo)
    ReadSets()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        local _, family = GetContainerNumFreeSlots(bag)
        if family == PLAIN then
            for slot = 1, GetContainerNumSlots(bag) or 0 do ScanSlot(bag, slot) end
        end
    end
    table.sort(picks, Cheaper)
    index = 1
    if not keepID then return end
    for i = 1, #picks do
        local e = picks[i]
        if e.itemID == keepID and e.bag == keepBag and e.slot == keepSlot then
            index = i
            return
        end
    end
end

local function LootTake()
    lootUsed = lootUsed + 1
    local e = lootPool[lootUsed]
    if not e then
        e = {}
        lootPool[lootUsed] = e
    end
    return e
end

local function SlotOpen(slot)
    if not (LootFrame and LootFrame:IsShown()) then return false end
    if LootSlotHasItem and not LootSlotHasItem(slot) then return false end
    local _, _, _, _, _, locked = GetLootSlotInfo(slot)
    return not locked
end

local function ReadLoot()
    local keep = loots[lootIndex]
    local keepSlot = keep and keep.slot
    for i = #loots, 1, -1 do loots[i] = nil end
    lootUsed = 0
    lootIndex = 1
    if not (LootFrame and LootFrame:IsShown()) then return end
    for i = 1, GetNumLootItems() or 0 do
        local skip = LootSlotHasItem and not LootSlotHasItem(i)
        if not skip and GetLootSlotType and LOOT_SLOT_ITEM and GetLootSlotType(i) ~= LOOT_SLOT_ITEM then skip = true end
        if not skip then
            local texture, name, qty, currencyID, quality, _, isQuest, questID, _, isCoin = GetLootSlotInfo(i)
            if texture and not isCoin and not currencyID then
                local link = GetLootSlotLink(i)
                local vendor = link and select(SELL, GetItemInfo(link))
                if link and vendor == nil then Remember(GetItemInfoInstant(link)) end
                local e = LootTake()
                e.slot, e.link, e.icon, e.name = i, link, texture, name
                e.count, e.quality = qty or 1, quality
                e.quest = (isQuest or questID) and true or false
                e.vendor = vendor
                e.value = vendor and vendor > 0 and vendor * e.count or nil
                loots[#loots + 1] = e
                if e.slot == keepSlot then lootIndex = #loots end
            end
        end
    end
end

local function WorthIt(pick, loot)
    if not loot or loot.quest or not loot.vendor or loot.vendor <= 0 then return true end
    return loot.vendor * loot.count >= pick.value
end

local function Opened()
    return popup and popup:IsShown()
end

local watch = CreateFrame("Frame")

local function Listen(open)
    watch:UnregisterAllEvents()
    if not On() then return end
    watch:RegisterEvent("UI_ERROR_MESSAGE")
    if open or pending then
        watch:RegisterEvent("BAG_UPDATE_DELAYED")
        watch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        watch:RegisterEvent("LOOT_CLOSED")
        watch:RegisterEvent("LOOT_SLOT_CLEARED")
    end
end

local function Place()
    popup:ClearAllPoints()
    if LootFrame and LootFrame:IsShown() then
        popup:SetFrameLevel((LootFrame:GetFrameLevel() or 0) + 20)
        popup:SetPoint("BOTTOMLEFT", LootFrame, "TOPLEFT", 0, 8)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    end
end

local function StepDestroy(delta)
    if pending or #picks < 2 then return end
    armed = false
    index = index + delta
    if index < 1 then index = #picks end
    if index > #picks then index = 1 end
    Paint()
end

local function StepLoot(delta)
    if pending or #loots < 2 then return end
    armed = false
    lootIndex = lootIndex + delta
    if lootIndex < 1 then lootIndex = #loots end
    if lootIndex > #loots then lootIndex = 1 end
    Paint()
end

local function NewCard(parent, caption, step)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    if card.SetClipsChildren then card:SetClipsChildren(true) end
    ns.Solid(card, "BACKGROUND", T.bg, 0.45):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    card.caption = ns.Font(card, 10, nil, T.muted, true)
    card.caption:SetPoint("TOPLEFT", 8, -6)
    card.caption:SetText(caption)
    card.icon = Parts.ItemIcon(card, ICON)
    card.icon:SetPoint("TOPLEFT", 8, -24)
    card.name = ns.Font(card, 12, nil, T.fg)
    card.name:SetJustifyH("LEFT")
    card.stack = ns.Font(card, 11, nil, T.muted)
    card.stack:SetJustifyH("LEFT")
    card.value = ns.Font(card, 12, nil, T.fg)
    card.value:SetJustifyH("LEFT")
    card.prev = ns.Button(card, "<", 22, 18, function() step(-1) end)
    card.next = ns.Button(card, ">", 22, 18, function() step(1) end)
    card.count = ns.Font(card, 11, nil, T.muted)
    card.prev:SetPoint("BOTTOMLEFT", 6, 4)
    card.next:SetPoint("BOTTOMRIGHT", -6, 4)
    card.count:SetPoint("BOTTOM", 0, 6)
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        local e = self.entry
        if not (e and (e.bag or e.link)) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.bag then GameTooltip:SetBagItem(e.bag, e.slot) else GameTooltip:SetHyperlink(e.link) end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    card.stack:ClearAllPoints()
    card.value:ClearAllPoints()
    if not e then
        card.icon:Hide()
        card.name:SetPoint("TOPLEFT", 8, -28)
        card.name:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.name:SetWordWrap(true)
        card.name:SetText(blank)
        card.name:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        card.stack:Hide()
        card.value:Hide()
        return
    end
    card.icon:Show()
    card.icon.texture:SetTexture(e.icon)
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 6, 2)
    card.name:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.name:SetWordWrap(false)
    card.name:SetText(e.name or "")
    local c = ITEM_QUALITY_COLORS[e.quality]
    if c then card.name:SetTextColor(c.r, c.g, c.b) else card.name:SetTextColor(T.fg.r, T.fg.g, T.fg.b) end
    local anchor = card.name
    if e.count and e.count > 1 then
        card.stack:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -1)
        card.stack:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.stack:SetText(TEXT.STACK:format(e.count))
        card.stack:Show()
        anchor = card.stack
    else
        card.stack:Hide()
    end
    if e.value and e.value > 0 then
        card.value:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
        card.value:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.value:SetText(Coins(e.value))
        card.value:Show()
    else
        card.value:Hide()
    end
end

local function ButtonLabel(loot)
    if armed then return "Click again to destroy" end
    if loot then return "Destroy & Loot" end
    return "Destroy"
end

local function Layout(noteText, showButton)
    local y = HEADER + CARD_H + 8
    if noteText then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", PAD, -y)
        note:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
        note:SetText(noteText)
        note:Show()
        y = y + 40
    else
        note:Hide()
    end
    if showButton then
        action:ClearAllPoints()
        action:SetPoint("TOPLEFT", PAD, -y)
        action:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
        action:Show()
        y = y + 24 + 8
    else
        action:Hide()
    end
    popup:SetHeight(y + PAD)
end

function Paint()
    if not popup then return end
    local pick, loot = picks[index], loots[lootIndex]
    if not (pick and pick.bag == armedBag and pick.slot == armedSlot and pick.itemID == armedID) then
        armed = false
    end
    if armed and pick then
        armedBag, armedSlot, armedID = pick.bag, pick.slot, pick.itemID
    else
        armedBag, armedSlot, armedID = nil, nil, nil
    end
    FillCard(destroyCard, pick, TEXT.BLANK_DESTROY, index, pending and 0 or #picks)
    FillCard(lootCard, loot, TEXT.BLANK_LOOT, lootIndex, pending and 0 or #loots)
    local noteText, showButton
    if pending then
        noteText = pending.mode == "cursor" and TEXT.GROUND or TEXT.WAITING
        showButton = false
    elseif not pick then
        noteText, showButton = TEXT.NONE, false
    elseif loot and not WorthIt(pick, loot) then
        noteText, showButton = TEXT.NOT_WORTH, false
    else
        noteText, showButton = nil, true
        ns.SetButtonText(action, ButtonLabel(loot))
    end
    Layout(noteText, showButton)
end

function Build()
    popup = Parts.Panel("Bags Are Full", true)
    popup:Hide()
    popup:SetFrameStrata("DIALOG")
    popup.backdrop:Paint(1)
    destroyCard = NewCard(popup, TEXT.DESTROY, StepDestroy)
    lootCard = NewCard(popup, TEXT.LOOT, StepLoot)
    destroyCard:SetPoint("TOPLEFT", PAD, -HEADER)
    lootCard:SetPoint("TOPLEFT", destroyCard, "TOPRIGHT", GAP, 0)
    note = ns.Font(popup, 11, nil, T.muted)
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    action = ns.Button(popup, "Destroy & Loot", POPUP_W - PAD * 2, 24, OnDestroy)
    ns.PrimaryButton(action)
    popup:HookScript("OnHide", function()
        GameTooltip:Hide()
        if not pending then
            armed = false
            wipe(requested)
            wipe(waitingInfo)
            Listen(false)
        end
    end)
end

local function Refresh()
    if pending then return end
    if PlainFree() > 0 then
        if Opened() then popup:Hide() end
        return
    end
    Scan()
    ReadLoot()
    if Opened() then Paint() end
end

local function TryLoot(slot)
    if InCombatLockdown() then
        ns.Print(TEXT.LOOT_COMBAT)
        return
    end
    if not (slot and SlotOpen(slot)) then
        ns.Print(TEXT.LOOT_AGAIN)
        return
    end
    LootSlot(slot)
end

local function Finish(p)
    local slot = p.lootSlot
    pending = nil
    armed = false
    ns.Print(TEXT.DESTROYED:format(p.link or p.name or p.itemID, Coins(p.value)))
    if Opened() then popup:Hide() end
    TryLoot(slot)
end

local function TryFinish()
    local p = pending
    if not p then return end
    if DialogOpen() or CursorHolds(p.itemID) then return end
    local state = SlotState(p)
    if state == "locked" then return end
    if state == "gone" and (GetItemCount(p.itemID) or 0) <= p.owned - p.count then return Finish(p) end
    pending = nil
    armed = false
    if Opened() then Refresh() else Listen(false) end
end

function OnDestroy()
    if pending or not On() then return end
    local pick, loot = picks[index], loots[lootIndex]
    if not pick then return end
    if not StillThere(pick) then
        ns.Print(TEXT.MOVED)
        return Refresh()
    end
    if not WorthIt(pick, loot) then return Paint() end
    if GetCursorInfo() then return ns.Print(TEXT.HOLDING) end
    if InCombatLockdown() then return ns.Print(TEXT.COMBAT) end
    local same = armed and pick.bag == armedBag and pick.slot == armedSlot and pick.itemID == armedID
    if pick.quality > 0 and not same then
        armed = true
        armedBag, armedSlot, armedID = pick.bag, pick.slot, pick.itemID
        return Paint()
    end
    armed = false
    pending = {
        bag = pick.bag, slot = pick.slot, itemID = pick.itemID, link = pick.link, name = pick.name,
        count = pick.count, value = pick.value, owned = GetItemCount(pick.itemID) or 0,
        lootSlot = loot and loot.slot,
    }
    Listen(true)
    C_Container.PickupContainerItem(pick.bag, pick.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= pick.itemID then
        pending = nil
        if GetCursorInfo() then ClearCursor() end
        ns.Print(TEXT.MOVED)
        return Refresh()
    end
    if pick.quality == 0 then DeleteCursorItem() end
    pending.mode = CursorHolds(pick.itemID) and "cursor" or "wait"
    if pending.mode == "cursor" then ns.Print(TEXT.GROUND) end
    Paint()
end

local function Show()
    if not On() or ns.GamepadStandDown() then return end
    if PlainFree() > 0 then
        if Opened() then popup:Hide() end
        return
    end
    if not popup then Build() end
    local was = Opened()
    if not was then wipe(requested) end
    Scan()
    ReadLoot()
    if not was then Place() end
    popup:Show()
    Listen(true)
    Paint()
end

local function OnEvent(_, event, a, b)
    if event == "UI_ERROR_MESSAGE" then
        if not BagsFull(a, b) then return end
        if not (LootFrame and LootFrame:IsShown()) then return end
        if pending then return end
        return Show()
    end
    if event == "BAG_UPDATE_DELAYED" then
        if pending then return TryFinish() end
        if Opened() then Refresh() end
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not waitingInfo[a] then return end
        waitingInfo[a] = nil
        if pending or not Opened() then return end
        return Refresh()
    end
    if pending or not Opened() then return end
    ReadLoot()
    Paint()
end

watch:SetScript("OnEvent", OnEvent)

local function Apply()
    if not On() then
        pending = nil
        armed = false
        watch:UnregisterAllEvents()
        if popup then popup:Hide() end
        return
    end
    Listen(Opened())
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "destroyCheapest" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

Settings.Page("QoL/Loot & Items", S):Card({
    id = "destroyCheapest", name = "Destroy Cheapest Item", order = 62, switch = "destroyCheapest",
    help = "When loot does not fit in your bags, offers the cheapest safe item to destroy so you can make room.",
})
