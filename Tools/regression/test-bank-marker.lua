-- Bank marking and transfers against a simulated asynchronous character bank.
local settings = { enabled = true, bankMarker = false, bankMarkerMode = "ask", bankMarkerScope = "account",
    bankMarkerSave = false, scrapMarker = true, sellJunk = true }
local listeners, frames, timers, account, messages = {}, {}, {}, {}, {}
local bags = { [0] = {}, [1] = {} }
local bank, requests, now, combat, cursor, usable = {}, {}, 0, false, false, true
local merchantOpen, greySales = false, {}
local bankReady = true
local bankSlots = 4
local bankFamily, itemFamily = 0, 0
local changes, made, pending = 0, 0, nil
local function Nothing() end
local function Wipe(t) for k in pairs(t) do t[k] = nil end return t end
local function Frame()
    made = made + 1
    local f = { events = {}, shown = true }
    function f:SetScript(_, fn) self.handler = fn end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterAllEvents() Wipe(self.events) end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    frames[#frames + 1] = f
    return f
end
local bankFrame = Frame()
local S = { Get = function(key) return settings[key] end, OnChange = function(fn) listeners[#listeners + 1] = fn end }
local panel, card, panelOwner
local ellesmereFrame = Frame()
local ns = { QoLSettings = S, GamepadStandDown = function() return false end, Apply = Nothing,
    QoLConstants = { SELL_PRICE = 11 },
    L = function(text) return text end, Print = function(text) messages[#messages + 1] = text end,
    AccountSettings = function() return account end,
    ScrapMarker = { Unscrap = Nothing, Refresh = function() changes = changes + 1 end },
    Shared = { Parts = {}, Settings = {}, View = {} } }
function ns.Shared.Settings.Page()
    return { Card = function(_, value) card = value end }
end
function ns.Shared.Parts.SidePanel(actions, newView)
    panel = Frame()
    panel.actions, panel.title = actions, { SetText = Nothing }
    panel.view = newView(panel)
    return panel
end
ns.Shared.Parts.ShowBeside = function(p, owner) p.shown = true; panelOwner = owner end
ns.Shared.View.NewKinds = function() return {} end
ns.Shared.View.New = function(_, _, mixin)
    return setmetatable({ Clear = Nothing, Add = Nothing, Fit = Nothing }, { __index = mixin })
end
local env = setmetatable({ _G = { NaowhForever = ns, EUI_BankFrame = ellesmereFrame }, wipe = Wipe, CreateFrame = Frame,
    UnitGUID = function() return "Player-1" end, InCombatLockdown = function() return combat end,
    GetCursorInfo = function() return cursor and "item" or nil end, GetTime = function() return now end,
    BankFrame = bankFrame, MerchantFrame = { IsShown = function() return merchantOpen end },
    BACKPACK_CONTAINER = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 1,
    Enum = { BankType = { Character = 0 }, BagIndex = { CharacterBankTab_1 = 6, CharacterBankTab_9 = 14 } },
    C_Bank = { CanUseBank = function(kind) assert(kind == 0); return usable end },
    C_Container = {
        GetContainerNumSlots = function(bag)
            if bags[bag] then return 4 end
            return bag == 6 and bankReady and bankSlots or 0
        end,
        GetContainerNumFreeSlots = function() return 0, bankFamily end,
        GetContainerItemInfo = function(bag, slot)
            if bags[bag] then return bags[bag][slot] end
            if bag == 6 then
                local n = 0
                for id, count in pairs(bank) do
                    n = n + 1
                    if n == slot then return { itemID = id, stackCount = count } end
                end
            end
        end,
        GetContainerItemID = function(bag, slot) local i = bags[bag] and bags[bag][slot]; return i and i.itemID end,
        UseContainerItem = function(bag, slot, unit, kind)
            if kind == nil then
                assert(merchantOpen and not combat and not cursor)
                greySales[#greySales + 1] = bags[bag][slot].itemID
                bags[bag][slot] = nil
                return
            end
            assert(not combat and not cursor and usable and kind == 0 and unit == nil)
            requests[#requests + 1] = bags[bag][slot].itemID
            pending = { bag, slot, bags[bag][slot].itemID, bags[bag][slot].stackCount }
        end },
    C_Item = { GetItemInfo = function() return nil, nil, 0, nil, nil, nil, nil, 20, nil, nil, 1 end,
        GetItemFamily = function() return itemFamily end },
    bit = { band = function(a, b) return a == b and a or 0 end },
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { now + delay, fn } end },
    hooksecurefunc = function(t, key, fn)
        local original = t[key]
        t[key] = function(...) original(...); fn(...) end
    end,
}, { __index = _G })
local function Load(path) local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk() end
local function Fire(event)
    for _, f in ipairs(frames) do if f.events[event] then f.handler(f, event) end end
end
local function Set(key, value)
    settings[key] = value
    for _, fn in ipairs(listeners) do fn(key) end
end
local function Advance(seconds)
    now = now + seconds
    local due = {}
    for i = #timers, 1, -1 do
        if timers[i][1] <= now then table.insert(due, 1, table.remove(timers, i)[2]) end
    end
    for _, fn in ipairs(due) do fn() end
end
local function Put(slot, id, count) bags[0][slot] = { itemID = id, stackCount = count or 1 } end
local function Settle(count)
    local bag, slot, id, before = unpack(pending)
    local moved = count or before
    bank[id] = (bank[id] or 0) + moved
    bags[bag][slot] = moved < before and { itemID = id, stackCount = before - moved } or nil
    pending = nil
    Fire("BAG_UPDATE_DELAYED")
end
local before = made
Load("NaowhForever_QoL/Loot/BankMarker.lua")
ns.Apply()
assert(made == before, "disabled feature creates no frames")
assert(card.switch == "bankMarker")
local Bank = assert(ns.BankMarker)
Set("bankMarker", true)
Put(1, 201, 20)
Bank.Mark(201)
assert(Bank.IsMarked(201) and changes > 0)
Fire("BANKFRAME_OPENED")
Advance(1)
assert(panel and panel.shown and #requests == 0, "ask mode waits for consent")
assert(panelOwner == ellesmereFrame, "confirmation anchors to the visible Ellesmere bank")
panel.actions[1][2]()
assert(#requests == 1 and pending, "deposit starts one request")
Fire("ITEM_LOCK_CHANGED")
assert(#requests == 1, "unsettled action is not repeated")
Settle()
assert(bank[201] == 20 and not Bank.IsMarked(201), "successful deposit prunes an unsaved mark")
assert(messages[#messages]:find("Deposited 1 stack (20 items)", 1, true), "summary distinguishes stacks and individual items")
Fire("BANKFRAME_CLOSED")
Set("bankMarkerSave", true)
Set("bankMarkerMode", "move")
Put(1, 202, 10)
Bank.Mark(202)
Fire("BANKFRAME_OPENED")
Advance(1)
Settle(4)
assert(Bank.IsMarked(202) and bags[0][1].stackCount == 6, "partial transfer retains mark")
Advance(5)
assert(Bank.IsMarked(202), "full bank does not clear a mark")
local count = #requests
Put(2, 202)
Fire("BAG_UPDATE_DELAYED")
assert(#requests == count, "bag updates do not start another session")
Fire("BANKFRAME_CLOSED")
combat = true
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == count, "combat prevents deposits")
combat = false
Fire("BANKFRAME_CLOSED")
cursor = true
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == count, "occupied cursor prevents deposits")
cursor = false
Fire("BANKFRAME_CLOSED")
usable = false
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == count, "unavailable character bank prevents deposits")
usable = true
Set("bankMarker", false)
for _, f in ipairs(frames) do assert(next(f.events) == nil, "disabled events released") end
Advance(5)
assert(#requests == count, "disabled feature cancels delayed work")
assert(not Bank.IsMarked(202), "disabled marks are inactive")
Set("bankMarker", true)
merchantOpen = true
Put(1, 301)
Put(2, 302)
Bank.Mark(301)
Bank.SellGreys()
Advance(1)
assert(bags[0][1] and not bags[0][2] and #greySales == 1 and greySales[1] == 302,
    "selective grey selling protects bank marks and sells other greys")
merchantOpen = false
Fire("MERCHANT_CLOSED")
Fire("BANKFRAME_CLOSED")
bankReady = false
local requested = #requests
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == requested, "unloaded bank is not used")
bankReady = true
Fire("BAG_UPDATE_DELAYED")
assert(#requests == requested + 1, "inventory readiness starts the deferred offer")
Fire("BANKFRAME_CLOSED")
Advance(3)
assert(#requests == requested + 1, "closing cancels an in-flight session")
Set("bankMarkerMode", "none")
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == requested + 1, "Nothing mode does not deposit")
Fire("BANKFRAME_CLOSED")
Set("bankMarkerMode", "ask")
Fire("BANKFRAME_OPENED")
Advance(1)
Bank.Clear(301)
panel.actions[1][2]()
assert(#requests == requested + 1, "cleared marks are rechecked after confirmation")
Fire("BANKFRAME_CLOSED")
Put(1, 303, 5)
Bank.Mark(303)
Fire("BANKFRAME_OPENED")
Advance(1)
Put(1, 303, 10)
panel.actions[1][2]()
assert(#requests == requested + 1, "confirmation never deposits a larger newly merged stack")
Fire("BANKFRAME_CLOSED")
Set("bankMarkerScope", "char")
Bank.Mark(304)
assert(account.bankChars["Player-1"][304] and not (account.bankItems or {})[304], "character marks use the GUID")
Set("bankMarkerMode", "move")
Wipe(bags[0]); Wipe(bags[1]); Wipe(bank)
bankSlots = 1
bank[401] = 20
Put(1, 402, 15)
Bank.Mark(402)
local fullRequests = #requests
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == fullRequests and Bank.IsMarked(402), "full bank is checked before issuing a move")
assert(table.concat(messages, "\n"):find("Not enough room in your character bank", 1, true), "full bank is reported in chat")
Fire("BANKFRAME_CLOSED")
Wipe(bank)
bank[402] = 5
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == fullRequests + 1, "room in a matching stack permits a deposit without empty slots")
Settle()
assert(bank[402] == 20, "matching stack capacity is used")
Fire("BANKFRAME_CLOSED")
bank[402] = 10
Put(1, 402, 15)
local beforeCapacity = #requests
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == beforeCapacity, "insufficient matching stack space is rejected before moving")
Fire("BANKFRAME_CLOSED")
bankSlots, bankFamily = 2, 4
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == beforeCapacity, "empty incompatible specialty slots do not count as space")
Fire("BANKFRAME_CLOSED")
itemFamily = 4
Fire("BANKFRAME_OPENED")
Advance(1)
assert(#requests == beforeCapacity + 1, "empty compatible specialty slots count as space")
account.bankItems = { [201] = true }
account.bankChars = { ["Player-1"] = { [201] = true, [202] = true }, ["Player-2"] = { [203] = true } }
assert(card.summary() == "2 items marked", "summary counts distinct marks for this character")
Bank.Clear(202)
assert(card.summary() == "1 item marked", "summary updates when a mark is cleared")
Bank.Clear(201)
assert(card.summary() == "0 items marked", "summary excludes marks for other characters")
print("test-bank-marker: passed")
