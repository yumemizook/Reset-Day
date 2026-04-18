local t = Def.ActorFrame {
	Name = "SongInfoBar",
	BeginCommand = function(self)
		self:visible(true)
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end
}

local frameX = 20
local frameY = 15

-- Background for title area (top left) - matching screenshot
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(130, 50):zoomto(400, 60):halign(0):valign(0.5):diffuse(color("#000000")):diffusealpha(0.5)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.3)
	end
}

-- Song Title - top left like screenshot
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(140, 40):zoom(0.6):halign(0):diffuse(color("#FFFFFF"))
		self:maxwidth(380 / 0.6)
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:settext(song:GetDisplayMainTitle())
		else
			self:settext("")
		end
	end
}

-- Pack/Artist info below title - top left like screenshot
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(140, 65):zoom(0.4):halign(0):diffuse(color("#CCCCCC"))
		self:maxwidth(380 / 0.4)
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			local group = song:GetGroupName()
			self:settext("🔗 " .. group)
		else
			self:settext("")
		end
	end
}

return t
