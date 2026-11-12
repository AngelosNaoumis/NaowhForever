-- Run with Lua 5.1 from the repository root: the listings under The Market's Sell form. The item in front of you
-- shows its listings cheapest first, with a marker where your price lands; a click takes a row's price, Cancel takes
-- your own auction down after the house confirm, and Buy buys: an item at its buyout from the confirm's click, a
-- commodity in the two clicks the game needs, the quote first and the purchase from the confirm that names its total.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM

local ORE, GEAR = 2770, 9999
local ACCENT = { r = 0, g = 0.5, b = 0.9 }

local function Setup(account)
    local t = Page.Setup({ bags = { [0] = { Stack(ORE, 20), Stack(GEAR, 1) } }, status = { [ORE] = COMMODITY, [GEAR] = ITEM },
        scan = { [ORE] = 500 }, vendor = { [ORE] = 5, [GEAR] = 20 }, money = 100000 })
    for k, v in pairs(account or {}) do t.account[k] = v end
    return t
end

local function Pane(t)
    for _, f in ipairs(t.frames) do
        if rawget(f, "mark") then return f end
    end
end

local function Ore(t, rows)
    t.results.commodity[ORE] = rows
    t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", ORE)
end

local function Gear(t, rows)
    t.results.item[GEAR] = rows
    t.Fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = GEAR })
end

local ORE_ROWS = {
    { unitPrice = 480, quantity = 5, numOwnerItems = 0 },
    { unitPrice = 500, quantity = 30, numOwnerItems = 10, auctionID = 71 },
    { unitPrice = 520, quantity = 8, numOwnerItems = 8, auctionID = 72 },
    { unitPrice = 600, quantity = 100, numOwnerItems = 0 },
}

local t = Setup()
t.ns.THEME.accent = ACCENT
local Sell = t.M.Sell
t.page.Show()
local pane = Pane(t)
Check("the listings sit between the form and Up Next, open until folded", pane ~= nil and pane.shown and pane.status.shown
    and pane.title.text == "Listings")
Check("while the auction house is asked they read Checking", pane.status.text == "Checking" and #t.Lines() == 0)
local loading = pane.height

Ore(t, ORE_ROWS)
local lines = t.Lines()
Check("each listing is a row, cheapest first, counted in the head", #lines == 4 and pane.title.text == "Listings (4)"
    and lines[1].price.text == "480" and lines[4].price.text == "600")
Check("with its quantity", lines[1].quantity.text == "x5" and lines[4].quantity.text == "x100")
Check("yours are marked, the others are not", not lines[1].yours.shown and lines[2].yours.shown and lines[3].yours.shown
    and not lines[4].yours.shown)
Check("the cheapest that is not yours has the accent price", lines[1].price.color.b == ACCENT.b
    and lines[2].price.color.b ~= ACCENT.b)
Check("the rows take the room the Checking line had and more", pane.height > loading)
Check("the marker sits where your price lands: before the first dearer row", (Sell.Price(Sell.Focus())) == 479
    and pane.mark.y == 0 and lines[1].y == 12)

t.Click(lines[2])
local price, why = Sell.Price(Sell.Focus())
Check("a click takes that row's price, as one set by hand", price == 500 and why == "hand" and t.moneys[1].amount == 500)
lines = t.Lines()
Check("and the marker moves under the rows at or below it", lines[1].y == 0 and lines[2].y == 18 and pane.mark.y == 36
    and lines[3].y == 48)
t.moneys[1].Type(10000)
Check("a price over every listing puts the marker last", pane.mark.y == 72)
Sell.SetPrice(ORE, 100)
t.post.click()
Check("Ask Before a Bad Post still weighs a price taken or typed", #t.posts == 0 and #t.confirms == 1)
t.confirms[1].no()
Sell.SetPrice(ORE, 0)
t.page.Draw()

t.Hover(lines[1])
Check("hovering another's row offers Buy, and says so", lines[1].buy.shown and lines[1].cancel == nil
    and t.tips[1] == "Click to take this price." and t.tips[2] == "Buy takes the 5 listed up to this price, about 2400.")
t.Hover(lines[3])
Check("hovering yours offers Cancel in place of the Yours mark", lines[3].cancel.shown and lines[3].buy == nil
    and not lines[3].yours.shown and t.tips[2] == "Cancel takes your auction down.")
t.Hover(lines[2])
Check("a price you share with others offers both", lines[2].buy.shown and lines[2].cancel.shown and #t.tips == 3
    and t.tips[2] == "Buy takes the 25 listed up to this price, about 12400.")
lines[1].IsMouseOver = function() return true end
Ore(t, { { unitPrice = 480, quantity = 5, numOwnerItems = 5, auctionID = 70 }, ORE_ROWS[4] })
Check("a row under the mouse that turns all yours loses its Buy", not lines[1].buy.shown and lines[1].cancel.shown)
lines[1].IsMouseOver = nil
Ore(t, ORE_ROWS)
lines = t.Lines()

lines[3].cancel.click()
Check("Cancel asks first, as My Auctions does", #t.cancels == 0 and #t.confirms == 2
    and t.confirms[2].text == "Cancel Item 2770? The items come back by mail.")
t.confirms[2].no()
Check("No cancels nothing", #t.cancels == 0)
lines[3].cancel.click()
t.confirms[3].yes()
Check("Yes is the click that cancels that auction", #t.cancels == 1 and t.cancels[1] == 72)
local searches = #t.searches
t.Fire("AUCTION_CANCELED", 72)
Check("and the listings are read again", #t.searches == searches + 1)
Ore(t, ORE_ROWS)
lines = t.Lines()
t.Hover(lines[3])
lines[3].cancel.click()
t.confirms[#t.confirms].yes()
Check("an auction once cancelled is not cancelled twice", #t.cancels == 1)

local function BuyAll(line)
    local asked = #t.prompts
    line.buy.click()
    local prompt = t.prompts[#t.prompts]
    if #t.prompts > asked then prompt.accept(prompt.text) end
end
t.Hover(lines[2])
BuyAll(lines[2])
Check("Buy on a commodity asks the game for its price first, with no confirm yet", #t.purchases == 1
    and t.purchases[1].step == "start" and t.purchases[1].itemID == ORE and t.purchases[1].quantity == 25
    and pane.note.text == "Getting the price")
local asked = #t.confirms
BuyAll(lines[2])
Check("a second Buy waits for the first", #t.purchases == 1)
t.Fire("COMMODITY_PRICE_UPDATED", 497, 12425)
local confirm = t.confirms[#t.confirms]
Check("the game's quote opens the confirm: the quantity, the item and the total quoted", #t.confirms == asked + 1
    and confirm.text == "Buy 25 Item 2770 for 12425?" and confirm.yesText == "Buy" and #t.purchases == 1)
t.post.click()
Check("Post does nothing while it asks", #t.posts == 0)
confirm.no()
Check("Cancel drops the quote and buys nothing", #t.purchases == 2 and t.purchases[2].step == "cancel"
    and not t.M.Purchase.Busy())
BuyAll(lines[2])
t.Fire("COMMODITY_PRICE_UPDATED", 497, 12425)
t.Fire("COMMODITY_PRICE_UPDATED", 500, 12500)
confirm = t.confirms[#t.confirms]
Check("a quote that moves asks again with the new total", confirm.text == "Buy 25 Item 2770 for 12500?")
confirm.yes()
local last = t.purchases[#t.purchases]
Check("Buy's click confirms the purchase", last.step == "confirm" and last.itemID == ORE and last.quantity == 25)
searches = #t.searches
t.Fire("COMMODITY_PURCHASE_SUCCEEDED")
Check("bought, it says so and reads the listings again", pane.note.text == "Bought 25." and #t.searches == searches + 1
    and not t.M.Purchase.Busy())
Ore(t, ORE_ROWS)

lines = t.Lines()
t.Hover(lines[1])
BuyAll(lines[1])
t.Fire("COMMODITY_PRICE_UNAVAILABLE")
Check("a price the game cannot quote buys nothing and says so", pane.note.text == "The purchase did not go through."
    and not t.M.Purchase.Busy() and t.purchases[#t.purchases].step == "cancel")
BuyAll(lines[1])
t.Fire("COMMODITY_PRICE_UPDATED", 480, 2400)
t.confirms[#t.confirms].yes()
t.Fire("COMMODITY_PURCHASE_FAILED")
Check("nor does a purchase the game refuses", pane.note.text == "The purchase did not go through."
    and not t.M.Purchase.Busy())
Check("and its quote is let go, as Blizzard's dialog does", t.purchases[#t.purchases].step == "cancel")
BuyAll(lines[1])
t.RunTimers()
Check("nor one the game never answers", not t.M.Purchase.Busy())
local started = #t.purchases
lines[2].buy.click()
local prompt = t.prompts[#t.prompts]
Check("Buy on a commodity asks how many first, offering all up to that row", #t.purchases == started
    and prompt.title == "Buy how many? Up to 25, cheapest first." and prompt.text == "25")
prompt.accept("nine")
prompt.accept("0")
Check("a quantity that is not a number, or none, asks the game for nothing", #t.purchases == started)
prompt.accept("7")
Check("a smaller quantity is the one quoted", t.purchases[#t.purchases].step == "start"
    and t.purchases[#t.purchases].quantity == 7)
t.Fire("COMMODITY_PRICE_UPDATED", 485, 3400)
Check("and the one the confirm names", t.confirms[#t.confirms].text == "Buy 7 Item 2770 for 3400?")
t.confirms[#t.confirms].no()
lines[2].buy.click()
t.prompts[#t.prompts].accept("400")
Check("more than the row offers buys only up to the row", t.purchases[#t.purchases].quantity == 25)
t.Fire("COMMODITY_PRICE_UNAVAILABLE")
t.money = 1000
started = #t.purchases
BuyAll(lines[1])
Check("with too little gold nothing is asked", #t.purchases == started and pane.note.text == "You don't have enough money.")
t.money = 3000
BuyAll(lines[1])
t.Fire("COMMODITY_PRICE_UPDATED", 700, 3500)
Check("nor confirmed when the quote is more than you have", t.purchases[#t.purchases].step == "cancel"
    and pane.note.text == "You don't have enough money.")
t.money = 100000

BuyAll(lines[1])
t.Fire("COMMODITY_PRICE_UPDATED", 480, 2400)
confirm = t.confirms[#t.confirms]
t.page.Hide()
Check("leaving Sell closes the confirm and drops the quote", not confirm.dimmer.shown and not t.M.Purchase.Busy()
    and t.purchases[#t.purchases].step == "cancel")
t.page.Show()
Ore(t, {})
Check("with nobody selling it says yours would be the only one", pane.title.text == "Listings (0)" and #t.Lines() == 0
    and pane.status.shown and pane.status.text == "No listings: yours would be the only one.")
Ore(t, ORE_ROWS)
local open = pane.height
Sell.Pick("item:9999")
t.page.Draw()
Check("the next item's search keeps the height, so Up Next does not jump", pane.height == open
    and pane.status.text == "Checking" and #t.Lines() == 0)

Gear(t, {
    { buyoutAmount = 40000, quantity = 1, containsOwnerItem = false, auctionID = 11 },
    { buyoutAmount = 40000, quantity = 1, containsOwnerItem = true, auctionID = 12, itemLink = "item:8888" },
    { buyoutAmount = 45050, quantity = 1, containsOwnerItem = false, auctionID = 13, itemLink = "item:7777" },
    { quantity = 1, containsOwnerItem = false, auctionID = 14 },
})
lines = t.Lines()
Check("an item's auctions at one price are one row, and one with no buyout is left out", #lines == 2
    and lines[1].quantity.text == "x2" and lines[1].yours.shown)
t.Click(lines[2])
Check("an item's price taken stays on whole silver", (Sell.Price(Sell.Focus())) == 45000)
t.Hover(lines[2])
Check("its Buy names the buyout", t.tips[2] == "Buy takes this auction for 45050.")
lines[2].buy.click()
confirm = t.confirms[#t.confirms]
Check("Buy on an item asks first, naming that auction's own item, not the one in your bags, and its buyout",
    confirm.text == "Buy 1 Item 7777 for 45050?" and #t.bids == 0)
confirm.no()
Check("Cancel buys nothing", #t.bids == 0 and not t.M.Purchase.Busy())
lines[2].buy.click()
started = #t.purchases
t.confirms[#t.confirms].yes()
Check("Buy's click buys that auction out", #t.bids == 1 and t.bids[1].auctionID == 13 and t.bids[1].amount == 45050)
searches = #t.searches
t.Fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 99)
Check("another auction's purchase is not this one", t.M.Purchase.Busy())
t.Fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 13)
Check("bought, the listings are read again", pane.note.text == "Bought 1." and #t.searches == searches + 1)
Check("and an item's purchase touches no commodity quote", #t.purchases == started)
t.Hover(lines[1])
lines[1].cancel.click()
Check("Cancel names your auction's own item", t.confirms[#t.confirms].text:find("Item 8888", 1, true) ~= nil)
t.confirms[#t.confirms].yes()
Check("an item's own auction cancels by its own ID", t.cancels[#t.cancels] == 12)

pane.head.scripts.OnClick(pane.head)
Check("the head folds the listings away, for the account", t.account.marketListingsFolded == true and #t.Lines() == 0
    and pane.height < open)
t = Setup({ marketListingsFolded = true })
t.page.Show()
pane = Pane(t)
Ore(t, ORE_ROWS)
Check("and they stay folded on the next visit, the head still counting them", #t.Lines() == 0
    and pane.title.text == "Listings (4)")
pane.head.scripts.OnClick(pane.head)
Check("until the head is clicked again", t.account.marketListingsFolded == nil and #t.Lines() == 4)

t.bags[0] = {}
t.Fire("BAG_UPDATE_DELAYED")
t.RunTimers()
Check("with nothing to sell there are no listings to show", not pane.shown)

print("market sell listings: " .. checks .. " checks passed")
