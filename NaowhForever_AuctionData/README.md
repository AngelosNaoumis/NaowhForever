# Auction Data

Every Forever auction house's lowest price per item, built from Blizzard's auction data by
`Tools/build/auction_feed.py` when a release is packaged. Load-on-demand: Auction Prices
(`NaowhForever_QoL/Loot/AuctionPrices.lua`) loads it the first time something asks for a price, so a
player who never uses a price never loads it.

## Layout

```
NaowhForever_AuctionData/
  NaowhForever_AuctionData.toc  its metadata (LoadOnDemand), and AuctionData.xml
  AuctionData.xml               every file, in load order
  Prices.lua                    each region's houses and prices (ns.AuctionFeed), built at release; git keeps an empty placeholder
```

## Why

- Addons cannot reach the internet, so the prices travel in the addon: every release carries the
  prices of its hour, and a price release (`<version>-prices.<n>`, no changelog line, no Discord
  post, CurseForge only) goes out every evening, between the daily release and the nightly beta.
- `ns.AuctionFeed.time` is Blizzard's Last-Modified of the oldest house, not when the release was
  built: Blizzard's data can lag by hours, and a player's newer scan should win.
- `ns.AuctionFeed.regions` is keyed by `GetCurrentRegion()` (1 the Americas, 3 Europe), then by
  Blizzard's house ID. Each house has its `faction` (Alliance, Horde or Blackwater) and its prices as
  one `id:price,...` string in base 36, each ID the step from the one before: a string costs a
  fraction of the table it decodes to, and only the player's houses are ever decoded.
- Blizzard lists five houses per faction and region, one of them empty. Which one is the player's is
  found in game, from the player's own scan; until then a price is the middle of that faction's houses.
- Git keeps `Prices.lua` as an empty placeholder: the release builds the real one over it just before
  packaging, with the repository's Blizzard API client. Build one from the repo root with
  `BLIZZARD_CLIENT_ID` and `BLIZZARD_CLIENT_SECRET` set, `python Tools/build/auction_feed.py`; don't
  commit the result (the `auction-data-placeholder` pre-commit hook refuses it).
