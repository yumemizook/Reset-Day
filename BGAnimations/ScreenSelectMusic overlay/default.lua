local showVisualizer = themeConfig:get_data().global.ShowVisualizer

local function input(event)
	-- mouse click events left here to let anything in selectmusic react to them
	if event.DeviceInput.button == "DeviceButton_left mouse button" then 
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseLeftClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	elseif event.DeviceInput.button == "DeviceButton_right mouse button" then
		if event.type == "InputEventType_Release" then
			MESSAGEMAN:Broadcast("MouseRightClick")
			MESSAGEMAN:Broadcast("MouseUp", {event = event})
		elseif event.type == "InputEventType_FirstPress" then
			MESSAGEMAN:Broadcast("MouseDown", {event = event})
		end
	end
	return false
end

local hoverAlpha = 0.6

local t = Def.ActorFrame {
	BeginCommand = function(self)
		local s = SCREENMAN:GetTopScreen()
		s:AddInputCallback(input)
		setenv("NewOptions","Main")
	end
}

t[#t + 1] = Def.Actor {
	CodeMessageCommand = function(self, params)
		if params.Name == "AvatarShow" and getTabIndex() == 0 and not SCREENMAN:get_input_redirected(PLAYER_1) then
			SCREENMAN:SetNewScreen("ScreenAssetSettings")
		end
	end,
	OnCommand = function(self)
		inScreenSelectMusic = true
	end,
	EndCommand = function(self)
		inScreenSelectMusic = nil
	end,
}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 480, 0):zoomto(475, 115):halign(0):valign(0):diffuse(color("#000000")):diffusealpha(1.0)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.15)
	end
}

t[#t + 1] = LoadActor("../_frame")
t[#t + 1] = LoadActor("../_PlayerInfo")

if showVisualizer then
	local vis = audioVisualizer:new {
		x = SCREEN_WIDTH - 200,
		y = 32,
		maxHeight = 30,
		freqIntervals = audioVisualizer.multiplyIntervals(audioVisualizer.defaultIntervals, 5),
		color = getMainColor("positive"),
		onBarUpdate = function(self)
			--[
			self:diffusetopedge(getMainColor("frames"))
			self:diffusebottomedge(getMainColor("positive"))
			--]]
			--[[
			self:diffuselowerleft()
			self:diffuseupperleft()
			self:diffuselowerright()
			self:diffuseupperright()
			--]]
		end
	}
	t[#t + 1] = vis
end


t[#t + 1] = LoadActor("currentsort")
-- Title label removed as requested

t[#t + 1] = LoadActor("../_cursor")
t[#t + 1] = LoadActor("../_halppls")

updateDiscordStatusForMenus()
updateNowPlaying()

return t
