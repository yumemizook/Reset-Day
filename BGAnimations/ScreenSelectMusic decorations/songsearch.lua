local searchstring = ""
local active = false
local whee
local lastsearchstring = ""
local instantSearch = themeConfig:get_data().global.InstantSearch

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
		if event.button == "Back" then
			searchstring = ""
			whee:SongSearch(searchstring)
			active = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("EndingSearch")
		elseif event.button == "Start" then
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
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH - 250, 15):zoom(0.45):halign(0)
		end,
		UpdateStringMessageCommand = function(self)
			if active then
				self:settext("Search: " .. searchstring .. "_")
				self:diffuse(color("#00FF00"))
			elseif searchstring ~= "" then
				self:settext("Search: " .. searchstring)
				self:diffuse(color("#FFFFFF"))
			else
				self:settext("Press Tab to search")
				self:diffuse(color("#888888"))
			end
		end,
		BeginCommand = function(self)
			self:playcommand("UpdateString")
		end
	}
}

return t
