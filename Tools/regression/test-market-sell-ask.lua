-- Run with Lua 5.1 from the repository root: The Market asks before a bad post. A price that makes no more than a
-- vendor pays after the cut, or one set by hand far under the going price, opens the house confirm instead of
-- posting; its accept is the click (or Enter, with Post With Keys) that posts.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM
local GOLD = 10000

local t = Page.Setup({
    bags = { [0] = { Stack(2770, 20), Stack(4306, 3), Stack(9999, 1), Stack(7777, 1) } },
    status = { [2770] = COMMODITY, [4306] = COMMODITY, [9999] = ITEM, [7777] = ITEM },
    scan = { [2770] = 5000, [4306] = 100, [9999] = 20 * GOLD, [7777] = 80 * GOLD },
    vendor = { [2770] = 5, [4306] = 99, [9999] = 2000, [7777] = 100 },
})
local M = t.M
local Sell = M.Sell

local function List(itemID, price)
    if M.Bags.Get(itemID) then
        t.results.commodity[itemID] = price and { { unitPrice = price, quantity = 5, numOwnerItems = 0 } } or {}
        t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", itemID)
    else
        t.results.item[itemID] = price and { { buyoutAmount = price, quantity = 1, containsOwnerItem = false } } or {}
        t.Fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = itemID })
    end
end

Check("Ask Before a Bad Post is on until you turn it off", M.Settings.Get("askBadPost") == true)
t.page.Show()
Sell.Pick(2770)
List(2770, 5000)
local ore = Sell.Focus()
Check("the price The Market suggests is never a bad post", Sell.Risk(ore, (Sell.Price(ore))) == nil)
Check("nor is one over it", Sell.Risk(ore, 9000) == nil)
Check("under a gold, a price at 70% of the cheapest listing posts without asking", Sell.Risk(ore, 3500) == nil)
local risk, ref = Sell.Risk(ore, 3499)
Check("and one under it asks, against that listing", risk == "listing" and ref == 5000)
risk, ref = Sell.Risk(ore, 5)
Check("a price that makes no more than a vendor pays after the cut asks, against the vendor", risk == "vendor" and ref == 5)
Check("a copper more after the cut is not the vendor's", (Sell.Risk(ore, 7)) == "listing")
List(2770, nil)
risk, ref = Sell.Risk(ore, 3000)
Check("with nobody selling, it is compared with your last scan", risk == "scan" and ref == 5000)

Sell.Pick("item:9999")
List(9999, 20 * GOLD)
local piece = Sell.Focus()
Check("from a gold to fifty, half the going price posts without asking", Sell.Risk(piece, 10 * GOLD) == nil)
Check("and under half asks", Sell.Risk(piece, 10 * GOLD - 100) == "listing")
Sell.Pick("item:7777")
List(7777, 80 * GOLD)
local rare = Sell.Focus()
Check("over fifty gold, only under 30% asks", Sell.Risk(rare, 24 * GOLD) == nil
    and Sell.Risk(rare, 24 * GOLD - 100) == "listing")
M.Settings.Set("askBadPost", false)
Check("turned off, nothing asks", Sell.Risk(rare, 100) == nil and Sell.Risk(ore, 1) == nil)
M.Settings.Set("askBadPost", true)

Sell.Pick(2770)
List(2770, 5000)
t.post.click()
Check("a post at the suggested price goes straight up", #t.posts == 1 and #t.confirms == 0 and t.posts[1].price == 4999)

t = Page.Setup({
    bags = { [0] = { Stack(2770, 20), Stack(4306, 3) } }, status = { [2770] = COMMODITY, [4306] = COMMODITY },
    scan = { [2770] = 5000, [4306] = 100 }, vendor = { [2770] = 5, [4306] = 99 },
})
M, Sell = t.M, t.M.Sell
t.page.Show()
List(2770, 5000)
Sell.SetPrice(2770, 1000)
t.post.click()
Check("a price far under the cheapest listing asks instead of posting", #t.posts == 0 and #t.confirms == 1)
local confirm = t.confirms[1]
Check("naming the item, your price and the listing it is compared with", confirm.text:find("Item 2770", 1, true)
    and confirm.text:find("1000", 1, true) and confirm.text:find("5000", 1, true) and confirm.text:find("cheapest listing"))
Check("with Post Anyway and Cancel", confirm.yesText == "Post Anyway" and confirm.noText == "Cancel")
t.post.click()
Check("the Post button does nothing more while it asks", #t.posts == 0 and #t.confirms == 1)
confirm.no()
Check("Cancel posts nothing", #t.posts == 0)
t.post.click()
Check("and Post asks again", #t.confirms == 2)
t.confirms[2].yes()
Check("Post Anyway's click posts it, at the price asked about", #t.posts == 1 and t.posts[1].price == 1000
    and t.posts[1].quantity == 20)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)

Sell.Pick(4306)
List(4306, 100)
t.post.click()
confirm = t.confirms[3]
Check("an item for a vendor asks, against the vendor's price", #t.posts == 1 and confirm.text:find("vendor")
    and confirm.text:find("99", 1, true))
Sell.SetQuantity(4306, 1)
Sell.SetPrice(4306, 5000)
confirm.yes()
Check("it posts what it asked about, not what was typed since", #t.posts == 2 and t.posts[2].price == 99
    and t.posts[2].quantity == 3)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 2)

t = Page.Setup({ bags = { [0] = { Stack(2770, 20) } }, status = { [2770] = COMMODITY }, scan = { [2770] = 5000 },
    vendor = { [2770] = 5 } })
M, Sell = t.M, t.M.Sell
t.page.Show()
List(2770, 5000)
Sell.SetPrice(2770, 1000)
Check("without Post With Keys, the panel takes no keys", not t.Key("SPACE") and #t.confirms == 0)
M.Settings.Set("postKeys", true)
Check("with it, Space opens the confirm", t.Key("SPACE") and #t.confirms == 1 and #t.posts == 0)
Check("Space, S, Up and Down do nothing while it asks", t.Key("SPACE") and t.Key("S") and t.Key("UP") and t.Key("DOWN")
    and #t.confirms == 1 and #t.posts == 0 and Sell.Focus().key == 2770 and (Sell.Price(Sell.Focus())) == 1000)
Check("Enter accepts it and posts", t.Key("ENTER") and #t.posts == 1 and t.posts[1].price == 1000
    and not t.confirms[1].dimmer.shown)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 3)
Check("Enter is not taken with nothing asked", not t.Key("ENTER"))

Sell.SetPrice(2770, 1000)
t.post.click()
t.page.Hide()
Check("leaving Sell closes the confirm", #t.confirms == 2 and not t.confirms[2].dimmer.shown)
t.page.Show()
List(2770, 5000)
t.post.click()
Check("and Post asks again when you are back", #t.confirms == 3 and #t.posts == 1)
t.bags[0][1] = nil
t.Fire("BAG_UPDATE_DELAYED")
t.RunTimers()
t.confirms[3].yes()
Check("an item gone from your bags since is not posted", #t.posts == 1)

print("market sell ask: " .. checks .. " checks passed")
