-- Whole-addon check: every file in the TOC, in TOC order, over the panel stub plus the game APIs the engine reads.
-- Logs in, walks city → open world → dungeon → raid, runs smart mode, Find my best settings and the window.
-- Run: lua ForeverSmartGraphics/tests/load_spec.lua (or from the addon folder: lua tests/load_spec.lua)
local script = arg and arg[0] or ""
local dir = script:match("^(.*)[/\\]tests[/\\]") or (script:match("^tests[/\\]") and ".") or "ForeverSmartGraphics"
local W = dofile(dir .. "/tests/panel_stub.lua")

local checks = 0
local function check(ok, msg)
	checks = checks + 1
	if not ok then error("FAIL: " .. msg, 2) end
end

-- Events: the stub's frames ignore RegisterEvent, so record registrations here.
local listeners = {}
local baseCreateFrame = CreateFrame
function CreateFrame(...)
	local f = baseCreateFrame(...)
	function f:RegisterEvent(event)
		listeners[event] = listeners[event] or {}
		table.insert(listeners[event], self)
	end
	function f:UnregisterEvent(event)
		for i, g in ipairs(listeners[event] or {}) do if g == self then table.remove(listeners[event], i) break end end
	end
	return f
end
local function fire(event, ...)
	for _, f in ipairs(listeners[event] or {}) do
		local handler = f.scripts.OnEvent
		if handler then handler(f, event, ...) end
	end
end

-- Game state the engine reads.
local cvars = {
	graphicsShadowQuality = "3", graphicsLiquidDetail = "2", graphicsPBRLiquidDetail = "1", graphicsParticleDensity = "3",
	graphicsSSAO = "3", graphicsDepthEffects = "3", graphicsComputeEffects = "2", graphicsOutlineMode = "1",
	graphicsTextureResolution = "2", graphicsSpellDensity = "1", graphicsProjectedTextures = "1", graphicsLightMode = "1",
	graphicsViewDistance = "5", graphicsEnvironmentDetail = "5", graphicsGroundClutter = "5", RenderScale = "0.75",
	ResampleQuality = "3", textureFilteringMode = "5", shadowSoft = "0", groundEffectDensity = "32", groundEffectDist = "185",
	groundEffectFade = "70", terrainLodDist = "500", wmoLodDist = "350", horizonStart = "1700", lodObjectCullSize = "19",
	lodObjectFadeScale = "90", sunShafts = "2", weatherDensity = "3", ffxglow = "1", reflectionMode = "2",
	shadowTextureSize = "1536", vrsValar = "0", shadowrt = "0", shadowNumCascades = "3", assaoBlurPassCount = "2",
	ResampleAlwaysSharpen = "0", doodadLodScale = "100", useTargetFPS = "0", targetFPS = "60", maxFPS = "73", useMaxFPS = "0",
}
for k, v in pairs(cvars) do W.cvars[k] = v end
local IGNORED = { vrsValar = true, shadowrt = true }
local writes = {}
C_CVar = {
	GetCVar = function(name) return W.cvars[name] end,
	SetCVar = function(name, value)
		writes[#writes + 1] = { name, value }
		if not IGNORED[name] then W.cvars[name] = tostring(value) end
		fire("CVAR_UPDATE", name, tostring(value))
		return true
	end,
	GetCVarDefault = function(name) return cvars[name] end,
}
function GetCVar(name) return W.cvars[name] end

local place = { type = "none", name = "", difficulty = 0, id = 0, map = 1456, zone = "Thunder Bluff", resting = true }
function GetInstanceInfo() return place.name, place.type, place.difficulty, "", 5, 0, false, place.id, 5 end
function IsResting() return place.resting end
C_Map = { GetBestMapForUnit = function() return place.map end }
function GetRealZoneText() return place.zone end
function GetSubZoneText() return "" end
function GetZoneText() return place.zone end
function UnitAffectingCombat() return W.combat end
function GetUnitSpeed() return 0 end
function GetMinRenderScale() return 0.33 end
function GetMaxRenderScale() return 2 end
function GetGraphicsCVarValueForQualityLevel(_, level) return math.floor(level / 2) end
function IsGraphicsCVarValueSupported() return 0 end
time = os.time
SlashCmdList = {}
C_EventUtils = { IsEventValid = function() return true end }

local function travel(kind, name, map, id)
	place.type, place.name, place.map, place.id = kind, name or "", map or place.map, id or 0
	place.zone = name or place.zone
	fire("PLAYER_LEAVING_WORLD")
	fire("PLAYER_ENTERING_WORLD", false, false)
	W.advance(2)
end

-- Load every TOC file in order.
local loaded = 0
for line in io.lines(dir .. "/ForeverSmartGraphics.toc") do
	local file = line:match("^([%w_/]+%.lua)%s*$")
	if file then
		assert(loadfile(dir .. "/" .. file))("ForeverSmartGraphics", ForeverSmartGraphics or {})
		loaded = loaded + 1
	elseif line:match("^[%w_/]+%.xml%s*$") then
		loaded = loaded + 1
	end
end
-- Core creates the shared namespace; files loaded before it existed got a throwaway table, so Core must be first.
local ns = ForeverSmartGraphics
check(ns and ns.Catalog and ns.Profiles and ns.Location and ns.Apply and ns.Smart and ns.Calibrate, "every module on one namespace")
check(loaded >= 17, "TOC lists every file (" .. loaded .. ")")

-- Login.
fire("ADDON_LOADED", "ForeverSmartGraphics")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
W.advance(2)
local db = ns.db
check(db and db.version == 1 and db.profiles.default, "db ready with Default")
check(db.original.RenderScale == "0.75", "original captured")
check(#writes == 0, "Default writes nothing at login (" .. #writes .. ")")
check(ns.Location.Current().key == "city", "Thunder Bluff resting = city")

-- A change made in the game's own Options is the player's: nothing set up, so the addon keeps it.
C_CVar.SetCVar("graphicsViewDistance", "8")
writes = {}
ns.Apply.Refresh("zone")
W.advance(2)
check(W.cvars.graphicsViewDistance == "8" and #writes == 0, "an Options change survives a refresh on a fresh install")
C_CVar.SetCVar("graphicsViewDistance", "5")
writes = {}

-- Profiles and switching.
local fps = ns.Profiles.FromPreset("fps")
local beyond = ns.Profiles.FromPreset("beyond")
check(fps and beyond and ns.Profiles.Get(beyond).name == "Beyond Ultra", "presets create profiles")
ns.Profiles.Assign("city", fps)
W.advance(1)
check(tonumber(W.cvars.RenderScale) == 0.6, "City → Max FPS writes render scale 0.6 (" .. tostring(W.cvars.RenderScale) .. ")")

place.resting, place.map, place.zone = false, 1412, "Mulgore"
fire("PLAYER_UPDATE_RESTING")
fire("ZONE_CHANGED_NEW_AREA")
-- Leaving a city without a loading screen counts after a short dwell.
W.advance(3.5)
check(ns.Location.Current().key == "outdoor", "left the city")
check(tonumber(W.cvars.RenderScale) == 0.75, "open world back to the original render scale")

ns.Profiles.Assign("dungeon", beyond)
travel("party", "Ragefire Chasm", 213, 389)
check(ns.Location.Current().key == "dungeon", "dungeon detected")
check(W.cvars.groundEffectDensity == "256", "Beyond Ultra hidden detail applied in the dungeon")
check(W.cvars.graphicsTextureResolution == "2", "heavy setting written on the loading screen")
check(not ns.Apply.Pending(), "no toast needed after a loading screen")

-- A heavy change outside a loading screen waits for the toast countdown.
W.advance(5)
-- Announcing is off by default; the countdown path needs it on.
db.options.announce = true
-- The player's own edit applies at once; the same change from a profile switch waits.
ns.Profiles.SetValue(beyond, "graphicsTextureResolution", 0)
W.advance(0.2)
check(W.cvars.graphicsTextureResolution == "0" and not ns.Apply.Pending(), "the player's own texture edit applies at once")
ns.Profiles.Get(beyond).values.graphicsTextureResolution = 1
ns.Apply.Refresh("zone")
W.advance(0.2)
local pending = ns.Apply.Pending()
check(pending and pending.values.graphicsTextureResolution == 1, "texture change queued for the toast")
W.advance(11)
check(W.cvars.graphicsTextureResolution == "1" and not ns.Apply.Pending(), "applied after the countdown")

travel("raid", "Molten Core", 232, 409)
check(ns.Location.Current().key == "raid" and ns.Apply.Active().profileId == "default", "raid uses Default")

-- Unsupported writes are noticed.
ns.Profiles.SetValue("default", "vrsValar", 2)
W.advance(1)
ns.Apply.Refresh("again")
check(not db.unsupported.vrsValar and db.limits.vrsValar == 0, "a refused value is a limit, not an unsupported setting")

-- Smart mode.
travel("none", nil, 1412, 0)
place.zone = "Mulgore"
W.slash = function(msg) SlashCmdList.FOREVERSMARTGRAPHICS(msg) end
W.slash("smart on")
W.slash("target 70")
check(ns.Smart.Enabled() and db.smart.target == 70, "slash smart on / target")
local function knobSum()
	local sum = 0
	for _, entry in ipairs(ns.Catalog.LIST) do
		if entry.smart and not entry.heavy then sum = sum + (tonumber(W.cvars[entry.cvar]) or 0) / (entry.max or 1) end
	end
	return sum
end
-- A GPU-bound scene: fps rises as settings come down (a scene that ignores cuts is handed its settings back).
local function load(seconds, base, ref)
	for _ = 1, seconds do
		W.fps = base * (1 + 3 * math.max(0, ref - knobSum()))
		W.advance(1, 1 / W.fps)
	end
end
local start = knobSum()
local before = {}
for _, entry in ipairs(ns.Catalog.LIST) do before[entry.cvar] = W.cvars[entry.cvar] end
load(40, 40, start)
local lowered = knobSum()
check(lowered < start, "smart lowered settings at low fps")
check(tonumber(W.cvars.RenderScale) >= db.smart.scaleFloor - 1e-6, "render scale never drops below the 75% default floor (" .. W.cvars.RenderScale .. ")")
W.fps = 140
-- After recovering, calm pacing holds raises for 60 s and spaces them 20 s apart.
W.advance(120, 1 / 140)
check(knobSum() > lowered, "smart raised settings again with headroom")
check(#ns.Smart.Areas() >= 1, "area memory recorded")
check(tonumber(W.cvars.RenderScale) <= 1 + 1e-6, "smart never raises render scale above 100% on its own (" .. W.cvars.RenderScale .. ")")
W.slash("smart off")
W.advance(1)
local left = {}
for _, entry in ipairs(ns.Catalog.LIST) do
	if not IGNORED[entry.cvar] and tonumber(W.cvars[entry.cvar]) ~= tonumber(before[entry.cvar]) then left[#left + 1] = entry.cvar end
end
check(#left == 0, "Smart mode off leaves no trace: " .. table.concat(left, ", "))

-- Turning the addon off turns Smart mode off first; Smart mode on turns the addon on.
W.slash("smart on")
ns.Apply.SetSwitching(false)
check(not ns.Smart.Enabled() and db.options.switching == false, "turning the addon off turns Smart mode off")
W.slash("smart on")
check(ns.Smart.Enabled() and db.options.switching == true, "Smart mode on turns the addon on")
W.slash("smart off")
W.advance(1)

-- Render scale above 100% and anti-aliasing are the player's own choice in a profile; Smart lowers the extra first.
local sharp = ns.Apply.Active().profileId
ns.Profiles.SetValue(sharp, "RenderScale", 1.35)
ns.Profiles.SetValue(sharp, "ffxAntiAliasingMode", 2)
W.advance(1)
check(tonumber(W.cvars.RenderScale) == 1.35 and W.cvars.ffxAntiAliasingMode == "2", "a profile writes 135% render scale and FXAA High")
W.slash("smart on")
load(40, 40, knobSum())
check(tonumber(W.cvars.RenderScale) < 1.35 and W.cvars.ffxAntiAliasingMode == "2", "smart lowers a supersampled profile and leaves anti-aliasing alone (" .. W.cvars.RenderScale .. ")")

-- The Eco goal caps FPS at the target and hands the player's own cap back when it ends.
local capBefore, capOnBefore = W.cvars.maxFPS, W.cvars.useMaxFPS
W.slash("goal eco")
W.advance(1)
check(tonumber(W.cvars.maxFPS) == db.smart.target and W.cvars.useMaxFPS == "1", "the Eco goal caps FPS at the target (" .. tostring(W.cvars.maxFPS) .. ")")
W.slash("goal balanced")
W.advance(1)
check(W.cvars.maxFPS == capBefore and W.cvars.useMaxFPS == capOnBefore, "leaving Eco puts the player's own cap back")
W.slash("smart off")
ns.Profiles.SetValue(sharp, "RenderScale", nil)
ns.Profiles.SetValue(sharp, "ffxAntiAliasingMode", nil)
W.advance(1)

-- Find my best settings at a display that tops out at the target changes nothing.
local capOn, cap, calm = W.cvars.useMaxFPS, W.cvars.maxFPS, knobSum()
W.cvars.useMaxFPS, W.cvars.maxFPS = "1", "60"
W.slash("findbest 60")
W.fps = 59.94
W.advance(30, 1 / 59.94)
check(ns.Calibrate.State().scenes[1].done and knobSum() == calm, "a 60 fps cap at target 60 is done in one pass with nothing cut")
W.slash("stop")
W.cvars.useMaxFPS, W.cvars.maxFPS = capOn, cap
W.advance(1)

-- Find my best settings.
W.slash("findbest 60")
check(ns.Calibrate.State().running, "calibration running")
W.fps = 50
W.advance(130, 1 / 50)
travel("none", "Orgrimmar", 85, 0)
place.resting = true
W.advance(130, 1 / 50)
W.slash("finish")
local best = ns.Profiles.FindByName and ns.Profiles.FindByName("Best for 60 FPS")
check(best and db.locations.city == best and db.locations.outdoor == best, "Finish saves and assigns Best for 60 FPS")
check(not ns.Smart.Enabled(), "smart stays off after Finish")

-- The window.
W.slash("")
local window = ns.UI.Current()
check(window and window:IsShown(), "/fsg opens the window")
for _, key in ipairs({ "PADDDOWN", "PADDDOWN", "PADDRIGHT", "PADRSHOULDER", "PADRSHOULDER", "PADRSHOULDER", "PADLSHOULDER" }) do W.press(window, key) end
check(ns.UI.Current(), "tabs and D-pad moves keep the window open")
W.combat = true
fire("PLAYER_REGEN_DISABLED")
check(not ns.UI.Current(), "combat closes the window")
fire("PLAYER_REGEN_ENABLED")
W.combat = false
ForeverSmartGraphics_OnCompartmentClick()
W.advance(0.1)
check(ns.UI.Current(), "the compartment opens the window")
W.press(ns.UI.Current(), "PAD2")
W.press(ns.UI.Current(), "PAD2")
check(not ns.UI.Current(), "B goes to the page list, B again closes it")
check(#W.trapped == 0, "no forbidden Blizzard UI touched: " .. table.concat(W.trapped, "; "))

-- Restore puts the original back.
-- A macro holds a profile: the engine and the window agree, and the location assignments stay.
local heldId, cityBefore = ns.Profiles.FromPreset("ultra"), db.locations.city
W.slash("profile " .. ns.Profiles.Get(heldId).name)
check(ns.Apply.Active().source == "held" and ns.Apply.Active().profileId == heldId and db.locations.city == cityBefore, "/fsg profile holds a profile everywhere")
check(ns.UI.WhyLine():find("holding the profile", 1, true), "the window says a profile is held")
W.slash("profile auto")
check(ns.Apply.Active().source ~= "held" and db.held == nil, "/fsg profile auto goes back to the location's profile")

-- What's new: the generated notes, the saved state and the window agree. Only closing the window stores the version.
db.news.seen = "1.0.0-beta.1"
local pending = ns.News.Pending()
check(pending and pending.from == "1.0.0-beta.1" and pending.entries[1] == ns.NEWS[1], "an update lists the notes since the last seen version, newest first")
W.slash("whatsnew")
check(ns.UI.Current() == ns.UI.WhatsNew() and db.news.seen == "1.0.0-beta.1", "/fsg whatsnew opens the window and stores nothing yet")
W.press(ns.UI.Current(), "PAD2")
check(not ns.UI.Current() and db.news.seen == ns.News.Running() and not ns.News.Pending(), "closing it records the running version")

ns.Apply.RestoreOriginal()
local wrong = {}
for cvar, value in pairs(db.original) do
	if not IGNORED[cvar] and W.cvars[cvar] and tonumber(W.cvars[cvar]) ~= tonumber(value) and cvar ~= "RenderScale" then wrong[#wrong + 1] = cvar end
end
check(#wrong == 0, "restore puts every original back: " .. table.concat(wrong, ", "))
check(math.abs(tonumber(W.cvars.RenderScale) - 0.75) < 0.01, "render scale restored")

for _, line in ipairs(W.log) do
	if line:find("error") or line:find("skipped") then error("FAIL: chat error line: " .. line) end
end
io.write("load_spec: ", checks, " checks passed\n")
