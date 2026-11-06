![Ground Waypoints](docs/banner.png)

# Ground Waypoints — planet markers on foot and on the hoverbike for SpaceBourne 2

From your ship, SpaceBourne 2 marks a planet's outposts, cities, dungeons and mission sites. Land,
step out or jump on the hoverbike, and those markers vanish: you cross the planet guessing.
Ground Waypoints brings them back on the ground: a marker, the name and the distance, in the same
colours the game uses from the ship.

Version 0.1.3 · [Nexus Mods page](https://www.nexusmods.com/spacebourne2/mods/13) · UE4SS Lua mod · works alone or with the rest of the
[realism set](#part-of-the-spacebourne-2-realism-set). Idea by **TheCalcMan** (Steam).

## What it does

- **On foot and on the hoverbike**, while you are on a planet's surface:
  - **places**: outposts, cities, villages, camps, wrecks;
  - **locations**: dungeons, caves and mission sites;
  - **points of interest** nearby: crash sites, traders and the like.
- **Same look as the ship's markers.** Orange places, pink mission places, grey cleared dungeons.
  The name sits next to the marker with the distance below, in the game's format (`152m`, `3.4km`).
- **Arrows at the screen edge** for the nearest places behind you or off screen, with their distance.
- **Calm.** At most 12 markers, nearest first (mission places always first). Nothing within 40 m
  (you are there). Points of interest only within 5 km; places and locations up to 600 km (a planet's
  outposts and dungeons are often 100–500 km apart).
- **No double markers.** Mission objectives and the few places the game already shows on the
  hoverbike stay the game's own.
- **Out of the way.** Hidden in the ship, in dungeons and stations, in photo mode, with a menu open,
  and when the game hides its HUD.
- **On by default, no key needed.** Markers appear on planets by themselves.

## Requirements

- SpaceBourne 2 (Steam).
- [UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1), a free script loader
  for Unreal Engine games. Installing HTR or the realism set installer installs it too.

## Install

Option A (recommended): the [SpaceBourne 2 Realism installer](https://www.nexusmods.com/spacebourne2/mods/11).

Option B, manual:

1. Download `GroundWaypoints-0.1.3.zip` from the
   [releases](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints/releases).
2. Extract it into the game folder (`...\steamapps\common\SpaceBourne 2\`). It adds
   `SB2\Binaries\Win64\Mods\GroundWaypoints\`; the `enabled.txt` inside turns it on.
3. That's it: land on a planet and step out.

Uninstall: delete `SB2\Binaries\Win64\Mods\GroundWaypoints`. Ground Waypoints never writes to your
saves.

## Controls

No key needed: markers show on planets automatically. To add an on/off key, set `ToggleKey` in
`scripts\config.lua` (for example `"0"`).

## Settings

Edit `Mods\GroundWaypoints\scripts\config.lua`. Every line is optional.

- `Enabled`: `false` switches the mod off completely.
- `StartOn`: start with the markers shown (`true`) or hidden.
- `ToggleKey`: none by default; for example `"0"` to add an on/off key.
- `OnFoot` / `OnHoverbike`: where markers show.
- `Places` / `Locations` / `PointsOfInterest`: what is marked.
- `MaxDistance` (600 000 m), `PoiMaxDistance` (5 000 m), `HideWithinMeters` (40 m).
- `MaxMarkers` (12), `OffscreenArrows` and `MaxOffscreenArrows` (4).
- Look: `MarkerSize`, `TextScale`, `HeightOffset`, `ShowNames`, and `Colors`.

The text follows the game's own **indicator scale** setting, like the ship's markers.

## How it works

The game draws all its markers on the HUD canvas (`Q1Hud`). On foot its planet-place function stops
at once, and on the hoverbike it only draws an active mission's site. There is no switch to flip, so
Ground Waypoints draws the markers itself on the same canvas, with the game's own font, icons and
colours. It reads the places' positions and names a few times a second and keeps only plain data;
each frame it only places and draws the markers. Details: [DESIGN.md](DESIGN.md).

## Status and known limits

<!-- nexus:skip -->
Tested in game on 2026-10-31 on planet Oclite (details in [DESIGN.md](DESIGN.md), section 8):
- on foot and on the hoverbike, the markers, names, distances and edge arrows;
- the optional 0 key (the game does nothing else with it);
- the game's own markers (your ship) unchanged;
- 12 markers at once, up to 460 km away;
- frame times with the mod on vs off: no measurable difference (120 vs 118 fps, same median and p99);
- your saves untouched.

0.1.2 (places found again after a dungeon) was checked against the mod's own logic; it has not
been run in a dungeon yet.
0.1.3 (places learnt from their ReceiveBeginPlay on the game thread instead of NotifyOnNewObject) was
smoke-tested on 2026-11-06 with the whole set at a station: no crash, the four hooks registered. A
planet surface was not visited in that test.
<!-- /nexus:skip -->

Known limits:

- **Only what the planet has loaded.** Places appear once the game has created them, as in the
  ship.
- **Point-of-interest names come from the game's internal names** ("Ship Crash", "Raided House"…), so
  they are in English.
- **Two places in the same direction** can overlap their labels.
- **If the mod is reloaded mid-game**, the first time you step out on a planet it may search once for
  places it missed: about 0.2 s of small stutters.

## Part of the SpaceBourne 2 realism set

This mod is part of the realism set, built around [Hardcore Tactical Realism](https://www.nexusmods.com/spacebourne2/mods/4) as the core mod. HTR is not required: this mod works on its own or with any of the others. **Install them all at once** with the [SpaceBourne 2 Realism installer](https://www.nexusmods.com/spacebourne2/mods/11) ([GitHub](https://github.com/hubertdungen/SpaceBourne2-Realism)): tick the mods you want, and it switches them on and keeps them up to date.

- **Hardcore Tactical Realism (HTR)**: the core: realistic ballistics, wounds and tactical AI. [GitHub](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/4) · [Steam](https://steamcommunity.com/app/1646850/discussions/0/573805072991123580/)
- **Split Controls**: separate look inversion for ships and on foot. [GitHub](https://github.com/hubertdungen/SpaceBourne2-SplitControls) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/5)
- **Silent Ops**: realistic stealth, suppressors and silent takedowns. [GitHub](https://github.com/hubertdungen/SpaceBourne2-SilentOps) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/6)
- **Gear Without Levels**: any weapon or suit at any level, with small penalties. [GitHub](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/7)
- **SB2 HOTAS**: joystick, HOTAS, pedals, head tracking and triple screen. [GitHub](https://github.com/hubertdungen/SpaceBourne2-HOTAS) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/8)
- **Faction Power**: dungeons, sales and missions earn your faction power. [GitHub](https://github.com/hubertdungen/SpaceBourne2-FactionPower) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/9)
- **Tactical Engineering**: deployable turrets and barricades that take time to set up. [GitHub](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/10)
- **Ammo Discipline**: realistic ammo limits and scavenging. [GitHub](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/12)
- **Ground Waypoints** *(this mod)*: planet waypoints on foot and on the hoverbike. [GitHub](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/13)
- **Get Out of the Way**: NPCs step aside naturally when you walk through them. [GitHub](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/14)

Coming soon: Tactical First Person.

## Thanks

**TheCalcMan** (Steam), for the idea of this mod and for play-testing the realism set.

## License

MIT. See [LICENSE](LICENSE).
