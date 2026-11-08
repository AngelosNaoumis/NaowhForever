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
  View/
    Style.lua        The Market's own look, over Shared/Style.lua (Market.Style)
  UI/
    Window.lua       the window: title bar, scan line, pages, Blizzard's button (Market.Window)
    Sell.lua         the Sell page: the item, its listings, the post line, Up Next
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

## Checking

`lua5.1 Tools/regression/test-market-sell.lua` covers the queue, the prices and posting offline.
In game, at an auctioneer, with The Market on:

1. The Market opens over Blizzard's window with your bags in Up Next, most valuable first.
2. The first item's listings fill in, and its price is one step under the cheapest that is not yours.
3. Space posts it, the next item comes up, and the bar's total counts up.
4. Up and Down step the price to just under the next listing; typing a price makes it yours.
5. Right-clicking a bag item picks it.
6. The eye button shows Blizzard's window; The Market button under it comes back.
7. Escape or the X closes the auction house.
