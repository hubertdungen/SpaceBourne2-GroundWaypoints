--[[
  Ground Waypoints for SpaceBourne 2
  ==================================
  USER SETTINGS. Edit with any text editor, then restart the game.
  Everything here is optional: delete a line and the default is used.
]]

return {
    -- false = the mod does nothing at all.
    Enabled = true,

    -- Markers start ON. false = start hidden (then use ToggleKey to show them).
    StartOn = true,

    -- Optional key to show / hide the markers. None by default: markers only appear on a planet's
    -- surface, on foot or on the hoverbike. Example: ToggleKey = "0" (zero, top row, free in the
    -- game). Keys the game or other realism-set mods use are refused (see DESIGN.md).
    ToggleKey = "",

    -- Where the markers show.
    OnFoot = true,
    OnHoverbike = true,

    -- What is marked.
    Places = true,            -- outposts, cities, villages, wrecks, camps
    Locations = true,         -- dungeons, caves, mission sites
    PointsOfInterest = true,  -- crash sites, traders, corpses... (short range)

    -- Ranges, in metres.
    MaxDistance = 600000,     -- places and locations (a planet's outposts are 100-500 km apart)
    PoiMaxDistance = 5000,    -- points of interest
    HideWithinMeters = 40,    -- you are there: no marker

    -- At most this many markers at once (nearest first; quest places always first).
    MaxMarkers = 12,

    -- Arrows at the screen edge for places behind you or off screen (nearest ones only).
    OffscreenArrows = true,
    MaxOffscreenArrows = 4,

    -- Look.
    MarkerSize = 18,          -- pixels
    TextScale = 1.0,
    HeightOffset = 300,       -- cm above the place's origin
    ShowNames = true,         -- false: distance only

    -- Colours {R, G, B} 0-1. Defaults are the game's own ship-marker colours.
    Colors = {
        Place = { 1.0, 0.598, 0.208 },
        Quest = { 1.0, 0.0024, 0.48 },
        Poi = { 0.40, 1.0, 0.97 },
        Cleared = { 0.6, 0.6, 0.6 },
    },

    Debug = false,            -- true: writes details to groundwaypoints.log in the mod folder
}
