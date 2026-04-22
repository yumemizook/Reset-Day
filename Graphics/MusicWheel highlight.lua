return Def.ActorFrame {
	Def.Quad {
		Name = "Horizontal",
		InitCommand = function(self)
			self:xy(0, -2):zoomto(854, 34):halign(0):blend("BlendMode_Normal")
		end,
		SetCommand = function(self)
			self:diffuseramp():effectclock("beat")
			self:effectcolor1(color("#FFFFFF33"))
			self:effectcolor2(color("#FFFFFF33"))
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetDynamicAccentColorMessageCommand = function(self, params)
			self:effectcolor1(color("#FFFFFF22"))
			self:effectcolor2(params.color):blend("BlendMode_Add"):diffusealpha(0.2) -- you can tell i was hitting my head against a wall trying to make this effect more subtle
			self:GetParent():GetChild("AccentGlow"):finishtweening():linear(0.1):diffuse(params.color):diffusealpha(0.3)
		end,
		OffCommand = function(self)
			self:visible(false)
		end
	},
	-- Subtle glow behind the highlight that uses the accent color
	Def.Quad {
		Name = "AccentGlow",
		InitCommand = function(self)
			self:xy(0, -2):zoomto(854, 38):halign(0):diffusealpha(0):blend("BlendMode_Normal")
		end
	}
}
