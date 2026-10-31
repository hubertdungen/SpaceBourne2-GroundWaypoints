# Ground Waypoints — design

Idea: **TheCalcMan** (Steam). Part of the SpaceBourne 2 realism set.

## 1. Goal

In space, and while flying the ship near a planet, SpaceBourne 2 marks outposts, cities, dungeons
and other surface locations with a marker, their name and the distance. When you land and walk, or
ride the hoverbike, almost all of them disappear. Crossing a planet on the hoverbike becomes guesswork.

Ground Waypoints shows those places on foot and on the hoverbike: a marker, the name and the
distance, in the colours the game uses from the ship.

## 2. Where the game hides them (research, game version of 2026-10)

Everything is drawn by the canvas HUD `Q1Hud_C` (`/Game/1Data/Q1Hud`) in `ReceiveDrawHUD`. The
older ScreenIndicator widgets are dead code: `Master_Planet_Building_C.AddIndictitor` and
`RemoveIndictitator` are empty.

- **In the ship** (`CharacterOn?` false), `ReceiveDrawHUD` calls `Indictitaor()`. When
  `Game_Builder.PlayerAtSurface` is true it loops over every `Master_Planet_Building_C` (except
  `Surface_Center_C`) and every `Master_Random_LocationAtSurface_C` and calls
  `Arrow_For_PlanetBuildings()` for each (orange marker, pink for `SpawnedForQuest`).
- **On foot and on the hoverbike** (`CharacterOn?` true), it calls `Objectives()` instead:
  - on foot: mission `ObjectiveActor_C` (green), enemy shooters, dungeon doors (inside dungeons), your
    ship;
  - on the hoverbike: also the `Master_Random_LocationAtSurface_C` with `IsQuestActive` within
    20 km, and `MasterSurfacePoi_C` between 20 and 500 m.
- `Arrow_For_PlanetBuildings()` itself starts with `Cast<Q1_Character>(GetPlayerPawn) → return`,
  so it draws nothing on foot, even when called.

So there is no visibility flag or widget to flip: the on-foot check is compiled into the
Blueprint. Calling the game's function from Lua would work on the hoverbike only.

## 3. Approach: draw our own markers with the HUD's own canvas

A post-hook on `Q1Hud_C:ReceiveDrawHUD` (the canvas is valid there) draws with `AHUD` calls:
`Project`, `DrawTexture`, `DrawText`. It uses only assets the HUD itself references (kept loaded by
its bytecode): the engine font `Roboto`, the arrow `T_Arrow_U_64x64`, the circle `circle_03`. No
material instances are created, so nothing can be garbage-collected under us.

Look: the same colours as the game's ship markers (orange places, pink quest places), name and
distance in the game's format (`152m`, `3.4km`). Off-screen places get an arrow at the screen edge
with the distance (nearest ones only).

## 4. What is shown

| Kind | Class | Label | Default range |
|---|---|---|---|
| Places | `Master_Planet_Building_C` (outposts, cities, villages, wrecks, camps…), not `Surface_Center_C` | `Name` | 600 km |
| Locations | `Master_Random_LocationAtSurface_C` (dungeons, caves, quest sites) | `NameOfStruct` (not the game's entry points `DiretkEnterPoint_C`, `SafeLocationPlanet_C`) | 600 km |
| Points of interest | `MasterSurfacePoi_C` (crash sites, traders…), from the class name | 5 km |

Quest locations (`SpawnedForQuest` or `IsQuestActive`) are pink and always kept; cleared dungeons
are grey. Places closer than 40 m are hidden (you are there). At most 12 markers, nearest first.

No duplicates: on the hoverbike the game already draws active quest locations (≤ 20 km) and points
of interest (≤ 500 m), so the mod skips exactly those. Mission objectives stay the game's.

Hidden when: not on a planet surface (`Game_Builder.PlayerIsAt` ≠ 1, e.g. in a dungeon or a
station), in the ship, in photo mode, with a 3D menu open (`Any3d Widget On`), or when the game
hides its indicators (`HideIndicators`). The game's own "hide HUD" stops `ReceiveDrawHUD`, so it
hides ours too.

## 5. Cost rules

- **Per frame** (inside the draw hook): per marker one `Project` and two or three draw calls. No
  property reads of game actors, no searches.
- **4 times a second**: pawn, place in the world and HUD flags (a handful of reads); distances,
  sorting and labels in plain Lua from cached positions.
- **Once a second, one class at a time** (each class every 3 s): `GameplayStatics:GetAllActorsOfClass`
  (a class-hashed engine lookup, not UE4SS `FindAllOf`). Only plain data is kept (position, name,
  flags), never actor objects from one frame to the next.
- Classes are found once with `StaticFindObject`; a miss costs ~37 ms, so lookups back off
  (1, 2, 4, 8, 16 s) and only happen before the HUD class exists.

Measured cost: see §8.

## 6. Settings and key

`config.lua`: `Enabled` (master switch, first line), `StartOn`, `ToggleKey`, kinds on/off,
ranges, `MaxMarkers`, `HideWithinMeters`, `OffscreenArrows`, `MarkerSize`, `TextScale`, colours.

Key: **plain 0** (zero, top row) shows / hides the markers (key plan rev 2e). Every Shift+F-key of the
shared plan is taken. The game's key presets (`1Data/1_Keybings/AllPresets`, compared without case)
bind every letter except **P**, and `MSM1_X_Shared` binds a lowercase `i` next to the cargo
interface. But a scan of all 35,059 packages for raw key events found
`Q1Controller.InpActEvt_P_K2Node_InputKeyEvent`: in the shipping build it runs the same handler as
Escape. Keys free in both the presets and the raw events: **Zero**, Delete, Insert, Home, End,
PageDown. Delete belongs to the set (Tactical Engineering, Gear Without Levels); the others are
missing on many laptops. A plain key, because Ctrl, Alt and Shift are game actions on foot; UE4SS
matches modifiers exactly, so plain 0 stays quiet with Shift held (Shift+0 = Ammo Discipline). `ToggleKey` can be changed or
emptied; the mod refuses the game's own keys (F1, F2, F5, F6, F8, F10, F11, F12, with or without
Shift), plain I and P, plain F3/F4 (Silent Ops on foot), Shift+0 (Ammo Discipline), and Ctrl or Alt.

## 7. Risks

- `GetAllActorsOfClass` out-parameter shape in UE4SS 3.0.1 (array as table of params): handled both ways.
- Actors far away may not exist until you get closer (planet streaming): then the marker appears
  when the game spawns the place, as it does in the ship.
- A game patch can rename classes: every game name is at the top of `main.lua`.

## 8. Test log

2026-10-31, Steam game, UE4SS 3.0.1, test slot copied from the pretest CheckPoint save (saves hashed
before and after: all 81 files identical), with HTR, Split Controls, Silent Ops and Gear Without Levels.

| Check | Result |
|---|---|
| `GameplayStatics:GetAllActorsOfClass` from Lua | out array empty, then a crash inside UE4SS (17:52). Replaced by NotifyOnNewObject + path lookups |
| Hook on `Q1Hud_C:ReceiveDrawHUD`, drawing with `DrawText` / `DrawTexture` | works; markers, names, distances and edge arrows on screen (in space, with warp targets as a stand-in) |
| Reaching a planet | script: into the ship, ship moved into planet Oclite's entry sphere, descent by the game, eject (real G) |
| On foot on Oclite | pawn `Q1_Character_C` → foot; markers drawn; the game's own Ship marker unchanged |
| Hoverbike | `SpawnHoverBike` + `OnInteractWithHover`; pawn `BP_Hover_Car_Effects_C` → bike; markers drawn |
| Places found on Oclite | 16 locations (`SB_CampType_C` outposts, `SB_MineType_C` pits/lairs, `SB_Villige_Type_C`), 4 points of interest, 0 `Master_Planet_Building_C`. **111–460 km away**: ranges raised to 600 km (5 km for points of interest); the game's entry points `DiretkEnterPoint_C` / `SafeLocationPlanet_C` excluded |
| Real key 0 | hides / shows the markers; the game does nothing else |
| Cost, 2 markers | draw 0.23 ms per frame on average (2 ms max, clock resolution 1 ms); 4 Hz tick 0.33 ms |
| Cost, 9 markers (old code: engine `Project`, 6 calls a marker) | 0.9–1.1 ms per frame → now Lua projection and 2 calls a marker |
| Safety-net `FindAllOf` | 4 × ~50 ms the first time on foot after a load; now only when the mod started late or after a level change it could not see |

Final check, 21:00–21:05 (the game would not start at 20:00 and 20:07 with the PC in a remote session:
"GameThread timed out waiting for RenderThread"; it started fine with the screen on):

| Check | Result |
|---|---|
| Long ranges | 12 markers on the horizon (Kare Village 111.4 km, Omba Picket 254.5 km, Pit of Twinn 363.5 km, Lair of McMains…) plus a nearby point of interest ("Rock") and an edge arrow |
| Lua projection vs the engine's `Project` | identical (820,723 and 820,723) |
| After a load | no safety-net search: the places were tracked as the game created them |
| Drawing, 12 markers | 0.62 ms per frame on average (3 ms max); 4 Hz tick 0.45–0.58 ms |
| Frames, 32 s each, standing on foot | **mod on**: 120 fps, median 8.0 ms, p99 10 ms, max 16 ms, 0 spikes; **mod off**: 118 fps, median 8.0 ms, p99 11 ms, max 91 ms (6 game spikes, mod off). No measurable difference |
| Real 0 key | off and on again |

Seen, not yet changed: two places in the same direction can overlap their labels.
