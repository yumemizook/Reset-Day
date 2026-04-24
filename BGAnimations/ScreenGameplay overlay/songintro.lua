-- Song intro overlay showing background and banner
-- Displays for a few seconds when gameplay starts

local t = Def.ActorFrame {
	Name = "SongIntroOverlay",
	InitCommand = function(self)
		self:diffusealpha(0)
	end,
	OnCommand = function(self)
		self:sleep(0.1):smooth(0.3):diffusealpha(1):sleep(2.5):smooth(0.5):diffusealpha(0):queuecommand("DestroyMe")
	end,
	DestroyMeCommand = function(self)
		self:visible(false)
	end
}

-- Get target goal info
local targetGoal = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetGoal
local targetTrackerMode = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).TargetTrackerMode

-- Dark background overlay
local bgEnabled = PREFSMAN:GetPreference("ShowBackgrounds")

if bgEnabled then
	-- Song background (full opacity)
	t[#t + 1] = Def.Sprite {
		Name = "SongBackground",
		InitCommand = function(self)
			self:FullScreen():diffusealpha(0)
		end,
		BeginCommand = function(self)
			if GAMESTATE:GetCurrentSong() and GAMESTATE:GetCurrentSong():GetBackgroundPath() then
				self:LoadBackground(GAMESTATE:GetCurrentSong():GetBackgroundPath())
				self:scaletocover(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
				self:diffusealpha(1)
			else
				self:visible(false)
			end
		end
	}
end

-- Darken overlay (lighter for better visibility)
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:FullScreen():diffuse(Color.Black):diffusealpha(0.3)
	end
}

-- Center container for banner and text
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:Center()
	end,

	-- Banner background frame
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(320, 140):diffuse(Color.Black):diffusealpha(0.8)
		end
	},

	-- Song banner
	Def.Sprite {
		Name = "SongBanner",
		InitCommand = function(self)
			self:y(-10):zoomto(300, 0):diffusealpha(0)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:LoadFromCached("Banner", song:GetBannerPath())
				self:zoomto(300, 94)
				self:diffusealpha(1)
			else
				self:visible(false)
			end
		end
	},

	-- Song title
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:y(55):zoom(0.4):maxwidth(750):diffusealpha(0)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				self:settext(song:GetDisplayMainTitle())
				self:diffusealpha(1)
			end
		end
	},

	-- Song artist/subtitle
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:y(72):zoom(0.35):maxwidth(850):diffusealpha(0)
		end,
		BeginCommand = function(self)
			local song = GAMESTATE:GetCurrentSong()
			if song then
				local subtitle = song:GetDisplaySubTitle()
				local artist = song:GetDisplayArtist()
				local text = "";
				if subtitle and subtitle ~= "" then
					text = subtitle
					if artist and artist ~= "" then
						text = text .. " - " .. artist
					end
				elseif artist and artist ~= "" then
					text = artist
				end
				self:settext(text)
				self:diffusealpha(1)
			end
		end
	},

	-- Target Goal display
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:y(92):zoom(0.35):maxwidth(600):diffusealpha(0)
		end,
		BeginCommand = function(self)
			local targetText = ""
			local targetPercent = nil
			
			if targetTrackerMode == 0 then
				-- Set percent mode - use the configured target
				targetPercent = targetGoal
			else
				-- PB mode - get actual PB for current chart/rate
				local steps = GAMESTATE:GetCurrentSteps()
				local song = GAMESTATE:GetCurrentSong()
				if steps and song then
					local chartKey = steps:GetChartKey()
					local rate = GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate()
					local scoresByRate = SCOREMAN:GetScoresByKey(chartKey)
					if scoresByRate then
						local x = "x"
						for r, scoreList in pairs(scoresByRate) do
							local rr = r:gsub("["..x.."]+", "")
							if math.abs(tonumber(rr) - rate) < 0.001 then
								local scores = scoreList:GetScores()
								if scores and #scores > 0 then
									local pbScore = scores[1]
									targetPercent = pbScore:GetWifeScore() * 100
								end
								break
							end
						end
					end
				end
				-- Fallback to target goal if no PB found
				if not targetPercent then
					targetPercent = targetGoal
				end
			end
			
			targetText = string.format("Target: %.2f%%", targetPercent)
			self:settext(targetText)
			self:diffuse(getMainColor("positive"))
			self:diffusealpha(1)
		end
	}
}

return t
