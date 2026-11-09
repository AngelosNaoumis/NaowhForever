# The Market

Naowh's own auction house window. At an auctioneer it opens over Blizzard's: your bags most
valuable first, the item in front of you with the auction house's live listings, a price one step
under the cheapest of someone else's, and a post line you work through with Space (post), S (skip)
and Up and Down (the next price step). Blizzard's own window is one button away until you leave the
auctioneer. Away from it, `/market` (or `/nfmarket`) or its key binding opens the same window on Farm: the zones
where your Herbalism and Mining gather the most, a zone's map with every herb and vein priced, and a
loop through it you can follow by waypoint. Last Run records each herb and vein you gather and draws
the run's gold over time with its haul; what you really gather prices Farm's nodes. Crafts shows what your characters' known recipes make
from your bags, priced from your last scan, and Reagents what each reagent in them goes into, in every
profession, and whether crafting it beats selling it. Bag Worth puts what your
bags would fetch on your bags, and item tooltips gain The Market's lines: your stack's worth, the
price over the past week, disenchanting, who makes it and what it crafts into.
Built on [`Shared/`](../Shared/README.md).

## Layout

```
NaowhForever_Market/
  NaowhForever_Market.toc   metadata, and Market.xml
  Market.xml         every file, in load order
  Market.lua         settings (ns.MarketSettings) and the module table (ns.Market)
  Constants.lua      the numbers several files share: the cut, timeouts, durations (Market.C)
  Bags.lua           what in your bags the auction house takes, one entry per item (Market.Bags)
  Listings.lua       one item's live listings, cheapest first (Market.Listings)
  Post.lua           posting from a click or key press, and the game's answer (Market.Post)
  Sell.lua           the sell queue, each item's price from its listings, what you posted (Market.Sell)
  Sales.lua          what you sold, from your sold auctions, per realm and faction (Market.Sales)
  Auctions.lua       your auctions, each checked against the listings, and cancelling (Market.Auctions)
  Buy.lua            the name and category search, the cost of a quantity, and buying (Market.Buy)
  History.lua        each item's lowest price per day from your scans, two weeks of them (Market.History)
  Worth.lua          what your bags would fetch, and their most valuable items (Market.Worth)
  Crafts.lua         your characters' known recipes priced, and what your bags make (Market.Crafts)
  Runs.lua           your gathering runs, what each node yields on average, and the pools you fish from (Market.Runs)
  Farm.lua           zones ranked for your skills, a zone's spots priced, and its loop (Market.Farm)
  Data/
    Skinning.lua     the creatures you can skin, their loot and their camps, packed, from Tools/build/market_gather.py
    Fishing.lua      what each zone's water catches, and the fishing pools, from Tools/build/market_gather.py
  View/
    Style.lua        The Market's own look, over Shared/Style.lua (Market.Style)
    Ladder.lua       an item's listings as a ladder, its bars and lit rungs, for Sell and Buy (Market.Ladder)
    Spark.lua        an item's last two weeks of prices as a small line, for Farm and Buy (Market.Spark)
  UI/
    Window.lua       the window: title bar, scan line, pages, Blizzard's button (Market.Window)
    Farm.lua         the Farm page: the zone list, the zone's map, its loop and the picked item
    Runs.lua         the Last Run page: the run's gold over time, its haul, earlier runs
    Sell.lua         the Sell page: the item, its listings, the post line, Up Next
    Crafts.lua       the Crafts page: recipes, who knows them, materials, gains, Add to Queue
    Buy.lua          the Buy page: the Shopping List, the category and search, the listings, the buy button
    Auctions.lua     the My Auctions page: your auctions, their status, Cancel and Cancel Undercut
    Reagents.lua     the Reagents page: Professions' Reagents list under a search
    Takeover.lua     covering Blizzard's auction house, and the way back to it
    BagWorth.lua     the Bag Worth card on your bags, and the numbers on their most valuable slots
    Tooltip.lua      The Market's lines on item tooltips
    SettingsPage.lua the settings page, declared as cards
```

## Why

- Blizzard's auction house window is covered, never hidden: its OnHide calls
  `C_AuctionHouse.CloseAuctionHouse`, which would end the visit. It stays shown at alpha 0 under ours,
  set from its own OnShow so it never shows for a frame. Ours is one strata above it and at least its
  size, anchored to its top left, so nothing of Blizzard's can be clicked through ours. Blizzard's tabs,
  and QoL's Scan Prices button beside them, hang under its bottom edge, so ours reaches
  `BLIZZARD_TABS` further down to cover them too.
- At an auctioneer ours does not move: Blizzard's window is placed by the panel manager and cannot be
  dragged either, and moving it from addon code would fight that placing. Away from one it opens where
  you last dragged it (`marketWindow`, placed by the shared `Parts.Place`), one strata up (`HIGH`), and
  drags. A scan finishing redraws the page shown, but never a Sell, Buy or My Auctions tab away from the
  auctioneer, and Bag Worth's rows pick an item on Sell only at the auctioneer.
- While ours covers Blizzard's window, `ns.MarketAuctionWindow` hands it to Professions, whose panels
  at the auction house (Search Favorites AH, Disenchant Deals, the Shopping List) then sit beside ours
  instead of on top of it; Takeover tells it each time ours covers or steps aside
  (`ns.AuctionWindowChanged`).
- Sell, Buy and My Auctions need the auction house, so away from it their tabs show a short "At an
  auctioneer" note instead; `/market` opens on Farm. Opening it while Blizzard's window is showing
  at an auctioneer steps back into ours instead.
- With the Forever look, only about 27 of a rail row's 36 pixels of art are visible. A page name in the
  heading font with that note under it is as tall as that and sat high, so the name ran over the top
  edge. Those rows are `FOREVER_ROW_H` (48) tall, and the two lines sit `FOREVER_DROP` (3) lower.
- Closing ours (its X or Escape) closes the auction house with `C_AuctionHouse.CloseAuctionHouse`, so
  the visit ends as Blizzard's own close does.
- A right-click on a bag item at the auction house goes to Blizzard's `SetPostItem`. The Market hooks
  it and picks that item on its Sell page; Blizzard's window still takes it too, out of sight.
- `PostCommodity`, `PostItem` and their Confirm calls need a hardware event, so a post only ever runs
  from the Post button or from Space in the window's OnKeyDown. The key is claimed with
  `SetPropagateKeyboardInput(false)` only for that press, out of combat, as the Dungeon Journal does.
- When the game asks to confirm a post (`needsConfirmation`), it shows Blizzard's own
  `AUCTION_HOUSE_POST_WARNING`, whose Accept confirms only Blizzard's pending post. The Market hooks
  that dialog's OnAccept with `hooksecurefunc`: the hook runs inside the same click, so it can confirm
  ours. Closing the dialog without Accept counts as not posted.
- A commodity searches with `SendSearchQuery` sorted by price, an item by buyout then bid, as
  Blizzard's sell frame does; equipment searches with `SendSellSearchQuery` and its item level and
  suffix cleared, so similar items compare.
- Searches and posts wait for `IsThrottledMessageSystemReady`; a search that waited goes on
  `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`. The Post button follows the throttle as Blizzard's sell frame
  does, checked again on that event and `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`: the listings can arrive
  before the throttle frees, and nothing else redraws the page then.
  A search with no answer in `SEARCH_TIMEOUT` seconds, or a
  post in `POST_TIMEOUT`, frees the page instead of holding it. A post of several items restarts
  `POST_TIMEOUT` with each auction the game makes, so a long one is not given up while it posts.
- When a scan finishes, the Sell page reads your bags again (`Page.Refresh`), so Up Next takes the new
  prices and order.
- The price steps a copper, or a silver where `C_AuctionHouse.SupportsCopperValues()` is false, and is
  never under one step. Your own cheapest listing is matched, never undercut.
- With no listings and no scan price, an item is priced as Blizzard's sell frame prices it: its
  vendor price times `DEFAULT_AUCTION_PRICE_MULTIPLIER`, rounded up to a silver.
- An item is the vendor's when a vendor pays at least what it makes on the auction house after the 5%
  cut (`AH_CUT`).
- The scan prices that order the queue come from QoL's Auction Prices (`ns.AuctionPrice`); its
  Scan Prices button sits under Blizzard's covered window, so The Market's title bar has its own,
  which runs the same scan (`ns.AuctionScan`) and redraws when it finishes (`ns.MarketRefresh`).
- Items the client has not loaded have an unknown commodity status; they are asked for and the queue
  is read again when they arrive.
- It steps aside when the gamepad interface style is on, like every window that covers Blizzard's.
- My Auctions asks for your auctions (`QueryOwnedAuctions`) each time it opens and after each cancel
  (`AUCTION_CANCELED`), then checks one item at a time through the same listings search as Sell, so the
  throttle is never flooded. A commodity is checked once by item ID for all your auctions of it; any
  other item by its own item key, item level and suffix included. An auction's price is
  `buyoutAmount`, read as the price for one, as Blizzard's auctions list shows it.
- An auction is undercut when the cheapest listing that is not yours is under its price. Under
  `UNDERCUT_SMALL` (3%) it shows the amount in warning orange, more in red as a percent.
- `CancelAuction` needs a hardware event: each Cancel and each Cancel Undercut press cancels one
  auction. A row's Cancel asks first with `ns.Confirm`, whose Yes is the click that cancels. Cancel
  Undercut does not ask: its label says what it does and it cancels one per press. An auction once
  cancelled is not offered again until your auctions are read back, so a quick second press moves on.
  A check's answer is kept under the item it was asked for, since the auctions are read again (and
  their tables reused) whenever the game sends them. Cancelled items come
  back by mail, so a cancelled auction cannot be posted again from here.
- Buy searches by name with `SendBrowseQuery`, sorted by price then name, as Blizzard's browse does;
  a picked item's listings come through the same search as Sell. Its categories are Blizzard's own
  (`AuctionCategories`, from Blizzard_AuctionHouseUI, which is loaded whenever Buy can be used), so
  they match the game's auction house on every client language; a picked one's `filters` go in as
  `itemClassFilters`, alone or with a name. The WoW Token category is left out: it is bought another way.
  A list longer than the game's first page asks for the next one (`RequestMoreBrowseResults`) when
  scrolled within `MORE_ROWS` of its end, as Blizzard's list does, and the page arrives with
  `AUCTION_HOUSE_BROWSE_RESULTS_ADDED`. A result row's tooltip is the item from
  `GetItemKeySampleLink`, or `SetItemKey` when there is no sample, as Blizzard's own auction house does
  on Forever; Shopping List and Favourites rows show the plain item. The throttle freeing, another item's
  data arriving or an error while not buying redraw nothing: the page rebuilds Professions' whole
  shopping plan on each draw, and the throttle frees after every message, Blizzard's own included.
- A commodity is bought in two presses, each a hardware event: the first asks the game for a price
  (`StartCommoditiesPurchase`, which answers with `COMMODITY_PRICE_UPDATED`), the second confirms it
  (`ConfirmCommoditiesPurchase`). A quote over `QUOTE_SLACK` (5%) above the listings' average is flagged,
  the margin Blizzard's own buy dialog refuses at. Picking something else cancels an open quote, through
  `pcall` as Professions' Buyer does: the game can drop the quote first.
- Gear buys the cheapest auction that is not yours at its buyout with `PlaceBid`, as Blizzard's buyout
  does, and answers with `AUCTION_HOUSE_PURCHASE_COMPLETED` for that auction or `AUCTION_HOUSE_SHOW_ERROR`.
- The Shopping List is Professions' (`ns.Professions.Shopping`), read only when Professions is loaded.
  A commodity bought here is taken off it with its own `Shopping.Bought`, as its Buy button does.
  Buy listens to `Shopping.OnChange` from its first show and redraws the list only while it is
  shown, since a listener cannot be removed; without it, a craft added at the auctioneer stayed off
  the list until the tab was opened again.
- An owned auction's item key info (`GetItemKeyInfo`) can be missing until
  `ITEM_KEY_ITEM_INFO_RECEIVED`; until then it shows as Checking and is checked when it arrives.
- Price history keeps each item's lowest price per day from QoL's scans (`ns.AuctionPriceList`), for
  `HISTORY_DAYS` (14) days per realm and faction, in the account's `marketHistory`. It is written when a
  scan finishes (`ns.MarketRefresh`) and at login, so a scan taken while The Market was off is kept the
  next time it is on. A day is a UTC day. Today is a table, since each scan lowers its prices; a past
  day is packed into one string (",id:price,id:price,"), read with one `match` per lookup, which
  roughly halves what thousands of items take in saved data and loads far faster than a table.
- A price change compares today's lowest with the oldest day within `CHANGE_DAYS` (7) that has one, and
  says how many days back that is: with a scan only yesterday it reads "Since yesterday", never "7 days".
- Bag Worth counts an item at what it makes on the auction house after the cut when that beats its
  vendor price, and at the vendor price otherwise; bound items count at the vendor price. Its card sits
  above the combined bags or EllesmereUI's bags, and left of the backpack when bags open one by one,
  so it never covers a bag. It is parented to the bag it sits on, so it shows and hides with it.
- The numbers go on the first slot holding each of the `WORTH_TOP` (5) most valuable items, through
  `Shared/Game/Bags.lua` as Scrap Marker's marks do: after the game's `UpdateItems`, and EllesmereUI's
  overlay icons.
- Crafts reads the recipes Professions saves for each character (`profMakes`, through
  `Shopping.Makes` and `Shopping.MakesOf`) when its window opens, so a profession shows once it has been
  opened on that character. Alts come from The Market's own list (`marketCharacters`), noted at login
  with The Market on, and only those on this realm and faction, who could be mailed the materials.
  A recipe two characters know is listed once, as yours.
- A craft sells for its output's scan price after the cut, times what it makes. Its gain is that less
  what its materials would fetch sold as they are (their auction price after the cut or their vendor
  price, whichever is more); its profit is that less what they cost to buy (`Shopping.BuyPrice`).
  Materials a vendor sells (`Shopping.VendorPrice`) count at their price and never limit how many your
  bags make. Outputs with no scan price are left out.
- Each row's From Bags is what that recipe alone could make. The total on top shares your bags out:
  recipes are taken best gain a craft first, each using up the materials it makes from, so two
  recipes that need the same cloth never count it twice.
- Crafts reads its recipes when the page shows after a scan or a bag change (`Crafts.Changed`), not on
  every draw.
- Add to Queue goes to Professions' Craft Queue with `CraftQueue.AddWithShopping`, as its own Add does,
  only for your own recipes and while its Craft Queue is on. At an auctioneer, Buy opens the Buy page on
  the first material you are short of.
- The Reagents page is Professions' own Reagents list (`P.ReagentList`), so both say the same; without
  Professions loaded and on, it says to turn it on. It names an alt from The Market's list
  (`marketCharacters`) when that alt is on this realm and faction.
- Farm reads where herbs and veins grow from Glimmer's map (`ns.GlimmerSpots`, unpacked by
  `Glimmer.Spots.Load`, which waits out combat), its nodes (`Glimmer.NODES`) and the ones you gathered
  (`Glimmer.Spots.Gathered`); a node's item is Professions' (`GatherNodes`, by the node's English name,
  as Glimmer's names are). Both are read only when loaded: QoL's files load with Glimmer switched off,
  so Farm works without Glimmer's own pins.
- A node is priced at its item's scan price after the cut, times `YIELD` (2 for a herb, 1.5 for a vein).
  Your skill is Glimmer's (`Target.Skill`): a node you cannot gather yet is drawn faded behind a filter
  and left off the loop.
- The loop is a nearest-neighbour tour of the zone's spots you can gather, starting at the one nearest
  you when you are in the zone, on its own map ID or one `Shared.Places.SameMap` reads as it. Its time is its length at `TRAVEL_SPEED` (10 yards a second, riding)
  plus `GATHER_SECONDS` a node, and its worth assumes `OCCUPANCY` (a third) of spots hold a node at a
  time, so the hourly figure is an estimate and says so.
- A zone you can fish is a row of its own, beside its gathering row, once your Fishing reaches the
  lowest skill that fishes there (QoL's `ns.FishingLevels`). A catch is worth each of the zone's
  catches (`FISH_CATCHES`) at its chance, after the cut. Below the zone's top skill some fish get away,
  so the catch rate climbs from `FISH_LOW_CATCH` (a half) at the lowest to every catch at the top, and
  the hour is `CATCHES_PER_HOUR` (200, a catch every 18 seconds) times that rate times a catch.
- No source places fishing pools, so Farm learns them: a fishing loot window (`IsFishingLoot`) whose
  source GUID is one of `FISH_POOLS` marks a pool where you stand, account-wide (`marketPools`), at most
  `POOLS_PER_MAP` (60) a map, the one seen longest ago going first. One within `POOL_MERGE` (1.5 map
  percent) of a known pool is that pool again. A fish row's loop runs through its pools, `POOL_SECONDS`
  (72, about four catches) at each; with none learned, its map has no pins and says to fish anywhere.
- Ranking every zone with a full tour would stall a frame, so the zone list estimates each tour's
  length as `TOUR_FACTOR` (0.92) times the square root of its spots times its area, the
  nearest-neighbour length for scattered points; the zone you pick gets its real tour.
- Start Loop hands the loop to the shared waypoint route (`ns.PlaceWaypointRoute`), which places the
  next stop as you reach each, so the loop is followed by the game's own waypoint arrow. Open Map opens
  the world map on the zone (`Shared.Places.ShowMap`).
- The zone map is drawn from the map's own art (`C_Map.GetMapArtLayers` and
  `GetMapArtLayerTextures`, laid out in tiles as Blizzard's map canvas does), scaled to fit and
  clipped. A spot gathered in the last `PICKED_FADE` (10) minutes is faded, its node likely gone.
- A gather is a loot window whose items come from a herb or vein: `GetLootSourceInfo` gives each
  slot's source GUID, and Glimmer's `GUID_OBJECT` pattern its object ID, looked up in `Glimmer.NODES`.
  An item counts when its slot is taken (`LOOT_SLOT_CLEARED`), and the window's haul is recorded when
  it closes, so items left behind with full bags count once, when you come back for them.
  Nothing is read from the soft target or tooltips, so it works on every client language. A vein
  mined again keeps its GUID, so its loot adds to the same node; a secret GUID is skipped.
- A run starts with your first gather and ends after `RUN_IDLE` (10) minutes without one. Each
  character keeps its last `RUN_KEEP` (10) runs (`marketRuns`), each up to `RUN_EVENTS` (400) events
  with where they were. Values are worked out from your current scan, not frozen at the time, so the
  chart, the haul and the total agree.
- What every node gives is kept account-wide (`marketYields`): after `YIELD_MIN` (3) nodes of a kind,
  Farm prices that node from its average loot, stones and gems included, instead of `YIELD`. A zone
  with a run of at least `RUN_MIN` (5) minutes is ranked by what you made an hour there, and says so.
  Each gather tells Farm to rank again (`Farm.Changed`), and a run is kept under the zone's own map ID
  (`Shared.Places.SameMap`), so it counts for the zone Farm lists.
- The chart's hover runs an OnUpdate only while the mouse is over it.
- Sales are noted from your own sold auctions (`Enum.AuctionStatus.Sold` in `GetOwnedAuctionInfo`):
  The Market asks for your auctions each time the auction house opens and reads every
  `OWNED_AUCTIONS_UPDATED` while it is open, whoever asked, so a sale is caught without opening My
  Auctions. Mail is never read: a sold auction carries its own ID, a mail does not, so nothing is
  counted twice. A sold row stays only until its gold is mailed, about an hour (`SALE_DELIVERY`), so a
  sale whose gold arrived while you were away from the auction house is not seen.
- A sale is kept once per auction ID and quantity (`seen`), so part of a commodity auction selling
  later is its own sale; seen keys are forgotten after `SALE_SEEN_SECONDS` (2 days), long after a sold
  row is gone. Sales are kept for `SALES_DAYS` (30) days, at most `SALES_KEEP` (2000) per realm and
  faction (`marketSales`), with each item's last sale kept on its own for tooltips (`latest`).
- A sale is worth its buyout, or its bid when it has no buyout, times its quantity, after the cut:
  Blizzard's own auctions list shows a sold row at its buyout. It is dated by the time its gold still
  has to arrive (`timeLeftSeconds` within `SALE_DELIVERY`), else when it was read. My Auctions sums the
  last `SALES_WINDOW_DAYS` (7); tooltips show your last sale of the item.
- Favourites are account-wide (`marketFavourites`), starred from Buy's detail with the item key's item
  level and suffix, so a piece of gear is searched as the one you starred. They are listed by name and
  drawn when Buy opens, when one is starred, and when a favourite's item data arrives
  (`GET_ITEM_INFO_RECEIVED`). The detail's name runs to the star when there is no price line to draw.
- The tooltip lines are added at PLAYER_LOGIN, after QoL's Auction Price line, so they follow it.
  A stack's size is read from the bag slot the tooltip is over; elsewhere it counts one, and the line
  is left out. Disenchanting is priced with Professions' `DisenchantValues`, read only when Professions
  is loaded.

## Checking

`lua5.1 Tools/regression/test-market-sell.lua` covers the queue, the prices and posting offline,
`test-market-auctions.lua` My Auctions, `test-market-buy.lua` Buy, `test-market-worth.lua` the price
history and Bag Worth, `test-market-crafts.lua` Crafts, `test-market-farm.lua` Farm,
`test-market-runs.lua` Last Run, `test-market-extras.lua` sales and favourites; all load the rules
through
`Tools/regression/market_world.lua`.
In game, at an auctioneer, with The Market on:

1. The Market opens over Blizzard's window with your bags in Up Next, most valuable first.
2. The first item's listings fill in, and its price is one step under the cheapest that is not yours.
3. Space posts it, the next item comes up, and the bar's total counts up.
4. Up and Down step the price to just under the next listing; typing a price makes it yours.
5. Right-clicking a bag item picks it.
6. The eye button shows Blizzard's window; The Market button under it comes back. Professions' Shopping
   List (and Search Favorites AH, Disenchant Deals) sits beside whichever window shows, never on top of ours.
7. Escape or the X closes the auction house.
8. My Auctions lists your auctions, checks each item, and marks the undercut ones; a commodity
   auction's price is the price for one (check against Blizzard's Auctions tab).
9. Cancel asks first and cancels; Cancel Undercut cancels one per press; the list reads again.
10. Buy: a name and Enter lists results; picking one shows its listings and what you would take.
11. A commodity: Buy gets the price, Confirm buys it, and the Shopping List counts it.
12. Gear: Buy buys the cheapest auction that is not yours.

Away from the auction house:

13. Opening your bags shows Bag Worth above them: the total, and the five most valuable items; the
    same five are numbered on their slots, in Blizzard's bags and in EllesmereUI's.
14. Selling or looting changes the card and the numbers.
15. At the auction house, clicking a Bag Worth row picks it on the Sell page.
16. A stack's tooltip shows Stack of N with its worth; after scans on two days, the change line shows.
17. A green or blue weapon or armour shows a Disenchant line with Professions loaded.
18. `/market` and `/nfmarket` open The Market on Farm; Sell, Buy and My Auctions say to visit an auctioneer. It drags,
    and opens where you left it.
19. After opening a profession, Crafts lists its recipes with prices; From My Bags shows what your bags
    make and the total it adds; All Recipes shows every priced one, by profit.
20. Add to Queue puts the crafts in Professions' Craft Queue.
21. Log in on an alt with The Market on and open its profession: its recipes show under its name.
22. A crafted item's tooltip shows Made by and its materials' cost; a material's shows Crafts into.
23. Farm lists the zones for your Herbalism and Mining, richest first, each with its best items.
24. Picking a zone draws its map with every herb and vein: bigger pins for more gold, a gold line for
    the loop, faded pins for nodes you gathered in the last ten minutes.
25. Herbs, Veins and Nodes I Can't Gather Yet change the map, the loop and the list.
26. Start Loop places a waypoint at the nearest stop and the next as you reach each.
27. Clicking a pin shows its item in the strip: price, the last 14 days, what you hold. At an
    auctioneer, Sell picks it on the Sell page.
28. Gather a few herbs or veins: Last Run shows the zone, the minutes, the nodes and skill-ups, a gold
    line stepping up at each gather, and the haul.
29. Hovering the chart names the node, what it gave and the run so far.
30. Ten minutes without gathering, then another gather, starts a new run; < and > step between runs.
31. After three of a node, its pins on Farm are priced from what you gathered; after a five-minute run
    the zone reads "you made ... an hour".
32. After an auction sells, My Auctions' line adds what you sold in the last 7 days, and the item's
    tooltip shows "You sold N" with the price and when.
33. On Buy, the star beside a picked item keeps it under Favourites; clicking a favourite picks it.
34. Buy's detail and Farm's strip draw the item's last 14 days once two days have scans.
35. With Fishing learned, Farm lists fishing rows (the Fishing icon first, then the best catches) beside
    the gathering rows, and the Fishing filter takes them out. A fish row's map says to fish anywhere
    until a pool is learned; its strip shows the best catch and what A catch is worth.
36. Fish from a school (Oily Blackmouth, Firefin Snapper, Floating Wreckage): a pool pin appears where
    you stood. Unverified: that a pool's catch names the pool as its loot source (`GetLootSourceInfo`).
    If it names the bobber instead, no pool is ever recorded.
37. With Buy open at an auctioneer, add a craft to Professions' Shopping List: its materials show under
    Shopping List at once.
38. Buy's category menu has the game's categories (Weapons, Armor, Containers, ...); picking one, or All
    inside one, lists what is for sale there without a name, and a name then searches only that category.
39. A big category (Armor, Trade Goods) lists more as you scroll to its end.
40. Hovering a Buy result, a Shopping List row or a Favourite shows the item's tooltip, with Shift comparing
    gear to what you wear.
41. Reagents, away from an auctioneer too: each reagent in your bags, with Craft beside the ones worth crafting; a click
    opens every recipe it goes into, and an unlearned one's click sets a waypoint to where you learn it.
42. Typing in Reagents' search finds any reagent by name, carried or not.
