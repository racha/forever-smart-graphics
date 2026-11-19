-- Profiles: named sets of Catalog values. A value left out inherits from Default, and Default from the original
-- settings captured at the first load. Every change fires FSG_PROFILES_CHANGED(id).
local _, ns = ...
local Profiles = {}
ns.Profiles = Profiles

local DEFAULT = "default"
local NAME_MAX = 32
local CHANGED = "FSG_PROFILES_CHANGED"
local FROM_DEFAULT, FROM_ORIGINAL = "Default", "your original"

local function db() return ns.db end
local function changed(id) ns.Fire(CHANGED, id) end
local function trim(name) return type(name) == "string" and name:match("^%s*(.-)%s*$") or "" end

local function taken(name, except)
	local lower = name:lower()
	for id, profile in pairs(db().profiles) do
		if id ~= except and profile.name:lower() == lower then return true end
	end
	return false
end

-- "City", "City 2", "City 3"…, always within NAME_MAX.
local function uniqueName(name, except)
	local base = trim(name):sub(1, NAME_MAX)
	if base == "" then base = "Profile" end
	if not taken(base, except) then return base end
	for n = 2, math.huge do
		local suffix = " " .. n
		local candidate = trim(base:sub(1, NAME_MAX - #suffix)) .. suffix
		if not taken(candidate, except) then return candidate end
	end
end

local function cleanValues(values)
	local out = {}
	for cvar, value in pairs(type(values) == "table" and values or {}) do
		local entry, clamped = ns.Catalog.Get(cvar), ns.Catalog.Clamp(cvar, value)
		if entry and clamped then out[entry.cvar] = clamped end
	end
	return out
end

function Profiles.List()
	local out, profiles = {}, db().profiles
	for _, id in ipairs(db().profileOrder) do
		local profile = profiles[id]
		if profile then out[#out + 1] = { id = id, name = profile.name } end
	end
	return out
end

function Profiles.Get(id) return db().profiles[id] end

function Profiles.FindByName(name)
	local lower = trim(name):lower()
	for id, profile in pairs(db().profiles) do
		if profile.name:lower() == lower then return id end
	end
end

function Profiles.Create(name, values)
	local data = db()
	local id = "p" .. data.nextId
	data.nextId = data.nextId + 1
	data.profiles[id] = { id = id, name = uniqueName(name), values = cleanValues(values) }
	data.profileOrder[#data.profileOrder + 1] = id
	changed(id)
	return id
end

function Profiles.FromPreset(key)
	local preset = ns.Catalog.Preset(key)
	if not preset then return nil end
	return Profiles.Create(preset.name, preset.build())
end

function Profiles.FromCurrent(name)
	local values = {}
	for _, entry in ipairs(ns.Catalog.LIST) do values[entry.cvar] = ns.Get(entry.cvar) end
	return Profiles.Create(name or "My settings", values)
end

function Profiles.Copy(id)
	local profile = Profiles.Get(id)
	if not profile then return nil end
	return Profiles.Create(profile.name .. " copy", profile.values)
end

-- The final name, or nil (unknown id, Default, or an empty name).
function Profiles.Rename(id, name)
	local profile = Profiles.Get(id)
	if not profile or id == DEFAULT or trim(name) == "" then return nil end

	profile.name = uniqueName(name, id)
	changed(id)
	return profile.name
end

function Profiles.Delete(id)
	local data = db()
	if id == DEFAULT or not data.profiles[id] then return false end

	data.profiles[id] = nil
	for i = #data.profileOrder, 1, -1 do
		if data.profileOrder[i] == id then table.remove(data.profileOrder, i) end
	end
	for key, profileId in pairs(data.locations) do
		if profileId == id then data.locations[key] = nil end
	end
	for key, entry in pairs(data.overrides) do
		if entry.profile == id then data.overrides[key] = nil end
	end
	if data.held == id then data.held = nil end
	changed(id)
	return true
end

-- nil clears the value (inherit). False when the profile or cvar is unknown.
function Profiles.SetValue(id, cvar, value)
	local profile, entry = Profiles.Get(id), ns.Catalog.Get(cvar)
	if not (profile and entry) then return false end

	local clamped = value ~= nil and ns.Catalog.Clamp(cvar, value) or nil
	if value ~= nil and not clamped then return false end
	profile.values[entry.cvar] = clamped
	changed(id)
	return true
end

function Profiles.Inherited(id, cvar)
	local entry = ns.Catalog.Get(cvar)
	if not entry then return nil end

	local default = db().profiles[DEFAULT]
	local value = id ~= DEFAULT and default.values[entry.cvar]
	if value then return value, FROM_DEFAULT end
	return ns.Catalog.Clamp(entry.cvar, db().original[entry.cvar]), FROM_ORIGINAL
end

-- Every Catalog cvar with a known value: original, then Default, then the profile (unknown id = Default).
function Profiles.Effective(id)
	local data = db()
	local out = {}
	for _, entry in ipairs(ns.Catalog.LIST) do
		local cvar = entry.cvar
		out[cvar] = ns.Catalog.Clamp(cvar, data.original[cvar])
	end
	for _, profileId in ipairs({ DEFAULT, id }) do
		local profile = data.profiles[profileId]
		for cvar, value in pairs(profile and profile.values or {}) do out[cvar] = ns.Catalog.Clamp(cvar, value) end
	end
	return out
end

-- True when Default or the profile sets cvar itself (not inherited from the original).
function Profiles.Sets(id, cvar)
	local data = db()
	local profile = data.profiles[id]
	return data.profiles[DEFAULT].values[cvar] ~= nil or (profile and profile.values[cvar] ~= nil) or false
end

local function knownKey(key)
	for _, k in ipairs(ns.Location.KEYS) do
		if k == key then return true end
	end
	return false
end

-- Default is stored as nil, which means Default.
function Profiles.Assign(locKey, id)
	if not knownKey(locKey) or (id ~= nil and not Profiles.Get(id)) then return false end

	db().locations[locKey] = id ~= DEFAULT and id or nil
	changed(id)
	return true
end

-- Every location type and every specific place.
function Profiles.AssignAll(id)
	if not Profiles.Get(id) then return false end

	local data = db()
	for _, key in ipairs(ns.Location.KEYS) do data.locations[key] = id ~= DEFAULT and id or nil end
	for _, entry in pairs(data.overrides) do entry.profile = id end
	changed(id)
	return true
end

function Profiles.SetOverride(key, name, id)
	local valid = type(key) == "string" and (key:find("^map:%d+$") or key:find("^instance:%d+$"))
	if not valid or not Profiles.Get(id) then return false end

	db().overrides[key] = { profile = id, name = trim(name) ~= "" and trim(name) or key }
	changed(id)
	return true
end

function Profiles.RemoveOverride(key)
	local entry = db().overrides[key]
	if not entry then return false end

	db().overrides[key] = nil
	changed(entry.profile)
	return true
end

-- A hold: one profile in every place until released (macros), on top of the location assignments, which stay as
-- they are. nil releases. False for an unknown id or with switching by location off.
function Profiles.Hold(id)
	local data = db()
	if not data.options.switching or (id ~= nil and not Profiles.Get(id)) then return false end

	local previous = Profiles.Held()
	if previous == id then return true end
	data.held = id
	changed(id or previous)
	return true
end

function Profiles.Held()
	local id = db().held
	return id and Profiles.Get(id) and id or nil
end
