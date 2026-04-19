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

-- Background for title area (top left)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(130, 65):zoomto(400, 130):halign(0):valign(0.5):diffuse(color("#000000")):diffusealpha(0.5)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.3)
	end
}

-- Song Title - top left
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

-- Pack/Artist info below title
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

-- Banner Graphic - below the text
t[#t + 1] = Def.Sprite {
	Name = "Banner",
	InitCommand = function(self)
		self:xy(140, 100):halign(0):valign(0.5)
		self:scaletoclipped(380, 50)
	end,
	SetCommand = function(self)
		self:finishtweening()
		local song = GAMESTATE:GetCurrentSong()
		local bnpath
		if song then
			bnpath = song:GetBannerPath()
			if not bnpath then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
		else
			bnpath = SONGMAN:GetSongGroupBannerPath(SCREENMAN:GetTopScreen():GetMusicWheel():GetSelectedSection())
			if not bnpath or bnpath == "" then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
		end
		
		if bnpath then
			self:visible(true)
			self:LoadBackground(bnpath)
			self:scaletoclipped(380, 50)
			
			if self:GetTexture() then
				local dominant = self:GetTexture():GetAverageColor(14)
				if dominant then
					MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = dominant})
				end
			end
		else
			self:visible(false)
		end
	end
}

return t
