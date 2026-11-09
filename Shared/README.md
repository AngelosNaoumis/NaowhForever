# Shared

What every module can use, so they look and work the same from one copy of the code. The
Dungeon Journal and the BiS List are built on it. Loads after Core and before every module,
through `Shared.xml`. Nothing is made or listened to at load.

## Layout

```
Shared/
  Shared.xml       what loads, in order (the core TOC's Shared load point)
  Shared.lua       the namespace (ns.Shared), the map pin sections that QoL and other modules add to its Map & Pins tab
                   (Shared.MapPins, in order by Shared.MapPinSections), a map pin's scale (Shared.ScalePin), what a character keeps by its
                   GUID (Shared.CharacterData), and how long ago a time was (Shared.Ago)
  Style.lua        the house look: colors (BiS stars, worn green, looks, red and warning orange), icons, sizes
  Data/            data only, generated; never edited by hand
    Forever.lua      what is new in WoW Forever, by ID (Shared.ForeverNew), from Tools/build/forever_new.py
    ItemFacts.lua    each dungeon item's class, subclass, item level, required level and quality before the
                     client loads it (Shared.ItemFacts), from Tools/build/journal.py: the Journal's loot,
                     the BiS List's levels and the Naowh Score's best read it
    FactionItems.lua the same for the factions' rewards, added to it, from Tools/build/factions.py
    SameMaps.lua     the maps the game has under two IDs, each to the one whose data it reads
                     (Shared.SameMaps), from Tools/build/same_maps.py
  Decode.lua       a pasted import string read back as plain data, with size, depth and bomb caps, and
                   outside text cleaned for display (Decode.String, Decode.Text)
  Encode.lua       plain data written as a code the Naowh website reads: LibSerialize's version 1 form
                   without its short forms, deflated and printable (Encode.String): Action Bars' Export
                   to Website
  Game/Items.lua   item helpers: an ID from a link or URL, its name and quality color, In Bag and In Bank,
                   your loot lines, waiting on item data, the items the server would not send, and the
                   Cozy Sleeping Bag's item ID (Items.SLEEPING_BAG)
  Game/Gear.lua    gear helpers on Shared.Items: gear slots, what fits where, what you wear, weapons in
                   short ("1h Sword"), what a class can use (ns.ClassCanUse)
  Game/Bags.lua    the item buttons in your bags, the game's, EllesmereUI's and Baganator's, for
                   the marks painted on them (Bag Marks, Junk Marker)
  Game/Consumables.lua your best food and drink in your bags (ns.BestFoodAndDrink), the healthstones,
                   healing and mana potions, best first (ns.HEALTHSTONES, ns.HEALING_POTIONS,
                   ns.MANA_POTIONS), the food spells and Well Fed buffs (ns.FOOD_SPELLS, ns.WELL_FED),
                   whether you use mana (ns.UsesMana) and whether an item is a drink (ns.IsDrink): QoL's
                   Food & Drink Bar, the Macros' Smart Macros, Aura Buffs' reminders and the Consumable Bar
  Game/ActionKeys.lua the keys on action buttons: the game's bars, LibActionButton bars and EllesmereUI's
                   (Shared.ActionKeys): the Consumable Bar's and the Food & Drink Bar's Show Keybinds
  Game/Roster.lua  our part of a player's tooltip in the Guild & Communities and Friends lists (Badges, Naowh Score)
  Game/Places.lua  zones by name, the map whose data a map reads (Places.SameMap), and showing one on the
                   world map
  Game/Layers.lua  the layer an NPC is on, from its GUID (Shared.LayerOf): QoL's Layer Tracker and
                   Discovery's rare kills
  Game/Towns.lua   town service NPCs by world map (ns.TownNPCs) and the capitals (ns.TownCapitals), by hand:
                   QoL's town pins, the Training Planner's trainers and Professions' rank alerts read it
  Game/Played.lua  the character's /played time, asked for once with the chat print muted (XP Bar, XP per Hour)
  UI/Parts.lua     the small parts: icons in text (Parts.Inline), smooth textures, hover cards (Parts.Tip,
                   Parts.TipLines), the chevron, links (Parts.FlipLink puts the chevron first, pointing
                   back: the Action Bars window's back link), icon buttons, the flat hover and pressed look
                   on a bar button (Parts.Press: the item bars, Blessings, Gear Set and Trinket bars, Group
                   Buttons), a short label in a pill of its color
                   (Parts.Pill, Parts.SetPill: Group Inspect's "NF"), the worn bar, the Wowhead copy card
  UI/Marks.lua     an item's marks: rank stars and lines, the upgrade line, Forever's mark, the item icon,
                   its slot marks (item level, star, Forever's mark, upgrade arrow) and an atlas badge on
                   its top corner (Parts.ItemBadge: Bag Space's clock and quest "!"), and a class icon's
                   crop (Parts.ClassCrop)
  UI/Text.lua      text made once and kept: counts ("3/10"), money with its coins (Parts.Coins; compact,
                   its largest coin only), plain where-lines, numbers lined up to the pixel (Parts.Cells),
                   and a row of labels packed or spread evenly (Parts.LabelRow)
  UI/Money.lua     a price typed in gold, silver and copper, each box beside its coin (Parts.MoneyBox):
                   The Market's post line
  UI/Hud.lua       the HUD look: a HUD line's shadow, font, size and outline (Parts.HudText, Parts.HudFont, Parts.HudFlags),
                   a HUD card's background: the card, a soft fade or none (Parts.HudBackdrop), a window's
                   soft drop shadow (Parts.Shadow), and a progress line that holds still (Parts.ProgressLine)
  UI/Timer.lua     a timer line the client runs down by itself (Parts.TimerLine), its short time text
                   (Parts.ShortTime), and stopping any timer bar (Parts.StopTimer)
  UI/AuraIcon.lua  an aura icon with its stacks and the game's own countdown, sized and coloured from a
                   module's store and style (Shared.AuraIcon): PvP Auras and Raid Debuffs
  UI/Thresholds.lua a proportional four-band line with numeric boundaries and a clamped current-value marker
                   (Parts.ThresholdLine), composed from ProgressLine; an empty band has no label, close labels use extra rows;
                   an optional marker text uses its own row below the boundary labels
  UI/Share.lua     sharing a line in chat or on a copy card (Parts.ShareMenu), and a spot on the map with
                   its pin link (Parts.SharePlace)
  UI/CopyCard.lua  the copy cards: an ID with its Wowhead links (ns.ShowCopyCard), or any line
                   (ns.ShowCopyLine)
  UI/CodeModal.lua a code to paste in or copy out, laid out like the website's popups: a title, a line,
                   a full-width code box (read-only and selected when copying), a summary, Cancel and a
                   primary button (Parts.CodeModal): Action Bars' Import Website Code and Export to Website
  UI/Panels.lua    a window's backdrop and its cards (Parts.Backdrop), the panel a view sits in, and the
                   side panel that opens beside a window
  UI/Window.lua    a window: the frame, its size grip, the title bar with its logo and icons, the link
                   back to the window it was opened from, and the footer
  UI/Forever.lua   the Forever skin's parts, each on the game's own art with a drawn fallback: the window
                   frame with its title bar, portrait and red close (Parts.ForeverFrame), insets, buttons,
                   fields, the search box, tabs, check boxes, dropdowns, sliders, swatches, the
                   help tip, list bars, headings, scroll chevrons, and the options
                   window's header band and metal rails (Parts.ForeverPanes)
  UI/Tabs.lua      a switch of parts side by side (Parts.Tabs), and a search box (Parts.SearchBox)
  UI/SettingsCard.lua a module's card at the top of its settings page: the logo, a line or two, and the
                   button that opens its window
  UI/Tracker.lua   a tracker's small window (Parts.TrackerPanel), and a list row's bands
                   (Parts.RowBands: stripe, hover, the line under it)
  UI/Toast.lua     a toast (Parts.Toast): a banner like the game's level-up one that you can drag, a line over
                   a title, icons and buttons under it, filled by Parts.FillToast and gone by itself after
                   Parts.ShowToast's seconds:
                   Professions' New Herbs and Ores
  UI/ItemBar.lua   an item bar (Shared.ItemBar): secure item buttons in a grid, their count and key texts,
                   the bar's mover, its place or anchor, the count and keybind rows with their cogs, and the
                   Growth Direction choice and placing (ItemBar.GrowChoice, Place): the Consumable Bar,
                   QoL's Food & Drink Bar and Group Buttons, and the Gear Set, Trinket and Blessing bars
  UI/MinimapPins.lua spots on a world map as pins on the minimap, kept in place while you move
                   (Parts.MinimapLayer): Glimmer's herb and ore icons
  UI/Anchor.lua    anchoring a bar to a frame (Shared.Anchor): its Anchor rows, the picker that lights the
                   frame under the cursor, and the editor beside the bar
  View/View.lua    the row engine: pooled rows, cards, the card grid, one redraw per burst
  View/Kinds.lua   the rows every page has: section title (shorter with view.tightTitles), note, card, and
                   an item in a list you keep (icon, name in its quality color, a line under it, a tag, a
                   value, an X)
  Settings/
    Settings.lua   every settings page, declared once: pages, cards, rows, what changed, reset, search index
    Ellesmere.lua  the popup when a setting is on in both EllesmereUI and here
                   (Settings.EllesmereClash)
    Style.lua      the numbers a settings page's controls, rows and page share (Settings.Style)
    Controls.lua   the control on a row for each kind of setting, made once per row (Settings.Control)
    Rows.lua       a settings page's row kinds: a setting, a card's head and foot, a group, an info line,
                   a window card (Settings.kinds)
    Page.lua       a declared page drawn on the row engine: cards, their heads, two-column rows
    Studio.lua     a card's live preview: a stage and the moments it can be seen in
    EditZone.lua   a part of a preview made editable by drag, wheel, click and right-click
```

Each file uses only the ones above it in `Shared.xml`. Every part sits on `ns.Shared.Parts`
(`Parts`), whichever file makes it, so a module never needs to know which file that is.

## Using it

- **A look:** make your module's `Style` with `setmetatable({ ... }, { __index = ns.Shared.Style })`.
  Put only your own values in it; the house ones come through.
- **A page:** `local kinds = ns.Shared.View.NewKinds()`, add your row kinds to it
  (`New(view)` makes the frame once, `Set(row, ...)` fills it and returns its height), then
  `ns.Shared.View.New(parent, kinds, mixin)`. Your mixin draws: `self:Clear()`, `self:Add(...)`
  rows, `self:Fit(events)`, and `Redraw()` draws again.
- **Settings:** a module declares its settings next to its code, on the page they show on:
  `ns.Shared.Settings.Page("QoL/General", S):Card({ id, name, help, switch, summary, order,
  studio, rows = { ... } })`, rows like `{ key = "iconSize", label = "Icon Size", slider = { 12,
  32, 1 } }` and `Settings.Group("Clock")` between them (see `Settings/Settings.lua`).
  `Settings.Group(title, true)` folds the rows up to the next group under a chevron, shut until
  clicked, for this session; a search hit or a jump to one of its rows opens it (AuraBuffs' raid and
  personal buffs). A
  row with `field` (and its own `get`/`set`) is one entry of a table setting `key`, with its own dot
  and reset (AuraBuffs' raid buff switches). A card's `switchWhy`, a function, holds its switch
  and its rows while it returns a reason, greyed with the reason in place of Off (the Food & Drink Bar while its
  buttons are on the Consumable Bar). A row's `why` beside a `needs` function may be a function
  too, for a row held for more than one reason (NF Drink on the Consumable Bar). A row or
  group with `hidden` is left off the page: `true` for one set on the preview instead, or a
  function, so rows for one choice only (the Campfire's Round and Simple rows) show with it. A
  row's `cog = { title, tip }` puts a cog left of its control, opening a small panel of the rows
  declared `under` that row's label: hidden rows, still searched, counted and reset with the
  card, and a search hit on one opens the cog. `icons = { { texture, tip, open, enabled }, ... }`
  adds other icons beside it. A row's or card's `note` is a function given the row or card that
  returns a short line for it, or nil: beside a row's control, after a card's summary. A row's
  `labelColor` is a color table for its label (AuraBuffs' class colors and grey).
  A button row's `buttonText` may be a function, read when the row is drawn and again after each
  click.
  A card with `into = "<id>"` puts its rows, under a group named for it, in the card of that id on the
  same page, in `order`, instead of drawing a card of its own (QoL's Looting, Vendors, Auction Prices
  and Mail & Alts are one card); it has no switch, and its id still finds the shared card. A card's
  `watch = { store, ... }` draws it again when another module's settings change too. A card's
  or row's `search = "..."` adds words the settings
  search finds but nothing shows, for clicks and slash commands too small for its help. The page
  in the options window, its search entries, the dot on what you changed and each card's reset
  all come from that one declaration. Settings pages hold settings only: a module's lists and
  editors live in its own window, opened from the page's `page:Window{ ... }` card (first on
  the page, or where its `order` puts it). A card that
  shows something on screen can carry a live preview (`studio`, see `Settings/Studio.lua`; its
  `height` a number, or a function for a stage that changes with a setting),
  drawn by the module's own drawing code on plain frames, never on its real (secure) frames.
  `Settings.EditZone(parent, opts)` (`Settings/EditZone.lua`) makes part of a preview editable, every option optional:
  `click(zone)`, `menu(owner, root)` (the house context menu on right-click), `wheel(zone, delta)`,
  `drag = { get, set, live, range, axis, factor }` (a drag along `axis`, "x" by default, snapped to
  `range` `{ low, high, step }` with `Settings.Snap`, drawn through `live` and saved through `set`
  on release), and a hover mark: `wash` (a faint fill) or `edge` (an accent line down its middle).
  Nothing runs per frame except while dragging. The Campfire's Simple bar preview uses it.
- **A window:** `Parts.Window`, `Parts.TitleBar`, `Parts.BarButton`,
  `Parts.Logo` (the title bar's logo alone, opening a settings page), `Parts.FooterBrand`, `Parts.Resizable(window, sizeKey, minW, minH, onSized, onReleased)` (a corner
  grip; the size is kept; `onSized` and `onReleased`, run as the grip is let go, are optional). See
  `NaowhForever_BiS/BiS/UI/Window.lua` for a short one.
- **A tracker:** `Parts.TrackerPanel(title, opts)` builds a tracker's window once, on first
  use: the window look, the title (click and drag), a scrolling body, a cog, its place kept.
  Every option is optional:

  | Option | What it adds |
  | --- | --- |
  | `width` | starting width (`TRACKER_W`) |
  | `titleRoom` | room left of the close button for your own buttons |
  | `onTitle`, `titleTip`, `titleHint` | a click on the title, and its tooltip |
  | `onClose` | the close button's click, in place of hiding it |
  | `bar` | a progress bar under the title: `panel.bar`, with `bar.bg` (`TRACKER_BAR_RGB`) and `bar.text` |
  | `picker = { values, order, get, set, menuHeight }` | a dropdown under the title or bar: `panel.picker` |
  | `newBody(scroll)` | what scrolls in the body (a row engine view); else a plain frame for `panel:SetRows` |
  | `settings = { page, card, tip, hint }` | the cog in the bottom right, opening that settings page and card |
  | `opacity()` | its opacity, for `panel:Paint()` |
  | `load()`, `save(point, relativePoint, x, y)`, `place` | its place: read, saved on drag, and the default `{ point, relativePoint, x, y }` |
  | `mover(panel, onMoved)` | Unlock Mode's mover: return `ns.UI.AttachMover(panel, label, onMoved, page)`; it saves through `save` |
  | `maxHeight()` | taller than this, its body scrolls |

  The panel has `panel:Paint()`, `panel:Place()`, `panel:SetTrackerWidth(w)`,
  `panel:Fit(bodyHeight)` (true when it starts or stops scrolling: set its width again and
  redraw), `panel:ScrollGap()`, `panel:Top()` and `panel:SetRows(entries)`: pooled rows of
  `{ text, sub, color, done, waypoint(entry), tip(row), click(row, button) }`, a pin column (a
  tick once done), the text in `color` (`T.fg` when nil), returning their height. Keep the
  entries and refill them, with shared functions that read the entry, and a redraw makes no
  garbage. See `NaowhForever_DungeonJournal/UI/QuestTracker.lua`, and the Discovery trackers for `bar`,
  `SetRows` and `mover`.
- **A HUD panel:** an on-screen bar or pill uses the windows' own backdrop, `Parts.Backdrop(frame)`
  painted at `Style.BACKDROP_ALPHA` (near opaque, so the world does not tint it), with the 1px black
  edge (`Style.BORDER_RGB`). The Campfire's Simple bar is one: its words are panel text (no HUD
  shadow), an amount in the text colour before its muted stat, and the accent only on a key word.
- **A timer line:** `Parts.TimerLine(parent, height, text)` is a thin StatusBar the client runs
  down by itself (`SetTimerDuration`), so no Lua runs while it counts: a full-width track in the
  theme's line color, a fill in a gradient into its color, and a soft glow where the fill ends.
  Give it a FontString as `text` (optional) and the time left is written into it the same way,
  short (`35s`, `42m`, `1h`: `Parts.ShortTime(prefix)`, one formatter per prefix, made once).
  `line:Run(start, duration, prefix)` starts it (`prefix` optional, e.g. `"in "`), `line:Stop()`
  empties it, and `line:Paint(color, textColor)` colors the fill and the glow, and the text in
  `textColor` when given, else in `color`. The Campfire's Simple bar uses it, in
  `Style.TIME_OK_RGB`, `TIME_LOW_RGB` and `TIME_OUT_RGB` (plenty, running low, nearly out).
- **Labels in a row:** `Parts.LabelRow(parent, size, flags, color, opts)` (all but `parent` and
  `size` optional) makes a frame of pooled labels. `row:SetLabels(list, n, icons)` writes the first
  `n` strings of `list` and returns the widest; `row:Pack()` lines them up left to right and
  returns the width, `row:Spread(width)` centres each in an equal share of `width` instead;
  `row:SetColor(color)` and `row:SetTextSize(size)` restyle them. `opts`: `gap` (space between
  labels as they are packed), `separator` (text between labels, e.g. `Style.PLACE_DOT`) in
  `separatorColor` (muted by default), and an item icon before each label (`Parts.ItemIcon`, the
  house edge) sized `icon`, or `iconGrow` more than the text, `iconGap` from it and `iconDrop`
  lower; `icons[i]` is its texture, false for none. Anchor the row by its left edge.
  Refilling it with the same strings makes no garbage.
- **Minimap pins:** `Parts.MinimapLayer({ max, new, paint, xy })` keeps up to `max` pins on the minimap
  for the spots of one world map. `new(i)` makes pin `i` (a frame on `Minimap`), `paint(pin, spots, i)`
  fills it for spot `i`, and `xy(spots, i)` gives spot `i`'s place on the map from 0 to 1, so the spots
  can be any list, flat or not. `layer:Set(mapID, spots, count)` shows a map's spots (nil to clear),
  `layer:Repaint()` paints every pin again. It moves the pins only while you move or the minimap turns,
  and looks only at the spots within twice the minimap's view, gathered again every `REFRESH_YARDS`.
- **A price to type:** `Parts.MoneyBox(parent, onChange)` makes three number boxes, gold, silver and
  copper, each with its coin; Tab and Shift-Tab move between them. `money:SetAmount(copper)` fills them,
  `money:GetAmount()` reads them back in copper (silver and copper over 99 count as 99),
  `money:ShowCopper(shown)` hides the copper box where the auction house takes silver only, and
  `money:HasFocus()` says whether one is being typed in, so a redraw leaves it alone.
  `onChange(money, copper)` runs only for what the player types.
- **Copying:** `Parts.CopyWowhead(kind, id, name)` opens the copy card on an item, quest or
  NPC's Wowhead link; a menu's Copy uses `ns.ShowCopyLine(title, text, icon)` (`CopyCard.lua`)
  for any line. `ns.ShowCopyCard(kind, label, id, title, mode, onClose)` opens the ID card itself.
- **Text on the game world:** `Parts.HudText(fontString, shadow)` gives a HUD line (the XP
  Ticker, an alert) the house look: no outline, a soft drop shadow (`HUD_SHADOW_RGB`,
  `HUD_SHADOW_ALPHA`, `HUD_SHADOW_X`, `HUD_SHADOW_Y` in `Style.lua`). Pass `shadow` false to
  take it off, for text a player chose to outline, or a background mode (`"soft"`, `"none"`) for
  the stronger shadow text needs over the world (`HUD_SOFT_SHADOW_ALPHA`, `HUD_BARE_SHADOW_*`).
  It returns the font string. A HUD card (the Flight Timer, the XP Ticker) puts it on the theme's
  background at `HUD_CARD_ALPHA` with the 1px black border, so the text needs no outline; its
  icons are `PLAY`, `PAUSE` and `RESET`.
- **A HUD card's background:** `Parts.HudBackdrop(frame, opts)` gives a HUD card the background a
  player picks: `backdrop:SetMode(mode)` with `"card"`, `"soft"` or `"none"` (anything else is
  `"card"`) returns the mode, and the same one again does nothing. Card is the theme's background
  at `HUD_CARD_ALPHA` with the 1px black edge (`backdrop.fill`, `backdrop.border`). Soft has no
  edge: a fade in the theme's background, `HUD_SOFT_ALPHA` behind the text and clear
  `HUD_SOFT_FADE` further out, `HUD_SOFT_INSET` of it inside the frame. It is nine pieces of one
  round texture (`Style.SOFT_SHADE`, from `Tools/media/make_media.py`), so its corners are round and no
  edge shows, made the first time Soft is picked (`backdrop.soft`). None shows nothing. `opts`, all
  optional: `alpha` (the card's fill), `color` (`T.bg`), `softAlpha`, `fade`, `inset` and `mode`.
  Pass the mode to `Parts.HudText` for each line on it; the choice row's values are
  `Parts.HUD_BACKGROUNDS`. The XP Ticker and Bag Space use it.
- **A HUD element's look:** every on-screen element offers the same Text, Bar and Background rows,
  declared with `Settings.Look(prefix, opts)` as one entry of a card's `rows` (a card takes a list
  of rows in place). Its keys are `<prefix>Font`, `<prefix>FontSize`, `<prefix>Outline`,
  `<prefix>Texture`, and `<prefix>Background` (card/soft/none) or `<prefix>BgAlpha`; with the
  prefix `""` they are `font`, `fontSize` and so on. `opts`: `text`, `size` (the font size
  slider's range), `bar` (the name the element's own texture shows under), `background` (`"card"`
  or `"alpha"`), `needs` and `why` for every row, and `keys`, which maps a suffix to a key the
  element already saves under (`{ FontSize = "textSize" }`) or to false to leave the row out. The
  defaults stay in the module's `UI.ModuleSettings`, at today's look (`outline = "OUTLINE"` for
  outlined text, `""` for the rest). To draw it, `Parts.HudFont(fs, font, size, outline,
  background)` sets the font (a SharedMedia name, `""` for the Addon Font), size and outline (one
  of `Parts.HUD_OUTLINES`: `"NONE"` plain text, `""` Shadow, `"OUTLINE"`, `"THICKOUTLINE"`, `"OUTLINE, SLUG"`) and gives
  Shadow the HUD shadow for its `background` mode. Text set by hand takes its flags from
  `Parts.HudFlags(outline)`, never the raw choice: the game rejects `"NONE"` as a font flag.
  A bar's texture is `ns.UI.TexturePath(name, own)`: the
  SharedMedia statusbar, or `own` for `""` and anything missing. A row of its own uses the
  `texture` kind, `{ key = "texture", label = "Bar Texture", texture = "Flat" }`, which lists
  `ns.UI.TextureChoices`. The Swing Timer and Threat Meter use it.
- **A window's shadow:** `Parts.Shadow(frame, size, alpha)` puts a soft drop shadow round a
  window, outside it only, so a see-through window shows none of it: Soft's pieces without the
  middle, in black from `alpha` (`SHADOW_ALPHA`) at the edge to clear `size` (`SHADOW_SIZE`) out.
  It returns the textures. The options window uses it.
- **A progress line:** `Parts.ProgressLine(parent, height)` is a thin line that holds still (the
  XP Ticker's level progress): a track in the theme's line color, a fill in a gradient into its
  color, and a fainter segment ahead of the fill (rested XP). `line:SetProgress(value, ahead)`
  takes shares of the whole (0 to 1), and `line:Paint(color, aheadColor)` colors them. Anchor it
  where it goes; it sizes with its anchors, so a card that grows needs no redraw. `line.track` is
  the track, hidden where no card is behind it.
- **Played time:** `ns.Shared.Played`. `Played.Want(key)` (one key per module) listens and asks
  for /played once, with the chat print muted for that request only; `Played.Drop(key)` stops
  listening once nobody wants it. `Played.Total()` and `Played.Level()` are the running seconds, nil
  before the answer; a ding starts the level's time again. Hook `Played.Answered(total, level)` and
  `Played.LeveledUp(level, total)` with `hooksecurefunc` to hear the answer and each ding. A /played
  the player types updates it too. The XP Bar and XP per Hour use it.
- **Forever's mark:** `Parts.IsForever(kind, id)` says whether it is new in Forever: an item or
  quest in Forever's own tables and not Classic Era's, an NPC Wowhead has as new (`Data/Forever.lua`,
  generated by `Tools/build/forever_new.py`; do not edit by hand).

## The rule: always use these

Every module builds its UI from these components and the `ns.UI` widgets, never its own copy.

- **It exists:** use it as it is.
- **It almost fits:** make it more flexible. Add an optional input (a parameter or an options
  field) that leaves every current caller working as before, rather than copying it.
- **Nothing fits:** add a new component here, list it above, and use it from your module.
  Anything another module could want belongs here, not inside one module.

Colors and sizes come from `ns.THEME` and `Style.lua`, never written as numbers in a module.

## Why

- A toast is drawn like the game's own level-up banner, in the accent: no window, a band whose fill and lines
  fade to both sides, the line small over the title. It shows in the same place as the game's banner
  (EventToastManagerFrame), so a toast waits for that to close, and for any other toast shown, then takes its
  place. A toast turned off while it waits is skipped and the next one in line shows. Training's Level-Up Toast keeps its own window and is not one of these.
- `ConsumableLevelAllowed` checks the fifth `C_Item.GetItemInfo` return (minimum level), not item level. Unknown or secret requirements are skipped until item data is available. Food and drink keep their existing ranking among eligible items.
- Forever's cooked food, fish included, casts Nutritious Food, and its teas and smoothies Nutritious Drink: a spell that starts a Food or Drink and adds Well Fed. `BestFoodAndDrink` and `ns.IsDrink` match those names as well as Food and Drink, read from one spell of each (`NUTRITIOUS_FOOD` is Brilliant Smallfish's, `NUTRITIOUS_DRINK` Peace Tea's), so a new cooked item counts without a list. They rank a quarter level under food and drink of their own required level (`NUTRITIOUS_PENALTY`): over a lower level, never over the same one. Plain food of the same level is still eaten first, as before they counted, and buff food is kept.
- `ns.FOOD_SPELLS` is every food use spell that adds a Well Fed, and `ns.WELL_FED` those Well Fed auras, from
  the Item, ItemEffect and SpellEffect tables (wago.tools build 1.60.1.70862). The teas and smoothies are drinks
  and left out, and so are the food spells of items Forever does not have (no ItemSparse row).
- Two off-hand tankards, Lapidis Tankard of Tidesippe and Bael'dun Tankard, have a use spell named Drink, and using one from the bags equips it. `BestFoodAndDrink` skips anything that can be equipped (`C_Item.IsEquippableItem`), so a tankard carried in the bags is never the best drink.
- Raw Sagefish and Raw Greater Sagefish (Brain Food, a Food and mana) are left out of `FOOD_AND_DRINK`: they restore less than food and drink of a lower required level, and they are cooking reagents.
- Some items restore health and mana in one (`FOOD_AND_DRINK`, `ns.IsFoodAndDrink`): the Enriched Manna Biscuit casts a spell of its own that starts a Food and a Drink, others restore both in one spell, and a few Food spells restore mana too, so their spell name does not say it and they are known by ID. That is every such item in Forever's tables but the battleground rations, which work only in their battleground (SpellCastingRequirements). `BestFoodAndDrink` offers each as food and as drink, and for a class that uses mana half a level above its required level: over food and drink of its own level, never over a higher level or a conjured one. `ns.IsDrink` stays false for them, so a warrior or rogue still gets them as food.


What a comment in the code used to say, in short. The house rules behind it are in
[CONTRIBUTING.md](../.github/CONTRIBUTING.md) and [STYLE.md](../.github/STYLE.md).

### Loading and saved data

- Nothing is made, hooked or listened to at load: a module builds what it uses the first time
  it shows it, so Shared costs nothing for a feature that is off.
- `Shared.CharacterData` keys a character's data by its GUID: first names are not unique on
  Forever, so a name key collides. It returns nil before the game knows who you are.
- `Shared.ScalePin` is a map pin's `ApplyCurrentScale`. Pins sit on the map's canvas, which the
  map scales to fit and to zoom, so the pin's scale is `PIN_SCALE` (1.5) over the canvas scale:
  the same size on screen at every zoom. The map's global pin scale still applies. An optional
  `factor` sizes one kind of pin against the rest, so that `PIN_SIZE_DEFAULT` (20) is the right size for each
  and one Pin Size number means the same on every kind (town 0.5625, quests, library books and Sleeping Bag steps 0.5, rares 0.75).
  On the full screen map pins are `FULL_SCREEN_PIN_SCALE` (1.5) times that: the same size on screen
  as in the small map's window read as too small on a map that fills the screen.
- `Shared.PinClicks` is called by every clickable map pin as it is placed. While Ctrl is held
  the pins take no mouse at all, so a Ctrl+Click on a pin goes to the map itself and places or
  removes the game's waypoint there. The map removes its waypoint only when the mouse is over
  the waypoint's own pin, so a pin beneath it that still took the mouse (even only for its
  tooltip) made the map place a new waypoint instead, and a waypoint on a dungeon entrance or a
  rare could not be removed. The click is passed by the game, never by addon code: clearing the
  waypoint from addon code while the map is open would taint its pin. The pins' tooltips are
  gone while Ctrl is held.
- `Shared.MapPins` is a plain list, filled at load by the modules that have map pins and read
  only when QoL's Map Options or Map Pins card is drawn, so the load order of the addons does not matter.
  A section is `{ title, order, store, switch, rows, map }`: `map` puts it on the Map Options card instead of Map Pins, `switch` is its own on and off key in `store`, `order` (default 50, after the lower ones, then by load order) where it comes, and `title` its group, none to continue the one above.
- A settings row marked `lent` belongs to another module's store: its card's Reset and changed
  count leave it out, while its own changed dot still resets it.
- `Decode.lua` loads with nothing else from the addon and returns its table, so the offline
  tests can load it on its own.

### The look (`Style.lua`)

- A name ends in what it holds: `_CODE` is a color escape (`"|cffb06bff"`), `_RGB` a `{ r, g, b }`
  table (0 to 1). Sizes are pixels at the addon's UI scale.
- The theme's own colors (`T.fg`, `T.muted`, `T.accent`) come from the theme, read when a row
  is made, so a theme change shows after a `/reload`.
- Naowh's house style is a 1px black edge round cards, badges, chips, icons, buttons and
  panels; the accent (Naowh blue) marks what is picked.
- Your BiS is legendary orange so it stands apart from blue item names, your second pick
  silver and your third copper (`THIRD_RGB`, a0522d): the usual bronze, cd7f32, is too close to the BiS
  orange on a tooltip-sized star. Picks past the third show their number. New looks are cyan, clear
  of the BiS orange for color-blind eyes too.
- `PICKED_RGB` (a boss picked on a dungeon map) is the game's quest gold until the player picks
  an Accent of their own. `GUIDE_RGB` (the HUD Editor's guides) is amber so it never reads as
  the accent's selection.
- The addon's own icons in `Core/Media/` are white, so they take any color; `Tools/media/make_media.py`
  draws them. `ROUND` is 128px: load it "TRILINEAR" or it is jagged small. `FOREVER` is 32 by 16;
  `ELBOW` is 8 by 8 and drawn at that size.
- HUD text without the card: Soft fades from `HUD_SOFT_ALPHA` behind the text to clear over
  `HUD_SOFT_FADE`, `HUD_SOFT_INSET` of it inside the card's edge, its text shadow at full
  strength. None has no backdrop: the shadow at full strength and as close (1px), since 2px
  doubles small text.
- `TRACKER_BAR_RGB` is behind a tracker's bar until the player changes the theme's panel color.
- `TEXT_SIZE` (12) and `SMALL_SIZE` (11) are the house text sizes: body text, and muted notes.
- `OPEN_TURN` is the quarter turn of a chevron on an open section or card head. It is written
  with `PI`, not `math.pi`: the offline tests load `Style.lua` without the math library.
- The slider ranges every module shares live here: `OPACITY_RANGE` (a window's opacity, from
  `OPACITY_MIN`), `ALPHA_RANGE` (a HUD part's opacity, down to 0), `SCALE_RANGE`,
  `PIN_SIZE_RANGE` (a map pin, `PIN_SIZE_DEFAULT` the default every pin size shares) and `HUD_TEXT_RANGE` (a HUD part's text size in `Settings.Look`).
  `PERCENT_SCALE` turns a percent slider into the 0 to 1 the setting saves.
- `STAGE_MARGIN`, `STAGE_NOTE_Y` and `STAGE_NOTE_SIZE` place a settings card's live preview and
  the muted note under it.
- `ICON_CROP` (and `ICON_CROP_HIGH`) trims the game's border off an icon. `CLASS_CROP` trims a
  class icon cut from `CLASS_ICONS` (`Parts.ClassCrop`). `TIP_TITLE_RGB` is a tooltip's first line.
- `Style.lua` writes the core's media path out rather than reading `ns.MEDIA`: the offline
  tests load it without `Core/Core.lua`.

### Items and gear

- `Items.KEPT_CODE` is the worn green at 200 of 255 (`KEPT_SHADE`): where you keep an item is a
  state of it, quieter than its name.
- `Items.SLEEPING_BAG` is the Cozy Sleeping Bag's one item ID: Discovery's chain gives it and the
  Campfire reminder offers it, two addons that may load without each other.
- Your loot lines are found by the start of the game's own line (`LOOT_ITEM_SELF`,
  `LOOT_ITEM_PUSHED_SELF`, up to its first `%s`), so it works in any client language. A secret
  line (in an encounter) is nobody's: `issecretvalue` is checked before anything else.
- `Items.OnLoaded` runs its function at most once a frame as the items load. An item the server
  fails to load never calls back, so a ContinuableContainer over them would never finish; an
  item already loaded is not waited on.
- As in classic, mail and plate are learned at level 40 (`HEAVY_ARMOR_LEVEL`): below it a
  hunter, shaman, warrior or paladin wears the lighter armor.
- Weapons in short go by the game's weapon subclass (`Enum.ItemWeaponSubclass`), so any client
  language gets them; one that only goes in one hand says which ("MH Sword", "OH Dagger").
- `Items.ClassCanUse` reads an item's facts as `ItemFacts` holds them: `{ class, subclass, item
  level, required level, quality }`, class 2 a weapon, subclass 0 no armor type, 6 a shield.
- `Items.SlotsFor` returns shared tables: read them, never change them.
- `Items.SlotName` names a slot in the player's language. The cloak slot's catalog key is
  "Back (slot)", because "Back" alone is also the Back button; `enUS.lua` gives it its English
  text.

### Bags, tooltips, maps and /played

- Bag marks hook each bag frame's `UpdateItems` with `hooksecurefunc`, never `SetScript`, and
  only once a module first asks. EllesmereUI's bags are painted through the
  `RegisterItemOverlayIcon` hook it offers other addons. `Bags.Baganator` hands back Baganator's
  public `Baganator.API` when it is loaded; a module registers its own corner widget there.
- The guild list's tooltip is GameTooltip, so our lines go on it. The Friends list's tooltip has
  fixed lines, so ours is a tooltip of our own `TIP_GAP` under it, which hides itself as soon as
  the Friends tooltip stops showing that row. List rows are hooked with `HookScript`, after the
  game's own, once each. A GUID is used only when it is a readable string, never a secret value.
- Under Forever's Gamepad interface style (`ns.GamepadStandDown()`) the game's bags and the Friends
  and Guild lists are left alone: `Bags.OnGameUpdate` hooks no bag frame and `Roster.AddTooltip`
  hooks no list, so Bag Marks, Junk Marker, the badges and Naowh Score add nothing there.
  EllesmereUI's and Baganator's bags still get their marks. That style navigates these windows
  from secure code, which our hooks and tooltip lines would taint.
- `Places.ShowMap` opens the world map only out of combat, where addon code may open it. While
  `ns.GamepadOwnsPanels()` it says so in chat instead: `C_Map.OpenWorldMap` runs the game's
  `ShowUIPanel` from our click, and the gamepad builds its bindings inside that, which is how the
  Map Window tainted them. Every "show on the map" in the addon goes through it.
- Forever has Zephras Isle twice: map 2521 (under Azeroth) and map 2665 (no parent), with the
  same name, continent (2991) and bounds in the game's UiMapAssignment, so a map percentage is
  the same spot on both; the game puts players on 2665 too (the Nightclaw Druids' Wowhead data
  lists both). The addon's map data is keyed by 2521, so a lookup by the player's or the world
  map's ID goes through `Places.SameMap`, which turns 2665 into 2521. The player's position is
  still read on the game's own ID; the Flight Point Reminder asks for 2521's flight points.
  Unexplored Areas does not alias: 2665 has its own map art, which 2521's
  overlays do not fit. `Tools/build/same_maps.py` finds such pairs in the game's tables, so a
  new one is caught when the build moves on.
- /played is asked for with `TIME_PLAYED_MSG` unregistered from the chat frames for our request
  only. They get it back on the next frame after the answer, so they do not print it, or after
  `MUTE_LIMIT` seconds if no answer comes. A ding starts the level's time again; a /played the
  player types updates it too.

### Parts

- How much lower an icon in text sits, level with the letters: a tooltip's lines need 1
  (`TOOLTIP_DROP`); on a card the Naowh font's capitals fill the middle of the line, so 0
  (`CARD_DROP`). Measured in game, 2 Oct 2026.
- `Parts.Smooth`: a texture drawn smaller than its file stays smooth when it is mipmapped
  ("TRILINEAR", for the addon's own) and never snapped to whole screen pixels, which makes a
  scaled icon's edges step. A text icon (`|T|t`) cannot be smoothed: draw those near their size.
- `Parts.Tip` shows nothing while a menu is open, so moving the mouse from a menu's owner over
  other rows to reach it does not cover the menu with their cards.
- An action on a page is a link, not a box, so the page reads as content; boxes are for a
  window's controls. A link's chevron sits out by its own margin (`LINK_ARROW_OUT`), so its
  point lines up with the text above. A disabled link rests muted and says why on hover.
- An icon button's `margin` is the empty edge on the right of its image: it moves out by it, so
  the shapes, not their boxes, line up.
- The game cannot put text on the clipboard for an addon, so copying opens a copy card with the
  text selected (`Parts.CopyWowhead`, `ns.ShowCopyLine`).
- An item's marks are the same wherever one is drawn (the BiS List's paperdoll, the character
  panel, your bags): item level bottom right, your BiS's star bottom left, Forever's mark top
  left, the game's green upgrade arrow top right, over a shade rising from the foot
  (`SHADE_SHARE` of the icon tall, `SHADE_ALPHA` dark) so the numbers read on any icon's art.
- `MARK_STAR_DROP` is -1: the star 1px over the line's middle sits level with the outlined
  digits across the icon; 2px left it high beside a two-digit level (7 Oct 2026).
- Forever's mark on an icon is `FOREVER_SHARE` of the icon tall, never under `FOREVER_MIN`, with
  no box: its own dark outline keeps it readable on the icon's art.
- The addon's lines in an item's tooltip are one fact each in one look (the mark, the words in
  its color, then after a dot, muted, whose it is), all from the same makers, so the same fact
  never reads two ways, or twice.
- Text that is drawn again and again (counts, ranks, coins, plain lines, Forever marks) is made
  once per value and kept, so a redraw makes no garbage. Coins keep at most `COINS_KEPT`.
- A where line is shown plain: its color codes pull the eye off the titles, and the dash between
  place and person reads as a dot.
- `Parts.Cells`: the Naowh font's digits are not all as wide, so each character gets a cell as
  wide as the widest digit ("-" and "/" narrower), measured once per size.

### HUD, timers and panels

- HUD text has no outline and a soft drop shadow; the Shadow outline gets the HUD shadow for its
  background mode, and a player's own outline gets none.
- Soft is nine pieces of one round texture (`SOFT_SHADE`), so its corners are round and no edge
  shows; they are made the first time Soft is picked. `Parts.Shadow` uses the same pieces without
  the middle, outside the window only, so a see-through window shows none of it.
- A timer line is run down by the client (`SetTimerDuration`) and its time written by a duration
  text binding, so no Lua runs while it counts. The game formats the time, since it can be
  secret. Without those APIs it shows a still bar.
- Short times count seconds up to 90, then minutes up to 90, then hours, each rounded up so a
  time never reads less than is left.
- `Parts.StopTimer`: `SetValue` does not repaint a bar its timer owns, but a duration that has
  already run out (`STOP_AGO` seconds long, started that long ago) leaves it still.
- A window's backdrop paints its opacity into the colors, not with SetAlpha: a texture's alpha
  does not reach a gradient's colors.
- A side panel opens beside the window it was opened from, on whichever side has room, closes
  with it (a `HookScript` on our own window), and opening one closes the others. Its buttons
  share its width with a count of at least 1: the game's Lua stops on a division by zero.
- Sharing never goes through the chat box: opening it from addon code taints it, and the game
  then blocks the next message you send. Say is offered only inside an instance, the one place
  the game lets an addon speak; a dungeon finder group's chat is the instance's.

### Item bars (`UI/ItemBar.lua`, `UI/Anchor.lua`, `Game/ActionKeys.lua`)

- A weapon item (a poison, stone or oil) used on its own only asks which item to put it on, so
  `ItemBar.SetWeapon` makes the button a macro that uses it and then that weapon slot: the left click
  on the slot given (the main hand by default), the right click on the other hand. `ItemBar.SetItem`
  turns a button back into a plain item.
- `ActionKeys.Text` writes a mouse button as its modifiers' letters and M with its number (SM5), as
  action bar addons show it: the game's short text still spells out "s-Mouse Button 5". Every other key
  keeps the game's short text.
- A bar's icons are cropped (`ItemBar.CropIcon`, `Style.ICON_CROP`) like the addon's other item
  icons, cutting off the rounded border the game draws into the item art. A rectangular button
  (`ItemBar.Shape`) crops its art further along its longer side, so the art keeps its shape.
- `ItemBar.Place` and `ItemBar.Size` take an optional icon height (square without one) and
  `Place` an optional flip that starts each new row on the other side of the first; a bar that
  passes neither lays out as it always has.
- A bar's settings share one prefix (`consumableBar`, `foodBar`): its count and key text, its
  anchor and where it was dragged are `<prefix>Font`, `<prefix>Anchor`, `<prefix>Pos` and so on, so
  one set of rows and one placement serve every bar.
- A bar anchors to a unit frame here (a secure unit button, moved only out of combat like the bar's
  own buttons), never to itself or its icons. Another addon's frame could move in combat, and the
  bar's secure buttons on it would block that. A name that is no such frame puts the bar back where
  it was dragged.
- To follow another Naowh Forever element, a bar uses the HUD Editor's own Anchor (`UI.PickAnchorFor`
  starts it from the bar's settings), so there is one way to tie elements together. Picking a unit
  frame drops that anchor (`UI.DropAnchor`); the HUD Editor moving the bar saves a screen position,
  which drops the unit frame. Only one of the two ever places a bar.
- A key comes from a button's own text, or from the binding behind it when a bar draws its own
  text (Blizzard's command, EllesmereUI's `binding` attribute, or a CLICK binding on its name).
  EllesmereUI takes its buttons off `ActionBarButtonEventsFrame`, so they are found by name.

### Windows

- A window is made hidden: a frame is made shown, and `Show()` on a shown frame runs no OnShow;
  hidden, the first open runs it too, and takes the link back to the window it was opened from.
- A window takes the keyboard only out of combat, where that is allowed, and passes on every key
  but Esc.
- A window's size grip keeps its size account-wide under its `sizeKey`, as the options window's
  is; its place is kept account-wide under `positionKey`.
- The title bar's subtitle is one line, cut short `BAR_GAP` before the close button: the header
  has room for one line, and a long one ran under the close button and out of the window. A window
  that puts its own buttons left of the close button anchors the subtitle's right edge to the
  left-most of them, as the Shopping List does.
- A switch's hairlines are made once, when made: its parts are laid out again on a change.
- A module's settings card holds itself in its button's click, made once: `ns.Button` calls its
  click with no arguments.

### The row engine and settings

- A row is sized as it is placed, not only anchored, so wrapped text measures at the right
  width; its top is kept to scroll to it. The view's height is set as it draws, so the furthest
  it can scroll is known before the layout.
- A burst of events makes one redraw (`REDRAW_DELAY`), and none while the view is hidden. An item
  the server refuses (`GET_ITEM_INFO_RECEIVED` with success false) is not waited on again.
- A redraw reuses the row a tooltip belongs to, so it hides the view's own tooltip. The tooltip
  can be on a Blizzard frame the game forbids touching in combat (a nameplate aura): the walk
  stops there, and none of a view's own rows is ever forbidden.
- A card's edge is reset when it is opened: a card last used for a picked one has the accent's.
  An empty card's note stays centered under its header when the grid stretches it.
- A view whose rows sit on bands insets their text (`view.inset`); its section titles line up.
  A section's link passes itself, for a window to open beside what was clicked.
- A settings row with `field` is one entry of a table setting: its dot and reset are that
  entry's own. A number counts as unchanged within `SAME_WITHIN`, so a value saved back through
  a slider or color picker still reads as the default.
- A card starts folded unless it says `open = true` (Damage Meter, Glimmer and Top Bar), so a tab
  opens showing its sections, not one long card. A card someone opened or folded stays so for the
  session. A search holds a card open, so its head does not fold it.
- A hidden row is set on the card's preview instead; it is still searched, counted and reset. A
  search match on a hidden row shows the card whole, and part of a card shows no reset, which
  would reset what is left out too.
- The Naowh skin uses solid charcoal surfaces and outlined settings cards. Windows and side
  panels paint one background color at both ends of their backdrop; the optional Forever
  skin and its onboarding preview keep their stone and shading. Settings cards reuse the
  row engine's pooled card frame, with the theme's line color around each section. Their
  heights follow the visible rows, including folded and filtered cards.
- Naowh settings have dividers at category boundaries rather than between related rows.
  Paired controls keep a center divider; an unpaired control has none. Open card headings
  and group titles keep their rules. The optional Forever skin keeps its center divider but, as
  Naowh, no line under each row. Its divider runs the row's full height, so a pair's line meets the
  heading's above it; inset, it left a gap once the row lines were gone.
- The sidebar is shaded by `SIDEBAR_SHADE`, and preview stages by `PREVIEW_SHADE`, over the
  chosen background so custom palettes retain their colors. Both are flat fills.
- Naowh tabs share a recessed rail, a filled accent selection with a complete outline and a
  small diamond. A label sits in the middle of its tab, and the picked one moves right by half
  the diamond's room so the diamond and label are centered together. Every tab's width still
  holds that room, so picking one never resizes the strip.
  `Parts.Tabs` keeps its sixth `plain` input for callers; all Naowh strips use the same segments,
  including preview states and module windows. The Forever skin keeps its own art and fitting.
- Tab labels shorten only when their strip has no room, and show the full label on hover.
  Changing the tab list repaints reused buttons so a previous selection cannot stay lit.
- `Settings.Reset` and `Settings.ResetRow` retain one session-only undo, exposed through
  `CanUndoReset(card)` and `UndoReset(card)`. Undo copies raw values back through each store,
  once per key. A different profile or a subsequent edit to any affected key invalidates it.
- `Settings.Dependency(row)` resolves declared dependencies to their controlling row or card;
  computed conditions keep their explanation without a guessed destination.
- A slider being dragged holds the settings redraw until it is let go (`DRAG_WAIT`): the redraw
  hides and shows the rows, and hiding the slider ended its drag after one step. Visible studio
  previews repaint during that wait without rebuilding the slider.
- A preview is drawn by the module's own drawing code on plain frames, never on its real
  (secure) frames. An edit zone runs nothing per frame except while it is dragged.
- A row's icons (its cog first) are made once per declared row, so drawing them makes no tables.
  A cog whose settings were changed is tinted as a row's dot is.
- A cog opens one shared panel, drawn with the page's own row kinds, so its rows' dots, controls
  and help are the same. A redraw of the page puts it back under the cog. The page's rows hide for
  a moment on every redraw, so the panel closes only once the page itself is gone, a frame later.
- A setting EllesmereUI also has (`OVERLAPS` in `Settings/Ellesmere.lua`) asks the player to turn
  one of them off when both end up on: right after a toggle or card switch is clicked on here, or
  when EllesmereUI's window closes with one newly on there. Only a click asks, so a profile import
  or a setup never pops it. Turn Off Here turns ours off; EllesmereUI's settings are never written.
- EllesmereUI's toggles save straight to its tables with no event, so its side is checked when its
  window closes, against what was on when it opened. Its window is found through
  `EllesmereUI:GetMainFrame()` after its Show, Toggle or ShowModule, hooked by Core a second after
  login (`Settings.WatchEllesmere`), once every addon has loaded.
- EllesmereUI's saved settings are read where its own code reads them: `EllesmereUIDB`
  (account-wide, Forever Essentials' features in a table of their own) and the Quest Tracker's
  profile (`_EQT_DB`). A value it never saved reads as its default, as EllesmereUI does. Nothing is
  on there while the addon that runs the feature is off, or its table is not there. Auto-accept and
  hand-in read off while the Quest Tracker itself is off: they never run then.
- A settings view changed while hidden is marked stale and drawn again as it shows, so it never
  shows an old value (an options window that stepped aside for a picker, a page another changed).

### The Forever skin

- The skin is read once per load with the theme's colors, so every part asks it as it is made:
  `ns.Skin()` is `""` or `"forever"`, and `ns.foreverSkin` is true on Forever. A change takes a
  reload. It replaced the Classic+ skin, and the parts it kept from it keep their `CLASSIC_` names:
  the full-color icons (`CLASSIC_ICONS`, `Parts.ClassicIcon`), the Top Bar's highlight and the
  heading step.
- `Parts.ClassicIcon` answers false when the name has no icon or this client lacks its file, and
  the caller keeps its own glyph.
- It dresses the windows as WoW Forever's own (Talents, Spellbook, Character, Professions) and is
  built on their art. Every atlas is asked for with `C_Texture.GetAtlasInfo` first (once, then
  remembered), and a whole frame only through `NineSliceUtil` when all of its pieces exist; when one
  is missing the part is drawn from the `FOREVER_*` tokens in `Style.lua`, so nothing shows a missing
  texture. A file texture is checked by `SetTexture`'s answer the same way.
- Nothing is inherited from a Blizzard template: our frames take the art (`SetAtlas`,
  `NineSliceUtil.ApplyLayoutByName` on a frame of our own), so no Blizzard script or secure code runs.
- A window's frame is the game's portrait frame (`PortraitFrameTemplate`'s nine-slice) on a frame
  laid round the window: `FOREVER_TITLE_H` above it for the title bar, `FOREVER_SIDE` out on the
  other sides, so nothing inside the window moves. Its name is the addon's, in gold, centred on the
  bar; the Naowh logo sits in the portrait, which takes the old logo's click, and the window's own
  close button gives way to the game's red one. The title bar drags the window. Drawn, it is a rim of
  black, dark bronze, bronze, deep bronze and black with a ring round the portrait.
- The logo fills the portrait as the game's own portraits do (`PORTRAIT_ART.logo` of the disc: the
  logo's hexagon is as wide as its file, so its corners stay inside the ring), on a deep blue disc with
  a soft lighter middle (`FOREVER_PORTRAIT_GLOW_RGB`) and a dark edge under the ring (`St.RING`), so it
  sits in the ring instead of floating on a flat fill.
- The chrome sits `FOREVER_CHROME_LEVEL` over the window, under the size grip, so the metal edge is
  drawn over the content's edge as the game draws it.
- A window's backdrop is the game's rock (`UI-Background-Rock`), darkened (`FOREVER_ROCK_SHADE`) and
  partly see-through (`FOREVER_ROCK_ALPHA`), fading with the window's opacity.
- A picture of a Forever window on any skin (the onboarding's skin step) asks for it:
  `Parts.Backdrop(frame, true)` lays the rock, `backdrop:Paint(alpha, colors)` takes a palette other
  than the theme's, and `Parts.ForeverFrame(window, { preview })` leaves out the drag strip and keeps
  the close button off the mouse, so the picture neither moves nor closes.
- Every button is the game's one red button, the Friends list's Add Friend
  (`SharedButtonTemplate`, `Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml` on the
  `forever` branch): the `128-RedButton` three-slice (`128-RedButton-Left`, `_128-RedButton-Center`,
  `128-RedButton-Right`, each with `-Pressed` and `-Disabled`, and `128-RedButton-Highlight`), named as
  `ThreeSliceButtonMixin` names them (`ThreeSliceButtonTemplate.lua`), its ends scaled to the button's
  height and cropped when it is narrow, as the game's are. Gold text, white under the mouse, grey when
  disabled (`FOREVER_DISABLED_TEXT_RGB`, as `GameFontDisable`). There is no main-action variant: the
  game uses the one red button, so `ns.AccentBorder` leaves it as it is, and a picked button's colored
  edge still shows. Without the atlases it is drawn: a red gradient (`FOREVER_RED_RGB`, brighter under
  the mouse, grey when disabled) in a bronze rim. The onboarding's Forever preview uses the same art
  (`Parts.ForeverButtonArt`).
- A picked red button (one whose edge a module colors, as the Training Planner's class row) shows
  the button's pressed art with its highlight kept on (`LockHighlight`) instead of a colored edge,
  which read as a modern outline round a classic button.
- Tabs are the game's Settings window tabs (`MinimalTabTemplate`, `Blizzard_SharedXML/Shared/Tabs/
  MinimalTab.xml`): `Options_Tab_*` and, picked, `Options_Tab_Active_*`, at the art's own height on
  the tab's bottom edge, the label a little low on it (`FOREVER_TAB_TEXT_Y`). They replaced the
  panel tabs turned upside down, which needed a crop and offsets to sit on top. A preview's tabs
  (Normal, In Combat) sit on the preview's top edge, `FOREVER_TABS_IN` (Studio.lua) in from its right.
- A tab is measured as its label plus its art's two end caps (`capRoom`, at least two
  `FOREVER_TAB_PAD`): measured on the label alone, a long one ("Dungeons & Raids") ran past its caps.
- Forever tabs keep that width and sit side by side `FOREVER_TAB_GAP` apart, as the game's do, instead of
  stretching to fill the row. When the row is too narrow for them (Quality of Life's eleven), each
  gives up padding
  down to `FOREVER_TAB_TIGHT` a side, so every label stays whole where it can, then the widest are cut to one width with their label shortened, as the
  game's `PanelTemplates_ResizeTabsToFit` does; a cut tab shows its full label on hover.
- A settings card is only its list bar, the Friends list's category header ("Favorites 0/2"):
  `SocialUIScrollableHeaderTemplate` (`Blizzard_SocialUIShared/SocialUISharedTemplates.xml`) on
  `ListHeaderVisualTemplate` (`Blizzard_SharedXML/ListTemplates.xml`), whose bar is
  `common-button-list-collapseExpand`. It is `FOREVER_CARD_BAR_H` tall and `FOREVER_CARD_GAP` apart,
  with no card box round it: a bar inside a box read as boxes in boxes. Its title is gold, its summary
  right-aligned before the sign, and the sign is the header's collapse button: `common-button-list-plus`
  or `common-button-list-minus` at the atlas's own size (`CollapseButtonMixin`, `ListTemplates.lua`),
  centered `FOREVER_SIGN_RIGHT` in from the right, with the same atlas as its glow. Stretched to a square
  the slim minus read as a solid yellow block, so it never is. Its switch, a check box, sits at its
  left. Drawn, the bar is a lighter brown gradient in a thin rim with a gold `+` or `-`. An open
  card's rows lie right under its bar (`FOREVER_BODY_GAP` above and below them), and the page is as
  tall as its bars and open rows, so it reflows as a card opens or closes. A group (Clock, Buttons)
  is its name in the heading font over the game's Settings divider (`Parts.ForeverHeading`,
  `Options_HorizontalDivider`, a faint white line fading to the right), or a thick brown line
  (`FOREVER_HEADING_LINE`) without it: the title plaque it sat on before read as one more button.
  Settings rows have gold labels and no line under each, as on Naowh: a line under every row read
  as a busy table. On the Settings page a section that folds (Modules, Minimap Icons) is a list bar
  with the game's plus, as a card is, and a section that does not is a heading.
- A check box is the game's own beveled one (`UI-CheckBox-Up`, `-Down` and `-Highlight`, with
  `UI-CheckBox-Check`), `FOREVER_CHECK_SIZE` square everywhere, the card bars' switches too, so every
  box matches; its highlight lights it under the mouse. Without the file it is drawn: a dark
  `FOREVER_CHECK_DRAWN` box in the same square, the game's yellow tick a size up (`FOREVER_CHECK_SCALE`).
  A row that is off (its card switched off, or a setting it needs) keeps its box whole, as the game's
  disabled check button does (`UICheckButtonArtTemplate`, `Blizzard_SharedXML/Shared/Button/
  CheckButtonTemplates.xml`): `UI-CheckBox-Up` at `FOREVER_CHECK_DIM_ALPHA` and, ticked,
  `UI-CheckBox-Check-Disabled`; the label dims as before. Fading the whole box made it vanish.
- The help card is the game's help tip: its gradient in the window's frame rings. The metal frame's
  own art was tried twice and does not fit a small card: the whole layout's top edge is a title-bar
  strip that covered the first line, and its corner pieces are long bars that stuck out past the
  card's ends. And the talent frame's yellow pointer under it when it sits over what it explains
  (none at the cursor).
- A dropdown is the game's `WowStyle1DropdownTemplate` (`Blizzard_Menu/Mainline/
  MenuTemplates.xml`): `common-dropdown-textholder` laid `FOREVER_DROPDOWN_OUT` past the button on
  each side, as the template lays it (the art's shadow sits in that margin, and the atlas's own
  slice margins keep its ends whole when it stretches), with `common-dropdown-a-button` at its own
  size at the right (`FOREVER_DROPDOWN_ARROW_X`, `_Y`), lit (`-hover`) under the mouse. It has no
  edge of ours. Drawn, it is a dark field in a rim with a gold arrow plate and a faint white sheen
  under the mouse (`FOREVER_HOVER_SHEEN`).
- A slider is the game's Settings slider (`MinimalSliderTemplate`, `Blizzard_SharedXML/Shared/
  Slider/MinimalSlider.xml`): the `Minimal_SliderBar` groove and knob at their own size, with no
  fill, as the game's has none. Its knob glows faintly while the mouse is on the slider. The
  template's step arrows are left out: the number box beside it already sets an exact value. That
  box is the game's input box (`InputBoxTemplate`'s `common-search-border` art,
  `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`) at our box's own size. Drawn, the
  groove is a dark field with a bronze fill and the game's older knob, its groove sheened under the
  mouse.
- Text fields keep their edge under the mouse and while typing; the house skin's accent edge read as
  modern.
- A row of tabs in a module's own window has a rail under it, `FOREVER_TAB_RAIL_OUT` wider than the
  tabs on each side. The options window's section tabs have the full-width rail instead, and a
  preview's tabs (Normal, In Combat) sit on the preview's edge, so both pass `noRail`.
- The portrait's ring is the minimap's own frame (`FOREVER_RING_ATLAS`), sized so its inside
  (`FOREVER_RING_INNER` of the art, measured) meets the logo's disc, over the disc's shade. Drawn,
  it is the window lines' metal: a black edge, light gold, dark bronze and a black edge,
  `FOREVER_PORTRAIT_RING` across, whole so the frame's corner piece leaves no part of the logo bare.
- The options window is laid out as the game's Legacy Challenges window (`Parts.ForeverPanes`).
  Under the title bar a header band (`FOREVER_BAND_H`) holds the page's name and path, clear of the
  portrait, and Enable, HUD Editor and Reload UI at its right, so no strip is spent on two buttons.
  A rail (`Parts.ForeverRail`, `FOREVER_RAIL` of layout) closes the band off and runs down between
  the module list and the content. It is drawn in the outer border's metal, light gold to dark bronze
  across its width (`FOREVER_RAIL_RGB`, measured off the frame in game), so every line in the window
  matches the border. The frame's own edge art was tried: its metal sits off-centre in a wider
  picture, so it drew 20 pixels away from the line it stood for.
- The line above Settings is the same drawn metal (`Parts.ForeverRod`), from the frame to the side
  line, with the boss dragon (`FOREVER_DRAGON`) lying on it, made to sit on top of a bar; the
  module list scrolls `Forever.NavRoom()` past its last module, so the dragon never covers it.
  Forever's frame divider and the bank's rod were tried for these lines and looked worse in game
  than the drawn metal.
- Forever swaps an atlas for its `-c60` twin by name: asked for the quest tracker's header
  (`ui-questtracker-primary-objective-header`) it draws the plainer Forever one. And some
  Forever-only `-c60` atlases are not found by name from addon code at all (in game,
  `GetAtlasInfo` gave nil for the bronze frame), though the game draws them. So every part asks
  for its atlas first and, when that fails, draws the same picture from its file by ID and
  position (`FOREVER_ART_FILES`, read from the build's UiTextureAtlas tables), which no swap or
  lookup touches. The picked module's header is always drawn from its file (`FOREVER_PICK_ART`,
  the 2x art, 80 tall in its 1024x512 file), `h` tall so it is not squeezed into the 28px row, and
  cut at 548 of its 600px, where its fade ends, so its line runs the row's length as the group
  headers do.
- The file IDs and texture coordinates in `FOREVER_ART_FILES` and `FOREVER_PICK_ART` are pinned to
  build 70790 and nothing checks them in game: a client update that repacks a file in place draws
  the wrong crop, or nothing, rather than falling back. Read them again from each new build's
  UiTextureAtlas tables.
- The window wears the Journeys art (`FOREVER_WINDOW_ART`) over the rock and the header band the
  Legacy Challenges window's (`FOREVER_BAND_ART`), from its top. Both are cropped to cover, never
  stretched, and cropped again as the window is resized (`OnSizeChanged`).
- Its sidebar has no logo: the portrait ring is the brand. The search box sits at its top. Each group
  (Adventure, Combat, Utilities) is the game's Settings category header (`Parts.ForeverGroupBar`,
  `Options_CategoryHeader_1`, `Blizzard_Settings_Shared/Blizzard_CategoryList.lua`): a dark bar
  whose thin outline runs down past its first modules and fades. The art is `FOREVER_GROUP_ART.h`
  tall with its bar `FOREVER_GROUP_ART.bar` rows from `top`, and it is scaled so that bar is the
  group's row. Its name is in cream. Drawn, it is a list bar as light as a card's. The modules are
  plain gold text under it, as the game's Options list has them (`Parts.ForeverNavLine`): the picked
  one on the quest tracker's header and the one under the mouse on `Options_List_Hover`, stretched
  to the whole row: the art is 21 tall for the game's 20-tall rows, so at its own size it looked
  thin on our 28-tall ones. Drawn, the picked one sits
  between two gold lines that fade out at both ends, over a faint gold fill
  (`FOREVER_NAV_FILL_ALPHA`), and the one under the mouse gets the lines in grey
  (`FOREVER_NAV_HOVER_RGB`). Settings,
  Profiles, Patch Notes and Credits stay list bars, the picked one lit as the Achievement window's
  picked category: the bar tinted amber (`FOREVER_NAV_LIT_RGB`) under the quest log's gold highlight
  (`Parts.ForeverPick`), masked to the bar's own shape so it is no taller than the bar. The content is the frame's own rock, lighter in the middle
  (`FOREVER_LIGHT_ALPHA`), not a boxed inset, with its section tabs at its top on the same
  rail. A module's own window keeps its content in the game's inset frame.
- A slim scroll bar is the game's `MinimalScrollBar` (`Parts.ForeverScrollArrows`,
  `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml`): the `minimal-scrollbar-track-*` track,
  the three-piece `minimal-scrollbar-small-thumb-*` grip (`-over` under the mouse,
  `Parts.PaintForeverThumb`) and the `minimal-scrollbar-arrow-*` step arrows at their own size
  (`FOREVER_SCROLL_STEP_W`, `_H`), each a wheel notch. Like the bar they show only when the list
  overflows. Drawn, the arrows are chevrons and the grip lights in the window lines' bronze
  (`FOREVER_RAIL_RGB`), not the accent gold, which read as bright yellow.
- Settings, Profiles, Patch Notes and Credits stay at the sidebar's foot, where the Naowh skin has them,
  as list bars like the modules above. As the game's side tabs on the frame's outer right edge they
  were hard to find, and a screenshot of the window cropped them off.
- On-screen cards (`Parts.HudBackdrop` on a Card background, and window cards) wear one thin
  bronze frame instead of the black edge (`Parts.ForeverFrameArt`, the profession window's bar
  frame, `FOREVER_HUD_FRAME`). Its atlas only stretches left and right, so it is cut into eight
  pieces with `corner` px corners, set `out` px outside the card; Soft and None backgrounds have no
  frame. The waypoint card shows it only above 0% Background Opacity, as it did its edge. The frame
  takes the place of the edge the Group Buttons coloured under the mouse, so they show
  `Options_List_Hover` there instead (`Parts.ForeverHover`), as the game's Settings list does.
- `Parts.ProgressLine(parent, height, framed)`: a framed line (the XP tracker's, the trainer card's)
  is the game's cast bar on Forever (`Parts.ForeverProgress`, `FOREVER_CAST_BAR`: its track, gold
  fill untinted and frame cut into ends and middle). Unframed lines in list rows stay thin and
  drawn, as a 15px frame does not fit a 2px line. The part ahead (the XP of completed quests) is
  the same gold fill, dimmed: a flat yellow strip on the textured bar read as pasted on. The
  Journey card shows one segment per step, so each step is its own small cast bar.
- The micro menu's pieces, for the Top Bar's framed Bar Styles: `Parts.ForeverContainer` (its
  container, cut into nine with its dark middle) and `Parts.ForeverMicroButton` /
  `Parts.ShowForeverMicro` (a button's micro menu art, pressed while held, and its hover inside
  the rim in place of the button's own highlight). They are drawn from their files under
  `naowh:` names in `FOREVER_ART_FILES`, which no atlas lookup can swap.
- A HUD card's header has the Settings divider under it (`Parts.ForeverHeadLine`), and a HUD
  list's current row the Settings list's gold selection (`Parts.ForeverRowPick`) instead of an
  accent stripe.
- Fonts are the game's: Friz Quadrata for text and headings, Arial Narrow for numbers, unless an
  Addon Font is picked. Headings stand out as the game's titles do: a size up
  (`CLASSIC_HEADING_STEP`), on a black drop shadow.

#### The HUD Editor on Forever

WoW Forever ships Blizzard's Edit Mode (`Blizzard_EditMode` on the `forever` branch, Shared files
with Camelot overrides that change no look), so the HUD Editor borrows its look. Nothing inherits an
Edit Mode template or touches `EditModeManagerFrame`: the art goes on our own frames.

- The toolbar and the Elements list wear the bare metal frame (`Parts.ForeverFrame(window, { bare,
  title, onClose })`): `ButtonFrameTemplateNoPortrait` (`UI-Frame-Metal-CornerTopLeft`,
  `-CornerTopRight`, `-CornerBottomLeft`, `-CornerBottomRight`, `_UI-Frame-Metal-EdgeTop`,
  `_UI-Frame-Metal-EdgeBottom`, `!UI-Frame-Metal-EdgeLeft`, `!UI-Frame-Metal-EdgeRight`) from
  `Blizzard_SharedXML/Mainline/NineSliceLayouts.lua`, with Camelot's offsets
  (`Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua`). Two small floating panels with a
  portrait each read as two windows, so neither has one; the title sits centred on the bar. The
  toolbar's red close button (`RedButton-Exit`) is its old Exit Config and leaves the HUD Editor;
  the list's closes the list as the Elements button does. Drawn, both are the rings round a window.
- Undo, Redo, Revert and Elements are the red button at one height (22).
  With nothing to take back they are disabled, so they wear `128-RedButton-*-Disabled` and grey
  text instead of fading, and their tooltips still show (`SetMotionScriptsWhileDisabled`).
  Elements wears `-Pressed` while the list is open (`Parts.SetForeverLatched`).
- Layouts is a dropdown, as Edit Mode's layout picker (`EditModeManagerFrame.LayoutDropdown`, a
  `WowStyle1DropdownTemplate` in `Blizzard_EditMode/Shared/EditModeManager.xml`, filled in
  `EditModeManager.lua`: the layouts as radios, a divider, then New Layout and the rest). It is the
  kit's dropdown (`common-dropdown-a-button`) with the same entries as the old Layouts menu:
  the layouts to switch to, then Save to, Save as New Layout, Rename and Delete. There is no
  separate Manage step: Edit Mode keeps its actions in the same list, and so does ours.
- Each mover wears Edit Mode's selection (`EditModeSystemSelectionBaseTemplate` in
  `Blizzard_EditMode/Shared/EditModeSystemTemplates.xml`): its kits `editmode-actionbar-highlight`
  and `editmode-actionbar-selected` (`FOREVER_SELECTION_KIT`) on the layout
  `EditModeSystemSelectionLayout` copied from `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua`
  (`%s-NineSlice-Corner` mirrored and `FOREVER_SELECTION_OUT` out, `_%s-NineSlice-EdgeTop`,
  `_%s-NineSlice-EdgeBottom`, `!%s-NineSlice-EdgeLeft`, `!%s-NineSlice-EdgeRight`,
  `%s-NineSlice-Center`), applied with `NineSliceUtil.ApplyLayout`. Blue at rest, yellow when
  picked, and under the mouse the highlight kit again added on top at 0.4, as its
  `MouseOverHighlight`. The name stays centred on it at all times (Edit Mode only names a picked
  one, but ours have no other label). Drag, snap, lock and hide are ours, unchanged. A mover is
  dressed the first time the HUD Editor shows it, never at load. Drawn: a see-through blue fill in
  a light blue edge, yellow when picked.
- The list's groups are list bars (`common-button-list-collapseExpand`, the gold name, and
  `common-button-list-plus` or `-minus`) that fold with a click, for the session; a search shows
  every match whatever is folded. The picked row lights with the quest log's
  `UI-QuestLogTitleHighlight`, gold. The eye and padlock stay ours, a size up (16): Forever's files
  have an open eye (`GM-icon-visible`, `Blizzard_CompactRaidFrames/Mainline/
  Blizzard_CompactRaidFrameManager.xml`) but no closed one, and their padlock
  (`QuestSharing-Padlock`, `Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml`) is a colored
  badge that sits badly beside a flat eye.
- Guides is the game's check box, as Edit Mode's own (`EditModeCheckButtonTemplate`,
  `Blizzard_EditMode/Shared/EditModeTemplates.xml`, uses the same `UI-CheckBox-*` files). Snap
  lines were already one screen pixel, so they are lighter instead: `FOREVER_GUIDE_RGB` at
  `FOREVER_GUIDE_ALPHA`, not the orange.

## Checking

`lua Tools/regression/test-shared.lua` loads these files as `Shared.xml` lists them, against
stubs: nothing made at load, the item helpers, the Forever mark, and the row engine (rows
pooled and reused, one redraw per burst of events, none while hidden, no garbage). A module's
own test loads them the same way before its files, with `Tools/regression/load_files.lua`
and `toc_files.lua`, and times its draws with `measure.lua`: see
`test-dungeon-journal.lua` and `test-bis-window.lua`. A test that lists Shared files by hand
lists every file the parts it uses are made in: `Parts.lua` with `Marks.lua`, `Text.lua`,
`Hud.lua`, `Timer.lua`, `Share.lua` and `Panels.lua`; `Window.lua` with `Tabs.lua` and
`SettingsCard.lua`; `Items.lua` with `Gear.lua`.

`lua Tools/regression/test-forever-skin.lua` builds every Forever part twice, on a client with all of
the game's art and on one with none of it, and checks Naowh makes none of it. It draws a
settings page (bare bars that reflow as a card opens and closes) and builds the options window on
Forever: its header band and rails, the buttons on the band, no sidebar logo and no boxed content.

`lua Tools/regression/test-forever-unlock.lua` opens the HUD Editor on Forever, with all of the art
and with none of it: both frames, the close buttons, the disabled and pressed buttons, the Layouts
dropdown, Edit Mode's selection on a mover (not made before the editor opens), the folding list bars
and the lighter guides; and checks Naowh keeps its HUD Editor.
