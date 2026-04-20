local hoverAlpha = 0.6
local statsOverlayActive = false
local statsOverlayInputRedirect = false
local quickMenuActive = false
local quickMenuInputRedirect = false
local quickMenuPanelX = 34
local quickMenuPanelY = 50
local quickMenuPanelWidth = 262
local quickMenuPanelHeight = 214
local quickMenuItemX = quickMenuPanelX + 18
local quickMenuItemY = quickMenuPanelY + 58
local quickMenuItemWidth = quickMenuPanelWidth - 36
local quickMenuItemHeight = 38
local quickMenuItemGap = 14
local sessionRowCount = 5
local sessionPanelX = 320
local sessionPanelY = 100
local sessionPanelWidth = 450
local sessionCardWidth = sessionPanelWidth - 24
local overlayCloseButtonX = SCREEN_WIDTH - 94
local overlayCloseButtonY = 77
local overlayCloseButtonHalfWidth = 14
local overlayCloseButtonHalfHeight = 12
local activityColumnCount = 7
local activityCellCount = 35
local activityCellSize = 18
local activityCellStepX = 26
local activityCellStepY = 24
local activityGridX = 102
local activityGridY = 160
local activityPrevButtonX = 104
local activityPrevButtonY = 133
local activityNextButtonX = 286
local activityNextButtonY = 133
local activityButtonWidth = 16
local activityButtonHeight = 16
local selectedYear = tonumber(os.date("%Y"))
local selectedMonth = tonumber(os.date("%m"))
local selectedDay = tonumber(os.date("%d"))
local hoveredActivityDay = nil
local activityMonthCounts = {}
local activityMonthMaxCount = 0
local activityMonthDayCount = 31
local selectedScoresForDisplay = {}
local sessionScoreOffset = 0
local lastSessionDisplayKey = nil
local statsOverlayTabs = {
	Sessions = 1,
	Overall = 2,
	Leaderboards = 3
}
local statsOverlayTab = statsOverlayTabs.Sessions
local overallSubTabs = {
	Overview = 1,
	Timeline = 2,
	BestScores = 3
}
local overallSubTab = overallSubTabs.BestScores
local overallBestScores = {}
local overallBestScoreRowCount = 8
local overallBestScoreOffset = 0
local statsLeaderboardScores = {}
local statsLeaderboardRowCount = 10
local statsLeaderboardOffset = 0
local statsOverlayTabTop = 60
local statsOverlayTabHeight = 34
local statsOverlayTabButtons = {
	{tab = statsOverlayTabs.Sessions, left = 80, width = 70, label = "Sessions"},
	{tab = statsOverlayTabs.Overall, left = 152, width = 86, label = "Overall"},
	{tab = statsOverlayTabs.Leaderboards, left = 240, width = 118, label = "Leaderboards"}
}

local refreshStatsLeaderboard
local formatChartMeter

local function pointInBox(x, y, centerX, centerY, halfWidth, halfHeight)
	return x >= centerX - halfWidth and x <= centerX + halfWidth and y >= centerY - halfHeight and y <= centerY + halfHeight
end

local function pointInRect(x, y, left, top, width, height)
	return x >= left and x <= left + width and y >= top and y <= top + height
end

local function isStatsOverlaySessionTab()
	return statsOverlayTab == statsOverlayTabs.Sessions
end

local function getStatsOverlayTitle()
	if statsOverlayTab == statsOverlayTabs.Overall then
		return "Overall"
	elseif statsOverlayTab == statsOverlayTabs.Leaderboards then
		return "Leaderboards"
	end
	return "Sessions"
end

local function getStatsOverlayTabAtPosition(mouseX, mouseY)
	if mouseY < statsOverlayTabTop or mouseY > statsOverlayTabTop + statsOverlayTabHeight then return nil end
	for _, button in ipairs(statsOverlayTabButtons) do
		if pointInRect(mouseX, mouseY, button.left, statsOverlayTabTop, button.width, statsOverlayTabHeight) then
			return button.tab
		end
	end
	return nil
end

local function setStatsOverlayTab(tab)
	if not tab then return end
	if statsOverlayTab == tab then return end
	statsOverlayTab = tab
	if statsOverlayTab == statsOverlayTabs.Overall then
		overallSubTab = overallSubTabs.BestScores
		overallBestScoreOffset = 0
	elseif statsOverlayTab == statsOverlayTabs.Leaderboards then
		refreshStatsLeaderboard()
	end
	hoveredActivityDay = nil
	MESSAGEMAN:Broadcast("StatsOverlayTabChanged", {tab = tab})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

local function getOverallSubTabAtPosition(mouseX, mouseY)
	if statsOverlayTab ~= statsOverlayTabs.Overall then return nil end
	local left = sessionPanelX
	local top = 100
	local height = 26
	if mouseY < top or mouseY > top + height then return nil end
	local buttons = {
		{tab = overallSubTabs.Overview, left = left + 12, width = 84},
		{tab = overallSubTabs.Timeline, left = left + 12 + 90, width = 86},
		{tab = overallSubTabs.BestScores, left = left + 12 + 90 + 92, width = 112}
	}
	for _, b in ipairs(buttons) do
		if pointInRect(mouseX, mouseY, b.left, top, b.width, height) then
			return b.tab
		end
	end
	return nil
end

local function setOverallSubTab(tab)
	if not tab then return end
	if overallSubTab == tab then return end
	overallSubTab = tab
	overallBestScoreOffset = 0
	MESSAGEMAN:Broadcast("OverallSubTabChanged", {tab = tab})
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

local function clampOverallBestScoreOffset()
	local maxOffset = math.max(0, #overallBestScores - overallBestScoreRowCount)
	if overallBestScoreOffset < 0 then
		overallBestScoreOffset = 0
	elseif overallBestScoreOffset > maxOffset then
		overallBestScoreOffset = maxOffset
	end
end

local function clampStatsLeaderboardOffset()
	local maxOffset = math.max(0, #statsLeaderboardScores - statsLeaderboardRowCount)
	if statsLeaderboardOffset < 0 then
		statsLeaderboardOffset = 0
	elseif statsLeaderboardOffset > maxOffset then
		statsLeaderboardOffset = maxOffset
	end
end

refreshStatsLeaderboard = function()
	statsLeaderboardScores = {}
	statsLeaderboardOffset = 0
	if not DLMAN then
		MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
		return
	end
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then
		MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
		return
	end
	local chartKey = steps:GetChartKey()
	if not chartKey or chartKey == "" then
		MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
		return
	end
	if not DLMAN.IsLoggedIn or not DLMAN:IsLoggedIn() then
		MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
		return
	end
	if DLMAN.RequestChartLeaderBoardFromOnline then
		DLMAN:RequestChartLeaderBoardFromOnline(chartKey, function(leaderboard)
			statsLeaderboardScores = leaderboard or {}
			clampStatsLeaderboardOffset()
			MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
		end)
	else
		statsLeaderboardScores = DLMAN:GetChartLeaderBoard(chartKey) or {}
		clampStatsLeaderboardOffset()
		MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
	end
end

local function statsLeaderboardRow(i)
	local rowY = sessionPanelY + 44 + ((i - 1) * 24)
	local rowWidth = sessionPanelWidth - 24
	return Def.ActorFrame {
		Name = "LBRow" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 12, rowY)
			self:visible(false)
		end,
		UpdateCommand = function(self)
			if statsOverlayTab ~= statsOverlayTabs.Leaderboards then
				self:visible(false)
				return
			end
			local steps = GAMESTATE:GetCurrentSteps()
			local loggedIn = DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() or false
			if not steps or not loggedIn then
				self:visible(false)
				return
			end
			local entry = statsLeaderboardScores[statsLeaderboardOffset + i]
			local name = entry and entry.GetDisplayName and entry:GetDisplayName() or nil
			if not name then
				self:visible(false)
				return
			end
			self:visible(true)
			local wife = entry.GetWifeScore and entry:GetWifeScore() or nil
			local grade = entry.GetWifeGrade and entry:GetWifeGrade() or nil
			self:GetChild("Rank"):settext(tostring(statsLeaderboardOffset + i))
			self:GetChild("Name"):settext(name)
			if wife then
				self:GetChild("Wife"):settextf("%05.2f%%", wife * 100)
				if grade then
					self:GetChild("Wife"):diffuse(byGrade(grade))
				else
					self:GetChild("Wife"):diffuse(color("#FFFFFF"))
				end
			else
				self:GetChild("Wife"):settext("")
				self:GetChild("Wife"):diffuse(color("#FFFFFF"))
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 0):halign(0):valign(0):zoomto(rowWidth, 20):diffuse(color("#111111")):diffusealpha(0.8)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rank",
			InitCommand = function(self)
				self:xy(10, 10):halign(0):valign(0.5):zoom(0.24):diffuse(color("#BBBBBB"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(46, 10):halign(0):valign(0.5):zoom(0.28):maxwidth(980)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Wife",
			InitCommand = function(self)
				self:xy(rowWidth - 10, 10):halign(1):valign(0.5):zoom(0.28)
			end
		}
	}
end

local function isOverStatsLeaderboardPanel(mouseX, mouseY)
	if statsOverlayTab ~= statsOverlayTabs.Leaderboards then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY, sessionPanelWidth, 300)
end

local function pageStatsLeaderboard(direction)
	statsLeaderboardOffset = statsLeaderboardOffset + (direction * statsLeaderboardRowCount)
	clampStatsLeaderboardOffset()
	MESSAGEMAN:Broadcast("StatsLeaderboardUpdated")
end

local function refreshOverallBestScores()
	overallBestScores = {}
	for i = 1, 200 do
		local hs = SCOREMAN:GetTopSSRHighScoreForGame(i, "Overall")
		if not hs then break end
		overallBestScores[#overallBestScores + 1] = hs
	end
	clampOverallBestScoreOffset()
end

local function isOverOverallBestScoresPanel(mouseX, mouseY)
	if statsOverlayTab ~= statsOverlayTabs.Overall then return false end
	if overallSubTab ~= overallSubTabs.BestScores then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY, sessionPanelWidth, 300)
end

local function pageOverallBestScores(direction)
	overallBestScoreOffset = overallBestScoreOffset + (direction * overallBestScoreRowCount)
	clampOverallBestScoreOffset()
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

local function overallBestScoreRow(i)
	local rowY = sessionPanelY + 44 + ((i - 1) * 32)
	local rowWidth = sessionCardWidth
	return Def.ActorFrame {
		Name = "BestRow" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 12, rowY)
			self:visible(false)
		end,
		UpdateCommand = function(self)
			if statsOverlayTab ~= statsOverlayTabs.Overall or overallSubTab ~= overallSubTabs.BestScores then
				self:visible(false)
				return
			end
			local score = overallBestScores[overallBestScoreOffset + i]
			if not score then
				self:visible(false)
				return
			end
			local chartKey = score:GetChartKey()
			local song = SONGMAN:GetSongByChartKey(chartKey)
			local steps = SONGMAN:GetStepsByChartKey(chartKey)
			local ssr = score:GetSkillsetSSR("Overall")
			local meta = song and song:GetDisplayArtist() or "Unknown Artist"
			local subtitle = song and song:GetDisplaySubTitle() or ""
			if subtitle ~= "" then
				meta = meta .. " • " .. subtitle
			end
			self:visible(true)
			self:GetChild("Title"):settext(song and song:GetDisplayMainTitle() or chartKey)
			self:GetChild("Meta"):settext(meta)
			self:GetChild("Chart"):settext(formatChartMeter(steps))
			self:GetChild("Rate"):settext(formatRate(score))
			self:GetChild("Percent"):settext(string.format("%s [%s]", formatPercent(score), formatJudge(score)))
			self:GetChild("Percent"):diffuse(getGradeColor(score:GetWifeGrade()))
			if ssr and ssr > 0 then
				self:GetChild("SSR"):settext(string.format("%.2f", ssr))
				self:GetChild("SSR"):diffuse(byMSD(ssr))
			else
				self:GetChild("SSR"):settext("--")
				self:GetChild("SSR"):diffuse(color("#888888"))
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 0):halign(0):valign(0):zoomto(rowWidth, 26):diffuse(color("#111111")):diffusealpha(0.8)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(8, 2):halign(0):valign(0):zoom(0.20):maxwidth(760)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Meta",
			InitCommand = function(self)
				self:xy(8, 12):halign(0):valign(0):zoom(0.14):diffuse(color("#BBBBBB")):maxwidth(760)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Chart",
			InitCommand = function(self)
				self:xy(8, 20):halign(0):valign(0):zoom(0.14):diffuse(color("#D6D6D6")):maxwidth(760)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Percent",
			InitCommand = function(self)
				self:xy(rowWidth - 180 + 107, 3):halign(1):valign(0):zoom(0.18)
			end
		},
		LoadFont("Common Large") .. {
			Name = "SSR",
			InitCommand = function(self)
				self:xy(rowWidth - 112 + 107, 3):halign(1):valign(0):zoom(0.18)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self)
				self:xy(rowWidth - 180 + 107, 18):halign(1):valign(0):zoom(0.14):diffuse(color("#DDDDDD"))
			end
		}
	}
end

local function formatPercent(score)
	if not score then return "" end
	return string.format("%.2f%%", score:GetWifeScore() * 100)
end

local function formatRate(score)
	if not score then return "" end
	return string.format("%.2f", score:GetMusicRate()):gsub("%.?0+$", "") .. "x"
end

local function getRecentScoreCount()
	local count = 0
	for i = 1, 64 do
		if SCOREMAN:GetRecentScoreForGame(i) then
			count = count + 1
		else
			break
		end
	end
	return count
end

local function formatDateKey(year, month, day)
	return string.format("%04d-%02d-%02d", year, month, day)
end

local function getTodayDateParts()
	local now = os.time()
	return tonumber(os.date("%Y", now)), tonumber(os.date("%m", now)), tonumber(os.date("%d", now))
end

local function daysInMonth(year, month)
	local nextMonth = os.time({year = year, month = month + 1, day = 1, hour = 0, min = 0, sec = 0})
	return tonumber(os.date("%d", nextMonth - 86400))
end

local function shiftSelectedMonth(offset)
	local shifted = os.time({year = selectedYear, month = selectedMonth + offset, day = 1, hour = 0, min = 0, sec = 0})
	selectedYear = tonumber(os.date("%Y", shifted))
	selectedMonth = tonumber(os.date("%m", shifted))
	selectedDay = math.min(selectedDay, daysInMonth(selectedYear, selectedMonth))
end

local function parseScoreTime(score)
	if not score then return nil end
	local d = score:GetDate()
	if not d or d == "" then return nil end
	local year, month, day, hour, min, sec = d:match("(%d+)%-(%d+)%-(%d+)[ T](%d+):(%d+):(%d+)")
	if not year then
		year, month, day = d:match("(%d+)%-(%d+)%-(%d+)")
		hour = 0
		min = 0
		sec = 0
	end
	if not year then return nil end
	return os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)})
end

local function getScoreDateParts(score)
	local t = parseScoreTime(score)
	if not t then return nil end
	return tonumber(os.date("%Y", t)), tonumber(os.date("%m", t)), tonumber(os.date("%d", t))
end

local function getScoreDateKey(score)
	local year, month, day = getScoreDateParts(score)
	if not year then return nil end
	return formatDateKey(year, month, day)
end

local function getScoresForSelectedDate()
	local selectedKey = formatDateKey(selectedYear, selectedMonth, selectedDay)
	local scores = {}
	for i = 1, 512 do
		local score = SCOREMAN:GetRecentScoreForGame(i)
		if not score then break end
		if getScoreDateKey(score) == selectedKey then
			scores[#scores + 1] = score
		end
	end
	return scores
end

local function getSelectedMonthActivity()
	local counts = {}
	local monthDays = daysInMonth(selectedYear, selectedMonth)
	for day = 1, monthDays do
		counts[day] = 0
	end
	local maxCount = 0
	for i = 1, 512 do
		local score = SCOREMAN:GetRecentScoreForGame(i)
		if not score then break end
		local year, month, day = getScoreDateParts(score)
		if year == selectedYear and month == selectedMonth and day and day >= 1 and day <= monthDays then
			counts[day] = counts[day] + 1
			if counts[day] > maxCount then
				maxCount = counts[day]
			end
		end
	end
	return counts, maxCount, monthDays
end

local function getSelectedSessionSeconds(scores)
	local displayDay = hoveredActivityDay or selectedDay
	local todayYear, todayMonth, todayDay = getTodayDateParts()
	if selectedYear == todayYear and selectedMonth == todayMonth and displayDay == todayDay then
		return GAMESTATE:GetSessionTime()
	end
	local earliest = nil
	local latest = nil
	for _, score in ipairs(scores) do
		local scoreTime = parseScoreTime(score)
		if scoreTime then
			if not earliest or scoreTime < earliest then earliest = scoreTime end
			if not latest or scoreTime > latest then latest = scoreTime end
		end
	end
	if earliest and latest and latest > earliest then
		return latest - earliest
	end
	return 0
end

local function formatJudge(score)
	if not score then return "" end
	local j = table.find(ms.JudgeScalers, notShit.round(score:GetJudgeScale(), 2))
	if not j then j = 4 end
	if j < 4 then j = 4 end
	return "J" .. j
end

formatChartMeter = function(steps)
	if not steps then return "" end
	local parts = {}
	local style = GAMESTATE:GetCurrentStyle()
	local keymode = nil
	if style then
		local ok, columns = pcall(function() return style:ColumnsPerPlayer() end)
		if ok and columns then
			keymode = tostring(columns) .. "K"
		end
	end
	if keymode then parts[#parts + 1] = keymode end
	parts[#parts + 1] = getShortDifficulty(steps:GetDifficulty())
	parts[#parts + 1] = tostring(steps:GetMeter())
	return table.concat(parts, " ")
end

local function getActivityDayAtPosition(mouseX, mouseY)
	for day = 1, activityMonthDayCount do
		local index = day - 1
		local col = index % activityColumnCount
		local row = math.floor(index / activityColumnCount)
		local cellX = activityGridX + (col * activityCellStepX)
		local cellY = activityGridY + (row * activityCellStepY)
		if pointInRect(mouseX, mouseY, cellX, cellY, activityCellSize, activityCellSize) then
			return day
		end
	end
	return nil
end

local function isOverSessionPanel(mouseX, mouseY)
	if not isStatsOverlaySessionTab() then return false end
	return pointInRect(mouseX, mouseY, sessionPanelX, sessionPanelY, sessionPanelWidth, 300)
end

local function clampSessionScoreOffset()
	local maxOffset = math.max(0, #selectedScoresForDisplay - sessionRowCount)
	if sessionScoreOffset < 0 then
		sessionScoreOffset = 0
	elseif sessionScoreOffset > maxOffset then
		sessionScoreOffset = maxOffset
	end
end

local function pageSessionScores(direction)
	sessionScoreOffset = sessionScoreOffset + (direction * sessionRowCount)
	clampSessionScoreOffset()
	MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
end

local function getQuickMenuItemTop(index)
	return quickMenuItemY + ((index - 1) * (quickMenuItemHeight + quickMenuItemGap))
end

local function pointInQuickMenuItem(mouseX, mouseY, index)
	return pointInRect(mouseX, mouseY, quickMenuItemX, getQuickMenuItemTop(index), quickMenuItemWidth, quickMenuItemHeight)
end

local function setStatsOverlayActive(active)
	if statsOverlayActive == active then return end
	statsOverlayActive = active
	setenv("StatsOverlayActive", active)
	if active then
		selectedYear, selectedMonth, selectedDay = getTodayDateParts()
		hoveredActivityDay = nil
		sessionScoreOffset = 0
		lastSessionDisplayKey = nil
		statsOverlayTab = statsOverlayTabs.Sessions
		statsOverlayInputRedirect = SCREENMAN:get_input_redirected(PLAYER_1)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
	else
		hoveredActivityDay = nil
		sessionScoreOffset = 0
		lastSessionDisplayKey = nil
		SCREENMAN:set_input_redirected(PLAYER_1, statsOverlayInputRedirect)
	end
	MESSAGEMAN:Broadcast("StatsOverlayStateChanged", {active = active})
end

local function setQuickMenuActive(active)
	if quickMenuActive == active then return end
	quickMenuActive = active
	setenv("QuickMenuActive", active)
	if active then
		if statsOverlayActive then
			setStatsOverlayActive(false)
		end
		quickMenuInputRedirect = SCREENMAN:get_input_redirected(PLAYER_1)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
	else
		SCREENMAN:set_input_redirected(PLAYER_1, quickMenuInputRedirect)
	end
	MESSAGEMAN:Broadcast("QuickMenuStateChanged", {active = active})
end

local function openServiceMenu()
	setQuickMenuActive(false)
	SCREENMAN:SetNewScreen("ScreenOptionsService")
end

local function openNoteskinOptions()
	setQuickMenuActive(false)
	setenv("NewOptions", "Main")
	local top = SCREENMAN:GetTopScreen()
	if top and top.OpenOptions then
		top:OpenOptions()
	end
end

local function openKeyConfig()
	setQuickMenuActive(false)
	SCREENMAN:SetNewScreen("ScreenMapControllers")
end

local function input(event)
	local deviceButton = event.DeviceInput and event.DeviceInput.button or nil
	if quickMenuActive and event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or deviceButton == "DeviceButton_right mouse button" then
			setQuickMenuActive(false)
			return true
		end
	end
	if quickMenuActive and deviceButton == "DeviceButton_left mouse button" then
		if event.type == "InputEventType_FirstPress" then
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			if pointInQuickMenuItem(mouseX, mouseY, 1) then
				openServiceMenu()
			elseif pointInQuickMenuItem(mouseX, mouseY, 2) then
				openNoteskinOptions()
			elseif pointInQuickMenuItem(mouseX, mouseY, 3) then
				openKeyConfig()
			elseif not pointInRect(mouseX, mouseY, quickMenuPanelX, quickMenuPanelY, quickMenuPanelWidth, quickMenuPanelHeight) then
				setQuickMenuActive(false)
			end
		end
		return true
	end
	if quickMenuActive and deviceButton == "DeviceButton_right mouse button" then
		return true
	end
	if statsOverlayActive and event.type == "InputEventType_FirstPress" then
		if event.button == "Back" or deviceButton == "DeviceButton_right mouse button" then
			setStatsOverlayActive(false)
			return true
		end
	end
	if statsOverlayActive and deviceButton == "DeviceButton_left mouse button" then
		if event.type == "InputEventType_FirstPress" then
			local mouseX = INPUTFILTER:GetMouseX()
			local mouseY = INPUTFILTER:GetMouseY()
			if pointInBox(mouseX, mouseY, overlayCloseButtonX, overlayCloseButtonY, overlayCloseButtonHalfWidth, overlayCloseButtonHalfHeight) then
				setStatsOverlayActive(false)
			else
				local selectedTab = getStatsOverlayTabAtPosition(mouseX, mouseY)
				if selectedTab then
					setStatsOverlayTab(selectedTab)
				else
					local selectedOverallSubTab = getOverallSubTabAtPosition(mouseX, mouseY)
					if selectedOverallSubTab then
						setOverallSubTab(selectedOverallSubTab)
					elseif isStatsOverlaySessionTab() and pointInRect(mouseX, mouseY, activityPrevButtonX, activityPrevButtonY, activityButtonWidth, activityButtonHeight) then
						shiftSelectedMonth(-1)
						sessionScoreOffset = 0
						lastSessionDisplayKey = nil
						MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
					elseif isStatsOverlaySessionTab() and pointInRect(mouseX, mouseY, activityNextButtonX, activityNextButtonY, activityButtonWidth, activityButtonHeight) then
						shiftSelectedMonth(1)
						sessionScoreOffset = 0
						lastSessionDisplayKey = nil
						MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
					elseif isStatsOverlaySessionTab() then
						local day = getActivityDayAtPosition(mouseX, mouseY)
						if day then
							selectedDay = day
							sessionScoreOffset = 0
							lastSessionDisplayKey = nil
							MESSAGEMAN:Broadcast("StatsOverlayDataChanged")
						end
					end
				end
			end
		end
		return true
	end
	if statsOverlayActive and deviceButton == "DeviceButton_right mouse button" then
		return true
	end
	if deviceButton == "DeviceButton_left mouse button" then 
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseLeftClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	elseif deviceButton == "DeviceButton_right mouse button" then
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseRightClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	end
	return false
end

local function sessionRow(i)
	return Def.ActorFrame {
		Name = "Row" .. i,
		InitCommand = function(self)
			self:xy(sessionPanelX + 12, sessionPanelY + 44 + ((i - 1) * 50))
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Update")
		end,
		UpdateCommand = function(self)
			if not isStatsOverlaySessionTab() then
				self:visible(false)
				return
			end
			local score = selectedScoresForDisplay[sessionScoreOffset + i]
			if not score then
				self:visible(false)
				return
			end
			local chartKey = score:GetChartKey()
			local song = SONGMAN:GetSongByChartKey(chartKey)
			local steps = SONGMAN:GetStepsByChartKey(chartKey)
			local ssr = score:GetSkillsetSSR("Overall")
			local meta = song and song:GetDisplayArtist() or "Unknown Artist"
			local subtitle = song and song:GetDisplaySubTitle() or ""
			if subtitle ~= "" then
				meta = meta .. " • " .. subtitle
			end
			self:visible(true)
			self:GetChild("Title"):settext(song and song:GetDisplayMainTitle() or chartKey)
			self:GetChild("Meta"):settext(meta)
			self:GetChild("Chart"):settext(formatChartMeter(steps))
			self:GetChild("Rate"):settext(formatRate(score))
			self:GetChild("Percent"):settext(string.format("%s [%s]", formatPercent(score), formatJudge(score)))
			self:GetChild("Percent"):diffuse(getGradeColor(score:GetWifeGrade()))
			self:GetChild("ClearType"):settext(getClearTypeFromScore(PLAYER_1, score, 0))
			self:GetChild("ClearType"):diffuse(getClearTypeFromScore(PLAYER_1, score, 2))
			if ssr and ssr > 0 then
				self:GetChild("SSR"):settext(string.format("%.2f", ssr))
				self:GetChild("SSR"):diffuse(byMSD(ssr))
			else
				self:GetChild("SSR"):settext("--")
				self:GetChild("SSR"):diffuse(color("#888888"))
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(0, 0):halign(0):valign(0):zoomto(sessionCardWidth, 34):diffuse(color("#111111")):diffusealpha(0.8)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(8, 2):halign(0):valign(0):zoom(0.23):maxwidth(760)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Meta",
			InitCommand = function(self)
				self:xy(8, 13):halign(0):valign(0):zoom(0.16):diffuse(color("#BBBBBB")):maxwidth(760)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Chart",
			InitCommand = function(self)
				self:xy(8, 23):halign(0):valign(0):zoom(0.16):diffuse(color("#D6D6D6")):maxwidth(760)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Percent",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 242 + 107, 4):halign(1):valign(0):zoom(0.21)
			end
		},
		LoadFont("Common Large") .. {
			Name = "ClearType",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 186 +107	, 4):halign(0.5):valign(0):zoom(0.21)
			end
		},
		LoadFont("Common Large") .. {
			Name = "SSR",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 116 + 107, 4):halign(1):valign(0):zoom(0.21)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Rate",
			InitCommand = function(self)
				self:xy(sessionCardWidth - 242 +107, 20):halign(1):valign(0):zoom(0.18):diffuse(color("#DDDDDD"))
			end
		}
	}
 end

local function statsOverlayTabButton(button)
	return Def.ActorFrame {
		Name = "TabButton" .. tostring(button.tab),
		InitCommand = function(self)
			self:xy(button.left, statsOverlayTabTop)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			local active = statsOverlayTab == button.tab
			self:GetChild("Label"):diffuse(active and color("#FFFFFF") or color("#BBBBBB"))
			self:GetChild("ActiveLine"):visible(active)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(button.width, statsOverlayTabHeight):diffusealpha(0)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(12, 17):halign(0):valign(0.5):zoom(0.42):settext(button.label)
			end
		},
		Def.Quad {
			Name = "ActiveLine",
			InitCommand = function(self)
				self:xy(0, statsOverlayTabHeight - 1):halign(0):valign(1):zoomto(button.width, 2):diffuse(color("#FFFFFF")):visible(false)
			end
		}
	}
end

local statsOverlay = Def.ActorFrame {
	Name = "StatsOverlay",
	InitCommand = function(self)
		self:diffusealpha(0):visible(false):draworder(3000)
		self:SetUpdateFunction(function(actor)
			if not statsOverlayActive then return end
			if not isStatsOverlaySessionTab() then
				if hoveredActivityDay ~= nil then
					hoveredActivityDay = nil
					actor:playcommand("Update")
				end
				return
			end
			local hovered = getActivityDayAtPosition(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY())
			if hoveredActivityDay ~= hovered then
				hoveredActivityDay = hovered
				actor:playcommand("Update")
			end
		end)
	end,
	StatsOverlayStateChangedMessageCommand = function(self, params)
		if params.active then
			self:visible(true):stoptweening():linear(0.15):diffusealpha(1):queuecommand("Refresh")
		else
			self:stoptweening():linear(0.15):diffusealpha(0):queuecommand("HideIfClosed")
		end
	end,
	HideIfClosedCommand = function(self)
		if not statsOverlayActive then
			self:visible(false)
		end
	end,
	StatsOverlayDataChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayTabChangedMessageCommand = function(self)
		if statsOverlayActive then
			self:queuecommand("Update")
		end
	end,
	StatsOverlayMouseWheelMessageCommand = function(self, params)
		if not statsOverlayActive then return end
		local mouseX = INPUTFILTER:GetMouseX()
		local mouseY = INPUTFILTER:GetMouseY()
		if isStatsOverlaySessionTab() then
			if not isOverSessionPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageSessionScores(-1)
			elseif params and params.direction == "down" then
				pageSessionScores(1)
			end
		elseif statsOverlayTab == statsOverlayTabs.Overall and overallSubTab == overallSubTabs.BestScores then
			if not isOverOverallBestScoresPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageOverallBestScores(-1)
			elseif params and params.direction == "down" then
				pageOverallBestScores(1)
			end
		elseif statsOverlayTab == statsOverlayTabs.Leaderboards then
			if not isOverStatsLeaderboardPanel(mouseX, mouseY) then return end
			if params and params.direction == "up" then
				pageStatsLeaderboard(-1)
			elseif params and params.direction == "down" then
				pageStatsLeaderboard(1)
			end
		end
	end,
	RefreshCommand = function(self)
		SCOREMAN:SortRecentScoresForGame()
		refreshOverallBestScores()
		refreshStatsLeaderboard()
		self:playcommand("Update")
	end,
	UpdateCommand = function(self)
		self:GetChild("Title"):settext(getStatsOverlayTitle())
		self:GetChild("RightPaneSessions"):visible(isStatsOverlaySessionTab())
		self:GetChild("RightPaneOverall"):visible(statsOverlayTab == statsOverlayTabs.Overall)
		self:GetChild("RightPaneLeaderboards"):visible(statsOverlayTab == statsOverlayTabs.Leaderboards)
		self:GetChild("OverallSubTabs"):visible(statsOverlayTab == statsOverlayTabs.Overall)
		self:GetChild("OverallLeft"):visible(statsOverlayTab == statsOverlayTabs.Overall)
		self:GetChild("SessionsLeft"):visible(isStatsOverlaySessionTab())
		self:GetChild("OverallBestScores"):visible(statsOverlayTab == statsOverlayTabs.Overall and overallSubTab == overallSubTabs.BestScores)
		if not isStatsOverlaySessionTab() then
			self:GetChild("EmptyState"):visible(false)
			for i = 1, sessionRowCount do
				self:GetChild("Row" .. i):playcommand("Update")
			end
			return
		end
		local displayDay = hoveredActivityDay or selectedDay
		local selectedDateTime = os.time({year = selectedYear, month = selectedMonth, day = displayDay, hour = 0, min = 0, sec = 0})
		local selectedKey = formatDateKey(selectedYear, selectedMonth, displayDay)
		if lastSessionDisplayKey ~= selectedKey then
			sessionScoreOffset = 0
			lastSessionDisplayKey = selectedKey
		end
		selectedScoresForDisplay = {}
		for i = 1, 512 do
			local score = SCOREMAN:GetRecentScoreForGame(i)
			if not score then break end
			if getScoreDateKey(score) == selectedKey then
				selectedScoresForDisplay[#selectedScoresForDisplay + 1] = score
			end
		end
		clampSessionScoreOffset()
		activityMonthCounts, activityMonthMaxCount, activityMonthDayCount = getSelectedMonthActivity()
		self:GetChild("Title"):settext("Session on " .. os.date("%d/%m/%Y", selectedDateTime))
		self:GetChild("MonthLabel"):settext(os.date("%B %Y", os.time({year = selectedYear, month = selectedMonth, day = 1, hour = 0, min = 0, sec = 0})))
		self:GetChild("SelectedDateLabel"):settext(os.date("%A, %d %B %Y", selectedDateTime))
		self:GetChild("SessionTime"):settext("Session time: " .. SecondsToHHMMSS(getSelectedSessionSeconds(selectedScoresForDisplay)))
		self:GetChild("SongsPlayed"):settext("Songs played: " .. #selectedScoresForDisplay)
		self:GetChild("EmptyState"):visible(#selectedScoresForDisplay == 0)
		for i = 1, sessionRowCount do
			self:GetChild("Row" .. i):playcommand("Update")
		end
		for i = 1, activityCellCount do
			self:GetChild("Activity" .. i):playcommand("Update")
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("#000000")):diffusealpha(0.7)
		end
	},
	Def.ActorFrame {
		Name = "SessionsLeft",
		InitCommand = function(self)
			self:visible(true)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end,
		Def.Quad {
			Name = "Backing",
			InitCommand = function(self)
				self:xy(90, 100):halign(0):valign(0):zoomto(220, 300):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Heading",
			InitCommand = function(self)
				self:xy(102, 114):halign(0):zoom(0.36):settext("Activity")
			end
		}
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(80, 60):halign(0):valign(0):zoomto(SCREEN_WIDTH - 160, SCREEN_HEIGHT - 140):diffuse(color("#0E0E0E")):diffusealpha(0.92)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(80, 60):halign(0):valign(0):zoomto(SCREEN_WIDTH - 160, 34):diffuse(color("#1A1A1A")):diffusealpha(0.95)
		end
	},
	LoadFont("Common Large") .. {
		Name = "Title",
		InitCommand = function(self)
			self:xy(430, 77):zoom(0.56):halign(0):valign(0.5)
		end
	},
	statsOverlayTabButton(statsOverlayTabButtons[1]),
	statsOverlayTabButton(statsOverlayTabButtons[2]),
	statsOverlayTabButton(statsOverlayTabButtons[3]),
	UIElements.TextToolTip(1, 1, "Common Large") .. {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 94, 77):zoom(0.38):halign(0.5):valign(0.5):settext("X")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				setStatsOverlayActive(false)
			end
		end
	},
	Def.ActorFrame {
		Name = "RightPaneSessions",
		InitCommand = function(self)
			self:visible(true)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, 300):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 12, sessionPanelY + 14):halign(0):zoom(0.34):settext("Selected day scores")
			end
		}
	},
	Def.ActorFrame {
		Name = "RightPaneOverall",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall)
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, 300):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 18):halign(0):zoom(0.34):settext("Overview")
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 50):halign(0):zoom(0.28):diffuse(color("#DDDDDD")):settext("This pane is reserved for the Overall screen content.")
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 80):halign(0):zoom(0.24):diffuse(color("#AFAFAF")):maxwidth(1700):settext("Top-left tabs now switch this right-side pane inside the same Stats overlay.")
			end
		}
	},
	Def.ActorFrame {
		Name = "RightPaneLeaderboards",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Leaderboards)
			if statsOverlayTab == statsOverlayTabs.Leaderboards then
				refreshStatsLeaderboard()
				self:queuecommand("Update")
			end
		end,
		StatsLeaderboardUpdatedMessageCommand = function(self)
			if statsOverlayActive and statsOverlayTab == statsOverlayTabs.Leaderboards then
				self:queuecommand("Update")
			end
		end,
		UpdateCommand = function(self)
			if statsOverlayTab ~= statsOverlayTabs.Leaderboards then return end
			local steps = GAMESTATE:GetCurrentSteps()
			local loggedIn = DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() or false
			self:GetChild("NeedSteps"):visible(not steps)
			self:GetChild("NeedLogin"):visible(steps and not loggedIn)
			self:GetChild("EmptyBoard"):visible(steps and loggedIn and #statsLeaderboardScores == 0)
			self:GetChild("Page"):queuecommand("Update")
			for i = 1, statsLeaderboardRowCount do
				self:GetChild("LBRow" .. i):queuecommand("Update")
			end
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(sessionPanelX, sessionPanelY):halign(0):valign(0):zoomto(sessionPanelWidth, 300):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 18):halign(0):zoom(0.34):settext("Leaderboards")
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(sessionPanelX + 16, sessionPanelY + 50):halign(0):zoom(0.24):diffuse(color("#AFAFAF")):settext("Chart leaderboard (online)")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "NeedSteps",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 160):halign(0.5):zoom(0.34):diffuse(color("#BBBBBB")):settext("Select a chart to view its leaderboard"):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "NeedLogin",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 160):halign(0.5):zoom(0.34):diffuse(color("#BBBBBB")):settext("Log in to view online leaderboards"):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "EmptyBoard",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 160):halign(0.5):zoom(0.34):diffuse(color("#BBBBBB")):settext("No leaderboard entries available"):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Page",
			InitCommand = function(self)
				self:xy(sessionPanelX + sessionPanelWidth - 12, sessionPanelY + 20):halign(1):zoom(0.24):diffuse(color("#AFAFAF"))
			end,
			UpdateCommand = function(self)
				if statsOverlayTab ~= statsOverlayTabs.Leaderboards then return end
				local total = #statsLeaderboardScores
				if total == 0 then
					self:settext("")
					return
				end
				local startIndex = math.min(total, statsLeaderboardOffset + 1)
				local endIndex = math.min(total, statsLeaderboardOffset + statsLeaderboardRowCount)
				self:settextf("%d-%d/%d", startIndex, endIndex, total)
			end
		},
		Def.ActorFrame {
			Name = "LBRows",
			InitCommand = function(self)
				self:xy(0, 0)
			end
		},
		statsLeaderboardRow(1),
		statsLeaderboardRow(2),
		statsLeaderboardRow(3),
		statsLeaderboardRow(4),
		statsLeaderboardRow(5),
		statsLeaderboardRow(6),
		statsLeaderboardRow(7),
		statsLeaderboardRow(8),
		statsLeaderboardRow(9),
		statsLeaderboardRow(10)
	},
	Def.ActorFrame {
		Name = "OverallLeft",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall)
			self:queuecommand("Update")
		end,
		UpdateCommand = function(self)
			if statsOverlayTab ~= statsOverlayTabs.Overall then return end
			local profile = GetPlayerOrMachineProfile(PLAYER_1)
			local name = profile and profile:GetDisplayName() or "Player"
			local rating = profile and profile.GetPlayerRating and profile:GetPlayerRating() or nil
			local playtime = profile and profile.GetTotalSessionSeconds and profile:GetTotalSessionSeconds() or nil
			local notes = profile and profile.GetTotalTapsAndHolds and profile:GetTotalTapsAndHolds() or nil
			self:GetChild("Name"):settext(name)
			self:GetChild("Rating"):settext(rating and string.format("%.2f", rating) or "--")
			self:GetChild("Playtime"):settext(playtime and SecondsToHHMMSS(playtime) or "--")
			self:GetChild("Notes"):settext(notes and tostring(notes) or "--")
		end,
		Def.Quad {
			InitCommand = function(self)
				self:xy(90, 100):halign(0):valign(0):zoomto(220, 300):diffuse(color("#151515")):diffusealpha(0.95)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Name",
			InitCommand = function(self)
				self:xy(102, 120):halign(0):zoom(0.36)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(102, 156):halign(0):zoom(0.26):diffuse(color("#BBBBBB")):settext("Rating")
			end
		},
		LoadFont("Common Large") .. {
			Name = "Rating",
			InitCommand = function(self)
				self:xy(102, 178):halign(0):zoom(0.32)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(102, 216):halign(0):zoom(0.26):diffuse(color("#BBBBBB")):settext("Playtime")
			end
		},
		LoadFont("Common Large") .. {
			Name = "Playtime",
			InitCommand = function(self)
				self:xy(102, 238):halign(0):zoom(0.32)
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(102, 276):halign(0):zoom(0.26):diffuse(color("#BBBBBB")):settext("Taps+Holds")
			end
		},
		LoadFont("Common Large") .. {
			Name = "Notes",
			InitCommand = function(self)
				self:xy(102, 298):halign(0):zoom(0.32)
			end
		}
	},
	Def.ActorFrame {
		Name = "OverallSubTabs",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall)
			self:queuecommand("Set")
		end,
		OverallSubTabChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:GetChild("Tab1"):diffuse(overallSubTab == overallSubTabs.Overview and color("#FFFFFF") or color("#BBBBBB"))
			self:GetChild("Tab2"):diffuse(overallSubTab == overallSubTabs.Timeline and color("#FFFFFF") or color("#BBBBBB"))
			self:GetChild("Tab3"):diffuse(overallSubTab == overallSubTabs.BestScores and color("#FFFFFF") or color("#BBBBBB"))
		end,
		LoadFont("Common Normal") .. {
			Name = "Tab1",
			InitCommand = function(self)
				self:xy(sessionPanelX + 12, 113):halign(0):valign(0.5):zoom(0.30):settext("Overview")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Tab2",
			InitCommand = function(self)
				self:xy(sessionPanelX + 12 + 90, 113):halign(0):valign(0.5):zoom(0.30):settext("Timeline")
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Tab3",
			InitCommand = function(self)
				self:xy(sessionPanelX + 12 + 90 + 92, 113):halign(0):valign(0.5):zoom(0.30):settext("Best scores")
			end
		}
	},
	Def.ActorFrame {
		Name = "OverallBestScores",
		InitCommand = function(self)
			self:visible(false)
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall and overallSubTab == overallSubTabs.BestScores)
			self:queuecommand("Update")
		end,
		OverallSubTabChangedMessageCommand = function(self)
			self:visible(statsOverlayTab == statsOverlayTabs.Overall and overallSubTab == overallSubTabs.BestScores)
			self:queuecommand("Update")
		end,
		StatsOverlayDataChangedMessageCommand = function(self)
			if statsOverlayActive and statsOverlayTab == statsOverlayTabs.Overall and overallSubTab == overallSubTabs.BestScores then
				self:queuecommand("Update")
			end
		end,
		UpdateCommand = function(self)
			if statsOverlayTab ~= statsOverlayTabs.Overall or overallSubTab ~= overallSubTabs.BestScores then return end
			refreshOverallBestScores()
			for i = 1, overallBestScoreRowCount do
				self:GetChild("BestRow" .. i):queuecommand("Update")
			end
			self:GetChild("Page"):queuecommand("Update")
			self:GetChild("Empty"):visible(#overallBestScores == 0)
		end,
		LoadFont("Common Normal") .. {
			Name = "Empty",
			InitCommand = function(self)
				self:xy(sessionPanelX + (sessionPanelWidth / 2), 250):halign(0.5):zoom(0.34):settext("No local best scores found"):diffuse(color("#BBBBBB")):visible(false)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Page",
			InitCommand = function(self)
				self:xy(sessionPanelX + sessionPanelWidth - 12, 120):halign(1):zoom(0.24):diffuse(color("#AFAFAF"))
			end,
			UpdateCommand = function(self)
				if statsOverlayTab ~= statsOverlayTabs.Overall or overallSubTab ~= overallSubTabs.BestScores then return end
				local total = #overallBestScores
				local startIndex = math.min(total, overallBestScoreOffset + 1)
				local endIndex = math.min(total, overallBestScoreOffset + overallBestScoreRowCount)
				if total == 0 then
					self:settext("")
				else
					self:settextf("%d-%d/%d", startIndex, endIndex, total)
				end
			end
		},
		overallBestScoreRow(1),
		overallBestScoreRow(2),
		overallBestScoreRow(3),
		overallBestScoreRow(4),
		overallBestScoreRow(5),
		overallBestScoreRow(6),
		overallBestScoreRow(7),
		overallBestScoreRow(8)
	},
	LoadFont("Common Large") .. {
		Name = "PrevMonth",
		InitCommand = function(self)
			self:xy(activityPrevButtonX + 8, activityPrevButtonY + 8):halign(0.5):valign(0.5):zoom(0.26):settext("<"):diffuse(color("#DDDDDD"))
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "MonthLabel",
		InitCommand = function(self)
			self:xy(193, 141):halign(0.5):valign(0.5):zoom(0.28):diffuse(color("#DDDDDD"))
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Large") .. {
		Name = "NextMonth",
		InitCommand = function(self)
			self:xy(activityNextButtonX + 8, activityNextButtonY + 8):halign(0.5):valign(0.5):zoom(0.26):settext(">"):diffuse(color("#DDDDDD"))
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SessionTime",
		InitCommand = function(self)
			self:xy(102, 322):halign(0):zoom(0.34)
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SongsPlayed",
		InitCommand = function(self)
			self:xy(102, 342):halign(0):zoom(0.34)
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "SelectedDateLabel",
		InitCommand = function(self)
			self:xy(102, 360):halign(0):zoom(0.28):diffuse(color("#DDDDDD")):maxwidth(620)
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "ActivityHint",
		InitCommand = function(self)
			self:xy(102, 381):halign(0):zoom(0.24):diffuse(color("#AFAFAF")):settext("Select a date to view that day's session")
		end,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(isStatsOverlaySessionTab())
		end
	},
	LoadFont("Common Normal") .. {
		Name = "EmptyState",
		InitCommand = function(self)
			self:xy(sessionPanelX + (sessionPanelWidth / 2), sessionPanelY + 150):halign(0.5):zoom(0.34):settext("No scores recorded on this date"):diffuse(color("#BBBBBB")):visible(false)
		end
		,
		StatsOverlayTabChangedMessageCommand = function(self)
			self:visible(false)
		end
	}
}

for i = 1, activityCellCount do
	local col = (i - 1) % activityColumnCount
	local row = math.floor((i - 1) / activityColumnCount)
	statsOverlay[#statsOverlay + 1] = Def.ActorFrame {
		Name = "Activity" .. i,
		InitCommand = function(self)
			self:xy(activityGridX + (col * activityCellStepX), activityGridY + (row * activityCellStepY))
		end,
		UpdateCommand = function(self)
			if not isStatsOverlaySessionTab() then
				self:visible(false)
				return
			end
			local active = i <= activityMonthDayCount
			self:visible(active)
			if not active then return end
			local count = activityMonthCounts[i] or 0
			local fill = self:GetChild("Fill")
			local border = self:GetChild("Border")
			local dayText = self:GetChild("Day")
			if count > 0 and activityMonthMaxCount > 0 then
				local ratio = count / activityMonthMaxCount
				fill:diffuse(Brightness(getMainColor("positive"), 0.35 + (ratio * 0.85))):diffusealpha(0.4 + (ratio * 0.6))
			else
				fill:diffuse(color("#242424")):diffusealpha(1)
			end
			if i == selectedDay then
				border:visible(true):diffuse(getMainColor("highlight")):diffusealpha(0.9)
			elseif i == hoveredActivityDay then
				border:visible(true):diffuse(getMainColor("positive")):diffusealpha(0.55)
			else
				border:visible(false)
			end
			dayText:settext(tostring(i))
			dayText:diffuse(i == selectedDay and color("#FFFFFF") or color("#B8B8B8"))
		end,
		Def.Quad {
			Name = "Border",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(activityCellSize + 4, activityCellSize + 4):diffuse(getMainColor("highlight")):diffusealpha(0):visible(false)
			end
		},
		Def.Quad {
			Name = "Fill",
			InitCommand = function(self)
				self:xy(2, 2):halign(0):valign(0):zoomto(activityCellSize, activityCellSize):diffuse(color("#242424"))
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Day",
			InitCommand = function(self)
				self:xy(2 + (activityCellSize / 2), 2 + (activityCellSize / 2)):halign(0.5):valign(0.5):zoom(0.23):diffuse(color("#B8B8B8"))
			end
		}
	}
end

for i = 1, sessionRowCount do
	statsOverlay[#statsOverlay + 1] = sessionRow(i)
end

local function quickMenuItem(index, label)
	return Def.ActorFrame {
		Name = "QuickMenuItem" .. index,
		InitCommand = function(self)
			self:xy(quickMenuItemX, getQuickMenuItemTop(index))
		end,
		SetCommand = function(self)
			local hovered = quickMenuActive and pointInQuickMenuItem(INPUTFILTER:GetMouseX(), INPUTFILTER:GetMouseY(), index)
			self:GetChild("Backing"):diffusealpha(hovered and 0.32 or 0.18)
			self:GetChild("Label"):diffuse(hovered and getMainColor("positive") or color("#FFFFFF"))
		end,
		UpdateCommand = function(self)
			self:playcommand("Set")
		end,
		Def.Quad {
			Name = "Backing",
			InitCommand = function(self)
				self:halign(0):valign(0):zoomto(quickMenuItemWidth, quickMenuItemHeight):diffuse(color("#FFFFFF")):diffusealpha(0.18)
			end
		},
		LoadFont("Common Large") .. {
			Name = "Label",
			InitCommand = function(self)
				self:xy(12, quickMenuItemHeight / 2):halign(0):valign(0.5):zoom(0.34):settext(label)
			end
		}
	}
end

local quickMenu = Def.ActorFrame {
	Name = "QuickMenu",
	InitCommand = function(self)
		self:visible(false):diffusealpha(0):draworder(3100)
		self:SetUpdateFunction(function(actor)
			if quickMenuActive then
				actor:playcommand("Update")
			end
		end)
	end,
	QuickMenuStateChangedMessageCommand = function(self, params)
		if params.active then
			self:visible(true):stoptweening():linear(0.12):diffusealpha(1):queuecommand("Update")
		else
			self:stoptweening():linear(0.12):diffusealpha(0):queuecommand("HideIfClosed")
		end
	end,
	HideIfClosedCommand = function(self)
		if not quickMenuActive then
			self:visible(false)
		end
	end,
	UpdateCommand = function(self)
		for i = 1, 3 do
			self:GetChild("QuickMenuItem" .. i):playcommand("Update")
		end
	end,
	Def.Quad {
		InitCommand = function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(color("#000000")):diffusealpha(0.62)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(quickMenuPanelX, quickMenuPanelY):halign(0):valign(0):zoomto(quickMenuPanelWidth, quickMenuPanelHeight):diffuse(color("#101010")):diffusealpha(0.96)
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:xy(quickMenuPanelX, quickMenuPanelY):halign(0):valign(0):zoomto(quickMenuPanelWidth, 32):diffuse(color("#191919")):diffusealpha(0.98)
		end
	},
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(quickMenuPanelX + 14, quickMenuPanelY + 16):halign(0):valign(0.5):zoom(0.42):settext("Quick Menu")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(quickMenuPanelX + 14, quickMenuPanelY + quickMenuPanelHeight - 18):halign(0):valign(0.5):zoom(0.26):diffuse(color("#BBBBBB")):settext("Back / right click to close")
		end
	},
	quickMenuItem(1, "Service Menu"),
	quickMenuItem(2, "Player Options"),
	quickMenuItem(3, "Key Config")
}

local t = Def.ActorFrame {
	BeginCommand = function(self)
		local s = SCREENMAN:GetTopScreen()
		s:AddInputCallback(input)
		SCREENMAN:set_input_redirected(PLAYER_1, false)
		setenv("NewOptions","Main")
	end
}

t[#t + 1] = Def.Actor {
	ToggleMenuMessageCommand = function(self)
		setQuickMenuActive(not quickMenuActive)
	end,
	ToggleStatsOverlayMessageCommand = function(self)
		if quickMenuActive then
			setQuickMenuActive(false)
		end
		setStatsOverlayActive(not statsOverlayActive)
	end,
	SetStatsOverlayMessageCommand = function(self, params)
		if params and params.active and quickMenuActive then
			setQuickMenuActive(false)
		end
		setStatsOverlayActive(params and params.active)
	end,
	CodeMessageCommand = function(self, params)
		if params.Name == "AvatarShow" and getTabIndex() == 0 and not statsOverlayActive and not SCREENMAN:get_input_redirected(PLAYER_1) then
			SCREENMAN:SetNewScreen("ScreenAssetSettings")
		end
	end,
	OnCommand = function(self)
		inScreenSelectMusic = true
	end,
	EndCommand = function(self)
		if statsOverlayActive then
			SCREENMAN:set_input_redirected(PLAYER_1, statsOverlayInputRedirect)
			statsOverlayActive = false
		end
		if quickMenuActive then
			SCREENMAN:set_input_redirected(PLAYER_1, quickMenuInputRedirect)
			quickMenuActive = false
		end
		setenv("StatsOverlayActive", false)
		setenv("QuickMenuActive", false)
		inScreenSelectMusic = nil
	end,
}

t[#t + 1] = LoadActor("../_frame")
t[#t + 1] = LoadActor("../_PlayerInfo")

t[#t + 1] = quickMenu

t[#t + 1] = statsOverlay

t[#t + 1] = LoadActor("currentsort")

t[#t + 1] = LoadActor("../_cursor")
t[#t + 1] = LoadActor("../_halppls")

updateDiscordStatusForMenus()
updateNowPlaying()

return t
