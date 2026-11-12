-- DestroyCheapest.lua: when bags are full, the state the scan, the popup and the delete share.
local ns = _G.NaowhForever

local GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots

local S = ns.QoLSettings

local D = {}
ns.DestroyCheapest = D

local PLAIN = ns.QoLConstants.PLAIN_BAG
local TRANSFER_FRAMES = {
    "BankFrame", "EUI_BankFrame", "MailFrame", "TradeFrame",
    "MerchantFrame", "GuildBankFrame", "QuestFrame",
}
D.TRANSFER_FRAMES = TRANSFER_FRAMES

D.STALE_DAYS = 7
D.STALE_RANGE = { 1, 30, 1 }
D.TEXT = {
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
    CONFIRM = "Click again to destroy",
    ANYWAY = "Destroy Anyway",
    DESTROY_LOOT = "Destroy & Loot",
    DESTROY_ONLY = "Destroy",
}

D.picks, D.pool, D.used = {}, {}, 0
D.loots, D.lootPool, D.lootUsed = {}, {}, 0
D.index, D.lootIndex = 1, 1
D.waitingInfo, D.requested = {}, {}
D.pendingLoads, D.loadCount = {}, 0
D.setItems = {}
D.transferHooks = {}
D.watch = CreateFrame("Frame")

function D.On()
    return S.Get("enabled") and S.Get("destroyCheapest")
end

function D.IsPlain(bag)
    local _, family = GetContainerNumFreeSlots(bag)
    return family == nil or family == PLAIN
end

function D.PlainFree()
    local free = 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
    for bag = BACKPACK_CONTAINER, last do
        if D.IsPlain(bag) then
            local n = GetContainerNumFreeSlots(bag)
            free = free + (n or 0)
        end
    end
    return free
end

function D.BagsFull(a, b)
    return b == ERR_INV_FULL or b == ERR_BAG_FULL or a == ERR_INV_FULL or a == ERR_BAG_FULL
end

function D.LootShown()
    return LootFrame:IsShown()
end

function D.TransferShown()
    if not S.Get("destroyCheapestTransfers") then return false end
    for i = 1, #TRANSFER_FRAMES do
        local frame = _G[TRANSFER_FRAMES[i]]
        if frame and frame.IsShown and frame:IsShown() then return true end
    end
    return false
end

function D.CursorHolds(itemID)
    local kind, id = GetCursorInfo()
    return kind == "item" and id == itemID
end

function D.Ignored(itemID)
    local db = S.DB()
    local own = db and db.destroyCheapestIgnore
    return own and own[itemID] ~= nil or false
end

function D.IgnoreAdd(itemID)
    local db = S.DB()
    local list = db.destroyCheapestIgnore
    if type(list) ~= "table" then
        list = {}
        db.destroyCheapestIgnore = list
    end
    list[itemID] = time()
end

function D.Opened()
    return D.popup and D.popup:IsShown()
end
