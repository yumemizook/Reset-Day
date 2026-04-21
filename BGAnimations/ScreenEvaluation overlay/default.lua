local t = Def.ActorFrame {}
t[#t + 1] = LoadActor("../_frame")

translated_info = {
	Replay = THEME:GetString("ScreenEvaluation", "ReplayTitle")
}

local function formatSessionTime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

local function getDisplayName()
	if DLMAN:IsLoggedIn() then
		return DLMAN:GetUsername()
	end
	local profile = GetPlayerOrMachineProfile(PLAYER_1)
	if profile then
		local name = profile:GetDisplayName()
		if name ~= "" then
			return name
		end
	end
	return "Guest"
end

local function getStepHeaderText()
	local steps = GAMESTATE:GetCurrentSteps()
	local style = GAMESTATE:GetCurrentStyle()
	if not steps then return "" end
	local columns = style and style:ColumnsPerPlayer() or 4
	local diff = getDifficulty(steps:GetDifficulty())
	return string.format("%dK %s %d", columns, getShortDifficulty(diff), steps:GetMeter())
end

local function getPackCreditText()
	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps()
	if not song then return "" end
	local group = song:GetGroupName() or "Unknown group"
	local credit = steps and steps:GetAuthorCredit() or ""
	if credit ~= "" then
		return string.format("From %s · Charted by %s", group, credit)
	end
	return string.format("From %s", group)
end

local function getCurrentScore()
	local score = SCOREMAN:GetMostRecentScore()
	if not score then
		score = SCOREMAN:GetTempReplayScore()
	end
	return score
end

local function scaleToJudge(scale)
	scale = notShit.round(scale or ms.JudgeScalers[GetTimingDifficulty()], 2)
	local scales = ms.JudgeScalers
	local out = 4
	for k, v in pairs(scales) do
		if v == scale then
			out = k
		end
	end
	if out < 4 then out = 4 end
	if out > 9 then out = 9 end
	return out
end

local function getDisplayedJudgeLabel()
	local top = SCREENMAN:GetTopScreen()
	local judge = GetTimingDifficulty()
	if top and top.GetReplayJudge then
		judge = scaleToJudge(top:GetReplayJudge())
	end
	local js = judge ~= 9 and judge or "ustice"
	return "Wife3 J" .. js
end

local function getCurrentRateRecordScore(score)
	if not score then return nil end
	local scoreTable = getScoresByKey(PLAYER_1)
	if not scoreTable then return nil end
	local rateTable = getRateTable(scoreTable) or {}
	local currentRateTable = rateTable[getRate(score)] or {}
	return currentRateTable[1]
end

local function getDisplayedPercentText(score)
	if not score then return "-" end
	local percent = score:GetWifeScore() * 100
	if percent > 99 then
		return string.format("%05.4f%%", percent)
	end
	return string.format("%05.2f%%", percent)
end

local function getRecordLabel(score)
	local recordScore = getCurrentRateRecordScore(score)
	if not recordScore then return "" end
	if recordScore == score and score == SCOREMAN:GetMostRecentScore() then
		return "New record!"
	end
	local recordPercent = recordScore:GetWifeScore() * 100
	if recordPercent > 99 then
		return string.format("Your record: %05.4f%%", recordPercent)
	end
	return string.format("Your record: %05.2f%%", recordPercent)
end

local function getClearTypeText(score)
	if not score then return "-" end
	return getClearTypeFromScore(PLAYER_1, score, 0)
end

local function getClearTypeColor(score)
	if not score then return color("#FFFFFF") end
	return getClearTypeFromScore(PLAYER_1, score, 2)
end

local function getClearRecordLabel(score)
	local recordScore = getCurrentRateRecordScore(score)
	if not recordScore then return "" end
	if recordScore == score and score == SCOREMAN:GetMostRecentScore() then
		return "New record!"
	end
	return "Your record: " .. getClearTypeFromScore(PLAYER_1, recordScore, 0)
end

local function isLivePlay()
	local top = SCREENMAN:GetTopScreen()
	if not top or not top.GetStageStats then return false end
	local ss = top:GetStageStats()
	return ss and ss:GetLivePlay()
end

local function continueToSongSelect()
	local top = SCREENMAN:GetTopScreen()
	if top then
		top:Cancel()
	end
end

local function retryCurrentChart()
	if not isLivePlay() then return end
	SCREENMAN:SetNewScreen("ScreenGameplay")
end

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "SongTitleHeader",
	InitCommand = function(self)
		self:xy(10, 10):halign(0):valign(0):zoom(0.65):diffuse(color("#FFFFFF"))
		self:maxwidth(900)
		self:settext("")
	end,
	OnCommand = function(self)
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:settext(song:GetDisplayMainTitle() .. (song:GetDisplaySubTitle() ~= "" and " - " .. song:GetDisplaySubTitle() or ""))
		end
	end,
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "StepInfoHeader",
	InitCommand = function(self)
		self:xy(10, 42):halign(0):valign(0):zoom(0.4):maxwidth(760)
	end,
	BeginCommand = function(self)
		self:queuecommand("Set"):diffuse(color("#FFFFFF"))
	end,
	SetCommand = function(self)
		self:settext(getStepHeaderText())
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "PackCreditHeader",
	InitCommand = function(self)
		self:xy(10, 60):halign(0):valign(0):zoom(0.3):maxwidth(900)
		self:diffuse(color("#FFFFFF"))
	end,
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		self:settext(getPackCreditText())
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "EvalPlayerName",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 10, 8):halign(1):valign(0):zoom(0.4)
		self:diffuse(getMainColor("positive"))
	end,
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		self:settext(" " .. getDisplayName())
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "EvalClock",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 10, 36):halign(1):valign(0):zoom(0.36)
		self:diffuse(color("#FFFFFF"))
	end,
	UpdateCommand = function(self)
		self:settext(os.date("%m/%d/%Y %I:%M:%S %p"))
		self:sleep(1):queuecommand("Update")
	end,
	OnCommand = function(self)
		self:queuecommand("Update")
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	Name = "EvalSessionTime",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 10, 58):halign(1):valign(0):zoom(0.28)
		self:diffuse(color("#FFFFFF"))
	end,
	UpdateCommand = function(self)
		local profile = GetPlayerOrMachineProfile(PLAYER_1)
		local sessionSeconds = profile and profile:GetTotalSessionSeconds() or 0
		self:settextf("Current session: %s", formatSessionTime(sessionSeconds))
		self:sleep(1):queuecommand("Update")
	end,
	OnCommand = function(self)
		self:queuecommand("Update")
	end
}

t[#t + 1] = Def.ActorFrame {
	Name = "EvalTopCards",
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 505, 75)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(100, 70):halign(0):valign(0):diffuse(color("#202020")):diffusealpha(0.88)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 46):zoomto(100, 24):halign(0):valign(0):diffuse(color("#25d0ff")):diffusealpha(0.35)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:diffuse(score and getGradeColor(score:GetWifeGrade()) or color("#FFFFFF"))
				self:diffusealpha(0.35)
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(50, 22):halign(0.5):valign(0.5):zoom(0.85)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:settext(score and getGradeStrings(score:GetWifeGrade()) or "-")
				self:diffuse(score and getGradeColor(score:GetWifeGrade()) or color("#FFFFFF"))
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
	},
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 395, 75)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(210, 70):halign(0):valign(0):diffuse(color("#202020")):diffusealpha(0.88)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 46):zoomto(210, 24):halign(0):valign(0):diffuse(color("#25d0ff")):diffusealpha(0.35)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:diffuse(score and getGradeColor(score:GetWifeGrade()) or color("#FFFFFF"))
				self:diffusealpha(0.35)
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(105, 22):halign(0.5):valign(0.5):zoom(0.7)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:settext(getDisplayedPercentText(score))
				self:diffuse(score and getGradeColor(score:GetWifeGrade()) or color("#FFFFFF"))
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(105, 58):halign(0.5):valign(0.5):zoom(0.26):diffuse(color("#FFFFFF"))
				self:maxwidth(200 / 0.26)
			end,
			SetCommand = function(self)
				self:settext(getRecordLabel(getCurrentScore()))
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
	},
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 175, 75)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(165, 70):halign(0):valign(0):diffuse(color("#202020")):diffusealpha(0.88)
			end,
		},
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 46):zoomto(165, 24):halign(0):valign(0):diffuse(color("#25d0ff")):diffusealpha(0.35)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:diffuse(getClearTypeColor(score))
				self:diffusealpha(0.35)
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(82.5, 22):halign(0.5):valign(0.5):zoom(0.7)
				self:maxwidth(160 / 0.7)
			end,
			SetCommand = function(self)
				local score = getCurrentScore()
				self:settext(getClearTypeText(score))
				self:diffuse(getClearTypeColor(score))
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(82.5, 58):halign(0.5):valign(0.5):zoom(0.26):diffuse(color("#FFFFFF"))
				self:maxwidth(160 / 0.26)
			end,
			SetCommand = function(self)
				self:settext(getClearRecordLabel(getCurrentScore()))
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		},
	},
}

t[#t + 1] = Def.ActorFrame {
	Name = "EvalFooterActions",
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(374, SCREEN_HEIGHT - 31):zoomto(150, 24):halign(0):valign(0):diffuse(color("#1c1f26")):diffusealpha(0.88)
		end,
		MouseOverCommand = function(self) self:diffusealpha(1) end,
		MouseOutCommand = function(self) self:diffusealpha(0.88) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				MESSAGEMAN:Broadcast("ToggleCustomWindows")
			end
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(75, 12):halign(0.5):valign(0.5):zoom(0.4):settext("Graph settings")
			end,
		}
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(536, SCREEN_HEIGHT - 31):zoomto(150, 24):halign(0):valign(0):diffuse(color("#1c1f26")):diffusealpha(0.88)
		end,
		MouseOverCommand = function(self) self:diffusealpha(1) end,
		MouseOutCommand = function(self) self:diffusealpha(0.88) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				MESSAGEMAN:Broadcast("ToggleEvalScoreBoard")
			end
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(75, 12):halign(0.5):valign(0.5):zoom(0.4):settext("Chart actions")
			end,
		}
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(698, SCREEN_HEIGHT - 31):zoomto(150, 24):halign(0):valign(0):diffuse(color("#1c1f26")):diffusealpha(0.88)
		end,
		MouseOverCommand = function(self) self:diffusealpha(1) end,
		MouseOutCommand = function(self) self:diffusealpha(0.88) end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(75, 12):halign(0.5):valign(0.5):zoom(0.4):settext("Watch replay")
			end,
		}
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(860, SCREEN_HEIGHT - 31):zoomto(154, 24):halign(0):valign(0):diffuse(color("#1c1f26")):diffusealpha(0.88)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(77, 12):halign(0.5):valign(0.5):zoom(0.4)
			end,
			SetCommand = function(self)
				self:settext(getDisplayedJudgeLabel())
			end,
			BeginCommand = function(self) self:queuecommand("Set") end,
			ScoreChangedMessageCommand = function(self) self:queuecommand("Set") end,
		}
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(728, 349):zoomto(132, 24):halign(0):valign(0):diffuse(color("#285b7c")):diffusealpha(0.92)
		end,
		BeginCommand = function(self) self:visible(isLivePlay()) end,
		MouseOverCommand = function(self) self:diffusealpha(1) end,
		MouseOutCommand = function(self) self:diffusealpha(0.92) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				retryCurrentChart()
			end
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(66, 12):halign(0.5):valign(0.5):zoom(0.45):settext("Retry")
			end,
		}
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(872, 349):zoomto(142, 24):halign(0):valign(0):diffuse(color("#285b7c")):diffusealpha(0.92)
		end,
		BeginCommand = function(self) self:visible(isLivePlay()) end,
		MouseOverCommand = function(self) self:diffusealpha(1) end,
		MouseOutCommand = function(self) self:diffusealpha(0.92) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				continueToSongSelect()
			end
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(71, 12):halign(0.5):valign(0.5):zoom(0.45):settext("Continue")
			end,
		}
	},
}

t[#t + 1] = LoadActor("../_cursor")

return t
