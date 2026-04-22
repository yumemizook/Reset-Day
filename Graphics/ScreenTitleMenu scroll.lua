local gc = Var("GameCommand")
local choiceKey = gc:GetText()
local buttonWidth = 210

-- holy spaghetti code.
local choiceLayout = {
	Engage = {offset = 40},
	GameStart = {offset = 40},
	Options = {offset = 10},
	ColorChange = {offset = -20},
	Color = {offset = -50},
	Exit = {offset = -80},
}

local choiceMetricNames = {
	Engage = "GameStart",
	GameStart = "GameStart",
	Options = "Options",
	ColorChange = "Color",
	Color = "Color",
	Exit = "Exit",
}
local layout = choiceLayout[choiceKey] or {offset = 18}
local function getChoiceLabel()
	local ok, translated = pcall(function()
		return THEME:GetString("ScreenTitleMenu", choiceKey)
	end)
	if ok and translated and translated ~= "" then
		return translated
	end
	return choiceKey
end

local function applyChoice()
	local choiceName = choiceMetricNames[choiceKey]
	if not choiceName then return end
	local top = SCREENMAN:GetTopScreen()
	if top then
		top:playcommand("MadeChoicePlayer_1")
		top:playcommand("Choose")
	end
	if choiceName == "GameStart" or choiceName == "Engage" then
		GAMESTATE:JoinPlayer()
	end
	GAMESTATE:ApplyGameCommand(THEME:GetMetric("ScreenTitleMenu", "Choice" .. choiceName))
end

return Def.ActorFrame {
	UIElements.QuadButton(1, 1) .. {
		Name = "Hitbox",
		InitCommand = function(self)
			self:x(layout.offset):halign(0):valign(0.5):zoomto(buttonWidth, 54):diffuse(color("#000000")):diffusealpha(0.28)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				applyChoice()
			end
		end,
		MouseOverCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.48)
		end,
		MouseOutCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.28)
		end,
		GainFocusCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.48)
		end,
		LoseFocusCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.28)
		end
	},
	Def.Quad {
		Name = "Plate",
		InitCommand = function(self)
			self:x(layout.offset):halign(0):valign(0.5):zoomto(buttonWidth, 54):diffuse(getMainColor("frames")):diffusealpha(0.32)
		end,
		SetDynamicAccentColorMessageCommand = function(self, params)
			self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.32)
		end,
		GainFocusCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.65)
		end,
		LoseFocusCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.32)
		end
	},
	LoadFont("Common Normal") .. {
		Text = getChoiceLabel(),
		OnCommand = function(self)
			self:xy(layout.offset + 18, 0):align(0, 0.5):zoom(0.72)
		end,
		GainFocusCommand = function(self)
			self:zoom(0.76):diffuse(getMainColor("positive"))
		end,
		LoseFocusCommand = function(self)
			self:zoom(0.70):diffuse(color("#FFFFFF"))
		end
	}
}
