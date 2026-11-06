# Changelog

## 0.1.3 — 2026-11-06

- **Fix: a possible crash while a level loads.** The mod learnt each new place through a UE4SS
  feature that runs on the game's loading thread, and that could crash the game ("Fatal Error!")
  during a level load. Places now report themselves when they appear in the world, on the game's
  own thread. On arriving on a planet the mod also looks the places up once, as a safety net.
- Tested in game with the whole realism set: no crash, the hooks register.

## 0.1.2 — 2026-11-01

Thanks to **TheCalcMan** (Steam) for the report.

- **The orange markers come back after a dungeon.** After you left a dungeon only the small blue
  points of interest showed: outposts, cities and dungeon entrances stayed hidden until you flew
  away and landed again. The planet's places are now looked up again when you come out.
- Install section: the realism set installer first, the manual install second.

## 0.1.1 — 2026-10-31

- **No key by default.** Markers only appear on a planet's surface, on foot or on the hoverbike, so
  the mod needs no key. `ToggleKey` in `scripts\config.lua` still adds one (for example `"0"`).
- Shorter, plainer key text in the description.

## 0.1.0 — 2026-10-31

First release. Idea by **TheCalcMan** (Steam): show the planet waypoints on the ground, so crossing a
planet on the hoverbike is fun again.

- Markers for a planet's places (outposts, cities, villages, camps, wrecks), locations (dungeons,
  caves, mission sites) and nearby points of interest, on foot and on the hoverbike: marker, name
  and distance, in the colours of the game's ship markers.
- Arrows at the screen edge for the nearest places off screen.
- No double markers: mission objectives and what the game already shows on the hoverbike stay the
  game's own.
- Hidden in the ship, in dungeons and stations, in photo mode, with a menu open, and with the HUD
  hidden.
- On by default; **0** (zero) shows / hides the markers (`ToggleKey`).
