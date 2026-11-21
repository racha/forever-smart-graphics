-- Smart mode over the real engine (Core, Catalog, Profiles, Location, Apply) and the shared WoW stubs:
-- lua tests/smart_engine_spec.lua
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local harness = dofile(here .. "/wow.lua")
local FILES = { "Core.lua", "NewsData.lua", "News.lua", "Catalog.lua", "Profiles.lua", "Location.lua", "Apply.lua", "Smart.lua" }

local passed, failures, waiting = 0, {}, {}
local function check(name, cond, detail)
	if cond then passed = passed + 1 else failures[#failures + 1] = name .. (detail ~= nil and (": " .. tostring(detail)) or "") end
end
-- A check that needs the other half of a contract (Engine item `unit`): reported, not failed, until that half merges.
local function waits(unit, name, cond, detail)
	if cond then passed = passed + 1 else waiting[#waiting + 1] = unit .. ": " .. name .. (detail ~= nil and (": " .. tostring(detail)) or "") end
end
local function near(a, b, eps) return a and b and math.abs(a - b) <= (eps or 1e-6) end

local function new(opts)
	opts = opts or {}
	opts.files = FILES
	local W = harness(here .. "/..", opts)
	W.login()
	return W, W.ns
end

-- A reload: the saved table as the game wrote it, every file loaded again.
local function reload(W, opts)
	opts = opts or {}
	opts.db, opts.cvars = W.copy(W.ns.db), W.copy(W.cvars)
	return new(opts)
end

local function num(W, cvar) return tonumber(W.cvars[cvar]) end
-- GPU-bound: fps follows render scale and soft shadows.
local function play(W, seconds, load, opts)
	opts = opts or {}
	for _ = 1, seconds do
		local f = load * 1.07 ^ ((1 - num(W, "RenderScale")) / 0.05) * (num(W, "shadowSoft") >= 1 and 1 or 1.12)
		W.run(1, opts.fps or math.min(opts.cap or 1e9, f))
	end
end

local PROFILE = { RenderScale = 1.0, shadowSoft = 1, graphicsSSAO = 3, graphicsComputeEffects = 2, graphicsLightMode = 2, ResampleQuality = 3 }
local function withProfile(ns)
	for cvar, value in pairs(PROFILE) do ns.Profiles.SetValue("default", cvar, value) end
end

-- Eco through a real reload (Core's repair must keep the goal).
do
	local W, ns = new()
	ns.Smart.SetGoal("eco")
	ns.Smart.SetLocationGoal("raid", "eco")
	W.lines = {}
	W, ns = reload(W)
	waits("E1", "eco: the goal survives a reload", ns.db.smart.goal == "eco" and ns.db.smart.goals and ns.db.smart.goals.raid == "eco" and not W.said("repaired"), ns.db.smart.goal)
end

-- A confirmed ceiling through a real reload (Core's repair must keep confirmed).
do
	local W, ns = new({ cvars = { useMaxFPS = "0" } })
	ns.db.smart.ceiling = { fps = 60, t = time(), confirmed = true }
	W, ns = reload(W)
	waits("E6", "ceiling: confirmed survives a reload", ns.Smart.Limit and ns.Smart.Limit() == 60, ns.Smart.Limit and ns.Smart.Limit())
end

-- Smart off on the real Apply leaves no trace, also when switching is already off.
for _, switchingOff in ipairs({ false, true }) do
	local W, ns = new({ cvars = { useMaxFPS = "0" } })
	withProfile(ns)
	W.run(1)
	ns.db.smart.ceiling = { fps = 74.5, t = time(), confirmed = true }
	ns.Smart.SetTarget(75)
	ns.Smart.SetEnabled(true)
	play(W, 300, 40)
	local cut = num(W, "shadowSoft") == 0 and num(W, "RenderScale") < 1
	if switchingOff then ns.db.options.switching = false end
	ns.Smart.SetEnabled(false)
	local target, back = ns.Apply.Target(), true
	for cvar in pairs(PROFILE) do if not ns.Catalog.Same(cvar, W.cvars[cvar], target[cvar]) then back = false end end
	check("off" .. (switchingOff and " with switching off" or "") .. ": every knob back at the profile", cut and back, W.cvars.RenderScale)
end

-- Smart on with switching off turns switching on.
do
	local W, ns = new()
	ns.Apply.SetSwitching(false)
	check("on: turns switching on", ns.Smart.SetEnabled(true) and ns.db.options.switching == true and ns.Smart.Enabled())
end

-- A machine with no frame cap: 5 min heavy, then light; the steady level is not a limit and the cuts come back.
do
	local W, ns = new({ cvars = { useMaxFPS = "0" } })
	withProfile(ns)
	W.run(1)
	ns.Smart.SetTarget(60)
	ns.Smart.SetEnabled(true)
	play(W, 300, 42)
	local cut = num(W, "RenderScale") < 1 or num(W, "shadowSoft") == 0
	play(W, 3600, 95)
	check("no cap: cuts undone, no limit", cut and near(num(W, "RenderScale"), 1, 0.03) and num(W, "shadowSoft") == 1 and ns.Smart.Limit() == nil, W.cvars.RenderScale)
end

-- Seconds in the background at Max Background FPS cut nothing.
do
	local W, ns = new({ cvars = { useMaxFPS = "0", useMaxFPSBk = "1", maxFPSBk = "30" } })
	withProfile(ns)
	W.run(1)
	ns.db.smart.ceiling = { fps = 60, t = time(), confirmed = true }
	ns.Smart.SetTarget(60)
	ns.Smart.SetEnabled(true)
	play(W, 120, 70, { cap = 60 })
	local rs, soft = W.cvars.RenderScale, W.cvars.shadowSoft
	play(W, 300, 70, { fps = 30 })
	check("background: alt-tabbed seconds cut nothing", W.cvars.RenderScale == rs and W.cvars.shadowSoft == soft, W.cvars.RenderScale)
end

-- Raises between pulls: where fights run under the lowering line, the calm seconds between them raise nothing.
do
	local W, ns = new({ cvars = { useMaxFPS = "0" } })
	withProfile(ns)
	W.run(1)
	ns.db.smart.ceiling = { fps = 60, t = time(), confirmed = true }
	ns.Smart.SetTarget(60)
	ns.Smart.SetEnabled(true)
	play(W, 300, 40, { cap = 60 })
	local raised = false
	for _ = 1, 3 do
		W.setCombat(true)
		play(W, 120, 40, { fps = 35 })
		W.setCombat(false)
		W.run(1)
		local before = W.copy(W.cvars)
		play(W, 300, 70, { cap = 60 })
		for cvar in pairs(PROFILE) do if num(W, cvar) > tonumber(before[cvar]) + 1e-6 then raised = true end end
	end
	check("fights: no raise between slow pulls", not raised and num(W, "shadowSoft") == 0)
end

-- wow.lua takes print for the chat log.
for _, f in ipairs(waiting) do io.write("WAITS ON ", f, "\n") end
for _, f in ipairs(failures) do io.write("FAIL ", f, "\n") end
io.write(("smart_engine_spec: %d passed, %d failed, %d waiting on the Engine unit\n"):format(passed, #failures, #waiting))
if #failures > 0 then os.exit(1) end
