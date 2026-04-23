local searchstring = ""
local active = false
local whee
local lastsearchstring = ""
local instantSearch = themeConfig:get_data().global.InstantSearch

local interludeIconTargetSize = 48

local function normalizeInterludeIcon(self)
	local width = self:GetWidth()
	local height = self:GetHeight()
	if width > 0 and height > 0 then
		self:zoom(interludeIconTargetSize / math.max(width, height))
	end
end

local function getSearchDisplayState()
	if active then
		return searchstring .. "_", color("#00FF00")
	elseif searchstring ~= "" then
		return searchstring, color("#FFFFFF")
	end
	return "Press Tab to search", color("#888888")
end

local function searchInput(event)
	if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_tab" then
		active = not active
		if active then
			MESSAGEMAN:Broadcast("BeginningSearch")
			whee:Move(0)
			SCREENMAN:set_input_redirected(PLAYER_1, true)
			MESSAGEMAN:Broadcast("RefreshSearchResults")
		else
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("EndingSearch")
		end
		MESSAGEMAN:Broadcast("UpdateString")
		return true
	end

	if event.type ~= "InputEventType_Release" and active == true then
		local deviceButton = event.DeviceInput and event.DeviceInput.button or ""
		if event.button == "Back" then
			searchstring = ""
			whee:SongSearch(searchstring)
			active = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("EndingSearch")
		elseif event.button == "Start" or deviceButton == "DeviceButton_enter" then
			if not instantSearch then
				whee:SongSearch(searchstring)
			end
			active = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("EndingSearch")
		elseif event.DeviceInput.button == "DeviceButton_space" then
			searchstring = searchstring .. " "
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			searchstring = searchstring:sub(1, -2)
		elseif event.DeviceInput.button == "DeviceButton_delete" then
			searchstring = ""
		else
			local CtrlPressed = INPUTFILTER:IsControlPressed()
			if event.DeviceInput.button == "DeviceButton_v" and CtrlPressed then
				searchstring = searchstring .. Arch.getClipboard()
			elseif event.char and event.char:match('[%%%+%-%!%@%#%$%^%&%*%(%)%=%_%.%,%:%;%\'%"%>%<%?%/%~%|%w%[%]%{%}%`%\\]') and (not tonumber(event.char) or CtrlPressed) then
				searchstring = searchstring .. event.char
			end
		end
		if lastsearchstring ~= searchstring then
			MESSAGEMAN:Broadcast("UpdateString")
			if instantSearch then
				whee:SongSearch(searchstring)
			end
			lastsearchstring = searchstring
		end
		return true
	end
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
		SCREENMAN:GetTopScreen():AddInputCallback(searchInput)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 420, 70):zoomto(410, 35):halign(0):diffuse(color("#000000")):diffusealpha(0.5)
		end,
		SetDynamicAccentColorMessageCommand = function(self, params)
			self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.3)
		end
	},
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 392, 70):zoom(0.45)
		end,
		Def.Sprite {
			Texture = THEME:GetPathG("", "Interlude Icons/magnifying-glass-solid.png"),
			InitCommand = function(self)
				self:halign(0.5):valign(0.5)
			end,
			OnCommand = function(self)
				normalizeInterludeIcon(self)
				self:playcommand("UpdateState")
			end,
			UpdateStringMessageCommand = function(self)
				self:playcommand("UpdateState")
			end,
			UpdateStateCommand = function(self)
				local _, iconColor = getSearchDisplayState()
				self:diffuse(iconColor)
			end
		}
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 375, 70):zoom(0.4):halign(0)
		end,
		UpdateStringMessageCommand = function(self)
			local displayText, textColor = getSearchDisplayState()
			self:settext(displayText)
			self:diffuse(textColor)
		end,
		BeginCommand = function(self)
			self:playcommand("UpdateString")
		end
	}
}

return t
