-- Forever Smart Graphics "Find my best settings": a one-time guided search while the player moves through a few
-- kinds of places. Each place type is a scene searched like smart mode, only faster; Finish saves the most
-- conservative result of all scenes as one static profile used everywhere. Nothing changes after that.
--
-- API (ns.Calibrate):
--   Start(target) -> true | false, reason    Finish() -> profile id | nil, reason
--   Stop(opts) -> true | false; opts.keepOff: the caller (Restore original) leaves switching off
--   State() -> { running, target, scenes = { { locKey, label, values, fpsP10, seconds, done }, ... },
--               current = { locKey, label, status = "searching"|"holding"|"paused" (combat)|"done", seconds } | nil, ready, hint,
--               changes = { { cvar, from, to, t }, ... } (last 6 writes, newest first), last = changes[1] | nil }
-- Stop and Finish leave smart mode off. The game's own Target FPS is off while a run is active.
-- Message FSG_CALIBRATE(state) on start, every sampled second, scene changes, finish and stop.
-- Uses Smart's bucket sampler and ladder (ns.Smart._Listen/_PickLower/_PickRaise/_IsKnob/_Current/_Fail): each scene
-- walks down the ladder until the target holds, and a raise undoes the last rung.
local addonName, ns = ...

local Calibrate = {}
ns.Calibrate = Calibrate

local RING, LOWER_BUCKETS, RAISE_BUCKETS, HOLD_BUCKETS = 20, 2, 8, 20
-- HOLD_AT: a display or frame cap at the target reads a little under it (59.94 at 60) and still holds.
local RAISE_AT, HOLD_AT, P10 = 1.08, 0.97, 0.1
local SCENE_MAX, MIN_SECONDS, SCENE_WARM, CHANGE_GAP = 120, 30, 3, 3
local TARGET_MIN, TARGET_MAX, READY_SCENES, CHANGES = 20, 240, 2, 6
local REASON, TARGET_FPS = "Find my best settings", "useTargetFPS"
local HINT_SEARCHING = "Move around here for about a minute"
local HINT_DONE = "Done here. Now go to the open world or a city"
local HINT_READY = "Ready: press Finish or visit another kind of place"

local fpsRing, scratch = {}, {}
for i = 1, RING do fpsRing[i], scratch[i] = 0, 0 end
local run

local function say(msg) if ns.log then ns.log(msg) end end

-- Core passes the words after the command as a table; a plain string still works.
local function argText(args) return type(args) == "table" and table.concat(args, " ") or args or "" end

local function fire() if ns.Fire then ns.Fire("FSG_CALIBRATE", Calibrate.State()) end end

local function slot(n) return (n - 1) % RING + 1 end

local function mean(k, n)
	local sum = 0
	for b = n - k + 1, n do sum = sum + fpsRing[slot(b)] end
	return sum / k
end

-- 10th-percentile bucket of the last k (insertion sort into a fixed scratch array: no allocation).
local function p10(k, n)
	for j = 1, k do
		local v, i = fpsRing[slot(n - k + j)], j - 1
		while i > 0 and scratch[i] > v do
			scratch[i + 1] = scratch[i]
			i = i - 1
		end
		scratch[i + 1] = v
	end
	return scratch[math.max(1, math.ceil(k * P10))]
end

local function knobValues()
	local out, Smart = {}, ns.Smart
	for _, entry in ipairs(ns.Catalog.LIST) do
		if Smart._IsKnob(entry) then out[entry.cvar] = Smart._Current(entry.cvar) end
	end
	return out
end

-- A write held for combat end (false, "combat") is not a failure.
local function write(cvar, value)
	local ok, written, why = pcall(ns.Apply.Write, cvar, value, REASON)
	if ok and written then return true end
	if not (ok and why == "combat") then ns.Smart._Fail(cvar) end
	return false
end

local function inCombat() return not not (ns.InCombat and ns.InCombat()) end

local function writeAll(values)
	local Smart = ns.Smart
	for cvar, value in pairs(values) do
		if Smart._Current(cvar) ~= value then write(cvar, value) end
	end
end

-- Lowest value per knob across the scenes that have a result (when minSeconds is given: done scenes and scenes with
-- at least that many seconds; a scene that converged sooner is a full result).
local function conservative(minSeconds)
	local merged
	for _, sc in ipairs(run.scenes) do
		if sc.values and (sc.done or sc.seconds >= (minSeconds or 0)) then
			merged = merged or {}
			for cvar, value in pairs(sc.values) do
				if merged[cvar] == nil or value < merged[cvar] then merged[cvar] = value end
			end
		end
	end
	return merged
end

local function record(sc)
	sc.values = knobValues()
	sc.fpsP10 = sc.n > 0 and p10(math.min(sc.n, RING), sc.n) or nil
end

local function finishScene(sc)
	record(sc)
	sc.done, sc.status = true, "done"
end

local function newScene(loc)
	local sc = run.current
	if sc and not sc.done then record(sc) end
	local key = type(loc) == "table" and loc.key or "outdoor"
	local labels = ns.Location and ns.Location.LABELS
	sc = { locKey = key, label = labels and labels[key] or key, seconds = 0, n = 0, warm = 0, since = 0, done = false, status = "searching" }
	run.scenes[#run.scenes + 1] = sc
	run.current = sc
	local start = conservative()
	if start and inCombat() then run.pendingStart = start elseif start then writeAll(start) end
end

local function step(sc, cvar, to)
	local from = ns.Smart._Current(cvar)
	if not write(cvar, to) then return false end
	run.nChanges = run.nChanges + 1
	local c = run.changes[(run.nChanges - 1) % CHANGES + 1]
	c.cvar, c.from, c.to, c.t = cvar, from, to, GetTime()
	sc.since, sc.status = 0, "searching"
	return true
end

local function decide(sc)
	local target, n, Smart = run.target, sc.n, ns.Smart
	local hold = target * HOLD_AT
	if n >= SCENE_MAX then return finishScene(sc) end
	if sc.since >= HOLD_BUCKETS and n >= HOLD_BUCKETS and p10(HOLD_BUCKETS, n) >= hold then return finishScene(sc) end
	if sc.since < CHANGE_GAP then return end
	local recent = mean(LOWER_BUCKETS, n)
	if recent < hold then
		local cvar, _, to = Smart._PickLower()
		if cvar and step(sc, cvar, to) then return end
	elseif n >= RAISE_BUCKETS then
		local low = p10(RAISE_BUCKETS, n)
		if low >= target * RAISE_AT then
			local cvar, _, to = Smart._PickRaise()
			if cvar and step(sc, cvar, to) then return end
		end
	end
	sc.status = recent >= hold and "holding" or "searching"
end

-- In combat the search pauses (nothing written) and warms up again after the fight.
local function onBucket(fps)
	local sc = run and run.current
	if not sc or sc.done then return end
	if inCombat() then
		sc.warm, sc.status = 0, "paused"
		return fire()
	end
	if run.pendingStart then
		writeAll(run.pendingStart)
		run.pendingStart = nil
	end
	sc.warm = sc.warm + 1
	if sc.warm <= SCENE_WARM then return end
	sc.n, sc.since = sc.n + 1, sc.since + 1
	sc.seconds = sc.n
	fpsRing[slot(sc.n)] = fps
	decide(sc)
	fire()
end

local function endRun(keepOff)
	local r = run
	run = nil
	ns.Smart._Listen(nil)
	if r.targetFPS then pcall(ns.Apply.Write, TARGET_FPS, r.targetFPS, REASON) end
	if ns.Apply.SetSwitching and not keepOff then pcall(ns.Apply.SetSwitching, r.wasSwitching) end
end

function Calibrate.State()
	if not run then return { running = false, scenes = {}, ready = false, changes = {} } end
	local scenes, done = {}, 0
	for i, sc in ipairs(run.scenes) do
		scenes[i] = { locKey = sc.locKey, label = sc.label, values = sc.values, fpsP10 = sc.fpsP10, seconds = sc.seconds, done = sc.done }
		if sc.done then done = done + 1 end
	end
	local sc = run.current
	local ready = done >= READY_SCENES
	local hint = ready and HINT_READY or (sc and sc.done and HINT_DONE) or HINT_SEARCHING
	local current = sc and { locKey = sc.locKey, label = sc.label, status = sc.status, seconds = sc.seconds }
	local changes = {}
	for k = run.nChanges, math.max(1, run.nChanges - CHANGES + 1), -1 do
		local c = run.changes[(k - 1) % CHANGES + 1]
		changes[#changes + 1] = { cvar = c.cvar, from = c.from, to = c.to, t = c.t }
	end
	return { running = true, target = run.target, scenes = scenes, current = current, ready = ready, hint = hint, changes = changes, last = changes[1] }
end

function Calibrate.Start(target)
	if run then return false, "already running" end
	local Smart, Apply, Catalog, Profiles = ns.Smart, ns.Apply, ns.Catalog, ns.Profiles
	if not (Smart and Smart._Listen and Apply and Apply.Write and Catalog and Catalog.LIST and Profiles) then return false, "not loaded" end
	local db = type(ns.db) == "table" and ns.db or {}
	target = tonumber(target) or tonumber(db.smart and db.smart.target) or 60
	local limit = tonumber(Smart.Limit and Smart.Limit())
	target = math.floor(math.max(TARGET_MIN, math.min(TARGET_MAX, limit or TARGET_MAX, target)) + 0.5)
	if Smart.Enabled() then Smart.SetEnabled(false) end
	if Smart.CancelAdjust then Smart.CancelAdjust() end
	local wasSwitching = not (type(db.options) == "table" and db.options.switching == false)
	local changes = {}
	for i = 1, CHANGES do changes[i] = {} end
	run = { target = target, scenes = {}, snapshot = knobValues(), wasSwitching = wasSwitching, changes = changes, nChanges = 0 }
	if Apply.SetSwitching then pcall(Apply.SetSwitching, false) end
	-- The game's own Target FPS lowers settings by itself and would fight the search.
	if tonumber(ns.Get and ns.Get(TARGET_FPS)) == 1 and pcall(Apply.Write, TARGET_FPS, 0, REASON) then run.targetFPS = 1 end
	local ok, loc = pcall(function() return ns.Location and ns.Location.Current() end)
	newScene(ok and loc or nil)
	Smart._Listen(onBucket)
	fire()
	return true
end

function Calibrate.Finish()
	if not run then return nil, "not running" end
	local target, sc = run.target, run.current
	if sc and not sc.done then record(sc) end
	local result = conservative(MIN_SECONDS)
	if not result then return nil, "needs 30 seconds in one place (or one finished place) first" end
	local Profiles = ns.Profiles
	local values = {}
	for cvar, value in pairs(Profiles.Effective("default") or {}) do values[cvar] = value end
	for cvar, value in pairs(result) do values[cvar] = value end
	local name = ("Best for %d FPS"):format(target)
	local id = Profiles.Create(name, values)
	if id and Profiles.AssignAll then Profiles.AssignAll(id) end
	endRun()
	local profile = id and Profiles.Get and Profiles.Get(id)
	say(('Saved "%s" and set it everywhere.'):format(profile and profile.name or name))
	fire()
	return id
end

function Calibrate.Stop(opts)
	if not run then return false end
	writeAll(run.snapshot)
	endRun(opts and opts.keepOff)
	fire()
	return true
end

ns.On("FSG_LOCATION", function(loc, _, loading)
	local sc = run and run.current
	if not sc then return end
	if loading or type(loc) ~= "table" or loc.key ~= sc.locKey then
		newScene(loc)
		fire()
	end
end)

ns.On("PLAYER_LOGOUT", function() if run then Calibrate.Stop() end end)

ns.On("FSG_READY", function()
	local commands = ns.commands
	if not commands then return end
	commands.findbest = function(args)
		local ok, reason = Calibrate.Start(argText(args):match("%d+"))
		local target = run and run.target
		say(ok and ("Finding your best settings for %d FPS. Move around, visit a few kinds of places, then /fsg finish."):format(target) or ("Can't start: " .. tostring(reason)))
	end
	commands.finish = function()
		local id, reason = Calibrate.Finish()
		if not id then say(reason == "not running" and "Find my best settings is not running." or ("Not yet: " .. tostring(reason))) end
	end
	commands.stop = function()
		say(Calibrate.Stop() and "Stopped. Your settings are back as they were. Smart mode is off." or "Find my best settings is not running.")
	end
end)
