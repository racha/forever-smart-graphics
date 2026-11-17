-- Forever Smart Graphics panel entry points and the settings window. Adapted from Forever
-- Controller Tweaks (MIT, same author). /fsg, the minimap button and the addon compartment open the window: the game's
-- Settings panel frame with a status strip in its tab band (Here > Profile > Smart > FPS, each a link), the page list
-- on the left (Graphics: Overview, Profiles, Locations, Smart mode; Addon: Options) and the page on the right, with a
-- fixed action bar under the title where the page has one. The profile editor is a second level under Profiles. The
-- bottom line only shows short confirmations. No page in Options: a Settings category registered by addon code
-- taints Options' search.
local _, ns = ...
local UI = ns.UI
local L = UI.L
local N = UI.N

-- Ours on top of the native numbers: the status strip in the tab band, the action bar under the page title.
-- The strip starts right of the round portrait (62 wide at -5): 62 instead of the tab band's 32.
local STRIP_X, STRIP_Y, STRIP_H, STRIP_PAD, STRIP_RIGHT = 62, 27, 37, 8, 32
local PORTRAIT = "Interface\\AddOns\\ForeverSmartGraphics\\Media\\portrait"
local BAR_Y, BAR_H, HEADER_BAR_H, FLASH_FOR = 54, 22, 82, 4
local METER_W, METER_H, METER_SPAN = 96, 7, 1.5
local PAGE_ORDER = { "overview", "profiles", "locations", "smart", "general" }
local GROUPS = { { header = "CAT_GRAPHICS", pages = { "overview", "profiles", "locations", "smart" } }, { header = "CAT_ADDON", pages = { "general" } } }

local main, list, canvas, scroll, bar, strip
local contents, bars = {}, {}
local sel = { key = "overview" }
local profileId
local SCROLL_STEP = N.ROW_H + N.ROW_GAP

local function pageOf(key)
	for _, spec in ipairs(UI.PAGES) do if spec.key == key then return spec end end
end

-- The editor sits under Profiles: the list marks Profiles and L1/R1 step from there.
local function listKey(key) return key == "profile" and "profiles" or key end

-- The goal Smart mode holds (its goal, else the target) and Smart's word for now.
function UI.Goal()
	local smart = ns.Smart
	local state = smart and smart.Enabled() and smart.State()
	return state and state.goal or ns.db.smart.target
end

local function capital(text) return (text or ""):gsub("^%l", string.upper) end

local function calibrating()
	local state = ns.Calibrate and ns.Calibrate.State()
	return state and state.running and state
end

-- Why this profile is in use here (Apply.Active().source), for the strip's tooltip and the Overview sentence.
function UI.WhyLine(gold)
	local active = ns.Apply.Active() or {}
	local loc = active.loc or {}
	local typeLabel = ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE
	local name = active.profileName or L.DEFAULT
	if gold then name = "|cffffd100" .. name .. "|r" end
	if not ns.db.options.switching then return L.WHY_OFF end
	if active.source == "place" then return string.format(L.WHY_PLACE, loc.name or L.UNKNOWN_PLACE, name) end
	if active.source == "type" then return string.format(L.WHY_TYPE, typeLabel, name) end
	return string.format(L.WHY_DEFAULT, typeLabel)
end

-- The category list as the Settings panel builds it (Blizzard_CategoryList.lua): a header, its pages, an 18 tall
-- spacer, the next header.
local function isSelected(key) return listKey(sel.key) == key end

local function paintCategory(button)
	local selected = button.key and isSelected(button.key)
	button.label:SetFontObject(selected and "GameFontHighlight" or "GameFontNormal")
	button.texture:SetShown(selected or button.over)
	button.texture:SetAtlas(selected and "Options_List_Active" or "Options_List_Hover", true)
end

local function place(region, y)
	if region.listY == y then return end
	region.listY = y
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
end

local function buildCategories()
	list.buttons, list.headers = {}, {}
	local y = 0
	for g, group in ipairs(GROUPS) do
		if g > 1 then y = y + N.CAT_SPACER + N.CAT_GAP end
		local header = CreateFrame("Frame", nil, list)
		header:SetSize(N.CAT_W, N.CAT_HEADER_H)
		header.background = header:CreateTexture(nil, "BACKGROUND")
		header.background:SetPoint("TOPLEFT")
		header.background:SetAtlas("Options_CategoryHeader_" .. g, true)
		header.label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
		header.label:SetPoint("LEFT", N.CAT_HEADER_X, -1)
		header.label:SetText(L[group.header])
		place(header, y)
		list.headers[g] = header
		y = y + N.CAT_HEADER_H + N.CAT_GAP
		for _, key in ipairs(group.pages) do
			local button = CreateFrame("Button", nil, list)
			button:SetSize(N.CAT_W, N.CAT_H)
			button.key = key
			button.texture = button:CreateTexture(nil, "BACKGROUND")
			button.texture:SetPoint("CENTER")
			button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			button.label:SetPoint("LEFT", N.CAT_LABEL_X, 1)
			button.label:SetJustifyH("LEFT")
			button:SetScript("OnEnter", function(self)
				self.over = true
				paintCategory(self)
			end)
			button:SetScript("OnLeave", function(self)
				self.over = nil
				paintCategory(self)
			end)
			button:SetScript("OnClick", function(self)
				UI.NoteInput("mouse")
				if not main.modal then UI.SelectPage(self.key) end
			end)
			place(button, y)
			list.buttons[#list.buttons + 1] = button
			y = y + N.CAT_H + N.CAT_GAP
		end
	end
end

local function drawCategories(nodes)
	for _, button in ipairs(list.buttons) do
		local spec = pageOf(button.key)
		button.label:SetText(spec and spec.title({ key = button.key }) or button.key)
		paintCategory(button)
		nodes[#nodes + 1] = UI.Node(main, button, function() UI.SelectPage(button.key) end, { cursorX = 0, category = button.key })
	end
end

-- The status strip, in the native tab band (32, -27, 37 tall): Here > Profile > Smart, then the FPS with its meter
-- against the goal. Segments are mouse links only (pads use L1/R1); they redraw every second.
local function segment(caption, onClick, tip)
	local seg = CreateFrame("Button", nil, strip)
	seg:SetHeight(STRIP_H)
	seg.wash = seg:CreateTexture(nil, "BACKGROUND")
	seg.wash:SetColorTexture(1, 1, 1, 0.1)
	seg.wash:SetAllPoints()
	seg.wash:Hide()
	seg.caption = seg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	seg.caption:SetPoint("LEFT", STRIP_PAD, 0)
	seg.caption:SetText(caption)
	seg.value = seg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	seg.value:SetPoint("LEFT", seg.caption, "RIGHT", 6, 0)
	seg.value:SetWordWrap(false)
	seg:SetScript("OnEnter", function(self)
		self.wash:Show()
		UI.Tooltip(self, tip())
	end)
	seg:SetScript("OnLeave", function(self)
		self.wash:Hide()
		UI.HideTooltip(self)
	end)
	seg:SetScript("OnClick", function()
		UI.NoteInput("mouse")
		onClick()
	end)
	return seg
end

local function chevron(after)
	local tex = strip:CreateTexture(nil, "ARTWORK")
	tex:SetAtlas("common-dropdown-icon-next", true)
	tex:SetAlpha(0.4)
	tex:SetPoint("LEFT", after, "RIGHT", 2, 0)
	return tex
end

local function sizeSegment(seg)
	seg:SetWidth(STRIP_PAD * 2 + seg.caption:GetStringWidth() + 6 + math.min(seg.value:GetStringWidth(), 170))
end

local function hereTip()
	local loc = ns.Location.Current() or {}
	local own = loc.overrideKey and ns.db.overrides[loc.overrideKey]
	local first = own and string.format(L.STRIP_HERE_PLACE, loc.name or L.UNKNOWN_PLACE) or string.format(L.STRIP_HERE_TYPE, loc.name or L.UNKNOWN_PLACE, (ns.Location.LABELS[loc.key] or ""):lower())
	return { title = L.STRIP_HERE, lines = { first, L.STRIP_CLICK_LOCATIONS }, side = "right" }
end

local function profileTip() return { title = L.STRIP_PROFILE, lines = { UI.WhyLine(), L.STRIP_CLICK_PROFILE }, side = "right" } end

local function smartTip()
	local lines = {}
	if ns.Smart then
		local state = ns.Smart.State() or {}
		lines[1] = string.format(L.STATUS, UI.SmartStatus(state))
		lines[2] = string.format(L.STRIP_GOAL, UI.Goal())
		if state.cap then lines[#lines + 1] = string.format(L.CAP, state.cap) end
		local change = UI.ChangeText(state.last)
		if change then lines[#lines + 1] = string.format(L.LAST, change) end
	end
	lines[#lines + 1] = L.STRIP_CLICK_SMART
	return { title = L.STRIP_SMART, lines = lines, side = "right" }
end

local function fpsNow() return math.floor((tonumber(ns.plain(GetFramerate())) or 0) + 0.5) end

local function fpsTip()
	local lines = { string.format(L.STRIP_FPS_TIP, fpsNow(), UI.Goal()) }
	local state = ns.Smart and ns.Smart.State()
	if state and state.cap then lines[2] = string.format(L.CAP, state.cap) end
	return { title = L.TITLE, lines = lines, side = "left" }
end

local STRIP_COLORS = { good = GREEN_FONT_COLOR, warn = YELLOW_FONT_COLOR, bad = RED_FONT_COLOR }

local function drawStrip()
	local active = ns.Apply.Active() or {}
	local loc = active.loc or {}
	strip.here.value:SetText(string.format(L.STRIP_SMART_VALUE, loc.name or L.UNKNOWN_PLACE, ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE))
	local switching = ns.db.options.switching
	strip.profile.value:SetText(switching and (active.profileName or L.DEFAULT) or L.STRIP_NONE)
	strip.profile.value:SetFontObject(switching and "GameFontHighlight" or "GameFontDisable")
	local smartOn = ns.Smart and ns.Smart.Enabled()
	local text = L.STRIP_OFF
	if calibrating() then
		text = L.STRIP_CALIBRATING
	elseif smartOn then
		local style = UI.SmartStyle()
		text = capital(UI.SmartStatus(ns.Smart.State())) .. (style ~= "" and " · " .. style or "")
	end
	strip.smart.value:SetText(text)
	strip.smart.value:SetFontObject((smartOn or calibrating()) and "GameFontHighlight" or "GameFontDisable")
	for _, seg in ipairs({ strip.here, strip.profile, strip.smart }) do sizeSegment(seg) end
	local fps, goal = fpsNow(), UI.Goal()
	strip.fps:SetText(string.format(L.FPS, fps))
	strip.fps:SetTextColor(STRIP_COLORS[UI.FpsColor(fps, goal)]:GetRGB())
	strip.target:SetText(string.format(L.STRIP_TARGET, goal))
	strip.fill:SetWidth(math.max(1, METER_W * math.min(1, fps / math.max(1, goal * METER_SPAN))))
end

local function buildStrip()
	strip = CreateFrame("Frame", nil, main)
	strip:SetPoint("TOPLEFT", STRIP_X, -STRIP_Y)
	strip:SetSize(N.W - STRIP_X - STRIP_RIGHT, STRIP_H)
	strip.here = segment(L.STRIP_HERE, function()
		UI.OpenPanel("locations")
		local loc = ns.Location.Current() or {}
		if loc.overrideKey and ns.db.overrides[loc.overrideKey] and UI.LocationsTab then UI.LocationsTab.Focus(loc.overrideKey) end
	end, hereTip)
	strip.here:SetPoint("LEFT")
	strip.profile = segment(L.STRIP_PROFILE, function()
		local active = ns.Apply.Active()
		UI.OpenPanel("profile", active and active.profileId)
	end, profileTip)
	strip.profile:SetPoint("LEFT", chevron(strip.here), "RIGHT", 2, 0)
	strip.smart = segment(L.STRIP_SMART, function() UI.OpenPanel("smart") end, smartTip)
	strip.smart:SetPoint("LEFT", chevron(strip.profile), "RIGHT", 2, 0)
	strip.fps = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	strip.fps:SetPoint("RIGHT", -2, 0)
	strip.fps:SetJustifyH("RIGHT")
	strip.meter = CreateFrame("Frame", nil, strip)
	strip.meter:SetSize(METER_W, METER_H)
	strip.meter:SetPoint("RIGHT", strip.fps, "LEFT", -10, -6)
	local back = strip.meter:CreateTexture(nil, "BACKGROUND")
	back:SetColorTexture(0, 0, 0, 0.6)
	back:SetAllPoints()
	strip.fill = strip.meter:CreateTexture(nil, "ARTWORK")
	strip.fill:SetColorTexture(1, 1, 1, 0.7)
	strip.fill:SetPoint("TOPLEFT")
	strip.fill:SetPoint("BOTTOMLEFT")
	local tick = strip.meter:CreateTexture(nil, "OVERLAY")
	tick:SetColorTexture(1, 0.82, 0, 1)
	tick:SetSize(2, METER_H + 2)
	tick:SetPoint("LEFT", METER_W / METER_SPAN - 1, 0)
	strip.target = strip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	strip.target:SetPoint("BOTTOMLEFT", strip.meter, "TOPLEFT", 0, 2)
	local fpsHit = CreateFrame("Frame", nil, strip)
	fpsHit:SetPoint("TOPLEFT", strip.meter, "TOPLEFT", 0, 14)
	fpsHit:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT")
	fpsHit:EnableMouse(true)
	fpsHit:SetScript("OnEnter", function(self) UI.Tooltip(self, fpsTip()) end)
	fpsHit:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
	strip.fpsHit = fpsHit
end

-- The bottom line: a short confirmation, gone after 4 s.
function UI.Flash(text)
	if not main then return end
	main.status:SetText(text or "")
	main.flashUntil = GetTime() + FLASH_FOR
end

-- The page area: a scroll frame under the header (50 tall, or 82 with an action bar: title in GameFontHighlightHuge
-- at 7, -22, the divider at 50, the bar's buttons at 54), scrolled in steps of one row by the wheel, the bar or the
-- focus moving out of view.
local function headerHeight(key)
	local spec = pageOf(key)
	return spec and spec.bar and HEADER_BAR_H or N.HEADER_H
end

local function maxScroll()
	local content = contents[sel.key]
	return math.max(0, (content and content:GetHeight() or 0) - scroll:GetHeight())
end

local function scrollTo(px)
	local limit = maxScroll()
	px = math.max(0, math.min(px, limit))
	scroll.offset = px
	scroll:SetVerticalScroll(px)
	bar:Set(math.floor(px / SCROLL_STEP + 0.5), 1, math.ceil(limit / SCROLL_STEP) + 1)
end

local function reveal(region)
	local content = contents[sel.key]
	local owner = region
	while owner and owner ~= content and owner.GetParent do
		if owner.flowY then break end
		owner = owner:GetParent()
	end
	local top = owner and owner.flowY
	if not top or owner:GetParent() ~= content then return end
	local view, offset = scroll:GetHeight(), scroll.offset or 0
	if top < offset then return scrollTo(top - N.PAD_TOP) end
	local bottom = top + owner:GetHeight()
	if bottom > offset + view then scrollTo(bottom - view + N.PAD_TOP) end
end

local function contentOf(key)
	local content = contents[key]
	if content then return content end

	local spec = pageOf(key)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(N.CONTAINER_W - N.BAR_W, 1)
	content:Hide()
	contents[key] = content
	if spec.bar then
		bars[key] = CreateFrame("Frame", nil, canvas)
		bars[key]:SetPoint("TOPLEFT", 0, -BAR_Y)
		bars[key]:SetSize(N.CONTAINER_W, BAR_H)
		bars[key]:Hide()
	end
	spec.build(content, main, bars[key])
	return content
end

-- Footer: the focused node's own prompts after Select, the neighbouring pages, then Back (or Close).
local function neighbour(offset)
	for i, key in ipairs(PAGE_ORDER) do
		if key == listKey(sel.key) then
			local nextKey = PAGE_ORDER[i + offset]
			return nextKey and pageOf(nextKey) and nextKey
		end
	end
end

local function setPrompts(node)
	if UI.DialogShown() or main.modal then return end
	local prompts = { { "PAD1", L.SELECT } }
	for _, prompt in ipairs(node and node.prompts or {}) do prompts[#prompts + 1] = prompt end
	local before, after = neighbour(-1), neighbour(1)
	if before then prompts[#prompts + 1] = { "PADLSHOULDER", pageOf(before).title({ key = before }) } end
	if after then prompts[#prompts + 1] = { "PADRSHOULDER", pageOf(after).title({ key = after }) } end
	prompts[#prompts + 1] = { "PAD2", (node and not node.category) and L.BACK or L.CLOSE }
	main:SetPrompts(prompts)
end

-- key: a page ("overview", "profiles", "locations", "smart", "general") or "profile" with the profile id (the editor).
function UI.SelectPage(key, id)
	if not pageOf(key) then key = pageOf("overview") and "overview" or UI.PAGES[1].key end
	if key == "profile" then
		id = ns.Profiles.Get(id or "") and id or profileId or "default"
		profileId = id
	end
	local changed = sel.key ~= key or sel.id ~= id
	sel = { key = key, id = id }
	if not main then return end
	for k, content in pairs(contents) do
		if k ~= key then
			content:Hide()
			if bars[k] then bars[k]:Hide() end
		end
	end
	local content = contentOf(key)
	local top = headerHeight(key)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", 0, -top - 1)
	scroll:SetSize(N.CONTAINER_W - N.BAR_W, N.CONTAINER_H - top - 1)
	canvas.divider:ClearAllPoints()
	canvas.divider:SetPoint("TOP", 0, -N.HEADER_H)
	scroll:SetScrollChild(content)
	content:Show()
	if bars[key] then bars[key]:Show() end
	if changed then
		main.focus = nil
		scrollTo(0)
	end
	if main:IsShown() then main:Refresh() end
end

UI.SelectCategory = UI.SelectPage

function UI.Selection() return sel end

local function build()
	main = UI.NewWindow(N.W, N.H, true)
	main:SetTitle(L.TITLE)
	UI.AddPortrait(main, PORTRAIT)
	main.status = main:CreateFontString(nil, "OVERLAY", "GameFontWhite")
	main.status:SetPoint("BOTTOM", 0, 24)
	buildStrip()
	list = CreateFrame("Frame", nil, main)
	list:SetSize(N.LIST_W, N.CONTAINER_H)
	list:SetPoint("TOPLEFT", N.LIST_X, -N.LIST_Y)
	buildCategories()
	canvas = CreateFrame("Frame", nil, main)
	canvas:SetSize(N.CONTAINER_W, N.CONTAINER_H)
	canvas:SetPoint("TOPLEFT", N.CONTAINER_X, -N.LIST_Y)
	canvas.title = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	canvas.title:SetPoint("TOPLEFT", N.TITLE_X, -N.TITLE_Y)
	canvas.title:SetJustifyH("LEFT")
	canvas.subtitle = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	canvas.subtitle:SetPoint("LEFT", canvas.title, "RIGHT", 10, -2)
	canvas.divider = canvas:CreateTexture(nil, "ARTWORK")
	canvas.divider:SetAtlas("Options_HorizontalDivider", true)
	scroll = CreateFrame("ScrollFrame", nil, canvas)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta) scrollTo((scroll.offset or 0) - delta * SCROLL_STEP) end)
	bar = UI.ScrollBar(canvas, N.CONTAINER_H - N.HEADER_H - 8, function(top) scrollTo(top * SCROLL_STEP) end)
	bar:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, -N.HEADER_H - 4)
	main.canvas, main.scroll, main.list, main.strip = canvas, scroll, list, strip
	main.closeButton = UI.SmallButton(main, L.CLOSE)
	main.closeButton:SetSize(N.BUTTON_W, N.BUTTON_H)
	main.closeButton:SetPoint("BOTTOMRIGHT", N.CLOSE_X, N.CLOSE_Y)
	main.closeButton.action = function() UI.CloseAll() end
	main.resume = { text = L.RESUME_TEXT, fn = function() UI.OpenPanel() end }
	main.OnRefresh = function()
		drawStrip()
		local spec = pageOf(sel.key)
		canvas.title:SetText(spec.title(sel))
		canvas.subtitle:SetText(spec.subtitle and spec.subtitle(sel) or "")
		local nodes = spec.refresh(contentOf(sel.key), main, sel, bars[sel.key]) or {}
		nodes[#nodes + 1] = UI.Node(main, main.closeButton, function() UI.CloseAll() end)
		drawCategories(nodes)
		main:SetNodes(nodes)
		scrollTo(scroll.offset or 0)
		setPrompts(main.focus)
	end
	main.OnFocusChanged = function(_, node)
		if node then reveal(node.region) end
		setPrompts(node)
	end
	main.OnKey = function(_, key)
		local spec = pageOf(sel.key)
		return spec.onKey and spec.onKey(key, main.focus)
	end
	-- B: the editor goes back to the list on its profile's row; a page to its entry in the list; the list closes.
	main.OnBack = function()
		local spec = pageOf(sel.key)
		if spec.onBack and spec.onBack(main.focus) then return end
		local focus = main.focus
		if focus and not focus.category then
			for _, node in ipairs(main.nodes) do if node.category and isSelected(node.category) then return main:Focus(node) end end
		end
		UI.CloseAll()
	end
	main.OnTab = function(_, offset)
		local key = neighbour(offset)
		if key then UI.SelectPage(key) end
	end
	main.OnTick = function()
		drawStrip()
		if main.flashUntil and GetTime() >= main.flashUntil then
			main.flashUntil = nil
			main.status:SetText("")
		end
		local spec = pageOf(sel.key)
		if spec.tick then spec.tick(contentOf(sel.key)) end
	end
end

-- key: "overview", "profiles", "locations", "smart", "general", or "profile" with a profile id (its editor); nil for
-- the last one shown.
local KEYS = { options = "general" }

function UI.OpenPanel(key, id)
	if not ns.db then return end
	if InCombatLockdown() then return ns.log(L.COMBAT) end
	if not main then build() end
	local pageKey = key and (KEYS[key] or key) or sel.key
	if pageKey == "profile" then id = id or sel.id or profileId end
	UI.SelectPage(pageKey, id)
	UI.Show(main)
end

function UI.Main() return main end

function ns.TogglePanel()
	if UI.Current() then return UI.CloseAll() end
	UI.OpenPanel()
end

-- The profile the editor shows next (the Smart page's Save as profile picks the new one).
UI.ProfilesTab = {
	Select = function(id)
		profileId = id
		if sel.key == "profile" then UI.SelectPage("profile", id) end
	end,
	Selected = function() return sel.key == "profile" and sel.id or profileId end,
}

local function refreshMain() if main and main:IsShown() then UI.RefreshSoon(main) end end
for _, message in ipairs({ "FSG_PROFILES_CHANGED", "FSG_LOCATION", "FSG_SMART", "FSG_SWITCHING", "FSG_UNSUPPORTED", "FSG_LIMIT", "FSG_CALIBRATE", "FSG_PENDING", "FSG_ADJUST", "FSG_SUGGEST" }) do ns.On(message, refreshMain) end

-- Addon compartment (minimap AddOns button), declared in the TOC. Blizzard calls these globals after
-- forceinsecure(); the window opens on the next frame, outside the compartment menu's own click handling.
function ForeverSmartGraphics_OnCompartmentClick()
	C_Timer.After(0, function() ns.TogglePanel() end)
end

function ForeverSmartGraphics_OnCompartmentEnter(_, button)
	UI.Tooltip(button, { title = L.TITLE, lines = { L.COMPARTMENT_TIP } })
end

function ForeverSmartGraphics_OnCompartmentLeave(_, button) UI.HideTooltip(button) end

-- Blizzard leftovers behind our window: the last tooltip (GameTooltip, or Options' SettingsTooltip) and
-- SmartNavigation's gamepad focus arrow go transparent while the window is open (SetAlpha only, saved and given back):
-- a Hide from here would run GameTooltip's OnHide, which writes its fields, under the addon's taint.
local hidden = {}

local function fade(region)
	if not region or hidden[region] then return end
	hidden[region] = region:GetAlpha()
	region:SetAlpha(0)
end

local function hideLeftovers()
	for _, tooltip in ipairs({ GameTooltip, SettingsTooltip }) do
		if tooltip and tooltip:IsShown() then fade(tooltip) end
	end
	fade(SmartNavigation and SmartNavigation.Pointer)
end

local function restoreLeftovers()
	for region, alpha in pairs(hidden) do region:SetAlpha(alpha) end
	hidden = {}
end

local setOpen = UI.SetOpen
function UI.SetOpen(open)
	local was = UI.open
	if not open and was then restoreLeftovers() end
	setOpen(open)
	if open and not was then hideLeftovers() end
end

-- Our own minimap button, no library: the native tracking-button look with the addon's icon, on the minimap ring at
-- options.minimap.angle (drag it round); a click toggles the window. options.minimap.shown = false hides it.
local MINIMAP_ANGLE, MINIMAP_OUTSIDE = 200, 10
local ICON = "Interface\\AddOns\\ForeverSmartGraphics\\Media\\logo"
local atan2 = math.atan2 or math.atan
local minimapButton

local function placeMinimapButton()
	local angle = math.rad(ns.db.options.minimap.angle or MINIMAP_ANGLE)
	local radius = Minimap:GetWidth() / 2 + MINIMAP_OUTSIDE
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function dragMinimapButton()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	ns.db.options.minimap.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
	placeMinimapButton()
end

local function buildMinimapButton()
	local button = CreateFrame("Button", "ForeverSmartGraphicsMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	button:SetScript("OnClick", function() ns.TogglePanel() end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", dragMinimapButton) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self) UI.Tooltip(self, { title = L.TITLE, lines = { L.COMPARTMENT_TIP, L.MINIMAP_LINE } }) end)
	button:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
	minimapButton = button
end

function UI.UpdateMinimapButton()
	if not (Minimap and ns.db) then return end
	if not minimapButton then buildMinimapButton() end
	placeMinimapButton()
	minimapButton:SetShown(ns.db.options.minimap.shown ~= false)
end

ns.On("FSG_READY", UI.UpdateMinimapButton)

-- Show FPS on minimap (options.minimapFps): our own readout in the zone box's art. WoW Forever loads the Camelot
-- minimap (Blizzard_Minimap.toc: [Game] files for camelot): the zone box is one atlas, ui-hud-minimap-header-button at
-- its own size (152 x 23), with GameFontHighlightSmall 8 in (Camelot/MinimapZoneTextButton.xml:9-22); the addon count
-- under the calendar is ui-hud-minimap-addon-indicator, 23 x 22, 1 into the calendar (Camelot/AddonCompartment.xml:
-- 9-11, 31). Ours is the zone box's atlas cut in three (the ends kept, the middle stretched to the text), 23 tall, in
-- the same font, under the zone box with left edges aligned and the count's 1 overlap, at the minimap cluster's
-- scale; without the zone box, under the minimap. No other background: if the atlas is missing it shows no frame.
-- White normally; yellow within 15% under the goal (Smart's goal, else the target), red below. A plain button on
-- UIParent: only its own anchors and scale are set (nothing of Blizzard's is written), mouse only, up in combat. A
-- ticker every 0.5 s runs only while the option is on; it hides with the minimap.
local FPS_EVERY, FPS_WARN, FPS_H, FPS_PAD, FPS_OVERLAP = 0.5, 0.85, 23, 16, 1
local FPS_ATLAS, FPS_CAP = "ui-hud-minimap-header-button", 10
local FPS_COLORS = { good = HIGHLIGHT_FONT_COLOR, warn = YELLOW_FONT_COLOR, bad = RED_FONT_COLOR }
local fpsFrame, fpsTicker
-- The change signal: a gold glow (our glow texture) that pulses once over PULSE_FOR, and a mark beside the number for
-- MARK_FOR (the notice's minimal scroll bar arrows, or a dot), fading out over MARK_FADE. The last BATCHES_KEPT
-- batches stay in memory for the tooltip, LAST_LINES lines at most. Never saved.
local PULSE_FOR, MARK_FOR, MARK_FADE, MARK_W, BATCHES_KEPT, LAST_LINES = 1.2, 6, 0.8, 10, 3, 5
local GLOW = "Interface\\AddOns\\ForeverSmartGraphics\\Media\\glow"
local MARKS = { up = "minimal-scrollbar-arrow-top", down = "minimal-scrollbar-arrow-bottom" }
local batches = {}

function UI.FpsPulseOn() return ns.db.options.fpsPulse ~= false end

function UI.MinimapFpsOn()
	local options = ns.db.options
	if type(options.minimapFps) ~= "boolean" then options.minimapFps = false end
	return options.minimapFps
end

local function fpsGoal() return UI.Goal() end

function UI.FpsColor(fps, goal)
	if fps >= goal then return "good" end
	if fps >= goal * FPS_WARN then return "warn" end
	return "bad"
end

local function ago(t)
	local seconds = GetTime() - t
	if seconds < 10 then return L.AGO_NOW end
	if seconds < 60 then return string.format(L.AGO_SECONDS, seconds) end
	return string.format(L.AGO_MINUTES, seconds / 60)
end

local function fpsTip(self)
	local active = ns.Apply.Active() or {}
	local loc = active.loc or {}
	local lines = { string.format(L.FPS_TIP_PLACE, loc.name or L.UNKNOWN_PLACE, ns.Location.LABELS[loc.key] or L.UNKNOWN_PLACE), string.format(L.FPS_TIP_PROFILE, active.profileName or L.DEFAULT) }
	if ns.Smart and ns.Smart.Enabled() then lines[#lines + 1] = string.format(L.FPS_TIP_SMART, UI.SmartStatus(ns.Smart.State()), fpsGoal()) end
	if #batches > 0 then
		lines[#lines + 1] = { text = L.FPS_TIP_CHANGES, color = { NORMAL_FONT_COLOR:GetRGB() } }
		local shown = 0
		for b = #batches, 1, -1 do
			local batch = batches[b]
			for _, change in ipairs(batch.changes) do
				if shown == LAST_LINES then break end
				shown = shown + 1
				lines[#lines + 1] = string.format(L.FPS_TIP_CHANGE, ago(batch.t), L.SOURCES[batch.source] or tostring(batch.source or ""), UI.ChangeText(change))
			end
		end
	end
	lines[#lines + 1] = L.FPS_TIP_CLICK
	UI.Tooltip(self, { title = L.TITLE, lines = lines, side = "left" })
end

-- The zone bar (MinimapCluster.ZoneTextButton) is read only, never written.
local function fpsAnchor()
	local zone = MinimapCluster and MinimapCluster.ZoneTextButton
	if zone and zone:IsVisible() then return "zone", "TOPLEFT", zone, "BOTTOMLEFT", 0, FPS_OVERLAP, zone end
	return "minimap", "TOP", Minimap, "BOTTOM", 0, -6, Minimap
end

local function placeFps()
	local key, point, rel, relPoint, x, y, scaleOf = fpsAnchor()
	local scale = (scaleOf:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	if fpsFrame:GetScale() ~= scale then fpsFrame:SetScale(scale) end
	if fpsFrame.anchor == key then return end
	fpsFrame.anchor = key
	fpsFrame:ClearAllPoints()
	fpsFrame:SetPoint(point, rel, relPoint, x, y)
end

local tickFps

-- The mark beside the number: the last batch's for MARK_FOR, else a steady dot while Smart tests a raise.
local function drawMark()
	local mark, now = fpsFrame.mark, GetTime()
	local kind = fpsFrame.markUntil and now < fpsFrame.markUntil and fpsFrame.markKind
	local testing = not kind and ns.Smart and ns.Smart.State and (ns.Smart.State() or {}).status == "raising (testing)"
	kind = kind or (testing and "dot")
	mark:SetShown(kind and true or false)
	fpsFrame.text:SetPoint("CENTER", kind and -MARK_W / 2 or 0, -1)
	if not kind then return end

	if kind == "dot" then
		mark:SetTexture(nil)
		mark:SetColorTexture(1, 0.82, 0, 1)
		mark:SetSize(3, 3)
	else
		mark:SetAtlas(MARKS[kind])
		mark:SetSize(8, 5)
	end
	local left = fpsFrame.markUntil and fpsFrame.markKind and (fpsFrame.markUntil - now) or MARK_FADE
	mark:SetAlpha(math.min(1, left / MARK_FADE))
end

-- Every batch of changes: kept for the tooltip; with the readout and the pulse on, one glow and a mark. All up or
-- all down shows its arrow; a mix or a profile switch, a dot.
local function signal(changes, source)
	table.insert(batches, { t = GetTime(), source = source, changes = changes })
	while #batches > BATCHES_KEPT do table.remove(batches, 1) end
	if not (fpsFrame and fpsFrame:IsShown() and UI.MinimapFpsOn() and UI.FpsPulseOn()) then return end

	local up, down = 0, 0
	for _, change in ipairs(changes) do
		local from, to = tonumber(change.from), tonumber(change.to)
		if from and to and to > from then up = up + 1 elseif from and to and to < from then down = down + 1 end
	end
	local kind = "dot"
	if source ~= "profile" and down == 0 and up > 0 then kind = "up" end
	if source ~= "profile" and up == 0 and down > 0 then kind = "down" end
	fpsFrame.markKind, fpsFrame.markUntil = kind, GetTime() + MARK_FOR
	fpsFrame.pulse:Stop()
	fpsFrame.pulse:Play()
	tickFps()
	C_Timer.After(MARK_FOR - MARK_FADE / 2, function() if fpsFrame:IsShown() then tickFps() end end)
	C_Timer.After(MARK_FOR, function() if fpsFrame:IsShown() then tickFps() end end)
end

ns.On("FSG_CHANGES", function(a, b)
	local changes, source = a, b
	if type(a) == "table" and (a.source or a.reason) then changes, source = a.changes or {}, a.reason == "after combat" and "after combat" or a.source end
	if type(changes) == "table" and #changes > 0 then signal(changes, source) end
end)

function tickFps()
	local shown = Minimap:IsVisible()
	fpsFrame:SetShown(shown)
	if not shown then return end

	placeFps()
	local fps = math.floor((tonumber(ns.plain(GetFramerate())) or 0) + 0.5)
	fpsFrame.text:SetText(string.format(L.FPS, fps))
	fpsFrame.text:SetTextColor(FPS_COLORS[UI.FpsColor(fps, fpsGoal())]:GetRGB())
	drawMark()
	fpsFrame:SetWidth(fpsFrame.text:GetStringWidth() + FPS_PAD + (fpsFrame.mark:IsShown() and MARK_W or 0))
	if UI.TooltipOwner and UI.TooltipOwner() == fpsFrame then fpsTip(fpsFrame) end
end

local function buildMinimapFps()
	local frame = CreateFrame("Button", "ForeverSmartGraphicsMinimapFps", UIParent)
	frame:SetSize(40, FPS_H)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(10)
	frame:RegisterForClicks("LeftButtonUp")
	frame.slices = UI.ThreeSlice(frame, FPS_ATLAS, FPS_CAP)
	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.text:SetPoint("CENTER", 0, -1)
	frame.mark = frame:CreateTexture(nil, "OVERLAY")
	frame.mark:SetPoint("LEFT", frame.text, "RIGHT", 3, 0)
	frame.mark:Hide()
	frame.glow = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.glow:SetTexture(GLOW)
	frame.glow:SetVertexColor(1, 0.82, 0, 1)
	frame.glow:SetSize(120, 72)
	frame.glow:SetPoint("TOP", frame, "CENTER", 0, 72 * 0.25)
	frame.glow:SetAlpha(0)
	-- One soft gold breath, in and out, then back to nothing.
	frame.pulse = frame.glow:CreateAnimationGroup()
	for i, spec in ipairs({ { 0, 0.5 }, { 0.5, 0 } }) do
		local fade = frame.pulse:CreateAnimation("Alpha")
		fade:SetFromAlpha(spec[1])
		fade:SetToAlpha(spec[2])
		fade:SetDuration(PULSE_FOR / 2)
		fade:SetOrder(i)
		fade:SetSmoothing(i == 1 and "OUT" or "IN")
	end
	frame:SetScript("OnClick", function() UI.OpenPanel() end)
	frame:SetScript("OnEnter", fpsTip)
	frame:SetScript("OnLeave", function(self) UI.HideTooltip(self) end)
	frame:Hide()
	fpsFrame = frame
end

function UI.UpdateMinimapFps()
	if not (Minimap and ns.db) then return end
	local on = UI.MinimapFpsOn()
	if fpsTicker then fpsTicker:Cancel() end
	fpsTicker = nil
	if not on then
		if fpsFrame then fpsFrame:Hide() end
		return
	end

	if not fpsFrame then buildMinimapFps() end
	tickFps()
	fpsTicker = C_Timer.NewTicker(FPS_EVERY, tickFps)
end

ns.On("FSG_READY", UI.UpdateMinimapFps)

-- A small native message window: text and one or two buttons (A presses the focused one, B closes).
-- buttons = { { label, fn }, ... }.
local message, messageButtons

function UI.ShowMessage(text, buttons)
	if not message then
		message = UI.NewWindow(440, 150)
		message:SetTitle(L.TITLE)
		message.text = UI.Text(message, "GameFontHighlight", 24, 44, "", 392)
		message.text:SetSpacing(3)
		messageButtons = {}
		for i = 1, 2 do
			local button = CreateFrame("Button", nil, message, "SharedButtonSmallTemplate")
			button:SetSize(138, 28)
			button:SetScript("OnEnter", nil)
			button:SetScript("OnLeave", nil)
			messageButtons[i] = button
		end
		message.OnBack = function() UI.CloseAll() end
	end
	message.text:SetText(text)
	local nodes = {}
	for i, button in ipairs(messageButtons) do
		local spec = buttons[i]
		button:SetShown(spec ~= nil)
		if spec then
			local function press()
				UI.CloseAll()
				if spec[2] then spec[2]() end
			end
			button:SetText(spec[1])
			button:SetScript("OnClick", press)
			button:ClearAllPoints()
			if #buttons == 1 then button:SetPoint("BOTTOM", message, "BOTTOM", 0, 20) else button:SetPoint("BOTTOM", message, "BOTTOM", (i - 1.5) * 148, 20) end
			nodes[i] = UI.Node(message, button, press)
		end
	end
	message.OnRefresh = function()
		message:SetNodes(nodes)
		message:SetPrompts({ { "PAD1", L.SELECT }, { "PAD2", L.CLOSE } })
	end
	UI.Show(message)
end

-- After combat: offer to open again what combat closed.
function UI.OfferResume(resume) UI.ShowMessage(resume.text, { { L.RESUME, resume.fn }, { L.NOT_NOW } }) end

