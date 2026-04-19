local AvatarX = SCREEN_WIDTH - 180
local AvatarY = 17
-- Old avatar actor frame.. renamed since much more will be placed here (hopefully?)
local t =
	Def.ActorFrame {
	Name = "PlayerAvatar",
}

local username = ""
local profile

local profileName = THEME:GetString("GeneralInfo", "NoProfile")
local playCount = 0
local playTime = 0
local noteCount = 0
local numfaves = 0
local playerRating = 0
local uploadbarwidth = 100
local uploadbarheight = 10

local ButtonColor = getMainColor("positive")
local nonButtonColor = ColorMultiplier(getMainColor("positive"), 1.25)
--------UNCOMMENT THIS NEXT LINE IF YOU WANT THE OLD LOOK--------
--nonButtonColor = getMainColor("positive")

local setnewdisplayname = function(answer)
	if answer ~= "" then
		profile:RenameProfile(answer)
		profileName = answer
		MESSAGEMAN:Broadcast("ProfileRenamed", {doot = answer})
	end
end

local function highlightIfOver(self)
	if isOver(self) then
		local topname = SCREENMAN:GetTopScreen():GetName()
		if topname ~= "ScreenEvaluationNormal" and topname ~= "ScreenNetEvaluation" then
			self:diffusealpha(0.6)
		end
	else
		self:diffusealpha(1)
	end
end

local translated_info = {
	ProfileNew = THEME:GetString("ProfileChanges", "ProfileNew"),
	NameChange = THEME:GetString("ProfileChanges", "ProfileNameChange"),
	ClickLogin = THEME:GetString("GeneralInfo", "ClickToLogin"),
	ClickLogout = THEME:GetString("GeneralInfo", "ClickToLogout"),
	NotLoggedIn = THEME:GetString("GeneralInfo", "NotLoggedIn"),
	LoggedInAs = THEME:GetString("GeneralInfo", "LoggedInAs.."),
	LoginFailed = THEME:GetString("GeneralInfo", "LoginFailed"),
	LoginSuccess = THEME:GetString("GeneralInfo", "LoginSuccess"),
	LoginCanceled = THEME:GetString("GeneralInfo", "LoginCanceled"),
	Password = THEME:GetString("GeneralInfo","Password"),
	Username = THEME:GetString("GeneralInfo","Email"),
	Plays = THEME:GetString("GeneralInfo", "ProfilePlays"),
	PlaysThisSession = THEME:GetString("GeneralInfo", "PlaysThisSession"),
	TapsHit = THEME:GetString("GeneralInfo", "ProfileTapsHit"),
	Playtime = THEME:GetString("GeneralInfo", "ProfilePlaytime"),
	Judge = THEME:GetString("GeneralInfo", "ProfileJudge"),
	RefreshSongs = THEME:GetString("GeneralInfo", "DifferentialReloadTrigger"),
	SongsLoaded = THEME:GetString("GeneralInfo", "ProfileSongsLoaded"),
	SessionTime = THEME:GetString("GeneralInfo", "SessionTime"),
	GroupsLoaded = THEME:GetString("GeneralInfo", "GroupsLoaded"),
}

local function UpdateTime(self)
	-- Function disabled as time display is commented out
	--[[
	local year = Year()
	local month = MonthOfYear() + 1
	local day = DayOfMonth()
	local hour = Hour()
	local minute = Minute()
	local second = Second()
	self:GetChild("CurrentTime"):settextf("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)

	local sessiontime = GAMESTATE:GetSessionTime()
	self:GetChild("SessionTime"):settextf("%s: %s", translated_info["SessionTime"], SecondsToHHMMSS(sessiontime))
	self:diffuse(nonButtonColor)
	]]
end

-- handle logging in exactly like Til Death
local function loginStep1(self)
	local redir = SCREENMAN:get_input_redirected(PLAYER_1)
	local function off()
		if redir then
			SCREENMAN:set_input_redirected(PLAYER_1, false)
		end
	end
	local function on()
		if redir then
			SCREENMAN:set_input_redirected(PLAYER_1, true)
		end
	end
	off()

	username = ""

	easyInputStringOKCancel(
		translated_info["Username"]..":", 255, true,
		function(answer)
			username = answer
			if answer:gsub("^%s*(.-)%s*$", "%1") ~= "" then
				self:sleep(0.04):queuecommand("LoginStep2")
			else
				ms.ok(translated_info["LoginCanceled"])
				on()
			end
		end,
		function()
			ms.ok(translated_info["LoginCanceled"])
			on()
		end
	)
end

local function loginStep2()
	local password = ""
	easyInputStringOKCancel(
		translated_info["Password"]..":", 255, true,
		function(answer)
			password = answer
			if answer:gsub("^%s*(.-)%s*$", "%1") ~= "" then
				DLMAN:Login(username, password)
			else
				ms.ok(translated_info["LoginCanceled"])
			end
		end,
		function()
			ms.ok(translated_info["LoginCanceled"])
		end
	)
end



t[#t + 1] = Def.Actor {
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		profile = GetPlayerOrMachineProfile(PLAYER_1)
		profileName = profile:GetDisplayName()
		playCount = SCOREMAN:GetTotalNumberOfScores()
		playTime = profile:GetTotalSessionSeconds()
		noteCount = profile:GetTotalTapsAndHolds()
		playerRating = profile:GetPlayerRating()
	end,
	PlayerRatingUpdatedMessageCommand = function(self)
		playerRating = profile:GetPlayerRating()
		self:GetParent():GetDescendant("AvatarPlayerNumber_P1", "Name"):playcommand("Set")
	end
}

t[#t + 1] = Def.ActorFrame {
	Name = "Avatar" .. PLAYER_1,
	BeginCommand = function(self)
		self:queuecommand("Set")
	end,
	SetCommand = function(self)
		if profile == nil then
			self:visible(false)
		else
			self:visible(true)
		end
	end,
	UIElements.SpriteButton(1, 1, nil) .. {
		Name = "Image",
		InitCommand = function(self)
			self:visible(false):halign(0):valign(0.5):xy(AvatarX, AvatarY)
		end,
		BeginCommand = function(self)
			self:queuecommand("ModifyAvatar")
		end,
		ModifyAvatarCommand = function(self)
			self:finishtweening()
			self:Load(getAvatarPath(PLAYER_1))
			self:zoomto(50, 50)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and not SCREENMAN:get_input_redirected(PLAYER_1) then
				local top = SCREENMAN:GetTopScreen()
				SCREENMAN:SetNewScreen("ScreenAssetSettings")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		Name = "Name",
		InitCommand = function(self)
			self:halign(1) -- Right align to point at the button
			self:xy(AvatarX + 15, AvatarY)
			self:zoom(0.45)
			self:maxwidth(capWideScale(200,300))
			self:diffuse(ButtonColor)
		end,
		SetCommand = function(self)
			self:settextf("%s (%5.2f)", profileName, playerRating)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and not SCREENMAN:get_input_redirected(PLAYER_1) then
				easyInputStringWithFunction(translated_info["NameChange"], 64, false, setnewdisplayname)
			end
		end,
		ProfileRenamedMessageCommand = function(self, params)
			self:settextf("%s (%5.2f)", params.doot, playerRating)
		end,
		MouseOverCommand = function(self)
			highlightIfOver(self)
		end,
		MouseOutCommand = function(self)
			highlightIfOver(self)
		end,
	},
	Def.ActorFrame {
		Name = "LoginButtonFrame",
		InitCommand = function(self)
			self:xy(AvatarX + 22, AvatarY)
		end,
		UpdateLoginStatusCommand = function(self)
			-- Background now always uses the dynamic accent color as requested
			-- The diffuse is handled by the BGSprite actor directly via messages
			-- but we ensure the alpha is consistent here.
			self:GetChild("BGSprite"):diffusealpha(0.8)
		end,
		BeginCommand = function(self) self:queuecommand("UpdateLoginStatus") end,
		DLMANLoginMessageCommand = function(self) self:queuecommand("UpdateLoginStatus") end,
		DLMANLogoutMessageCommand = function(self) self:queuecommand("UpdateLoginStatus") end,

		Def.Quad {
			Name = "BGSprite",
			InitCommand = function(self)
				self:zoomto(125, 26):halign(0):valign(0.5):xy(0, 0):diffuse(getMainColor("highlight")):diffusealpha(0.8)
			end,
			SetDynamicAccentColorMessageCommand = function(self, params)
				self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.8)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "GlobeIcon",
			InitCommand = function(self)
				self:xy(6, 0):halign(0):zoom(0.4):settext("🌐"):diffuse(color("#22CC66"))
			end,
		},
		UIElements.TextToolTip(1, 1, "Common Normal") .. {
			Name = "loginlogout",
			InitCommand = function(self)
				self:xy(71, 0):halign(0.5):zoom(0.40):diffuse(color("#22CC66")) -- Green at all times
			end,
			BeginCommand = function(self)
				self:queuecommand("Set")
			end,
			SetCommand = function(self)
				if DLMAN:IsLoggedIn() then
					self:queuecommand("Login")
				else
					self:queuecommand("LogOut")
				end
			end,
			LogOutMessageCommand = function(self)
				local top = SCREENMAN:GetTopScreen():GetName()
				if DLMAN:IsLoggedIn() then
					playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).UserName = ""
					playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).PasswordToken = ""
					playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
					playerConfig:save(pn_to_profile_slot(PLAYER_1))
					DLMAN:Logout()
				end
				self:settext(translated_info["NotLoggedIn"])
			end,
		LoginMessageCommand = function(self)
			if not SCREENMAN:GetTopScreen() then return end
			local top = SCREENMAN:GetTopScreen():GetName()
			if not DLMAN:IsLoggedIn() then return end
			playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).UserName = DLMAN:GetUsername()
			playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).PasswordToken = DLMAN:GetToken()
			playerConfig:set_dirty(pn_to_profile_slot(PLAYER_1))
			playerConfig:save(pn_to_profile_slot(PLAYER_1))
			
			self:settextf(
				"%s (%5.2f)",
				DLMAN:GetUsername(),
				DLMAN:GetSkillsetRating("Overall")
			)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and not SCREENMAN:get_input_redirected(PLAYER_1) then
				if DLMAN:IsLoggedIn() then
					DLMAN:ShowUserPage(DLMAN:GetUsername())
				else
					loginStep1(self)
				end
			elseif params.event == "DeviceButton_right mouse button" and not SCREENMAN:get_input_redirected(PLAYER_1) then
				if DLMAN:IsLoggedIn() then
					self:queuecommand("LogOut")
				end
			end
		end,
		OnlineUpdateMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			highlightIfOver(self)
		end,
		MouseOutCommand = function(self)
			highlightIfOver(self)
		end,
		LoginFailedMessageCommand = function(self, params)
			ms.ok(translated_info["LoginFailed"] .. " -- " .. params.why)
		end,
		LoginHotkeyPressedMessageCommand = function(self)
			if DLMAN:IsLoggedIn() then
				self:queuecommand("LogOut")
			else
				loginStep1(self)
			end
		end,
		LoginStep2Command = function(self)
			loginStep2()
		end
	},
}
}



--[[
t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:SetUpdateFunction(UpdateTime)
	end,
	-- Session/Footer time commented out as requested
	-- LoadFont("Common Normal") .. {
	-- 	Name = "CurrentTime",
	-- 	InitCommand = function(self)
	-- 		self:xy(SCREEN_WIDTH - 3, SCREEN_BOTTOM - 3.5):halign(1):valign(1):zoom(0.45)
	-- 	end
	-- },

	-- LoadFont("Common Normal") .. {
	-- 	Name = "SessionTime",
	-- 	InitCommand = function(self)
	-- 		self:xy(SCREEN_CENTER_X, SCREEN_BOTTOM - 5):halign(0.5):valign(1):zoom(0.45)
	-- 	end
	-- }
}
]]--

local function UpdateAvatar(self)
	if getAvatarUpdateStatus() then
		self:GetChild("Avatar" .. PLAYER_1):GetChild("Image"):queuecommand("ModifyAvatar")
		setAvatarUpdateStatus(PLAYER_1, false)
	end
end


t.InitCommand = function(self)
	self:SetUpdateFunction(UpdateAvatar)
end

return t
