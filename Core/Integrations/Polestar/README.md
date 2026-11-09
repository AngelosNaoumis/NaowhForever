# Polestar guide feed

The Waypoint Pin's optional feed from Polestar's guide target: QoL > Interface > Waypoint Pin >
Follow Polestar (`waypointPolestar`, off by default), with Polestar's Next Stop (`waypointPolestarStops`,
on). Works only with Polestar loaded and new enough to have `Polestar.Nav.API` minor 1. Loads through
`Polestar.xml`, after `Core/Core.xml`.

## Layout

```
Core/Integrations/Polestar/
  Polestar.xml   what loads
  Waypoint.lua   the feed: follows Polestar's target and hands it to ns.SetGuideWaypoint
```

## Why

- It reads Polestar only through its public API (`Polestar.Nav.API`: `Target`, `Follow`, `Unfollow`,
  `Dismiss`, version 1 minor 1), never Polestar's internals. `Target()` gives the point in C_Map's terms
  (0-1 of the map's live frame); Polestar's own points can be in another frame, so they are not read.
- Polestar calls the feed back the frame after its target or route changes, many changes in one frame
  as one call, so the feed registers no events and polls nothing while it follows.
- `Follow` says the feed sets the game's waypoint (`pin`), so Polestar's own Blizzard waypoint steps
  aside, and whether it shows the target on screen (`shows`: the Navigator Bar is on), so Polestar may
  hide its arrow (Polestar's own option). Direct Navigator Bar changes and profile switches refresh
  the existing follower's `shows` option while Follow Polestar stays on. Unchanged options do not
  register the follower again; both option tables are reused.
- The same target again is not placed again: once the game clears it on arrival, the pin waits for
  Polestar's next target instead of placing it over and over. Turning Follow RestedXP off places ours
  again, as that feed's destination may have taken the pin.
- Turned off, the feed clears its own pin before it lets go of Polestar: unfollowed, Polestar may set
  its own game waypoint at the same spot, which the clear would take with it.
- Each successful placement owns its `details` table by identity. A replacement keeps the previous
  token until placement succeeds: an unsupported map releases the previous pin and journey, rather
  than leaving them behind when Follow Polestar is turned off.
- The Navigator Bar dismisses Polestar only when its current super-tracked target is a user waypoint
  whose coordinates match the placed guide pin. Journey steps carry the same token, so clearing a
  genuine guide journey still dismisses it. Stale placed-pin or journey metadata cannot turn a clear
  of a native replacement pin or tracked quest into a Polestar dismissal.
- Logged in without a Polestar to follow (not loaded, or too old), it stops waiting: none comes later.
- `ns.PolestarFollowable()` says whether Polestar can be followed and why not, for the settings row.
