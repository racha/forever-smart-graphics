-- Forever Smart Graphics "Profiles" page and the profile editor. Row pattern adapted
-- from Forever Controller Tweaks' Tweaks tab (MIT, same author). The list: one row per profile with where it is used
-- (a click or Edit opens it), New profile... in the bar. The editor, a second level under Profiles: All profiles,
-- Copy, Rename, Delete and Use everywhere in a fixed bar; a legend, the Quality preset, then Quality / Render /
-- Detail as fold sections, one row per Catalog setting with the control the game's Graphics options use (a slider for
-- numbers, a dropdown for named levels), a reset icon while the profile sets its own value, its FPS impact, and what
-- Smart mode runs it at right now when that differs. X or a right-click puts a value back to following.
local _, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

local ORIGINAL = "your original"
local RESET_SIZE, LIST_ROW_H, LIST_ROW_GAP, EDIT_W, BAR_LEFT, BAR_RIGHT, BAR_GAP = 18, 44, 4, 60, 7, -20, 6
local NOW_COLOR = { 0.4, 0.8, 1 }

local window
local selected

local function profileOf() return ns.Profiles.Get(selected) or ns.Profiles.Get("default") end

-- The value the profile uses for a cvar: its own, else the inherited one and where it comes from.
local function valueOf(cvar)
	local profile = profileOf()
	local own = profile and profile.values[cvar]
	if own ~= nil then return own end
	local value, source = ns.Profiles.Inherited(profile.id, cvar)
	return value, source or ORIGINAL
end

local function refresh() window:Refresh() end

local function unsupported(cvar) return ns.db.unsupported[cvar] end

local function set(cvar, value)
	ns.Profiles.SetValue(profileOf().id, cvar, value)
	UI.UserEdit()
	refresh()
end

-- One step of a setting; false at an end (nothing changes).
local function step(cvar, dir)
	if unsupported(cvar) then return end
	local entry = ns.Catalog.Get(cvar)
	local nextValue = ns.Catalog.Step(cvar, tonumber((valueOf(cvar))) or entry.min, dir)
	if nextValue == nil then return false end
	set(cvar, nextValue)
end

-- A slider drag or track click: on the setting's grid; nothing when it lands on the value it has.
local function slide(cvar, value)
	if unsupported(cvar) then return end
	local snapped = ns.Catalog.Clamp(cvar, value)
	if snapped == nil or snapped == tonumber((valueOf(cvar))) then return end
	set(cvar, snapped)
end

local function openChoice(row)
	local cvar = row.cvar
	if not cvar or unsupported(cvar) then return end
	local entry = ns.Catalog.Get(cvar)
	local entries = UI.ChoiceEntries(UI.ChoiceValues(entry), function(value) return ns.Catalog.Format(cvar, value) end)
	UI.OpenChoice(window, row.choice, entries, tonumber((valueOf(cvar))), function(picked) set(cvar, picked.id) end)
end

local function clear(cvar)
	ns.Profiles.SetValue(profileOf().id, cvar, nil)
	UI.UserEdit()
	refresh()
end

local function openEditor(id)
	if not id then return refresh() end
	UI.SelectPage("profile", id)
end

-- Where a profile is used: location types, then specific places by name; Default also every place without one.
local function usage(id)
	local used = {}
	for _, key in ipairs(ns.Location.KEYS) do
		if (ns.db.locations[key] or "default") == id then used[#used + 1] = ns.Location.LABELS[key] end
	end
	local places = {}
	for _, override in pairs(ns.db.overrides) do if override.profile == id then places[#places + 1] = string.format(L.PLACE_SUFFIX, override.name or "?") end end
	table.sort(places)
	for _, name in ipairs(places) do used[#used + 1] = name end
	return #used > 0 and string.format(L.USED_IN, table.concat(used, ", ")) or L.NOT_USED
end

local function usedCount(id)
	local count = 0
	for _, key in ipairs(ns.Location.KEYS) do if (ns.db.locations[key] or "default") == id then count = count + 1 end end
	for _, override in pairs(ns.db.overrides) do if override.profile == id then count = count + 1 end end
	return count == 1 and L.USED_COUNT_ONE or string.format(L.USED_COUNT, count)
end

local function usageLine(profile)
	if profile.id == "default" then return L.USED_BY_DEFAULT end

	local preset = UI.PresetOf(profile.id)
	local own = 0
	for _ in pairs(profile.values) do own = own + 1 end
	local second = preset and string.format(L.PRESET_NAMED, UI.PresetName(preset)) or (own > 0 and string.format(L.OWN_COUNT, own) or L.OWN_NONE)
	return usage(profile.id) .. " · " .. second
end

-- New profile: a name (the next free "Profile N") and what it starts from: nothing (every setting follows Default),
-- the current settings, or a preset. Create makes it and opens its editor; it is not assigned anywhere.
local Create = {}
UI.CreateProfile = Create
local createFrame, createState
local CREATE_W, CHOICE_H, CREATE_PAD, DIVIDER_H = 380, 20, 20, 9

local function startChoices()
	local choices = { { id = "empty", name = L.START_EMPTY, hint = L.START_EMPTY_TIP, note = L.START_EMPTY_NOTE }, { id = "current", name = L.START_CURRENT, hint = L.START_CURRENT_TIP } }
	for _, preset in ipairs(ns.Catalog.PRESETS) do
		choices[#choices + 1] = { id = preset.key, name = preset.name, hint = L.PRESET_TIPS[preset.key] or string.format(L.START_PRESET_TIP, preset.name), note = preset.key == "beyond" and L.START_HEAVIEST or nil, divider = #choices == 2 }
	end
	return choices
end

local function createdId(choice, name)
	if choice.id == "empty" then return ns.Profiles.Create(name, {}) end
	if choice.id == "current" then return ns.Profiles.FromCurrent(name) end
	local id = ns.Profiles.FromPreset(choice.id)
	local profile = id and ns.Profiles.Get(id)
	if profile and profile.name ~= name then ns.Profiles.Rename(id, name) end
	return id
end

-- Pad focus: each choice, then Create and Cancel (the name is typed with a keyboard; pads keep the auto name).
local function createPoint()
	local state = createState
	local items = createFrame.items
	local focused = items[state.index]
	for i, choice in ipairs(createFrame.choices) do choice.check:SetShown(i == state.choice) end
	createFrame.hint:SetText(state.choices[state.choice].hint or "")
	for _, button in ipairs({ createFrame.create, createFrame.cancel }) do if button == focused then button:LockHighlight() else button:UnlockHighlight() end end
	state.window.cursor:Attach(focused, -12)
end

function Create.Close(accept)
	local state = createState
	if not state then return end
	local name = createFrame.edit:GetText()
	createState = nil
	createFrame.edit:ClearFocus()
	createFrame:Hide()
	createFrame.shade:Hide()
	local win = state.window
	win.modal = nil
	if not accept then return win:Refresh() end

	name = name and name:match("^%s*(.-)%s*$")
	if not name or name == "" then name = state.auto end
	openEditor(createdId(state.choices[state.choice], name))
end

function Create.Move(_, dx, dy)
	local state = createState
	local last = #createFrame.items
	if dy ~= 0 then
		local index = state.index - dy
		if index > last - 1 then index = last - 1 end
		state.index = math.max(2, index)
	elseif state.index >= last - 1 then
		state.index = dx > 0 and last or last - 1
	end
	createPoint()
end

function Create.OnPad(_, key)
	local state = createState
	if key == "PAD2" then return Create.Close(false) end
	if key ~= "PAD1" then
		local dir = key == "PADDUP" and { 0, 1 } or key == "PADDDOWN" and { 0, -1 } or key == "PADDLEFT" and { -1, 0 } or key == "PADDRIGHT" and { 1, 0 }
		if dir then Create.Move(nil, dir[1], dir[2]) end
		return
	end
	local index, last = state.index, #createFrame.items
	if index == last then return Create.Close(false) end
	if index == last - 1 then return Create.Close(true) end
	if index > 1 then
		state.choice = index - 1
		createPoint()
	end
end

function Create.IsOpen() return createState ~= nil end

function Create.Frame() return createFrame end

local function buildCreate(choices)
	createFrame = CreateFrame("Frame", "ForeverSmartGraphicsCreate", UIParent)
	createFrame:SetWidth(CREATE_W)
	createFrame:EnableMouse(true)
	createFrame:Hide()
	UI.DialogArt(createFrame)
	-- The window dimmed under the dialog.
	createFrame.shade = CreateFrame("Frame", nil, UIParent)
	createFrame.shade:EnableMouse(true)
	createFrame.shade:Hide()
	local dim = createFrame.shade:CreateTexture(nil, "BACKGROUND")
	dim:SetColorTexture(0, 0, 0, 0.5)
	dim:SetAllPoints()
	createFrame.title = createFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	createFrame.title:SetPoint("TOP", 0, -16)
	createFrame.title:SetText(L.NEW_PROFILE_TITLE)
	createFrame.nameLabel = createFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	createFrame.nameLabel:SetPoint("TOPLEFT", CREATE_PAD, -44)
	createFrame.nameLabel:SetText(L.NAME)
	local edit = CreateFrame("EditBox", nil, createFrame, "InputBoxTemplate")
	edit:SetAutoFocus(false)
	edit:SetSize(CREATE_W - 2 * CREATE_PAD - 60, 20)
	edit:SetPoint("TOPLEFT", CREATE_PAD + 56, -40)
	edit:SetMaxLetters(32)
	edit:SetScript("OnEnterPressed", function() Create.Close(true) end)
	edit:SetScript("OnEscapePressed", function() Create.Close(false) end)
	createFrame.edit = edit
	createFrame.from = createFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	createFrame.from:SetPoint("TOPLEFT", CREATE_PAD, -74)
	createFrame.from:SetText(L.START_FROM)
	createFrame.items = { edit }
	createFrame.choices = {}
	local y = 94
	for i, spec in ipairs(choices) do
		if spec.divider then
			local line = createFrame:CreateTexture(nil, "ARTWORK")
			line:SetColorTexture(1, 1, 1, 0.15)
			line:SetSize(CREATE_W - 2 * CREATE_PAD, 1)
			line:SetPoint("TOPLEFT", CREATE_PAD, -(y + 4))
			y = y + DIVIDER_H
		end
		local choice = CreateFrame("Button", nil, createFrame)
		choice:SetSize(CREATE_W - 2 * CREATE_PAD, CHOICE_H)
		choice:SetPoint("TOPLEFT", CREATE_PAD, -y)
		-- UIRadioButtonTemplate's art: Interface\Buttons\UI-RadioButton, normal, checked and highlight quarters.
		local radio = choice:CreateTexture(nil, "ARTWORK")
		radio:SetTexture("Interface\\Buttons\\UI-RadioButton")
		radio:SetTexCoord(0, 0.25, 0, 1)
		radio:SetSize(16, 16)
		radio:SetPoint("LEFT")
		choice.check = choice:CreateTexture(nil, "OVERLAY")
		choice.check:SetTexture("Interface\\Buttons\\UI-RadioButton")
		choice.check:SetTexCoord(0.25, 0.5, 0, 1)
		choice.check:SetAllPoints(radio)
		choice:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton", "ADD")
		choice.label = choice:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		choice.label:SetPoint("LEFT", radio, "RIGHT", 6, 0)
		choice.note = choice:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		choice.note:SetPoint("LEFT", choice.label, "RIGHT", 8, 0)
		choice:SetScript("OnClick", function()
			UI.NoteInput("mouse")
			createState.choice = i
			createState.index = i + 1
			createPoint()
		end)
		createFrame.choices[i] = choice
		createFrame.items[#createFrame.items + 1] = choice
		y = y + CHOICE_H
	end
	createFrame.hint = createFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	createFrame.hint:SetPoint("TOPLEFT", CREATE_PAD, -(y + 4))
	createFrame.hint:SetWidth(CREATE_W - 2 * CREATE_PAD)
	createFrame.hint:SetJustifyH("LEFT")
	createFrame.create = UI.DialogButton(createFrame)
	UI.FitButton(createFrame.create, L.CREATE)
	createFrame.create:SetPoint("BOTTOMRIGHT", createFrame, "BOTTOM", -6.5, 16)
	createFrame.create:SetScript("OnClick", function() Create.Close(true) end)
	createFrame.cancel = UI.DialogButton(createFrame)
	UI.FitButton(createFrame.cancel, L.CANCEL)
	createFrame.cancel:SetPoint("BOTTOMLEFT", createFrame, "BOTTOM", 6.5, 16)
	createFrame.cancel:SetScript("OnClick", function() Create.Close(false) end)
	createFrame.items[#createFrame.items + 1] = createFrame.create
	createFrame.items[#createFrame.items + 1] = createFrame.cancel
	createFrame:SetHeight(y + 34 + 21 + 16)
end

function Create.Open(win)
	local choices = startChoices()
	if not createFrame then buildCreate(choices) end
	createState = { window = win, choices = choices, choice = 1, index = 2, auto = UI.AutoName() }
	for i, choice in ipairs(createFrame.choices) do
		choice.label:SetText(choices[i] and choices[i].name or "")
		choice.note:SetText(choices[i] and choices[i].note or "")
	end
	createFrame.edit:SetText(createState.auto)
	createFrame:SetScale(win:GetScale())
	createFrame.shade:SetScale(win:GetScale())
	createFrame.shade:ClearAllPoints()
	createFrame.shade:SetAllPoints(win)
	createFrame:ClearAllPoints()
	createFrame:SetPoint("CENTER", win, "CENTER", 0, 0)
	UI.HideTooltip()
	win.modal = Create
	createFrame.shade:Show()
	UI.RaiseAbove(createFrame.shade, win, "catcher")
	UI.RaiseAbove(createFrame, win, "dialog")
	createFrame:Show()
	win:SetPrompts({ { "PAD1", L.SELECT }, { "PAD2", L.CANCEL } })
	createPoint()
	createFrame.edit:SetFocus()
	createFrame.edit:HighlightText()
end

-- The editor's actions, in its fixed bar.
local ACTIONS = {
	{ key = "copy", label = "COPY", tip = "COPY_TIP" },
	{ key = "rename", label = "RENAME", tip = "RENAME_TIP", locked = true },
	{ key = "delete", label = "DELETE", tip = "DELETE_TIP", locked = true },
	{ key = "everywhere", label = "USE_EVERYWHERE", tip = "USE_EVERYWHERE_TIP" },
}

local RUN = {
	copy = function(profile) openEditor(ns.Profiles.Copy(profile.id)) end,
	rename = function(profile, cell)
		UI.Name.Open({ window = window, cell = cell, title = L.NAME_TITLE, text = profile.name, onOK = function(name) ns.Profiles.Rename(profile.id, name) end })
	end,
	delete = function(profile)
		UI.Confirm(window, string.format(L.DELETE_TEXT, profile.name), L.DELETE_SUB, L.DELETE, function()
			ns.Profiles.Delete(profile.id)
			UI.SelectPage("profiles")
		end)
	end,
	everywhere = function(profile)
		UI.Confirm(window, string.format(L.EVERYWHERE_TEXT, profile.name), L.EVERYWHERE_SUB, L.USE_EVERYWHERE, function()
			ns.Profiles.AssignAll(profile.id)
			UI.Flash(string.format(L.USED_EVERYWHERE, profile.name))
			refresh()
		end)
	end,
}

local function locked() return profileOf().id == "default" end

local function runAction(spec, cell)
	if spec.locked and locked() then return end
	RUN[spec.key](profileOf(), cell)
end

-- The list page.
local function profileRow(content, i)
	local rows = content.rows
	if rows[i] then return rows[i] end

	local row = CreateFrame("Button", nil, content)
	row:SetSize(N.ROW_W, LIST_ROW_H)
	for _, key in ipairs({ "hover", "wash" }) do
		local tex = row:CreateTexture(nil, "BACKGROUND")
		tex:SetColorTexture(1, 1, 1, 0.1)
		tex:SetPoint("TOPLEFT", N.HOVER_LEFT, 0)
		tex:SetPoint("BOTTOMRIGHT", N.HOVER_RIGHT, 0)
		tex:Hide()
		row[key] = tex
	end
	row:SetScript("OnEnter", function(self) self.hover:Show() end)
	row:SetScript("OnLeave", function(self) self.hover:Hide() end)
	local line = row:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.08)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", N.HOVER_LEFT, -LIST_ROW_GAP / 2)
	line:SetPoint("BOTTOMRIGHT", N.HOVER_RIGHT, -LIST_ROW_GAP / 2)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
	row.label:SetPoint("TOPLEFT", N.LABEL_X, -5)
	row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
	row.tag:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
	row.tag:SetText(L.IN_USE)
	row.usage = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.usage:SetPoint("TOPLEFT", N.LABEL_X, -25)
	row.usage:SetWidth(N.ROW_W - N.LABEL_X - EDIT_W - 24)
	row.usage:SetJustifyH("LEFT")
	row.usage:SetWordWrap(false)
	row.edit = UI.SmallButton(row, L.EDIT)
	row.edit:SetSize(EDIT_W, N.BUTTON_H)
	row.edit:SetPoint("RIGHT", -8, 0)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", UI.RowClick)
	rows[i] = row
	return row
end

local function buildList(content, win, bar)
	window = win
	content.flow = UI.Flow(content)
	content.rows = {}
	content.newButton = UI.SmallButton(bar, L.NEW_PROFILE)
	content.newButton:SetPoint("LEFT", bar, "LEFT", BAR_LEFT, 0)
	content.newButton.action = function() Create.Open(window) end
	content.hint = bar:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	content.hint:SetPoint("LEFT", content.newButton, "RIGHT", 10, 0)
	content.hint:SetText(L.PROFILES_HINT)
	content.empty = UI.Description(content, "GameFontDisable")
	content.empty:SetText(L.ONE_PROFILE)
end

local function refreshList(content)
	local flow, nodes = content.flow, {}
	local active = ns.Apply.Active() or {}
	nodes[1] = UI.Node(window, content.newButton, content.newButton.action, { tip = { title = L.NEW_PROFILE, lines = { L.NEW_TIP }, side = "right" } })
	flow:Start()
	local profiles = ns.Profiles.List()
	for i, item in ipairs(profiles) do
		local profile = ns.Profiles.Get(item.id)
		local row = profileRow(content, i)
		local id = item.id
		row.label:SetText(profile.name)
		row.tag:SetShown(active.profileId == id)
		row.usage:SetText(usageLine(profile))
		-- Too long for the line: just where it is used, then just how many places; never cut.
		local fits = function() return UI.TextWidth(row.usage) <= row.usage:GetWidth() end
		if not fits() then row.usage:SetText(usage(profile.id)) end
		if not fits() then row.usage:SetText(usedCount(profile.id)) end
		row.onClick = function() openEditor(id) end
		row.edit.action = row.onClick
		flow:Add(row, LIST_ROW_H, LIST_ROW_GAP)
		nodes[#nodes + 1] = UI.Node(window, row, row.onClick, {
			cursorX = N.LABEL_X - 6, onFocus = UI.RowFocus(row), profileRowId = id,
			tip = { title = profile.name, lines = { row.usage:GetText(), UI.ByMode(L.PROFILE_ROW_TIP_PAD, L.PROFILE_ROW_TIP) }, side = "right" },
		})
	end
	if #profiles == 1 then flow:Add(content.empty, 14, N.ROW_GAP, N.LABEL_X) end
	flow:Finish()
	return nodes
end

UI.AddPage({ key = "profiles", order = 1, bar = true, title = function() return L.TAB_PROFILES end, build = buildList, refresh = refreshList })

-- The editor page.
local DIM = { 0.65, 0.65, 0.65 }

local function dim(text) return { text = text, color = DIM, small = true } end

-- Smart mode's value for a cvar right now, when it runs this profile differently from its own value.
local function nowValue(cvar, value)
	if not (ns.Smart and ns.Smart.Enabled() and ns.Apply.Target) then return end
	local active = ns.Apply.Active() or {}
	if active.profileId ~= profileOf().id then return end
	local ok, target = pcall(ns.Apply.Target)
	local now = ok and type(target) == "table" and target[cvar]
	if now == nil or value == nil or ns.Catalog.Same(cvar, now, value) then return end
	return now
end

local function editTip(entry, own, source, now)
	local lines = {}
	if entry.desc then lines[1] = entry.desc end
	lines[#lines + 1] = UI.ImpactLine(entry)
	if unsupported(entry.cvar) then
		lines[#lines + 1] = dim(L.UNSUPPORTED_TIP)
		return { title = entry.label, lines = lines, side = "above" }
	end
	local value = valueOf(entry.cvar)
	if now ~= nil then lines[#lines + 1] = dim(string.format(L.NOW_TIP, ns.Catalog.Format(entry.cvar, now), ns.Catalog.Format(entry.cvar, value))) end
	lines[#lines + 1] = dim(own and L.OWN_TIP or string.format(L.INHERIT_TIP, L.INHERIT_SOURCE[source] or L.INHERIT_SOURCE[ORIGINAL]))
	local limit = ns.db.limits and ns.db.limits[entry.cvar]
	if limit then lines[#lines + 1] = dim(string.format(L.LIMIT, ns.Catalog.Format(entry.cvar, limit))) end
	lines[#lines + 1] = dim(UI.ControlKind(entry) == "dropdown" and UI.ByMode(L.CHOICE_TIP, L.CHOICE_TIP_MOUSE) or UI.ByMode(L.STEPPER_TIP, L.SLIDER_TIP_MOUSE))
	if entry.heavy then lines[#lines + 1] = dim(L.HEAVY_TIP) end
	if own then lines[#lines + 1] = dim(profileOf().id == "default" and L.CLEAR_DEFAULT_TIP or L.CLEAR_TIP) end
	local actions = { { "PAD1", L.SELECT } }
	if own then actions[2] = { "PAD3", L.CLEAR } end
	return { title = entry.label, lines = lines, actions = actions, mouse = own and { L.RIGHT_CLEAR }, side = "above" }
end

local function buildRow(content, entry)
	local row = UI.SettingRow(content, entry.label)
	row.cvar = entry.cvar
	local function onStep(dir) return step(entry.cvar, dir) end
	if UI.ControlKind(entry) == "dropdown" then
		UI.RowChoice(row, onStep, function() openChoice(row) end)
	else
		UI.RowSlider(row, entry.min, entry.max, entry.step, onStep, function(value) slide(entry.cvar, value) end)
	end
	row.reset = UI.IconButton(row, "common-icon-undo", RESET_SIZE, { title = L.RESET_VALUE, lines = { L.RESET_VALUE_TIP }, side = "left" })
	row.reset:SetPoint("LEFT", row, "LEFT", N.RESET_X, 0)
	row.reset.action = function() clear(entry.cvar) end
	row.impact = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.impact:SetPoint("LEFT", N.IMPACT_X, 0)
	row.impact:SetWidth(N.IMPACT_W)
	row.impact:SetJustifyH("CENTER")
	row.now = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.now:SetTextColor(unpack(NOW_COLOR))
	row.off = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.off:SetPoint("LEFT", row, "CENTER", N.SLIDER_X, 0)
	row.off:SetText(L.UNSUPPORTED)
	return row
end

local function buildEditor(content, win, bar)
	window = win
	content.flow = UI.Flow(content)
	content.back = UI.SmallButton(bar, L.ALL_PROFILES)
	content.back:SetPoint("LEFT", bar, "LEFT", BAR_LEFT, 0)
	content.back.action = function() UI.SelectPage("profiles") end
	content.actions = {}
	local x = BAR_RIGHT
	for i = #ACTIONS, 1, -1 do
		local spec = ACTIONS[i]
		local button = UI.SmallButton(bar, L[spec.label])
		button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
		button:SetMotionScriptsWhileDisabled(true)
		button.action = function() runAction(spec, button) end
		x = x - button:GetWidth() - BAR_GAP
		content.actions[i] = button
	end
	content.legend = UI.Description(content, "GameFontHighlightSmall")
	content.legend:SetWidth(N.ROW_W - N.TITLE_X)
	content.preset = UI.SettingRow(content, L.QUALITY_PRESET)
	local function openPreset()
		UI.OpenChoice(window, content.preset.choice, UI.PresetEntries(), UI.PresetOf(profileOf().id), function(picked) UI.ApplyPreset(window, profileOf().id, picked.id) end)
	end
	UI.RowChoice(content.preset, function(dir) return UI.StepPreset(window, profileOf().id, dir) end, openPreset)
	content.preset.onClick = openPreset
	content.folds, content.rows = {}, {}
	for _, group in ipairs(ns.Catalog.GROUPS) do
		local fold = UI.FoldSection(content, group, L.GROUPS[group], true)
		fold.onToggle = refresh
		content.folds[group] = fold
		content.rows[group] = {}
		for _, entry in ipairs(ns.Catalog.LIST) do
			if entry.group == group then table.insert(content.rows[group], buildRow(content, entry)) end
		end
	end
end

local function drawRow(row, nodes)
	local cvar = row.cvar
	local entry = ns.Catalog.Get(cvar)
	local value, source = valueOf(cvar)
	local own = source == nil
	local off = unsupported(cvar)
	row.label:SetFontObject(off and "GameFontDisable" or "GameFontNormal")
	local number = tonumber(value)
	local text = value ~= nil and ns.Catalog.Format(cvar, value) or "-"
	local font = own and "GameFontHighlight" or "GameFontDisable"
	row.control:SetShown(not off)
	row.off:SetShown(off and true or false)
	if row.choice then
		row.choice:Set(text, number == nil or ns.Catalog.Step(cvar, number, -1) == nil, number == nil or ns.Catalog.Step(cvar, number, 1) == nil)
		row.choice.text:SetFontObject(font)
	else
		row.slider:Set(number or entry.min, text)
		row.slider.value:SetFontObject(font)
	end
	row.reset:SetShown(own and not off)
	local level = UI.ImpactOf(entry)
	row.impact:SetText(level and L.IMPACT[level] or "")
	if level then row.impact:SetTextColor(unpack(off and DIM or UI.ImpactColor(level))) end
	local now = not off and nowValue(cvar, value)
	row.now:SetShown(now ~= nil)
	if now ~= nil then
		row.now:SetText(string.format(L.NOW_VALUE, ns.Catalog.Format(cvar, now)))
		row.now:ClearAllPoints()
		row.now:SetPoint("LEFT", row, "LEFT", N.LABEL_X + math.min(row.label:GetStringWidth(), N.CENTER + N.LABEL_END - N.LABEL_X) + 8, 0)
	end
	if off then
		nodes[#nodes + 1] = UI.Node(window, row, nil, { cursorX = N.LABEL_X - 6, onFocus = UI.RowFocus(row), tip = editTip(entry, own, source), tipRegion = row.tipAnchor })
		return
	end
	local open = row.choice and function() openChoice(row) end or nil
	row.onClick = open
	row.onRightClick = own and function() clear(cvar) end
	nodes[#nodes + 1] = UI.Node(window, row, open, {
		cursorX = N.LABEL_X - 6, noSide = true, onFocus = UI.RowFocus(row), tip = editTip(entry, own, source, now), tipRegion = row.tipAnchor,
		prompts = own and { { "PAD3", L.CLEAR } } or nil,
		onDir = function(dir) return step(cvar, dir) end,
		onKey = function(key)
			if key ~= "PAD3" then return end
			if own then clear(cvar) end
			return true
		end,
	})
end

local function refreshEditor(content, _, sel)
	selected = sel.id
	if not ns.Profiles.Get(selected) then selected = "default" end
	local profile = profileOf()
	local flow = content.flow
	local nodes = { UI.Node(window, content.back, content.back.action, { tip = { title = L.ALL_PROFILES, lines = { L.ALL_PROFILES_TIP }, side = "right" } }) }
	local isLocked = locked()
	for i, spec in ipairs(ACTIONS) do
		local button, off = content.actions[i], spec.locked and isLocked
		button:SetEnabled(not off)
		nodes[#nodes + 1] = UI.Node(window, button, function() runAction(spec, button) end, { tip = { title = L[spec.label], lines = { off and L.DEFAULT_LOCKED or L[spec.tip] }, side = "right" } })
	end
	flow:Start()
	content.legend:SetText(profile.id == "default" and L.LEGEND_DEFAULT or L.LEGEND)
	flow:Add(content.legend, content.legend:GetStringHeight(), N.ROW_GAP, N.TITLE_X)
	local first, last = UI.PresetEnds(profile.id)
	content.preset.choice:Set(UI.PresetName(UI.PresetOf(profile.id)), first, last)
	flow:Add(content.preset, N.ROW_H)
	local presetLines = { string.format(L.PRESET_TIP, profile.name), L.PRESET_TIP_STEP, L.PRESET_TIP_CUSTOM }
	if ns.Smart and ns.Smart.Enabled() then presetLines[#presetLines + 1] = L.PRESET_TIP_SMART end
	nodes[#nodes + 1] = UI.Node(window, content.preset, content.preset.onClick, { cursorX = N.LABEL_X - 6, noSide = true, onFocus = UI.RowFocus(content.preset), tipRegion = content.preset.tipAnchor, tip = { title = L.QUALITY_PRESET, lines = presetLines, side = "above" }, onDir = function(dir) return UI.StepPreset(window, profile.id, dir) end })
	for _, group in ipairs(ns.Catalog.GROUPS) do
		local fold, rows = content.folds[group], content.rows[group]
		local setHere = 0
		for _, row in ipairs(rows) do if profile.values[row.cvar] ~= nil then setHere = setHere + 1 end end
		-- Detail starts folded unless this profile sets something in it; the others start open.
		local key = group .. ":" .. profile.id
		fold.key = key
		if UI.Folded[key] == nil then UI.Folded[key] = group == "hidden" and setHere == 0 end
		fold.IsOpen = function() return not UI.Folded[key] end
		fold.Toggle = function()
			UI.Folded[key] = not UI.Folded[key]
			fold.Paint()
			refresh()
		end
		fold.Paint()
		fold.count:SetText(string.format(L.FOLD_COUNT, #rows, setHere))
		flow:Add(fold, N.SECTION_H, 0)
		nodes[#nodes + 1] = UI.Node(window, fold, function() fold.Toggle() end, { cursorX = 0, foldKey = group, tip = { title = L.GROUPS[group], lines = { L.FOLD_TIP }, side = "right" } })
		if fold.IsOpen() then
			for _, row in ipairs(rows) do
				flow:Add(row, N.ROW_H)
				drawRow(row, nodes)
			end
		end
	end
	flow:Finish()
	return nodes
end

UI.AddPage({
	key = "profile", order = 1.5, bar = true, build = buildEditor, refresh = refreshEditor,
	title = function(sel)
		local profile = sel and ns.Profiles.Get(sel.id or "")
		return profile and profile.name or L.DEFAULT
	end,
	subtitle = function(sel) return usage(sel and sel.id or "default") end,
	-- B goes back to the list, on this profile's row.
	onBack = function()
		local id = selected
		UI.SelectPage("profiles")
		for _, node in ipairs(window.nodes or {}) do if node.profileRowId == id then window:Focus(node) end end
		return true
	end,
})
