-- Run with Lua 5.1 from the repository root: The Market's sell queue, its prices from the listings, and posting.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local World = dofile("Tools/regression/market_world.lua")
local Setup, Stack = World.Setup, World.Stack
local COMMODITY, ITEM, UNKNOWN = World.COMMODITY, World.ITEM, World.UNKNOWN

local t = Setup({
    bags = { [0] = { Stack(2770, 20), Stack(2770, 5), Stack(6948, 1, { isBound = true }), Stack(4306, 3) },
        [1] = { Stack(9999, 1, { hyperlink = "item:9999:suffix1" }), Stack(9999, 1, { hyperlink = "item:9999:suffix2" }),
            Stack(1234, 1, { invalid = true }) } },
    status = { [2770] = COMMODITY, [4306] = COMMODITY, [9999] = ITEM },
    scan = { [2770] = 60, [4306] = 100 },
    vendor = { [2770] = 5, [4306] = 99, [9999] = 2000 },
})
local M = t.M
Check("posts run for Blizzard's own default duration until you pick one", M.Sell.Duration() == 2)
local loading = M.Sell.Read()
Check("every item's slots add up to one entry", M.Bags.Get(2770).count == 25 and not loading)
Check("an item that is not a commodity is one entry per link", M.Bags.Get("item:9999:suffix1").count == 1
    and M.Bags.Get("item:9999:suffix2").count == 1)
Check("bound items and ones the auction house refuses are left out", M.Bags.Get(6948) == nil and M.Bags.Get(1234) == nil)
local queue = M.Sell.queue
Check("the queue is priced items by worth, then unpriced, then the vendor's", #queue == 4 and queue[1].key == 2770
    and queue[2].key:find("9999") and queue[3].key:find("9999") and queue[4].key == 4306)
Check("an item a vendor pays more for, after the cut, is the vendor's", queue[4].vendorBetter and not queue[1].vendorBetter)

M.Listings.Start()
M.Sell.Keep()
Check("the most valuable item is picked first and its listings asked for", M.Sell.Focus().key == 2770
    and #t.searches == 1 and t.searches[1].kind == "search" and t.searches[1].key.itemID == 2770)
Check("until they answer, it is priced at your scan", M.Sell.Price(M.Sell.Focus()) == 60
    and M.Listings.state == "searching")
t.results.commodity[2770] = { { unitPrice = 50, quantity = 3, numOwnerItems = 0 },
    { unitPrice = 52, quantity = 100, numOwnerItems = 0 }, { unitPrice = 70, quantity = 40, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 4306)
Check("another item's results change nothing", M.Listings.state == "searching")
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
local price, why, ref = M.Sell.Price(M.Sell.Focus())
Check("listed: a copper under the cheapest listing", M.Listings.state == "listed" and price == 49 and why == "under"
    and ref == 50)
Check("Up steps to just under the next listing", M.Sell.StepPrice(M.Sell.Focus(), true)
    and M.Sell.Price(M.Sell.Focus()) == 51)
Check("and Down back", M.Sell.StepPrice(M.Sell.Focus(), false) and M.Sell.Price(M.Sell.Focus()) == 49)
Check("a price stepped to is your own", select(2, M.Sell.Price(M.Sell.Focus())) == "hand")
M.Sell.SetPrice(2770, 0)
t.results.commodity[2770][1].numOwnerItems = 3
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
price, why = M.Sell.Price(M.Sell.Focus())
Check("yours already the cheapest: matched, never undercut", price == 50 and why == "yours")
t.results.commodity[2770] = {}
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
price, why = M.Sell.Price(M.Sell.Focus())
Check("nobody selling: your scan's price", price == 60 and why == "scan")

t.RunTimers()
Check("an answered search does not time out", M.Listings.state == "listed")
M.Sell.Pick(4306)
t.RunTimers()
Check("an unanswered one does", M.Listings.state == "noanswer")

t.ready = false
M.Sell.Pick(2770)
Check("a search waits for the auction house's throttle", M.Listings.state == "waiting" and #t.searches == 2)
t.ready = true
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("and goes when it is ready", M.Listings.state == "searching" and #t.searches == 3)
local onChange, changes = M.Listings.onChange, 0
M.Listings.onChange = function() changes = changes + 1 end
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("the throttle freeing with nothing waiting redraws nothing", changes == 0)
M.Listings.onChange = onChange

M.Sell.Pick("item:9999:suffix1")
local gear = t.searches[#t.searches]
Check("an item that is not a commodity searches by its own key", gear.kind == "search" and gear.key.itemLevel == 30)
t.results.item[9999] = { { buyoutAmount = 3000, quantity = 1, containsOwnerItem = false },
    { buyoutAmount = 3000, quantity = 1, containsOwnerItem = true }, { quantity = 1, containsOwnerItem = false },
    { buyoutAmount = 4000, quantity = 2, containsOwnerItem = false } }
t.Fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 9999 })
Check("same buyouts are one rung and bids without a buyout are left out", M.Listings.count == 2
    and M.Listings.rows[1].quantity == 2 and M.Listings.rows[1].own == 1 and M.Listings.rows[2].price == 4000)
price, why = M.Sell.Price(M.Sell.Focus())
Check("tied with your own auction, it matches rather than undercuts you", price == 3000 and why == "yours")
t.results.item[9999][2].containsOwnerItem = false
t.Fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 9999 })
price, why = M.Sell.Price(M.Sell.Focus())
Check("only commodities take copper: an item undercuts by a silver", price == 2900 and why == "under"
    and not M.Sell.Copper(M.Sell.Focus()) and M.Sell.Copper(M.Bags.Get(2770)))
Check("and steps in silver", M.Sell.StepPrice(M.Sell.Focus(), true) and M.Sell.Price(M.Sell.Focus()) == 3900)

t = Setup({ bags = { [0] = { Stack(2770, 20) } }, status = { [2770] = COMMODITY }, scan = { [2770] = 1234 },
    vendor = { [2770] = 5 }, copper = false })
M = t.M
M.Sell.Read()
M.Listings.Start()
M.Sell.Keep()
Check("without copper on the auction house, the scan's price drops to silver", (M.Sell.Price(M.Sell.Focus())) == 1200)
t.results.commodity[2770] = { { unitPrice = 1500, quantity = 3, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
Check("and the undercut is a silver", (M.Sell.Price(M.Sell.Focus())) == 1400)

t = Setup({ bags = { [0] = { Stack(2770, 20) } }, status = { [2770] = COMMODITY }, vendor = { [2770] = 7 } })
M = t.M
M.Sell.Read()
M.Listings.Start()
M.Sell.Keep()
t.results.commodity[2770] = {}
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
price, why = M.Sell.Price(M.Sell.Focus())
Check("no listings and no scan: half again what a vendor pays, up to a silver", price == 100 and why == "vendor")

t = Setup({ bags = { [0] = { Stack(2770, 20), Stack(4306, 3), Stack(5555, 2) } },
    status = { [2770] = COMMODITY, [4306] = COMMODITY, [5555] = COMMODITY }, scan = { [2770] = 60, [4306] = 100, [5555] = 10 },
    vendor = { [2770] = 5, [4306] = 99, [5555] = 1 } })
M = t.M
M.Sell.Read()
M.Listings.Start()
M.Post.Start()
M.Sell.Keep()
local done = {}
M.Post.onDone = function(key, quantity, each, ok) done[#done + 1] = { key = key, quantity = quantity, price = each, ok = ok } end
Check("a post goes up as a commodity with its price, count and duration",
    M.Post.Send(M.Sell.Focus(), 20, 59, 2) and t.posts[1].kind == "commodity" and t.posts[1].quantity == 20
    and t.posts[1].price == 59 and t.posts[1].duration == 2 and t.posts[1].loc.bag == 0)
Check("nothing else posts until the game answers", not M.Post.Ready() and not M.Post.Send(M.Sell.Focus(), 1, 59, 1))
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 77)
Check("the auction made is the answer", #done == 1 and done[1].ok and done[1].key == 2770 and M.Post.Ready())
M.Sell.Posted(2770, 20, 59)
local postedTotal = M.Sell.Totals()
Check("what you posted is counted", postedTotal == 20 * 59 and #M.Sell.postedOrder == 1)
M.Sell.Next()
Check("Next skips what a vendor should have", M.Sell.Focus().key == 5555)

t.needsConfirm = true
Check("a post the game wants confirmed waits", M.Post.Send(M.Sell.Focus(), 2, 9, 1) and #done == 1
    and t.hooks[#t.hooks - 1] == "OnAccept")
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 78)
Check("nothing counts before it is confirmed", #done == 1)
t.dialog.OnAccept(t.dialog, nil)
Check("the game's own Accept confirms ours, with the same arguments", #t.confirms == 1 and t.confirms[1].quantity == 2
    and t.confirms[1].price == 9)
t.dialog.OnHide(t.dialog, nil)
Check("closing the confirmed warning is not a cancel", #done == 1)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 79)
Check("then the auction made answers it", #done == 2 and done[2].ok)
M.Post.Send(M.Sell.Focus(), 2, 9, 1)
t.dialog.OnHide(t.dialog, nil)
Check("a warning closed without Accept is not posted", #done == 3 and not done[3].ok and #t.confirms == 1)
t.needsConfirm = false
M.Post.Send(M.Sell.Focus(), 2, 9, 1)
t.RunTimers()
Check("no answer at all frees the post line", #done == 4 and not done[4].ok and M.Post.Ready())

t = Setup({ bags = { [0] = { Stack(9999, 1), Stack(9999, 1) } }, status = { [9999] = ITEM } })
M = t.M
M.Sell.Read()
M.Post.Start()
done = {}
M.Post.onDone = function(key, _, _, ok) done[#done + 1] = { key = key, ok = ok } end
M.Post.Send(M.Bags.Get("item:9999"), 2, 5000, 3)
Check("identical items post together, priced each, with no bid", t.posts[1].kind == "item" and t.posts[1].quantity == 2
    and t.posts[1].price == 5000 and t.posts[1].bid == nil)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
t.Fire("AUCTION_MULTISELL_UPDATE", 1, 2)
Check("a multisell answers when its last auction is made", #done == 0)
t.Fire("AUCTION_MULTISELL_UPDATE", 2, 2)
Check("and only then", #done == 1 and done[1].ok)
M.Post.Send(M.Bags.Get("item:9999"), 2, 5000, 3)
local firstTimeout = t.timers[#t.timers]
t.Fire("AUCTION_MULTISELL_UPDATE", 1, 2)
firstTimeout()
Check("each auction a multisell makes gives it longer to answer", #done == 1 and M.Post.Waiting())
t.Fire("AUCTION_MULTISELL_UPDATE", 2, 2)
Check("and it still answers when done", #done == 2 and done[2].ok)

t = Setup({ bags = { [0] = { Stack(2770, 20) } }, status = { [2770] = UNKNOWN } })
loading = t.M.Sell.Read()
Check("an item the client has not loaded waits for its data", loading and t.loads == 1 and #t.M.Sell.queue == 0)

print("market sell: " .. checks .. " checks passed")
