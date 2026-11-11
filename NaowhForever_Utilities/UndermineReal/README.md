# Undermine Real Reminder

Blinks a Tarnished Undermine Real (item 226404) on screen after you kill a dungeon boss that drops one, until you loot the boss. Each boss drops one a day. Its settings card is on Quality of Life > Interface (`QoL/Interface`), and its switch and default come from `ns.FEATURES.undermineReal` (off).

## Layout

```
NaowhForever_Utilities/UndermineReal/
  UndermineReal.xml        every file, in load order
  UndermineReal.lua        the settings, the module table (ns.UndermineReal), the daily kill record and what is pending
  Data/
    Bosses.lua             the item, and the boss list: encounter ID to NPC ID (UR.BOSSES)
  UI/
    Reminder.lua           the blinking icon, its mover, and the events
    SettingsPage.lua       the settings card: icon size, the text's font, size, outline and position, with a preview
  README.md                this file
```

## Why

- The boss list is fixed: 56 bosses in Blackrock Depths, Lower and Upper Blackrock Spire, Dire Maul, Scholomance and Stratholme, each an encounter ID from the Dungeon Journal's data with its NPC ID. Nothing is matched by name, so it works in every language.
- Not listed, because the Dungeon Journal has no encounter for them: Bael'gar, Ezra Grimm, Malor the Zealous and Grand Crusader Dathrohan. Demon Fall Canyon is not in the journal either.
- `ENCOUNTER_END` with `success` starts it, and only a boss's first kill since the daily reset does: a boss's kill is stored on the character until `C_DateAndTime.GetSecondsUntilDailyReset()` passes, so killing it again the same day does not blink.
- It ends when the boss's corpse is opened: `LOOT_OPENED` is read for `GetLootSourceInfo` GUIDs, and the NPC ID in the GUID is compared with the boss's. A click on the icon, or leaving the instance, also ends it.
- Events are registered only while the module is on.
- The text is "Loot Real", short so it reads at a glance. `LABEL_GAP` is 4: the space between the icon and the text on whichever side the text sits.

## Checking

In game, in a dungeon from the list, with the module on (Settings > Modules):

1. Kill a listed boss for the first time that day: the icon blinks with "Loot Real".
2. Open the boss's corpse: the icon goes. Check the real is in the loot, and that it is item 226404 on Forever.
3. Kill the same boss again after a reset of the instance, the same day: nothing blinks.
4. After the daily reset it blinks for that boss again.
5. Click the icon: it hides until the next boss. Leave the instance with it showing: it goes.
6. Unlock Mode shows the icon to move; its position is kept.
7. Change the text's font, size, outline and position on the card: the icon on screen and the preview follow.
