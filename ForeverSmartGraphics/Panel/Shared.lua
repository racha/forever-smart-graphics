-- Forever Smart Graphics panel: pieces shared by every tab. Adapted from Forever Controller Tweaks (MIT, same
-- author).
-- Taint rule: nothing here drives Blizzard's Menu, StaticPopup, SmartNavigation or Settings, and no Blizzard callback
-- registry is written. Visual templates whose code is pure (SettingsFrameTemplate's NineSlice, flat background and
-- close button, InsetFrameTemplate, SharedButtonSmallTemplate, InputBoxTemplate) are inherited; everything else is
-- the same native art in the addon's own frames. Positions are UI units from a window's top left.
local _, ns = ...
local UI = {}
ns.UI = UI

UI.L = {
	TITLE = "Forever Smart Graphics",
	TAB_PROFILES = "Profiles",
	TAB_LOCATIONS = "Locations",
	TAB_SMART = "Smart mode",
	TAB_GENERAL = "Options",
	TAB_OVERVIEW = "Overview",
	TAB_PROFILES = "Profiles",
	SELECT = "Select",
	BACK = "Back",
	CLOSE = "Close",
	CANCEL = "Cancel",
	OK = "OK",
	MORE = "More",
	CLEAR = "Clear",
	REMOVE = "Remove",
	RESET = "Reset",
	SAVE_PROFILE = "Save as profile",
	RESUME = "Open again",
	NOT_NOW = "Not now",
	COMBAT = "Smart Graphics opens out of combat only",
	RESUME_TEXT = "Combat closed Forever Smart Graphics. Open it again?",
	STEPPER_TIP = "D-pad left and right change it.",
	CHOICE_TIP = "A opens the list; D-pad left and right pick the next one.",
	CHOICE_TIP_MOUSE = "Click to pick from the list, or use the arrows beside it.",
	SLIDER_TIP_MOUSE = "Drag the slider, click its track or arrows, or use the mouse wheel.",
	RIGHT_CLEAR = "Right-click: use inherited",
	RIGHT_REMOVE = "Right-click: remove",
	RIGHT_RESET = "Right-click: reset",
	RIGHT_FORGET = "Right-click: forget",
	SAVE_CLICK = "Click: save as profile",
	NEW = "New",
	NEW_TIP = "A new profile: empty, from your current settings or from a preset.",
	NEW_PROFILE = "New profile...",
	NEW_PROFILE_TITLE = "New profile",
	PROFILE_TITLE = "%s (profile)",
	START_FROM = "Start from:",
	START_EMPTY = "Empty",
	START_EMPTY_NOTE = "follows Default until you change a setting",
	START_HEAVIEST = "heaviest",
	NAME = "Name",
	START_EMPTY_TIP = "Empty: every setting follows your Default profile until you change it.",
	START_CURRENT = "My current settings",
	START_CURRENT_TIP = "Every graphics setting as it is right now.",
	START_PRESET_TIP = "%s: the preset's values.",
	CREATE = "Create",
	FROM_CURRENT = "From current settings",
	EVERYWHERE_TEXT = "Use \"%s\" everywhere?",
	EVERYWHERE_SUB = "Every location type uses this profile. Specific places keep their own.",
	RESET_VALUE = "Use inherited value",
	IMPACT = { none = "None", low = "Low", medium = "Medium", high = "High", ["very high"] = "Very high" },
	CAT_GRAPHICS = "Graphics",
	CAT_ADDON = "Addon",
	STRIP_HERE = "Here",
	STRIP_PROFILE = "Profile",
	STRIP_SMART = "Smart",
	STRIP_OFF = "Off",
	STRIP_NONE = "None",
	STRIP_CALIBRATING = "Finding best settings",
	STRIP_SMART_VALUE = "%s · %s",
	STRIP_TARGET = "target %d",
	STRIP_HERE_TYPE = "%s is a %s zone.",
	STRIP_HERE_PLACE = "%s has a profile of its own.",
	STRIP_CLICK_LOCATIONS = "Click: Locations",
	STRIP_CLICK_PROFILE = "Click: edit this profile",
	STRIP_CLICK_SMART = "Click: Smart mode",
	STRIP_FPS_TIP = "%d fps now · target %d",
	STRIP_GOAL = "Goal %d fps",
	WHY_TYPE = "%s zones use the profile %s.",
	WHY_PLACE = "%s has its own profile, %s.",
	WHY_DEFAULT = "%s has no profile of its own, so it uses Default.",
	WHY_OFF = "Smart Graphics is off. The game's own settings are in use.",
	WHY_HERE = "You are in %s.",
	WHY_SMART = "and Smart mode adjusts it to hold %s fps.",
	WHY_EXACT = "exactly as you set it.",
	SECTION_LOOK = "Look and speed here",
	SECTION_HANDLE = "Let it handle itself",
	SECTION_BY_LOCATION = "By location",
	PROFILE_FOR = "Profile for %s",
	PROFILE_FOR_TYPE_TIP = "The profile used in every %s.",
	PROFILE_FOR_PLACE_TIP = "The profile used in %s, before its location type's.",
	EDIT = "Edit",
	EDIT_TIP = "Opens every setting of %s.",
	QUALITY_PRESET = "Quality preset",
	PRESET_CUSTOM = "Custom",
	PRESET_TIP = "Sets every quality setting and render scale of %s in one step.",
	PRESET_TIP_STEP = "Left: more FPS. Right: better looks.",
	PRESET_TIP_CUSTOM = "Custom: the profile no longer matches a preset.",
	PRESET_TIP_SMART = "Smart mode starts from these values.",
	PRESET_REPLACE = "Replace %s's settings with %s?",
	PRESET_REPLACE_SUB = "Its own values are replaced.",
	REPLACE = "Replace",
	SMART_HINT = "Holds your target FPS as you play",
	SMART_PAUSED = "Paused while finding your best settings",
	SMART_TIP_FULL = "Holds your target FPS. It starts from the place's profile and lowers or raises settings as needed, and learns each location.",
	GOAL = "Goal",
	GOAL_TIP = "What Smart mode holds:",
	PACE = "Pace",
	PACE_TIP = "How eagerly Smart mode changes settings:",
	START_HINT = "One guided run, then it leaves settings alone",
	CALIBRATE_TIP_CLOSES = "Closes this window. Turns Smart mode off.",
	CALIBRATE_CONFIRM = "Start Find my best settings?",
	CALIBRATE_CONFIRM_SUB = "The window closes and Smart mode turns off while it runs.",
	SUMMARY_PLACES = "%d specific places",
	SUMMARY_PLACE = "1 specific place",
	SET_UP_LOCATIONS = "Set up locations",
	SET_UP_LOCATIONS_TIP = "Give a city, a raid or one place its own profile.",
	TURN_ON = "Turn on",
	BANNER_PENDING = "%s will change in a moment.",
	BANNER_PENDING_COMBAT = "%s waits for combat to end.",
	BANNER_ADJUST = "Adjusting %s...",
	ACTIVITY_RAISE = "Optimizing graphics",
	ACTIVITY_LOWER = "Easing graphics for FPS",
	ACTIVITY_MORE = "   +%d more",
	ACTIVITY_FPS = "%s / %d fps",
	ACTIVITY_TIP = "Smart mode's changes so far",
	ACTIVITY_DONE = "Graphics optimized",
	ACTIVITY_EASED = "Eased for FPS",
	AFTER_COMBAT_DONE = "Applied after combat: %d changes",
	NOW_USING = "Now using %s · %s",
	CHANGED_ONE = "%d setting changed: %s",
	CHANGED_MANY = "%d settings changed: %s",
	CHANGED_COUNT_ONE = "%d setting changed",
	CHANGED_COUNT = "%d settings changed",
	CHANGED_MORE = " +%d",
	RESTORED = "Original settings restored",
	APPLIED_TEXTURE = "Texture change applied",
	PROFILE_NOTICE = "Show profile switches on screen",
	PROFILE_NOTICE_TIP = "A notice near the top of the screen when the profile in use changes, with what it changed.",
	COMBAT_LOW = "Low FPS in this fight: %d / %d",
	LOWER_NOW = "Lower now",
	AFTER_COMBAT = "After combat",
	SMART_NOTICE = "Show Smart mode activity on screen",
	SMART_NOTICE_TIP = "A small notice near the top of the screen while Smart mode changes settings, then a short summary.",
	CHAT_LOG_SMART = "Also log Smart mode changes in chat",
	CHAT_LOG_SMART_TIP = "A chat line for every change Smart mode makes, as well as the notice.",
	BANNER_LAG = "This place has run under your target: avg %d of %d fps.",
	CHANGE_PROFILE = "Change profile",
	CAL_LAST = "Last change: %s",
	PROFILES_HINT = "A profile is one full set of graphics settings.",
	IN_USE = "In use here now",
	USED_IN = "Used in %s",
	NOT_USED = "Not used anywhere",
	EVERY_OTHER = "every place without a profile of its own",
	OWN_COUNT = "%d settings of its own, the rest follow Default",
	OWN_NONE = "follows Default",
	PRESET_NAMED = "%s preset",
	PLACE_SUFFIX = "%s (specific place)",
	ONE_PROFILE = "One profile is enough to start. Add another when a kind of place needs different settings.",
	PROFILE_ROW_TIP = "Click to edit this profile.",
	PROFILE_ROW_TIP_PAD = "Press to edit this profile.",
	ALL_PROFILES = "< All profiles",
	ALL_PROFILES_TIP = "Back to the list of profiles.",
	LEGEND = "White values are set in this profile. Grey values follow Default until you change them; the reset arrow puts a value back to following.",
	LEGEND_DEFAULT = "White values are set in this profile. Grey values follow your original settings until you change them; the reset arrow puts a value back to following.",
	COLUMN_VALUE_SHORT = "Value",
	FOLD_COUNT = "%d settings · %d set here",
	FOLD_TIP = "Click to show or hide these settings.",
	NOW_VALUE = "now %s",
	NOW_TIP = "Smart mode is running this at %s right now. The profile's own value is %s.",
	SWITCHING_HINT = "Each place uses its own profile when you arrive",
	COLUMN_PROFILE = "Profile",
	COLUMN_STYLE = "Smart goal",
	COLUMN_STYLE_OFF = "Smart goal (Smart mode is off)",
	YOU_ARE_HERE = "you are here",
	GOAL_TYPE_TIP = "The Smart goal used in every %s. Default uses the Goal on the Smart mode page.",
	PLACES_WIN = "A specific place wins over its location type.",
	ADD_THIS_PLACE = "Add this place: %s",
	REMOVE_TIP = "This place goes back to its location type's profile.",
	SMART_INTRO = "Smart mode starts from the profile of the place you are in, then lowers or raises settings to hold your target FPS with the best picture it can.",
	RIGHT_NOW = "Right now",
	NOW_LINE = "%s · %d fps, goal %d · %s · %s",
	BEFORE_THAT = "Before that: %s",
	SMART_OFF_LINE = "Smart mode is off. Profiles are used exactly as set.",
	LEARNED_FOLD = "What it learned",
	LEARNED_COUNT = "%d locations",
	LAGGED_COUNT = "%d places",
	AGE_MIN = "%d min ago",
	AGE_HOURS = "%d h ago",
	AGE_DAYS = "%d days ago",
	SECTION_CONTROLS = "Controls",
	SECTION_NOTICES = "Notifications",
	NOTICES_DESC = "All off by default. Turn on what you want to see.",
	SECTION_MINIMAP = "Minimap",
	SECTION_START_OVER = "Start over",
	RESTORE_KEEPS = "Your profiles stay.",
	ABOUT_LINE = "Version %s · /fsg opens this window · /fsg help lists the commands",
	COLUMN_SETTING = "Setting",
	COLUMN_IMPACT = "FPS impact",
	COLUMN_VALUE = "Value",
	IMPACT_HEAD_TIP = { "How much frame rate a setting costs, per step up.", "None or Low: barely shows. Medium: a few fps. High: a clear cost. Very high: the biggest costs.", "Measured values come from Smart mode on this PC; the rest are tested on other machines or estimated." },
	IMPACT_LINE = "FPS impact: %s (%s)",
	IMPACT_PERCENT = "about %d%% per step, %s",
	IMPACT_SOURCE = { measured = "measured on your PC", probe = "tested", estimate = "estimate" },
	RESET_VALUE_TIP = "Clears this profile's own value; it uses the inherited one again.",
	HEADER = "%s · %s: %s · %d fps",
	HEADER_SMART = " · Smart: %s",
	HEADER_MODE = " (%s)",
	MODE_LINE = "%s: %s",
	MODE_DEFAULT = "Default (%s)",
	MODE_OFF_TIP = "Used when Smart mode is on.",
	HEADER_OFF = " · Switching off",
	UNKNOWN_PLACE = "Unknown place",

	PROFILES = "Profiles",
	ACTIVE = "active",
	GROUPS = { quality = "Quality", render = "Render", hidden = "Detail" },
	INHERIT = { Default = "(Default)", ["your original"] = "(original)" },
	INHERIT_TIP = "Not set in this profile: it uses %s.",
	INHERIT_SOURCE = { Default = "the Default profile", ["your original"] = "your original setting" },
	OWN_TIP = "Set in this profile.",
	CLEAR_TIP = "Clear it to use the Default profile's value.",
	CLEAR_DEFAULT_TIP = "Clear it to use your original setting.",
	HEAVY_TIP = "Changing this can stutter for a moment: it is announced first.",
	UNSUPPORTED = "Not supported on this machine",
	UNSUPPORTED_TIP = "The game ignores this setting on this machine, so it is left alone.",
	PROFILE_TIP = "Press to edit this profile.",
	PROFILE_TIP_MOUSE = "Click to edit this profile.",
	PROFILE_ACTIVE_TIP = "In use here now.",
	NEW_PRESET = "New from preset",
	NEW_PRESET_TIP = "A new profile from one of the game's quality levels, or for best looks or best FPS.",
	NEW_CURRENT = "New from current settings",
	NEW_CURRENT_TIP = "A new profile with every setting as it is now.",
	COPY = "Copy",
	COPY_TIP = "A new profile with the same settings.",
	RENAME = "Rename",
	RENAME_TIP = "Type a new name with the keyboard.",
	DELETE = "Delete",
	DELETE_TIP = "Places that used it go back to Default.",
	DELETE_TEXT = "Delete the profile \"%s\"?",
	DELETE_SUB = "Places that used it go back to Default.",
	USE_EVERYWHERE = "Use everywhere",
	USE_EVERYWHERE_TIP = "Every location type uses this profile.",
	USED_EVERYWHERE = "%s is now used everywhere",
	DEFAULT_LOCKED = "The Default profile can't be renamed or deleted.",
	PRESETS = "Presets",
	PRESET_TIPS = { beyond = "Everything at maximum plus hidden detail settings beyond the in-game max (draw distance, grass, shadows, sharpening). Heaviest preset." },
	LIMIT = "max on this machine: %s",
	AUTO_NAME = "Profile %d",
	NAME_TITLE = "Profile name",
	NAME_HINT = "Enter: OK · Esc: cancel",

	SWITCHING = "Switch by location",
	SWITCHING_TIP = "Uses each location's profile when you get there. Off: the game's settings stay as they are.",
	LOCATION_TYPES = "Location types",
	PLACES = "Specific places",
	DEFAULT = "Default",
	HERE = "You are here",
	HERE_LABEL = "%s (you are here)",
	SWITCHING_SECTION = "Switching",
	TYPE_TIP = "The profile used in every %s without a place of its own.",
	PLACE_TIP = "The profile used in %s, before its location type's.",
	ADD_PLACE = "Add current place: %s",
	ADD_PLACE_TIP = "Gives this place a profile of its own.",
	PLACE_ADDED = "This place already has its own row.",
	NO_PLACES = "No specific places yet.",

	SMART_MISSING = "Smart mode not loaded",
	SMART = "Smart mode",
	SMART_TIP = "Holds your target FPS: lowers render scale first, down to its floor, then the settings that cost most for least looks, and raises them again when there is room. It learns each location.",
	TARGET = "Target FPS",
	TARGET_TIP = "The frame rate Smart mode holds. Your FPS cap wins if it is lower.",
	FLOOR = "Render scale floor",
	FLOOR_TIP = "Smart mode never lowers render scale below this.",
	NOW = "Now",
	STATUS = "Status: %s",
	FPS_GOAL = "%d fps · goal %d",
	CAP = "Your FPS cap is %d",
	LAST = "Last change: %s",
	CHANGE = "%s %s to %s",
	CHANGES = "Changes",
	NO_CHANGES = "No changes yet",
	NO_LAST = "No change yet",
	LEARNED = "Learned per location",
	LEARNED_ROW = "%d samples · %s",
	LEARNED_TIP = "What Smart mode settled on here.",
	NO_LEARNED = "Nothing learned yet.",
	RESET_ALL = "Reset all learning",
	RESET_ALL_TIP = "Forgets every location's learned settings.",
	RESET_ALL_TEXT = "Forget everything Smart mode learned?",
	SMART_NAME = "%s (smart)",
	PRE_ADJUSTED = "Pre-adjusted for %s",
	PRE_ADJUSTED_SHORT = "Pre-adjusted",
	LAGGED = "Places that lagged",
	LAG_ROW = "avg %d fps · low %d · below target %d%% of the time",
	LAG_FIGHTS = " · fights -%d%%",
	LAG_TIP = "Smart mode lowers settings here ahead of time, before the frame rate drops.",
	NO_LAGGED = "Nothing yet. Play a while with Smart mode on.",
	FORGET = "Forget",
	CALIBRATE = "Find my best settings",
	CALIBRATE_LINE = "Move around a few kinds of places; the addon finds the best look that holds your FPS, saves it as a profile and then leaves your settings alone.",
	START = "Start",
	START_TIP = "Closes this window so you can move around. A small checklist shows what is left.",
	FINISH = "Finish",
	FINISH_TIP = "Saves what it found as a profile for every location.",
	STOP = "Stop",
	STOP_TIP = "Stops without saving; your settings go back.",
	CAL_TITLE = "Finding your best settings · %d FPS",
	CAL_SEARCHING = "searching %d s",
	CAL_HOLDING = "holding",
	CAL_FPS = "Now: %d fps",
	CAL_PAD = "Pad: /fsg finish · /fsg stop",
	CAL_SAVED = "Saved \"%s\" and set it for every location. Run Find my best settings again any time.",
	SAVED_AS = "saved as %s",

	OPTIONS = "Options",
	ANNOUNCE = "Announce texture changes before they stutter",
	ANNOUNCE_TIP = "Texture changes wait 10 seconds with a notice and an Apply now button. Off: they wait for the next loading screen.",
	MINIMAP = "Minimap button",
	MINIMAP_TIP = "The Smart Graphics button on the minimap ring; drag it to move it.",
	CHAT_LOG = "Log setting changes in chat",
	CHAT_LOG_TIP = "A short chat line each time the addon changes a graphics setting.",
	DEBUG = "Debug log",
	DEBUG_TIP = "Keeps a log of what the addon changes, for bug reports.",
	CONTROLS = "Controls",
	CONTROLS_TIP = "Automatic follows what you used last: the mouse and keyboard, or a controller.",
	INPUTS = { auto = "Automatic", mouse = "Mouse and keyboard", pad = "Controller" },
	RESTORE = "Restore my original settings",
	RESTORE_TIP = "Puts back the settings you had before Smart Graphics, and turns switching and Smart mode off.",
	RESTORE_TEXT = "Put back your original graphics settings?",
	RESTORE_SUB = "Switching by location and Smart mode turn off. Your profiles stay.",
	ABOUT = "About",
	VERSION = "Version %s",
	ABOUT_TEXT = "/fsg opens this window.\n/fsg status: location, profile, smart mode, fps.\n/fsg use <profile>: that profile everywhere.\n/fsg smart on|off · /fsg target <fps> · /fsg floor <percent>\n/fsg applynow: apply a waiting texture change.\n/fsg restore: your original settings.\n/fsg help: every command.",

	NOTIFY_SETTING = "%s: %s",
	NOTIFY_WAITS = " · waits for combat",
	NOTIFY_LOW_FPS = "Low FPS in %s: avg %d, target %d",
	CHANGE_BUTTON = "Change",
	SMART_ADJUST = "Smart adjust",
	ADJUST_REFUSED = "Smart adjust can't start: %s",
	ADJUSTING = "Adjusting %s...",
	ADJUST_DONE = "Saved \"Smart: %s\" for this place",
	SUGGEST = "Suggest changes when FPS drops",
	SUGGEST_TIP = "When a place stays under your target FPS for a while, a small notice offers to change its settings or let Smart adjust find them.",
	APPLY_NOW = "Apply now",

	COMPARTMENT_TIP = "Open the settings window",
	MINIMAP_LINE = "Drag to move it.",
	MINIMAP_FPS = "Show FPS on minimap",
	MINIMAP_FPS_TIP = "A small frame rate readout under the minimap: green at your goal, yellow a little under it, red well under. Click it to open this window.",
	FPS = "%d fps",
	FPS_TIP_PLACE = "%s · %s",
	FPS_TIP_PROFILE = "Profile: %s",
	FPS_TIP_SMART = "Smart: %s · goal %d fps",
	FPS_TIP_CLICK = "Click: open Smart Graphics",
	FPS_TIP_CHANGES = "Last changes",
	FPS_TIP_CHANGE = "%s · %s: %s",
	FPS_PULSE = "Pulse the minimap FPS on changes",
	FPS_PULSE_TIP = "The minimap FPS glows once and shows an arrow for a few seconds when a setting changes: up, down, or a dot for a mix or a profile switch. Needs Show FPS on minimap.",
	AGO_NOW = "just now",
	AGO_SECONDS = "%d s ago",
	AGO_MINUTES = "%d min ago",
	SOURCES = { smart = "smart mode", profile = "profile", restore = "restore", apply = "applied", adjust = "smart adjust", calibrate = "find my best settings", ["after combat"] = "after combat" },
}

local L = UI.L

-- The window's pages, one per category of the left list: { key, order, title(sel), build(content, window),
-- refresh(content, window, sel) returns nodes, onKey(key, focus), onBack(focus), tick(content) every second }. The
-- "profile" page draws whichever profile sel.id names. Panel.lua lists them in order.
UI.PAGES = {}

function UI.AddPage(spec)
	local i = #UI.PAGES + 1
	while i > 1 and UI.PAGES[i - 1].order > spec.order do i = i - 1 end
	table.insert(UI.PAGES, i, spec)
end

local function at(region, parent, x, y, point) region:SetPoint(point or "TOPLEFT", parent, "TOPLEFT", x, -y) end
UI.At = at

-- Two looks: "pad" (footer, button glyphs, focus cursor and glow) and "mouse" (hover highlight, visible buttons for
-- every pad-only action, right-click). options.input is "auto", "mouse" or "pad"; auto follows the last input used
-- (a pad button, or a mouse move, click or navigation key on our frames). FSG_INPUT(mode) fires when the look changes.
UI.INPUTS = { "auto", "mouse", "pad" }
local VALID_INPUT = { auto = true, mouse = true, pad = true }

function UI.InputSetting()
	local options = ns.db.options
	if not VALID_INPUT[options.input] then options.input = "auto" end
	return options.input
end

local function padGuess()
	local ok, on = pcall(C_GamePad and C_GamePad.IsEnabled)
	return ok and ns.plain(on) and "pad" or "mouse"
end

function UI.Mode()
	local setting = ns.db and UI.InputSetting() or "auto"
	if setting ~= "auto" then return setting end
	UI.lastInput = UI.lastInput or padGuess()
	return UI.lastInput
end

function UI.Pad() return UI.Mode() == "pad" end

local function modeChanged(was) if UI.Mode() ~= was then ns.Fire("FSG_INPUT", UI.Mode()) end end

local cursorX, cursorY

-- Where the pointer rests now: a frame shown or scrolled under it is not a mouse move.
function UI.MarkCursor() cursorX, cursorY = GetCursorPosition() end

function UI.NoteInput(kind)
	if kind == "pad" then UI.MarkCursor() end
	local was = UI.Mode()
	UI.lastInput = kind
	modeChanged(was)
end

-- True when the pointer moved since the last look: only then is a hover mouse input.
function UI.NoteHover()
	local x, y = GetCursorPosition()
	if x == cursorX and y == cursorY then return false end
	cursorX, cursorY = x, y
	UI.NoteInput("mouse")
	return true
end

function UI.SetInput(setting)
	local was = UI.Mode()
	ns.db.options.input = setting
	modeChanged(was)
end

ns.On("GAME_PAD_ACTIVE_CHANGED", function(active) UI.NoteInput(ns.plain(active) and "pad" or "mouse") end)

-- Mode-dependent text: the pad wording, or the mouse wording.
function UI.ByMode(pad, mouse) return UI.Pad() and pad or mouse end

-- An edit made in the window is the player's own: the engine applies it even where it holds its own changes (in
-- combat). Apply.Refresh(reason, loading, { user = true }) after the edit's own refresh.
function UI.UserEdit()
	local refresh = ns.Apply and ns.Apply.Refresh
	if refresh then refresh("user", false, { user = true }) end
end

-- Quality presets as the Overview and the editor show them: left = more FPS, right = better looks. The shown preset
-- is the first whose every value is the profile's effective value, in PRESET_MATCH order; none is "Custom".
local PRESET_ORDER = { "fps", "low", "fair", "good", "high", "ultra", "beyond" }
local PRESET_MATCH = { "beyond", "fps", "ultra", "high", "good", "fair", "low" }

function UI.PresetValues(key)
	local ok, values = pcall(ns.Catalog.BuildPreset, key)
	return ok and type(values) == "table" and values or nil
end

function UI.PresetName(key)
	local preset = key and ns.Catalog.Preset(key)
	return preset and preset.name or L.PRESET_CUSTOM
end

function UI.PresetOf(id)
	local effective = ns.Profiles.Effective(id) or {}
	for _, key in ipairs(PRESET_MATCH) do
		local values = UI.PresetValues(key)
		local same = values ~= nil
		for cvar, value in pairs(values or {}) do
			if not ns.Catalog.Same(cvar, effective[cvar], value) then same = false break end
		end
		if same then return key end
	end
end

function UI.PresetEntries()
	local entries = {}
	for _, key in ipairs(PRESET_ORDER) do
		if ns.Catalog.Preset(key) then entries[#entries + 1] = { id = key, name = UI.PresetName(key), detail = L.PRESET_TIPS[key] } end
	end
	return entries
end

-- Replaces the profile's own values with the preset's (the rest follow Default again), one refresh at the end. A
-- profile that matches no preset asks first.
local function replaceValues(window, id, key)
	local profile, values = ns.Profiles.Get(id), UI.PresetValues(key)
	if not (profile and values) then return end
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		local want, own = values[cvar], profile.values[cvar]
		if not (want == nil and own == nil) and not (want ~= nil and own ~= nil and ns.Catalog.Same(cvar, own, want)) then ns.Profiles.SetValue(id, cvar, want) end
	end
	UI.UserEdit()
	UI.RefreshSoon(window)
end

function UI.ApplyPreset(window, id, key)
	local profile = ns.Profiles.Get(id)
	if not profile or UI.PresetOf(id) == key then return end
	if UI.PresetOf(id) then return replaceValues(window, id, key) end
	UI.Confirm(window, string.format(L.PRESET_REPLACE, profile.name, UI.PresetName(key)), L.PRESET_REPLACE_SUB, L.REPLACE, function() replaceValues(window, id, key) end)
end

-- One step left or right; false at an end. From Custom it goes to the nearest preset by render scale and shadows.
local function nearestPreset(id)
	local effective = ns.Profiles.Effective(id) or {}
	local best, bestScore
	for _, key in ipairs(PRESET_ORDER) do
		local values = UI.PresetValues(key) or {}
		local score = math.abs((tonumber(effective.RenderScale) or 1) - (tonumber(values.RenderScale) or 1)) * 20 + math.abs((tonumber(effective.graphicsShadowQuality) or 0) - (tonumber(values.graphicsShadowQuality) or 0))
		if not bestScore or score < bestScore then best, bestScore = key, score end
	end
	return best
end

function UI.StepPreset(window, id, dir)
	local current = UI.PresetOf(id)
	if not current then return UI.ApplyPreset(window, id, nearestPreset(id)) end
	for i, key in ipairs(PRESET_ORDER) do
		if key == current then
			local nextKey = PRESET_ORDER[i + dir]
			if not nextKey then return false end
			return UI.ApplyPreset(window, id, nextKey)
		end
	end
	return false
end

function UI.PresetEnds(id)
	local current = UI.PresetOf(id)
	return current == PRESET_ORDER[1], current == PRESET_ORDER[#PRESET_ORDER]
end

-- One setting change { cvar, from, to } as "<label> <from> to <to>", or nil.
function UI.ChangeText(change)
	if not (change and change.cvar) then return end
	local cvar, format = change.cvar, ns.Catalog.Format
	local entry = ns.Catalog.Get(cvar)
	return string.format(L.CHANGE, entry and entry.label or tostring(cvar), format(cvar, change.from), format(cvar, change.to))
end

function UI.Text(parent, font, x, y, text, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	if x then at(fs, parent, x, y) end
	if width then
		fs:SetWidth(width)
		fs:SetJustifyH("LEFT")
	end
	fs:SetText(text or "")
	return fs
end

-- A button glyph from the active native glyph set (InputIconTextureSetUtility, a pure lookup; the InputIconTexture
-- template registers with InputDeviceIconSetManager, so it is not used). Without a glyph set, the button's name.
local ICON_STATE = { Normal = 1, Active = 4, Disabled = 5 }
local LARGE_PROMPT_W, LARGE_PROMPT_H = 76, 75
local GLYPH_NAME = { PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "L1", PADRSHOULDER = "R1", PADDUP = "Up", PADDDOWN = "Down", PADDLEFT = "Left", PADDRIGHT = "Right" }

local function glyphAtlas(key, state)
	local util = InputIconTextureSetUtility
	if not (util and key) then return end
	local ok, textures = pcall(util.GetActiveInputIconButtonTextures, key)
	if not (ok and type(textures) == "table") then return end
	return textures[ICON_STATE[state]] or textures[ICON_STATE.Normal]
end

UI.GlyphAtlas = glyphAtlas

local GlyphMixin = {}

function GlyphMixin:Paint()
	local atlas = glyphAtlas(self.key, self.disabled and "Disabled" or "Normal")
	local icon = self.icon
	icon:ClearAllPoints()
	self.name:SetShown(not atlas)
	if not atlas then
		self.name:SetText(GLYPH_NAME[self.key] or self.key or "")
		return icon:Hide()
	end

	icon:SetAtlas(atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	local pad = info and info.width == LARGE_PROMPT_W and info.height == LARGE_PROMPT_H and 5 or 0
	icon:SetPoint("TOPLEFT", -pad, pad)
	icon:SetPoint("BOTTOMRIGHT", pad, -pad)
	icon:Show()
end

function GlyphMixin:SetCode(key)
	self.key = key
	self:Paint()
end

function GlyphMixin:SetDisabled(disabled)
	self.disabled = disabled
	self:Paint()
end

function UI.Glyph(parent, size, key)
	local glyph = Mixin(CreateFrame("Frame", nil, parent), GlyphMixin)
	glyph:SetSize(size, size)
	glyph.icon = glyph:CreateTexture(nil, "ARTWORK")
	glyph.name = glyph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	glyph.name:SetPoint("CENTER")
	glyph:SetCode(key)
	return glyph
end

-- Section header in the character window's art: UI-Character-Info-Title with centred GameFontHighlight.
function UI.SectionHeader(parent, x, y, width, text)
	local header = CreateFrame("Frame", nil, parent)
	header:SetSize(width, 40)
	at(header, parent, x, y)
	local bg = header:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("UI-Character-Info-Title")
	bg:SetAllPoints()
	header.text = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	header.text:SetPoint("CENTER", 0, 1)
	header.text:SetText(text)
	return header
end

-- Every overlay (list and its click catcher, dialog, tooltip, focus cursor) sits in its window's strata, one level
-- above everything the window and its other open overlays draw; none of our frames is toplevel.
local MAX_LEVEL = 10000
local OVERLAY_RANK = { catcher = 2, picker = 4, dialog = 6, tooltip = 8, cursor = 10 }

local function treeTop(frame, skip)
	if skip[frame] then return 0 end
	local top = frame:GetFrameLevel()
	for _, child in ipairs({ frame:GetChildren() }) do top = math.max(top, treeTop(child, skip)) end
	return top
end

function UI.RaiseAbove(frame, window, kind)
	local overlays = window.overlays or {}
	window.overlays = overlays
	overlays[frame] = true
	frame:SetFrameStrata(window:GetFrameStrata())
	frame:SetFrameLevel(math.min(treeTop(window, overlays) + OVERLAY_RANK[kind], MAX_LEVEL))
end

-- SmartNavigation's pointer art: gamepad-largecursor-white x 0.8, GAMEPAD_SMARTNAV_CURSOR_COLOR, bobbing 4 units.
function UI.Cursor(parent)
	local cursor = CreateFrame("Frame", nil, parent)
	cursor:SetSize(33.6, 56)
	local texture = cursor:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints()
	texture:SetAtlas("gamepad-largecursor-white")
	local color = GAMEPAD_SMARTNAV_CURSOR_COLOR
	if color and color.GetRGB then texture:SetVertexColor(color:GetRGB()) else texture:SetVertexColor(1, 230 / 255, 0) end

	local bob = texture:CreateAnimationGroup()
	bob:SetLooping("REPEAT")
	for order, offset in ipairs({ 4, -4 }) do
		local move = bob:CreateAnimation("Translation")
		move:SetOffset(offset, 0)
		move:SetDuration(1)
		move:SetSmoothing("IN_OUT")
		move:SetOrder(order)
	end

	function cursor:Attach(region, x)
		self:ClearAllPoints()
		if not (region and UI.Pad()) then return self:Hide() end
		self:SetPoint("LEFT", region, "LEFT", (x or 0) - 22, 0)
		UI.RaiseAbove(self, parent, "cursor")
		self:Show()
		if not bob:IsPlaying() then bob:Play() end
	end
	cursor:Hide()
	return cursor
end

-- The gamepad focus outline of a native frame: FrameGlowMixin's atlas, offsets and half scale, coloured and faded
-- from GamepadFocusStateColor / GamepadFocusStateOpacity (read only). FrameGlowTemplate registers with
-- CVarCallbackRegistry, so it is built here.
local GLOW_COLOR = { [1] = { 1, 0.9, 0.4 }, [2] = { 0, 0, 0 }, [3] = { 0.3, 0.5, 1 } }

function UI.Glow(frame, relative, atlas, x, y, x1, y1)
	local glow = CreateFrame("Frame", nil, frame)
	glow:SetPoint("TOPLEFT", relative, "TOPLEFT", x, y)
	glow:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", x1, y1)
	glow:SetFrameLevel(frame:GetFrameLevel() + 5)
	local texture = glow:CreateTexture(nil, "BACKGROUND")
	texture:SetAtlas(atlas)
	texture:SetScale(0.5)
	texture:SetAllPoints()
	glow:SetScript("OnShow", function(self)
		if not UI.Pad() then return self:Hide() end
		local color = GLOW_COLOR[tonumber(GetCVar("GamepadFocusStateColor") or "")]
		if color then texture:SetVertexColor(unpack(color)) else texture:SetVertexColor(1, 1, 1) end
		self:SetAlpha(tonumber(GetCVar("GamepadFocusStateOpacity") or "") or 1)
	end)
	glow:Hide()
	return glow
end

-- The native footer, drawn by the addon: a box under the window's bottom-right corner, gamepad-footer-slot-bg +
-- -frameneutral, 24-unit glyphs with GameFontNormal labels, sorted the way PromptedBindingFooter sorts keys. Blizzard's
-- footer templates bind through InputBindingManager. Clicking a prompt does what its button does.
local PROMPT_ORDER = { PAD1 = 1, PAD3 = 2, PAD4 = 3, PADDUP = 4, PADLSHOULDER = 5, PADRSHOULDER = 6, PAD2 = 9 }

function UI.Footer(window)
	local footer = CreateFrame("Frame", nil, window)
	footer:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, 0)
	footer:SetSize(44, 44)
	footer:SetFrameLevel(window:GetFrameLevel() + 10)
	local slot = footer:CreateTexture(nil, "BACKGROUND")
	slot:SetAtlas("gamepad-footer-slot-bg")
	slot:SetAllPoints()
	local border = footer:CreateTexture(nil, "BORDER")
	border:SetAtlas("gamepad-footer-slot-frameneutral")
	border:SetAllPoints()
	footer.prompts = {}

	-- Prompts still listed stay shown (only their text and place change): hiding a button under the pointer drops its
	-- click, and the footer is set again on every refresh and focus change. The mouse look has no footer.
	function footer:Set(list)
		local sorted = {}
		for _, entry in ipairs(UI.Pad() and list or {}) do sorted[#sorted + 1] = entry end
		table.sort(sorted, function(a, b) return (PROMPT_ORDER[a[1]] or 7) < (PROMPT_ORDER[b[1]] or 7) end)
		for i = #sorted + 1, #self.prompts do self.prompts[i]:Hide() end

		local x = 10
		for i, entry in ipairs(sorted) do
			local prompt = self.prompts[i]
			if not prompt then
				prompt = CreateFrame("Button", nil, self)
				prompt:SetHeight(24)
				prompt.glyph = UI.Glyph(prompt, 24)
				prompt.glyph:SetPoint("LEFT")
				prompt.label = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				prompt.label:SetPoint("LEFT", prompt.glyph, "RIGHT", 4, 0)
				prompt:SetScript("OnClick", function(button) window:Pad(button.key) end)
				self.prompts[i] = prompt
			end
			prompt.key = entry[1]
			prompt.glyph:SetCode(entry[1])
			prompt.label:SetText(entry[2])
			prompt:SetWidth(28 + prompt.label:GetStringWidth())
			prompt:ClearAllPoints()
			prompt:SetPoint("TOPLEFT", self, "TOPLEFT", x, -10)
			prompt:Show()
			x = x + prompt:GetWidth() + 15
		end
		self:SetWidth(x - 15 + 10)
		self:SetShown(#sorted > 0)
	end
	return footer
end

-- A plain button in StaticPopupButtonTemplate's art (UI-DialogBox-Button-*), without its TextSizeManager mixin.
local DIALOG_COORDS = { 0, 1, 0, 0.71875 }

function UI.DialogButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(128, 21)
	for _, spec in ipairs({ { "SetNormalTexture", "Up" }, { "SetPushedTexture", "Down" }, { "SetDisabledTexture", "Disabled" }, { "SetHighlightTexture", "Highlight" } }) do
		button[spec[1]](button, "Interface\\Buttons\\UI-DialogBox-Button-" .. spec[2])
	end
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
		texture:SetTexCoord(unpack(DIALOG_COORDS))
	end
	button:GetHighlightTexture():SetBlendMode("ADD")
	button:SetNormalFontObject("GameFontNormal")
	button:SetHighlightFontObject("GameFontHighlight")
	button:SetDisabledFontObject("GameFontDisable")
	return button
end

-- A dialog button sized to its label (text + 40, at least 128), as StaticPopup sizes its buttons.
local BUTTON_MIN, BUTTON_PAD = 128, 40

function UI.FitButton(button, text)
	button:SetText(text)
	button:SetWidth(math.max(BUTTON_MIN, (button:GetTextWidth() or 0) + BUTTON_PAD))
	return button:GetWidth()
end

-- StaticPopup's art (UI-DialogBox-Background-Dark under the GameDialogBackgroundTop border) on a frame of ours; the
-- dialog, the name box, the toast and the overlay share it. The dark fill is translucent: a black underlay, as the
-- window has, keeps what is behind unreadable.
function UI.DialogArt(frame)
	frame.underlay = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	frame.underlay:SetColorTexture(0, 0, 0, 1)
	frame.underlay:SetPoint("TOPLEFT", 7, -7)
	frame.underlay:SetPoint("BOTTOMRIGHT", -7, 7)
	local bottom = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	bottom:SetAtlas("UI-DialogBox-Background-Dark")
	bottom:SetPoint("TOPLEFT", 7, -7)
	bottom:SetPoint("BOTTOMRIGHT", -7, 7)
	local top = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
	top:SetAtlas(GameDialogBackgroundTop or "UI-DiamondDialogBox-Border")
	top:SetAllPoints()
end

-- A confirm box in StaticPopup's look, built by the addon: StaticPopup_Show pushes Blizzard's popup binding set.
-- Pad: A presses the focused button, B the second (or spec.back), D-pad left/right moves. The box widens to its
-- buttons; the text wraps to the final width.
local DIALOG_W, DIALOG_SIDE, DIALOG_GAP, DIALOG_TEXT_PAD, CURSOR_OUTSIDE = 320, 24, 13, 40, -12
local dialog
local DialogMixin = {}

function DialogMixin:Open(owner, spec)
	self.owner, self.spec, self.index = owner, spec, 1
	local two = spec.buttons[2] ~= nil
	local buttons = UI.FitButton(self.Button1, spec.buttons[1]) + (two and UI.FitButton(self.Button2, spec.buttons[2]) + DIALOG_GAP or 0)
	local width = math.max(DIALOG_W, buttons + 2 * DIALOG_SIDE)
	self:SetWidth(width)
	self.Text:SetWidth(width - DIALOG_TEXT_PAD)
	self.SubText:SetWidth(width - DIALOG_TEXT_PAD)
	self.Text:SetText(spec.text)
	self.SubText:SetText(spec.sub or "")
	self.Button2:SetShown(two)
	self.Button1:ClearAllPoints()
	if spec.buttons[2] then self.Button1:SetPoint("BOTTOMRIGHT", self, "BOTTOM", -6.5, 16) else self.Button1:SetPoint("BOTTOM", self, "BOTTOM", 0, 16) end
	self:ClearAllPoints()
	self:SetScale(owner:GetScale())
	self:SetPoint("TOP", owner, "TOPLEFT", owner:GetWidth() / 2, -210)
	self:SetHeight(math.max(120, 16 + self.Text:GetStringHeight() + 6 + self.SubText:GetStringHeight() + 16 + 21 + 16))
	UI.RaiseAbove(self, owner, "dialog")
	UI.HideTooltip()
	self:Show()
	owner:SetPrompts({ { "PAD1", L.SELECT }, { "PAD2", L.BACK } })
	self:Point()
end

function DialogMixin:Point()
	for i = 1, 2 do
		local button = self["Button" .. i]
		if i == self.index then button:LockHighlight() else button:UnlockHighlight() end
	end
	self.owner.cursor:Attach(self["Button" .. self.index], CURSOR_OUTSIDE)
end

function DialogMixin:Close()
	if not self:IsShown() then return end
	local owner = self.owner
	self:Hide()
	if owner and owner:IsShown() then owner:Refresh() end
end

function DialogMixin:Press(index)
	local spec = self.spec
	self:Close()
	local fn = spec and spec["on" .. index]
	if fn then fn() end
end

function DialogMixin:OnPad(key)
	local two = self.Button2:IsShown()
	if key == "PADDLEFT" or key == "PADDRIGHT" then
		self.index = two and key == "PADDRIGHT" and 2 or 1
		return self:Point()
	end
	if key == "PAD1" then return self:Press(self.index) end
	if key == "PAD2" then return self:Press(self.spec.back or two and 2 or 1) end
end

function UI.Dialog()
	if dialog then return dialog end

	dialog = Mixin(CreateFrame("Frame", "ForeverSmartGraphicsDialog", UIParent), DialogMixin)
	dialog:SetSize(320, 120)
	dialog:EnableMouse(true)
	dialog:Hide()
	UI.DialogArt(dialog)
	dialog.glow = UI.Glow(dialog, dialog, "gamepad-uiframediamondmetal-focus-large", -6, 6, 6, -6)
	dialog:SetScript("OnShow", function(self) self.glow:Show() end)
	dialog:SetScript("OnHide", function(self) self.glow:Hide() end)

	dialog.Text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	dialog.Text:SetWidth(280)
	dialog.Text:SetSpacing(2)
	dialog.Text:SetPoint("TOP", 0, -16)
	dialog.SubText = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	dialog.SubText:SetWidth(280)
	dialog.SubText:SetPoint("TOP", dialog.Text, "BOTTOM", 0, -6)
	dialog.Button1 = UI.DialogButton(dialog)
	dialog.Button2 = UI.DialogButton(dialog)
	dialog.Button2:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 6.5, 16)
	for index = 1, 2 do
		local button = dialog["Button" .. index]
		button:SetScript("OnClick", function() dialog:Press(index) end)
		button:SetScript("OnEnter", function()
			dialog.index = index
			dialog:Point()
		end)
	end
	return dialog
end

function UI.DialogShown() return dialog and dialog:IsShown() end

-- Yes / Cancel confirm for a destructive action.
function UI.Confirm(window, text, sub, label, fn) UI.Dialog():Open(window, { text = text, sub = sub, buttons = { label, L.CANCEL }, on1 = fn }) end

-- The addon's own tooltip in GameTooltip's art (TooltipDefaultLayout NineSlice, TOOLTIP_DEFAULT_BACKGROUND_COLOR): a
-- NORMAL_FONT_COLOR title, white lines, then the focused row's button actions as glyph + GREEN_FONT_COLOR text.
-- GameTooltip is shared with Blizzard's secure buttons, so it is left alone. A line is text or { text, color = { r, g,
-- b }, small = true }. spec = { title, lines, actions =
-- { { key, label }, ... }, side = "right" | "left" }.
local tooltip
local TIP_PAD, TIP_GAP, ACTION_GLYPH, TIP_TEXT_W = 10, 2, 18, 300
local TIP_WHITE = { 1, 1, 1 }

local function tipText(fs, text)
	fs:SetWidth(TIP_TEXT_W)
	fs:SetText(text)
	local full = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
	fs:SetWidth(math.min(full or TIP_TEXT_W, TIP_TEXT_W) + 1)
	return fs:GetWidth()
end

local function tooltipFrame()
	if tooltip then return tooltip end

	tooltip = CreateFrame("Frame", nil, UIParent)
	tooltip:SetClampedToScreen(true)
	if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then NineSliceUtil.ApplyLayoutByName(tooltip, "TooltipDefaultLayout") end
	local color = TOOLTIP_DEFAULT_BACKGROUND_COLOR
	if tooltip.Center and color and color.GetRGB then tooltip.Center:SetVertexColor(color:GetRGB()) end
	tooltip.title = tooltip:CreateFontString(nil, "ARTWORK", "GameTooltipHeaderText")
	tooltip.title:SetJustifyH("LEFT")
	tooltip.lines, tooltip.actions = {}, {}
	return tooltip
end

local function tipLine(i)
	local line = tooltip.lines[i] or tooltip:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	line:SetJustifyH("LEFT")
	tooltip.lines[i] = line
	return line
end

local function tipAction(i)
	local action = tooltip.actions[i]
	if action then return action end

	action = CreateFrame("Frame", nil, tooltip)
	action:SetHeight(ACTION_GLYPH)
	action.glyph = UI.Glyph(action, ACTION_GLYPH)
	action.glyph:SetPoint("LEFT")
	action.text = action:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	action.text:SetPoint("LEFT", action.glyph, "RIGHT", 6, 0)
	tooltip.actions[i] = action
	return action
end

function UI.Tooltip(owner, spec)
	local tip = tooltipFrame()
	tip.owner = owner
	for _, line in ipairs(tip.lines) do line:Hide() end
	for _, action in ipairs(tip.actions) do action:Hide() end

	-- The mouse look shows spec.mouse lines (right-click hints) in place of the pad actions.
	local pad = UI.Pad()
	local lines, actions = spec.lines or {}, pad and spec.actions or {}
	if not pad and spec.mouse then
		lines = { unpack(lines) }
		for _, text in ipairs(spec.mouse) do lines[#lines + 1] = text end
	end
	local y = TIP_PAD
	local width = tipText(tip.title, spec.title or "")
	tip.title:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
	tip.title:ClearAllPoints()
	tip.title:SetPoint("TOPLEFT", TIP_PAD, -y)
	y = y + tip.title:GetStringHeight() + TIP_GAP
	for i, entry in ipairs(lines) do
		local line = tipLine(i)
		local spec = type(entry) == "table" and entry or { text = entry }
		line:SetFontObject(spec.small and "GameFontHighlightSmall" or "GameFontHighlight")
		line:SetTextColor(unpack(spec.color or TIP_WHITE))
		width = math.max(width, tipText(line, spec.text))
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", TIP_PAD, -y)
		line:Show()
		y = y + line:GetStringHeight() + TIP_GAP
	end
	if #actions > 0 then y = y + 8 end
	for i, entry in ipairs(actions) do
		local action = tipAction(i)
		action.glyph:SetCode(entry[1])
		action.text:SetText(entry[2])
		action.text:SetTextColor(GREEN_FONT_COLOR:GetRGB())
		action:SetWidth(ACTION_GLYPH + 6 + action.text:GetStringWidth())
		action:ClearAllPoints()
		action:SetPoint("TOPLEFT", TIP_PAD, -y)
		action:Show()
		y, width = y + ACTION_GLYPH + 6, math.max(width, action:GetWidth())
	end

	tip:SetSize(width + TIP_PAD * 2, y - TIP_GAP + TIP_PAD)
	tip:ClearAllPoints()
	-- Beside the row, never over it: a side the screen can't hold flips to the other.
	local side, left, right = spec.side, owner:GetLeft(), owner:GetRight()
	local screen = UIParent:GetRight() and UIParent:GetRight() * UIParent:GetEffectiveScale() / owner:GetEffectiveScale()
	local need = tip:GetWidth() + 8
	if side ~= "left" and right and screen and right + need > screen and left and left - need >= 0 then side = "left"
	elseif side == "left" and left and left - need < 0 and right and screen and right + need <= screen then side = "right" end
	if spec.side == "above" then tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", UI.N.TIP_X, 0)
	elseif side == "left" then tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
	else tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0) end
	tip:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
	local window = UI.Current and UI.Current()
	if window and window:IsShown() then UI.RaiseAbove(tip, window, "tooltip") else tip:SetFrameStrata("TOOLTIP") end
	tip:Show()
end

function UI.TooltipOwner() return tooltip and tooltip:IsShown() and tooltip.owner end

function UI.HideTooltip(owner)
	if tooltip and (not owner or tooltip.owner == owner) then tooltip:Hide() end
end

-- Settings controls: our own frames with the Settings panel's art, never its templates. They only draw and take mouse
-- clicks; the tab keeps the value, steps it on the pad (its row's onDir and A) and sets it back with Set.

-- A checkbox (SettingsCheckboxTemplate's art), 30 x 29. onClick() on a click; box:Set(on) shows the check.
function UI.Checkbox(parent, onClick)
	local box = CreateFrame("Button", nil, parent)
	box:SetSize(30, 29)
	local bg = box:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("checkbox-minimal")
	bg:SetAllPoints()
	box.check = box:CreateTexture(nil, "ARTWORK")
	box.check:SetAtlas("checkmark-minimal")
	box.check:SetAllPoints()
	box:SetScript("OnClick", function() onClick() end)
	function box.Set(_, on) box.check:SetShown(not not on) end
	return box
end

-- A dropdown with steppers, as the Settings panel draws one (DropdownWithSteppersTemplate around the Menu addon's
-- style-1 dropdown button), rebuilt on our frames: the back and next icons (common-dropdown-icon-*), and between
-- them the button in common-dropdown-textholder art with the common-dropdown-a-button arrow (-hover, -open, -disabled)
-- and its value in GameFontHighlight. onStep(-1 | 1) from the steppers; onOpen(button) from a click on the button
-- (the tab opens UI.List under it). A right-click on it is the row's right-click. drop:Set(text, first, last) greys a
-- stepper at an end; drop:SetFocused(on) lights the arrow; drop:SetOpen(on) shows it open.
local DROP_H, DROP_STEP = 25, 22

-- The dropdown button itself (common-dropdown-textholder, common-dropdown-a-button arrow, GameFontHighlight text) on
-- holder, which keeps its state: holder.open, holder.focused; holder.Paint() redraws the arrow.
local function dropButton(holder, parent, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, DROP_H)
	local art = button:CreateTexture(nil, "BACKGROUND")
	art:SetAtlas("common-dropdown-textholder")
	art:SetPoint("TOPLEFT", -8, 7)
	art:SetPoint("BOTTOMRIGHT", 8, -9)
	holder.arrow = button:CreateTexture(nil, "OVERLAY")
	holder.arrow:SetPoint("RIGHT", 1, -3)
	holder.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	holder.text:SetPoint("LEFT", 8, 0)
	holder.text:SetPoint("RIGHT", holder.arrow, "LEFT", -2, 0)
	holder.text:SetJustifyH("LEFT")
	holder.text:SetWordWrap(false)
	holder.button = button
	function holder.Paint()
		local state = holder.open and "-open" or (holder.focused or button:IsMouseOver()) and "-hover" or ""
		holder.arrow:SetAtlas("common-dropdown-a-button" .. state, true)
	end
	function holder.SetOpen(_, on)
		holder.open = on
		holder.Paint()
	end
	function holder.SetFocused(_, on)
		holder.focused = on
		holder.Paint()
	end
	button:SetScript("OnEnter", holder.Paint)
	button:SetScript("OnLeave", holder.Paint)
	holder.Paint()
	return button
end

function UI.Choice(parent, width, onStep, onOpen)
	local drop = CreateFrame("Frame", nil, parent)
	drop:SetSize(width + 2 * DROP_STEP, DROP_H)
	local button = dropButton(drop, drop, width)
	button:SetPoint("LEFT", DROP_STEP, 0)
	local paint = drop.Paint
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then return UI.RowClick(parent, mouse) end
		UI.NoteInput("mouse")
		onOpen(self)
	end)

	drop.steppers = {}
	for step, name in pairs({ [-1] = "back", [1] = "next" }) do
		local stepper = CreateFrame("Button", nil, drop)
		stepper:SetSize(DROP_STEP, DROP_H)
		stepper:SetPoint(step < 0 and "LEFT" or "RIGHT")
		stepper.icon = stepper:CreateTexture(nil, "ARTWORK")
		stepper.icon:SetPoint("CENTER")
		stepper.atlas = "common-dropdown-icon-" .. name
		stepper:SetScript("OnClick", function()
			UI.NoteInput("mouse")
			onStep(step)
		end)
		drop.steppers[step] = stepper
	end

	function drop.Set(_, text, first, last)
		drop.text:SetText(text)
		for step, stepper in pairs(drop.steppers) do
			local ended = step < 0 and first or step > 0 and last or drop.off
			stepper.icon:SetAtlas(stepper.atlas .. (ended and "-disabled" or ""), true)
			stepper:SetEnabled(not ended)
		end
		paint()
	end
	-- Greyed: it keeps showing its value, takes no clicks.
	function drop.SetEnabledState(_, on)
		drop.off = not on
		button:SetEnabled(on)
		drop.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
		for step, stepper in pairs(drop.steppers) do
			stepper:SetEnabled(on)
			stepper.icon:SetAtlas(stepper.atlas .. (on and "" or "-disabled"), true)
		end
	end
	return drop
end

-- A Catalog setting's control, as Blizzard's Graphics options draw it: numbers without names are a slider, named
-- levels and fixed choices a dropdown.
function UI.ControlKind(entry) return (entry.kind == "choice" or entry.names) and "dropdown" or "slider" end

-- A dropdown setting's values in order: its fixed choices, or every step of its range.
function UI.ChoiceValues(entry)
	if entry.choices then return entry.choices end
	local values = {}
	for value = entry.min, entry.max + entry.step / 2, entry.step do values[#values + 1] = value end
	return values
end

-- A setting's FPS cost: level ("none" .. "very high"), percent per step or nil, source ("measured" | "probe" |
-- "estimate"). Catalog.Impact when the engine has it (measured on this PC), else the entry's own impact; nil when
-- neither is known (an older engine).
local IMPACT_COLORS = { none = { 0.1, 1, 0.1 }, low = { 0.1, 1, 0.1 }, medium = { 1, 0.82, 0 }, high = { 1, 0.5, 0.15 }, ["very high"] = { 1, 0.1, 0.1 } }

function UI.ImpactOf(entry)
	local impact = ns.Catalog.Impact
	if impact then
		local ok, level, percent, source = pcall(impact, entry.cvar)
		if ok and IMPACT_COLORS[level] then return level, tonumber(percent), source end
	end
	if IMPACT_COLORS[entry.impact] then return entry.impact, nil, "estimate" end
end

function UI.ImpactColor(level) return IMPACT_COLORS[level] end

-- "FPS impact: High (about 11% per step, measured on your PC)", or without the percent when it is unknown.
function UI.ImpactLine(entry)
	local level, percent, source = UI.ImpactOf(entry)
	if not level then return end
	local where = L.IMPACT_SOURCE[source] or L.IMPACT_SOURCE.estimate
	local detail = percent and string.format(L.IMPACT_PERCENT, math.floor(percent + 0.5), where) or where
	return { text = string.format(L.IMPACT_LINE, L.IMPACT[level], detail), color = IMPACT_COLORS[level] }
end

-- The choices of a dropdown as list entries: values in order, each labelled by label(value); current marked.
function UI.ChoiceEntries(values, label)
	local entries = {}
	for i, value in ipairs(values) do entries[i] = { id = value, name = label(value) } end
	return entries
end

-- Opens a dropdown's list under its button; the arrow shows open until the list closes.
function UI.OpenChoice(window, drop, entries, current, onPick, returnTo)
	drop:SetOpen(true)
	UI.List.Open({ window = window, cell = drop.button, returnTo = returnTo or drop:GetParent(), below = true, width = math.max(drop.button:GetWidth(), 160), entries = entries, current = current, onPick = onPick, onClose = function() drop:SetOpen(false) end })
end

-- A slider with steppers, as the Settings panel's slider control (MinimalSliderWithSteppersTemplate's art), the value
-- in GameFontNormal 10 past its right. onStep(-1 | 1) from the steppers and the mouse wheel; onSet(value) when the
-- thumb is dragged or the track clicked. slider:Set(value, text) moves the thumb; slider:SetRange(min, max, step).
function UI.Slider(parent, width, min, max, step, onStep, onSet)
	local slider = CreateFrame("Frame", nil, parent)
	slider:SetSize(width, 19)
	slider.steppers = {}
	for dir, spec in pairs({ [-1] = { "LEFT", 11, 19, "Minimal_SliderBar_Button_Left" }, [1] = { "RIGHT", 9, 18, "Minimal_SliderBar_Button_Right" } }) do
		local button = CreateFrame("Button", nil, slider)
		button:SetSize(spec[2], spec[3])
		button:SetPoint(spec[1])
		local tex = button:CreateTexture(nil, "ARTWORK")
		tex:SetAtlas(spec[4])
		tex:SetAllPoints()
		button:SetScript("OnClick", function()
			UI.NoteInput("mouse")
			onStep(dir)
		end)
		slider.steppers[dir] = button
	end
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(_, delta) onStep(delta > 0 and 1 or -1) end)
	-- A Slider takes no mouse until enabled (Blizzard's slider templates set enableMouse): without it no drag.
	local bar = CreateFrame("Slider", nil, slider)
	bar:EnableMouse(true)
	bar:SetPoint("TOPLEFT", 15, -1)
	bar:SetPoint("BOTTOMRIGHT", -13, 1)
	bar:SetOrientation("HORIZONTAL")
	bar:SetMinMaxValues(min, max)
	bar:SetValueStep(step)
	bar:SetObeyStepOnDrag(true)
	for _, part in ipairs({ { "Minimal_SliderBar_Left", "LEFT" }, { "Minimal_SliderBar_Right", "RIGHT" } }) do
		local cap = bar:CreateTexture(nil, "BACKGROUND")
		cap:SetAtlas(part[1])
		cap:SetSize(11, 17)
		cap:SetPoint(part[2])
	end
	local middle = bar:CreateTexture(nil, "BACKGROUND")
	middle:SetAtlas("_Minimal_SliderBar_Middle")
	middle:SetPoint("TOPLEFT", 11, 0)
	middle:SetPoint("BOTTOMRIGHT", -11, 0)
	local thumb = bar:CreateTexture(nil, "ARTWORK")
	thumb:SetAtlas("Minimal_SliderBar_Button")
	thumb:SetSize(20, 19)
	bar:SetThumbTexture(thumb)
	-- Set moves the thumb quietly; only a drag reaches onSet. Values round to hundredths, so steps never drift.
	bar:SetScript("OnValueChanged", function(_, value)
		if not slider.quiet then onSet(math.floor(value * 100 + 0.5) / 100) end
	end)
	slider.bar = bar
	function slider.SetRange(_, low, high, by)
		slider.quiet = true
		bar:SetMinMaxValues(low, high)
		bar:SetValueStep(by)
		slider.quiet = nil
	end
	slider.value = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slider.value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
	function slider.Set(_, value, text)
		slider.quiet = true
		bar:SetValue(value)
		slider.quiet = nil
		slider.value:SetText(text or value)
	end
	function slider.SetEnabledState(_, on)
		for _, button in pairs(slider.steppers) do button:SetEnabled(on) end
		bar:EnableMouse(on)
		slider:SetAlpha(on and 1 or 0.5)
	end
	return slider
end

-- A vertical scroll bar (MinimalScrollBar's art and geometry) on our own frames. onScroll(top) from an arrow, a thumb
-- drag, a track click or the wheel; the caller clamps it and redraws. bar:Set(top, visible, total) shows the bar
-- only while rows are out of view.
local BAR_W, BAR_END, BAR_THUMB = 8, 19, 23

function UI.ScrollBar(parent, height, onScroll)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetSize(BAR_W, height)
	bar.top = 0
	local track = CreateFrame("Slider", nil, bar)
	track:EnableMouse(true)
	track:SetOrientation("VERTICAL")
	track:SetPoint("TOPLEFT", 0, -BAR_END)
	track:SetPoint("BOTTOMRIGHT", 0, BAR_END)
	track:SetValueStep(1)
	track:SetObeyStepOnDrag(true)
	local function art(region, layer, name, tile)
		local first, last, middle = track:CreateTexture(nil, layer), track:CreateTexture(nil, layer), track:CreateTexture(nil, layer)
		first:SetAtlas(name .. "-top", true)
		first:SetPoint("TOPLEFT", region)
		last:SetAtlas(name .. "-bottom", true)
		last:SetPoint("BOTTOMLEFT", region)
		middle:SetAtlas((tile or "") .. name .. "-middle", true)
		middle:SetPoint("TOPLEFT", first, "BOTTOMLEFT")
		middle:SetPoint("BOTTOMRIGHT", last, "TOPRIGHT")
	end
	art(track, "BACKGROUND", "minimal-scrollbar-track", "!")
	local thumb = track:CreateTexture(nil, "ARTWORK")
	thumb:SetColorTexture(0, 0, 0, 0)
	thumb:SetSize(BAR_W, BAR_THUMB)
	track:SetThumbTexture(thumb)
	art(thumb, "ARTWORK", "minimal-scrollbar-small-thumb")
	track:SetScript("OnValueChanged", function(_, value) if not bar.quiet then onScroll(math.floor(value + 0.5)) end end)
	bar.arrows = {}
	for step, name in pairs({ [-1] = "top", [1] = "bottom" }) do
		local button = CreateFrame("Button", nil, bar)
		button:SetSize(17, 11)
		button:SetPoint(step < 0 and "TOP" or "BOTTOM")
		button.icon = button:CreateTexture(nil, "BACKGROUND")
		button.icon:SetAtlas("minimal-scrollbar-arrow-" .. name)
		button.icon:SetAllPoints()
		button:SetHighlightAtlas("minimal-scrollbar-arrow-" .. name .. "-over", "BLEND")
		button:SetPushedAtlas("minimal-scrollbar-arrow-" .. name .. "-down")
		button:SetScript("OnClick", function() onScroll(bar.top + step) end)
		bar.arrows[step] = button
	end
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(_, delta) onScroll(bar.top - delta) end)
	function bar.Set(_, top, visible, total)
		local last = math.max(0, total - visible)
		bar.top = top
		bar:SetShown(last > 0)
		if last == 0 then return false end
		bar.quiet = true
		track:SetMinMaxValues(0, last)
		track:SetValue(top)
		bar.quiet = nil
		thumb:SetHeight(math.max(BAR_THUMB, (height - 2 * BAR_END) * visible / total))
		for step, button in pairs(bar.arrows) do
			local live = step < 0 and top > 0 or step > 0 and top < last
			button:SetEnabled(live)
			button.icon:SetDesaturated(not live)
		end
		return true
	end
	return bar
end

-- A row click: the left button does what A does (row.onClick), the right one what X or Y does (row.onRightClick).
function UI.RowClick(row, button)
	UI.NoteInput("mouse")
	local fn = button == "RightButton" and row.onRightClick or button ~= "RightButton" and row.onClick
	if fn then fn() end
end

-- The focus wash shows for pad and keyboard focus; a mouse hover has the row's own highlight.
function UI.ShowWash()
	local window = UI.Current and UI.Current()
	return UI.Pad() or not (window and window.byHover)
end

-- The row's focus look: its own wash plus the control's hover art.
function UI.RowFocus(row)
	return function(focused)
		row.wash:SetShown(focused and UI.ShowWash())
		if row.control and row.control.SetFocused then row.control:SetFocused(focused) end
	end
end

-- A native atlas drawn wider than its own size without stretching its ends: the atlas's file and coordinates (from
-- C_Texture.GetAtlasInfo) cut into a left end and a right end cap pixels wide and a middle that stretches. Returns the
-- three textures, or nil when the atlas is unknown (no art at all, rather than a stand-in).
function UI.ThreeSlice(frame, atlas, cap)
	local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
	local file = ok and type(info) == "table" and (info.file or info.filename)
	if not (file and info.width and info.width > 2 * cap) then return end

	local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local capCoord = (right - left) * cap / info.width
	local slices = {}
	for i, spec in ipairs({ { left, left + capCoord }, { left + capCoord, right - capCoord }, { right - capCoord, right } }) do
		local tex = frame:CreateTexture(nil, "BACKGROUND")
		tex:SetTexture(file)
		tex:SetTexCoord(spec[1], spec[2], top, bottom)
		slices[i] = tex
	end
	slices[1]:SetPoint("TOPLEFT")
	slices[1]:SetPoint("BOTTOMLEFT")
	slices[1]:SetWidth(cap)
	slices[3]:SetPoint("TOPRIGHT")
	slices[3]:SetPoint("BOTTOMRIGHT")
	slices[3]:SetWidth(cap)
	slices[2]:SetPoint("TOPLEFT", slices[1], "TOPRIGHT")
	slices[2]:SetPoint("BOTTOMRIGHT", slices[3], "BOTTOMLEFT")
	return slices
end

-- A small native button for a row's own actions (SharedButtonSmallTemplate, 22 tall), sized to its label as the
-- dialog's buttons are. button.action is called on a click; draw code sets it.
local SMALL_H, SMALL_PAD, SMALL_MIN = 22, 24, 56

function UI.SmallButton(parent, text)
	local button = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate")
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)
	button:SetText(text)
	button:SetSize(math.max(SMALL_MIN, (button:GetTextWidth() or 0) + SMALL_PAD), SMALL_H)
	button:SetScript("OnClick", function(self)
		UI.NoteInput("mouse")
		if self.action then self.action() end
	end)
	return button
end

-- A small icon button (native icon atlas, its own highlight); tip = { title, lines } on hover. button.action on click.
function UI.IconButton(parent, atlas, size, tip)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAtlas(atlas)
	button.icon:SetAllPoints()
	button:SetHighlightAtlas(atlas, "ADD")
	button:SetScript("OnClick", function(self)
		UI.NoteInput("mouse")
		if self.action then self.action() end
	end)
	button:SetScript("OnEnter", function(self) UI.Tooltip(self, tip) end)
	button:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
	return button
end

-- A modal list in native dropdown art (common-dropdown-bg, UI-Character-Info-Title header, UI-QuestTitleHighlight
-- focus, radial tick and gold text on the current entry), FCT's action picker in list mode; opts.below opens it under
-- a dropdown button, as a dropdown's menu (opts.width wide, no title), opts.returnTo gets the focus back. D-pad up/down moves (hold repeats,
-- wraps), A chooses, B closes; mouse hover, click, wheel, a click outside closes. The focused entry's detail shows
-- beside it. opts = { window, cell (focus returns there), title, entries = { { id, name, note, detail, disabled } },
-- current = id, onPick(entry) }. A disabled entry only shows its detail.
local List = {}
UI.List = List

local LIST_ROWS, LIST_ROW_H, LIST_W, LIST_HEADER = 12, 24, 320, 44
local listFrame, state

local function listRow(i)
	local r = listFrame.rows[i]
	if r then return r end

	r = CreateFrame("Button", nil, listFrame)
	r:SetHeight(LIST_ROW_H)
	r.highlight = r:CreateTexture(nil, "BACKGROUND")
	r.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	r.highlight:SetBlendMode("ADD")
	r.highlight:SetAllPoints()
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.name:SetPoint("LEFT", 10, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.note = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.note:SetPoint("RIGHT", -24, 0)
	r.tick = r:CreateTexture(nil, "OVERLAY")
	r.tick:SetAtlas("common-dropdown-icon-radialtick-yellow")
	r.tick:SetSize(16, 16)
	r.tick:SetPoint("RIGHT", -4, 0)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetScript("OnEnter", function(self) if UI.NoteHover() and self.index then List.Focus(self.index) end end)
	r:SetScript("OnClick", function(self, button)
		UI.NoteInput("mouse")
		if button == "RightButton" then return List.Close() end
		if self.index then List.Choose(self.index) end
	end)
	listFrame.rows[i] = r
	return r
end

local function listDraw()
	local entries = state.entries
	listFrame.header.text:SetText(state.title or "")
	local total = #entries
	state.offset = math.max(0, math.min(state.offset, total - LIST_ROWS))
	if state.index <= state.offset then state.offset = state.index - 1 end
	if state.index > state.offset + LIST_ROWS then state.offset = state.index - LIST_ROWS end

	for i = 1, LIST_ROWS do
		local r, index = listRow(i), state.offset + i
		local entry = entries[index]
		r.index = entry and index or nil
		r:SetShown(entry ~= nil)
		if entry then
			r.name:SetText(entry.name)
			local current = state.current ~= nil and entry.id == state.current
			r.name:SetFontObject(entry.disabled and "GameFontDisable" or current and "GameFontNormal" or "GameFontHighlight")
			r.name:SetWidth(state.width - 20 - 40 - (entry.note and 110 or 0))
			r.note:SetText(entry.note or "")
			r.tick:SetShown(current)
			r.highlight:SetShown(index == state.index)
		end
	end
	listFrame.up:SetShown(state.offset > 0)
	listFrame.down:SetShown(state.offset + LIST_ROWS < total)

	local focused = listFrame.rows[state.index - state.offset]
	if focused then state.window.cursor:Attach(focused, 0) end
	local entry = entries[state.index]
	if entry and entry.detail then UI.Tooltip(listFrame, { title = entry.name, lines = { entry.detail }, side = state.side }) else UI.HideTooltip() end
end

function List.Focus(index)
	state.index = index
	listDraw()
end

function List.Move(_, dx, dy)
	if dy == 0 then return end
	state.index = (state.index - (dy > 0 and 1 or -1) - 1) % #state.entries + 1
	listDraw()
end

function List.Choose(index)
	local entry = state.entries[index]
	if not entry or entry.disabled then return end
	local pick = state.onPick
	List.Close()
	pick(entry)
end

function List.OnPad(_, key)
	if key == "PAD1" then return List.Choose(state.index) end
	if key == "PAD2" then return List.Close() end
	local dir = key == "PADDUP" and 1 or key == "PADDDOWN" and -1
	if not dir then return end
	local window = state.window
	window.repeatKey = key
	window:StartRepeat({ 0, dir })
end

function List.IsOpen() return state ~= nil end

function List.Redraw() if state then listDraw() end end

function List.Frame() return listFrame end

local function createList()
	listFrame = CreateFrame("Frame", nil, UIParent)
	listFrame:SetSize(LIST_W, LIST_HEADER + LIST_ROWS * LIST_ROW_H + 12)
	listFrame:SetClampedToScreen(true)
	listFrame:EnableMouse(true)
	listFrame:EnableMouseWheel(true)
	listFrame:SetScript("OnMouseWheel", function(_, delta)
		state.offset = math.max(0, math.min(state.offset - delta * 3, math.max(0, #state.entries - LIST_ROWS)))
		if state.index <= state.offset or state.index > state.offset + LIST_ROWS then state.index = state.offset + 1 end
		listDraw()
	end)
	local bg = listFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAtlas("common-dropdown-bg")
	bg:SetAlpha(0.925)
	bg:SetPoint("TOPLEFT", -10, 3)
	bg:SetPoint("BOTTOMRIGHT", 10, -3)
	listFrame.header = UI.SectionHeader(listFrame, 0, 2, LIST_W, "")
	listFrame.header.text:SetWordWrap(false)
	listFrame.up = listFrame:CreateTexture(nil, "OVERLAY")
	listFrame.up:SetAtlas("minimal-scrollbar-arrow-top", true)
	listFrame.up:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -LIST_HEADER + 2)
	listFrame.down = listFrame:CreateTexture(nil, "OVERLAY")
	listFrame.down:SetAtlas("minimal-scrollbar-arrow-bottom", true)
	listFrame.down:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -2, 4)
	listFrame.rows = {}
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetScript("OnClick", function() List.Close() end)
	catcher:Hide()
	listFrame.catcher = catcher
	listFrame:Hide()
end

function List.Open(opts)
	if not listFrame then createList() end
	if state then List.Close() end

	local width, top = opts.width or LIST_W, opts.title and LIST_HEADER or 8
	state = { window = opts.window, cell = opts.cell, returnTo = opts.returnTo or opts.cell, title = opts.title, entries = opts.entries, current = opts.current, onPick = opts.onPick, onClose = opts.onClose, width = width, index = 1, offset = 0 }
	for i, entry in ipairs(opts.entries) do if entry.id == opts.current then state.index = i end end
	listFrame:SetSize(width, top + math.min(LIST_ROWS, #opts.entries) * LIST_ROW_H + 8 + (opts.title and 4 or 0))
	listFrame.header:SetShown(opts.title ~= nil)
	listFrame.header:SetWidth(width)
	for i = 1, LIST_ROWS do
		local r = listRow(i)
		r:SetWidth(width - 20)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 10, -(top + (i - 1) * LIST_ROW_H))
	end
	listFrame.up:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -top + 2)
	local window, cell = state.window, opts.cell
	local cellX, windowX = cell:GetCenter() or 0, window:GetCenter() or 0
	listFrame:SetScale(window:GetScale())
	listFrame:ClearAllPoints()
	if opts.below then
		listFrame:SetPoint("TOPLEFT", cell, "BOTTOMLEFT", 0, -4)
		state.side = "right"
	elseif cellX <= windowX then
		listFrame:SetPoint("TOPLEFT", cell, "TOPRIGHT", 8, 0)
		state.side = "right"
	else
		listFrame:SetPoint("TOPRIGHT", cell, "TOPLEFT", -8, 0)
		state.side = "left"
	end
	listFrame.catcher:Show()
	UI.RaiseAbove(listFrame.catcher, window, "catcher")
	UI.RaiseAbove(listFrame, window, "picker")
	listFrame:Show()
	window.modal = List
	UI.HideTooltip()
	window:SetPrompts({ { "PAD1", L.SELECT }, { "PAD2", L.BACK } })
	listDraw()
end

-- Closing returns the focus to the cell and redraws the window.
function List.Close()
	if not state then return end
	local window, cell, onClose = state.window, state.returnTo, state.onClose
	state = nil
	listFrame:Hide()
	listFrame.catcher:Hide()
	UI.HideTooltip()
	window.modal = nil
	window.focus = { region = cell }
	if onClose then onClose() end
	if window:IsShown() then window:Refresh() end
end

-- A small name box in the dialog's art with a native InputBoxTemplate EditBox (its scripts only clear focus and
-- highlight text). Keyboard and mouse: Enter or OK accepts, Esc or Cancel closes; on the pad A accepts the shown
-- name, B cancels. The box takes keyboard focus only while open and gives it back on close.
-- opts = { window, cell, title, text, onOK(name) }.
local Name = {}
UI.Name = Name
local nameFrame, nameState

function Name.Close(accept)
	if not nameState then return end
	local opts, text = nameState, nameFrame.edit:GetText()
	nameState = nil
	nameFrame.edit:ClearFocus()
	nameFrame:Hide()
	local window = opts.window
	window.modal = nil
	window.focus = { region = opts.cell }
	if accept and text and text:match("%S") then opts.onOK(text) end
	if window:IsShown() then window:Refresh() end
end

function Name.Move() end

function Name.OnPad(_, key)
	if key == "PAD1" then return Name.Close(true) end
	if key == "PAD2" then return Name.Close(false) end
end

function Name.IsOpen() return nameState ~= nil end

local NAME_MAX = 32

local function createName()
	nameFrame = CreateFrame("Frame", nil, UIParent)
	nameFrame:SetSize(320, 130)
	nameFrame:EnableMouse(true)
	nameFrame:Hide()
	UI.DialogArt(nameFrame)
	nameFrame.glow = UI.Glow(nameFrame, nameFrame, "gamepad-uiframediamondmetal-focus-large", -6, 6, 6, -6)
	nameFrame:SetScript("OnShow", function(self) self.glow:Show() end)
	nameFrame:SetScript("OnHide", function(self) self.glow:Hide() end)
	nameFrame.title = nameFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	nameFrame.title:SetPoint("TOP", 0, -16)
	local edit = CreateFrame("EditBox", nil, nameFrame, "InputBoxTemplate")
	edit:SetAutoFocus(false)
	edit:SetSize(240, 20)
	edit:SetPoint("TOP", 0, -42)
	edit:SetMaxLetters(NAME_MAX)
	edit:SetScript("OnEnterPressed", function() Name.Close(true) end)
	edit:SetScript("OnEscapePressed", function() Name.Close(false) end)
	nameFrame.edit = edit
	nameFrame.hint = nameFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	nameFrame.hint:SetPoint("TOP", edit, "BOTTOM", 0, -6)
	nameFrame.hint:SetText(L.NAME_HINT)
	for index, spec in ipairs({ { L.OK, true, "BOTTOMRIGHT", -6.5 }, { L.CANCEL, false, "BOTTOMLEFT", 6.5 } }) do
		local button = UI.DialogButton(nameFrame)
		button:SetPoint(spec[3], nameFrame, "BOTTOM", spec[4], 16)
		button:SetText(spec[1])
		button:SetScript("OnClick", function() Name.Close(spec[2]) end)
		nameFrame["Button" .. index] = button
	end
end

function Name.Open(opts)
	if not nameFrame then createName() end
	if nameState then Name.Close(false) end

	nameState = opts
	local window = opts.window
	nameFrame.title:SetText(opts.title)
	nameFrame.edit:SetText(opts.text or "")
	nameFrame:SetScale(window:GetScale())
	nameFrame:ClearAllPoints()
	nameFrame:SetPoint("TOP", window, "TOPLEFT", window:GetWidth() / 2, -210)
	UI.RaiseAbove(nameFrame, window, "dialog")
	UI.HideTooltip()
	nameFrame:Show()
	window.modal = Name
	window:SetPrompts({ { "PAD1", L.OK }, { "PAD2", L.CANCEL } })
	window.cursor:Attach(nameFrame.Button1, CURSOR_OUTSIDE)
	nameFrame.edit:SetFocus()
	nameFrame.edit:HighlightText()
end

-- The next free "Profile N" name: gamepad users get one without typing.
function UI.AutoName()
	local taken = {}
	for _, profile in ipairs(ns.Profiles.List()) do taken[profile.name] = true end
	local n = 1
	while taken[string.format(L.AUTO_NAME, n)] do n = n + 1 end
	return string.format(L.AUTO_NAME, n)
end

-- Smart mode's two settings, each a list of { key, name, desc } from the engine: Goal (what it holds: FPS, Balanced,
-- Fidelity; db.smart.goal, per location type db.smart.goals) and Pace (how eagerly it changes: Aggressive, Balanced,
-- Smooth; db.smart.pace, global). Helpers: the list, an entry by key, the chosen one, the dropdown entries (each
-- desc shows on hover), and what is in use where you are.
local PICKERS = {
	goal = { list = "GOALS", field = "goal", set = "SetGoal", label = "GOAL", tip = "GOAL_TIP", current = "Goal" },
	pace = { list = "PACES", field = "pace", set = "SetPace", label = "PACE", tip = "PACE_TIP", current = "Pace" },
}

function UI.SmartList(kind)
	local smart = ns.Smart
	return smart and smart[PICKERS[kind].list] or nil
end

function UI.SmartEntry(kind, key)
	for _, entry in ipairs(UI.SmartList(kind) or {}) do if entry.key == key then return entry end end
end

function UI.SmartChoice(kind) return UI.SmartEntry(kind, ns.db.smart[PICKERS[kind].field]) or (UI.SmartList(kind) or {})[1] end

function UI.SmartEntries(kind)
	local entries = {}
	for i, entry in ipairs(UI.SmartList(kind) or {}) do entries[i] = { id = entry.key, name = entry.name, detail = entry.desc } end
	return entries
end

-- The goal and pace in use here (the goal can be the location type's own).
function UI.SmartInUse(kind)
	local smart = ns.Smart
	local get = smart and smart[PICKERS[kind].current]
	if not get then return UI.SmartChoice(kind) end
	local loc = ns.Location.Current() or {}
	local ok, key = pcall(get, loc.key)
	return ok and UI.SmartEntry(kind, key) or UI.SmartChoice(kind)
end

-- "Balanced · Smooth": the goal and pace in use, for the strip, the notices and the Smart page.
function UI.SmartStyle()
	local goal, pace = UI.SmartInUse("goal"), UI.SmartInUse("pace")
	local parts = {}
	if goal then parts[#parts + 1] = goal.name end
	if pace and pace.name ~= (goal and goal.name) then parts[#parts + 1] = pace.name end
	return table.concat(parts, " · ")
end

-- A Goal or Pace row: its dropdown, its desc on a grey line under it, a tooltip listing every choice. picker:Draw(flow,
-- nodes, enabled) lays it out and adds its focus node when enabled; refresh() redraws the page after a pick.
function UI.SmartPicker(window, content, kind, refresh)
	local spec = PICKERS[kind]
	local row = UI.SettingRow(content, L[spec.label])
	local function current() return UI.SmartChoice(kind) end
	local function set(key)
		ns.Smart[spec.set](key)
		refresh()
	end
	local function index()
		for i, entry in ipairs(UI.SmartList(kind) or {}) do if entry == current() then return i end end
		return 0
	end
	local function step(dir)
		local nextEntry = (UI.SmartList(kind) or {})[index() + dir]
		if not nextEntry then return false end
		set(nextEntry.key)
	end
	local function open()
		local entry = current()
		UI.OpenChoice(window, row.choice, UI.SmartEntries(kind), entry and entry.key, function(picked) set(picked.id) end)
	end
	UI.RowChoice(row, step, open)
	row.onClick = open
	row.desc = UI.Description(content, "GameFontHighlightSmall")
	row.desc:SetTextColor(0.65, 0.65, 0.65)
	row.pickerKind = kind
	function row.Draw(flow, nodes, enabled)
		local N = UI.N
		local list, entry = UI.SmartList(kind) or {}, current()
		local at = index()
		row.choice:Set(entry and entry.name or "-", at <= 1, at >= #list)
		UI.SetRowEnabled(row, enabled)
		flow:Add(row, N.ROW_H, 2)
		row.desc:SetText(entry and entry.desc or "")
		flow:Add(row.desc, row.desc:GetStringHeight(), N.ROW_GAP, N.CENTER + N.DROP_X + 22 + 8)
		if not enabled then return end
		local lines = { L[spec.tip] }
		for _, e in ipairs(list) do lines[#lines + 1] = string.format(L.MODE_LINE, e.name, e.desc or "") end
		nodes[#nodes + 1] = UI.Node(window, row, open, { cursorX = N.LABEL_X - 6, noSide = true, onFocus = UI.RowFocus(row), tipRegion = row.tipAnchor, tip = { title = L[spec.label], lines = lines, side = "above" }, onDir = step, picker = kind })
	end
	return row
end

-- Smart mode's status as shown: "Pre-adjusted for <area>" when it lowered settings ahead of a place that lagged.
function UI.SmartStatus(state)
	if state.status ~= "pre-adjusted" then return state.status or "off" end
	local area = state.area
	return area and area.name and string.format(L.PRE_ADJUSTED, area.name) or L.PRE_ADJUSTED_SHORT
end

-- A location key's label: a type's name, else a specific place's saved name.
function UI.PlaceLabel(key)
	local label = ns.Location.LABELS[key]
	if label then return label end
	local override = ns.db.overrides[key]
	return override and override.name or tostring(key)
end

-- The native Settings panel, rebuilt on our own frames (its templates register with Settings and CallbackRegistry).
-- Every number is Blizzard's; the report lists each with its file and line (Blizzard_Settings_Shared).
local N = {
	W = 920, H = 724, LIST_X = 18, LIST_Y = 76, LIST_W = 199, BOTTOM = 46, LIST_GAP = 16, RIGHT = 22,
	HEADER_H = 50, TITLE_X = 7, TITLE_Y = 22, PAD_TOP = 10, PAD_LEFT = 25, ROW_H = 26, ROW_GAP = 9, SECTION_H = 45,
	SECTION_TITLE_Y = 16, LABEL_X = 37, LABEL_END = -85, CHECK_X = -80, SLIDER_X = -80, SLIDER_W = 250, DROP_X = -48,
	DROP_W = 220, HOVER_LEFT = -10, HOVER_RIGHT = -5, TIP_X = -10, TIP_CUT = 80,
	CAT_W = 175, CAT_H = 20, CAT_HEADER_H = 30, CAT_GAP = 2, CAT_SPACER = 18, CAT_LABEL_X = 36, CAT_HEADER_X = 20,
	CAT_INDENT = 10, BUTTON_W = 96, BUTTON_H = 22, CLOSE_X = -16, CLOSE_Y = 16, BAR_W = 16,
}
N.CONTAINER_X = N.LIST_X + N.LIST_W + N.LIST_GAP
N.CONTAINER_W = N.W - N.CONTAINER_X - N.RIGHT
N.CONTAINER_H = N.H - N.LIST_Y - N.BOTTOM
N.ROW_W = N.CONTAINER_W - N.PAD_LEFT - N.BAR_W
N.CENTER = N.ROW_W / 2
-- Ours, right of the native control column: the reset icon and the FPS impact column.
N.RESET_X, N.IMPACT_X = N.ROW_W - 92, N.ROW_W - 68
N.IMPACT_W = N.ROW_W - N.IMPACT_X
UI.N = N

-- A page's content laid out top down as the native settings list does (10 in, rows 26 tall and 9 apart, 25 from the
-- left). flow:Start(), then flow:Add(region, height[, gap]) in order, then flow:Finish() hides what was not added. A
-- region is re-anchored only when its place changed (a button moved under the pointer drops its click).
local Flow = {}

function UI.Flow(content) return Mixin({ content = content, all = {}, placed = {} }, Flow) end

function Flow:Start()
	self.y, self.placed = N.PAD_TOP, {}
end

function Flow:Add(region, height, gap, x)
	self.all[region], self.placed[region] = true, true
	local left = N.PAD_LEFT + (x or 0)
	if region.flowY ~= self.y or region.flowX ~= left then
		region.flowY, region.flowX = self.y, left
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", self.content, "TOPLEFT", left, -self.y)
	end
	region:Show()
	self.y = self.y + height + (gap or N.ROW_GAP)
	return region
end

function Flow:Finish()
	for region in pairs(self.all) do if not self.placed[region] then region:Hide() end end
	self.content:SetHeight(self.y + N.PAD_TOP)
end

-- A section header (SettingsListSectionHeaderTemplate: 45 tall, GameFontHighlightLarge at 7, -16). impact adds the
-- "FPS impact" column header over the rows' impact column.
function UI.Section(parent, text, impact)
	local section = CreateFrame("Frame", nil, parent)
	section:SetSize(N.ROW_W, N.SECTION_H)
	section.title = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	section.title:SetPoint("TOPLEFT", N.TITLE_X, -N.SECTION_TITLE_Y)
	section.title:SetJustifyH("LEFT")
	section.title:SetText(text or "")
	if impact then
		section.impact = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		section.impact:SetPoint("BOTTOMLEFT", N.IMPACT_X, 2)
		section.impact:SetWidth(N.IMPACT_W)
		section.impact:SetJustifyH("CENTER")
		section.impact:SetText(L.COLUMN_IMPACT)
	end
	return section
end

-- A settings row (SettingsListElementTemplate): label in GameFontNormal from x 37 to 85 left of centre, the white 10%
-- hover background from 10 left of the row to 5 short of its right, the tooltip beside the label half. It is a button
-- here so a click on the label acts (row.onClick, row.onRightClick); the focus shows the same background.
function UI.SettingRow(parent, text)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(N.ROW_W, N.ROW_H)
	for _, key in ipairs({ "hover", "wash" }) do
		local tex = row:CreateTexture(nil, "BACKGROUND")
		tex:SetColorTexture(1, 1, 1, 0.1)
		tex:SetPoint("TOPLEFT", N.HOVER_LEFT, 0)
		tex:SetPoint("BOTTOMRIGHT", N.HOVER_RIGHT, 0)
		tex:Hide()
		row[key] = tex
	end
	row:SetScript("OnEnter", function(self) self.hover:Show() end)
	row:SetScript("OnLeave", function(self) self.hover:Hide() end)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", N.LABEL_X, 0)
	row.label:SetWidth(N.CENTER + N.LABEL_END - N.LABEL_X)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetText(text or "")
	row.tipAnchor = CreateFrame("Frame", nil, row)
	row.tipAnchor:SetPoint("TOPLEFT")
	row.tipAnchor:SetSize(N.CENTER - N.TIP_CUT, N.ROW_H)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", UI.RowClick)
	return row
end

function UI.RowCheckbox(row, onClick)
	row.control = UI.Checkbox(row, onClick)
	row.control:SetPoint("LEFT", row, "CENTER", N.CHECK_X, 0)
	return row.control
end

function UI.RowSlider(row, min, max, step, onStep, onSet)
	row.slider = UI.Slider(row, N.SLIDER_W, min, max, step, onStep, onSet)
	row.slider:SetPoint("LEFT", row, "CENTER", N.SLIDER_X, 3)
	row.control = row.slider
	return row.slider
end

-- x and width place a second (or narrower) dropdown in the row: its left edge x from the row's left, its box width.
function UI.RowChoice(row, onStep, onOpen, x, width)
	local choice = UI.Choice(row, width or N.DROP_W, onStep, onOpen)
	if x then choice:SetPoint("LEFT", row, "LEFT", x, 3) else choice:SetPoint("LEFT", row, "CENTER", N.DROP_X, 3) end
	if not x then row.choice, row.control = choice, choice end
	return choice
end

-- A grey hint right of a row's control (or at x from the row's left).
function UI.RowHint(row, text, anchor, x)
	row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	if anchor then row.hint:SetPoint("LEFT", anchor, "RIGHT", 8, 0) else row.hint:SetPoint("LEFT", row, "LEFT", x, 0) end
	row.hint:SetJustifyH("LEFT")
	row.hint:SetText(text or "")
	return row.hint
end

-- Greys a row and its controls (they keep showing their value) or brings them back.
function UI.SetRowEnabled(row, on)
	row.label:SetFontObject(on and "GameFontNormal" or "GameFontDisable")
	for _, control in ipairs({ row.control, row.second, row.button }) do
		if control and control.SetEnabledState then control:SetEnabledState(on) elseif control and control.SetEnabled then control:SetEnabled(on) end
	end
	row.disabled = not on
end

-- A fold section (a section header that shows or hides its rows): a plus/minus toggle at 7 (the native category
-- toggle's art), the title moved to 25, a grey count after it, optional column captions on its bottom edge. Its state
-- lives for the session in UI.Folded[key]; open is the first state when nothing is remembered.
UI.Folded = {}

function UI.FoldSection(parent, key, text, captions)
	local fold = CreateFrame("Button", nil, parent)
	fold:SetSize(N.ROW_W, N.SECTION_H)
	fold.key = key
	fold.toggle = fold:CreateTexture(nil, "ARTWORK")
	fold.toggle:SetSize(14, 14)
	fold.toggle:SetPoint("TOPLEFT", N.TITLE_X, -N.SECTION_TITLE_Y - 2)
	fold.title = fold:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	fold.title:SetPoint("TOPLEFT", N.TITLE_X + 18, -N.SECTION_TITLE_Y)
	fold.title:SetText(text)
	fold.count = fold:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	fold.count:SetPoint("LEFT", fold.title, "RIGHT", 8, -1)
	fold.wash = fold:CreateTexture(nil, "BACKGROUND")
	fold.wash:SetColorTexture(1, 1, 1, 0.1)
	fold.wash:SetPoint("TOPLEFT", N.HOVER_LEFT, -8)
	fold.wash:SetPoint("BOTTOMRIGHT", N.HOVER_RIGHT, 4)
	fold.wash:Hide()
	fold.hover = fold.wash
	fold:SetScript("OnEnter", function(self) self.wash:Show() end)
	fold:SetScript("OnLeave", function(self) self.wash:Hide() end)
	if captions then
		fold.valueCaption = fold:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fold.valueCaption:SetPoint("BOTTOMLEFT", N.CENTER + N.SLIDER_X, 2)
		fold.valueCaption:SetText(L.COLUMN_VALUE_SHORT)
		fold.impact = fold:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fold.impact:SetPoint("BOTTOMLEFT", N.IMPACT_X, 2)
		fold.impact:SetWidth(N.IMPACT_W)
		fold.impact:SetJustifyH("CENTER")
		fold.impact:SetText(L.COLUMN_IMPACT)
	end
	function fold.IsOpen() return not UI.Folded[key] end
	function fold.Paint()
		fold.toggle:SetTexture(fold.IsOpen() and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
	end
	function fold.Toggle()
		UI.Folded[key] = fold.IsOpen()
		fold.Paint()
		if fold.onToggle then fold.onToggle() end
	end
	fold:SetScript("OnClick", function()
		UI.NoteInput("mouse")
		fold.Toggle()
	end)
	fold.Paint()
	return fold
end

-- A page's notice: a dark band with a gold edge, text from 37 and its buttons right-aligned 8 from the edge.
-- banner:Set(text, buttons = { { label, fn, enabled } }) lays it out and returns its height.
local BANNER_MIN, BANNER_PAD = 40, 10

function UI.Banner(parent)
	local banner = CreateFrame("Frame", nil, parent)
	banner:SetSize(N.ROW_W - 10, BANNER_MIN)
	local bg = banner:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0, 0, 0, 0.45)
	bg:SetAllPoints()
	local edge = banner:CreateTexture(nil, "ARTWORK")
	edge:SetColorTexture(1, 0.5, 0.15, 0.9)
	edge:SetPoint("TOPLEFT")
	edge:SetPoint("BOTTOMLEFT")
	edge:SetWidth(3)
	banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	banner.text:SetPoint("TOPLEFT", N.LABEL_X, -BANNER_PAD)
	banner.text:SetJustifyH("LEFT")
	banner.buttons = {}
	function banner.Set(_, text, specs)
		local x = -8
		for i = #specs + 1, #banner.buttons do banner.buttons[i]:Hide() end
		for i = #specs, 1, -1 do
			local spec = specs[i]
			local button = banner.buttons[i] or UI.SmallButton(banner, spec[1])
			banner.buttons[i] = button
			button:SetText(spec[1])
			button:SetWidth(math.max(56, (button:GetTextWidth() or 0) + 24))
			button:ClearAllPoints()
			button:SetPoint("TOPRIGHT", banner, "TOPRIGHT", x, -9)
			button:SetEnabled(spec[3] ~= false)
			button.action = spec[2]
			button:Show()
			x = x - button:GetWidth() - 6
		end
		banner.text:SetWidth(N.ROW_W - 10 - N.LABEL_X + x - 8)
		banner.text:SetText(text)
		local height = math.max(BANNER_MIN, banner.text:GetStringHeight() + 2 * BANNER_PAD)
		banner:SetHeight(height)
		return height
	end
	return banner
end


-- A row's own action buttons at its right end, right to left from labels' last; returns the buttons in order.
function UI.RowButtons(row, labels)
	local buttons, x = {}, -8
	for i = #labels, 1, -1 do
		local button = UI.SmallButton(row, labels[i])
		button:SetPoint("RIGHT", row, "RIGHT", x, 0)
		x = x - button:GetWidth() - 6
		buttons[i] = button
	end
	row.buttons = buttons
	return buttons
end

-- A line of native buttons from the label column, left to right; returns the frame (frame.buttons[i]).
function UI.ButtonLine(parent, labels)
	local line = CreateFrame("Frame", nil, parent)
	line:SetSize(N.ROW_W, N.BUTTON_H)
	line.buttons = {}
	local x = N.LABEL_X
	for i, label in ipairs(labels) do
		local button = UI.SmallButton(line, label)
		button:SetPoint("LEFT", line, "LEFT", x, 0)
		x = x + button:GetWidth() + 6
		line.buttons[i] = button
	end
	return line
end

-- Description text under a section, wrapped to the row; add it to a flow at x = N.LABEL_X.
function UI.Description(parent, font)
	local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	text:SetWidth(N.ROW_W - N.LABEL_X)
	text:SetJustifyH("LEFT")
	return text
end
