-- Forever Smart Graphics "Locations" page. Row pattern adapted from Forever Controller
-- Tweaks' Tweaks tab (MIT, same author). Switch by location; one table of location types, each with its profile and its
-- Smart goal (greyed while Smart mode is off); specific places, each with its profile and a Remove button, and Add
-- this place. A dropdown opens with a click or A; its arrows or D-pad left/right step it, and past its end the focus
-- moves on to the row's next control. X or a right-click removes a place.
local _, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

-- The table's columns, from the row's left: label 150 wide, Profile at 192 (box 170), Smart goal at 418 (box 150).
local LABEL_W, PROFILE_X, PROFILE_W, STYLE_X, STYLE_W, CAPTION_PROFILE_X, CAPTION_STYLE_X = 150, 192, 170, 410, 168, 222, 440

local window, page

local function refresh() window:Refresh() end

local function nameOf(id)
	local profile = id and ns.Profiles.Get(id)
	return profile and profile.name or L.DEFAULT
end

-- A location type's choices: Default (false), then every other profile. A place's: every profile, Default too.
local function choices(withDefault)
	local list = withDefault and {} or { false }
	for _, profile in ipairs(ns.Profiles.List()) do
		if withDefault or profile.id ~= "default" then list[#list + 1] = profile.id end
	end
	return list
end

local function indexOf(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return 1
end

-- One step through options from value; nil past an end.
local function stepIn(options, value, dir)
	local i = indexOf(options, value) + dir
	return options[i], options[i] ~= nil
end

local function assignType(key, id)
	ns.Profiles.Assign(key, id or nil)
	UI.UserEdit()
	refresh()
end

local function assignPlace(key, id)
	local override = ns.db.overrides[key]
	if not override then return end
	ns.Profiles.SetOverride(key, override.name, id)
	UI.UserEdit()
	refresh()
end

local function stepType(key, dir)
	local nextValue, ok = stepIn(choices(false), ns.db.locations[key] or false, dir)
	if not ok then return false end
	assignType(key, nextValue)
end

local function stepPlace(key, dir)
	local override = ns.db.overrides[key]
	if not override then return end
	local nextValue, ok = stepIn(choices(true), override.profile, dir)
	if not ok then return false end
	assignPlace(key, nextValue)
end

local function openType(row, key)
	UI.OpenChoice(window, row.choice, UI.ChoiceEntries(choices(false), nameOf), ns.db.locations[key] or false, function(picked) assignType(key, picked.id) end)
end

local function openPlace(row, key)
	local override = ns.db.overrides[key]
	if not override then return end
	UI.OpenChoice(window, row.choice, UI.ChoiceEntries(choices(true), nameOf), override.profile, function(picked) assignPlace(key, picked.id) end)
end

local function addCurrent()
	local loc = ns.Location.Current()
	if not (loc and loc.overrideKey) or ns.db.overrides[loc.overrideKey] then return end
	-- Its own assignment, not a profile a macro holds.
	ns.Profiles.SetOverride(loc.overrideKey, loc.name or L.UNKNOWN_PLACE, ns.Location.ProfileFor(loc, true) or "default")
	UI.UserEdit()
	refresh()
end

local function calibrating()
	local state = ns.Calibrate and ns.Calibrate.State()
	return state and state.running
end

local function toggleSwitching()
	if calibrating() then return end
	ns.Apply.SetSwitching(not ns.db.options.switching)
	refresh()
end

local function removePlace(key)
	ns.Profiles.RemoveOverride(key)
	UI.UserEdit()
	refresh()
end

-- Smart goal per location type: Same as Smart mode (the Goal on the Smart mode page) or one of the goals; Pace is global. Greyed
-- (still showing its value) while Smart mode is off.
local function smartOn() return ns.Smart and ns.Smart.Enabled() end

local function modeChoices()
	local entries = { { id = false, name = L.MODE_DEFAULT } }
	for _, entry in ipairs(UI.SmartEntries("goal")) do entries[#entries + 1] = entry end
	return entries
end

local function locationMode(key) return (ns.db.smart.goals or {})[key] or false end

local function setLocationMode(key, mode)
	ns.Smart.SetLocationGoal(key, mode or nil)
	refresh()
end

local function modeIndex(entries, key)
	for i, entry in ipairs(entries) do if entry.id == key then return i end end
	return 1
end

local function stepLocationMode(key, dir)
	local entries = modeChoices()
	local nextEntry = entries[modeIndex(entries, locationMode(key)) + dir]
	if not nextEntry then return false end
	setLocationMode(key, nextEntry.id)
end

local function openLocationMode(row, key)
	UI.OpenChoice(window, row.second, modeChoices(), locationMode(key), function(picked) setLocationMode(key, picked.id) end, row.second)
end

local function placeItems()
	local items = {}
	for key, override in pairs(ns.db.overrides) do items[#items + 1] = { key = key, name = override.name or key, profile = override.profile } end
	table.sort(items, function(a, b) return a.name < b.name end)
	return items
end

local function tableRow(content, label)
	local row = UI.SettingRow(content, label)
	row.label:SetWidth(LABEL_W)
	row.here = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
	row.here:SetText(L.YOU_ARE_HERE)
	return row
end

local function markHere(row, isHere)
	row.label:SetFontObject(isHere and "GameFontHighlight" or "GameFontNormal")
	row.here:SetShown(isHere and true or false)
	if not isHere then return end
	row.here:ClearAllPoints()
	row.here:SetPoint("LEFT", row, "LEFT", N.LABEL_X + math.min(row.label:GetStringWidth(), LABEL_W) + 6, 0)
end

local function placeRow(i)
	local row = page.placeRows[i]
	if row then return row end

	row = tableRow(page)
	row.choice = UI.RowChoice(row, function(dir) if row.key then return stepPlace(row.key, dir) end end, function() if row.key then openPlace(row, row.key) end end, PROFILE_X, PROFILE_W)
	row.control = row.choice
	UI.RowButtons(row, { L.REMOVE })
	row.remove = row.buttons[1]
	page.placeRows[i] = row
	return row
end

local function caption(section, text, x)
	local fs = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("BOTTOMLEFT", x, 2)
	fs:SetText(text)
	return fs
end

local function build(content, win)
	window, page = win, content
	page.flow = UI.Flow(content)
	page.toggle = UI.SettingRow(content, L.SWITCHING)
	UI.RowCheckbox(page.toggle, toggleSwitching)
	page.toggle.onClick = toggleSwitching
	UI.RowHint(page.toggle, L.SWITCHING_HINT, page.toggle.control)
	page.typeSection = UI.Section(content, L.LOCATION_TYPES)
	caption(page.typeSection, L.COLUMN_PROFILE, CAPTION_PROFILE_X)
	page.styleCaption = caption(page.typeSection, L.COLUMN_STYLE, CAPTION_STYLE_X)
	page.typeRows = {}
	for i, key in ipairs(ns.Location.KEYS) do
		local row = tableRow(content, ns.Location.LABELS[key])
		row.key = key
		row.choice = UI.RowChoice(row, function(dir) return stepType(key, dir) end, function() openType(row, key) end, PROFILE_X, PROFILE_W)
		row.control = row.choice
		row.onClick = function() openType(row, key) end
		if UI.SmartList("goal") then
			row.second = UI.RowChoice(row, function(dir) return stepLocationMode(key, dir) end, function() openLocationMode(row, key) end, STYLE_X, STYLE_W)
			local button = row.second.button
			button:SetMotionScriptsWhileDisabled(true)
			button:HookScript("OnEnter", function(self) if row.second.off then UI.Tooltip(self, { title = ns.Location.LABELS[key], lines = { L.MODE_OFF_TIP }, side = "above" }) end end)
			button:HookScript("OnLeave", function(self) UI.HideTooltip(self) end)
		end
		page.typeRows[i] = row
	end
	page.placeSection = UI.Section(content, L.PLACES)
	-- Over the place rows, under the line that explains them; only with rows.
	page.placeCaption = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	page.placeCaption:SetText(L.COLUMN_PROFILE)
	page.placesWin = UI.Description(content, "GameFontDisableSmall")
	page.placesWin:SetText(L.PLACES_WIN)
	page.empty = UI.Description(content, "GameFontDisable")
	page.empty:SetText(L.NO_PLACES)
	page.add = UI.ButtonLine(content, { "" })
	page.add.buttons[1].action = addCurrent
	page.placeRows = {}
end

local function choiceNode(row, onStep, tip, extra)
	local node = extra or {}
	node.cursorX, node.onFocus, node.tip, node.tipRegion = N.LABEL_X - 6, UI.RowFocus(row), tip, row.tipAnchor
	node.onDir = function(dir) return onStep(dir) end
	return UI.Node(window, row, row.onClick, node)
end

local function refreshPage(content)
	local loc = ns.Location.Current() or {}
	local switching = ns.db.options.switching
	local flow = content.flow
	local nodes = {}
	flow:Start()
	flow:Add(content.toggle, N.ROW_H)
	content.toggle.control:Set(switching)
	-- Find my best settings needs it on while it runs.
	local busy = calibrating()
	UI.SetRowEnabled(content.toggle, not busy)
	if not busy then nodes[1] = UI.Node(window, content.toggle, toggleSwitching, { cursorX = N.LABEL_X - 6, onFocus = UI.RowFocus(content.toggle), tipRegion = content.toggle.tipAnchor, tip = { title = L.SWITCHING, lines = { L.SWITCHING_TIP }, side = "above" } }) end

	flow:Add(content.typeSection, N.SECTION_H, 0)
	local styleOn = smartOn()
	content.styleCaption:SetText(styleOn and L.COLUMN_STYLE or L.COLUMN_STYLE_OFF)
	content.styleCaption:SetFontObject(styleOn and "GameFontNormalSmall" or "GameFontDisableSmall")
	local typeOptions = choices(false)
	local styles = UI.SmartList("goal") and modeChoices()
	for i, key in ipairs(ns.Location.KEYS) do
		local row, value = content.typeRows[i], ns.db.locations[key] or false
		local index = indexOf(typeOptions, value)
		local label = ns.Location.LABELS[key]
		flow:Add(row, N.ROW_H)
		markHere(row, loc.key == key)
		row.choice:Set(nameOf(value), index == 1, index == #typeOptions)
		UI.SetRowEnabled(row, switching)
		if loc.key == key and switching then row.label:SetFontObject("GameFontHighlight") end
		if row.second then
			local at = modeIndex(styles, locationMode(key))
			row.second:Set(styles[at].name, at == 1, at == #styles)
			row.second:SetEnabledState(switching and styleOn)
		end
		if switching then
			-- Y jumps to the row's Smart goal, so a pad reaches it without stepping the profile.
			local goalNode
			local toGoal = row.second and styleOn and {
				prompts = { { "PAD4", L.COLUMN_STYLE } },
				onKey = function(pressed)
					if pressed ~= "PAD4" then return end
					window:Focus(goalNode)
					return true
				end,
			}
			local lines = { string.format(L.TYPE_TIP, label:lower()), UI.ByMode(L.CHOICE_TIP, L.CHOICE_TIP_MOUSE) }
			nodes[#nodes + 1] = choiceNode(row, function(dir) return stepType(key, dir) end, { title = label, lines = lines, actions = toGoal and { { "PAD4", L.COLUMN_STYLE } } or nil, side = "above" }, toGoal or nil)
			if toGoal then
				local tip = { title = label, lines = { string.format(L.GOAL_TYPE_TIP, label:lower()) }, side = "above" }
				goalNode = UI.Node(window, row.second.button, function() openLocationMode(row, key) end, { cursorX = -6, tip = tip, styleKey = key, onDir = function(dir) return stepLocationMode(key, dir) end })
				nodes[#nodes + 1] = goalNode
			end
		end
	end

	flow:Add(content.placeSection, N.SECTION_H, 0)
	flow:Add(content.placesWin, 14, N.ROW_GAP, N.LABEL_X)
	local items = placeItems()
	local placeOptions = choices(true)
	if #items > 0 then flow:Add(content.placeCaption, 12, 2, CAPTION_PROFILE_X) end
	for i, item in ipairs(items) do
		local row, key = placeRow(i), item.key
		local at = indexOf(placeOptions, item.profile)
		flow:Add(row, N.ROW_H)
		row.key = key
		row.label:SetText(item.name)
		markHere(row, loc.overrideKey == key)
		row.choice:Set(nameOf(item.profile), at == 1, at == #placeOptions)
		UI.SetRowEnabled(row, switching)
		row.remove:SetEnabled(switching)
		row.onClick = function() openPlace(row, key) end
		row.remove.action = function() removePlace(key) end
		if switching then
			nodes[#nodes + 1] = choiceNode(row, function(dir) return stepPlace(key, dir) end, { title = item.name, lines = { string.format(L.PLACE_TIP, item.name), UI.ByMode(L.CHOICE_TIP, L.CHOICE_TIP_MOUSE) }, actions = { { "PAD3", L.REMOVE } }, side = "above" }, {
				prompts = { { "PAD3", L.REMOVE } },
				placeKey = key,
				onKey = function(pressed)
					if pressed ~= "PAD3" then return end
					removePlace(key)
					return true
				end,
			})
			nodes[#nodes + 1] = UI.Node(window, row.remove, row.remove.action, { tip = { title = L.REMOVE, lines = { L.REMOVE_TIP }, side = "right" } })
		end
	end
	if #items == 0 then flow:Add(content.empty, 14, N.ROW_GAP, N.LABEL_X) end
	local added = loc.overrideKey and ns.db.overrides[loc.overrideKey]
	local addButton = content.add.buttons[1]
	addButton:SetText(string.format(L.ADD_THIS_PLACE, loc.name or L.UNKNOWN_PLACE))
	addButton:SetWidth((addButton:GetTextWidth() or 0) + 24)
	addButton:SetMotionScriptsWhileDisabled(true)
	local canAdd = switching and loc.overrideKey ~= nil and not added
	addButton:SetEnabled(canAdd)
	flow:Add(content.add, N.BUTTON_H)
	if canAdd then nodes[#nodes + 1] = UI.Node(window, addButton, addCurrent, { tip = { title = addButton:GetText(), lines = { L.ADD_PLACE_TIP }, side = "right" } }) end
	flow:Finish()
	return nodes
end

-- A suggestion's Change: put the focus on a specific place's row (shown as a selection in the mouse look too).
local function focusPlace(key)
	if not (page and window and window:IsShown()) then return end
	for _, node in ipairs(window.nodes or {}) do
		if node.placeKey == key then
			window.byHover = false
			return window:Focus(node)
		end
	end
end

UI.LocationsTab = { Focus = focusPlace }

UI.AddPage({ key = "locations", order = 2, title = function() return L.TAB_LOCATIONS end, build = build, refresh = refreshPage })
