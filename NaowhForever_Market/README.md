# The Market

At the auction house The Market is a panel docked to the right of Blizzard's own window, which stays
exactly as the game draws it. The panel has four tabs, and follows Blizzard's own. Buy is your Watch List:
search your scans for an item, give it a price, and each scan tells you in chat when it is at or under it. Its
Searches view keeps named lists of searches and the last ones you ran; a click runs one in Blizzard's own Buy tab. Sell lists your bags most valuable first, puts the
item in front of you at a price one step under the cheapest listing that is not yours, says how it
compares, and posts it with the Post button, or with Space (post), S (skip) and Up and Down (the next
price step) once Post With Keys is on. Under the form it lists the item's listings, cheapest first, with where
your price lands among them: a click takes a listing's price, and a row's Buy or Cancel buys it or takes
yours down. My Auctions checks each of your auctions against the listings,
undercut ones first, filtered by name, and cancels them one press at a time, of its button or of a key you bind. Shopping List, with Professions loaded, lists
what your Shopping List and your alts' still need, and counts what you buy in Blizzard's window on that
character's list. Farm, Price Graph and Reagents tabs, after Blizzard's Auctions tab and drawn like it,
dock The Market's own window in the panel's place; the same tab again or the window's X brings the panel
back. Shift + drag moves the auction house with whatever is docked. Away from it, `/market` (or
`/nfmarket`) or its key binding open that window, anywhere, with three tabs along the
bottom: Farm, the zones where your Herbalism and Mining gather the most, a zone's map with every herb
and vein priced, and a loop through it you can follow by waypoint; Reagents, what each reagent in your
bags goes into, in every profession, and whether crafting it beats selling it; and Price Graph, any item in
your scans, found by name or picked from your bags, with its lowest price each day over two weeks. What
you gather is recorded, and what you really gather prices Farm's nodes. Bag Worth, once on, puts what your
bags would fetch on your bags, and item tooltips gain The Market's lines: your stack's worth, the
price over the past week, disenchanting, who makes it, what it crafts into and, if you ask, the best way
to sell it. A Compact style keeps only the auction, vendor and disenchant prices.
Built on [`Shared/`](../Shared/README.md).

## Layout

```
NaowhForever_Market/
  NaowhForever_Market.toc   metadata, and Market.xml
  Market.xml         every file, in load order
  Market.lua         settings (ns.MarketSettings) and the module table (ns.Market)
  Constants.lua      the numbers several files share: the cut, timeouts, durations (Market.C)
  Houses.lua         the other auction house you can reach: its name, an item's price there and what selling there gains (Market.Houses)
  Bags.lua           what in your bags the auction house takes, one entry per item (Market.Bags)
  Listings.lua       one item's live listings, cheapest first (Market.Listings)
  Post.lua           posting from a click or key press, and the game's answer (Market.Post)
  Purchase.lua       buying a listing from a click: an item at its buyout, a commodity at the game's quote (Market.Purchase)
  Sell.lua           the sell queue, each item's price from its listings, what you posted (Market.Sell)
  Sales.lua          what you sold, from your sold auctions, per realm and faction (Market.Sales)
  Auctions.lua       your auctions, each checked against the listings, and cancelling (Market.Auctions)
  History.lua        each item's lowest price per day and how many were listed, from your scans and the listings you see, two weeks of them, and the items whose price moved most (Market.History)
  Watch.lua          the items you watch for a price, and the chat line when one is at or under it (Market.Watch)
  Searches.lua       your searches in named lists and the last ones you ran, run in Blizzard's Buy tab, and a list as a string to share (Market.Searches)
  Worth.lua          what your bags would fetch, their most valuable items, and the best way to sell an item (Market.Worth)
  Bank.lua           what your bank held when you last had it open, kept for each character, and what it would fetch (Market.Bank)
  Crafts.lua         your characters' known recipes priced at their best outlet, and what your bags make (Market.Crafts)
  Runs.lua           your gathering runs, what each node yields on average, and the pools you fish from (Market.Runs)
  Farm.lua           zones ranked for your skills, a zone's spots priced, and its loop (Market.Farm)
  Data/
    Skinning.lua     the creatures you can skin, their loot and their camps, packed, from Tools/build/market_gather.py
    Fishing.lua      what each zone's water catches, and the fishing pools, from Tools/build/market_gather.py
    Writs.lua        the Craftsman's Writs each profession can fill, from Tools/build/market_writs.py
  View/
    Style.lua        The Market's own look, over Shared/Style.lua (Market.Style)
    Spark.lua        an item's last two weeks of prices as a small line, for Farm (Market.Spark)
    Chart.lua        an item's lowest price each day as a chart you can hover for the day's price and how many were listed, for Price Graph (Market.Chart)
    Finder.lua       an item list searched by name across your scans, and the Watch price box, for Buy, Shopping List and Price Graph (Market.Finder)
    Listed.lua       the listings of the item on Sell, where your price lands, and Buy and Cancel on a row (Market.Listed)
    Quantity.lua     the chips over Sell's quantity box: 1, a number and All, kept as the default for that type of item (Market.Quantity)
  UI/
    Window.lua       The Market's window: title bar, scan line, the Farm, Reagents and Price Graph pages, free or docked (Market.Window)
    Farm.lua         the Farm page: the zone list, the zone's map, its loop and the picked item
    Tabs.lua         a tab bar for the window and the panel, with Buy's, Sell's and My Auctions' counts after their labels (Market.Tabs)
    Sell.lua         the panel's Sell page: the item, its price against the listings, the post line, its listings, Up Next
    Auctions.lua     the panel's My Auctions page: your auctions, undercut first, a name filter, Cancel, Cancel Undercut and its key
    Reagents.lua     the Reagents page: Professions' Reagents list under a search
    Prices.lua       the Price Graph page: any item in your scans by name, from your bags, a writ filter or the movers, and its price chart
    Searches.lua     the Buy page's Searches view: a saved list or Recent, run with a click, kept and edited from menus (Market.SearchView)
    Buy.lua          the panel's Buy page: your Watch List with any item in your scans to add to it, or your saved searches
    Shopping.lua     the panel's Shopping List page: yours and your alts' materials still to buy, counted when bought
    Move.lua         Shift + drag moving Blizzard's auction house, and keeping it there (Market.Move)
    HouseTabs.lua    the Farm, Price Graph and Reagents tabs under Blizzard's window, drawn as its own tabs (Market.HouseTabs)
    Dock.lua         the panel docked beside Blizzard's auction house, and the tabs that dock the window there instead (Market.Dock)
    BagWorth.lua     the Bag Worth card on your bags, with your bank if you ask, and the numbers on their most valuable slots
    Tooltip.lua      The Market's lines on item tooltips
    Mail.lua         what a mail's attachments would fetch at auction, one line on the inbox's own tooltip
    SettingsPage.lua the settings page, declared as cards
```

## Why

- Blizzard's auction house window is left as the game draws it. The Market used to cover it with its own
  window, until players said they wanted the game's window and its flow, with The Market's extras beside
  it. The panel is anchored to the right edge of Blizzard's window, top to bottom, on its strata and
  scale, so it follows wherever the panel manager places it; Blizzard's frames are never anchored to it.
- The panel's X closes only the panel, and nothing is left above Blizzard's window to bring it back: the next
  visit opens it again, and so does putting away a window docked by the tabs below.
- Farm, Price Graph and Reagents are tabs along the bottom of Blizzard's window, one row after its last tab
  (`AuctionsTab`, or the last tab another addon added through LibAHTab, read as QoL reads it), parented to it so
  they show and hide with it. QoL's Scan Prices follows them (`ns.MarketAuctionTabs`). They are The Market's own
  plain buttons, never made from Blizzard's tab templates: `PanelTabButtonTemplate` puts each button in its
  parent's `Tabs` list (`parentArray`) and runs Blizzard's tab code on it. Nothing of Blizzard's is written to or
  called: no `PanelTemplates_*`, no `SetScript`, no field on its frames.
- They look like Blizzard's tabs beside them by copying, each time the auction house shows and again a frame
  later (a skin restyles on the same show), what Blizzard's last tab reads back: its height and frame level, the
  seam between its tabs, its idle and picked label offsets, and its font objects (normal, highlight on hover,
  disabled for the picked tab, as `PanelTemplates_SelectTab` sets it). When its art is the stock art, each of its
  nine pieces (idle, active and highlight left, middle and right) is copied with its atlas, alpha, blend mode,
  tiling and anchors. When a skin has emptied that art (EllesmereUI's flat tabs), the skin's own label is found
  as the tab's other font string with the same text, and its font, idle and picked colours and shadow are
  copied; the block under it and the line under the picked tab are drawn, since a texture cannot hand its
  colour back (there is no getter for `SetColorTexture`): `SKIN_FILL_RGB` is EllesmereUI's dark tab fill and the
  line is the house accent. A skin's hover wash is left out, as EllesmereUI has none on these tabs.
- A tab is `MIN_W` (70) wide or its label plus `TEXT_PAD` (40), as Blizzard sizes the auction house tabs
  (`TAB_SIDES_PADDING` 20 plus its own padding 20, at least 70).
- The picked tab is the page docked; with the panel showing none is picked. Clicking a tab docks The Market's
  window right of Blizzard's on that page (`Window.DockTo`) and hides the panel; the picked tab again, or the
  window's X, closes it and the panel comes back, even after its own X. Which tab was docked is not kept: each
  visit opens on the panel. Docked, the window's own tabs move the picked tab.
- Docked, the window runs from the top to the bottom of Blizzard's window, on its strata, and is as wide as the
  screen leaves to the right of it, worked out in screen pixels from both frames' effective scales, never wider
  than its own `WINDOW_W` and never narrower than `DOCK_MIN_W` (700), the width its pages still lay out in.
  Below that (a 16:9 screen at the default scale leaves about 540) it stays 700 and, clamped to the screen,
  overlaps Blizzard's window rather than running off the edge: while docked its clamp insets are zero, as
  a free window's let most of it leave the screen. With the Forever look the window's frame draws its
  title bar and sides outside it (`FOREVER_TITLE_H`, `FOREVER_SIDE`), so the window is set in by them and the frame
  stays within Blizzard's window's height. The width is worked out again after a Shift +
  drag and each time the panel manager places Blizzard's window (`Window.FitDock`), and the page redraws when it
  changes. Put away, the window goes back to its own spot, size and strata, so `/market`, the key binding and the
  options menu open it free as before; opening it that way while it is docked puts it back free.
- At 700 wide Farm's picked-item strip has no room for its two weeks of prices: below `STRIP_FULL_W` (680) of map
  pane it drops that line and the "at your last scan" note, narrows its numbers to `KV_NARROW_W` (130) and cuts the
  item's name short. Price Graph's list is `LIST_W` (280) and its buttons `BUTTON_W` (100), so its Watch row, with
  Stop Watching, fits beside it; Reagents' description wraps beside its search.
- Shift + left-drag on Blizzard's window, the panel or the docked window moves Blizzard's window (`StartMoving`),
  and what is docked with it, since it is anchored to it. Blizzard's window has no drag or mouse scripts of its
  own: The Market registers its left-button drag and adds `OnDragStart` and `OnDragStop` with `HookScript`.
  After a drag `SetUserPlaced(false)` keeps the game's layout cache out of it, and the spot is kept account-wide
  (`marketAuctionHouse`: point, relative point, x and y on UIParent). Blizzard's window is clamped to the
  screen from then on, so a spot saved at another resolution or scale cannot lose it.
- The panel manager anchors the doublewide auction house again on every pass, inside `ShowUIPanel`,
  `HideUIPanel` and `UpdateUIPanelPositions` (each sets an attribute on its delegate, whose handler places the
  panels before the call returns), so a post-hook on each puts it back on the kept spot. Blizzard's window holds
  no secure templates, so placing it is not blocked in combat. Leaving the auctioneer mid-drag ends the drag.
  With The Market off the hooks return at once; they and the drag registration stay until a reload.
- The Market's window opens where you last dragged it (`marketWindow`, placed by the shared
  `Parts.Place`), one strata up (`HIGH`), at an auctioneer or away from one. A scan finishing redraws
  the page shown in it and in the panel.
- While the panel or the docked window shows, `ns.MarketAuctionWindow` hands it to Professions, whose panels at
  the auction house (Search Favorites AH, Disenchant Deals, the Shopping List) then sit to its right instead of on
  top of it; The Market tells it each time either shows or hides (`ns.AuctionWindowChanged`).
- Buy, Sell, My Auctions and Shopping List belong at the auction house, so they live only in the panel; the window
  has the pages that work anywhere.
- The panel's tab counts follow their labels (an optional `note` of `Parts.Tabs`), measured with them: four tabs
  in 360 pixels leave no room for a count at a tab's edge. With one-digit counts on Buy and My Auctions and two on
  Sell the four still fit whole on both looks; a longer count shortens the widest label first.
- Sell and My Auctions both read one item's listings at a time (`Market.Listings`), so only the tab shown
  searches; the other stops when you leave it.
- The panel is `DOCK_W` (380) wide: Blizzard's window is 800 wide and sits at the left of the screen, so
  the panel fits beside it on a 16:9 screen at the default UI scale. Its pages drop the old full-size
  Sell page's chart for that; the chart moved to Price Graph. The listings ladder came back as the short
  list under Sell's form (below).
- With the Forever look, only about 27 of a rail row's 36 pixels of art are visible. A page name in the
  heading font with that note under it is as tall as that and sat high, so the name ran over the top
  edge. Those rows are `FOREVER_ROW_H` (48) tall, and the two lines sit `FOREVER_DROP` (3) lower.
- Post With Keys and Bag Worth start off: Space posted an item without meaning to, and Bag Worth's numbers
  on their slots puzzled them. With Post With Keys off the panel takes no keys at all.
- A right-click on a bag item at the auction house goes to Blizzard's `SetPostItem`. The Market hooks
  it and picks that item on the panel's Sell page; Blizzard's own Sell tab takes it too. Blizzard's tab
  locks the item with `C_Item.LockItem`, and Sell passes over locked slots, so the hook unlocks it.
  Blizzard's auction house code never reads that lock.
- `PostCommodity`, `PostItem` and their Confirm calls need a hardware event, so a post only ever runs
  from the Post button or from Space in the panel's OnKeyDown. The key is claimed with
  `SetPropagateKeyboardInput(false)` only for that press, out of combat, as the Dungeon Journal does.
- Ask Before a Bad Post starts on, unlike other new settings: it is a safety net that acts only on a post
  that loses gold, and a mistyped price cannot be taken back once someone buys it. A post at or over the
  price The Market suggests is not asked about for being under the going price, unless Undercut is One
  Silver or Fixed Amount: those can take most of a cheap item's price, where a step, a match or a percent
  you chose cannot.
- It asks when the price for one, after the cut, is no more than a vendor pays (the For a Vendor rule), or
  when a price under The Market's suggestion is under a share of the going price: the cheapest listing that
  is not yours, or your last scan's price when nobody is selling. The share is `ASK_SHARE_CHEAP` (70%) of a
  going price under `ASK_CHEAP` (1 gold), `ASK_SHARE_MID` (50%) up to `ASK_DEAR` (50 gold) and
  `ASK_SHARE_DEAR` (30%) over it. Cheap items have many listings close together, so a price well under
  them is a slip; an expensive item often has one or two listings far apart and is undercut hard on
  purpose. A dropped digit is a tenth of the price, under every share.
- It asks with `ns.Confirm`, whose Yes runs the post inside its own click, so `PostItem` and
  `PostCommodity` still have their hardware event. It posts the item, count and price it asked about, even
  if the form changed behind it. With Post With Keys on, Space opens it and Enter accepts it from the
  panel's OnKeyDown: the confirm passes keys on, and the panel claims Enter for that press. Space, S, Up
  and Down are claimed and do nothing while it asks. Escape, Cancel or leaving Sell closes it unposted.
- A post's duration is the index `PostItem` and `PostCommodity` take, 1 to 3, labelled with the game's
  own `AUCTION_DURATION_ONE` to `_THREE` as Blizzard's sell frame does. On Forever they read 2, 8 and
  24 Hours, not retail's 12, 24 and 48. Until you pick one it is the default of Blizzard's own
  `auctionHouseDurationDropdown` CVar (2, 8 Hours, on Forever).
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
- A right-click on an Up Next row opens a menu (`ns.ContextMenu`) with Favourite and Hide from Sell; a
  left-click still picks the item, and a right-click on a bag item still goes to Blizzard's `SetPostItem`.
  Both marks are the account's, by item ID (`marketSellFavourites`, `marketSellHidden`), so an alt's bags
  sort the same and every suffix of a piece of gear is marked at once. An item has one mark at most:
  hiding a favourite, or making a hidden item a favourite, drops the other.
- A favourite lists before every other item to post, with a gold star on its icon; one a vendor pays more
  for stays under For a Vendor. A hidden item is left out of Up Next, Skip, the first item picked, the tab's
  count and the totals, and is listed under Hidden at the bottom, folded until its head is clicked (each
  visit starts folded); its row's menu shows it again. A hidden item can still be picked there, or by a
  right-click in your bags, and posted. Bag Worth and tooltips never read the marks.
- The price steps a copper, or a silver where `C_AuctionHouse.SupportsCopperValues()` is false, and is
  never under one step. Your own cheapest listing is matched, never undercut.
- Only commodities take copper. Forever's `SupportsCopperValues()` is true, but posts from The Market,
  which undercut by a copper, got "Internal auction error" while the same items posted from Blizzard's
  sell frame, which prices in silver ("AH prices must be in silver increments"). So an item that is not
  a commodity steps a silver and its price box has no copper.
- Selling's Undercut sets how far under the cheapest listing that is not yours the price goes: a step
  (Smallest Step, the default, as before), a silver (One Silver: 100 copper on a commodity, the same as a
  step on an item) or nothing (Match the Cheapest). Up and Down step to the same distance under each
  listing; one that is all yours is matched. A price that lands on the cheapest listing, chosen or
  because a step under it would go under one step, says it matches.
- Percent goes Undercut Percent (`undercutPercent`, 1 to 50, 5 until changed) of each listing's own price
  under it, rounded down, and never less than one step; Fixed Amount goes Undercut Amount
  (`undercutAmount`, saved in copper, set in whole silver from 1 to 500) under it. Both go through the same
  rounding as the other choices, down to the item's step, so an item that is not a commodity stays on
  whole silver and no price goes under one step; your own cheapest listing is still matched.
- Starting Bid (`startingBid`, off) adds a bid box to Sell for an item that is not a commodity, with no
  copper, as its price box has none. It is the bid for one item, `PostItem`'s fourth argument, before the
  buyout, and the same bid answers the game's own confirm (`ConfirmPostItem`). Blank or zero posts a buyout
  only, as before; a commodity has no bid (`PostCommodity` takes none). The bid has to be under the price:
  Blizzard's sell frame refuses a buyout at or under the bid, so Post is greyed and the line under it reads
  the game's own `AUCTION_HOUSE_SELL_FRAME_ERROR_BUYOUT`. A bid is kept for one post of the item, and
  Ask Before a Bad Post does not weigh it: a bid is meant to start low.
- A post is kept when the game answers that it made the auction (`Post.onDone` with `ok`), never when it
  is sent: a refused or unanswered post is no past post. `Post` hands back the item ID and duration it
  sent, since the bag entry can be gone by then.
- Past posts are the account's, per realm and faction as sales are (`marketPosts`, through
  `Market.HouseData`), by item ID: `POSTS_KEEP` (10) an item, newest first, and `POSTS_ITEMS` (500) items,
  the item posted longest ago going first, checked only when an item gets its first line. A post with the
  same price, quantity and duration as a kept one is that line again, dated now and moved to the top, so
  reposting the same stack every day does not push the others out. A line is one string,
  "price:quantity:duration:time", read with one `match` for the item in front of you.
- Sell shows the last one under the post line as a link, "Last post: 2g 10s x20 (3 days ago)", and a click
  takes its price as a price set by hand, so Ask Before a Bad Post still weighs it. With more than one,
  All N on the right opens a menu (`ns.ContextMenu`) of every line with its duration, and picking one
  takes that price. One line and a menu, not a list of ten: every row added to Sell's top part is a row
  less of Up Next. The row shows only for an item with a past post, and the top part grows by it.
- The bid box is a row of its own between the price and the duration, shown only while it applies, and
  Sell's top part grows by that row: beside the price, the quantity and its "of N" there are under 100 of
  the panel's 360 pixels left, and the box is 112 wide.
- With no listings and no scan price, an item is priced at its vendor price times
  `DEFAULT_AUCTION_PRICE_MULTIPLIER`, to the copper on a commodity and down to a whole silver on anything
  else. Blizzard's sell frame rounds that up to a silver; no price of ours is rounded up.
- Prices and totals on Sell, My Auctions and Bag Worth are shown to the copper. Only Farm's "about ... an
  hour" rates, which are estimates, are rounded to their largest coin.
- An item is the vendor's when a vendor pays at least what it makes on the auction house after the 5%
  cut (`AH_CUT`).
- The scan prices that order the queue come from QoL's Auction Prices (`ns.AuctionPrice`). Its Scan
  Prices button is on Blizzard's window, and a scan finishing redraws The Market (`ns.MarketRefresh`).
- Items the client has not loaded have an unknown commodity status; they are asked for and the queue
  is read again when they arrive.
- It steps aside when the gamepad interface style is on.
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
- An owned auction's item key info (`GetItemKeyInfo`) can be missing until
  `ITEM_KEY_ITEM_INFO_RECEIVED`; until then it shows as Checking and is checked when it arrives.
- Price history keeps each item's lowest price per day from QoL's scans (`ns.AuctionPriceList`), for
  `HISTORY_DAYS` (14) days per realm and faction, in the account's `marketHistory`. It is written when a
  scan finishes (`ns.MarketRefresh`) and at login, so a scan taken while The Market was off is kept the
  next time it is on. Prices QoL keeps as you go (`ns.MarketPricesSeen`, the items of one browse or
  listings event) lower the day's price for those items alone, on the day they were seen, which then is
  the chart's last day; Bag Worth, Crafts and Farm are told to read again, and nothing is redrawn, since
  the Sell page's own listings are among them. A scan or the release's prices are recorded once each
  (`house.recorded`), into the day they are from, even when a price was seen after them that day; ones
  from a day before the last price seen are not. A day is a UTC day. Today is a table, since each scan lowers its prices; a past
  day is packed into one string (",id:price,id:price,"), read with one `match` per lookup, which
  roughly halves what thousands of items take in saved data and loads far faster than a table.
- Each day also keeps how many of the item were listed, where QoL knows it (`ns.AuctionListed`): the count
  that came with the day's last scan or sighting, not the lowest, since it says what was up for sale. Today's
  counts are a table beside today's prices (`listed`, by day); a past day's go into its string as a third
  field (",id:price:count,"), left out where there was none. One `match` still reads a day, with or without
  the count, so history saved before the counts reads as before, with no counts, and nothing is rewritten.
  It adds about three characters an item a day to the saved data. A count is the items for sale after a page
  by page scan or a sighting, and the auctions after a fast scan or from the release's prices, as QoL keeps it.
- A price change compares today's lowest with the oldest day within `CHANGE_DAYS` (7) that has one, and
  says how many days back that is: with a scan only yesterday it reads "Since yesterday", never "7 days".
- The price chart on Price Graph draws that history: a point for each day with a price, joined across
  days without one, between the lowest and highest price of the two weeks, with the same change the
  tooltip shows. A price that never moved is one line across the middle. It keeps a point a day, not one
  a scan: a full scan prices thousands of items, and one allowed every 15 minutes would fill the saved
  data. Its right edge is the day of the last scan or release prices, so each day is named from the real
  today back and a last scan two days old never reads "Today". An axis price of a gold or more drops its
  copper to fit `PLOT_LEFT`. The hover runs an OnUpdate only while the mouse is over the plot, and names
  the nearest day that has a price, with "N listed" under the price on a day whose count is known. The
  count is on the hover alone: a second line under the prices needs a scale of its own, on a chart that is
  about price.
- Price Graph finds an item by name among the items in your scans (`ns.AuctionPriceList`), from
  `MIN_LETTERS` (2) letters typed, and only among the items the client already holds data for
  (`C_Item.IsItemDataCachedByID`): asking for thousands of names at once would flood the game with
  item loads. It lists at most `MAX_RESULTS` (50). With nothing typed it lists the items in your bags
  that have a scan price, most valuable first.
- Price Graph's filter beside the search lists only Craftsman's Writs: every one in your scans, or the ones a
  profession fills, named by the client (`GetTradeSkillDisplayName`). A writ's profession is the one that
  crafts what it asks for: `Tools/build/market_writs.py` reads each writ quest's asked-for item from the
  quest catalog and finds the recipe that makes it in Professions' recipe data, so the addon reads IDs
  only. An item two professions craft (the Gordok Ogre Suit) lists its writ under both. Typing searches
  within the filter. The writs' item data is asked for when a filter is first picked, about 150 items
  rather than thousands, and the list redraws as it arrives. The filter is not saved.
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
- A craft sells for what its output fetches at its best outlet, times what it makes. Its gain is that less
  what its materials would fetch sold as they are (their auction price after the cut or their vendor
  price, whichever is more); its profit is that less what they cost to buy (`Shopping.BuyPrice`).
  Materials a vendor sells (`Shopping.VendorPrice`) count at their price and never limit how many your
  bags make. Outputs with neither a scan price nor a disenchant value are left out.
- An output has three outlets: the auction house (its scan price after the cut), disenchanting and a
  vendor (its sell price). `Crafts.Outlet` takes the one that pays most. A vendor wins a tie with the
  auction house, as on Sell; the auction house wins a tie with disenchanting, which is an average and
  needs an enchanter.
- Disenchanting is priced as the tooltip's Disenchant line is: Professions' `DisenchantValues` expected
  value after the cut, for the equipment it takes, read only when Professions is loaded and a full price
  list is there (`ns.AuctionPriceList`). It does not check anyone's Enchanting skill, as Disenchant
  Deals' Profit does not by default.
- A vendor price alone does not list a craft: every item has one, so every recipe would list before a
  scan.
- The Disenchant view lists the crafts best disenchanted, by profit, since a shuffle buys its
  materials. The tooltip's Made by and Crafts into lines name the outlet when it is not the auction
  house, so a profit from disenchanting is not read as a sale.
- Each row's From Bags is what that recipe alone could make. The total on top shares your bags out:
  recipes are taken best gain a craft first, each using up the materials it makes from, so two
  recipes that need the same cloth never count it twice.
- Crafts reads its recipes when the page shows after a scan or a bag change (`Crafts.Changed`), not on
  every draw.
- Add to Queue goes to Professions' Craft Queue with `CraftQueue.AddWithShopping`, as its own Add does,
  only for your own recipes and while its Craft Queue is on.
- An alt's row has Add to List instead, while Professions' Shopping List is on: the Craft Queue is for
  crafting, which the alt does, but a bank character can buy the alt's materials. It goes through
  `Shopping.Add`, one craft a click as the profession window's Add to List starts at. It reads the recipe's
  materials live first, as the Craft Queue does, and falls back to the ones the alt saved (`need`) when this
  character cannot read a recipe it does not know. The button shows only when the craft leaves something to
  buy (`Shopping.HasNeeds`). Away from an auctioneer it opens the Shopping List; at one the list already
  shows beside the auction house.
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
  and left off the loop. Plan at max skill (`farmPlan`) ranks and loops every node as if each skill
  were maxed, so a player can compare professions before learning one; its nodes stay faded and marked
  Requires, since you still cannot gather them.
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
- The first Buy page, with its Favourites and saved searches, is gone: Blizzard's own Buy tab is
  what players buy in. Its saved data (`marketFavourites`, `marketSearches`, `sortBuy`) and the old Open at
  the Auctioneer setting (`openAtAuctioneer`) are left as they were, unread; the Searches view below keeps
  its own (`marketSearchLists`).
- The tooltip lines are added at PLAYER_LOGIN, after QoL's Auction Price line, so they follow it.
  A stack's size is read from the bag slot the tooltip is over; elsewhere it counts one, and the line
  is left out. Disenchanting is priced with Professions' `DisenchantValues`, read only when Professions
  is loaded.
- Tooltip Style's Compact keeps one line each for Auction, Vendor and Disenchant (when the item takes it),
  and the verdict when Best Way to Sell is on: the three prices are what deciding where an item goes
  takes. The price change, sales and craft lines stay Detailed's, and so does the header: the labels
  name themselves, so a header would be a fourth line over three. Compact leaves out the price's age;
  the Scan Prices button and the Auction Prices card say it. Detailed with its defaults draws exactly
  what it drew before these settings.
- Stack Prices reads a stack in your bags for each item, the whole stack, or both; away from your bags an
  item counts one. Both is the old split: Auction Prices' line per item, The Market's Stack of N under
  it. Each Item drops Stack of N; Whole Stack keeps it and Auction Prices leaves its line off on that
  stack. Compact puts the two on one line ("Auction x20", "10s each, 2g") and a single item plain. The
  count sits beside the label, so the prices line up on the right for a glance; Each Item has no count,
  since its price is for one.
- Shift Swaps Stack Prices (`tooltipShift`, off) reads Stack Prices the other way while Shift is held: Each
  Item as Whole Stack and Whole Stack as Each Item, in both styles, with Auction Prices' own line and the
  verdict's lead following (`StackPrices` is the one place the choice is read). Both already shows the two,
  and a single item has one price, so neither changes. It starts off: Shift over a bag item already shows
  the compare tooltips, and a tooltip that changes under a held Shift would surprise a player who never
  asked for it.
- It registers nothing. The game builds a bag item's tooltip again every `TOOLTIP_UPDATE_TIME` (0.2 seconds):
  `GameTooltip_OnUpdate` calls its owner's `UpdateTooltip`, which for a bag button, Blizzard's and
  EllesmereUI's, is the `SetBagItem` its OnEnter runs. The Market's post-call runs on each build and reads
  `IsShiftKeyDown()` there, so the lines follow Shift within that fifth of a second, with no
  `MODIFIER_STATE_CHANGED` listener, no OnUpdate of ours and nothing written to the tooltip. Only bag
  stacks have a stack to swap, and they are the tooltips the game rebuilds. Shift-click links and the
  compare tooltips are the game's own and are not touched.
- A price shows once: whenever The Market's lines carry the auction price (Compact, or Whole Stack on a
  stack), `Market.ShowsPrice` tells QoL's Auction Prices to leave its own line off. QoL reads it only
  when The Market is loaded, and it answers no until The Market's post-call is in, so Auction Prices
  alone works as before. The Market keeps the choice since its lines are the ones that change, and the
  settings stay on one card.
- The Disenchant Deals card holds Professions' Disenchant Deals rows, bound to Professions' own store
  (`store =`), so a change here is the same change there and both pages keep them. Its rows are built
  when the page opens (`rows = PriceRows`): The Market loads before Professions, and a card's rows
  cannot be shared, since each row keeps its card. The rows show only while Professions is loaded.
- Best Way to Sell weighs what each way puts in your bags, per item (`Worth.Best`): the auction price
  after the 5% cut, the vendor price, and disenchanting's materials after the cut. A vendor wins a tie
  with the auction house, as in Bag Worth, and the auction house a tie with disenchanting: the surer
  gold first. Its line leads the block and says how much more the winner pays than the next way, for
  the whole stack unless Stack Prices is Each Item.
- Auction Margin (`tooltipBestMargin`, saved in copper, set in whole silver) is how much more per item,
  after the cut, the auction house must pay than a vendor before the verdict says Auction. A lead of
  exactly the margin stays the vendor's, so 0 is the tie rule above and today's verdict. An auction
  held under the margin ranks just under the vendor, so disenchanting can still beat both, and the
  line reads "Auction only +..." with what the auction house would have added. It weighs only the
  verdict: Bag Worth and Crafts still count an item at the most it fetches.
- Disenchanting counts only when Professions is loaded, the item takes it, and this character's
  Enchanting can disenchant it now (`DisenchantDeals.MeetsSkill`): a way you cannot take is no advice, so
  a character without Enchanting is told to sell even when the Disenchant line is higher. A bound item
  (`isBound` on its bag slot) has no auction house.
- A way that applies but has no price (no scan price for an item that can be auctioned, or a material
  with none) makes the line read "Better:" and name only what it beat, never "Best:", as the unpriced
  way could pay more. With fewer than two priced ways there is no line.
- The Auction line shows the listing price, as the auction house and Auction Prices do; Disenchant and
  the verdict count what you keep after the cut, so near a tie the verdict can pick a way whose line
  reads a little lower than Auction's.

- The Watch List is the account's (`marketWatch`, item ID to a price in copper), so your alts watch the same items,
  and it holds at most `MAX_ITEMS` (100). It reads the lowest price of the realm and faction you are on from your
  scans (`ns.AuctionPrice`), so it only knows a price after a scan there.
- The Watch List lives on the panel's Buy tab, beside Blizzard's Buy, because you watch an item to buy it. Price
  Graph keeps a Watch box for the item it shows; both use `Market.Finder`, the one search list and price box.
- Each finished scan (`ns.MarketRefresh`) prints one chat line for every watched item at or under your price, while
  Watch Alerts is on. A listing search on the panel tells you too, once for each price it sees. The Watch List
  never searches Blizzard's window for you: it names the item and its price, and you buy it there. A chat line cannot
  open anything, since the addon has no clickable chat links.
- The panel's line counts the watched items at or under your price at the last scan, and opens the Buy tab on the
  Watch List. It hides on Buy, where the list and the tab's green count already show them.
- The panel follows Blizzard's tabs through a post-hook on `AuctionHouseFrame:SetDisplayMode`, reading
  `GetDisplayMode` against `AuctionHouseFrameDisplayMode`: Buy (and an item's or commodity's buy page) to Buy, Sell
  to Sell, Auctions to My Auctions. It moves only when Blizzard's tab changes, so a tab you pick on the panel
  stays; each visit starts over, on the tab Blizzard's window opens on.
- The Shopping List tab shows only while Professions is loaded (`ns.Professions.Shopping`). It lists what
  Professions' Shopping List still needs from the auction house (`Shopping.Materials`), then each alt's on this
  realm and faction from The Market's list (`marketCharacters`), by name, as that alt would plan it
  (`Shopping.MaterialsOf`). An alt shows only with a list (`Shopping.HasList`), and never one with your name, so a
  character remade under it is not listed twice. It is always on: the lists are already kept, and reading them
  costs nothing until the tab opens.
- It is the Watch List's search list and Watch box (`Market.Finder`); a row says "N more" or "N more for <alt>"
  where a scan price would be. The same item can be on two lists, so a row is picked by its place in the list
  (`finder.at`) as well as its item.
- The Shopping List page never buys. A post-hook on Blizzard's buy dialog's `BuyNow` notes the item and amount when it is the
  picked row's, and `COMMODITY_PURCHASE_SUCCEEDED`, listened to only while that purchase waits, counts it on that
  row's list: yours with `Shopping.Bought`, an alt's with `Shopping.BoughtFor`. Professions' own Buy All buys
  without that dialog and counts its own, so nothing is counted twice. A purchase that fails, of another item, or
  with the page closed counts on no list.
- Saved searches are a view of the Buy page, not a fifth tab: four tabs with their counts already fill the panel's
  360 pixels, and a search is something you buy with, as the Watch List is. Buy's two views are a switch under the
  panel's tabs, and the one you left is the one you come back to until a reload. Nothing of the Searches view is
  built until it is picked.
- Lists are the account's (`marketSearchLists`: `lists`, each a name and its searches, and `recent`): at most
  `MAX_LISTS` (20) of `MAX_SEARCHES` (100) each, with a name of `MAX_NAME` (24) bytes so it fits the list button. The
  old Buy page's `marketSearches` is another shape and stays unread.
- A search is its `text` (up to 63 bytes, what Blizzard's box takes), `exact`, `cat` (the path into Blizzard's
  `AuctionCategories` by index: category, subcategory, sub-subcategory), `min` and `max` level (1 to 999, Blizzard's
  three-digit boxes), `quality` (the item qualities left on, 0 to 5, absent when all are) and `price`. Blizzard's
  Usable Only and Uncollected Only are not kept: a saved search runs the same whatever its Filter button is on.
- Running one drives Blizzard's window as Professions' `P.AH.Search` does; The Market shows no results and never
  buys. `SetDisplayMode(Buy)` comes first, since the search bar empties its box each time it shows; then the
  category through the categories list's own `SetSelectedCategory`, the text with `SearchBar:SetSearchText`, and
  `AuctionHouseFrame:SendBrowseQuery(text, min, max, filters)`, the call Blizzard's Search button ends in. The level
  range and filters go as its arguments, so Blizzard's saved Filter choices (`g_auctionHouseFilters`) are never
  written. The filter list is made new each run: Blizzard keeps the one it is given for its sort headers.
- Exact Name is `Enum.AuctionHouseFilter.ExactMatch` added to that filter list. Forever's Filter menu has no tick for
  it, so it is set from a saved search's right-click menu. Unverified in game: that Forever's server honours it.
- A category is kept as its indexes: they are the same in every client language and are what `SetSelectedCategory`
  takes. Its name is read from `AuctionCategories` when drawn. One whose path is no longer there is left out of the
  run and the row.
- Max Price is a note on the row. A browse query has no price field, and hiding results over it would take a result
  list of The Market's own.
- A browse sent while the auction house is busy is dropped (Professions' Why), so a run waits for
  `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, listened to only while one waits. A newer click replaces it and leaving the
  page drops it.
- Recent is the last `MAX_RECENT` (30) searches, newest first, each once, noted by a post-hook on
  `AuctionHouseFrame:SendBrowseQuery`: the Search button's call and The Market's own, not the sort headers' query
  again (`SendBrowseQueryInternal`) or QoL's scan (`ReplicateItems`). Its category is read back with
  `GetSelectedCategory`. The hook goes on when the Buy page is first built and returns at once with The Market off.
  A browse with no text and no category is not noted.
- Save Search reads Blizzard's window as it stands (`SearchBox:GetSearchString`, `GetLevelFilterRange`,
  `FilterButton:CalculateFiltersArray`, `GetSelectedCategory`), searched yet or not. On Recent it asks which list.
- A list is shared as `!NFMS1!` and its data, serialized, deflated and printable, written by `Shared.Encode` and
  read by `Shared.Decode` within its size, depth and bomb caps, as Console Variables' string is. An import is taken
  whole or not at all: an unknown field, a wrong type, or a level, quality or category out of range refuses it.
  Names lose colour codes and control characters, a search listed twice comes in once, and it always makes a new
  list. A name or search text cut at its byte limit ends on a whole character: the prompts count letters, and
  half a Cyrillic or Korean letter would go to Blizzard's box and the browse query.
- A row's + (Recent) and x (a list) are one button and the rest is in a saved search's right-click menu, so a row
  keeps its width for its name and filters; its tooltip has both in full when a long one is cut. The max price is
  typed in gold in the house prompt, with a decimal point or comma.
- My Auctions' filter lists the auctions with what you type anywhere in their name. Cancel Undercut, its count and
  the key work on the auctions listed, so a filter picks what a run of presses cancels; the line above keeps the
  totals of all your auctions, and so does the tab's count.
- Cancel Next Undercut Auction is a key binding (`NAOWHFOREVER_MARKET_CANCEL` in `Bindings.xml`, set on the Key
  Binding card or in the game's Key Bindings), unbound until you set it. `CancelAuction` needs a hardware event and
  a binding's press is one, so each press cancels one auction, the one Cancel Undercut would. It was chosen over an
  override binding put on while the page shows: `SetOverrideBinding` is refused in combat, so opening or leaving the
  page in combat would leave the key wrong until combat ends, and it would need a second place to pick the key.
  Away from My Auctions the key does nothing; with The Market not loaded it says so (`Core/Commands.lua`).
- Items Ahead Allowed (`aheadAllowed`, 0 to 200) is how many items may be listed for less before an auction counts
  as undercut. The items ahead of an auction are the listed quantities, less your own, of every listing under its
  price, from the same check that finds the lowest (`Market.Listings`' rows, kept per item as price and quantity
  pairs until the page is opened again). At 0 any cheaper item is an undercut, as before the setting. With some
  ahead but no more than allowed, the row's pill reads "N ahead" in green, it sorts just before Lowest, and Cancel
  Undercut and the key pass it by.
- The listings read stop at `MAX_ROWS` (50) price rows, so the items ahead of an auction far down a long ladder are
  at least the number shown.
- An undercut row is a line taller (`ROW_TALL_H`): "Yours ..., lowest ..." and under it "N ahead" with its time
  left, which do not fit one line at 380 wide. The other rows keep two lines.
- Sell's listings are `Market.Listings`' rows for the item in front of you, the search Sell already sends: no
  query is added. They are a pane of their own between the form and Up Next (`View/Listed.lua`), under a head
  that folds them, "Listings (N)" with N the price rows. Open is the default, since the listings are what
  the price is set against; the fold is the account's (`marketListingsFolded`).
- Blizzard's window is 538 tall, which leaves the Sell page about 458: the form takes 212 of it, so the list
  shows `ROWS` (4) rows of `ROW_H` (18) and the marker, and scrolls for the rest. A fifth row would leave Up
  Next one row once an item has a past post. Folded, the pane is its head, `HEAD_H` (22).
- While an item's listings are asked for, the pane keeps the height it had and reads Checking, so Up Next does
  not jump with every item; with nobody selling it is one line saying yours would be the only one.
- A row is its price for one, to the copper, its quantity, and a green Yours pill when some of it is yours.
  The cheapest row that is not yours has the accent price: it is the one Sell prices against.
- The Your price marker is a thin row put before the first listing dearer than the price in the price box,
  so a price equal to a listing's lands after it, as the auction house sells the older auction first. It
  moves with every price typed, stepped or taken.
- A click on a row takes its price as a price set by hand (`Sell.TakePrice`), so Ask Before a Bad Post
  weighs it; an item that is not a commodity is taken down to a whole silver.
- Buy and Cancel are small buttons shown on the row under the mouse, made the first time a row is hovered:
  nothing is hidden behind a right-click, and the row's tooltip says what each does. A row of a price you
  share with others shows both.
- Buying is `Market.Purchase`, which listens to the game's answers only while a purchase waits.
  `PlaceBid`, `StartCommoditiesPurchase` and `ConfirmCommoditiesPurchase` need a hardware event each
  (Professions' Why: a commodity purchase started on its own was blocked), so nothing is bought outside a
  click.
- An item's Buy asks first (`ns.Confirm`, naming that auction's own item (`row.link`), since a piece of
  gear's listings hold every suffix of it, and the buyout), and the confirm's Buy is the click
  that calls `PlaceBid` with the buyout, as Blizzard's own `BUYOUT_AUCTION` popup does. It is done on
  `AUCTION_HOUSE_PURCHASE_COMPLETED` for that auction, and failed on `AUCTION_HOUSE_SHOW_ERROR`.
- A commodity takes the two clicks Blizzard's own buy dialog takes. The row's Buy, or the Buy of the
  how-many prompt below when the row holds more than one, is the first: it calls
  `StartCommoditiesPurchase` and the head reads Getting the price. The game's quote
  (`COMMODITY_PRICE_UPDATED`) opens the confirm with the total the game quoted, not The Market's sum, and
  the confirm's Buy is the second click, `ConfirmCommoditiesPurchase`. A quote that changes while the
  confirm is up asks again with the new total. Closing the confirm, leaving Sell or `BUY_TIMEOUT` (15)
  seconds without an answer calls `CancelCommoditiesPurchase`, as Blizzard's dialog does when it hides.
- The game sells a commodity cheapest first, so a row's Buy is for every item listed up to that row's price
  that is not yours (`Listings.Others`), and the tooltip says how many and about how much.
- With more than one to buy, the row's Buy asks how many first (`ns.PromptText`, filled in with them all),
  so part of a row can be bought: a number over the row's count buys the row's count, and one that costs
  more than you carry says so and asks the game nothing. The quote is then for the number typed.
- Cancel is My Auctions' confirm and `Auctions.Cancel`: one auction a click, never twice. The auction is the
  search result's own `auctionID` on a row that holds yours, which is what Blizzard's Auctions tab cancels
  from the same rows, offered only while `CanCancelAuction` says so.
- After a purchase or `AUCTION_CANCELED` the same search is sent again (`Listings.Again`).
- Sell offers all you carry of an item, as it always has, until a chip over the quantity box says otherwise:
  1, a number or All. A chip sets the quantity now and is kept as the default for that type of item: Trade
  Goods, Consumables, Recipes (`Enum.ItemClass`, read with `GetItemInfoInstant`) and everything else. The
  default is where the player is, on the form, because that is where it is wanted; no setting has to be found
  first.
- A default is a number, `sellQuantityTrade`, `sellQuantityConsumable`, `sellQuantityRecipe` and
  `sellQuantityOther`: 0 is all you carry, which every type starts at. The number chip's number is kept by type
  too (`sellNumberTrade` and the others, 20 until changed); a right-click on it asks for another with
  `ns.PromptText`, from `NUMBER_MIN` (2), since 1 has a chip of its own. Its tooltip says so, and names the type
  with the game's own class name (`C_Item.GetItemClassInfo`), so no class name is written or translated here.
- A quantity typed in the box is for that post only: the default stays, no chip is lit, and the next post of
  the item is back on the default. No quantity is ever more than you carry. Up Next's worth and the totals
  still count all of an item, since what is left stays in the queue.
- The chips sit on the form's label line, over the quantity box and right-aligned to the form, as
  `Parts.Pill`s. Beside the box they do not fit: the price boxes, the quantity box and "of N" leave under 130
  of the panel's 360 pixels, and a row of their own would cost Up Next a row.
- The Selling card has one Default Quantity row: each type's default beside a Reset button that puts them all
  back to All. A row for each type would need the game's class names as row labels, and a settings row's label
  is read by the search index when the game is not running.
- Blackwater Price (`tooltipOther`, off) adds one line under the auction price with the price at the other
  house you can reach: the realm's Blackwater house, or your faction's while you stand at a Blackwater
  auctioneer, then named with the game's own name for your faction. It reads `ns.AuctionOtherPrice` (QoL's
  Auction Prices), never a price table, and sends no query: the price is the release's, or your own scan or
  sighting made there. It reads as the stack prices do, to the copper.
- Until a scan at Blackwater tells which of the region's Blackwater houses is this realm's, that price is
  the middle of them, as your faction's is before your first scan.
  Price Graph's line on which house pays more waits for that scan (or a price seen there): a middle of
  other realms' houses is no reason to make the trip.
- Price Graph says the same under the picked item's header, with the price's age, and adds a second line
  when one house clearly pays more: what one item makes after the 5% cut at each house (`Market.AfterCut`),
  one less the other. Clearly is `CLEARLY_HIGHER`, a tenth of the lower of the two: closer than that is not
  worth the trip. They are two lines, not one, so each fits the header at the window's narrowest (about 376
  pixels beside the list) in every language; the header grows by `LINE_H` for each, and the Watch row and
  the chart move down with it.
- What The Market keeps per house (price history, sales, past posts) follows the house you are at
  (`ns.AuctionHouseKey`), so prices seen at Blackwater never draw into your faction's chart. Your characters
  are still told apart by realm and faction (`Market.HouseKey`).
- Movers are a switch over Price Graph's list, Items, Dropped and Rose (`Parts.Tabs`, as Buy's Watch List and
  Searches are): the same search list (`Market.Finder`) filled another way, so a row is picked and charted
  as any other. A row's price column carries today's price and the change, red for a drop and green for a
  rise, through the list's own `side` note, so the list has no second kind of row. A long name is cut as on
  every list, and the row's tooltip is the item's.
- `History.Movers` compares the last two days that have prices, whatever lies between them: each item's
  lowest on the last day against its lowest on the one before. That day is unpacked once with one `gmatch`,
  never with one `match` an item, which would read the whole day's string thousands of times.
- Thin markets are left out. An item needs `MOVERS_MIN_LISTED` (5) listed on both days where the count is
  known (an unknown count still counts, or history from before the counts would list nothing), and a price
  of at least `MOVERS_MIN_PRICE` (a silver) on both, so 1c to 2c is not +100%. Each list is its
  `MOVERS_TOP` (20) biggest moves, biggest first.
- They are worked out when the list is drawn and the history has changed since (`house.at`): after a scan,
  a sighting, or on opening the view, never per frame. Only the listed items' prices and changes are kept.
- While Dropped or Rose shows, the writ filter is put away and the search takes its room; typing still
  searches every scan by name. The view you left is the one you come back to until a reload, as on Buy.
- The switch's labels are `Dropped (price)` and `Rose (price)` in the catalog: Dropped already means loot
  that dropped.
- Include Bank (`bagWorthBank`, off) adds the bank to Bag Worth. The bank can be read only while it is open,
  so each character keeps what it held (`marketBank`, by GUID through `Shared.CharacterData`): item ID to
  count, with bound items in a list of their own, since a bound item counts at its vendor price as in the
  bags, and items with no value (`hasNoValue`) left out, as the bag reader leaves them.
- It is read when the bank opens (`BANKFRAME_OPENED`) and a frame after a change while it is open:
  `PLAYERBANKSLOTS_CHANGED`, which a sort sends once a slot, and `BAG_UPDATE_DELAYED`, which is what QoL's
  Alt Item Counts reads the bank tabs on. Those two are listened for only between opening and closing.
  Closing dates what is kept and reads nothing: a change still waiting then is dropped, because a closed
  bank may read as empty and would wipe it. `BANKFRAME_CLOSED` can come twice, and the second does nothing.
- The tabs are `Enum.BagIndex.CharacterBankTab_1` to `_9`, the character's own bank. The account's bank is
  not counted: it is no one character's.
- It keeps at most `MAX_ITEMS` (500) different items a character. It is priced when the card is, from the
  current scan (`Worth.Each`, the bags' own rule), so a new scan reprices the bank too. An item the client
  has not loaded yet counts at its auction price alone until it has.
- The card says how old it is on a line of its own, "Bank as of 2 h ago" with what the bank would fetch, and
  Bags and bank under it; a bank not seen yet says to open it once. Beside Most Valuable there is no room
  for a longer total in the card's 260 pixels, so each is a row, a label left and coins right. The card's
  own total and its five items stay the bags': a click on one sells it from your bags, and Sell's queue
  never reads the bank.
- With Include Bank off no bank event is registered and no frame is made. Turned on with the bank already
  open, it is read at the next visit.
- Mailbox Total (`tooltipMail`, off, under Tooltip Lines) adds one line to the tooltip of a mail in the inbox:
  what its attachments would fetch at auction, each at the price its own tooltip shows (`ns.AuctionPrice`)
  times its count, to the copper. A line an attachment would run to sixteen lines, so it is one total; a
  mail whose attachments have no auction price gets no line.
- Blizzard's inbox buttons build that tooltip in `InboxFrameItem_OnEnter`, a global their OnEnter, OnEvent
  and OnUpdate call by name, so a `hooksecurefunc` on it runs after each build and adds the line to the
  tooltip Blizzard already made. Nothing is set or hooked on the buttons, and the button is only read
  (`index`, `hasItem`). The hook goes in the first time the setting is on, and returns at once while it is off.
- The buttons' OnUpdate builds the tooltip again every frame while it is up. The total is therefore kept
  for `TOTAL_KEEP` (half a second) for the mail under the mouse: its `ATTACHMENTS_MAX_RECEIVE` (16)
  attachments are read twice a second, not sixty times, and a mail that changed is right half a second on.
- Average Price (`tooltipAverage`, off) adds "7-day average": the mean of the item's lowest price on each
  day that has one among the last `CHANGE_DAYS` (7) days of history, the window the change line looks back
  over, counted back from the last day with prices. It needs `AVERAGE_MIN_DAYS` (3) of them: two days are
  the change line's business, and a mean of two says less than either. It is the price for one, rounded to
  the nearest copper and shown to the copper, in both tooltip styles: under the change line in Detailed,
  under the Auction line in Compact.
- A bag tooltip is built again five times a second and a past day is one `match` over that day's string,
  so `History.Average` keeps its last answer, for that item and window, until the history changes.

## Checking

`lua5.1 Tools/regression/test-market-sell.lua` covers the queue, the prices and posting offline,
`test-market-auctions.lua` My Auctions and the items ahead, `test-market-auctions-page.lua` its page, filter and
key, `test-market-worth.lua` the price history, Bag Worth and Best
Way to Sell's verdict, `test-market-tooltip.lua` the tooltip lines and Shift swapping their stack prices, `test-market-chart.lua` the price
chart, `test-market-crafts.lua` Crafts, `test-market-farm.lua` Farm, `test-market-runs.lua` gathering
runs, `test-market-extras.lua` sales; all load the rules through `Tools/regression/market_world.lua`.
`test-market-dock.lua` checks the panel and the tabs beside Blizzard's window, `test-market-house-tabs.lua`
those tabs' look, `test-market-window.lua` the window free and docked, `test-market-move.lua` Shift + drag
and the spot kept, `test-market-shopping.lua` the
Shopping List page, `test-market-tabs.lua` the tab bars, `test-market-searches.lua` the saved searches, running them
and their share string, and `test-market-search-view.lua` Buy's Watch List and Searches views.
`test-market-sell-listings.lua` covers the listings under Sell's form, buying and cancelling from them, and
`test-market-sell-quantity.lua` the quantity chips and each type's default.
`test-market-houses.lua` covers the other auction house's price and what is kept per house,
`test-market-movers.lua` the movers, and `test-market-buy-watch.lua` Price Graph's list, its views and its header.
`test-market-bank.lua` covers Include Bank: what is kept of the bank, its worth and its lines on the card,
and `test-market-mail.lua` Mailbox Total.
`test-market-sell-ask.lua` builds the Sell page on stub frames (`market_sell_page.lua`) for Ask Before a Bad Post,
`test-market-sell-marks.lua` for favourites and hidden items, `test-market-sell-undercut.lua` for Undercut's Percent
and Fixed Amount and the Starting Bid, and `test-market-sell-past.lua` for your past posts.
In game, at an auctioneer, with The Market on:

1. Blizzard's window opens as the game draws it, with The Market's panel docked to its right, top to
   bottom, on Sell with your bags in Up Next, most valuable first. Blizzard's Buy, Sell and Auctions
   tabs all work as without The Market.
2. The panel's tabs read Buy, Sell, My Auctions and Shopping List, every label whole, with counts after
   Sell's and My Auctions'. With Professions off, Shopping List is not there.
3. Farm, Price Graph and Reagents follow Blizzard's Auctions tab in one row, as tall as its tabs, in
   their font and art, none picked; Scan Prices follows them. With EllesmereUI's skin on, they are the
   same flat dark tabs as Blizzard's, the same height and font, and a picked one has the line under it.
4. The first item's listing count fills in top right, and its price is one step under the cheapest that
   is not yours; the line under the item says how far under, or that yours is already the cheapest.
5. Post posts it, the next item comes up, and the bar's total counts up. With Post With Keys on, Space
   does the same; with it off, Space does nothing in the panel.
6. With Post With Keys on, Up and Down step the price to just under the next listing; typing a price
   makes it yours.
7. Right-clicking a bag item picks it on the panel's Sell, and Blizzard's Sell tab takes it too. Post on the
   panel posts it.
8. The panel's X closes it, and nothing appears above Blizzard's window. Leaving the auctioneer and coming
   back opens the panel again.
9. Professions' Shopping List (and Search Favorites AH, Disenchant Deals) sits to the right of the
   panel, never on top of it; with the panel closed, beside Blizzard's window.
10. My Auctions lists your auctions, undercut first, checks each item, and marks the undercut ones; a
    commodity auction's price is the price for one (check against Blizzard's Auctions tab).
11. Cancel asks first and cancels; Cancel Undercut cancels one per press; the list reads again.
12. Sell and My Auctions show their counts on their tabs; My Auctions turns orange when one is undercut. Buy shows,
    in green, how many watched items are at or under your price.
13. A piece of gear on Sell, with someone else's listed, is priced a whole silver under theirs and its
    price box has no copper; it posts without "Internal auction error". A commodity still steps a copper.
14. Set Selling's Undercut to Match the Cheapest: Sell prices at the cheapest listing that is not yours
    and says it matches it. One Silver puts a commodity a silver under, and gear a silver under as before.
15. The panel fits the auction house's height at your UI scale, with Up Next showing several items.
16. Farm docks The Market's window right of Blizzard's, top to bottom, ending at the screen's right edge, and
    the panel goes; Farm shows as picked. The map, the zone list and the picked item's strip lay out without
    overlap; at 700 wide the strip drops its 14-day line. Price Graph and Reagents do the same: Price Graph's
    list, chart and Watch row with Stop Watching fit, Reagents' list and description fit beside its search.
17. Search Favorites AH, Disenchant Deals and the Shopping List sit to the right of the docked window.
18. Clicking the picked tab again, or the window's X, closes it and the panel comes back; so does a Bag
    Worth row or Farm's Sell button, on Sell with that item. The window's own tabs move the picked tab.
19. Dock Farm, leave the auctioneer and come back: the panel opens, not Farm. Away from it, `/market` opens
    the window free, at its own spot and size.
20. Shift + drag on Blizzard's window, the panel or the docked window moves Blizzard's window with them;
    a drag without Shift does nothing. Opening and closing your bags, the character window or the map
    keeps it there, and so does leaving and coming back. Dragged right, the docked window narrows to stay
    on screen. With The Market off, it opens where the game puts it.
21. On Shopping List, with a Shopping List on this character and on an alt on the same realm and faction:
    your materials come first, then the alt's, each reading "N more for <alt>". Buying the alt's row's
    item in Blizzard's buy dialog lowers the alt's row, yours does not; on the alt, its list shows what
    was bought. Buying with your own row picked lowers your row.
22. With The Market off, Blizzard's window has no tabs of The Market's, no panel and Scan Prices sits
    after its Auctions tab.

Away from the auction house:

23. With Bag Worth on, opening your bags shows it above them: the total, and the five most valuable
    items; the same five are numbered on their slots, in Blizzard's bags and in EllesmereUI's.
24. Selling or looting changes the card and the numbers.
25. At the auction house, clicking a Bag Worth row picks it on the panel's Sell page.
26. A stack's tooltip shows Stack of N with its worth; after scans on two days, the change line shows.
27. A green or blue weapon or armour shows a Disenchant line with Professions loaded.
28. `/market`, `/nfmarket` and the key binding open The Market's window on Farm, with Farm, Reagents and
    Price Graph along the bottom. It drags, and opens where you left it.
29. Log in on an alt with The Market on and open its profession: its recipes show under its name.
30. A crafted item's tooltip shows Made by and its materials' cost; a material's shows Crafts into.
31. Farm lists the zones for your Herbalism and Mining, richest first, each with its best items.
32. Picking a zone draws its map with every herb and vein: bigger pins for more gold, a gold line for
    the loop, faded pins for nodes you gathered in the last ten minutes.
33. Herbs, Veins and Nodes I Can't Gather Yet change the map, the loop and the list.
34. Start Loop places a waypoint at the nearest stop and the next as you reach each.
35. Clicking a pin shows its item in the strip: price, the last 14 days, what you hold. With Farm docked
    at an auctioneer, Sell picks it on the panel's Sell page.
36. Gather a few herbs or veins: Farm's picked item shows what you hold of it.
37. Farm's list head reads your Herbalism, Mining, Skinning and Fishing skill.
38. Ten minutes without gathering, then another gather, starts a new run that counts toward Farm's
    learned yields.
39. After three of a node, its pins on Farm are priced from what you gathered; after a five-minute run
    the zone reads "you made ... an hour".
40. After an auction sells, My Auctions' line adds what you sold in the last 7 days, and the item's
    tooltip shows "You sold N" with the price and when.
41. Farm's strip draws the item's last 14 days once two days have scans.
42. With Fishing learned, Farm lists fishing rows (the Fishing icon first, then the best catches) beside
    the gathering rows, and the Fishing filter takes them out. A fish row's map says to fish anywhere
    until a pool is learned; its strip shows the best catch and what A catch is worth.
43. Fish from a school (Oily Blackmouth, Firefin Snapper, Floating Wreckage): a pool pin appears where
    you stood. Unverified: that a pool's catch names the pool as its loot source (`GetLootSourceInfo`).
    If it names the bobber instead, no pool is ever recorded.
44. Reagents, away from an auctioneer too: each reagent in your bags, with Craft beside the ones worth
    crafting; a click opens every recipe it goes into, and an unlearned one's click sets a waypoint to
    where you learn it.
45. Typing in Reagents' search finds any reagent by name, carried or not.
46. With Professions on and a scan taken, each Crafts row shows Sell, Disenchant or Vendor under Sells
    for. A green your characters craft that disenchants for more than it sells shows Disenchant, at its
    tooltip's Disenchant line times what it makes, and sorts by that profit; the Disenchant tab lists
    only those, and the green's tooltip reads "profit ... (Disenchant)".
47. Tooltip Style on Compact: a stack of cloth in your bags shows Auction and Vendor, one line each, with
    no The Market header and no Market Price line above them; a green adds Disenchant. Back on
    Detailed, the tooltip is as it was.
48. Stack Prices on the same stack: Each Item, Whole Stack and Both change Compact's Auction and Vendor
    lines. Whole Stack and Both read "Auction x20" on the left with the stack's price on the right; Each
    Item reads "Auction" with no count. On Detailed, Whole Stack shows Stack of N and no Market Price
    line, Each Item the Market Price line and no Stack of N, and Both the two.
49. Best Way to Sell on: the cloth reads Best: Auction (or Vendor, when a vendor pays more after the cut)
    and by how much. A green reads Best: Disenchant on an enchanter who can disenchant it when its
    materials fetch more, never on a character without Enchanting; an item with no scan price reads
    Better: and names only what it beat.
50. The Market's settings page has Disenchant Deals: Professions' Disenchant Deals rows (with Professions
    loaded). Turning one on there turns it on in Professions too.
51. The Market's settings page has Key Binding: set a key there and it shows the same in the game's Key
    Bindings menu (Open The Market). The key opens The Market's window and a second press closes it.
52. Price Graph lists the items in your bags that have a scan price, most valuable first, and draws the first
    one's lowest price each day once two days have scans: its highest and lowest price on the left, the
    change over the week top right. Hovering it names the day and its price.
53. Typing two letters or more in Price Graph's search lists the items in your scans with that in their name;
    picking one draws its chart. Clearing the search lists your bags again.

Back at an auctioneer:

54. The panel opens on Buy as Blizzard's window does. Clicking Blizzard's Sell or Auctions tab moves the panel to
    Sell or My Auctions, and Buy back to Buy; a tab picked on the panel stays until Blizzard's tab changes.
55. On Buy, type two letters of an item in your scans, pick it, set a price and press Watch: it joins the list,
    marked in blue. With the search empty, the list shows only watched items, at or under your price first in green.
56. A watched row's x and the Stop Watching button take it off the list.
57. With a watched item at or under your price, on Sell the panel shows the green line; clicking it opens Buy.

Away from it again:

58. Price Graph still has the Watch box for the item it shows, and its list is your bags, not the Watch List.
59. Best Way to Sell on, Auction Margin at 1s: a stack of cloth whose auction price beats its vendor price
    by under a silver each after the cut reads Best: Vendor and "Auction only +..."; at 0 it reads Best:
    Auction again. With Best Way to Sell off, Auction Margin is dimmed and says it needs it.
60. Price Graph's filter: All Writs lists the Craftsman's Writs in your scans, by name; a profession, named in
    your client's language, lists only its own; typing searches within it; All Items goes back to your bags.
61. On a character without Mining, tick Veins and Plan at max skill: Farm lists the vein zones, and a
    zone's map shows its veins faded with a loop through them. Untick it and the list empties again.

Back at an auctioneer, on Sell:

62. Type a price a tenth of the cheapest listing and press Post: a confirm names the item, your price and
    the cheapest listing, and nothing is posted. Cancel or Escape posts nothing; Post Anyway posts it. An
    item under For a Vendor asks against the vendor's price. A post at the suggested price never asks.
63. With Post With Keys on, Space opens the same confirm and Enter posts it. With Ask Before a Bad Post
    off, the low price posts at once.
64. Right-click an Up Next row and pick Favourite: it moves to the top with a gold star on its icon, and
    is still there after a /reload and on an alt. Remove Favourite puts it back.
65. Right-click a row and pick Hide from Sell: it leaves Up Next, the Sell tab's count drops by one and
    Hidden (1) appears at the bottom. Clicking Hidden lists it; its right-click has Show in Sell, which
    puts it back. Bag Worth and the item's tooltip read the same as before it was hidden.
66. Set Selling's Undercut to Percent: Undercut Percent lights up (Undercut Amount stays dimmed and says
    what it needs), and at 10 a commodity with a cheapest listing of 1g is priced at 90s. Gear is priced on
    whole silver, 10% or a little more under. With your own listing the cheapest, it still matches yours.
67. Fixed Amount with Undercut Amount at 5s: the same commodity is priced at 95s, gear 5s under.
68. Turn on Starting Bid: a piece of gear on Sell shows a Starting Bid row between the price and the
    duration, with gold and silver only, and every control still fits the panel; a commodity shows no
    such row. Post with a bid of half the price: Blizzard's Auctions tab lists the auction with that bid
    and your buyout, and no "Internal auction error". A bid at or over the price greys Post and says the
    buyout must be higher. Left blank, the post is a buyout only.
69. Post an item, then bring the same item up on Sell again (another stack, or after cancelling it):
    under the post line it reads "Last post:" with the price each, the quantity and Today. Clicking it
    puts that price in the price box. A post the auction house refuses adds nothing.
70. Post the same item at a second price: All 2 appears on the right of that line, and its menu lists both
    with their durations; picking one takes its price. The lines are still there after a /reload and on
    an alt on the same realm and faction, and the line fits the panel beside All.

At an auctioneer, on the panel's Buy tab:

71. Watch List and Searches switch the page, both labels whole. Searches opens on Recent, or on your first list.
72. Search in Blizzard's Buy tab with a category picked, a level range and a quality unticked: the search shows at
    the top of Recent with those under its name. Clicking it runs it again in Blizzard's window, with the category
    picked in Blizzard's list and the name in its search box.
73. The + on a recent search offers your lists and New List. With a list shown, Save Search keeps what Blizzard's
    window has now, and says so when it is already there.
74. A saved search's right-click menu has Rename, Exact Name, Max Price, Move Up, Move Down and Delete; its x deletes
    it. A max price shows on the row as "Up to ...". Unverified: with Exact Name ticked, the results are only items
    of exactly that name.
75. The list button's menu has New List, Rename List, Delete List (it asks first), Import List and Export List. An
    exported string pasted into Import List makes a new list with the same searches; a cut or changed string says
    it is not a search list.
76. After running a saved search with a category, buy an item and a commodity in Blizzard's window: no blocked
    action, no Lua error.
77. Click a saved search while Blizzard's results are still loading: it runs once the auction house is ready.
78. On an alt, the lists and Recent are the same.

On My Auctions, with several auctions up and some undercut:

79. The filter box under the totals lists only the auctions with what you type in their name, and Cancel Undercut's
    count follows it; a name nothing matches says so. Clearing it lists them all.
80. An undercut row is taller than the others: "Yours ..., lowest ..." and under it "N ahead" with its time
    left. N is the items listed under your price that are not yours (check against Blizzard's listings).
81. The Market's settings, Key Binding: set Cancel Next Undercut Auction to a key. On My Auctions each press cancels
    one undercut auction, the next one listed, with no blocked action; with a filter typed, only auctions it lists.
    On another tab, or away from the auction house, the key does nothing.
82. The Market's settings, My Auctions: set Items Ahead Allowed above an undercut row's N. The row turns to a green
    "N ahead", drops out of Cancel Undercut's count and the tab's orange count, and the key passes it by. Back at
    0, it is undercut again.

Prices kept as you go, at an auctioneer, with QoL's Scan Prices Button or The Market on:

83. Search Blizzard's Buy tab for an item and hover one in your bags: its Market Price is the row's price
    and reads "1m ago", while Scan Prices still says when the last scan was. `/dump
    NaowhForever.AuctionListed(itemID)` is the row's Available.
84. Unverified: what a browse row's price is for an item with bids only. If such an item gets a Market
    Price, `minPrice` is a bid there and rows without a buyout need leaving out.
85. Pick an item on the panel's Sell page: once its listings show, its tooltip price is the cheapest listing.
    Post it under that: the tooltip price is your post's.
86. Search "of the Monkey" on a green with random suffixes whose scan price is lower than every row: its
    Market Price does not go up.
87. Price Graph, on an item just seen at a lower price than today's scan: today's point is the lower price.
88. With the Scan Prices Button and The Market both off, browsing changes no tooltip price.

Scan Prices, at an auctioneer:

89. Press Scan Prices: chat says to wait, the button counts up in percent, and chat ends with "Last scan
    1m ago: N items priced".
90. Press it again inside 15 minutes: chat says the fast scan is free again in Nm and that this one reads
    page by page, the button counts items ("1500 items"), Blizzard's Buy tab fills with every item, and
    it ends with the same "Last scan" line. Unverified offline: that an empty browse query returns every
    item on Forever, how many rows a page holds and how long a whole house takes; if it returns nothing
    the scan says "The auction house returned no listings" and the old prices stay.
91. Compare a few items' Market Price after a page by page scan with Blizzard's Buy tab: the same lowest
    price, and `/dump NaowhForever.AuctionListed(itemID)` is the row's Available.
92. During a page by page scan, search for something in Blizzard's Buy tab: chat says the scan stopped
    because another search took its place, and your results show. Leave the auctioneer during one: chat
    says the scan stopped because the auction house closed.
93. With The Market's Sell page open and searching, a page by page scan still finishes, and Sell still
    prices its items.
94. Scan on Opening on, older than 15 min: opening the auction house a second later starts a scan by
    itself and says so; opening it again a minute later starts none. Off (the default), opening scans
    nothing. With favourites set, Blizzard's favourites show first and the scan follows.

Listed counts in the price history:

95. After a scan, hover today's point on Price Graph: the day, its price and "N listed", the number
    Blizzard's Buy tab shows as Available after a page by page scan.
96. A day scanned before this version shows its price and no "listed" line, and its chart is unchanged.
97. After the next day's first scan, yesterday's point still shows its count (`/reload` first, so it is read
    from the saved data).

The listings on Sell, at an auctioneer:

98. Pick a commodity several people sell: under the form, Listings (N) lists each price with its quantity,
    cheapest first, four rows and a scroll bar for the rest, and Up Next still shows items under it. Nothing
    is cut off at the panel's right edge, in the Naowh look and the Forever look.
99. The cheapest listing that is not yours has a blue price. A thin Your price row sits where the price in
    the price box lands; typing a price, or Up and Down with Post With Keys, moves it.
100. Click a listing: its price is in the price box and the line under the item reads set by hand. Click one
     far under the others and press Post: Ask Before a Bad Post asks.
101. Post one of the item, then pick it again: its row has a green Yours pill. Hovering it swaps the pill for
     Cancel; Cancel asks as My Auctions does, Yes takes the auction down with no blocked action, and the
     list reads again without it.
102. Hover a row that is not yours: Buy shows at its right edge and the tooltip says how many it buys and for
     about how much. Press Buy on a commodity's second row and accept how many (step 116): the head reads
     Getting the price, then a confirm names the quantity, the item and the total. Cancel buys nothing. Buy
     buys it, with no blocked action and no Lua error, the head reads Bought N and the list reads again.
103. On a piece of gear someone else sells, Buy asks with its buyout, and the confirm's Buy buys that auction.
104. With less gold than a row costs, Buy says you do not have enough money and asks nothing.
105. Click the Listings head: the rows fold away and Up Next takes the room. It is still folded after a
     /reload and on an alt. An item nobody sells reads "No listings: yours would be the only one."
106. Unverified in game: that a commodity row holding your items and another seller's carries your auction's
     ID. If Cancel does nothing there, the row's ID is the other seller's and `CanCancelAuction` should have
     hidden it.

The quantity chips on Sell:

107. Over the quantity box, right-aligned to the form, are three chips: 1, 20 and All, with All lit, and the
     quantity box reads all you carry. Nothing overlaps the Quantity label or "of N", in both looks.
108. Pick a stack of ore and click 20: the quantity is 20 (or all you carry, if fewer), 20 is lit and Post
     reads Post 20. Pick another trade good: it offers 20 too. A potion still offers all.
109. Hover a chip on a trade good: it reads Default for Trade Goods, in your client's language; on a piece
     of gear, Default for other items.
110. Right-click the number chip, type 40 and Save: the chip reads 40 and the quantity is 40. A potion's
     number chip still reads 20.
111. Type 7 in the quantity box and post: 7 are posted, no chip is lit while it is typed, and the next ore
     offers the default again.
112. The Market's settings, Selling: Default Quantity lists each type's default, and Reset puts them all back
     to All.

Shift on a stack's tooltip, away from the auction house too:

113. With Shift Swaps Stack Prices off (the default), holding Shift over a stack in your bags changes none of
     The Market's lines.
114. Turn it on with Stack Prices on Each Item and hover a stack: holding Shift shows Stack of N (Compact:
     "Auction x20" with the stack's price) and letting go puts each item's price back, while the tooltip
     stays up. On Whole Stack it is the other way round, and the Market Price line comes and goes with it.
     On Both nothing changes.
115. With it on: Shift-click a bag item into chat still links it, Shift over a piece of gear still shows the
     compare tooltips, and no error or blocked action shows in or out of combat. In EllesmereUI's bags the
     lines follow Shift the same way.

Buying part of a commodity row, on Sell at an auctioneer:

116. Buy on a commodity row with several listed asks how many, filled in with all of them up to that row.
     Typing a smaller number and pressing Buy gets the price for that many, and the confirm names that
     number and its total; a number over the row's count buys the row's count. With one listed, it goes
     straight to the price.

The other auction house's price:

117. With Blackwater Price off (the default), tooltips are as before. On, an item the release's prices or
     your scans price at Blackwater shows a Blackwater line under its auction price, in both tooltip styles.
118. Price Graph: the picked item's header has a muted line, "Blackwater: ... each, ... ago", and a second
     line when one house clearly pays more, saying how much after the cut. The Watch row and the chart sit
     under them with nothing overlapping, in both looks, and docked at 700 wide.
119. At a Blackwater auctioneer (Booty Bay), `/dump NaowhForever.AuctionHouseKey()` ends in Blackwater, a
     tooltip's Market Price is Blackwater's and the extra line is named for your faction. Scan there, leave,
     and hover an item: Market Price is your faction's again and the Blackwater line reads the scan's price.
120. Unverified in game: at a city auctioneer, `/dump UnitFactionGroup("npc"), C_PvP.GetZonePVPInfo()` is
     your faction and "friendly", and `NaowhForever.AuctionHouseKey()` ends in your faction. In Booty Bay
     the first is nil, the second is not "friendly", and the key ends in Blackwater.

Movers on Price Graph:

121. Over Price Graph's list are Items, Dropped and Rose, every label whole, in both looks. With prices on
     one day only, Dropped and Rose say they need prices on two days.
122. After scans on two days, Dropped lists up to twenty items, the biggest drop first, each with its icon,
     name, today's price and the percent in red; Rose the same in green. The first is picked and its chart
     drawn; clicking another draws that one's.
123. No row reads +100% for an item worth coppers, and an item with one or two listed is not there.
124. On Dropped or Rose the filter button is gone and the search is as wide as the list; typing finds any
     item in your scans. Items brings your bags and the filter back.

Include Bank, with Bag Worth on:

125. With Include Bank off (the default), the Bag Worth card is as before. On, before visiting a bank, the
     card has a line "Bank not seen yet: open it once", inside the card.
126. Open the bank and close it: the card reads "Bank as of just now" with what the bank would fetch, and
     Bags and bank under it with the sum, both inside the card in both looks. An hour later it reads "Bank
     as of 1 h ago". The total top right and the five items are still your bags'.
127. Move a stack from your bags into the bank and close it: the bank's line goes up by it and the bags'
     total down. Unverified in game: that a move within or into a bank tab sends `PLAYERBANKSLOTS_CHANGED`
     or `BAG_UPDATE_DELAYED`; if neither comes, what is kept is the bank as it opened.
128. A soulbound item in the bank counts at its vendor price, and a quest item with no sell price not at all.
129. On another character the card reads not seen yet until that character opens its own bank. Sell's Up
     Next lists no bank item.

Mailbox Total, at a mailbox:

130. With Mailbox Total off (the default), a mail's tooltip in the inbox is Blizzard's own. On, a mail with
     several attachments reads "Attachments: ... at auction" under Blizzard's lines, the sum of each
     attachment's Market Price times its count; a mail with one stack shows the item's tooltip and the line
     for the whole stack.
131. A mail with money or a C.O.D. charge keeps Blizzard's money line, with the Attachments line under it. A
     mail with no attachments, or only items with no Market Price, has no line.
132. Take one item out of a mail with several while hovering it: the line drops by it within a moment. Open
     and take mail, and send mail with attachments: no blocked action and no Lua error, in or out of combat.
133. With Tooltip Lines off, the line is gone.

Average Price on tooltips:

134. With Average Price off (the default), tooltips are as before. On, an item with prices on three or more
     of the last seven days reads "7-day average" with a price to the copper, under the change line; an
     item with one or two days of prices has no such line.
135. The average is between the lowest and highest points of the item's last week on Price Graph. On
     Compact it sits under the Auction line.

Which house pays more, on Price Graph:

136. Before any scan at Blackwater, Price Graph shows Blackwater's price for an item but no "After the cut"
     line. After a scan there, the line appears for items whose prices differ by a tenth or more.
