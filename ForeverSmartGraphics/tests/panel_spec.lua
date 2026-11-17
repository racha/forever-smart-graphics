-- Settings window, toast and entry points over a stub ns and
-- the panel stub: lua ForeverSmartGraphics/tests/panel_spec.lua. Opens each page, steps a profile row, opens More,
-- renames through the name box, toggles smart mode, shows the toast and presses Apply now, closes on combat, and
-- checks that no Blizzard UI the panel must avoid was touched and no stray global was made.
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local dir = here .. "/.."
local W = dofile(here .. "/panel_stub.lua")
local FILES = { "Panel/Shared.lua", "Panel/Window.lua", "Panel/ProfilesTab.lua", "Panel/LocationsTab.lua", "Panel/SmartTab.lua", "Panel/GeneralTab.lua", "Panel/OverviewTab.lua", "Panel/Toast.lua", "Panel/Calibrate.lua", "Panel/Panel.lua" }

local checks = 0
local function check(ok, msg)
	checks = checks + 1
	if not ok then error("FAIL: " .. msg, 2) end
end

-- The engine as the contract describes it, in memory; calls are recorded.
local function stubNS(withSmart)
	local ns, handlers, calls = { commands = {} }, {}, {}
	ns.calls = calls
	local function call(name, ...) calls[#calls + 1] = { name, ... } end
	function ns.On(event, fn)
		handlers[event] = handlers[event] or {}
		table.insert(handlers[event], fn)
		if event == "FSG_READY" and ns.ready then fn() end
	end
	function ns.Fire(event, ...) for _, fn in ipairs(handlers[event] or {}) do fn(...) end end
	function ns.log(msg) W.log[#W.log + 1] = msg end
	function ns.plain(v) return v end
	function ns.TogglePanel() end

	ns.db = {
		options = { switching = true, debug = false, minimap = { shown = true, angle = 200 } },
		profiles = {
			default = { id = "default", name = "Default", values = { graphicsShadowQuality = 3 } },
			p1 = { id = "p1", name = "City", values = { RenderScale = 0.8 } },
		},
		profileOrder = { "default", "p1" }, nextId = 2,
		locations = { city = "p1" },
		overrides = { ["map:84"] = { profile = "p1", name = "Stormwind City" } },
		smart = { enabled = false, target = 60, scaleFloor = 0.6, goal = "balanced", pace = "balanced", goals = {}, learned = { city = { values = { RenderScale = 0.75 }, gains = { RenderScale = { ema = 5, n = 3 } }, t = 1700000000 } } },
		unsupported = { vrsValar = true },
		limits = { shadowSoft = 0 },
	}
	local db = ns.db

	local LIST = {
		{ cvar = "graphicsShadowQuality", group = "quality", label = "Shadow quality", desc = "How sharp and how far shadows draw.", impact = "medium", kind = "level", min = 0, max = 5, step = 1, names = { [0] = "Low", "Fair", "Good", "High", "Ultra", "Ultra High" } },
		{ cvar = "graphicsTextureResolution", group = "quality", label = "Texture resolution", kind = "level", min = 0, max = 2, step = 1, heavy = true, names = { [0] = "Low", "Good", "High" } },
		{ cvar = "graphicsViewDistance", group = "quality", label = "View distance", kind = "level", min = 0, max = 9, step = 1 },
		{ cvar = "vrsValar", group = "hidden", label = "Variable rate shading", kind = "level", min = 0, max = 2, step = 1, names = { [0] = "Off", "Standard", "Aggressive" } },
		{ cvar = "RenderScale", group = "render", label = "Render scale", kind = "scale", min = 0.33, max = 1, step = 0.05 },
		{ cvar = "shadowSoft", group = "hidden", label = "Soft shadows", kind = "level", min = 0, max = 1, step = 1, names = { [0] = "Off", "On" } },
		{ cvar = "groundEffectDensity", group = "hidden", label = "Grass density", kind = "range", min = 16, max = 256, step = 16 },
		{ cvar = "shadowTextureSize", group = "hidden", label = "Shadow map size", kind = "choice", choices = { 512, 1024, 2048 }, min = 512, max = 2048 },
	}
	-- Enough Detail rows that the editor scrolls.
	for i = 1, 14 do LIST[#LIST + 1] = { cvar = "detail" .. i, group = "hidden", label = "Detail " .. i, kind = "level", min = 0, max = 3, step = 1 } end
	local byName = {}
	for _, entry in ipairs(LIST) do byName[entry.cvar] = entry end
	ns.Catalog = {
		Preset = function(key) for _, p in ipairs(ns.Catalog.PRESETS) do if p.key == key then return p end end end,
		BuildPreset = function(key) local p = ns.Catalog.Preset(key) return p and p.build() end,
		LIST = LIST, GROUPS = { "quality", "render", "hidden" },
		PRESETS = {
			{ key = "low", name = "Low", build = function() return { graphicsShadowQuality = 0, RenderScale = 1 } end },
			{ key = "fair", name = "Fair", build = function() return { graphicsShadowQuality = 1, RenderScale = 1 } end },
			{ key = "good", name = "Good", build = function() return { graphicsShadowQuality = 2, RenderScale = 1 } end },
			{ key = "high", name = "High", build = function() return { graphicsShadowQuality = 3, RenderScale = 1 } end },
			{ key = "ultra", name = "Ultra", build = function() return { graphicsShadowQuality = 4, RenderScale = 1 } end },
			{ key = "beyond", name = "Beyond Ultra", build = function() return { graphicsShadowQuality = 5, RenderScale = 1, shadowSoft = 1 } end },
			{ key = "fps", name = "Max FPS", build = function() return { graphicsShadowQuality = 0, RenderScale = 0.6 } end },
		},
		Same = function(cvar, a, b)
			a, b = tonumber(a), tonumber(b)
			return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6
		end,
		Get = function(cvar) return byName[cvar] end,
		Clamp = function(cvar, v)
			local e = byName[cvar]
			if not e then return nil end
			if e.choices then return e.choices[1] end
			return math.max(e.min, math.min(e.max, math.floor(v / e.step + 0.5) * e.step))
		end,
		Step = function(cvar, v, d)
			local e = byName[cvar]
			if e.choices then
				for i, c in ipairs(e.choices) do if c == v then return e.choices[i + d] end end
				return nil
			end
			local n = math.floor((v + d * e.step) * 100 + 0.5) / 100
			if n < e.min or n > e.max then return nil end
			return n
		end,
		Impact = function(cvar)
			if cvar == "graphicsShadowQuality" then return "high", 11, "measured" end
			if cvar == "RenderScale" then return "very high", nil, "probe" end
			local e = byName[cvar]
			return e and e.impact
		end,
		Format = function(cvar, v)
			if cvar == "RenderScale" then return string.format("%d%%", math.floor(v * 100 + 0.5)) end
			local names = byName[cvar] and byName[cvar].names
			return names and names[v] or tostring(v)
		end,
	}

	local P = {}
	ns.Profiles = P
	function P.List()
		local list = {}
		for _, id in ipairs(db.profileOrder) do list[#list + 1] = { id = id, name = db.profiles[id].name } end
		return list
	end
	function P.Get(id) return db.profiles[id] end
	function P.Create(name, values)
		local id = "p" .. db.nextId
		db.nextId = db.nextId + 1
		db.profiles[id] = { id = id, name = name, values = values or {} }
		db.profileOrder[#db.profileOrder + 1] = id
		call("Create", name)
		return id
	end
	function P.FromPreset(key) call("FromPreset", key) return P.Create(key) end
	function P.FromCurrent(name) call("FromCurrent", name) return P.Create(name) end
	function P.Copy(id) call("Copy", id) return P.Create(db.profiles[id].name .. " 2") end
	function P.Rename(id, name) call("Rename", id, name) db.profiles[id].name = name return name end
	function P.Delete(id)
		call("Delete", id)
		db.profiles[id] = nil
		for i, v in ipairs(db.profileOrder) do if v == id then table.remove(db.profileOrder, i) end end
	end
	function P.SetValue(id, cvar, value) call("SetValue", id, cvar, value) db.profiles[id].values[cvar] = value; ns.Fire("FSG_PROFILES_CHANGED", id) end
	function P.Inherited(id, cvar)
		if id ~= "default" and db.profiles.default.values[cvar] ~= nil then return db.profiles.default.values[cvar], "Default" end
		return 1, "your original"
	end
	function P.Effective(id)
		local out = {}
		for _, entry in ipairs(LIST) do
			local own = db.profiles[id] and db.profiles[id].values[entry.cvar]
			out[entry.cvar] = own ~= nil and own or (P.Inherited(id, entry.cvar))
		end
		return out
	end
	function P.Assign(key, id) call("Assign", key, id) db.locations[key] = id end
	function P.AssignAll(id) call("AssignAll", id) end
	function P.SetOverride(key, name, id) call("SetOverride", key, name, id) db.overrides[key] = { profile = id, name = name } end
	function P.RemoveOverride(key) call("RemoveOverride", key) db.overrides[key] = nil end

	local KEYS = { "city", "outdoor", "dungeon", "raid", "battleground", "arena" }
	local loc = { key = "city", overrideKey = "map:1453", name = "Stormwind Keep" }
	ns.Location = {
		KEYS = KEYS,
		LABELS = { city = "City", outdoor = "Open world", dungeon = "Dungeon", raid = "Raid", battleground = "Battleground", arena = "Arena" },
		Current = function() return loc end,
		ProfileFor = function() return "p1", "type" end,
	}
	ns.Apply = {
		Active = function() return ns.activeOverride or { loc = loc, profileId = "p1", profileName = "City", source = "type" } end,
		SetSwitching = function(on) call("SetSwitching", on) db.options.switching = on end,
		RestoreOriginal = function() call("RestoreOriginal") end,
		ApplyPending = function(...) call("ApplyPending", ...) end,
		Refresh = function(...) call("Refresh", ...) end,
		Target = function() return ns.target or {} end,
		Pending = function() return ns.pending end,
	}
	if withSmart then
		ns.Smart = {
			Enabled = function() return db.smart.enabled end,
			SetEnabled = function(on) call("SetEnabled", on) db.smart.enabled = on end,
			SetTarget = function(fps) call("SetTarget", fps) db.smart.target = fps end,
			SetFloor = function(scale) call("SetFloor", scale) db.smart.scaleFloor = scale end,
			Areas = function() return ns.areas end,
			ForgetArea = function(key) call("ForgetArea", key) end,
			State = function() return ns.smartState or { status = db.smart.enabled and (ns.preAdjusted and "pre-adjusted" or "holding") or "off", area = ns.preAdjusted and { key = "map:85", name = "Orgrimmar" }, fps = 58, target = db.smart.target, cap = 73, locKey = "city", last = { cvar = "RenderScale", from = 0.75, to = 0.7, t = 1 } } end,
			ResetLearning = function(key) call("ResetLearning", key) end,
			DismissSuggestion = function(key) call("DismissSuggestion", key) end,
			AdjustPlace = function(key)
				call("AdjustPlace", key)
				if ns.adjustRefusal then return false, ns.adjustRefusal end
				return true
			end,
			SetSuggest = function(on) call("SetSuggest", on) db.options.suggest = on end,
			ApplyCombatCuts = function() call("ApplyCombatCuts") end,
			DeferCombatCuts = function() call("DeferCombatCuts") end,
			GOALS = {
				{ key = "fps", name = "FPS", desc = "Holds the target first." },
				{ key = "balanced", name = "Balanced", desc = "The best picture that holds the target." },
				{ key = "fidelity", name = "Fidelity", desc = "The target is a minimum; spends headroom on looks." },
			},
			PACES = {
				{ key = "aggressive", name = "Aggressive", desc = "Changes on the go, reacts in a second or two." },
				{ key = "balanced", name = "Balanced", desc = "Changes on the go with calm rules." },
				{ key = "smooth", name = "Smooth", desc = "Changes only when you enter a new area." },
			},
			Goal = function(locKey) return db.smart.goals[locKey] or db.smart.goal end,
			Pace = function() return db.smart.pace end,
			SetGoal = function(key) call("SetGoal", key) db.smart.goal = key end,
			SetPace = function(key) call("SetPace", key) db.smart.pace = key end,
			SetLocationGoal = function(locKey, key) call("SetLocationGoal", locKey, key) db.smart.goals[locKey] = key end,
			CancelAdjust = function() call("CancelAdjust") end,
			Suggestion = function() return ns.suggestion end,
			AdjustState = function() return ns.adjust or { running = false } end,
			SaveAsProfile = function(key, name) call("SaveAsProfile", key, name) return P.Create(name) end,
		}
	end
	ns.areas = {
		{ key = "map:85", name = "Orgrimmar", locKey = "city", fps = 52, minFps = 31, lagShare = 0.4, seconds = 600, combatDrop = 0.25 },
		{ key = "map:1", name = "Durotar", locKey = "outdoor", fps = 64, minFps = 50, lagShare = 0.12, seconds = 300 },
	}
	if withSmart then
		local cal = { running = false, target = 60, scenes = {} }
		ns.cal = cal
		ns.Calibrate = {
			Start = function(fps)
				call("CalStart", fps)
				cal.running, cal.target = true, fps
				cal.scenes = { { locKey = "city", label = "City", seconds = 10, done = false }, { locKey = "outdoor", label = "Open world", seconds = 0, done = false } }
				cal.current = { locKey = "city", label = "City", status = "searching", seconds = 10 }
				cal.hint = "Walk around a city."
			end,
			Finish = function() call("CalFinish") cal.running = false return P.Create("Best for 60 FPS") end,
			Stop = function() call("CalStop") cal.running = false end,
			State = function() return cal end,
		}
	end
	return ns
end

local function last(ns, name)
	for i = #ns.calls, 1, -1 do if ns.calls[i][1] == name then return ns.calls[i] end end
end

local before = {}
for k in pairs(_G) do before[k] = true end

local function load(ns)
	for _, file in ipairs(FILES) do assert(loadfile(dir .. "/" .. file))("ForeverSmartGraphics", ns) end
	ns.ready = true
	ns.Fire("FSG_READY")
	return ns.UI
end

local ns = stubNS(true)
local UI = load(ns)
local L = UI.L

-- Entry points: the minimap button, /fsg replaced, the compartment opens on the next frame.
check(ForeverSmartGraphicsMinimapButton and ForeverSmartGraphicsMinimapButton:IsShown(), "minimap button shown")
ForeverSmartGraphics_OnCompartmentClick()
check(UI.Current() == nil, "compartment waits a frame")
W.advance(0.05)
local main = UI.Main()
local N = UI.N
check(main and UI.Current() == main and main:IsShown(), "compartment opens the window")
check(main.w == 920 and main.h == 724, "window is the Settings panel's 920 x 724")
check(main.NineSlice.Text:GetText() == "Forever Smart Graphics", "title")
check(main.portrait and main.portrait.texture == "Interface\\AddOns\\ForeverSmartGraphics\\Media\\portrait" and main.portrait.w == 62 and main.portrait.x == -5 and main.portrait.y == 7, "the round portrait: our logo, 62 at -5, 7")
check(main.portraitMask.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask" and main.portrait.masks and main.portrait.masks[1] == main.portraitMask, "masked round by the native portrait mask")
check(main.NineSlice.Text.point == "LEFT" and main.NineSlice.Text.x == 58, "the title moves right of the portrait")
ns.TogglePanel()
check(UI.Current() == nil and not main:IsShown(), "/fsg closes")
ns.TogglePanel()
check(main:IsShown(), "/fsg opens")

local function nodeWhere(pred)
	for _, node in ipairs(main.nodes) do if pred(node) then return node end end
end
local function labelled(text) return nodeWhere(function(n) return not n.category and n.region.label and n.region.label:GetText() == text end) end
local function category(key) return nodeWhere(function(n) return n.category == key end) end
local function row(cvar) return nodeWhere(function(n) return n.region.cvar == cvar end) end
local function buttonNode(label) return nodeWhere(function(n) return n.region:GetText() == label end) end
local function open(key) category(key).region:Click() end
local function listRows() return UI.List.Frame().rows end
local function tooltipFrame()
	for _, f in ipairs(W.frames) do if f.lines and f.actions and f.title then return f end end
end
local function tipLineOf(text)
	for _, fs in ipairs(tooltipFrame().lines) do if fs:IsShown() and fs:GetText() == text then return fs end end
end

-- The page list (Graphics: Overview, Profiles, Locations, Smart mode; Addon: Options); the window opens on Overview.
local cats = {}
for _, n in ipairs(main.nodes) do if n.category then cats[#cats + 1] = n.category end end
check(table.concat(cats, ",") == "overview,profiles,locations,smart,general", "pages: " .. table.concat(cats, ","))
check(main.list.headers[1].label:GetText() == L.CAT_GRAPHICS and main.list.headers[2].label:GetText() == L.CAT_ADDON, "two headers: Graphics and Addon")
check(UI.Selection().key == "overview" and main.canvas.title:GetText() == L.TAB_OVERVIEW, "opens on Overview")
check(category("overview").region.texture.atlas == "Options_List_Active" and category("general").region.label:GetText() == "Options", "native list, Options renamed")
check(main.nodes[1].category == nil, "the page's first control comes first in the focus order")

-- The status strip: Here > Profile > Smart, the FPS against the goal; each segment a link.
local strip = main.strip
check(strip.x == 62 and strip.y == -27 and strip.h == 37, "strip in the native tab band, right of the portrait")
check(strip.here.value.w >= #strip.here.value:GetText() * 6 and strip.here.w >= 8 * 2 + strip.here.caption:GetStringWidth() + 6 + strip.here.value.w - 1, "the Here value keeps its whole text inside its segment, clear of the chevron")
check(strip.here.value:GetText() == "Stormwind Keep · City" and strip.profile.value:GetText() == "City" and strip.smart.value:GetText() == L.STRIP_OFF, "Here, Profile, Smart off")
check(strip.fps:GetText() == "60 fps" and strip.target:GetText() == "target 60" and strip.fps.textColor[2] == 1 and strip.fps.textColor[1] < 0.5, "FPS green at the goal, its target")
check(math.abs(strip.fill.w - 96 * 60 / 90) < 1e-6, "the meter fills fps / (goal x 1.5)")
strip.here:Fire("OnEnter")
check(UI.TooltipOwner() == strip.here and tipLineOf("Stormwind Keep is a city zone."), "Here tooltip")
strip.here:Fire("OnLeave")
strip.profile:Fire("OnEnter")
check(tipLineOf("City zones use the profile City."), "Profile tooltip: the why line")
strip.profile:Fire("OnLeave")
strip.here:Click()
check(UI.Selection().key == "locations", "Here opens Locations")
strip.profile:Click()
check(UI.Selection().key == "profile" and UI.Selection().id == "p1", "Profile opens the active profile's editor")
strip.smart:Click()
check(UI.Selection().key == "smart", "Smart opens Smart mode")
check(main.status:GetText() == "", "the bottom line is empty until a confirmation")

-- Overview: why, the profile here and its preset, Smart mode, target, style, Find my best settings, by location.
open("overview")
local page = labelled("Profile for City").region:GetParent()
check(page.why:GetText():find("Stormwind Keep", 1, true) and page.why:GetText():find("City zones use the profile", 1, true) and page.why:GetText():find(L.WHY_EXACT, 1, true), "why sentence: " .. page.why:GetText())
local here = labelled("Profile for City")
check(here.region.choice.text:GetText() == "City" and here.region.buttons[1]:GetText() == L.EDIT, "Profile for City with Edit")
here.region:Click()
check(UI.List.IsOpen() and listRows()[1].name:GetText() == "Default" and listRows()[2].name:GetText() == "City", "the profile list")
listRows()[1]:Click()
check(last(ns, "Assign")[2] == "city" and last(ns, "Assign")[3] == nil, "picking Default clears the type")
labelled("Profile for City").region:Click()
listRows()[2]:Click()
check(last(ns, "Assign")[3] == "p1", "picking a profile assigns it")
labelled("Profile for City").region.buttons[1]:Click()
check(UI.Selection().key == "profile" and UI.Selection().id == "p1", "Edit opens the editor")
open("overview")
local preset = labelled(L.QUALITY_PRESET)
check(preset.region.choice.text:GetText() == L.PRESET_CUSTOM, "City matches no preset: Custom")
preset.region:Click()
check(listRows()[1].name:GetText() == "Max FPS" and listRows()[7].name:GetText() == "Beyond Ultra", "presets left to right: Max FPS ... Beyond Ultra")
listRows()[5]:Click()
check(UI.DialogShown() and ForeverSmartGraphicsDialog.Text:GetText() == "Replace City's settings with High?", "Custom asks before replacing")
local calls = #ns.calls
ForeverSmartGraphicsDialog.Button1:Click()
local p1 = ns.db.profiles.p1.values
check(p1.graphicsShadowQuality == 3 and p1.RenderScale == 1 and #ns.calls > calls, "the preset's values replace the profile's own")
W.advance(0.05)
check(labelled(L.QUALITY_PRESET).region.choice.text:GetText() == "High", "it now reads High")
calls = #ns.calls
main:Focus(labelled(L.QUALITY_PRESET))
W.press(main, "PADDLEFT")
check(not UI.DialogShown() and p1.graphicsShadowQuality == 2, "a matching preset steps without asking (left = more FPS)")
ns.db.profiles.p1.values = { RenderScale = 0.8 }
p1 = ns.db.profiles.p1.values
main:Refresh()
local smartRow = labelled(L.SMART)
check(smartRow.region.hint:GetText() == L.SMART_HINT and not smartRow.region.control.check:IsShown(), "Smart mode off, with its hint")
check(labelled(L.GOAL) == nil and labelled(L.PACE) == nil and page.goal and page.goal.label.font == "GameFontDisable", "Goal and Pace are greyed (not focus stops) while Smart is off")
main:Focus(labelled(L.TARGET))
W.press(main, "PADDRIGHT")
check(last(ns, "SetTarget")[2] == 65, "Target FPS steps by 5, Smart off too")
labelled(L.SMART).region:Click()
check(last(ns, "SetEnabled")[2] == true, "the Smart mode checkbox")
check(labelled(L.GOAL) and labelled(L.PACE), "Goal and Pace come on with Smart")
check(page.goal.desc:GetText() == "The best picture that holds the target." and page.pace.desc:GetText() == "Changes on the go with calm rules.", "each with its line")
check(labelled(L.GOAL).tip.lines[2] == "FPS: Holds the target first.", "the tooltip lists every goal")
labelled(L.GOAL).region:Click()
check(listRows()[1].name:GetText() == "FPS" and listRows()[3].name:GetText() == "Fidelity", "Goal: FPS, Balanced, Fidelity")
listRows()[1]:Click()
check(last(ns, "SetGoal")[2] == "fps", "Goal picks")
labelled(L.PACE).region:Click()
check(listRows()[1].name:GetText() == "Aggressive" and listRows()[3].name:GetText() == "Smooth", "Pace: Aggressive, Balanced, Smooth")
listRows()[3]:Click()
check(last(ns, "SetPace")[2] == "smooth", "Pace picks")
main:Focus(labelled(L.PACE))
W.press(main, "PADDLEFT")
check(last(ns, "SetPace")[2] == "balanced", "pad: left steps the pace")
labelled(L.PACE).region:Click()
listRows()[3]:Click()
check(page.why:GetText():find("and Smart mode adjusts it to hold", 1, true), "the why sentence follows Smart")
check(strip.smart.value:GetText() == "Holding · FPS · Smooth", "the strip: status, goal, pace: " .. strip.smart.value:GetText())
check(page.summary:GetText():find("City", 1, true) and page.summary:GetText():find("1 specific place", 1, true), "by location summary: " .. page.summary:GetText())
local summaryLines = {}
for line in page.summary:GetText():gmatch("[^\n]+") do summaryLines[#summaryLines + 1] = line end
local dangling = false
for _, line in ipairs(summaryLines) do dangling = dangling or line:find("·%s*$") or line:find("^%s*·") end
check(#summaryLines > 1 and not dangling and summaryLines[#summaryLines]:find("1 specific place$"), "by location breaks between places only, no dangling separator: " .. table.concat(summaryLines, " / "))
buttonNode(L.SET_UP_LOCATIONS).region:Click()
check(UI.Selection().key == "locations", "Set up locations")
open("overview")
buttonNode(L.START).region:Click()
check(UI.DialogShown() and not last(ns, "CalStart"), "Start asks first")
ForeverSmartGraphicsDialog.Button1:Click()
check(last(ns, "CalStart")[2] == 65 and UI.Current() == nil, "then calibrates at the target and closes the window")
UI.OpenPanel("overview")
local banner = page.banner
check(banner:IsShown() and banner.text:GetText():find("Finding your best settings · 65 FPS", 1, true) and banner.buttons[1]:GetText() == L.FINISH and not banner.buttons[1]:IsEnabled(), "calibration card, Finish waits for ready")
check(labelled("Profile for City") == nil and labelled(L.SMART) == nil and labelled(L.SMART) == nil, "what it would fight with is greyed")
check(page.smart.hint:GetText() == L.SMART_PAUSED and strip.smart.value:GetText() == L.STRIP_CALIBRATING, "Paused, and the strip says so")
ns.cal.ready = true
main:Refresh()
check(banner.buttons[1]:IsEnabled(), "Finish when ready")
banner.buttons[2]:Click()
check(last(ns, "CalStop") and not banner:IsShown(), "Stop ends it, the card goes")
ns.cal.ready = nil
ns.db.options.switching = false
main:Refresh()
check(banner:IsShown() and banner.text:GetText() == L.WHY_OFF and strip.profile.value:GetText() == L.STRIP_NONE, "switching off: notice, strip Profile None")
banner.buttons[1]:Click()
check(last(ns, "SetSwitching")[2] == true, "Turn on")
ns.pending = { values = { graphicsTextureResolution = 2 }, seconds = 5 }
main:Refresh()
check(banner.text:GetText() == "Texture resolution will change in a moment." and banner.buttons[1]:GetText() == L.APPLY_NOW, "a heavy change waiting")
banner.buttons[1]:Click()
check(last(ns, "ApplyPending"), "Apply now")
ns.pending = nil
ns.adjust = { running = true, key = "map:1453", name = "Stormwind Keep", seconds = 10, changes = { { cvar = "RenderScale", from = 1, to = 0.9 } } }
main:Refresh()
check(banner.text:GetText() == "Adjusting Stormwind Keep...\nLast change: Render scale 100% to 90%", "Smart adjust running")
banner.buttons[1]:Click()
check(last(ns, "CancelAdjust"), "Stop cancels it")
ns.adjust = nil
ns.db.smart.enabled = false
ns.suggestion = { key = "map:1453/Old Town", overrideKey = "map:1453", name = "Stormwind Keep", avg = 41.6, goal = 60 }
main:Refresh()
check(banner.text:GetText() == "This place has run under your target: avg 42 of 60 fps.", "this place lagged (a suggestion for here)")
banner.buttons[1]:Click()
check(last(ns, "AdjustPlace")[2] == "map:1453/Old Town", "Smart adjust")
ns.suggestion = nil
ns.areas[3] = { key = "map:1453", name = "Stormwind Keep", fps = 40, minFps = 20, lagShare = 0.6 }
main:Refresh()
check(banner.text:GetText() == "This place has run under your target: avg 40 of 65 fps.", "or its own lag record (goal 65)")
banner.buttons[2]:Click()
check(last(ns, "SetOverride")[2] == "map:1453" and UI.Selection().key == "locations" and main.focus and main.focus.placeKey == "map:1453", "Change profile adds the place and focuses it")
ns.areas[3] = nil
ns.db.overrides["map:1453"] = nil

-- Profiles: one row per profile with where it is used; New profile... in the bar; a row opens its editor.
open("profiles")
check(main.canvas.title:GetText() == L.TAB_PROFILES and buttonNode(L.NEW_PROFILE), "Profiles with New profile... in the bar")
local defaultRow = nodeWhere(function(n) return n.profileRowId == "default" end)
local cityRow = nodeWhere(function(n) return n.profileRowId == "p1" end)
check(defaultRow.region.usage:GetText() == "Used everywhere without its own profile", "Default's usage, short enough for its line: " .. defaultRow.region.usage:GetText())
check(cityRow.region.usage:GetText() == "Used in City, Stormwind City (specific place)" and cityRow.region.tag:IsShown() and not defaultRow.region.tag:IsShown(), "City: used in, own count, In use here now")
check(cityRow.region.h == 44 and cityRow.region.edit:GetText() == L.EDIT, "44 tall rows with Edit")
cityRow.region:Click()
check(UI.Selection().key == "profile" and UI.Selection().id == "p1" and main.canvas.title:GetText() == "City", "a click on the row opens the editor")
check(main.canvas.subtitle:GetText() == "Used in City, Stormwind City (specific place)", "the editor's title shows where it is used")

-- The editor: a fixed bar, the legend, the preset, fold sections; Detail folded unless it sets something there.
for _, label in ipairs({ L.ALL_PROFILES, L.COPY, L.RENAME, L.DELETE, L.USE_EVERYWHERE }) do check(buttonNode(label) and buttonNode(label).region:IsEnabled(), label .. " in the bar") end
local editor = row("RenderScale").region:GetParent()
check(editor.legend:GetText() == L.LEGEND, "legend")
local folds = {}
for _, n in ipairs(main.nodes) do if n.foldKey then folds[n.foldKey] = n end end
check(folds.quality and folds.render and folds.hidden, "Quality, Render, Detail fold headers")
check(folds.quality.region.count:GetText() == "3 settings · 0 set here" and folds.quality.region.valueCaption:GetText() == L.COLUMN_VALUE_SHORT and folds.quality.region.impact:GetText() == L.COLUMN_IMPACT, "fold count and column captions")
check(row("detail1") == nil and row("RenderScale"), "Detail starts folded, the others open")
folds.hidden.region:Click()
check(row("detail1") and row("vrsValar"), "a click opens Detail")
main:Focus(nodeWhere(function(n) return n.foldKey == "hidden" end))
W.press(main, "PAD1")
check(row("detail1") == nil, "A on the header folds it again")
folds = {}
for _, n in ipairs(main.nodes) do if n.foldKey then folds[n.foldKey] = n end end
folds.hidden.region:Click()
local shadow = row("graphicsShadowQuality")
local r = shadow.region
check(r.choice.text:GetText() == "High" and r.choice.text.font == "GameFontDisable" and not r.reset:IsShown(), "inherited: grey value, no reset")
check(r.impact:GetText() == "High" and r.impact.textColor[2] == 0.5, "impact column")
main:Focus(shadow)
W.press(main, "PADDRIGHT")
check(last(ns, "SetValue")[3] == "graphicsShadowQuality" and last(ns, "SetValue")[4] == 4, "D-pad right steps the row")
check(last(ns, "Refresh")[2] == "user" and last(ns, "Refresh")[4].user == true, "a window edit reaches the engine as the player's own")
check(row("graphicsShadowQuality").region.reset:IsShown() and row("graphicsShadowQuality").region.choice.text.font == "GameFontHighlight", "own: white value, reset")
W.press(main, "PAD3")
check(last(ns, "SetValue")[4] == nil, "X puts it back to following")
local vrs = row("vrsValar").region
check(vrs.label.font == "GameFontDisable" and not vrs.control:IsShown() and vrs.off:IsShown() and vrs.off:GetText() == L.UNSUPPORTED, "unsupported: grey, no control, the reason in its place")
ns.db.smart.enabled = true
ns.target = { RenderScale = 0.7 }
main:Refresh()
local now = row("RenderScale").region.now
check(now:IsShown() and now:GetText() == "now 70%", "Smart running it differently: now <value>")
main:Focus(row("RenderScale"))
check(tipLineOf(string.format(L.NOW_TIP, "70%", "80%")), "and the tooltip says so")
ns.target = nil
ns.db.smart.enabled = false
main:Refresh()
check(not row("RenderScale").region.now:IsShown(), "no note when it runs the profile's value")
main:Focus(row("detail14"))
check(main.scroll.offset > 0, "focusing a row below the view scrolls it in")
W.press(main, "PAD2")
check(UI.Selection().key == "profiles" and main.focus and main.focus.profileRowId == "p1", "B goes back to the list, on this profile's row")
W.press(main, "PAD2")
check(main.focus and main.focus.category == "profiles", "B again: the page list")

-- Editor actions.
cityRow = nodeWhere(function(n) return n.profileRowId == "p1" end)
cityRow.region:Click()
buttonNode(L.COPY).region:Click()
check(last(ns, "Copy")[2] == "p1" and UI.Selection().id ~= "p1", "Copy opens the copy's editor")
buttonNode(L.DELETE).region:Click()
check(UI.DialogShown(), "Delete asks first")
ForeverSmartGraphicsDialog.Button1:Click()
check(last(ns, "Delete") and UI.Selection().key == "profiles", "deleted, back to the list")
nodeWhere(function(n) return n.profileRowId == "default" end).region:Click()
local renameNode, deleteNode = buttonNode(L.RENAME), buttonNode(L.DELETE)
check(not renameNode.region:IsEnabled() and not deleteNode.region:IsEnabled() and renameNode.tip.lines[1] == L.DEFAULT_LOCKED, "Rename and Delete greyed on Default, with the reason")
check(row("RenderScale").region:GetParent().legend:GetText() == L.LEGEND_DEFAULT, "Default's legend")
calls = #ns.calls
renameNode.select()
check(#ns.calls == calls and not UI.Name.IsOpen(), "and do nothing")
UI.OpenPanel("profile", "p1")
buttonNode(L.USE_EVERYWHERE).region:Click()
ForeverSmartGraphicsDialog.Button1:Click()
check(last(ns, "AssignAll")[2] == "p1" and main.status:GetText() == "City is now used everywhere", "Use everywhere, confirmed on the bottom line")
W.advance(5.1)
check(main.status:GetText() == "", "the confirmation clears after 4 s (on the next 1 s tick)")
buttonNode(L.RENAME).region:Click()
check(UI.Name.IsOpen() and W.focus:GetText() == "City", "Rename opens the name box")
W.focus:SetText("Raid night")
W.focus:Fire("OnEnterPressed")
check(last(ns, "Rename")[3] == "Raid night" and main.canvas.title:GetText() == "Raid night", "renamed")
buttonNode(L.ALL_PROFILES).region:Click()
check(UI.Selection().key == "profiles", "All profiles")

-- New profile: a name and what it starts from; Create opens its editor.
local Create = UI.CreateProfile
buttonNode(L.NEW_PROFILE).region:Click()
local dialog = Create.Frame()
check(Create.IsOpen() and dialog:IsShown() and dialog.shade:IsShown() and dialog.w == 380, "the dialog, 380 wide, the window dimmed")
check(W.focus == dialog.edit and dialog.edit:GetText() == "Profile 1", "the name is focused and prefilled")
check(dialog.choices[1].note:GetText() == L.START_EMPTY_NOTE and dialog.choices[8].label:GetText() == "Beyond Ultra" and dialog.choices[8].note:GetText() == L.START_HEAVIEST, "grey notes on Empty and Beyond Ultra")
dialog.edit:SetText("Raid")
dialog.edit:Fire("OnEnterPressed")
check(last(ns, "Create")[2] == "Raid" and next(ns.db.profiles[UI.Selection().id].values) == nil and UI.Selection().key == "profile", "Enter creates an empty profile and opens its editor")
open("profiles")
buttonNode(L.NEW_PROFILE).region:Click()
dialog.choices[2]:Click()
dialog.create:Click()
check(last(ns, "FromCurrent")[2] == "Profile 1", "from the current settings")
open("profiles")
buttonNode(L.NEW_PROFILE).region:Click()
dialog.edit:ClearFocus()
W.press(main, "PADDDOWN")
W.press(main, "PADDDOWN")
W.press(main, "PAD1")
check(dialog.choices[3].check:IsShown(), "pad: the name is skipped, down picks a start")
for _ = 1, 12 do W.press(main, "PADDDOWN") end
W.press(main, "PAD1")
check(last(ns, "FromPreset")[2] == "low" and not Create.IsOpen(), "pad: down to Create, A creates")
open("profiles")
buttonNode(L.NEW_PROFILE).region:Click()
W.press(main, "PAD2")
check(not Create.IsOpen() and not dialog.shade:IsShown(), "B cancels")

-- Locations: one table, each type's profile and Smart style; specific places with Remove.
open("locations")
local switch = labelled(L.SWITCHING)
check(switch.region.hint:GetText() == L.SWITCHING_HINT, "Switch by location with its hint")
local city = labelled("City")
check(city.region.here:IsShown() and city.region.choice.text:GetText() == "Raid night" and city.region.choice.x == 192 and city.region.second.x == 410 and city.region.second.w == 168 + 44, "City row: you are here, Profile at 192, Smart goal at 410, 168 wide")
check(city.region.second.text:GetText() == "Default: FPS" and city.region.second.off, "the goal shows its value, greyed while Smart is off")
local locPage = city.region:GetParent()
check(locPage.placeCaption:IsShown() and locPage.placeCaption.flowY > locPage.placesWin.flowY, "the places' Profile header sits over their rows, under the line that explains them")
local savedOverrides = ns.db.overrides
ns.db.overrides = {}
main:Refresh()
check(not locPage.placeCaption:IsShown() and locPage.empty:IsShown(), "no places: no Profile header over the empty line")
ns.db.overrides = savedOverrides
main:Refresh()
check(nodeWhere(function(n) return n.styleKey end) == nil, "greyed goals take no focus")
main:Focus(city)
W.press(main, "PADDLEFT")
check(last(ns, "Assign")[2] == "city", "left steps the profile")
ns.db.smart.enabled = true
main:Refresh()
local style = nodeWhere(function(n) return n.styleKey == "city" end)
check(style and not labelled("City").region.second.off, "the goal column comes on with Smart")
check(main.list and labelled("City").region:GetParent().styleCaption:GetText() == L.COLUMN_STYLE, "column caption Smart goal")
style.region:Click()
check(listRows()[1].name:GetText() == "Default: FPS" and listRows()[4].name:GetText() == "Fidelity" and listRows()[5]:IsShown() == false, "Default, then the three goals")
listRows()[4]:Click()
check(last(ns, "SetLocationGoal")[2] == "city" and last(ns, "SetLocationGoal")[3] == "fidelity", "a goal per location type")
nodeWhere(function(n) return n.styleKey == "city" end).region:Click()
listRows()[1]:Click()
check(last(ns, "SetLocationGoal")[3] == nil, "Default clears it")
main:Focus(labelled("Arena"))
for _ = 1, 8 do W.press(main, "PADDRIGHT") end
check(main.focus.styleKey == "arena" or main.focus.region == labelled("Arena").region, "right past the profile's end moves on to the style")
local place = labelled("Stormwind City")
check(place and place.region.remove:GetText() == L.REMOVE and not place.region.second, "a place row: profile and Remove, no style")
main:Focus(place)
W.press(main, "PAD3")
check(last(ns, "RemoveOverride")[2] == "map:84", "X removes a place")
ns.db.overrides["map:84"] = { profile = "p1", name = "Stormwind City" }
main:Refresh()
labelled("Stormwind City").region.remove:Click()
check(last(ns, "RemoveOverride")[2] == "map:84", "Remove too")
ns.db.overrides["map:84"] = { profile = "p1", name = "Stormwind City" }
main:Refresh()
local add = buttonNode(string.format(L.ADD_THIS_PLACE, "Stormwind Keep"))
add.region:Click()
check(last(ns, "SetOverride")[2] == "map:1453", "Add this place")
ns.db.overrides["map:1453"] = nil
labelled(L.SWITCHING).region:Click()
check(last(ns, "SetSwitching")[2] == false and labelled("City") == nil, "switching off greys the table")
labelled(L.SWITCHING).region:Click()
ns.db.smart.enabled = false

-- Smart mode: switch, target, style with its line, floor; right now; learned and lagged folded.
open("smart")
check(labelled(L.START) == nil and buttonNode(L.START) == nil, "Find my best settings is not on this page")
local smartPage = labelled(L.SMART).region:GetParent()
check(smartPage.intro:GetText() == L.SMART_INTRO and smartPage.offLine:IsShown(), "intro, and the off line while Smart is off")
labelled(L.SMART).region:Click()
check(last(ns, "SetEnabled")[2] == true and smartPage.lines[1]:GetText():find("Holding · 58 fps, goal", 1, true), "right now: " .. smartPage.lines[1]:GetText())
check(smartPage.lines[3]:GetText() == "Last change: Render scale 75% to 70%", "last change")
check(smartPage.goal.desc:GetText() == "Holds the target first." and smartPage.pace.desc:GetText() == "Changes only when you enter a new area.", "goal and pace with their lines")
check(smartPage.lines[1]:GetText():find("FPS · Smooth", 1, true), "right now names the goal and pace")
ns.smartState = { status = "holding", fps = 74, target = 75, goal = 72, ceiling = 74 }
W.advance(1.1)
check(smartPage.lines[1]:GetText():find("Holding · 74 fps, goal 72 (display tops out at 74)", 1, true), "Smart's goal, with the display's ceiling: " .. smartPage.lines[1]:GetText())
ns.smartState = nil
W.advance(1.1)
check(not smartPage.lines[1]:GetText():find("tops out", 1, true), "no ceiling known: no aside")
smartPage.goal:Click()
listRows()[2]:Click()
check(last(ns, "SetGoal")[2] == "balanced", "the Smart page's Goal")
main:Focus(labelled(L.FLOOR))
W.press(main, "PADDLEFT")
check(math.abs(last(ns, "SetFloor")[2] - 0.55) < 1e-9, "floor steps by 5%")
local learnedFold = nodeWhere(function(n) return n.foldKey == "learned" end)
check(learnedFold and learnedFold.region.count:GetText() == "1 locations" and labelled("City") == nil, "What it learned starts folded")
learnedFold.region:Click()
local learnedRow = labelled("City")
check(learnedRow.region.buttons[1]:GetText() == L.SAVE_PROFILE and learnedRow.region.detail:GetText():find("^3 samples"), "learned row: samples, Save as profile, Reset")
learnedRow.region.buttons[2]:Click()
check(last(ns, "ResetLearning")[2] == "city", "Reset")
labelled("City").region.buttons[1]:Click()
check(last(ns, "SaveAsProfile")[3] == "City (smart)", "Save as profile")
local lagFold = nodeWhere(function(n) return n.foldKey == "lagged" end)
lagFold.region:Click()
local lag = labelled("Orgrimmar")
check(lag and lag.region.detail:GetText() == "avg 52 · low 31 fps · 40% under target · fights -25%", "lag row")
lag.region.buttons[1]:Click()
check(last(ns, "ForgetArea")[2] == "map:85", "Forget")

-- Options.
open("general")
check(main.canvas.title:GetText() == "Options", "Options page")
local chat = labelled(L.CHAT_LOG)
check(chat and not chat.region.control.check:IsShown() and ns.db.options.chatLog == nil, "Log setting changes in chat: off when unset")
chat.region:Click()
check(ns.db.options.chatLog == true, "the checkbox turns it on")
labelled(L.CHAT_LOG).region:Click()
check(ns.db.options.chatLog == false, "and off")
local noticeRows = {}
for _, n in ipairs(main.nodes) do if n.region.label then noticeRows[#noticeRows + 1] = n.region.label:GetText() end end
local order = table.concat(noticeRows, "|")
check(order:find(table.concat({ L.SMART_NOTICE, L.PROFILE_NOTICE, L.SUGGEST, L.ANNOUNCE, L.CHAT_LOG, L.CHAT_LOG_SMART, L.FPS_PULSE }, "|"), 1, true), "Notifications: the six notices, then the FPS pulse, in order: " .. order)
check(L.SECTION_NOTICES == "Notifications" and L.ANNOUNCE == "Announce texture changes before they stutter", "the section and its rows say what they show")
local noticeDesc = labelled(L.SMART_NOTICE).region:GetParent().sections[1].desc
check(noticeDesc and noticeDesc:GetText() == "All off by default. Turn on what you want to see.", "All off by default, under the header")
for _, label in ipairs({ L.SMART_NOTICE, L.PROFILE_NOTICE, L.SUGGEST, L.ANNOUNCE, L.CHAT_LOG_SMART }) do check(not labelled(label).region.control.check:IsShown(), label .. ": off by default") end
check(labelled(L.FPS_PULSE).region.control.check:IsShown(), "the FPS pulse: on by default")
labelled(L.MINIMAP).region:Click()
check(ns.db.options.minimap.shown == false and not ForeverSmartGraphicsMinimapButton:IsShown(), "minimap button off")
check(labelled(L.DEBUG) and labelled(L.CONTROLS), "Debug log and Controls rows")
local restore = buttonNode(L.RESTORE)
main:Focus(restore)
W.press(main, "PAD1")
check(UI.DialogShown(), "restore asks first")
W.key(main, "ESCAPE")
check(not UI.DialogShown() and not last(ns, "RestoreOriginal"), "Esc cancels")
W.press(main, "PADRSHOULDER")
check(UI.Selection().key == "general", "R1 stops at the last page")
W.press(main, "PADLSHOULDER")
check(UI.Selection().key == "smart", "L1 goes back a page")
open("general")

-- Two looks: auto follows the last input.
ns.db.options.input = "bogus"
check(UI.InputSetting() == "auto", "unknown input setting repairs to auto")
W.press(main, "PADDUP")
W.advance(0.05)
check(UI.Mode() == "pad" and main.footer:IsShown() and main.glow:IsShown(), "pad press: footer and glow")
category("general").region:Click()
W.advance(0.05)
check(UI.Mode() == "mouse" and not main.footer:IsShown() and not main.cursor:IsShown(), "a mouse click: mouse look")
labelled(L.CONTROLS).region:Click()
listRows()[2]:Click()
check(ns.db.options.input == "mouse", "Controls: Mouse and keyboard")
W.press(main, "PADDUP")
check(UI.Mode() == "mouse", "a pad press keeps a pinned mouse look")
labelled(L.CONTROLS).region:Click()
listRows()[1]:Click()
check(ns.db.options.input == "auto", "back to Automatic")

-- Every focus node takes the mouse on every page.
ns.db.smart.enabled = true
for _, key in ipairs({ "overview", "profiles", "locations", "smart", "general" }) do
	open(key)
	for _, node in ipairs(main.nodes) do check(node.region:IsMouseEnabled(), key .. ": node takes the mouse") end
end
UI.OpenPanel("profile", "p1")
for _, node in ipairs(main.nodes) do check(node.region:IsMouseEnabled(), "editor: node takes the mouse") end
ns.db.smart.enabled = false
UI.CloseAll()

-- The game font has no arrow or minus sign: no U+2192 or U+2212 anywhere in the panel's Lua.
for _, file in ipairs(FILES) do
	local fh = assert(io.open(dir .. "/" .. file, "rb"))
	local text = fh:read("*a")
	fh:close()
	check(not text:find("\226\134\146", 1, true) and not text:find("\226\136\146", 1, true), file .. " has no arrow or minus sign glyph")
end

-- Show FPS on minimap: off by default (and repaired to off), the General checkbox shows it, coloured against the goal.
ns.db.options.minimapFps = "yes"
check(UI.MinimapFpsOn() == false and ns.db.options.minimapFps == false, "minimapFps repairs to off")
check(not ForeverSmartGraphicsMinimapFps or not ForeverSmartGraphicsMinimapFps:IsShown(), "no FPS readout by default")
UI.OpenPanel("general")
local fpsRow = nodeWhere(function(n) return n.region.label and n.region.label:GetText() == L.MINIMAP_FPS end)
check(fpsRow, "General: Show FPS on minimap")
fpsRow.region:Click()
local readout = ForeverSmartGraphicsMinimapFps
check(ns.db.options.minimapFps == true and readout:IsShown() and readout.text:GetText() == "60 fps", "checkbox shows the readout: " .. tostring(readout and readout.text:GetText()))
check(readout.rel == Minimap and readout.parent == UIParent and readout.anchor == "minimap", "no zone bar: under the minimap, parented to UIParent")
check(readout.h == 23 and readout.text.font == "GameFontHighlightSmall", "the zone box's height and the zone text's font")
local slices = readout.slices
check(slices and #slices == 3 and slices[1].texture == "Interface/HUD/MinimapHeader" and slices[2].texture == slices[1].texture, "the zone box's own atlas file, in three slices")
check(math.abs(slices[1].coords[2] - (0.25 + 0.15 * 10 / 152)) < 1e-9 and slices[1].w == 10 and slices[3].w == 10 and slices[3].coords[2] == 0.4, "fixed 10 wide ends cut from the atlas, the middle stretched")
local plain
for k, child in pairs(readout) do if type(child) == "table" and child.color and k ~= "parent" and k ~= "rel" then plain = k end end
check(not plain and not rawget(readout, "NineSlice") and not rawget(readout, "Center") and not rawget(readout, "TopLeftCorner"), "no stand-in background and no nine-slice: " .. tostring(plain))
ns.db.smart.target = 60
W.advance(0.6)
check(readout.text.textColor[1] == 1 and readout.text.textColor[2] == 1 and readout.text.textColor[3] == 1, "white at the goal")
MinimapCluster = { ZoneTextButton = W.new("Button", UIParent) }
W.advance(0.6)
check(readout.anchor == "zone" and readout.rel == MinimapCluster.ZoneTextButton and readout.point == "TOPLEFT" and readout.x == 0 and readout.y == 1, "under the zone box, left edges aligned, 1 overlap like the addon count")
MinimapCluster.ZoneTextButton.scale = 0.8
W.advance(0.6)
check(math.abs(readout:GetScale() - 0.8) < 1e-9, "at the minimap cluster's scale")
MinimapCluster.ZoneTextButton.shown = false
W.advance(0.6)
check(readout.anchor == "minimap", "zone box hidden: under the minimap")
MinimapCluster = nil
W.advance(0.6)
check(readout.anchor == "minimap", "back under the minimap")
check(UI.FpsColor(75, 60) == "good" and UI.FpsColor(60, 60) == "good" and UI.FpsColor(52, 60) == "warn" and UI.FpsColor(50, 60) == "bad", "colour thresholds: at goal, within 15%, below")
ns.db.smart.target = 60
W.fps = 45
W.advance(0.6)
check(readout.text:GetText() == "45 fps" and readout.text.textColor[1] == 1 and readout.text.textColor[2] < 0.5, "updates every half second, red well under the goal")
W.fps = 55
W.advance(0.6)
check(readout.text.textColor[1] == 1 and readout.text.textColor[2] == 1 and readout.text.textColor[3] == 0, "yellow a little under")
Minimap.shown = false
W.advance(0.6)
check(not readout:IsShown(), "hidden with the minimap")
Minimap.shown = true
W.advance(0.6)
check(readout:IsShown(), "back with the minimap")
readout:Fire("OnEnter")
check(UI.TooltipOwner() == readout, "tooltip on hover")
readout:Fire("OnLeave")
-- The quiet signal for changes: one gold pulse and a mark beside the number, then gone; the tooltip lists them.
local function tipLines()
	local lines = {}
	for _, f in ipairs(W.frames) do if f.lines and f.actions and f.title and f:IsShown() then for _, fs in ipairs(f.lines) do if fs:IsShown() then lines[#lines + 1] = fs:GetText() end end end end
	return lines
end
local glowAnim = readout.pulse
check(readout.glow.texture:find("glow$") and readout.glow.vertexColor[2] == 0.82 and readout.glow:GetAlpha() == 0, "a gold glow behind the box, at rest unseen")
ns.Fire("FSG_CHANGES", { source = "smart", reason = "smart", changes = { { cvar = "RenderScale", from = 0.8, to = 0.85 } } })
check(glowAnim.plays == 1 and readout.mark:IsShown() and readout.mark.atlas == "minimal-scrollbar-arrow-top", "a raise: one pulse and an up arrow")
check(readout.text.x == -5 and readout.point == readout.point, "the number makes room for the mark; the box does not move")
W.advance(3)
check(readout.mark:IsShown() and readout.mark:GetAlpha() == 1, "the arrow stays a few seconds")
W.advance(3.1)
check(not readout.mark:IsShown() and readout.text.x == 0, "then it is gone after 6 s")
ns.Fire("FSG_CHANGES", { source = "smart", reason = "smart", changes = { { cvar = "graphicsShadowQuality", from = 3, to = 2 } } })
check(glowAnim.plays == 2 and readout.mark.atlas == "minimal-scrollbar-arrow-bottom", "a lower: down")
ns.Fire("FSG_CHANGES", { source = "profile", reason = "City", changes = { { cvar = "RenderScale", from = 1, to = 0.8 } } })
check(readout.mark.color and readout.mark.w == 3, "a profile switch: a dot")
readout:Fire("OnEnter")
local tl = table.concat(tipLines(), "\n")
check(tl:find(L.FPS_TIP_CHANGES, 1, true) and tl:find("just now · profile: Render scale 100% to 80%", 1, true) and tl:find("smart mode: Shadow quality High to Good", 1, true), "the tooltip lists the last changes, newest first: " .. tl)
readout:Fire("OnLeave")
W.advance(7)
ns.smartState = { status = "raising (testing)", fps = 60, goal = 60 }
W.advance(0.5)
check(readout.mark:IsShown() and readout.mark.color and glowAnim.plays == 3, "testing a raise: a steady dot, no pulse")
ns.smartState = nil
W.advance(0.5)
ns.db.options.fpsPulse = false
ns.Fire("FSG_CHANGES", { source = "smart", reason = "smart", changes = { { cvar = "RenderScale", from = 0.8, to = 0.85 } } })
check(glowAnim.plays == 3 and not readout.mark:IsShown(), "the option off: no pulse, no mark")
ns.db.options.fpsPulse = nil
UI.CloseAll()
readout:Click()
check(UI.Current() == main, "a click opens the window")
UI.OpenPanel("general")
nodeWhere(function(n) return n.region.label and n.region.label:GetText() == L.MINIMAP_FPS end).region:Click()
check(not readout:IsShown() and ns.db.options.minimapFps == false, "checkbox hides it again")
W.fps = 60
UI.CloseAll()

-- With every notification option at its default (off), nothing makes or shows the notice frame.
UI.CloseAll()
local function fireEveryKind()
	ns.Fire("FSG_CHANGES", { source = "profile", reason = "City", changes = { { cvar = "RenderScale", from = 1, to = 0.8 } } })
	ns.Fire("FSG_CHANGES", { source = "smart", reason = "smart", changes = { { cvar = "RenderScale", from = 0.8, to = 0.9 } } })
	ns.Fire("FSG_SUGGEST", { key = "map:85/Valley of Strength", overrideKey = "map:85", name = "Orgrimmar", avg = 42, goal = 60 })
	ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 10 })
	ns.Fire("FSG_COMBAT_LOW", { fps = 48, goal = 75, cuts = { "graphicsShadowQuality" } })
	ns.Fire("FSG_CHANGES", { source = "smart", reason = "after combat", changes = { { cvar = "RenderScale", from = 0.9, to = 0.8 } } })
	ns.Fire("FSG_ADJUST", { running = true, key = "map:85", name = "Orgrimmar", seconds = 30, changes = {} })
end
ns.smartState = { status = "holding", fps = 60, goal = 60 }
fireEveryKind()
W.advance(5)
check(ForeverSmartGraphicsToast == nil, "defaults: no notice frame is ever made")
local function shownKinds()
	local list = {}
	for _, child in ipairs(ForeverSmartGraphicsToast and ForeverSmartGraphicsToast.children or {}) do if child.item and child:IsShown() then list[#list + 1] = child.item.kind end end
	table.sort(list)
	return table.concat(list, ",")
end
-- Smart's own kinds outnumber the three places, so the oldest of them (its run, hidden by the fight) gives way.
for _, case in ipairs({ { "smartNotice", "adjust,combat,done" }, { "notifyProfile", "profile" }, { "suggest", "suggest" }, { "announce", "pending" } }) do
	ns.db.options[case[1]] = true
	fireEveryKind()
	check(shownKinds() == case[2], case[1] .. " on shows only its own kinds: " .. shownKinds())
	UI.Notify.Poll(GetTime() + 10)
	for _, kind in ipairs({ "smart", "profile", "suggest", "pending", "combat", "done", "adjust" }) do UI.Notify.Hide(kind) end
	ns.db.options[case[1]] = nil
end
ns.smartState = nil
for _, key in ipairs({ "smartNotice", "notifyProfile", "suggest", "announce" }) do ns.db.options[key] = true end

-- Notifications: one light frame, a pill per notification, newest on top, at most 3.
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 10 })
local note = ForeverSmartGraphicsToast
local function slotOf(kind)
	for _, child in ipairs(note.children) do if child.item and child.item.kind == kind and child:IsShown() then return child end end
end
local pend = slotOf("pending")
check(note:IsShown() and pend and pend.text:GetText() == "Texture resolution: High", "pending names the change: " .. tostring(pend and pend.text:GetText()))
-- One dark glow behind centred words with a shadow: densest at the title's top centre, no gradient rectangles, no
-- border, box or icon.
local glow = pend.glow
check(glow.texture == "Interface\\AddOns\\ForeverSmartGraphics\\Media\\glow" and glow.vertexColor[1] == 0 and glow.vertexColor[4] == 0.7, "a black radial glow, 70% at its peak")
check(glow.point == "TOP" and glow.rel == pend and math.abs(glow.y - (glow.h * 0.25 - 8)) < 1e-6 and glow.w > pend:GetWidth() and glow.h > pend:GetHeight(), "its peak at the title's top centre, reaching past the words all round")
local gradients = 0
for _, child in pairs(pend) do if type(child) == "table" and child.kind == "Texture" and child.gradient then gradients = gradients + 1 end end
check(not pend.band and not pend.fade and gradients == 0, "no band, no gradient rectangles")
check(pend:GetWidth() <= 264, "the words are at most 264 wide: " .. pend:GetWidth())
check(not rawget(pend, "NineSlice") and not rawget(pend, "TopLeftCorner") and not rawget(pend, "Center") and not rawget(pend, "icon") and not rawget(pend, "pill"), "no border, no NineSlice, no box, no icon")
check(pend.text.font == "GameFontNormal" and pend.sub.font == "GameFontHighlightSmall" and pend.third.font == "GameFontHighlightSmall" and pend.text.justifyH == "CENTER" and pend.text.shadowOffset[1] == 1 and pend.text.shadowColor[4] == 1, "a gold title and small white details, centred, with a shadow")
check(pend.buttons[1]:GetText() == L.APPLY_NOW and pend.buttons[1].point == "TOPLEFT" and pend.buttons[1].rel == pend, "Apply now as quiet text under the words")
check(pend.line[1].gradient.from.a == 0 and pend.line[2].gradient.to.a == 0 and pend.line[1].point == "RIGHT" and pend.line[2].point == "LEFT" and pend.line[1].rel == pend.text and pend.line[1].h == 1, "a thin gold line under the title, fading at both ends, from the middle out")
for _, tex in ipairs(pend.line) do check(tex.rel ~= pend, "no line along the foot") end
W.advance(0.2)
check(pend.item.born and pend:GetAlpha() > 0 and pend:GetAlpha() < 1, "a new notice fades in")
W.advance(0.5)
check(pend:GetAlpha() == 1 and not pend.item.born, "over 0.6 s")
check(not note.keyboard and not pend.close.keyboard, "never takes the keyboard")
local half = pend.text:GetStringWidth() * 0.4
check(2 * half < pend.text:GetStringWidth(), "the gold line is shorter than the title")
local startW = pend.line[1].w
W.advance(2)
local after = pend.line[1].w
check(after < startW and pend.line[2].w == after and math.abs(after / half - 0.715) < 0.03, "the line shrinks from both ends with the countdown: " .. tostring(after / half))
W.advance(0.25)
check(pend.line[1].w < after, "smoothly, not by whole seconds")
W.combat = true
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 7, waitingCombat = true })
pend = slotOf("pending")
local paused = pend.line[1].w
W.advance(1)
check(pend.line[1].w == paused and pend.line[1].alpha == 0.35, "in combat the line stops and dims")
check(pend.text:GetText() == "Texture resolution: High" .. L.NOTIFY_WAITS, "and says it waits for combat")
W.combat = false
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 7, waitingCombat = false })
W.advance(0.5)
check(slotOf("pending").line[1].w < paused and slotOf("pending").line[1].alpha == 1, "it runs on after combat")
function note.GetLeft() return 700 end
function note.GetTop() return 1000 end
pend:Fire("OnDragStart")
pend:Fire("OnDragStop")
local saved = ns.db.options.notifyPos
check(math.abs(saved.fx - 700 / 1920) < 1e-9 and math.abs(saved.fy - 1000 / 1080) < 1e-9 and note.point == "TOPLEFT", "a drag saves the position as screen fractions")
UIParent:SetSize(1280, 720)
note:Hide()
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 5 })
check(math.abs(note.x - 700 / 1920 * 1280) < 1e-6 and math.abs(note.y - 1000 / 1080 * 720) < 1e-6, "a smaller screen keeps the same place")
UIParent:SetSize(1920, 1080)
ns.db.options.notifyPos = { x = 700, y = 1000 }
note:Hide()
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 5 })
check(ns.db.options.notifyPos == nil and note.point == "TOP", "an old absolute position repairs to the default")
pend = slotOf("pending")
pend.close:Click()
check(not note:IsShown(), "x closes it")
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 6 })
check(not note:IsShown(), "the same change stays closed")
ns.db.options.notifyPos = "bad"
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 1 }, seconds = 10 })
check(note:IsShown() and ns.db.options.notifyPos == nil and note.point == "TOP", "a newer change shows again; a bad position repairs to the default")
slotOf("pending").buttons[1]:Click()
check(last(ns, "ApplyPending") and not note:IsShown(), "Apply now applies")
ns.Fire("FSG_PENDING", nil)

-- Suggestions: Change, Smart adjust, x; the General option turns them off.
local suggestion = { key = "map:85/Valley of Strength", overrideKey = "map:85", name = "Orgrimmar", locKey = "city", avg = 42.4, goal = 60 }
ns.Fire("FSG_SUGGEST", suggestion)
local sug = slotOf("suggest")
check(sug and sug.text:GetText() == "Low FPS in Orgrimmar: avg 42, target 60", "suggestion text: " .. tostring(sug and sug.text:GetText()))
check(sug.buttons[1]:GetText() == L.CHANGE_BUTTON and sug.buttons[2]:GetText() == L.SMART_ADJUST, "Change and Smart adjust buttons")
sug.buttons[1]:Click()
local over = last(ns, "SetOverride")
check(over and over[2] == "map:85" and over[3] == "Orgrimmar" and over[4] == "p1", "Change adds the place with the current profile")
check(main:IsShown() and UI.Selection().key == "locations" and main.focus and main.focus.region.label:GetText() == "Orgrimmar", "Change opens Locations on that place")
check(not slotOf("suggest"), "Change closes the suggestion")
UI.CloseAll()
calls = #ns.calls
ns.Fire("FSG_SUGGEST", suggestion)
slotOf("suggest").buttons[1]:Click()
check(not last(ns, "SetOverride") or #ns.calls == calls, "an existing place is not added again")
UI.CloseAll()
ns.Fire("FSG_SUGGEST", suggestion)
slotOf("suggest").buttons[2]:Click()
check(last(ns, "AdjustPlace")[2] == "map:85/Valley of Strength" and not slotOf("suggest"), "Smart adjust starts the search for the place")
ns.adjustRefusal = "busy"
ns.Fire("FSG_SUGGEST", suggestion)
slotOf("suggest").buttons[2]:Click()
check(slotOf("suggest") and slotOf("notice") and slotOf("notice").text:GetText() == "Smart adjust can't start: busy", "a refused Smart adjust keeps the suggestion and says why")
W.advance(4.1)
check(not slotOf("notice") and slotOf("suggest"), "the notice goes after 4 s")
ns.adjustRefusal = nil
UI.Notify.Hide("suggest")
UI.CloseAll()
ns.db.overrides["map:85"] = nil
W.combat = true
calls = #ns.calls
ns.Fire("FSG_SUGGEST", suggestion)
slotOf("suggest").buttons[1]:Click()
check(#ns.calls == calls and UI.Current() == nil and slotOf("suggest"), "Change in combat does nothing (no override, no window)")
W.combat = false
UI.Notify.Hide("suggest")
ns.Fire("FSG_SUGGEST", suggestion)
slotOf("suggest").close:Click()
check(last(ns, "DismissSuggestion")[2] == "map:85/Valley of Strength" and not slotOf("suggest"), "x dismisses the suggestion")
UI.OpenPanel("general")
local suggestRow = nodeWhere(function(n) return n.region.label and n.region.label:GetText() == L.SUGGEST end)
check(suggestRow and suggestRow.region.control.check:IsShown(), "General: Suggest changes when FPS drops, on")
suggestRow.region:Click()
check(ns.db.options.suggest == false and last(ns, "SetSuggest")[2] == false, "the checkbox turns suggestions off through Smart")
UI.CloseAll()
ns.Fire("FSG_SUGGEST", suggestion)
check(not slotOf("suggest"), "no suggestion while it is off")
ns.db.options.suggest = "x"
check(UI.SuggestOn() == false, "only true is on")
ns.db.options.suggest = true

-- Smart adjust progress, then what it saved, gone after 6 s.
ns.Fire("FSG_ADJUST", { running = true, key = "map:85", name = "Orgrimmar", seconds = 30, changes = { { cvar = "graphicsShadowQuality", from = 3, to = 2 } } })
local adj = slotOf("adjust")
check(adj and adj.text:GetText() == "Adjusting Orgrimmar..." and adj.sub:GetText() == "Shadow quality High to Good", "adjust shows the place and its latest change")
check(math.abs(adj.line[1].w / (adj.text:GetStringWidth() * 0.4) - 60 / 90) < 0.02, "the line is the 90 s limit")
ns.Fire("FSG_ADJUST", { running = true, paused = true, key = "map:85", name = "Orgrimmar", seconds = 30, changes = {} })
local held = adj.line[1].w
W.advance(1)
check(adj.line[1].w == held and adj.line[1].alpha == 0.35, "a paused adjust holds its line")
adj.buttons[1]:Click()
check(last(ns, "CancelAdjust"), "Cancel stops the adjust")
ns.Fire("FSG_ADJUST", { done = true, key = "map:85", name = "Orgrimmar", profileId = "p9" })
adj = slotOf("adjust")
check(adj and adj.text:GetText() == 'Saved "Smart: Orgrimmar" for this place' and #(adj.item.buttons or {}) == 0, "done says what it saved")
W.advance(6.1)
check(not slotOf("adjust") and not note:IsShown(), "and hides after 6 s")

-- At most three, newest on top.
for _, kind in ipairs({ "a", "b", "c", "d" }) do UI.Notify.Show(kind, { text = kind }) end
local list = UI.Notify.Items()
check(#list == 3 and list[1].kind == "d" and list[3].kind == "b", "stack capped at 3, newest first")
check(slotOf("d").top == 0 and slotOf("b").top > slotOf("c").top, "newest on top, older below")
for _, kind in ipairs({ "b", "c", "d" }) do UI.Notify.Hide(kind) end
check(not note:IsShown(), "empty frame hides")

-- Every change shows: FSG_CHANGES batches drive the notices. Smart's notice updates in place for every batch, then a
-- summary; a profile switch says "Now using"; none of Smart's in combat or with the window open.
UI.CloseAll()
local function kinds()
	local out = {}
	for _, item in ipairs(UI.Notify.Items()) do out[#out + 1] = item.kind end
	return table.concat(out, ",")
end
local function smartSlot() return slotOf("smart") end
local function batch(source, changes, reason) ns.Fire("FSG_CHANGES", { source = source, reason = reason or source, changes = changes }) end
local function tipOf(slot)
	slot:Fire("OnEnter")
	local lines = {}
	for _, f in ipairs(W.frames) do if f.lines and f.actions and f.title and f:IsShown() then for _, fs in ipairs(f.lines) do if fs:IsShown() then lines[#lines + 1] = fs:GetText() end end end end
	slot:Fire("OnLeave")
	return lines
end
local st = { status = "holding", fps = 75, goal = 75, target = 75 }
ns.smartState = st
ns.db.smart.enabled = true
local burst = { "graphicsShadowQuality", "graphicsViewDistance", "shadowSoft", "detail1", "graphicsViewDistance" }
for i, cvar in ipairs(burst) do batch("smart", { { cvar = cvar, from = i, to = i + 1 } }) end
local act = smartSlot()
check(kinds() == "smart" and act, "a burst of Smart batches: one notice, whatever the status")
check(act.text:GetText() == L.ACTIVITY_RAISE, "Optimizing graphics, the tag kept out of the title: " .. act.text:GetText())
check(act.sub:GetText() == "View distance 5 to 6   +4 more" and act.subIcon.atlas == "minimal-scrollbar-arrow-top", "the latest change, up, +4 more: " .. act.sub:GetText())
check(act.third:GetText() == "75 / 75 fps |cff9e9e9e· " .. UI.SmartStyle() .. "|r" and act.item.shimmer, "fps against the target, the muted tag, the working line: " .. act.third:GetText())
check(act.third.w >= act.third:GetStringWidth() and act.third.w <= 264 - 2 * 12, "the fps line is as wide as its words, not cut short")
local goal0, pace0 = ns.db.smart.goal, ns.db.smart.pace
ns.db.smart.goal, ns.db.smart.pace = "balanced", "balanced"
check(UI.SmartStyle() == "Balanced", "the same goal and pace name shows once: " .. UI.SmartStyle())
ns.db.smart.goal, ns.db.smart.pace = goal0, pace0
local w0 = act.line[1].w
W.advance(0.4)
check(act.line[1].w ~= w0 and act.line[1]:IsShown(), "the line breathes while it works")
batch("smart", { { cvar = "RenderScale", from = 1, to = 0.9 } })
check(smartSlot().text:GetText():find("^" .. L.ACTIVITY_LOWER) and smartSlot().subIcon.atlas == "minimal-scrollbar-arrow-bottom", "a batch that lowers: Easing graphics for FPS, down")
W.advance(4.5)
act = smartSlot()
check(act and act.text:GetText() == "Graphics optimized" and not act.item.shimmer and act.sub:GetText() == "5 settings changed" and not act.sub:GetText():find("...", 1, true), "no batch for 4 s: the summary, its count said once, the list too long for the line left to the tooltip: " .. tostring(act and act.sub:GetText()))
local tipLines = tipOf(act)
check(#tipLines == 5 and tipLines[1] == "Shadow quality Fair to Good" and tipLines[2] == "View distance 2 to 6" and tipLines[5] == "Render scale 100% to 90%", "the tooltip lists the net changes, oldest first")
W.mouseOver = act
W.advance(7)
check(smartSlot(), "hover keeps it open")
W.mouseOver = nil
W.advance(6.5)
check(not smartSlot(), "then it fades out (6 s)")
batch("smart", { { cvar = "RenderScale", from = 0.8, to = 0.75 } })
batch("smart", { { cvar = "RenderScale", from = 0.75, to = 0.8 } })
check(smartSlot(), "a flip shows while it works")
W.advance(4.5)
check(not smartSlot(), "but a net-zero run shows no summary")
batch("smart", { { cvar = "RenderScale", from = 0.8, to = 0.75 } })
batch("smart", { { cvar = "graphicsShadowQuality", from = 3, to = 2 } })
batch("smart", { { cvar = "RenderScale", from = 0.75, to = 0.8 } })
W.advance(4.5)
check(smartSlot() and smartSlot().text:GetText() == "Eased for FPS" and smartSlot().sub:GetText():find("^1 setting changed") and #tipOf(smartSlot()) == 1, "a flip nets out of the summary")
UI.Notify.Hide("smart")
-- The title follows the newest change, whatever most of the batch did; no fps reading yet is "--", never 0.
st.fps = nil
batch("smart", { { cvar = "RenderScale", from = 0.8, to = 0.7 }, { cvar = "shadowSoft", from = 3, to = 2 }, { cvar = "graphicsShadowQuality", from = 2, to = 3 } })
check(smartSlot().text:GetText() == L.ACTIVITY_RAISE and smartSlot().subIcon.atlas == "minimal-scrollbar-arrow-top", "a raise last shows Optimizing graphics: " .. smartSlot().text:GetText())
check(smartSlot().third:GetText():find("^%-%- / 75 fps") and not smartSlot().third:GetText():find("^0 "), "no fps yet: -- / 75 fps, never 0: " .. smartSlot().third:GetText())
batch("smart", { { cvar = "RenderScale", from = 0.7, to = 0.6 } })
check(smartSlot().text:GetText() == L.ACTIVITY_LOWER, "a lower last: Easing graphics for FPS")
st.fps = 75
UI.Notify.Hide("smart")
ns.db.options.smartNotice = false
batch("smart", { { cvar = "RenderScale", from = 0.9, to = 0.95 } })
check(not smartSlot(), "the option off: no Smart notice")
ns.db.options.smartNotice = true
UI.OpenPanel("overview")
batch("smart", { { cvar = "RenderScale", from = 0.95, to = 1 } })
check(not smartSlot(), "no Smart notice while the window is open")
UI.CloseAll()

-- A profile switch: "Now using <profile> · <location>" with what it changed, 5 s; with nothing changed, 2.5 s.
batch("profile", { { cvar = "graphicsShadowQuality", from = 3, to = 2 }, { cvar = "RenderScale", from = 1, to = 0.8 } }, "City")
local prof = slotOf("profile")
check(prof and prof.text:GetText() == "Now using City · City" and prof.sub:GetText() == "2 settings changed", "a profile batch: Now using, with the change count")
check(prof.item.sub == "2 settings changed: Shadow quality High to Good, Render scale 100% to 80%", "the list stays in the item for a line wide enough")
check(#tipOf(prof) == 2, "its tooltip lists the batch")
W.advance(5.5)
check(not slotOf("profile"), "gone after 5 s")
ns.activeOverride = { loc = { key = "raid", name = "Molten Core" }, profileId = "default", profileName = "Default", source = "default" }
ns.Fire("FSG_LOCATION")
W.advance(0.05)
prof = slotOf("profile")
check(prof and prof.text:GetText() == "Now using Default · Raid" and prof.sub:GetText() == "", "a switch that changes nothing still says Now using")
W.advance(3)
check(not slotOf("profile"), "for 2.5 s")
ns.activeOverride = nil
ns.db.options.notifyProfile = false
batch("profile", { { cvar = "RenderScale", from = 1, to = 0.8 } }, "City")
check(not slotOf("profile"), "the option off: no profile notice")
ns.db.options.notifyProfile = true
batch("restore", { { cvar = "RenderScale", from = 0.8, to = 1 } }, "Restore original")
check(slotOf("done") and slotOf("done").text:GetText() == L.RESTORED, "a restore says so")
UI.Notify.Hide("done")
batch("apply", { { cvar = "graphicsTextureResolution", from = 1, to = 2 } }, "Apply now")
check(slotOf("done") and slotOf("done").text:GetText() == L.APPLIED_TEXTURE, "Apply now says the texture change applied")
UI.Notify.Hide("done")
ns.adjust = { running = true, key = "map:85", name = "Orgrimmar", seconds = 10, changes = {} }
ns.Fire("FSG_ADJUST", ns.adjust)
batch("adjust", { { cvar = "RenderScale", from = 1, to = 0.9 } }, "Smart adjust")
check(slotOf("adjust").sub:GetText() == "Render scale 100% to 90%" and #tipOf(slotOf("adjust")) == 1, "a Smart adjust batch shows in its notice")
ns.adjust = nil
ns.Fire("FSG_ADJUST", nil)

-- Low FPS in a fight: a notice with Lower now and After combat; nothing changes on its own.
W.combat = true
ns.Fire("FSG_COMBAT_START")
batch("smart", { { cvar = "RenderScale", from = 1, to = 0.95 } })
check(not smartSlot(), "no activity notice in combat")
ns.Fire("FSG_COMBAT_LOW", { fps = 48.2, goal = 75, cuts = { "graphicsShadowQuality", { cvar = "RenderScale" } } })
local fight = slotOf("combat")
check(fight and fight.text:GetText() == "Low FPS in this fight: 48 / 75" and fight.sub:GetText() == "Shadow quality, Render scale", "the combat notice with the proposed cuts")
check(fight.buttons[1]:GetText() == L.LOWER_NOW and fight.buttons[2]:GetText() == L.AFTER_COMBAT, "Lower now and After combat")
fight.buttons[1]:Click()
check(last(ns, "ApplyCombatCuts") and not slotOf("combat"), "Lower now")
ns.Fire("FSG_COMBAT_LOW", { fps = 48, goal = 75, cuts = { "graphicsShadowQuality" } })
slotOf("combat").buttons[2]:Click()
check(last(ns, "DeferCombatCuts") and not slotOf("combat"), "After combat")
ns.Fire("FSG_COMBAT_LOW", { fps = 48, goal = 75, cuts = { "graphicsShadowQuality" } })
W.combat = false
ns.Fire("FSG_COMBAT_END")
check(not slotOf("combat"), "it hides when combat ends")
batch("profile", { { cvar = "graphicsShadowQuality", from = 3, to = 2 }, { cvar = "RenderScale", from = 1, to = 0.9 } }, "after combat")
check(slotOf("done") and slotOf("done").text:GetText() == "Applied after combat: 2 changes", "the after-combat summary")
W.advance(5.5)
check(not slotOf("done"), "and it fades")
ns.smartState = nil
ns.db.smart.enabled = false
UI.Notify.Hide("pending")
ns.Fire("FSG_PENDING", { values = { graphicsTextureResolution = 2 }, seconds = 5 })
slotOf("pending").buttons[1]:Click()
check(last(ns, "ApplyPending")[2] == "user" and last(ns, "ApplyPending")[3].user == true, "Apply now is the player's own")
ns.Fire("FSG_PENDING", nil)

-- Combat closes the window and offers it again after.
ns.TogglePanel()
check(main:IsShown(), "open again")
ns.Fire("FSG_COMBAT_START")
check(not main:IsShown() and UI.Current() == nil, "combat start closes the window")
W.combat = true
ns.TogglePanel()
check(UI.Current() == nil, "no opening in combat")
W.combat = false
ns.Fire("FSG_COMBAT_END")
W.advance(0.6)
local offer = UI.Current()
check(offer and offer ~= main and offer.text:GetText() == L.RESUME_TEXT, "resume offered after combat")
W.press(offer, "PAD1")
check(UI.Current() == main and main:IsShown(), "resume reopens the window")
-- No text is cut on any page at the default scale (W.truncated measures as the store screenshots did).
for _, key in ipairs({ "overview", "profiles", "profile", "locations", "smart", "general" }) do
	UI.OpenPanel(key, key == "profile" and "p1" or nil)
	W.advance(1.1)
	local cut = W.truncated()
	check(#cut == 0, key .. ": no text cut: " .. table.concat(cut, "; "))
end
open("general")
local announce = labelled(L.ANNOUNCE).region
check(announce.control.x == 340 and announce.label.w == 293 and labelled(L.CONTROLS).region.choice.x == 340, "Options: one control column at 340, labels up to it")
UI.CloseAll()

-- No Smart.lua: the Smart tab says so.
local bare = stubNS(false)
local UI2 = load(bare)
UI2.OpenPanel("smart")
local main2 = UI2.Main()
check(main2:IsShown() and UI2.Selection().key == "smart" and #main2.nodes == 6, "Smart page without Smart.lua: only the categories and Close")
check(pcall(UI2.LocationsTab.Focus, "map:1"), "focusing a place before the Locations tab is built does not throw")
UI2.CloseAll()

check(#W.trapped == 0, "no forbidden Blizzard UI touched: " .. table.concat(W.trapped, ", "))
local ALLOWED_GLOBALS = { ForeverSmartGraphicsCalibrate = true, ForeverSmartGraphics_OnCompartmentClick = true, ForeverSmartGraphics_OnCompartmentEnter = true, ForeverSmartGraphics_OnCompartmentLeave = true, ForeverSmartGraphicsDialog = true, ForeverSmartGraphicsMinimapButton = true, ForeverSmartGraphicsMinimapFps = true, ForeverSmartGraphicsCreate = true, MinimapCluster = true, ForeverSmartGraphicsToast = true }
for k in pairs(_G) do check(before[k] or ALLOWED_GLOBALS[k], "stray global " .. tostring(k)) end

io.write(checks .. " checks passed\n")
