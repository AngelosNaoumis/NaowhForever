-- Run with Lua 5.1 from the repository root: your past posts on The Market's Sell page. A post the game made is kept
-- under its item, for the realm and faction, newest first, ten distinct ones an item and five hundred items at most;
-- Sell shows the last one for the item in front of you, and clicking it, or one of the others, takes its price.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM

local ORE, CLOTH, GEAR = 2770, 2589, 9999
local DAY = 86400
local HOUSE = "Realm-Horde"

local function Setup(account)
    local t = Page.Setup({ bags = { [0] = { Stack(ORE, 20), Stack(CLOTH, 10), Stack(GEAR, 1) } },
        status = { [ORE] = COMMODITY, [CLOTH] = COMMODITY, [GEAR] = ITEM }, scan = { [ORE] = 500, [CLOTH] = 100 },
        vendor = { [ORE] = 5, [CLOTH] = 3, [GEAR] = 20 } })
    for k, v in pairs(account or {}) do t.account[k] = v end
    t.M.C.DURATION_LABELS = { "2 Hours", "8 Hours", "24 Hours" }
    t.now = 100 * DAY
    return t
end

local t = Setup()
local Sell = t.M.Sell
local last = t.links[1]

local function Ore(price)
    t.results.commodity[ORE] = { { unitPrice = price, quantity = 5, numOwnerItems = 0 } }
    t.Fire("COMMODITY_SEARCH_RESULTS_UPDATED", ORE)
end

t.page.Show()
Ore(500)
Check("an item never posted shows no past post", Sell.PastCount(ORE) == 0 and Sell.Past(ORE, 1) == nil
    and not last.parent.shown)
t.post.click()
Check("a post sent is not a post made", #t.posts == 1 and Sell.PastCount(ORE) == 0)
t.Fire("AUCTION_HOUSE_POST_ERROR")
Check("one the auction house refuses is not kept", Sell.PastCount(ORE) == 0 and t.account.marketPosts == nil)
t.post.click()
t.Fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
local price, quantity, duration, at = Sell.Past(ORE, 1)
Check("the auction made is kept: price each, quantity, duration and when", Sell.PastCount(ORE) == 1 and price == 499
    and quantity == 20 and duration == 2 and at == t.now)
Check("for the account, under this realm and faction, by item ID", t.account.marketPosts[HOUSE][ORE][1] == "499:20:2:" .. t.now)

t.now = t.now + DAY
Sell.Posted(ORE, 20, 499, ORE, 2)
Check("the same post again is the same line, dated again", Sell.PastCount(ORE) == 1
    and select(4, Sell.Past(ORE, 1)) == t.now)
Sell.Posted(ORE, 5, 499, ORE, 2)
Sell.Posted(ORE, 20, 480, ORE, 2)
Sell.Posted(ORE, 20, 480, ORE, 3)
Check("another quantity, price or duration is another line, newest first", Sell.PastCount(ORE) == 4
    and select(3, Sell.Past(ORE, 1)) == 3 and (Sell.Past(ORE, 2)) == 480 and select(2, Sell.Past(ORE, 3)) == 5
    and select(2, Sell.Past(ORE, 4)) == 20)
Sell.Posted(ORE, 20, 499, ORE, 2)
Check("a line posted again moves to the top without a second copy", Sell.PastCount(ORE) == 4 and (Sell.Past(ORE, 1)) == 499
    and select(2, Sell.Past(ORE, 1)) == 20 and (Sell.Past(ORE, 2)) == 480)
for i = 1, 12 do Sell.Posted(ORE, 1, 1000 + i, ORE, 1) end
Check("an item keeps its last ten", Sell.PastCount(ORE) == 10 and (Sell.Past(ORE, 1)) == 1012 and (Sell.Past(ORE, 10)) == 1003
    and Sell.Past(ORE, 11) == nil)
Sell.Posted("item:9999", 1, 5000, GEAR, 3)
Check("an item that is not a commodity is kept by its item ID", Sell.PastCount(GEAR) == 1 and (Sell.Past(GEAR, 1)) == 5000)
Sell.Posted(CLOTH, 10, 99)
Check("a post with no item named is counted for the visit and not kept", Sell.PastCount(CLOTH) == 0 and #Sell.postedOrder == 3)

for i = 1, 600 do
    t.now = t.now + 1
    Sell.Posted(100000 + i, 1, 100, 100000 + i, 1)
end
local items = 0
for _ in pairs(t.account.marketPosts[HOUSE]) do items = items + 1 end
Check("five hundred items at most are kept", items == 500)
Check("the ones posted longest ago go first", Sell.PastCount(ORE) == 0 and Sell.PastCount(GEAR) == 0
    and Sell.PastCount(100100) == 0 and Sell.PastCount(100101) == 1 and Sell.PastCount(100600) == 1)

t = Setup({ marketPosts = { [HOUSE] = { [ORE] = { "450:20:2:" .. 100 * DAY, "470:5:3:" .. 97 * DAY, "520:20:1:" .. 60 * DAY } },
    ["Other-Horde"] = { [CLOTH] = { "90:10:2:" .. 100 * DAY } } } })
Sell = t.M.Sell
last = t.links[1]
local all = t.links[2]
t.page.Show()
Ore(500)
Check("Sell shows your last post of the item in front of you", Sell.Focus().itemID == ORE and last.parent.shown
    and last.text == "Last post: 450 x20 (Today)")
Check("and how many more there are", all.shown and all.text == "All 3")
t.now = 101 * DAY
t.page.Draw()
Check("a day later it reads Yesterday", last.text == "Last post: 450 x20 (Yesterday)")
t.now = 103 * DAY + 100
t.page.Draw()
Check("then days ago", last.text == "Last post: 450 x20 (3 days ago)")
last.click(last)
local taken, why = Sell.Price(Sell.Focus())
Check("clicking it takes its price", taken == 450 and why == "hand" and t.moneys[1].amount == 450)
all.click(all)
local menu = t.menus[1]
Check("All lists every post kept, with its duration", #menu.items == 3 and menu.items[1].text == "450 x20, 8 Hours (3 days ago)"
    and menu.items[2].text == "470 x5, 24 Hours (6 days ago)" and menu.items[3].text == "520 x20, 2 Hours (43 days ago)")
menu.items[3].click()
Check("and picking one takes its price", (Sell.Price(Sell.Focus())) == 520)
all.click(all)
Sell.Pick(CLOTH)
t.page.Draw()
t.menus[#t.menus].items[1].click()
Check("a menu left open does not price the next item", select(2, Sell.Price(Sell.Focus())) ~= "hand")
Sell.Pick(CLOTH)
t.page.Draw()
Check("another realm's posts are not shown here", Sell.PastCount(CLOTH) == 0 and not last.parent.shown)
t.account.marketPosts[HOUSE][CLOTH] = { "95:10:2:" .. 103 * DAY }
t.page.Draw()
Check("an item with one post shows it and no All", last.parent.shown and last.text == "Last post: 95 x10 (Today)"
    and not all.shown)

print("market sell past: " .. checks .. " checks passed")
