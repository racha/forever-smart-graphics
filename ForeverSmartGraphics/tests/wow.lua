-- Shared WoW stubs for the specs (adapted from Forever Controller Tweaks' harness). Not a spec itself.
-- local W = dofile(here .. "/wow.lua")(here .. "/..", { db = ..., cvars = ..., files = ... })
--   W.cvars[name]         the CVar store (strings); W.ignore[name] = value makes a write read back that value instead.
--   W.clamp[name] = n caps a write at n, like a client limit.
--   W.cascade[name] = fn(value) runs after a write, like a graphics* preset rewriting engine cvars.
--   W.instance / W.resting / W.mapID / W.zone / W.subzone   what the location APIs return.
--   opts.maxScale / opts.aa   what GetMaxRenderScale and AntiAliasingSupported return (read when the Catalog loads).
--   W.meta[field]         what C_AddOns.GetAddOnMetadata returns (Version, X-Website).
--   W.writes              every SetCVar call in order: { cvar, value }.
--   W.run(seconds, fps)   advances the clock frame by frame, running OnUpdate, tickers and timers.
local ENGINE = { "Core.lua", "NewsData.lua", "News.lua", "Catalog.lua", "Profiles.lua", "Location.lua", "Apply.lua" }

local DEFAULT_CVARS = {
	graphicsShadowQuality = "3", graphicsLiquidDetail = "2", graphicsPBRLiquidDetail = "1", graphicsParticleDensity = "4",
	graphicsSSAO = "3", graphicsDepthEffects = "2", graphicsComputeEffects = "2", graphicsOutlineMode = "1",
	graphicsTextureResolution = "2", graphicsSpellDensity = "1", graphicsProjectedTextures = "1", graphicsLightMode = "1",
	graphicsViewDistance = "5", graphicsEnvironmentDetail = "5", graphicsGroundClutter = "5",
	RenderScale = "0.75", ResampleQuality = "3", textureFilteringMode = "5",
	shadowSoft = "0", groundEffectDensity = "64", groundEffectDist = "200", groundEffectFade = "100", terrainLodDist = "450",
	wmoLodDist = "650", horizonStart = "1500", lodObjectCullSize = "20", lodObjectFadeScale = "90", sunShafts = "1",
	weatherDensity = "2", ffxglow = "1", reflectionMode = "1", shadowTextureSize = "2048", vrsValar = "0", shadowrt = "0",
	shadowNumCascades = "3", assaoBlurPassCount = "2", ResampleAlwaysSharpen = "0", doodadLodScale = "100",
	ffxAntiAliasingMode = "1", useTargetFPS = "1", targetFPS = "60", maxFPS = "73", useMaxFPS = "1",
}

return function(dir, opts)
	opts = opts or {}
	local W = { now = 100, combat = false, lines = {}, frames = {}, tickers = {}, timers = {}, writes = {}, fps = 60 }

	local function copy(v)
		if type(v) ~= "table" then return v end
		local o = {}
		for k, x in pairs(v) do o[k] = copy(x) end
		return o
	end
	W.copy = copy

	function W.same(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in pairs(a) do if not W.same(v, b[k]) then return false end end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end

	W.cvars = copy(DEFAULT_CVARS)
	for k, v in pairs(opts.cvars or {}) do W.cvars[k] = v end
	W.ignore, W.cascade, W.clamp = {}, {}, {}
	W.instance = { "", "none", 0, "", 0, 0, false, 0 }
	W.resting, W.mapID, W.zone, W.subzone = false, 1412, "Mulgore", ""
	W.levels = opts.levels

	local function lowerKey(name)
		for k in pairs(W.cvars) do if k:lower() == name:lower() then return k end end
		return name
	end

	function print(msg) W.lines[#W.lines + 1] = tostring(msg) end
	function date() return "12:00:00 " end
	function GetTime() return W.now end
	function time() return math.floor(W.now) end
	function GetFramerate() return W.fps end
	function InCombatLockdown() return W.combat end
	function UnitAffectingCombat() return W.combat end
	function GetBuildInfo() return "1.60.1", "12345", "", 16001 end
	function GetMinRenderScale() return 0.33 end
	function GetMaxRenderScale() return opts.maxScale or 2.0 end
	-- opts.aa = { fxaa, cmaa, cmaa2 } (default all supported); false removes the API.
	AntiAliasingSupported = opts.aa ~= false and function() return (table.unpack or unpack)(opts.aa or { true, true, true }) end or nil
	function GetInstanceInfo() return (table.unpack or unpack)(W.instance) end
	function IsResting() return W.resting end
	function GetRealZoneText() return W.zone end
	function GetSubZoneText() return W.subzone end
	C_Map = { GetBestMapForUnit = function() return W.mapID end }
	-- Optional table { [cvar] = { [level] = value } }; nil makes the Catalog fall back to its straight line.
	function GetGraphicsCVarValueForQualityLevel(cvar, level)
		if not W.levels then error("no quality table") end
		local row = W.levels[cvar]
		return row and row[level] or level
	end
	SlashCmdList = {}
	-- Version defaults to the repo checkout's dev build; set W.meta.Version (or opts.meta) per test.
	W.meta = opts.meta or { Version = "@project-version@", ["X-Website"] = "https://example.invalid/fsg" }
	C_AddOns = { GetAddOnMetadata = function(_, field) return W.meta[field] end }

	C_CVar = {
		GetCVar = function(name) return W.cvars[lowerKey(name)] end,
		SetCVar = function(name, value)
			local key = lowerKey(name)
			W.writes[#W.writes + 1] = { key, value }
			local limit = W.clamp[key]
			if limit and tonumber(value) > limit then value = limit end
			W.cvars[key] = W.ignore[key] or tostring(value)
			W.fire("CVAR_UPDATE", key)
			if W.cascade[key] then W.cascade[key](value) end
			return true
		end,
	}

	function CreateFrame()
		local f = { events = {}, scripts = {}, shown = true }
		function f:RegisterEvent(e) self.events[e] = true end
		function f:SetScript(name, fn) self.scripts[name] = fn end
		function f:Show() self.shown = true end
		function f:Hide() self.shown = false end
		W.frames[#W.frames + 1] = f
		return f
	end

	C_Timer = {
		NewTicker = function(interval, fn)
			local t = { fn = fn, interval = interval, nextAt = W.now + interval }
			function t:Cancel() self.cancelled = true end
			W.tickers[#W.tickers + 1] = t
			return t
		end,
		After = function(delay, fn) W.timers[#W.timers + 1] = { at = W.now + delay, fn = fn } end,
	}

	ForeverSmartGraphicsDB = opts.db
	W.ns = {}
	for _, file in ipairs(opts.files or ENGINE) do
		assert(loadfile(dir .. "/" .. file))("ForeverSmartGraphics", W.ns)
	end

	function W.fire(event, ...)
		for _, f in ipairs(W.frames) do
			if f.events[event] then f.scripts.OnEvent(f, event, ...) end
		end
	end

	function W.run(seconds, fps)
		fps = fps or 30
		for _ = 1, math.max(1, math.floor((seconds or 0.2) * fps + 0.5)) do
			W.now = W.now + 1 / fps
			for _, f in ipairs(W.frames) do
				if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 1 / fps) end
			end
			for _, t in ipairs(W.tickers) do
				if not t.cancelled and W.now >= t.nextAt - 1e-9 then
					t.nextAt = t.nextAt + t.interval
					t.fn()
				end
			end
			local due = {}
			for i = #W.timers, 1, -1 do if W.timers[i].at <= W.now + 1e-9 then table.insert(due, 1, table.remove(W.timers, i)) end end
			for _, t in ipairs(due) do t.fn() end
		end
	end

	function W.liveTickers()
		local n = 0
		for _, t in ipairs(W.tickers) do if not t.cancelled then n = n + 1 end end
		return n
	end

	function W.login()
		W.fire("ADDON_LOADED", "ForeverSmartGraphics")
		W.fire("PLAYER_LOGIN")
		W.fire("PLAYER_ENTERING_WORLD", true, false)
		W.run(1)
	end

	function W.setCombat(on)
		W.combat = on
		W.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
	end

	function W.slash(msg) SlashCmdList.FOREVERSMARTGRAPHICS(msg) end

	function W.said(pattern)
		for _, line in ipairs(W.lines) do if line:find(pattern) then return true end end
		return false
	end

	function W.wrote(cvar)
		for i, w in ipairs(W.writes) do if w[1] == cvar then return i, w[2] end end
	end

	function W.clearWrites() W.writes = {} end

	return W
end
