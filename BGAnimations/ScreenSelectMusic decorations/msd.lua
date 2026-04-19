local t = Def.ActorFrame {
	Name = "SongInfoBar",
	BeginCommand = function(self)
		self:visible(true)
	end,
	CurrentStepsChangedMessageCommand = function(self)
		-- lag begone
		-- this was borrewed from wifetwirl because someone was stupid enought to let everything update very quickly (not goodo) -ifwas
		local topscr = SCREENMAN:GetTopScreen()

		if fuckkkkkkkkkkkkkkkkkkk ~= nil then
			topscr:clearInterval(fuckkkkkkkkkkkkkkkkkkk)
			fuckkkkkkkkkkkkkkkkkkk = nil
		end
		fuckkkkkkkkkkkkkkkkkkk = topscr:setInterval(function()
			self:queuecommand("updateMeta")
			if fuckkkkkkkkkkkkkkkkkkk ~= nil then
				topscr:clearInterval(fuckkkkkkkkkkkkkkkkkkk)
				fuckkkkkkkkkkkkkkkkkkk = nil
			end
		end,
		0.045)
	end,
}

local frameX = 20
local frameWidth = capWideScale(get43size(400), 400)
-- Leaderboards start at y=103. Information bar spans from y=37 to y=103.
local barY = 70 
local barHeight = 66

-- 1. Banner Graphic (Underlying)
t[#t + 1] = Def.Sprite {
	Name = "Banner",
	InitCommand = function(self)
		self:xy(frameX, barY):halign(0):valign(0.5)
		self:scaletoclipped(frameWidth, barHeight)
	end,
	updateMetaCommand = function(self)
		self:finishtweening()
		local song = GAMESTATE:GetCurrentSong()
		local bnpath
		if song then
			bnpath = song:GetBannerPath()
			if not bnpath then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
		else
			local section = SCREENMAN:GetTopScreen():GetMusicWheel():GetSelectedSection()
			bnpath = SONGMAN:GetSongGroupBannerPath(section)
			if not bnpath or bnpath == "" then
				bnpath = THEME:GetPathG("Common", "fallback banner")
			end
		end
		
		if bnpath then
			self:visible(true)
			self:LoadBackground(bnpath)
			self:scaletoclipped(frameWidth, barHeight)
			
			if self:GetTexture() then
				local dominant = self:GetTexture():GetAverageColor(14)
				MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = dominant})
			end
		else
			self:visible(false)
		end
	end
}

-- 2. Dark Overlay for legibility
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(frameX, barY):zoomto(frameWidth, barHeight):halign(0):valign(0.5):diffuse(color("#000000")):diffusealpha(0.6)
	end
}

-- 3. Song Title
t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(frameX + 10, barY - 12):zoom(0.5):halign(0):diffuse(color("#FFFFFF"))
		self:maxwidth((frameWidth - 20) / 0.5)
	end,
	updateMetaCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:settext(song:GetDisplayMainTitle())
		else
			self:settext("")
		end
	end
}

-- 4. Pack Name
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameX + 10, barY + 12):zoom(0.4):halign(0):diffuse(color("#CCCCCC"))
		self:maxwidth((frameWidth - 20) / 0.4)
	end,
	updateMetaCommand = function(self)
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