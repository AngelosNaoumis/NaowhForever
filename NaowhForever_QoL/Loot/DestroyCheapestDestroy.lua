-- DestroyCheapestDestroy.lua: the click that picks a bag item up and deletes it.
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetItemCount = C_Item.GetItemCount

local D = ns.DestroyCheapest
local Coins = ns.Shared.Parts.Coins
local TEXT = D.TEXT

local DIALOGS = { "DELETE_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }

local function DialogOpen()
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

function D.ReturnCursor(p)
    if not D.CursorHolds(p.itemID) then return true end
    if InCombatLockdown() then return false end
    ClearCursor()
    if not D.CursorHolds(p.itemID) then return true end
    if InCombatLockdown() then return false end
    C_Container.PickupContainerItem(p.bag, p.slot)
    return not D.CursorHolds(p.itemID)
end

local function TryLoot(slot)
    if not slot or not D.LootShown() then
        ns.Print(TEXT.ROOM)
        return
    end
    if InCombatLockdown() then
        ns.Print(TEXT.LOOT_COMBAT)
        return
    end
    if not D.SlotOpen(slot) then
        ns.Print(TEXT.LOOT_AGAIN)
        return
    end
    LootSlot(slot)
end

local function Finish(p)
    local slot = p.lootSlot
    D.pending = nil
    D.armed = false
    ns.Print(TEXT.DESTROYED:format(p.link or p.name or p.itemID, Coins(p.value)))
    if D.Opened() then D.popup:Hide() end
    TryLoot(slot)
end

local function GiveUp()
    D.pending = nil
    D.armed = false
    if D.Opened() then D.Refresh() else D.Listen(false) end
end

function D.Resolve()
    local p = D.pending
    if not p or not p.mode then return end
    if DialogOpen() then return end
    if D.CursorHolds(p.itemID) then
        if p.mode == "cursor" then return end
        if D.ReturnCursor(p) then
            ns.Print(TEXT.RETURNED)
            return GiveUp()
        end
        p.mode = "cursor"
        ns.Print(TEXT.STUCK)
        if D.Opened() then D.Paint() end
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

local function SameArmed(pick)
    return D.armed and pick.bag == D.armedBag and pick.slot == D.armedSlot and pick.itemID == D.armedID
end

local function Arm(pick)
    D.armed = true
    D.armedBag, D.armedSlot, D.armedID = pick.bag, pick.slot, pick.itemID
    D.Paint()
end

function D.OnDestroy()
    local allow = D.forced
    D.forced = false
    if D.pending or not D.On() then return end
    local pick, loot = D.picks[D.index], D.loots[D.lootIndex]
    if not pick then return end
    if not StillThere(pick) then
        ns.Print(TEXT.MOVED)
        return D.Refresh()
    end
    if not allow and not D.WorthIt(pick, loot) then return D.Paint() end
    if GetCursorInfo() then return ns.Print(TEXT.HOLDING) end
    if InCombatLockdown() then return ns.Print(TEXT.COMBAT) end
    if not SameArmed(pick) then return Arm(pick) end
    D.armed = false
    D.pending = {
        bag = pick.bag, slot = pick.slot, itemID = pick.itemID, link = pick.link, name = pick.name,
        count = pick.count, value = pick.value, owned = GetItemCount(pick.itemID) or 0,
        lootSlot = loot and loot.slot,
    }
    D.Listen(true)
    if InCombatLockdown() then
        D.pending = nil
        return ns.Print(TEXT.COMBAT)
    end
    C_Container.PickupContainerItem(pick.bag, pick.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= pick.itemID then
        D.pending = nil
        ns.Print(TEXT.MOVED)
        return D.Refresh()
    end
    if InCombatLockdown() then
        if D.ReturnCursor(D.pending) then
            D.pending = nil
            ns.Print(TEXT.BLOCKED)
            return D.Refresh()
        end
        D.pending.mode = "cursor"
        ns.Print(TEXT.STUCK)
        return D.Paint()
    end
    DeleteCursorItem()
    if DialogOpen() then
        D.pending.mode = "dialog"
        return D.Paint()
    end
    if D.CursorHolds(pick.itemID) then
        if D.ReturnCursor(D.pending) then
            D.pending = nil
            ns.Print(TEXT.BLOCKED)
            return D.Refresh()
        end
        D.pending.mode = "cursor"
        ns.Print(TEXT.STUCK)
        return D.Paint()
    end
    D.pending.mode = "wait"
    D.Resolve()
    if D.pending and D.Opened() then D.Paint() end
end

function D.OnAnyway()
    D.forced = true
    D.OnDestroy()
end

function D.ReleaseCursor()
    local p = D.pending
    if not p or not D.CursorHolds(p.itemID) then return end
    D.ReturnCursor(p)
end
