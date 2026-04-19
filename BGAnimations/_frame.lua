local t = Def.ActorFrame {}
local topFrameHeight = 35
local bottomFrameHeight = 54
local borderWidth = 4
local hoverAlpha = 0.6

local function headerButton(x, text, icon, cmd)
	return UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(x, topFrameHeight / 2):zoom(0.45):halign(0)
			self:settext(icon .. " " .. text)
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				cmd()
			end
		end
	}
end

--Frames
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:xy(0, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH, topFrameHeight):diffuse(getMainColor("frames"))
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.6)
	end
}

t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT):halign(0):valign(1):zoomto(SCREEN_WIDTH, bottomFrameHeight):diffuse(getMainColor("frames"))
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.6)
	end
}

-- Header Buttons
t[#t + 1] = headerButton(10, "", "≡", function() MESSAGEMAN:Broadcast("ToggleMenu") end)
t[#t + 1] = headerButton(40, "Options", "⚙", function() SCREENMAN:GetTopScreen():OpenOptions() end)
t[#t + 1] = headerButton(115, "Import", "📥", function() SCREENMAN:SetNewScreen("ScreenPackDownloader") end)
t[#t + 1] = headerButton(185, "Stats", "📈", function() SCREENMAN:SetNewScreen("ScreenProfileStats") end)

-- Profile/Login area (Handled by _PlayerInfo.lua now to avoid overlap)
--[[
t[#t + 1] = UIElements.QuadButton(1, 1) .. {
	Name = "LoginArea",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 80, topFrameHeight / 2):zoomto(150, topFrameHeight - 8):diffuse(color("#22CC66")):diffusealpha(0.8)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.8)
	end,
	MouseDownCommand = function(self, params)
		if params.event == "DeviceButton_left mouse button" then
			if not DLMAN:IsLoggedIn() then
				SCREENMAN:AddNewScreenToTop("ScreenSMOnlineLogin")
			end
		end
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 80, topFrameHeight / 2):zoom(0.45)
	end,
	UpdateLoginStatusCommand = function(self)
		if DLMAN:IsLoggedIn() then
			self:settext("👤 " .. DLMAN:GetUsername())
		else
			self:settext("🌐 Not logged in")
		end
	end,
	BeginCommand = function(self) self:playcommand("UpdateLoginStatus") end,
	DLMANLoginMessageCommand = function(self) self:playcommand("UpdateLoginStatus") end,
	DLMANLogoutMessageCommand = function(self) self:playcommand("UpdateLoginStatus") end
}
]]


--FrameBorders
t[#t + 1] = Def.Quad {
	Name = "TopBorder",
	InitCommand = function(self)
		self:xy(0, topFrameHeight):halign(0):valign(1):zoomto(SCREEN_WIDTH, borderWidth):diffuse(getMainColor("highlight")):diffusealpha(
			0.5
		)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.5)
	end
}

t[#t + 1] = Def.Quad {
	Name = "BottomBorder",
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT - bottomFrameHeight):halign(0):valign(0):zoomto(SCREEN_WIDTH, borderWidth):diffuse(
			getMainColor("highlight")
		):diffusealpha(0.5)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.5)
	end
}

return t
