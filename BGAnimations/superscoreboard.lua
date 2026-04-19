local tzoom = 0.5
local pdh = 48 * tzoom
local ygap = 2
local packspaceY = pdh + ygap
local currentCountry = "Global"

-- Helper function for relative time display
local function getRelativeTime(dateStr)
	if not dateStr or dateStr == "" then return "" end
	local y, m, d, h, min, s = dateStr:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
	if not y then return dateStr end
	local t = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
	local diff = os.time() - t
	if diff < 60 then return "just now"
	elseif diff < 3600 then return math.floor(diff/60) .. "m"
	elseif diff < 86400 then return math.floor(diff/3600) .. "h"
	elseif diff < 2592000 then return math.floor(diff/86400) .. "d"
	elseif diff < 31536000 then return math.floor(diff/2592000) .. "mo"
	else return math.floor(diff/31536000) .. "y" end
end

local numscores = 10
local ind = 0
local offx = 5
local width = SCREEN_WIDTH * 0.40
local dwidth = width - offx * 2
local height = 196

local pdh = 19.6
local packspaceY = pdh
local tzoom = 0.45 -- reduced slightly to fit two lines better

local moving
local cheese
local collapsed = false

-- Layout constants for various sub-elements
local adjx = 14
local c0x = 10
local c1x = 20 + c0x
local c2x = c1x + (tzoom * 7 * adjx)
local c5x = dwidth
local c4x = c5x - adjx - (tzoom * 3 * adjx)
local c3x = c4x - adjx - (tzoom * 10 * adjx)
local headeroff = 15 -- standard header offset
local row2yoff = 1

local isGlobalRanking = true

-- will eat any mousewheel inputs to scroll pages while mouse is over the background frame
local function input(event)
	if isOver(cheese:GetChild("FrameDisplay")) then -- visibility checks are built into isover now -mina
		if event.DeviceInput.button == "DeviceButton_mousewheel up" and event.type == "InputEventType_FirstPress" then
			moving = true
			cheese:queuecommand("PrevPage")
			return true
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" and event.type == "InputEventType_FirstPress" then
			cheese:queuecommand("NextPage")
			return true
		elseif moving == true then
			moving = false
		end
	end
	return false
end

local hoverAlpha = 0.6

local filts = {
	THEME:GetString("NestedScores", "FilterAll"),
	THEME:GetString("NestedScores", "FilterCurrent")
}
local topornah = {
	THEME:GetString("NestedScores", "ScoresTop"),
	THEME:GetString("NestedScores", "ScoresAll")
}
local ccornah = {
	THEME:GetString("NestedScores", "ShowInvalid"),
	THEME:GetString("NestedScores", "HideInvalid")
}

local translated_info = {
	LoginToView = THEME:GetString("NestedScores", "LoginToView"),
	NoScoresFound = THEME:GetString("NestedScores", "NoScoresFound"),
	RetrievingScores = THEME:GetString("NestedScores", "RetrievingScores"),
	Watch = THEME:GetString("NestedScores", "WatchReplay"),
	NoReplay = THEME:GetString("NestedScores", "NoReplay"),
}

local scoretable = {}
local o = Def.ActorFrame {
	Name = "ScoreDisplay",
	InitCommand = function(self)
		cheese = self
	end,
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		self:playcommand("Update")
	end,
	GetFilteredLeaderboardCommand = function(self)
		if GAMESTATE:GetCurrentSong() then
			scoretable = DLMAN:GetChartLeaderBoard(GAMESTATE:GetCurrentSteps():GetChartKey(), currentCountry)
			ind = 0
			self:playcommand("Update")
		end
	end,
	SetFromLeaderboardCommand = function(self, lb)
		scoretable = lb
		ind = 0
		self:playcommand("GetFilteredLeaderboard") -- we can move all the filter stuff to lua so we're not being dumb hurr hur -mina
		self:playcommand("Update")
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		-- Apply accent color to frame display
		local frame = self:GetChild("FrameDisplay")
		if frame and params and params.color then
			frame:playcommand("SetDynamicAccentColor", {color = params.color})
		end
	end,
	UpdateCommand = function(self)
		if not scoretable then
			ind = 0
			return
		end
		if ind == #scoretable then
			ind = ind - numscores
		elseif ind > #scoretable - (#scoretable % numscores) then
			ind = #scoretable - (#scoretable % numscores)
		end
		if ind < 0 then
			ind = 0
		end
	end,
	NextPageCommand = function(self)
		ind = ind + numscores
		self:queuecommand("Update")
	end,
	PrevPageCommand = function(self)
		ind = ind - numscores
		self:queuecommand("Update")
	end,
	CollapseCommand = function(self)
		tzoom = 0.5 * 0.75
		pdh = 38 * tzoom
		ygap = 2
		packspaceY = pdh + ygap

		numscores = 8
		ind = 0
		offx = 5
		width = math.max(SCREEN_WIDTH * 0.22, 200)
		dwidth = width - offx * 2
		height = (numscores + 2) * packspaceY

		adjx = 14
		c0x = 10
		c1x = 10 + c0x
		c2x = c1x + (tzoom * 7 * adjx)
		c5x = dwidth
		c4x = c5x - adjx - (tzoom * 3 * adjx)
		c3x = c4x - adjx - (tzoom * 10 * adjx)
		headeroff = packspaceY / 2
		row2yoff = 1
		collapsed = true
		self:diffusealpha(0.8)

		if
			-- a generic bounds check function that snaps an actor onto the screen or within specified coordinates should be added as an actor member, ie, not this -mina
			FILTERMAN:grabposx("ScoreDisplay") <= 10 or FILTERMAN:grabposy("ScoreDisplay") <= 45 or
				FILTERMAN:grabposx("ScoreDisplay") >= SCREEN_WIDTH - 60 or
				FILTERMAN:grabposy("ScoreDisplay") >= SCREEN_HEIGHT - 45
		 then
			self:xy(10, 45)
		else
			self:LoadXY()
		end

		FILTERMAN:HelpImTrappedInAChineseFortuneCodingFactory(true)
		self:playcommand("Init")
	end,
	ExpandCommand = function(self)
		tzoom = 0.5
		pdh = 48 * tzoom
		ygap = 2
		packspaceY = pdh + ygap

		numscores = 13
		ind = 0
		offx = 5
		width = SCREEN_WIDTH * 0.56
		dwidth = width - offx * 2
		height = (numscores + 2) * packspaceY - packspaceY / 3

		adjx = 14
		c0x = 10
		c1x = 20 + c0x
		c2x = c1x + (tzoom * 7 * adjx) -- guesswork adjustment for epxected text length
		c5x = dwidth -- right aligned cols
		c4x = c5x - adjx - (tzoom * 3 * adjx) -- right aligned cols
		c3x = c4x - adjx - (tzoom * 10 * adjx) -- right aligned cols
		headeroff = packspaceY / 2
		row2yoff = 1
		collapsed = false
		self:diffusealpha(1)
		FILTERMAN:HelpImTrappedInAChineseFortuneCodingFactory(false)
		self:playcommand("Init")
	end,
	UIElements.QuadButton(1, 1) .. {-- this is a nonfunctional button to mask buttons behind the window
		Name = "FrameDisplay",
		SetDynamicAccentColorMessageCommand = function(self, params)
			if params and params.color then
				self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.8)
			end
		end,
		UpdateCommand = function(self)
			self:zoomto(width, height)
		end,
		MouseRightClickMessageCommand = function(self)
			if isOver(self) and not collapsed then
				FILTERMAN:HelpImTrappedInAChineseFortuneCodingFactory(true)
				self:GetParent():GetParent():playcommand("Collapse")
			elseif isOver(self) then
				self:GetParent():GetParent():playcommand("Expand")
			end
		end
	},
	-- headers
	Def.Quad {
		Name = "HeaderBar",
		InitCommand = function(self)
			self:zoomto(width, 30):halign(0):valign(0):diffuse(getMainColor("frames")):diffusebottomedge(color("#000000")):diffusealpha(0.9)
		end
	},
	-- grabby thing
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:valign(1):halign(0)
			self:xy(dwidth / 4, headeroff):zoomto(dwidth - dwidth / 4, pdh - 8 * tzoom)
			self:diffuse(getMainColor("frames"))
			self:diffusealpha(0)
		end,
		CollapseCommand = function(self)
			self:zoomto(dwidth / 2, pdh / 2):diffusealpha(0.5)
		end,
		ExpandCommand = function(self)
			self:diffusealpha(0):zoomto(400, 400):valign(0.5):halign(0.5)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and collapsed then
				self:diffusealpha(0.6):diffuse(color("#fafafa"))
				self.initialClickX = params.MouseX - self:GetTrueX()
				self.initialClickY = params.MouseY - self:GetTrueY()
			elseif params.event == "DeviceButton_right mouse button" and collapsed then
				self:zoomto(dwidth / 2, pdh / 2):valign(1):halign(0)
			end
		end,
		MouseUpCommand = function(self, params)
			self.gettindragged = false
			if params.event == "DeviceButton_left mouse button" and collapsed then
				self:diffusealpha(0.5):diffuse(getMainColor("frames"))
			end
		end,
		MouseReleaseCommand = function(self, params)
			self.gettindragged = false
			if params.event == "DeviceButton_left mouse button" and collapsed then
				self:diffusealpha(0.5):diffuse(getMainColor("frames"))
			end
		end,
		MouseDragCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and collapsed then
				local nx = params.MouseX - self:GetX() - self.initialClickX or 0
				local ny = params.MouseY - self:GetY() - self.initialClickY or 0
				self:GetParent():SaveXY(nx, ny)
				self:GetParent():LoadXY()
				self.gettindragged = true
			end
		end,
		MouseOutCommand = function(self)
			if not collapsed then return end
			if self.gettindragged then return end -- dragging fast triggers this
			self:diffuse(getMainColor("frames")):diffusealpha(0.5)
		end,
		MouseOverCommand = function(self)
			if not collapsed then return end
			self:diffusealpha(1)
		end,
	},
	LoadFont("Common normal") .. {
		-- informational text about online scores
		Name = "RequestStatus",
		InitCommand = function(self)
			if collapsed then
				self:xy(c1x, headeroff + 15):zoom(tzoom):halign(0)
			else
				self:xy(c1x, headeroff + 25):zoom(tzoom):halign(0)
			end
		end,
		UpdateCommand = function(self)
			local numberofscores = scoretable ~= nil and #scoretable or 0
			local online = DLMAN:IsLoggedIn()
			if not GAMESTATE:GetCurrentSong() then
				self:settext("")
			elseif not online and scoretable ~= nil and #scoretable == 0 then
				self:settext(translated_info["LoginToView"])
			else
				if scoretable ~= nil and #scoretable == 0 then
					self:settext(translated_info["NoScoresFound"])
				elseif scoretable == nil then
					self:settext("Chart is not ranked")
				else
					self:settext("")
				end
			end
		end,
		CurrentSongChangedMessageCommand = function(self)
			local online = DLMAN:IsLoggedIn()
			if not GAMESTATE:GetCurrentSong() then
				self:settext("")
			elseif not online and scoretable ~= nil and #scoretable == 0 then
				self:settext(translated_info["LoginToView"])
			elseif scoretable == nil then
				self:settext("Chart is not ranked")
			else
				self:settext(translated_info["NoScoresFound"])
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		-- No filter button (matches local "No filter")
		InitCommand = function(self)
			self:xy(width - 50, 15):zoom(0.4):halign(0.5):valign(0.5)
			self:diffuse(getMainColor("positive"))
			self:settext("No filter")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				DLMAN:ToggleRateFilter()
				ind = 0
				self:GetParent():queuecommand("GetFilteredLeaderboard")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		-- Accuracy button (instead of Performance)
		InitCommand = function(self)
			self:xy(width / 2, 15):zoom(0.4):halign(0.5):valign(0.5)
			self:diffuse(getMainColor("positive"))
			self:settext("Accuracy")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				-- Sort logic
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		-- Leaderboard button - switches back to local
		InitCommand = function(self)
			self:xy(50, 15):zoom(0.4):halign(0.5):valign(0.5)
			self:diffuse(getMainColor("highlight"))
			self:settext("Leaderboard")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				MESSAGEMAN:Broadcast("SwitchToLocalScores")
			end
		end
	}
}

local function makeScoreDisplay(i)
	local hs

	local o = Def.ActorFrame {
		Name = "Scoredisplay_"..i,
		InitCommand = function(self)
			self:y(30 + packspaceY * (i - 1))
		end,
		UpdateCommand = function(self)
			if scoretable ~= nil then
				hs = scoretable[(i + ind)]
			else
				hs = nil
			end
			if hs and i <= numscores then
				self:visible(true)
				self:playcommand("Display")
			else
				self:visible(false)
			end
		end,
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:x(0):zoomto(width, pdh):halign(0)
				self:diffuse(color("#111111")):diffusealpha(0.4)
			end,
		},
		-- Row border
		Def.Quad {
			InitCommand = function(self)
				self:zoomto(width, 1):halign(0):valign(1):y(pdh/2):diffusealpha(0.05)
			end
		},
		-- Line 1: #Rank Username · Score% (Left)
		LoadFont("Common normal") .. {
			InitCommand = function(self)
				self:x(10):zoom(tzoom + 0.1):halign(0):valign(1):y(-1)
			end,
			DisplayCommand = function(self)
				local perc = hs:GetWifeScore() * 100
				local percStr = string.format(perc > 99.65 and "%.4f%%" or "%.2f%%", perc)
				self:settextf("#%i %s · %s", i + ind, hs:GetDisplayName(), percStr)
				self:diffuse(getGradeColor(hs:GetWifeGrade()))
			end
		},
		-- Line 2: ClearType · Notes · SSR (Left)
		LoadFont("Common normal") .. {
			InitCommand = function(self)
				self:x(10):zoom(tzoom - 0.05):halign(0):valign(0):y(1)
			end,
			DisplayCommand = function(self)
				local clearText = getClearTypeFromScore(PLAYER_1, hs, 0)
				local ssr = hs:GetSkillsetSSR("Overall")
				local notes = "--"
				local steps = GAMESTATE:GetCurrentSteps()
				if steps then
					local radar = steps:GetRadarValues(PLAYER_1)
					if radar then
						notes = string.format("%d", radar:GetValue("RadarCategory_Notes"))
					end
				end
				self:settextf("%s · %sx · %.2f", clearText, notes, ssr)
				self:diffuse(color("#CCCCCC"))
			end
		},
		-- Rate (Top Right)
		LoadFont("Common normal") .. {
			InitCommand = function(self)
				self:x(width - 10):zoom(tzoom):halign(1):valign(1):y(-1)
			end,
			DisplayCommand = function(self)
				local rate = hs:GetMusicRate()
				local curRate = notShit.round(GAMESTATE:GetSongOptionsObject("ModsLevel_Current"):MusicRate(), 2)
				local rateStr = string.format("%.2fx", rate)
				if math.abs(rate - curRate) < 0.001 then
					rateStr = rateStr .. ", MR"
				end
				self:settext(rateStr)
			end
		},
		-- Time (Bottom Right)
		LoadFont("Common normal") .. {
			InitCommand = function(self)
				self:x(width - 10):zoom(tzoom - 0.05):halign(1):valign(0):y(1)
			end,
			DisplayCommand = function(self)
				self:settext(getRelativeTime(hs:GetDate()))
				self:diffuse(color("#AAAAAA"))
			end
		}
	}
	return o
end

for i = 1, numscores do
	o[#o + 1] = makeScoreDisplay(i)
end

--[[
--Commented for now
-- Todo: make the combobox scrollable
-- To handle a large amount of choices
local countryDropdown
countryDropdown =
	Widg.ComboBox {
	onSelectionChanged = function(newChoice)
		currentCountry = newChoice
		cheese:queuecommand("ChartLeaderboardUpdate")
	end,
	choice = "Global",
	choices = DLMAN:GetCountryCodes(),
	commands = {
		CollapseCommand = function(self)
			self:xy(c5x - 20, headeroff - 20):halign(0)
		end,
		ExpandCommand = function(self)
			self:xy(c5x - 89, headeroff)
		end,
		ChartLeaderboardUpdateMessageCommand = function(self)
			self:visible(DLMAN:IsLoggedIn())
		end
	},
	selectionColor = color("#111111"),
	itemColor = color("#111111"),
	hoverColor = getMainColor("highlight"),
	height = tzoom * 29,
	width = 50,
	x = c5x - 89, -- needs to be thought out for design purposes
	y = headeroff,
	visible = DLMAN:IsLoggedIn(),
	numitems = 4
}
o[#o + 1] = countryDropdown
]]
return o
