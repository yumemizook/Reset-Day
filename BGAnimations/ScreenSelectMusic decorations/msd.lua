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

t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX, frameY):zoom(0.7):halign(0):diffuse(getMainColor("positive"))
		self:maxwidth((SCREEN_WIDTH * 0.5) / 0.7)
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

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameX, frameY + 25):zoom(0.5):halign(0):diffuse(color("#CCCCCC"))
		self:maxwidth((SCREEN_WIDTH * 0.5) / 0.5)
	end,
	SetCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:settext(song:GetDisplayArtist())
		else
			self:settext("")
		end
	end
}

return t
