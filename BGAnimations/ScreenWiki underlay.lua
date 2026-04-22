local t = Def.ActorFrame {
	OnCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type == "InputEventType_FirstPress" and event.button == "Back" then
				SCREENMAN:GetTopScreen():Cancel()
				return true
			end
		end)
	end
}

t[#t + 1] = LoadActor("_frame")

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(20, 54):halign(0):valign(0):zoomto(SCREEN_WIDTH - 40, SCREEN_HEIGHT - 108):diffuse(color("#000000")):diffusealpha(0.5)
	end
}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(20, 54):halign(0):valign(0):zoomto(SCREEN_WIDTH - 40, SCREEN_HEIGHT - 108):diffuse(getMainColor("frames")):diffusealpha(0.2)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.2)
	end
}

t[#t + 1] = LoadFont("Common Large") .. {
	InitCommand = function(self)
		self:xy(28, 38):halign(0):valign(1):zoom(0.55):diffuse(getMainColor("highlight")):settext("Wiki")
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color)
	end
}

t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(48, 92):halign(0):valign(0):zoom(0.65):maxwidth((SCREEN_WIDTH - 120) / 0.65)
		self:settext("Placeholder wiki screen.\n\nUse this screen for documentation, quick links, guides, or external resources later.\n\nFor now, this is only a temporary destination for the title-screen Wiki button and online profile display.")
	end
}

t[#t + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(48, SCREEN_HEIGHT - 62)
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(120, 34):diffuse(color("#000000")):diffusealpha(0.45)
		end,
		MouseOverCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.65)
		end,
		MouseOutCommand = function(self)
			self:stoptweening():linear(0.1):diffusealpha(0.45)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SCREENMAN:GetTopScreen():Cancel()
			end
		end
	},
	Def.Quad {
		InitCommand = function(self)
			self:halign(0):valign(0.5):zoomto(120, 34):diffuse(getMainColor("frames")):diffusealpha(0.32)
		end,
		SetDynamicAccentColorMessageCommand = function(self, params)
			self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.32)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(60, 0):zoom(0.5):settext("Back")
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				SCREENMAN:GetTopScreen():Cancel()
			end
		end
	}
}

return t
