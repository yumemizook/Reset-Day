local t = Def.ActorFrame {}
local topFrameHeight = 35
local bottomFrameHeight = 35
local borderWidth = 4
local hoverAlpha = 0.6
local showVisualizer = themeConfig:get_data().global.ShowVisualizer
local frameVisualizerColor = color("#FFFFFF")

local function frameVisualizer(y, maxHeight, alpha)
	local vis = audioVisualizer:new {
		x = 0,
		y = y,
		width = SCREEN_WIDTH,
		maxHeight = maxHeight,
		freqIntervals = audioVisualizer.multiplyIntervals(audioVisualizer.defaultIntervals, 4),
		color = frameVisualizerColor,
		onBarUpdate = function(self)
			self:diffuse(frameVisualizerColor):diffusealpha(alpha)
		end
	}
	local oldInitCommand = vis.InitCommand
	vis.InitCommand = function(self)
		if oldInitCommand then
			oldInitCommand(self)
		end
		self:draworder(50)
	end
	return vis
end

local function headerVisualizer()
	return frameVisualizer(topFrameHeight, topFrameHeight - 4, 0.65)
end

local function footerVisualizer()
	return frameVisualizer(SCREEN_HEIGHT - 1, bottomFrameHeight - 3, 0.4)
end

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

local function footerButton(x, text, icon, cmd)
	return UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(x, SCREEN_HEIGHT - bottomFrameHeight / 2):zoom(0.45):halign(0)
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
		self:xy(0, 0):halign(0):valign(0):zoomto(SCREEN_WIDTH, topFrameHeight):diffuse(getMainColor("frames")):diffusealpha(0.6)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.6)
	end
}

if showVisualizer then
	t[#t + 1] = headerVisualizer()
end

-- Footer Background (Solid Underlay)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT - bottomFrameHeight):zoomto(SCREEN_WIDTH, bottomFrameHeight):halign(0):valign(0):diffuse(color("#000000"))
	end
}

-- Accent Color Overlay (Semi-transparent)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(0, SCREEN_HEIGHT - bottomFrameHeight):zoomto(SCREEN_WIDTH, bottomFrameHeight):halign(0):valign(0):diffuse(color("#111111")):diffusealpha(0.6)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.6)
	end
}

if showVisualizer then
	t[#t + 1] = footerVisualizer()
end

-- Song Information (Marquee Text)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(175, SCREEN_HEIGHT - bottomFrameHeight / 2)
	end,

	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.45):halign(0):diffuse(color("#FFFFFF"))
		end,
		SetCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			local str = "None"
			if song then
				local title = song:GetDisplayMainTitle()
				local artist = song:GetDisplayArtist()
				str = title .. " - " .. artist
				
				if HandleSongChangeForHistory then
					HandleSongChangeForHistory()
				end
			else
				str = "MUSIC PLAYER: NONE"
			end

			-- Reset state and set text
			self:stoptweening():x(0)
			self:settext(str .. "    ") -- Get width of one instance + padding
			local singleWidth = self:GetZoomedWidth()
			self:settext(str .. "    " .. str .. "    ") -- Double it for seamless loop
			
			-- Start the seamless scroll
			local scrollTime = singleWidth / 30 -- Speed: 30 pixels per second
			
			local function marquee(self)
				self:x(0):linear(scrollTime):x(-singleWidth):queuecommand("MarqueeSnap")
			end
			self:queuecommand("MarqueeSnap")
		end,
		MarqueeSnapCommand = function(self)
			-- Snapping back to 0 creates the seamless loop
			local str = self:GetText()
			local singleWidth = self:GetZoomedWidth() / 2
			local scrollTime = singleWidth / 30
			self:x(0):linear(scrollTime):x(-singleWidth):queuecommand("MarqueeSnap")
		end,
		OnCommand = function(self) self:playcommand("Set") end,
		CurrentSongChangedMessageCommand = function(self) self:playcommand("Set") end,
	}
}

-- Clipping Covers (These are OPAQUE black to 100% hide the text overflow)
-- Then the Accent Overlay (if we want it on top) or just same color?
-- Let's put these AFTER the text but BEFORE the accent overlay?
-- No, they should be OPAQUE.

local function clippingCover(x, width)
	return Def.ActorFrame {
		Def.Quad { -- Opaque Base to hide text
			InitCommand = function(self)
				self:xy(x, SCREEN_HEIGHT - bottomFrameHeight):zoomto(width, bottomFrameHeight):halign(0):valign(0):diffuse(color("#000000"))
			end
		},
		Def.Quad { -- Matching tint
			InitCommand = function(self)
				self:xy(x, SCREEN_HEIGHT - bottomFrameHeight):zoomto(width, bottomFrameHeight):halign(0):valign(0):diffuse(color("#111111")):diffusealpha(0.6)
			end,
			SetDynamicAccentColorMessageCommand = function(self, params)
				self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.6)
			end
		}
	}
end

t[#t + 1] = clippingCover(0, 175) -- Left cover
t[#t + 1] = clippingCover(425, SCREEN_WIDTH - 425) -- Right cover
 
 -- Header Buttons
 t[#t + 1] = headerButton(10, "", "≡", function() MESSAGEMAN:Broadcast("ToggleMenu") end)
 t[#t + 1] = headerButton(40, "Options", "⚙", function() SCREENMAN:SetNewScreen("ScreenOptionsService") end)
 t[#t + 1] = headerButton(115, "Upload All", "�", function()
	if DLMAN:IsLoggedIn() then
		DLMAN:UploadAllScores()
	else
		ms.ok("You must be logged in...")
	end
end)
 t[#t + 1] = headerButton(210, "Stats", "📈", function() MESSAGEMAN:Broadcast("ToggleStatsOverlay") end)
 
 -- Footer Elements (Drawn on top of covers)
 -- Back Button
 t[#t + 1] = footerButton(10, "Back", "⇽", function() SCREENMAN:GetTopScreen():Cancel() end)

-- Music Player Controls
t[#t + 1] = footerButton(80, "", "|<<", function() 
	if SongHistory and SongHistory.GetPrevious then
		local prev = SongHistory.GetPrevious()
		if prev then
			local top = SCREENMAN:GetTopScreen()
			if top and top.GetMusicWheel then
				top:GetMusicWheel():SelectSong(prev)
			end
		end
	end
end) .. {
	MusicHistoryChangedMessageCommand = function(self)
		if SongHistory and #SongHistory.stack > 1 then
			self:diffuse(color("#FFFFFF")):diffusealpha(1)
		else
			self:diffuse(color("#666666")):diffusealpha(0.6)
		end
	end,
	OnCommand = function(self) self:playcommand("MusicHistoryChanged") end
}

local isPaused = false
t[#t + 1] = footerButton(110, "", "||", function() 
	local top = SCREENMAN:GetTopScreen()
	if top and top.PauseSampleMusic then
		top:PauseSampleMusic()
		MESSAGEMAN:Broadcast("MusicPauseToggled")
	end
end) .. {
	MusicPauseToggledMessageCommand = function(self)
		isPaused = not isPaused
		self:settext(isPaused and "▶" or "||")
	end
}

t[#t + 1] = footerButton(135, "", ">>|", function() 
	if SelectRandomSong then
		SelectRandomSong()
	end
end)

-- System Information (Version and Time)
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 10, SCREEN_HEIGHT - bottomFrameHeight / 2)
	end,
	
	-- Version
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(-8):zoom(0.35):halign(1)
			self:settext("Etterna " .. ProductVersion())
		end
	},
	
	-- Time
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(6):zoom(0.35):halign(1)
		end,
		UpdateCommand = function(self)
			self:settext(os.date("%d/%m/%Y %I:%M:%S %p"))
			self:sleep(1):queuecommand("Update")
		end,
		OnCommand = function(self) self:queuecommand("Update") end
	}
}

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
