-- Run with Lua 5.1 from the repository root: The Market's Undercut by a percent or a fixed amount, and Sell's
-- Starting Bid. A percent or amount under the cheapest listing still lands on whole silver for an item that is not
-- a commodity and never undercuts your own listing; a starting bid goes to PostItem only with its setting on, for an
-- item that is not a commodity, and only under the price.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM

local ORE, GEAR = 2770, 9999

local function Setup()
    return Page.Setup({ bags = { [0] = { Stack(ORE, 20), Stack(GEAR, 2) } }, status = { [ORE] = COMMODITY, [GEAR] = ITEM },
        vendor = { [ORE] = 5, [GEAR] = 20 } })
end

local t = Setup()
local M, Sell, Set = t.M, t.M.Sell, t.M.Settings.Set

local function Ore(rows)
    t.results.commodity[ORE] = rows
    t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", ORE)
end

local function Gear(rows)
    t.results.item[GEAR] = rows
    t.Fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = GEAR })
end

local function Theirs(price, quantity) return { unitPrice = price, quantity = quantity or 5, numOwnerItems = 0 } end
local function Piece(price, own) return { buyoutAmount = price, quantity = 1, containsOwnerItem = own or false } end

Check("Undercut starts on Smallest Step, at 5 percent and a silver for the others", M.Settings.Get("undercut") == "step"
    and M.Settings.Get("undercutPercent") == 5 and M.Settings.Get("undercutAmount") == 100)
t.page.Show()
Sell.Pick(ORE)
Ore({ Theirs(5000), Theirs(5200), Theirs(8000) })
local ore = Sell.Focus()

Set("undercut", "percent")
local price, why, ref = Sell.Price(ore)
Check("Percent prices a commodity that share under the cheapest listing", price == 4750 and why == "under" and ref == 5000)
Set("undercutPercent", 50)
Check("up to half of it", (Sell.Price(ore)) == 2500)
Set("undercutPercent", 1)
Check("or a hundredth", (Sell.Price(ore)) == 4950)
Set("undercutPercent", 5)
Check("Up steps to the same share under the next listing", Sell.StepPrice(ore, true) and (Sell.Price(ore)) == 4940)
Check("and Down back", Sell.StepPrice(ore, false) and (Sell.Price(ore)) == 4750)
Sell.SetPrice(ORE, 0)
Sell.PriceAt(ore, 3)
Check("a listing clicked is priced that share under it", (Sell.Price(ore)) == 7600)
Sell.SetPrice(ORE, 0)
Ore({ Theirs(10) })
price, why = Sell.Price(ore)
Check("a share smaller than a step is a step", price == 9 and why == "under")
Ore({ { unitPrice = 5000, quantity = 5, numOwnerItems = 5 }, Theirs(5200) })
price, why = Sell.Price(ore)
Check("your own cheapest listing is matched, never undercut by a percent", price == 5000 and why == "yours")

Set("undercut", "amount")
Set("undercutAmount", 300)
Ore({ Theirs(5000), Theirs(5200) })
price, why, ref = Sell.Price(ore)
Check("Fixed Amount prices a commodity that much under the cheapest listing", price == 4700 and why == "under" and ref == 5000)
Check("and Up steps to that much under the next", Sell.StepPrice(ore, true) and (Sell.Price(ore)) == 4900)
Sell.SetPrice(ORE, 0)
Ore({ { unitPrice = 5000, quantity = 5, numOwnerItems = 5 }, Theirs(5200) })
price, why = Sell.Price(ore)
Check("your own cheapest listing is matched, never undercut by an amount", price == 5000 and why == "yours")
Ore({ Theirs(250) })
Check("an amount over the listing's price stops at one step", (Sell.Price(ore)) == 1)
Check("which makes less than a vendor pays, so it asks first", Sell.Risk(ore, 1) == "vendor")
Ore({ Theirs(400) })
price = Sell.Price(ore)
Check("a fixed amount that leaves under 70% of a cheap listing asks, though The Market suggested it", price == 100
    and Sell.Risk(ore, price) == "listing")
Set("undercut", "percent")
Set("undercutPercent", 50)
Ore({ Theirs(5000) })
Check("a percent you chose never asks", (Sell.Price(ore)) == 2500 and Sell.Risk(ore, 2500) == nil)
Set("undercutPercent", 5)

Sell.Pick("item:9999")
local piece = Sell.Focus()
Gear({ Piece(3000), Piece(4050) })
price, why = Sell.Price(piece)
Check("a percent under an item that is not a commodity lands on whole silver", price == 2800 and why == "under"
    and price % 100 == 0)
Check("and so does each step", Sell.StepPrice(piece, true) and (Sell.Price(piece)) == 3800)
Sell.SetPrice("item:9999", 0)
Gear({ Piece(100) })
price, why = Sell.Price(piece)
Check("a percent of a one-silver item cannot go under a silver, so it matches", price == 100 and why == "match")
Gear({ Piece(3000, true), Piece(3000) })
price, why = Sell.Price(piece)
Check("tied with your own auction, a percent matches rather than undercuts you", price == 3000 and why == "yours")
Set("undercut", "amount")
Set("undercutAmount", 500)
Gear({ Piece(3000), Piece(4000) })
Check("Fixed Amount is whole silver, so an item stays on whole silver", (Sell.Price(piece)) == 2500)

t = Setup()
M, Sell = t.M, t.M.Sell
t.page.Show()
Sell.Pick("item:9999")
Gear({ Piece(3000) })
piece = Sell.Focus()
local bidBox = t.moneys[2]
Check("Starting Bid is off until you turn it on", M.Settings.Get("startingBid") == false)
Check("and Sell has no bid box", not bidBox.parent.shown)
Sell.SetBid("item:9999", 1000)
Check("off, no bid is read", Sell.Bid(piece) == nil and Sell.BidFits(piece))
t.post.click()
Check("and a post goes up with a buyout only, as before", #t.posts == 1 and t.posts[1].kind == "item"
    and t.posts[1].bid == nil and t.posts[1].price == 2900)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
t.Fire("AUCTION_MULTISELL_UPDATE", 2, 2)

t = Setup()
Sell, Set = t.M.Sell, t.M.Settings.Set
Set("startingBid", true)
t.page.Show()
Sell.Pick("item:9999")
Gear({ Piece(3000) })
piece = Sell.Focus()
bidBox = t.moneys[2]
Check("on, an item that is not a commodity has a bid box with no copper", bidBox.parent.shown and bidBox.copper == false)
Check("a blank bid is still a buyout only", Sell.Bid(piece) == nil and Sell.BidFits(piece) and bidBox.amount == 0)
bidBox.Type(2000)
Check("typing in it sets the starting bid", Sell.Bid(piece) == 2000)
bidBox.Type(0)
Check("and clearing it takes the bid away", Sell.Bid(piece) == nil)
Sell.SetBid("item:9999", 2000)
Check("a bid under the price is the starting bid", Sell.Bid(piece) == 2000 and Sell.BidFits(piece))
Sell.SetBid("item:9999", 2900)
Check("a bid at the price does not fit: the game wants the buyout over the bid", not Sell.BidFits(piece))
t.post.click()
Check("so nothing posts", #t.posts == 0)
Sell.SetBid("item:9999", 5000)
t.post.click()
Check("nor with a bid over it", not Sell.BidFits(piece) and #t.posts == 0)
Sell.SetBid("item:9999", 2000)
t.needsConfirm = true
t.post.click()
Check("PostItem takes the bid before the buyout", #t.posts == 1 and t.posts[1].bid == 2000 and t.posts[1].price == 2900
    and t.posts[1].quantity == 2)
t.dialog.OnAccept(t.dialog, nil)
local confirmed = t.confirms[#t.confirms]
Check("and the game's confirm is answered with the same bid", confirmed.bid == 2000 and confirmed.price == 2900)
t.needsConfirm = false
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
t.Fire("AUCTION_MULTISELL_UPDATE", 2, 2)
t.bags[0][2].stackCount = 1
t.Fire("BAG_UPDATE_DELAYED")
t.RunTimers()
Sell.Pick("item:9999")
Gear({ Piece(3000) })
Check("a bid is for one post: the next starts blank", Sell.Bid(Sell.Focus()) == nil)

Sell.SetBid("item:9999", 1000)
Sell.SetPrice("item:9999", 1500)
t.post.click()
Check("a bad post's confirm keeps the bid", #t.posts == 1 and #t.confirms == 2 and t.confirms[2].text ~= nil)
Sell.SetBid("item:9999", 0)
t.confirms[2].yes()
Check("and posts with it", #t.posts == 2 and t.posts[2].bid == 1000 and t.posts[2].price == 1500)
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 2)

Sell.Pick(ORE)
Ore({ Theirs(5000) })
Sell.SetBid(ORE, 1000)
t.page.Draw()
Check("a commodity never has a bid, or a bid box", Sell.Bid(Sell.Focus()) == nil and not bidBox.parent.shown)
t.post.click()
Check("and posts as a commodity", t.posts[#t.posts].kind == "commodity" and t.posts[#t.posts].bid == nil)

print("market sell undercut: " .. checks .. " checks passed")
