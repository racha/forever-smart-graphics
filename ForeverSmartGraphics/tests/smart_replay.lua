-- Replay of Smart mode against a small GPU model (fps follows the cvars in force). Prints change counts per
-- scenario; it asserts nothing. Run from the repo root: lua ForeverSmartGraphics/tests/smart_replay.lua
local script = arg and arg[0] or ""
local dir = "ForeverSmartGraphics"
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
function GetMaxRenderScale() return 1 end
function GetGraphicsCVarValueForQualityLevel(_, level) return math.floor(level / 2) end
function IsGraphicsCVarValueSupported() return 0 end
time = function() return 1794900000 + math.floor(W.clock) end
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

-- An independent replay: a small GPU model drives fps from the cvars in force.
local CEIL = 74.5
local seed = 7
local function noise() seed = (seed * 1103515245 + 12345) % 2147483648 return (seed / 2147483648 - 0.5) * 0.6 end
local function num(c) return tonumber(W.cvars[c]) or 0 end
local function raw(load)
	local f = load
	f = f * 1.07 ^ ((0.75 - num("RenderScale")) / 0.05)
	if num("shadowSoft") >= 1 then f = f * 0.89 end
	f = f * 1.025 ^ (3 - num("graphicsSSAO")) * 1.02 ^ (2 - num("graphicsComputeEffects")) * 1.025 ^ (1 - num("graphicsLightMode"))
	if num("ResampleQuality") <= 2 and num("RenderScale") < 1 then f = f * 1.03 end
	return f
end
local function run(seconds, load, dipEvery, dipTo)
	for s = 1, seconds do
		local fps = math.min(CEIL, raw(load)) + noise()
		if dipEvery and s % dipEvery < 3 then fps = dipTo end
		W.fps = fps
		W.advance(1, 1 / fps)
	end
end
local mark = 0
local function since(label, keep)
	local list, counts = {}, 0
	for i = mark + 1, #writes do
		counts = counts + 1
		if counts <= (keep or 14) then list[#list + 1] = writes[i][1]:gsub("graphics", "") .. "=" .. tostring(writes[i][2]) end
	end
	mark = #writes
	local st = ns.Smart.State()
	io.write(string.format("%-34s %3d writes | status %-22s goal %s ceil %s | RS %s soft %s ssao %s comp %s light %s view %s shadowQ %s depth %s\n   %s\n",
		label, counts, tostring(st.status), tostring(st.goal and math.floor(st.goal * 10) / 10), tostring(st.ceiling and math.floor(st.ceiling * 10) / 10),
		W.cvars.RenderScale, W.cvars.shadowSoft, W.cvars.graphicsSSAO, W.cvars.graphicsComputeEffects, W.cvars.graphicsLightMode, W.cvars.graphicsViewDistance, W.cvars.graphicsShadowQuality, W.cvars.graphicsDepthEffects,
		table.concat(list, ", ")))
end
local function zone(map, name)
	place.resting, place.map, place.zone = false, map, name
	fire("PLAYER_UPDATE_RESTING")
	fire("ZONE_CHANGED_NEW_AREA")
end

W.slash = function(msg) SlashCmdList.FOREVERSMARTGRAPHICS(msg) end
zone(1421, "Silverpine Forest")
W.fps = CEIL
W.advance(3, 1 / CEIL)
W.slash("smart on")
W.slash("target 75")
mark = #writes
io.write("\nS1 light scene (raw 100 at original), ceiling 74.5, target 75\n")
run(600, 100); since("first 10 min")
run(1200, 100); since("next 20 min (stable)")
io.write("\nS2 same, 3 s dips to 55 every 40 s\n")
run(1800, 100, 40, 55); since("30 min with transients")
io.write("\nS3 walk to a heavy zone (raw 62 at original), then back, twice\n")
zone(1420, "Tirisfal Glades"); run(600, 62); since("B first visit 10 min")
zone(1421, "Silverpine Forest"); run(300, 100); since("A return 5 min")
zone(1420, "Tirisfal Glades"); run(300, 62); since("B return 5 min")
zone(1421, "Silverpine Forest"); run(300, 100); since("A return 5 min")
io.write("\nS4 subzone crossings inside A\n")
local subs = { "The Sepulcher", "The Dead Field", "" }
function GetSubZoneText() return subs[1] end
for i = 1, 6 do subs[1] = ({ "The Sepulcher", "The Dead Field", "" })[i % 3 + 1]; fire("ZONE_CHANGED"); run(60, 100) end
since("6 subzone crossings, 6 min")
io.write("\nS5 sustained heavy fight-free load in A (raw 58)\n")
run(600, 58); since("10 min at raw 58")
run(600, 100); since("load gone, 10 min")
run(1200, 100); since("load gone, next 20 min")
io.write("\nMachine 2: no display limit (uncapped), Max Background FPS on at 30; learning starts over\n")
CEIL = math.huge
W.cvars.useMaxFPSBk, W.cvars.maxFPSBk = "1", "30"
db.smart.ceiling = nil
ns.Smart.ResetLearning()
mark = #writes
io.write("\nM2-S1 light scene (raw 100 at original), target 75\n")
run(1200, 100); since("20 min")
io.write("\nM2-S2 alt-tabbed 5 min (the background cap), then back\n")
for _ = 1, 300 do W.fps = 30; W.advance(1, 1 / 30) end
since("5 min in the background")
run(600, 100); since("10 min back")
io.write("\nM2-S3 heavy 5 min (raw 50), then light again\n")
run(300, 50); since("5 min heavy")
run(1800, 100); since("30 min light")

for _, line in ipairs(W.log) do if line:find("error") or line:find("skipped") then io.write("CHAT ERROR: " .. line .. "\n") end end
