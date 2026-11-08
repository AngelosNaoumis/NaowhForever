-- Run with Lua 5.1 from the repository root: The Market's sales log and Buy's favourites.
local World = dofile("Tools/regression/market_world.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local DAY = 86400
local t = World.Setup({ keyInfo = { [2770] = { isCommodity = true } } })
local Sales, Buy = t.M.Sales, t.M.Buy

Check("no sales yet", Sales.Since(7 * DAY) == 0 and Sales.Last(2770) == nil)
t.now = 10 * DAY
Check("a sale is noted", Sales.Note(501, 2770, 20, 100))
Check("only once per auction", not Sales.Note(501, 2770, 20, 100))
Check("a sale with no price is not", not Sales.Note(502, 2770, 1, 0))
Check("part of the same commodity auction selling later is its own sale", Sales.Note(501, 2770, 5, 100))
local total, count = Sales.Since(7 * DAY)
Check("the week's sales are counted after the cut", total == 20 * 95 + 5 * 95 and count == 2)
Check("the last sale of an item is found", Sales.Last(2770).qty == 5 and Sales.Last(2770).at == 10 * DAY)
Sales.Note(503, 4306, 1, 100, 600)
Check("a sale is dated by the time its gold has left to arrive", Sales.Last(4306).at == 10 * DAY - 3000)

t.now = 20 * DAY
Sales.Note(504, 2770, 5, 120)
total, count = Sales.Since(7 * DAY)
Check("an older sale drops out of the week", total == 5 * 114 and count == 1)
Check("the newest sale is the last", Sales.Last(2770).price == 120)

local house = t.account.marketSales["Realm-Horde"]
t.now = 45 * DAY
Sales.Note(505, 2589, 1, 10)
Check("sales older than 30 days are dropped", #house.list == 2 and house.list[2].price == 120)
Check("and an auction seen long ago is forgotten", house.seen["501:20"] == nil and house.seen["505:1"] ~= nil)
Check("an item's last sale is kept past its listing", Sales.Last(4306).qty == 1)

t.ns.MarketSettings.Set("enabled", true)
t.ns.Apply()
t.owned = {
    { auctionID = 77, itemKey = { itemID = 2770, itemLevel = 0, itemSuffix = 0 }, quantity = 10, buyoutAmount = 90,
      status = 1, timeLeftSeconds = 3600 },
    { auctionID = 78, itemKey = { itemID = 2770, itemLevel = 0, itemSuffix = 0 }, quantity = 4, buyoutAmount = 95,
      status = 0, timeLeftSeconds = 3600 },
    { auctionID = 79, itemKey = { itemID = 9999, itemLevel = 30, itemSuffix = 0 }, quantity = 1, bidAmount = 3000,
      status = 1, timeLeftSeconds = 3600 },
}
local queries = t.queries
t.Fire("AUCTION_HOUSE_SHOW")
Check("opening the auction house asks for your auctions", t.queries == queries + 1)
t.Fire("OWNED_AUCTIONS_UPDATED")
Check("a sold auction is noted without opening My Auctions", house.seen["77:10"] ~= nil
    and Sales.Last(2770).price == 90)
Check("one still up is not", house.seen["78:4"] == nil)
Check("one sold on a bid with no buyout is noted at its bid", Sales.Last(9999).price == 3000)
local listed = #house.list
t.Fire("OWNED_AUCTIONS_UPDATED")
Check("reading them again notes each once", #house.list == listed)
t.ns.MarketSettings.Set("enabled", false)
t.ns.Apply()
t.Fire("AUCTION_HOUSE_SHOW")
Check("nothing is asked with The Market off", t.queries == queries + 1)

Check("nothing is a favourite at first", not Buy.IsFavourite(2589) and #Buy.Favourites({}) == 0)
Buy.ToggleFavourite({ itemID = 2770, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 })
Buy.ToggleFavourite({ itemID = 9999, itemLevel = 30, itemSuffix = 7, battlePetSpeciesID = 0 })
Buy.ToggleFavourite({ itemID = 2589, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 })
local list = Buy.Favourites({})
Check("starring keeps an item, listed by name", Buy.IsFavourite(2589) and #list == 3 and list[1] == 2589
    and list[2] == 2770 and list[3] == 9999)
local key = Buy.FavouriteKey(9999)
Check("gear is kept with its own item level and suffix", key.itemID == 9999 and key.itemLevel == 30
    and key.itemSuffix == 7)
Buy.ToggleFavourite({ itemID = 2589, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 })
Check("starring again lets it go", not Buy.IsFavourite(2589) and #Buy.Favourites(list) == 2)

print("market extras: " .. checks .. " checks passed")
