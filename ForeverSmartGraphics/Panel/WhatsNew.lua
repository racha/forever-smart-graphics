-- Forever Smart Graphics: the "What's new" window. After an update it opens once on its own and lists the notes since
-- the version the player last saw (ns.News.Pending); /fsg whatsnew opens it with this version's notes
-- (ns.News.Current). Only the close action (B, Escape, the X) stores anything, through ns.News.Close; a hide without a
-- close (combat, UIParent hidden, another window) stores nothing and the window opens once more, unticked.
local _, ns = ...
local UI = ns.UI
local L = UI.L

local W, H = 560, 520
local PORTRAIT = "Interface\\AddOns\\ForeverSmartGraphics\\Media\\portrait"
local BODY_ALPHA = 0.75
local VERSION_X, VERSION_Y = 62, -31
local ROW_W, ROW_H, ROW_X, ROW_Y = 176, 29, -24, -24
local DIVIDER_Y, NOTES_X, NOTES_Y, VIEW_W, VIEW_H, COLUMN_W = -60, 24, -68, 512, 436, 490
local HEADER_W, HEADER_H = 201, 32
local LINE = 14.4
local STEP = 3 * LINE
local STICK_SPEED = 500
local FIRST_CHECK, CHECK_EVERY, REOPEN_AFTER = 3, 2, 2

local window, box, notesNode, boxNode, onClosed
local offset, contentH, stickY = 0, 0, 0

local function overflows() return contentH > VIEW_H end

local function setOffset(value)
	offset = math.max(0, math.min(value, math.max(0, contentH - VIEW_H)))
	window.scroll:SetVerticalScroll(offset)
	window.bar:Set(offset / LINE, VIEW_H / LINE, contentH / LINE)
end

local function setTicked(on)
	window.ticked = on
	box:Set(on)
end

-- The close action, the only place anything is stored.
local function close()
	window.closed = true
	ns.News.Close(window.ticked == true)
	UI.CloseAll()
	window.closed = nil
end

-- Notes: one pass over the blocks, FontStrings and headers from pools, each under the previous one.
local function poolText(i)
	local pool = window.texts
	local fs = pool[i] or window.child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pool[i] = fs
	fs:SetJustifyH("LEFT")
	fs:SetSpacing(2)
	fs:Show()
	return fs
end

local function poolHeader(i)
	local pool = window.headers
	local header = pool[i]
	if not header then
		header = UI.SectionHeader(window.child, 0, 0, HEADER_W, "")
		header:SetSize(HEADER_W, HEADER_H)
		header.text:ClearAllPoints()
		header.text:SetPoint("TOP", 0, -8)
		pool[i] = header
	end
	header:Show()
	return header
end

local function fill(content)
	local child = window.child
	local texts, headers, y = 0, 0, 0
	local function put(font, x, width, gap, text)
		texts = texts + 1
		local fs = poolText(texts)
		fs:SetFontObject(font)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", child, "TOPLEFT", x, -(y + gap))
		fs:SetWidth(width)
		fs:SetText(text)
		return fs
	end
	local function block(font, x, width, gap, text)
		local fs = put(font, x, width, gap, text)
		y = y + gap + fs:GetStringHeight()
		return fs
	end

	local entries = content.entries or {}
	for i, entry in ipairs(entries) do
		y = y + (i == 1 and 4 or 18)
		headers = headers + 1
		local header = poolHeader(headers)
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", child, "TOPLEFT", (COLUMN_W - HEADER_W) / 2, -y)
		header.text:SetText(entry.date and string.format(L.NEWS_HEADER, entry.version, entry.date) or entry.version)
		y = y + HEADER_H + 6
		for _, b in ipairs(entry.blocks or {}) do
			local kind, text, depth = b[1], b[2] or "", b[3]
			if kind == "h" then
				block("GameFontNormal", 4, COLUMN_W - 4, 9, text)
				y = y + 3
			elseif kind == "b" then
				local inset = depth == 2 and 16 or 0
				put("GameFontHighlight", 8 + inset, 10, 3, L.NEWS_BULLET)
				block("GameFontHighlight", 18 + inset, COLUMN_W - 18 - inset, 3, text)
			else
				block("GameFontHighlight", 4, COLUMN_W - 4, 2, text)
			end
		end
	end
	if #entries == 0 then block("GameFontHighlight", 4, COLUMN_W - 4, 4, L.NEWS_EMPTY) end
	local website = content.older and ns.News.Website and ns.News.Website()
	if website then block("GameFontDisable", 4, COLUMN_W - 4, 14, string.format(L.NEWS_OLDER, website)) end

	for i = texts + 1, #window.texts do window.texts[i]:Hide() end
	for i = headers + 1, #window.headers do window.headers[i]:Hide() end
	contentH = y + 8
	child:SetHeight(contentH)
	setOffset(0)
end

-- The version line takes the room left of the checkbox row; a line that would be cut falls back to the version alone.
local function setVersion(text, short)
	local line = window.version
	line:SetText(text)
	if short and UI.TextWidth(line) > line:GetWidth() then line:SetText(short) end
end

-- The footer and the hint glyph follow the focus: Select and A only while the box has it.
local function paint(self)
	local onBox = self.focus == boxNode
	local prompts = {}
	if onBox then prompts[#prompts + 1] = { "PAD1", L.SELECT } end
	if overflows() then prompts[#prompts + 1] = { "GAMEPAD_STICK_RIGHT_VERTICAL", L.NEWS_SCROLL } end
	prompts[#prompts + 1] = { "PAD2", L.CLOSE }
	self:SetPrompts(prompts)
	self.hint:SetShown(UI.Pad())
	self.hint:SetCode(onBox and "PAD1" or "PADDUP")
end

local function onRefresh(self)
	self:SetNodes({ notesNode, boxNode })
	paint(self)
end

local function build()
	if window then return window end

	window = UI.NewWindow(W, H)
	UI.AddPortrait(window, PORTRAIT)
	window.glow = UI.Glow(window, window.NineSlice, "gamepad-uiframemetal-largeportrait-focus", -20, 24, 14, -14)
	-- Frame alpha applies to each region separately: an opaque underlay under a 0.75 body would still hide the world.
	window.underlay:Hide()
	window.Bg:SetAlpha(BODY_ALPHA)
	window:SetTitle(L.NEWS_TITLE)
	window.ClosePanelButton:SetScript("OnClick", close)
	window.texts, window.headers = {}, {}

	local row = CreateFrame("Button", nil, window)
	row:SetSize(ROW_W, ROW_H)
	row:SetPoint("TOPRIGHT", window, "TOPRIGHT", ROW_X, ROW_Y)
	row:SetScript("OnClick", function() setTicked(not window.ticked) end)
	box = UI.Checkbox(row, function() setTicked(not window.ticked) end)
	box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("RIGHT", box, "LEFT", -6, 0)
	label:SetText(L.NEWS_NEVER)
	window.hint = UI.Glyph(row, 20, "PADDUP")
	window.hint:SetPoint("RIGHT", label, "LEFT", -4, 0)
	window.row, window.label = row, label

	window.version = UI.Text(window, "GameFontHighlight", VERSION_X, -VERSION_Y, "", W - VERSION_X - ROW_W + ROW_X - 8)
	window.version:SetWordWrap(false)

	local divider = window:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider")
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", window, "TOPLEFT", NOTES_X, DIVIDER_Y)
	divider:SetPoint("TOPRIGHT", window, "TOPRIGHT", -NOTES_X, DIVIDER_Y)
	window.divider = divider

	local scroll = CreateFrame("ScrollFrame", nil, window)
	scroll:SetPoint("TOPLEFT", window, "TOPLEFT", NOTES_X, NOTES_Y)
	scroll:SetSize(VIEW_W, VIEW_H)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(COLUMN_W, 1)
	scroll:SetScrollChild(child)
	local function wheel(_, delta) setOffset(offset - delta * STEP) end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", wheel)
	window.scroll, window.child = scroll, child
	window.bar = UI.ScrollBar(window, VIEW_H, function(top) setOffset(top * LINE) end)
	window.bar:SetPoint("TOPLEFT", window, "TOPLEFT", W - 32, NOTES_Y)
	window.bar:SetScript("OnMouseWheel", wheel)

	local anchor = CreateFrame("Frame", nil, window)
	anchor:SetSize(1, HEADER_H)
	anchor:SetPoint("TOPLEFT", window, "TOPLEFT", NOTES_X, NOTES_Y)
	-- Up at the top of the notes reaches the box; Down from the box comes back. Left and right do nothing.
	notesNode = UI.Node(window, anchor, nil, { noSide = true, onFocus = function() end, onMove = function(_, dy)
		if dy > 0 and offset <= 0 then window:Focus(boxNode)
		elseif dy ~= 0 then setOffset(offset - dy * STEP) end
		return true
	end })
	boxNode = UI.Node(window, row, function() setTicked(not window.ticked) end, { noSide = true, tip = { title = L.NEWS_NEVER, lines = { L.NEWS_NEVER_TIP }, side = "below" }, onMove = function(_, dy)
		if dy < 0 then window:Focus(notesNode) end
		return true
	end })

	window.OnRefresh = onRefresh
	window.OnFocusChanged = paint
	window.OnClosed = onClosed
	window.OnBack = close
	window.OnKey = function(_, key)
		if key ~= "PADFORWARD" and key ~= "PADSOCIAL" then return end
		close()
		return true
	end
	window:SetScript("OnGamePadStick", function(_, stick, _, y) if stick == "Right" then stickY = y or 0 end end)
	window:HookScript("OnUpdate", function(_, elapsed)
		if stickY == 0 then return end
		local ok, speed = pcall(GetCVarNumberOrDefault, "SmartNavigationScrollSpeed")
		setOffset(offset - stickY * (ok and tonumber(speed) or STICK_SPEED) * elapsed)
	end)
	return window
end

-- Automatic opening: one ticker, armed at the first PLAYER_ENTERING_WORLD of the session.
-- ponytail: polling instead of one event per gate; six cheap checks every 2 s, only until it shows. Upgrade path:
-- events, if a gate ever becomes costly.
local loading, entered, ticker, scheduled, autoLeft, reopened = false, false, nil, false, 1, false

local function padFree()
	if not IsOnlyCoreBindingSetActive then return true end
	local ok, only = pcall(IsOnlyCoreBindingSetActive)
	return not ok or ns.plain(only) ~= false
end

local function gatesOpen()
	if loading or ns.InCombat() or UI.Current() then return false end
	local cal = ns.Calibrate and ns.Calibrate.State()
	if cal and cal.running then return false end
	return padFree()
end

local function open(content, versionText, short, auto)
	build()
	window.auto = auto
	setTicked(false)
	fill(content)
	setVersion(versionText, short)
	stickY = 0
	UI.Show(window)
	if UI.Current() == window then window:EnableGamePadStick(true) end
end

local function showPending(pending)
	local running = ns.News.Running() or ""
	local short = string.format(L.NEWS_VERSION, running)
	autoLeft = autoLeft - 1
	open(pending, pending.from and string.format(L.NEWS_UPDATED, running, pending.from) or short, short, true)
end

-- true while it should keep waiting.
local function check()
	local pending = autoLeft > 0 and ns.News and ns.News.Pending()
	if pending and not gatesOpen() then return true end
	if ticker then ticker:Cancel() end
	ticker = nil
	if pending then showPending(pending) end
end

local function arm(delay)
	if scheduled or ticker then return end
	scheduled = true
	C_Timer.After(delay, function()
		scheduled = false
		if check() then ticker = C_Timer.NewTicker(CHECK_EVERY, check) end
	end)
end

function onClosed(self)
	stickY = 0
	self:EnableGamePadStick(false)
	if self.closed or not self.auto or reopened then return end
	reopened = true
	autoLeft = 1
	arm(REOPEN_AFTER)
end

ns.On("LOADING_SCREEN_ENABLED", function() loading = true end)
ns.On("LOADING_SCREEN_DISABLED", function() loading = false end)
ns.On("PLAYER_ENTERING_WORLD", function()
	if entered then return end
	entered = true
	arm(FIRST_CHECK)
end)

function ns.ShowWhatsNew()
	if ns.InCombat() then return ns.log(L.COMBAT) end
	local content = ns.News and ns.News.Current()
	if not content then return ns.log(L.NEWS_EMPTY) end
	local first = (content.entries or {})[1]
	local text = content.dev and string.format(L.NEWS_DEV, first and first.version or "") or string.format(L.NEWS_VERSION, ns.News.Running() or "")
	open(content, text, nil, false)
end

UI.WhatsNew = function() return window end
