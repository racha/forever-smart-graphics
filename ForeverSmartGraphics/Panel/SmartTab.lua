-- Forever Smart Graphics "Smart mode" page. Row pattern adapted from Forever Controller
-- Tweaks' Tweaks tab (MIT, same author). What Smart mode does; its switch, target, goal and pace (each with its line
-- under it) and render scale floor; what it is doing right now; what it learned per location (Save as profile, Reset,
-- Reset all) and the places that lagged, worst first (Forget), both folded. A, X and a right-click are shortcuts for a
-- row's buttons. Find my best settings lives on Overview. Without Smart.lua loaded the page says so.
local _, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

local TARGET_MIN, TARGET_MAX, TARGET_STEP = 20, 240, 5
local FLOOR_MIN, FLOOR_MAX, FLOOR_STEP = 33, 100, 5
local LINE_H, LAG_SHOWN, FIGHT_DROP, FINISH_AFTER, DETAIL_W = 18, 10, 0.1, 30, 230
local LEARNED_X, LAG_X, HISTORY = 192, 222, 3

local window, page
local Smart
local recent, lastSeen = {}, nil

local function refresh() window:Refresh() end

local function toggle()
	Smart.SetEnabled(not Smart.Enabled())
	refresh()
end

local function target() return ns.db.smart.target end
local function floorPercent() return math.floor(ns.db.smart.scaleFloor * 100 + 0.5) end

local function setTarget(value)
	Smart.SetTarget(math.max(TARGET_MIN, math.min(TARGET_MAX, value)))
	refresh()
end

local function nudgeTarget(dir)
	local value = target() + dir * TARGET_STEP
	if value < TARGET_MIN or value > TARGET_MAX then return false end
	setTarget(value)
end

local function setFloor(percent)
	Smart.SetFloor(math.max(FLOOR_MIN, math.min(FLOOR_MAX, percent)) / 100)
	refresh()
end

-- Steps land on multiples of 5; the 33% minimum is its own stop.
local function nudgeFloor(dir)
	local percent = floorPercent()
	local value = dir > 0 and (math.floor(percent / FLOOR_STEP) + 1) * FLOOR_STEP or (math.ceil(percent / FLOOR_STEP) - 1) * FLOOR_STEP
	value = math.max(FLOOR_MIN, math.min(FLOOR_MAX, value))
	if value == percent then return false end
	setFloor(value)
end

-- Calibration: Start closes the window (the player has to move around); Finish and Stop are also on the overlay.
local function calibrating()
	local state = ns.Calibrate and ns.Calibrate.State()
	return state and state.running and state
end

local function canFinish(state)
	if state.ready then return true end
	for _, scene in ipairs(state.scenes or {}) do if (scene.seconds or 0) >= FINISH_AFTER then return true end end
end

UI.CanFinishCalibration = canFinish

UI.CanFinishCalibration = canFinish

local function sliderRow(content, label, min, max, step, onStep, onSet)
	local row = UI.SettingRow(content, label)
	UI.RowSlider(row, min, max, step, onStep, onSet)
	return row
end

-- A place row: its name, a short grey detail at x from the row's left, its buttons at the right.
local function listRow(content, labels, x)
	local row = UI.SettingRow(content)
	row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.detail:SetPoint("LEFT", row, "LEFT", x, 0)
	row.detail:SetWidth(DETAIL_W)
	row.detail:SetJustifyH("LEFT")
	row.detail:SetWordWrap(false)
	UI.RowButtons(row, labels)
	return row
end

local function pooled(pool, i, labels, x)
	pool[i] = pool[i] or listRow(page, labels, x)
	return pool[i]
end

local function build(content, win)
	window, page = win, content
	Smart = ns.Smart
	page.flow = UI.Flow(content)
	if not Smart then
		page.missing = UI.Description(content, "GameFontDisableLarge")
		page.missing:SetText(L.SMART_MISSING)
		return
	end

	page.intro = UI.Description(content, "GameFontHighlight")
	page.intro:SetWidth(N.ROW_W - N.TITLE_X)
	page.intro:SetText(L.SMART_INTRO)
	page.enable = UI.SettingRow(content, L.SMART)
	UI.RowCheckbox(page.enable, toggle)
	page.enable.onClick = toggle
	page.target = sliderRow(content, L.TARGET, TARGET_MIN, TARGET_MAX, TARGET_STEP, nudgeTarget, setTarget)
	for _, kind in ipairs({ "goal", "pace" }) do
		if UI.SmartList(kind) then page[kind] = UI.SmartPicker(window, content, kind, refresh) end
	end
	page.floor = sliderRow(content, L.FLOOR, FLOOR_MIN, FLOOR_MAX, 1, nudgeFloor, function(value) setFloor(value < FLOOR_STEP * 7 and FLOOR_MIN or math.floor(value / FLOOR_STEP + 0.5) * FLOOR_STEP) end)
	page.nowSection = UI.Section(content, L.RIGHT_NOW)
	page.lines = {}
	for i = 1, 4 do page.lines[i] = UI.Description(content, i == 1 and "GameFontNormal" or i == 4 and "GameFontDisableSmall" or "GameFontHighlight") end
	page.offLine = UI.Description(content, "GameFontDisable")
	page.offLine:SetText(L.SMART_OFF_LINE)
	page.learnedFold = UI.FoldSection(content, "learned", L.LEARNED_FOLD)
	page.learnedFold.onToggle = refresh
	page.resetAll = UI.ButtonLine(content, { L.RESET_ALL })
	page.resetAll.buttons[1].action = function()
		UI.Confirm(window, L.RESET_ALL_TEXT, nil, L.RESET, function()
			Smart.ResetLearning(nil)
			refresh()
		end)
	end
	page.noLearned = UI.Description(content, "GameFontDisable")
	page.noLearned:SetText(L.NO_LEARNED)
	page.learnedRows = {}
	page.lagFold = UI.FoldSection(content, "lagged", L.LAGGED)
	page.lagFold.onToggle = refresh
	page.noLag = UI.Description(content, "GameFontDisable")
	page.noLag:SetText(L.NO_LAGGED)
	page.lagRows = {}
	-- Both start folded.
	for _, key in ipairs({ "learned", "lagged" }) do if UI.Folded[key] == nil then UI.Folded[key] = true end end
	page.learnedFold.Paint()
	page.lagFold.Paint()
end

-- The last changes Smart made, newest first; State() keeps only the latest, so the page remembers a few.
local function noteChange(last)
	if not (last and last.cvar) or last == lastSeen or (lastSeen and last.t == lastSeen.t and last.cvar == lastSeen.cvar) then return end
	lastSeen = { cvar = last.cvar, from = last.from, to = last.to, t = last.t }
	table.insert(recent, 1, lastSeen)
	while #recent > HISTORY do table.remove(recent) end
end

local function tick()
	if not Smart then return end
	local state = Smart.State() or {}
	noteChange(state.last)
	local lines = page.lines
	local goal = state.goal or (state.cap and math.min(state.target or target(), state.cap)) or state.target or target()
	local loc = ns.Location.Current() or {}
	lines[1]:SetText(string.format(L.NOW_LINE, (UI.SmartStatus(state):gsub("^%l", string.upper)), math.floor((state.fps or 0) + 0.5), goal, ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE, UI.SmartStyle()))
	lines[2]:SetText(state.cap and string.format(L.CAP, state.cap) or "")
	local text = UI.ChangeText(state.last)
	lines[3]:SetText(text and string.format(L.LAST, text) or L.NO_LAST)
	local older = {}
	for i = 2, #recent do older[#older + 1] = UI.ChangeText(recent[i]) end
	lines[4]:SetText(#older > 0 and string.format(L.BEFORE_THAT, table.concat(older, " · ")) or "")
end

local function age(t)
	local seconds = math.max(0, time() - (t or 0))
	if seconds < 3600 then return string.format(L.AGE_MIN, math.floor(seconds / 60)) end
	if seconds < 86400 then return string.format(L.AGE_HOURS, math.floor(seconds / 3600)) end
	return string.format(L.AGE_DAYS, math.floor(seconds / 86400))
end

local function learnedItems()
	local items = {}
	for key, entry in pairs(ns.db.smart.learned) do
		local samples = 0
		for _, gain in pairs(entry.gains or {}) do samples = samples + (gain.n or 0) end
		items[#items + 1] = { key = key, label = UI.PlaceLabel(key), samples = samples, t = entry.t }
	end
	table.sort(items, function(a, b) return a.label < b.label end)
	return items
end

-- The worst places first, as Smart sorts them; the top LAG_SHOWN only.
local function lagItems()
	local items = {}
	for i, area in ipairs(Smart.Areas and Smart.Areas() or {}) do
		if i > LAG_SHOWN then break end
		items[i] = area
	end
	return items
end

local function percent(share) return math.floor((share or 0) * 100 + 0.5) end

local function lagDetail(area)
	local text = string.format(L.LAG_ROW, math.floor((area.fps or 0) + 0.5), math.floor((area.minFps or 0) + 0.5), percent(area.lagShare))
	if area.combatDrop and area.combatDrop >= FIGHT_DROP then text = text .. string.format(L.LAG_FIGHTS, percent(area.combatDrop)) end
	return text
end

local function saveAsProfile(item)
	local id = Smart.SaveAsProfile(item.key, string.format(L.SMART_NAME, item.label))
	local profile = id and ns.Profiles.Get(id)
	if profile then
		ns.log(string.format(L.SAVED_AS, profile.name))
		UI.ProfilesTab.Select(id)
	end
	refresh()
end

local function resetOne(item)
	Smart.ResetLearning(item.key)
	refresh()
end

local function forgetArea(area)
	Smart.ForgetArea(area.key)
	refresh()
end

local function rowNode(row, tip, extra)
	local node = extra or {}
	node.cursorX, node.onFocus, node.tipRegion, node.tip = N.LABEL_X - 6, UI.RowFocus(row), row.tipAnchor, tip
	return UI.Node(window, row, row.onClick, node)
end

local function buttonNode(button, tip) return UI.Node(window, button, button.action, { tip = { title = button:GetText(), lines = { tip }, side = "right" } }) end

local function sliderNode(row, title, tip, onDir)
	return rowNode(row, { title = title, lines = { tip, UI.ByMode(L.STEPPER_TIP, L.SLIDER_TIP_MOUSE) }, side = "above" }, { noSide = true, onDir = onDir })
end

local function foldNode(fold, title) return UI.Node(window, fold, function() fold.Toggle() end, { cursorX = 0, foldKey = fold.key, tip = { title = title, lines = { L.FOLD_TIP }, side = "right" } }) end

local function refreshPage(content)
	local flow, nodes = content.flow, {}
	flow:Start()
	if not Smart then
		flow:Add(content.missing, 20, N.ROW_GAP, N.LABEL_X)
		flow:Finish()
		return nodes
	end

	tick()
	local on = Smart.Enabled()
	local busy = calibrating()
	flow:Add(content.intro, content.intro:GetStringHeight(), N.ROW_GAP, N.TITLE_X)
	flow:Add(content.enable, N.ROW_H)
	content.enable.control:Set(on)
	UI.SetRowEnabled(content.enable, not busy)
	if not busy then nodes[#nodes + 1] = rowNode(content.enable, { title = L.SMART, lines = { L.SMART_TIP_FULL }, side = "above" }) end
	local value = target()
	content.target.slider:Set(value, tostring(value))
	flow:Add(content.target, N.ROW_H)
	nodes[#nodes + 1] = sliderNode(content.target, L.TARGET, L.TARGET_TIP, nudgeTarget)
	for _, kind in ipairs({ "goal", "pace" }) do
		if content[kind] then content[kind].Draw(flow, nodes, true) end
	end
	local floor = floorPercent()
	content.floor.slider:Set(floor, floor .. "%")
	flow:Add(content.floor, N.ROW_H)
	nodes[#nodes + 1] = sliderNode(content.floor, L.FLOOR, L.FLOOR_TIP, nudgeFloor)

	flow:Add(content.nowSection, N.SECTION_H, 0)
	if on then
		for _, line in ipairs(content.lines) do if line:GetText() ~= "" then flow:Add(line, LINE_H, 2, N.LABEL_X) end end
	else
		flow:Add(content.offLine, LINE_H, 2, N.LABEL_X)
	end

	local items = learnedItems()
	local learnedFold = content.learnedFold
	learnedFold.count:SetText(string.format(L.LEARNED_COUNT, #items))
	flow:Add(learnedFold, N.SECTION_H, 0)
	nodes[#nodes + 1] = foldNode(learnedFold, L.LEARNED_FOLD)
	if learnedFold.IsOpen() then
		if #items == 0 then flow:Add(content.noLearned, 14, N.ROW_GAP, N.LABEL_X) end
		for i, item in ipairs(items) do
			local row = pooled(content.learnedRows, i, { L.SAVE_PROFILE, L.RESET }, LEARNED_X)
			flow:Add(row, N.ROW_H)
			row.label:SetText(item.label)
			row.detail:SetText(string.format(L.LEARNED_ROW, item.samples, (item.t or 0) > 0 and age(item.t) or "-"))
			row.onClick = function() saveAsProfile(item) end
			row.onRightClick = function() resetOne(item) end
			row.buttons[1].action, row.buttons[2].action = row.onClick, row.onRightClick
			nodes[#nodes + 1] = rowNode(row, { title = item.label, lines = { L.LEARNED_TIP }, actions = { { "PAD1", L.SAVE_PROFILE }, { "PAD3", L.RESET } }, mouse = { L.SAVE_CLICK, L.RIGHT_RESET }, side = "above" }, {
				prompts = { { "PAD3", L.RESET } },
				onKey = function(key)
					if key ~= "PAD3" then return end
					resetOne(item)
					return true
				end,
			})
			nodes[#nodes + 1] = buttonNode(row.buttons[1], L.LEARNED_TIP)
			nodes[#nodes + 1] = buttonNode(row.buttons[2], L.RESET_ALL_TIP)
		end
		local resetAll = content.resetAll.buttons[1]
		resetAll:SetEnabled(#items > 0)
		flow:Add(content.resetAll, N.BUTTON_H)
		if #items > 0 then nodes[#nodes + 1] = buttonNode(resetAll, L.RESET_ALL_TIP) end
	end

	local areas = lagItems()
	local lagFold = content.lagFold
	lagFold.count:SetText(string.format(L.LAGGED_COUNT, #areas))
	flow:Add(lagFold, N.SECTION_H, 0)
	nodes[#nodes + 1] = foldNode(lagFold, L.LAGGED)
	if lagFold.IsOpen() then
		if #areas == 0 then flow:Add(content.noLag, 14, N.ROW_GAP, N.LABEL_X) end
		for i, area in ipairs(areas) do
			local row = pooled(content.lagRows, i, { L.FORGET }, LAG_X)
			flow:Add(row, N.ROW_H)
			row.label:SetText(area.name or area.key)
			row.detail:SetText(lagDetail(area))
			row.onClick = nil
			row.onRightClick = function() forgetArea(area) end
			row.buttons[1].action = row.onRightClick
			nodes[#nodes + 1] = rowNode(row, { title = area.name or area.key, lines = { lagDetail(area), L.LAG_TIP }, actions = { { "PAD3", L.FORGET } }, mouse = { L.RIGHT_FORGET }, side = "above" }, {
				prompts = { { "PAD3", L.FORGET } },
				onKey = function(key)
					if key ~= "PAD3" then return end
					forgetArea(area)
					return true
				end,
			})
			nodes[#nodes + 1] = buttonNode(row.buttons[1], L.LAG_TIP)
		end
	end
	flow:Finish()
	return nodes
end

UI.SmartLines = function() return page and page.lines end

UI.AddPage({ key = "smart", order = 3, title = function() return L.TAB_SMART end, build = build, refresh = refreshPage, tick = tick })
