-- refactored a bit but still needs work -mina
local collapsed = false
local rtTable
local rates
local rateIndex = 1
local scoreIndex = 1
local score
local page = 1 -- Fix for leaderboard glitch
local pn = GAMESTATE:GetEnabledPlayers()[1]
local nestedTab = 1
local nestedTabs = {
	THEME:GetString("TabScore", "NestedLocal"),
	THEME:GetString("TabScore", "NestedOnline")
}
local hasReplayData
local currentAccentColor = nil

local frameX = 20
local frameY = 70
local frameWidth = SCREEN_WIDTH * 0.40
local frameHeight = 280
local fontScale = 0.35
local function getRelativeTime(dateStr)
	if not dateStr or dateStr == "" then return "" end
	local y, m, d, h, min, s = dateStr:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	if not y then return dateStr end
	local t = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
	local diff = os.time() - t
	if diff < 60 then return "just now"
	elseif diff < 3600 then return math.floor(diff/60) .. "m ago"
	elseif diff < 86400 then return math.floor(diff/3600) .. "h ago"
	elseif diff < 2592000 then return math.floor(diff/86400) .. "d ago"
	elseif diff < 31536000 then return math.floor(diff/2592000) .. "mo ago"
	else return math.floor(diff/31536000) .. "y ago" end
end

local offsetX = 15
local offsetY = 15
local netScoresPerPage = 8
local netScoresCurrentPage = 1
local nestedTabButtonWidth = 153
local nestedTabButtonHeight = 20
local netPageButtonWidth = 50
local netPageButtonHeight = 50
local headeroffY = 10

local selectedrateonly

local judges = {
	"TapNoteScore_W1",
	"TapNoteScore_W2",
	"TapNoteScore_W3",
	"TapNoteScore_W4",
	"TapNoteScore_W5",
	"TapNoteScore_Miss",
	"HoldNoteScore_Held",
	"HoldNoteScore_LetGo"
}

local translated_info = {
	MaxCombo = THEME:GetString("TabScore", "MaxCombo"),
	ComboBreaks = THEME:GetString("TabScore","ComboBreaks"),
	DateAchieved = THEME:GetString("TabScore", "DateAchieved"),
	Mods = THEME:GetString("TabScore", "Mods"),
	Rate = THEME:GetString("TabScore", "Rate"), -- used in conjunction with Showing
	Showing = THEME:GetString("TabScore", "Showing"), -- to produce a scuffed thing
	ChordCohesion = THEME:GetString("TabScore", "ChordCohesion"),
	Judge = THEME:GetString("TabScore", "ScoreJudge"),
	NoScores = THEME:GetString("TabScore", "NoScores"),
	NoChart = THEME:GetString("TabScore", "NoChart"),
	Yes = THEME:GetString("OptionNames", "Yes"),
	No = THEME:GetString("OptionNames", "No"),
	ShowOffset = THEME:GetString("TabScore", "ShowOffsetPlot"),
	NoReplayData = THEME:GetString("TabScore", "NoReplayData"),
	ShowReplay = THEME:GetString("TabScore", "ShowReplay"),
	ShowEval = THEME:GetString("TabScore", "ShowEval"),
	UploadReplay = THEME:GetString("TabScore", "UploadReplay"),
	UploadAllScoreChart=THEME:GetString("TabScore", "UploadAllScoreChart"),
	UploadAllScorePack=THEME:GetString("TabScore", "UploadAllScorePack"),
	UploadAllScore=THEME:GetString("TabScore", "UploadAllScore"),
	UploadingReplay = THEME:GetString("TabScore", "UploadingReplay"),
	UploadingScore = THEME:GetString("TabScore", "UploadingScore"),
	NotLoggedIn = THEME:GetString("GeneralInfo", "NotLoggedIn"),
    ValidateScore = THEME:GetString("TabScore", "ValidateScore"),
    ScoreValidated = THEME:GetString("TabProfile", "ScoreValidated"),
    InvalidateScore = THEME:GetString("TabScore", "InvalidateScore"),
    ScoreInvalidated = THEME:GetString("TabProfile", "ScoreInvalidated")
}

local defaultRateText = ""
if themeConfig:get_data().global.RateSort then
	defaultRateText = "1.0x"
else
	defaultRateText = "All"
end

local hoverAlpha = 0.6

local moped
-- Only works if ... it should work
-- You know, if we can see the place where the scores should be.
local function updateLeaderBoardForCurrentChart()
	local top = SCREENMAN:GetTopScreen()
	if top:GetName() == "ScreenSelectMusic" or top:GetName() == "ScreenNetSelectMusic" then
		if top:GetMusicWheel():IsSettled() and ((getTabIndex() == 2 and nestedTab == 2) or collapsed) then
			local steps = GAMESTATE:GetCurrentSteps()
			if steps then
				local leaderboardAttempt = DLMAN:GetChartLeaderBoard(steps:GetChartKey())
				if leaderboardAttempt ~= nil and #leaderboardAttempt > 0 then
					moped:playcommand("SetFromLeaderboard", leaderboardAttempt)
				elseif leaderboardAttempt ~= nil and #leaderboardAttempt == 0 then
					DLMAN:RequestChartLeaderBoardFromOnline(
						steps:GetChartKey(),
						function(leaderboard)
							moped:queuecommand("SetFromLeaderboard", leaderboard)
						end
					)
				else
					moped:queuecommand("SetFromLeaderboard", nil)
				end
			else
				moped:playcommand("SetFromLeaderboard", {})
			end
		end
	end
end

local ret = Def.ActorFrame {
	Name = "Scoretab",
	BeginCommand = function(self)
		moped = self:GetChild("ScoreDisplay")
		self:queuecommand("Set"):visible(true)
		-- Start with local scores visible, online hidden (default nestedTab = 1)
		self:GetChild("LocalScores"):xy(frameX, frameY):visible(true)
		moped:xy(frameX, frameY):visible(false)

		if FILTERMAN:oopsimlazylol() then -- set saved position and auto collapse (switch to online)
			nestedTab = 2
			self:GetChild("LocalScores"):visible(false)
			moped:xy(FILTERMAN:grabposx("Doot"), FILTERMAN:grabposy("Doot")):visible(true)
			self:playcommand("Collapse")
		end
	end,
	OffCommand = function(self)
		self:bouncebegin(0.2):xy(-500, 0):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
		self:GetChild("LocalScores"):visible(false)
		self:GetChild("ScoreDisplay"):visible(false)
	end,
	OnCommand = function(self)
		self:bouncebegin(0.2):xy(0, 0):diffusealpha(1)
		-- Default: show local (nestedTab = 1), hide online
		if getTabIndex() == 2 then
			if nestedTab == 1 then
				self:GetChild("LocalScores"):visible(true)
				self:GetChild("ScoreDisplay"):visible(false)
			else
				self:GetChild("LocalScores"):visible(false)
				self:GetChild("ScoreDisplay"):visible(true)
			end
		end
	end,
	SetCommand = function(self)
		self:finishtweening(1)
		local sd = self:GetParent():GetChild("StepsDisplay")
		if sd then sd:visible(false) end
		self:queuecommand("On")
		self:visible(true)
	end,
	TabChangedMessageCommand = function(self, params)
		self:queuecommand("Set")
		-- if tab was already visible, swap nested tabs
		if params ~= nil and params.from == 2 and params.to == 2 and self:GetVisible() and not collapsed then
			if nestedTab == 1 then nestedTab = 2 else nestedTab = 1 end
			local sd = self:GetParent():GetChild("StepsDisplay")
			self:GetChild("Button_1"):playcommand("NestedTabChanged")
			self:GetChild("Button_2"):playcommand("NestedTabChanged")
			if nestedTab == 1 then
				self:GetChild("ScoreDisplay"):visible(false)
				self:GetChild("LocalScores"):visible(true)
				sd:visible(true)
			else
				updateLeaderBoardForCurrentChart()
				self:GetChild("ScoreDisplay"):visible(true)
				self:GetChild("LocalScores"):visible(false)
				sd:visible(false)
			end
		end
		updateLeaderBoardForCurrentChart()
	end,
	ChangeStepsMessageCommand = function(self)
		self:queuecommand("Set")
		updateLeaderBoardForCurrentChart()
	end,
	CollapseCommand = function(self)
		collapsed = true
		local tind = getTabIndex()
		resetTabIndex()
		MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = 0})
	end,
	ExpandCommand = function(self)
		collapsed = false
		local tind = getTabIndex()
		if getTabIndex() ~= 2 then
			setTabIndex(2)
		end
		local after = getTabIndex()
		self:GetChild("ScoreDisplay"):xy(frameX, frameY)
		MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = after})
	end,
	DelayedChartUpdateMessageCommand = function(self)
		local leaderboardEnabled =
			playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).leaderboardEnabled and DLMAN:IsLoggedIn()
		if GAMESTATE:GetCurrentSteps() then
			local chartkey = GAMESTATE:GetCurrentSteps():GetChartKey()
			if leaderboardEnabled then
			DLMAN:RequestChartLeaderBoardFromOnline(
				chartkey,
				function(leaderboard)
					moped:playcommand("SetFromLeaderboard", leaderboard)
				end
			)	-- this is also intentionally super bad so we actually do something about it -mina
			elseif (SCREENMAN:GetTopScreen():GetName() == "ScreenSelectMusic" or SCREENMAN:GetTopScreen():GetName() == "ScreenNetSelectMusic") then
				DLMAN:RequestChartLeaderBoardFromOnline(
				chartkey,
				function(leaderboard)
					moped:playcommand("SetFromLeaderboard", leaderboard)
				end
			)
			end
		end
	end,
	NestedTabChangedMessageCommand = function(self)
		self:queuecommand("Set")
		-- Toggle visibility between local and online leaderboards
		if nestedTab == 1 then
			self:GetChild("LocalScores"):visible(true)
			self:GetChild("ScoreDisplay"):visible(false)
		else
			self:GetChild("LocalScores"):visible(false)
			self:GetChild("ScoreDisplay"):visible(true)
			updateLeaderBoardForCurrentChart()
		end
		-- Broadcast accent color to ensure both leaderboards have it
		if currentAccentColor then
			MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = currentAccentColor})
		end
	end,
	SwitchToLocalScoresMessageCommand = function(self)
		-- Handle request from online leaderboard to switch back to local
		nestedTab = 1
		self:GetChild("LocalScores"):visible(true)
		self:GetChild("ScoreDisplay"):visible(false)
		-- Update button text in LocalScores
		local btn = self:GetChild("LocalScores"):GetChild("YourScoresBtn")
		if btn then
			btn:settext("Your scores")
			btn:playcommand("Update")
		end
		-- Broadcast accent color to ensure visibility
		if currentAccentColor then
			MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = currentAccentColor})
		end
		MESSAGEMAN:Broadcast("NestedTabChanged")
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		-- Store the current accent color for later use
		if params and params.color then
			currentAccentColor = params.color
		end
	end,
	CodeMessageCommand = function(self, params) -- this is intentionally bad to remind me to fix other things that are bad -mina
		if ((getTabIndex() == 2 and nestedTab == 2) and not collapsed) and DLMAN:GetCurrentRateFilter() then
			local rate = getCurRateValue()
			if params.Name == "PrevScore" and rate < MAX_MUSIC_RATE - 0.05 then
				GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(rate + 0.1)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(rate + 0.1)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(rate + 0.1)
				MESSAGEMAN:Broadcast("CurrentRateChanged")
			elseif params.Name == "NextScore" and rate > MIN_MUSIC_RATE + 0.05 then
				GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(rate - 0.1)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(rate - 0.1)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(rate - 0.1)
				MESSAGEMAN:Broadcast("CurrentRateChanged")
			end
			if params.Name == "PrevRate" and rate < MAX_MUSIC_RATE then
				GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(rate + 0.05)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(rate + 0.05)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(rate + 0.05)
				MESSAGEMAN:Broadcast("CurrentRateChanged")
			elseif params.Name == "NextRate" and rate > MIN_MUSIC_RATE then
				GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(rate - 0.05)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Song"):MusicRate(rate - 0.05)
				GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(rate - 0.05)
				MESSAGEMAN:Broadcast("CurrentRateChanged")
			end
		end
	end,
	CurrentRateChangedMessageCommand = function(self)
		if ((getTabIndex() == 2 and nestedTab == 2) or collapsed) and DLMAN:GetCurrentRateFilter() then
			moped:queuecommand("GetFilteredLeaderboard")
		end
	end
}

local cheese
-- eats only inputs that would scroll to a new score
local function input(event)
	if isOver(cheese:GetChild("FrameDisplay")) then
		if event.DeviceInput.button == "DeviceButton_mousewheel up" and event.type == "InputEventType_FirstPress" then
			moving = true
			if nestedTab == 1 and rtTable and rtTable[rates[rateIndex]] ~= nil then
				cheese:queuecommand("PrevScore")
				return true
			end
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" and event.type == "InputEventType_FirstPress" then
			if nestedTab == 1 and rtTable ~= nil and rtTable[rates[rateIndex]] ~= nil then
				cheese:queuecommand("NextScore")
				return true
			end
		elseif moving == true then
			moving = false
		end
	end
	return false
end

local t = Def.ActorFrame {
	Name = "LocalScores",
	InitCommand = function(self)
		rtTable = nil
		cheese = self
	end,
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	OnCommand = function(self)
		if nestedTab == 1 and self:IsVisible() then
			if GAMESTATE:GetCurrentSong() ~= nil then
				rtTable = getRateTable()
				if rtTable ~= nil then
					rates, rateIndex = getUsedRates(rtTable)
					scoreIndex = 1
					page = 1
					self:queuecommand("Display")
				else
					self:queuecommand("Init")
				end
			else
				self:queuecommand("Init")
			end
		end
	end,
	NestedTabChangedMessageCommand = function(self)
		self:visible(nestedTab == 1)
		page = 1
		self:queuecommand("Set")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:playcommand("On")
		if rtTable == nil or #rtTable == 0 or rates == nil or #rates == 0 or rates[rateIndex] == nil or rtTable[rates[rateIndex]] == nil then
			return
		end
		self:playcommand("Display")
	end,
	CodeMessageCommand = function(self, params)
		if nestedTab == 1 and rtTable ~= nil and rtTable[rates[rateIndex]] ~= nil then
			if params.Name == "NextRate" then
				self:queuecommand("NextRate")
			elseif params.Name == "PrevRate" then
				self:queuecommand("PrevRate")
			elseif params.Name == "NextScore" then
				self:queuecommand("NextScore")
			elseif params.Name == "PrevScore" then
				self:queuecommand("PrevScore")
			end
		end
	end,
	NextRateCommand = function(self)
		rateIndex = ((rateIndex) % (#rates)) + 1
		scoreIndex = 1
		self:queuecommand("Display")
	end,
	PrevRateCommand = function(self)
		rateIndex = ((rateIndex - 2) % (#rates)) + 1
		scoreIndex = 1
		self:queuecommand("Display")
	end,
	NextScoreCommand = function(self)
		scoreIndex = ((scoreIndex) % (#rtTable[rates[rateIndex]])) + 1
		self:queuecommand("Display")
	end,
	PrevScoreCommand = function(self)
		scoreIndex = ((scoreIndex - 2) % (#rtTable[rates[rateIndex]])) + 1
		self:queuecommand("Display")
	end,
	DisplayCommand = function(self)
		score = rtTable[rates[rateIndex]][scoreIndex]
		hasReplayData = score:HasReplayData()
		setScoreForPlot(score)
	end,
	Def.Quad {
		Name = "FrameDisplay",
		InitCommand = function(self)
			self:zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(getMainColor("tabs"))
		end,
		SetDynamicAccentColorMessageCommand = function(self, params)
			self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.8)
		end,
		CollapseCommand = function(self)
			self:visible(false)
		end,
		ExpandCommand = function(self)
			self:visible(true)
		end
	}
}

-- header bar
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:zoomto(frameWidth, 30):halign(0):valign(0):diffuse(getMainColor("frames")):diffusealpha(0.8)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.8)
	end,
}

local function topBarButton(name, x, width, text, cmd, activeFunc)
	return UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = name,
		InitCommand = function(self)
			self:xy(x, 15):zoom(0.45):halign(0.5):settext(text)
		end,
		UpdateCommand = function(self)
			if activeFunc and activeFunc() then
				self:diffuse(getMainColor("highlight"))
			else
				self:diffuse(getMainColor("positive"))
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				cmd()
				MESSAGEMAN:Broadcast("TopBarUpdate")
			end
		end,
		TopBarUpdateMessageCommand = function(self) self:playcommand("Update") end,
		NestedTabChangedMessageCommand = function(self)
			if name == "YourScoresBtn" then
				if nestedTab == 1 then
					self:settext("Your scores")
				else
					self:settext("Online Scores")
				end
			end
			self:playcommand("Update")
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
	}
end

t[#t + 1] = topBarButton("YourScoresBtn", 50, 100, "Your scores", function() 
	nestedTab = (nestedTab == 1) and 2 or 1 
	MESSAGEMAN:Broadcast("NestedTabChanged")
end, function() return nestedTab == 1 end)

t[#t + 1] = topBarButton("PerformanceBtn", 150, 100, "Performance", function()
	-- Sort logic
end, function() return true end)

t[#t + 1] = topBarButton("FilterBtn", 250, 100, "No filter", function()
	-- Rate filter logic
end, function() return true end)

local l = Def.ActorFrame {
	-- stuff inside the frame.. so we can move it all at once
	InitCommand = function(self)
		self:xy(offsetX, offsetY + headeroffY)
	end,
	-- Score rows
	(function()
		local rows = Def.ActorFrame {}
		for i = 1, 10 do
			local score
			rows[#rows + 1] = Def.ActorFrame {
				Name = "ScoreRow" .. i,
				InitCommand = function(self)
					self:y(20 + (i-1) * 28)
				end,
				DisplayCommand = function(self)
					if rtTable and rates and rates[rateIndex] and rtTable[rates[rateIndex]] then
						score = rtTable[rates[rateIndex]][i + (page - 1) * 10]
						if score then
							self:visible(true)
							self:playcommand("SetScore")
						else
							self:visible(false)
						end
					else
						self:visible(false)
					end
				end,
				-- Date
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:zoom(fontScale):halign(0)
					end,
					SetScoreCommand = function(self)
						self:settext(getRelativeTime(score:GetDate()))
					end
				},
				-- Wife% - show 4 decimal places for high scores
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(80):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						local perc = score:GetWifeScore() * 100
						if perc > 99.65 then
							self:settextf("%.4f%%", perc):diffuse(getGradeColor(score:GetWifeGrade()))
						else
							self:settextf("%.2f%%", perc):diffuse(getGradeColor(score:GetWifeGrade()))
						end
					end
				},
				-- ClearType
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(145):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						self:settext(getClearTypeFromScore(PLAYER_1, score, 0)):diffuse(getClearTypeFromScore(PLAYER_1, score, 2))
					end
				},
				-- MSD (chart difficulty)
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(200):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						local steps = GAMESTATE:GetCurrentSteps()
						if steps then
							local msd = steps:GetMSD(score:GetMusicRate(), 1)
							self:settextf("%.2f", msd):diffuse(byMSD(msd))
						else
							self:settext("--")
						end
					end
				},
				-- Rate
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(260):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						self:settextf("%.2fx", score:GetMusicRate())
					end
				}
			}
		end
		return rows
	end)(),
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 15 - offsetY):zoom(0.5):halign(1)
			if GAMESTATE:GetCurrentSteps() == nil then
				self:settext(translated_info["NoChart"])
			else
				self:settext(translated_info["NoScores"])
			end
		end,
		DisplayCommand = function(self)
			self:settextf("%s %s - %s %d/%d", translated_info["Rate"], rates[rateIndex], translated_info["Showing"], scoreIndex, #rtTable[rates[rateIndex]])
			self:zoom(0.4)
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				MESSAGEMAN:Broadcast("Code", {Name = "NextScore"})
			elseif params.event == "DeviceButton_right mouse button" then
				MESSAGEMAN:Broadcast("Code", {Name = "PrevScore"})
			end
		end,
	},
	LoadFont("Common Normal") .. {
		Name = "Judge",
		InitCommand = function(self)
			self:xy(frameX + offsetX + 55,frameHeight - headeroffY - 65 - offsetY):zoom(0.45):halign(0.5):settext("")
		end,
		DisplayCommand = function(self)
			local j = table.find(ms.JudgeScalers, notShit.round(score:GetJudgeScale(), 2))
			if not j then j = 4 end
			if j < 4 then j = 4 end
			self:settextf("%s %i", translated_info["Judge"], j)
		end
	},
	LoadFont("Common Normal") .. {
		Name = "ChordCohesion",
		InitCommand = function(self)
			self:xy(frameX + offsetX + 55,frameHeight - headeroffY - 50 - offsetY):zoom(0.4):halign(0.5):settext("")
		end,
		DisplayCommand = function(self)
			if score:GetChordCohesion() then
				self:settextf("%s: %s", translated_info["ChordCohesion"], translated_info["Yes"])
				self:diffuse(1,0,0,1)
			else
				self:settextf("%s: %s", translated_info["ChordCohesion"], translated_info["No"])
				self:diffuse(1,1,1,1)
			end
		end
	},
}

local function makeText(index)
	return UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth - frameX, offsetY + 100 + (index * 15)):zoom(fontScale + 0.05):halign(1):settext("")
		end,
		DisplayCommand = function(self)
			local count = 0
			if rtTable[rates[index]] ~= nil then
				count = #rtTable[rates[index]]
			end
			if index <= #rates then
				self:settextf("%s (%d)", rates[index], count)
				if index == rateIndex then
					self:diffuse(color("#FFFFFF"))
				else
					self:diffuse(getMainColor("positive"))
				end
			else
				self:settext("")
			end
		end,
		MouseOverCommand = function(self)
			if index ~= rateIndex then
				self:diffusealpha(hoverAlpha)
			end
		end,
		MouseOutCommand = function(self)
			if index ~= rateIndex then
				self:diffusealpha(1)
			end
		end,
		MouseDownCommand = function(self, params)
			if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
				rateIndex = index
				scoreIndex = 1
				self:GetParent():queuecommand("Display")
			end
		end
	}
end

for i = 1, 9 do
	t[#t + 1] = makeText(i)
end

local function makeJudge(index, judge)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:y(129 + ((index - 1) * 18))
		end
	}

	--labels
	t[#t + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:zoom(0.55):halign(0)
		end,
		BeginCommand = function(self)
			self:settext(getJudgeStrings(judge))
			self:diffuse(byJudgment(judge))
		end
	}

	t[#t + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(127):zoom(0.55):halign(1):settext("0")
		end,
		DisplayCommand = function(self)
			if judge ~= "HoldNoteScore_Held" and judge ~= "HoldNoteScore_LetGo" then
				self:settext(getScoreTapNoteScore(score, judge))
			else
				self:settext(getScoreHoldNoteScore(score, judge))
			end
		end
	}

	t[#t + 1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x(130):zoom(0.3):halign(0):settext("")
		end,
		DisplayCommand = function(self)
			if judge ~= "HoldNoteScore_Held" and judge ~= "HoldNoteScore_LetGo" then
				local taps = math.max(1, getMaxNotes(pn))
				local count = getScoreTapNoteScore(score, judge)
				self:settextf("(%03.2f%%)", (count / taps) * 100)
			else
				local holds = math.max(1, getMaxHolds(pn))
				local count = getScoreHoldNoteScore(score, judge)
				self:settextf("(%03.2f%%)", (count / holds) * 100)
			end
		end
	}

	return t
end

for i = 1, #judges do
	--l[#l + 1] = makeJudge(i, judges[i]) -- Hide judges to condense UI
end

l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "Score",
	InitCommand = function(self)
		self:y(frameHeight - headeroffY - 31 - offsetY):zoom(0.55):halign(0):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
		if hasReplayData then
			self:settext(translated_info["ShowOffset"])
		else
			self:settext("")
		end
	end,
	MouseOverCommand = function(self)
		if hasReplayData then
			self:diffusealpha(hoverAlpha)
		end
	end,
	MouseOutCommand = function(self)
		if hasReplayData then
			self:diffusealpha(1)
		end
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and getScoreForPlot() and hasReplayData and isOver(self) then
				SCREENMAN:AddNewScreenToTop("ScreenScoreTabOffsetPlot")
			end
		end
	end,
}
l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "ReplayViewer",
	InitCommand = function(self)
		self:y(frameHeight - headeroffY - 15 - offsetY):zoom(0.55):halign(0):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	BeginCommand = function(self)
		if SCREENMAN:GetTopScreen():GetName() == "ScreenNetSelectMusic" then
			self:visible(false)
		end
	end,
	DisplayCommand = function(self)
		if hasReplayData then
			self:settext(translated_info["ShowReplay"])
			self:diffuse(getMainColor("positive")):zoom(0.55)
		else
			self:settext(translated_info["NoReplayData"])
			self:diffuse(1,1,1,1):zoom(0.4)
		end
	end,
	MouseOverCommand = function(self)
		if hasReplayData then
			self:diffusealpha(hoverAlpha)
		end
	end,
	MouseOutCommand = function(self)
		if hasReplayData then
			self:diffusealpha(1)
		end
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and getScoreForPlot() and hasReplayData and isOver(self) then
				SCREENMAN:GetTopScreen():PlayReplay(score)
			end
		end
	end
}
l[#l + 1] = Def.ActorFrame {
	InitCommand = function(self)
		if not IsUsingWideScreen() then --offset it a bit if not using widescreen
			self:x(6):y(37):zoom(0.9)
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		Name = "EvalViewQuad",
		InitCommand = function(self)
			self:xy((frameWidth - offsetX - frameX) / 2.1, frameHeight - headeroffY - 17 - offsetY):diffuse(0,0,0,0)
			self:zoomtowidth(145):zoomtoheight(21)
		end,
		BeginCommand = function(self)
			if SCREENMAN:GetTopScreen():GetName() == "ScreenNetSelectMusic" then
				self:visible(false)
			end
		end,
		DisplayCommand = function(self)
			if hasReplayData then
				self:diffusealpha(0.3)
			else
				self:diffusealpha(0)
			end
		end,
		MouseOverCommand = function(self)
			self:GetParent():GetChild("EvalViewer"):diffusealpha(0.6)
		end,
		MouseOutCommand = function(self)
			self:GetParent():GetChild("EvalViewer"):diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
				if getTabIndex() == 2 and getScoreForPlot() and hasReplayData and isOver(self) then
					SCREENMAN:GetTopScreen():ShowEvalScreenForScore(score)
				end
			end
		end,
	},
	LoadFont("Common Large") .. {
		Name = "EvalViewer",
		InitCommand = function(self)
			self:xy((frameWidth - offsetX - frameX) / 2.1, frameHeight - headeroffY - 18 - offsetY):zoom(0.35):settext("")
			self:diffuse(getMainColor("positive"))
		end,
		BeginCommand = function(self)
			if SCREENMAN:GetTopScreen():GetName() == "ScreenNetSelectMusic" then
				self:visible(false)
			end
		end,
		DisplayCommand = function(self)
			if hasReplayData then
				self:settext(translated_info["ShowEval"])
			else
				self:settext("")
			end
		end,
	},
}

l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "TheDootButton",
	InitCommand = function(self)
		self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 35 - offsetY):zoom(0.525):halign(1):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
		self:settext(translated_info["UploadReplay"])
	end,
	MouseOverCommand = function(self)
		self:diffusealpha(hoverAlpha)
	end,
	MouseOutCommand = function(self)
		self:diffusealpha(1)
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and isOver(self) and DLMAN:IsLoggedIn() then
				DLMAN:SendReplayDataForOldScore(score:GetScoreKey())
				ms.ok(translated_info["UploadingReplay"]) --should have better feedback -mina
			elseif getTabIndex() == 2 and isOver(self) and not DLMAN:IsLoggedIn() then
				ms.ok(translated_info["NotLoggedIn"])
			end
		end
	end
}
l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "TheDootButtonTWO",
	InitCommand = function(self)
		self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 49 - offsetY):zoom(0.425):halign(1):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
		self:settext(translated_info["UploadAllScoreChart"])
	end,
	MouseOverCommand = function(self)
		self:diffusealpha(hoverAlpha)
	end,
	MouseOutCommand = function(self)
		self:diffusealpha(1)
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and isOver(self) and DLMAN:IsLoggedIn() then
				DLMAN:UploadScoresForChart(score:GetChartKey())
			elseif getTabIndex() == 2 and isOver(self) and not DLMAN:IsLoggedIn() then
				ms.ok(translated_info["NotLoggedIn"])
			end
		end
	end
}
l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "TheDootButtonTHREEEEEEEE",
	InitCommand = function(self)
		self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 63 - offsetY):zoom(0.425):halign(1):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
		self:settext(translated_info["UploadAllScorePack"])
	end,
	MouseOverCommand = function(self)
		self:diffusealpha(hoverAlpha)
	end,
	MouseOutCommand = function(self)
		self:diffusealpha(1)
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and isOver(self) and DLMAN:IsLoggedIn() then
				DLMAN:UploadScoresForPack(GAMESTATE:GetCurrentSong():GetGroupName())
			elseif getTabIndex() == 2 and isOver(self) and not DLMAN:IsLoggedIn() then
				ms.ok(translated_info["NotLoggedIn"])
			end
		end
	end
}
l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "TheDootButtonFOUR",
	InitCommand = function(self)
		self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 77 - offsetY):zoom(0.425):halign(1):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
		self:settext(translated_info["UploadAllScore"])
	end,
	MouseOverCommand = function(self)
		self:diffusealpha(hoverAlpha)
	end,
	MouseOutCommand = function(self)
		self:diffusealpha(1)
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and isOver(self) and DLMAN:IsLoggedIn() then
				DLMAN:UploadAllScores()
			elseif getTabIndex() == 2 and isOver(self) and not DLMAN:IsLoggedIn() then
				ms.ok(translated_info["NotLoggedIn"])
			end
		end
	end
}
l[#l + 1] = UIElements.TextToolTip(1, 1, "Common Normal") .. {
	Name = "ValidateInvalidateScoreButton",
	InitCommand = function(self)
		self:xy(frameWidth - offsetX - frameX, frameHeight - headeroffY - 91 - offsetY):zoom(0.425):halign(1):settext("")
		self:diffuse(getMainColor("positive"))
	end,
	DisplayCommand = function(self)
        if score:GetEtternaValid() then
            self:settext(translated_info["InvalidateScore"])
        else
            self:settext(translated_info["ValidateScore"])
        end
	end,
	MouseOverCommand = function(self)
		self:diffusealpha(hoverAlpha)
	end,
	MouseOutCommand = function(self)
		self:diffusealpha(1)
	end,
	MouseDownCommand = function(self, params)
		if nestedTab == 1 and params.event == "DeviceButton_left mouse button" then
			if getTabIndex() == 2 and isOver(self) then
                score:ToggleEtternaValidation()
                MESSAGEMAN:Broadcast("UpdateRanking")
				if score:GetEtternaValid() then
					ms.ok(translated_info["ScoreValidated"])
                    self:settext(translated_info["InvalidateScore"])
                else
                    ms.ok(translated_info["ScoreInvalidated"])
                    self:settext(translated_info["ValidateScore"])
				end
			end
		end
	end
}
t[#t + 1] = l

t[#t + 1] = Def.Quad {
	Name = "ScrollBar",
	InitCommand = function(self)
		self:x(frameWidth):zoomto(4, 0):halign(1):valign(1):diffuse(getMainColor("highlight")):diffusealpha(0.75)
	end,
	DisplayCommand = function(self)
		self:finishtweening()
		self:smooth(0.15)
		self:zoomy(((frameHeight - offsetY) / #rtTable[rates[rateIndex]]))
		self:y((((frameHeight - offsetY) / #rtTable[rates[rateIndex]]) * scoreIndex) + offsetY)
	end
}

ret[#ret + 1] = t

local function nestedTabButton(i)
	return Def.ActorFrame {
		Name = "Button_"..i,
		InitCommand = function(self)
			self:xy(frameX + offsetX/2 + (i - 1) * (nestedTabButtonWidth - capWideScale(100, 80)), frameY + offsetY - 4)
			-- Only show if on Scores tab
			self:visible(getTabIndex() == 2)
		end,
		TabChangedMessageCommand = function(self)
			self:visible(getTabIndex() == 2)
		end,
		CollapseCommand = function(self)
			self:visible(false)
		end,
		ExpandCommand = function(self)
			self:visible(getTabIndex() == 2)
		end,
		UIElements.TextToolTip(1, 1, "Common Normal") .. {
			InitCommand = function(self)
				self:diffuse(getMainColor("positive")):maxwidth(nestedTabButtonWidth - 80):maxheight(40):zoom(0.65)
				self:settext(nestedTabs[i])
				self:halign(0):valign(1)
				self.hoverDiffusefunction = function(self)
					local inTabNotHovered = 1
					local offTabNotHovered = 0.6
					local offTabHovered = 0.8
					local inTabHovered = 0.6
					if isOver(self) then
						if nestedTab == i then
							self:diffusealpha(inTabHovered)
						else
							self:diffusealpha(offTabHovered)
						end
					else
						if nestedTab == i then
							self:diffusealpha(inTabNotHovered)
						else
							self:diffusealpha(offTabNotHovered)
						end
					end
				end
				self:hoverDiffusefunction()
			end,
			MouseOverCommand = function(self)
				self:hoverDiffusefunction()
			end,
			MouseOutCommand = function(self)
				self:hoverDiffusefunction()
			end,
			NestedTabChangedMessageCommand = function(self)
				self:hoverDiffusefunction()
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					nestedTab = i
					MESSAGEMAN:Broadcast("NestedTabChanged")
					if nestedTab == 1 then
						self:GetParent():GetParent():GetChild("ScoreDisplay"):visible(false)
						self:GetParent():GetParent():GetParent():GetChild("StepsDisplay"):visible(true)
					else
						self:GetParent():GetParent():GetChild("ScoreDisplay"):visible(true)
						self:GetParent():GetParent():GetParent():GetChild("StepsDisplay"):visible(false)
					end
				end
			end
		}
	}
end

-- online score display
ret[#ret + 1] = LoadActor("../superscoreboard")

for i = 1, #nestedTabs do
	ret[#ret + 1] = nestedTabButton(i)
end

return ret
