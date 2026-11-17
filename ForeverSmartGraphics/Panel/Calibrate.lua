-- Forever Smart Graphics calibration overlay ("Find my best settings"): while ns.Calibrate runs, a small frame below
-- the minimap shows the target, the hint, a checklist of scenes, the last settings it changed and the current fps,
-- with Finish and Stop. Dialog art as in Forever Controller Tweaks' dialog (MIT, same author). A plain frame: it stays
-- up in combat (no protected calls), takes mouse clicks and drags only and never keyboard focus; pads use /fsg finish
-- and /fsg stop. The drag position is saved in db.options.calibratePos. Driven by FSG_CALIBRATE(state).
local _, ns = ...
local UI = ns.UI
local L = UI.L

local WIDTH, PAD, ROW_H, MAX_SCENES, MAX_CHANGES, CHANGE_H = 280, 16, 18, 8, 6, 14
local DEFAULT_X, DEFAULT_Y = -20, -230
local FPS_EVERY = 1

local frame
local Calibrate = {}
UI.Calibrate = Calibrate

local function place()
	frame:ClearAllPoints()
	local pos = ns.db.options.calibratePos
	if type(pos) == "table" and pos.x and pos.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", DEFAULT_X, DEFAULT_Y)
	end
end

local function savePosition(self)
	self:StopMovingOrSizing()
	local left, top = self:GetLeft(), self:GetTop()
	if left and top then ns.db.options.calibratePos = { point = "TOPLEFT", x = left, y = top } end
	place()
end

local function sceneRow(i)
	local row = frame.rows[i]
	if row then return row end

	row = CreateFrame("Frame", nil, frame)
	row:SetSize(WIDTH - 2 * PAD, ROW_H)
	row.tick = row:CreateTexture(nil, "ARTWORK")
	row.tick:SetAtlas("common-icon-checkmark")
	row.tick:SetSize(14, 14)
	row.tick:SetPoint("LEFT")
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.label:SetPoint("LEFT", 20, 0)
	row.label:SetJustifyH("LEFT")
	row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.status:SetPoint("RIGHT")
	frame.rows[i] = row
	return row
end

local function updateFps()
	frame.fps:SetText(string.format(L.CAL_FPS, math.floor((tonumber(ns.plain(GetFramerate())) or 0) + 0.5)))
end

local function build()
	frame = CreateFrame("Frame", "ForeverSmartGraphicsCalibrate", UIParent)
	frame:SetSize(WIDTH, 200)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", savePosition)
	frame:Hide()
	UI.DialogArt(frame)
	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", PAD, -PAD)
	frame.title:SetWidth(WIDTH - 2 * PAD - 20)
	frame.title:SetJustifyH("LEFT")
	frame.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.hint:SetWidth(WIDTH - 2 * PAD)
	frame.hint:SetJustifyH("LEFT")
	frame.fps = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.fps:SetJustifyH("LEFT")
	frame.finish = UI.DialogButton(frame)
	frame.finish:SetSize(110, 21)
	frame.finish:SetText(L.FINISH)
	frame.finish:SetScript("OnClick", function() UI.FinishCalibration() end)
	frame.stop = UI.DialogButton(frame)
	frame.stop:SetSize(110, 21)
	frame.stop:SetText(L.STOP)
	frame.stop:SetScript("OnClick", function()
		ns.Calibrate.Stop()
		Calibrate.Update(ns.Calibrate.State())
	end)
	frame.pad = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	frame.pad:SetText(L.CAL_PAD)
	frame.changesTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.changesTitle:SetText(L.CHANGES)
	frame.changes = {}
	frame.rows = {}
	frame.elapsed = 0
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < FPS_EVERY then return end
		self.elapsed = 0
		updateFps()
	end)
end

local function sceneStatus(scene, current)
	if scene.done then return "" end
	if not (current and current.locKey == scene.locKey) then return "" end
	if current.status == "holding" then return L.CAL_HOLDING end
	return string.format(L.CAL_SEARCHING, math.floor((current.seconds or 0) + 0.5))
end

-- Re-anchors a region only when its place changed: the overlay updates every second, and a button moved between
-- mouse down and up drops the click.
local function moveTo(region, point, x, y)
	local at = point .. x .. ":" .. y
	if region.at == at then return end
	region.at = at
	region:ClearAllPoints()
	region:SetPoint(point, x, -y)
end

local function line(list, i, font)
	local fs = list[i] or frame:CreateFontString(nil, "ARTWORK", font)
	fs:SetWidth(WIDTH - 2 * PAD)
	fs:SetJustifyH("LEFT")
	list[i] = fs
	return fs
end

-- Lays the frame out from the top: title, hint, scenes, the changes it made, fps, buttons, the pad line (pad look
-- only). It is placed when it shows, never while shown, so a drag is never pulled back.
function Calibrate.Update(state)
	if not (state and state.running) then
		if frame then frame:Hide() end
		return
	end

	if not frame then build() end
	if not frame:IsShown() then place() end
	frame.title:SetText(string.format(L.CAL_TITLE, state.target or ns.db.smart.target))
	frame.hint:SetText(state.hint or "")
	local y = PAD + frame.title:GetStringHeight() + 6
	moveTo(frame.hint, "TOPLEFT", PAD, y)
	y = y + (state.hint and frame.hint:GetStringHeight() + 8 or 0)
	local scenes = state.scenes or {}
	local shown = math.min(#scenes, MAX_SCENES)
	for i = shown + 1, #frame.rows do frame.rows[i]:Hide() end
	for i = 1, shown do
		local scene, row = scenes[i], sceneRow(i)
		row.tick:SetShown(scene.done)
		row.label:SetText(scene.label or scene.locKey)
		row.label:SetFontObject(scene.done and "GameFontDisableSmall" or "GameFontNormalSmall")
		row.status:SetText(sceneStatus(scene, state.current))
		moveTo(row, "TOPLEFT", PAD, y)
		row:Show()
		y = y + ROW_H
	end

	y = y + 6
	moveTo(frame.changesTitle, "TOPLEFT", PAD, y)
	y = y + 16
	local changes = state.changes or {}
	local count = math.min(#changes, MAX_CHANGES)
	for i = count + 1, #frame.changes do frame.changes[i]:Hide() end
	for i = 1, math.max(count, 1) do
		local fs = line(frame.changes, i, "GameFontHighlightSmall")
		fs:SetText(UI.ChangeText(changes[i]) or L.NO_CHANGES)
		fs:SetFontObject(count == 0 and "GameFontDisableSmall" or "GameFontHighlightSmall")
		moveTo(fs, "TOPLEFT", PAD, y)
		fs:Show()
		y = y + CHANGE_H
	end

	moveTo(frame.fps, "TOPLEFT", PAD, y + 6)
	updateFps()
	y = y + 6 + 20
	moveTo(frame.finish, "TOPLEFT", PAD, y)
	moveTo(frame.stop, "TOPRIGHT", -PAD, y)
	frame.finish:SetEnabled(UI.CanFinishCalibration and UI.CanFinishCalibration(state) or false)
	y = y + 21 + 6
	frame.pad:SetShown(UI.Pad())
	if UI.Pad() then
		moveTo(frame.pad, "TOPLEFT", PAD, y)
		y = y + 14
	end
	frame:SetHeight(y + PAD)
	frame:Show()
end

function Calibrate.Frame() return frame end

-- Finish saves the profile; a short message says so (out of combat; in combat the chat line says it).
function UI.FinishCalibration()
	local id = ns.Calibrate.Finish()
	Calibrate.Update(ns.Calibrate.State())
	local profile = id and ns.Profiles.Get(id)
	if not profile then return end
	local text = string.format(L.CAL_SAVED, profile.name)
	if InCombatLockdown() then return ns.log(text) end
	UI.ShowMessage(text, { { L.OK } })
end

ns.On("FSG_CALIBRATE", function(state) Calibrate.Update(state) end)
ns.On("FSG_READY", function() if ns.Calibrate then Calibrate.Update(ns.Calibrate.State()) end end)
ns.On("FSG_INPUT", function() if ns.Calibrate and frame and frame:IsShown() then Calibrate.Update(ns.Calibrate.State()) end end)
