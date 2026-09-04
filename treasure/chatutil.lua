---------------------------------------------------------------------------
-- Treasure · chatutil.lua
-- Shared incoming-text normalization and origin classification.
---------------------------------------------------------------------------

local chatutil = {}

-- FFXI chat modes that can be authored directly by a player. Unknown modes
-- are intentionally not rejected so private-server system modes remain
-- compatible; callers can use stricter allow-lists where the protocol is known.
local PLAYER_TEXT_MODES = {
    [1] = true, [2] = true, [3] = true,
    [4] = true, [5] = true, [6] = true, [7] = true,
    [9] = true, [10] = true, [11] = true, [12] = true,
    [13] = true, [14] = true, [15] = true,
    [205] = true, [206] = true,
    [211] = true, [212] = true, [213] = true, [214] = true,
    [217] = true, [220] = true, [222] = true,
}

function chatutil.is_player_text_mode(mode)
    return PLAYER_TEXT_MODES[tonumber(mode)] == true
end

function chatutil.is_trusted_game_text(context)
    if context and context.injected == true then
        return false
    end
    return not chatutil.is_player_text_mode(context and context.mode)
end

function chatutil.strip(s)
    s = tostring(s or '')
    -- Color/control prefixes are two-byte digraphs. Remove both bytes before
    -- sweeping remaining controls so the payload byte cannot break patterns.
    s = s:gsub('[\30\31\127].', '')
    s = s:gsub('%c', ' ')
    s = s:gsub('^%[%d%d:%d%d:%d%d%]%s*', '')
    s = s:gsub('^%b()%s*', '')
    s = s:gsub('%s+', ' ')
    return s:gsub('^%s+', ''):gsub('%s+$', '')
end

function chatutil.normalize(s)
    return chatutil.strip(s):lower()
end

return chatutil
