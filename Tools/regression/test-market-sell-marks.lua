-- Run with Lua 5.1 from the repository root: favourites and hidden items in The Market's Sell queue. A right-click on
-- an Up Next row marks its item a favourite, which lists first, or hides it for good, by item ID and account-wide;
-- hidden items sit in a folded Hidden section they can be shown again from, and count nowhere on Sell.

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local Page = dofile("Tools/regression/market_sell_page.lua")
local Stack, COMMODITY, ITEM = Page.Stack, Page.COMMODITY, Page.ITEM

local ORE, CLOTH, HERB, JUNK, GEAR = 2770, 2589, 765, 4306, 9999
local function Bags()
    return { [0] = { Stack(ORE, 20), Stack(CLOTH, 10), Stack(HERB, 5), Stack(JUNK, 3),
        Stack(GEAR, 1, { hyperlink = "item:9999:a" }), Stack(GEAR, 1, { hyperlink = "item:9999:b" }) } }
end
local OPTS = { status = { [ORE] = COMMODITY, [CLOTH] = COMMODITY, [HERB] = COMMODITY, [JUNK] = COMMODITY, [GEAR] = ITEM },
    scan = { [ORE] = 500, [CLOTH] = 100, [HERB] = 40, [JUNK] = 100 },
    vendor = { [ORE] = 5, [CLOTH] = 3, [HERB] = 2, [JUNK] = 99, [GEAR] = 2000 } }

local function Setup(account)
    local t = Page.Setup({ bags = Bags(), status = OPTS.status, scan = OPTS.scan, vendor = OPTS.vendor })
    for k, v in pairs(account or {}) do t.account[k] = v end
    return t
end

local function Keys(t)
    local keys = {}
    for i, entry in ipairs(t.M.Sell.queue) do keys[i] = entry.itemID end
    return table.concat(keys, " ")
end

local function Row(t, itemID)
    for _, row in ipairs(t.Rows()) do
        if row.kind == "item" and row.entry.itemID == itemID then return row end
    end
end

local function Fold(t)
    for _, row in ipairs(t.Rows()) do
        if row.kind == "fold" then return row end
    end
end

local function Menu(t, row, label)
    t.Click(row, "RightButton")
    local menu = t.menus[#t.menus]
    for _, item in ipairs(menu.items) do
        if item.text == label then return item.click() end
    end
    error("no menu item " .. label)
end

local t = Setup()
local Sell = t.M.Sell
t.page.Show()
Check("with nothing marked the queue is as before: priced by worth, unpriced, then the vendor's",
    Keys(t) == "2770 2589 765 9999 9999 4306")
Check("and has no Hidden section", Fold(t) == nil and Sell.Left() == 5)

t.Click(Row(t, HERB), "RightButton")
local menu = t.menus[1]
Check("a right-click on an Up Next row offers Favourite and Hide from Sell", #menu.items == 2
    and menu.items[1].text == "Favourite" and menu.items[2].text == "Hide from Sell")
Check("and picks nothing", Sell.Focus().itemID == ORE)
menu.items[1].click()
Check("a favourite comes first in Up Next, whatever it is worth", Keys(t) == "765 2770 2589 9999 9999 4306"
    and t.Rows()[1].entry.itemID == HERB)
Check("with a star on its row, and none on the others", Row(t, HERB).star.shown and not Row(t, ORE).star.shown)
Check("it is kept account-wide by item ID", t.account.marketSellFavourites[HERB] == true)
Check("marking it leaves the item in front of you where it was", Sell.Focus().itemID == ORE)
Menu(t, Row(t, GEAR), "Favourite")
Check("an item that is not a commodity is marked by its item ID, every one of it", Keys(t) == "765 9999 9999 2770 2589 4306")
t.Click(Row(t, GEAR), "RightButton")
Check("a favourite's menu takes it back off", t.menus[#t.menus].items[1].text == "Remove Favourite")
t.menus[#t.menus].items[1].click()
Check("and it goes back to its place", Keys(t) == "765 2770 2589 9999 9999 4306")
Menu(t, Row(t, JUNK), "Favourite")
Check("a favourite a vendor pays more for stays For a Vendor", Keys(t) == "765 2770 2589 9999 9999 4306"
    and Row(t, JUNK).star.shown)

local before = Sell.Left()
local _, total = Sell.Totals()
Menu(t, Row(t, CLOTH), "Hide from Sell")
Check("a hidden item leaves Up Next", Row(t, CLOTH) == nil and Keys(t) == "765 2770 9999 9999 4306 2589")
local _, after = Sell.Totals()
Check("and Sell's counts and totals", Sell.Left() == before - 1 and after == total - 10 * 100)
local fold = Fold(t)
Check("a Hidden section counts it, folded, at the bottom", fold and fold.section.text == "Hidden (1)"
    and fold.fold.shown and t.Rows()[#t.Rows()] == fold)
Check("it is kept account-wide by item ID", t.account.marketSellHidden[CLOTH] == true)
t.Click(fold)
Check("clicking the section lists what is hidden", Row(t, CLOTH) ~= nil and t.Rows()[#t.Rows()] == Row(t, CLOTH))
t.Click(Row(t, CLOTH), "RightButton")
Check("a hidden row's menu shows it again", t.menus[#t.menus].items[2].text == "Show in Sell")
t.Click(fold)
Check("clicking it again folds it", Row(t, CLOTH) == nil)

Check("the item in front of you is the first in the queue", Sell.Focus().itemID == ORE)
Menu(t, Row(t, ORE), "Hide from Sell")
Check("hiding the item in front of you brings up the next one", Sell.Focus().itemID == HERB
    and Fold(t).section.text == "Hidden (2)")
Menu(t, Row(t, HERB), "Hide from Sell")
Check("hiding a favourite takes its star away", t.account.marketSellFavourites[HERB] == nil
    and t.account.marketSellHidden[HERB] == true)
Sell.Next()
Sell.Next()
Sell.Next()
Check("Skip never lands on a hidden item", Sell.Focus().itemID == GEAR)

t.Click(Fold(t))
Menu(t, Row(t, ORE), "Show in Sell")
Check("Show in Sell puts it back in Up Next", Keys(t) == "2770 9999 9999 4306 2589 765" and Sell.Left() == 3
    and t.account.marketSellHidden[ORE] == nil)
Menu(t, Row(t, CLOTH), "Favourite")
Check("making a hidden item a favourite shows it again, first", Keys(t) == "2589 2770 9999 9999 4306 765"
    and t.account.marketSellHidden[CLOTH] == nil)
t.Click(Row(t, HERB))
Check("a hidden item can still be picked from its section, to post it", Sell.Focus().itemID == HERB)
t.Fire("BAG_UPDATE_DELAYED")
t.RunTimers()
Check("and stays in front of you when your bags change", Sell.Focus().itemID == HERB)

local account = t.account
t = Setup(account)
Sell = t.M.Sell
t.page.Show()
Check("the marks are still there on the next visit, and on your alts", Keys(t) == "2589 2770 9999 9999 4306 765"
    and Fold(t).section.text == "Hidden (1)" and Row(t, CLOTH).star.shown)
Check("the Hidden section starts folded", Row(t, HERB) == nil)
Check("the first item up is never a hidden one", Sell.Focus().itemID == CLOTH)

t = Setup({ marketSellHidden = { [ORE] = true, [CLOTH] = true, [HERB] = true, [GEAR] = true } })
Sell = t.M.Sell
t.page.Show()
Check("with everything hidden nothing is in front of you", Sell.Focus() == nil and Sell.Left() == 0)
Check("and Up Next has only the vendor's and the Hidden section", #t.Rows() == 3 and t.Rows()[3].section.text == "Hidden (5)")

print("market sell marks: " .. checks .. " checks passed")
