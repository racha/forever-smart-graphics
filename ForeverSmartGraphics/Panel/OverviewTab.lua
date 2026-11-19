-- Forever Smart Graphics "Overview" page, the landing view. Row pattern adapted from
-- Forever Controller Tweaks' Tweaks tab (MIT, same author). One sentence says where you are and why this profile is
-- in use; at most one notice (Find my best settings running, switching off, a heavy change waiting, Smart adjust
-- running, this place lagged); then the controls for the common goals: the profile here and its quality preset,
-- Smart mode with its target, goal and pace, Find my best settings, and a summary of the location types.
local _, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

local LAG_SHARE = 0.5

local window, page

local function refresh() window:Refresh() end

local function gold(text) return "|cffffd100" .. tostring(text) .. "|r" end

local function here()
	local loc = ns.Location.Current() or {}
	local own = loc.overrideKey and ns.db.overrides[loc.overrideKey]
	return loc, own
end

local function nameOf(id)
	local profile = id and ns.Profiles.Get(id)
	return profile and profile.name or L.DEFAULT
end

local function calibrating()
	local state = ns.Calibrate and ns.Calibrate.State()
	return state and state.running and state
end

-- The profile this place uses (its own row's, else its type's, else Default), and every profile to pick from.
local function hereProfile()
	local loc, own = here()
	if own then return own.profile or "default" end
	return ns.db.locations[loc.key] or "default"
end

local function profileIds()
	local ids = {}
	for _, profile in ipairs(ns.Profiles.List()) do ids[#ids + 1] = profile.id end
	return ids
end

local function setHereProfile(id)
	local loc, own = here()
	if own then
		ns.Profiles.SetOverride(loc.overrideKey, own.name or loc.name, id)
	else
		ns.Profiles.Assign(loc.key, id ~= "default" and id or nil)
	end
	UI.UserEdit()
	refresh()
end

local function indexOf(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return 1
end

local function stepHereProfile(dir)
	local ids = profileIds()
	local nextId = ids[indexOf(ids, hereProfile()) + dir]
	if not nextId then return false end
	setHereProfile(nextId)
end

local function openHereProfile()
	UI.OpenChoice(window, page.profile.choice, UI.ChoiceEntries(profileIds(), nameOf), hereProfile(), function(picked) setHereProfile(picked.id) end)
end

local function editHere() UI.OpenPanel("profile", hereProfile()) end

local function openPreset()
	local id = hereProfile()
	UI.OpenChoice(window, page.preset.choice, UI.PresetEntries(), UI.PresetOf(id), function(picked) UI.ApplyPreset(window, id, picked.id) end)
end

local function toggleSmart()
	if calibrating() then return end
	ns.Smart.SetEnabled(not ns.Smart.Enabled())
	refresh()
end

local TARGET_MIN, TARGET_MAX, TARGET_STEP = 20, 240, 5

local function setTarget(value)
	ns.Smart.SetTarget(math.max(TARGET_MIN, math.min(TARGET_MAX, value)))
	refresh()
end

local function nudgeTarget(dir)
	local value = ns.db.smart.target + dir * TARGET_STEP
	if value < TARGET_MIN or value > TARGET_MAX then return false end
	setTarget(value)
end

local function startCalibration()
	UI.Confirm(window, L.CALIBRATE_CONFIRM, L.CALIBRATE_CONFIRM_SUB, L.START, function()
		ns.Calibrate.Start(ns.db.smart.target)
		UI.CloseAll()
		if UI.Calibrate then UI.Calibrate.Update(ns.Calibrate.State()) end
	end)
end

-- The notice: the first that applies, or nil. Returns text, buttons and which rows it greys.
local function pendingNames(values)
	local names = {}
	for cvar in pairs(values or {}) do
		local entry = ns.Catalog.Get(cvar)
		names[#names + 1] = entry and entry.label or cvar
	end
	table.sort(names)
	return table.concat(names, ", ")
end

-- This place lagged: a pending suggestion for it, else its worst area entry (area keys start with the place's
-- override key) under the target at least half the time. Smart mode off only.
local function lagHere()
	local smart = ns.Smart
	if not smart or smart.Enabled() then return end
	local loc = here()
	local key = loc.overrideKey
	if not key then return end
	local s = smart.Suggestion and smart.Suggestion()
	if s and (s.overrideKey == key or s.key == key) then return s.avg, s.goal, s end
	for _, area in ipairs(smart.Areas and smart.Areas() or {}) do
		local k = tostring(area.key)
		if (k == key or k:sub(1, #key + 1) == key .. "/") and (area.lagShare or 0) >= LAG_SHARE then return area.fps, UI.Goal(), { key = area.key, overrideKey = key, name = loc.name } end
	end
end

local function calibrationText(state)
	local lines = { string.format(L.CAL_TITLE, state.target or ns.db.smart.target) }
	if state.hint then lines[#lines + 1] = state.hint end
	for _, scene in ipairs(state.scenes or {}) do
		local status = scene.done and "+" or (state.current and state.current.locKey == scene.locKey) and "..." or "-"
		lines[#lines + 1] = status .. " " .. (scene.label or scene.locKey or "")
	end
	local change = UI.ChangeText((state.changes or {})[1])
	if change then lines[#lines + 1] = string.format(L.CAL_LAST, change) end
	return table.concat(lines, "\n")
end

local function notice()
	local state = calibrating()
	if state then
		return calibrationText(state), {
			{ L.FINISH, function() UI.FinishCalibration() end, state.ready == true },
			{ L.STOP, function()
				ns.Calibrate.Stop()
				refresh()
			end },
		}, "calibrating"
	end
	if not ns.db.options.switching then
		return L.WHY_OFF, { { L.TURN_ON, function()
			ns.Apply.SetSwitching(true)
			refresh()
		end } }, "off"
	end
	local held = ns.Profiles.Held and ns.Profiles.Held()
	if held then
		local profile = ns.Profiles.Get(held)
		return string.format(L.WHY_HELD, profile and profile.name or held), { { L.HOLD_RELEASE, function()
			ns.Profiles.Hold(nil)
			refresh()
		end } }
	end
	local pending = ns.Apply.Pending and ns.Apply.Pending()
	if pending then
		local text = string.format(pending.waitingCombat and L.BANNER_PENDING_COMBAT or L.BANNER_PENDING, pendingNames(pending.values))
		return text, { { L.APPLY_NOW, function()
			ns.Apply.ApplyPending("user", { user = true })
			refresh()
		end } }
	end
	local adjust = ns.Smart and ns.Smart.AdjustState and ns.Smart.AdjustState()
	if adjust and adjust.running then
		local text = string.format(L.BANNER_ADJUST, adjust.name or adjust.key or "")
		local change = UI.ChangeText((adjust.changes or {})[1])
		if change then text = text .. "\n" .. string.format(L.CAL_LAST, change) end
		return text, { { L.STOP, function()
			ns.Smart.CancelAdjust()
			refresh()
		end } }
	end
	local avg, goal, s = lagHere()
	if avg then
		return string.format(L.BANNER_LAG, math.floor(avg + 0.5), math.floor((goal or UI.Goal()) + 0.5)), {
			{ L.SMART_ADJUST, function()
				local ok, reason = ns.Smart.AdjustPlace(s.key)
				if ok == false then UI.Flash(string.format(L.ADJUST_REFUSED, tostring(reason or ""))) end
				refresh()
			end },
			{ L.CHANGE_PROFILE, function()
				local loc = here()
				if not ns.db.overrides[loc.overrideKey] then ns.Profiles.SetOverride(loc.overrideKey, loc.name or L.UNKNOWN_PLACE, hereProfile()) end
				UI.OpenPanel("locations")
				UI.LocationsTab.Focus(loc.overrideKey)
			end },
		}
	end
end

local function build(content, win)
	window, page = win, content
	page.flow = UI.Flow(content)
	page.why = UI.Description(content, "GameFontHighlight")
	page.why:SetWidth(N.ROW_W - N.TITLE_X)
	page.banner = UI.Banner(content)
	page.lookSection = UI.Section(content, L.SECTION_LOOK)
	page.profile = UI.SettingRow(content, "")
	UI.RowChoice(page.profile, stepHereProfile, openHereProfile)
	page.profile.onClick = openHereProfile
	UI.RowButtons(page.profile, { L.EDIT })
	page.profile.buttons[1].action = editHere
	page.preset = UI.SettingRow(content, L.QUALITY_PRESET)
	UI.RowChoice(page.preset, function(dir) return UI.StepPreset(window, hereProfile(), dir) end, openPreset)
	page.preset.onClick = openPreset
	page.handleSection = UI.Section(content, L.SECTION_HANDLE)
	if ns.Smart then
		page.smart = UI.SettingRow(content, L.SMART)
		UI.RowCheckbox(page.smart, toggleSmart)
		page.smart.onClick = toggleSmart
		UI.RowHint(page.smart, L.SMART_HINT, page.smart.control)
		page.target = UI.SettingRow(content, L.TARGET)
		UI.RowSlider(page.target, TARGET_MIN, TARGET_MAX, TARGET_STEP, nudgeTarget, setTarget)
		for _, kind in ipairs({ "goal", "pace" }) do
			if UI.SmartList(kind) then page[kind] = UI.SmartPicker(window, content, kind, refresh) end
		end
	end
	if ns.Calibrate then
		page.calibrate = UI.SettingRow(content, L.CALIBRATE)
		page.calibrate.button = UI.SmallButton(page.calibrate, L.START)
		page.calibrate.button:SetPoint("LEFT", page.calibrate, "CENTER", N.SLIDER_X, 0)
		page.calibrate.button.action = startCalibration
		page.calibrate.onClick = startCalibration
		UI.RowHint(page.calibrate, L.START_HINT, page.calibrate.button)
	end
	page.locationSection = UI.Section(content, L.SECTION_BY_LOCATION)
	page.summary = UI.Description(content, "GameFontHighlight")
	page.setUp = UI.ButtonLine(content, { L.SET_UP_LOCATIONS })
	page.setUp.buttons[1].action = function() UI.OpenPanel("locations") end
end

local function whyText()
	local loc = here()
	local why = UI.WhyLine(true)
	if not ns.db.options.switching then return why end
	local tail = (ns.Smart and ns.Smart.Enabled()) and string.format(L.WHY_SMART, gold(UI.Goal())) or L.WHY_EXACT
	return string.format(L.WHY_HERE, gold(loc.name or L.UNKNOWN_PLACE)) .. " " .. why:gsub("%.$", "") .. ", " .. tail
end

local function summaryText()
	local parts = {}
	for _, key in ipairs(ns.Location.KEYS) do parts[#parts + 1] = ns.Location.LABELS[key] .. " " .. gold(nameOf(ns.db.locations[key] or "default")) end
	local count = 0
	for _ in pairs(ns.db.overrides) do count = count + 1 end
	if count > 0 then parts[#parts + 1] = count == 1 and L.SUMMARY_PLACE or string.format(L.SUMMARY_PLACES, count) end
	return parts
end

-- The parts on as few lines as fit, broken only between parts: no separator ends a line.
local function wrapParts(fs, parts)
	local lines, line = {}, nil
	for _, part in ipairs(parts) do
		local candidate = line and line .. " · " .. part or part
		fs:SetText(candidate)
		if line and UI.TextWidth(fs) > fs:GetWidth() then
			lines[#lines + 1] = line
			line = part
		else
			line = candidate
		end
	end
	lines[#lines + 1] = line
	return table.concat(lines, "\n")
end

local function rowNode(row, select, tip, extra)
	local node = extra or {}
	node.cursorX, node.onFocus, node.tipRegion, node.tip = N.LABEL_X - 6, UI.RowFocus(row), row.tipAnchor, tip
	return UI.Node(window, row, select, node)
end

local function buttonNode(button, tip) return UI.Node(window, button, button.action, { tip = tip }) end

local function refreshPage(content)
	local flow, nodes = content.flow, {}
	local loc, own = here()
	local id = hereProfile()
	flow:Start()
	content.why:SetText(whyText())
	flow:Add(content.why, content.why:GetStringHeight(), N.ROW_GAP, N.TITLE_X)

	local text, buttons, mode = notice()
	if text then
		local height = content.banner:Set(text, buttons)
		flow:Add(content.banner, height)
		for i, spec in ipairs(buttons) do
			if spec[3] ~= false then nodes[#nodes + 1] = buttonNode(content.banner.buttons[i], { title = spec[1], side = "right" }) end
		end
	end
	local busy, off = mode == "calibrating", mode == "off"

	flow:Add(content.lookSection, N.SECTION_H, 0)
	local profileRow = content.profile
	local typeLabel = ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE
	local forName = own and (own.name or loc.name) or typeLabel
	profileRow.label:SetText(string.format(L.PROFILE_FOR, forName))
	local ids = profileIds()
	local at = indexOf(ids, id)
	profileRow.choice:Set(nameOf(id), at == 1, at == #ids)
	UI.SetRowEnabled(profileRow, not (busy or off))
	profileRow.buttons[1]:SetEnabled(not (busy or off))
	flow:Add(profileRow, N.ROW_H)
	if not (busy or off) then
		local tip = own and string.format(L.PROFILE_FOR_PLACE_TIP, forName) or string.format(L.PROFILE_FOR_TYPE_TIP, typeLabel:lower())
		nodes[#nodes + 1] = rowNode(profileRow, openHereProfile, { title = profileRow.label:GetText(), lines = { tip, UI.ByMode(L.CHOICE_TIP, L.CHOICE_TIP_MOUSE) }, side = "above" }, { noSide = false, onDir = stepHereProfile })
		nodes[#nodes + 1] = buttonNode(profileRow.buttons[1], { title = L.EDIT, lines = { string.format(L.EDIT_TIP, nameOf(id)) }, side = "right" })
	end

	local presetRow = content.preset
	local first, last = UI.PresetEnds(id)
	presetRow.choice:Set(UI.PresetName(UI.PresetOf(id)), first, last)
	UI.SetRowEnabled(presetRow, not (busy or off))
	flow:Add(presetRow, N.ROW_H)
	if not (busy or off) then
		local lines = { string.format(L.PRESET_TIP, nameOf(id)), L.PRESET_TIP_STEP, L.PRESET_TIP_CUSTOM }
		if ns.Smart and ns.Smart.Enabled() then lines[#lines + 1] = L.PRESET_TIP_SMART end
		nodes[#nodes + 1] = rowNode(presetRow, openPreset, { title = L.QUALITY_PRESET, lines = lines, side = "above" }, { noSide = true, onDir = function(dir) return UI.StepPreset(window, id, dir) end })
	end

	flow:Add(content.handleSection, N.SECTION_H, 0)
	if content.smart then
		local smartOn = ns.Smart.Enabled()
		content.smart.control:Set(smartOn)
		content.smart.hint:SetText(busy and L.SMART_PAUSED or L.SMART_HINT)
		UI.SetRowEnabled(content.smart, not (busy or off))
		flow:Add(content.smart, N.ROW_H)
		if not (busy or off) then nodes[#nodes + 1] = rowNode(content.smart, toggleSmart, { title = L.SMART, lines = { L.SMART_TIP_FULL }, side = "above" }) end

		local target = ns.db.smart.target
		content.target.slider:Set(target, tostring(target))
		UI.SetRowEnabled(content.target, not off)
		flow:Add(content.target, N.ROW_H)
		if not off then nodes[#nodes + 1] = rowNode(content.target, nil, { title = L.TARGET, lines = { L.TARGET_TIP, UI.ByMode(L.STEPPER_TIP, L.SLIDER_TIP_MOUSE) }, side = "above" }, { noSide = true, onDir = nudgeTarget }) end

		for _, kind in ipairs({ "goal", "pace" }) do
			if content[kind] then content[kind].Draw(flow, nodes, smartOn and not (busy or off)) end
		end
	end
	if content.calibrate then
		UI.SetRowEnabled(content.calibrate, not (busy or off))
		flow:Add(content.calibrate, N.ROW_H)
		if not (busy or off) then nodes[#nodes + 1] = buttonNode(content.calibrate.button, { title = L.CALIBRATE, lines = { L.CALIBRATE_LINE, L.CALIBRATE_TIP_CLOSES }, side = "right" }) end
	end

	flow:Add(content.locationSection, N.SECTION_H, 0)
	content.summary:SetText(wrapParts(content.summary, summaryText()))
	flow:Add(content.summary, content.summary:GetStringHeight(), N.ROW_GAP, N.LABEL_X)
	flow:Add(content.setUp, N.BUTTON_H)
	nodes[#nodes + 1] = buttonNode(content.setUp.buttons[1], { title = L.SET_UP_LOCATIONS, lines = { L.SET_UP_LOCATIONS_TIP }, side = "right" })
	flow:Finish()
	return nodes
end

UI.AddPage({ key = "overview", order = 0, title = function() return L.TAB_OVERVIEW end, build = build, refresh = refreshPage })
