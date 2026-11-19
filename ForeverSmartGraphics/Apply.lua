-- Applies the wanted profile for the current location. The addon's only C_CVar.SetCVar call is in Apply.Write.
-- Order: the quality presets first (each rewrites engine cvars), then render, then hidden overrides.
-- Heavy settings (texture reloads, 0.4–0.7 s stutter) wait: written at a loading screen, or after a 10 s countdown
-- the toast shows (paused in combat), or at once with Apply now.
local _, ns = ...
local Apply = {}
ns.Apply = Apply

local TARGET_FPS = "useTargetFPS"
-- The player's frame cap: never written automatically, only put back by RestoreOriginal (and once by the goal/pace
-- migration in Core after the old Efficient style).
local FPS_CAP = { "maxFPS", "useMaxFPS" }
local COUNTDOWN, LOADING_WINDOW, AFTER_LOADING = 10, 3, 0.5
-- Announce off: a heavy change waits for a loading screen, but never longer than this (out of combat), then lands quietly.
local QUIET_WAIT = 600
local quietAt
local MISSES_UNSUPPORTED = 2
local TOLERANCE = 1e-3
local RENDER_SCALE, RENDER_LIMIT_FLOOR = "RenderScale", 0.5

local misses = {}
-- Nothing changes in combat unless the player asks: automatic writes wait here (latest value wins) until combat ends.
local held = {}
local USER = { user = true }
local AFTER_COMBAT = "after combat"
-- Hidden cvars this session wrote from a profile; once no profile wants them they go back to the original value.
local overridden = {}
local writing = false
local enteredAt = -math.huge
local pending, ticker
local smartWasOn

-- Chat log of real changes: every write in one go (a profile switch, a Smart step) becomes one line, sent next frame,
-- and one FSG_CHANGES({ reason, source, changes = { { cvar, label, from, to }, ... } }) whether or not it prints.
local LINE_MAX = 250
local DEFAULT_REASON = "smart mode"
local REASONS = { smart = "smart mode", loading = "loading screen" }
local SOURCES = { ["Find my best settings"] = "calibrate", ["Smart adjust"] = "adjust", ["Restore original"] = "restore", ["Apply now"] = "apply" }
-- Smart's own steps are frequent: chat shows them only with options.chatLogSmart; FSG_CHANGES always carries them.
local QUIET = { smart = true, calibrate = true, adjust = true }
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
-- The chat log's reason for a value Smart.Adjust shaped: "smart mode (Fidelity)", plus a note when it is the value
-- Smart learned for this place.
local function smartReason(locKey, cvar, value)
	local Smart, name = ns.Smart, nil
	local key = Smart and Smart.Goal and Smart.Goal(locKey)
	for _, goal in ipairs(Smart and Smart.GOALS or {}) do
		if goal.key == key then name = goal.name end
	end
	local learned = ns.db.smart.learned[locKey]
	local mine = learned and learned.values and ns.Catalog.Same(cvar, learned.values[cvar], value)
	return "smart mode" .. (name and " (" .. name .. ")" or "") .. (mine and ", learned for this place" or "")
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
		held[cvar] = value
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
	if ok then return true, readback end

	-- Moved, but a full step short of the value asked: the client clamped it, so that is this machine's limit.
	local entry = ns.Catalog.Get(cvar)
	if entry and readback and not same(readback, before) then
		if clamped(entry, value, readback) then
			local db = ns.db
			db.limits[entry.cvar], db.limitSides[entry.cvar] = readback, readback < value and "max" or "min"
			ns.Fire("FSG_LIMIT", entry.cvar, readback)
		end
		return false, readback
	end

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

function Apply.Pending() return pending end

local quietDue

local function stopTicker()
	if ticker then ticker:Cancel() end
	ticker = nil
end

local function writeOrdered(values, reason, opts)
	for _, entry in ipairs(ns.Catalog.LIST) do
		local value = values[entry.cvar]
		if value ~= nil then Apply.Write(entry.cvar, value, reason, opts) end
	end
end

function Apply.CombatHeld()
	if not next(held) then return nil end
	local out = {}
	for cvar, value in pairs(held) do out[cvar] = value end
	return out
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

-- reason: "Apply now" by default; the countdown passes the reason the change was queued with.
function Apply.ApplyPending(reason)
	if not pending then return false end

	reason = reason or "Apply now"
	local values = pending.values
	pending = nil
	stopTicker()
	-- A user action (Apply now) except at the countdown's end, which never runs in combat (tick waits).
	writeOrdered(values, reason, USER)
	ns.Fire("FSG_PENDING", nil)
	return true
end

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
	if pending.seconds <= 0 then return Apply.ApplyPending(pending.reason) end
	ns.Fire("FSG_PENDING", pending)
end

local function samePending(values)
	if not pending then return false end
	for cvar, value in pairs(values) do if pending.values[cvar] ~= value then return false end end
	for cvar in pairs(pending.values) do if values[cvar] == nil then return false end end
	return true
end

local function queue(values, reason)
	if not next(values) then
		if not pending then return end
		pending = nil
		stopTicker()
		return ns.Fire("FSG_PENDING", nil)
	end
	if samePending(values) then return end

	pending = { values = values, seconds = COUNTDOWN, waitingCombat = ns.InCombat(), reason = reason }
	if not ticker then ticker = C_Timer.NewTicker(1, tick) end
	ns.Fire("FSG_PENDING", pending)
end

-- A hidden cvar is written only when a profile, Default or Smart sets it; otherwise the quality presets' own
-- engine values stay (forcing the original would undo every preset change).
local function wanted(entry, target, effective, profileId)
	local cvar = entry.cvar
	if entry.group ~= "hidden" then return ns.Catalog.Clamp(cvar, target[cvar]) end
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

-- opts.user: the player changed something (a profile edit, switching on), so it writes even in combat.
function Apply.Refresh(reason, loading, opts)
	if not (ns.db and ns.db.options.switching) then return end

	loading = loading or GetTime() - enteredAt < LOADING_WINDOW
	local db = ns.db
	local loc = ns.Location.Current()
	local profileId = ns.Location.ProfileFor(loc)
	local target, effective = Apply.Target(), ns.Profiles.Effective(profileId)
	local heavy, written, waiting = {}, 0, 0
	local why = readable(reason)
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		local value = not db.unsupported[cvar] and wanted(entry, target, effective, profileId)
		-- Read right before the write: an earlier preset write may have changed this cvar.
		if value and not ns.Catalog.Same(cvar, ns.Get(cvar), value) then
			if entry.heavy and not loading then
				heavy[cvar], waiting = value, waiting + 1
			else
				local shaped = smartOn() and not ns.Catalog.Same(cvar, value, effective[cvar])
				Apply.Write(cvar, value, shaped and smartReason(loc.key, cvar, value) or why, opts)
				written = written + 1
			end
		end
	end

	local wantTarget = smartOn() and 0 or tonumber(db.original[TARGET_FPS])
	if wantTarget and not ns.Catalog.Same(TARGET_FPS, ns.Get(TARGET_FPS), wantTarget) then Apply.Write(TARGET_FPS, wantTarget, why, opts) end

	-- Announce off: heavy changes wait silently for the next loading screen (or QUIET_WAIT).
	if db.options.announce then queue(heavy, why) elseif pending then queue({}) end
	if waiting == 0 or db.options.announce then
		quietAt = nil
	elseif not quietAt then
		quietAt = GetTime() + QUIET_WAIT
		C_Timer.After(QUIET_WAIT, quietDue)
	end
	ns.debug("refresh %s: %d written, %d heavy waiting", tostring(reason), written, waiting)
end

function Apply.SetSwitching(on)
	on = not not on
	if ns.db.options.switching == on then return end

	ns.db.options.switching = on
	ns.Fire("FSG_SWITCHING", on)
	if on then Apply.Refresh("switching", nil, USER) end
end

function Apply.RestoreOriginal()
	local db = ns.db
	db.options.switching = false
	if ns.Smart and ns.Smart.CancelAdjust then ns.Smart.CancelAdjust() end
	if ns.Smart then ns.Smart.SetEnabled(false) end
	db.smart.enabled = false
	db.held = nil
	if pending then queue({}) end
	held = {}

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
	for cvar in pairs(overridden) do overridden[cvar] = nil end
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
	if not pending then return end
	pending.waitingCombat = true
	ns.Fire("FSG_PENDING", pending)
end)
ns.On("FSG_COMBAT_END", function()
	if next(held) then
		flushHeld()
		Apply.Refresh(AFTER_COMBAT)
	end
	if quietAt and GetTime() >= quietAt then Apply.Refresh("heavy", true) end
	if not pending then return end
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
ns.On("CVAR_UPDATE", function(name)
	if writing then return end
	ns.debug("cvar %s changed outside the addon", tostring(name))
end)

local function fps()
	local ok, value = pcall(GetFramerate)
	value = ok and tonumber(ns.plain(value))
	return value and string.format("%.0f", value) or "?"
end

function ns.commands.status()
	local active = Apply.Active()
	local loc = active.loc
	local smart = ns.Smart and ns.Smart.Enabled() and ns.Smart.State().status or "off"
	local switching = ns.db.options.switching and "" or " (switching off)"
	ns.log(string.format("%s · %s: %s (%s)%s · smart %s · %s fps", tostring(loc.name), ns.Location.LABELS[loc.key], active.profileName, active.source, switching, smart, fps()))
	if pending then ns.log(string.format("texture change waiting%s", pending.waitingCombat and " for combat to end" or " " .. pending.seconds .. " s")) end
end

function ns.commands.use(args)
	local name = table.concat(args, " ")
	local id = ns.Profiles.FindByName(name)
	if not id then return ns.log("no profile named \"" .. name .. "\"") end

	-- "Everywhere, for good": a hold would hide it.
	ns.db.held = nil
	ns.Profiles.AssignAll(id)
	ns.log(ns.Profiles.Get(id).name .. " is now used everywhere")
end

local NONE_HELD = "no profile is held"

-- /fsg profile <name> | auto | toggle <name>, or alone to report. auto and toggle are reserved first words.
function ns.commands.profile(args)
	local Profiles, first = ns.Profiles, (args[1] or ""):lower()
	local held = Profiles.Held()
	if #args == 0 then return ns.log(held and "holding " .. Profiles.Get(held).name or NONE_HELD) end
	if not ns.db.options.switching then return ns.log("Smart Graphics is off; turn it on in /fsg") end

	local release = first == "auto"
	local id
	if not release then
		local name = table.concat(args, " ", first == "toggle" and 2 or 1)
		id = Profiles.FindByName(name)
		if not id then return ns.log("no profile named \"" .. name .. "\"") end
		release = first == "toggle" and id == held
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
	ns.log("your original settings are back; switching by location is off (turn it on in /fsg)")
end

function ns.commands.applynow()
	if not Apply.ApplyPending() then ns.log("nothing is waiting") end
end
