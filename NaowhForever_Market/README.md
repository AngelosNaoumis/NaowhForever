# The Market

Naowh's own auction house window. At an auctioneer it opens over Blizzard's: your bags most
valuable first, the item in front of you with the auction house's live listings, a price one step
under the cheapest of someone else's, and a post line you work through with Space (post), S (skip)
and Up and Down (the next price step). Blizzard's own window is one button away until you leave the
auctioneer. Built on [`Shared/`](../Shared/README.md).

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
  Auctions.lua       your auctions, each checked against the listings, and cancelling (Market.Auctions)
  Buy.lua            the name search, the cost of a quantity, and buying (Market.Buy)
  View/
    Style.lua        The Market's own look, over Shared/Style.lua (Market.Style)
    Ladder.lua       an item's listings as a ladder, its bars and lit rungs, for Sell and Buy (Market.Ladder)
  UI/
    Window.lua       the window: title bar, scan line, pages, Blizzard's button (Market.Window)
    Sell.lua         the Sell page: the item, its listings, the post line, Up Next
    Buy.lua          the Buy page: the Shopping List, the search, the listings, the buy button
    Auctions.lua     the My Auctions page: your auctions, their status, Cancel and Cancel Undercut
    Takeover.lua     covering Blizzard's auction house, and the way back to it
    SettingsPage.lua the settings page, declared as cards
```

## Why

- Blizzard's auction house window is covered, never hidden: its OnHide calls
  `C_AuctionHouse.CloseAuctionHouse`, which would end the visit. It stays shown at alpha 0 under ours,
  set from its own OnShow so it never shows for a frame. Ours is one strata above it and at least its
  size, anchored to its top left, so nothing of Blizzard's can be clicked through ours. Blizzard's tabs,
  and QoL's Scan Prices button beside them, hang under its bottom edge, so ours reaches
  `BLIZZARD_TABS` further down to cover them too.
- Ours does not move: Blizzard's window is placed by the panel manager and cannot be dragged either,
  and moving it from addon code would fight that placing.
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
  `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`. A search with no answer in `SEARCH_TIMEOUT` seconds, or a
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
  a picked item's listings come through the same search as Sell. The throttle freeing, another item's
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
- An owned auction's item key info (`GetItemKeyInfo`) can be missing until
  `ITEM_KEY_ITEM_INFO_RECEIVED`; until then it shows as Checking and is checked when it arrives.

## Checking

`lua5.1 Tools/regression/test-market-sell.lua` covers the queue, the prices and posting offline,
`test-market-auctions.lua` My Auctions, `test-market-buy.lua` Buy; all load the rules through
`Tools/regression/market_world.lua`.
In game, at an auctioneer, with The Market on:

1. The Market opens over Blizzard's window with your bags in Up Next, most valuable first.
2. The first item's listings fill in, and its price is one step under the cheapest that is not yours.
3. Space posts it, the next item comes up, and the bar's total counts up.
4. Up and Down step the price to just under the next listing; typing a price makes it yours.
5. Right-clicking a bag item picks it.
6. The eye button shows Blizzard's window; The Market button under it comes back.
7. Escape or the X closes the auction house.
8. My Auctions lists your auctions, checks each item, and marks the undercut ones; a commodity
   auction's price is the price for one (check against Blizzard's Auctions tab).
9. Cancel asks first and cancels; Cancel Undercut cancels one per press; the list reads again.
10. Buy: a name and Enter lists results; picking one shows its listings and what you would take.
11. A commodity: Buy gets the price, Confirm buys it, and the Shopping List counts it.
12. Gear: Buy buys the cheapest auction that is not yours.
