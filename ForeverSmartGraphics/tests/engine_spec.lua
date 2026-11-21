-- Stubbed checks of the engine (Core, Catalog, Profiles, Location, Apply): lua tests/engine_spec.lua
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local harness = dofile(here .. "/wow.lua")
local function new(opts) return harness(here .. "/..", opts) end
local function near(a, b) return a and b and math.abs(a - b) < 1e-6 end

-- db: fresh install.
local W = new()
W.login()
local ns, db = W.ns, W.ns.db
assert(db.version == 1 and ForeverSmartGraphicsDB == db and not W.said("repaired"))
assert(db.options.switching == true and db.options.debug == false)
for _, key in ipairs({ "announce", "suggest", "smartNotice", "notifyProfile", "chatLog", "chatLogSmart" }) do assert(db.options[key] == false, key .. " off by default") end
assert(W.said("Smart Graphics|r is ready%. Type /fsg to open it%."), "first install greets once")
assert(db.options.minimap.shown == true and db.options.minimap.angle == 200)
assert(db.original.graphicsShadowQuality == "3" and db.original.RenderScale == "0.75" and db.original.useTargetFPS == "1", "original captured")
assert(db.profiles.default.name == "Default" and db.profileOrder[1] == "default" and db.nextId == 1)
assert(next(db.locations) == nil and next(db.overrides) == nil and next(db.unsupported) == nil)
assert(db.smart.enabled == false and db.smart.target == 60 and db.smart.scaleFloor == 0.75 and db.migrations == nil)
assert(#W.writes == 0, "Default with no values writes nothing")

-- db: the original is never rewritten; a damaged db is repaired.
local log = {}
for i = 1, 600 do log[i] = "line " .. i end
W = new({ cvars = { graphicsShadowQuality = "1" }, db = {
	version = 1,
	options = { switching = "yes", announce = false, debug = "on", minimap = { shown = 1, angle = 0 / 0 }, calibratePos = { point = "TOP", x = "a", y = 1 } },
	original = { graphicsShadowQuality = "4", junk = 5 },
	profiles = {
		default = { name = "Mine", values = { RenderScale = 0.77, gxapi = 1, bogus = 3, shadowSoft = "1" } },
		p3 = { name = "  City  ", values = { graphicsSSAO = 99 } },
		p9 = "broken",
		[5] = {},
	},
	profileOrder = { "p3", "gone", "p3" },
	nextId = 2,
	locations = { city = "p3", raid = "gone", dungeon = "default", nowhere = "p3", delve = "p3", scenario = "p3", housing = "p3" },
	overrides = { ["map:84"] = { profile = "p3", name = "Stormwind City" }, ["map:85"] = { profile = "gone" }, bad = { profile = "p3" } },
	smart = { enabled = "x", target = 999, scaleFloor = 0.1, 		areas = { ["map:84"] = { anything = 1 }, broken = 7 }, gains = { RenderScale = { ema = 4, n = 1 }, shadowSoft = "x" } },
	limits = { shadowTextureSize = 2048, gxapi = 1, sunShafts = 0 / 0, lodObjectFadeScale = 90 },
	limitSides = { lodObjectFadeScale = "min" },
	unsupported = { vrsValar = true, gxapi = true, ffxglow = "yes" },
	debugLog = log,
	keep = "other",
} })
W.login()
ns, db = W.ns, W.ns.db
local default, city = db.profiles.default, db.profiles.p3
assert(W.said("repaired %d+ damaged saved settings"))
assert(db.options.switching == true and db.options.announce == false and db.options.debug == false)
assert(db.options.minimap.shown == true and db.options.minimap.angle == 200)
assert(db.original.graphicsShadowQuality == "4" and db.original.RenderScale == "0.75", "kept, gaps filled")
assert(default.name == "Default" and near(default.values.RenderScale, 0.75) and default.values.shadowSoft == 1)
assert(default.values.gxapi == nil and default.values.bogus == nil, "NEVER and unknown cvars dropped")
assert(city.name == "City" and city.values.graphicsSSAO == 4, "trimmed, clamped")
assert(db.profiles.p9 == nil and db.profiles[5] == nil)
assert(W.same(db.profileOrder, { "default", "p3" }) and db.nextId == 4, "order rebuilt, nextId above p3")
assert(W.same(db.locations, { city = "p3" }), "unknown ids, removed keys (delve/scenario/housing) gone, default stored as nil")
assert(db.overrides["map:84"].profile == "p3" and db.overrides["map:85"] == nil and db.overrides.bad == nil)
assert(db.smart.enabled == false and db.smart.target == 60 and db.smart.scaleFloor == 0.75)
assert(db.options.calibratePos == nil and W.same(db.smart.areas, { ["map:84"] = { anything = 1 } }) and W.same(db.smart.gains, { RenderScale = { ema = 4, n = 1 } }))
assert(next(db.limits) == nil and next(db.limitSides) == nil and next(db.unsupported) == nil, "machine limits are found again every session")
assert(W.ns.Catalog.Clamp("shadowTextureSize", 4096) == 4096 and W.ns.Catalog.Clamp("lodObjectFadeScale", 45) == 45)
assert(#db.debugLog == 500 and db.debugLog[1] == "line 101" and db.keep == "other")

W = new({ db = { options = { calibratePos = { point = "CENTER", x = 10, y = -20 } } } })
W.login()
assert(W.same(W.ns.db.options.calibratePos, { point = "CENTER", x = 10, y = -20 }) and next(W.ns.db.limits) == nil and next(W.ns.db.smart.areas) == nil)

-- db: not a table, newer version, odd versions.
W = new({ db = "garbage" })
W.login()
assert(W.ns.db.version == 1 and W.ns.db.profiles.default)
W = new({ db = { version = 9 } })
W.login()
assert(W.ns.db.version == 9 and W.said("newer version of Smart Graphics") and W.ns.db.profiles.default)
for _, version in ipairs({ 0, -3, 1.5, 0 / 0, math.huge }) do
	W = new({ db = { version = version, options = {} } })
	W.login()
	assert(W.ns.db.version == 1, "version " .. tostring(version))
end

-- Catalog.
W = new()
W.login()
ns = W.ns
local C = ns.Catalog
assert(#C.LIST == 39 and C.LIST[1].group == "quality" and C.Get("rENDERsCALE").cvar == "RenderScale")
local quality, rank, last = 0, { quality = 1, render = 2, hidden = 3 }, 1
for _, entry in ipairs(C.LIST) do
	if entry.group == "quality" then quality = quality + 1 end
	assert(rank[entry.group] >= last, "groups in order: " .. entry.cvar)
	last = rank[entry.group]
end
assert(quality == 15)
for _, cvar in ipairs({ "graphicsTextureResolution", "textureFilteringMode", "shadowTextureSize" }) do assert(C.Get(cvar).heavy) end
assert(C.Get("RenderScale").smart and C.Get("sunShafts").smart and not C.Get("graphicsTextureResolution").smart)
assert(C.PRIOR.RenderScale == 6 and C.PRIOR.shadowSoft == 11 and C.PRIOR.graphicsViewDistance == 0.5)
assert(C.NEVER.gxapi and C.NEVER.msaaquality and C.Get("gxApi") == nil and C.Clamp("MSAAQuality", 1) == nil and C.Clamp("nothing", 1) == nil)
assert(C.Clamp("RenderScale", 0.77) == 0.75 and C.Clamp("RenderScale", 0.1) == 0.35 and C.Clamp("RenderScale", 1.5) == 1.5)
assert(C.Clamp("groundEffectDensity", 0) == 16 and C.Clamp("groundEffectDensity", 70) == 64 and C.Clamp("graphicsSSAO", 9) == 4)
assert(C.Clamp("shadowTextureSize", 1900) == 2048 and C.Clamp("graphicsParticleDensity", 0) == 1 and C.Clamp("shadowSoft", 0 / 0) == nil)
assert(C.Step("RenderScale", 0.75, -1) == 0.7 and C.Step("RenderScale", 0.35, -1) == nil)
assert(C.Step("graphicsSSAO", 0, -1) == nil and C.Step("graphicsSSAO", 3, 1) == 4)
assert(C.Step("shadowTextureSize", 2048, 1) == 4096 and C.Step("shadowTextureSize", 512, -1) == nil and C.Step("shadowTextureSize", 2048, -1) == 1536)
assert(C.Format("RenderScale", 0.75) == "75%" and C.Format("shadowSoft", 1) == "On" and C.Format("graphicsShadowQuality", 0) == "Low")
assert(C.Format("graphicsViewDistance", 5) == "5" and C.Format("shadowTextureSize", 2048) == "2048")
assert(select(2, C.Range("RenderScale")) == 2, "render scale up to the game's 2.0")
assert(C.Clamp("RenderScale", 1.33) == 1.35 and C.Clamp("RenderScale", 2.5) == 2 and C.Step("RenderScale", 1, 1) == 1.05 and C.Step("RenderScale", 2, 1) == nil)
assert(C.Format("RenderScale", 1.35) == "135%")
assert(C.Get("MSAAQuality") == nil and C.Get("msaaquality") == nil, "MSAA stays out: it needs a restart")

-- Anti-aliasing: only the modes the card supports.
local aa = C.Get("ffxAntiAliasingMode")
assert(aa.kind == "choice" and aa.group == "render" and not aa.smart and not aa.heavy and aa.desc and aa.impact == "low")
assert(W.same(aa.choices, { 0, 1, 2, 3, 4 }) and W.same({ C.Range("ffxAntiAliasingMode") }, { 0, 4 }))
assert(C.Format("ffxAntiAliasingMode", 0) == "None" and C.Format("ffxAntiAliasingMode", 2) == "FXAA High" and C.Format("ffxAntiAliasingMode", 4) == "CMAA 2")
assert(C.Step("ffxAntiAliasingMode", 2, 1) == 3 and C.Step("ffxAntiAliasingMode", 2, -1) == 1)
assert(C.Step("ffxAntiAliasingMode", 4, 1) == nil and C.Step("ffxAntiAliasingMode", 0, -1) == nil)
for _, build in ipairs({ "low", "ultra", "beyond", "fps" }) do assert(C.BuildPreset(build).ffxAntiAliasingMode == nil, "no preset sets AA: " .. build) end
local noCmaa = new({ aa = { true, false, false } }).ns.Catalog
assert(W.same(noCmaa.Get("ffxAntiAliasingMode").choices, { 0, 1, 2 }) and noCmaa.Clamp("ffxAntiAliasingMode", 3) == 2 and noCmaa.Clamp("ffxAntiAliasingMode", 4) == 2)
assert(noCmaa.Step("ffxAntiAliasingMode", 2, 1) == nil, "CMAA missing: FXAA High is the top")
local cmaaOnly = new({ aa = { false, true, false } }).ns.Catalog
assert(W.same(cmaaOnly.Get("ffxAntiAliasingMode").choices, { 0, 3 }) and cmaaOnly.Step("ffxAntiAliasingMode", 0, 1) == 3)
local noApi = new({ aa = false }).ns.Catalog
assert(W.same(noApi.Get("ffxAntiAliasingMode").choices, { 0, 1, 2 }) and select(2, noApi.Range("ffxAntiAliasingMode")) == 2)
local capped = new({ maxScale = 1.5 }).ns.Catalog
assert(select(2, capped.Range("RenderScale")) == 1.5 and capped.Clamp("RenderScale", 1.8) == 1.5, "the game's lower max caps the range")

-- Presets: the game's quality table, or a straight line without it.
local low = C.BuildPreset("low")
assert(low.RenderScale == 1 and low.graphicsSSAO == C.Clamp("graphicsSSAO", 4 * 1 / 9) and low.graphicsParticleDensity >= 1)
local beyond, fps = C.BuildPreset("beyond"), C.BuildPreset("fps")
local BEYOND = {
	graphicsShadowQuality = 5, graphicsLightMode = 3, graphicsSSAO = 4, graphicsComputeEffects = 4, graphicsLiquidDetail = 3, graphicsPBRLiquidDetail = 2,
	graphicsParticleDensity = 5, graphicsOutlineMode = 2, graphicsSpellDensity = 2, graphicsViewDistance = 9, graphicsEnvironmentDetail = 9,
	graphicsGroundClutter = 9, graphicsTextureResolution = 2, RenderScale = 1, groundEffectDensity = 256, groundEffectDist = 400, groundEffectFade = 300,
	lodObjectCullSize = 8, lodObjectFadeScale = 200, terrainLodDist = 1000, wmoLodDist = 800, horizonStart = 4000, doodadLodScale = 200,
	shadowTextureSize = 2048, shadowNumCascades = 4, assaoBlurPassCount = 3, ResampleAlwaysSharpen = 1, reflectionMode = 3, shadowSoft = 1, sunShafts = 2,
}
for cvar, value in pairs(BEYOND) do assert(beyond[cvar] == value, "beyond " .. cvar) end
assert(C.BuildPreset("fidelity") == nil and C.PRESETS[6].key == "beyond" and C.PRESETS[6].name == "Beyond Ultra" and C.PRESETS[7].key == "fps")
assert(C.Get("doodadLodScale").step == 25 and C.Get("shadowNumCascades").min == 1 and not C.Get("shadowNumCascades").heavy and not C.Get("ResampleAlwaysSharpen").smart)
assert(fps.RenderScale == 0.6 and fps.shadowSoft == 0 and fps.graphicsShadowQuality == low.graphicsShadowQuality)
assert(#C.PRESETS == 7 and C.BuildPreset("nope") == nil)
W = new({ levels = { graphicsSSAO = { [1] = 1, [9] = 4 }, graphicsShadowQuality = { [1] = 9 } } })
W.login()
local preset = W.ns.Catalog.BuildPreset("low")
assert(preset.graphicsSSAO == 1 and preset.graphicsShadowQuality == 5, "game values, clamped")

-- Profiles.
W = new()
W.login()
ns, db = W.ns, W.ns.db
local P = ns.Profiles
local changes = 0
ns.On("FSG_PROFILES_CHANGED", function() changes = changes + 1 end)
local a = P.Create("City", { graphicsSSAO = 1, gxapi = 2, RenderScale = 0.52 })
local b = P.Create("city", {})
local long = P.Create(string.rep("x", 40), {})
assert(a == "p1" and b == "p2" and P.Get(a).values.gxapi == nil and P.Get(a).values.RenderScale == 0.5)
assert(P.Get(b).name == "city 2" and #P.Get(long).name == 32 and changes == 3)
assert(P.List()[1].id == "default" and P.List()[2].name == "City" and #P.List() == 4)
assert(P.Rename(a, "  Town ") == "Town" and P.Rename(b, "town") == "town 2" and P.Rename("default", "X") == nil and P.Rename(a, "   ") == nil)
local copy = P.Copy(a)
assert(P.Get(copy).name == "Town copy" and P.Get(copy).values.graphicsSSAO == 1)
local fromPreset, fromCurrent = P.FromPreset("fps"), P.FromCurrent()
assert(P.Get(fromPreset).name == "Max FPS" and P.Get(fromPreset).values.RenderScale == 0.6)
assert(P.Get(fromCurrent).name == "My settings" and P.Get(fromCurrent).values.graphicsShadowQuality == 3 and P.Get(fromCurrent).values.RenderScale == 0.75)
assert(P.SetValue("default", "graphicsViewDistance", 7) and P.SetValue(a, "shadowSoft", 1) and not P.SetValue(a, "gxapi", 1) and not P.SetValue("nope", "shadowSoft", 1))
local value, source = P.Inherited(a, "graphicsViewDistance")
assert(value == 7 and source == "Default")
value, source = P.Inherited(a, "graphicsLightMode")
assert(value == 1 and source == "your original")
value, source = P.Inherited("default", "graphicsViewDistance")
assert(value == 5 and source == "your original")
local effective = P.Effective(a)
assert(effective.graphicsViewDistance == 7 and effective.graphicsSSAO == 1 and effective.shadowSoft == 1 and effective.graphicsLightMode == 1 and effective.RenderScale == 0.5)
assert(P.Effective("missing").graphicsSSAO == 3, "unknown id = Default")
assert(P.SetValue(a, "shadowSoft", nil) and P.Get(a).values.shadowSoft == nil)
assert(P.Sets(a, "graphicsViewDistance") and P.Sets(a, "graphicsSSAO") and not P.Sets(a, "shadowSoft"))
assert(P.Assign("city", a) and P.Assign("raid", "default") and db.locations.raid == nil and not P.Assign("moon", a) and not P.Assign("city", "nope"))
assert(P.SetOverride("map:84", " Stormwind City ", a) and db.overrides["map:84"].name == "Stormwind City" and not P.SetOverride("zone:1", "x", a))
assert(P.SetOverride("instance:2652", "", copy) and db.overrides["instance:2652"].name == "instance:2652")
assert(P.Delete(a) and db.locations.city == nil and db.overrides["map:84"] == nil and db.overrides["instance:2652"])
assert(not P.Delete("default") and not P.Delete(a) and db.profileOrder[2] == b)
assert(P.AssignAll(copy) and db.locations.outdoor == copy and db.locations.arena == copy and db.locations.housing == nil and db.overrides["instance:2652"].profile == copy)
assert(P.RemoveOverride("instance:2652") and not P.RemoveOverride("instance:2652"))
assert(P.FindByName(" TOWN copy ") == copy)

-- Location: every instance type, resting, override keys, names.
W = new()
local seen = {}
W.ns.On("FSG_LOCATION", function(loc, prev, loading) seen[#seen + 1] = { loc = loc, prev = prev, loading = loading } end)
W.login()
local L = W.ns.Location
assert(#seen == 1 and seen[1].loc.key == "outdoor" and seen[1].loc.overrideKey == "map:1412" and seen[1].loc.name == "Mulgore" and seen[1].loading, "once after login")
local cases = {
	{ { "Halls", "party", 2, "", 5, 0, false, 600 }, "dungeon" },
	{ { "Nerub-ar", "raid", 14, "", 30, 0, false, 2657 }, "raid" },
	{ { "Warsong", "pvp", 0, "", 10, 0, false, 489 }, "battleground" },
	{ { "Nagrand", "arena", 0, "", 6, 0, false, 1505 }, "arena" },
	{ { "Fungal Folly", "scenario", 208, "", 5, 0, false, 2664 }, "dungeon" },
	{ { "Island", "scenario", 38, "", 3, 0, false, 1000 }, "dungeon" },
	{ { "Plot", "neighborhood", 0, "", 40, 0, false, 2735 }, "city" },
	{ { "House", "interior", 0, "", 40, 0, false, 2736 }, "city" },
}
for _, case in ipairs(cases) do
	W.instance = case[1]
	local loc = L.Read()
	assert(loc.key == case[2] and loc.overrideKey == "instance:" .. case[1][8] and loc.name == case[1][1] and loc.difficultyID == case[1][3], case[2])
end
W.instance = { "", "none", 0, "", 0, 0, false, 0 }
W.resting, W.mapID, W.zone = true, 84, "Stormwind City"
assert(L.Read().key == "city" and L.Read().overrideKey == "map:84" and L.Read().name == "Stormwind City")
W.zone, W.subzone = "", "Trade District"
assert(L.Read().name == "Trade District")
W.zone, W.subzone = "Stormwind City", ""

-- Debounce: a burst of events gives one message, 0.3 s after the last one; no change gives none. Open world to city
-- without a loading screen (an inn) counts only after 3 s; stepping back out within them gives nothing.
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(0.2)
W.fire("PLAYER_UPDATE_RESTING")
W.run(0.2)
assert(#seen == 1, "still waiting")
W.run(2)
assert(#seen == 1, "city: waits 3 s")
W.resting = false
W.fire("PLAYER_UPDATE_RESTING")
W.run(4)
assert(seen[#seen].loc.key == "outdoor" and L.Current().key == "outdoor", "a step in and out: never city")
seen = { seen[1] }
W.resting = true
W.fire("PLAYER_UPDATE_RESTING")
W.run(3.5)
assert(#seen == 2 and seen[2].loc.key == "city" and seen[2].prev.key == "outdoor" and not seen[2].loading)
W.fire("ZONE_CHANGED")
W.run(0.5)
assert(#seen == 2, "same place: nothing")
W.mapID = 85
W.fire("ZONE_CHANGED_INDOORS")
W.run(0.5)
assert(#seen == 3 and seen[3].loc.overrideKey == "map:85" and L.Current().mapID == 85, "same type, new place")

-- ProfileFor: place, then type, then Default; a deleted profile falls through.
local P2 = W.ns.Profiles
local typeId, placeId = P2.Create("Cities", {}), P2.Create("Orgrimmar", {})
assert(select(2, L.ProfileFor()) == "default")
P2.Assign("city", typeId)
assert(L.ProfileFor() == typeId and select(2, L.ProfileFor()) == "type")
P2.SetOverride("map:85", "Orgrimmar", placeId)
assert(L.ProfileFor() == placeId and select(2, L.ProfileFor()) == "place")
W.ns.db.overrides["map:85"].profile = "gone"
assert(L.ProfileFor() == typeId)

-- Apply: order; the player's own edit writes heavy settings at once; any other heavy change counts down (announce on),
-- pauses in combat; a loading screen writes it at once.
W = new()
W.login()
ns, db = W.ns, W.ns.db
db.options.announce = true
P, C = ns.Profiles, ns.Catalog
local pend = {}
ns.On("FSG_PENDING", function(info) pend[#pend + 1] = info and info.seconds or false end)
W.run(4)
W.clearWrites()
local id = P.Create("Busy", { graphicsShadowQuality = 1, shadowSoft = 1, RenderScale = 0.6, graphicsTextureResolution = 0, shadowTextureSize = 1024 })
-- A preset rewrites an engine cvar, like the game: the hidden override written after it must win.
W.cascade.graphicsShadowQuality = function() W.cvars.shadowSoft = "0" end
P.Assign("outdoor", id)
local q, r, h = W.wrote("graphicsShadowQuality"), W.wrote("RenderScale"), W.wrote("shadowSoft")
assert(q and r and h and q < r and r < h, "quality, render, hidden")
assert(W.cvars.shadowSoft == "1" and W.cvars.RenderScale == "0.6")
assert(W.cvars.graphicsTextureResolution == "0" and W.cvars.shadowTextureSize == "1024" and ns.Apply.Pending() == nil and #pend == 0, "the player's own edit: heavy at once")
assert(not W.wrote("groundEffectDensity"), "hidden cvars no profile sets are left to the presets")
-- Walking into a place with its own profile (no loading screen) is not the player's edit: the heavy part waits.
local spot = P.Create("Spot", { graphicsTextureResolution = 2, shadowTextureSize = 2048 })
P.SetOverride("map:1413", "Spot", spot)
W.mapID = 1413
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(0.4)
local info = ns.Apply.Pending()
assert(info and info.seconds == 10 and info.values.graphicsTextureResolution == 2 and info.values.shadowTextureSize == 2048 and not info.waitingCombat and not info.quiet)
assert(W.cvars.graphicsTextureResolution == "0", "waits")
ns.Apply.Refresh("location")
assert(ns.Apply.Pending().seconds == 10 and #pend == 1, "same heavy change keeps its countdown")
W.run(3.05)
assert(ns.Apply.Pending().seconds == 7 and pend[#pend] == 7)
W.setCombat(true)
assert(ns.Apply.Pending().waitingCombat)
W.run(5)
assert(ns.Apply.Pending().seconds == 7 and W.cvars.graphicsTextureResolution == "0", "paused in combat")
W.setCombat(false)
assert(ns.Apply.Pending().seconds == 10 and not ns.Apply.Pending().waitingCombat, "countdown restarts")
W.run(10.05)
assert(ns.Apply.Pending() == nil and W.cvars.graphicsTextureResolution == "2" and W.cvars.shadowTextureSize == "2048" and pend[#pend] == false)
assert(W.liveTickers() == 0)

-- Apply now, in combat too, ignores any argument; /fsg applynow; a newer change replaces the old.
db.profiles[spot].values.textureFilteringMode = 2
ns.Apply.Refresh("location")
assert(ns.Apply.Pending().values.textureFilteringMode == 2)
db.profiles[spot].values.textureFilteringMode = 3
ns.Apply.Refresh("location")
assert(ns.Apply.Pending().values.textureFilteringMode == 3 and ns.Apply.Pending().seconds == 10)
W.setCombat(true)
local applied
ns.On("FSG_CHANGES", function(batch) applied = batch end)
ns.Apply.ApplyPending("user", { user = true })
W.run(0.1)
assert(W.cvars.textureFilteringMode == "3" and ns.Apply.Pending() == nil and applied.source == "apply" and applied.reason == "Apply now", "the argument is ignored")
W.setCombat(false)
W.slash("applynow")
assert(W.said("nothing is waiting"))

-- Announce off: the change is still kept (quiet, no countdown, no ticks); applynow and status see it; a loading
-- screen writes it at once.
db.options.announce = false
db.profiles[spot].values.graphicsTextureResolution = 1
pend = {}
ns.Apply.Refresh("location")
info = ns.Apply.Pending()
assert(info and info.quiet and info.seconds == 600 and W.cvars.graphicsTextureResolution == "2" and #pend == 1 and W.liveTickers() == 0)
W.run(5)
assert(#pend == 1 and ns.Apply.Pending().seconds <= 596 and ns.Apply.Pending().seconds >= 594, "no per-second messages; seconds left counts down")
W.lines = {}
W.slash("status")
assert(W.said("texture change waiting 59%d s"))
W.fire("PLAYER_ENTERING_WORLD", false, false)
W.run(1)
assert(W.cvars.graphicsTextureResolution == "1" and ns.Apply.Pending() == nil and pend[#pend] == false, "loading screen")
db.profiles[spot].values.graphicsTextureResolution = 0
ns.Apply.Refresh("location")
W.slash("applynow")
assert(W.cvars.graphicsTextureResolution == "0" and ns.Apply.Pending() == nil, "applynow applies a quiet change")
db.options.announce = true
db.overrides["map:1413"] = nil
W.mapID = 1412
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(0.5)
ns.Apply.ApplyPending()

-- A heavy change from a location change during a loading screen is written at once.
W.run(4)
local raid = P.Create("Raid", { graphicsTextureResolution = 2 })
P.Assign("raid", raid)
assert(ns.Apply.Pending() == nil and W.cvars.graphicsTextureResolution == "0", "not the current location")
W.instance = { "Nerub-ar", "raid", 14, "", 30, 0, false, 2657 }
W.fire("PLAYER_ENTERING_WORLD", false, false)
W.run(1)
assert(W.cvars.graphicsTextureResolution == "2" and ns.Apply.Pending() == nil and ns.Apply.Active().profileId == raid and ns.Apply.Active().loc.key == "raid")

-- A hidden override no profile wants any more goes back to the original.
W.instance = { "", "none", 0, "", 0, 0, false, 0 }
P.Assign("outdoor", nil)
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(0.5)
assert(W.cvars.shadowSoft == "0" and W.cvars.RenderScale == "0.75" and W.cvars.graphicsShadowQuality == "3", "back on Default = original")

-- Readback: a clamped write records this machine's limit and caps later values; it is not "unsupported".
local limited = {}
ns.On("FSG_LIMIT", function(cvar, value) limited[#limited + 1] = cvar .. "=" .. value end)
W.clamp.sunShafts, W.cvars.sunShafts = 1, "0"
local ok, readback = ns.Apply.Write("sunShafts", 2)
assert(not ok and readback == 1 and db.limits.sunShafts == 1 and db.limitSides.sunShafts == "max" and limited[1] == "sunShafts=1")
assert(C.Clamp("sunShafts", 2) == 1 and C.Step("sunShafts", 1, 1) == nil and C.Step("sunShafts", 1, -1) == 0)
ns.Apply.Write("sunShafts", 0)
W.clearWrites()
P.SetValue("default", "sunShafts", 2)
assert(W.cvars.sunShafts == "1" and P.Effective("default").sunShafts == 1, "capped write")
assert(not ns.Apply.Write("sunShafts", 2) and not db.unsupported.sunShafts, "clamped again: still not unsupported")
W.clamp.shadowTextureSize, W.cvars.shadowTextureSize = 2048, "1024"
P.SetValue("default", "shadowTextureSize", 4096)
ns.Apply.ApplyPending()
assert(db.limits.shadowTextureSize == 2048 and db.limitSides.shadowTextureSize == "max" and C.Clamp("shadowTextureSize", 4096) == 2048 and C.Step("shadowTextureSize", 2048, 1) == nil)

-- The client's own float grid is not a limit: 0.75 stored as 0.7533 is a good write and needs no rewrite.
W.cvars.RenderScale, W.ignore.RenderScale = "0.6", "0.7533"
ok, readback = ns.Apply.Write("RenderScale", 0.75)
assert(ok and readback == 0.7533 and not db.limits.RenderScale and C.Clamp("RenderScale", 0.6) == 0.6)
assert(C.Same("RenderScale", 0.7533, 0.75) and not C.Same("RenderScale", 0.7, 0.75) and C.Same("shadowTextureSize", 2000, 2048))
W.clearWrites()
P.SetValue("default", "RenderScale", 0.75)
assert(not W.wrote("RenderScale"), "within half a step: not rewritten")
-- Less than a full step off, or a RenderScale reading below 0.5: no limit either.
W.ignore.RenderScale = "0.72"
assert(not ns.Apply.Write("RenderScale", 0.75) and not db.limits.RenderScale)
W.ignore.RenderScale = "0.4"
assert(not ns.Apply.Write("RenderScale", 0.75) and not db.limits.RenderScale)
W.ignore.RenderScale = "0.6"
assert(not ns.Apply.Write("RenderScale", 0.75) and db.limits.RenderScale == 0.6 and db.limitSides.RenderScale == "max", "a real cap inside 0.5..max")
W.ignore.RenderScale, db.limits.RenderScale, db.limitSides.RenderScale = nil, nil, nil

-- Readback: a refused write that stays at a legal value is a limit on that side, never "unsupported".
W.ignore.vrsValar = "0"
ok, readback = ns.Apply.Write("vrsValar", 2)
assert(not ok and readback == 0 and db.limits.vrsValar == 0 and db.limitSides.vrsValar == "max")
assert(not ns.Apply.Write("vrsValar", 2) and not db.unsupported.vrsValar, "refused twice: still a limit")
W.ignore.vrsValar, db.limits.vrsValar, db.limitSides.vrsValar = nil, nil, nil
W.ignore.lodObjectFadeScale, W.cvars.lodObjectFadeScale = "90", "90"
assert(not ns.Apply.Write("lodObjectFadeScale", 45) and db.limits.lodObjectFadeScale == 90 and db.limitSides.lodObjectFadeScale == "min", "kept at 90: a minimum")
W.ignore.lodObjectFadeScale, db.limits.lodObjectFadeScale, db.limitSides.lodObjectFadeScale = nil, nil, nil
-- A value the game can't read back, twice in a row: unsupported, skipped afterwards. A good write in between resets the count.
local unsupported = {}
ns.On("FSG_UNSUPPORTED", function(cvar) unsupported[#unsupported + 1] = cvar end)
W.ignore.vrsValar = "x"
assert(not ns.Apply.Write("vrsValar", 2) and not db.unsupported.vrsValar)
W.ignore.vrsValar = nil
assert(ns.Apply.Write("vrsValar", 1))
W.ignore.vrsValar = "x"
assert(not ns.Apply.Write("vrsValar", 2) and not db.unsupported.vrsValar, "the good write cleared the miss")
assert(not ns.Apply.Write("vrsValar", 1) and db.unsupported.vrsValar and unsupported[1] == "vrsValar")
P.SetValue("default", "vrsValar", 2)
W.clearWrites()
P.SetValue("default", "graphicsSSAO", 2)
assert(not W.wrote("vrsValar") and W.cvars.graphicsSSAO == "2", "unsupported skipped")
assert(not ns.Apply.Write("gxapi", 1) and not ns.Apply.Write("MSAAQUALITY", 1) and not W.wrote("gxapi"), "NEVER refused")

-- Switching off: nothing is written. Restore puts every original back.
local switches = 0
ns.On("FSG_SWITCHING", function() switches = switches + 1 end)
ns.Apply.SetSwitching(false)
ns.Apply.SetSwitching(false)
assert(switches == 1, "fires only on a change")
W.clearWrites()
P.SetValue("default", "graphicsSSAO", 0)
assert(#W.writes == 0)
ns.Apply.SetSwitching(true)
assert(W.cvars.graphicsSSAO == "0")
local switched
ns.On("FSG_SWITCHING", function(on) switched = on end)
W.slash("use Raid")
assert(W.cvars.graphicsTextureResolution == "2" or ns.Apply.Pending(), "Raid everywhere")
assert(db.locations.city == raid and db.locations.outdoor == raid)
W.slash("restore")
assert(switched == false and db.options.switching == false and db.smart.enabled == false and ns.Apply.Pending() == nil)
for _, entry in ipairs(C.LIST) do
	local cvar = entry.cvar
	assert(cvar == "vrsValar" or tonumber(W.cvars[cvar]) == tonumber(db.original[cvar]), "restored " .. cvar)
end
assert(W.cvars.useTargetFPS == "1")

-- Smart (stub): its Adjust feeds the target; useTargetFPS is 0 while on and back when off.
W = new()
local smart = { on = false }
W.ns.Smart = {
	Enabled = function() return smart.on end,
	SetEnabled = function(on) smart.on = on W.ns.Fire("FSG_SMART", {}) end,
	State = function() return { status = smart.on and "holding" or "off" } end,
	Adjust = function(locKey, values)
		smart.key = locKey
		local out = W.copy(values)
		out.RenderScale = 0.6
		return out
	end,
}
W.login()
W.run(4)
W.ns.Smart.SetEnabled(true)
assert(smart.key == "outdoor" and W.cvars.RenderScale == "0.6" and W.cvars.useTargetFPS == "0")
W.slash("status")
assert(W.said("Mulgore · Open world: Default %(Default%) · smart holding · 60 fps"))
W.ns.Smart.SetEnabled(false)
assert(W.cvars.RenderScale == "0.75" and W.cvars.useTargetFPS == "1")

-- Slash: help, unknown words, the window stub, debug ring.
W.slash("")
assert(W.said("window not loaded"))
W.slash("whatever")
assert(W.said("/fsg opens the window"))
W.slash("debug on")
assert(W.ns.db.options.debug)
for i = 1, 600 do W.ns.debug("n %d", i) end
assert(#W.ns.db.debugLog == 500)
W.fire("PLAYER_LOGOUT")
assert(W.ns.db.debugLog[500]:find("n 600") and W.ns.db.debugLog[1]:find("n 101"), "unrolled in order")
W.slash("selftest")
assert(W.said("selftest: 39 of 39 settings readable"))
W.fire("ADDON_ACTION_BLOCKED", "ForeverSmartGraphics", "SetCVar")
W.fire("ADDON_ACTION_BLOCKED", "ForeverSmartGraphics", "SetCVar")
local blocked = 0
for _, line in ipairs(W.lines) do if line:find("Blizzard blocked") then blocked = blocked + 1 end end
assert(blocked == 1)

-- A failing listener is reported once, the others still run.
local after = 0
W.ns.On("FSG_TEST", function() error("boom") end)
W.ns.On("FSG_TEST", function() after = after + 1 end)
W.ns.Fire("FSG_TEST")
W.ns.Fire("FSG_TEST")
local told = 0
for _, line in ipairs(W.lines) do if line:find("an error in FSG_TEST") then told = told + 1 end end
assert(after == 2 and told == 1)

-- FSG_READY registered late runs at once; combat messages fire.
local late, combat = false, {}
W.ns.On("FSG_READY", function() late = true end)
W.ns.On("FSG_COMBAT_START", function() combat[#combat + 1] = "start" end)
W.ns.On("FSG_COMBAT_END", function() combat[#combat + 1] = "end" end)
W.setCombat(true)
assert(W.ns.InCombat())
W.setCombat(false)
assert(late and W.same(combat, { "start", "end" }) and not W.ns.InCombat())

-- Descriptions and FPS impact: every entry, Latin-1 text; measured gains (8+ samples) win over probe and estimate.
W = new()
W.login()
local C = W.ns.Catalog
local IMPACT_LEVELS = { none = true, low = true, medium = true, high = true, ["very high"] = true }
for _, entry in ipairs(C.LIST) do
	local desc = entry.desc
	assert(type(desc) == "string" and desc:find("%a") and not desc:find("[\1-\8\11-\31\127]"), entry.cvar .. " desc")
	for i = 1, #desc do assert(desc:byte(i) < 128 or desc:byte(i) >= 160, entry.cvar .. " desc is Latin-1 text") end
	assert(IMPACT_LEVELS[entry.impact] and (entry.impactSource == "probe" or entry.impactSource == "estimate"), entry.cvar .. " impact")
end
assert(C.Impact("nope") == nil and C.Impact("gxapi") == nil)
local level, percent, source = C.Impact("RenderScale")
assert(level == "very high" and percent == 6 and source == "probe")
level, percent, source = C.Impact("groundEffectDensity")
assert(level == "medium" and percent == nil and source == "estimate")
local smart = W.ns.db.smart
local function gains(cvar, ...)
	local sum, n = 0, 0
	for _, g in ipairs({ ... }) do
		if g[1] >= 0 and g[1] <= 40 or cvar == "RenderScale" and g[1] >= 0 then sum, n = sum + g[1] * g[2], n + g[2] end
	end
	smart.gains = { [cvar] = { ema = n > 0 and sum / n or 0, n = n } }
	return C.Impact(cvar)
end
assert(gains("graphicsComputeEffects", { 15, 3 }) == "medium" and select(3, C.Impact("graphicsComputeEffects")) == "probe", "3 noisy samples keep the probe level")
level, percent, source = gains("graphicsComputeEffects", { 15, 20 })
assert(level == "very high" and near(percent, (20 * 15 + 5 * 2) / 25) and source == "measured", "20 samples, shrunk toward the probe 2%")
level, percent = gains("groundEffectDensity", { 1, 6 }, { 4, 2 }, { 9, 0 })
assert(near(percent, (6 * 1 + 2 * 4 + 5 * 7 / 5) / 13), "weighted by n; the estimate's prior is its level midpoint per step")
level, percent = gains("graphicsSSAO", { 3, 8 }, { -6, 30 }, { 55, 30 })
assert(near(percent, (8 * 3 + 5 * 2.5) / 13), "negative and absurd emas ignored")
level, percent = gains("RenderScale", { 50, 10 })
assert(near(percent, (10 * 50 + 5 * 6) / 15) and level == "very high", "RenderScale may exceed 40% per step")
smart.gains = { sunShafts = { ema = 0.2, n = 9 }, ffxglow = { ema = 1, n = 7 } }
level, percent, source = C.Impact("sunShafts")
assert(level == "low" and near(percent, (9 * 0.2 + 5 * 2.5 / 2) / 14) and source == "measured", "the measured gains")
assert(select(3, C.Impact("ffxglow")) == "estimate", "7 samples is not measured")
assert(C.Impact("shadowSoft") == "high" and select(2, C.Impact("shadowSoft")) == 11)

-- Change log in chat: one line per batch, split when long, nothing when unchanged or turned off.
W = new()
W.login()
ns, db = W.ns, W.ns.db
assert(db.options.chatLog == false and db.options.chatLogSmart == false, "chat log off by default")
W.slash("log on")
assert(db.options.chatLog == true and W.said("change log in chat on"))
local batches = {}
ns.On("FSG_CHANGES", function(batch) batches[#batches + 1] = batch end)
local function changedLines()
	local out = {}
	for _, line in ipairs(W.lines) do if line:find("Changed %(") then out[#out + 1] = line end end
	return out
end
W.lines = {}
local fast = ns.Profiles.Create("Fast", { graphicsShadowQuality = 1, graphicsSSAO = 1, RenderScale = 0.6 })
ns.Profiles.Assign("outdoor", fast)
assert(#changedLines() == 0, "sent on the next frame")
W.run(0.1)
local lines = changedLines()
assert(#batches == 1 and batches[1].source == "profile" and batches[1].reason == "Open world: Fast" and #batches[1].changes == 3)
assert(batches[1].changes[1].cvar == "graphicsShadowQuality" and batches[1].changes[1].from == 3 and batches[1].changes[1].to == 1)
assert(#lines == 1 and lines[1]:find("Changed (Open world: Fast): Shadow quality High to Fair, Ambient occlusion High to Low, Render scale 75% to 60%", 1, true), lines[1])
W.lines, batches = {}, {}
ns.Apply.Write("graphicsSSAO", 1, "test")
ns.Apply.Write("sunShafts", 2)
ns.Apply.Write("graphicsSSAO", 2, "Find my best settings")
W.run(0.1)
assert(#changedLines() == 0, "Smart's steps are silent by default")
assert(#batches == 2 and batches[1].source == "smart" and batches[1].reason == "smart mode" and batches[2].source == "calibrate", "FSG_CHANGES fires anyway; unchanged writes give none")
W.slash("log smart on")
assert(db.options.chatLogSmart == true and W.said("Smart mode changes in chat on"))
W.lines, batches = {}, {}
ns.Apply.Write("sunShafts", 1)
ns.Apply.Write("graphicsSSAO", 1, "Restore original")
W.run(0.1)
lines = changedLines()
assert(#lines == 2 and lines[1]:find("Changed (smart mode): Sun shafts High to Low", 1, true) and lines[2]:find("Changed (Restore original): Ambient occlusion Good to Low", 1, true), "with chatLogSmart both print")
assert(#batches == 2 and batches[2].source == "restore")
W.lines = {}
ns.Apply.Write("sunShafts", 1, "test")
W.run(0.1)
assert(#changedLines() == 0, "no line when nothing changed")
W.slash("log off")
assert(db.options.chatLog == false and W.said("change log in chat off"))
batches = {}
ns.Apply.Write("sunShafts", 0, "test")
ns.Apply.Write("sunShafts", 1)
W.run(0.1)
assert(#changedLines() == 0 and #batches == 2, "no line with the chat log off, Smart's included; FSG_CHANGES still fires")
W.slash("log on")
W.lines = {}
local LONG = { groundEffectDensity = 128, groundEffectDist = 300, groundEffectFade = 200, terrainLodDist = 700, wmoLodDist = 900, horizonStart = 3000,
	lodObjectCullSize = 10, lodObjectFadeScale = 150, weatherDensity = 1, reflectionMode = 3, shadowNumCascades = 4, assaoBlurPassCount = 3, doodadLodScale = 200, ResampleAlwaysSharpen = 1 }
for cvar, value in pairs(LONG) do ns.Apply.Write(cvar, value, "Find my best settings") end
W.run(0.1)
lines = changedLines()
local parts = 0
for _, line in ipairs(lines) do
	local body = line:match("Changed %(Find my best settings%): (.*)$")
	assert(body and #body + #"Changed (Find my best settings): " <= 250, "split, each line within 250")
	for _ in (body .. ", "):gmatch(" to [^,]+, ") do parts = parts + 1 end
end
assert(#lines >= 2 and parts == 14, "long batch split over lines, nothing dropped")
W = new({ db = { version = 1, options = { chatLog = "yes", chatLogSmart = "yes" } } })
W.login()
assert(W.ns.db.options.chatLog == false and W.ns.db.options.chatLogSmart == false, "repaired to the defaults")
W = new({ db = { version = 1, options = { chatLog = false, chatLogSmart = true } } })
W.login()
assert(W.ns.db.options.chatLog == false and W.ns.db.options.chatLogSmart == true, "saved choices are kept")

W = new({ db = { version = 1, smart = { scaleFloor = 0.6 } } })
W.login()
assert(W.ns.db.smart.scaleFloor == 0.6, "a saved floor is not touched")

-- Goal + Pace: repaired; the frame cap captured and restored.
W = new()
W.login()
ns, db = W.ns, W.ns.db
assert(db.smart.goal == "balanced" and db.smart.pace == "balanced" and next(db.smart.goals) == nil and not W.said("repaired"), "fresh: balanced/balanced")
assert(db.original.maxFPS == "73" and db.original.useMaxFPS == "1", "frame cap captured at first load")
assert(not ns.Profiles.SetValue("default", "maxFPS", 60))
for _, preset in ipairs(ns.Catalog.PRESETS) do assert(preset.build().maxFPS == nil, "no frame cap in presets") end
W.cvars.maxFPS, W.cvars.useMaxFPS = "60", "0"
ns.Apply.RestoreOriginal()
assert(W.cvars.maxFPS == "73" and W.cvars.useMaxFPS == "1", "restore puts the frame cap back")
local function migrate(smart, extra)
	local saved = { version = 1, smart = smart, original = { maxFPS = "144", useMaxFPS = "1" } }
	for k, v in pairs(extra or {}) do saved[k] = v end
	W = new({ db = saved, cvars = { maxFPS = "60", useMaxFPS = "1" } })
	W.login()
	return W.ns.db.smart
end
local smart
smart = migrate({ goal = "turbo", pace = 3, goals = { city = "fps", raid = "nope", moon = "fidelity" } })
assert(smart.goal == "balanced" and smart.pace == "balanced" and W.same(smart.goals, { city = "fps" }) and W.said("repaired"), "bad goal, pace and goals dropped")
smart = migrate({ goal = "fidelity", pace = "aggressive", goals = "x" })
assert(smart.goal == "fidelity" and smart.pace == "aggressive" and next(smart.goals) == nil)
assert(W.ns.db.original.maxFPS == "144", "a captured frame cap is never overwritten")

-- Chat log reasons: a value Smart shaped is credited to smart mode (with the goal), the profile's own values to the
-- profile.
W = new()
local shaping = { on = false }
W.ns.Smart = {
	GOALS = { { key = "balanced", name = "Balanced" }, { key = "fidelity", name = "Fidelity" } },
	Goal = function(locKey) return locKey == "outdoor" and "fidelity" or "balanced" end,
	Enabled = function() return shaping.on end,
	SetEnabled = function(on) shaping.on = on W.ns.Fire("FSG_SMART", {}) end,
	State = function() return { status = "holding" } end,
	Adjust = function(_, values)
		local out = W.copy(values)
		out.RenderScale = 0.9
		return out
	end,
}
W.login()
W.run(4)
W.ns.db.options.chatLog = true
shaping.on = true
W.lines = {}
W.ns.Profiles.SetValue("default", "graphicsShadowQuality", 1)
W.run(0.1)
assert(W.said("Changed %(Open world: Default%): Shadow quality High to Fair$") and not W.said("smart mode"), "by default only the profile's line prints")
W.ns.db.options.chatLogSmart, W.lines = true, {}
W.cvars.RenderScale, W.cvars.graphicsShadowQuality = "0.75", "3"
W.ns.Profiles.SetValue("default", "graphicsShadowQuality", 2)
W.run(0.1)
assert(W.said("Changed %(Open world: Default%): Shadow quality High to Good$"), "the profile's value under the profile")
assert(W.said("Changed %(smart mode %(Fidelity%)%): Render scale 75%% to 90%%$"), "Smart's value under smart mode")

-- Nothing changes in combat: automatic writes are held (latest wins) and land as one batch at combat end.
W = new()
W.login()
ns, db = W.ns, W.ns.db
local batches = {}
ns.On("FSG_CHANGES", function(batch) batches[#batches + 1] = batch end)
W.setCombat(true)
W.clearWrites()
local ok, why = ns.Apply.Write("sunShafts", 0)
assert(not ok and why == "combat" and not W.wrote("sunShafts") and W.cvars.sunShafts == "1", "automatic write in combat: held")
for _ = 1, 3 do ns.Apply.Write("sunShafts", 2, "smart mode (Balanced)") end
ns.Apply.Write("maxFPS", 60)
assert(not db.unsupported.sunShafts, "combat never counts as a miss")
assert(ns.Apply.Write("graphicsSSAO", 1, "test", { user = true }) and W.cvars.graphicsSSAO == "1", "a user write lands in combat")
local profile = ns.Profiles.Create("Town", { graphicsShadowQuality = 1 })
assert(W.cvars.graphicsShadowQuality == "3", "the new profile is not used here yet")
ns.Profiles.Assign("city", profile)
W.resting = true
W.fire("PLAYER_UPDATE_RESTING")
W.run(3.5)
assert(ns.Location.Current().key == "city" and W.cvars.graphicsShadowQuality == "3", "a location change in combat waits")
W.clearWrites()
batches = {}
W.run(0.1)
W.setCombat(false)
assert(W.cvars.sunShafts == "2" and W.cvars.maxFPS == "60" and W.cvars.graphicsShadowQuality == "1", "applied at combat end, latest value")
local count = 0
for _, w in ipairs(W.writes) do if w[1] == "sunShafts" or w[1] == "graphicsShadowQuality" then count = count + 1 end end
assert(count == 2, "each written once")
W.run(0.1)
assert(#batches == 2 and batches[1].reason == "after combat" and #batches[1].changes == 1 and batches[2].reason == "City: Town", "Smart's held value as held, the profile's from a fresh refresh")
W.setCombat(true)
ns.Apply.Write("sunShafts", 0)
ns.Apply.RestoreOriginal()
W.clearWrites()
W.setCombat(false)
assert(W.cvars.sunShafts == "1" and not W.wrote("sunShafts"), "restore works in combat and drops held writes")
W.setCombat(false)
assert(W.cvars.sunShafts == "1")

-- Notifications the player turned on stay on.
local QUIET = { "announce", "suggest", "smartNotice", "notifyProfile", "chatLog", "chatLogSmart" }
local loud = {}
for _, key in ipairs(QUIET) do loud[key] = true end
W = new({ db = { version = 1, options = W.copy(loud) } })
W.login()
for _, key in ipairs(QUIET) do assert(W.ns.db.options[key] == true, key .. " kept on") end

-- Announce off: a heavy change waits for a loading screen, else lands quietly after 10 minutes out of combat.
local function heavyWaiting()
	W = new()
	W.login()
	W.run(4)
	ns, db = W.ns, W.ns.db
	W.clearWrites()
	W.lines = {}
	-- Not the player's own edit (that lands at once): a value the refresh finds different.
	db.profiles.default.values.graphicsTextureResolution = 0
	ns.Apply.Refresh("location")
	assert(not W.wrote("graphicsTextureResolution") and ns.Apply.Pending().quiet and #W.lines == 0, "waits silently")
end
heavyWaiting()
W.fire("PLAYER_ENTERING_WORLD", false, true)
W.run(1)
assert(W.cvars.graphicsTextureResolution == "0", "applied at the next loading screen")
W.run(601, 1)
local count = 0
for _, w in ipairs(W.writes) do if w[1] == "graphicsTextureResolution" then count = count + 1 end end
assert(count == 1, "not written again by the fallback")
heavyWaiting()
W.run(590, 1)
assert(W.cvars.graphicsTextureResolution == "2", "still waiting before 10 minutes")
W.setCombat(true)
W.run(20, 1)
assert(W.cvars.graphicsTextureResolution == "2", "not in combat")
W.setCombat(false)
assert(W.cvars.graphicsTextureResolution == "0" and #W.lines == 0, "lands quietly after combat once 10 minutes passed")
heavyWaiting()
W.run(601, 1)
assert(W.cvars.graphicsTextureResolution == "0", "lands after 10 minutes with no loading screen")

-- fpsPulse on by default; smart.ceiling kept only as { fps > 0, t }.
W = new()
W.login()
assert(W.ns.db.options.fpsPulse == true and W.ns.db.smart.ceiling == nil)
W = new({ db = { version = 1, options = { fpsPulse = false }, smart = { ceiling = { fps = 144, t = 1700000000, extra = 1 } } } })
W.login()
assert(W.ns.db.options.fpsPulse == false and W.same(W.ns.db.smart.ceiling, { fps = 144, t = 1700000000 }), "kept")
W = new({ db = { version = 1, smart = { ceiling = { fps = 55, t = 1700000000, confirmed = true } } } })
W.login()
assert(W.same(W.ns.db.smart.ceiling, { fps = 55, t = 1700000000, confirmed = true }), "confirmed survives a reload")
for _, bad in ipairs({ { fps = 0, t = 1 }, { fps = 60 }, { fps = "60", t = 1 }, { fps = 0 / 0, t = 1 }, 5 }) do
	W = new({ db = { version = 1, options = { fpsPulse = "yes" }, smart = { ceiling = bad } } })
	W.login()
	assert(W.ns.db.smart.ceiling == nil and W.ns.db.options.fpsPulse == true and W.said("repaired"), "bad ceiling dropped")
end

-- Profile hold (macros): one profile everywhere until released, location assignments untouched.
W = new()
W.login()
W.run(4)
ns, db = W.ns, W.ns.db
P, L = ns.Profiles, ns.Location
local town = P.Create("Town", { graphicsShadowQuality = 1 })
local raidSet = P.Create("Raid set", { graphicsShadowQuality = 0 })
local fastSet = P.Create("Fast", { graphicsShadowQuality = 4, graphicsTextureResolution = 0 })
P.Assign("city", town)
P.Assign("raid", raidSet)
P.SetOverride("map:84", "Stormwind City", raidSet)
local locations, overrides = W.copy(db.locations), W.copy(db.overrides)
local changes = 0
ns.On("FSG_PROFILES_CHANGED", function() changes = changes + 1 end)
assert(P.Held() == nil and L.ProfileFor() == "default")
W.lines = {}
W.slash("profile fast")
assert(P.Held() == fastSet and db.held == fastSet and W.said("holding Fast everywhere %(/fsg profile auto goes back%)"))
local places = { { key = "city", overrideKey = "map:1" }, { key = "raid", overrideKey = "instance:409" }, { key = "outdoor", overrideKey = "map:84" } }
for _, loc in ipairs(places) do
	local id, source = L.ProfileFor(loc)
	assert(id == fastSet and source == "held", loc.key .. " resolves to the held profile")
end
assert(L.ProfileFor(places[1], true) == town and L.ProfileFor(places[3], true) == raidSet, "assigned ignores the hold")
assert(W.same(db.locations, locations) and W.same(db.overrides, overrides), "assignments untouched")
assert(ns.Apply.Active().source == "held" and ns.Apply.Active().profileName == "Fast")
assert(W.cvars.graphicsShadowQuality == "4", "applied")
W.slash("profile")
assert(W.said("^.*holding Fast$"))
local before = changes
assert(P.Hold(fastSet) and changes == before, "unchanged hold: no fire")
assert(not P.Hold("nope") and P.Held() == fastSet, "unknown id refused")
W.lines = {}
W.slash("profile toggle FAST")
assert(P.Held() == nil and W.said("back to switching by location") and W.cvars.graphicsShadowQuality == "3", "toggle releases")
assert(L.ProfileFor(places[1]) == town and L.ProfileFor(places[2]) == raidSet and L.ProfileFor(places[3]) == raidSet, "release restores the per-location result")
W.slash("profile toggle Fast")
assert(P.Held() == fastSet, "toggle holds")
W.slash("profile toggle Fast")
assert(P.Held() == nil, "toggle twice = back to automatic")
W.lines = {}
W.slash("profile auto")
assert(W.said("no profile is held"))
W.slash("profile Nowhere")
assert(P.Held() == nil and W.said("no profile named \"Nowhere\""), "unknown name: no change")

-- The chat log credits a hold.
db.options.chatLog = true
W.lines = {}
P.Hold(town)
W.run(0.1)
assert(W.said("Changed %(held: Town%): Shadow quality High to Fair"), "reason held: <name>")
W.lines = {}
P.Hold(nil)
W.run(0.1)
assert(W.said("Changed %(Open world: Default%): Shadow quality Fair to High"), "after a release the usual reason")

-- Persists in the saved table; a missing profile is repaired; Delete releases.
P.Hold(raidSet)
local saved = W.copy(db)
W = new({ db = saved })
W.login()
assert(W.ns.Profiles.Held() == raidSet and select(2, W.ns.Location.ProfileFor()) == "held", "survives a reload")
saved = W.copy(W.ns.db)
saved.held = "p999"
W = new({ db = saved })
W.login()
assert(W.ns.db.held == nil and W.said("repaired"), "a missing held profile becomes nil")
ns, db, P = W.ns, W.ns.db, W.ns.Profiles
P.Hold(raidSet)
assert(P.Delete(raidSet) and db.held == nil and P.Held() == nil, "Delete releases")

-- Switching off refuses; use and restore release.
P.Hold(town)
ns.Apply.SetSwitching(false)
W.lines = {}
W.slash("profile Fast")
assert(db.held == town and W.said("Smart Graphics|r is turned off; turn it on in /fsg"), "refused, nothing stored")
assert(not P.Hold(nil) and db.held == town)
ns.Apply.SetSwitching(true)
W.slash("use Fast")
assert(db.held == nil and db.locations.city == fastSet and ns.Location.ProfileFor() == fastSet, "use releases, then assigns everywhere")
P.Hold(town)
W.slash("restore")
assert(db.held == nil and P.Held() == nil, "restore releases")

-- A hold in combat is the player's action: written at once, heavy settings too (contract 3).
W = new()
W.login()
W.run(4)
ns, db, P = W.ns, W.ns.db, W.ns.Profiles
local combatSet = P.Create("Combat", { graphicsShadowQuality = 1, graphicsTextureResolution = 0 })
W.setCombat(true)
W.slash("profile combat")
assert(P.Held() == combatSet and W.cvars.graphicsShadowQuality == "1", "written in combat")
assert(W.cvars.graphicsTextureResolution == "0" and ns.Apply.Pending() == nil, "heavy at once")
W.setCombat(false)
W.slash("help")
assert(W.said("profile <name>|auto|toggle <name> %(hold a profile, for macros%)"))

-- What's new: version order.
local C = W.ns.News.Compare
local chain = { "1.0.0-beta.1", "1.0.0-beta.2", "1.0.0-rc.0", "1.0.0", "1.0.1", "1.1.0" }
for i = 1, #chain - 1 do assert(C(chain[i], chain[i + 1]) == -1 and C(chain[i + 1], chain[i]) == 1, chain[i] .. " < " .. chain[i + 1]) end
assert(C("1.10.0", "1.9.0") == 1 and C("v1.2.0", "1.2.0") == 0 and C("1.0.0-beta.2", "1.0.0-beta.2") == 0)
W.meta.Version = "v1.0.0-beta.3"
assert(ns.News.Running() == "1.0.0-beta.3", "the packager's leading v is dropped")
assert(C("1.0.0-beta", "1.0.0-beta.1") == -1 and C("1.0.0-1", "1.0.0-beta") == -1 and C("1.0.0-beta.10", "1.0.0-beta.9") == 1)
for _, dev in ipairs({ "@project-version@", "1.4.0-3-gabc1234", "", "1.0", "1.0.0-", "1.0.0-beta..1" }) do
	assert(C(dev, "1.0.0") == nil and C("1.0.0", dev) == nil, "dev build: " .. dev)
end
assert(C(nil, "1.0.0") == nil)

-- What's new: state on load.
local NEWS = {
	{ version = "1.6.0", blocks = {} }, { version = "1.5.0", blocks = {} }, { version = "1.5.0-beta.1", blocks = {} },
	{ version = "1.4.0", blocks = {} }, { version = "1.3.0", blocks = {} }, { version = "1.2.0", blocks = {} },
	{ version = "1.1.0", blocks = {} }, { version = "1.0.0", blocks = {} },
}
local function versions(list)
	local out = {}
	for i, entry in ipairs(list) do out[i] = entry.version end
	return table.concat(out, " ")
end
local function newsAt(version, saved, data)
	W = new({ db = saved, meta = { Version = version, ["X-Website"] = "https://example.invalid/fsg" } })
	W.ns.NEWS = data or NEWS
	W.login()
	return W.ns, W.ns.db, W.ns.News
end
local N
ns, db, N = newsAt("1.5.0")
assert(db.news.seen == "1.5.0" and db.news.never == nil and N.Pending() == nil, "fresh install: nothing")
assert(N.Running() == "1.5.0" and N.Website() == "https://example.invalid/fsg")
local betas = { { version = "1.0.0-beta.3", blocks = {} }, { version = "1.0.0-beta.2", blocks = {} }, { version = "1.0.0-beta.1", blocks = {} } }
ns, db, N = newsAt("1.0.0-beta.3", { version = 1, options = {} }, betas)
assert(db.news.seen == "1.0.0-beta.2", "existing data starts at the baseline")
local pending = N.Pending()
assert(versions(pending.entries) == "1.0.0-beta.3" and pending.older == false and pending.from == "1.0.0-beta.2")
for _, dev in ipairs({ "@project-version@", "1.4.0-3-gabc1234", "" }) do
	ns, db, N = newsAt(dev, { version = 1, options = {} })
	assert(db.news == nil and N.Running() == nil and N.Pending() == nil, "dev build: no news key " .. dev)
	N.Close(true)
	assert(db.news == nil, "dev build: Close writes nothing")
	assert(versions(N.Current().entries) == "1.6.0" and N.Current().dev == true, "dev build: newest notes")
end
ns, db, N = newsAt(nil, { version = 1 })
assert(db.news == nil and N.Running() == nil)
ns, db, N = newsAt("1.5.0", { version = 1, news = "broken" })
assert(W.said("repaired") and db.news.seen == "1.0.0-beta.2" and db.news.never == nil)
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = 3, never = "yes" } })
assert(db.news.seen == "1.0.0-beta.2" and db.news.never == nil)
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = "1.4.0", never = true } })
assert(db.news.seen == "1.4.0" and db.news.never == true and N.Pending() == nil, "never: nothing")

-- What's new: Pending.
ns, db, N = newsAt("1.6.0", { version = 1, news = { seen = "1.0.0" } })
pending = N.Pending()
assert(versions(pending.entries) == "1.6.0 1.5.0 1.5.0-beta.1 1.4.0 1.3.0" and pending.older == true and pending.from == "1.0.0", "newest first, at most 5")
assert(db.news.seen == "1.0.0", "Pending stores nothing")
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = "1.3.0" } })
assert(versions(N.Pending().entries) == "1.5.0 1.5.0-beta.1 1.4.0" and N.Pending().older == false, "nothing newer than running")
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = "1.5.0-beta.1" } })
assert(versions(N.Pending().entries) == "1.5.0", "pre-release to release: the release only")
ns, db, N = newsAt("1.4.0", { version = 1, news = { seen = "1.5.0" } })
assert(N.Pending() == nil and db.news.seen == "1.5.0", "downgrade: nil, seen kept")
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = "1.5.0" } })
assert(N.Pending() == nil and db.news.seen == "1.5.0", "same version")
ns, db, N = newsAt("1.7.1", { version = 1, news = { seen = "1.6.0" } })
assert(N.Pending() == nil and db.news.seen == "1.7.1", "nothing for players: seen moves quietly")
ns, db, N = newsAt("1.6.0", { version = 1, news = { seen = "1.0.0" } })
ns.NEWS = nil
assert(N.Pending() == nil and N.Current() == nil and db.news.seen == "1.0.0", "no data: nothing, seen kept")

-- What's new: Current and Close.
ns, db, N = newsAt("1.5.0", { version = 1, news = { seen = "1.0.0" } })
assert(versions(N.Current().entries) == "1.5.0" and not N.Current().dev)
ns, db, N = newsAt("1.5.1", { version = 1, news = { seen = "1.0.0" } })
assert(#N.Current().entries == 0, "no entry for the running version")
N.Close()
assert(db.news.seen == "1.5.1" and db.news.never == nil and N.Pending() == nil, "Close stores seen")
db.news.seen = "1.0.0"
N.Close(true)
assert(db.news.seen == "1.5.1" and db.news.never == true, "ticked stores never")
local reloaded = W.copy(ForeverSmartGraphicsDB)
ns, db, N = newsAt("1.6.0", reloaded)
assert(db.news.never == true and N.Pending() == nil, "never survives a reload")

-- What's new: /fsg whatsnew.
local shown = 0
ns.ShowWhatsNew = function() shown = shown + 1 end
W.slash("whatsnew")
assert(db.news.never == nil and W.said("What's new is on again: it opens after each update%.") and shown == 1)
W.lines = {}
W.slash("whatsnew")
assert(not W.said("on again") and shown == 2)
ns.NEWS = nil
W.slash("whatsnew")
assert(W.said("Nothing new for players in this version%.") and shown == 2)
ns, db, N = newsAt("1.6.0", { version = 1 })
W.slash("whatsnew")
assert(W.said("window not loaded"), "Core stub until the window replaces it")
W.slash("help")
assert(W.said("| whatsnew %(what changed in this version%) |"))
ns, db, N = newsAt("@project-version@", { version = 1 })
ns.ShowWhatsNew = function() shown = shown + 1 end
W.slash("whatsnew")
assert(db.news == nil and shown == 3, "dev build: opens, writes nothing")

-- Render scale above 100% and anti-aliasing through a profile.
W = new()
W.login()
ns, db = W.ns, W.ns.db
assert(db.original.ffxAntiAliasingMode == "1", "AA captured on a fresh install")
db.profiles.default.values.RenderScale, db.profiles.default.values.ffxAntiAliasingMode = 1.35, 3
ns.Apply.Refresh("test", nil, { user = true })
assert(W.cvars.RenderScale == "1.35" and W.cvars.ffxAntiAliasingMode == "3", "written and read back")
assert(ns.Catalog.BuildPreset("ultra").RenderScale == 1 and ns.Catalog.BuildPreset("fps").RenderScale == 0.6, "presets unchanged")
local saved = W.copy(ForeverSmartGraphicsDB)
saved.original.ffxAntiAliasingMode = nil
W = new({ db = saved, cvars = { ffxAntiAliasingMode = "2" } })
W.login()
assert(W.ns.db.original.ffxAntiAliasingMode == "2" and W.ns.db.original.RenderScale == saved.original.RenderScale, "an older db gains the new cvar, the rest kept")

-- E1: Eco (global and per place) survives a reload; Core keeps every goal and pace Smart.lua knows.
GetUnitSpeed = GetUnitSpeed or function() return 0 end
local FULL = { "Core.lua", "NewsData.lua", "News.lua", "Catalog.lua", "Profiles.lua", "Location.lua", "Apply.lua", "Smart.lua" }
W = new({ files = FULL })
W.login()
for _, goal in ipairs(W.ns.Smart.GOALS) do
	for _, pace in ipairs(W.ns.Smart.PACES) do
		local saved = W.copy(W.ns.db)
		saved.smart.goal, saved.smart.pace, saved.smart.goals = goal.key, pace.key, { raid = goal.key }
		local R = new({ db = saved, files = FULL })
		R.login()
		local s = R.ns.db.smart
		assert(s.goal == goal.key and s.pace == pace.key and s.goals.raid == goal.key and not R.said("repaired"), goal.key .. "/" .. pace.key .. " survives a reload")
	end
end

-- E4: a change in the game's own Options sticks when nothing in the addon sets that setting.
W = new()
W.login()
W.run(4)
ns, db = W.ns, W.ns.db
C_CVar.SetCVar("graphicsShadowQuality", "5")
C_CVar.SetCVar("RenderScale", "1")
C_CVar.SetCVar("maxFPS", "144")
W.clearWrites()
W.mapID, W.zone = 1413, "The Barrens"
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(1)
assert(#W.writes == 0 and W.cvars.graphicsShadowQuality == "5" and W.cvars.RenderScale == "1", "the Options change is kept at the next refresh")
assert(db.original.graphicsShadowQuality == "5" and db.original.maxFPS == "144", "adopted as the player's own value")
ns.Profiles.SetValue("default", "graphicsSSAO", 1)
C_CVar.SetCVar("graphicsSSAO", "4")
assert(db.original.graphicsSSAO == "3", "a setting Default sets is not adopted")
ns.Apply.Refresh("location")
assert(W.cvars.graphicsSSAO == "1", "and the profile's value comes back")
local R = new({ db = W.copy(db), cvars = { graphicsShadowQuality = "5", RenderScale = "1" } })
R.login()
R.run(2)
assert(R.cvars.graphicsShadowQuality == "5" and R.cvars.RenderScale == "1" and not R.wrote("graphicsShadowQuality"), "and next session")
-- First login on a machine whose own value is outside the Catalog range: nothing written.
W = new({ cvars = { graphicsParticleDensity = "0", ResampleQuality = "4" } })
W.login()
W.run(2)
assert(#W.writes == 0 and W.cvars.graphicsParticleDensity == "0" and W.cvars.ResampleQuality == "4", "the player's out-of-range value is not clamped")
-- Smart mode on: an outside change is not adopted (Smart decides those settings).
W = new()
W.ns.Smart = { Enabled = function() return true end, SetEnabled = function() end, State = function() return { status = "holding" } end, Adjust = function(_, v) return v end }
W.login()
C_CVar.SetCVar("graphicsShadowQuality", "5")
assert(W.ns.db.original.graphicsShadowQuality == "3", "not adopted while Smart mode is on")

-- E3: limits and unsupported settings are rediscovered every session.
W = new()
W.login()
W.ignore.vrsValar = "x"
W.ns.Apply.Write("vrsValar", 2)
W.ns.Apply.Write("vrsValar", 1)
W.clamp.sunShafts = 1
W.ns.Apply.Write("sunShafts", 2)
assert(W.ns.db.unsupported.vrsValar and W.ns.db.limits.sunShafts == 1)
local again = new({ db = W.copy(W.ns.db) })
again.login()
assert(next(again.ns.db.unsupported) == nil and next(again.ns.db.limits) == nil and next(again.ns.db.limitSides) == nil and not again.said("repaired"), "a refused value is not unsupported next session")

-- E5a: a profile's hidden settings go back to the original in the next session too.
W = new()
W.login()
W.run(4)
local rich = W.ns.Profiles.Create("Rich", { shadowSoft = 1, groundEffectDensity = 256 })
W.ns.Profiles.Assign("outdoor", rich)
assert(W.cvars.shadowSoft == "1" and W.ns.db.overridden.shadowSoft and W.ns.db.overridden.groundEffectDensity)
local saved = W.copy(W.ns.db)
saved.locations.outdoor = nil
saved.overridden.bogus, saved.overridden.graphicsSSAO = true, true
W = new({ db = saved, cvars = { shadowSoft = "1", groundEffectDensity = "256" } })
W.login()
W.run(2)
assert(W.cvars.shadowSoft == "0" and W.cvars.groundEffectDensity == "64" and next(W.ns.db.overridden) == nil, "back to the original next session")
assert(W.said("repaired 2 "), "only hidden Catalog cvars are kept in the set")

-- E7: saved values are repaired against the static range, not this session's machine range; newer data is kept.
W = new({ maxScale = 2.0 })
W.login()
local sharp = W.ns.Profiles.Create("Sharp", { RenderScale = 1.5, ffxAntiAliasingMode = 4, graphicsParticleDensity = 1 })
W.ns.db.profiles[sharp].values.graphicsParticleDensity = 0
W = new({ db = W.copy(W.ns.db), maxScale = 1.0, aa = { true, false, false } })
W.login()
local values = W.ns.Profiles.Get(sharp).values
assert(values.RenderScale == 1.5 and values.ffxAntiAliasingMode == 4 and values.graphicsParticleDensity == 0 and not W.said("repaired"), "a smaller display does not rewrite the profile")
assert(W.ns.Profiles.Effective(sharp).RenderScale == 1 and W.ns.Profiles.Effective(sharp).ffxAntiAliasingMode == 2, "clamped at use")
W = new({ db = { version = 2, profiles = { default = { name = "Default", values = { futureCvar = 3, RenderScale = 0.77 } } } } })
W.login()
assert(W.ns.db.version == 2 and W.ns.db.profiles.default.values.futureCvar == 3 and W.ns.db.profiles.default.values.RenderScale == 0.77 and W.said("newer version"), "newer data kept as it is")

-- E20: a value held for a place the player already left is never written; only the current place's refresh lands.
W = new()
W.login()
W.run(4)
local town = W.ns.Profiles.Create("Town", { graphicsShadowQuality = 1 })
W.ns.Profiles.Assign("city", town)
W.setCombat(true)
W.resting = true
W.fire("PLAYER_UPDATE_RESTING")
W.run(4)
W.resting = false
W.fire("PLAYER_UPDATE_RESTING")
W.run(4)
W.clearWrites()
W.setCombat(false)
assert(#W.writes == 0 and W.cvars.graphicsShadowQuality == "3", "the stale held value is dropped")

-- E8: switching off drops a counting-down heavy change and everything held for combat end.
W = new()
W.login()
W.run(4)
ns, db = W.ns, W.ns.db
db.options.announce = true
local spot2 = ns.Profiles.Create("Spot", { graphicsTextureResolution = 0 })
ns.Profiles.SetOverride("map:1413", "Spot", spot2)
W.mapID = 1413
W.fire("ZONE_CHANGED_NEW_AREA")
W.run(0.5)
assert(ns.Apply.Pending())
ns.Apply.SetSwitching(false)
W.clearWrites()
W.run(11)
assert(ns.Apply.Pending() == nil and W.liveTickers() == 0 and #W.writes == 0 and W.cvars.graphicsTextureResolution == "2", "4a: nothing lands after switching off")
ns.Apply.SetSwitching(true)
ns.Apply.ApplyPending()
local cities = ns.Profiles.Create("Cities", { graphicsShadowQuality = 1 })
ns.Profiles.Assign("city", cities)
W.setCombat(true)
W.resting = true
W.fire("PLAYER_UPDATE_RESTING")
W.run(4)
ns.Apply.Write("sunShafts", 2)
ns.Apply.SetSwitching(false)
W.clearWrites()
W.setCombat(false)
assert(#W.writes == 0 and W.cvars.graphicsShadowQuality ~= "1" and W.cvars.sunShafts == "1", "4b: nothing held lands after switching off")
-- Switching off turns Smart mode off first, while refreshes still run.
W = new()
local order = {}
local on = true
W.ns.Smart = {
	Enabled = function() return on end,
	SetEnabled = function(v) on = v order[#order + 1] = "smart off, switching " .. tostring(W.ns.db.options.switching) W.ns.Fire("FSG_SMART") end,
	State = function() return { status = "holding" } end,
	Adjust = function(_, v) return v end,
}
W.login()
W.ns.Apply.SetSwitching(false)
assert(order[1] == "smart off, switching true" and W.ns.db.options.switching == false, "Smart mode off first")

-- E10: restore stops Find my best settings first and ends with switching off.
W = new()
local stopped
W.ns.Calibrate = {
	State = function() return { running = not stopped } end,
	Stop = function(opts) stopped = opts W.ns.Apply.SetSwitching(true) return true end,
}
W.login()
W.ns.Apply.SetSwitching(false)
W.slash("restore")
assert(stopped and stopped.keepOff and W.ns.db.options.switching == false and W.said("put your original settings back and is turned off; turn it on in /fsg"), "Calibrate stopped, switching stays off")

-- E11, E15, E17: use releases a hold through AssignAll; reserved words only as the whole argument; usage lines.
W = new()
W.login()
W.run(4)
ns, db, P = W.ns, W.ns.db, W.ns.Profiles
local autoLow, toggleTest, raidP = P.Create("Auto low", { graphicsSSAO = 0 }), P.Create("Toggle test", { graphicsSSAO = 1 }), P.Create("Raid", { graphicsSSAO = 2 })
P.Hold(raidP)
assert(P.AssignAll(autoLow) and P.Held() == nil and ns.Apply.Active().profileId == autoLow, "AssignAll releases a held profile")
W.slash("profile Auto low")
assert(P.Held() == autoLow, "a name starting with auto")
W.slash("profile Toggle test")
assert(P.Held() == toggleTest, "a name starting with toggle")
W.slash("profile toggle Toggle test")
assert(P.Held() == nil, "toggle form still works")
W.lines = {}
W.slash("use")
W.slash("profile toggle")
assert(W.said("Usage: /fsg use <profile name>") and W.said("Usage: /fsg profile toggle <profile name>"))
ns.Apply.SetSwitching(false)
W.lines = {}
W.slash("use Raid")
assert(W.said("Raid is now used everywhere %(Smart Graphics is turned off, so nothing changes until you turn it on%)") and db.locations.city == raidP)
W.slash("help")
for _, word in ipairs({ "goal <", "pace <", "findbest", "| finish", "| stop", "applynow" }) do assert(W.said(word:gsub("%p", "%%%0")), "help lists " .. word) end

-- E13: particle density follows the game's menu: 0..4 Low..Ultra with secondary lighting, else 1..5.
C_VideoOptions = { IsSecondaryLightingSupported = function() return true end }
W = new()
local particles = W.ns.Catalog.Get("graphicsParticleDensity")
assert(particles.min == 0 and particles.max == 4 and W.ns.Catalog.Format("graphicsParticleDensity", 0) == "Low" and W.ns.Catalog.Format("graphicsParticleDensity", 4) == "Ultra")
C_VideoOptions = nil
W = new()
particles = W.ns.Catalog.Get("graphicsParticleDensity")
assert(particles.min == 1 and particles.max == 5 and W.ns.Catalog.Format("graphicsParticleDensity", 5) == "Ultra")

-- E21: value names as the game's menu shows them.
local F = W.ns.Catalog.Format
assert(F("graphicsPBRLiquidDetail", 0) == "Low" and F("graphicsPBRLiquidDetail", 1) == "High" and F("graphicsPBRLiquidDetail", 2) == "Ultra")
assert(F("graphicsComputeEffects", 0) == "Low" and F("graphicsComputeEffects", 1) == "Fair" and F("graphicsComputeEffects", 4) == "Ultra")
assert(F("graphicsTextureResolution", 1) == "Fair" and F("graphicsTextureResolution", 2) == "High")
assert(F("graphicsLightMode", 0) == "Fair" and F("graphicsLightMode", 3) == "Ultra")

-- E12: selftest says whether the Raid and Battleground graphics set is in use.
W = new({ cvars = { RAIDsettingsEnabled = "1" } })
function GetCurrentGraphicsSetting() return 1 end
W.login()
W.slash("selftest")
assert(W.said("selftest: Raid and Battleground graphics set turned on, active now: yes"))
GetCurrentGraphicsSetting = nil

-- E18: a name cut at 32 bytes never ends in half a letter.
W = new()
W.login()
local cyr = string.rep("\208\175", 17)
local cut = W.ns.Profiles.Get(W.ns.Profiles.Create("x" .. cyr, {})).name
assert(#cut == 31 and cut:byte(-1) == 175, "a whole letter dropped, not half")
assert(W.ns.Cut("abc", 2) == "ab" and W.ns.Cut("a\226\130\172", 3) == "a" and W.ns.Cut("a\226\130\172", 4) == "a\226\130\172")
local saved = W.copy(W.ns.db)
saved.profiles.p1.name = "y" .. cyr
W = new({ db = saved })
W.login()
assert(#W.ns.Profiles.Get("p1").name == 31)

-- E19: a seen version the order can't read counts as missing; a broken news table does not stop /fsg whatsnew.
W = new({ db = { version = 1, news = { seen = "garbage" } }, meta = { Version = "1.0.0" } })
W.login()
assert(W.ns.db.news.seen == "1.0.0-beta.2" and W.said("repaired"), "unreadable seen is reset to the baseline")
W.ns.db.news = "broken"
W.ns.ShowWhatsNew = function() end
W.slash("whatsnew")

-- E22: a place added on the parent map covers the maps inside it.
W = new()
C_Map.GetMapInfo = function(id) return id == 85 and { parentMapID = 84 } or { parentMapID = 0 } end
W.login()
W.run(4)
local city2 = W.ns.Profiles.Create("Capital", { graphicsSSAO = 1 })
W.ns.Profiles.SetOverride("map:84", "Stormwind City", city2)
W.mapID = 85
W.fire("ZONE_CHANGED")
W.run(0.5)
assert(W.ns.Location.Current().parentKey == "map:84" and select(2, W.ns.Location.ProfileFor()) == "place" and W.cvars.graphicsSSAO == "1", "parent override")
local own = W.ns.Profiles.Create("Own", { graphicsSSAO = 0 })
W.ns.Profiles.SetOverride("map:85", "Old Town", own)
assert(W.ns.Location.ProfileFor() == own, "the map's own override wins")

-- E24: use the addon, copy the saved table, load again: no "repaired" line.
W = new({ meta = { Version = "1.0.0" } })
W.login()
W.run(4)
P = W.ns.Profiles
local rt = P.Create("Round trip", { RenderScale = 1.35, ffxAntiAliasingMode = 3, shadowSoft = 1, shadowTextureSize = 1024 })
P.Assign("city", rt)
P.SetOverride("map:84", "Stormwind City", rt)
P.Hold(rt)
W.ns.db.smart.ceiling = { fps = 60, t = 1700000000, confirmed = true }
W.ns.db.smart.goal, W.ns.db.smart.goals.raid = "eco", "fidelity"
W.ns.db.options.calibratePos = { point = "TOP", x = 1, y = 2 }
W.ns.Apply.Write("sunShafts", 2)
W.fire("PLAYER_LOGOUT")
local R = new({ db = W.copy(ForeverSmartGraphicsDB), meta = { Version = "1.0.0" } })
R.login()
assert(not R.said("repaired") and R.ns.Profiles.Held() == rt and R.ns.db.smart.goal == "eco" and R.ns.db.smart.ceiling.confirmed, "a used saved table loads clean")

io.write("engine_spec: all passed\n")
