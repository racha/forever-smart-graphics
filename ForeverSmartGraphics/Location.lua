-- Where the player is: a location type (city, outdoor, dungeon…) and a specific place key for overrides.
-- Fires FSG_LOCATION(loc, prev, loading) 0.3 s after the last zone event, only when the type or place changed
-- (always once after login). Inns count as city: IsResting() is the only city test the game gives, so a step between
-- city and open world without a loading screen counts only once it held for 3 s.
-- scenario/neighborhood/interior don't exist on Forever; they fall back to dungeon/city in case the client reports one.
local _, ns = ...
local Location = {}
ns.Location = Location

Location.KEYS = { "city", "outdoor", "dungeon", "raid", "battleground", "arena" }
Location.LABELS = { city = "City", outdoor = "Open world", dungeon = "Dungeon", raid = "Raid", battleground = "Battleground", arena = "Arena" }

local DEBOUNCE, SETTLE = 0.3, 3
local RESTING_KEYS = { city = true, outdoor = true }
local BY_TYPE = { party = "dungeon", raid = "raid", pvp = "battleground", arena = "arena", scenario = "dungeon", neighborhood = "city", interior = "city" }

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g, h end
end

local function text(fn)
	local value = ns.plain(call(fn))
	return type(value) == "string" and value ~= "" and value or nil
end

function Location.Read()
	local name, instanceType, difficultyID, _, _, _, _, instanceID = call(GetInstanceInfo)
	name, instanceType = ns.plain(name), ns.plain(instanceType)
	difficultyID, instanceID = tonumber(ns.plain(difficultyID)), tonumber(ns.plain(instanceID))
	local mapID = tonumber(ns.plain(call(C_Map and C_Map.GetBestMapForUnit, "player")))
	local inside = type(instanceType) == "string" and instanceType ~= "none" and instanceType ~= ""

	local key = inside and BY_TYPE[instanceType]
	if not key then key = ns.plain(call(IsResting)) and "city" or "outdoor" end

	local overrideKey
	if inside and instanceID then overrideKey = "instance:" .. instanceID else overrideKey = "map:" .. (mapID or 0) end
	local place = inside and type(name) == "string" and name ~= "" and name or text(GetRealZoneText) or text(GetSubZoneText) or Location.LABELS[key]
	-- One level up, so a place added on a zone also covers the smaller maps inside it.
	local info = not inside and mapID and call(C_Map and C_Map.GetMapInfo, mapID)
	local parent = type(info) == "table" and tonumber(ns.plain(info.parentMapID))
	local parentKey = parent and parent > 0 and "map:" .. parent or nil
	return { key = key, overrideKey = overrideKey, parentKey = parentKey, name = place, mapID = mapID, instanceID = instanceID, instanceType = instanceType or "none", difficultyID = difficultyID }
end

local current, loadingSeen, dueAt, settleAt

function Location.Current()
	current = current or Location.Read()
	return current
end

-- The profile id for loc and where it came from: "place" (an override), "type" (the location type) or "default".
-- assigned: the place's own assignment, ignoring a held profile (a new place starts from it).
function Location.ProfileFor(loc, assigned)
	loc = loc or Location.Current()
	local held = not assigned and ns.Profiles and ns.Profiles.Held()
	if held then return held, "held" end

	local db, profiles = ns.db, ns.db.profiles
	local override = db.overrides[loc.overrideKey]
	if not (override and profiles[override.profile]) and loc.parentKey then override = db.overrides[loc.parentKey] end
	if override and profiles[override.profile] then return override.profile, "place" end

	local id = db.locations[loc.key]
	if id and profiles[id] then return id, "type" end
	return "default", "default"
end

local fired = false
local flush

local function check()
	local now = Location.Read()
	local prev, loading = current, loadingSeen
	local resting = fired and prev and not loading and prev.key ~= now.key and RESTING_KEYS[prev.key] and RESTING_KEYS[now.key]
	if not resting then settleAt = nil end
	if resting and not settleAt then
		settleAt, dueAt = GetTime() + SETTLE, GetTime() + SETTLE
		return C_Timer.After(SETTLE, flush)
	end
	if resting and GetTime() < settleAt - 0.01 then return end

	settleAt, loadingSeen = nil, false
	current = now
	if fired and prev and prev.key == now.key and prev.overrideKey == now.overrideKey then return end

	fired = true
	ns.debug("location %s %s (%s)%s", now.key, now.overrideKey, tostring(now.name), loading and " loading" or "")
	ns.Fire("FSG_LOCATION", now, prev, loading)
end

-- One timer per burst of events: a later event moves the deadline and the timer re-arms itself until it passes.
function flush()
	local wait = dueAt and dueAt - GetTime()
	if wait and wait > 0.01 then return C_Timer.After(wait, flush) end

	dueAt = nil
	check()
end

local function schedule()
	local idle = not dueAt
	dueAt = GetTime() + DEBOUNCE
	if idle then C_Timer.After(DEBOUNCE, flush) end
end

ns.On("PLAYER_ENTERING_WORLD", function()
	loadingSeen = true
	schedule()
end)
for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_UPDATE_RESTING" }) do ns.On(event, schedule) end
