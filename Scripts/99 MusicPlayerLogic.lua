-- Global Music Player Logic for Reset-Day theme

SongHistory = {
    stack = {},
    maxSize = 50,
}

function SongHistory.Add(song)
    if not song then return end
    -- Don't add if it's the same as the last one
    if #SongHistory.stack > 0 and SongHistory.stack[#SongHistory.stack] == song then
        return
    end
    
    table.insert(SongHistory.stack, song)
    if #SongHistory.stack > SongHistory.maxSize then
        table.remove(SongHistory.stack, 1)
    end
    MESSAGEMAN:Broadcast("MusicHistoryChanged")
end

function SongHistory.GetPrevious()
    if #SongHistory.stack > 1 then
        -- The last item is the current song, so remove it first
        table.remove(SongHistory.stack)
        -- Return the one before it
        local prev = SongHistory.stack[#SongHistory.stack]
        MESSAGEMAN:Broadcast("MusicHistoryChanged")
        return prev
    end
    return nil
end

function SelectRandomSong()
    local top = SCREENMAN:GetTopScreen()
    if top and top.GetMusicWheel then
        local we = top:GetMusicWheel()
        local allSongs = SONGMAN:GetAllSongs()
        if allSongs and #allSongs > 0 then
            local randomSong = allSongs[math.random(#allSongs)]
            we:SelectSong(randomSong)
        end
    elseif MenuMusicState and MenuMusicState.Save then
        local allSongs = SONGMAN:GetAllSongs()
        if allSongs and #allSongs > 0 then
            local randomSong = allSongs[math.random(#allSongs)]
            MenuMusicState.Save(randomSong, 0)
        end
    end
end

-- Helper to safely handle song changes and update history
-- This can be called from a MessageCommand
function HandleSongChangeForHistory()
    local song = GAMESTATE:GetCurrentSong()
    if song then
        SongHistory.Add(song)
    end
end

MenuMusicState = {
    lastSong = nil,
    samplePosition = 0,
}

local function getSongChartKey(song)
    if not song then return "" end
    local allSteps = song.GetAllSteps and song:GetAllSteps() or nil
    if not allSteps then return "" end
    for _, steps in ipairs(allSteps) do
        local ok, chartKey = pcall(function() return steps:GetChartKey() end)
        if ok and chartKey and chartKey ~= "" then
            return chartKey
        end
    end
    return ""
end

function MenuMusicState.Save(song, samplePosition, suppressBroadcast)
    local songChanged = song ~= nil and song ~= MenuMusicState.lastSong
    local shouldAddToHistory = song ~= nil and SongHistory and SongHistory.Add and (#SongHistory.stack == 0 or songChanged)
    if song then
        MenuMusicState.lastSong = song
        local chartKey = getSongChartKey(song)
        if chartKey ~= "" then
            themeConfig:get_data().global.LastSongChartKey = chartKey
        end
        if shouldAddToHistory then
            SongHistory.Add(song)
        end
    end
    if samplePosition ~= nil then
        MenuMusicState.samplePosition = math.max(0, samplePosition)
        themeConfig:get_data().global.LastSampleMusicPosition = MenuMusicState.samplePosition
    end
    themeConfig:set_dirty()
    themeConfig:save()
    if not suppressBroadcast then
        MESSAGEMAN:Broadcast("MenuMusicStateChanged")
    end
end

function MenuMusicState.LoadLastSong()
    if MenuMusicState.lastSong then return MenuMusicState.lastSong end
    local chartKey = themeConfig:get_data().global.LastSongChartKey or ""
    if chartKey == "" then return nil end
    local song = SONGMAN:GetSongByChartKey(chartKey)
    if song then
        MenuMusicState.lastSong = song
    end
    return song
end

function MenuMusicState.GetMenuSong()
    return MenuMusicState.lastSong or MenuMusicState.LoadLastSong()
end

function MenuMusicState.GetScreenSong(top)
    top = top or SCREENMAN:GetTopScreen()
    if top and top.GetMusicWheel then
        return GAMESTATE:GetCurrentSong() or MenuMusicState.GetMenuSong()
    end
    return MenuMusicState.GetMenuSong() or GAMESTATE:GetCurrentSong()
end

function MenuMusicState.GetActiveSong()
    return MenuMusicState.GetScreenSong(SCREENMAN:GetTopScreen())
end

function MenuMusicState.LoadSavedPosition()
    local saved = themeConfig:get_data().global.LastSampleMusicPosition or 0
    MenuMusicState.samplePosition = math.max(0, saved)
    return MenuMusicState.samplePosition
end

function MenuMusicState.CaptureFromTopScreen(top)
    if not top then return end
    local song = GAMESTATE:GetCurrentSong() or MenuMusicState.lastSong
    local samplePosition = nil
    if top.GetSampleMusicPosition then
        local ok, pos = pcall(function() return top:GetSampleMusicPosition() end)
        if ok and type(pos) == "number" then
            samplePosition = pos
        end
    end
    MenuMusicState.Save(song, samplePosition)
end

function MenuMusicState.RestoreToWheel(wheel)
    local song = MenuMusicState.LoadLastSong()
    if wheel and song then
        wheel:SelectSong(song)
    end
    return song
end

function MenuMusicState.RestorePlayback(top)
    if not top or not top.SetSampleMusicPosition then return end
    local position = MenuMusicState.LoadSavedPosition()
    if position > 0 then
        top:SetSampleMusicPosition(position)
    end
end
