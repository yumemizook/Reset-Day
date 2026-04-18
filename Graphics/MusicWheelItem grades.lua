-- Score cache for the currently selected chart
local cachedScore = nil
local cachedRate  = nil
local cachedKey   = nil

local function getBestScore()
	local steps = GAMESTATE:GetCurrentSteps()
	if not steps then
		cachedKey = nil; cachedScore = nil; cachedRate = nil
		return nil, nil
	end

	local ck = steps:GetChartKey()
	if not ck or ck == "" then
		cachedKey = nil; cachedScore = nil; cachedRate = nil
		return nil, nil
	end

	if ck == cachedKey then return cachedScore, cachedRate end

	cachedKey   = ck
	cachedScore = nil
	cachedRate  = nil

	local byRate = SCOREMAN:GetScoresByKey(ck)
	if not byRate then return nil, nil end

	for rate, scoresAtRate in pairs(byRate) do
		local ok, slist = pcall(function() return scoresAtRate:GetScores() end)
		if ok and slist then
			for _, s in ipairs(slist) do
				if not cachedScore or s:GetWifeScore() > cachedScore:GetWifeScore() then
					cachedScore = s
					cachedRate  = rate
				end
			end
		end
	end

	return cachedScore, cachedRate
end

-- Compute ClearType string/color from a HighScore object (no grade fallback)
local ctNames     = {"MFC","WF","SDP","PFC","BF","SDG","FC","MF","SDCB","Clear","Failed","Invalid","No Play","-"}
local ctColorKeys = {"MFC","WF","SDP","PFC","BF","SDG","FC","MF","SDCB","Clear","Failed","Invalid","NoPlay","None"}

local function ctColor(idx)
	local key = ctColorKeys[idx] or "None"
	local ok, c = pcall(function() return color(colorConfig:get_data().clearType[key]) end)
	return ok and c or color("#888888")
end

local function getClearType(score, ret)
	if not score then return nil end

	local w2  = score:GetTapNoteScore("TapNoteScore_W2")  or 0
	local w3  = score:GetTapNoteScore("TapNoteScore_W3")  or 0
	local w4  = score:GetTapNoteScore("TapNoteScore_W4")  or 0
	local w5  = score:GetTapNoteScore("TapNoteScore_W5")  or 0
	local mis = score:GetTapNoteScore("TapNoteScore_Miss") or 0
	local grade = score:GetWifeGrade()

	if grade == "Grade_Failed" or grade == "Grade_None" then
		local lv = 11
		if ret == 0 then return ctNames[lv] elseif ret == 2 then return ctColor(lv) end
		return lv
	end

	local cb = mis + w5 + w4
	local lv
	if     cb > 0  then lv = cb == 1 and 8 or (cb < 10 and 9 or 10)
	elseif w3 > 0  then lv = w3 == 1 and 5 or (w3 < 10 and 6 or 7)
	elseif w2 > 0  then lv = w2 == 1 and 2 or (w2 < 10 and 3 or 4)
	else               lv = 1
	end

	if ret == 0 then return ctNames[lv] elseif ret == 2 then return ctColor(lv) end
	return lv
end

-- Returns true only for the wheel item that IS the currently selected song.
-- params.Grade is the engine's best grade for that chart slot.
-- For the selected chart, getBestScore() returns a score whose GetWifeGrade()
-- matches what the engine put in params.Grade.
local function isSelectedItem(paramsGrade)
	if not paramsGrade or paramsGrade == "Grade_None" or paramsGrade == "Grade_Tier17" then
		return false
	end
	local score = getBestScore()
	if score then
		local ok, g = pcall(function() return score:GetWifeGrade() end)
		return ok and g == paramsGrade
	end
	-- Selected chart has no score: we can't positively identify it,
	-- so suppress ClearType for all items (correct — nothing to show anyway)
	return false
end

-- ─── Layout ──────────────────────────────────────────────────────────────────
local boxW   = 50
local boxH   = 32
local boxGap = 4
local gradeX = -boxW - boxGap/2
local clearX =  boxGap/2

return Def.ActorFrame {

	-- ═══ GRADE BOX ══════════════════════════════════════════════════════════

	Def.Quad {
		Name = "GradeBG",
		InitCommand = function(self)
			self:xy(gradeX, -2):zoomto(boxW, boxH):halign(0):valign(0.5)
			self:diffuse(color("#000000")):diffusealpha(0.6)
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			self:visible(g ~= "Grade_None" and g ~= "Grade_Tier17")
		end
	},

	LoadFont("Common Normal") .. {
		Name = "GradeText",
		InitCommand = function(self)
			self:xy(gradeX + boxW/2, -8):zoom(0.5):halign(0.5):valign(0.5)
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g == "Grade_None" or g == "Grade_Tier17" then
				self:settext("")
			else
				self:settext(THEME:GetString("Grade", ToEnumShortString(g)) or "")
				self:diffuse(getGradeColor(g))
			end
		end
	},

	LoadFont("Common Normal") .. {
		Name = "GradeRate",
		InitCommand = function(self)
			self:xy(gradeX + boxW/2, 6):zoom(0.28):halign(0.5):valign(0.5)
			self:diffuse(color("#00ff00"))
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g == "Grade_None" or g == "Grade_Tier17" then
				self:settext(""); return
			end
			if isSelectedItem(g) then
				local _, rate = getBestScore()
				self:settext(rate and ("(" .. rate .. ")") or "")
			else
				self:settext("")
			end
		end
	},

	-- ═══ CLEARTYPE BOX ══════════════════════════════════════════════════════

	Def.Quad {
		Name = "ClearTypeBG",
		InitCommand = function(self)
			self:xy(clearX, -2):zoomto(boxW, boxH):halign(0):valign(0.5)
			self:diffuse(color("#000000")):diffusealpha(0.6)
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g == "Grade_None" or g == "Grade_Tier17" or not isSelectedItem(g) then
				self:visible(false); return
			end
			local score = getBestScore()
			self:visible(score ~= nil)
		end
	},

	LoadFont("Common Normal") .. {
		Name = "ClearTypeText",
		InitCommand = function(self)
			self:xy(clearX + boxW/2, -8):zoom(0.4):halign(0.5):valign(0.5)
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g == "Grade_None" or g == "Grade_Tier17" or not isSelectedItem(g) then
				self:settext(""); return
			end
			local score = getBestScore()
			if score then
				self:settext(getClearType(score, 0))
				self:diffuse(getClearType(score, 2))
			else
				self:settext("")
			end
		end
	},

	LoadFont("Common Normal") .. {
		Name = "ClearTypeRate",
		InitCommand = function(self)
			self:xy(clearX + boxW/2, 6):zoom(0.28):halign(0.5):valign(0.5)
			self:diffuse(color("#00ff00"))
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g == "Grade_None" or g == "Grade_Tier17" or not isSelectedItem(g) then
				self:settext(""); return
			end
			local score, rate = getBestScore()
			self:settext((score and rate) and ("(" .. rate .. ")") or "")
		end
	},

	-- ═══ INDICATORS ═════════════════════════════════════════════════════════

	-- Difficulty colour bar (left edge of grade box)
	Def.Quad {
		InitCommand = function(self)
			self:xy(-boxW - boxGap/2 - 4, -2):zoomto(3, boxH):halign(0.5):valign(0.5)
		end,
		SetGradeCommand = function(self, params)
			local g = params.Grade or "Grade_None"
			if g ~= "Grade_None" and g ~= "Grade_Tier17" then
				self:diffuse(getDifficultyColor("Difficulty_" .. (params.Difficulty or "Medium")))
				self:diffusealpha(0.7)
			else
				self:diffusealpha(0)
			end
		end
	},

	-- PermaMirror icon
	Def.Sprite {
		InitCommand = function(self) self:xy(gradeX - 16, -12):zoomto(4, 19) end,
		SetGradeCommand = function(self, params)
			if params.PermaMirror then
				self:Load(THEME:GetPathG("", "mirror")):zoomto(14, 14):visible(true)
			else
				self:visible(false)
			end
		end
	},

	-- Favourite icon
	Def.Sprite {
		InitCommand = function(self) self:xy(gradeX - 16, 4):zoomto(4, 19) end,
		SetGradeCommand = function(self, params)
			if params.Favorited then
				self:Load(THEME:GetPathG("", "favorite")):zoomto(14, 14):visible(true)
			else
				self:visible(false)
			end
		end
	},
}
