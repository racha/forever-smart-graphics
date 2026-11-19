-- Forever Smart Graphics core: namespace, SavedVariables, events and messages, logging, /fsg.
-- Adapted from Forever Controller Tweaks' Core.lua (MIT, same author).
--   ns.db                  ForeverSmartGraphicsDB, ready from ADDON_LOADED on (FSG_READY fires then).
--   ns.On(event, fn)       fn(...) on a WoW event or an internal message (any name starting FSG_). FSG_READY
--                          registered once ns.db is ready runs fn at once.
--   ns.Fire(msg, ...)      sends an internal message; a failing listener is reported once per session.
--   ns.log(msg) / ns.debug(fmt, ...) / ns.plain(v) / ns.InCombat() / ns.Get(cvar) / ns.OnBlocked(event, addon, func)
--   ns.commands[name] = fn(args)
-- FSG_COMBAT_START fires synchronously first thing in PLAYER_REGEN_DISABLED, FSG_COMBAT_END in PLAYER_REGEN_ENABLED.
local addonName, ns = ...
ForeverSmartGraphics = ns

local VERSION, DEBUG_CAP = 1, 500
local PREFIX = "|cff66ccffSmart Graphics|r "
local NONE = {}

ns.VERSION = VERSION
ns.commands = {}

local handlers, run = {}, nil
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...) ns.Fire(event, ...) end)

-- Registering an event the client doesn't have throws and would stop the file loading.
local function validEvent(event)
	local check = C_EventUtils and C_EventUtils.IsEventValid
	return not check or check(event)
end

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if not event:find("^FSG_") and validEvent(event) then eventFrame:RegisterEvent(event) end
	end
	local list = handlers[event]
	list[#list + 1] = fn
	if event == "FSG_READY" and ns.db then run(event, fn) end
end

function ns.log(msg) print(PREFIX .. msg) end

local errorTold = {}

function run(msg, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return end

	ns.debug("%s listener error: %s", msg, tostring(err))
	if not errorTold[fn] then ns.log("an error in " .. msg .. " was skipped — please /reload and report: " .. tostring(err)) end
	errorTold[fn] = true
end

function ns.Fire(msg, ...)
	for _, fn in ipairs(handlers[msg] or NONE) do run(msg, fn, ...) end
end

function ns.plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

function ns.InCombat()
	local ok, combat = pcall(UnitAffectingCombat, "player")
	return InCombatLockdown() or (ok and ns.plain(combat) and true) or false
end

function ns.Get(cvar)
	if not (C_CVar and C_CVar.GetCVar) then return nil end
	local ok, value = pcall(C_CVar.GetCVar, cvar)
	if ok then return ns.plain(value) end
end

-- A ring of DEBUG_CAP lines: once full, debugAt is the newest line's index. Put back in order at logout.
local debugAt, lastDebug = 0, nil

function ns.debug(fmt, ...)
	local db = ns.db
	if not (db and db.options.debug) then return end

	local log = db.debugLog
	lastDebug = date("%H:%M:%S ") .. string.format(fmt, ...)
	if #log < DEBUG_CAP then
		log[#log + 1] = lastDebug
		return
	end
	debugAt = debugAt % DEBUG_CAP + 1
	log[debugAt] = lastDebug
end

local function unroll(log)
	if debugAt == 0 or #log < DEBUG_CAP then return log end
	local out = {}
	for i = 1, #log do out[i] = log[(debugAt + i - 1) % #log + 1] end
	return out
end

local blockedTold

function ns.OnBlocked(event, addon, func)
	ns.debug("%s addon=%s func=%s combat=%s", tostring(event), tostring(addon), tostring(func), tostring(InCombatLockdown()))
	if addon ~= addonName or blockedTold then return end

	blockedTold = true
	ns.log("Blizzard blocked " .. tostring(func) .. " — please /reload and report")
end

-- Replaced by Panel.lua; the compartment globals too.
function ns.TogglePanel() ns.log("window not loaded") end

-- Replaced by Panel/WhatsNew.lua.
function ns.ShowWhatsNew() ns.log("window not loaded") end

function ForeverSmartGraphics_OnCompartmentClick() ns.TogglePanel() end
function ForeverSmartGraphics_OnCompartmentEnter() end
function ForeverSmartGraphics_OnCompartmentLeave() end

ns.On("PLAYER_REGEN_DISABLED", function() ns.Fire("FSG_COMBAT_START") end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.Fire("FSG_COMBAT_END") end)
ns.On("ADDON_ACTION_BLOCKED", function(addon, func) ns.OnBlocked("ADDON_ACTION_BLOCKED", addon, func) end)
ns.On("ADDON_ACTION_FORBIDDEN", function(addon, func) ns.OnBlocked("ADDON_ACTION_FORBIDDEN", addon, func) end)

-- Migrations keyed by the version they upgrade to; each runs once, on a repaired db.
local MIGRATIONS = {}
local OLD_FLOOR = 0.6

local function asTable(value) return type(value) == "table" and value or {} end
-- value - value is NaN for NaN and for an infinity.
local function finite(value) return type(value) == "number" and value - value == 0 end
local function bool(value, default) if type(value) == "boolean" then return value end return default end
local function within(value, min, max, default) return finite(value) and value >= min and value <= max and value or default end

ns.SMART_TARGET, ns.SMART_FLOOR = { 20, 240, 60 }, { 0.33, 1.0, 0.75 }
local LOCATION_KEYS = { "city", "outdoor", "dungeon", "raid", "battleground", "arena" }
local OVERRIDE_PATTERNS = { "^map:%d+$", "^instance:%d+$" }
-- Not in the Catalog (never in a profile or preset) but written by Apply or Smart's Efficient mode, so restorable.
local EXTRA_CVARS = { "useTargetFPS", "maxFPS", "useMaxFPS" }
local GOALS = { fps = true, balanced = true, fidelity = true }
local PACES = { aggressive = true, balanced = true, smooth = true }
local DEFAULT_GOAL, DEFAULT_PACE = "balanced", "balanced"
-- The five old styles as goal + pace ("quality" was Fidelity's first name).
local OLD_MODES = {
	balanced = { "balanced", "balanced" }, smooth = { "balanced", "smooth" }, performance = { "fps", "aggressive" },
	fidelity = { "fidelity", "balanced" }, quality = { "fidelity", "balanced" }, efficient = { "balanced", "balanced" },
}
local FRAME_CAP = { "maxFPS", "useMaxFPS" }
local NOTIFICATIONS = { "announce", "suggest", "smartNotice", "notifyProfile", "chatLog", "chatLogSmart" }
local restoreFrameCap = false

local function overrideKey(key)
	if type(key) ~= "string" then return false end
	for _, pattern in ipairs(OVERRIDE_PATTERNS) do
		if key:find(pattern) then return true end
	end
	return false
end

-- Keeps known cvars on their Catalog grid; drops the rest.
local function repairValues(values, path, fix)
	local out = {}
	for cvar, value in pairs(asTable(values)) do
		local clamped = type(cvar) == "string" and ns.Catalog.Clamp(cvar, tonumber(value))
		local entry = clamped and ns.Catalog.Get(cvar)
		if entry then out[entry.cvar] = clamped end
		if clamped ~= value then fix(path .. "." .. tostring(cvar)) end
	end
	return out
end

local function repairProfiles(db, fix)
	local profiles = {}
	for id, profile in pairs(db.profiles) do
		if type(id) ~= "string" or type(profile) ~= "table" then
			fix("profiles." .. tostring(id))
		else
			local name = type(profile.name) == "string" and profile.name:match("^%s*(.-)%s*$") or ""
			if name == "" then name = id == "default" and "Default" or id end
			profiles[id] = { id = id, name = name:sub(1, 32), values = repairValues(profile.values, "profiles." .. id, fix) }
		end
	end
	if not profiles.default then fix("profiles.default") end
	profiles.default = profiles.default or { id = "default", name = "Default", values = {} }
	profiles.default.name = "Default"
	db.profiles = profiles

	local order, seen = { "default" }, { default = true }
	for _, id in ipairs(asTable(db.profileOrder)) do
		if profiles[id] and not seen[id] then order[#order + 1], seen[id] = id, true end
	end
	local rest = {}
	for id in pairs(profiles) do if not seen[id] then rest[#rest + 1] = id end end
	table.sort(rest)
	for _, id in ipairs(rest) do order[#order + 1] = id end
	db.profileOrder = order

	-- nextId stays above every "pN" id so Create never reuses one.
	local nextId = finite(db.nextId) and db.nextId >= 1 and math.floor(db.nextId) or 1
	for id in pairs(profiles) do
		local n = tonumber(id:match("^p(%d+)$"))
		if n and n >= nextId then nextId = n + 1 end
	end
	db.nextId = nextId
end

local function repairMappings(db, fix)
	local locations, profiles = {}, db.profiles
	for _, key in ipairs(LOCATION_KEYS) do
		local id = asTable(db.locations)[key]
		if profiles[id] and id ~= "default" then locations[key] = id end
		if id ~= nil and locations[key] == nil and id ~= "default" then fix("locations." .. key) end
	end
	db.locations = locations

	local overrides = {}
	for key, entry in pairs(asTable(db.overrides)) do
		if overrideKey(key) and type(entry) == "table" and profiles[entry.profile] then
			overrides[key] = { profile = entry.profile, name = type(entry.name) == "string" and entry.name or key }
		else
			fix("overrides." .. tostring(key))
		end
	end
	db.overrides = overrides

	if db.held ~= nil and not (type(db.held) == "string" and profiles[db.held]) then
		fix("held")
		db.held = nil
	end
end

local function repairLearned(learned, fix)
	local out = {}
	for key, entry in pairs(asTable(learned)) do
		if type(key) ~= "string" or type(entry) ~= "table" then
			fix("smart.learned." .. tostring(key))
		else
			local path, gains = "smart.learned." .. key, {}
			for cvar, gain in pairs(asTable(entry.gains)) do
				local known = type(cvar) == "string" and ns.Catalog.Get(cvar)
				if known and type(gain) == "table" and finite(gain.ema) and finite(gain.n) and gain.n >= 0 then
					gains[known.cvar] = { ema = gain.ema, n = math.floor(gain.n) }
				else
					fix(path .. ".gains." .. tostring(cvar))
				end
			end
			out[key] = { values = repairValues(entry.values, path, fix), gains = gains, t = finite(entry.t) and entry.t or 0 }
		end
	end
	return out
end

local function repairSmart(db, fix)
	local smart = asTable(db.smart)
	local target, floor = ns.SMART_TARGET, ns.SMART_FLOOR
	smart.enabled = bool(smart.enabled, false)
	smart.target = within(smart.target, target[1], target[2], target[3])
	smart.scaleFloor = within(smart.scaleFloor, floor[1], floor[2], floor[3])
	smart.learned = repairLearned(smart.learned, fix)
	-- Once: the old style (and per-place styles) become goal + pace. Efficient's frame cap goes back to the original.
	if not db.migrations.goalPace then
		local old, goals = OLD_MODES[smart.mode], asTable(smart.goals)
		if old and smart.goal == nil then smart.goal, smart.pace = old[1], smart.pace or old[2] end
		restoreFrameCap = smart.mode == "efficient"
		for key, mode in pairs(asTable(smart.modes)) do
			if OLD_MODES[mode] and goals[key] == nil then goals[key] = OLD_MODES[mode][1] end
			if mode == "efficient" then restoreFrameCap = true end
		end
		smart.goals, smart.mode, smart.modes = goals, nil, nil
		db.migrations.goalPace = true
	end
	if smart.goal ~= nil and not GOALS[smart.goal] then fix("smart.goal") end
	smart.goal = GOALS[smart.goal] and smart.goal or DEFAULT_GOAL
	if smart.pace ~= nil and not PACES[smart.pace] then fix("smart.pace") end
	smart.pace = PACES[smart.pace] and smart.pace or DEFAULT_PACE
	if smart.goals ~= nil and type(smart.goals) ~= "table" then fix("smart.goals") end
	local goals, known = {}, {}
	for _, key in ipairs(LOCATION_KEYS) do known[key] = true end
	for key, goal in pairs(asTable(smart.goals)) do
		if known[key] and GOALS[goal] then goals[key] = goal else fix("smart.goals." .. tostring(key)) end
	end
	smart.goals = goals
	local ceiling = smart.ceiling
	local validCeiling = type(ceiling) == "table" and finite(ceiling.fps) and ceiling.fps > 0 and finite(ceiling.t)
	if ceiling ~= nil and not validCeiling then fix("smart.ceiling") end
	smart.ceiling = validCeiling and { fps = ceiling.fps, t = ceiling.t } or nil
	-- Smart's own stores: only their shape is repaired here.
	for _, key in ipairs({ "areas", "gains" }) do
		if smart[key] ~= nil and type(smart[key]) ~= "table" then fix("smart." .. key) end
		local kept = {}
		for k, v in pairs(asTable(smart[key])) do
			if type(v) == "table" then kept[k] = v else fix("smart." .. key .. "." .. tostring(k)) end
		end
		smart[key] = kept
	end
	db.smart = smart
end

-- Captured once at the first load; a cvar the Catalog gains later is added, an existing value is never rewritten.
local function captureOriginal(db)
	local original = {}
	for cvar, value in pairs(asTable(db.original)) do
		if type(cvar) == "string" and type(value) == "string" then original[cvar] = value end
	end
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		original[cvar] = original[cvar] or ns.Get(cvar)
	end
	for _, cvar in ipairs(EXTRA_CVARS) do original[cvar] = original[cvar] or ns.Get(cvar) end
	db.original = original
end

-- A first install starts at the running version and sees nothing. Data saved before What's new existed has no
-- news key: it starts at the last release without the window, so the player sees this version's notes once.
-- A dev build has no version to store and leaves db.news alone.
local NEWS_BASELINE = "1.0.0-beta.2"
local function repairNews(db, fresh, fix)
	local running = ns.News and ns.News.Running()
	if not running then return end
	local news = db.news
	if news ~= nil and type(news) ~= "table" then fix("news") end
	news = asTable(news)
	if news.seen ~= nil and type(news.seen) ~= "string" then fix("news.seen") end
	if news.never ~= nil and news.never ~= true then fix("news.never") end
	local seen = type(news.seen) == "string" and news.seen or (fresh and running or NEWS_BASELINE)
	db.news = { seen = seen, never = news.never == true or nil }
end

-- Repairs whatever the SavedVariables hold into the current shape; other top-level keys stay untouched.
local function loadDB()
	local db = asTable(ForeverSmartGraphicsDB)
	local fresh = next(db) == nil
	local version = db.version
	if type(version) ~= "number" or version < 1 or version % 1 ~= 0 then db.version = fresh and VERSION or 1 end

	local fixes = {}
	local function fix(what) fixes[#fixes + 1] = what end
	for _, key in ipairs({ "options", "profiles", "locations", "overrides", "smart", "unsupported", "limits", "limitSides", "debugLog", "migrations" }) do
		if db[key] ~= nil and type(db[key]) ~= "table" then fix(key) end
		db[key] = asTable(db[key])
	end

	local options = db.options
	options.switching = bool(options.switching, true)
	options.debug = options.debug == true
	-- Every notification is off until the player turns it on. Once: saved data from before this rule goes quiet too
	-- (pre-release, so nobody chose these yet).
	for _, key in ipairs(NOTIFICATIONS) do
		if not db.migrations.quietDefaults then options[key] = false end
		options[key] = bool(options[key], false)
	end
	db.migrations.quietDefaults = true
	-- The minimap FPS box pulsing on a change: the one quiet signal, on by default.
	options.fpsPulse = bool(options.fpsPulse, true)
	local minimap = asTable(options.minimap)
	options.minimap = { shown = bool(minimap.shown, true), angle = finite(minimap.angle) and minimap.angle % 360 or 200 }
	local pos = options.calibratePos
	local validPos = type(pos) == "table" and type(pos.point) == "string" and finite(pos.x) and finite(pos.y)
	if pos ~= nil and not validPos then fix("options.calibratePos") end
	options.calibratePos = validPos and { point = pos.point, x = pos.x, y = pos.y } or nil

	local log, kept = db.debugLog, {}
	for i = math.max(1, #log - DEBUG_CAP + 1), #log do if type(log[i]) == "string" then kept[#kept + 1] = log[i] end end
	db.debugLog = kept

	local unsupported = {}
	for cvar, on in pairs(db.unsupported) do
		local entry = on == true and type(cvar) == "string" and ns.Catalog.Get(cvar)
		if entry then unsupported[entry.cvar] = true else fix("unsupported." .. tostring(cvar)) end
	end
	db.unsupported = unsupported

	-- Before any Clamp below: the limits cap profile values.
	local limits, sides = {}, {}
	for cvar, limit in pairs(db.limits) do
		local entry = type(cvar) == "string" and finite(limit) and ns.Catalog.Get(cvar)
		if entry then
			limits[entry.cvar] = limit
			sides[entry.cvar] = db.limitSides[cvar] == "min" and "min" or "max"
		else
			fix("limits." .. tostring(cvar))
		end
	end
	db.limits, db.limitSides = limits, sides

	captureOriginal(db)
	repairProfiles(db, fix)
	repairMappings(db, fix)
	repairSmart(db, fix)
	repairNews(db, fresh, fix)
	-- The default floor went from 60% to 75%: move only a floor still at the old default, once, so a 60% the
	-- player picks afterwards stays.
	if not db.migrations.floor75 and math.abs(db.smart.scaleFloor - OLD_FLOOR) < 1e-6 then db.smart.scaleFloor = ns.SMART_FLOOR[3] end
	db.migrations.floor75 = true

	if db.version > VERSION then
		ns.log("these settings were saved by a newer version of Smart Graphics; some may be ignored")
	else
		for v = db.version + 1, VERSION do MIGRATIONS[v](db) end
		db.version = VERSION
	end
	ForeverSmartGraphicsDB = db
	-- A first install builds every table from nothing: that's not a repair.
	return db, fresh and {} or fixes
end

ns.On("ADDON_LOADED", function(name)
	if name ~= addonName then return end

	local db, fixes = loadDB()
	ns.db = db
	-- Not a user action: in combat Apply holds it for combat end like any other automatic write.
	if restoreFrameCap and ns.Apply then
		for _, cvar in ipairs(FRAME_CAP) do
			local value = tonumber(db.original[cvar])
			if value and tonumber(ns.Get(cvar)) ~= value then ns.Apply.Write(cvar, value, "Restore original") end
		end
	end
	restoreFrameCap = false
	for _, what in ipairs(fixes) do ns.debug("db repaired %s", what) end
	if #fixes > 0 then ns.log(string.format("repaired %d damaged saved setting%s", #fixes, #fixes == 1 and "" or "s")) end
	ns.Fire("FSG_READY")
end)

ns.On("PLAYER_LOGOUT", function()
	if not ns.db then return end
	ns.db.debugLog = unroll(ns.db.debugLog)
	debugAt = 0
end)

local HELP = "/fsg opens the window (so do the addon compartment and the minimap button). Commands: status"
	.. " | use <profile name> (that profile everywhere) | profile <name>|auto|toggle <name> (hold a profile, for macros) | restore (your original settings, switching off) | applynow (a waiting texture change)"
	.. " | smart on|off | target <fps> | floor <percent> | log on|off (settings changes in chat) | log smart on|off (Smart mode steps too) | whatsnew (what changed in this version) | debug on|off | selftest | help"

function ns.commands.help() ns.log(HELP) end

function ns.commands.whatsnew()
	local news = ns.db.news
	if news and news.never then
		news.never = nil
		ns.log("What's new is on again: it opens after each update.")
	end
	if not ns.NEWS then return ns.log("Nothing new for players in this version.") end
	ns.ShowWhatsNew()
end

function ns.commands.debug(args)
	local on = args[1] == "on"
	if not on and args[1] ~= "off" then return ns.log("debug log is " .. (ns.db.options.debug and "on" or "off")) end

	ns.db.options.debug = on
	ns.log("debug log " .. (on and "on (ForeverSmartGraphicsDB.debugLog)" or "off"))
end

-- /fsg log on|off: every change in chat; /fsg log smart on|off: Smart mode's own steps too.
function ns.commands.log(args)
	local smart = args[1] == "smart"
	local key, what, word = smart and "chatLogSmart" or "chatLog", smart and "Smart mode changes in chat" or "change log in chat", args[smart and 2 or 1]
	if word ~= "on" and word ~= "off" then return ns.log(what .. " is " .. (ns.db.options[key] and "on" or "off")) end

	ns.db.options[key] = word == "on"
	ns.log(what .. " " .. word)
end

-- Pcall'd: the reading is for a bug report, so a missing API or another file's error must not stop it.
local function safe(fn, ...)
	if type(fn) ~= "function" then return "n/a" end
	local ok, a = pcall(fn, ...)
	if not ok then return "error: " .. tostring(a) end
	return tostring(a)
end
ns.safe = safe

function ns.commands.selftest()
	ns.db.options.debug = true
	local function add(fmt, ...)
		local line = string.format(fmt, ...)
		ns.log("selftest: " .. line)
		ns.debug("selftest %s", line)
	end

	local version, build, _, interface = GetBuildInfo()
	add("build %s.%s, interface %s", tostring(version), tostring(build), tostring(interface))
	add("render scale range %s..%s, fps %s", safe(GetMinRenderScale), safe(GetMaxRenderScale), safe(GetFramerate))
	local readable, unsupported = 0, {}
	for _, entry in ipairs(ns.Catalog.LIST) do
		if ns.Get(entry.cvar) then readable = readable + 1 end
		if ns.db.unsupported[entry.cvar] then unsupported[#unsupported + 1] = entry.cvar end
	end
	add("%d of %d settings readable; unsupported: %s", readable, #ns.Catalog.LIST, #unsupported > 0 and table.concat(unsupported, ", ") or "none")
	local loc = ns.Location.Current()
	add("location %s (%s, %s), instance type %s, difficulty %s", tostring(loc.name), loc.key, loc.overrideKey, tostring(loc.instanceType), tostring(loc.difficultyID))
	local active = ns.Apply.Active()
	add("profile %s (%s), switching %s, pending %s", active.profileName, active.source, tostring(ns.db.options.switching), ns.Apply.Pending() and "yes" or "no")
	add("smart %s, window %s", ns.Smart and safe(function() return ns.Smart.State().status end) or "not loaded", ns.UI and ns.UI.Main and "loaded" or "not loaded")
	ns.log("selftest: the debug log is on (/fsg debug off to stop). For a taint check type /console taintLog 2, then /reload.")
end

SLASH_FOREVERSMARTGRAPHICS1 = "/fsg"
SlashCmdList.FOREVERSMARTGRAPHICS = function(msg)
	local args = {}
	for word in msg:gmatch("%S+") do args[#args + 1] = word end

	if not ns.db then return ns.log("not loaded yet") end

	local name = (table.remove(args, 1) or ""):lower()
	if name == "" then return ns.TogglePanel() end

	local handler = ns.commands[name] or ns.commands.help
	handler(args)
end
