-- Smart.lua spec (smart-v3) over its own minimal ns stub: trace replays with a frame ceiling, transients, sustained load
-- and zone walks. Run: lua ForeverSmartGraphics/tests/smart_spec.lua
local script = arg and arg[0] or ""
local dir = script:match("^(.*)[/\\]tests[/\\]") or (script:match("^tests[/\\]") and ".") or "ForeverSmartGraphics"
local SMART = dir .. "/Smart.lua"

local passed, failures = 0, {}
local function check(name, cond, detail)
	if cond then passed = passed + 1 else failures[#failures + 1] = name .. (detail ~= nil and (": " .. tostring(detail)) or "") end
end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6) end

local T, store, speed, frame
GetTime = function() return T end
time = function() return math.floor(T) end
CreateFrame = function()
	local f = { scripts = {} }
	function f:SetScript(name, fn) self.scripts[name] = fn end
	frame = f
	return f
end
C_CVar = {
	GetCVar = function(name) return store[name] ~= nil and tostring(store[name]) or nil end,
	SetCVar = function(name, value) store[name] = tonumber(value) or value end,
}
GetUnitSpeed = function() return speed, 7, 7, 4.7 end
local subzone, zone, timers = "", "Stormwind City", {}
local locKey, mapKey = "city", "map:1"
GetSubZoneText = function() return subzone end
GetRealZoneText = function() return zone end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { T + delay, fn } end }

-- Knobs as in the real Catalog (the ladder's and the zero-gain ones); texture filtering is heavy, weather not smart.
local LIST = {
	{ cvar = "RenderScale", min = 0.33, max = 2.0, step = 0.05, visual = 4, smart = true },
	{ cvar = "ResampleQuality", min = 0, max = 3, step = 1, visual = 2, smart = true },
	{ cvar = "shadowSoft", min = 0, max = 1, step = 1, visual = 2, smart = true },
	{ cvar = "graphicsSSAO", min = 0, max = 4, step = 1, visual = 2, smart = true },
	{ cvar = "graphicsComputeEffects", min = 0, max = 4, step = 1, visual = 2, smart = true },
	{ cvar = "graphicsLightMode", min = 0, max = 3, step = 1, visual = 3, smart = true },
	{ cvar = "graphicsSpellDensity", min = 0, max = 2, step = 1, visual = 1, smart = true },
	{ cvar = "graphicsParticleDensity", min = 1, max = 5, step = 1, visual = 2, smart = true },
	{ cvar = "groundEffectDensity", min = 16, max = 256, step = 16, visual = 2, smart = true },
	{ cvar = "graphicsShadowQuality", min = 0, max = 5, step = 1, visual = 3, smart = true },
	{ cvar = "graphicsViewDistance", min = 0, max = 9, step = 1, visual = 4, smart = true },
	{ cvar = "graphicsEnvironmentDetail", min = 0, max = 9, step = 1, visual = 3, smart = true },
	{ cvar = "graphicsDepthEffects", min = 0, max = 3, step = 1, visual = 2, smart = true },
	{ cvar = "graphicsGroundClutter", min = 0, max = 9, step = 1, visual = 2, smart = true },
	{ cvar = "graphicsLiquidDetail", min = 0, max = 3, step = 1, visual = 1, smart = true },
	{ cvar = "sunShafts", min = 0, max = 2, step = 1, visual = 1, smart = true },
	{ cvar = "textureFilteringMode", min = 0, max = 5, step = 1, visual = 1, smart = true, heavy = true },
	{ cvar = "weatherDensity", min = 0, max = 3, step = 1, visual = 1 },
}
local byCvar = {}
for _, e in ipairs(LIST) do byCvar[e.cvar] = e end
local PROBED = { RenderScale = 6, shadowSoft = 11, ResampleQuality = 3, graphicsSSAO = 2.5, graphicsLightMode = 2.5, graphicsComputeEffects = 2 }
local ZERO = { graphicsShadowQuality = true, graphicsViewDistance = true, graphicsEnvironmentDetail = true, graphicsDepthEffects = true, graphicsGroundClutter = true, graphicsLiquidDetail = true, sunShafts = true }

-- A player's profile (graphicsQuality 5-ish) and an all-max one.
local PROFILE = {
	RenderScale = 1.0, ResampleQuality = 3, shadowSoft = 1, graphicsSSAO = 3, graphicsComputeEffects = 2, graphicsLightMode = 2,
	graphicsSpellDensity = 2, graphicsParticleDensity = 4, groundEffectDensity = 32, graphicsShadowQuality = 3, graphicsViewDistance = 5,
	graphicsEnvironmentDetail = 5, graphicsDepthEffects = 2, graphicsGroundClutter = 5, graphicsLiquidDetail = 2, sunShafts = 1,
	textureFilteringMode = 5, weatherDensity = 3,
}
local MAX = {}
for _, e in ipairs(LIST) do MAX[e.cvar] = e.max end
MAX.weatherDensity, MAX.RenderScale = 3, 1.0

local ns, profile
local function copy(t) local out = {} for k, v in pairs(t) do out[k] = v end return out end

local function newNs(opts)
	local handlers = {}
	local n = { commands = {}, logs = {}, fired = {}, writes = {}, held = {}, refreshes = 0, created = {}, overrides = {} }
	function n.On(event, fn) handlers[event] = handlers[event] or {}; table.insert(handlers[event], fn) end
	function n.Fire(msg, ...) n.fired[#n.fired + 1] = msg; for _, fn in ipairs(handlers[msg] or {}) do fn(...) end end
	function n.log(msg) n.logs[#n.logs + 1] = msg end
	function n.debug() end
	function n.plain(v) return v end
	function n.InCombat() return false end
	n.db = { options = {}, smart = { enabled = false, target = 60, scaleFloor = 0.75, learned = {} }, unsupported = {} }
	if opts and opts.coreOnly then return n end
	n.Catalog = {
		LIST = LIST,
		PRIOR = { RenderScale = 6, shadowSoft = 11, ResampleQuality = 3, graphicsSSAO = 2.5, graphicsLightMode = 2.5, graphicsComputeEffects = 2 },
		Impact = function(cvar)
			local probe = PROBED[cvar]
			return nil, probe, probe and "probe" or "estimate"
		end,
		Get = function(cvar) return byCvar[cvar] end,
		Step = function(cvar, value, d)
			local e = byCvar[cvar]
			local v = value + d * e.step
			if v < e.min - 1e-9 or v > e.max + 1e-9 then return nil end
			return v
		end,
	}
	n.Profiles = {
		Effective = function() return copy(profile) end,
		Create = function(name, values) n.created[#n.created + 1] = { name = name, values = values }; return "p1" end,
		SetOverride = function(key, name, id) n.overrides[#n.overrides + 1] = { key, name, id }; return true end,
	}
	n.Location = {
		LABELS = { city = "City", outdoor = "Open world", raid = "Raid" },
		Current = function() return { key = locKey, overrideKey = mapKey, name = zone } end,
		ProfileFor = function() return "default" end,
	}
	n.Apply = {
		-- Like the engine: in combat an automatic write is held ("combat"); only the player's own goes through.
		Write = function(cvar, value, reason, wopts)
			if n.InCombat() and not (wopts and wopts.user) then
				n.held[#n.held + 1] = { cvar, value, reason }
				return false, "combat"
			end
			n.writes[#n.writes + 1] = { cvar, value, reason, T, store[cvar], wopts }
			store[cvar] = value
			return true, value
		end,
		Target = function()
			local values = n.Profiles.Effective()
			if n.Smart and n.Smart.Enabled() then return n.Smart.Adjust(locKey, values) end
			return values
		end,
		SetSwitching = function(on) n.db.options.switching = on end,
		-- The location refresh: the profile through Smart.Adjust, written where it differs (one batch).
		Refresh = function()
			if n.db.options.switching == false then return end
			n.refreshes = n.refreshes + 1
			if not (n.Smart and n.Smart.Enabled()) then return end
			local values = n.Smart.Adjust(locKey, n.Profiles.Effective())
			for _, e in ipairs(LIST) do
				local v = values[e.cvar]
				if v ~= nil and not near(tonumber(store[e.cvar]), v) then n.Apply.Write(e.cvar, v, "location") end
			end
		end,
	}
	-- Apply listens before Smart (load order), as in the addon.
	n.On("FSG_LOCATION", function() n.Apply.Refresh() end)
	return n
end

local function fresh(values, opts)
	T, speed, subzone, zone, timers, locKey, mapKey = 1000, 0, "", "Stormwind City", {}, "city", "map:1"
	profile = copy(values or PROFILE)
	store = copy(profile)
	store.useMaxFPS, store.maxFPS = "0", 0
	ns = newNs(opts)
	assert(loadfile(SMART))("ForeverSmartGraphics", ns)
	ns.Fire("FSG_READY")
	return ns.Smart
end

-- Drives the sampler for seconds at fps (a number, or a function of the cvar store and the time).
local function run(seconds, fps)
	local stop = T + seconds
	while T < stop do
		local f = type(fps) == "function" and fps(store, T) or fps
		local dt = 1 / f
		T = T + dt
		for i = #timers, 1, -1 do
			local t = timers[i]
			if t[1] <= T then table.remove(timers, i); t[2]() end
		end
		local onUpdate = frame.scripts.OnUpdate
		if onUpdate then onUpdate(frame, dt) end
	end
end

local function go(map, key, name)
	mapKey, locKey, zone, subzone = map, key or "city", name or map, ""
	ns.Fire("FSG_LOCATION", { key = locKey, overrideKey = mapKey, name = zone }, nil, false)
end

local function start(S, target)
	if target then S.SetTarget(target) end
	S.SetEnabled(true)
	go("map:1", "city", "Stormwind City")
end

local function writesOf(cvar)
	local out = {}
	for _, w in ipairs(ns.writes) do if w[1] == cvar then out[#out + 1] = w[2] end end
	return out
end
local function decisions(from)
	local out = {}
	for i = (from or 0) + 1, #ns.writes do
		local w = ns.writes[i]
		if w[3] ~= "location" then out[#out + 1] = w end
	end
	return out
end
local function fired(msg)
	local n = 0
	for _, m in ipairs(ns.fired) do if m == msg then n = n + 1 end end
	return n
end
local function uniqueTimes(list)
	local seen, n = {}, 0
	for _, w in ipairs(list) do if not seen[w[4]] then seen[w[4]], n = true, n + 1 end end
	return n
end
local function seeCeiling(fps) ns.db.smart.ceiling = { fps = fps, t = time(), confirmed = true } end
-- A GPU-bound scene: render scale moves fps (5 per 0.05 step), the rest a little.
local function gpu(base) return function(st) return base + (1 - st.RenderScale) * 100 + (1 - st.shadowSoft) * 1 end end
-- The rungs taken in values form a prefix of the ladder (cuts never skip ahead).
local function prefix(rungs, values)
	local k = 0
	for i, r in ipairs(rungs) do
		if values[r.cvar] <= r.to + 1e-6 then
			if k ~= i - 1 then return false end
			k = i
		end
	end
	return true, k
end
-- Replays writes over a copy of values; after each batch (one timestamp) the ladder prefix must hold.
local function prefixHeld(rungs, values, list)
	local v, ok = copy(values), true
	for i, w in ipairs(list) do
		v[w[1]] = w[2]
		if (not list[i + 1] or list[i + 1][4] ~= w[4]) and not prefix(rungs, v) then ok = false end
	end
	return ok
end
-- The replay's model: fps follows the probed knobs, everything else costs nothing; the display tops out at 74.5.
local function owner(load)
	return function(st)
		local f = load * 1.07 ^ ((0.75 - st.RenderScale) / 0.05)
		if st.shadowSoft >= 1 then f = f * 0.89 end
		f = f * 1.025 ^ (3 - st.graphicsSSAO) * 1.02 ^ (2 - st.graphicsComputeEffects) * 1.025 ^ (1 - st.graphicsLightMode)
		if st.ResampleQuality <= 2 and st.RenderScale < 1 then f = f * 1.03 end
		return math.min(74.5, f)
	end
end
local MACHINE = copy(PROFILE)
MACHINE.RenderScale, MACHINE.shadowSoft, MACHINE.graphicsLightMode, MACHINE.graphicsSpellDensity, MACHINE.graphicsParticleDensity = 0.75, 0, 1, 1, 3
MACHINE.graphicsDepthEffects, MACHINE.sunShafts = 3, 2

-- Loads with only Core present.
do
	local S = fresh(nil, { coreOnly = true })
	check("core only: State off", S.State().status == "off")
	S.SetEnabled(true)
	local ok, err = pcall(run, 20, 30)
	check("core only: sampler runs without engine", ok, err)
	check("core only: Adjust copies", S.Adjust("city", { a = 1 }).a == 1)
	check("core only: SaveAsProfile nil", S.SaveAsProfile("city", "x") == nil)
end

-- Sampler: the lag watcher samples while smart mode is off unless suggestions are off.
do
	local S = fresh()
	check("off: lag watcher samples by default", frame.scripts.OnUpdate ~= nil and ns.db.options.suggest == true)
	S.SetSuggest(false)
	check("off, no suggestions: no OnUpdate", frame.scripts.OnUpdate == nil)
	S.SetEnabled(true)
	check("on: OnUpdate set, Apply refreshed", frame.scripts.OnUpdate ~= nil and ns.refreshes == 1)
	S.SetEnabled(false)
	check("off again: no OnUpdate, status off", frame.scripts.OnUpdate == nil and S.State().status == "off")
	check("floor clamps", S.SetFloor(0.1) == 0.33 and S.SetFloor(2) == 1)
	check("target clamps", S.SetTarget(5) == 20 and S.SetTarget(500) == 240 and S.SetTarget(72.4) == 72)
end

-- Smart off leaves no trace (even with switching already off); on turns switching on; refused while Find my best
-- settings runs.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(300, gpu(40))
	local cut = store.shadowSoft == 0 and store.RenderScale < 1
	ns.db.options.switching = false
	S.SetEnabled(false)
	local back = true
	for cvar, v in pairs(PROFILE) do if not near(tonumber(store[cvar]), v) then back = false end end
	check("off: every knob back at the profile, written by Smart", cut and back and ns.writes[#ns.writes][3] == "smart mode off")
	check("on: turns switching on first", S.SetEnabled(true) == true and ns.db.options.switching == true and S.Enabled())
	S.SetEnabled(false)
	ns.Calibrate = { State = function() return { running = true } end }
	local n = ns.refreshes
	check("on: refused while Find my best settings runs", S.SetEnabled(true) == false and not S.Enabled() and ns.refreshes == n)
	ns.commands.smart({ "on" })
	check("slash: smart on says why it stays off", not S.Enabled() and ns.logs[#ns.logs]:find("Find my best settings") ~= nil, ns.logs[#ns.logs])
	ns.Calibrate = nil
	ns.commands.smart({ "toggle" })
	check("slash: smart with another word prints usage", ns.logs[#ns.logs] == "Usage: /fsg smart [on|off]", ns.logs[#ns.logs])
end

-- Render scale off Smart's 0.05 grid (the client's own snap): no tiny rungs, and the same value is not rewritten.
do
	local grid = copy(PROFILE)
	grid.RenderScale = 0.7533
	local S = fresh(grid)
	local tiny = false
	for _, r in ipairs(S.Ladder()) do if r.cvar == "RenderScale" and math.abs(r.from - r.to) < 0.025 then tiny = true end end
	check("grid: no render scale rung under half a step", not tiny)
	store.RenderScale = 0.7533
	start(S, 60)
	run(600, gpu(30))
	local tinyWrite = false
	for _, w in ipairs(ns.writes) do if w[1] == "RenderScale" and math.abs(w[2] - tonumber(w[5])) < 0.025 then tinyWrite = true end end
	check("grid: no render scale write under half a step", not tinyWrite)
end

-- The ladder, from the profile: best FPS per visible loss first; zero-gain knobs never on it.
do
	local S = fresh()
	local rungs = S.Ladder()
	local names = {}
	for i, r in ipairs(rungs) do names[i] = r.cvar:gsub("graphics", "") .. " " .. ("%g>%g"):format(r.from, r.to) end
	local want = { "shadowSoft 1>0", "RenderScale 1>0.95", "RenderScale 0.95>0.9", "ResampleQuality 3>2", "SSAO 3>2", "ComputeEffects 2>1", "RenderScale 0.9>0.85", "LightMode 2>1", "RenderScale 0.85>0.8", "RenderScale 0.8>0.75", "SSAO 2>1", "ComputeEffects 1>0", "SpellDensity 2>1", "ParticleDensity 4>3", "groundEffectDensity 32>16" }
	check("ladder: balanced order from the profile", table.concat(names, ", ") == table.concat(want, ", "), table.concat(names, ", "))
	local zeroOnLadder = false
	for _, r in ipairs(rungs) do if ZERO[r.cvar] then zeroOnLadder = true end end
	check("ladder: zero-gain knobs never on it", not zeroOnLadder)
	S.SetGoal("fps")
	local first = S.Ladder()[1]
	local light = 3
	for _, r in ipairs(S.Ladder()) do if r.cvar == "graphicsLightMode" then light = math.min(light, r.to) end end
	check("ladder: FPS goal starts with the CPU rungs and may take lighting to 0", first.cvar == "graphicsSpellDensity" and light == 0, first.cvar)
	S.SetGoal("fidelity")
	local lowest = 1
	for _, r in ipairs(S.Ladder()) do if r.cvar == "RenderScale" then lowest = math.min(lowest, r.to) end end
	check("ladder: Fidelity keeps render scale at 0.90", near(lowest, 0.9), lowest)
	S.SetGoal("balanced")
	S.SetFloor(0.6)
	lowest = 1
	for _, r in ipairs(S.Ladder()) do if r.cvar == "RenderScale" then lowest = math.min(lowest, r.to) end end
	check("ladder: down to the user's floor", near(lowest, 0.6), lowest)
end

-- 1. Ceiling 74.5, target 75: goal about 72; 30 min flat -> at most one batch at the start, then nothing.
do
	local S = fresh(MAX)
	start(S, 75)
	run(1800, 74.5)
	local s = S.State()
	check("ceiling: learned from a flat top", near(s.ceiling, 74.5, 0.3), s.ceiling)
	check("ceiling: goal = 97% of it", near(s.goal, 74.5 * 0.97, 0.3), s.goal)
	check("ceiling: 30 min flat, no changes", #decisions() == 0, #decisions())
	ns.commands.smart()
	check("ceiling: status line says where the display tops out", ns.logs[#ns.logs]:find("target 75, holding 72 %(display tops out at 7[45]%)") ~= nil, ns.logs[#ns.logs])
end

-- A busy scene is not a display limit: 10 min at 55-66 fps (not flat at the top) sets no ceiling, so it cuts toward
-- the target.
do
	local S = fresh()
	start(S, 75)
	run(600, function(st, t) return 55 + 11 * (math.floor(t) % 10) / 9 + (1 - st.RenderScale) * 100 end)
	check("ceiling: a busy scene sets none", S.State().ceiling == nil and ns.db.smart.ceiling == nil)
	check("ceiling: so the target stands and it cuts", near(S.State().goal, 75) and #decisions() >= 1, #decisions())
end

-- 2. Same, with 3 s dips to 55 every 40 s: no cuts.
do
	local S = fresh(MAX)
	start(S, 75)
	run(1800, function(_, t) return (t % 40) < 3 and 55 or 74.5 end)
	check("transients: 3 s dips every 40 s cut nothing", #decisions() == 0, #decisions())
end

-- A hitch second (one 500 ms frame, the rest fine) never counts.
do
	local S = fresh(MAX)
	seeCeiling(74.5)
	start(S, 75)
	local count = 0
	run(600, function()
		count = count + 1
		return count % 74 == 0 and 2 or 74.5
	end)
	check("hitches: never count toward short", #decisions() == 0, #decisions())
end

-- Alt-tabbed at the background cap (30) or minimised (one frame every 2 s): not samples, nothing cut.
do
	local S = fresh(MAX)
	store.useMaxFPSBk, store.maxFPSBk = "1", 30
	seeCeiling(60)
	start(S, 60)
	run(120, 60)
	local n = #ns.writes
	run(300, 30)
	run(120, 0.5)
	check("background: alt-tab and minimised seconds cut nothing", #decisions(n) == 0, #decisions(n))
end

-- A machine with no frame cap: fps follows the costly knobs (relative to PROFILE), with a little noise.
local seed = 11
local function noise(amp)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return (seed / 2147483648 - 0.5) * 2 * amp
end
local function uncapped(load)
	return function(st)
		local f = load * 1.07 ^ ((1.0 - st.RenderScale) / 0.05) * (st.shadowSoft >= 1 and 1 or 1 / 0.89)
		f = f * 1.025 ^ (3 - st.graphicsSSAO) * 1.02 ^ (2 - st.graphicsComputeEffects) * 1.025 ^ (2 - st.graphicsLightMode)
		if st.ResampleQuality <= 2 and st.RenderScale < 1 then f = f * 1.03 end
		return f + noise(1)
	end
end

-- A taxi flight or a cinematic: not samples, and no zone memory written on a taxi.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(60, 74.5)
	local n = #ns.writes
	local taxi = true
	UnitOnTaxi = function() return taxi end
	go("map:3", "outdoor", "Fields")
	run(300, 30)
	check("taxi: nothing cut, no zone remembered", #decisions(n) == 0 and ns.db.smart.areas["map:3"] == nil, #decisions(n))
	UnitOnTaxi = nil
	S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(60, 74.5)
	n = #ns.writes
	ns.Fire("CINEMATIC_START")
	run(300, 30)
	ns.Fire("CINEMATIC_STOP")
	check("cinematic: nothing cut", #decisions(n) == 0, #decisions(n))
end

-- No frame cap: 5 min heavy (42 at the profile), then light (95): the steady level is not a limit, the cuts come back.
do
	local S = fresh()
	start(S, 60)
	run(300, uncapped(42))
	local cut = store.shadowSoft == 0
	run(3600, uncapped(95))
	check("no cap: a steady scene is not a limit, cuts undone", cut and near(store.RenderScale, 1.0) and store.shadowSoft == 1 and S.Limit() == nil, store.RenderScale)
	ns.commands.smart()
	check("no cap: the status line names no display limit", not ns.logs[#ns.logs]:find("tops out"), ns.logs[#ns.logs])
end

-- 3. Sustained GPU load under a known 74.5 ceiling: cuts are ladder prefixes (batches when far short); lighting stays
-- at 1 or more; the zero-gain knobs are never lowered; stutters at least 20 s apart; the budget never holds a cut back.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	local rungs = S.Ladder()
	run(3600, gpu(40))
	local cuts = decisions()
	check("sustained: cuts are ladder prefixes", #cuts >= 6 and prefixHeld(rungs, PROFILE, cuts), #cuts)
	local light, zero = 3, false
	for _, w in ipairs(cuts) do
		if w[1] == "graphicsLightMode" then light = math.min(light, w[2]) end
		if ZERO[w[1]] then zero = true end
	end
	check("sustained: lighting never below 1", light >= 1, light)
	check("sustained: shadow quality, view distance, depth effects and friends never lowered while cuts are left", not zero)
	local hitchGap, last = math.huge, nil
	for _, w in ipairs(cuts) do
		if w[1] == "RenderScale" then
			if last and w[4] ~= last then hitchGap = math.min(hitchGap, w[4] - last) end
			last = w[4]
		end
	end
	check("stutter: render scale writes at least 20 s apart", hitchGap >= 20, hitchGap)
	check("sustained: at the floor", S.State().status == "at floor" or S.State().status == "holding", S.State().status)
end

-- 4. Recovery: raises undo the cuts in reverse order; a probe that costs 3% is reverted and the zone stops probing.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	local rungs = S.Ladder()
	local phase = "load"
	local load = gpu(55)
	run(1500, function(st)
		if phase == "load" then return load(st) end
		return st.shadowSoft == 1 and 72 or 74.5
	end)
	local cuts = decisions()
	local n = #ns.writes
	local v = copy(store)
	phase = "free"
	run(3600, function(st) return st.shadowSoft == 1 and 72 or 74.5 end)
	local ups, reverse = decisions(n), true
	for _, w in ipairs(ups) do
		local want
		for i = #rungs, 1, -1 do
			local r = rungs[i]
			if v[r.cvar] <= r.to + 1e-6 then want = r break end
		end
		if want and not (want.cvar == w[1] and near(want.from, w[2])) and not ZERO[w[1]] then reverse = false end
		v[w[1]] = w[2]
	end
	check("recovery: raises undo the cuts in reverse order, one rung each", #cuts >= 1 and #ups >= 3 and reverse, #ups .. "/" .. #cuts)
	check("recovery: soft shadows (3% here) tried, reverted", store.shadowSoft == 0 and #writesOf("shadowSoft") >= 3)
	local a = ns.db.smart.areas["map:1"]
	check("recovery: the zone keeps its best and stops probing", a and a.best == 1 and S.State().best == 1 and S.State().status == "best look at target", a and a.best)
	local m = #ns.writes
	run(1800, function(st) return st.shadowSoft == 1 and 72 or 74.5 end)
	check("recovery: no more probes in that zone", #ns.writes == m, #ns.writes - m)
	local sg = ns.db.smart.gains.shadowSoft
	check("learn: the reverted probe fed its cost (fps came back)", sg and sg.n >= 1 and sg.ema > 0.5, sg and (sg.n .. "/" .. sg.ema))
end

-- 5. Walk A -> B -> A: one batch per entry, no decisions while stable, identical values on each return.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	local function model()
		if mapKey == "map:2" then return math.min(74.5, 56 + 3 * S.State().pos) end
		return 74.5
	end
	go("map:1", "city", "A")
	run(1800, model)
	go("map:2", "city", "B")
	run(1800, model)
	local function snapshot()
		local out = {}
		for _, e in ipairs(LIST) do out[#out + 1] = tostring(store[e.cvar]) end
		return table.concat(out, ",")
	end
	local seen, quiet, batches = {}, true, {}
	for i = 1, 4 do
		local map = i % 2 == 1 and "map:1" or "map:2"
		local from = #ns.writes
		go(map, "city", map == "map:1" and "A" or "B")
		local entered = #ns.writes
		run(300, model)
		if #ns.writes ~= entered then quiet = false end
		batches[#batches + 1] = entered - from
		local snap = snapshot()
		if seen[map] and seen[map] ~= snap then quiet = false end
		seen[map] = snap
	end
	check("walk: a batch on each entry, then nothing while stable", quiet and batches[1] > 0 and batches[1] == batches[3] and batches[2] == batches[4], table.concat(batches, ","))
	check("walk: identical values on each return", seen["map:1"] ~= seen["map:2"])
	local a, b = ns.db.smart.areas["map:1"], ns.db.smart.areas["map:2"]
	check("walk: each zone keeps its own position", a and b and b.pos > a.pos, a and b and (tostring(a.pos) .. "/" .. tostring(b.pos)))

	-- 6. Subzone crossings inside a zone: no writes.
	local n = #ns.writes
	for _, sub in ipairs({ "Bank", "Trade District", "Old Town", "" }) do
		subzone = sub
		ns.Fire("ZONE_CHANGED")
		run(30, model)
	end
	check("subzones: crossing them writes nothing", #ns.writes == n, #ns.writes - n)
	check("subzones: same zone", S.State().area.key == "map:2")
end

-- Fights here run under the lowering line: no raises between pulls; a raise not yet judged goes back at the pull.
do
	local S = fresh()
	seeCeiling(74.5)
	ns.db.smart.areas["map:1"] = { locKey = "city", combatFps = 40 }
	start(S, 70)
	run(600, 74.5)
	check("fights: no raises where fights are slow", #decisions() == 0, #decisions())
	S = fresh()
	seeCeiling(74.5)
	start(S, 70)
	local stop = T + 600
	while S.State().status ~= "raising (testing)" and T < stop do run(1, 74.5) end
	ns.InCombat = function() return true end
	ns.Fire("FSG_COMBAT_START")
	check("fights: a raise not yet judged goes back at the pull", #ns.held > 0 and ns.held[1][2] == PROFILE[ns.held[1][1]], #ns.held)
	ns.InCombat = function() return false end
end

-- Large headroom undoes up to 4 rungs in one probe.
do
	local S = fresh()
	ns.db.smart.areas["map:1"] = { locKey = "city", pos = 8, posAt = time() }
	start(S, 60)
	local entry = #ns.writes
	run(120, uncapped(95))
	local ups = {}
	for _, w in ipairs(decisions(entry)) do if w[2] > w[5] then ups[#ups + 1] = w end end
	check("headroom: 8 cuts back in at most 3 probes", S.State().pos <= 0 and uniqueTimes(ups) <= 3, uniqueTimes(ups))
end

-- A raise that costs over 10%: undone; when fps comes back it was the raise, so the zone keeps its best.
do
	local S = fresh()
	seeCeiling(74.5)
	ns.db.smart.areas["map:1"] = { locKey = "city", pos = 1, posAt = time() }
	start(S, 75)
	run(1800, function(st) return st.shadowSoft == 1 and 60 or 74.5 end)
	local a = ns.db.smart.areas["map:1"]
	local soft = 0
	for _, w in ipairs(decisions()) do if w[1] == "shadowSoft" then soft = soft + 1 end end
	check("big cost: the zone keeps its best, no repeat", a.best == 1 and soft == 2, soft)
end

-- Settings changes reopen every zone; a higher minimum lifts render scale now.
do
	local S = fresh()
	ns.db.smart.areas["map:5"] = { locKey = "city", best = 2, settledFps = 60, waitUntil = time() + 900 }
	S.SetTarget(70)
	local a = ns.db.smart.areas["map:5"]
	check("settings: a target change reopens zones", a.best == nil and a.settledFps == nil and a.waitUntil == nil)
	S.SetFloor(0.6)
	start(S, 60)
	store.RenderScale = 0.65
	S.SetFloor(0.9)
	check("settings: a higher minimum lifts render scale now", near(store.RenderScale, 0.9), store.RenderScale)
	S.SetFloor(0.6)
	store.RenderScale = 0.65
	S.SetGoal("fidelity")
	check("settings: Fidelity's own minimum lifts it too", near(store.RenderScale, 0.9), store.RenderScale)
end

-- Zone flags carry a date and expire after a day; a cleanly kept raise resets the lock and back-off; ResetLearning
-- clears all of them.
do
	local S = fresh()
	seeCeiling(74.5)
	ns.db.smart.areas["map:1"] = { locKey = "city", lockLen = 3600, backoff = 900, freeCost = time() - 2 * 86400 }
	start(S, 70)
	local a
	local stop = T + 1200
	repeat
		run(1, 74.5)
		a = ns.db.smart.areas["map:1"]
	until a.lastRaise or T >= stop
	check("flags: a day-old freeCost no longer holds the free track", store.graphicsViewDistance == 9)
	check("flags: a kept raise resets lock and back-off", a.lastRaise and a.lockLen == nil and a.backoff == nil)
	a.cpu, a.freeFree, a.freeCost, a.ceiling, a.noGain = time(), time(), time(), { fps = 50, t = time() }, 1
	S.ResetLearning("city")
	check("flags: ResetLearning clears them", a.cpu == nil and a.freeFree == nil and a.freeCost == nil and a.ceiling == nil and a.noGain == nil)
end

-- A subzone much slower than its zone becomes a zone of its own.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(120, 74.5)
	subzone = "Arena"
	ns.Fire("ZONE_CHANGED")
	run(120, 50)
	subzone = ""
	ns.Fire("ZONE_CHANGED")
	run(5, 74.5)
	subzone = "Arena"
	ns.Fire("ZONE_CHANGED")
	run(2, 50)
	check("subzones: one 15% slower splits off", S.State().area.key == "map:1/Arena", S.State().area.key)
end

-- 7. Target 70 under a 74.5 ceiling (the old dead zone): raises are probed: the free track first, in one batch.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 70)
	run(1200, 74.5)
	local ups = decisions()
	local first, together = ups[1], true
	for _, w in ipairs(ups) do if ZERO[w[1]] and w[4] ~= first[4] then together = false end end
	check("dead zone: at the ceiling it probes upward, the free track first", first and ZERO[first[1]] and first[2] > first[5], first and first[1])
	check("dead zone: the free track goes up in one batch", together and store.graphicsViewDistance == 9 and store.graphicsShadowQuality == 5)
end

-- 8. Learning: clamp and shrink; the old data goes once.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(1200, function(st) return st.graphicsSSAO == 4 and 68.5 or 74.5 end)
	local g = ns.db.smart.gains.graphicsSSAO
	check("learn: a probe sample is clamped to 2.5x the prior", g and near(g.ema, 2.5 * 2.5, 0.01), g and g.ema)
	S = fresh()
	ns.db.smart.learnVersion = 2
	ns.db.smart.gains = { graphicsLightMode = { ema = 77.9, n = 2 } }
	ns.db.smart.learned = { city = { values = { graphicsLightMode = 0 }, gains = {}, t = 1 } }
	ns.db.smart.areas = { ["map:1"] = { name = "A", fps = 74, seconds = 900, below = 10, settled = { graphicsLightMode = 0 }, cpu = true, values = {} } }
	ns.Fire("FSG_READY")
	local a = ns.db.smart.areas["map:1"]
	check("learn: version 3 drops the old gains and sets", next(ns.db.smart.gains) == nil and next(ns.db.smart.learned) == nil and a.settled == nil and a.cpu == nil and a.values == nil and ns.db.smart.learnVersion == 3)
	check("learn: lag history kept", a.fps == 74 and a.seconds == 900 and a.below == 10)
	ns.db.smart.gains.graphicsLightMode = { ema = 9, n = 1 }
	ns.Fire("FSG_READY")
	check("learn: only once", ns.db.smart.gains.graphicsLightMode ~= nil)
	-- Shrink: 3 samples of 30% on lighting barely move it, so the ladder keeps its order.
	S = fresh()
	ns.db.smart.gains.graphicsLightMode = { ema = 30, n = 3 }
	ns.db.smart.gains.RenderScale = { ema = 6, n = 3 }
	S.SetFloor(0.75)
	local before = S.Ladder()[8].cvar
	check("learn: a few samples don't reorder rungs", before == "graphicsLightMode", before)
	ns.db.smart.gains.graphicsLightMode = { ema = 30, n = 8 }
	ns.db.smart.gains.RenderScale = { ema = 6, n = 8 }
	S.SetFloor(0.75)
	local order = {}
	for i, r in ipairs(S.Ladder()) do order[i] = r.cvar end
	check("learn: 8 samples and a big difference swap neighbours", order[7] == "graphicsLightMode" and order[8] == "RenderScale", order[7] .. "," .. order[8])
end

-- One sustained-load cut feeds half a sample.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	local stop = T + 120
	local soft = function(st) return 66 + (1 - st.shadowSoft) * 5 end
	while #decisions() == 0 and T < stop do run(1, soft) end
	run(12, soft)
	local g = ns.db.smart.gains[decisions()[1][1]]
	check("learn: a sustained-load cut is half a sample", g and g.n == 0.5, g and g.n)
end

-- Passive learning only: a stable zone below the ceiling with no headroom changes nothing; a probe whose revert doesn't
-- bring fps back feeds nothing; two render scale cuts under sustained load that gain under 2% make the zone CPU-bound,
-- are undone, and its fps becomes the zone's limit.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(1800, 68)
	check("learn: a stable zone below the ceiling makes no changes", #decisions() == 0, #decisions())
	S = fresh()
	seeCeiling(74.5)
	ns.db.smart.areas["map:1"] = { locKey = "city", pos = 1 }
	start(S, 75)
	local probed, reverted
	local stop = T + 900
	while not reverted and T < stop do
		run(1, function(st)
			if st.shadowSoft == 1 then probed = true end
			return probed and 60 or 74.5
		end)
		reverted = probed and store.shadowSoft == 0
	end
	run(13, 60)
	check("learn: a probe whose revert didn't bring fps back feeds nothing", reverted and ns.db.smart.gains.shadowSoft == nil and S.State().status ~= "raising (testing)")
	S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(1800, function(st) return 60 + (1 - st.shadowSoft) * 6 end)
	local a = ns.db.smart.areas["map:1"]
	check("learn: two render scale cuts without gain -> CPU-bound", type(a.cpu) == "number" and S.Ladder()[1].cvar == "graphicsSpellDensity", tostring(a.cpu))
	check("learn: and undone, the zone's fps its limit", near(store.RenderScale, 0.9) and #writesOf("RenderScale") == 5 and a.ceiling and near(a.ceiling.fps, 66, 0.5), store.RenderScale)
end


-- CPU-bound (45 whatever the settings), under a known 60 limit and under a 144 frame cap: cuts that gain nothing are
-- undone, the zone's 45 becomes its limit, the profile stays.
for _, capped in ipairs({ false, true }) do
	local S = fresh()
	if capped then store.useMaxFPS, store.maxFPS = "1", 144 else ns.db.smart.ceiling = { fps = 60, t = time() } end
	start(S, 60)
	run(1800, 45)
	local a, intact = ns.db.smart.areas["map:1"], true
	for _, cvar in ipairs({ "RenderScale", "shadowSoft", "graphicsSSAO", "graphicsComputeEffects", "graphicsLightMode", "graphicsSpellDensity", "graphicsParticleDensity" }) do
		if not near(tonumber(store[cvar]), PROFILE[cvar]) then intact = false end
	end
	local label = capped and "under a 144 cap" or "under a 60 limit"
	check("cpu-bound " .. label .. ": nothing cut for nothing", intact and a.ceiling and near(a.ceiling.fps, 45, 0.5) and near(S.State().goal, 45 * 0.97, 0.5), S.State().goal)
end

-- The ceiling must be proven below the target. Three cases from a first session.
do
	-- Flat at 60 under GPU load: the first cut helps, so it was load, not a limit.
	local S = fresh(MACHINE)
	start(S, 75)
	run(1800, owner(60))
	local c = S.State().ceiling
	check("ceiling proof: flat 60 under GPU load is no ceiling", (c == nil or c >= 75) and near(S.State().goal, 75) and not ns.db.smart.areas["map:1"].ceiling, c)
	check("ceiling proof: and its cuts stay", store.ResampleQuality == 2 and store.graphicsSSAO < 3)
	-- A real cap at 60 (target 75): two cuts gain nothing, each is undone, the zone's ceiling is 60.
	S = fresh(MAX)
	start(S, 75)
	run(1800, 60)
	local a = ns.db.smart.areas["map:1"]
	local cuts, backs = 0, 0
	for _, w in ipairs(decisions()) do if w[2] < w[5] then cuts = cuts + 1 else backs = backs + 1 end end
	check("ceiling proof: a real cap at 60 is confirmed for the zone", a.ceiling and near(a.ceiling.fps, 60, 0.5) and near(S.State().ceiling, 60, 0.5) and near(S.State().goal, 60 * 0.97, 0.5), a.ceiling and a.ceiling.fps)
	local cutAt, backAt = {}, {}
	for _, w in ipairs(decisions()) do if w[2] < w[5] then cutAt[#cutAt + 1] = w[4] else backAt[#backAt + 1] = w[4] end end
	check("ceiling proof: two cuts, each undone", uniqueTimes(decisions()) == 4 and cuts == backs and store.shadowSoft == 1 and near(store.RenderScale, 1.0) and store.graphicsSpellDensity == 2, cuts .. "/" .. backs)
	local n = #ns.writes
	run(1800, 60)
	check("ceiling proof: then quiet", #ns.writes == n, #ns.writes - n)
	-- 74.5 with the target at 75 (the user's case): within 3%, so a probe raise proves it; no cuts.
	S = fresh()
	start(S, 75)
	run(600, 74.5)
	local cutsMade = 0
	for _, w in ipairs(decisions()) do if w[2] < w[5] then cutsMade = cutsMade + 1 end end
	check("ceiling proof: 74.5 vs 75 confirmed by a kept probe", ns.db.smart.ceiling and ns.db.smart.ceiling.confirmed and near(S.State().goal, 74.5 * 0.97, 0.3))
	check("ceiling proof: no cuts for it", cutsMade == 0, cutsMade)
end

-- A kept free batch proves nothing about a ceiling (free knobs cost nothing): flat at 67 under a 72 target, the free
-- track goes up, render scale costs and is reverted, and 67 stays unconfirmed (goal = target).
do
	local S = fresh(MACHINE)
	start(S, 72)
	run(1200, function(st) return st.RenderScale > 0.75 + 1e-6 and 63 or 67 end)
	check("ceiling proof: a kept free batch confirms nothing", store.graphicsViewDistance == 9 and not (ns.db.smart.ceiling and ns.db.smart.ceiling.confirmed) and near(S.State().goal, 72), S.State().goal)
end

-- The replay's scenarios on the same model (round 2 defects).
do
	-- 1. A light scene (raw 100 at render scale 0.75): the free track goes up, then render scale climbs while fps holds
	-- at the ceiling; 1.0 costs too much (raw 71), so it ends at 0.95.
	local S = fresh(MACHINE)
	start(S, 75)
	run(1800, owner(100))
	check("costly raises: render scale climbs above the profile to 0.95", near(store.RenderScale, 0.95), store.RenderScale)
	check("costly raises: the free knobs at their top", store.graphicsViewDistance == 9 and store.graphicsShadowQuality == 5 and store.graphicsEnvironmentDetail == 9 and store.graphicsGroundClutter == 9 and store.graphicsLiquidDetail == 3)
	check("costly raises: the ceiling confirmed by a kept render scale probe", ns.db.smart.ceiling and ns.db.smart.ceiling.confirmed and near(S.State().goal, 74.5 * 0.97, 0.3))
	local raises = {}
	for _, w in ipairs(decisions()) do if w[2] > w[5] then raises[#raises + 1] = w end end
	local budget = #raises >= 6
	for i, w in ipairs(raises) do
		local used, seen = 0, {}
		for j = i, #raises do
			local x = raises[j]
			if x[4] - w[4] < 600 and not seen[x[4]] then
				seen[x[4]] = true
				local hitchy = false
				for _, y in ipairs(raises) do if y[4] == x[4] and (y[1] == "RenderScale" or y[1] == "graphicsLiquidDetail") then hitchy = true end end
				used = used + (hitchy and 2 or 1)
			end
		end
		if used > 6 then budget = false end
	end
	check("budget: raises and probes at most 6 per 10 min (a batch with a stutter counts 2)", budget)
end
do
	-- 4. The budget never holds a cut back: 10 min into the climb (budget spent), a heavy load cuts at once; a cut
	-- right after a kept raise is one flap: one 15 min lock, not one per cut.
	local S = fresh(MACHINE)
	start(S, 75)
	run(600, owner(100))
	local n = #ns.writes
	local t0 = T
	local start = copy(store)
	run(60, owner(58))
	local first = decisions(n)[1]
	check("budget: never blocks a cut while short", first and first[4] - t0 < 30 and first[2] < first[5], first and (first[4] - t0))
end
do
	local S = fresh(MACHINE)
	start(S, 75)
	local a
	local stop = T + 1800
	repeat
		run(1, owner(100))
		a = ns.db.smart.areas["map:1"]
	until (a and a.lastRaise) or T >= stop
	run(120, owner(58))
	check("flap: one lock of 15 min for one flap", a.lastRaise == nil and a.lockUntil and a.lockUntil - time() <= 900 and a.lockUntil - time() > 700, a.lockUntil and a.lockUntil - time())

end
do
	local S = fresh(MACHINE)
	start(S, 75)
	run(600, owner(100))
	local n = #ns.writes
	local start = copy(store)
	run(60, owner(58))
	-- 2. Sustained heavy load (raw 58): the free track drops (one batch) before anything below the profile, gains
	-- nothing, and goes back up.
	run(900, owner(58))
	local cuts = decisions(n)
	local rungs = S.Ladder()
	local v, firstFree, atFloor = start, nil, nil
	for i, w in ipairs(cuts) do
		if ZERO[w[1]] and not firstFree then
			firstFree = i
			local _, k = prefix(rungs, v)
			atFloor = k == 0
		end
		v[w[1]] = w[2]
	end
	check("free track: Smart's own free batch goes before the profile is cut", firstFree and atFloor, firstFree)
	local freeTimes = {}
	for _, w in ipairs(cuts) do if ZERO[w[1]] then freeTimes[w[4]] = (freeTimes[w[4]] or 0) + 1 end end
	local batches = 0
	for _ in pairs(freeTimes) do batches = batches + 1 end
	check("free track: dropped in one batch, judged, and back up (it gained nothing)", batches == 2 and store.graphicsViewDistance == 9 and type(ns.db.smart.areas["map:1"].freeFree) == "number", batches)
end
do
	-- 3. Far short in a new zone (raw 62): one batch covers the gap; settled within 2 decisions.
	local S = fresh(MACHINE)
	seeCeiling(74.5)
	start(S, 75)
	go("map:2", "city", "B")
	run(600, owner(62))
	local d = decisions()
	check("far short: settles within 2 decisions", #d >= 1 and uniqueTimes(d) <= 2 and S.State().status == "holding", uniqueTimes(d))
end
do
	-- 5. The load changes while a judgment is pending: dropped, not judged.
	-- A probe raise and then a heavy load: undone for safety, but no best and no learning.
	local S = fresh(MACHINE)
	seeCeiling(74.5)
	start(S, 75)
	local heavy, resolved = false, false
	local stop = T + 900
	while not resolved and T < stop do
		run(1, function(st)
			if st.RenderScale > 0.75 + 1e-6 and not heavy then heavy = true end
			return heavy and 50 or 74.5
		end)
		resolved = heavy and S.State().status ~= "raising (testing)"
	end
	local a = ns.db.smart.areas["map:1"]
	check("regime: a probe judged across a load change sets no best and learns nothing", resolved and a.best == nil and ns.db.smart.gains.RenderScale == nil and near(store.RenderScale, 0.75), store.RenderScale)
	-- A cut and then the load gone: its sample is dropped.
	S = fresh(MACHINE)
	seeCeiling(74.5)
	start(S, 75)
	local cut = false
	run(300, function(st)
		if st.ResampleQuality == 2 then cut = true end
		return cut and 74.5 or 66
	end)
	check("regime: a cut judged across a load change feeds nothing", cut and ns.db.smart.gains.ResampleQuality == nil)
end

-- Render scale maximum: Smart's own raises stop at min(scaleMax, Catalog max). Above 100% comes last on the way up
-- (after SSAO, compute, lighting, soft shadows) and first on the way down; a profile's own value is never cut to it.
local function upsAbove(list)
	local out = {}
	for _, w in ipairs(list) do if w[1] == "RenderScale" and w[2] > 1 + 1e-6 and w[2] > w[5] then out[#out + 1] = w end end
	return out
end
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(3600, 74.5)
	check("scale max: the default stops at 100%", near(store.RenderScale, 1.0) and #upsAbove(decisions()) == 0, store.RenderScale)
end
do
	local S = fresh()
	seeCeiling(74.5)
	check("scale max: set", S.SetScaleMax(1.5) == 1.5 and ns.db.smart.scaleMax == 1.5)
	start(S, 75)
	run(7200, 74.5)
	local list = decisions()
	local firstAbove, lastOther = math.huge, 0
	for i, w in ipairs(list) do
		if w[1] == "RenderScale" and w[2] > 1 + 1e-6 then firstAbove = math.min(firstAbove, i) end
		if w[2] > w[5] and (w[1] == "graphicsSSAO" or w[1] == "graphicsComputeEffects" or w[1] == "graphicsLightMode") then lastOther = i end
	end
	check("scale max: past 100% only after SSAO, compute and lighting", lastOther > 0 and firstAbove > lastOther, firstAbove .. "/" .. lastOther)
	check("scale max: stops at 150%", near(store.RenderScale, 1.5) and store.graphicsSSAO == 4 and store.graphicsLightMode == 3, store.RenderScale)
	local n = #ns.writes
	run(30, 40)
	local first = decisions(n)[1]
	check("scale max: under load the supersampled part goes first", first and first[1] == "RenderScale" and first[2] >= 1 - 1e-6 and first[5] > 1 + 1e-6 and store.graphicsSSAO == 4, first and first[1])
	S = fresh()
	seeCeiling(74.5)
	S.SetScaleMax(1.5)
	start(S, 75)
	run(7200, 74.5)
	check("scale max: reached 150% again", near(store.RenderScale, 1.5))
	check("scale max: lowering it takes back Smart's extra now", S.SetScaleMax(1.0) == 1.0 and near(store.RenderScale, 1.0))
	check("scale max: and in what is remembered", near(S.Adjust("city", copy(PROFILE)).RenderScale, 1.0) and ns.db.smart.areas["map:1"].pos > -20)
end
do
	local S = fresh()
	byCvar.RenderScale.max = 1.25
	seeCeiling(74.5)
	check("scale max: clamped to the Catalog", S.SetScaleMax(1.5) == 1.25)
	-- A saved maximum over what this client's Catalog allows still stops at the Catalog's top.
	ns.db.smart.scaleMax = 1.5
	start(S, 75)
	run(7200, 74.5)
	check("scale max: stops at the Catalog's 125%", near(store.RenderScale, 1.25), store.RenderScale)
	byCvar.RenderScale.max = 2.0
end
do
	-- A 135% profile with the default maximum: not cut while there is room, lowered first under load, back to 135%.
	local profile135 = copy(PROFILE)
	profile135.RenderScale = 1.35
	local S = fresh(profile135)
	seeCeiling(74.5)
	start(S, 75)
	run(300, 74.5)
	check("scale max: a 135% profile is not cut to the maximum", near(store.RenderScale, 1.35) and #writesOf("RenderScale") == 0)
	check("scale max: a lower maximum leaves the profile's own value", S.SetScaleMax(1.0) == 1.0 and near(store.RenderScale, 1.35))
	local n = #ns.writes
	run(60, function(st) return 40 + (1.35 - st.RenderScale) * 100 end)
	local first
	for _, w in ipairs(decisions(n)) do
		if not first and profile135[w[1]] and w[2] < profile135[w[1]] - 1e-6 then first = w end
	end
	check("scale max: the profile's part above 100% is the first cut below the profile", first and first[1] == "RenderScale" and first[2] >= 1 - 1e-6, first and first[1])
	run(3600, 74.5)
	check("scale max: back to the profile's 135% with room", near(store.RenderScale, 1.35), store.RenderScale)
end
do
	local S = fresh()
	check("scale max: clamps", S.SetScaleMax(0.5) == 1.0 and S.SetScaleMax(3) == 2.0 and S.SetScaleMax("x") == nil and S.SetScaleMax(1.234) == 1.23)
	ns.commands.maxscale({ "150" })
	check("slash: maxscale", ns.db.smart.scaleMax == 1.5 and ns.logs[#ns.logs] == "Render scale maximum 150%", ns.logs[#ns.logs])
	ns.commands.maxscale({ "x" })
	check("slash: maxscale usage", ns.logs[#ns.logs] == "Usage: /fsg maxscale <percent 100-200>")
	for _, case in ipairs({ { "floor", "0.8", 0.8 }, { "floor", "80%", 0.8 }, { "maxscale", "1.5", 1.5 } }) do
		ns.commands[case[1]]({ case[2] })
		local key = case[1] == "floor" and "scaleFloor" or "scaleMax"
		check("slash: " .. case[1] .. " " .. case[2], near(ns.db.smart[key], case[3]), ns.db.smart[key])
	end
	for _, case in ipairs({ { "floor", "-50" }, { "floor", "20" }, { "maxscale", "300" }, { "target", "-30" }, { "target", "0" }, { "target", "abc" } }) do
		local before = ns.db.smart.target
		ns.commands[case[1]]({ case[2] })
		check("slash: " .. case[1] .. " " .. case[2] .. " is refused", ns.logs[#ns.logs]:find("^Usage") ~= nil and ns.db.smart.target == before, ns.logs[#ns.logs])
	end
	ns.commands.target({ "60.9" })
	check("slash: target 60.9", ns.db.smart.target == 61, ns.db.smart.target)
	ns.commands.floor({ "75" })
	check("slash: floor says minimum", ns.logs[#ns.logs] == "Render scale minimum 75%", ns.logs[#ns.logs])
end

-- Eco: the frame cap at the target (the player's own cap saved once, written back once), never above the profile.
local function capWrites(from)
	local n = 0
	for i = (from or 0) + 1, #ns.writes do
		local c = ns.writes[i][1]
		if c == "maxFPS" or c == "useMaxFPS" then n = n + 1 end
	end
	return n
end
-- A reload: the same saved data and game settings, Smart.lua loaded again.
local function reload()
	local db = ns.db
	ns = newNs()
	ns.db = db
	assert(loadfile(SMART))("ForeverSmartGraphics", ns)
	ns.Fire("FSG_READY")
	return ns.Smart
end
do
	local S = fresh()
	store.useMaxFPS, store.maxFPS = "1", 73
	S.SetGoal("eco")
	start(S, 60)
	local saved = ns.db.smart.ecoCap
	check("eco: caps at the target", tonumber(store.useMaxFPS) == 1 and store.maxFPS == 60 and S.State().style == "Eco · Balanced")
	check("eco: the player's cap saved (on at 73)", saved and saved.useMaxFPS == 1 and saved.maxFPS == 73)
	check("eco: the cap is the ceiling, goal = target", S.State().ceiling == 60 and S.State().goal == 60)
	S.SetTarget(50)
	check("eco: a target change moves the cap", store.maxFPS == 50 and ns.db.smart.ecoCap.maxFPS == 73)
	local n = #ns.writes
	S.SetGoal("balanced")
	check("eco: another goal writes the player's cap back", store.maxFPS == 73 and tonumber(store.useMaxFPS) == 1 and ns.db.smart.ecoCap == nil and capWrites(n) == 2, capWrites(n))
	S.SetGoal("fidelity")
	check("eco: back once only", capWrites(n) == 2)
	S = fresh()
	store.useMaxFPS, store.maxFPS = "0", 0
	S.SetGoal("eco")
	start(S, 60)
	check("eco: the player's cap saved (off)", ns.db.smart.ecoCap.useMaxFPS == 0 and ns.db.smart.ecoCap.maxFPS == 0 and store.useMaxFPS == 1)
	n = #ns.writes
	S.SetEnabled(false)
	check("eco: smart off (and restore, which turns it off) writes it back", store.useMaxFPS == 0 and store.maxFPS == 0 and capWrites(n) == 2)
	S.SetEnabled(false)
	check("eco: once", capWrites(n) == 2)
	-- A location goal.
	S = fresh()
	store.useMaxFPS, store.maxFPS = "1", 73
	S.SetGoal("eco")
	S.SetLocationGoal("outdoor", "balanced")
	start(S, 60)
	n = #ns.writes
	go("map:9", "outdoor", "Fields")
	check("eco: a location whose goal is not Eco writes it back", store.maxFPS == 73 and capWrites(n) == 2)
	go("map:1", "city", "Town")
	check("eco: and caps again where Eco applies", store.maxFPS == 60 and ns.db.smart.ecoCap.maxFPS == 73)
	-- A reload while Eco holds the cap keeps the player's saved cap, not ours; a login where it no longer applies restores.
	S = reload()
	check("eco: a reload keeps the player's cap", ns.db.smart.ecoCap and ns.db.smart.ecoCap.maxFPS == 73 and store.maxFPS == 60)
	ns.db.smart.goal = "balanced"
	n = 0
	S = reload()
	check("eco: a login where Eco no longer applies writes it back", store.maxFPS == 73 and ns.db.smart.ecoCap == nil and capWrites() == 2, capWrites())
end
do
	-- At the cap with a profile below maximum, over a long run: nothing raised (no up track, no free track, no
	-- maximum); the cap is not taken for a display limit.
	local S = fresh()
	S.SetScaleMax(1.5)
	S.SetGoal("eco")
	start(S, 60)
	run(3600, 60)
	local up = 0
	for _, w in ipairs(decisions()) do if w[1] ~= "maxFPS" and w[1] ~= "useMaxFPS" and w[2] > w[5] then up = up + 1 end end
	check("eco: nothing above the profile over an hour at the cap", up == 0 and near(store.RenderScale, 1.0) and store.graphicsViewDistance == 5, up)
	check("eco: our cap is not learned as the display's limit", ns.db.smart.ceiling == nil)
	-- Low fps lowers; with room again it comes back to the profile and no further.
	local n = #ns.writes
	run(600, gpu(40))
	local cuts = 0
	for _, w in ipairs(decisions(n)) do if w[2] < w[5] then cuts = cuts + 1 end end
	check("eco: low fps lowers", cuts >= 1 and store.shadowSoft == 0)
	run(5400, 60)
	local back = true
	for cvar, v in pairs(PROFILE) do if type(v) == "number" and not near(tonumber(store[cvar]), v) then back = false end end
	check("eco: recovery returns to the profile and no further", back and store.maxFPS == 60)
	S.SetGoal("balanced")
	run(20, 50)
	check("eco: leaving it, the 5 min under our cap are forgotten", S.State().ceiling == nil and near(S.State().goal, 60), S.State().ceiling)
end
do
	-- In combat the cap write waits for the fight to end (held by the engine).
	local S = fresh()
	store.useMaxFPS, store.maxFPS = "1", 73
	start(S, 60)
	ns.InCombat = function() return true end
	S.SetGoal("eco")
	check("eco: in combat the cap write is held", store.maxFPS == 73 and #ns.held >= 1 and ns.held[#ns.held][3] == "smart mode (Eco)")
	ns.InCombat = function() return false end
end
do
	-- Eco through a reload keeps the player's own saved cap.
	local S = fresh()
	store.useMaxFPS, store.maxFPS = "1", 60
	ns.db.smart.ecoCap = { useMaxFPS = 1, maxFPS = 73 }
	ns.db.smart.enabled, ns.db.smart.goal = true, "eco"
	S = reload()
	check("eco: a reload keeps the player's own saved cap", ns.db.smart.ecoCap.maxFPS == 73 and ns.db.smart.ecoCap.useMaxFPS == 1 and store.maxFPS == 60 and tonumber(store.useMaxFPS) == 1)
	local n = #ns.writes
	S = reload()
	check("eco: nothing more on the next login", capWrites(n) == 0, capWrites(n))
	ns.commands.goal({ "eco" })
	check("slash: goal eco", ns.db.smart.goal == "eco" and ns.logs[#ns.logs] == "Smart goal: Eco")
	ns.commands.goal({ "raid", "eco" })
	check("slash: goal per location eco", S.Goal("raid") == "eco")
end

do
	-- Eco caps at the player's own lower cap; a cap changed from outside becomes the player's; the saved cap goes only
	-- once the write-back took (in combat it waits for the fight to end).
	local S = fresh()
	store.useMaxFPS, store.maxFPS = "1", 50
	S.SetGoal("eco")
	start(S, 60)
	check("eco: the player's own lower cap stands", store.maxFPS == 50 and ns.db.smart.ecoCap.maxFPS == 50)
	S.SetTarget(40)
	check("eco: a lower target caps under it", store.maxFPS == 40)
	store.maxFPS = 100
	ns.Fire("CVAR_UPDATE", "maxFPS")
	check("eco: an outside change is the player's cap, Eco's back on top", ns.db.smart.ecoCap.maxFPS == 100 and store.maxFPS == 40)
	ns.Fire("CVAR_UPDATE", "maxFPS")
	check("eco: our own cap write is not taken for the player's", ns.db.smart.ecoCap.maxFPS == 100)
	ns.InCombat = function() return true end
	S.SetGoal("balanced")
	check("eco: in combat the saved cap waits", ns.db.smart.ecoCap and ns.db.smart.ecoCap.maxFPS == 100)
	ns.InCombat = function() return false end
	ns.Fire("FSG_COMBAT_END")
	check("eco: and is written back after the fight", ns.db.smart.ecoCap == nil and store.maxFPS == 100 and tonumber(store.useMaxFPS) == 1, store.maxFPS)
end

-- 10. Nothing in combat; the fight notice offers the next rungs; the player's buttons write.
do
	local S = fresh()
	seeCeiling(74.5)
	start(S, 75)
	run(30, 70)
	ns.writes, ns.held = {}, {}
	local fighting = true
	ns.InCombat = function() return fighting end
	ns.Fire("FSG_COMBAT_START")
	local seen
	ns.On("FSG_COMBAT_LOW", function(info) seen = info end)
	run(4, 40)
	check("combat: no notice before 5 s", seen == nil and S.CombatLow() == nil)
	run(90, 40)
	check("combat: nothing written or held", #ns.writes == 0 and #ns.held == 0 and S.State().status == "in combat")
	check("combat: one notice with the next 3 rungs", fired("FSG_COMBAT_LOW") == 1 and seen and #seen.cuts == 3 and seen.cuts[1].cvar == "shadowSoft" and seen.cuts[2].cvar == "RenderScale" and near(seen.cuts[3].to, 0.9), seen and seen.cuts[1].cvar)
	check("combat: Lower now writes as the player", S.ApplyCombatCuts() == 3 and ns.writes[1][3] == "you, in combat" and ns.writes[1][6].user == true and near(store.RenderScale, 0.9))
	fighting = false
	ns.Fire("FSG_COMBAT_END")
	check("combat: hidden at combat end", S.CombatLow() == nil and seen == nil)
	check("combat: the zone remembers the player's cuts", ns.db.smart.areas["map:1"].pos == 3)
	fighting = true
	ns.Fire("FSG_COMBAT_START")
	run(6, 40)
	ns.writes = {}
	check("combat: After combat queues", S.DeferCombatCuts() == true and #ns.writes == 0)
	fighting = false
	ns.Fire("FSG_COMBAT_END")
	check("combat: After combat applies at the end", #ns.writes == 3 and ns.writes[1][3] == "you, after combat", #ns.writes)
	run(4.5, 74.5)
	check("combat end: warm-up first", S.State().status == "warming")
end

-- Goal x pace: every pair cuts under sustained load with its own reason; Aggressive takes up to 3 when far short;
-- Smooth only right after a zone's warm-up.
do
	for _, goal in ipairs({ "fps", "balanced", "fidelity" }) do
		for _, pace in ipairs({ "aggressive", "balanced", "smooth" }) do
			local S = fresh()
			seeCeiling(74.5)
			S.SetGoal(goal)
			S.SetPace(pace)
			start(S, 75)
			run(60, 40)
			local cuts = decisions()
			check("goal x pace: " .. goal .. " / " .. pace .. " cuts", #cuts >= 1 and cuts[1][3] == "smart mode (" .. S.State().style .. ")", #cuts)
			if goal == "fps" then check("goal fps: CPU rungs first", cuts[1] and cuts[1][1] == "graphicsSpellDensity", cuts[1] and cuts[1][1]) end
		end
	end
	local S = fresh()
	seeCeiling(74.5)
	S.SetPace("aggressive")
	start(S, 75)
	run(14, 40)
	local cuts = decisions()
	check("far short: one batch of up to 4 rungs, each knob written once", #cuts == 3 and cuts[3][4] == cuts[1][4] and cuts[1][1] == "shadowSoft" and cuts[2][1] == "RenderScale" and near(cuts[2][2], 0.9) and cuts[3][1] == "ResampleQuality", #cuts)
	S = fresh()
	seeCeiling(74.5)
	S.SetPace("smooth")
	start(S, 75)
	local entered = T
	run(600, 40)
	local late = false
	for _, w in ipairs(decisions()) do if w[4] > entered + 25 + 1e-6 then late = true end end
	check("pace smooth: changes only in the 20 s after a zone's warm-up", #decisions() >= 1 and not late)
	check("pace smooth: then one notice instead", fired("FSG_SUGGEST") == 1)
	S = fresh()
	seeCeiling(74.5)
	S.SetGoal("fidelity")
	start(S, 75)
	run(3600, 40)
	local lowest = 1
	for _, v in ipairs(writesOf("RenderScale")) do lowest = math.min(lowest, v) end
	check("goal fidelity: render scale never under 0.90", lowest >= 0.9 - 1e-6, lowest)
end

-- Goal and pace API, overrides, slash.
do
	local S = fresh()
	check("goal/pace: defaults", S.Goal() == "balanced" and S.Pace() == "balanced" and S.State().style == "Balanced · Balanced")
	check("goal/pace: unknown refused", S.SetGoal("turbo") == nil and S.SetPace("quality") == nil)
	check("goal/pace: lists", #S.GOALS == 4 and S.GOALS[3].desc == "Your target is a minimum; spends spare FPS on looks." and #S.PACES == 3 and S.PACES[3].desc == "Changes only when you enter a new area.")
	S.SetGoal("fps")
	check("location goal: override wins", S.SetLocationGoal("city", "fidelity") and S.Goal("city") == "fidelity" and S.Goal("outdoor") == "fps")
	S.SetLocationGoal("city", nil)
	check("location goal: default follows", S.Goal("city") == "fps")
	ns.commands.goal({ "fidelity" })
	check("slash: goal", ns.db.smart.goal == "fidelity" and ns.logs[#ns.logs] == "Smart goal: Fidelity")
	ns.commands.goal({ "outdoor", "fps" })
	check("slash: goal per location", S.Goal("outdoor") == "fps" and ns.logs[#ns.logs] == "Open world: FPS")
	ns.commands.pace({ "smooth" })
	check("slash: pace", S.Pace() == "smooth" and ns.logs[#ns.logs] == "Smart pace: Smooth")
	ns.commands.target({ "90" })
	ns.commands.floor({ "65" })
	check("slash: Core word tables", ns.db.smart.target == 90 and near(ns.db.smart.scaleFloor, 0.65))
	ns.commands.smart({ "on" })
	check("slash: smart on", S.Enabled() and ns.logs[#ns.logs]:find("^Smart %(") ~= nil)
end

-- A maxFPS cap is the ceiling.
do
	local S = fresh(MAX)
	store.useMaxFPS, store.maxFPS = "1", 73
	start(S, 144)
	check("cap: maxFPS is the ceiling", S.State().ceiling == 73 and near(S.State().goal, 73 * 0.97) and S.State().cap == 73)	S = fresh(MAX)
	store.useMaxFPS, store.maxFPS = "1", 73
	start(S, 75)
	run(600, 73)
	check("cap: fps at the cap confirms no display ceiling", not (ns.db.smart.ceiling and ns.db.smart.ceiling.confirmed) and S.Limit() == 73)
end

-- Adjust: a zone never visited starts at the profile; a cut position older than 6 hours is stale; SaveAsProfile
-- builds on the zone's values.
do
	local S = fresh()
	ns.db.smart.areas = { ["map:5"] = { locKey = "city", pos = 1 }, ["map:6"] = { locKey = "city", pos = 2 }, ["map:7"] = { locKey = "city", pos = 6 }, ["map:8"] = { locKey = "outdoor", pos = 9 } }
	mapKey = "map:99"
	local out = S.Adjust("city", copy(PROFILE))
	check("adjust: a zone never visited starts at the profile", out.shadowSoft == 1 and near(out.RenderScale, 1.0) and out.ResampleQuality == 3)
	ns.db.smart.areas["map:7"].posAt = time()
	mapKey = "map:7"
	out = S.Adjust("city", copy(PROFILE))
	check("adjust: a known zone at its own", out.ResampleQuality == 2 and out.graphicsComputeEffects == 1 and out.graphicsSSAO == 2)
	check("adjust: input untouched, heavy and non-knobs kept", PROFILE.shadowSoft == 1 and out.textureFilteringMode == 5 and out.weatherDensity == 3)
	ns.db.smart.areas["map:7"].posAt = time() - 7 * 3600
	check("adjust: a cut position older than 6 hours starts at the profile", S.Adjust("city", copy(PROFILE)).shadowSoft == 1)
	ns.db.smart.areas["map:7"].posAt = time()
	local id = S.SaveAsProfile("city", "My city")
	check("save: Profiles.Create with the zone's values", id == "p1" and ns.created[1].name == "My city" and ns.created[1].values.graphicsSSAO == 2)
end

-- Areas() ordering, ForgetArea, ResetLearning.
do
	local S = fresh()
	ns.db.smart.areas = {
		a = { name = "A", locKey = "city", fps = 50, minFps = 20, seconds = 10, below = 5, t = 1 },
		b = { name = "B", locKey = "outdoor", fps = 70, minFps = 50, seconds = 10, below = 1, t = 1 },
		c = { name = "C", locKey = "city", fps = 30, minFps = 10, seconds = 10, below = 9, t = 1, combatFps = 30, calmFps = 60, pos = 3, best = 3 },
	}
	local list = S.Areas()
	check("Areas: lag share order", list[1].key == "c" and list[2].key == "a" and list[3].key == "b")
	check("Areas: fields", near(list[1].lagShare, 0.9) and near(list[1].combatDrop, 0.5) and list[1].name == "C")
	S.ResetLearning("city")
	check("ResetLearning(locKey): that type's zones forget their positions", ns.db.smart.areas.c.pos == nil and ns.db.smart.areas.c.best == nil and ns.db.smart.areas.c.fps == 30)
	S.ForgetArea("a")
	check("ForgetArea", ns.db.smart.areas.a == nil and #S.Areas() == 2)
	ns.db.smart.gains.shadowSoft = { ema = 1, n = 1 }
	S.ResetLearning()
	check("ResetLearning(nil) clears zones and gains", next(ns.db.smart.areas) == nil and next(ns.db.smart.gains) == nil)
end

-- A write that fails is skipped until the next location; one held by combat is not a failure.
do
	local S = fresh()
	seeCeiling(74.5)
	local refuse = true
	local write = ns.Apply.Write
	ns.Apply.Write = function(cvar, value, reason, o)
		if cvar == "shadowSoft" and refuse and reason ~= "location" then return false, 1 end
		return write(cvar, value, reason, o)
	end
	start(S, 75)
	run(60, gpu(40))
	local first = decisions()[1]
	check("failed: soft shadows skipped after a refused write", first and first[1] == "RenderScale" and store.shadowSoft == 1, first and first[1])
	refuse = false
	go("map:2", "city", "Other")
	run(60, gpu(40))
	check("failed: retried after a location change", store.shadowSoft == 0)
end

-- Lag suggestions while smart mode is off (zones are maps now).
local combat = false
local function lagging()
	combat = false
	local S = fresh()
	ns.InCombat = function() return combat end
	go("map:84", "city", "Stormwind City")
	run(4, 60)
	return S
end
local function share(percent) return function(_, t) return math.floor(t) % 10 < percent / 10 and 40 or 70 end end
do
	local S = lagging()
	run(50, share(80))
	check("suggest: not before 60 s", fired("FSG_SUGGEST") == 0)
	run(15, share(80))
	local s = S.Suggestion()
	check("suggest: after 60 s at 70% below", fired("FSG_SUGGEST") == 1 and s and s.key == "map:84" and s.overrideKey == "map:84" and s.locKey == "city" and s.goal == 60, s and s.key)
	run(120, 30)
	check("suggest: once per zone per session", fired("FSG_SUGGEST") == 1)
	S.DismissSuggestion("map:84")
	check("dismiss: snoozed 7 days", ns.db.smart.snoozed["map:84"] == time() + 7 * 86400 and S.Suggestion() == nil)
end
do
	lagging()
	run(130, share(60))
	check("suggest: not at 60% below", fired("FSG_SUGGEST") == 0)
	local S = lagging()
	combat = true
	run(70, 30)
	check("suggest: none in combat", fired("FSG_SUGGEST") == 0)
	combat = false
	ns.Fire("FSG_COMBAT_END")
	check("suggest: fires after combat", fired("FSG_SUGGEST") == 1 and S.Suggestion().key == "map:84")
	S = lagging()
	ns.UI = { Current = function() return true end }
	run(70, 30)
	check("suggest: none while the window is open", fired("FSG_SUGGEST") == 0)
	ns.UI = nil
end

-- AdjustPlace: a one-place walk down the ladder, saved as an override; cancel restores; combat pauses it.
do
	local S = lagging()
	local ok = S.AdjustPlace("map:84")
	check("adjust place: starts", ok and S.AdjustState().running and S.AdjustState().key == "map:84")
	run(90, function(st) return st.shadowSoft == 1 and 40 or 70 end)
	local st = S.AdjustState()
	check("adjust place: first rung is soft shadows, then done", st.done and st.changes[1].cvar == "shadowSoft" and #st.changes == 1, #st.changes)
	check("adjust place: saved as this place's override", ns.overrides[1] and ns.overrides[1][1] == "map:84" and ns.created[1].values.shadowSoft == 0)
	S = lagging()
	S.AdjustPlace()
	run(20, 30)
	check("adjust place: lowered", store.shadowSoft == 0)
	check("adjust place: cancel writes back", S.CancelAdjust() and store.shadowSoft == 1 and near(store.RenderScale, 1.0))
	S = lagging()
	S.AdjustPlace()
	combat = true
	run(30, 30)
	check("adjust place: paused in combat, nothing written", S.AdjustState().paused and #ns.held == 0 and store.shadowSoft == 1)
	combat = false
end

-- KB allocated by seconds at 2000 fps with the GC stopped. The difference of two runs cancels one-off growth (Lua
-- regrows its stack after a collect); LuaJIT counts compiled traces as GC memory, so the interpreter is measured.
local function growth(seconds)
	if jit then jit.off(); jit.flush() end
	collectgarbage("collect")
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	run(seconds, 2000)
	local grew = collectgarbage("count") - before
	collectgarbage("restart")
	if jit then jit.on() end
	return grew
end
do
	local S = fresh(MAX)
	seeCeiling(2000)
	start(S, 75)
	run(20, 2000)
	local grew = growth(10) - growth(5)
	check("alloc: holding 10000 frames allocates < 2 KB", grew < 2, grew)
end
do
	lagging()
	run(10, 2000)
	local grew = growth(10) - growth(5)
	check("alloc: watching 10000 frames allocates < 2 KB", grew < 2, grew)
end

for _, f in ipairs(failures) do print("FAIL " .. f) end
print(("smart_spec: %d passed, %d failed"):format(passed, #failures))
if #failures > 0 then os.exit(1) end
