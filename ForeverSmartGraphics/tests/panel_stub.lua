-- WoW UI stub for the panel specs (tests/panel_spec.lua): frames, timers, edit boxes, with taint traps on Blizzard UI
-- the panel must never touch. Adapted from Forever Controller Tweaks' panel stub (MIT, same author). Lua 5.1 and
-- 5.4. Not a spec itself.
unpack = unpack or table.unpack
local W = { clock = 100, timers = {}, frames = {}, log = {}, combat = false, fps = 60 }
_G.W = W

function GetTime() return W.clock end
function GetFramerate() return W.fps end
date = os.date
time = time or os.time
function InCombatLockdown() return W.combat end
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	W.log[#W.log + 1] = table.concat(parts, " ")
end
function Mixin(obj, ...)
	for _, m in ipairs({ ... }) do for k, v in pairs(m) do obj[k] = v end end
	return obj
end
W.cvars = { GamepadFocusStateColor = "1", GamepadFocusStateOpacity = "1" }
function GetCVar(name) return W.cvars[name] end
local function color(r, g, b) return { GetRGB = function() return r, g, b end } end
NORMAL_FONT_COLOR, GREEN_FONT_COLOR, HIGHLIGHT_FONT_COLOR = color(1, 0.82, 0), color(0.1, 1, 0.1), color(1, 1, 1)
YELLOW_FONT_COLOR, RED_FONT_COLOR = color(1, 1, 0), color(1, 0.1, 0.1)
InputIconTextureSetUtility = {
	GetActiveInputIconButtonTextures = function(k) assert(type(k) == "string"); return { [1] = "gamepad-ps-" .. k .. "-normal", [4] = "gamepad-ps-" .. k .. "-focus", [5] = "gamepad-ps-" .. k .. "-disabled" } end,
}
W.atlases = { ["ui-hud-minimap-header-button"] = { width = 152, height = 23, file = "Interface/HUD/MinimapHeader", leftTexCoord = 0.25, rightTexCoord = 0.4, topTexCoord = 0.5, bottomTexCoord = 0.6 } }
C_Texture = { GetAtlasInfo = function(atlas) return W.atlases[atlas] or { width = 55, height = 60 } end }
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "1.0.0" or nil end }

-- Taint traps: the panel must never reach these. The few reads it may make: a leftover tooltip's shown state and
-- alpha (SetAlpha only), and SmartNavigation's Pointer for its alpha.
W.trapped = {}
local function fromPanel()
	for level = 3, 6 do
		local info = debug.getinfo(level, "Sl")
		if info and info.source:find("/Panel/", 1, true) then return info.source:match("[^/]+$") .. ":" .. tostring(info.currentline) end
	end
end
local ALLOWED = {
	GameTooltip = {
		IsShown = function() return W.tooltipShown end,
		GetAlpha = function() return W.tooltipAlpha or 1 end,
		SetAlpha = function(_, a) W.tooltipAlpha = a end,
	},
	SmartNavigation = { Pointer = function() W.pointer = W.pointer or CreateFrame("Frame") return W.pointer end },
}
local function trapHit(what)
	local where = fromPanel()
	if not where then return end
	W.trapped[#W.trapped + 1] = what .. " at " .. where
	error("Panel touched " .. what .. " at " .. where, 3)
end
local function trap(name)
	return setmetatable({}, {
		__index = function(_, k)
			local allowed = ALLOWED[name] and ALLOWED[name][k]
			if allowed then
				if name == "SmartNavigation" then return allowed() end
				return allowed
			end
			trapHit(name .. "." .. tostring(k))
		end,
		__newindex = function(_, k) trapHit(name .. "." .. tostring(k) .. " (write)") end,
		__call = function() trapHit(name .. "()") end,
	})
end
W.TRAPS = { "Menu", "MenuUtil", "UIDropDownMenu_Initialize", "UIDropDownMenu_AddButton", "ToggleDropDownMenu", "StaticPopup_Show", "StaticPopup_Hide", "StaticPopupDialogs", "ShowUIPanel", "HideUIPanel", "UISpecialFrames", "SmartNavigation", "Settings", "GameTooltip", "EventRegistry", "CVarCallbackRegistry", "InputDeviceIconSetManager", "TextSizeManager", "FrameControlsManager", "GamepadMode" }
for _, name in ipairs(W.TRAPS) do _G[name] = trap(name) end
-- Blizzard Menu / Dropdown templates are never inherited.
local FORBIDDEN_TEMPLATE = { "Dropdown", "Menu", "StaticPopup", "SmartNav" }

-- timers
C_Timer = {}
function C_Timer.After(d, fn) W.timers[#W.timers + 1] = { at = W.clock + d, fn = fn } end
function C_Timer.NewTicker(d, fn)
	local t = { every = d, at = W.clock + d, fn = fn, ticker = true }
	function t:Cancel() self.cancelled = true end
	W.timers[#W.timers + 1] = t
	return t
end

-- frames
local Obj = {}
Obj.__index = function(self, k)
	local v = rawget(Obj, k)
	if v ~= nil then return v end
	-- Unknown WoW methods are no-ops; lowercase fields and the panel's own On* hooks stay nil until set.
	if type(k) == "string" and k:match("^%u") and not k:match("^On") then return function() end end
end
local function new(kind, parent)
	return setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, hooks = {}, w = 0, h = 0, x = 0, y = 0, text = "" }, Obj)
end
W.new = new
function Obj:Show() if not self.shown then self.shown = true; self:Fire("OnShow") end end
function Obj:Hide() if self.shown then self.shown = false; self:Fire("OnHide") end end
function Obj:SetShown(s) if s then self:Show() else self:Hide() end end
function Obj:IsShown() return self.shown end
function Obj:IsVisible()
	local o = self
	while o do if not o.shown then return false end o = o.parent end
	return true
end
function Obj:GetParent() return self.parent end
function Obj:SetSize(w, h) self.w, self.h = w, h end
function Obj:SetWidth(w) self.w = w end
function Obj:SetHeight(h) self.h = h end
function Obj:GetWidth() return self.w end
function Obj:GetHeight() return self.h end
function Obj:SetPoint(point, rel, relPoint, x, y)
	if type(rel) == "number" then x, y, rel = rel, relPoint, nil
	elseif type(relPoint) == "number" then x, y = relPoint, x end
	-- A second anchor (e.g. RIGHT after TOPLEFT) only stretches the region; keep the position anchor.
	if self.point == "TOPLEFT" and point ~= "TOPLEFT" and not self.cleared then return end
	self.cleared = false
	self.point, self.rel, self.x, self.y = point, rel, x or 0, y or 0
end
function Obj:ClearAllPoints() self.cleared = true end
function Obj:Abs()
	local base = self.rel or self.parent
	local bx, by = 0, 0
	if base and base ~= self and base.Abs then bx, by = base:Abs() end
	return bx + (self.x or 0), by + (self.y or 0)
end
function Obj:GetCenter()
	local x, y = self:Abs()
	if self.point == "TOPLEFT" then return x + self.w / 2, y - self.h / 2 end
	return x, y
end
function Obj:SetScript(name, fn) self.scripts[name] = fn end
function Obj:GetScript(name) return self.scripts[name] end
function Obj:HookScript(name, fn) self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], fn) end
function Obj:Fire(name, ...)
	if self.scripts[name] then self.scripts[name](self, ...) end
	for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end
end
-- Mouse: Buttons and EditBoxes take the mouse and left clicks by default; anything else needs EnableMouse, and other
-- buttons need RegisterForClicks. A click on a frame that doesn't take it does nothing, as in the game.
function Obj:EnableMouse(on) self.mouse = not not on end
function Obj:IsMouseEnabled()
	if self.mouse ~= nil then return self.mouse end
	return self.kind == "Button" or self.kind == "EditBox"
end
function Obj:RegisterForClicks(...) self.clicks = { ... } end
function Obj:TakesClick(button)
	if not self:IsMouseEnabled() then return false end
	local wanted = (button or "LeftButton") .. "Up"
	for _, registered in ipairs(self.clicks or { "LeftButtonUp" }) do if registered == wanted then return true end end
	return false
end
function Obj:Click(button)
	if not self:TakesClick(button) then return end
	self:Fire("OnClick", button or "LeftButton")
end
function Obj:IsMouseOver() return W.mouseOver == self end
function Obj:Hover()
	W.cursorX = (W.cursorX or 0) + 1
	W.mouseOver = self
	self:Fire("OnEnter")
end
function Obj:Leave()
	if W.mouseOver == self then W.mouseOver = nil end
	self:Fire("OnLeave")
end
function Obj:SetText(t) self.text = t or "" end
function Obj:GetText() return self.text end
function Obj:GetStringHeight() return 14 end
-- Text width as the store screenshots measured it: about 6.5 per character in the 12 pt fonts and 5.5 in the small
-- ones, colour codes not counted.
local function measured(fs, text) return #text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * ((fs.font or ""):find("Small") and 5.5 or 6.5) end
function Obj:GetStringWidth() return measured(self, self.text or "") end
function Obj:GetTextWidth() return #(self.text or "") * 6 end
function Obj:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Obj:SetGradient(orientation, from, to) self.gradient = { orientation = orientation, from = from, to = to } end
function Obj:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
function Obj:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function Obj:SetAlpha(a) self.alpha = a end
function Obj:GetAlpha() return self.alpha or 1 end
function Obj:GetName() return self.frameName end
function Obj:SetEnabled(on) self.enabled = on end
function Obj:IsEnabled() return self.enabled ~= false end
function Obj:SetFontObject(f) self.font = f end
function Obj:SetJustifyH(j) self.justifyH = j end
function Obj:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Obj:GetFrameLevel() return self.level or ((self.parent and self.parent.GetFrameLevel and self.parent:GetFrameLevel() or 0) + 1) end
function Obj:GetChildren() return unpack(self.children or {}) end
function Obj:SetFrameLevel(l) self.level = l end
function Obj:SetFrameStrata(s) self.strata = s end
function Obj:GetFrameStrata() return self.strata or (self.parent and self.parent.GetFrameStrata and self.parent:GetFrameStrata()) or "MEDIUM" end
function Obj:CreateTexture() return new("Texture", self) end
function Obj:CreateMaskTexture() return new("Mask", self) end
function Obj:AddMaskTexture(m) self.masks = self.masks or {}; table.insert(self.masks, m) end
function Obj:CreateFontString(_, _, font)
	local fs = new("FontString", self)
	fs.font = font
	self.fontStrings = self.fontStrings or {}
	table.insert(self.fontStrings, fs)
	return fs
end
function Obj:SetWordWrap(on) self.wordWrap = on end
-- Every shown one-line FontString on a visible frame whose words are wider than the width it was given: what the
-- game would cut with "...".
function W.truncated()
	local cut = {}
	for _, f in ipairs(W.frames) do
		if f:IsVisible() then
			for _, fs in ipairs(f.fontStrings or {}) do
				local text, width = fs.text or "", fs:GetStringWidth()
				if fs.shown and fs.wordWrap == false and fs.w > 0 and width > fs.w + 1 then cut[#cut + 1] = text .. " (" .. width .. " > " .. fs.w .. ")" end
			end
		end
	end
	return cut
end
function Obj:SetAtlas(a) self.atlas = a end
function Obj:SetTexture(t) self.texture = t end
function Obj:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
function Obj:SetTexCoord(...) self.coords = { ... } end
function Obj:SetNormalTexture() self.normal = self.normal or new("Texture", self) end
function Obj:SetPushedTexture() self.pushed = self.pushed or new("Texture", self) end
function Obj:SetDisabledTexture() self.disabledTex = self.disabledTex or new("Texture", self) end
function Obj:SetHighlightTexture() self.highlightTex = self.highlightTex or new("Texture", self) end
function Obj:GetNormalTexture() return self.normal end
function Obj:GetPushedTexture() return self.pushed end
function Obj:GetDisabledTexture() return self.disabledTex end
function Obj:GetHighlightTexture() return self.highlightTex end
function Obj:SetValue(v) self.value = v end
function Obj:SetVerticalScroll(v) self.vscroll = v end
function Obj:SetScale(v) self.scale = v end
function Obj:GetScale() return self.scale or 1 end
function Obj:GetEffectiveScale() return self.scale or 1 end
function Obj:SetPropagateKeyboardInput(p) self.propagate = p end
function Obj:CreateAnimationGroup()
	local g = new("Anim", self)
	function g:CreateAnimation() return new("A", g) end
	function g:IsPlaying() return self.playing end
	function g:Play() self.playing, self.plays = true, (self.plays or 0) + 1 end
	function g:Stop() self.playing = false end
	return g
end
-- Edit boxes: the keyboard focus is W.focus.
function Obj:SetFocus() W.focus = self end
function Obj:ClearFocus() if W.focus == self then W.focus = nil end end
function Obj:HasFocus() return W.focus == self end

local TEMPLATES = {}
TEMPLATES.ForeverSmartGraphicsWindowTemplate = function(f)
	f.NineSlice = new("Frame", f)
	f.NineSlice.Text = f:CreateFontString()
	f.ClosePanelButton = new("Button", f)
	f.Bg = new("Frame", f)
	f.shown = false
end
TEMPLATES.InsetFrameTemplate = function(f) f.Bg = f:CreateTexture() end
function CreateFrame(kind, name, parent, template)
	for _, word in ipairs(FORBIDDEN_TEMPLATE) do
		if template and template:find(word) then trapHit("template " .. template) end
	end
	local f = new(kind, parent)
	if parent then parent.children = parent.children or {}; table.insert(parent.children, f) end
	if template then
		f.template = template
		for t in template:gmatch("[^,%s]+") do if TEMPLATES[t] then TEMPLATES[t](f) end end
	end
	if name then _G[name], f.frameName = f, name end
	W.frames[#W.frames + 1] = f
	return f
end
UIParent = new("Frame")
UIParent:SetSize(1920, 1080)
Minimap = new("Frame", UIParent)
Minimap:SetSize(140, 140)
function GetCursorPosition() return W.cursorX or 0, 0 end

function W.advance(seconds, step)
	step = step or 0.05
	local target = W.clock + seconds
	while W.clock < target do
		W.clock = W.clock + step
		for i = #W.timers, 1, -1 do
			local t = W.timers[i]
			if not t.cancelled and W.clock >= t.at then
				if t.ticker then t.at = W.clock + t.every else table.remove(W.timers, i) end
				t.fn()
			end
		end
		for _, f in ipairs(W.frames) do
			if f.scripts.OnUpdate and f:IsVisible() then f:Fire("OnUpdate", step) end
		end
	end
end

function W.press(window, key)
	window:Fire("OnGamePadButtonDown", key)
	window:Fire("OnGamePadButtonUp", key)
end

function W.key(window, key) window:Fire("OnKeyDown", key) end

return W
