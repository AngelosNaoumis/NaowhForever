-- BankMarker.lua: marked bag items deposited in the character bank (ns.BankMarker).
local ns = _G.NaowhForever

local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetItemInfo = C_Item.GetItemInfo

local S = ns.QoLSettings
local Parts, View = ns.Shared.Parts, ns.Shared.View

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local OPEN_DELAY, MOVE_TIMEOUT = 0.25, 2
local POOR, STACK_SIZE = 0, 8
local EMPTY = {}
local MODE = { { move = "Move Automatically", ask = "Ask First", none = "Nothing" }, { "move", "ask", "none" } }
local SCOPE = { { account = "Account", char = "This Character" }, { "account", "char" } }
local MODIFIER = { { alt = "Alt", ctrl = "Ctrl" }, { "alt", "ctrl" } }
local TEXT_MARKED = ns.L(" marked for the bank.")
local TEXT_CLEARED = ns.L(" is no longer marked for the bank.")
local TEXT_ASK = ns.L("Deposit marked items?")
local TEXT_TARGET = ns.L("Character bank")
local TEXT_DEPOSIT, TEXT_NOT_NOW = ns.L("Deposit"), ns.L("Not Now")
local TEXT_RESULT_ONE = ns.L("Deposited 1 stack (%d items); %d marked items remain in your bags.")
local TEXT_RESULT = ns.L("Deposited %d stacks (%d items); %d marked items remain in your bags.")
local TEXT_FULL = ns.L("Not enough room in your character bank; marked items were left in your bags.")
local TEXT_HELP = ns.L("Cycle bag items through Junk, Bank and Unmarked with your marking modifier.")
local TEXT_CLEAR = ns.L("Clear your account and current character bank marks?")
local TEXT_SUMMARY_ONE, TEXT_SUMMARY = ns.L("%d item marked"), ns.L("%d items marked")

local events, panel, bankOpen, offered, offerPending, running, timeoutPending
local waitingID, beforeBags, beforeBank, deadline, moved
local movedStacks, waitingBag, waitingSlot, waitingSize, partialBag, partialSlot
local ids, counts, remaining, held, seen = {}, {}, {}, {}, {}
local guid
local greyBag, greySlot, greyRunning, greyPending
local Step, Offer, CheckTimeout

local Bank = {}
ns.BankMarker = Bank

function Bank.On()
    return S.Get("enabled") and S.Get("bankMarker") == true and not ns.GamepadStandDown()
end

local function Me()
    guid = guid or UnitGUID("player")
    return guid
end

local function AccountMarks()
    return ns.AccountSettings().bankItems or EMPTY
end

local function CharMarks()
    local chars = ns.AccountSettings().bankChars
    return chars and chars[Me()] or EMPTY
end

function Bank.HasMark(id)
    return AccountMarks()[id] == true or CharMarks()[id] == true
end

function Bank.IsMarked(id)
    return Bank.On() and Bank.HasMark(id)
end

local function SellGreyStep()
    greyPending = false
    if not greyRunning or not Bank.On() or not S.Get("sellJunk") or InCombatLockdown()
        or GetCursorInfo() or not MerchantFrame or not MerchantFrame:IsShown() then
        greyRunning = false
        return
    end
    while greyBag <= LAST_BAG do
        while greySlot <= GetContainerNumSlots(greyBag) do
            local bag, slot = greyBag, greySlot
            greySlot = slot + 1
            local info = GetContainerItemInfo(bag, slot)
            if info and not info.isLocked and not info.hasNoValue and not Bank.IsMarked(info.itemID) then
                local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(info.itemID)
                if quality == POOR and price and price > 0 then
                    if InCombatLockdown() or not MerchantFrame:IsShown() or GetCursorInfo() then return end
                    C_Container.UseContainerItem(bag, slot)
                    greyPending = true
                    C_Timer.After(OPEN_DELAY, SellGreyStep)
                    return
                end
            end
        end
        greyBag, greySlot = greyBag + 1, 1
    end
    greyRunning = false
end

function Bank.SellGreys()
    greyBag, greySlot, greyRunning = BACKPACK_CONTAINER, 1, true
    if not greyPending then SellGreyStep() end
end

local function Changed()
    if ns.ScrapMarker then ns.ScrapMarker.Refresh() end
end

function Bank.Clear(id, link)
    local account = ns.AccountSettings()
    if account.bankItems then account.bankItems[id] = nil end
    if account.bankChars and account.bankChars[Me()] then account.bankChars[Me()][id] = nil end
    if link then ns.Print(link .. TEXT_CLEARED) end
    Changed()
end

function Bank.Mark(id, link)
    if not Bank.On() then return false end
    ns.ScrapMarker.Unscrap(id)
    local account = ns.AccountSettings()
    local list
    if S.Get("bankMarkerScope") == "char" and Me() then
        account.bankChars = account.bankChars or {}
        account.bankChars[Me()] = account.bankChars[Me()] or {}
        list = account.bankChars[Me()]
    else
        account.bankItems = account.bankItems or {}
        list = account.bankItems
    end
    list[id], held[id] = true, true
    if link then ns.Print(link .. TEXT_MARKED) end
    Changed()
    return true
end

local function Count(id, first, last)
    local count = 0
    for bag = first, last do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info and info.itemID == id then count = count + (info.stackCount or 1) end
        end
    end
    return count
end

local function Carried(id)
    return Count(id, BACKPACK_CONTAINER, LAST_BAG)
end

local function BankCount(id)
    return Count(id, Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9)
end

local function Fits(info)
    local needed = info.stackCount or 1
    local maximum = select(STACK_SIZE, GetItemInfo(info.hyperlink or info.itemID))
    local family = C_Item.GetItemFamily(info.hyperlink or info.itemID) or 0
    for bag = Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9 do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if not bagFamily or bagFamily == 0 or bit.band(family, bagFamily) ~= 0 then
            for slot = 1, GetContainerNumSlots(bag) do
                local target = GetContainerItemInfo(bag, slot)
                if not target then return true end
                if maximum and target.itemID == info.itemID and target.hyperlink == info.hyperlink
                    and not target.isLocked then
                    needed = needed - math.max(0, maximum - (target.stackCount or 1))
                    if needed <= 0 then return true end
                end
            end
        end
    end
    return false
end

local function Prune()
    if S.Get("bankMarkerSave") then return end
    wipe(seen)
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info then seen[info.itemID] = true end
        end
    end
    for id in pairs(AccountMarks()) do if seen[id] then held[id] = true end end
    for id in pairs(CharMarks()) do if seen[id] then held[id] = true end end
    for id in pairs(held) do
        if not seen[id] then held[id] = nil; Bank.Clear(id) end
    end
end

local function AtBank()
    return bankOpen and Bank.On() and not InCombatLockdown() and not GetCursorInfo()
        and C_Bank.CanUseBank(Enum.BankType.Character)
end

local function Collect()
    wipe(ids)
    wipe(counts)
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            if info and Bank.IsMarked(info.itemID) then
                local id = info.itemID
                if not counts[id] then ids[#ids + 1] = id; counts[id] = 0 end
                counts[id] = counts[id] + (info.stackCount or 1)
            end
        end
    end
end

local function Finish()
    local left = 0
    for id in pairs(remaining) do
        if Bank.HasMark(id) then left = left + Carried(id) end
    end
    if running and moved > 0 then
        ns.Print(movedStacks == 1 and TEXT_RESULT_ONE:format(moved, left)
            or TEXT_RESULT:format(movedStacks, moved, left))
    end
    running, waitingID = false, nil
    wipe(remaining)
end

function CheckTimeout()
    timeoutPending = false
    if not running or not waitingID then return end
    if GetTime() >= deadline then return Finish() end
    timeoutPending = true
    C_Timer.After(deadline - GetTime(), CheckTimeout)
end

local function Observe()
    if not waitingID then return true end
    local count = math.min(beforeBags - Carried(waitingID), BankCount(waitingID) - beforeBank)
    if count <= 0 then return false end
    count = math.min(count, remaining[waitingID])
    remaining[waitingID] = remaining[waitingID] - count
    moved = moved + count
    if partialBag ~= waitingBag or partialSlot ~= waitingSlot then movedStacks = movedStacks + 1 end
    if count < waitingSize then
        partialBag, partialSlot = waitingBag, waitingSlot
    else
        partialBag, partialSlot = nil, nil
    end
    waitingID = nil
    return true
end

function Step()
    if not running then return end
    if not AtBank() or S.Get("bankMarkerMode") == "none" then return Finish() end
    if not Observe() then return end
    for bag = BACKPACK_CONTAINER, LAST_BAG do
        for slot = 1, GetContainerNumSlots(bag) do
            local info = GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and (remaining[id] or 0) > 0 and Bank.IsMarked(id) and not info.isLocked then
                if (info.stackCount or 1) > remaining[id] then return Finish() end
                if not Fits(info) then ns.Print(TEXT_FULL); return Finish() end
                waitingID, beforeBags, beforeBank = id, Carried(id), BankCount(id)
                waitingBag, waitingSlot, waitingSize = bag, slot, info.stackCount or 1
                deadline = GetTime() + MOVE_TIMEOUT
                if not timeoutPending then
                    timeoutPending = true
                    C_Timer.After(MOVE_TIMEOUT, CheckTimeout)
                end
                if not AtBank() or InCombatLockdown() then return Finish() end
                C_Container.UseContainerItem(bag, slot, nil, Enum.BankType.Character)
                return
            end
        end
    end
    Finish()
end

local function Deposit()
    if panel then panel:Hide() end
    if not AtBank() or running then return end
    wipe(remaining)
    for i = 1, #ids do remaining[ids[i]] = counts[ids[i]] end
    running, moved, movedStacks = true, 0, 0
    partialBag, partialSlot = nil, nil
    Step()
end

local Draw = {}

function Draw:Redraw()
    self:Clear()
    self:Add("note", TEXT_TARGET)
    for i = 1, #ids do
        local id = ids[i]
        self:Add("item", id, "x" .. counts[id])
    end
    self:Fit(EMPTY)
end

local function NewView(scroll)
    return View.New(scroll, View.NewKinds(), Draw)
end

local function One() return 1 end

local function HideAsk() panel:Hide() end

local function ClearMarks()
    local account = ns.AccountSettings()
    account.bankItems = nil
    if account.bankChars then account.bankChars[Me()] = nil end
    Changed()
end

local function AskClear()
    ns.Confirm(TEXT_CLEAR, ClearMarks)
end

function Offer()
    offerPending = false
    if offered or not AtBank() then return end
    local ready = false
    for bag = Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_9 do
        if GetContainerNumSlots(bag) > 0 then ready = true; break end
    end
    if not ready then return end
    offered = true
    Collect()
    if #ids == 0 then return end
    local mode = S.Get("bankMarkerMode")
    if mode == "move" then return Deposit() end
    if mode ~= "ask" then return end
    if not panel then
        panel = Parts.SidePanel({ { TEXT_DEPOSIT, Deposit }, { TEXT_NOT_NOW, HideAsk } }, NewView, One)
    end
    panel.title:SetText(TEXT_ASK)
    local owner = _G.EUI_BankFrame
    if not (owner and owner:IsShown()) then owner = BankFrame end
    Parts.ShowBeside(panel, owner)
    panel.view:Redraw()
end

local function OnEvent(_, event)
    if event == "BANKFRAME_OPENED" then
        bankOpen, offered = true, false
        if not offerPending then offerPending = true; C_Timer.After(OPEN_DELAY, Offer) end
    elseif event == "BANKFRAME_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        bankOpen = false
        if panel then panel:Hide() end
        Finish()
        greyRunning = false
    elseif event == "MERCHANT_CLOSED" then
        greyRunning = false
    elseif event == "BAG_UPDATE_DELAYED" or event == "ITEM_LOCK_CHANGED" then
        if running then Step() end
        if bankOpen and not offered and not offerPending then Offer() end
        if event == "BAG_UPDATE_DELAYED" then Prune() end
    end
end

local function Apply()
    if events then events:UnregisterAllEvents() end
    bankOpen = false
    greyRunning = false
    if panel then panel:Hide() end
    Finish()
    if not Bank.On() then return end
    if not events then events = CreateFrame("Frame"); events:SetScript("OnEvent", OnEvent) end
    events:RegisterEvent("BANKFRAME_OPENED")
    events:RegisterEvent("BANKFRAME_CLOSED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("ITEM_LOCK_CHANGED")
    events:RegisterEvent("MERCHANT_CLOSED")
    Prune()
    Changed()
end

S.OnChange(function(key)
    if key == "enabled" or key:find("^bankMarker") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local function Summary()
    local accountMarks, charMarks = AccountMarks(), CharMarks()
    local count = 0
    for _, marked in pairs(accountMarks) do
        if marked == true then count = count + 1 end
    end
    for id, marked in pairs(charMarks) do
        if marked == true and accountMarks[id] ~= true then count = count + 1 end
    end
    return (count == 1 and TEXT_SUMMARY_ONE or TEXT_SUMMARY):format(count)
end

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "bankMarker", name = "Bank Marker", order = 66, switch = "bankMarker", help = TEXT_HELP, summary = Summary,
    rows = {
        { key = "scrapMarkerModifier", label = "Marking Modifier", choice = MODIFIER,
          help = "Choose the key to hold when marking items." },
        { key = "bankMarkerMode", label = "At the Bank", choice = MODE,
          help = "Deposit marked items in your character bank automatically, ask first, or do nothing." },
        { key = "bankMarkerScope", label = "New Marks", choice = SCOPE,
          help = "Choose whether bank marks apply to this character or every character." },
        { key = "bankMarkerSave", label = "Save Marks", toggle = true,
          help = "Remember bank marks after the items leave your bags." },
        { label = "Clear Bank Marks", button = AskClear, buttonText = "Clear",
          help = "Clear all account marks and this character's bank marks." },
    },
})
