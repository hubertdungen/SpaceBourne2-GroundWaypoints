--[[
  Ground Waypoints for SpaceBourne 2 (UE4SS Lua mod)
  Idea: TheCalcMan (Steam). Part of the SpaceBourne 2 realism set.

  The game marks planet places (outposts, cities, dungeons...) only while you fly the ship. On foot
  and on the hoverbike its HUD skips them: Q1Hud_C:Arrow_For_PlanetBuildings returns at once for
  Q1_Character, and the on-foot path never calls it. There is no flag to flip, so this mod draws
  the same kind of marker itself, with the HUD's own canvas, in a post-hook of
  Q1Hud_C:ReceiveDrawHUD (the canvas is only valid there). See DESIGN.md.

  Cost rules:
    * per frame: per marker one Project and a few draw calls; nothing else;
    * 4 times a second: pawn, place in the world, HUD flags; distances and labels in plain Lua;
    * once a second, one class at a time: GameplayStatics:GetAllActorsOfClass. Only plain data
      (position, name, flags) is kept, never actor objects between frames.
]]

local VERSION = "0.1.4"

-- Game names (the only things to fix after a game patch) -------------------------------------
local G = {
    HudClass = "/Game/1Data/Q1Hud.Q1Hud_C",
    DrawHook = "/Game/1Data/Q1Hud.Q1Hud_C:ReceiveDrawHUD",
    Classes = {
        place = "/Game/Vx/Biomes/Planet_Buidlings/Master_Planet_Building.Master_Planet_Building_C",
        location = "/Game/Vx/Spwner/SurfaceLocations/Master_Random_LocationAtSurface.Master_Random_LocationAtSurface_C",
        poi = "/Game/Vx/RandomSurfacePOIs/MasterSurfacePoi.MasterSurfacePoi_C",
        objective = "/Game/1Galaxy/Warp/QuestSpawners/ObjectiveActor.ObjectiveActor_C",
    },
    SkipPlaceClass = "Surface_Center_C",
    -- the game's own landing / entry points on a planet, not places
    SkipLocationClass = { DiretkEnterPoint_C = true, SafeLocationPlanet_C = true },
    FootClass = "Q1_Character_C",
    BikeClass = "BP_Hover_Car_C",
    Space = 0, PlanetSurface = 1, -- Game_Builder.PlayerIsAt: 0 space, 1 planet surface, 2 dungeon, ...
    Assets = {
        font = "/Engine/EngineFonts/Roboto.Roboto",
        fontDF = "/Engine/EngineFonts/RobotoDistanceField.RobotoDistanceField",
        arrow = "/Game/Packes/CompShooterHUD/Textures/Icons/Generic_Icons/64x64/T_Arrow_U_64x64.T_Arrow_U_64x64",
        dot = "/Game/_Textures/MaskPack/circle_03.circle_03",
    },
    -- What the game itself draws on the hoverbike (Q1Hud_C:Objectives): never draw it twice.
    BikeQuestRange = 2000000, -- cm, active quest locations
    BikePoiMin = 2000, BikePoiMax = 50000, -- cm, points of interest
}

-- Folder and log ---------------------------------------------------------------------------
local DIR
do
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local cut
    for i in src:lower():gmatch("()[\\/]scripts[\\/]") do cut = i end
    DIR = cut and src:sub(1, cut) or ".\\Mods\\GroundWaypoints\\"
end
local LOG = DIR .. "groundwaypoints.log"
local verbose = false

local function write(prefix, ...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local f = io.open(LOG, "a")
    if f then f:write(os.date("%H:%M:%S "), prefix, table.concat(t, " "), "\n"); f:close() end
    return table.concat(t, " ")
end
local function log(...) if verbose then write("", ...) end end
local function warn(...) print("[GroundWaypoints] " .. write("WARN ", ...) .. "\n") end

-- Settings ---------------------------------------------------------------------------------
local defaults = {
    Enabled = true, StartOn = true, ToggleKey = "", OnFoot = true, OnHoverbike = true,
    Places = true, Locations = true, PointsOfInterest = true,
    MaxDistance = 600000, PoiMaxDistance = 5000, HideWithinMeters = 40, MaxMarkers = 12,
    OffscreenArrows = true, MaxOffscreenArrows = 4, MarkerSize = 18, TextScale = 1.0,
    HeightOffset = 300, ShowNames = true, Debug = false,
    Colors = {},
}
local okCfg, cfg = pcall(require, "config")
if not okCfg or type(cfg) ~= "table" then
    warn("config.lua could not be read (" .. tostring(cfg) .. "); using defaults")
    cfg = {}
end
for k, v in pairs(defaults) do if cfg[k] == nil then cfg[k] = v end end
local function color(name, def)
    local c = cfg.Colors[name]
    if type(c) ~= "table" then c = def end
    return { R = tonumber(c[1] or c.R) or def[1], G = tonumber(c[2] or c.G) or def[2], B = tonumber(c[3] or c.B) or def[3], A = 1.0 }
end
local COL = {
    place = color("Place", { 1.0, 0.598, 0.208 }),
    quest = color("Quest", { 1.0, 0.0024, 0.48 }),
    poi = color("Poi", { 0.40, 1.0, 0.97 }),
    cleared = color("Cleared", { 0.6, 0.6, 0.6 }),
    toast = { R = 0.40, G = 1.0, B = 0.97, A = 1.0 },
}
verbose = cfg.Debug == true

if not cfg.Enabled then
    warn("Ground Waypoints " .. VERSION .. " loaded, disabled in config.lua (Enabled = false)")
    return
end

-- State ------------------------------------------------------------------------------------
local S = {
    on = cfg.StartOn ~= false,
    mode = nil,          -- "foot" / "bike" / nil (nothing drawn)
    show = {},           -- markers chosen at the last tick (plain data)
    nextTick = 0,
    pawnAddr = nil, pawnKind = nil,
    textScale = 1.0,
    assets = {},
    toast = nil, toastUntil = 0,
    stats = { frames = 0, drawTime = 0, drawMax = 0, ticks = 0, tickTime = 0, scans = 0, scanTime = 0, scanMax = 0, since = os.clock() },
}
local KINDS = { "place", "location", "poi", "objective" }
local TICK = 0.25        -- s
local REFRESH = 3.0      -- s: every tracked place is re-checked and re-read this often
local GAP = 1.5          -- s without HUD drawing = maybe a level change (see the registry below)

-- Helpers ----------------------------------------------------------------------------------
local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end
local function get(o, prop)
    local ok, v = pcall(function() return o[prop] end)
    if ok then return v end
    return nil
end
local function textOf(t)
    if t == nil then return "" end
    local ok, s = pcall(function() return t:ToString() end)
    if ok and type(s) == "string" then return s end
    return ""
end
local function className(o)
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or ""
end
-- Is `name` this object's class or one of its parents?
local function classChain(o, depth)
    local names = {}
    local ok, c = pcall(function() return o:GetClass() end)
    for _ = 1, depth or 8 do
        if not (ok and valid(c)) then break end
        local okN, n = pcall(function() return c:GetFName():ToString() end)
        if okN then names[n] = true end
        ok, c = pcall(function() return c:GetSuperStruct() end)
    end
    return names
end
-- "Surface_ShipCrash_C" -> "Ship Crash"
local function prettyClass(n)
    n = n:gsub("_C$", ""):gsub("^Master", ""):gsub("^ALG_", ""):gsub("^POI_", ""):gsub("^Surface_?", ""):gsub("^Planet_", "")
    n = n:gsub("_", " "):gsub("(%l)(%u)", "%1 %2"):gsub("%s+", " ")
    return (n:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function distLabel(cm)
    local m = cm / 100
    if m < 1000 then return string.format("%dm", math.floor(m + 0.5)) end
    return string.format("%.1fkm", m / 1000)
end

-- Classes and assets: found once. A miss costs ~37 ms in UE4SS, so misses back off.
local found, missAt, missWait = {}, {}, {}
local function findObj(path, now)
    local o = found[path]
    if o ~= nil and valid(o) then return o end
    found[path] = nil
    if now < (missAt[path] or 0) then return nil end
    o = StaticFindObject(path)
    if valid(o) then
        found[path] = o
        missWait[path] = nil
        return o
    end
    missWait[path] = math.min((missWait[path] or 0.5) * 2, 16)
    missAt[path] = now + missWait[path]
    log("not loaded yet: " .. path)
    return nil
end

local GS
local function gameplayStatics()
    if not valid(GS) then GS = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
    return GS
end

-- Registry of planet places ------------------------------------------------------------------
-- GameplayStatics:GetAllActorsOfClass is not usable from UE4SS 3.0.1 Lua (its array out-parameter
-- came back empty and the game crashed inside UE4SS, tested 2026-10-31), and FindAllOf costs
-- 50-70 ms. So each place reports itself when it
-- begins play (a hook on its ReceiveBeginPlay, on the game thread; 0.1.2's NotifyOnNewObject ran on
-- the loading thread and could crash UE4SS on a level load). No actor object is kept: each place is found again by its path
-- (StaticFindObject, ~0 ms while it exists; the address must match), so a destroyed and freed
-- actor is never touched. Places are forgotten without being touched when the player leaves the
-- planet surface or the level changes; FindAllOf (once per class) refills the list only when
-- the mod may have missed places (it started late, or after a level change).
local R = { list = {}, byAddr = {}, pending = {}, cursor = 0, lastDraw = 0, needSeed = {}, notified = {} }

local function track(obj, kind, born)
    local okA, a = pcall(function() return obj:GetAddress() end)
    if not okA or not a or R.byAddr[a] then return end
    local okN, full = pcall(function() return obj:GetFullName() end)
    if not okN or type(full) ~= "string" or full:find("Default__", 1, true) or not full:find(":PersistentLevel.", 1, true) then return end
    local path = full:match("^%S+%s+(.+)$") or full
    local e = { path = path, addr = a, kind = kind, born = born }
    R.list[#R.list + 1] = e
    R.byAddr[a] = e
end

local function untrack(i)
    local e = R.list[i]
    R.byAddr[e.addr] = nil
    table.remove(R.list, i)
end

-- Drop everything that existed before `t` (never touching it). reseed: places may have been missed.
local function dropBefore(t, reseed)
    local dropped = 0
    for i = #R.list, 1, -1 do
        if R.list[i].born < t then untrack(i); dropped = dropped + 1 end
    end
    local keep = {}
    for _, p in ipairs(R.pending) do if p.born >= t then keep[#keep + 1] = p end end
    dropped = dropped + #R.pending - #keep
    R.pending = keep
    if reseed then for _, k in ipairs(KINDS) do R.needSeed[k] = true end end
    if dropped > 0 then log("dropped " .. dropped .. " tracked places" .. (reseed and " (level change)" or "")) end
end

local function readEntry(e, a, now)
    local okL, l = pcall(function() return a:K2_GetActorLocation() end)
    if okL and l then e.x, e.y, e.z = l.X, l.Y, l.Z end
    if e.readAt and now - e.readAt < 15 then return end
    e.readAt = now
    if not e.cls then e.cls = className(a) end
    local k = e.kind
    if k == "place" then
        e.skip = e.cls == G.SkipPlaceClass
        e.name = textOf(get(a, "Name"))
    elseif k == "location" then
        e.name = textOf(get(a, "NameOfStruct"))
        e.quest = get(a, "SpawnedForQuest") == true
        e.active = get(a, "IsQuestActive") == true
        e.cleared = get(a, "DungeonCleared") == true
        e.skip = G.SkipLocationClass[e.cls] == true
    elseif k == "objective" then
        e.skip = get(a, "ShowObjective") ~= true or get(a, "Hide") == true
    end
    if (e.name == nil or e.name == "") and k ~= "objective" then e.name = prettyClass(e.cls) end
end

-- 4 times a second: queue -> list, re-check a slice of the list, read new places.
-- where: Game_Builder.PlayerIsAt (1 = planet surface, in the ship too).
local function maintain(now, where, onFootOrBike)
    local atSurface = where == G.PlanetSurface
    for _, p in ipairs(R.pending) do -- queued less than a tick ago: still alive
        if valid(p.obj) then track(p.obj, p.kind, p.born) end
    end
    R.pending = {}
    if R.wasSurface and not atSurface then
        -- Off to space: the planet's actors go away and the next planet's are new (the game tells us
        -- about each). Into a dungeon (or anywhere else) the planet stays loaded, so nothing tells us
        -- about its places again: look them up once we are back (0.1.2; before, only the points of
        -- interest the game spawns again came back after a dungeon).
        dropBefore(now, where ~= G.Space)
    end
    if atSurface and not R.wasSurface then
        -- arriving on a surface: one lookup per class (a place class whose BeginPlay skips its
        -- parent's would never report itself)
        for _, k in ipairs(KINDS) do R.needSeed[k] = true end
    end
    R.wasSurface = atSurface
    if not atSurface then return end
    if onFootOrBike then -- safety net: one FindAllOf per class (50-70 ms), only when needed
        for _, k in ipairs(KINDS) do
            if R.needSeed[k] then
                R.needSeed[k] = nil
                local t0 = os.clock()
                local short = G.Classes[k]:match("%.([^%.]+)$")
                local all = FindAllOf(short) or {}
                for _, o in ipairs(all) do if valid(o) then track(o, k, now - 10) end end
                log(string.format("seeded %s: %d objects in %.0f ms", k, #all, (os.clock() - t0) * 1000))
                break -- one class per tick
            end
        end
    end
    local n = #R.list
    if n == 0 then return end
    local slice = math.max(2, math.ceil(n * TICK / REFRESH))
    for _ = 1, math.min(slice, n) do
        R.cursor = R.cursor % #R.list + 1
        local e = R.list[R.cursor]
        if now - e.born >= 2 then -- give a new place time to settle (name, alignment)
            local o = StaticFindObject(e.path)
            local okA, a = pcall(function() return o:GetAddress() end)
            if valid(o) and okA and a == e.addr then
                readEntry(e, o, now)
            else
                log("gone: " .. e.kind .. " " .. e.path)
                untrack(R.cursor)
                R.cursor = R.cursor - 1
                if #R.list == 0 then break end
            end
        end
    end
end

local function registerNotify(now)
    for _, k in ipairs(KINDS) do
        if not R.notified[k] then
            local cls = findObj(G.Classes[k], now)
            if cls then
                local kind = k
                -- 0.1.3: the place's own BeginPlay, on the game thread. 0.1.2 used NotifyOnNewObject,
                -- whose callback UE4SS runs on whatever thread creates the object (the loading thread
                -- during a level load), which could crash inside UE4SS (2026-11-06).
                local ok, err = pcall(RegisterHook, G.Classes[k] .. ":ReceiveBeginPlay", function(self)
                    local o = self:get()
                    if valid(o) then track(o, kind, os.clock()) end
                end)
                if ok then
                    R.notified[k] = true
                    if R.lastDraw > 0 then R.needSeed[k] = true end -- late: a world already exists
                    log("watching new " .. k .. " objects")
                else warn("could not watch " .. k .. ": " .. tostring(err)) end
            end
        end
    end
end

-- Context (4 Hz) -----------------------------------------------------------------------------
local function pawnKind(pawn)
    local a = pawn:GetAddress()
    if a ~= S.pawnAddr then
        S.pawnAddr = a
        local chain = classChain(pawn)
        S.pawnKind = chain[G.FootClass] and "foot" or (chain[G.BikeClass] and "bike" or nil)
        log("pawn " .. className(pawn) .. " -> " .. tostring(S.pawnKind))
    end
    return S.pawnKind
end

local function whereIsPlayer(hud)
    local pc = get(hud, "PlayerOwner")
    local gb = valid(pc) and get(pc, "GameBuilderRef") or nil
    if not valid(gb) then gb = get(hud, "DataBuilderRef") end
    if valid(gb) then
        local v = get(gb, "PlayerIsAt")
        if type(v) == "number" then return v end
    end
    local w = get(hud, "New Where")
    return type(w) == "number" and w or -1
end

local function tick(hud, now)
    S.show = {}
    S.mode = nil
    if verbose then -- debug only: toggle.txt in the mod folder switches the markers (tests without a keyboard)
        local f = io.open(DIR .. "toggle.txt", "r")
        if f then f:close(); os.remove(DIR .. "toggle.txt"); S.on = not S.on; log("toggled by file: " .. tostring(S.on)) end
    end
    local pawn = gameplayStatics():GetPlayerPawn(hud, 0)
    local hasPawn = valid(pawn)
    if R.gapAt then -- the HUD paused: a new pawn means a new level (loading a save)
        if hasPawn and pawn:GetAddress() ~= R.gapPawn then dropBefore(R.gapAt, true) end
        R.gapAt = nil
    end
    local kind = hasPawn and pawnKind(pawn) or nil
    local where = whereIsPlayer(hud)
    local atSurface = where == G.PlanetSurface
    local onSurface = kind ~= nil and atSurface
    local t0 = os.clock()
    maintain(now, where, onSurface)
    local dt = os.clock() - t0
    S.stats.scans, S.stats.scanTime = S.stats.scans + 1, S.stats.scanTime + dt
    if dt > S.stats.scanMax then S.stats.scanMax = dt end

    if not (S.on and onSurface) then return end
    if kind == "foot" and not cfg.OnFoot then return end
    if kind == "bike" and not cfg.OnHoverbike then return end
    if get(hud, "PhotoMode") == true or get(hud, "HideIndicators") == true or get(hud, "Any3d Widget On") == true then return end
    S.mode = kind
    local ts = get(hud, "Indicators_TextScale")
    S.textScale = (type(ts) == "number" and ts > 0.3) and ts or 1.0
    -- Assets the HUD's own bytecode references, so they stay loaded; looked up here, not per frame.
    local A = S.assets
    A.font = findObj(G.Assets.fontDF, now) or findObj(G.Assets.font, now)
    A.arrow = findObj(G.Assets.arrow, now)
    A.dot = findObj(G.Assets.dot, now)
    if not A.font then return end
    local pc = get(hud, "PlayerOwner")
    S.pcm = valid(pc) and get(pc, "PlayerCameraManager") or nil -- used by the frames until the next tick
    if not valid(S.pcm) then S.pcm = nil; return end

    local okL, pl = pcall(function() return pawn:K2_GetActorLocation() end)
    if not (okL and pl) then return end
    local px, py, pz = pl.X, pl.Y, pl.Z
    local hide = cfg.HideWithinMeters * 100
    local maxD, maxPoi = cfg.MaxDistance * 100, cfg.PoiMaxDistance * 100
    local objectives = {}
    for _, e in ipairs(R.list) do
        if e.kind == "objective" and e.x and e.readAt and not e.skip then objectives[#objectives + 1] = e end
    end
    local cand = {}
    local function consider(e, limit)
        if not (e.x and e.readAt) or e.skip then return end
        local dx, dy, dz = e.x - px, e.y - py, e.z - pz
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d < hide or d > limit then return end
        if kind == "bike" then -- the game draws these itself on the hoverbike
            if e.kind == "location" and e.active and d <= G.BikeQuestRange then return end
            if e.kind == "poi" and d >= G.BikePoiMin and d <= G.BikePoiMax then return end
        end
        for _, o in ipairs(objectives) do -- a mission marker of the game is already there
            local ox, oy, oz = e.x - o.x, e.y - o.y, e.z - o.z
            if ox * ox + oy * oy + oz * oz < 5000 * 5000 then return end
        end
        local quest = e.quest or e.active
        local name = (cfg.ShowNames and e.name ~= "") and e.name or nil
        local dist = distLabel(d)
        cand[#cand + 1] = {
            x = e.x, y = e.y, z = e.z + cfg.HeightOffset, d = d, quest = quest,
            col = quest and COL.quest or (e.cleared and COL.cleared or (e.kind == "poi" and COL.poi or COL.place)),
            name = name, dist = dist, label = name and (name .. "\n" .. dist) or dist,
        }
    end
    for _, e in ipairs(R.list) do
        if e.kind == "place" and cfg.Places then consider(e, maxD)
        elseif e.kind == "location" and cfg.Locations then consider(e, maxD)
        elseif e.kind == "poi" and cfg.PointsOfInterest then consider(e, maxPoi) end
    end
    table.sort(cand, function(a, b)
        if a.quest ~= b.quest then return a.quest end
        return a.d < b.d
    end)
    for i = 1, math.min(#cand, cfg.MaxMarkers) do S.show[i] = cand[i] end
end

-- Drawing (every frame) -------------------------------------------------------------------------
local PIVOT = { X = 0.5, Y = 0.5 }

local function drawText(hud, s, col, x, y, font, scale)
    hud:DrawText(s, col, x, y, font, scale, false)
end

-- Projection in plain Lua from the camera (3 engine calls per frame instead of one per marker).
-- UE rotation matrix axes; horizontal field of view (the engine's default aspect constraint).
local function cameraBasis(pcm)
    local L = pcm:GetCameraLocation()
    local Rt = pcm:GetCameraRotation()
    local fov = pcm:GetFOVAngle()
    local p, yw, r = math.rad(Rt.Pitch), math.rad(Rt.Yaw), math.rad(Rt.Roll)
    local SP, CP, SY, CY, SR, CR = math.sin(p), math.cos(p), math.sin(yw), math.cos(yw), math.sin(r), math.cos(r)
    return {
        lx = L.X, ly = L.Y, lz = L.Z,
        fx = CP * CY, fy = CP * SY, fz = SP,
        rx = SR * SP * CY - CR * SY, ry = SR * SP * SY + CR * CY, rz = -SR * CP,
        ux = -(CR * SP * CY + SR * SY), uy = CY * SR - CR * SP * SY, uz = CR * CP,
        t = math.tan(math.rad((fov > 1 and fov or 90) / 2)),
    }
end

-- Returns screen x, y, in front (bool), and the screen direction (dx, dy) from the centre.
local function project(c, m, w, h)
    local dx, dy, dz = m.x - c.lx, m.y - c.ly, m.z - c.lz
    local f = dx * c.fx + dy * c.fy + dz * c.fz
    local r = dx * c.rx + dy * c.ry + dz * c.rz
    local u = dx * c.ux + dy * c.uy + dz * c.uz
    local half = w / 2
    local focal = half / c.t
    if f > 1 then return half + r * focal / f, h / 2 - u * focal / f, true, r, -u end
    return nil, nil, false, r, -u
end

local function draw(hud, w, h)
    local A = S.assets
    local font, arrow, dot = A.font, A.arrow, A.dot
    local c = cameraBasis(S.pcm)
    local cx, cy = w / 2, h / 2
    local size = cfg.MarkerSize
    local scale = math.max(0.3, (S.textScale - 0.4) * cfg.TextScale)
    local arrows, placed = 0, {}
    for _, m in ipairs(S.show) do
        local x, y, front, ddx, ddy = project(c, m, w, h)
        if front and x >= 0 and x <= w and y >= 0 and y <= h then
            if dot then
                hud:DrawTexture(dot, x - size / 2, y - size / 2, size, size, 0, 0, 1, 1, m.col, 2, 1.0, false, 0, PIVOT)
            else
                hud:DrawRect(m.col, x - size / 4, y - size / 4, size / 2, size / 2)
            end
            drawText(hud, m.label, m.col, x + size / 2 + 6, y - (m.name and 14 or 7), font, scale)
        elseif cfg.OffscreenArrows and arrows < cfg.MaxOffscreenArrows and arrow then
            if math.abs(ddx) < 1 and math.abs(ddy) < 1 then ddy = 1 end
            local margin = 64
            local sx = math.abs(ddx) > 0.001 and (cx - margin) / math.abs(ddx) or 1e9
            local sy = math.abs(ddy) > 0.001 and (cy - margin) / math.abs(ddy) or 1e9
            local s = math.min(sx, sy)
            local ax, ay = cx + ddx * s, cy + ddy * s
            local free = true -- one arrow per spot: nearer places come first
            for _, q in ipairs(placed) do
                if math.abs(q[1] - ax) < 48 and math.abs(q[2] - ay) < 40 then free = false; break end
            end
            if free then
                arrows = arrows + 1
                placed[#placed + 1] = { ax, ay }
                local rot = math.deg(math.atan(ddy, ddx)) + 90
                hud:DrawTexture(arrow, ax - 16, ay - 16, 32, 32, 0, 0, 1, 1, m.col, 2, 0.7, false, rot, PIVOT)
                local len = math.sqrt(ddx * ddx + ddy * ddy)
                drawText(hud, m.dist, m.col, ax - ddx / len * 34 - 18, ay - ddy / len * 34 - 8, font, scale)
            end
        end
    end
    if verbose and not S.checkedProjection and S.show[1] and project(c, S.show[1], w, h) then -- once: compare with the engine
        S.checkedProjection = true
        local m = S.show[1]
        local x, y, front = project(c, m, w, h)
        local p = hud:Project({ X = m.x, Y = m.y, Z = m.z })
        log(string.format("projection check: lua %s %.0f,%.0f  engine %.0f,%.0f (z %.3f)", tostring(front), x or -1, y or -1, p.X, p.Y, p.Z))
    end
end

local function drawToast(hud, w, now)
    if not S.toast or now > S.toastUntil then S.toast = nil; return end
    local font = S.assets.font or findObj(G.Assets.font, now)
    if font then drawText(hud, S.toast, COL.toast, w / 2 - #S.toast * 6, 90, font, 0.8) end
end

-- The hook ----------------------------------------------------------------------------------
local function onDrawHUD(ctx, sx, sy)
    local now = os.clock()
    local hud = ctx:get()
    if not valid(hud) then return end
    -- A new HUD means a new level: forget older places. A pause in drawing may be one too (the
    -- next tick compares the pawn).
    local ha = hud:GetAddress()
    if ha ~= R.hudAddr then -- a new HUD = a new level: places from before its loading screen go
        dropBefore(R.lastDraw, false)
        -- and places of another level (the main menu's) go too, untouched
        local okF, full = pcall(function() return hud:GetFullName() end)
        local level = okF and type(full) == "string" and full:match("^%S+%s+(.-:PersistentLevel%.)") or nil
        if level then
            for i = #R.list, 1, -1 do
                if R.list[i].path:sub(1, #level) ~= level then untrack(i) end
            end
        end
        S.show, S.mode, S.pcm, S.nextTick = {}, nil, nil, 0
    elseif now - R.lastDraw > GAP then
        R.gapAt, R.gapPawn = R.lastDraw, S.pawnAddr
    end
    R.lastDraw, R.hudAddr = now, ha
    if now >= S.nextTick then
        S.nextTick = now + TICK
        local t0 = os.clock()
        local ok, err = pcall(tick, hud, now)
        if not ok then S.show = {}; S.mode = nil; S.errors = (S.errors or 0) + 1; if S.errors <= 5 then warn("tick: " .. tostring(err)) end end
        S.stats.ticks, S.stats.tickTime = S.stats.ticks + 1, S.stats.tickTime + (os.clock() - t0)
    end
    if not S.toast and (S.mode == nil or #S.show == 0) then return end
    local t0 = os.clock()
    local w, h = 1920, 1080
    pcall(function() w, h = sx:get(), sy:get() end)
    if S.mode and #S.show > 0 and S.pcm then
        local ok, err = pcall(draw, hud, w, h)
        if not ok then S.drawErrors = (S.drawErrors or 0) + 1; if S.drawErrors <= 5 then warn("draw: " .. tostring(err)) end end
    end
    pcall(drawToast, hud, w, now)
    local dt = os.clock() - t0
    local st = S.stats
    st.frames, st.drawTime = st.frames + 1, st.drawTime + dt
    if dt > st.drawMax then st.drawMax = dt end
    if verbose and now - st.since >= 10 then
        log(string.format("perf: %d frames drawn, draw avg %.3f ms max %.1f ms; %d ticks avg %.3f ms; %d scans avg %.2f ms max %.1f ms; mode %s, %d markers",
            st.frames, st.frames > 0 and st.drawTime / st.frames * 1000 or 0, st.drawMax * 1000,
            st.ticks, st.ticks > 0 and st.tickTime / st.ticks * 1000 or 0,
            st.scans, st.scans > 0 and st.scanTime / st.scans * 1000 or 0, st.scanMax * 1000, tostring(S.mode), #S.show))
        S.stats = { frames = 0, drawTime = 0, drawMax = 0, ticks = 0, tickTime = 0, scans = 0, scanTime = 0, scanMax = 0, since = now }
    end
end

-- Register the hook when the HUD class is loaded (again if it is reloaded).
local hudAddr, hudNext, hudWait = nil, 0, 1
local errors = 0
local function guarded(ctx, sx, sy)
    if errors >= 25 then return end
    local ok, err = pcall(onDrawHUD, ctx, sx, sy)
    if not ok then
        errors = errors + 1
        if errors <= 3 then warn("error: " .. tostring(err)) end
        if errors >= 25 then warn("switched off after repeated errors") end
    end
end
-- Once a second on the game thread, pumped by the ALS character tick (gametick.lua, 0.1.4). Until
-- 0.1.3 this was LoopAsync + ExecuteInGameThread: called from UE4SS's async thread,
-- ExecuteInGameThread writes a map all mods share without a lock, and two mods doing it at once
-- crashed the game (UE4SS.dll+0x87c104). After each load (ClientRestart) the pump hook is set again.
local GT = require("gametick")
GT.log = function(msg) warn(msg) end
GT.drive(GT.FOOT_TICK, "foot")
GT.boot()
GT.every(1.0, function(now)
    if now < hudNext then return end
    local c = StaticFindObject(G.HudClass)
    local a = valid(c) and c:GetAddress() or nil
    if a then
        hudNext, hudWait = now + 5, 1
        if a ~= hudAddr then
            local ok, err = pcall(RegisterHook, G.DrawHook, guarded)
            if ok then hudAddr = a; log("hooked " .. G.DrawHook) else warn("could not hook HUD: " .. tostring(err)) end
        end
        registerNotify(now) -- the place classes are referenced by the HUD, so they load with it
    else
        hudAddr = nil
        hudNext = now + hudWait
        hudWait = math.min(hudWait * 2, 16)
    end
end)

-- Optional toggle key (none by default; "0" is free in the game: no key preset, no raw key event) ------------------------------
-- Realism set key plan: the game's keys are refused with or without Shift, plain F3/F4 belong to
-- Silent Ops on foot, and Ctrl / Alt are game actions on foot (map, crouch). UE4SS matches
-- modifiers exactly, so plain 0 stays quiet while Shift is held (Shift+0 = Ammo Discipline, rule 3).
local GAME_KEYS = { F1 = 1, F2 = 1, F5 = 1, F6 = 1, F8 = 1, F10 = 1, F11 = 1, F12 = 1 }
local PLAIN_TAKEN = { F3 = "Silent Ops on foot", F4 = "Silent Ops on foot", I = "the game's cargo key", P = "a second Escape key in the game" }
local KEY_ALIAS = { INSERT = "INS", DELETE = "DEL", PAGEDOWN = "PAGE_DOWN", PAGEUP = "PAGE_UP", ESC = "ESCAPE",
    ["0"] = "ZERO", ["1"] = "ONE", ["2"] = "TWO", ["3"] = "THREE", ["4"] = "FOUR", ["5"] = "FIVE", ["6"] = "SIX",
    ["7"] = "SEVEN", ["8"] = "EIGHT", ["9"] = "NINE" }
local function bindToggle(spec)
    if type(spec) ~= "string" or spec:gsub("%s", "") == "" then return nil end
    local shift, key, bad = false, nil, nil
    for part in spec:upper():gsub("%s", ""):gmatch("[^+]+") do
        if part == "SHIFT" then shift = true
        elseif part == "CTRL" or part == "CONTROL" or part == "ALT" then bad = "Ctrl and Alt are game actions on foot"
        else key = KEY_ALIAS[part] or part end
    end
    if not bad and not (key and Key and Key[key]) then bad = "unknown key" end
    if not bad and GAME_KEYS[key] then bad = "the game uses " .. key end
    if not bad and not shift and PLAIN_TAKEN[key] then bad = "plain " .. key .. ": " .. PLAIN_TAKEN[key] end
    if not bad and shift and key == "ZERO" then bad = "Shift+0 belongs to Ammo Discipline" end
    if bad then warn("ToggleKey '" .. spec .. "' refused (" .. bad .. "); no key bound"); return nil end
    local function toggle()
        ExecuteInGameThread(function()
            S.on = not S.on
            S.nextTick = 0
            S.toast, S.toastUntil = "Ground Waypoints " .. (S.on and "ON" or "OFF"), os.clock() + 2
            log("toggled " .. (S.on and "on" or "off"))
        end)
    end
    if shift then RegisterKeyBind(Key[key], { ModifierKey.SHIFT }, toggle) else RegisterKeyBind(Key[key], toggle) end
    return (shift and "Shift+" or "") .. key
end
local bound = bindToggle(cfg.ToggleKey)

warn(string.format("=== Ground Waypoints %s loaded: %s, toggle key %s ===", VERSION, S.on and "ON" or "OFF", bound or "none"))
