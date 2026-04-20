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
