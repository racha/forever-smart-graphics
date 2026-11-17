-- Forever Smart Graphics panel: the window base. Adapted from Forever Controller Tweaks (MIT, same author).
-- One native window shown at a time; it owns the pad while shown (EnableGamePadButton) and runs its own 2D focus with
-- SmartNavigation's cursor art, lists included. Navigation is D-pad (a held direction repeats), keyboard arrows and
-- the mouse; the sticks are not read. Nothing here calls into Blizzard's Menu, SmartNavigation or binding stack.
-- Windows open out of combat only and close when combat starts.
local _, ns = ...
local UI = ns.UI
local L = UI.L

local DIRS = { PADDUP = { 0, 1 }, PADDDOWN = { 0, -1 }, PADDLEFT = { -1, 0 }, PADDRIGHT = { 1, 0 } }
local REPEAT_DELAY, REPEAT_EVERY = 0.38, 0.11
local TICK_EVERY = 1
local TAB_KEYS = { PADLSHOULDER = -1, PADRSHOULDER = 1 }
local CLOSE_KEYS = { PADFORWARD = true, PADSOCIAL = true }

local current
local Window = {}

function Window:SetTitle(text) self.NineSlice.Text:SetText(text) end

function Window:SetPrompts(list)
	self.promptList = list
	self.footer:Set(list)
end

-- nodes: { region, select = fn, cursorX, onFocus(focused), onDir(dir) returns false to hand left/right back, noSide,
-- onMove(dx, dy) returns true when it moved the focus itself (scrolling lists), onKey(key) returns true, tip,
-- prompts }. Refreshes rebuild the list, so the focus stays on the same region when it is still listed.
function Window:SetNodes(nodes)
	self.nodes = nodes
	local region, keep = self.focus and self.focus.region, nil
	for _, node in ipairs(nodes) do
		if node.region == region then keep = node end
	end
	if keep then self.focus = nil end
	-- The mouse look has no resting focus: only a hover or a navigation key makes one.
	self:Focus(keep or (UI.Pad() and nodes[1] or nil))
end

-- Native focus: the gold chevron at the row's left edge, a subtle row wash (unless the row draws its own focus
-- state), and the row's tooltip with its button actions beside it.
function Window:Focus(node)
	local old = self.focus
	self.focus = node
	if old and old ~= node and old.onFocus then old.onFocus(false) end
	if node and node.onFocus then node.onFocus(true) end

	local region = node and node.region
	local wash = region and not node.onFocus and UI.ShowWash()
	self.wash:ClearAllPoints()
	self.wash:SetShown(wash)
	if wash then
		self.wash:SetPoint("TOPLEFT", region, "TOPLEFT", -10, 0)
		self.wash:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 5, 0)
	end
	UI.HideTooltip()
	if UI.DialogShown() or self.modal then return end
	if node and node.tip then UI.Tooltip(node.tipRegion or region, type(node.tip) == "function" and node.tip() or node.tip) end
	self.cursor:Attach(node and (node.cursorRegion or region), node and node.cursorX)
	if self.OnFocusChanged then self:OnFocusChanged(node) end
end

-- Picks the nearest visible node in the direction; off-axis distance counts double.
local OFF_BAND = 10000

function Window:Move(dx, dy, repeats)
	if self.modal then return self.modal:Move(dx, dy, repeats) end
	self.byHover = false
	local focus = self.focus
	local from = focus and focus.region
	if not from then return self:Focus(self.nodes and self.nodes[1]) end
	if focus.onMove and focus.onMove(dx, dy) then return end

	local fx, fy = from:GetCenter()
	if not fx then return end
	local best, bestScore
	for _, node in ipairs(self.nodes or {}) do
		local region = node.region
		local x, y = region:GetCenter()
		-- noSide nodes (setting rows, where left/right change a value) are reached with up/down only.
		if node ~= focus and x and region:IsVisible() and not (dx ~= 0 and node.noSide) then
			local along = (x - fx) * dx + (y - fy) * dy
			local across = math.abs((x - fx) * dy) + math.abs((y - fy) * dx)
			if along > 1 then
				local score = along + across * 2
				if dx ~= 0 and math.abs(y - fy) >= (from:GetHeight() + region:GetHeight()) / 2 then score = score + OFF_BAND end
				if not bestScore or score < bestScore then best, bestScore = node, score end
			end
		end
	end
	if best then return self:Focus(best) end
end

function Window:Select()
	local node = self.focus
	if node and node.select then node.select() end
end

-- An open modal (a list, the name box) owns the input; the window redraws when it closes.
function Window:Refresh()
	if self.modal then return end
	if self.OnRefresh then self:OnRefresh() end
end

function Window:StartRepeat(dir)
	self.repeatDir, self.repeatAt, self.repeatCount = dir, GetTime() + REPEAT_DELAY, 0
	self:Move(dir[1], dir[2])
end

function Window:Pad(key)
	if UI.DialogShown() then
		self.repeatKey, self.repeatDir = nil, nil
		return UI.Dialog():OnPad(key)
	end
	if self.modal then return self.modal:OnPad(key) end
	local focus = self.focus
	if focus and focus.onKey and focus.onKey(key) then return end
	if self.OnKey and self:OnKey(key) then return end

	-- A focused control may use left/right itself; false hands the press back to focus movement. A noSide row keeps
	-- left/right even at its end, so walking the rows never lands on, or changes, another setting.
	if (key == "PADDLEFT" or key == "PADDRIGHT") and focus and (focus.onDir and focus.onDir(key == "PADDLEFT" and -1 or 1) ~= false or focus.noSide) then return end
	local dir = DIRS[key]
	if dir then
		self.repeatKey = key
		return self:StartRepeat(dir)
	end
	if TAB_KEYS[key] then
		if self.OnTab and not UI.DialogShown() then self:OnTab(TAB_KEYS[key]) end
		return
	end
	if key == "PAD1" then return self:Select() end
	if key == "PAD2" then
		if self.OnBack then return self:OnBack() end
		return UI.CloseAll()
	end
	if CLOSE_KEYS[key] then return UI.CloseAll() end
end

local function onPadDown(self, key)
	if InCombatLockdown() then return end
	UI.NoteInput("pad")
	self:SetPropagateKeyboardInput(false)
	-- A window opened in the mouse look has no focus: the first pad press puts it on the first element (a direction
	-- stops there; A presses it). B with nothing focused closes, as it does from the page list.
	if key ~= "PAD2" and not (self.focus or self.modal or UI.DialogShown()) and self.nodes and self.nodes[1] then
		self:Focus(self.nodes[1])
		if DIRS[key] then return end
	end
	self:Pad(key)
end

local function onPadUp(self, key)
	if key == self.repeatKey then self.repeatKey, self.repeatDir = nil, nil end
end

-- The keyboard keeps only navigation keys (arrows, Enter/Space as A, Escape as B); everything else passes on. While
-- the name box has focus its EditBox takes the keys first.
local KEY_AS_PAD = { UP = "PADDUP", DOWN = "PADDDOWN", LEFT = "PADDLEFT", RIGHT = "PADDRIGHT", ENTER = "PAD1", SPACE = "PAD1" }

local function onKeyDown(self, key)
	if InCombatLockdown() then return end
	local pad = KEY_AS_PAD[key]
	local nav = pad or key == "ESCAPE"
	self:SetPropagateKeyboardInput(not nav)
	if nav then UI.NoteInput("mouse") end
	if pad then
		self:Pad(pad)
		self.repeatKey, self.repeatDir = nil, nil
		return
	end
	if not nav then return end

	if self.modal then return self.modal:OnPad("PAD2") end
	if UI.DialogShown() then return UI.Dialog():OnPad("PAD2") end
	if self.OnBack then return self:OnBack() end
	UI.CloseAll()
end

local function onUpdate(self, elapsed)
	local now = GetTime()
	if self.repeatDir and now >= self.repeatAt then
		self.repeatAt = now + REPEAT_EVERY
		self.repeatCount = (self.repeatCount or 0) + 1
		self:Move(self.repeatDir[1], self.repeatDir[2], self.repeatCount)
	end

	if not self.OnTick then return end
	self.tickElapsed = (self.tickElapsed or 0) + elapsed
	if self.tickElapsed < TICK_EVERY then return end
	self.tickElapsed = 0
	self:OnTick()
end

local function onShow(self)
	UI.MarkCursor()
	self.glow:Show()
end

local function onHide(self)
	if self.closing then return end
	self.glow:Hide()
	UI.HideTooltip()
	self.repeatKey, self.repeatDir = nil, nil
	if self.modal then self.modal:OnPad("PAD2") end
	if UI.DialogShown() and UI.Dialog().owner == self then UI.Dialog():Close() end
	if self.OnClosed then self:OnClosed() end
	if current == self then current = nil end
	if not current then UI.SetOpen(false) end
	-- Hidden with UIParent (Alt+Z, a cinematic): the window is still shown and would take pad input when UIParent
	-- comes back, with nothing current. Hide it for real.
	if self:IsShown() then
		self.closing = true
		self:Hide()
		self.closing = nil
	end
end

local BODY_ATLAS, BODY_ALPHA, BODY_GREY = "bank-frame-background", 0.5, 0.6

-- A w x h window, centred on screen. native = the Settings panel's body: its flat background plus Options_InnerFrame at
-- 17, -64 (Blizzard_SettingsPanel.xml); otherwise the Bank frame's background.
function UI.NewWindow(w, h, native)
	local window = Mixin(CreateFrame("Frame", nil, UIParent, "ForeverSmartGraphicsWindowTemplate"), Window)
	window:SetSize(w, h)
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	-- Above the Settings panel (HIGH) and the game menu (DIALOG), which may stay open under our window.
	window:SetFrameStrata("FULLSCREEN_DIALOG")
	window.ClosePanelButton:SetScript("OnClick", function() UI.CloseAll() end)
	-- The flat background's colour is translucent; a black underlay makes the window opaque over the world.
	local underlay = (window.Bg or window):CreateTexture(nil, "BACKGROUND", nil, -8)
	underlay:SetColorTexture(0, 0, 0, 1)
	underlay:SetAllPoints()
	if native then
		local inner = window:CreateTexture(nil, "OVERLAY", nil, 2)
		inner:SetAtlas("Options_InnerFrame", true)
		inner:SetPoint("TOPLEFT", 17, -64)
	else
		-- The native Bank frame's background, tiled at 256 x 256 as the Bank frame does, so it stays crisp at any size.
		local body = (window.Bg or window):CreateTexture(nil, "BACKGROUND", nil, 1)
		body:SetAtlas(BODY_ATLAS)
		body:SetHorizTile(true)
		body:SetVertTile(true)
		body:SetAllPoints()
		body:SetAlpha(BODY_ALPHA)
		body:SetDesaturation(BODY_GREY)
	end
	window:EnableGamePadButton(true)
	window:EnableKeyboard(true)
	window:SetScript("OnGamePadButtonDown", onPadDown)
	window:SetScript("OnGamePadButtonUp", onPadUp)
	window:SetScript("OnKeyDown", onKeyDown)
	window:SetScript("OnUpdate", onUpdate)
	window:SetScript("OnShow", onShow)
	window:SetScript("OnHide", onHide)
	window:SetScript("OnMouseDown", function() UI.NoteInput("mouse") end)
	window.footer = UI.Footer(window)
	window.cursor = UI.Cursor(window)
	window.glow = UI.Glow(window, window.NineSlice, "gamepad-uiframemetal-focus", -10, 14, 14, -14)
	window.wash = window:CreateTexture(nil, "BACKGROUND", nil, 7)
	window.wash:SetColorTexture(1, 1, 1, 0.1)
	window.wash:Hide()
	return window
end

-- PortraitFrameTemplate's round portrait on one of our windows (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml
-- 574-596; NineSliceLayouts.lua PortraitFrameTemplate): the frame's border takes the portrait layout (its corner is
-- UI-Frame-PortraitMetal-CornerTopLeft, the gold ring), and under it a 62 x 62 texture at -5, 7 masked round by
-- Interface\CharacterFrame\TempPortraitAlphaMask, inset 2, 0, -2, 4. The title moves right of it as the template's
-- TitleContainer does (58 from the left, 24 from the right). This client has no SetPortraitToTexture, so the mask
-- does the rounding.
local PORTRAIT_SIZE, PORTRAIT_X, PORTRAIT_Y, TITLE_LEFT, TITLE_RIGHT, TITLE_Y = 62, -5, 7, 58, -24, -5
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function UI.AddPortrait(window, file)
	local nine = window.NineSlice
	if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then NineSliceUtil.ApplyLayoutByName(nine, "PortraitFrameTemplate") end
	local holder = CreateFrame("Frame", nil, window)
	holder:SetSize(1, 1)
	holder:SetPoint("TOPLEFT")
	holder:SetFrameLevel(window:GetFrameLevel() + 1)
	nine:SetFrameLevel(window:GetFrameLevel() + 2)
	local portrait = holder:CreateTexture(nil, "OVERLAY")
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint("TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	portrait:SetTexture(file)
	local mask = holder:CreateMaskTexture()
	mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, 0)
	mask:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 4)
	portrait:AddMaskTexture(mask)
	nine.Text:ClearAllPoints()
	nine.Text:SetPoint("TOP", 0, TITLE_Y)
	nine.Text:SetPoint("RIGHT", TITLE_RIGHT, 0)
	nine.Text:SetPoint("LEFT", TITLE_LEFT, 0)
	window.portrait, window.portraitMask = portrait, mask
	return portrait
end

-- A focus node for a frame: hover focuses it, click selects it (the frame's own OnClick). A hover counts only when
-- the pointer moved (a window or list shown under a resting pointer keeps the pad focus); in the mouse look leaving
-- the frame drops the focus, so a redraw never shows a tooltip for a row the pointer has left.
local function hoverEnter(window, region)
	local moved = UI.NoteHover()
	if not (window:IsShown() and window.nodes) or window.modal then return end
	if not moved and UI.Pad() then return end
	for _, n in ipairs(window.nodes) do
		if n.region == region then
			window.byHover = true
			return window:Focus(n)
		end
	end
end

local function hoverLeave(window, region)
	local focus = window.focus
	if UI.Pad() or window.modal or not (focus and focus.region == region) or region:IsMouseOver() then return end
	window:Focus(nil)
end

function UI.Node(window, region, select, extra)
	local node = extra or {}
	node.region, node.select = region, select
	if region.HookScript and not region.graphicsHooked then
		region.graphicsHooked = true
		region:HookScript("OnEnter", function() hoverEnter(window, region) end)
		region:HookScript("OnLeave", function() hoverLeave(window, region) end)
	end
	return node
end

-- Fit to screen: never larger than the screen minus the footer and a margin (Steam Deck 1280x800, large UI scales).
-- The window is centred, so each half must fit.
local FIT_MARGIN, FOOTER_HEIGHT = 8, 48

function UI.Fit(window)
	local halfWidth = window:GetWidth() / 2 + FIT_MARGIN
	local halfHeight = window:GetHeight() / 2 + FOOTER_HEIGHT + FIT_MARGIN
	window:SetScale(math.min(1, UIParent:GetWidth() / 2 / halfWidth, UIParent:GetHeight() / 2 / halfHeight))
end

-- Panel.lua wraps this: it fades Blizzard leftovers while one of our windows is open.
function UI.SetOpen(open) UI.open = open end

function UI.Show(window)
	if InCombatLockdown() then return ns.log(L.COMBAT) end

	local old = current
	current = window
	UI.SetOpen(true)
	if old and old ~= window then old:Hide() end
	-- A window opens on its first element, as native windows do.
	if not window:IsShown() then window.focus = nil end
	UI.Fit(window)
	window:Show()
	window:Refresh()
end

function UI.Current() return current end

function UI.CloseAll()
	local open = current
	current = nil
	if open then open:Hide() end
	UI.SetOpen(false)
end

-- Combat closes every window of ours, list and dialog in the same handler: Core fires FSG_COMBAT_START synchronously
-- first thing in PLAYER_REGEN_DISABLED, before lockdown. A window that wants to be offered again after combat sets
-- resume = { text, fn } and gets it in UI.resume.
local function combatClose()
	if not current then return end
	UI.resume = current.resume
	UI.CloseAll()
end

ns.On("FSG_COMBAT_START", combatClose)
ns.On("FSG_COMBAT_END", function()
	local resume = UI.resume
	if not resume then return end
	UI.resume = nil
	C_Timer.After(0.5, function()
		if not InCombatLockdown() and not current then UI.OfferResume(resume) end
	end)
end)

-- A new look re-lays the open window out in place: footer, glow, cursor, then its own controls on the next frame.
ns.On("FSG_INPUT", function()
	local window = current
	if not (window and window:IsShown()) then return end
	window.footer:Set(window.promptList or {})
	window.glow:SetShown(UI.Pad())
	if not UI.Pad() then window.cursor:Hide() end
	if UI.DialogShown() then UI.Dialog():Point() end
	if window.modal and window.modal.Redraw then window.modal.Redraw() end
	UI.RefreshSoon(window)
end)

local function refit()
	if current and current:IsShown() then UI.Fit(current) end
end
ns.On("UI_SCALE_CHANGED", refit)
ns.On("DISPLAY_SIZE_CHANGED", refit)

-- One redraw of a window on the next frame, however many changes asked for it in this one.
local soon = {}
function UI.RefreshSoon(window)
	if not window or soon[window] then return end
	soon[window] = true
	C_Timer.After(0, function()
		soon[window] = nil
		if window:IsShown() then window:Refresh() end
	end)
end
