-- Forever Smart Graphics notifications: one place near the top of the screen for every change the addon makes (each
-- FSG_CHANGES batch: a profile switch, Smart mode at work, a restore, a change applied after combat), a waiting heavy
-- change (FSG_PENDING), a low-FPS suggestion (FSG_SUGGEST), Smart adjust's progress (FSG_ADJUST) and low FPS in a
-- fight (FSG_COMBAT_LOW). Each notice is a subtitle band, in the manner of Spoken's on-screen quest text (studied, not
-- copied): centred words with a soft shadow, the title gold and the details white, on a dark glow that is densest at
-- the title's top centre and fades to nothing all round, with a thin gold line under the title that fades at its ends;
-- buttons are quiet text under the words. Newest on top, at most three. A countdown shrinks the gold line from both
-- ends. The frame is draggable
-- (db.options.notifyPos), plays no sound, never takes keyboard focus and works in combat (a plain frame, no protected
-- calls). Hovering a notice keeps it and lists its changes. Pads use /fsg applynow.
local _, ns = ...
local UI = ns.UI
local L = UI.L

-- Spoken's subtitle measures scaled down by about a third: the words 264 wide at most, 12 padding, 8 over and 10
-- under, 4 from title to details, 1 between lines, 32 tall at least; in over 0.6 s and out over 0.5 s as Spoken.
local MIN_W, MAX_W, PAD, TOP_PAD, TITLE_GAP, LINE_GAP, BOTTOM_PAD, MIN_H = 150, 264, 12, 8, 4, 1, 10, 32
local FADE_IN, FADE_OUT, GAP, MAX_ITEMS, DEFAULT_Y = 0.6, 0.5, 4, 3, -90
local LINE_H, LINE_Y, LINE_ALPHA, LINE_DIM, SHIMMER_LOW, SHIMMER_EVERY = 1, 2, 0.6, 0.35, 0.35, 1.6
-- The glow (Media/glow.tga, from release/make-glow.py): its peak sits a quarter down, at the title's top centre; it is
-- 1.5 times the words' width and 1.6 times their height, so it fades to nothing past the words in every direction.
local GLOW, GLOW_ALPHA, GLOW_W, GLOW_H, GLOW_PEAK = "Interface\\AddOns\\ForeverSmartGraphics\\Media\\glow", 0.7, 1.5, 1.6, 0.25
local BUTTONS_GAP, BUTTON_H, BUTTON_GAP, CLOSE_W, CLOSE_ALPHA, TAG_COLOR = 3, 14, 10, 10, 0.5, "|cff9e9e9e"
local DONE_SHOWN, ADJUST_LIMIT, COUNTDOWN, NOTICE_SHOWN = 6, 90, 10, 4

local frame
local items = {}
local slots = {}
local Notify = {}
UI.Notify = Notify

-- The saved place is the top-left corner as fractions of the screen (fx, fy from the bottom left), so a UI scale or
-- resolution change keeps it where it was. Anything else (an old absolute x/y included) repairs to the default.
local function position()
	local options = ns.db.options
	local pos = options.notifyPos
	local valid = type(pos) == "table" and tonumber(pos.fx) and tonumber(pos.fy) and pos.fx >= 0 and pos.fx <= 1 and pos.fy >= 0 and pos.fy <= 1
	if pos ~= nil and not valid then options.notifyPos = nil end
	return valid and pos
end

local function place()
	frame:ClearAllPoints()
	local pos = position()
	if pos then return frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.fx * UIParent:GetWidth(), pos.fy * UIParent:GetHeight()) end
	frame:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_Y)
end

local function startDrag() frame:StartMoving() end

local function stopDrag()
	frame:StopMovingOrSizing()
	local left, top = frame:GetLeft(), frame:GetTop()
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	if left and top and width > 0 and height > 0 then ns.db.options.notifyPos = { fx = left / width, fy = top / height } end
	place()
end

local function remove(item)
	for i, other in ipairs(items) do
		if other == item then
			table.remove(items, i)
			break
		end
	end
	Notify.Layout()
end

local function draggable(region)
	region:RegisterForDrag("LeftButton")
	region:SetScript("OnDragStart", startDrag)
	region:SetScript("OnDragStop", stopDrag)
end

local function textButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(BUTTON_H)
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetHighlightFontObject("GameFontHighlightSmall")
	button:SetDisabledFontObject("GameFontDisableSmall")
	draggable(button)
	return button
end

local function slotAt(i)
	local slot = slots[i]
	if slot then return slot end

	slot = CreateFrame("Frame", nil, frame)
	slot:EnableMouse(true)
	draggable(slot)
	-- One dark glow behind the words, densest at the title's top centre. No band, no border, no edge.
	slot.glow = slot:CreateTexture(nil, "BACKGROUND")
	slot.glow:SetTexture(GLOW)
	slot.glow:SetVertexColor(0, 0, 0, GLOW_ALPHA)
	-- Centred words with a soft shadow: the title larger and gold, the details white under it.
	slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slot.sub = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slot.third = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	for _, fs in ipairs({ slot.text, slot.sub, slot.third }) do
		fs:SetJustifyH("CENTER")
		fs:SetWordWrap(false)
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	end
	slot.subIcon = slot:CreateTexture(nil, "ARTWORK")
	slot.subIcon:SetSize(8, 5)
	slot:SetScript("OnEnter", function(self)
		local item = self.item
		if item and item.tip then UI.Tooltip(self, item.tip()) end
	end)
	slot:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
	-- A thin gold line under the title, fading at both ends; a countdown shrinks it from both ends.
	slot.line = {}
	for i, spec in ipairs({ { "RIGHT", 0, LINE_ALPHA }, { "LEFT", LINE_ALPHA, 0 } }) do
		local tex = slot:CreateTexture(nil, "ARTWORK")
		tex:SetColorTexture(1, 1, 1, 1)
		tex:SetGradient("HORIZONTAL", CreateColor(1, 0.82, 0, spec[2]), CreateColor(1, 0.82, 0, spec[3]))
		tex:SetHeight(LINE_H)
		tex:SetPoint(spec[1], slot.text, "BOTTOM", 0, -LINE_Y)
		slot.line[i] = tex
	end
	slot.close = textButton(slot)
	slot.close:SetText("x")
	slot.close:SetWidth(CLOSE_W)
	slot.close:SetHeight(CLOSE_W)
	slot.close:SetPoint("TOPRIGHT", -2, -2)
	slot.close:SetAlpha(CLOSE_ALPHA)
	slot.close:SetScript("OnClick", function()
		local item = slot.item
		if not item then return end
		remove(item)
		if item.onClose then item.onClose() end
	end)
	slot.buttons = {}
	slots[i] = slot
	return slot
end

local function slotButton(slot, j)
	local button = slot.buttons[j]
	if button then return button end

	button = textButton(slot)
	button:SetScript("OnClick", function()
		local spec = slot.item and slot.item.buttons[j]
		if spec then spec[2]() end
	end)
	slot.buttons[j] = button
	return button
end

-- Lays a notice out from the top (Spoken's subtitle spacing: 12 over the title, 8 to the details, 12 under): the
-- title (and a grey goal · pace tag), the details with an up or down mark, a third line, the buttons as quiet text
-- under the words. Re-anchors only when the words or buttons changed: the countdown updates every second, and a button
-- moved between mouse down and up drops the click.
-- A line's full width, not the width it was last cut to.
local function textWidth(fs) return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() end

-- The detail lines and the glow follow their words on every draw (an fps line changes each second), so a short line
-- is never cut short; only the anchors wait for the words or buttons to change.
local function fit(slot, item, widest)
	for _, fs in ipairs({ slot.text, slot.sub, slot.third }) do
		local w = textWidth(fs)
		fs:SetWidth(math.min(MAX_W - 2 * PAD, w + 2))
		widest = math.max(widest, w + (fs == slot.sub and item.subIcon and 12 or 0))
	end
	local width = math.min(MAX_W, math.max(MIN_W, widest + 2 * PAD))
	slot:SetWidth(width)
	local h = slot:GetHeight() * GLOW_H
	slot.glow:SetSize(width * GLOW_W, h)
	slot.glow:ClearAllPoints()
	slot.glow:SetPoint("TOP", slot, "TOP", 0, h * GLOW_PEAK - TOP_PAD)
end

local function drawSlot(slot, item)
	slot.item = item
	slot.text:SetText(item.text)
	slot.sub:SetText(item.sub or "")
	-- A detail too long for the line drops its list (the tooltip has it) rather than end in "...".
	if item.subShort and textWidth(slot.sub) > MAX_W - 2 * PAD then slot.sub:SetText(item.subShort) end
	-- The goal and pace tag, muted, in the detail font at the end of the last detail line.
	local third = item.third
	if item.tag then third = (third and third .. " " or "") .. TAG_COLOR .. (third and "· " or "") .. item.tag .. "|r" end
	slot.third:SetText(third or "")
	slot.subIcon:SetShown(item.subIcon ~= nil and item.sub ~= nil)
	if item.subIcon then slot.subIcon:SetAtlas(item.subIcon) end
	local buttons = item.buttons or {}
	local labels = {}
	for j, spec in ipairs(buttons) do labels[j] = spec[1] end
	local key = table.concat({ slot.text:GetText(), item.sub and "sub" or "", item.subIcon or "", third and "third" or "", table.concat(labels, "|") }, "|")
	if slot.key == key then return fit(slot, item, slot.buttonsWide or 0) end

	slot.key = key
	local y, widest = TOP_PAD, 0
	slot.text:ClearAllPoints()
	slot.text:SetPoint("TOP", 0, -y)
	y = y + slot.text:GetStringHeight()
	for _, fs in ipairs({ item.sub and slot.sub, third and slot.third }) do
		if fs then
			y = y + (fs == slot.sub and TITLE_GAP or LINE_GAP)
			fs:ClearAllPoints()
			fs:SetPoint("TOP", 0, -y)
			y = y + fs:GetStringHeight()
		end
	end
	slot.subIcon:ClearAllPoints()
	slot.subIcon:SetPoint("RIGHT", slot.sub, "LEFT", -3, 0)
	for j = #buttons + 1, #slot.buttons do slot.buttons[j]:Hide() end
	if #buttons > 0 then
		y = y + BUTTONS_GAP
		local row = 0
		for j = 1, #buttons do
			local button = slotButton(slot, j)
			button:SetText(buttons[j][1])
			button:SetWidth((button:GetTextWidth() or 0) + 8)
			row = row + button:GetWidth() + (j > 1 and BUTTON_GAP or 0)
		end
		local x = -row / 2
		for j = 1, #buttons do
			local button = slot.buttons[j]
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", slot, "TOP", x, -y)
			button:Show()
			x = x + button:GetWidth() + BUTTON_GAP
		end
		widest = math.max(widest, row)
		y = y + BUTTON_H
	end
	slot.buttonsWide = widest
	slot:SetHeight(math.max(MIN_H, y + BOTTOM_PAD))
	fit(slot, item, widest)
end

local function lineFraction(line)
	if line.paused then return line.left / line.total end
	return math.max(0, line.endsAt - GetTime()) / line.total
end

-- The gold line: its two halves from the middle out, 0.8 of the title's width, so it shrinks from both ends; while
-- Smart works it breathes.
local function drawLine(slot, item)
	local line = item.line
	local shown = line ~= nil or item.shimmer == true
	for _, half in ipairs(slot.line) do half:SetShown(shown) end
	if not shown then return end

	local half = textWidth(slot.text) * 0.4
	local fraction, alpha = 1, 1
	if item.shimmer then
		fraction = SHIMMER_LOW + (1 - SHIMMER_LOW) * (0.5 + 0.5 * math.sin(GetTime() * 2 * math.pi / SHIMMER_EVERY))
	else
		fraction = math.min(1, lineFraction(line))
		alpha = line.paused and LINE_DIM or 1
	end
	for _, tex in ipairs(slot.line) do
		tex:SetWidth(math.max(0.01, half * fraction))
		tex:SetAlpha(alpha)
	end
end

function Notify.Layout()
	if not frame then return end

	for i = #items + 1, #slots do
		slots[i].item = nil
		slots[i]:Hide()
	end
	if #items == 0 then return frame:Hide() end

	local y, width = 0, 0
	for i, item in ipairs(items) do
		local slot = slotAt(i)
		drawSlot(slot, item)
		drawLine(slot, item)
		if slot.top ~= y then
			slot.top = y
			slot:ClearAllPoints()
			slot:SetPoint("TOP", frame, "TOP", 0, -y)
		end
		slot:Show()
		y, width = y + slot:GetHeight() + GAP, math.max(width, slot:GetWidth())
	end
	frame:SetSize(width, y - GAP)
	if frame:IsShown() then return end

	place()
	frame:Show()
end

-- Spoken's timing: a notice fades in over 0.6 s eased out, and out over its last 0.5 s eased in. Hover keeps one with
-- keepOnHover.
local function onUpdate(self)
	local now = GetTime()
	if Notify.Poll then Notify.Poll(now) end
	for i = #items, 1, -1 do
		local item = items[i]
		if item.hideAt and item.keepOnHover and slots[i] and slots[i]:IsMouseOver() then item.hideAt = math.max(item.hideAt, now + FADE_OUT) end
		if item.hideAt and now >= item.hideAt then remove(item) end
	end
	for i, item in ipairs(items) do
		local slot = slots[i]
		if slot and (item.line or item.shimmer) then drawLine(slot, item) end
		if slot then
			local alpha = 1
			if item.born then
				local t = math.min(1, (now - item.born) / FADE_IN)
				alpha = 1 - (1 - t) * (1 - t)
				if t >= 1 then item.born = nil end
			end
			if item.hideAt then
				local t = math.max(0, math.min(1, (item.hideAt - now) / FADE_OUT))
				alpha = alpha * t * t
			end
			slot:SetAlpha(alpha)
		end
	end
end

local function build()
	frame = CreateFrame("Frame", "ForeverSmartGraphicsToast", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetScript("OnUpdate", onUpdate)
	frame:Hide()
end

local function find(kind)
	for _, item in ipairs(items) do if item.kind == kind then return item end end
end

-- spec = { text, sub, buttons = { { label, fn } }, line = { endsAt, total, paused, left }, hideAt, onClose }. A kind
-- already shown is updated where it is; a new one goes on top, and the oldest past three goes.
function Notify.Show(kind, spec)
	if not frame then build() end
	local item = find(kind)
	if not item then
		item = { kind = kind, born = GetTime() }
		table.insert(items, 1, item)
		while #items > MAX_ITEMS do table.remove(items) end
	end
	for _, field in ipairs({ "text", "sub", "subShort", "buttons", "line", "hideAt", "onClose", "icon", "tag", "subIcon", "third", "shimmer", "tip", "keepOnHover" }) do item[field] = spec[field] end
	Notify.Layout()
	return item
end

function Notify.Hide(kind)
	local item = find(kind)
	if item then remove(item) end
end

function Notify.Frame() return frame end

function Notify.Items() return items end

-- A waiting heavy change: its settings by name, the countdown as the line; combat stops and dims it. A close hides
-- this change only (it still applies on time); a newer change shows again.
local dismissed, total, lastSignature

local function signature(values)
	local parts = {}
	for cvar, value in pairs(values or {}) do parts[#parts + 1] = cvar .. "=" .. tostring(value) end
	table.sort(parts)
	return table.concat(parts, ";")
end

local function changeNames(values)
	local list = {}
	for cvar, value in pairs(values or {}) do
		local entry = ns.Catalog.Get(cvar)
		list[#list + 1] = string.format(L.NOTIFY_SETTING, entry and entry.label or cvar, ns.Catalog.Format(cvar, value))
	end
	table.sort(list)
	return table.concat(list, ", ")
end

local function inCombat() return (ns.InCombat or InCombatLockdown)() end

function UI.AnnounceOn() return ns.db.options.announce == true end

local function pending(info)
	if not (info and UI.AnnounceOn()) then
		dismissed, lastSignature = nil, nil
		return Notify.Hide("pending")
	end

	local sig = signature(info.values)
	if dismissed == sig then return end
	if sig ~= lastSignature then lastSignature, total = sig, math.max(info.seconds or COUNTDOWN, 1) end
	local paused = info.waitingCombat and inCombat() or false
	local seconds = info.seconds or 0
	local text = changeNames(info.values)
	if paused then text = text .. L.NOTIFY_WAITS end
	Notify.Show("pending", {
		text = text,
		buttons = { { L.APPLY_NOW, function()
			Notify.Hide("pending")
			ns.Apply.ApplyPending("user", { user = true })
		end } },
		line = { endsAt = GetTime() + seconds, total = total, paused = paused, left = seconds },
		onClose = function() dismissed = sig end,
	})
end

ns.On("FSG_PENDING", pending)

-- A place that lags: Change opens the window on it; Smart adjust searches settings for it; x = not again for a while.
function UI.SuggestOn() return ns.db.options.suggest == true end

-- The place's override key (zone or map), not its area key: SetOverride takes only override keys.
local function changePlace(s)
	if InCombatLockdown() then return ns.log(L.COMBAT) end

	Notify.Hide("suggest")
	local key = s.overrideKey
	if key and not ns.db.overrides[key] then
		local active = ns.Apply.Active() or {}
		ns.Profiles.SetOverride(key, s.name or key, active.profileId or "default")
	end
	UI.OpenPanel("locations")
	if key and UI.LocationsTab then UI.LocationsTab.Focus(key) end
end

-- AdjustPlace refuses with false, reason ("not here", "busy", "smart mode is on"): the suggestion stays and a short
-- notice says why.
local function smartAdjust(s)
	local ok, reason = ns.Smart.AdjustPlace(s.key)
	if ok == false then return Notify.Show("notice", { text = string.format(L.ADJUST_REFUSED, tostring(reason or "")), hideAt = GetTime() + NOTICE_SHOWN }) end
	Notify.Hide("suggest")
end

local function suggest(s)
	if not (s and ns.Smart and UI.SuggestOn()) then return Notify.Hide("suggest") end

	local smart = ns.Smart
	Notify.Show("suggest", {
		text = string.format(L.NOTIFY_LOW_FPS, s.name or s.key, math.floor((s.avg or 0) + 0.5), math.floor((s.goal or 0) + 0.5)),
		buttons = {
			{ L.CHANGE_BUTTON, function() changePlace(s) end },
			{ L.SMART_ADJUST, function() smartAdjust(s) end },
		},
		onClose = function() smart.DismissSuggestion(s.key) end,
	})
end

ns.On("FSG_SUGGEST", suggest)

-- A batch's changes for tooltips and detail lines; Smart adjust's changes so far.
local SHOWN_CHANGES = 3
local adjustChanges = {}

local function changeLines(changes)
	local lines = {}
	for i, change in ipairs(changes) do lines[i] = UI.ChangeText(change) end
	return lines
end

local function runTip(title, changes) return function() return { title = title, lines = changeLines(changes), side = "right" } end end

local function rising(change) return (tonumber(change.to) or 0) >= (tonumber(change.from) or 0) end

-- "6 settings changed", for a line too narrow for the list.
local function countLine(changes) return string.format(#changes == 1 and L.CHANGED_COUNT_ONE or L.CHANGED_COUNT, #changes) end

-- "6 settings changed: Shadow quality High to Good, ... +3"
local function detailLine(changes)
	local parts = {}
	for i = 1, math.min(SHOWN_CHANGES, #changes) do parts[i] = UI.ChangeText(changes[i]) end
	local text = string.format(#changes == 1 and L.CHANGED_ONE or L.CHANGED_MANY, #changes, table.concat(parts, ", "))
	if #changes > SHOWN_CHANGES then text = text .. string.format(L.CHANGED_MORE, #changes - SHOWN_CHANGES) end
	return text
end

-- Smart adjust: the place, its latest change (changes newest first, as Find my best settings lists them), the 90 s
-- limit as the line, Cancel; when done, what it saved, for 6 s.
local function adjust(state)
	if not (state and UI.SmartNoticeOn()) then return Notify.Hide("adjust") end

	local name = state.name or state.key or ""
	if state.done then
		local changes = adjustChanges
		adjustChanges = {}
		return Notify.Show("adjust", { text = string.format(L.ADJUST_DONE, name), sub = #changes > 0 and detailLine(changes) or nil, subShort = countLine(changes), hideAt = GetTime() + DONE_SHOWN, keepOnHover = true, tip = runTip(string.format(L.ADJUST_DONE, name), changes) })
	end
	if not state.running then
		adjustChanges = {}
		return Notify.Hide("adjust")
	end

	local left = math.max(0, ADJUST_LIMIT - (state.seconds or 0))
	local latest = adjustChanges[#adjustChanges] or (state.changes or {})[1]
	Notify.Show("adjust", {
		text = string.format(L.ADJUSTING, name),
		sub = UI.ChangeText(latest) or L.NO_CHANGES,
		tip = runTip(string.format(L.ADJUSTING, name), adjustChanges),
		buttons = { { L.CANCEL, function() ns.Smart.CancelAdjust() end } },
		line = { endsAt = GetTime() + left, total = ADJUST_LIMIT, left = left, paused = state.paused },
	})
end

ns.On("FSG_ADJUST", adjust)

-- Every change the addon makes, from FSG_CHANGES({ reason, source, changes = { { cvar, label, from, to } } }), one
-- batch per flush: a profile switch ("Now using <profile> · <location>", 5 s), Smart mode at work (one notice updated
-- in place for every batch, then a summary once no batch came for 4 s, 6 s), Smart adjust (its own notice), a restore,
-- a change applied by Apply now or after combat. A profile switch that changes nothing still says "Now using" for
-- 2.5 s. Smart's notice never shows with the settings window open or in combat. Every kind is off unless its option
-- is true: smartNotice (Smart at work, its adjust, after combat, low FPS in a fight), notifyProfile (a switch, a
-- restore), announce (a heavy change waiting, then applied), suggest. The up and down marks are the minimal scroll bar's arrows
-- (Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml); the icon is the addon's logo.
local UP, DOWN = "minimal-scrollbar-arrow-top", "minimal-scrollbar-arrow-bottom"
local SETTLE_AFTER, SUMMARY_FOR, PROFILE_FOR, BRIEF_FOR, OTHER_FOR, POLL_EVERY = 4, 6, 5, 2.5, 5, 0.25

local run, polled, lastProfile

function UI.SmartNoticeOn() return ns.db.options.smartNotice == true end

function UI.ProfileNoticeOn() return ns.db.options.notifyProfile == true end

local function busy() return UI.Current() ~= nil or inCombat() end

local function fpsLine()
	local state = ns.Smart and ns.Smart.State() or {}
	local fps = state.fps and tostring(math.floor(state.fps + 0.5)) or "--"
	return string.format(L.ACTIVITY_FPS, fps, math.floor((state.goal or state.target or ns.db.smart.target or 0) + 0.5))
end

local function drawRun()
	local changes = run.changes
	local latest = changes[#changes]
	local style = UI.SmartStyle()
	local more = #changes > 1 and string.format(L.ACTIVITY_MORE, #changes - 1) or ""
	Notify.Show("smart", {
		text = rising(latest) and L.ACTIVITY_RAISE or L.ACTIVITY_LOWER,
		tag = style ~= "" and style or nil,
		subIcon = rising(latest) and UP or DOWN,
		sub = UI.ChangeText(latest) .. more,
		third = fpsLine(),
		shimmer = true,
		tip = runTip(L.ACTIVITY_TIP, changes),
	})
end

-- A run's net effect: each setting once, from its first value to its last; a setting that came back where it started
-- (80% to 75% to 80%) is no change at all.
local function netChanges(changes)
	local byCvar, order = {}, {}
	for _, change in ipairs(changes) do
		local net = byCvar[change.cvar]
		if not net then
			net = { cvar = change.cvar, label = change.label, from = change.from }
			byCvar[change.cvar] = net
			order[#order + 1] = net
		end
		net.to = change.to
	end
	local out = {}
	for _, net in ipairs(order) do
		if not ns.Catalog.Same(net.cvar, net.from, net.to) then out[#out + 1] = net end
	end
	return out
end

UI.NetChanges = netChanges

local function summarize()
	local changes = netChanges(run.changes)
	if #changes == 0 then
		run = nil
		return Notify.Hide("smart")
	end
	local down = 0
	for _, change in ipairs(changes) do if not rising(change) then down = down + 1 end end
	local title = down * 2 > #changes and L.ACTIVITY_EASED or L.ACTIVITY_DONE
	run = nil
	if busy() then return Notify.Hide("smart") end
	Notify.Show("smart", { text = title, sub = detailLine(changes), subShort = countLine(changes), hideAt = GetTime() + SUMMARY_FOR, keepOnHover = true, tip = runTip(title, changes) })
end

-- A Smart batch: added to the run, the notice updated in place. The title follows the newest change, as its arrow does.
local function smartBatch(changes)
	if not UI.SmartNoticeOn() or busy() then
		run = nil
		return Notify.Hide("smart")
	end
	run = run or { changes = {} }
	run.last = GetTime()
	for _, change in ipairs(changes) do table.insert(run.changes, change) end
	drawRun()
end

-- While a run is on screen: its fps line follows, and 4 s without a new batch turns it into the summary.
function Notify.Poll(now)
	if not run or (polled and now - polled < POLL_EVERY) then return end
	polled = now
	if busy() then
		run = nil
		return Notify.Hide("smart")
	end
	if now - run.last >= SETTLE_AFTER then return summarize() end
	drawRun()
end

local function activeLine()
	local active = ns.Apply.Active() or {}
	local loc = active.loc or {}
	return string.format(L.NOW_USING, active.profileName or L.DEFAULT, ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE), active.profileId
end

local function profileBatch(changes)
	local title, id = activeLine()
	lastProfile = id
	if not UI.ProfileNoticeOn() then return end
	Notify.Show("profile", { text = title, sub = detailLine(changes), subShort = countLine(changes), hideAt = GetTime() + PROFILE_FOR, keepOnHover = true, tip = runTip(title, changes) })
end

local function otherBatch(kind, title, changes)
	Notify.Show(kind, { text = title, sub = detailLine(changes), subShort = countLine(changes), hideAt = GetTime() + OTHER_FOR, keepOnHover = true, tip = runTip(title, changes) })
end

local BATCH = {
	smart = smartBatch,
	profile = profileBatch,
	restore = function(changes) if UI.ProfileNoticeOn() then otherBatch("done", L.RESTORED, changes) end end,
	apply = function(changes) if UI.AnnounceOn() then otherBatch("done", L.APPLIED_TEXTURE, changes) end end,
	adjust = function(changes)
		for _, change in ipairs(changes) do table.insert(adjustChanges, change) end
		if ns.Smart and ns.Smart.AdjustState then adjust(ns.Smart.AdjustState()) end
	end,
}

-- FSG_CHANGES(batch); an older form FSG_CHANGES(changes, source) is read too. Changes written after combat arrive
-- with the reason "after combat".
ns.On("FSG_CHANGES", function(a, b)
	local changes, source, reason = a, b, nil
	if type(a) == "table" and (a.source or a.reason) then changes, source, reason = a.changes or {}, a.source, a.reason end
	if type(changes) ~= "table" or #changes == 0 then return end
	if reason == "after combat" or source == "after combat" then
		if UI.SmartNoticeOn() then otherBatch("done", string.format(L.AFTER_COMBAT_DONE, #changes), changes) end
		return
	end
	local handler = BATCH[source]
	if handler then handler(changes) end
end)

-- A profile switch that changed no setting: "Now using" for 2.5 s (a batch that follows replaces it in place).
local function checkProfile()
	local title, id = activeLine()
	if id == lastProfile then return end
	lastProfile = id
	if not UI.ProfileNoticeOn() or not lastProfile then return end
	Notify.Show("profile", { text = title, hideAt = GetTime() + BRIEF_FOR, keepOnHover = true })
end

ns.On("FSG_READY", function() lastProfile = select(2, activeLine()) end)
ns.On("FSG_LOCATION", function() C_Timer.After(0, checkProfile) end)
ns.On("FSG_PROFILES_CHANGED", function() C_Timer.After(0, checkProfile) end)

-- Low FPS in a fight: nothing changes in combat on its own; the notice offers to lower now or after the fight.
local function cutNames(cuts)
	local names = {}
	for _, cut in ipairs(cuts or {}) do
		local cvar = type(cut) == "table" and cut.cvar or cut
		local entry = ns.Catalog.Get(cvar)
		names[#names + 1] = entry and entry.label or tostring(cvar)
	end
	return table.concat(names, ", ")
end

ns.On("FSG_COMBAT_LOW", function(info)
	if not (info and ns.Smart and UI.SmartNoticeOn()) then return end
	Notify.Hide("smart")
	Notify.Show("combat", {
		text = string.format(L.COMBAT_LOW, math.floor((info.fps or 0) + 0.5), math.floor((info.goal or 0) + 0.5)),
		sub = cutNames(info.cuts),
		buttons = {
			{ L.LOWER_NOW, function()
				Notify.Hide("combat")
				ns.Smart.ApplyCombatCuts()
			end },
			{ L.AFTER_COMBAT, function()
				Notify.Hide("combat")
				ns.Smart.DeferCombatCuts()
			end },
		},
	})
end)

ns.On("FSG_COMBAT_START", function() Notify.Hide("smart") end)
ns.On("FSG_COMBAT_END", function() Notify.Hide("combat") end)

UI.Toast = { Frame = function() return frame end }
