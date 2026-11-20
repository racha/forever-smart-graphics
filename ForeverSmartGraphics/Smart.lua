-- Forever Smart Graphics smart mode: holds a target FPS with the best look the machine allows.
-- One ordered ladder of rungs (one step of one knob each, best FPS per visible loss first): a cut takes the next rung,
-- a raise always undoes the last one. Decisions use window medians; each zone remembers its rung position and its best.
--
-- API (ns.Smart):
--   Enabled(), SetEnabled(on), SetTarget(fps) 20-240, SetFloor(scale) 0.33-1.0, SetScaleMax(scale) 1.0-2.0
--   State()                 { status, fps, target, goal, ceiling, cap, pos, best, locKey, area = { key, name } | nil,
--                             goalKey, paceKey, style, last = { cvar, from, to, t } } (one reused table)
--                           goal = min(target, ceiling x 0.97); ceiling = the highest sustained fps (or maxFPS)
--                           status "off"|"warming"|"holding"|"holding (settling)"|"lowering"|"raising (testing)"|
--                           "testing"|"at floor"|"best look at target"|"pre-adjusted"|"in combat"
--   Goal(locKey), SetGoal(name), SetLocationGoal(locKey, name | nil), GOALS { { key, name, desc }, ... }
--   Pace(), SetPace(name), PACES { { key, name, desc }, ... }
--   CombatLow(), ApplyCombatCuts(), DeferCombatCuts()  the low-FPS notice of a fight and the player's buttons
--   Ladder()                { { cvar, from, to }, ... } the rungs down from the profile for this place and goal
--   Learned(locKey)         db.smart.learned[locKey] or nil (kept for callers; v3 learns per zone)
--   ResetLearning(locKey)   nil = every zone and the machine-wide gains
--   Adjust(locKey, values)  copy of values at this zone's rung position (Apply.Target calls it)
--   SaveAsProfile(locKey, name) -> new profile id
--   Areas()                 { { key, name, locKey, fps, minFps, lagShare, seconds, combatDrop, learned, t }, ... } worst lag
--                           first; learned = the zone holds a settled position
--   ForgetArea(key)
--   Suggestion(), DismissSuggestion(key), SetSuggest(on)   the lag notice while smart mode is off
--   AdjustPlace(key), AdjustState(), CancelAdjust()         one-place search down the ladder, saved as an override
-- Shared with Calibrate.lua: _Listen(fn(fps)), _PickLower(), _PickRaise(), _Feed(locKey, cvar, gain), _IsKnob(entry),
-- _Current(cvar), _Fail(cvar).
-- A zone is Location.Current().overrideKey (map:<id> / instance:<id>); a subzone becomes its own zone only when its
-- fps differs more than 15% from the zone's.
-- Messages: FSG_SMART(state), FSG_SUGGEST(suggestion), FSG_ADJUST(state), FSG_COMBAT_LOW(info | nil).
local addonName, ns = ...

local Smart = {}
ns.Smart = Smart

local RING, LONG, HIST_BINS = 20, 300, 1000
local LOWER_AT, RAISE_AT = 0.93, 1.10
-- Goal: what matters. Pace: how it moves (window, steps, dwell, settle, change budget per 10 min). Nothing changes in
-- combat at any pace. regionOnly: decisions only in the window seconds after a zone's warm-up.
local GOALS = {
	fps = { name = "FPS", lowerAt = 0.97, raiseAt = 1.15, cpuFirst = true, lightMin = 0 },
	balanced = { name = "Balanced", lowerAt = LOWER_AT, raiseAt = RAISE_AT, lightMin = 1 },
	fidelity = { name = "Fidelity", lowerAt = 0.85, raiseAt = 1.05, lightMin = 1, minScale = 0.90 },
	-- Eco: the frame cap at the target saves the GPU's idle time between frames; nothing ever goes above the profile.
	eco = { name = "Eco", lowerAt = LOWER_AT, raiseAt = RAISE_AT, lightMin = 1, eco = true },
}
local PACES = {
	aggressive = { name = "Aggressive", lowerN = 5, lowerDwell = 4, fastLower = 2, raiseDwell = 20, settle = 30, budget = 12 },
	balanced = { name = "Balanced", lowerN = 10, lowerDwell = 8, fastLower = 4, raiseDwell = 20, settle = 60, budget = 6 },
	smooth = { name = "Smooth", lowerN = 10, lowerDwell = 8, fastLower = 4, raiseDwell = 8, settle = 0, budget = 6, regionOnly = true, window = 20 },
}
local COMBOS = {}
for goalKey, goal in pairs(GOALS) do
	COMBOS[goalKey] = {}
	for paceKey, pace in pairs(PACES) do
		local combo = { goal = goalKey, pace = paceKey }
		for k, v in pairs(pace) do combo[k] = v end
		for k, v in pairs(goal) do combo[k] = v end
		combo.name = goal.name .. " · " .. pace.name
		COMBOS[goalKey][paceKey] = combo
	end
end
local OLD_MODES = { balanced = { "balanced", "balanced" }, smooth = { "balanced", "smooth" }, performance = { "fps", "aggressive" }, fidelity = { "fidelity", "balanced" }, quality = { "fidelity", "balanced" }, efficient = { "balanced", "balanced" } }
Smart.GOALS = {
	{ key = "fps", name = "FPS", desc = "Holds your target first; trims effects early." },
	{ key = "balanced", name = "Balanced", desc = "Best mix of looks and speed for your target." },
	{ key = "fidelity", name = "Fidelity", desc = "Your target is a minimum; spends spare FPS on looks." },
	{ key = "eco", name = "Eco", desc = "Saves battery: caps your FPS at the target and never spends spare FPS on looks." },
}
Smart.PACES = {
	{ key = "aggressive", name = "Aggressive", desc = "Changes on the go and reacts fast." },
	{ key = "balanced", name = "Balanced", desc = "Changes on the go, calmly." },
	{ key = "smooth", name = "Smooth", desc = "Changes only when you enter a new area." },
}

local TRACKS = {}
-- The ladder, ordered by FPS gained per visible loss and the probe gains
-- measured in game: one run of steps per entry. stop: step down to that value; n: at most n steps (default 1).
-- scaled: only while render scale is under 1 (resample does nothing at full scale). "floor" = the scale floor.
TRACKS.down = {
	{ cvar = "shadowSoft", stop = 0 },
	{ cvar = "RenderScale", stop = 0.90 },
	{ cvar = "ResampleQuality", stop = 2, scaled = true },
	{ cvar = "graphicsSSAO" },
	{ cvar = "graphicsComputeEffects" },
	{ cvar = "RenderScale", stop = 0.85 },
	{ cvar = "graphicsLightMode" },
	{ cvar = "RenderScale", stop = 0.80 },
	{ cvar = "RenderScale", stop = "floor" },
	{ cvar = "graphicsSSAO" },
	{ cvar = "graphicsComputeEffects" },
	{ cvar = "graphicsLightMode" },
}
-- CPU levers (crowds, cities): first for the FPS goal or a zone proven CPU-bound, else after the pixel rungs.
TRACKS.cpu = {
	{ cvar = "graphicsSpellDensity" },
	{ cvar = "graphicsParticleDensity", raidMin = 2 },
	{ cvar = "groundEffectDensity", stop = 16, n = 2 },
}
TRACKS.cpuSet = {}
for _, e in ipairs(TRACKS.cpu) do TRACKS.cpuSet[e.cvar] = true end
-- Two tracks. The cost track: the ladder below the profile and, while fps sits at the ceiling, the costly knobs above it
-- (TRACKS.up, one probe each). The free track: the knobs measured at about 0% (shadow quality, view distance,
-- environment detail, depth effects, ground clutter, liquid detail, sun shafts), never lowered for load; raised to their
-- top in one batch at the ceiling, first; dropped back in one batch only when the cost track is at its floor and fps is
-- still short (first, in a CPU-bound zone).
TRACKS.up = { "RenderScale", "graphicsSSAO", "graphicsComputeEffects", "graphicsLightMode", "shadowSoft" }
TRACKS.free = { "graphicsViewDistance", "graphicsShadowQuality", "graphicsEnvironmentDetail", "graphicsDepthEffects", "graphicsGroundClutter", "graphicsLiquidDetail", "sunShafts" }
-- Writes that stutter (probe P4: render scale ~130 ms, liquid detail up to 123 ms) cost 2 from the budget.
TRACKS.hitchy = { RenderScale = true, graphicsLiquidDetail = true }
-- SCALE_MAX is native (100%): resample only matters under it, and the up track passes it last (supersampling costs the
-- most for its looks). The player's maximum (db.smart.scaleMax, up to 200%) caps Smart's own raises above it.
local SCALE, LIGHT, SCALE_STEP, SCALE_MAX = "RenderScale", "graphicsLightMode", 0.05, 1.0

-- Measure: a ceiling candidate is the highest 5-minute p90 (of 60 valid seconds at least) that was flat at the top (p50
-- within 2% of p90: the shape of a display, vsync or cap limit), forgotten after 24 h unseen; maxFPS when it is on. At or
-- above the target it needs no proof. Below it must be confirmed (until then goal = target): within 3% of the target, or
-- whenever a probe raise is kept with no loss at it, machine-wide; further below, by cuts that gain nothing (2 pixel
-- rungs, then 2 CPU rungs unless the zone is CPU-bound, each under 2%), undone in one batch, for this zone only.
-- "At ceiling" = window median at 98% of the candidate. Buckets
-- within 3 s of a zone change, a loading screen or our own write don't count; a hitch second (worst frame over 4x the
-- others) never does. Short = window median under goal x lowerAt with 70% of the window below.
local MEASURE = { ceilMin = 60, ceilShare = 0.9, flat = 0.98, forget = 86400, goalShare = 0.97, atCeiling = 0.98, quiet = 3, hitch = 4, below = 0.7, binsPerFps = 2 }
MEASURE.nearTarget, MEASURE.noGain, MEASURE.flatRungs, MEASURE.noLoss = 0.97, 2, 2, 0.995
-- Decide: a probe raise is judged on the next 8 valid seconds; kept at 98% of before (at ceiling) or 103% of the goal.
-- A reverted probe sets the zone's best; it opens again when the 60 s median moves 10% or after 24 h.
local PROBE = { judge = 8, keepCeiling = 0.98, keepHeadroom = 1.03, drift = 0.10, driftN = 60, reopen = 86400, wait = 120, waitMax = 900 }
-- A probe or a cut whose window median moved more than 10% the other way (the load changed) is dropped, not judged.
-- Far short (over 10% under the goal): one batch of up to 4 rungs whose estimated gains cover the gap.
PROBE.regime, PROBE.farShort, PROBE.batchMax = 0.10, 0.10, 4
-- Change budget per 10 min (pace.budget) outside zone entry; hitchy writes at least 20 s apart; a cut within 3 min of a
-- kept raise locks raises in that zone for 15 min, doubling up to 2 h.
local CALM = { budgetWindow = 600, hitchGap = 20, flapWindow = 180, lockFirst = 900, lockMax = 7200, farShort = 0.15 }
-- Learn: only probes and A/B/A tests feed gains. A sample is clamped to 0..2.5x the prior; the estimate shrinks to the
-- prior (5 virtual samples); learned gains reorder adjacent rungs only with 8 samples and a 50% difference.
local LEARN = { capTimes = 2.5, shrink = 5, reorderN = 8, reorderBy = 1.5, alpha = 0.3, cpuLow = 2, cpuHigh = 4, cpuTests = 2 }
-- Learning is passive: Smart never changes a setting only to learn. A sustained-load cut feeds half a sample (the median
-- of the 8 valid seconds after against the trigger window); a reverted probe feeds its cost when fps came back within 3%.
LEARN.stepWeight, LEARN.backWithin = 0.5, 0.03
local LEARN_VERSION = 3
local WARMUP, PRE_HOLD = 5, 5
local DEFAULT_PRIOR = 0.5
local LIMITS = { targetMin = 20, targetMax = 240, floorMin = 0.33, floorMax = 1.0, topMin = 1.0, topMax = 2.0 }
-- Area fps EMAs move slowly (about 20 s) so one hitch or one good second doesn't redefine a place.
local AREA_ALPHA, AREA_CAP, SUB_SPLIT, SUB_MIN, AREA_SEP = 0.05, 300, 0.15, 60, " · "
local DEFAULTS = { target = 60, scaleFloor = 0.75, scaleMax = 1.0 }
local NOTICE = { fightAfter = 5, fightCuts = 3, smoothLow = 0.8, smoothAfter = 30 }
local SUGGEST = { after = 60, share = 0.7, below = 0.85, snooze = 7 * 86400 }
local ADJ = { warm = 3, gap = 3, lower = 2, hold = 10, max = 90, away = 30 }

-- Sampler state: OnUpdate only adds to frames/spent/worst; a full second rolls into fixed rings. No allocation.
local sampler = CreateFrame("Frame")
local frames, spent, worstFrame = 0, 0, 0
local ringFps, ringValid, scratch = {}, {}, {}
for i = 1, RING do ringFps[i], ringValid[i] = 0, 0 end
for i = 1, PROBE.driftN do scratch[i] = 0 end
local longBin, hist, longN = {}, {}, 0
for i = 1, LONG do longBin[i] = 0 end
for i = 1, HIST_BINS do hist[i] = 0 end
local bucketNo, validFrom, quietUntil = 0, 0, 0
local bucketHook

local loading, pauseUntil, preUntil, lastFire, dirty = false, 0, 0, 0, false
local calm = { lastChange = -math.huge, settleUntil = 0, recovering = false, regionUntil = 0, lowFor = 0, lastHitchy = -math.huge, driftN = 0 }
local changeT, changeW = {}, {}
for i = 1, 16 do changeT[i], changeW[i] = -math.huge, 0 end
local changeNo = 0
local locKey, locOverride, zoneName
local areaKey, areaName, area
local failed = {}
local areaInfo = {}
local state = { status = "off", last = {} }
local watchSeconds, watchBelow, watchSum = 0, 0, 0
local asked, suggestion, held = {}, nil, nil
local adjust, modeShown
local fight = { low = 0, shown = false, defer = false }
local probe = { active = false }
-- The sample of the last sustained-load cut, and a flat window under the target being tested as a limit (cuts that gain
-- nothing confirm it).
local learnStep = { active = false }
local flatTest = { active = false }
local adjRing = {}
for i = 1, ADJ.hold do adjRing[i] = 0 end
-- The ladder for the current base values and goal: built on demand, dropped when either changes.
local ladder = { dirty = true, rungs = {}, ups = {}, bonus = {} }
local baseVals
local startSampler, refresh, areaEntry, applyCut, openRegion, offer, decide

local function plain(v)
	if ns.plain then return ns.plain(v) end
	return v
end

local function now() return GetTime() end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function ema(old, v, alpha) return old and old + alpha * (v - old) or v end

local function cfg()
	local db = ns.db
	if type(db) ~= "table" then return nil end
	if type(db.smart) ~= "table" then db.smart = { enabled = false } end
	local smart = db.smart
	if type(smart.learned) ~= "table" then smart.learned = {} end
	if type(smart.areas) ~= "table" then smart.areas = {} end
	if type(smart.gains) ~= "table" then smart.gains = {} end
	if type(smart.snoozed) ~= "table" then smart.snoozed = {} end
	return smart
end

local function setting(key)
	local smart = cfg()
	return smart and tonumber(smart[key]) or DEFAULTS[key]
end

local function getCVar(name)
	if not (C_CVar and C_CVar.GetCVar) then return nil end
	local ok, v = pcall(C_CVar.GetCVar, name)
	if not ok then return nil end
	return plain(v)
end

-- Simulated values while working out the cuts a fight would need (nothing is written then).
local shadow = {}
local function current(cvar)
	local v = shadow[cvar]
	if v ~= nil then return v end
	return tonumber(getCVar(cvar))
end

local function gameText(fn)
	if not fn then return "" end
	local ok, text = pcall(fn)
	text = ok and plain(text)
	return type(text) == "string" and text or ""
end

local function inCombat() return not not (ns.InCombat and ns.InCombat()) end

local function slot(b) return (b - 1) % RING + 1 end

local function takeLocation(loc)
	if type(loc) ~= "table" then return end
	locKey, locOverride, zoneName = loc.key, loc.overrideKey, loc.name
end

local function currentLocKey()
	if locKey or not (ns.Location and ns.Location.Current) then return locKey end
	local ok, loc = pcall(ns.Location.Current)
	if ok then takeLocation(loc) end
	return locKey
end

local function goalKey(key)
	local smart = cfg()
	local goals = smart and type(smart.goals) == "table" and smart.goals
	local name = key and goals and goals[key]
	if GOALS[name] then return name end
	name = smart and smart.goal
	return GOALS[name] and name or "balanced"
end

local function paceKey()
	local smart = cfg()
	local name = smart and smart.pace
	return PACES[name] and name or "balanced"
end

local function activeMode() return COMBOS[goalKey(currentLocKey())][paceKey()] end

local function isKnob(entry) return entry and entry.smart and not entry.heavy end

local function usable(cvar)
	local db = ns.db
	return not failed[cvar] and not (db and db.unsupported and db.unsupported[cvar])
end

local function scaleFloor()
	local floor = setting("scaleFloor")
	local minScale = activeMode().minScale
	return minScale and math.max(floor, minScale) or floor
end

-- The top of Smart's own render scale raises: the player's maximum within the Catalog's range.
local function scaleTop()
	local entry = ns.Catalog and ns.Catalog.Get and ns.Catalog.Get(SCALE)
	return math.min(setting("scaleMax"), entry and entry.max or SCALE_MAX)
end

-- Measure ---------------------------------------------------------------------------------------------------------

local function capCVar()
	local cap = getCVar("useMaxFPS") == "1" and tonumber(getCVar("maxFPS")) or nil
	return cap and cap > 0 and cap or nil
end

local function pushLong(fps)
	local j = (bucketNo - 1) % LONG + 1
	local old = longBin[j]
	if old > 0 then hist[old], longN = hist[old] - 1, longN - 1 end
	if not fps then
		longBin[j] = 0
		return
	end
	local b = clamp(math.floor(fps * MEASURE.binsPerFps + 0.5), 1, HIST_BINS)
	longBin[j], hist[b], longN = b, hist[b] + 1, longN + 1
end

-- The share-th fps of the valid seconds of the last 5 minutes.
local function longPercentile(share)
	local want, seen = math.ceil(longN * share), 0
	for b = 1, HIST_BINS do
		seen = seen + hist[b]
		if seen >= want then return b / MEASURE.binsPerFps end
	end
	return nil
end

local function alive(c) return type(c) == "table" and tonumber(c.fps) and time() - (tonumber(c.t) or 0) < MEASURE.forget end

-- The flat-topped candidate, confirmed or not (for "at ceiling"); maxFPS when it is on.
local function candidate()
	local cap = capCVar()
	if cap then return cap end
	local smart = cfg()
	local c = smart and smart.ceiling
	return alive(c) and c.fps or nil
end

-- The ceiling the goal trusts: maxFPS; this zone's confirmed one; the machine-wide one once confirmed or at or above the
-- target. nil -> goal = target.
local function ceiling()
	local cap = capCVar()
	if cap then return cap end
	local smart = cfg()
	if not smart then return nil end
	local a = area or (areaKey and smart.areas[areaKey])
	if type(a) == "table" and alive(a.ceiling) then return a.ceiling.fps end
	local c = smart.ceiling
	if alive(c) and (c.confirmed or c.fps >= setting("target")) then return c.fps end
	return nil
end

-- While Eco holds the frame cap, fps sits at our own cap: that is not the display's limit.
local function ecoHolds()
	local smart = cfg()
	return smart and type(smart.ecoCap) == "table"
end

local function confirmCeiling()
	local smart = cfg()
	local c = smart and smart.ceiling
	if not alive(c) or c.confirmed then return end
	c.confirmed = true
	if ns.debug then ns.debug("smart ceiling %.1f confirmed", c.fps) end
end

local function updateCeiling()
	if longN < MEASURE.ceilMin or ecoHolds() then return end
	local smart = cfg()
	if not smart then return end
	local top, mid = longPercentile(MEASURE.ceilShare), longPercentile(0.5)
	if not (top and mid and mid >= top * MEASURE.flat) then return end
	local c = type(smart.ceiling) == "table" and smart.ceiling
	local t = time()
	if not c or not tonumber(c.fps) or top > c.fps / MEASURE.flat or t - (tonumber(c.t) or 0) >= MEASURE.forget then
		smart.ceiling = { fps = top, t = t, confirmed = false }
	elseif top >= c.fps * MEASURE.flat then
		c.t = t
	end
	-- A zone's own ceiling goes when something clearly higher shows up there.
	local a = area
	if type(a) == "table" and alive(a.ceiling) and top > a.ceiling.fps / MEASURE.flat then a.ceiling = nil end
end

-- goal, ceiling, cap
local function goalAndCap()
	local target, ceil = setting("target"), ceiling()
	if not ceil then return target, nil, capCVar() end
	return ceil >= target and target or ceil * MEASURE.goalShare, ceil, capCVar()
end

-- Median of the last n valid seconds since validFrom (sorted into scratch) and how many there were.
local function window(n)
	local k = 0
	for b = bucketNo, math.max(validFrom + 1, bucketNo - RING + 1), -1 do
		local i = slot(b)
		if ringValid[i] == 1 then
			k = k + 1
			local v, j = ringFps[i], k - 1
			while j > 0 and scratch[j] > v do
				scratch[j + 1] = scratch[j]
				j = j - 1
			end
			scratch[j + 1] = v
			if k == n then break end
		end
	end
	if k == 0 then return nil, 0 end
	return scratch[math.floor((k + 1) / 2)], k
end

-- How many of the k sorted window values are under line (call right after window()).
local function countBelow(k, line)
	local c = 0
	for j = 1, k do
		if scratch[j] >= line then break end
		c = c + 1
	end
	return c
end

-- Median of the last n entries of the 5-minute ring (fps), for the drift check.
local function longMedian(n)
	local k = 0
	for d = 0, LONG - 1 do
		local b = longBin[(bucketNo - 1 - d) % LONG + 1]
		if b > 0 then
			k = k + 1
			local v, j = b / MEASURE.binsPerFps, k - 1
			while j > 0 and scratch[j] > v do
				scratch[j + 1] = scratch[j]
				j = j - 1
			end
			scratch[j + 1] = v
			if k == n then break end
		end
	end
	if k == 0 then return nil end
	return scratch[math.floor((k + 1) / 2)]
end

local function markQuiet() quietUntil = now() + MEASURE.quiet end

local function notify(force)
	local t = now()
	if not force and t - lastFire < 1 then
		dirty = true
		return
	end
	lastFire, dirty = t, false
	if ns.Fire then ns.Fire("FSG_SMART", Smart.State()) end
end

local function setStatus(status)
	if state.status == status then return end
	state.status = status
	notify()
end

-- Learn -----------------------------------------------------------------------------------------------------------

local function prior(cvar)
	local Catalog = ns.Catalog
	if Catalog and Catalog.Impact then
		local ok, _, impact = pcall(Catalog.Impact, cvar)
		if ok and tonumber(impact) and impact > 0 then return impact end
	end
	local p = Catalog and Catalog.PRIOR and Catalog.PRIOR[cvar]
	return tonumber(p) or DEFAULT_PRIOR
end

-- The learned estimate, shrunk toward the prior, and how many samples it has.
local function estimate(cvar)
	local smart = cfg()
	local g = smart and smart.gains[cvar]
	local p = prior(cvar)
	local n = g and tonumber(g.n) or 0
	if n <= 0 then return p, 0 end
	return (n * g.ema + LEARN.shrink * p) / (n + LEARN.shrink), n
end

-- One sample from a probe or an A/B/A test, clamped to 0 .. 2.5x the prior.
local function feed(cvar, gain, weight)
	local smart = cfg()
	if not (smart and cvar and gain) then return end
	gain, weight = clamp(gain, 0, prior(cvar) * LEARN.capTimes), weight or 1
	local g = smart.gains[cvar]
	if not g then
		smart.gains[cvar] = { ema = gain, n = weight }
	else
		g.ema, g.n = (g.n or 0) > 0 and ema(g.ema, gain, LEARN.alpha * weight) or gain, (g.n or 0) + weight
	end
	ladder.dirty = true
	if ns.debug then ns.debug("smart learned %s %.1f%%", cvar, gain) end
end

-- Ladder ----------------------------------------------------------------------------------------------------------

-- The knob values the rung walk starts from: the profile in force (Apply.Target hands them to Adjust), else the
-- profile Location picks, else the knobs as they are now.
local function baseValues()
	if baseVals then return baseVals end
	local vals = {}
	local Profiles, Location = ns.Profiles, ns.Location
	if Profiles and Profiles.Effective and Location and Location.ProfileFor then
		local ok, eff = pcall(function() return Profiles.Effective(Location.ProfileFor(Location.Current and Location.Current() or nil)) end)
		if ok and type(eff) == "table" then
			for cvar, v in pairs(eff) do vals[cvar] = tonumber(v) end
		end
	end
	for _, entry in ipairs(ns.Catalog.LIST) do
		if isKnob(entry) and vals[entry.cvar] == nil then vals[entry.cvar] = current(entry.cvar) end
	end
	baseVals = vals
	return vals
end

local function zoneCpu()
	local smart = cfg()
	local a = area or (smart and areaKey and smart.areas[areaKey])
	return type(a) == "table" and a.cpu == true
end

local function buildLadder()
	local Catalog = ns.Catalog
	local m, raid, floor = activeMode(), currentLocKey() == "raid", scaleFloor()
	local base = baseValues()
	local v = {}
	for cvar, value in pairs(base) do v[cvar] = value end
	local rungs, ups, bonus = {}, {}, {}
	local function add(list, cvar, to)
		list[#list + 1] = { cvar = cvar, from = v[cvar], to = to }
		v[cvar] = to
	end
	local function run(e)
		local cvar = e.cvar
		local entry = Catalog.Get(cvar)
		if not (isKnob(entry) and v[cvar] ~= nil) then return end
		if cvar == SCALE then
			local stop = e.stop == "floor" and floor or math.max(e.stop, floor)
			while v[cvar] > stop + 0.001 do add(rungs, cvar, round2(math.max(stop, v[cvar] - SCALE_STEP))) end
			return
		end
		if e.scaled and not (v[SCALE] and v[SCALE] < SCALE_MAX - 0.001) then return end
		local lowest = (cvar == LIGHT and m.lightMin) or (raid and e.raidMin) or e.stop or entry.min
		for _ = 1, e.n or (e.stop and 99) or 1 do
			local nextValue = Catalog.Step(cvar, v[cvar], -1)
			if not nextValue or nextValue < lowest - 1e-9 then return end
			add(rungs, cvar, nextValue)
		end
	end
	-- A profile above native: that part goes first under load.
	if v[SCALE] and v[SCALE] > SCALE_MAX + 0.001 and isKnob(Catalog.Get(SCALE)) then
		while v[SCALE] > SCALE_MAX + 0.001 do add(rungs, SCALE, round2(math.max(SCALE_MAX, v[SCALE] - SCALE_STEP))) end
	end
	local cpuFirst = m.cpuFirst or zoneCpu()
	if cpuFirst then for _, e in ipairs(TRACKS.cpu) do run(e) end end
	for _, e in ipairs(TRACKS.down) do run(e) end
	if not cpuFirst then for _, e in ipairs(TRACKS.cpu) do run(e) end end
	-- Learned gains only swap neighbours, and only with 8 samples each and a 50% difference.
	for i = 1, #rungs - 1 do
		local a, b = rungs[i], rungs[i + 1]
		if a.cvar ~= b.cvar then
			local ga, na = estimate(a.cvar)
			local gb, nb = estimate(b.cvar)
			if na >= LEARN.reorderN and nb >= LEARN.reorderN and gb > ga * LEARN.reorderBy then rungs[i], rungs[i + 1] = b, a end
		end
	end
	if m.eco then return rungs, ups, bonus end
	-- Above the profile, the costly knobs (probes at the ceiling): render scale to full, then SSAO, compute, lighting,
	-- soft shadows last.
	for cvar, value in pairs(base) do v[cvar] = value end
	local top = scaleTop()
	local function scaleUp(to)
		while v[SCALE] < to - 0.001 do add(ups, SCALE, round2(math.min(to, v[SCALE] + SCALE_STEP))) end
	end
	for _, cvar in ipairs(TRACKS.up) do
		local entry = Catalog.Get(cvar)
		if isKnob(entry) and v[cvar] ~= nil then
			if cvar == SCALE then
				scaleUp(math.min(SCALE_MAX, top))
			else
				while true do
					local nextValue = Catalog.Step(cvar, v[cvar], 1)
					if not nextValue then break end
					add(ups, cvar, nextValue)
				end
			end
		end
	end
	-- Above native, last: up to the player's maximum.
	if isKnob(Catalog.Get(SCALE)) and v[SCALE] ~= nil then scaleUp(top) end
	-- The free track: each zero-gain knob at its top, moved as one batch.
	for _, cvar in ipairs(TRACKS.free) do
		local entry = Catalog.Get(cvar)
		if isKnob(entry) and base[cvar] ~= nil and entry.max and base[cvar] < entry.max - 1e-6 then bonus[#bonus + 1] = { cvar = cvar, from = base[cvar], to = entry.max } end
	end
	return rungs, ups, bonus
end

local function theLadder()
	if ladder.dirty then
		ladder.rungs, ladder.ups, ladder.bonus = buildLadder()
		ladder.dirty = false
	end
	return ladder.rungs, ladder.ups, ladder.bonus
end

local function dirtyLadder(newBase)
	ladder.dirty = true
	if newBase then baseVals = nil end
end

local function near(a, b) return a and b and math.abs(a - b) < 1e-6 end

-- A rung is taken when its knob is at or under the rung's value (rungs of one knob go down in order); an up step when
-- its knob is at or over it.
local function rungTaken(r)
	local v = current(r.cvar)
	return v ~= nil and v <= r.to + 1e-6
end

local function upTaken(r)
	local v = current(r.cvar)
	return v ~= nil and v >= r.to - 1e-6
end

local function rungOk(r) return usable(r.cvar) end

-- The cost track's position: rungs taken down (positive) or costly steps taken up (negative).
local function posNow()
	local rungs, ups = theLadder()
	local down, up = 0, 0
	for _, r in ipairs(rungs) do if rungTaken(r) then down = down + 1 end end
	if down > 0 then return down end
	for _, r in ipairs(ups) do if upTaken(r) then up = up + 1 end end
	return -up
end

-- The free track: up when every zero-gain knob is at its top; any raised above the profile can come down.
local function freeOn()
	local _, _, bonus = theLadder()
	for _, r in ipairs(bonus) do if not upTaken(r) then return false end end
	return #bonus > 0
end

local function freeAny()
	local _, _, bonus = theLadder()
	for _, r in ipairs(bonus) do
		local v = current(r.cvar)
		if v and v > r.from + 1e-6 then return true end
	end
	return false
end

-- Next step down on the cost track: undo the last costly raise, else the first rung not taken. -> cvar, from, to
local function pickLower()
	local rungs, ups = theLadder()
	for i = #ups, 1, -1 do
		local r = ups[i]
		if upTaken(r) and rungOk(r) then return r.cvar, current(r.cvar), r.from end
	end
	for _, r in ipairs(rungs) do
		if not rungTaken(r) and rungOk(r) then return r.cvar, current(r.cvar), r.to end
	end
	return nil
end

-- Next step up on the cost track: undo the last rung taken, else (above allowed) the next costly raise.
local function pickRaise(above)
	local rungs, ups = theLadder()
	for i = #rungs, 1, -1 do
		local r = rungs[i]
		if rungTaken(r) and rungOk(r) then return r.cvar, current(r.cvar), r.from end
	end
	if not above then return nil end
	for _, r in ipairs(ups) do
		if not upTaken(r) and rungOk(r) then return r.cvar, current(r.cvar), r.to end
	end
	return nil
end

-- Knob values at cost position pos with the free track up or not (for Adjust and zone entry).
local function valuesAt(pos, free, into)
	local rungs, ups, bonus = theLadder()
	for cvar, value in pairs(baseValues()) do
		if isKnob(ns.Catalog.Get(cvar)) then into[cvar] = value end
	end
	if pos > 0 then
		for i = 1, math.min(pos, #rungs) do into[rungs[i].cvar] = rungs[i].to end
	elseif pos < 0 then
		for i = 1, math.min(-pos, #ups) do into[ups[i].cvar] = ups[i].to end
	end
	if free then
		for _, r in ipairs(bonus) do into[r.cvar] = r.to end
	end
	return into
end

-- Zones -----------------------------------------------------------------------------------------------------------

local function evict(areas)
	local count, oldKey, oldT = 0, nil, nil
	for key, a in pairs(areas) do
		count = count + 1
		local t = type(a) == "table" and tonumber(a.t) or 0
		if not oldT or t < oldT then oldKey, oldT = key, t end
	end
	if count < AREA_CAP then return end
	areas[oldKey] = nil
	return evict(areas)
end

-- The zone key: the map/instance, or map/subzone once that subzone proved different.
local function computeArea()
	local key = currentLocKey()
	if not key then return nil end
	local base, sub = locOverride or key, gameText(GetSubZoneText)
	local zone = gameText(GetRealZoneText)
	if zone == "" then zone = zoneName or key end
	local smart = cfg()
	local z = smart and smart.areas[base]
	local subs = type(z) == "table" and type(z.subs) == "table" and z.subs
	local s = sub ~= "" and subs and subs[sub]
	if type(s) == "table" and s.split then return base .. "/" .. sub, sub == zone and zone or (zone .. AREA_SEP .. sub) end
	return base, zone
end

-- The location type's median position over its known zones (for a zone seen for the first time). Costly raises are
-- earned at each zone's own ceiling, so a new zone's cost track never starts above the profile; the free track follows
-- most known zones (it costs nothing).
-- -> position, free track up (most of the known zones).
local function typicalPos(key)
	local smart = cfg()
	if not smart then return 0, false end
	local list, up = {}, 0
	for _, a in pairs(smart.areas) do
		if type(a) == "table" and a.locKey == key and tonumber(a.pos) then
			list[#list + 1] = a.pos
			if a.free then up = up + 1 end
		end
	end
	if #list == 0 then return 0, false end
	table.sort(list)
	return math.max(0, list[math.floor((#list + 1) / 2)]), up * 2 > #list
end

function areaEntry()
	if area then return area end
	local smart = cfg()
	if not (smart and areaKey) then return nil end
	area = smart.areas[areaKey]
	if area then return area end
	evict(smart.areas)
	area = { name = areaName, locKey = currentLocKey(), seconds = 0, below = 0, t = time() }
	smart.areas[areaKey] = area
	return area
end

-- Lag history (Areas, suggestions) and the subzone split check.
local function updateArea(fps, goal)
	local a = areaEntry()
	if not a then return end
	a.fps, a.minFps = ema(a.fps, fps, AREA_ALPHA), math.min(a.minFps or fps, fps)
	a.seconds = (a.seconds or 0) + 1
	if fps < goal * LOWER_AT then a.below = (a.below or 0) + 1 end
	if inCombat() then a.combatFps = ema(a.combatFps, fps, AREA_ALPHA) else a.calmFps = ema(a.calmFps, fps, AREA_ALPHA) end
	a.t = time()
	if areaKey ~= (locOverride or locKey) or inCombat() then return end
	-- Each part of the zone ("" = no subzone) keeps its own fps; one 15% off the rest of the zone becomes a zone.
	local sub = gameText(GetSubZoneText)
	if type(a.subs) ~= "table" then a.subs = {} end
	local s = a.subs[sub]
	if not s then
		s = { n = 0 }
		a.subs[sub] = s
	end
	s.fps, s.n = ema(s.fps, fps, AREA_ALPHA), s.n + 1
	if sub == "" or s.split or s.n < SUB_MIN then return end
	local sum, n = 0, 0
	for other, o in pairs(a.subs) do
		if other ~= sub and type(o) == "table" and o.fps and (o.n or 0) >= SUB_MIN / 6 then sum, n = sum + o.fps * o.n, n + o.n end
	end
	if n > 0 and math.abs(s.fps - sum / n) > (sum / n) * SUB_SPLIT then s.split = true end
end

local function rememberPos(a)
	a = a or areaEntry()
	if a then a.pos, a.free = posNow(), freeOn() end
end

-- Writes ----------------------------------------------------------------------------------------------------------

-- One knob write through Apply. Held in combat by Apply ("combat"), which is not a failure.
local function write(cvar, from, to)
	local Apply = ns.Apply
	if not (Apply and Apply.Write) then return false end
	local ok, written, why = pcall(Apply.Write, cvar, to, "smart mode (" .. activeMode().name .. ")")
	if not (ok and written) then
		if not (ok and why == "combat") then failed[cvar] = true end
		return false
	end
	markQuiet()
	local last = state.last
	last.cvar, last.from, last.to, last.t = cvar, from, to, time()
	return true
end

local function budgetUsed(t)
	local used = 0
	for i = 1, #changeT do
		if t - changeT[i] < CALM.budgetWindow then used = used + changeW[i] end
	end
	return used
end

local function hitchyIn(list)
	for _, c in ipairs(list) do if TRACKS.hitchy[c.cvar] then return true end end
	return false
end

-- Whether a raise or probe batch may go now: the pace's budget per 10 min (a batch costs 1, 2 with a stutter in it).
-- Cuts are never held back by the budget, only by the dwell and the 20 s between stutters.
local function canSpend(list, m, t)
	local hitchy = hitchyIn(list)
	if hitchy and t - calm.lastHitchy < CALM.hitchGap then return false end
	return budgetUsed(t) + (hitchy and 2 or 1) <= m.budget
end

local function spend(list, t)
	local hitchy = hitchyIn(list)
	changeNo = changeNo + 1
	local i = (changeNo - 1) % #changeT + 1
	changeT[i], changeW[i] = t, hitchy and 2 or 1
	if hitchy then calm.lastHitchy = t end
	calm.lastChange = t
end

-- One batch as a decision: every knob written once (its last value in the list), then remembered as the position.
local function writeBatch(list, t)
	local final, n = {}, 0
	for _, c in ipairs(list) do final[c.cvar] = c.to end
	for _, c in ipairs(list) do
		local to = final[c.cvar]
		if to ~= nil then
			final[c.cvar] = nil
			local from = current(c.cvar)
			if not near(from, to) and write(c.cvar, from, to) then n = n + 1 end
		end
	end
	if n == 0 then return 0 end
	spend(list, t)
	validFrom = bucketNo
	rememberPos()
	notify()
	return n
end

-- A zone's position in one batch (zone entry): outside the budget, one stutter for all of it.
local function applyPos(pos, free)
	local want = valuesAt(pos, free, {})
	local n = 0
	for cvar, value in pairs(want) do
		local v = current(cvar)
		if usable(cvar) and v ~= nil and not near(v, value) and write(cvar, v, value) then n = n + 1 end
	end
	if n == 0 then return 0 end
	local t = now()
	calm.lastChange, preUntil, pauseUntil, validFrom = t, t + PRE_HOLD, t + WARMUP, bucketNo
	state.status = "pre-adjusted"
	notify()
	return n
end

local function canAct() return Smart.Enabled() and not loading and ns.Catalog and ns.Catalog.LIST and ns.Apply end

-- The Smooth pace decides only in the window seconds after a zone's warm-up (it waits out the warm-up first).
function openRegion()
	local m, t = activeMode(), now()
	calm.regionUntil, calm.lowFor = t + WARMUP + (m.window or 0), 0
	if m.regionOnly and Smart.Enabled() then pauseUntil = math.max(pauseUntil, t + WARMUP) end
end

-- Outside its window the Smooth pace holds. After 30 s under 80% of the goal it raises one notice for the zone
-- (the FSG_SUGGEST kind) instead of changing anything.
local function holdRegion(goal)
	setStatus("holding")
	calm.lowFor = ringFps[slot(bucketNo)] < goal * NOTICE.smoothLow and calm.lowFor + 1 or 0
	if calm.lowFor < NOTICE.smoothAfter or not areaKey or asked[areaKey] then return end
	asked[areaKey] = true
	local med = window(RING)
	offer({ key = areaKey, name = areaName, locKey = currentLocKey(), overrideKey = locOverride, avg = math.floor((med or 0) + 0.5), goal = goal })
end

-- A new zone: its remembered position (or the location type's typical one) in one batch, then a warm-up.
local function enterArea()
	local key, name = computeArea()
	if not key or key == areaKey then return false end
	areaKey, areaName, area = key, name, nil
	probe.active, learnStep.active, flatTest.active = false, false, false
	calm.driftN = 0
	validFrom = bucketNo
	markQuiet()
	openRegion()
	watchSeconds, watchBelow, watchSum = 0, 0, 0
	if held and held.key ~= key then asked[held.key], held = nil, nil end
	areaInfo.key, areaInfo.name = key, name
	dirtyLadder()
	if not canAct() or inCombat() then return false end
	local smart = cfg()
	local a = smart.areas[key]
	local pos, free = a and tonumber(a.pos), a and a.free
	if not pos then
		local parent = key:match("^(.-)/") and smart.areas[key:match("^(.-)/")]
		if type(parent) == "table" and tonumber(parent.pos) then pos, free = parent.pos, parent.free else pos, free = typicalPos(currentLocKey()) end
	end
	local n = applyPos(pos, free)
	a = areaEntry()
	if a and a.pos == nil then a.pos, a.free = pos, free end
	if n == 0 then pauseUntil = math.max(pauseUntil, now() + WARMUP) end
	return n > 0
end

-- Combat ----------------------------------------------------------------------------------------------------------

-- The next rungs down, worked out on simulated values: at most n.
local function wouldCut(n)
	local cuts = {}
	for _ = 1, n do
		local cvar, from, to = pickLower()
		if not cvar then break end
		cuts[#cuts + 1] = { cvar = cvar, from = from, to = to }
		shadow[cvar] = to
	end
	for k in pairs(shadow) do shadow[k] = nil end
	return cuts
end

-- In combat nothing changes. After 5 s under the lowering line the player gets one notice per fight with the rungs
-- this mode would take; only their button applies them.
local function watchFight(m, goal)
	setStatus("in combat")
	if fight.shown then return end
	local fps = ringFps[slot(bucketNo)]
	fight.low = fps < goal * m.lowerAt and fight.low + 1 or 0
	if fight.low < NOTICE.fightAfter then return end
	local cuts = wouldCut(NOTICE.fightCuts)
	if #cuts == 0 then return end
	local sum = 0
	for b = bucketNo - NOTICE.fightAfter + 1, bucketNo do sum = sum + ringFps[slot(b)] end
	fight.shown, fight.fps, fight.goal, fight.cuts = true, math.floor(sum / NOTICE.fightAfter + 0.5), goal, cuts
	if ns.Fire then ns.Fire("FSG_COMBAT_LOW", Smart.CombatLow()) end
end

-- Decide ----------------------------------------------------------------------------------------------------------

-- While a flat window is tested as a limit: pixel rungs first, then (unless the zone is CPU-bound) CPU rungs.
local function flatPick()
	local wantCpu = flatTest.pixel >= MEASURE.flatRungs
	if wantCpu and (zoneCpu() or flatTest.cpu >= MEASURE.flatRungs) then return nil end
	for _, r in ipairs((theLadder())) do
		if not rungTaken(r) and rungOk(r) and (TRACKS.cpuSet[r.cvar] or false) == wantCpu then return r.cvar, current(r.cvar), r.to end
	end
	return nil
end

-- Nothing helped: it is this zone's limit. The test cuts go back in one batch.
local function confirmFlat()
	flatTest.active = false
	for i = #flatTest.cuts, 1, -1 do
		local c = flatTest.cuts[i]
		write(c.cvar, current(c.cvar), c.from)
	end
	validFrom = bucketNo
	local a = areaEntry()
	if a then a.ceiling = { fps = flatTest.fps, t = time() } end
	rememberPos()
	if ns.debug then ns.debug("smart zone ceiling %.1f confirmed", flatTest.fps) end
	setStatus("holding")
end

-- The sample of a sustained-load cut: half weight, the CPU flag (render scale), and the flat-window test.
local function finishStep(after)
	learnStep.active = false
	local before = learnStep.before
	if not (before and before > 0) then return end
	local gain = (after - before) / before * 100
	-- The load changed while it was pending (fps fell, or rose far past what one rung can give): not judged.
	if after < before * (1 - PROBE.regime) or gain > math.max(PROBE.regime * 100, prior(learnStep.cvar) * LEARN.capTimes) then
		if flatTest.active then flatTest.active = false end
		return
	end
	feed(learnStep.cvar, gain, LEARN.stepWeight)
	local a = areaEntry()
	if a and learnStep.cvar == SCALE then
		if gain > LEARN.cpuHigh then
			a.cpu, a.cpuLow = false, 0
		elseif gain < LEARN.cpuLow then
			a.cpuLow = (a.cpuLow or 0) + 1
			if a.cpuLow >= LEARN.cpuTests then a.cpu = true end
		end
		dirtyLadder()
	end
	if not flatTest.active then return end
	if gain >= MEASURE.noGain then
		-- A cut helped: that level was load, not a limit.
		flatTest.active = false
		if a then a.flatNo = time() end
		local smart = cfg()
		if smart and type(smart.ceiling) == "table" and not smart.ceiling.confirmed then smart.ceiling = nil end
		return
	end
	if TRACKS.cpuSet[learnStep.cvar] then flatTest.cpu = flatTest.cpu + 1 else flatTest.pixel = flatTest.pixel + 1 end
	if not flatPick() then confirmFlat() end
end

-- The next n cost-track rungs down, worked out on simulated values; with need (a % to cover) it stops once the summed
-- estimates reach it. A stutter rung that may not go yet ends the list.
local function nextCuts(n, need, t)
	local list, sum = {}, 0
	for _ = 1, n do
		local cvar, from, to = pickLower()
		if not cvar then break end
		if TRACKS.hitchy[cvar] and t - calm.lastHitchy < CALM.hitchGap then break end
		list[#list + 1] = { cvar = cvar, from = from, to = to }
		shadow[cvar] = to
		sum = sum + estimate(cvar)
		if not need or sum >= need then break end
	end
	for k in pairs(shadow) do shadow[k] = nil end
	return list
end

-- The free track back to the profile (or up to the top) in one batch.
local function freeBatch(up)
	local _, _, bonus = theLadder()
	local list = {}
	for _, r in ipairs(bonus) do
		local v = current(r.cvar)
		local to = up and r.to or r.from
		if v and rungOk(r) and not near(v, to) then list[#list + 1] = { cvar = r.cvar, from = v, to = to } end
	end
	return list
end

-- A probe: a batch judged on the next 8 valid seconds. kind "cost" (one rung up), "free" (the free track up) or "drop"
-- (the free track down at the cost floor).
local function startProbe(kind, list, med, atCeil, t)
	if writeBatch(list, t) == 0 then return false end
	probe.active, probe.kind, probe.list, probe.before, probe.atCeil, probe.back = true, kind, list, med, atCeil, false
	learnStep.active = false
	setStatus(kind == "drop" and "lowering" or "raising (testing)")
	return true
end

-- Cut while short: one rung, or (over 10% short, outside a flat-window test) one batch of up to 4 covering the gap.
-- The budget never holds a cut back. At the cost floor the free track drops in one batch (first, in a CPU-bound zone).
local function lower(m, med, goal, t)
	local a = areaEntry()
	if a then
		a.best, a.settledFps = nil, nil
		-- A cut within 3 min of a kept raise is a flap: raises here wait (once per flap).
		if a.lastRaise and time() - a.lastRaise < CALM.flapWindow then
			a.lockLen = a.lockLen and math.min(a.lockLen * 2, CALM.lockMax) or CALM.lockFirst
			a.lockUntil, a.lastRaise = time() + a.lockLen, nil
		end
	end
	local canDrop = freeAny() and not (a and a.freeFree)
	if canDrop and zoneCpu() and startProbe("drop", freeBatch(false), med, false, t) then return end
	local list
	if flatTest.active then
		local cvar, from, to = flatPick()
		list = cvar and { { cvar = cvar, from = from, to = to } } or {}
	else
		local far = med < goal * (1 - PROBE.farShort)
		list = nextCuts(far and PROBE.batchMax or 1, far and (goal / med - 1) * 100 or nil, t)
	end
	if #list == 0 then
		if pickLower() then return setStatus("lowering") end
		if flatTest.active then
			if #flatTest.cuts > 0 then return confirmFlat() end
			flatTest.active = false
		end
		if canDrop and startProbe("drop", freeBatch(false), med, false, t) then return end
		return setStatus("at floor")
	end
	if writeBatch(list, t) == 0 then return setStatus("at floor") end
	if flatTest.active then flatTest.cuts[#flatTest.cuts + 1] = list[1] end
	-- One rung after about 10 s under the goal is half a sample; a batch can't be told apart.
	if #list == 1 then learnStep.active, learnStep.cvar, learnStep.before = true, list[1].cvar, med else learnStep.active = false end
	calm.recovering = true
	setStatus("lowering")
end

-- Raise: the free track first (one batch, at the ceiling), then the cost track one rung (undo a cut; at the ceiling, a
-- costly raise above the profile).
local function raise(m, med, atCeil, t)
	local a = areaEntry()
	local list
	if atCeil and not freeOn() and not (a and a.freeCost) then list = freeBatch(true) end
	local kind = list and #list > 0 and "free" or "cost"
	if kind == "cost" then
		local cvar, from, to = pickRaise(atCeil)
		list = cvar and { { cvar = cvar, from = from, to = to } } or {}
	end
	if #list == 0 then
		local cand = candidate()
		if atCeil and cand and cand >= setting("target") * MEASURE.nearTarget then confirmCeiling() end
		if a and atCeil and not a.best then a.best, a.bestAt, a.settledFps = posNow(), time(), med end
		return setStatus("best look at target")
	end
	if not canSpend(list, m, t) then return setStatus("holding (settling)") end
	if not startProbe(kind, list, med, atCeil, t) then setStatus("holding") end
end

local function revertProbe()
	local back = {}
	for i = #probe.list, 1, -1 do
		local c = probe.list[i]
		back[#back + 1] = { cvar = c.cvar, from = c.to, to = c.from }
	end
	writeBatch(back, now())
end

local function checkProbe(m, goal)
	local med, k = window(PROBE.judge)
	if k < PROBE.judge then return setStatus(probe.back and "best look at target" or (probe.kind == "drop" and "lowering" or "raising (testing)")) end
	local a = areaEntry()
	-- After a revert: the cost counts only when fps came back to where it was (a clean A/B/A).
	if probe.back then
		probe.active = false
		local only = probe.kind == "cost" and #probe.list == 1 and probe.list[1]
		if only and probe.before > 0 and math.abs(med - probe.before) <= probe.before * LEARN.backWithin then feed(only.cvar, probe.cost) end
		return setStatus("best look at target")
	end
	probe.active = false
	-- The free track dropped at the cost floor: if that gained nothing it goes back up and stays up here.
	if probe.kind == "drop" then
		if a and med < probe.before * (1 + MEASURE.noGain / 100) then
			a.freeFree = true
			revertProbe()
		elseif a then
			a.freeCost = true
		end
		rememberPos()
		return setStatus("holding")
	end
	-- The load changed under the probe (the median moved more than 10% the other way): dropped, not judged.
	if med > probe.before * (1 + PROBE.regime) then
		rememberPos()
		return setStatus("holding")
	end
	local keep = probe.atCeil and med >= probe.before * PROBE.keepCeiling or (not probe.atCeil and med >= goal * PROBE.keepHeadroom)
	if keep then
		-- A costly raise kept at the candidate with no loss: the fps was capped, not the scene's limit (free knobs prove
		-- nothing, they cost nothing).
		if probe.atCeil and probe.kind == "cost" and med >= probe.before * MEASURE.noLoss then confirmCeiling() end
		if a then a.lastRaise = time() end
		rememberPos()
		return setStatus("holding")
	end
	if a then
		a.backoff = a.backoff and math.min(a.backoff * 2, PROBE.waitMax) or PROBE.wait
		a.waitUntil = time() + a.backoff
	end
	if med < probe.before * (1 - PROBE.regime) and probe.kind == "cost" then
		-- A drop this big may be load arriving, not the probe: it is undone (safe) but neither judged nor remembered.
		revertProbe()
		return setStatus("holding")
	end
	probe.active, probe.back, probe.cost = true, true, probe.before > 0 and (probe.before - med) / probe.before * 100 or 0
	revertProbe()
	if a then
		if probe.kind == "free" then a.freeCost = true end
		a.best, a.bestAt, a.settledFps = posNow(), time(), probe.before
		a.pos = a.best
	end
	calm.driftN = 0
	if ns.debug then ns.debug("smart probe %s reverted (%.1f fps)", probe.kind, med) end
	setStatus("best look at target")
end

-- A zone with a best stays closed until its 60 s median moves 10% from where it settled, or a day passes.
local function bestHolds(a)
	if not (a and a.best) then return false end
	if a.bestAt and time() - a.bestAt > PROBE.reopen then
		a.best, a.settledFps = nil, nil
		return false
	end
	calm.driftN = calm.driftN + 1
	if calm.driftN < PROBE.driftN or not a.settledFps then return true end
	calm.driftN = 0
	local med = longMedian(PROBE.driftN)
	if med and math.abs(med - a.settledFps) > a.settledFps * PROBE.drift then
		a.best, a.settledFps = nil, nil
		return false
	end
	return true
end

function decide()
	if loading or (now() < pauseUntil and not inCombat()) then return setStatus("warming") end
	if not areaKey then enterArea() end
	local goal = goalAndCap()
	updateArea(ringFps[slot(bucketNo)], goal)
	if dirty then notify() end
	if not (ns.Catalog and ns.Catalog.LIST and ns.Apply) or not currentLocKey() then return end
	local m, t = activeMode(), now()
	if inCombat() then return watchFight(m, goal) end
	if probe.active then return checkProbe(m, goal) end
	if learnStep.active then
		local after, n = window(PROBE.judge)
		if n >= PROBE.judge then finishStep(after) end
	end
	if m.regionOnly and t > calm.regionUntil then return holdRegion(goal) end
	local med, k = window(m.lowerN)
	if k < m.lowerN then return setStatus(now() < preUntil and "pre-adjusted" or "holding") end
	local line = goal * m.lowerAt
	local short = med < line and countBelow(k, line) >= k * MEASURE.below
	if short then
		local far = med < goal * (1 - CALM.farShort)
		if t - calm.lastChange < (far and m.fastLower or m.lowerDwell) then return end
		-- No trusted ceiling: the first cuts here also test whether this level is a limit (once a day per zone).
		local cand, a = candidate(), areaEntry()
		local tested = a and a.flatNo and time() - a.flatNo < MEASURE.forget
		if not flatTest.active and not learnStep.active and not ceiling() and not tested and (not cand or (cand < setting("target") * MEASURE.nearTarget and med >= cand * MEASURE.atCeiling)) then
			flatTest.active, flatTest.pixel, flatTest.cpu, flatTest.cuts, flatTest.fps = true, 0, 0, {}, cand or med
		end
		return lower(m, med, goal, t)
	end
	if calm.recovering then calm.recovering, calm.settleUntil = false, t + m.settle end
	local a = areaEntry()
	local cand = candidate()
	local atCeil = cand and med >= cand * MEASURE.atCeiling
	if bestHolds(a) then return setStatus(atCeil and "best look at target" or "holding") end
	local locked = a and a.lockUntil and time() < a.lockUntil
	local waiting = a and a.waitUntil and time() < a.waitUntil
	local room = atCeil or med >= goal * m.raiseAt
	if room and not locked and not waiting and t >= calm.settleUntil and t - calm.lastChange >= m.raiseDwell then return raise(m, med, atCeil, t) end
	setStatus(now() < preUntil and "pre-adjusted" or "holding")
end

-- Suggestions while smart mode is off -----------------------------------------------------------------------------

local function suggestOn()
	local options = type(ns.db) == "table" and ns.db.options
	return not (type(options) == "table" and options.suggest == false)
end

local function snoozed(key)
	local smart = cfg()
	local till = smart and tonumber(smart.snoozed[key])
	return till and till > time()
end

function offer(s)
	suggestion = s
	if ns.Fire then ns.Fire("FSG_SUGGEST", s) end
end

local function windowOpen() return not not (ns.UI and ns.UI.Current and ns.UI.Current()) end

local function watch(fps)
	if loading or now() < pauseUntil or not suggestOn() or windowOpen() then return end
	if not areaKey then enterArea() end
	if not areaKey or asked[areaKey] or snoozed(areaKey) then return end
	local goal = goalAndCap()
	watchSeconds, watchSum = watchSeconds + 1, watchSum + fps
	if fps < goal * SUGGEST.below then watchBelow = watchBelow + 1 end
	if watchSeconds < SUGGEST.after or watchBelow < watchSeconds * SUGGEST.share then return end
	asked[areaKey] = true
	local s = { key = areaKey, name = areaName, locKey = currentLocKey(), overrideKey = locOverride, avg = math.floor(watchSum / watchSeconds + 0.5), goal = goal }
	if inCombat() then held = s else offer(s) end
end

-- Smart adjust (one place, smart mode off) ------------------------------------------------------------------------

local function fireAdjust() if ns.Fire then ns.Fire("FSG_ADJUST", Smart.AdjustState()) end end

local function adjWrite(cvar, to)
	local ok, written, why = pcall(ns.Apply.Write, cvar, to)
	if ok and written then return true end
	if not (ok and why == "combat") then failed[cvar] = true end
	return false
end

local function adjMean(k)
	local sum = 0
	for b = adjust.n - k + 1, adjust.n do sum = sum + adjRing[(b - 1) % ADJ.hold + 1] end
	return sum / k
end

-- The p10 of 10 buckets is the lowest one.
local function adjLowest()
	local low = adjRing[1]
	for i = 2, ADJ.hold do low = math.min(low, adjRing[i]) end
	return low
end

-- false when nothing is left to lower.
local function adjStep(a)
	local cvar, from, to = pickLower()
	if not cvar then return false end
	if not adjWrite(cvar, to) then return true end
	if a.before[cvar] == nil then a.before[cvar] = from end
	a.now[cvar] = to
	a.changes[#a.changes + 1] = { cvar = cvar, from = from, to = to }
	a.since = 0
	return true
end

-- Writes back even in another place: with switching off nothing else would undo the lowered knobs.
local function stopAdjust()
	local a = adjust
	a.running, a.paused = false, false
	for cvar, value in pairs(a.before) do adjWrite(cvar, value) end
	refresh("smart")
	startSampler()
	fireAdjust()
end

local function finishAdjust(a)
	local Profiles, Location = ns.Profiles, ns.Location
	local ok, base = pcall(function() return Profiles.Effective(Location.ProfileFor()) end)
	local values = {}
	for cvar, value in pairs(ok and type(base) == "table" and base or {}) do values[cvar] = value end
	for _, entry in ipairs(ns.Catalog.LIST) do
		if isKnob(entry) then values[entry.cvar] = current(entry.cvar) or values[entry.cvar] end
	end
	a.running, a.done = false, true
	-- Create's FSG_PROFILES_CHANGED would refresh to the old profile for a moment; only SetOverride's refresh runs.
	local options = type(ns.db) == "table" and type(ns.db.options) == "table" and ns.db.options
	local switching = options and options.switching
	if options then options.switching = false end
	local created, id = pcall(Profiles.Create, "Smart: " .. a.place, values)
	if options then options.switching = switching end
	a.profileId = created and id or nil
	if a.profileId and a.overrideKey and Profiles.SetOverride then Profiles.SetOverride(a.overrideKey, a.place, a.profileId) end
	startSampler()
	fireAdjust()
end

local function adjustTick(fps)
	local a = adjust
	if areaKey ~= a.key then
		a.awaySince = a.awaySince or now()
		if now() - a.awaySince >= ADJ.away then return stopAdjust() end
	else
		a.awaySince = nil
	end
	a.paused = loading or inCombat() or areaKey ~= a.key
	if a.paused then
		a.warm, a.since = 0, 0
		return fireAdjust()
	end
	if a.warm == 0 then
		for cvar, value in pairs(a.now) do
			if current(cvar) ~= value then adjWrite(cvar, value) end
		end
	end
	a.warm = a.warm + 1
	a.paused = a.warm <= ADJ.warm
	if a.paused then return fireAdjust() end
	a.n, a.since, a.seconds = a.n + 1, a.since + 1, a.seconds + 1
	adjRing[(a.n - 1) % ADJ.hold + 1] = fps
	local goal = goalAndCap()
	-- Smart mode's tolerance: a cap or vsync at the goal reads 59.4-60.3 against 60.
	local line = goal * LOWER_AT
	if a.seconds >= ADJ.max or (a.since >= ADJ.hold and adjLowest() >= line) then return finishAdjust(a) end
	if a.since >= ADJ.gap and adjMean(ADJ.lower) < line and not adjStep(a) then return finishAdjust(a) end
	fireAdjust()
end

-- Sampler ---------------------------------------------------------------------------------------------------------

local function onUpdate(_, elapsed)
	frames, spent = frames + 1, spent + elapsed
	if elapsed > worstFrame then worstFrame = elapsed end
	if spent < 1 then return end
	bucketNo = bucketNo + 1
	local i = slot(bucketNo)
	local fps = frames / spent
	-- A hitch second: its worst frame over 4x the other frames' average.
	local others = frames > 1 and (spent - worstFrame) / (frames - 1)
	local hitch = others and others > 0 and worstFrame > others * MEASURE.hitch
	local valid = not loading and not hitch and now() >= quietUntil and not inCombat()
	ringFps[i], ringValid[i] = fps, valid and 1 or 0
	pushLong(valid and fps or nil)
	if bucketNo % 10 == 0 then updateCeiling() end
	frames, spent, worstFrame = 0, 0, 0
	if bucketHook then bucketHook(fps) end
	if adjust and adjust.running then return adjustTick(fps) end
	if Smart.Enabled() then return decide() end
	if not bucketHook then watch(fps) end
end

local function warm()
	pauseUntil, validFrom = now() + WARMUP, bucketNo
	probe.active, learnStep.active = false, false
	markQuiet()
end

function startSampler()
	frames, spent, worstFrame = 0, 0, 0
	sampler:SetScript("OnUpdate", (Smart.Enabled() or bucketHook or (adjust and adjust.running) or suggestOn()) and onUpdate or nil)
end

function refresh(reason)
	local Apply = ns.Apply
	if Apply and Apply.Refresh then pcall(Apply.Refresh, reason) end
end

-- Saved data from the old Efficient style may still hold its frame cap: the player's own comes back once.
local function restoreOldCap()
	local smart, Apply = cfg(), ns.Apply
	local saved = smart and smart.capSaved
	if type(saved) ~= "table" or not (Apply and Apply.Write) then return end
	smart.capSaved = nil
	pcall(Apply.Write, "maxFPS", tonumber(saved.maxFPS) or 0, "smart mode")
	pcall(Apply.Write, "useMaxFPS", tonumber(saved.useMaxFPS) or 0, "smart mode")
end

-- The old single style becomes a goal and a pace, once (a fallback; Core's repair does the same).
local function migrateOldModes()
	local smart = cfg()
	if not smart then return end
	local old = OLD_MODES[smart.mode]
	if old and smart.goal == nil then smart.goal, smart.pace = old[1], smart.pace or old[2] end
	if type(smart.modes) == "table" then
		if type(smart.goals) ~= "table" then smart.goals = {} end
		for key, name in pairs(smart.modes) do
			if OLD_MODES[name] and smart.goals[key] == nil then smart.goals[key] = OLD_MODES[name][1] end
		end
	end
	smart.mode, smart.modes = nil, nil
end

-- Learning from the v2 loop credited transient recoveries to cuts; it goes once. Zone lag history stays.
local function dropStaleLearning()
	local smart = cfg()
	if not smart or smart.learnVersion == LEARN_VERSION then return end
	smart.learned, smart.gains, smart.retest, smart.learnVersion = {}, {}, nil, LEARN_VERSION
	for _, a in pairs(smart.areas) do
		if type(a) == "table" then a.settled, a.combatSettled, a.cpu, a.values, a.settledFps = nil, nil, nil, nil, nil end
	end
end

-- Eco's frame cap: the player's own cap is saved once when Eco takes over and written back once when it stops applying
-- (another goal or location goal, smart mode off, restore, or a login where it no longer applies). The fps seen under
-- our cap is then forgotten so it is never taken for the display's limit.
local function syncEco()
	local smart, Apply = cfg(), ns.Apply
	if not (smart and Apply and Apply.Write) then return end
	local reason = "smart mode (" .. GOALS.eco.name .. ")"
	if Smart.Enabled() and goalKey(currentLocKey()) == "eco" then
		if not ecoHolds() then smart.ecoCap = { useMaxFPS = tonumber(getCVar("useMaxFPS")) or 0, maxFPS = tonumber(getCVar("maxFPS")) or 0 } end
		local target = setting("target")
		if getCVar("useMaxFPS") ~= "1" then pcall(Apply.Write, "useMaxFPS", 1, reason) end
		if tonumber(getCVar("maxFPS")) ~= target then pcall(Apply.Write, "maxFPS", target, reason) end
		return
	end
	if not ecoHolds() then return end
	local saved = smart.ecoCap
	smart.ecoCap = nil
	pcall(Apply.Write, "maxFPS", tonumber(saved.maxFPS) or 0, reason)
	pcall(Apply.Write, "useMaxFPS", tonumber(saved.useMaxFPS) or 0, reason)
	for i = 1, LONG do longBin[i] = 0 end
	for i = 1, HIST_BINS do hist[i] = 0 end
	longN = 0
end

-- Re-reads the goal and pace for this place; a change is announced. Into Eco, the profile comes back from anything
-- Smart had raised above it.
local function syncMode()
	syncEco()
	local key = activeMode().name
	if key == modeShown then return end
	local intoEco = modeShown ~= nil and activeMode().eco
	modeShown = key
	dirtyLadder()
	if intoEco and Smart.Enabled() then refresh("smart") end
	notify(true)
end

-- Public API ------------------------------------------------------------------------------------------------------

function Smart.Enabled()
	local smart = cfg()
	return not not (smart and smart.enabled)
end

function Smart.SetEnabled(on)
	local smart = cfg()
	if not smart then return end
	smart.enabled = not not on
	if on and adjust and adjust.running then stopAdjust() end
	startSampler()
	if smart.enabled then warm() end
	state.status = smart.enabled and "warming" or "off"
	if smart.enabled then openRegion() end
	syncEco()
	refresh("smart")
	notify(true)
end

function Smart.SetTarget(fps)
	local smart = cfg()
	fps = tonumber(fps)
	if not (smart and fps) then return nil end
	smart.target = math.floor(clamp(fps, LIMITS.targetMin, LIMITS.targetMax) + 0.5)
	syncEco()
	notify(true)
	return smart.target
end

function Smart.Goal(key) return goalKey(key or currentLocKey()) end

function Smart.Pace() return paceKey() end

function Smart.SetGoal(name)
	local smart = cfg()
	if not (smart and GOALS[name]) then return nil end
	smart.goal = name
	syncMode()
	return name
end

-- name nil: the location type follows the overall goal again.
function Smart.SetLocationGoal(key, name)
	local smart = cfg()
	if not (smart and type(key) == "string") or (name ~= nil and not GOALS[name]) then return false end
	if type(smart.goals) ~= "table" then smart.goals = {} end
	smart.goals[key] = name
	syncMode()
	return true
end

function Smart.SetPace(name)
	local smart = cfg()
	if not (smart and PACES[name]) then return nil end
	smart.pace = name
	openRegion()
	syncMode()
	return name
end

function Smart.SetFloor(scale)
	local smart = cfg()
	scale = tonumber(scale)
	if not (smart and scale) then return nil end
	smart.scaleFloor = round2(clamp(scale, LIMITS.floorMin, LIMITS.floorMax))
	dirtyLadder()
	notify(true)
	return smart.scaleFloor
end

-- A lower maximum takes back Smart's own raise above it now (never below the profile's value); remembered positions
-- past the shorter up track stop at its end when they are applied.
function Smart.SetScaleMax(scale)
	local smart = cfg()
	scale = tonumber(scale)
	if not (smart and scale) then return nil end
	local entry = ns.Catalog and ns.Catalog.Get and ns.Catalog.Get(SCALE)
	smart.scaleMax = round2(math.min(clamp(scale, LIMITS.topMin, LIMITS.topMax), entry and entry.max or LIMITS.topMax))
	dirtyLadder()
	local live, base = current(SCALE), ns.Catalog and ns.Catalog.LIST and baseValues()[SCALE]
	local keep = math.max(smart.scaleMax, base or 0)
	if Smart.Enabled() and live and live > keep + 0.001 and usable(SCALE) and write(SCALE, live, keep) then rememberPos() end
	notify(true)
	return smart.scaleMax
end

function Smart.State()
	local goal, ceil, cap = goalAndCap()
	local med = window(5)
	state.fps = med and math.floor(med + 0.5) or nil
	state.target, state.goal, state.ceiling, state.cap, state.locKey = setting("target"), goal, ceil, cap, currentLocKey()
	state.goalKey, state.paceKey = goalKey(state.locKey), paceKey()
	state.style = COMBOS[state.goalKey][state.paceKey].name
	state.area = areaKey and areaInfo or nil
	local a = area
	state.pos = ns.Catalog and ns.Catalog.LIST and posNow() or 0
	state.best = a and a.best or nil
	state.free = ns.Catalog and ns.Catalog.LIST and freeOn() or false
	if not Smart.Enabled() then state.status = "off" end
	return state
end

function Smart.Ladder()
	local out = {}
	if not (ns.Catalog and ns.Catalog.LIST) then return out end
	for i, r in ipairs((theLadder())) do out[i] = { cvar = r.cvar, from = r.from, to = r.to } end
	return out
end

function Smart.Learned(key) return cfg() and cfg().learned[key] or nil end

function Smart.ResetLearning(key)
	local smart = cfg()
	if not smart then return end
	if key then
		smart.learned[key] = nil
		for _, a in pairs(smart.areas) do
			if type(a) == "table" and a.locKey == key then a.pos, a.best, a.settledFps, a.cpu = nil, nil, nil, nil end
		end
	else
		smart.learned, smart.areas, smart.gains, area = {}, {}, {}, nil
	end
	dirtyLadder()
	if smart.enabled then refresh("smart") end
	notify(true)
end

-- The location refresh asks for this zone's values: its rung position over the profile (the location type's typical
-- position for a zone seen for the first time). The zone is read fresh: Apply may refresh before Smart hears the move.
function Smart.Adjust(key, values)
	local out = {}
	for cvar, value in pairs(values or {}) do out[cvar] = value end
	local Catalog = ns.Catalog
	if not (Catalog and Catalog.Get and Catalog.LIST) then return out end
	if ns.Location and ns.Location.Current then
		local ok, loc = pcall(ns.Location.Current)
		if ok then takeLocation(loc) end
	end
	local saved = baseVals
	baseVals = {}
	for cvar, value in pairs(values or {}) do baseVals[cvar] = tonumber(value) end
	for _, entry in ipairs(Catalog.LIST) do
		if isKnob(entry) and baseVals[entry.cvar] == nil then baseVals[entry.cvar] = current(entry.cvar) end
	end
	dirtyLadder()
	local zone = key == locKey and computeArea()
	local smart = cfg()
	local a = zone and smart and smart.areas[zone]
	local pos, free
	if type(a) == "table" and tonumber(a.pos) then pos, free = a.pos, a.free else pos, free = typicalPos(key) end
	for cvar, value in pairs(valuesAt(pos, free, {})) do out[cvar] = value end
	-- Another location type's values were only borrowed for this answer.
	if key ~= locKey then
		baseVals = saved
		dirtyLadder()
	end
	return out
end

function Smart.SaveAsProfile(key, name)
	local Profiles, Location = ns.Profiles, ns.Location
	if not (Profiles and Profiles.Create and Profiles.Effective) then return nil end
	local id = Location and Location.ProfileFor and Location.ProfileFor({ key = key }) or "default"
	local label = Location and Location.LABELS and Location.LABELS[key] or key
	return Profiles.Create(name or (label .. " (Smart)"), Smart.Adjust(key, Profiles.Effective(id)))
end

function Smart.Areas()
	local out, smart = {}, cfg()
	if not smart then return out end
	for key, a in pairs(smart.areas) do
		local seconds = a.seconds or 0
		local combatDrop = a.combatFps and a.calmFps and a.calmFps > 0 and 1 - a.combatFps / a.calmFps or nil
		local lagShare = seconds > 0 and (a.below or 0) / seconds or 0
		out[#out + 1] = { key = key, name = a.name or key, locKey = a.locKey, fps = a.fps, minFps = a.minFps, lagShare = lagShare, seconds = seconds, combatDrop = combatDrop, learned = tonumber(a.pos) ~= nil, t = a.t }
	end
	table.sort(out, function(x, y)
		if x.lagShare ~= y.lagShare then return x.lagShare > y.lagShare end
		return x.key < y.key
	end)
	return out
end

function Smart.ForgetArea(key)
	local smart = cfg()
	if not (smart and key) then return end
	smart.areas[key] = nil
	if key == areaKey then area = nil end
	notify(true)
end

function Smart.Suggestion() return suggestion end

function Smart.DismissSuggestion(key)
	local smart = cfg()
	key = key or (suggestion and suggestion.key)
	if not (smart and key) then return end
	local t, snoozedAt = time(), smart.snoozed
	for k, till in pairs(snoozedAt) do
		if not (tonumber(till) and till > t) then snoozedAt[k] = nil end
	end
	snoozedAt[key] = t + SUGGEST.snooze
	if suggestion and suggestion.key == key then suggestion = nil end
	if held and held.key == key then held = nil end
end

function Smart.SetSuggest(on)
	local db = ns.db
	if type(db) ~= "table" then return end
	if type(db.options) ~= "table" then db.options = {} end
	db.options.suggest = not not on
	startSampler()
end

function Smart.AdjustPlace(key)
	if adjust and adjust.running then return false, "already running" end
	if Smart.Enabled() then return false, "smart mode is on" end
	if bucketHook then return false, "busy" end
	local Profiles, Apply = ns.Profiles, ns.Apply
	if not (ns.Catalog and ns.Catalog.LIST and Apply and Apply.Write and Profiles and Profiles.Create) then return false, "not loaded" end
	currentLocKey()
	if not areaKey then enterArea() end
	key = key or areaKey
	if not key or key ~= areaKey then return false, "not here" end
	asked[key] = true
	if suggestion and suggestion.key == key then suggestion = nil end
	adjust = { running = true, paused = true, key = key, name = areaName, place = zoneName or areaName or key, overrideKey = locOverride, n = 0, warm = 0, since = 0, seconds = 0, changes = {}, before = {}, now = {}, done = false }
	startSampler()
	fireAdjust()
	return true
end

function Smart.AdjustState()
	local a = adjust
	if not a then return { running = false, changes = {} } end
	local changes = {}
	for i, c in ipairs(a.changes) do changes[i] = { cvar = c.cvar, from = c.from, to = c.to } end
	return { running = a.running, paused = a.paused, key = a.key, name = a.name, seconds = a.seconds, changes = changes, done = a.done, profileId = a.profileId }
end

function Smart.CancelAdjust()
	if not (adjust and adjust.running) then return false end
	stopAdjust()
	return true
end

function Smart._Listen(fn)
	if fn and adjust and adjust.running then stopAdjust() end
	bucketHook = fn
	startSampler()
end

function Smart._PickLower() return pickLower() end

function Smart._PickRaise()
	local cvar, from, to = pickRaise(false)
	return cvar, from, to
end

-- Calibrate's own A/B samples are not fed: reactive steps credit recoveries to the step (smart-v3, Learn).
function Smart._Feed() end

Smart._IsKnob, Smart._Current = isKnob, current
function Smart._Fail(cvar) failed[cvar] = true end

-- One cut chosen by the player: written now even in combat, and kept as this zone's position.
function applyCut(c, reason, opts)
	local ok, written = pcall(ns.Apply.Write, c.cvar, c.to, reason, opts)
	if not (ok and written) then return false end
	calm.lastChange = now()
	rememberPos()
	return true
end

-- The low-fps notice of this fight, or nil: { fps, goal, cuts = { { cvar, from, to }, ... } }.
function Smart.CombatLow()
	if not (fight.shown and fight.cuts) then return nil end
	local cuts = {}
	for i, c in ipairs(fight.cuts) do cuts[i] = { cvar = c.cvar, from = c.from, to = c.to } end
	return { fps = fight.fps, goal = fight.goal, cuts = cuts }
end

-- The player's "Lower now": the notice's cuts, written in combat as a user action. -> how many were applied.
function Smart.ApplyCombatCuts()
	local cuts = fight.shown and fight.cuts
	if not cuts or not (ns.Apply and ns.Apply.Write) then return 0 end
	local n = 0
	for _, c in ipairs(cuts) do if applyCut(c, "you, in combat", { user = true }) then n = n + 1 end end
	fight.cuts = nil
	return n
end

-- The player's "After combat": the same cuts once the fight ends.
function Smart.DeferCombatCuts()
	if not (fight.shown and fight.cuts) then return false end
	fight.defer = true
	return true
end

-- Slash commands and events ---------------------------------------------------------------------------------------

local function onOff(word)
	if word == "on" then return true end
	if word == "off" then return false end
	return nil
end

local function say(msg) if ns.log then ns.log(msg) end end

-- Core passes the words after the command as a table; a plain string still works.
local function argText(args) return type(args) == "table" and table.concat(args, " ") or args or "" end

local function stateLine()
	local s = Smart.State()
	local top = s.ceiling and (" (display tops out at " .. math.floor(s.ceiling + 0.5) .. ")") or ""
	return ("Smart (%s): %s, %s fps, goal %s%s"):format(s.style, s.status, tostring(s.fps or "?"), tostring(math.floor(s.goal + 0.5)), top)
end

ns.On("FSG_READY", function()
	dropStaleLearning()
	migrateOldModes()
	restoreOldCap()
	local options = type(ns.db) == "table" and ns.db.options
	if type(options) == "table" and options.suggest == nil then options.suggest = true end
	startSampler()
	syncMode()
	if Smart.Enabled() then warm() end
	local commands = ns.commands
	if not commands then return end
	commands.smart = function(args)
		local on = onOff(argText(args):match("%S+"))
		if on ~= nil then Smart.SetEnabled(on) end
		say(stateLine())
	end
	commands.target = function(args)
		local fps = Smart.SetTarget(argText(args):match("%d+"))
		say(fps and ("Target FPS " .. fps) or "Usage: /fsg target <fps 20-240>")
	end
	commands.floor = function(args)
		local percent = tonumber(argText(args):match("%d+"))
		local scale = percent and Smart.SetFloor(percent / 100)
		say(scale and ("Render scale minimum " .. math.floor(scale * 100 + 0.5) .. "%") or "Usage: /fsg floor <percent 33-100>")
	end
	commands.maxscale = function(args)
		local percent = tonumber(argText(args):match("%d+"))
		local scale = percent and Smart.SetScaleMax(percent / 100)
		say(scale and ("Render scale maximum " .. math.floor(scale * 100 + 0.5) .. "%") or "Usage: /fsg maxscale <percent 100-200>")
	end
	commands.goal = function(args)
		local first, second = argText(args):lower():match("^%s*(%S*)%s*(%S*)")
		if GOALS[first] and second == "" then
			Smart.SetGoal(first)
			return say("Smart goal: " .. GOALS[first].name)
		end
		local labels = ns.Location and ns.Location.LABELS
		local known = labels and labels[first]
		if known and (GOALS[second] or second == "default") then
			Smart.SetLocationGoal(first, GOALS[second] and second or nil)
			return say(known .. ": " .. (GOALS[second] and GOALS[second].name or ("follows " .. GOALS[Smart.Goal("")].name)))
		end
		say("Smart: " .. activeMode().name .. ". Usage: /fsg goal <fps|balanced|fidelity|eco> or /fsg goal <location> <goal|default>")
	end
	commands.pace = function(args)
		local first = argText(args):lower():match("%S+")
		if PACES[first] then
			Smart.SetPace(first)
			return say("Smart pace: " .. PACES[first].name)
		end
		say("Smart: " .. activeMode().name .. ". Usage: /fsg pace <aggressive|balanced|smooth>")
	end
end)

-- A refresh in the middle of an adjust writes the profile over its values: rewrite them and warm up again.
local function rewarmAdjust() if adjust and adjust.running then adjust.warm = 0 end end

ns.On("FSG_PROFILES_CHANGED", function()
	rewarmAdjust()
	dirtyLadder(true)
end)

-- A failed write usually means the knob hit this client's limit; the next place gives it another chance.
ns.On("FSG_LOCATION", function(loc)
	rewarmAdjust()
	takeLocation(loc)
	failed = {}
	dirtyLadder(true)
	warm()
	enterArea()
	syncMode()
end)

-- Location's own debounce (0.3 s) runs first, so a subzone change that also changes the map is keyed on the new map.
local function subzoneChanged()
	if C_Timer and C_Timer.After then return C_Timer.After(0.5, enterArea) end
	enterArea()
end

ns.On("ZONE_CHANGED", subzoneChanged)
ns.On("ZONE_CHANGED_INDOORS", subzoneChanged)

ns.On("PLAYER_LEAVING_WORLD", function() loading = true end)

ns.On("PLAYER_ENTERING_WORLD", function()
	loading = false
	warm()
end)

ns.On("FSG_COMBAT_START", function()
	fight.low, fight.shown, fight.defer, fight.cuts = 0, false, false, nil
	probe.active, learnStep.active = false, false
end)

-- After a fight: the cuts the player put off, then a warm-up before the next decision.
ns.On("FSG_COMBAT_END", function()
	local cuts = fight.defer and fight.cuts
	if cuts then
		for _, c in ipairs(cuts) do applyCut(c, "you, after combat") end
	end
	local shown = fight.shown
	fight.low, fight.shown, fight.defer, fight.cuts = 0, false, false, nil
	if shown and ns.Fire then ns.Fire("FSG_COMBAT_LOW", nil) end
	if Smart.Enabled() then warm() end
	if not held then return end
	local s = held
	held = nil
	if windowOpen() then asked[s.key] = nil else offer(s) end
end)
