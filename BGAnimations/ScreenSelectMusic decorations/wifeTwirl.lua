local profile = PROFILEMAN:GetProfile(PLAYER_1)
local frameX = 20
local frameY = 280
local frameWidth = capWideScale(get43size(400), 400)
local score
local song
local steps
local noteField = false
local infoOnScreen = false
local heyiwasusingthat = false
local mcbootlarder
local pOptions = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
local usingreverse = pOptions:UsingReverse()
local prevX = capWideScale(get43size(98), 98)
local prevY = 55
local prevrevY = 60
local boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = false
local hackysack = false
local songChanged = false
local songChanged2 = false
local previewVisible = false
local onlyChangedSteps = false
local shouldPlayMusic = false
local prevtab = 0
local ctags = {}

local itsOn = false

local translated_info = {
	GoalTarget = THEME:GetString("ScreenSelectMusic", "GoalTargetString"),
	MaxCombo = THEME:GetString("ScreenSelectMusic", "MaxCombo"),
	BPM = THEME:GetString("ScreenSelectMusic", "BPM"),
	NegBPM = THEME:GetString("ScreenSelectMusic", "NegativeBPM"),
	UnForceStart = THEME:GetString("GeneralInfo", "UnforceStart"),
	ForceStart = THEME:GetString("GeneralInfo", "ForceStart"),
	Unready = THEME:GetString("GeneralInfo", "Unready"),
	Ready = THEME:GetString("GeneralInfo", "Ready"),
	TogglePreview = THEME:GetString("ScreenSelectMusic", "TogglePreview"),
	PlayerOptions = THEME:GetString("ScreenSelectMusic", "PlayerOptions"),
}

-- to reduce repetitive code for setting preview music position with booleans
local function playMusicForPreview(song)
	SOUND:StopMusic()
	SCREENMAN:GetTopScreen():PlayCurrentSongSampleMusic(true, true)
	MESSAGEMAN:Broadcast("PreviewMusicStarted") -- this is lying tbh

	restartedMusic = true

	-- use this opportunity to set all the random booleans to make it consistent
	songChanged = false
	boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = false
	hackysack = false
end

-- to toggle calc info display stuff
local function toggleCalcInfo(state)
	infoOnScreen = state

	if infoOnScreen then
		MESSAGEMAN:Broadcast("CalcInfoOn")
	else
		MESSAGEMAN:Broadcast("CalcInfoOff")
	end
end

local hoverAlpha = 0.8
local hoverAlpha2 = 0.6

-- to reduce repetitive code for setting preview visibility with booleans
local function setPreviewPartsState(state)
	if state == nil then return end
	mcbootlarder:visible(state)
	mcbootlarder:GetChild("NoteField"):visible(state)
	heyiwasusingthat = not state
	previewVisible = state
	if state ~= infoOnScreen and not state then
		toggleCalcInfo(false)
	end
end

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

local function getScoreDateRelative(score)
	if not score then return "" end
	return getRelativeTime(score:GetDate())
end

local function toggleNoteField()
	local nf = mcbootlarder:GetChild("NoteField")
	if song and not noteField then -- first time setup
		noteField = true
		MESSAGEMAN:Broadcast("ChartPreviewOn") -- for banner reaction... lazy -mina
		mcbootlarder:playcommand("SetupNoteField")
		mcbootlarder:xy(prevX, prevY)
		mcbootlarder:diffusealpha(1)

		pOptions = GAMESTATE:GetPlayerState():GetCurrentPlayerOptions()
		usingreverse = pOptions:UsingReverse()
		local usingscrollmod = false
		if pOptions:Split() ~= 0 or pOptions:Alternate() ~= 0 or pOptions:Cross() ~= 0 or pOptions:Centered() ~= 0 then
			usingscrollmod = true
		end

		nf:y(prevY * 2.85)
		if usingscrollmod then
			nf:y(prevY * 3.55)
		elseif usingreverse then
			nf:y(prevY * 2.85 + prevrevY)
		end

		if not songChanged then
			playMusicForPreview(song)
			tryingToStart = true
		else
			tryingToStart = false
		end
		songChanged = false
		hackysack = false
		previewVisible = true
		return true
	end

	if song then
		nf:diffusealpha(1)
		if mcbootlarder:IsVisible() then
			mcbootlarder:visible(false)
			nf:visible(false)
			MESSAGEMAN:Broadcast("ChartPreviewOff")
			toggleCalcInfo(false)
			previewVisible = false
			hackysack = changingSongs
			changingSongs = false
			return false
		else
			mcbootlarder:visible(true)
			nf:visible(true)
			if boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone or songChanged or songChanged2 then
				if not restartedMusic then
					playMusicForPreview(song)
				end
				boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = false
				hackysack = false
				songChanged = false
				songChanged2 = false
			end
			MESSAGEMAN:Broadcast("ChartPreviewOn")
			previewVisible = true
			return true
		end
	end
	return false
end

local mintyFreshIntervalFunction = nil
local update = false
local t = Def.ActorFrame {
	Name = "wifetwirler",
	BeginCommand = function(self)
		self:queuecommand("MintyFresh")
	end,
	OffCommand = function(self)
		self:bouncebegin(0.2):xy(-500, 0):diffusealpha(0)
		toggleCalcInfo(false)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
	end,
	OnCommand = function(self)
		self:bouncebegin(0.2):xy(0, 0):diffusealpha(1)
	end,
	CurrentSongChangedMessageCommand = function()
		-- This will disable mirror when switching songs if OneShotMirror is enabled or if permamirror is flagged on the chart (it is enabled if so in screengameplayunderlay/default)
		if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).OneShotMirror or profile:IsCurrentChartPermamirror() then
			local modslevel = topscreen == "ScreenEditOptions" and "ModsLevel_Stage" or "ModsLevel_Preferred"
			local playeroptions = GAMESTATE:GetPlayerState():GetPlayerOptions(modslevel)
			playeroptions:Mirror(false)
		end
		-- if not on General and we started the noteField and we changed tabs then changed songs
		-- this means the music should be set again as long as the preview is still "on" but off screen
		if getTabIndex() ~= 0 and noteField and heyiwasusingthat then
			boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = true
		end

		-- if the preview was turned on ever but is currently not on screen as the song changes
		-- this goes hand in hand with the above boolean
		if noteField and not previewVisible then
			songChanged = true
		end

		-- check to see if the song actually really changed
		-- >:(
		if noteField and GAMESTATE:GetCurrentSong() ~= song then
			-- always true if switching songs and preview has ever been opened
			songChanged2 = true
			restartedMusic = false
		else
			songChanged2 = false
		end

		-- an awkwardly named bool describing the fact that we just changed songs
		-- used in notefield creation function to see if we should restart music
		-- it is immediately turned off when toggling notefield
		changingSongs = true
		tryingToStart = false

		-- if switching songs, we want the notedata to disappear temporarily
		if noteField and songChanged2 and previewVisible then
			mcbootlarder:GetChild("NoteField"):finishtweening()
			mcbootlarder:GetChild("NoteField"):diffusealpha(0)
		end
	end,
	DelayedChartUpdateMessageCommand = function(self)
		-- wait for the music wheel to settle before playing the music
		-- to keep things very slightly more easy to deal with
		-- and reduce a tiny bit of lag
		local s = GAMESTATE:GetCurrentSong()
		local unexpectedlyChangedSong = s ~= song

		shouldPlayMusic = false
		-- should play the music because the notefield is visible
		shouldPlayMusic = shouldPlayMusic or (noteField and mcbootlarder:GetChild("NoteField") and mcbootlarder:GetChild("NoteField"):IsVisible())
		-- should play the music if we switched songs while on a different tab
		shouldPlayMusic = shouldPlayMusic or boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone
		-- should play the music if we switched to a song from a pack tab
		-- also applies for if we just toggled the notefield or changed screen tabs
		shouldPlayMusic = shouldPlayMusic or hackysack
		-- should play the music if we already should and we either jumped song or we didnt change the song
		shouldPlayMusic = shouldPlayMusic and (not onlyChangedSteps or unexpectedlyChangedSong) and not tryingToStart

		-- at this point the music will or will not play ....

		boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = false
		hackysack = false
		tryingToStart = false
		songChanged = false
		onlyChangedSteps = true
	end,
	PlayingSampleMusicMessageCommand = function(self)
		-- delay setting the music for preview up until after the sample music starts (smoothness)
		if shouldPlayMusic then
			shouldPlayMusic = false
			local s = GAMESTATE:GetCurrentSong()
			if s then
				if mcbootlarder and mcbootlarder:GetChild("NoteField") then mcbootlarder:GetChild("NoteField"):diffusealpha(1) end
				playMusicForPreview(s)
			end
		end
	end,
	MintyFreshCommand = function(self)
		self:finishtweening()
		local bong = GAMESTATE:GetCurrentSong()
		-- if not on a song and preview is on, hide it (dont turn it off)
		if not bong and noteField and mcbootlarder:IsVisible() then
			setPreviewPartsState(false)
			MESSAGEMAN:Broadcast("ChartPreviewOff")
		end

		-- if the song changed
		if song ~= bong then
			if not lockbools then
				onlyChangedSteps = false
			end
			if not song and previewVisible and not lockbools then
				hackysack = true -- used in cases when moving from null song (pack hover) to a song (this fixes searching and preview not working)
			end
			song = bong
			self:queuecommand("MortyFarts")
		else
			if not lockbools and not songChanged2 then
				onlyChangedSteps = true
			end
		end

		-- on general tab
		if getTabIndex() == 0 then
			-- if preview was on and should be made visible again
			if heyiwasusingthat and bong and noteField then
				setPreviewPartsState(true)
				MESSAGEMAN:Broadcast("ChartPreviewOn")
			elseif bong and noteField and previewVisible then
				-- make sure that it is visible even if it isnt, when it should be
				-- (haha lets call this 1000000 times nothing could go wrong)
				setPreviewPartsState(true)
			end

			self:visible(true)
			self:queuecommand("On")
			update = true
		else
			-- changing tabs off of general with preview on, hide the preview
			if bong and noteField and mcbootlarder:IsVisible() then
				setPreviewPartsState(false)
				MESSAGEMAN:Broadcast("ChartPreviewOff")
			end

			self:queuecommand("Off")
			update = false
		end
		lockbools = false
	end,
	TabChangedMessageCommand = function(self)
		local newtab = getTabIndex()
		if newtab ~= prevtab then
			self:queuecommand("MintyFresh")
			prevtab = newtab
			if getTabIndex() == 0 and noteField then
				mcbootlarder:GetChild("NoteField"):diffusealpha(1)
				lockbools = true
			elseif getTabIndex() ~= 0 and noteField then
				hackysack = mcbootlarder:IsVisible()
				onlyChangedSteps = false
				boolthatgetssettotrueonsongchangebutonlyifonatabthatisntthisone = false
				lockbools = true
			end
		end
	end,
	MilkyTartsCommand = function(self) -- when entering pack screenselectmusic explicitly turns visibilty on notefield off -mina
		if noteField and mcbootlarder:IsVisible() then
			toggleCalcInfo(false)
		end
	end,
	CurrentStepsChangedMessageCommand = function(self)
		-- this basically queues MintyFresh every 0.5 seconds but only once and also resets the 0.5 seconds
		-- if you scroll again
		-- so if you scroll really fast it doesnt pop at all until you slow down
		-- lag begone
		local topscr = SCREENMAN:GetTopScreen()

		if mintyFreshIntervalFunction ~= nil then
			topscr:clearInterval(mintyFreshIntervalFunction)
			mintyFreshIntervalFunction = nil
		end
		mintyFreshIntervalFunction = topscr:setInterval(function()
			self:queuecommand("MintyFresh")
			if mintyFreshIntervalFunction ~= nil then
				topscr:clearInterval(mintyFreshIntervalFunction)
				mintyFreshIntervalFunction = nil
			end
		end,
		0.05)
	end,
}


-- State update helper (crucial for InfoDisplayPanel)
t[#t + 1] = Def.Actor {
	MintyFreshCommand = function(self)
		song = GAMESTATE:GetCurrentSong()
		score = GetDisplayScore()
		if song then
			steps = GAMESTATE:GetCurrentSteps()
		end
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:queuecommand("MintyFresh")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		self:queuecommand("MintyFresh")
	end,
	CurrentRateChangedMessageCommand = function(self)
		self:queuecommand("MintyFresh")
	end
}

-- Information Display Panel
t[#t + 1] = Def.ActorFrame {
	Name = "InfoDisplayPanel",
	InitCommand = function(self)
		self:xy(frameX, frameY + 30)
	end,

	-- ROW 1: Colored status boxes
	(function()
		local boxW = (frameWidth - 10) / 3
		local boxH = 30
		local f = Def.ActorFrame{}
		
		-- Box backgrounds
		local function makeBoxBG(xIdx)
			return Def.Quad {
				InitCommand = function(self)
					self:xy((boxW * xIdx) + (5 * xIdx), 0):zoomto(boxW, boxH)
					self:halign(0):valign(0)
					self:diffuse(color("#000000")):diffusealpha(0.6)
				end
			}
		end
		f[#f+1] = makeBoxBG(0)
		f[#f+1] = makeBoxBG(1)
		f[#f+1] = makeBoxBG(2)

		-- Left Box: Skillset
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(boxW/2, boxH/2):zoom(0.35):halign(0.5):valign(0.5):diffuse(color("#FFFFFF"))
			end,
			MintyFreshCommand = function(self)
				if song and GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() == 4 then
					local ss = steps:GetRelevantSkillsetsByMSDRank(getCurRateValue(), 1)
					local out = ss == "" and "Uncategorised" or ms.SkillSetsTranslatedByName[ss]
					self:settext(out)
				else
					self:settext("Uncategorised")
				end
			end
		}

		-- Center Box: Clear Type
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(boxW + 5 + boxW/2, boxH/2 - 4):zoom(0.3):halign(0.5):valign(0.5)
			end,
			MintyFreshCommand = function(self)
				if score then
					self:settext(getClearTypeFromScore(PLAYER_1, score, 0))
					self:diffuse(getClearTypeFromScore(PLAYER_1, score, 2))
				else
					self:settext("--"):diffuse(color("#666666"))
				end
			end
		}
		f[#f+1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(boxW + 5 + boxW/2, boxH - 8):zoom(0.25):halign(0.5):valign(0.5):diffuse(color("#BBBBBB"))
			end,
			MintyFreshCommand = function(self)
				if score then
					self:settextf("(%.2fx) \183 %s", score:GetMusicRate(), getScoreDateRelative(score))
				else
					self:settext("")
				end
			end
		}

		-- Right Box: Score
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy((boxW*2) + 10 + boxW/2, boxH/2 - 4):zoom(0.3):halign(0.5):valign(0.5)
			end,
			MintyFreshCommand = function(self)
				if score then
					local perc = score:GetWifeScore() * 100
					self:settextf("%.2f%%", perc)
					self:diffuse(byGrade(score:GetWifeGrade()))
				else
					self:settext("--"):diffuse(color("#666666"))
				end
			end
		}
		f[#f+1] = LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy((boxW*2) + 10 + boxW/2, boxH - 8):zoom(0.25):halign(0.5):valign(0.5):diffuse(color("#00FF00"))
			end,
			MintyFreshCommand = function(self)
				if score then
					self:settextf("(%.2fx) \183 %s", score:GetMusicRate(), getScoreDateRelative(score))
					self:diffuse(color("#00FF00"))
				else
					self:settext("")
				end
			end
		}
		
		return f
	end)(),

	-- ROW 2: Rate (Left) & Last Played (Right)
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(0, 40):zoom(0.3):halign(0):valign(0):diffuse(color("#FFFFFF"))
		end,
		MintyFreshCommand = function(self)
			self:settextf("%.2fx", getCurRateValue())
		end
	},
	LoadFont("Common Large") .. {
		InitCommand = function(self)
			self:xy(frameWidth, 40):zoom(0.3):halign(1):valign(0):diffuse(color("#FFFFFF"))
		end,
		MintyFreshCommand = function(self)
			if score then
				self:settext("Last played " .. getScoreDateRelative(score))
			else
				self:settext("Never played")
			end
		end
	},

	-- ROW 3: Chart string (Left) & Radar string (Right)
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(0, 52):zoom(0.27):halign(0):valign(0):diffuse(color("#DDDDDD"))
		end,
		MintyFreshCommand = function(self)
			if steps then
				local stype = steps:GetStepsType():gsub("StepsType_","")
				local diff = ToEnumShortString(steps:GetDifficulty())
				local meter = steps:GetMeter()
				self:settextf("%s %s %d", stype, diff, meter)
			else
				self:settext("")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth, 52):zoom(0.27):halign(1):valign(0):diffuse(color("#DDDDDD"))
		end,
		MintyFreshCommand = function(self)
			if steps then
				local stype = steps:GetStepsType():gsub("StepsType_","")
				local notes = steps:GetRadarValues(PLAYER_1):GetValue("RadarCategory_Notes")
				local holds = steps:GetRadarValues(PLAYER_1):GetValue("RadarCategory_Holds")
				self:settextf("%s | %d Notes | %d Holds", stype, notes, holds)
			else
				self:settext("")
			end
		end
	},

	-- ROW 4: Icons (Star, Note, Clock)
	(function()
		local icY = 76
		local f = Def.ActorFrame{}
		-- MSD Rate
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(0, icY):zoom(0.45):halign(0):valign(0.5)
			end,
			MintyFreshCommand = function(self)
				if steps then
					local msd = steps:GetMSD(getCurRateValue(), 1)
					self:settextf("%.2f", msd)
					self:diffuse(byMSD(msd))
				else
					self:settext("--"):diffuse(color("#666666"))
				end
			end
		}

		-- Note Icon
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(frameWidth/2 - 20, icY):zoom(0.4):halign(1):valign(0.5):diffuse(color("#FFFFFF"))
				self:settext("♪")
			end
		}
		-- BPM
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(frameWidth/2 - 15, icY):zoom(0.45):halign(0):valign(0.5):diffuse(color("#FFFFFF"))
			end,
			MintyFreshCommand = function(self)
				if steps then
					local bpmVals = steps:GetDisplayBpms()
					if bpmVals and bpmVals[2] then
						local bpm = bpmVals[2] * getCurRateValue()
						self:settextf("%d", math.floor(bpm + 0.5))
					else
						self:settext("--")
					end
				else
					self:settext("--")
				end
			end
		}

		-- Clock Icon
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(frameWidth - 45, icY):zoom(0.4):halign(1):valign(0.5):diffuse(color("#FFFFFF"))
				self:settext("⏱")
			end
		}
		-- Duration
		f[#f+1] = LoadFont("Common Large") .. {
			InitCommand = function(self)
				self:xy(frameWidth - 40, icY):zoom(0.45):halign(0):valign(0.5):diffuse(color("#FFFFFF"))
			end,
			MintyFreshCommand = function(self)
				if song then
					self:settext(SecondsToMSS(song:GetStepsSeconds() / getCurRateValue()))
				else
					self:settext("--:--")
				end
			end
		}
		return f
	end)()
}



local enabledC = "#099948"
local disabledC = "#ff6666"
local force = false
local ready = false
local function toggleButton(textEnabled, textDisabled, msg, x, extrawidth, y, enabledF)
	local ison = false
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(10 - 115 + capWideScale(get43size(384), 384) + x, 66 + capWideScale(get43size(120), 120) + y)
			self.updatebutton = function()
				if self.ison ~= nil then
					ison = self.ison
				end

				-- wtf
				self:GetChild("Top"):diffuse((ison and color(enabledC) or (isOver(self:GetChild("Top")) and getMainColor("highlight") or color(disabledC))))
				self:GetChild("Words"):settext(ison and textEnabled or textDisabled)
			end
		end,

		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:zoomto(50 + extrawidth + 1.5, 24 + 1.5)
				self:diffuse(color("#333333"))
			end,
		},
		UIElements.QuadButton(1, 1) .. {
			Name = "Top",
			InitCommand = function(self)
				self:zoomto(50 + extrawidth, 24)
				self:diffuse(color(disabledC))
			end,
			MouseOverCommand = function(self)
				self:diffuse(ison and color(enabledC) or getMainColor("highlight"))
			end,
			MouseOutCommand = function(self)
				self:diffuse(color(ison and enabledC or disabledC))
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					if enabledF then
						ison = enabledF()
					else
						ison = (not ison)
					end
					
					-- wtf 2
					self:diffuse(ison and color(enabledC) or getMainColor("highlight"))
					NSMAN:SendChatMsg(msg, 1, NSMAN:GetCurrentRoomName())
				end
			end,
		},
		LoadFont("Common Large") .. {
			Name = "Words",
			InitCommand = function(self)
				self:zoom(0.3)
				self:diffuse(color("#FFFFFF"))
				self:maxwidth((50 + extrawidth) / 0.3)
				self:settext(textDisabled)
			end,
		},
	}
end
local forceStart = toggleButton(translated_info["UnForceStart"], translated_info["ForceStart"], "/force", -35, 30, 11) .. {
	Name = "ForceStart",
}
local readyButton = nil
do
	-- do-end block to minimize the scope of 'f'
	local areWeReadiedUp = function()
		local top = SCREENMAN:GetTopScreen()
		if top:GetName() == "ScreenNetSelectMusic" then
			local qty = top:GetUserQty()
			local loggedInUser = NSMAN:GetLoggedInUsername()
			for i = 1, qty do
				local user = top:GetUser(i)
				if user == loggedInUser then
					return top:GetUserReady(i)
				end
			end
			-- ???? this should never happen
			-- retroactive - had this happen once and i still dont know why
			error "Could not find ourselves in the userlist"
		end
	end
	readyButton = toggleButton(translated_info["Unready"], translated_info["Ready"], "/ready", 50, 0, 11, areWeReadiedUp) .. {
		Name = "Ready",
		UsersUpdateMessageCommand = function(self)
			self.ison = areWeReadiedUp()
			self.updatebutton()
		end
	}
end

local sn = Var ("LoadingScreen")
if sn and sn:find("Net") ~= nil then
	t[#t + 1] = forceStart
	t[#t + 1] = readyButton
end

-- t[#t+1] = LoadFont("Common Large") .. {
-- InitCommand=function(self)
-- 	self:xy((capWideScale(get43size(384),384))+68,SCREEN_BOTTOM-135):halign(1):zoom(0.4,maxwidth,125)
-- end,
-- BeginCommand=function(self)
-- 	self:queuecommand("Set")
-- end,
-- SetCommand=function(self)
-- if song then
-- self:settext(song:GetOrTryAtLeastToGetSimfileAuthor())
-- else
-- self:settext("")
-- end
-- end,
-- CurrentStepsChangedMessageCommand=function(self)
-- 	self:queuecommand("Set")
-- end,
-- RefreshChartInfoMessageCommand=function(self)
-- 	self:queuecommand("Set")
-- end,
-- }

-- active filters display
-- t[#t+1] = Def.Quad{InitCommand=cmd(xy,16,capWideScale(SCREEN_TOP+172,SCREEN_TOP+194);zoomto,SCREEN_WIDTH*1.35*0.4 + 8,24;halign,0;valign,0.5;diffuse,color("#000000");diffusealpha,0),
-- EndingSearchMessageCommand=function(self)
-- self:diffusealpha(1)
-- end
-- }
-- t[#t+1] = LoadFont("Common Large") .. {
-- InitCommand=function(self)
-- 	self:xy(20,capWideScale(SCREEN_TOP+170,SCREEN_TOP+194)):halign(0):zoom(0.4):settext("Active Filters: "..GetPersistentSearch()):maxwidth(SCREEN_WIDTH*1.35)
-- end,
-- EndingSearchMessageCommand=function(self, msg)
-- self:settext("Active Filters: "..msg.ActiveFilter)
-- end
-- }

-- tags?
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameX + 300, frameY - 60):halign(0):zoom(0.6):maxwidth(capWideScale(54, 450) / 0.6)
	end,
	MintyFreshCommand = function(self)
		if song and ctags[1] then
			self:settext(ctags[1])
		else
			self:settext("")
		end
	end,
	ChartPreviewOnMessageCommand = function(self)
		self:visible(false)
	end,
	ChartPreviewOffMessageCommand = function(self)
		self:visible(true)
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameX + 300, frameY - 30):halign(0):zoom(0.6):maxwidth(capWideScale(54, 450) / 0.6)
	end,
	MintyFreshCommand = function(self)
		if song and ctags[2] then
			self:settext(ctags[2])
		else
			self:settext("")
		end
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameX + 300, frameY):halign(0):zoom(0.6):maxwidth(capWideScale(54, 450) / 0.6)
	end,
	MintyFreshCommand = function(self)
		if song and ctags[3] then
			self:settext(ctags[3])
		else
			self:settext("")
		end
	end
}

--Chart Preview Button
local yesiwantnotefield = false
local lastratepresses = {0,0}
local function ihatestickinginputcallbackseverywhere(event)
	if event.type ~= "InputEventType_Release" and getTabIndex() == 0 then
		if event.DeviceInput.button == "DeviceButton_space" then
			toggleNoteField()
		end
		if event.GameButton == "EffectUp" then
			lastratepresses[1] = 0
		end
		if event.GameButton == "EffectDown" then
			lastratepresses[2] = 0
		end
	end
	if event.type == "InputEventType_FirstPress" then
		local CtrlPressed = INPUTFILTER:IsControlPressed()
		if CtrlPressed and event.DeviceInput.button == "DeviceButton_l" then
			MESSAGEMAN:Broadcast("LoginHotkeyPressed")
		end
		if event.GameButton == "EffectUp" then
			lastratepresses[1] = GetTimeSinceStart()
		end
		if event.GameButton == "EffectDown" then
			lastratepresses[2] = GetTimeSinceStart()
		end
		-- this sucks so bad
		if math.abs(lastratepresses[1] - lastratepresses[2]) < 0.05 and lastratepresses[1] ~= 0 and lastratepresses[2] ~= 0 then
			MESSAGEMAN:Broadcast("Code", {Name="ResetRate"})
			ChangeMusicRate(nil, {Name="ResetRate"})
		end
	end
	return false
end

local prevplayerops = "Main"

t[#t + 1] = Def.ActorFrame {
	Name = "LittleButtonsOnTheLeft",

	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "BackButton",
		BeginCommand = function(self)
			self:xy(25, SCREEN_BOTTOM - 28):zoom(0.5):halign(0)
			self:settext("⮪ Back")
			self:diffuse(getMainColor("positive"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SCREENMAN:GetTopScreen():Cancel()
			end
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha2) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
	},

	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "PreviewViewer",
		BeginCommand = function(self)
			mcbootlarder = self:GetParent():GetParent():GetChild("ChartPreview")
			SCREENMAN:GetTopScreen():AddInputCallback(MPinput)
			SCREENMAN:GetTopScreen():AddInputCallback(ihatestickinginputcallbackseverywhere)
			self:xy(60, SCREEN_BOTTOM - 68):zoom(0.5):halign(0.5)
			self:settext("👁 Preview")
			self:diffuse(getMainColor("positive"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and (song or noteField) then
				toggleNoteField()
			elseif params.event == "DeviceButton_right mouse button" and (song or noteField) then
				if mcbootlarder:IsVisible() then
					toggleCalcInfo(not infoOnScreen)
				else
					if toggleNoteField() then
						toggleCalcInfo(true)
					end
				end
			end
		end,
		ChartPreviewOnMessageCommand = function(self)
			local ready = self:GetParent():GetParent():GetChild("Ready")
			local force = self:GetParent():GetParent():GetChild("ForceStart")
			if ready ~= nil then
				ready:visible(false)
			end
			if force ~= nil then
				force:visible(false)
			end
		end,
		ChartPreviewOffMessageCommand = function(self)
			if SCREENMAN:GetTopScreen():GetName():find("Net") ~= nil then
				local ready = self:GetParent():GetParent():GetChild("Ready")
				local force = self:GetParent():GetParent():GetChild("ForceStart")
				if ready ~= nil then
					ready:visible(true)
				end
				if force ~= nil then
					force:visible(true)
				end
			end
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha2)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MintyFreshCommand = function(self)
			if song then
				self:settext(translated_info["TogglePreview"])
			else
				self:settext("")
			end
		end,
	},

	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "PlayerOptionsButton",
		BeginCommand = function(self)
			self:xy(220, SCREEN_BOTTOM - 68):halign(0.5):zoom(0.5)
			self:settext("⚡ Mods")
			self:diffuse(getMainColor("positive"))
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha2)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and song then
				SCREENMAN:GetTopScreen():OpenOptions()
			end
		end,
		OptionsScreenClosedMessageCommand = function(self)
			local nextplayerops = getenv("NewOptions") or "Main"
			if nextplayerops == prevplayerops then
				setenv("NewOptions", "Main")
				prevplayerops = "Main"
				return
			end
			prevplayerops = nextplayerops
			setenv("NewOptions", nextplayerops)
			SCREENMAN:GetTopScreen():OpenOptions()
		end,
	},

	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "Wife3J4Button",
		BeginCommand = function(self)
			self:xy(390, SCREEN_BOTTOM - 68):halign(0.5):zoom(0.5)
			self:settext("⚖ Wife3 J4")
			self:diffuse(getMainColor("positive"))
		end,
		MouseDownCommand = function(self, params)
			-- Toggle judge logic (copy from _PlayerInfo.lua if needed)
			local cur_judge = GetTimingDifficulty()
			if params.event == "DeviceButton_left mouse button" then
				if cur_judge < 9 then SetTimingDifficulty(cur_judge + 1) end
			else
				if cur_judge > 4 then SetTimingDifficulty(cur_judge - 1) end
			end
			MESSAGEMAN:Broadcast("JudgeChanged")
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha2) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
		JudgeChangedMessageCommand = function(self)
			self:settext("⚖ Wife3 J" .. GetTimingDifficulty())
		end
	},



	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "PlayButton",
		BeginCommand = function(self)
			self:xy(SCREEN_WIDTH - 20, SCREEN_BOTTOM - 68):halign(1):zoom(0.7)
			self:settext("▶ Play")
			self:diffuse(getMainColor("positive"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SCREENMAN:GetTopScreen():StartSelectedSong()
			end
		end,
		MouseOverCommand = function(self) self:diffusealpha(hoverAlpha2) end,
		MouseOutCommand = function(self) self:diffusealpha(1) end,
	},


--[[ -- This is the Widget Button alternative of the above implementation.
t[#t + 1] =
	Widg.Button {
	text = "Options",
	width = 50,
	height = 25,
	border = false,
	bgColor = BoostColor(getMainColor("frames"), 7.5),
	highlight = {color = BoostColor(getMainColor("frames"), 10)},
	x = SCREEN_WIDTH / 2,
	y = 5,
	onClick = function(self)
		SCREENMAN:GetTopScreen():OpenOptions()
	end
}]]
}

t[#t + 1] = LoadActorWithParams("../_chartpreview.lua", {yPos = prevY, yPosReverse = prevrevY})
return t
