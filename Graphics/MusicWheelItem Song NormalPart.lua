local lastclick = GetTimeSinceStart()
local requiredtimegap = 0.1

return Def.ActorFrame {
    -- Background bar for every item
    Def.Quad {
        Name = "ItemBG",
        InitCommand = function(self)
            self:halign(0)
            self:xy(0, -2)
            self:zoomto(854, 38)
            self:diffuse(color("#000000"))
            self:diffusealpha(0.6)
        end,
        SetDynamicAccentColorMessageCommand = function(self, params)
            self:finishtweening():linear(0.15):diffuse(params.color):diffusealpha(0.25)
        end
    },
    -- Separator line at the top of each item
    Def.Quad {
        Name = "SepLine",
        InitCommand = function(self)
            self:halign(0)
            self:xy(0, -21)
            self:zoomto(854, 1)
            self:diffuse(color("#333333"))
            self:diffusealpha(0.4)
        end
    },
    -- Clickable area (transparent, handles mouse input)
    UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:halign(0)
			self:xy(0,0)
			self:diffusealpha(0)
			self:zoomto(854, 38)
		end,
        SetCommand = function(self, params)
            self.index = params.DrawIndex
        end,
		MouseDownCommand = function(self, params)
            if params.event == "DeviceButton_left mouse button" then
                local now = GetTimeSinceStart()
                if now - lastclick < requiredtimegap then return end
                lastclick = now

                local numwheelitems = 15
                local middle = math.ceil(15 / 2)
                local top = SCREENMAN:GetTopScreen()
                local we = top:GetMusicWheel()
                if we then
                    local dist = self.index - middle
                    if dist == 0 and we:IsSettled() then
                        -- clicked current item
                        top:SelectCurrent()
                    else
                        local itemtype = we:MoveAndCheckType(self.index - middle)
                        we:Move(0)
                        if itemtype == "WheelItemDataType_Section" then
                            -- clicked a group
                            top:SelectCurrent()
                        end
                    end
                end
            elseif params.event == "DeviceButton_right mouse button" then
                -- right click doees something but not sure what yet
            end
		end,
	},
}
