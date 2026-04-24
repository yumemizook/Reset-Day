-- refactored a bit but still needs work -mina
local collapsed = false
local rtTable
local scoreIndex = 1
local score
local page = 1 -- Fix for leaderboard glitch
local scoreOffset = 0 -- offset for scrolling through the list
local pn = GAMESTATE:GetEnabledPlayers()[1]
local nestedTab = 1
local nestedTabs = {
	THEME:GetString("TabScore", "NestedLocal"),
	THEME:GetString("TabScore", "NestedOnline"),
	"Skillsets"
}
local hasReplayData
local currentAccentColor = nil

local frameX = 20
local frameY = 103
local frameWidth = capWideScale(get43size(400), 400)
local frameHeight = 196
local fontScale = 0.45
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

local offsetX = 7
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

local function getNestedTabButtonText()
	if nestedTab == 1 then
		return "Your scores"
	elseif nestedTab == 2 then
		return "Leaderboard"
	end
	return "Skillsets"
end

local function broadcastNestedTabChanged()
	MESSAGEMAN:Broadcast("NestedTabChanged", {tab = nestedTab})
end

local function cycleNestedTab()
	nestedTab = (nestedTab % 3) + 1
	broadcastNestedTabChanged()
end

local function getCurrentRateScores()
	if not rtTable then return nil end
	local currentRate = notShit.round(getCurRateValue(), 2)
	for rateKey, scores in pairs(rtTable) do
		local numericRate = tonumber((tostring(rateKey):gsub("x", "")))
		if numericRate and math.abs(notShit.round(numericRate, 2) - currentRate) < 0.001 then
			return scores
		end
	end
	return nil
end

local leaderboardSortModes = {"accuracy", "ssr", "time"}

local function getLeaderboardSortMode()
	local stored = getenv("MusicSelectLeaderboardSortMode")
	for _, mode in ipairs(leaderboardSortModes) do
		if stored == mode then
			return mode
		end
	end
	return "accuracy"
end

local function getLeaderboardSortModeLabel()
	local mode = getLeaderboardSortMode()
	if mode == "ssr" then
		return "SSR"
	elseif mode == "time" then
		return "Time"
	end
	return "Accuracy"
end

local function setLeaderboardSortMode(mode)
	setenv("MusicSelectLeaderboardSortMode", mode)
	MESSAGEMAN:Broadcast("MusicSelectLeaderboardSortChanged", {mode = mode})
end

local function cycleLeaderboardSortMode()
	local currentMode = getLeaderboardSortMode()
	for index, mode in ipairs(leaderboardSortModes) do
		if mode == currentMode then
			setLeaderboardSortMode(leaderboardSortModes[(index % #leaderboardSortModes) + 1])
			return
		end
	end
	setLeaderboardSortMode(leaderboardSortModes[1])
end

local function getLocalCurrentRateOnly()
	local stored = getenv("MusicSelectLocalCurrentRateOnly")
	if stored == nil then
		return true
	end
	return stored == true
end

local function getLocalRateFilterLabel()
	if getLocalCurrentRateOnly() then
		return "Current Rate"
	end
	return "All rates"
end

local function toggleLocalRateFilter()
	local currentRateOnly = not getLocalCurrentRateOnly()
	setenv("MusicSelectLocalCurrentRateOnly", currentRateOnly)
	MESSAGEMAN:Broadcast("MusicSelectLocalRateFilterChanged", {currentRateOnly = currentRateOnly})
end

local function getScoreDateValue(scoreObject)
	if not scoreObject then return 0 end
	local dateStr = scoreObject:GetDate()
	if not dateStr or dateStr == "" then return 0 end
	local y, m, d, h, min, s = dateStr:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	if not y then return 0 end
	return os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(h), min=tonumber(min), sec=tonumber(s)}) or 0
end

local function getScoreOverallSsr(scoreObject)
	if not scoreObject then return 0 end
	return scoreObject:GetSkillsetSSR("Overall") or 0
end

local function getAllRateScores()
	if not rtTable then return nil end
	local scores = {}
	for _, rateScores in pairs(rtTable) do
		for i = 1, #rateScores do
			scores[#scores + 1] = rateScores[i]
		end
	end
	return scores
end

local function getSortedScoreCopy(scores)
	if not scores then return nil end
	local sortedScores = {}
	for i = 1, #scores do
		sortedScores[i] = scores[i]
	end
	table.sort(sortedScores, function(left, right)
		if not left then return false end
		if not right then return true end
		local mode = getLeaderboardSortMode()
		local leftAcc = left:GetWifeScore() or 0
		local rightAcc = right:GetWifeScore() or 0
		local leftSsr = getScoreOverallSsr(left)
		local rightSsr = getScoreOverallSsr(right)
		local leftDate = getScoreDateValue(left)
		local rightDate = getScoreDateValue(right)
		if mode == "ssr" then
			if leftSsr == rightSsr then
				if leftAcc == rightAcc then
					return leftDate > rightDate
				end
				return leftAcc > rightAcc
			end
			return leftSsr > rightSsr
		elseif mode == "time" then
			if leftDate == rightDate then
				if leftAcc == rightAcc then
					return leftSsr > rightSsr
				end
				return leftAcc > rightAcc
			end
			return leftDate > rightDate
		end
		if leftAcc == rightAcc then
			if leftSsr == rightSsr then
				return leftDate > rightDate
			end
			return leftSsr > rightSsr
		end
		return leftAcc > rightAcc
	end)
	return sortedScores
end

local function getDisplayedScores()
	if getLocalCurrentRateOnly() then
		return getSortedScoreCopy(getCurrentRateScores())
	end
	return getSortedScoreCopy(getAllRateScores())
end

local moped
-- Only works if ... it should work
-- You know, if we can see the place where the scores should be.
local ret = Def.ActorFrame {
	Name = "Scoretab",
	BeginCommand = function(self)
		self:queuecommand("Set"):visible(true)
		self:GetChild("LocalScores"):xy(frameX, frameY):visible(true)
	end,
	OffCommand = function(self)
		self:bouncebegin(0.2):xy(-500, 0):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
		self:GetChild("LocalScores"):visible(false)
	end,
	OnCommand = function(self)
		self:bouncebegin(0.2):xy(0, 0):diffusealpha(1)
		if getTabIndex() == 2 then
			self:GetChild("LocalScores"):visible(true)
		end
	end,
	SetCommand = function(self)
		self:finishtweening(1)
		local sd = self:GetParent():GetChild("StepsDisplay")
		if sd then sd:visible(false) end
		self:queuecommand("On")
		self:visible(true)
	end,
	ChangeStepsMessageCommand = function(self)
		self:queuecommand("Set")
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
		-- Toggle visibility between local scores and shared leaderboard/skillset container
		if nestedTab == 1 then
			self:GetChild("LocalScores"):visible(true)
			if moped then moped:visible(false) end
		else
			self:GetChild("LocalScores"):visible(false)
			if moped then
				moped:visible(true)
				if nestedTab == 2 then
					moped:playcommand("GetFilteredLeaderboard")
				else
					moped:playcommand("Update")
				end
			end
		end
		-- Broadcast accent color to ensure both leaderboards have it
		if currentAccentColor then
			MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = currentAccentColor})
		end
	end,
	CycleNestedScoreViewMessageCommand = function(self)
		cycleNestedTab()
	end,
	SwitchToLocalScoresMessageCommand = function(self)
		-- Handle request from online leaderboard to switch back to local
		nestedTab = 1
		self:GetChild("LocalScores"):visible(true)
		if moped then moped:visible(false) end
		-- Update button text in LocalScores
		local btn = self:GetChild("LocalScores"):GetChild("YourScoresBtn")
		if btn then
			btn:settext(getNestedTabButtonText())
			btn:playcommand("Update")
		end
		-- Broadcast accent color to ensure visibility
		if currentAccentColor then
			MESSAGEMAN:Broadcast("SetDynamicAccentColor", {color = currentAccentColor})
		end
		broadcastNestedTabChanged()
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		-- Store the current accent color for later use
		if params and params.color then
			currentAccentColor = params.color
		end
	end,
	CodeMessageCommand = function(self, params) -- this is intentionally bad to remind me to fix other things that are bad -mina
		if (getTabIndex() == 2 and nestedTab == 2) and not collapsed then
			if params.Name == "PrevRate" or params.Name == "NextRate" or params.Name == "PrevScore" or params.Name == "NextScore" then
				return
			end
		end
	end,
	CurrentRateChangedMessageCommand = function(self)
		if (getTabIndex() == 2 and nestedTab == 2) or collapsed then
			if moped then
				moped:queuecommand("GetFilteredLeaderboard")
			end
		end
	end
}

local cheese
-- eats only inputs that would scroll to a new score
local function input(event)
	if isOver(cheese:GetChild("FrameDisplay")) then
		local displayedScores = getDisplayedScores()
		if event.DeviceInput.button == "DeviceButton_mousewheel up" and event.type == "InputEventType_FirstPress" then
			if nestedTab == 1 and displayedScores ~= nil then
				scoreOffset = math.max(0, scoreOffset - 1)
				cheese:playcommand("Display")
				return true
			end
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" and event.type == "InputEventType_FirstPress" then
			if nestedTab == 1 and displayedScores ~= nil then
				local maxOffset = math.max(0, #displayedScores - 5)
				scoreOffset = math.min(maxOffset, scoreOffset + 1)
				cheese:playcommand("Display")
				return true
			end
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
					scoreIndex = 1
					scoreOffset = 0
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
		scoreOffset = 0
		self:queuecommand("Set")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		rtTable = getRateTable()
		scoreIndex = 1
		scoreOffset = 0
		self:playcommand("On")
		self:playcommand("Display")
	end,
	CurrentRateChangedMessageCommand = function(self)
		if nestedTab == 1 then
			rtTable = getRateTable()
			scoreIndex = 1
			scoreOffset = 0
			self:playcommand("Display")
		end
	end,
	MusicSelectLeaderboardSortChangedMessageCommand = function(self)
		scoreIndex = 1
		scoreOffset = 0
		self:playcommand("Display")
	end,
	MusicSelectLocalRateFilterChangedMessageCommand = function(self)
		scoreIndex = 1
		scoreOffset = 0
		self:playcommand("Display")
	end,
	CodeMessageCommand = function(self, params)
		local displayedScores = getDisplayedScores()
		if nestedTab == 1 and displayedScores ~= nil then
			if params.Name == "NextScore" then
				self:queuecommand("NextScore")
			elseif params.Name == "PrevScore" then
				self:queuecommand("PrevScore")
			end
		end
	end,
	NextScoreCommand = function(self)
		local displayedScores = getDisplayedScores()
		if displayedScores ~= nil then
			scoreIndex = ((scoreIndex) % (#displayedScores)) + 1
			self:queuecommand("Display")
		end
	end,
	PrevScoreCommand = function(self)
		local displayedScores = getDisplayedScores()
		if displayedScores ~= nil then
			scoreIndex = ((scoreIndex - 2) % (#displayedScores)) + 1
			self:queuecommand("Display")
		end
	end,
	DisplayCommand = function(self)
		local displayedScores = getDisplayedScores()
		if displayedScores ~= nil then
			scoreIndex = math.min(math.max(scoreIndex, 1), #displayedScores)
			scoreOffset = math.min(math.max(scoreOffset, 0), math.max(0, #displayedScores - 5))
			score = displayedScores[scoreIndex]
			if score then
				hasReplayData = score:HasReplayData()
				setScoreForPlot(score)
			else
				score = nil
				hasReplayData = false
			end
		else
			score = nil
			hasReplayData = false
		end
	end,
	Def.Quad {
		Name = "FrameDisplay",
		InitCommand = function(self)
			self:zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(getMainColor("tabs"))
			-- Apply stored accent color if it exists
			if currentAccentColor then
				self:diffuse(currentAccentColor):diffusealpha(0.8)
			end
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
			if name == "YourScoresBtn" then
				self:settext(getNestedTabButtonText())
			elseif name == "PerformanceBtn" then
				self:settext(getLeaderboardSortModeLabel())
			elseif name == "FilterBtn" then
				self:settext(getLocalRateFilterLabel())
			end
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
			self:playcommand("Update")
		end,
		MusicSelectLeaderboardSortChangedMessageCommand = function(self)
			self:playcommand("Update")
		end,
		MusicSelectLocalRateFilterChangedMessageCommand = function(self)
			self:playcommand("Update")
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
	}
end

t[#t + 1] = topBarButton("YourScoresBtn", frameWidth * 0.2, 100, "Your scores", function() 
	cycleNestedTab()
end, function() return nestedTab == 1 end)

t[#t + 1] = topBarButton("PerformanceBtn", frameWidth * 0.5, 100, "Accuracy", function()
	cycleLeaderboardSortMode()
end, function() return true end)

t[#t + 1] = topBarButton("FilterBtn", frameWidth * 0.8, 100, "Current Rate", function()
	toggleLocalRateFilter()
end, function() return true end)

local l = Def.ActorFrame {
	-- stuff inside the frame.. so we can move it all at once
	InitCommand = function(self)
		self:xy(offsetX, offsetY + headeroffY)
	end,
	-- Score rows
	(function()
		local rows = Def.ActorFrame {}
		local numScoresToDisplay = 5
		for i = 1, numScoresToDisplay do
			local score
			rows[#rows + 1] = Def.ActorFrame {
				Name = "ScoreRow" .. i,
				InitCommand = function(self)
					self:y(32 + (i - 1) * 28)
				end,
				-- Row Background
				Def.Quad {
					InitCommand = function(self)
						self:zoomto(frameWidth - 15, 24):halign(0):diffuse(color("#000000")):diffusealpha(0.2)
					end,
				},
					DisplayCommand = function(self)
					local displayedScores = getDisplayedScores()
					if displayedScores ~= nil then
						score = displayedScores[i + scoreOffset]
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
						self:zoom(fontScale):halign(0):x(5)
					end,
					SetScoreCommand = function(self)
						self:settext(getRelativeTime(score:GetDate()))
					end
				},
				-- Wife% - show 4 decimal places for high scores
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(frameWidth * 0.28):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						local perc = score:GetWifeScore() * 100
						
						local j = table.find(ms.JudgeScalers, notShit.round(score:GetJudgeScale(), 2))
						if not j then j = 4 end
						if j < 4 then j = 4 end
						local jStr = " [J" .. j .. "]"
						
						if perc >= 99.7 then
							self:settextf("%.4f%%%s", perc, jStr):diffuse(getGradeColor(score:GetWifeGrade()))
						else
							self:settextf("%.2f%%%s", perc, jStr):diffuse(getGradeColor(score:GetWifeGrade()))
						end
					end
				},
				-- ClearType
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(frameWidth * 0.52):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						self:settext(getClearTypeFromScore(PLAYER_1, score, 0)):diffuse(getClearTypeFromScore(PLAYER_1, score, 2))
					end
				},
				-- MSD (chart difficulty)
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(frameWidth * 0.75):zoom(fontScale):halign(0.5)
					end,
					SetScoreCommand = function(self)
						local ssr = score:GetSkillsetSSR("Overall")
						if ssr and ssr > 0 then
							self:settextf("%.2f", ssr):diffuse(byMSD(ssr))
						else
							self:settext("--")
						end
					end
				},
				-- Rate
				LoadFont("Common Normal") .. {
					InitCommand = function(self)
						self:x(frameWidth * 0.94):zoom(fontScale):halign(1)
					end,
					SetScoreCommand = function(self)
						self:settextf("%.2fx", score:GetMusicRate())
					end
				},
				-- Clickable background to trigger Eval Screen
				UIElements.QuadButton(1, 1) .. {
					InitCommand = function(self)
						self:xy(2, 0):zoomto(frameWidth - 20, 19.6):diffusealpha(0):halign(0)
					end,
					MouseOverCommand = function(self)
						if score then self:finishtweening():diffusealpha(0.1) end
					end,
					MouseOutCommand = function(self)
						self:finishtweening():diffusealpha(0)
					end,
					MouseDownCommand = function(self, params)
						if nestedTab == 1 and params.event == "DeviceButton_left mouse button" and score then
							if SCREENMAN:GetTopScreen():GetName() ~= "ScreenNetSelectMusic" then
								SCREENMAN:GetTopScreen():ShowEvalScreenForScore(score)
							end
						end
					end
				}
			}
		end
		return rows
	end)(),
	-- Judge and ChordCohesion displays merged into the score rows
}

-- Obsolete rate list and interaction buttons removed here
t[#t + 1] = l

t[#t + 1] = Def.Quad {
	Name = "ScrollBar",
	InitCommand = function(self)
		self:x(frameWidth):zoomto(4, 0):halign(1):valign(0):diffuse(getMainColor("highlight")):diffusealpha(0.75)
	end,
	DisplayCommand = function(self)
		self:finishtweening()
		self:smooth(0.15)
		local currentRateScores = getCurrentRateScores()
		if currentRateScores ~= nil then
			self:zoomy(clamp(((frameHeight / #currentRateScores) * 5) - 30, 0, frameHeight - 30))
			self:y((((frameHeight) / #currentRateScores) * scoreOffset) + 30)
		else
			self:zoomy(0)
		end
	end
}

ret[#ret + 1] = t

ret[#ret + 1] = LoadActor("../superscoreboard") .. {
	InitCommand = function(self)
		moped = self
		self:xy(frameX, frameY):visible(false)
	end
}

return ret
