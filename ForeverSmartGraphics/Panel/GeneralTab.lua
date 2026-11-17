-- Forever Smart Graphics "Options" page. Row pattern adapted from Forever Controller
-- Tweaks' Tweaks tab (MIT, same author). Controls (automatic, mouse and keyboard, or controller look); Notices
-- (every notification, all off by default, and the minimap FPS pulse); Minimap (its button and the FPS readout); Start
-- over (Restore my original settings, asks first); About (the debug log and the version).
local addonName, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

local window, page

-- Log setting changes in chat (options.chatLog): off unless true, as every notification.
function UI.ChatLogOn() return ns.db.options.chatLog == true end

local function refresh() window:Refresh() end

local OPTIONS = {
	{ L.ANNOUNCE, L.ANNOUNCE_TIP, function() return UI.AnnounceOn() end, function(o)
		o.announce = not UI.AnnounceOn()
		if not o.announce then UI.Notify.Hide("pending") end
	end },
	{ L.MINIMAP, L.MINIMAP_TIP, function(o) return o.minimap.shown ~= false end, function(o)
		o.minimap.shown = o.minimap.shown == false
		UI.UpdateMinimapButton()
	end },
	{ L.MINIMAP_FPS, L.MINIMAP_FPS_TIP, function() return UI.MinimapFpsOn() end, function(o)
		o.minimapFps = not UI.MinimapFpsOn()
		UI.UpdateMinimapFps()
	end },
	{ L.SUGGEST, L.SUGGEST_TIP, function() return UI.SuggestOn() end, function(o)
		local on = not UI.SuggestOn()
		o.suggest = on
		if ns.Smart and ns.Smart.SetSuggest then ns.Smart.SetSuggest(on) end
		if not on then UI.Notify.Hide("suggest") end
	end },
	{ L.CHAT_LOG, L.CHAT_LOG_TIP, function() return UI.ChatLogOn() end, function(o) o.chatLog = not UI.ChatLogOn() end },
	{ L.DEBUG, L.DEBUG_TIP, function(o) return o.debug end, function(o) o.debug = not o.debug end },
	{ L.SMART_NOTICE, L.SMART_NOTICE_TIP, function() return UI.SmartNoticeOn() end, function(o) o.smartNotice = not UI.SmartNoticeOn() end },
	{ L.CHAT_LOG_SMART, L.CHAT_LOG_SMART_TIP, function(o) return o.chatLogSmart == true end, function(o) o.chatLogSmart = not (o.chatLogSmart == true) end },
	{ L.PROFILE_NOTICE, L.PROFILE_NOTICE_TIP, function() return UI.ProfileNoticeOn() end, function(o) o.notifyProfile = not UI.ProfileNoticeOn() end },
	{ L.FPS_PULSE, L.FPS_PULSE_TIP, function() return UI.FpsPulseOn() end, function(o) o.fpsPulse = not UI.FpsPulseOn() end },
}

local function toggle(i)
	OPTIONS[i][4](ns.db.options)
	refresh()
end

local function setInput(setting)
	UI.SetInput(setting)
	refresh()
end

-- One step through the Controls choices; false past an end.
local function stepInput(dir)
	local inputs = UI.INPUTS
	local i = 1
	for j, key in ipairs(inputs) do if key == UI.InputSetting() then i = j end end
	local nextInput = inputs[i + dir]
	if not nextInput then return false end
	setInput(nextInput)
end

local function openInput()
	UI.OpenChoice(window, page.controls.control, UI.ChoiceEntries(UI.INPUTS, function(key) return L.INPUTS[key] end), UI.InputSetting(), function(picked) setInput(picked.id) end)
end

local function restoreOriginal()
	UI.Confirm(window, L.RESTORE_TEXT, L.RESTORE_SUB, L.RESTORE, function()
		ns.Apply.RestoreOriginal()
		refresh()
	end)
end

local function version()
	local get = C_AddOns and C_AddOns.GetAddOnMetadata
	local ok, value = pcall(get, addonName, "Version")
	return ok and value or "?"
end

-- The checkboxes by section, as indexes into OPTIONS.
local SECTIONS = {
	{ title = "SECTION_NOTICES", desc = "NOTICES_DESC", rows = { 7, 9, 4, 1, 5, 8, 10 } },
	{ title = "SECTION_MINIMAP", rows = { 2, 3 } },
}
local DEBUG_ROW = 6

local function checkRow(content, i)
	local option = OPTIONS[i]
	local row = UI.SettingRow(content, option[1])
	UI.RowCheckbox(row, function() toggle(i) end)
	row.onClick = function() toggle(i) end
	content.rows[i] = row
	return row
end

local function build(content, win)
	window, page = win, content
	page.flow = UI.Flow(content)
	page.controlsSection = UI.Section(content, L.SECTION_CONTROLS)
	page.controls = UI.SettingRow(content, L.CONTROLS)
	UI.RowChoice(page.controls, stepInput, openInput)
	page.controls.onClick = openInput
	page.rows, page.sections = {}, {}
	for s, section in ipairs(SECTIONS) do
		page.sections[s] = UI.Section(content, L[section.title])
		if section.desc then
			page.sections[s].desc = UI.Description(content, "GameFontHighlight")
			page.sections[s].desc:SetText(L[section.desc])
		end
		for _, i in ipairs(section.rows) do checkRow(content, i) end
	end
	page.startSection = UI.Section(content, L.SECTION_START_OVER)
	page.restoreText = UI.Description(content, "GameFontHighlight")
	page.restoreText:SetText(L.RESTORE_TIP .. " " .. L.RESTORE_KEEPS)
	page.restore = UI.ButtonLine(content, { L.RESTORE })
	page.restore.buttons[1].action = restoreOriginal
	page.aboutSection = UI.Section(content, L.ABOUT)
	checkRow(content, DEBUG_ROW)
	page.version = UI.Description(content, "GameFontDisable")
end

local function optionNode(i)
	local row, option = page.rows[i], OPTIONS[i]
	row.control:Set(option[3](ns.db.options))
	return UI.Node(window, row, function() toggle(i) end, { cursorX = N.LABEL_X - 6, onFocus = UI.RowFocus(row), tipRegion = row.tipAnchor, tip = { title = option[1], lines = { option[2] }, side = "above" } })
end

local function refreshPage(content)
	local flow, nodes = content.flow, {}
	flow:Start()
	flow:Add(content.controlsSection, N.SECTION_H, 0)
	local setting = UI.InputSetting()
	content.controls.control:Set(L.INPUTS[setting], setting == UI.INPUTS[1], setting == UI.INPUTS[#UI.INPUTS])
	flow:Add(content.controls, N.ROW_H)
	nodes[1] = UI.Node(window, content.controls, openInput, {
		cursorX = N.LABEL_X - 6, noSide = true, onFocus = UI.RowFocus(content.controls), tipRegion = content.controls.tipAnchor, onDir = function(dir) return stepInput(dir) end,
		tip = { title = L.CONTROLS, lines = { L.CONTROLS_TIP, UI.ByMode(L.CHOICE_TIP, L.CHOICE_TIP_MOUSE) }, side = "above" },
	})
	for s, section in ipairs(SECTIONS) do
		local head = content.sections[s]
		flow:Add(head, N.SECTION_H, 0)
		if head.desc then flow:Add(head.desc, head.desc:GetStringHeight(), N.ROW_GAP, N.LABEL_X) end
		for _, i in ipairs(section.rows) do
			flow:Add(content.rows[i], N.ROW_H)
			nodes[#nodes + 1] = optionNode(i)
		end
	end
	flow:Add(content.startSection, N.SECTION_H, 0)
	flow:Add(content.restoreText, content.restoreText:GetStringHeight(), N.ROW_GAP, N.LABEL_X)
	flow:Add(content.restore, N.BUTTON_H)
	local restore = content.restore.buttons[1]
	nodes[#nodes + 1] = UI.Node(window, restore, restoreOriginal, { tip = { title = L.RESTORE, lines = { L.RESTORE_TIP }, side = "right" } })
	flow:Add(content.aboutSection, N.SECTION_H, 0)
	flow:Add(content.rows[DEBUG_ROW], N.ROW_H)
	nodes[#nodes + 1] = optionNode(DEBUG_ROW)
	content.version:SetText(string.format(L.ABOUT_LINE, version()))
	flow:Add(content.version, 16, N.ROW_GAP, N.LABEL_X)
	flow:Finish()
	return nodes
end

UI.AddPage({ key = "general", order = 4, title = function() return L.TAB_GENERAL end, build = build, refresh = refreshPage })
