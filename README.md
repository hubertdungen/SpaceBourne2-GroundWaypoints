![Ground Waypoints](docs/banner.png)

# Ground Waypoints — planet markers on foot and on the hoverbike for SpaceBourne 2

From your ship, SpaceBourne 2 marks a planet's outposts, cities, dungeons and mission sites. Land,
step out or jump on the hoverbike, and those markers vanish: you cross the planet guessing. Ground
Waypoints brings them back on the ground: a marker, the name and the distance, in the same colours
the game uses from the ship.

An idea by **TheCalcMan** (Steam).

**Links:** [GitHub](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints) ·
[Nexus Mods](https://www.nexusmods.com/spacebourne2/mods/13) · UE4SS Lua mod · works alone or with
the rest of the realism set.
**Install the whole realism set in one go:** the
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)).

## Features

### What is marked

- **On foot and on the hoverbike,** while you are on a planet's surface.
- **Places:** outposts, cities, villages, camps, wrecks.
- **Locations:** dungeons, caves and mission sites.
- **Points of interest** nearby: crash sites, traders and the like.

### How it looks

- **Same look as the ship's markers.** Orange places, pink mission places, grey cleared dungeons. The
  name sits next to the marker with the distance below, in the game's format (`152m`, `3.4km`).
- **Arrows at the screen edge** for the nearest places behind you or off screen.
- **Follows the game's indicator scale** setting, like the ship's markers.

### Calm, not cluttered

- **A sensible number.** At most 12 markers, nearest first (mission places always first). Nothing
  within 40 m (you are there). Points of interest only within 5 km; places and locations up to
  600 km (a planet's outposts and dungeons are often 100–500 km apart).
- **No double markers.** Mission objectives and the few places the game already shows on the
  hoverbike stay the game's own.
- **Out of the way.** Hidden in the ship, in dungeons and stations, in photo mode, with a menu open,
  and when the game hides its HUD.

### On by default

- No key needed: markers appear on planets by themselves.

## Requirements

- SpaceBourne 2 (Steam).
- [UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1), a free script loader
  for Unreal Engine games (the realism installer installs it for you).

## Install

**A. SpaceBourne 2 Realism installer (recommended)**
Get it on [Nexus](https://www.nexusmods.com/spacebourne2/mods/11) or
[GitHub](https://github.com/hubertdungen/SpaceBourne2-Realism/releases/latest). Tick Ground
Waypoints and any other mods of the set: it installs UE4SS if you don't have it, switches the mods
on and keeps them updated.

**B. Manual** (Nexus file, or the zip on the [releases page](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints/releases))
1. Extract the zip into your game folder (`...\SpaceBourne 2`, the one with `SpaceBourne2.exe`).
   It creates `SB2\Binaries\Win64\Mods\GroundWaypoints` and switches itself on.
2. No UE4SS yet? Get [RE-UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1)
   and copy `dwmapi.dll`, `UE4SS.dll` and `UE4SS-settings.ini` into
   `SpaceBourne 2\SB2\Binaries\Win64\`.

**Uninstall:** untick Ground Waypoints in the installer or delete the `GroundWaypoints` folder.
Ground Waypoints never writes to your saves.

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

## How it works

The game draws all its markers on the HUD canvas (`Q1Hud`). On foot its planet-place function stops
at once, and on the hoverbike it only draws an active mission's site. There is no switch to flip, so
Ground Waypoints draws the markers itself on the same canvas, with the game's own font, icons and
colours. It reads the places' positions and names a few times a second and keeps only plain data;
each frame it only places and draws the markers. Details: [DESIGN.md](DESIGN.md).

## Known limits

- **Only what the planet has loaded.** Places appear once the game has created them, as in the ship.
- **Point-of-interest names come from the game's internal names** ("Ship Crash", "Raided House"...),
  so they are in English.
- **Two places in the same direction** can overlap their labels.

Version history: [CHANGELOG.md](CHANGELOG.md).

## The SpaceBourne 2 realism set

Separate mods that work alone or in any combination. The
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)) installs the ones you tick and keeps them updated.

- **[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/4)): realistic ballistics, wounds and tactical AI. The core of the set.
- **[Silent Ops](https://github.com/hubertdungen/SpaceBourne2-SilentOps)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/6)): stealth, silent takedowns and suppressors.
- **[Ammo Discipline](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/12)): carried ammo limits and scavenging, so every magazine counts.
- **[Gear Without Levels](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/7)): use gear above your level, with small handling penalties.
- **[Tactical First Person](https://github.com/hubertdungen/SpaceBourne2-TacticalFirstPerson)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/15)): first person on foot, weapons held up, aiming down the sights.
- **[Tactical Engineering](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/10)): realistic deployable turrets.
- **[Get Out of the Way](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/14)): NPCs step aside naturally when you walk through them.
- **[Ground Waypoints](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/13)): planet waypoints on foot and on the hoverbike.
- **[Faction Power](https://github.com/hubertdungen/SpaceBourne2-FactionPower)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/9)): dungeons, strategic sales and missions earn your faction power.
- **[Bigger Armies](https://github.com/hubertdungen/SpaceBourne2-BiggerArmies)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/17)): twice the general slots for your faction's ground and space forces.
- **[Clear HUD](https://github.com/hubertdungen/SpaceBourne2-ClearHUD)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/16)): a reticle you can see and HUD colours of your choice.
- **[Split Controls](https://github.com/hubertdungen/SpaceBourne2-SplitControls)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/5)): separate vertical invert for ship and on foot, per device.
- **[SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)): HOTAS, rudder pedals, triple screens and head tracking.

## Thanks

**TheCalcMan** (Steam), for the idea of this mod and for play-testing the realism set.

## License

MIT. See [LICENSE](LICENSE).
