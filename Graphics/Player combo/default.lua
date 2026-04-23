local allowedCustomization = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).CustomizeGameplay
local c
local enabledCombo = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).ComboText
local CenterCombo = true
local CTEnabled = ComboTweensEnabled()

-- Track judgments in real-time (GetTapNoteScore not available during gameplay)
local jdgTracker = {
	w1 = 0,
	w2 = 0,
	w3 = 0,
	w4 = 0,
	w5 = 0,
	miss = 0
}


local function numberZoom()
    return math.max((MovableValues.ComboZoom) - 0.1, 0)
end

local function labelZoom()
    return math.max(MovableValues.ComboZoom, 0)
end

--[[
	-- old Pulse function from [Combo]:
	%function(self,param) self:stoptweening(); self:zoom(1.1*param.Zoom); self:linear(0.05); self:zoom(param.Zoom); end
]]
local Pulse = function(self, param)
	self:stoptweening()
	self:zoom(1.125 * param.Zoom * numberZoom())
	self:linear(0.05)
	self:zoom(param.Zoom * numberZoom())
end
local PulseLabel = function(self, param)
	self:stoptweening()
	self:zoom(1.125 * param.LabelZoom * labelZoom())
	self:linear(0.05)
	self:zoom(param.LabelZoom * labelZoom())
end

local function arbitraryComboX(value)
	c.Label:x(value)
	if not CenterCombo then
		c.Number:x(value - 4)
	else
		c.Number:x(value - 24)
	end
	c.Border:x(value)
  end

local function arbitraryComboZoom(value)
	c.Label:zoom(value)
	c.Number:zoom(value - 0.1)
	if allowedCustomization then
		c.Border:playcommand("ChangeWidth", {val = c.Number:GetZoomedWidth() + c.Label:GetZoomedWidth()})
		c.Border:playcommand("ChangeHeight", {val = c.Number:GetZoomedHeight()})
	end
end

local ShowComboAt = THEME:GetMetric("Combo", "ShowComboAt")
local labelColor = getComboColor("ComboLabel")

-- Clear type colors for combo (matching the theme's clear type system)
local ctColors = colorConfig:get_data().clearType
local mfcColor = color(ctColors.MFC)
local wfColor = color(ctColors.WF)
local sdpColor = color(ctColors.SDP)
local pfcColor = color(ctColors.PFC)
local bfColor = color(ctColors.BF)
local sdgColor = color(ctColors.SDG)
local fcColor = color(ctColors.FC)
local mfColor = color(ctColors.MF)
local sdcbColor = color(ctColors.SDCB)
local clearColor = color(ctColors.Clear)

local translated_combo = THEME:GetString("ScreenGameplay", "ComboText")

local t = Def.ActorFrame {
	InitCommand = function(self)
		self:vertalign(bottom)
	end,
	LoadFont("Combo", "numbers") .. {
		Name = "Number",
		InitCommand = function(self)
			if not CenterCombo then
				self:halign(1):valign(1):skewx(-0.125)
				self:xy(MovableValues.ComboX - 4, MovableValues.ComboY)
				self:visible(false)
			else
				self:halign(0.5):valign(1):skewx(-0.125)
				self:xy(MovableValues.ComboX - 24, MovableValues.ComboY)
				self:visible(false)
			end
		end
	},
	LoadFont("Common Normal") .. {
		Name = "Label",
		InitCommand = function(self)
			self:halign(0):valign(1)
			self:xy(MovableValues.ComboX, MovableValues.ComboY)
			self:diffusebottomedge(color("0.75,0.75,0.75,1"))
			self:visible(false)
		end
	},
	InitCommand = function(self)
		c = self:GetChildren()
		if (allowedCustomization) then
			Movable.DeviceButton_3.element = c
			Movable.DeviceButton_4.element = c
			Movable.DeviceButton_3.condition = enabledCombo
			Movable.DeviceButton_4.condition = enabledCombo
			Movable.DeviceButton_3.Border = self:GetChild("Border")
			Movable.DeviceButton_3.DeviceButton_left.arbitraryFunction = arbitraryComboX
			Movable.DeviceButton_3.DeviceButton_right.arbitraryFunction = arbitraryComboX
			Movable.DeviceButton_4.DeviceButton_up.arbitraryFunction = arbitraryComboZoom
			Movable.DeviceButton_4.DeviceButton_down.arbitraryFunction = arbitraryComboZoom
		end
	end,
	OnCommand = function(self)
		-- Reset judgment tracker for new song
		jdgTracker.w1 = 0
		jdgTracker.w2 = 0
		jdgTracker.w3 = 0
		jdgTracker.w4 = 0
		jdgTracker.w5 = 0
		jdgTracker.miss = 0
		if (allowedCustomization) then
			c.Number:visible(true)
			c.Number:settext(1000)
			c.Label:visible(false) -- Permanently removed
			c.Label:settext(translated_combo)

			Movable.DeviceButton_3.propertyOffsets = {self:GetTrueX() -6, self:GetTrueY()}	-- centered to screen/valigned
			setBorderAlignment(c.Border, 0.5, 1)
		end
		arbitraryComboZoom(MovableValues.ComboZoom)
	end,
	ComboCommand = function(self, param)
		local iCombo = param.Combo
		if not iCombo or iCombo < ShowComboAt then
			c.Number:visible(false)
			c.Label:visible(false)
			return
		end

		c.Number:visible(true)
		c.Number:settext(iCombo)
		c.Label:visible(false) -- Permanently removed

		-- Color based on tracked judgment counts (updated via JudgmentMessageCommand)
		local misscount = jdgTracker.w4 + jdgTracker.w5 + jdgTracker.miss
		local greatcount = jdgTracker.w3
		local perfcount = jdgTracker.w2
		local w1count = jdgTracker.w1

		if misscount > 0 then
			if misscount == 1 then
				-- MF: Miss Flag (1 miss/bad/shit)
				c.Number:diffuse(mfColor)
			elseif misscount > 1 and misscount < 10 then
				-- SDCB: Single Digit Combo Break (2-9 misses)
				c.Number:diffuse(sdcbColor)
			else
				-- Clear: 10+ misses (use white)
				c.Number:diffuse(color("#FFFFFF"))
			end
		else
			-- No misses
			if greatcount == 0 then
				-- No misses, no greats - check perfects for MFC/WF/SDP/PFC
				if perfcount == 0 and w1count > 0 then
					-- MFC: Only W1s (no perfects, no greats, no misses)
					c.Number:diffuse(mfcColor)
				elseif perfcount == 1 then
					-- WF: White Flag (1 perfect, rest W1s)
					c.Number:diffuse(wfColor)
				elseif perfcount > 1 and perfcount < 10 then
					-- SDP: Single Digit Perfects (2-9 perfects)
					c.Number:diffuse(sdpColor)
				else
					-- PFC: Perfect Full Combo (10+ perfects, no greats, no misses)
					c.Number:diffuse(pfcColor)
				end
			else
				-- No misses but has greats - check for BF/SDG/FC
				if greatcount == 1 then
					-- BF: Black Flag (1 great, any perfects, no misses)
					c.Number:diffuse(bfColor)
				elseif greatcount > 1 and greatcount < 10 then
					-- SDG: Single Digit Greats (2-9 greats)
					c.Number:diffuse(sdgColor)
				else
					-- FC: Full Combo (10+ greats, no misses)
					c.Number:diffuse(fcColor)
				end
			end
		end

		-- Animations
		if CTEnabled then
			local lb = 0.9
			local ub = 1.1
			local maxcombo = 100
			param.LabelZoom = scale( iCombo, 0, maxcombo, lb, ub )
			param.LabelZoom = clamp( param.LabelZoom, lb, ub )
			param.Zoom = scale( iCombo, 0, maxcombo, lb, ub )
			param.Zoom = clamp( param.Zoom, lb, ub )
			Pulse(c.Number, param)
			PulseLabel(c.Label, param)
		end
	end,
	JudgmentMessageCommand = function(self, params)
		-- Track judgments for combo color calculation
		if params.HoldNoteScore then return end -- Ignore holds
		if params.TapNoteScore then
			local tns = params.TapNoteScore
			if tns == "TapNoteScore_W1" then
				jdgTracker.w1 = jdgTracker.w1 + 1
			elseif tns == "TapNoteScore_W2" then
				jdgTracker.w2 = jdgTracker.w2 + 1
			elseif tns == "TapNoteScore_W3" then
				jdgTracker.w3 = jdgTracker.w3 + 1
			elseif tns == "TapNoteScore_W4" then
				jdgTracker.w4 = jdgTracker.w4 + 1
			elseif tns == "TapNoteScore_W5" then
				jdgTracker.w5 = jdgTracker.w5 + 1
			elseif tns == "TapNoteScore_Miss" then
				jdgTracker.miss = jdgTracker.miss + 1
			end
		end
	end,
	MovableBorder(0, 0, 1, MovableValues.ComboX, MovableValues.ComboY),
}

if enabledCombo then
	return t
end

return Def.ActorFrame {}
