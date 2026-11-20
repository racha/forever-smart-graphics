-- What's new: version order, what the player has seen, and the notes since. Panel/WhatsNew.lua shows them.
--   ns.News.Compare(a, b)  -1 | 0 | 1, nil when either is a dev build.
--   ns.News.Running()      the toc Version, nil on a dev build.
--   ns.News.Pending()      { entries, older, from } after an update, else nil.
--   ns.News.Current()      { entries = { the running version's entry } }, { entries = { newest }, dev = true } on a dev build.
--   ns.News.Close(never)   the player closed the window: seen = running, never stored when true.
--   ns.News.Website()      the toc X-Website, or nil.
-- db.news = { seen = "<version>", never = true } is set up in Core; a dev build never writes it.
local addonName, ns = ...
local News = {}
ns.News = News

local MAX = 5

-- Anything that isn't x.y.z with optional dot-separated alphanumeric pre-release identifiers is a dev build:
-- the packager's unreplaced token, a git-describe tail (its hyphens fail the identifier check), empty or nil.
local function parse(version)
	if type(version) ~= "string" then return nil end
	local major, minor, patch, rest = (version:gsub("^v", "", 1)):match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	if not major then return nil end
	local pre = {}
	if rest ~= "" then
		local ids = rest:match("^%-(.+)$")
		if not ids then return nil end
		for id in (ids .. "."):gmatch("([^.]*)%.") do
			if not id:find("^%w+$") then return nil end
			pre[#pre + 1] = id:find("^%d+$") and tonumber(id) or id
		end
	end
	return { tonumber(major), tonumber(minor), tonumber(patch), pre = pre }
end

local function order(a, b)
	if a == b then return 0 end
	return a < b and -1 or 1
end

function News.Compare(a, b)
	local x, y = parse(a), parse(b)
	if not x or not y then return nil end
	for i = 1, 3 do if x[i] ~= y[i] then return order(x[i], y[i]) end end
	local p, q = x.pre, y.pre
	-- A release is above every pre-release of the same core.
	if #p == 0 or #q == 0 then return order(#q, #p) end
	for i = 1, math.max(#p, #q) do
		local s, t = p[i], q[i]
		if s == nil or t == nil then return s == nil and -1 or 1 end
		if type(s) ~= type(t) then return type(s) == "number" and -1 or 1 end
		if s ~= t then return order(s, t) end
	end
	return 0
end

local function metadata(field)
	local get = C_AddOns and C_AddOns.GetAddOnMetadata
	local ok, value = pcall(get, addonName, field)
	value = ok and ns.plain(value)
	return type(value) == "string" and value ~= "" and value or nil
end

function News.Running()
	local version = metadata("Version")
	-- The packager writes the tag ("v1.0.0") into the toc; players see and we store the plain number.
	return parse(version) and (version:gsub("^v", "", 1)) or nil
end

function News.Website() return metadata("X-Website") end

local function state() return ns.db and ns.db.news end

function News.Pending()
	local running, news = News.Running(), state()
	if not running or not news or news.never or not ns.NEWS then return nil end
	local seen = news.seen
	if News.Compare(running, seen) ~= 1 then return nil end

	local entries, older = {}, false
	for _, entry in ipairs(ns.NEWS) do
		local version = entry.version
		if News.Compare(version, seen) == 1 and News.Compare(version, running) ~= 1 then
			if #entries < MAX then entries[#entries + 1] = entry else older = true end
		end
	end
	-- Nothing for players since seen: catch up quietly, so the next real notes start from here.
	if #entries == 0 then
		news.seen = running
		return nil
	end
	return { entries = entries, older = older, from = seen }
end

function News.Current()
	if not ns.NEWS then return nil end
	local running = News.Running()
	if not running then return { entries = { ns.NEWS[1] }, dev = true } end
	for _, entry in ipairs(ns.NEWS) do
		if News.Compare(entry.version, running) == 0 then return { entries = { entry } } end
	end
	return { entries = {} }
end

function News.Close(never)
	local running, news = News.Running(), state()
	if not running or not news then return end
	news.seen = running
	if never == true then news.never = true end
end
