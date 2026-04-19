--[[
	Note: This is still a WIP
	Feel free to contribute to it
--]]
local split = function(t, x)
    local t1, t2 = {}, {}
    local idx = nil
    -- Used to simulate a for break
    local aux = function()
        for i, v in ipairs(t) do
            if v == x then
                idx = t[i + 1] and i + 1 or nil
                return
            end
            t1[i] = v
        end
    end
    aux()
    while idx ~= nil do
        t2[#t2 + 1] = t[idx]
        idx = t[idx + 1] and idx + 1 or nil
    end
    return t1, t2
end

local findKeyOf = function(t, x)
    for k, v in pairs(t) do
        if v == x then
            return k
        end
    end
end

local find = function(t, x)
    local k = findKeyOf(t, x)
    return k and t[k] or nil
end

local concat = function(...)
    local arg = {...}
    local t = {}
    for i = 1, #arg do
        for i, v in ipairs(arg[i]) do
            t[#t + 1] = v
        end
    end
    return t
end
local Wheel = {}
local function fillNilTableFieldsFrom(table1, defaultTable)
    for key, value in pairs(defaultTable) do
        if table1[key] == nil then
            table1[key] = defaultTable[key]
        end
    end
end

local function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local function print(x)
    SCREENMAN:SystemMessage(dump(x))
end

local function getIndexCircularly(table, idx)
    if idx <= 0 then
        return getIndexCircularly(table, idx + #table)
    elseif idx > #table then
        return getIndexCircularly(table, idx - #table)
    end
    return idx
end
Wheel.mt = {
    move = function(whee, num)
        if whee.moveInterval then
            whee.actor:clearInterval(whee.moveInterval)
        end
        if num == 0 then
            whee.moveInterval = nil
            return
        end
        whee.floatingOffset = num
        local interval = whee.pollingSeconds / 5
        whee.index = getIndexCircularly(whee.items, whee.index + num)
        whee.moveInterval =
            whee.actor:setInterval(
            function()
                whee.floatingOffset = whee.floatingOffset - num / (whee.pollingSeconds / interval)
                if num < 0 and whee.floatingOffset >= 0 or num > 0 and whee.floatingOffset <= 0 then
                    whee.actor:clearInterval(whee.moveInterval)
                    whee.moveInterval = nil
                    whee.floatingOffset = 0
                end
                whee:update()
            end,
            interval
        )
    end,
    getItem = function(whee, idx)
        return whee.items[getIndexCircularly(whee.items, idx)]
        -- For some reason i have to +1 here
    end,
    getCurrentItem = function(whee)
        return whee:getItem(whee.index)
    end,
    getFrame = function(whee, idx)
        return whee.frames[getIndexCircularly(whee.frames, idx)]
        -- For some reason i have to +1 here
    end,
    getCurrentFrame = function(whee)
        return whee:getFrame(whee.index)
    end,
    update = function(whee)
        local numFrames = whee.count
        local idx = whee.index
        idx = idx - math.ceil(numFrames / 2)
        for i = 1, numFrames do
            local frame = whee.frames[i]
            local offset = i - math.ceil(numFrames / 2) + whee.floatingOffset
            if frame then
                whee.frameTransformer(frame, offset - 1, i, numFrames)
                -- Custom masking for Reset-Day theme
                if (whee.y or 0) + frame:GetY() < 115 then
                    frame:visible(false)
                else
                    frame:visible(true)
                end
                whee.frameUpdater(frame, whee:getItem(idx), offset)
            end
            idx = idx + 1
        end
    end,
    rebuildFrames = function(whee, newIndex)
        whee.items = whee.itemsGetter()
        if whee.sort then
            table.sort(whee.items, whee.sort)
        end
        if not whee.index then
            whee.index = newIndex or whee.startIndex
        end
        whee:update()
    end
}

Wheel.defaultParams = {
    itemsGetter = function()
        -- Should return an array table of elements for the wheel
        -- This is a function so it can be delayed, and rebuilt
        --  with different items using this function
        return SONGMAN:GetAllSongs()
    end,
    count = 20,
    frameBuilder = function()
        return LoadFont("Common Normal") .. {}
    end,
    frameUpdater = function(frame, item) -- Update an frame created with frameBuilder with an item
        frame:settext(item:GetMainTitle())
    end,
    x = 0,
    y = 0,
    highlightBuilder = function()
        return Def.ActorFrame {}
    end,
    buildOnInit = true, -- Build wheel in InitCommand (Will be empty until rebuilt otherwise)
    frameTransformer = function(frame, offsetFromCenter, index, total) -- Handle frame positioning
        frame:y(offsetFromCenter * 30)
    end,
    startIndex = 1,
    speed = 15,
    onSelection = nil, -- function(item)
    sort = nil -- function(a,b) return boolean end
}
function Wheel:new(params)
    params = params or {}
    fillNilTableFieldsFrom(params, Wheel.defaultParams)
    local whee = Def.ActorFrame {}
    setmetatable(whee, {__index = Wheel.mt})
    whee.itemsGetter = params.itemsGetter
    whee.count = params.count
    whee.sort = params.sort
    whee.startIndex = params.startIndex
    whee.frameUpdater = params.frameUpdater
    whee.floatingOffset = 0
    whee.buildOnInit = params.buildOnInit
    whee.frameTransformer = params.frameTransformer
    whee.index = whee.startIndex
    whee.onSelection = params.onSelection
    whee.pollingSeconds = 1 / params.speed
    whee.x = params.x
    whee.y = params.y
    whee.moveHeight = 10
    whee.items = {}
    whee.BeginCommand = function(self)
        local interval = nil
        SCREENMAN:GetTopScreen():AddInputCallback(
            function(event)
                local gameButton = event.button
                local key = event.DeviceInput.button
                local left = gameButton == "MenuLeft" or key == "DeviceButton_left"
                local enter = gameButton == "Start" or key == "DeviceButton_enter"
                local right = gameButton == "MenuRight" or key == "DeviceButton_right"
                if left or right then
                    if event.type == "InputEventType_FirstPress" then
                        if interval then
                            self:clearInterval(interval)
                        end
                        whee:move(right and 1 or -1)
                        interval =
                            self:setInterval(
                            function()
                                whee:move(right and 1 or -1)
                            end,
                            whee.pollingSeconds
                        )
                    elseif event.type == "InputEventType_Release" then
                        if interval then
                            self:clearInterval(interval)
                            interval = nil
                        end
                    end
                elseif enter then
                    if event.type == "InputEventType_FirstPress" then
                        whee.onSelection(whee:getCurrentFrame(), whee:getCurrentItem())
                    end
                end
                return false
            end
        )
    end
    whee.InitCommand = function(self)
        whee.actor = self
        local interval = false
        self:x(whee.x):y(whee.y)
        self:setTimeout(
            function()
                if params.buildOnInit then
                    whee:rebuildFrames()
                end
            end,
            0.1
        )
    end
    whee.frames = {}
    for i = 1, (params.count) do
        local frame =
            params.frameBuilder() ..
            {
                InitCommand = function(self)
                    whee.frames[i] = self
                end
            }
        whee[#whee + 1] = frame
    end
    whee[#whee + 1] =
        params.highlightBuilder() ..
        {
            InitCommand = function(self)
                whee.highlight = self
            end
        }
    return whee
end
MusicWheel = {}
MusicWheel.defaultParams = {
    songActorBuilder = function()
        local s
        s =
            Def.ActorFrame {
            InitCommand = function(self)
                s.actor = self
            end,
            LoadFont("Common Normal") ..
                {
                    BeginCommand = function(self)
                        s.actor.fontActor = self
                    end
                }
        }
        return s
    end,
    groupActorBuilder = function()
        local g
        g =
            Def.ActorFrame {
            InitCommand = function(self)
                g.actor = self
            end,
            LoadFont("Common Normal") ..
                {
                    BeginCommand = function(self)
                        g.actor.fontActor = self
                    end
                }
        }
        return g
    end,
    songActorUpdater = function(self, song)
        (self.fontActor):settext(song:GetMainTitle())
    end,
    groupActorUpdater = function(self, packName)
        (self.fontActor):settext(packName)
    end,
    highlightBuilder = nil,
    frameTransformer = nil --function(frame, offsetFromCenter, index, total) -- Handle frame positioning
}

function MusicWheel:new(params)
    params = params or {}
    fillNilTableFieldsFrom(params, MusicWheel.defaultParams)
    local groupActorBuilder = params.groupActorBuilder
    local songActorBuilder = params.songActorBuilder
    local songActorUpdater = params.songActorUpdater
    local groupActorUpdater = params.groupActorUpdater
    -- Cache all pack counts
    local packCounts = SONGMAN:GetSongGroupNames()
    for i, song in ipairs(SONGMAN:GetAllSongs()) do
        local pack = song:GetGroupName()
        local x = packCounts[pack]
        packCounts[pack] = x and x + 1 or 1
    end
    local w
    w =
        Wheel:new {
        frameTransformer = params.frameTransformer,
        x = params.x,
        highlightBuilder = params.highlightBuilder,
        y = params.y,
        frameBuilder = function()
            local x
            x =
                Def.ActorFrame {
                InitCommand = function(self)
                    x.actor = self
                end,
                groupActorBuilder() ..
                    {
                        BeginCommand = function(self)
                            x.actor.g = self
                        end
                    },
                songActorBuilder() ..
                    {
                        BeginCommand = function(self)
                            x.actor.s = self
                        end
                    }
            }
            return x
        end,
        frameUpdater = function(frame, songOrPack)
            if songOrPack.GetAllSteps then -- song
                -- Update songActor and make group actor invis
                local s = frame.s
                s:visible(true)
                local g = (frame.g)
                g:visible(false)
                songActorUpdater(s, songOrPack)
            else
                --update group actor and make song actor invis
                local s = frame.s
                s:visible(false)
                local g = (frame.g)
                g:visible(true)
                groupActorUpdater(g, songOrPack, packCounts[songOrPack])
            end
        end,
        onSelection = function(frame, songOrPack)
            if songOrPack.GetAllSteps then -- song
                -- Start song
                -- TODO: Add C++
                -- SCREENMAN:GetTopScreen():StartSong(songOrPack)
                -- steps???
            else
                local group = songOrPack
                if w.group and w.group == group then -- close pack
                    w.group = nil
                    local newItems = SONGMAN:GetSongGroupNames()
                    w.index = findKeyOf(newItems, group)
                    w.itemsGetter = function()
                        return newItems
                    end
                else -- open pack
                    w.group = group
                    local groups = SONGMAN:GetSongGroupNames()
                    local g1, g2 = split(groups, group)
                    local newItems = concat(g1, {group}, SONGMAN:GetSongsInGroup(group), g2)
                    w.index = findKeyOf(newItems, group)
                    w.itemsGetter = function()
                        return newItems
                    end
                end
                w:rebuildFrames()
            end
        end,
        itemsGetter = function()
            local groups = SONGMAN:GetSongGroupNames()
            table.sort(
                groups,
                function(a, b)
                    return a < b
                end
            )
            return groups
        end
    }
    return w
end

local function GetMetric(a, b)
    return THEME:GetMetric(a, b)
end
local function LegacyParams()
    local function SelectMusicWheelMetric(key)
        return GetMetric("ScreenSelectMusic", "MusicWheel" .. key)
    end
    local function MusicWheelMetric(key)
        return GetMetric("MusicWheel", key)
    end
    local function TextBannerMetric(key)
        return GetMetric("TextBanner", key)
    end
    local function MusicWheelItemMetric(key)
        return GetMetric("MusicWheelItem", key)
    end
    local wheelItemTypes = {
        "Custom",
        "Mode",
        "Portal",
        "Random",
        "Roulette",
        "SectionExpanded",
        "SectionCollapsed",
        "Song",
        "Sort"
    }
    local function loadGraphicFile(filename)
        return LoadActor(THEME:GetPathG("", filename))
    end
    local function loadMusicWheelThingActor(thing)
        return loadGraphicFile("MusicWheel " .. thing)
    end
    local function loadMusicWheelItemThingActor(thing)
        return loadGraphicFile("MusicWheelItem " .. thing)
    end
    local function loadMusicWheelItemTypePartLegacyActor(type, part)
        local str = type .. part
        return loadMusicWheelItemThingActor(type .. " " .. part .. "Part") ..
            {
                OnCommand = MusicWheelItemMetric(str .. "OnCommand"),
                InitCommand = function(self)
                    self:xy(MusicWheelItemMetric(str .. "X"), MusicWheelItemMetric(str .. "Y"))
                    self:playcommand("On")
                end
            }
    end
    local function loadMusicWheelItemTypeFontLegacyActor(type)
        return LoadFont("Common Normal") ..
            {
                Name = type,
                OnCommand = MusicWheelItemMetric(type .. "OnCommand"),
                InitCommand = function(self)
                    self:xy(MusicWheelItemMetric(type .. "X"), MusicWheelItemMetric(type .. "Y"))
                    self:playcommand("On")
                end
            }
    end
    local params = {}
    params.x = tonumber(SelectMusicWheelMetric("X")) - SCREEN_WIDTH / 2
    params.y = tonumber(SelectMusicWheelMetric("Y"))
    params.frameTransformer = MusicWheelMetric("ItemTransformFunction")
    params.count = MusicWheelMetric("NumWheelItems")
    --[[
    params.actorBuilders = {}
    for i = 1, #wheelItemTypes do
        local type = wheelItemTypes[i]
        params.actorBuilders[type] = constF(loadMusicWheelItemTypeLegacyActor(type))
    end
    -- TODO: grades isnt an item of params????
    params.actorBuilders.grades = constF(loadMusicWheelItemThingActor("grades"))
    params.actorBuilders.highlight = constF(loadGraphicFile("highlight"))
    ]]
    local TextBannerFont = function(type, t)
        return LoadFont("Common Normal") ..
            {
                BeginCommand = function(self)
                    (t.actor)[type] = self
                    self:playcommand("On")
                end,
                OnCommand = TextBannerMetric(type .. "OnCommand")
            }
    end

    -- The wheel item width for song rows
    local wheelItemWidth = 560

    params.songActorBuilder = function()
        local x = {}
        local t =
            Def.ActorFrame {
            InitCommand = function(self)
                x.actor = self
            end,
            -- Background bar for each item
            Def.Quad {
                Name = "BG",
                InitCommand = function(self)
                    self:zoomto(wheelItemWidth, 50):diffuse(color("#000000")):diffusealpha(0.7)
                end,
                SetDynamicAccentColorMessageCommand = function(self, params)
                    self:finishtweening():linear(0.15):diffuse(params.color):diffusealpha(0.25)
                end
            },
            -- Top separator line
            Def.Quad {
                Name = "TopLine",
                InitCommand = function(self)
                    self:y(-25):zoomto(wheelItemWidth, 1):diffuse(color("#333333")):diffusealpha(0.5)
                end
            },
            -- Title (bold, left-aligned)
            LoadFont("Common Large") .. {
                Name = "Title",
                InitCommand = function(self)
                    self:xy(-wheelItemWidth/2 + 10, -10):zoom(0.35):halign(0):valign(0.5)
                    self:maxwidth((wheelItemWidth * 0.6) / 0.35)
                end,
                BeginCommand = function(self)
                    x.actor.Title = self
                end
            },
            -- Artist + Difficulty (smaller, on same line as title)
            LoadFont("Common Normal") .. {
                Name = "Artist",
                InitCommand = function(self)
                    self:xy(-wheelItemWidth/2 + 10, 3):zoom(0.3):halign(0):valign(0.5):diffuse(color("#CCCCCC"))
                    self:maxwidth((wheelItemWidth * 0.55) / 0.3)
                end,
                BeginCommand = function(self)
                    x.actor.Artist = self
                end
            },
            -- Subtitle / description (smallest, below)
            LoadFont("Common Normal") .. {
                Name = "Subtitle",
                InitCommand = function(self)
                    self:xy(-wheelItemWidth/2 + 10, 16):zoom(0.25):halign(0):valign(0.5):diffuse(color("#888888"))
                    self:maxwidth((wheelItemWidth * 0.65) / 0.25)
                end,
                BeginCommand = function(self)
                    x.actor.Subtitle = self
                end
            },
            -- Pack name (far right)
            LoadFont("Common Normal") .. {
                Name = "PackName",
                InitCommand = function(self)
                    self:xy(wheelItemWidth/2 - 10, -10):zoom(0.3):halign(1):valign(0.5):diffuse(color("#AAAAAA"))
                    self:maxwidth(150 / 0.3)
                end,
                BeginCommand = function(self)
                    x.actor.PackName = self
                end
            },
            -- Grade display (right half)
            loadMusicWheelItemThingActor("grades") .. {
                BeginCommand = function(self)
                    self:xy(wheelItemWidth/2 - 120, 0):zoom(0.7)
                    x.actor.grades = self
                end
            },
            -- ClearType text (right of grade)
            LoadFont("Common Normal") .. {
                Name = "ClearType",
                InitCommand = function(self)
                    self:xy(wheelItemWidth/2 - 50, 0):zoom(0.35):halign(0.5):valign(0.5)
                end,
                BeginCommand = function(self)
                    x.actor.ClearType = self
                end
            }
        }
        return t
    end
    params.groupActorBuilder = function()
        local g
        g =
            Def.ActorFrame {
            InitCommand = function(self)
                g.actor = self
            end,
            -- Background bar for pack headers
            Def.Quad {
                Name = "BG",
                InitCommand = function(self)
                    self:zoomto(wheelItemWidth, 50):diffuse(color("#000000")):diffusealpha(0.7)
                end,
                SetDynamicAccentColorMessageCommand = function(self, params)
                    self:finishtweening():linear(0.15):diffuse(params.color):diffusealpha(0.25)
                end
            },
            -- Top separator line
            Def.Quad {
                Name = "TopLine",
                InitCommand = function(self)
                    self:y(-25):zoomto(wheelItemWidth, 1):diffuse(color("#333333")):diffusealpha(0.5)
                end
            },
        }
        g[#g + 1] =
            loadMusicWheelItemTypeFontLegacyActor("SectionCollapsed") ..
            {
                BeginCommand = function(self)
                    g.actor.SectionCollapsed = self
                end
            }
        g[#g + 1] =
            LoadFont("Common Normal") ..
            {
                Name = "SectionCount",
                OnCommand = MusicWheelItemMetric("SectionCountOnCommand"),
                BeginCommand = function(self)
                    self:xy(MusicWheelItemMetric("SectionCountX"), MusicWheelItemMetric("SectionCountY"))
                    self:playcommand("On")
                    g.actor.sectionCount = self
                end
            }
        return g
    end
    params.songActorUpdater = function(self, song)
        -- Title
        self.Title:settext(song:GetDisplayMainTitle())
        -- Artist + Difficulty on same line
        local artist = song:GetDisplayArtist()
        local diff = ""
        local steps = GAMESTATE:GetCurrentSteps()
        if steps then
            diff = steps:GetDifficulty():gsub("Difficulty_", "")
        end
        if artist ~= "" and diff ~= "" then
            self.Artist:settext(artist .. " · " .. diff)
        elseif artist ~= "" then
            self.Artist:settext(artist)
        else
            self.Artist:settext(diff)
        end
        -- Subtitle / chart description
        local sub = song:GetDisplaySubTitle()
        self.Subtitle:settext(sub)
        -- Pack name on far right
        self.PackName:settext(song:GetGroupName())

        self:diffuse(color("#FFFFFF"))

        -- Grade and ClearType
        local grade = song:GetTopGrade(steps, PLAYER_1)
        self.grades:playcommand(
            "SetGrade",
            {
                Grade = grade,
                Difficulty = steps and steps:GetDifficulty() or "Beginner",
                HasGoal = false,
                Favorited = song:IsFavorited(),
                PermaMirror = false,
                PlayerNumber = PLAYER_1
            }
        )

        -- ClearType from best score
        if steps then
            local chartKey = steps:GetChartKey()
            local scoresByRate = SCOREMAN:GetScoresByKey(chartKey)
            if scoresByRate then
                local bestScore = nil
                for _, scores in pairs(scoresByRate) do
                    for _, s in ipairs(scores) do
                        if bestScore == nil or s:GetWifeScore() > bestScore:GetWifeScore() then
                            bestScore = s
                        end
                    end
                end
                if bestScore then
                    self.ClearType:settext(getClearTypeFromScore(PLAYER_1, bestScore, 0))
                    self.ClearType:diffuse(getClearTypeFromScore(PLAYER_1, bestScore, 2))
                else
                    self.ClearType:settext("")
                end
            else
                self.ClearType:settext("")
            end
        else
            self.ClearType:settext("")
        end
    end
    params.groupActorUpdater = function(self, packName, count)
        self.SectionCollapsed:settext(packName)
        self.SectionCollapsed:diffuse(SONGMAN:GetSongGroupColor(packName))
        self.sectionCount:settext(tostring(count))
    end
    params.highlightBuilder = function()
        return loadMusicWheelThingActor("highlight")
    end
    return params
end

function MusicWheel:Legacy()
    return MusicWheel:new(LegacyParams())
end
