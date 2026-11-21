-- Applies the wanted profile for the current location. The addon's only C_CVar.SetCVar call is in Apply.Write.
-- Order: the quality presets first (each rewrites engine cvars), then render, then hidden overrides.
-- Heavy settings (texture reloads, 0.4-0.7 s stutter) from the player's own action are written at once. Any other
-- heavy change waits: written at a loading screen, after a 10 s countdown the toast shows (paused in combat), with
-- Announce off quietly after 10 minutes, or at once with Apply now.
local _, ns = ...
local Apply = {}
ns.Apply = Apply

local TARGET_FPS = "useTargetFPS"
-- The player's frame cap: Apply only puts it back in RestoreOriginal (Smart's Eco goal manages it while on).
local FPS_CAP = { "maxFPS", "useMaxFPS" }
local COUNTDOWN, LOADING_WINDOW, AFTER_LOADING = 10, 3, 0.5
-- Announce off: a heavy change waits for a loading screen, but never longer than this (out of combat), then lands quietly.
local QUIET_WAIT = 600
local quietAt, quietDue
local MISSES_UNSUPPORTED = 2
local TOLERANCE = 1e-3
local RENDER_SCALE, RENDER_LIMIT_FLOOR = "RenderScale", 0.5

local misses = {}
-- Nothing changes in combat unless the player asks: automatic writes wait here (latest value wins) until combat ends.
local held = {}
-- Held values a profile refresh asked for: at combat end a fresh refresh decides those again.
local heldByRefresh, refreshing = {}, false
local USER = { user = true }
local AFTER_COMBAT = "after combat"
local writing = false
local enteredAt = -math.huge
local pending, ticker
local smartWasOn

-- Chat log of real changes: every write in one go (a profile switch, a Smart step) becomes one line, sent next frame,
-- and one FSG_CHANGES({ reason, source, changes = { { cvar, label, from, to }, ... } }) whether or not it prints.
local LINE_MAX = 250
local DEFAULT_REASON = "smart mode"
local REASONS = { smart = "smart mode", loading = "loading screen" }
local SOURCES = { ["Find my best settings"] = "calibrate", ["Restore original"] = "restore", ["Apply now"] = "apply" }
-- Smart's own steps are frequent: chat shows them only with options.chatLogSmart; FSG_CHANGES always carries them.
local QUIET = { smart = true, calibrate = true }
local changes, changeOrder, flushQueued = {}, {}, false

local function sourceOf(reason)
	if reason:find("^smart mode") then return "smart" end
	return SOURCES[reason] or "profile"
end

local function flushChanges()
	flushQueued = false
	local options = ns.db.options
	for _, reason in ipairs(changeOrder) do
		local prefix, line, parts, real = "Changed (" .. reason .. "): ", nil, {}, {}
		for _, change in ipairs(changes[reason]) do
			local cvar, from, to = change.cvar, change.from, change.to
			if not ns.Catalog.Same(cvar, from, to) then
				real[#real + 1] = change
				parts[#parts + 1] = change.label .. " " .. ns.Catalog.Format(cvar, from) .. " to " .. ns.Catalog.Format(cvar, to)
			end
		end
		local source = sourceOf(reason)
		if real[1] then ns.Fire("FSG_CHANGES", { reason = reason, source = source, changes = real }) end
		if not options.chatLog or (QUIET[source] and not options.chatLogSmart) then parts = {} end
		for _, part in ipairs(parts) do
			if line and #line + 2 + #part > LINE_MAX then
				ns.log(line)
				line = nil
			end
			line = line and line .. ", " .. part or prefix .. part
		end
		if line then ns.log(line) end
		changes[reason] = nil
	end
	for i = #changeOrder, 1, -1 do changeOrder[i] = nil end
end

-- Several writes of one cvar in a batch keep the first value and the last.
local function noteChange(cvar, from, to, reason)
	local entry = ns.Catalog.Get(cvar)
	if not (entry and from and to) then return end

	local list = changes[reason]
	if not list then
		list = {}
		changes[reason], changeOrder[#changeOrder + 1] = list, reason
	end
	for _, change in ipairs(list) do
		if change.cvar == entry.cvar then
			change.to = to
			return
		end
	end
	list[#list + 1] = { cvar = entry.cvar, label = entry.label, from = from, to = to }
	if not flushQueued then
		flushQueued = true
		C_Timer.After(0, flushChanges)
	end
end

-- Profile switches read "Open world: Default"; Smart's and the loading screen's own words otherwise.
-- The chat log's reason for a value Smart.Adjust shaped: "smart mode (Fidelity)".
local function smartReason(locKey)
	local Smart, name = ns.Smart, nil
	local key = Smart and Smart.Goal and Smart.Goal(locKey)
	for _, goal in ipairs(Smart and Smart.GOALS or {}) do
		if goal.key == key then name = goal.name end
	end
	return "smart mode" .. (name and " (" .. name .. ")" or "")
end

local function readable(reason)
	if REASONS[reason] then return REASONS[reason] end
	local loc = ns.Location.Current()
	local id, source = ns.Location.ProfileFor(loc)
	local profile = ns.Profiles.Get(id)
	local name = profile and profile.name or "Default"
	if source == "held" then return "held: " .. name end
	return (ns.Location.LABELS[loc.key] or loc.key) .. ": " .. name
end

local function smartOn() return ns.Smart and ns.Smart.Enabled() or false end
local function same(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < TOLERANCE end
local function format(value) return string.format("%.6g", value) end

-- RenderScale's real bounds are GetMin/MaxRenderScale (the Catalog already uses them): only a reading inside
-- 0.5..max may cap it, so a stray readback never blocks Smart from lowering it.
local function clamped(entry, value, readback)
	if entry.kind ~= "choice" and math.abs(readback - value) < entry.step - TOLERANCE then return false end
	if entry.cvar ~= RENDER_SCALE then return true end

	local ok, max = pcall(GetMaxRenderScale)
	max = ok and tonumber(ns.plain(max))
	return readback >= RENDER_LIMIT_FLOOR and (not max or readback <= max)
end

-- reason: the chat log's words for why ("Restore original"); Smart and Calibrate may leave it out.
-- opts.user: the player asked for it (a button, a slash command), so it may write in combat. Any other write in combat
-- is held for combat end and returns false, "combat": held, not failed.
function Apply.Write(cvar, value, reason, opts)
	value = tonumber(value)
	if type(cvar) ~= "string" or ns.Catalog.NEVER[cvar:lower()] or not value then return false, nil end
	if not (C_CVar and C_CVar.SetCVar) then return false, nil end
	if ns.InCombat() and not (opts and opts.user) then
		held[cvar], heldByRefresh[cvar] = value, refreshing or nil
		ns.debug("held %s %s for combat end (%s)", cvar, format(value), tostring(reason))
		return false, "combat"
	end

	local before = tonumber(ns.Get(cvar))
	writing = true
	local ok, result = pcall(C_CVar.SetCVar, cvar, format(value))
	writing = false
	local readback = tonumber(ns.Get(cvar))
	noteChange(cvar, before, readback, reason or DEFAULT_REASON)
	ok = ok and ns.plain(result) ~= false and ns.Catalog.Same(cvar, readback, value)
	ns.debug("write %s %s -> %s%s", cvar, format(value), tostring(readback), ok and "" or " (not taken)")
	if ok then
		misses[cvar] = nil
		return true, readback
	end

	-- A full step short of the value asked at a legal value, moved or kept: the client clamped it (or would not leave
	-- that side), so that is this machine's limit on that side for this session, not a setting it lacks.
	local entry = ns.Catalog.Get(cvar)
	local legal = entry and readback and readback >= entry.min - TOLERANCE and readback <= entry.max + TOLERANCE
	if legal and clamped(entry, value, readback) then
		local db = ns.db
		db.limits[entry.cvar], db.limitSides[entry.cvar] = readback, readback < value and "max" or "min"
		ns.Fire("FSG_LIMIT", entry.cvar, readback)
		return false, readback
	end
	if readback and not same(readback, before) then return false, readback end

	misses[cvar] = (misses[cvar] or 0) + 1
	if entry and misses[cvar] >= MISSES_UNSUPPORTED and not ns.db.unsupported[entry.cvar] then
		ns.db.unsupported[entry.cvar] = true
		ns.Fire("FSG_UNSUPPORTED", entry.cvar)
	end
	return false, readback
end

function Apply.Target()
	local loc = ns.Location.Current()
	local values = ns.Profiles.Effective((ns.Location.ProfileFor(loc)))
	if smartOn() then values = ns.Smart.Adjust(loc.key, values) end
	return values
end

function Apply.Active()
	local loc = ns.Location.Current()
	local id, source = ns.Location.ProfileFor(loc)
	local profile = ns.Profiles.Get(id)
	return { loc = loc, profileId = id, profileName = profile and profile.name or "Default", source = source }
end

local function quietSeconds() return math.max(0, math.ceil((quietAt or GetTime()) - GetTime())) end

-- { values, seconds, reason, waitingCombat, quiet }: quiet (Announce off) has no countdown; seconds is the time left
-- until it lands by itself.
function Apply.Pending()
	if pending and pending.quiet then pending.seconds = quietSeconds() end
	return pending
end

local function stopTicker()
	if ticker then ticker:Cancel() end
	ticker = nil
end

local function clearPending()
	quietAt = nil
	stopTicker()
	if not pending then return end
	pending = nil
	ns.Fire("FSG_PENDING", nil)
end

local function writeOrdered(values, reason, opts)
	for _, entry in ipairs(ns.Catalog.LIST) do
		local value = values[entry.cvar]
		if value ~= nil then Apply.Write(entry.cvar, value, reason, opts) end
	end
end

-- One batch at combat end: Catalog order, then the extras; values already in place are skipped.
local function flushHeld()
	if not next(held) then return end
	local values = held
	held = {}
	local function put(cvar, value)
		if value ~= nil and not ns.Catalog.Same(cvar, ns.Get(cvar), value) then Apply.Write(cvar, value, AFTER_COMBAT) end
	end
	for _, entry in ipairs(ns.Catalog.LIST) do put(entry.cvar, values[entry.cvar]) end
	for cvar, value in pairs(values) do
		if not ns.Catalog.Get(cvar) then put(cvar, value) end
	end
end

-- reason: the countdown's end passes the reason the change was queued with; it never runs in combat (tick waits).
local function applyPending(reason)
	if not pending then return false end

	local values = pending.values
	pending, quietAt = nil, nil
	stopTicker()
	writeOrdered(values, reason, USER)
	ns.Fire("FSG_PENDING", nil)
	return true
end

-- The player's Apply now (window, notice, /fsg applynow). Takes no argument.
function Apply.ApplyPending() return applyPending("Apply now") end

local function tick()
	if not pending then return stopTicker() end
	if ns.InCombat() then
		if not pending.waitingCombat then
			pending.waitingCombat = true
			ns.Fire("FSG_PENDING", pending)
		end
		return
	end

	pending.seconds = pending.seconds - 1
	if pending.seconds <= 0 then return applyPending(pending.reason) end
	ns.Fire("FSG_PENDING", pending)
end

local function samePending(values, quiet)
	if not pending or pending.quiet ~= quiet then return false end
	for cvar, value in pairs(values) do if pending.values[cvar] ~= value then return false end end
	for cvar in pairs(pending.values) do if values[cvar] == nil then return false end end
	return true
end

-- quiet: no countdown and no per-second message; it lands at the next loading screen or after QUIET_WAIT.
local function queue(values, reason, quiet)
	if not next(values) then return clearPending() end
	quiet = quiet or nil
	if samePending(values, quiet) then return end

	if quiet then
		stopTicker()
		if not quietAt then
			quietAt = GetTime() + QUIET_WAIT
			C_Timer.After(QUIET_WAIT, quietDue)
		end
	else
		quietAt = nil
		if not ticker then ticker = C_Timer.NewTicker(1, tick) end
	end
	pending = { values = values, seconds = quiet and quietSeconds() or COUNTDOWN, waitingCombat = ns.InCombat(), reason = reason, quiet = quiet }
	ns.Fire("FSG_PENDING", pending)
end

-- A hidden cvar is written only when a profile, Default or Smart sets it; otherwise the quality presets' own
-- engine values stay (forcing the original would undo every preset change).
local function wanted(entry, target, effective, profileId)
	local cvar = entry.cvar
	if entry.group ~= "hidden" then return ns.Catalog.Clamp(cvar, target[cvar]) end
	-- db.overridden: hidden cvars a profile wrote (kept across sessions); once none wants them they go back to the original.
	local overridden = ns.db.overridden
	if ns.Profiles.Sets(profileId, cvar) or not same(target[cvar], effective[cvar]) then
		overridden[cvar] = true
		return ns.Catalog.Clamp(cvar, target[cvar])
	end
	if overridden[cvar] then
		overridden[cvar] = nil
		return ns.Catalog.Clamp(cvar, ns.db.original[cvar])
	end
end

-- Re-arms itself when the deadline moved; in combat FSG_COMBAT_END picks it up.
function quietDue()
	if not quietAt then return end
	local wait = quietAt - GetTime()
	if wait > 0.01 then return C_Timer.After(wait, quietDue) end
	if ns.InCombat() then return end

	Apply.Refresh("heavy", true)
end

-- opts.user: the player did it (a profile edit, a preset, /fsg use, a hold, switching on), so it writes even in combat
-- and heavy settings land at once.
function Apply.Refresh(reason, loading, opts)
	if not (ns.db and ns.db.options.switching) then return end

	local user = opts and opts.user
	loading = loading or user or GetTime() - enteredAt < LOADING_WINDOW
	local db = ns.db
	local loc = ns.Location.Current()
	local profileId = ns.Location.ProfileFor(loc)
	local target, effective = Apply.Target(), ns.Profiles.Effective(profileId)
	local heavy, written, waiting = {}, 0, 0
	local why = readable(reason)
	refreshing = true
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		local value = not db.unsupported[cvar] and wanted(entry, target, effective, profileId)
		-- Read right before the write: an earlier preset write may have changed this cvar.
		local current = ns.Get(cvar)
		-- Only the player's own value wants it: leave it as the game has it, even outside the Catalog range.
		local own = ns.Profiles.Sets(profileId, cvar) or not same(target[cvar], effective[cvar])
		if not own and ns.Catalog.Same(cvar, current, db.original[cvar]) then value = nil end
		if value and not ns.Catalog.Same(cvar, current, value) then
			if entry.heavy and not loading then
				heavy[cvar], waiting = value, waiting + 1
			else
				local shaped = smartOn() and not ns.Catalog.Same(cvar, value, effective[cvar])
				Apply.Write(cvar, value, shaped and smartReason(loc.key) or why, opts)
				written = written + 1
			end
		end
	end

	local wantTarget = smartOn() and 0 or tonumber(db.original[TARGET_FPS])
	if wantTarget and not ns.Catalog.Same(TARGET_FPS, ns.Get(TARGET_FPS), wantTarget) then Apply.Write(TARGET_FPS, wantTarget, why, opts) end
	refreshing = false

	queue(heavy, why, not db.options.announce)
	ns.debug("refresh %s: %d written, %d heavy waiting", tostring(reason), written, waiting)
end

-- Before switching off: Smart mode first (its write-back still refreshes), then nothing waits: no heavy change and
-- nothing held for combat end.
local function quiesce()
	if smartOn() then ns.Smart.SetEnabled(false) end
	clearPending()
	held, heldByRefresh = {}, {}
end

function Apply.SetSwitching(on)
	on = not not on
	if ns.db.options.switching == on then return end

	if not on then quiesce() end
	ns.db.options.switching = on
	ns.Fire("FSG_SWITCHING", on)
	if on then Apply.Refresh("switching", nil, USER) end
end

-- Ends with switching off, whatever Find my best settings or Smart mode did on the way.
function Apply.RestoreOriginal()
	local db, Calibrate = ns.db, ns.Calibrate
	if Calibrate and Calibrate.State and Calibrate.State().running then Calibrate.Stop({ keepOff = true }) end
	if ns.Smart and ns.Smart.CancelAdjust then ns.Smart.CancelAdjust() end
	quiesce()
	db.smart.enabled = false
	db.held = nil

	local original, why = db.original, "Restore original"
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		local value = tonumber(original[cvar])
		if value and not ns.Catalog.Same(cvar, ns.Get(cvar), value) then Apply.Write(cvar, value, why, USER) end
	end
	local target = tonumber(original[TARGET_FPS])
	if target then Apply.Write(TARGET_FPS, target, why, USER) end
	for _, cvar in ipairs(FPS_CAP) do
		local value = tonumber(original[cvar])
		if value and not ns.Catalog.Same(cvar, ns.Get(cvar), value) then Apply.Write(cvar, value, why, USER) end
	end
	db.overridden = {}
	db.options.switching = false
	ns.Fire("FSG_SWITCHING", false)
end

local function refreshAfterLoading() Apply.Refresh("loading", true) end

ns.On("FSG_LOCATION", function(_, _, loading) Apply.Refresh("location", loading) end)
-- Profiles change only by the player's hand (the window, /fsg use, Find my best settings' Finish).
ns.On("FSG_PROFILES_CHANGED", function() Apply.Refresh("profiles", nil, USER) end)
-- After Location's debounce, so the new place is known; a same-place loading screen still writes waiting heavy ones.
ns.On("PLAYER_ENTERING_WORLD", function()
	enteredAt = GetTime()
	C_Timer.After(AFTER_LOADING, refreshAfterLoading)
end)
ns.On("FSG_COMBAT_START", function()
	if not pending or pending.quiet then return end
	pending.waitingCombat = true
	ns.Fire("FSG_PENDING", pending)
end)
-- What a refresh held is decided again by one fresh refresh; only Smart's and Find my best settings' own values are
-- written as held.
ns.On("FSG_COMBAT_END", function()
	local any = next(held)
	for cvar in pairs(heldByRefresh) do held[cvar] = nil end
	heldByRefresh = {}
	flushHeld()
	if any then Apply.Refresh(AFTER_COMBAT) end
	if quietAt and GetTime() >= quietAt then Apply.Refresh("heavy", true) end
	if not pending or pending.quiet then return end
	pending.waitingCombat, pending.seconds = false, COUNTDOWN
	ns.Fire("FSG_PENDING", pending)
end)
ns.On("FSG_SMART", function()
	local on = smartOn()
	if on == smartWasOn then return end
	smartWasOn = on
	Apply.Refresh("smart")
end)
ns.On("FSG_READY", function() smartWasOn = smartOn() end)

-- A change made outside the addon (the game's own Options) is the player's new value for anything no profile and no
-- Smart mode decides, so the next refresh keeps it instead of putting the old one back.
local function outsideCvar(name)
	local entry = ns.Catalog.Get(name)
	if entry then return entry.cvar end
	for _, cvar in ipairs(ns.EXTRA_CVARS) do if cvar:lower() == name:lower() then return cvar end end
end

ns.On("CVAR_UPDATE", function(name)
	if writing or not ns.db or type(name) ~= "string" then return end
	ns.debug("cvar %s changed outside the addon", name)
	local cvar = outsideCvar(name)
	local value = cvar and not smartOn() and not ns.Profiles.Sets(ns.Location.ProfileFor(), cvar) and ns.Get(cvar)
	if value then ns.db.original[cvar] = value end
end)

local function fps()
	local ok, value = pcall(GetFramerate)
	value = ok and tonumber(ns.plain(value))
	return value and string.format("%.0f", value) or "?"
end

local OFF = "is turned off; turn it on in /fsg"
local SOURCE_WORDS = { place = "set for this place", type = "set for this kind of place", default = "Default", held = "held" }

function ns.commands.status()
	local active = Apply.Active()
	local loc = active.loc
	local smart = ns.Smart and ns.Smart.Enabled() and ns.Smart.State().status or "off"
	local switching = ns.db.options.switching and "" or " (turned off)"
	local source = SOURCE_WORDS[active.source] or active.source
	ns.log(string.format("%s · %s: %s (%s)%s · smart %s · %s fps", tostring(loc.name), ns.Location.LABELS[loc.key], active.profileName, source, switching, smart, fps()))
	local info = Apply.Pending()
	if not info then return end
	local when = info.waitingCombat and not info.quiet and " for combat to end" or " " .. info.seconds .. " s (/fsg applynow applies it)"
	ns.log("texture change waiting" .. when)
end

function ns.commands.use(args)
	local name = table.concat(args, " ")
	if name == "" then return ns.log("Usage: /fsg use <profile name>") end
	local id = ns.Profiles.FindByName(name)
	if not id then return ns.log("no profile named \"" .. name .. "\"") end

	ns.Profiles.AssignAll(id)
	local off = not ns.db.options.switching and " (Smart Graphics is turned off, so nothing changes until you turn it on)" or ""
	ns.log(ns.Profiles.Get(id).name .. " is now used everywhere" .. off)
end

local NONE_HELD = "no profile is held"

-- /fsg profile <name> | auto | toggle <name>, or alone to report. A profile's full name wins over the toggle form;
-- auto is the keyword only as the whole argument.
function ns.commands.profile(args)
	local Profiles = ns.Profiles
	local held, name = Profiles.Held(), table.concat(args, " ")
	if name == "" then return ns.log(held and "holding " .. Profiles.Get(held).name or NONE_HELD) end
	if not ns.db.options.switching then return ns.log(OFF) end

	local id = Profiles.FindByName(name)
	local release = not id and name:lower() == "auto"
	if not id and not release then
		if (args[1] or ""):lower() ~= "toggle" then return ns.log("no profile named \"" .. name .. "\"") end
		local rest = table.concat(args, " ", 2)
		if rest == "" then return ns.log("Usage: /fsg profile toggle <profile name>") end
		id = Profiles.FindByName(rest)
		if not id then return ns.log("no profile named \"" .. rest .. "\"") end
		release = id == held
	end
	if release then
		if not held then return ns.log(NONE_HELD) end
		Profiles.Hold(nil)
		return ns.log("back to switching by location")
	end

	Profiles.Hold(id)
	ns.log("holding " .. Profiles.Get(id).name .. " everywhere (/fsg profile auto goes back)")
end

function ns.commands.restore()
	Apply.RestoreOriginal()
	ns.log("put your original settings back and " .. OFF)
end

function ns.commands.applynow()
	if not Apply.ApplyPending() then ns.log("nothing is waiting") end
end
