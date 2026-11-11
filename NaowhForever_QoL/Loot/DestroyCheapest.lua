-- DestroyCheapest.lua: when bags are full, offer the cheapest safe item to destroy.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local Coins = Parts.Coins

local PAD, GAP, HEADER, CARD_H, ICON = 10, 8, 36, 124, 36
local QTY_IN, QTY_SIZE, QTY_LEVEL = 2, 12, 4
local CARD_ALPHA = 0.45
local POPUP_W = St.PANEL_W
local CARD_W = (POPUP_W - PAD * 2 - GAP) / 2
local BUTTON_H, NOTE_H, ANYWAY_H = 24, 40, 18
local PASS_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local PASS_GLOW = "Interface\\Buttons\\UI-GroupLoot-Pass-Highlight"
local STALE_DAYS = 7
local STALE = ns.QoLConstants.SECONDS_PER_DAY * STALE_DAYS
local HOME_Y, OVER_LOOT = 140, 20
local PLAIN = ns.QoLConstants.PLAIN_BAG
local SELL = ns.QoLConstants.SELL_PRICE
local DIRECT_DELETE = 1
local FISHING = LE_ITEM_WEAPON_FISHINGPOLE or 20
local BIND_ON_ACQUIRE = Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire or LE_ITEM_BIND_ON_ACQUIRE or 1
local BIND_QUEST = Enum and Enum.ItemBind and Enum.ItemBind.Quest
local CLASS = { CONSUMABLE = 0, WEAPON = 2, ARMOR = 4, PROJECTILE = 6, RECIPE = 9, QUIVER = 11, QUEST = 12, KEY = 13 }
local KEEP_CLASS = {
    [CLASS.PROJECTILE] = true, [CLASS.RECIPE] = true,
    [CLASS.QUIVER] = true, [CLASS.QUEST] = true, [CLASS.KEY] = true,
}
local QUALITY_KEY = {
    [0] = "destroyCheapestPoor", [1] = "destroyCheapestCommon",
    [2] = "destroyCheapestUncommon", [3] = "destroyCheapestRare",
    [4] = "destroyCheapestEpic", [5] = "destroyCheapestLegendary",
    [6] = "destroyCheapestArtifact", [7] = "destroyCheapestHeirloom",
}
local ANCHOR = {
    top = { "BOTTOMLEFT", "TOPLEFT", 0, 1 },
    bottom = { "TOPLEFT", "BOTTOMLEFT", 0, -1 },
    left = { "TOPRIGHT", "TOPLEFT", -1, 0 },
    right = { "TOPLEFT", "TOPRIGHT", 1, 0 },
}
local TRANSFER_FRAMES = {
    "BankFrame", "EUI_BankFrame", "MailFrame", "TradeFrame",
    "MerchantFrame", "GuildBankFrame", "QuestFrame",
}
local TOOLS = {
    [6948] = true, [5060] = true, [2901] = true, [7005] = true, [5956] = true, [6219] = true,
    [10498] = true, [9149] = true, [6217] = true, [6218] = true, [6338] = true, [6339] = true,
    [11128] = true, [11130] = true, [11144] = true, [11145] = true, [16206] = true, [16207] = true,
}
local DIALOGS = { "DELETE_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }
local LIST = {
    w = 440, h = 480, row = 30, icon = 24, inset = 2, remove = 22, gap = 8,
    text = 12, head = 14, side = 16, top = 72, right = 36, bottom = 52,
    searchY = 40, searchH = 24, buttonW = 110, buttonH = 24, buttonY = 16,
}
local TEXT = {
    BLANK_DESTROY = ns.L("Nothing safe to destroy"),
    DESTROY = ns.L("Destroy"),
    LOOT = ns.L("You get"),
    WAITING = ns.L("Waiting for the bags to update."),
    DIALOG = ns.L("Confirm the delete in the game window. Cancel puts it back."),
    STUCK = ns.L("That item is still on your cursor. Click its bag slot to put it back."),
    NOT_WORTH = ns.L("Not worth it: this loot is worth less than the item that would be destroyed."),
    NONE = ns.L("Nothing here is safe to destroy. Quest items, books, recipes, tools, set pieces and turned-off qualities stay."),
    HOLDING = ns.L("put down what you are holding first."),
    MOVED = ns.L("that item changed in your bags. The list has been refreshed."),
    COMBAT = ns.L("leave combat, then destroy it."),
    DESTROYED = ns.L("destroyed %s (%s)."),
    LOOT_AGAIN = ns.L("made room. Loot it again."),
    LOOT_COMBAT = ns.L("made room. Loot it again once combat ends."),
    ROOM = ns.L("made room."),
    AGAIN = ns.L("Loot it again after making room."),
    BLOCKED = ns.L("the game did not delete that, so it is back in your bags."),
    RETURNED = ns.L("that item is back in your bags."),
    IGNORED = ns.L("will not suggest %s again."),
    MARKET = ns.L("AH %s"),
    MARKET_OLD = ns.L("AH %s (%s)"),
    COUNT = ns.L("%d/%d"),
    LIST_HEAD = ns.L("Ignored Items (%d)"),
    LIST_EMPTY = ns.L("Nothing ignored yet. Ignore Item on the popup adds the one you are looking at."),
    LIST_NONE = ns.L("No ignored item matches your search."),
    ITEM = ns.L("Item "),
    CLEAR_ASK = "Offer every item you ignored again?",
}

local books, setItems, waitingInfo, requested = nil, {}, {}, {}
local pool, picks, used = {}, {}, 0
local lootPool, loots, lootUsed = {}, {}, 0
local pendingLoads, loadCount = {}, 0
local index, lootIndex = 1, 1
local armed, armedBag, armedSlot, armedID, forced
local pending, scanning, scanAgain, dragging, lootHooked
local popup, destroyCard, lootCard, note, action, anywayBtn
local ignorePanel
local Paint, Refresh, Finish, FillIgnore, OnDestroy, Build, placing

local function On()
    return S.Get("enabled") and S.Get("destroyCheapest")
end

local function IsPlain(bag)
    local _, family = GetContainerNumFreeSlots(bag)
    return family == nil or family == PLAIN
end

local function PlainFree()
    local free = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        if IsPlain(bag) then
            local n = GetContainerNumFreeSlots(bag)
            free = free + (n or 0)
        end
    end
    return free
end

local function BagsFull(a, b)
    return b == ERR_INV_FULL or b == ERR_BAG_FULL or a == ERR_INV_FULL or a == ERR_BAG_FULL
end

local function LootShown()
    return LootFrame and LootFrame.IsShown and LootFrame:IsShown()
end

local function TransferShown()
    if not S.Get("destroyCheapestTransfers") then return false end
    for i = 1, #TRANSFER_FRAMES do
        local frame = _G[TRANSFER_FRAMES[i]]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    return false
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
    local own = db and db.destroyCheapestIgnore
    return own and own[itemID] ~= nil or false
end

local function IgnoreAdd(itemID)
    local db = S.DB()
    local list = db.destroyCheapestIgnore
    if type(list) ~= "table" then
        list = {}
        db.destroyCheapestIgnore = list
    end
    list[itemID] = time()
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

local function QualityOn(quality)
    local key = QUALITY_KEY[quality]
    if not key then return false end
    return S.Get(key) == true
end

local function ConsumableOn()
    return S.Get("destroyCheapestConsumable") == true
end

local function ShowAll()
    return S.Get("destroyCheapestAll") == true
end

local function Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID)
    if Ignored(info.itemID) then return true end
    if ShowAll() then return false end
    if quality == nil or quality < 0 or not QualityOn(quality) then return true end
    if not vendor or vendor <= 0 then
        if classID ~= CLASS.CONSUMABLE or not ConsumableOn() then return true end
    end
    if KEEP_CLASS[classID] then return true end
    if setID and setID > 0 then return true end
    if classID == CLASS.WEAPON and subclassID == FISHING then return true end
    if TOOLS[info.itemID] or IsBook(info.itemID) then return true end
    if InSet(bag, slot, info.itemID) then return true end
    if ns.IsBisItem and ns.IsBisItem(info.itemID) then return true end
    if QuestSlot(bag, slot) then return true end
    if BIND_QUEST and bindType == BIND_QUEST then return true end
    return BoundGear(classID, info, bindType)
end

local function UseMarket()
    return S.Get("destroyCheapestMarket") == true
end

local function RankMarket()
    return S.Get("destroyCheapestMarketRank") == true
end

local function Quote(itemID)
    if not (itemID and ns.AuctionPrice) then return end
    local price, at = ns.AuctionPrice(itemID)
    if type(price) ~= "number" or price <= 0 then return end
    if type(at) ~= "number" then return price, nil, false end
    local age = GetServerTime() - at
    if age < 0 then age = 0 end
    return price, age, age <= STALE
end

local function ApplyMarket(e, itemID, count)
    e.market, e.marketAge, e.marketFresh, e.marketChecked = nil, nil, nil, nil
    if not (RankMarket() and itemID) then return end
    e.marketChecked = true
    local price, age, fresh = Quote(itemID)
    if not price then return end
    e.market, e.marketAge, e.marketFresh = price * (count or 1), age, fresh
end

local function RankValue(e)
    if RankMarket() and e.marketFresh and e.market then return e.market end
    return e.value
end

local function Cheaper(a, b)
    local ar, br = a.rank or a.value, b.rank or b.value
    if ar ~= br then return ar < br end
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

local function ReadQuality(fromBag, fromItem)
    local quality = fromBag
    if type(quality) ~= "number" then quality = fromItem end
    if type(fromItem) == "number" and type(quality) == "number" and fromItem > quality then
        quality = fromItem
    end
    if type(quality) ~= "number" or quality < 0 then return end
    return quality
end

local function ItemFacts(info)
    local name, _, itemQuality, _, _, _, _, _, _, _, vendor, infoClass, infoSub, bindType, _, setID =
        GetItemInfo(info.itemID)
    if name == nil and info.hyperlink then
        name, _, itemQuality, _, _, _, _, _, _, _, vendor, infoClass, infoSub, bindType, _, setID =
            GetItemInfo(info.hyperlink)
    end
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(info.itemID)
    if type(classID) ~= "number" then classID = infoClass end
    if type(subclassID) ~= "number" then subclassID = infoSub end
    return name, ReadQuality(info.quality, itemQuality), vendor, classID, subclassID, bindType, setID
end

local function Queue(itemID)
    if not itemID or requested[itemID] then
        if itemID then waitingInfo[itemID] = true end
        return
    end
    requested[itemID] = true
    waitingInfo[itemID] = true
    loadCount = loadCount + 1
    pendingLoads[loadCount] = itemID
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
end

local function FlushLoads()
    if loadCount == 0 then return end
    local batch, n = {}, loadCount
    for i = 1, n do
        batch[i] = pendingLoads[i]
        pendingLoads[i] = nil
    end
    loadCount = 0
    local items = ns.Shared and ns.Shared.Items
    if not (items and items.OnLoaded) then return end
    items.OnLoaded(batch, function()
        if pending or not (popup and popup:IsShown()) then return end
        if scanning then
            scanAgain = true
            return
        end
        Refresh()
    end)
end

local function ScanSlot(bag, slot)
    local info = GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) or info.isLocked then return end
    local name, quality, vendor, classID, subclassID, bindType, setID = ItemFacts(info)
    local showAll = ShowAll()
    if name == nil or (quality == nil and not showAll) then
        return Queue(info.itemID)
    end
    if vendor == nil then
        if not showAll and (classID ~= CLASS.CONSUMABLE or not ConsumableOn()) then
            return Queue(info.itemID)
        end
        vendor = 0
    end
    if Kept(bag, slot, info, quality, vendor, classID, subclassID, bindType, setID) then return end
    local e = Take()
    local count = info.stackCount or 1
    e.bag, e.slot, e.itemID = bag, slot, info.itemID
    e.link, e.icon, e.name = info.hyperlink, info.iconFileID, name
    e.count, e.quality, e.value = count, quality, vendor * count
    ApplyMarket(e, info.itemID, count)
    e.rank = RankValue(e)
    picks[#picks + 1] = e
end

local function Scan()
    if scanning then
        scanAgain = true
        return
    end
    scanning = true
    local keepBag, keepSlot, keepID
    local current = picks[index]
    if current then keepBag, keepSlot, keepID = current.bag, current.slot, current.itemID end
    for i = #picks, 1, -1 do picks[i] = nil end
    used = 0
    wipe(waitingInfo)
    ReadSets()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    local everyBag = ShowAll()
    for bag = BACKPACK_CONTAINER, last do
        if everyBag or IsPlain(bag) then
            for slot = 1, GetContainerNumSlots(bag) or 0 do ScanSlot(bag, slot) end
        end
    end
    table.sort(picks, Cheaper)
    index = 1
    if keepID then
        for i = 1, #picks do
            local e = picks[i]
            if e.itemID == keepID and e.bag == keepBag and e.slot == keepSlot then
                index = i
                break
            end
        end
    end
    scanning = false
    if scanAgain then
        scanAgain = false
        Scan()
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
    if not LootShown() then return false end
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
    if not LootShown() then return end
    for i = 1, GetNumLootItems() or 0 do
        local skip = LootSlotHasItem and not LootSlotHasItem(i)
        if not skip and GetLootSlotType and LOOT_SLOT_ITEM and GetLootSlotType(i) ~= LOOT_SLOT_ITEM then skip = true end
        if not skip then
            local texture, name, qty, currencyID, quality, _, isQuest, questID, _, isCoin = GetLootSlotInfo(i)
            if texture and not isCoin and not currencyID then
                local link = GetLootSlotLink(i)
                local vendor = link and select(SELL, GetItemInfo(link))
                if link and vendor == nil then Queue(GetItemInfoInstant(link)) end
                local e = LootTake()
                e.slot, e.link, e.icon, e.name = i, link, texture, name
                e.itemID = link and GetItemInfoInstant(link) or nil
                e.count, e.quality = qty or 1, quality
                e.quest = (isQuest or questID) and true or false
                e.vendor = vendor
                e.value = vendor and vendor > 0 and vendor * e.count or nil
                ApplyMarket(e, e.itemID, e.count)
                loots[#loots + 1] = e
                if e.slot == keepSlot then lootIndex = #loots end
            end
        end
    end
end

local function WorthIt(pick, loot)
    if not loot or loot.quest then return true end
    if not RankMarket() then
        if not loot.vendor or loot.vendor <= 0 then return true end
        return loot.vendor * loot.count >= pick.value
    end
    local offer = RankValue(pick) or 0
    if offer <= 0 then return true end
    local gain = RankValue(loot)
    if not gain or gain <= 0 then return true end
    return gain >= offer
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
        watch:RegisterEvent("LOOT_OPENED")
        watch:RegisterEvent("LOOT_CLOSED")
        watch:RegisterEvent("LOOT_SLOT_CLEARED")
    end
end

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
    if not center and LootShown() then
        local level = LootFrame.GetFrameLevel and LootFrame:GetFrameLevel() or 0
        popup:SetFrameLevel(level + OVER_LOOT)
        local side = ANCHOR[S.Get("destroyCheapestSide")] or ANCHOR.top
        popup:SetPoint(side[1], LootFrame, side[2], side[3] * GAP, side[4] * GAP)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
    placing = false
end

local function ClearLoot()
    for i = #loots, 1, -1 do loots[i] = nil end
    lootUsed = 0
    lootIndex = 1
    if lootCard then
        lootCard.entry = nil
        lootCard:Hide()
    end
    if pending then pending.lootSlot = nil end
end

local function Settle(lootEnded)
    if not Opened() and not pending then
        if lootEnded and lootUsed > 0 then ClearLoot() end
        return
    end
    if lootEnded or not LootShown() then ClearLoot() end
    if not Opened() then return end
    local lootOpen = not lootEnded and LootShown()
    if pending or lootOpen or TransferShown() then
        if not lootOpen and not SavedPos() and not dragging then Place(true) end
        if lootOpen and not pending then ReadLoot() end
        Paint()
        return
    end
    popup:Hide()
end

local function FollowLoot()
    if placing or dragging or not Opened() or SavedPos() then return end
    Place()
end

local function HookLoot()
    if lootHooked or type(LootFrame) ~= "table" or not LootFrame.HookScript then return end
    lootHooked = true
    LootFrame:HookScript("OnShow", FollowLoot)
    LootFrame:HookScript("OnHide", function() Settle(true) end)
end

local transferHooks = {}

local function HookTransfers()
    if not S.Get("destroyCheapestTransfers") then return end
    for i = 1, #TRANSFER_FRAMES do
        local name = TRANSFER_FRAMES[i]
        local frame = not transferHooks[name] and _G[name]
        if type(frame) == "table" and frame.HookScript then
            transferHooks[name] = true
            frame:HookScript("OnHide", function() Settle(false) end)
        end
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
    lootIndex = lootIndex + delta
    if lootIndex < 1 then lootIndex = #loots end
    if lootIndex > #loots then lootIndex = 1 end
    Paint()
end

local function NewCard(parent, caption, step)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    if card.SetClipsChildren then card:SetClipsChildren(true) end
    ns.Solid(card, "BACKGROUND", T.bg, CARD_ALPHA):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    card.caption = ns.Font(card, 10, nil, T.muted, true)
    card.caption:SetPoint("TOPLEFT", PAD - 2, -(GAP - 2))
    card.caption:SetText(caption)
    card.icon = Parts.ItemIcon(card, ICON)
    card.icon:SetPoint("TOPLEFT", PAD - 2, -(BUTTON_H))
    local qty = CreateFrame("Frame", nil, card.icon)
    qty:SetAllPoints()
    qty:SetFrameLevel(card.icon:GetFrameLevel() + QTY_LEVEL)
    card.qty = ns.Font(qty, QTY_SIZE, "OUTLINE", T.fg)
    card.qty:SetJustifyH("RIGHT")
    card.qty:SetPoint("BOTTOMRIGHT", -QTY_IN, QTY_IN)
    card.qty:Hide()
    card.name = ns.Font(card, 12, nil, T.fg)
    card.name:SetJustifyH("LEFT")
    card.value = ns.Font(card, 12, nil, T.fg)
    card.value:SetJustifyH("LEFT")
    card.market = ns.Font(card, 11, nil, T.muted)
    card.market:SetJustifyH("LEFT")
    card.market:SetWordWrap(false)
    card.market:Hide()
    card.prev = ns.Button(card, "<", BUTTON_H - 2, BUTTON_H - 6, function() step(-1) end)
    card.next = ns.Button(card, ">", BUTTON_H - 2, BUTTON_H - 6, function() step(1) end)
    card.count = ns.Font(card, 11, nil, T.muted)
    card.prev:SetPoint("BOTTOMLEFT", GAP - 2, GAP - 4)
    card.next:SetPoint("BOTTOMRIGHT", -(GAP - 2), GAP - 4)
    card.count:SetPoint("BOTTOM", 0, GAP - 2)
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
        card.name:SetPoint("TOPLEFT", PAD - 2, -(BUTTON_H + 4))
        card.name:SetPoint("RIGHT", card, "RIGHT", -(PAD - 2), 0)
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
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", GAP - 2, 2)
    card.name:SetPoint("RIGHT", card, "RIGHT", -(PAD - 2), 0)
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
        card.value:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
        card.value:SetPoint("RIGHT", card, "RIGHT", -(PAD - 2), 0)
        card.value:SetText(Coins(e.value))
        card.value:Show()
        anchor = card.value
    else
        card.value:Hide()
    end
    if UseMarket() and e.itemID and not e.marketChecked then
        e.marketChecked = true
        local price, age, fresh = Quote(e.itemID)
        if price then
            e.market = price * (e.count or 1)
            e.marketAge, e.marketFresh = age, fresh
        end
    end
    if UseMarket() and e.market then
        local age = type(e.marketAge) == "number" and ns.AuctionAge and ns.AuctionAge(e.marketAge)
        local coins = Coins(e.market)
        card.market:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
        card.market:SetPoint("RIGHT", card, "RIGHT", -(PAD - 2), 0)
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
        card.next:SetPoint("BOTTOMRIGHT", card.ignore, "BOTTOMLEFT", -(GAP - 2), 0)
    else
        card.next:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -(GAP - 2), GAP - 4)
    end
end

local function ButtonLabel(loot)
    if armed then return "Click again to destroy" end
    if loot then return "Destroy & Loot" end
    return "Destroy"
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
    local showLoot = loot ~= nil
    FitCards(showLoot)
    FillCard(destroyCard, pick, TEXT.BLANK_DESTROY, index, pending and 0 or #picks)
    if showLoot then
        FillCard(lootCard, loot, nil, lootIndex, pending and 0 or #loots)
    end
    local noteText, showButton, showAnyway
    if pending then
        if pending.mode == "dialog" then noteText = TEXT.DIALOG
        elseif pending.mode == "cursor" then noteText = TEXT.STUCK
        else noteText = TEXT.WAITING
        end
    elseif not pick then
        noteText = TEXT.NONE
    else
        if loot and not WorthIt(pick, loot) then
            noteText = TEXT.NOT_WORTH
            if S.Get("destroyCheapestAnyway") then
                showAnyway = true
                ns.SetButtonText(anywayBtn, armed and "Click again to destroy" or "Destroy Anyway")
            end
        else
            showButton = true
            ns.SetButtonText(action, ButtonLabel(loot))
            if not loot and TransferShown() then noteText = TEXT.AGAIN end
        end
    end
    Layout(noteText, showButton, showAnyway)
end

local function ReturnCursor(p)
    if not CursorHolds(p.itemID) then return true end
    ClearCursor()
    if CursorHolds(p.itemID) then C_Container.PickupContainerItem(p.bag, p.slot) end
    return not CursorHolds(p.itemID)
end

local function TryLoot(slot)
    if not slot or not LootShown() then
        ns.Print(TEXT.ROOM)
        return
    end
    if InCombatLockdown() then
        ns.Print(TEXT.LOOT_COMBAT)
        return
    end
    if not SlotOpen(slot) then
        ns.Print(TEXT.LOOT_AGAIN)
        return
    end
    LootSlot(slot)
end

function Finish(p)
    local slot = p.lootSlot
    pending = nil
    armed = false
    ns.Print(TEXT.DESTROYED:format(p.link or p.name or p.itemID, Coins(p.value)))
    if Opened() then popup:Hide() end
    TryLoot(slot)
end

local function GiveUp()
    pending = nil
    armed = false
    if Opened() then Refresh() else Listen(false) end
end

local function Resolve()
    local p = pending
    if not p or not p.mode then return end
    if DialogOpen() then return end
    if CursorHolds(p.itemID) then
        if p.mode == "cursor" then return end
        if ReturnCursor(p) then
            ns.Print(TEXT.RETURNED)
            return GiveUp()
        end
        p.mode = "cursor"
        ns.Print(TEXT.STUCK)
        if Opened() then Paint() end
        return
    end
    local state = SlotState(p)
    if state == "locked" then return end
    if state == "gone" then
        local left = GetItemCount(p.itemID)
        if type(left) ~= "number" then return end
        if left <= p.owned - p.count then return Finish(p) end
        if not p.sawGone then
            p.sawGone = true
            return
        end
        ns.Print(TEXT.MOVED)
    elseif state == "here" then
        ns.Print(TEXT.BLOCKED)
    end
    GiveUp()
end

local function OnIgnore()
    if pending or not On() then return end
    local pick = picks[index]
    if not pick then return end
    IgnoreAdd(pick.itemID)
    armed = false
    ns.Print(TEXT.IGNORED:format(pick.link or pick.name or pick.itemID))
    if ignorePanel and ignorePanel:IsShown() then FillIgnore() end
    Refresh()
end

function OnDestroy()
    local allow = forced
    forced = false
    if pending or not On() then return end
    local pick, loot = picks[index], loots[lootIndex]
    if not pick then return end
    if not StillThere(pick) then
        ns.Print(TEXT.MOVED)
        return Refresh()
    end
    if not allow and not WorthIt(pick, loot) then return Paint() end
    if GetCursorInfo() then return ns.Print(TEXT.HOLDING) end
    if InCombatLockdown() then return ns.Print(TEXT.COMBAT) end
    if not pick.quality or pick.quality > DIRECT_DELETE then
        local same = armed and pick.bag == armedBag and pick.slot == armedSlot and pick.itemID == armedID
        if not same then
            armed = true
            armedBag, armedSlot, armedID = pick.bag, pick.slot, pick.itemID
            return Paint()
        end
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
        ns.Print(TEXT.MOVED)
        return Refresh()
    end
    DeleteCursorItem()
    if DialogOpen() then
        pending.mode = "dialog"
        return Paint()
    end
    if CursorHolds(pick.itemID) then
        if ReturnCursor(pending) then
            pending = nil
            ns.Print(TEXT.BLOCKED)
            return Refresh()
        end
        pending.mode = "cursor"
        ns.Print(TEXT.STUCK)
        return Paint()
    end
    pending.mode = "wait"
    Resolve()
    if pending and Opened() then Paint() end
end

local function OnAnyway()
    forced = true
    OnDestroy()
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

function Build()
    popup = Parts.Panel("Bags Are Full", true)
    popup:Hide()
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self)
        if not S.Get("destroyCheapestMovable") then return end
        dragging = true
        self:StartMoving()
    end)
    popup:SetScript("OnDragStop", function(self)
        if not dragging then return end
        dragging = false
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
    note = ns.Font(popup, 11, nil, T.muted)
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    action = ns.Button(popup, "Destroy & Loot", POPUP_W - PAD * 2, BUTTON_H, OnDestroy)
    ns.PrimaryButton(action)
    anywayBtn = ns.Button(popup, "Destroy Anyway", POPUP_W - PAD * 2, ANYWAY_H, OnAnyway)
    destroyCard.ignore = CreateFrame("Button", nil, destroyCard)
    destroyCard.ignore:SetSize(St.ACTION, St.ACTION)
    destroyCard.ignore:SetPoint("BOTTOMRIGHT", -(GAP - 2), GAP - 4)
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
        if dragging then
            dragging = false
            popup:StopMovingOrSizing()
        end
        if not LootShown() then ClearLoot() end
        if not pending then
            armed = false
            wipe(requested)
            wipe(waitingInfo)
            Listen(false)
        end
    end)
end

function Refresh()
    if pending or scanning then
        if scanning then scanAgain = true end
        return
    end
    if not Opened() then return end
    if PlainFree() > 0 or not (LootShown() or TransferShown()) then
        popup:Hide()
        return
    end
    Listen(true)
    Scan()
    ReadLoot()
    FlushLoads()
    Paint()
end

local function ReleaseCursor()
    local p = pending
    if not p or not CursorHolds(p.itemID) then return end
    ReturnCursor(p)
end

local function Show()
    if not On() or ns.GamepadStandDown() then return end
    if PlainFree() > 0 then
        if Opened() then popup:Hide() end
        return
    end
    HookTransfers()
    if not popup then Build() end
    local was = Opened()
    if not was then wipe(requested) end
    Listen(true)
    if not was then Place() end
    popup:Show()
    Scan()
    ReadLoot()
    FlushLoads()
    Paint()
end

local function OnEvent(_, event, a, b)
    if event == "UI_ERROR_MESSAGE" then
        if not BagsFull(a, b) or pending then return end
        if not (LootShown() or TransferShown()) then return end
        return Show()
    end
    if event == "BAG_UPDATE_DELAYED" then
        if pending then return Resolve() end
        if Opened() then Refresh() end
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not waitingInfo[a] then return end
        waitingInfo[a] = nil
        if pending or not Opened() then return end
        return Refresh()
    end
    if event == "LOOT_CLOSED" then return Settle(not LootShown()) end
    if pending or not Opened() then return end
    ReadLoot()
    Paint()
end

watch:SetScript("OnEvent", OnEvent)

local function Apply()
    if not On() then
        ReleaseCursor()
        pending = nil
        armed = false
        watch:UnregisterAllEvents()
        if popup then popup:Hide() end
        return
    end
    HookLoot()
    HookTransfers()
    Listen(Opened())
end

local function SettingChanged(key)
    if key == "enabled" or key == "destroyCheapest" then
        Apply()
        return
    end
    if key == "destroyCheapestMarketRank" and not pending then index = 0 end
    if not Opened() then return end
    if key == "destroyCheapestSide" or key == "destroyCheapestPos" then
        Place()
        return
    end
    if type(key) == "string" and key:find("^destroyCheapest", 1, true) and not pending then
        if key == "destroyCheapestTransfers" then HookTransfers() end
        Refresh()
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
    if ignorePanel and ignorePanel:IsShown() then FillIgnore() end
    if Opened() and not pending then Refresh() end
end

local function ClearIgnored()
    local db = S.DB()
    if type(db.destroyCheapestIgnore) == "table" then wipe(db.destroyCheapestIgnore) end
    if ignorePanel and ignorePanel:IsShown() then FillIgnore() end
    if Opened() and not pending then Refresh() end
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
            if ignorePanel and ignorePanel:IsShown() then FillIgnore() end
        end)
    end
end

function FillIgnore()
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
    if ignorePanel and ignorePanel:IsShown() then FillIgnore() end
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
    FillIgnore()
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
          help = "Sorts by auction price times stack from the last seven days, cheapest first, and uses the vendor price when that price is missing or older." },
        Settings.Group("Full Bags"),
        { key = "destroyCheapestTransfers", label = "Bank and Other Transfers", toggle = true,
          help = "Also opens when the bank, mail, a trade, a vendor or a quest reward will not fit." },
        Settings.Group("Ignore List"),
        { label = "Ignored Items", button = ShowIgnoreList, buttonText = "Ignore List", always = true,
          help = "Items this popup never offers. Ignore Item on the popup adds the one you are looking at." },
    },
})
