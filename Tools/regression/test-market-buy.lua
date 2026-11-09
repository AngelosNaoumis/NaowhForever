-- Run with Lua 5.1 from the repository root: The Market's Buy: the name search, the cost of a quantity, and buying.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local function Key(itemID, level)
    return { itemID = itemID, itemLevel = level or 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

local t = World.Setup({ keyInfo = { [2589] = { isCommodity = true }, [9999] = { isCommodity = false } } })
local B, L = t.M.Buy, t.M.Listings
local bought, watchers = {}, {}
t.ns.Professions = { Shopping = {
    Materials = function() return { { item = 2589, qty = 30, name = "Linen Cloth" } } end,
    Bought = function(item, qty) bought[#bought + 1] = { item = item, qty = qty } end,
    OnChange = function(fn) watchers[#watchers + 1] = fn end,
} }
B.Open()
L.Start()

t.ready = false
B.Search("linen")
Check("a search waits for the throttle", #t.browses == 0)
t.ready = true
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
Check("and is sent by name when it is ready", t.browses[1] == "linen" and B.searching)
t.browse = { { itemKey = Key(2589), totalQuantity = 300, minPrice = 24 } }
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Check("its results are read", #B.results == 1 and B.results[1].minPrice == 24 and not B.searching)
local redraws = 0
B.onChange = function() redraws = redraws + 1 end
t.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", 1234)
t.Fire("AUCTION_HOUSE_SHOW_ERROR", 0)
Check("events with nothing to do redraw nothing", redraws == 0)
B.onChange = nil
Check("the Shopping List comes from Professions", B.ShoppingList()[1].qty == 30)
Check("the Buy page is told when the Shopping List changes", B.WatchShopping(print) and watchers[1] == print)
local professions = t.ns.Professions
t.ns.Professions = nil
Check("and watches nothing without Professions", not B.WatchShopping(print))
t.ns.Professions = professions

B.Pick(B.results[1].itemKey)
Check("picking a commodity asks for its listings", t.searches[1].key.itemID == 2589 and B.picked.commodity)
t.results.commodity[2589] = { { unitPrice = 24, quantity = 10, numOwnerItems = 4 },
    { unitPrice = 30, quantity = 100, numOwnerItems = 0 } }
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
local cost, short = B.Cost(10)
Check("the cost takes the cheapest first and never your own", cost == 6 * 24 + 4 * 30 and short == 0)
Check("more than is listed is short", select(2, B.Cost(200)) == 200 - 106)
Check("too many is not bought", not B.Purchase(200) and #t.purchases == 0)

Check("buying asks the game for a price", B.Purchase(10) and t.purchases[1].step == "start"
    and t.purchases[1].quantity == 10 and B.purchase.state == "quoting")
t.Fire("COMMODITY_PRICE_UPDATED", 27, 270)
Check("its quote is shown", B.purchase.state == "quoted" and B.purchase.total == 270 and not B.purchase.over)
Check("the second press confirms it", B.Purchase(10) and t.purchases[2].step == "confirm"
    and t.purchases[2].quantity == 10 and B.purchase.state == "buying")
t.Fire("COMMODITY_PURCHASE_SUCCEEDED")
Check("bought: the Shopping List is told", B.purchase.state == "bought" and bought[1].item == 2589
    and bought[1].qty == 10)
Check("and the listings are asked for again", #t.searches == 2)

B.Purchase(10)
t.Fire("COMMODITY_PRICE_UPDATED", 40, 400)
Check("a quote well over the listings is flagged", B.purchase.over)
B.Pick(B.results[1].itemKey)
Check("picking again cancels the open quote", t.purchases[#t.purchases].step == "cancel")
t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
B.Purchase(5)
t.Fire("COMMODITY_PRICE_UNAVAILABLE")
Check("nothing left at that price says so", B.purchase.state == "unavailable")
B.Purchase(5)
t.Fire("COMMODITY_PRICE_UPDATED", 24, 120)
B.Purchase(5)
t.Fire("COMMODITY_PURCHASE_FAILED")
Check("a failed purchase says so", B.purchase.state == "failed" and #bought == 1)

B.Pick(Key(9999, 30))
Check("picking gear searches its own key", t.searches[#t.searches].key.itemLevel == 30 and not B.picked.commodity)
t.results.item[9999] = { { auctionID = 11, buyoutAmount = 5000, quantity = 1, containsOwnerItem = true },
    { auctionID = 12, buyoutAmount = 5000, quantity = 1, containsOwnerItem = false },
    { auctionID = 13, buyoutAmount = 6000, quantity = 1, containsOwnerItem = false } }
t.Fire("ITEM_SEARCH_RESULTS_UPDATED", Key(9999, 30))
Check("gear buys the cheapest auction that is not yours", B.Purchase(1) and t.bids[1].auctionID == 12
    and t.bids[1].amount == 5000)
t.Fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 99)
Check("another auction's purchase is not ours", B.purchase.state == "buying")
t.Fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 12)
Check("ours is bought, and gear never touches the Shopping List", B.purchase.state == "bought" and #bought == 1)
B.Purchase(1)
t.Fire("AUCTION_HOUSE_SHOW_ERROR", 0)
Check("an error while buying fails it", B.purchase.state == "failed")
t.money = 100
Check("not enough gold buys nothing", not B.Purchase(1) and #t.bids == 2)

local searched = #t.searches
B.Pick(Key(4444))
Check("an item the client does not know yet waits", B.picked.waiting and #t.searches == searched)
t.keyInfo[4444] = { isCommodity = true }
t.Fire("ITEM_KEY_ITEM_INFO_RECEIVED", 4444)
Check("and is searched when it arrives", not B.picked.waiting and t.searches[searched + 1].key.itemID == 4444)

B.Close()
t.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
Check("closing the page stops listening", #B.results == 1)

print("market buy: " .. checks .. " checks passed")
