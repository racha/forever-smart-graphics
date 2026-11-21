-- Calibrate.lua spec: loads Smart.lua + Calibrate.lua over a minimal ns stub. Run: lua ForeverSmartGraphics/tests/calibrate_spec.lua
local script = arg and arg[0] or ""
local dir = script:match("^(.*)[/\\]tests[/\\]") or (script:match("^tests[/\\]") and ".") or "ForeverSmartGraphics"

local passed, failures = 0, {}
local function check(name, cond, detail)
	if cond then passed = passed + 1 else failures[#failures + 1] = name .. (detail ~= nil and (": " .. tostring(detail)) or "") end
end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) <= (eps or 1e-6) end

local T, store, frame
GetTime = function() return T end
time = function() return math.floor(T) end
CreateFrame = function()
	local f = { scripts = {} }
	function f:SetScript(name, fn) self.scripts[name] = fn end
	frame = f
	return f
end
C_CVar = { GetCVar = function(name) return store[name] ~= nil and tostring(store[name]) or nil end }
GetUnitSpeed = function() return 7 end
GetSubZoneText = function() return "" end
GetRealZoneText = function() return "Somewhere" end
C_Timer = { After = function() end }

local LIST = {
	{ cvar = "graphicsSSAO", min = 0, max = 4, step = 1, visual = 2, smart = true },
	{ cvar = "RenderScale", min = 0.33, max = 1.0, step = 0.05, visual = 4, smart = true },
	{ cvar = "textureFilteringMode", min = 0, max = 5, step = 1, visual = 1, smart = true, heavy = true },
	{ cvar = "shadowSoft", min = 0, max = 1, step = 1, visual = 2, smart = true },
	{ cvar = "weatherDensity", min = 0, max = 3, step = 1, visual = 1 },
}
local byCvar = {}
for _, e in ipairs(LIST) do byCvar[e.cvar] = e end

local PROBED = { RenderScale = 6, shadowSoft = 11, graphicsSSAO = 2.5, graphicsLightMode = 2.5, graphicsComputeEffects = 2, ResampleQuality = 3 }

local ns, locKey
local function fresh(values, smartOn)
	T, locKey = 1000, "city"
	store = { RenderScale = 0.75, shadowSoft = 1, graphicsSSAO = 3, textureFilteringMode = 5, weatherDensity = 3, useMaxFPS = "0", maxFPS = 0 }
	for k, v in pairs(values or {}) do store[k] = v end
	local handlers = {}
	local n = { commands = {}, logs = {}, fired = {}, writes = {}, switching = {}, created = {}, assigned = {}, held = {} }
	function n.On(event, fn) handlers[event] = handlers[event] or {}; table.insert(handlers[event], fn) end
	function n.Fire(msg, ...) n.fired[#n.fired + 1] = msg; for _, fn in ipairs(handlers[msg] or {}) do fn(...) end end
	function n.log(msg) n.logs[#n.logs + 1] = msg end
	function n.debug() end
	function n.plain(v) return v end
	function n.InCombat() return false end
	function n.Get(cvar) return store[cvar] ~= nil and tostring(store[cvar]) or nil end
	n.db = { options = { switching = true }, smart = { enabled = false, target = 60, scaleFloor = 0.6, learned = {} }, unsupported = {} }
	n.Catalog = {
		LIST = LIST,
		PRIOR = { RenderScale = 6, shadowSoft = 11, graphicsSSAO = 2.5 },
		-- Like the real Catalog: a gain only for probed knobs.
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
		Effective = function() return { RenderScale = 1, shadowSoft = 1, graphicsSSAO = 4, textureFilteringMode = 5, weatherDensity = 2 } end,
		Create = function(name, values) n.created[#n.created + 1] = { name = name, values = values }; return "p" .. #n.created end,
		Get = function(id) return { id = id, name = n.created[tonumber(id:sub(2))].name } end,
		AssignAll = function(id) n.assigned[#n.assigned + 1] = id end,
	}
	n.Location = { LABELS = { city = "City", outdoor = "Open world" }, Current = function() return { key = locKey } end, ProfileFor = function() return "default" end }
	n.Apply = {
		Write = function(cvar, value)
			if n.InCombat() then
				n.held[#n.held + 1] = { cvar, value }
				return false, "combat"
			end
			n.writes[#n.writes + 1] = { cvar, value }
			store[cvar] = value
			return true, value
		end,
		Refresh = function() end,
		SetSwitching = function(on) n.switching[#n.switching + 1] = on; n.db.options.switching = on end,
	}
	ns = n
	assert(loadfile(dir .. "/Smart.lua"))("ForeverSmartGraphics", ns)
	assert(loadfile(dir .. "/Calibrate.lua"))("ForeverSmartGraphics", ns)
	ns.Fire("FSG_READY")
	-- Smart.Limit (contract 1) may not be in Smart.lua yet; nil means no known limit.
	ns.Smart.Limit = function() return nil end
	if smartOn then ns.Smart.SetEnabled(true) end
	ns.writes = {}
	return ns.Calibrate
end

local function run(seconds, fps)
	local stop = T + seconds
	while T < stop do
		local f = type(fps) == "function" and fps(store) or fps
		T = T + 1 / f
		local onUpdate = frame.scripts.OnUpdate
		if onUpdate then onUpdate(frame, 1 / f) end
	end
end

local function goTo(key, loading)
	locKey = key
	ns.Fire("FSG_LOCATION", { key = key }, nil, loading)
end

local function writesOf(cvar)
	local out = {}
	for _, w in ipairs(ns.writes) do if w[1] == cvar then out[#out + 1] = w[2] end end
	return out
end

-- Start / Stop restore everything.
do
	local C = fresh(nil, true)
	check("start: ok", C.Start(60) == true)
	check("start: smart off", not ns.Smart.Enabled())
	check("start: switching paused", ns.switching[1] == false)
	check("start: fires", ns.fired[#ns.fired] == "FSG_CALIBRATE")
	local s = C.State()
	check("state: running, target, scene", s.running and s.target == 60 and s.current.locKey == "city" and s.current.label == "City" and s.current.status == "searching")
	check("state: hint searching", s.hint == "Move around here for about a minute")
	local again, reason = C.Start(70)
	check("start: refuses double start", again == false and reason == "already running")
	run(30, 40)
	check("search lowered something", store.RenderScale < 0.75)
	local ch = C.State().changes
	check("changes: newest first, from before the write", #ch >= 1 and C.State().last.cvar == ns.writes[#ns.writes][1] and ch[1].to == ns.writes[#ns.writes][2] and ch[#ch].cvar == "shadowSoft" and ch[#ch].from == 1 and ch[#ch].to == 0 and ch[#ch].t > 1000)
	check("stop: ok", C.Stop() == true)
	check("stop: knob snapshot back", near(store.RenderScale, 0.75) and store.shadowSoft == 1 and store.graphicsSSAO == 3)
	check("stop: switching back", ns.switching[#ns.switching] == true)
	check("stop: smart stays off", not ns.Smart.Enabled())
	check("stop: no changes when not running", #C.State().changes == 0 and C.State().last == nil)
	check("stop: not running", not C.State().running and C.Stop() == false)
	check("never heavy", #writesOf("textureFilteringMode") == 0 and #writesOf("weatherDensity") == 0)
end

-- A scene converges down under low fps (quality first, render scale as the bracket needs) and is done after 120 s.
do
	local C = fresh()
	C.Start(60)
	run(60, 40)
	local rs = writesOf("RenderScale")
	check("down: down the ladder (soft shadows, then render scale)", ns.writes[1][1] == "shadowSoft" and ns.writes[4][1] == "RenderScale" and #rs == 3 and near(store.RenderScale, 0.6))
	check("down: the ladder's SSAO rungs end at 2", store.shadowSoft == 0 and store.graphicsSSAO == 2)
	check("down: not done before 120 s", not C.State().scenes[1].done)
	run(70, 40)
	local sc = C.State().scenes[1]
	check("down: done after 120 s", sc.done and sc.seconds == 120 and C.State().current.status == "done", sc.seconds)
	check("down: hint go elsewhere", C.State().hint == "Done here. Now go to the open world or a city")
	check("down: its own steps feed no gains (reactive)", next(ns.db.smart.gains) == nil)
	local n = #ns.writes
	run(30, 40)
	check("down: done scene stays put", #ns.writes == n)
end

-- ... and up under high fps, quality and render scale together; done after 20 s holding.
do
	local C = fresh({ RenderScale = 0.6, shadowSoft = 0, graphicsSSAO = 0 })
	C.Start(60)
	run(100, 300)
	check("up: SSAO first, render scale to 1.0", ns.writes[1][1] == "graphicsSSAO" and near(store.RenderScale, 1.0))
	check("up: knobs to max", store.graphicsSSAO == 4 and store.shadowSoft == 1)
	local ch, w = C.State().changes, ns.writes
	local ordered = #w > 6 and #ch == 6
	for i = 1, #ch do
		local c, wi = ch[i], w[#w - i + 1]
		ordered = ordered and c.cvar == wi[1] and near(c.to, wi[2]) and near(c.to - c.from, byCvar[c.cvar].step) and (i == 1 or c.t <= ch[i - 1].t)
	end
	check("changes: capped at 6, newest first", ordered, #ch)
	check("changes: last is the newest", C.State().last.cvar == w[#w][1] and near(C.State().last.to, w[#w][2]))
	check("up: done by holding", C.State().scenes[1].done and C.State().scenes[1].seconds < 120, C.State().scenes[1].seconds)
end

-- Scene results, conservative merge, Finish.
local function cityModel(s) return 46 + (3 - s.graphicsSSAO) * 5 + (1 - s.RenderScale) * 100 end
local function outdoorModel(s) return 40 + (3 - s.graphicsSSAO) * 5 + (1 - s.RenderScale) * 100 end
do
	local C = fresh({ RenderScale = 1.0 })
	C.Start(58)
	run(40, cityModel)
	local city = C.State().scenes[1]
	check("scene: city holds at scale 0.85, SSAO untouched", city.done and city.values.graphicsSSAO == 3 and near(city.values.RenderScale, 0.85) and city.locKey == "city" and city.label == "City", city.values and city.values.RenderScale)
	check("scene: fpsP10", near(city.fpsP10, 61, 0.5), city.fpsP10)
	check("scene: not ready with one", not C.State().ready)
	goTo("outdoor")
	check("scene: new scene for a new type", #C.State().scenes == 2 and C.State().current.locKey == "outdoor")
	run(40, outdoorModel)
	local outdoor = C.State().scenes[2]
	check("scene: outdoor cuts soft shadows (tier 1) before scale 0.8", outdoor.done and near(outdoor.values.RenderScale, 0.8) and outdoor.values.shadowSoft == 0 and outdoor.values.graphicsSSAO == 3, outdoor.values and outdoor.values.RenderScale)
	check("ready: two scenes done", C.State().ready and C.State().hint == "Ready: press Finish or visit another kind of place")
	store.RenderScale, store.graphicsSSAO = 1.0, 4
	goTo("city")
	check("scene: next scene starts from the most conservative", near(store.RenderScale, 0.8) and store.graphicsSSAO == 3 and store.shadowSoft == 0)
	goTo("city", true)
	check("scene: loading starts a new scene", #C.State().scenes == 4)
	local id = C.Finish()
	local made = ns.created[1]
	check("finish: profile created", id == "p1" and made.name == "Best for 58 FPS")
	check("finish: most conservative values over Default", near(made.values.RenderScale, 0.8) and made.values.graphicsSSAO == 3 and made.values.shadowSoft == 0 and made.values.weatherDensity == 2 and made.values.textureFilteringMode == 5)
	check("finish: assigned everywhere", ns.assigned[1] == id)
	check("finish: smart stays off", not ns.Smart.Enabled())
	check("finish: switching restored", ns.switching[#ns.switching] == true)
	check("finish: chat line", ns.logs[#ns.logs] == 'Saved "Best for 58 FPS" and set it everywhere.', ns.logs[#ns.logs])
	check("finish: over", not C.State().running and C.Finish() == nil)
end
do
	local C = fresh()
	C.Start(60)
	run(15, 40)
	local id, reason = C.Finish()
	check("finish: needs 30 s", id == nil and reason and reason:find("30"), reason)
	check("finish: still running after refusal", C.State().running)
end

-- Finish after a start with smart on leaves smart off.
do
	local C = fresh(nil, true)
	C.Start(60)
	run(40, 40)
	check("finish: smart was on, stays off", C.Finish() ~= nil and not ns.Smart.Enabled())
end

-- Start cancels a running Smart adjust before taking its snapshot.
do
	local C = fresh()
	goTo("city")
	check("adjust first: started", ns.Smart.AdjustPlace() == true)
	run(20, 30)
	check("adjust first: lowered", store.RenderScale < 0.75)
	C.Start(60)
	check("adjust first: cancelled, values back", not ns.Smart.AdjustState().running and near(store.RenderScale, 0.75))
	run(10, 30)
	C.Stop()
	check("adjust first: Stop restores the values from before the adjust", near(store.RenderScale, 0.75) and store.shadowSoft == 1 and store.graphicsSSAO == 3)
end

-- In combat the search pauses: nothing written or held, and a held write is not a failure.
do
	local C = fresh()
	C.Start(60)
	run(10, 40)
	local n = #ns.writes
	local fighting = true
	ns.InCombat = function() return fighting end
	run(60, 40)
	check("combat: paused, nothing written or held", #ns.writes == n and #ns.held == 0 and C.State().current.status == "paused")
	goTo("outdoor")
	check("combat: a new scene's start waits for the fight to end", #ns.held == 0)
	fighting = false
	run(10, 40)
	check("combat: then the search goes on", #ns.writes > n and C.State().current.status ~= "paused")
	local failedOnes = 0
	ns.Smart._Fail = function() failedOnes = failedOnes + 1 end
	fighting = true
	C.Stop()
	check("combat: writes held by the engine are not failures", #ns.held > 0 and failedOnes == 0, failedOnes)
end

-- Logout stops and restores.
do
	local C = fresh(nil, true)
	C.Start(60)
	run(20, 40)
	ns.Fire("PLAYER_LOGOUT")
	check("logout: stopped", not C.State().running)
	check("logout: restored, smart off", near(store.RenderScale, 0.75) and store.shadowSoft == 1 and not ns.Smart.Enabled())
end

-- Slash commands.
do
	local C = fresh()
	ns.commands.findbest("75")
	check("slash: findbest fps", C.State().running and C.State().target == 75)
	ns.commands.stop()
	check("slash: stop", not C.State().running and ns.logs[#ns.logs] == "Stopped. Your settings are back as they were. Smart mode is off.")
	ns.commands.stop()
	check("slash: stop when not running", ns.logs[#ns.logs] == "Find my best settings is not running.")
	ns.commands.findbest("")
	check("slash: findbest defaults to smart target", C.State().target == 60)
	ns.commands.finish()
	check("slash: finish too early", ns.logs[#ns.logs]:find("Not yet") ~= nil)
	ns.commands.stop()
	ns.commands.findbest({ "60" })
	check("slash: findbest with Core word table", C.State().running and C.State().target == 60)
	ns.commands.stop({})
	ns.commands.findbest({ "45" })
	check("slash: findbest table target", C.State().target == 45)
end

-- A display or frame cap at the target reads a little under it: that holds, nothing is cut.
for _, fps in ipairs({ 59.94, 60.0 }) do
	local C = fresh()
	ns.Smart.Limit = function() return 60 end
	C.Start(60)
	run(25, fps)
	local sc = C.State().scenes[1]
	check(("capped %.2f: done in 20 s"):format(fps), sc.done and sc.seconds == 20, sc.seconds)
	check(("capped %.2f: nothing changed"):format(fps), #ns.writes == 0, #ns.writes)
	C.Finish()
	local made = ns.created[1]
	check(("capped %.2f: saved as found"):format(fps), made and near(made.values.RenderScale, 0.75) and made.values.shadowSoft == 1 and made.values.graphicsSSAO == 3)
end
do
	local C = fresh()
	C.Start(60)
	run(30, 45)
	check("short of the target: still cut", store.RenderScale < 0.75 and store.shadowSoft == 0, store.RenderScale)
	C.Stop()
	fresh()
	ns.Smart.Limit = function() return 50 end
	ns.Calibrate.Start(60)
	check("a limit under the target becomes the target", ns.Calibrate.State().target == 50)
end

-- The game's own Target FPS is off during a run and back after it.
do
	local C = fresh({ useTargetFPS = 1 })
	C.Start(60)
	check("target fps: off at start", store.useTargetFPS == 0)
	C.Stop()
	check("target fps: back at stop", store.useTargetFPS == 1)
	C = fresh({ useTargetFPS = 1 })
	C.Start(60)
	run(40, 40)
	C.Finish()
	check("target fps: back at finish", store.useTargetFPS == 1)
	C = fresh({ useTargetFPS = 0 })
	C.Start(60)
	C.Stop()
	check("target fps: left alone when off", #writesOf("useTargetFPS") == 0)
end

-- Steps carry their own reason for the chat log.
do
	local C, reasons = fresh(), {}
	local write = ns.Apply.Write
	ns.Apply.Write = function(cvar, value, reason) reasons[#reasons + 1] = reason; return write(cvar, value) end
	C.Start(60)
	run(10, 40)
	check("reason: Find my best settings", #reasons > 0 and reasons[1] == "Find my best settings" and reasons[#reasons] == "Find my best settings", reasons[1])
end

-- Restore original stops a run and leaves switching off.
do
	local C = fresh()
	C.Start(60)
	run(10, 40)
	ns.Apply.RestoreOriginal = function()
		ns.Calibrate.Stop({ keepOff = true })
		ns.Apply.SetSwitching(false)
	end
	ns.Apply.RestoreOriginal()
	check("restore: run stopped", not C.State().running)
	-- Turning switching on, even for a moment, refreshes and writes the profile over the restore.
	local flipped = false
	for i = 2, #ns.switching do flipped = flipped or ns.switching[i] == true end
	check("restore: switching stays off", ns.db.options.switching == false and not flipped, #ns.switching)
end

-- The game font draws U+2192 and U+2212 as squares.
do
	local f = assert(io.open(dir .. "/Calibrate.lua", "rb"))
	local src = f:read("*a")
	f:close()
	check("ascii: no U+2192 or U+2212", not src:find("\226\134\146", 1, true) and not src:find("\226\136\146", 1, true))
end

for _, f in ipairs(failures) do print("FAIL " .. f) end
print(("calibrate_spec: %d passed, %d failed"):format(passed, #failures))
if #failures > 0 then os.exit(1) end
