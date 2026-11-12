-- Run with Lua 5.1 from the repository root: The Market's My Auctions: your auctions, the undercut check and cancelling.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local function Key(itemID, level, suffix)
    return { itemID = itemID, itemLevel = level or 0, itemSuffix = suffix or 0, battlePetSpeciesID = 0 }
end

local t = World.Setup({
    owned = {
        { auctionID = 1, itemKey = Key(2770), quantity = 20, buyoutAmount = 60, status = 0, timeLeftSeconds = 3600 },
        { auctionID = 2, itemKey = Key(2770), quantity = 5, buyoutAmount = 58, status = 0 },
        { auctionID = 3, itemKey = Key(9999, 30, 7), itemLink = "item:9999", quantity = 1, buyoutAmount = 5000,
          status = 0 },
        { auctionID = 4, itemKey = Key(4306), quantity = 3, buyoutAmount = 100, status = 1 },
        { auctionID = 5, itemKey = Key(1111), quantity = 2, buyoutAmount = 40, status = 0 },
    },
    keyInfo = { [2770] = { isCommodity = true }, [9999] = { isCommodity = false }, [4306] = { isCommodity = true } },
})
local A = t.M.Auctions
local changes = 0
A.onChange = function() changes = changes + 1 end
A.Start()
Check("opening My Auctions asks for your auctions", t.queries == 1)
t.Fire("OWNED_AUCTIONS_UPDATED")
local list = A.list
Check("every auction is read", #list == 5 and list[1].auctionID == 1 and list[3].link == "item:9999")
Check("the first item is checked against the listings", #t.searches == 1 and t.searches[1].key.itemID == 2770)
Check("until it answers, it shows as checking", A.Status(list[1]) == "checking" and A.Status(list[4]) == "sold")
t.results.commodity[2770] = { { unitPrice = 59, quantity = 10, numOwnerItems = 0 },
    { unitPrice = 60, quantity = 20, numOwnerItems = 20 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
local status, low = A.Status(list[1])
Check("someone selling under your price is an undercut", status == "undercut" and low == 59)
Check("one check covers every auction of that item", A.Status(list[2]) == "lowest")
Check("then the next item, by its own key", #t.searches == 2 and t.searches[2].key.itemLevel == 30)
t.results.item[9999] = { { buyoutAmount = 5000, quantity = 1, containsOwnerItem = true } }
t.Fire("ITEM_SEARCH_RESULTS_UPDATED", Key(9999, 30, 7))
Check("only yours listed: still the lowest", A.Status(list[3]) == "lowest" and select(2, A.Status(list[3])) == nil)
Check("an item the client does not know yet waits", #t.searches == 2 and A.Status(list[5]) == "checking")

local undercut, listed = A.Counts()
Check("the counts leave out what has sold", undercut == 1 and listed == 60 * 20 + 58 * 5 + 5000 + 40 * 2)
Check("Cancel Undercut picks the undercut one", A.NextUndercut() == list[1])
Check("cancelling sends its auction", A.Cancel(1) and t.cancels[1] == 1)
Check("a second press before the list comes back cancels nothing again", A.NextUndercut() == nil
    and not A.Cancel(1) and #t.cancels == 1)
t.Fire("AUCTION_CANCELED", 1)
Check("and your auctions are asked for again", t.queries == 2)
t.Fire("OWNED_AUCTIONS_UPDATED")
t.locked[1] = true
Check("an auction the game will not cancel is skipped", A.NextUndercut() == nil and not A.Cancel(1))
Check("a sold one has no cancel", not A.CanCancel(list[4]))

t.keyInfo[1111] = { isCommodity = true }
t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", 1111)
Check("when it arrives, it is checked", #t.searches == 3 and t.searches[3].key.itemID == 1111)
t.RunTimers()
Check("a check with no answer says so", A.Status(list[5]) == "noanswer" and changes > 0)

t = World.Setup({
    owned = {
        { auctionID = 1, itemKey = Key(2770), quantity = 5, buyoutAmount = 60, status = 0 },
        { auctionID = 2, itemKey = Key(2589), quantity = 5, buyoutAmount = 10, status = 0 },
        { auctionID = 3, itemKey = Key(4306), quantity = 5, buyoutAmount = 10, status = 0 },
    },
    keyInfo = { [2770] = { isCommodity = true }, [2589] = { isCommodity = true }, [4306] = { isCommodity = true } },
})
A = t.M.Auctions
A.Start()
t.Fire("OWNED_AUCTIONS_UPDATED")
t.results.commodity[2770] = { { unitPrice = 50, quantity = 5, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
table.remove(t.owned, 1)
t.Fire("OWNED_AUCTIONS_UPDATED")
t.results.commodity[2589] = { { unitPrice = 2, quantity = 5, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
Check("a check answered after the list changed is kept for its own item", A.Status(A.list[1]) == "undercut"
    and A.Status(A.list[2]) == "checking")
A.Stop()

t = World.Setup({ owned = {} })
t.ready = false
t.M.Auctions.Start()
Check("the request waits for the throttle", t.queries == 0)
t.ready = true
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("and goes when it is ready", t.queries == 1)
t.M.Auctions.Stop()
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("closing the page stops listening", t.queries == 1)

t = World.Setup({
    owned = {
        { auctionID = 1, itemKey = Key(2770), quantity = 20, buyoutAmount = 60, status = 0 },
        { auctionID = 2, itemKey = Key(2770), quantity = 5, buyoutAmount = 56, status = 0 },
        { auctionID = 3, itemKey = Key(9999, 30, 7), itemLink = "item:9999", quantity = 1, buyoutAmount = 5000,
          status = 0 },
        { auctionID = 4, itemKey = Key(2589), quantity = 5, buyoutAmount = 10, status = 0 },
    },
    keyInfo = { [2770] = { isCommodity = true }, [9999] = { isCommodity = false }, [2589] = { isCommodity = true } },
})
A = t.M.Auctions
A.Start()
t.Fire("OWNED_AUCTIONS_UPDATED")
list = A.list
Check("before its check an auction has nothing ahead of it", list[1].ahead == 0)
t.results.commodity[2770] = { { unitPrice = 50, quantity = 5, numOwnerItems = 2 },
    { unitPrice = 55, quantity = 7, numOwnerItems = 0 }, { unitPrice = 56, quantity = 5, numOwnerItems = 5 },
    { unitPrice = 60, quantity = 30, numOwnerItems = 20 }, { unitPrice = 70, quantity = 9, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
Check("the items ahead are every cheaper one that is not yours", list[1].ahead == 3 + 7)
Check("listings at your own price are not ahead", list[2].ahead == 3 + 7 and A.Status(list[1]) == "undercut")
t.results.item[9999] = { { buyoutAmount = 4000, quantity = 1, containsOwnerItem = false },
    { buyoutAmount = 4000, quantity = 1, containsOwnerItem = false },
    { buyoutAmount = 4500, quantity = 1, containsOwnerItem = true },
    { buyoutAmount = 5000, quantity = 1, containsOwnerItem = true } }
t.Fire("ITEM_SEARCH_RESULTS_UPDATED", Key(9999, 30, 7))
Check("an item counts each cheaper auction that is not yours", list[3].ahead == 2 and A.Status(list[3]) == "undercut")
Check("with none allowed ahead, every one of them is undercut", (A.Counts()) == 3)

local S = t.M.Settings
S.Set("aheadAllowed", 2)
Check("an auction with no more ahead than you allow is not undercut", A.Status(list[3]) == "ahead"
    and A.Status(list[1]) == "undercut" and (A.Counts()) == 2)
S.Set("aheadAllowed", 10)
Check("it takes more than that many", A.Status(list[1]) == "ahead" and A.Status(list[2]) == "ahead"
    and (A.Counts()) == 0 and A.NextUndercut() == nil)
S.Set("aheadAllowed", 9)
Check("one more ahead and it is undercut again", A.Status(list[1]) == "undercut" and A.NextUndercut() == list[1])
Check("Cancel Undercut can be kept to some auctions", A.NextUndercut(function(auction) return auction == list[2] end)
    == list[2] and A.NextUndercut(function() return false end) == nil)
t.RunTimers()
Check("a check with no answer leaves nothing ahead", A.Status(list[4]) == "noanswer" and list[4].ahead == 0)
A.Stop()
A.Start()
t.Fire("OWNED_AUCTIONS_UPDATED")
Check("opening the page again checks afresh", A.list[1].ahead == 0 and A.Status(A.list[1]) == "checking")
A.Stop()

print("market auctions: " .. checks .. " checks passed")
