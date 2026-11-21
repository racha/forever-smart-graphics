-- Every graphics setting the addon knows: ranges, labels and the pure helpers on them. No writes here.
-- Entry kinds: "level" (integer 0..max, 0-1 toggles too), "scale" (RenderScale), "range" (numeric with a step),
-- "choice" (one of entry.choices).
local _, ns = ...
local Catalog = {}
ns.Catalog = Catalog

local RENDER_SCALE = "RenderScale"
local AA = "ffxAntiAliasingMode"
local EPSILON = 1e-6
local OFF_ON = { [0] = "Off", "On" }
local LOW_ULTRA = { [0] = "Low", "Fair", "Good", "High", "Ultra" }
local OFF_ULTRA = { [0] = "Off", "Low", "Good", "High", "Ultra" }
local OFF_HIGH = { [0] = "Off", "Low", "Good", "High" }
local PARTICLES = "graphicsParticleDensity"

-- Level ranges and names are the options Blizzard's Graphics settings offer (probed on 1.60.1).
local function level(cvar, label, max, extra)
	local entry = { cvar = cvar, group = "quality", label = label, kind = "level", min = 0, max = max, step = 1, visual = 1 }
	for k, v in pairs(extra or {}) do entry[k] = v end
	return entry
end

local function hidden(cvar, label, min, max, step, extra)
	local entry = { cvar = cvar, group = "hidden", label = label, kind = max - min > 5 and "range" or "level", min = min, max = max, step = step or 1, visual = 1 }
	for k, v in pairs(extra or {}) do entry[k] = v end
	return entry
end

Catalog.LIST = {
	level("graphicsShadowQuality", "Shadow quality", 5, { smart = true, visual = 3, names = { [0] = "Low", "Fair", "Good", "High", "Ultra", "Ultra High" } }),
	level("graphicsLiquidDetail", "Liquid detail", 3, { smart = true, names = { [0] = "Low", "Fair", "Good", "High" } }),
	level("graphicsPBRLiquidDetail", "Liquid shading", 2, { names = { [0] = "Low", "High", "Ultra" } }),
	level(PARTICLES, "Particle density", 5, { smart = true, visual = 2, min = 1, lo = 0, hi = 5, names = { [0] = "Off", "Low", "Fair", "Good", "High", "Ultra" } }),
	level("graphicsSSAO", "Ambient occlusion", 4, { smart = true, visual = 2, names = OFF_ULTRA }),
	level("graphicsDepthEffects", "Depth effects", 3, { smart = true, visual = 2, names = OFF_HIGH }),
	level("graphicsComputeEffects", "Compute effects", 4, { smart = true, visual = 2, names = LOW_ULTRA }),
	level("graphicsOutlineMode", "Outline mode", 2, { names = { [0] = "Off", "Good", "High" } }),
	level("graphicsTextureResolution", "Texture resolution", 2, { heavy = true, names = { [0] = "Low", "Fair", "High" } }),
	level("graphicsSpellDensity", "Spell density", 2, { smart = true, names = { [0] = "Essential", "Some", "Everything" } }),
	level("graphicsProjectedTextures", "Projected textures", 1, { names = { [0] = "Disabled", "Enabled" } }),
	level("graphicsLightMode", "Lighting quality", 3, { smart = true, visual = 3, names = { [0] = "Fair", "Good", "High", "Ultra" } }),
	level("graphicsViewDistance", "View distance", 9, { smart = true, visual = 4 }),
	level("graphicsEnvironmentDetail", "Environment detail", 9, { smart = true, visual = 3 }),
	level("graphicsGroundClutter", "Ground clutter", 9, { smart = true, visual = 2 }),
	{ cvar = RENDER_SCALE, group = "render", label = "Render scale", kind = "scale", min = 0.33, max = 2.0, lo = 0.33, hi = 2.0, step = 0.05, smart = true, visual = 4 },
	{ cvar = "ResampleQuality", group = "render", label = "Resample quality", kind = "level", min = 0, max = 3, step = 1, smart = true, visual = 2, names = { [0] = "Point", "Bilinear", "Bicubic", "FidelityFX" } },
	{ cvar = AA, group = "render", label = "Anti-aliasing", kind = "choice", lo = 0, hi = 4, step = 1, visual = 2, names = { [0] = "None", "FXAA Low", "FXAA High", "CMAA", "CMAA 2" } },
	{ cvar = "textureFilteringMode", group = "render", label = "Texture filtering", kind = "level", min = 0, max = 5, step = 1, heavy = true, visual = 1, names = { [0] = "Bilinear", "Trilinear", "2x Anisotropic", "4x Anisotropic", "8x Anisotropic", "16x Anisotropic" } },
	hidden("shadowSoft", "Soft shadows", 0, 1, 1, { smart = true, visual = 2, names = OFF_ON }),
	hidden("groundEffectDensity", "Grass density", 16, 256, 16, { smart = true, visual = 2 }),
	hidden("groundEffectDist", "Grass distance", 0, 500, 10),
	hidden("groundEffectFade", "Grass fade distance", 0, 510, 10),
	hidden("terrainLodDist", "Terrain detail distance", 100, 1000, 50),
	hidden("wmoLodDist", "Building detail distance", 100, 1200, 50),
	hidden("horizonStart", "Horizon distance", 400, 8000, 100),
	hidden("lodObjectCullSize", "Small object culling", 0, 100, 1),
	hidden("lodObjectFadeScale", "Object fade distance", 25, 400, 5),
	hidden("sunShafts", "Sun shafts", 0, 2, 1, { smart = true, names = { [0] = "Off", "Low", "High" } }),
	hidden("weatherDensity", "Weather density", 0, 3, 1, { names = { [0] = "Off", "Low", "Medium", "High" } }),
	hidden("ffxglow", "Glow effect", 0, 1, 1, { names = OFF_ON }),
	hidden("reflectionMode", "Reflections", 0, 3, 1, { names = { [0] = "Off", "Low", "Medium", "High" } }),
	{ cvar = "shadowTextureSize", group = "hidden", label = "Shadow map size", kind = "choice", choices = { 512, 1024, 1536, 2048, 4096 }, min = 512, max = 4096, heavy = true, visual = 1 },
	hidden("vrsValar", "Variable rate shading", 0, 2, 1, { names = { [0] = "Off", "Standard", "Aggressive" } }),
	hidden("shadowrt", "Ray traced shadows", 0, 3, 1, { names = { [0] = "Off", "Fair", "Good", "High" } }),
	hidden("shadowNumCascades", "Shadow cascades", 1, 4, 1, { visual = 3 }),
	hidden("assaoBlurPassCount", "AO smoothing", 0, 3, 1),
	hidden("ResampleAlwaysSharpen", "Always sharpen", 0, 1, 1, { visual = 2, names = OFF_ON }),
	hidden("doodadLodScale", "Small object detail", 25, 400, 25, { visual = 2 }),
}

-- What each setting does and what it costs. "probe": measured in game on a test machine; "estimate": its usual cost
-- in WoW (the probe saw it within noise on a GPU-bound Mac, or never stepped it).
local INFO = {
	graphicsShadowQuality = { "high", "estimate", "How sharp shadows are and how far from you they are drawn. Lower levels give blurry, blocky shadows that stop a short way off." },
	graphicsLiquidDetail = { "medium", "estimate", "How much detail water, lava and slime show. Higher levels add ripples and reflect the world around them." },
	graphicsPBRLiquidDetail = { "low", "estimate", "The lighting on water surfaces: how light reflects off and bends through it. Higher looks glossier and more realistic." },
	graphicsParticleDensity = { "medium", "estimate", "How many particles spells and the world give off: smoke, sparks, fire and magic effects. Mostly felt in big fights." },
	graphicsSSAO = { "medium", "probe", "Ambient occlusion: soft contact shadows in corners, creases and where objects meet the ground. Adds depth to the scene." },
	graphicsDepthEffects = { "low", "estimate", "Effects that depend on distance, such as heat shimmer and the soft blur on far-away scenery." },
	graphicsComputeEffects = { "medium", "probe", "Extra GPU effects such as fog that light shines through and particles that light the area around them." },
	graphicsOutlineMode = { "low", "estimate", "The glowing outline around the target or the object under your mouse. Off removes it." },
	graphicsTextureResolution = { "low", "probe", "How detailed the surfaces of everything look. Mostly uses video memory; changing it reloads textures with a short freeze." },
	graphicsSpellDensity = { "medium", "estimate", "How many spell effects from other players you see. Essential shows only the important ones; matters most in crowds and raids." },
	graphicsProjectedTextures = { "low", "estimate", "Effects painted onto the ground and walls, such as spell circles and area markers." },
	graphicsLightMode = { "medium", "probe", "How lights in the world are calculated. Higher levels let more lamps, fires and spells light up their surroundings." },
	graphicsViewDistance = { "high", "estimate", "How far away the world is drawn before it fades into the horizon. One of the costliest settings outdoors." },
	graphicsEnvironmentDetail = { "medium", "estimate", "How much scenery is drawn and in how much detail: trees, rocks and props, and how far out they stay detailed." },
	graphicsGroundClutter = { "medium", "estimate", "Grass, flowers and small plants on the ground, and how far away they still show." },
	RenderScale = { "very high", "probe", "The resolution the 3D world is drawn at before it is scaled to your screen. Lower is much faster but blurrier; above 100% is sharper and costs a lot of FPS. The interface stays sharp." },
	ResampleQuality = { "medium", "probe", "How the world is scaled to your screen when render scale is not 100%. FidelityFX keeps it sharpest; Point is blocky." },
	ffxAntiAliasingMode = { "low", "estimate", "Smooths jagged edges on the finished picture. FXAA is the cheapest; CMAA is sharper where your graphics card supports it. Multisampling (MSAA) needs a restart, so it stays in the game's own Graphics options." },
	textureFilteringMode = { "low", "estimate", "How sharp surfaces stay when seen at a slant, such as roads and floors stretching away. Changing it reloads textures." },
	shadowSoft = { "high", "probe", "Soft, natural shadow edges instead of hard ones. Looks nicer but costs about a tenth of your FPS." },
	groundEffectDensity = { "medium", "estimate", "How thick grass and small plants grow. Higher is a fuller, lusher ground." },
	groundEffectDist = { "medium", "estimate", "How far from you grass and small plants are drawn." },
	groundEffectFade = { "low", "estimate", "Where grass starts to fade out on its way to the grass distance. Higher fades it more gently." },
	terrainLodDist = { "medium", "estimate", "How far the ground keeps its full shape before switching to a simpler version. Higher keeps distant hills smooth." },
	wmoLodDist = { "low", "estimate", "How far buildings and other large structures keep their full detail before switching to a simpler version." },
	horizonStart = { "low", "estimate", "Where the far horizon starts. Higher pushes the distant scenery and its fog further out." },
	lodObjectCullSize = { "medium", "estimate", "How small an object can be before it is hidden in the distance. Lower keeps small far-away objects visible." },
	lodObjectFadeScale = { "medium", "estimate", "How far objects stay before fading out or swapping to a simpler model. Higher keeps them longer." },
	sunShafts = { "low", "estimate", "Rays of sunlight shining through trees, clouds and gaps in buildings." },
	weatherDensity = { "low", "estimate", "How heavy rain, snow and sandstorms look when the weather turns." },
	ffxglow = { "low", "estimate", "The soft glow around bright lights and sky. Off gives a flatter, crisper picture." },
	reflectionMode = { "medium", "estimate", "How much of the world is reflected in water and shiny surfaces." },
	shadowTextureSize = { "medium", "estimate", "The resolution of the shadow map. Larger gives crisper shadow edges and uses more video memory; changing it is a short freeze." },
	vrsValar = { "low", "estimate", "Variable rate shading draws parts of the screen with less detail to gain speed. Needs hardware support; ignored where missing." },
	shadowrt = { "very high", "estimate", "Ray traced shadows: very accurate shadows on graphics cards with ray tracing. Ignored on hardware without it." },
	shadowNumCascades = { "medium", "estimate", "How many layers of shadow detail are drawn from near to far. More keeps distant shadows sharp." },
	assaoBlurPassCount = { "low", "estimate", "How much ambient occlusion is smoothed. More passes remove grain from corner shadows." },
	ResampleAlwaysSharpen = { "low", "estimate", "Adds a sharpening pass even at 100% render scale, for a crisper picture." },
	doodadLodScale = { "medium", "estimate", "How far small props such as fences, crates and plants keep their full detail." },
}
for _, entry in ipairs(Catalog.LIST) do
	local info = INFO[entry.cvar]
	entry.impact, entry.impactSource, entry.desc = info[1], info[2], info[3]
end

Catalog.GROUPS = { "quality", "render", "hidden" }

-- fps % gained per step down, from the probe (RenderScale per 0.05).
Catalog.PRIOR = {}
for _, entry in ipairs(Catalog.LIST) do if entry.smart then Catalog.PRIOR[entry.cvar] = 0.5 end end
for cvar, gain in pairs({ RenderScale = 6, shadowSoft = 11, ResampleQuality = 3, graphicsLightMode = 2.5, graphicsSSAO = 2.5, graphicsComputeEffects = 2 }) do Catalog.PRIOR[cvar] = gain end

-- Restart cvars: a write needs a client or GX restart. Keys are lower case: cvar names are case-insensitive.
Catalog.NEVER = {}
for _, cvar in ipairs({ "gxMaxFrameLatency", "gxapi", "physicsLevel", "gxAdapter", "MSAAQuality", "msaaAlphaTest", "useHighResTextures" }) do Catalog.NEVER[cvar:lower()] = true end

local byLower = {}
for _, entry in ipairs(Catalog.LIST) do byLower[entry.cvar:lower()] = entry end

-- The game's own render scale range, kept inside 0.33..2.0.
do
	local entry = byLower[RENDER_SCALE:lower()]
	local okMin, low = pcall(GetMinRenderScale)
	local okMax, high = pcall(GetMaxRenderScale)
	low, high = okMin and tonumber(ns.plain(low)), okMax and tonumber(ns.plain(high))
	if low and low > entry.min and low < entry.max then entry.min = low end
	if high and high < entry.max and high > entry.min then entry.max = high end
end

-- With secondary lighting the game's particle menu is Low..Ultra on 0..4; without it 0 is Disabled and 1..5 the levels.
do
	local ok, secondary = pcall(function() return C_VideoOptions.IsSecondaryLightingSupported() end)
	local entry = byLower[PARTICLES:lower()]
	if ok and ns.plain(secondary) == true then entry.min, entry.max, entry.names = 0, 4, LOW_ULTRA end
end

-- Only the modes this graphics card offers, as the game's own menu does; FXAA unless the client says no.
do
	local entry = byLower[AA:lower()]
	local ok, fxaa, cmaa, cmaa2 = pcall(AntiAliasingSupported)
	if not ok then fxaa, cmaa, cmaa2 = true, false, false end
	local choices = { 0 }
	if ns.plain(fxaa) ~= false then choices[2], choices[3] = 1, 2 end
	if ns.plain(cmaa) then choices[#choices + 1] = 3 end
	if ns.plain(cmaa2) then choices[#choices + 1] = 4 end
	entry.choices, entry.min, entry.max = choices, choices[1], choices[#choices]
end

function Catalog.Get(cvar)
	if type(cvar) ~= "string" or Catalog.NEVER[cvar:lower()] then return nil end
	return byLower[cvar:lower()]
end

function Catalog.Range(cvar)
	local entry = Catalog.Get(cvar)
	if entry then return entry.min, entry.max end
end

-- Rounds float noise away; whole numbers come back as integers (Lua 5.4 tests print 5, not 5.0).
local function tidy(value)
	local n = tonumber(string.format("%.6f", value))
	if n == math.floor(n) then return math.floor(n) end
	return n
end

local function nearestChoice(choices, value)
	local best
	for _, choice in ipairs(choices) do
		if not best or math.abs(choice - value) < math.abs(best - value) then best = choice end
	end
	return best
end

-- What this machine's client clamped a write to (Apply.Write records it): a cap on one side of the range.
local function capped(cvar, value)
	local db = ns.db
	local limit = db and db.limits and db.limits[cvar]
	if not limit then return value end
	if db.limitSides[cvar] == "min" then return value < limit and limit or value end
	return value > limit and limit or value
end

local function grid(entry, value, min, max)
	local step = entry.step
	local snapped = math.floor(value / step + 0.5) * step
	if snapped < min - EPSILON then snapped = math.ceil(min / step - EPSILON) * step end
	if snapped > max + EPSILON then snapped = math.floor(max / step + EPSILON) * step end
	return snapped
end

-- On the step grid (counted from 0), inside the range and this machine's limit; NaN and non-numbers give nil.
function Catalog.Clamp(cvar, value)
	local entry = Catalog.Get(cvar)
	value = tonumber(value)
	if not (entry and value and value == value) then return nil end
	if entry.kind == "choice" then return capped(entry.cvar, nearestChoice(entry.choices, value)) end

	return tidy(capped(entry.cvar, grid(entry, value, entry.min, entry.max)))
end

-- Saved data keeps to the static range (lo..hi where this machine narrows the range at load); Clamp at use applies
-- this machine's range and limits.
function Catalog.Repair(cvar, value)
	local entry = Catalog.Get(cvar)
	value = tonumber(value)
	if not (entry and value and value == value) then return nil end
	if entry.kind == "choice" and not entry.lo then return nearestChoice(entry.choices, value) end
	return tidy(grid(entry, value, entry.lo or entry.min, entry.hi or entry.max))
end

-- The client snaps values to its own grid (RenderScale 0.75 can read back 0.7533): within half a step, or the same
-- choice, is the same setting. Unknown cvars compare almost exactly.
function Catalog.Same(cvar, a, b)
	a, b = tonumber(a), tonumber(b)
	if not (a and b) then return false end
	local entry = Catalog.Get(cvar)
	if not entry then return math.abs(a - b) < EPSILON * 1000 end
	if entry.kind == "choice" then return nearestChoice(entry.choices, a) == nearestChoice(entry.choices, b) end
	return math.abs(a - b) < entry.step / 2
end

function Catalog.Step(cvar, value, dir)
	local entry, current = Catalog.Get(cvar), Catalog.Clamp(cvar, value)
	if not current then return nil end
	if entry.kind == "choice" then
		local choices = entry.choices
		for i, choice in ipairs(choices) do
			local nextChoice = choice == current and Catalog.Clamp(cvar, choices[i + (dir > 0 and 1 or -1)])
			if nextChoice then return nextChoice ~= current and nextChoice or nil end
		end
		return nil
	end

	local nextValue = current + (dir > 0 and entry.step or -entry.step)
	if nextValue < entry.min - EPSILON or nextValue > entry.max + EPSILON then return nil end
	nextValue = Catalog.Clamp(cvar, nextValue)
	return nextValue ~= current and nextValue or nil
end

function Catalog.Format(cvar, value)
	local entry, number = Catalog.Get(cvar), tonumber(value)
	if not (entry and number) then return tostring(value) end
	if entry.kind == "scale" then return string.format("%d%%", math.floor(number * 100 + 0.5)) end

	local name = entry.names and entry.names[number]
	return name or tostring(tidy(number))
end

-- The game's quality slider passes 0..9 (its label shows value + 1).
local QUALITY_LEVELS = { low = 1, fair = 3, good = 5, high = 7, ultra = 9 }
local QUALITY_TOP = 9
-- Beyond the menu's Ultra: hidden engine values from our own measurements.
local BEYOND = {
	groundEffectDensity = 256, groundEffectDist = 400, groundEffectFade = 300, lodObjectCullSize = 8, lodObjectFadeScale = 200, terrainLodDist = 1000,
	wmoLodDist = 800, horizonStart = 4000, doodadLodScale = 200, shadowTextureSize = 2048, shadowNumCascades = 4, assaoBlurPassCount = 3,
	ResampleAlwaysSharpen = 1, reflectionMode = 3, shadowSoft = 1, sunShafts = 2,
}
local MAX_FPS = { RenderScale = 0.6, shadowSoft = 0 }

-- The game's own value for a quality level (what the Options slider sets); a straight line over the range without it.
local function qualityValue(entry, levelValue)
	local ok, value = pcall(GetGraphicsCVarValueForQualityLevel, entry.cvar, levelValue, false)
	value = ok and tonumber(ns.plain(value))
	if not value then value = entry.min + (entry.max - entry.min) * levelValue / QUALITY_TOP end
	return Catalog.Clamp(entry.cvar, value)
end

local function quality(levelValue)
	local values = {}
	for _, entry in ipairs(Catalog.LIST) do
		if entry.group == "quality" then values[entry.cvar] = qualityValue(entry, levelValue) end
	end
	values[RENDER_SCALE] = Catalog.Clamp(RENDER_SCALE, 1.0)
	return values
end

-- Every quality setting at the top of its menu, render scale native (or the game's max, if lower).
local function menuMax()
	local values = {}
	for _, entry in ipairs(Catalog.LIST) do
		if entry.group == "quality" then values[entry.cvar] = Catalog.Clamp(entry.cvar, entry.max) end
	end
	values[RENDER_SCALE] = Catalog.Clamp(RENDER_SCALE, 1.0)
	return values
end

local function with(values, extra)
	for cvar, value in pairs(extra) do values[cvar] = Catalog.Clamp(cvar, value) end
	return values
end

Catalog.PRESETS = {
	{ key = "low", name = "Low", build = function() return quality(QUALITY_LEVELS.low) end },
	{ key = "fair", name = "Fair", build = function() return quality(QUALITY_LEVELS.fair) end },
	{ key = "good", name = "Good", build = function() return quality(QUALITY_LEVELS.good) end },
	{ key = "high", name = "High", build = function() return quality(QUALITY_LEVELS.high) end },
	{ key = "ultra", name = "Ultra", build = function() return quality(QUALITY_LEVELS.ultra) end },
	{ key = "beyond", name = "Beyond Ultra", build = function() return with(menuMax(), BEYOND) end },
	{ key = "fps", name = "Max FPS", build = function() return with(quality(QUALITY_LEVELS.low), MAX_FPS) end },
}

function Catalog.Preset(key)
	for _, preset in ipairs(Catalog.PRESETS) do
		if preset.key == key then return preset end
	end
end

function Catalog.BuildPreset(key)
	local preset = Catalog.Preset(key)
	return preset and preset.build() or nil
end

-- Smart's per-step gains rated over (at most) the first 5 steps of the range, so fine-step settings like render
-- scale and on/off toggles land on one scale. ponytail: a straight line; measure a full sweep if it misleads.
-- Smart's A/B samples are noisy (movement, scene changes): emas below 0 or above 40% per step are dropped, the rest
-- are weighted by sample count and shrunk toward the prior by SHRINK pseudo-samples, and only 8+ samples count.
local MEASURED_N, SHRINK, NOISE_MAX, SPAN_STEPS = 8, 5, 40, 5
local LEVELS = { { 1, "none" }, { 4, "low" }, { 10, "medium" }, { 20, "high" } }
local MIDPOINT = { none = 0.5, low = 2.5, medium = 7, high = 15, ["very high"] = 25 }

local function span(entry)
	local steps = entry.kind == "choice" and #entry.choices - 1 or math.floor((entry.max - entry.min) / entry.step + 0.5)
	return math.max(1, math.min(steps, SPAN_STEPS))
end

local function rate(entry, percent)
	local total = math.abs(percent) * span(entry)
	for _, row in ipairs(LEVELS) do
		if total < row[1] then return row[2] end
	end
	return "very high"
end

-- Sum of n * ema and of n over usable gains.
local function addGain(entry, gain, sum, n)
	local ema, count = type(gain) == "table" and tonumber(gain.ema), type(gain) == "table" and tonumber(gain.n) or 0
	if not ema or count <= 0 or ema < 0 or (ema > NOISE_MAX and entry.cvar ~= RENDER_SCALE) then return sum, n end
	return sum + count * ema, n + count
end

-- level, fps % per step, source: "measured" (this machine's learning, 8+ usable samples), else the entry's "probe"
-- or "estimate" with the probe % (nil for an estimate).
function Catalog.Impact(cvar)
	local entry = Catalog.Get(cvar)
	if not entry then return nil end

	local probe = entry.impactSource == "probe" and Catalog.PRIOR[entry.cvar] or nil
	local smart = ns.db and ns.db.smart
	local gains = smart and type(smart.gains) == "table" and smart.gains or {}
	local sum, n = addGain(entry, gains[entry.cvar], 0, 0)
	if n < MEASURED_N then return entry.impact, probe, entry.impactSource end

	local prior = probe or MIDPOINT[entry.impact] / span(entry)
	local percent = (sum + SHRINK * prior) / (n + SHRINK)
	return rate(entry, percent), percent, "measured"
end
