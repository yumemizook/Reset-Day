local hoverAlpha = 0.6
local t = Def.ActorFrame {}

local frameWidth = 280
local frameY = 35
local frameX = SCREEN_WIDTH - 250

local sortTable = {
	SortOrder_Group = THEME:GetString("SortOrder", "Group"),
	SortOrder_Title = THEME:GetString("SortOrder", "Title"),
	SortOrder_BPM = THEME:GetString("SortOrder", "BPM"),
	SortOrder_TopGrades = THEME:GetString("SortOrder", "TopGrades"),
	SortOrder_Artist = THEME:GetString("SortOrder", "Artist"),
	SortOrder_Genre = THEME:GetString("SortOrder", "Genre"),
	SortOrder_ModeMenu = THEME:GetString("SortOrder", "ModeMenu"),
	SortOrder_Length = THEME:GetString("SortOrder", "Length"),
	SortOrder_DateAdded = THEME:GetString("SortOrder", "DateAdded"),
	SortOrder_Favorites = THEME:GetString("SortOrder", "Favorites"),
	SortOrder_Overall = THEME:GetString("SortOrder", "Overall"),
	SortOrder_Stream = THEME:GetString("SortOrder", "Stream"),
	SortOrder_Jumpstream = THEME:GetString("SortOrder", "Jumpstream"),
	SortOrder_Handstream = THEME:GetString("SortOrder", "Handstream"),
	SortOrder_Stamina = THEME:GetString("SortOrder", "Stamina"),
	SortOrder_JackSpeed = THEME:GetString("SortOrder", "JackSpeed"),
	SortOrder_Chordjack = THEME:GetString("SortOrder", "Chordjack"),
	SortOrder_Technical = THEME:GetString("SortOrder", "Technical"),
	SortOrder_Author = THEME:GetString("SortOrder", "Author"),
	SortOrder_Ungrouped = THEME:GetString("SortOrder", "Ungrouped")
}

local groupSortCycle = {
	"SortOrder_Group",
	"SortOrder_Title",
	"SortOrder_Artist",
	"SortOrder_Genre",
	"SortOrder_BPM",
	"SortOrder_Length",
	"SortOrder_DateAdded",
	"SortOrder_Favorites",
	"SortOrder_Author",
	"SortOrder_Ungrouped"
}

local function getCurrentGroupSortLabel()
	local sort = GAMESTATE:GetSortOrder()
	return sortTable[sort] or tostring(sort or "Group")
end

local function cycleGroupSort(top)
	if not top or not top.GetMusicWheel then return end
	local wheel = top:GetMusicWheel()
	if not wheel or not wheel.ChangeSort then return end
	local currentSort = GAMESTATE:GetSortOrder()
	for index, sortType in ipairs(groupSortCycle) do
		if sortType == currentSort then
			wheel:ChangeSort(groupSortCycle[(index % #groupSortCycle) + 1])
			return
		end
	end
	wheel:ChangeSort(groupSortCycle[1])
end

local sortY = 100
local sortX = SCREEN_WIDTH - 200

-- Small subtle background for sort area
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 280, sortY):zoomto(260, 25):halign(0):valign(0.5):diffuse(color("#000000")):diffusealpha(0.3)
	end,
	SetDynamicAccentColorMessageCommand = function(self, params)
		self:finishtweening():linear(0.2):diffuse(params.color):diffusealpha(0.2)
	end
}

local function makeGroupButton(xOffset)
	return UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(SCREEN_WIDTH + xOffset, sortY):halign(0):zoom(0.4):settext("")
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:settext("Group: " .. getCurrentGroupSortLabel())
			self:diffuse(getMainColor("positive"))
		end,
		SortOrderChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				cycleGroupSort(SCREENMAN:GetTopScreen())
			end
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end
	}
end

t[#t + 1] = makeGroupButton(-240)

return t
