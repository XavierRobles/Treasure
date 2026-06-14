---------------------------------------------------------------------------
-- Treasure · weekly/highwind.lua
-- Highwind weekly kill tracker (HorizonXI).
-- Signal: "<name> defeats the Highwind." followed by local-player XP gain
-- within XP_CONFIRM_WINDOW seconds.
---------------------------------------------------------------------------

local fs = ashita.fs

local highwind = {
    id = 'highwind',
    title = 'Highwind',
}

local SERVER_NAME = 'HorizonXI'
local MAX_MESSAGES = 6
local XP_CONFIRM_WINDOW = 5
local DEFEAT_PATTERN = '^[%w%-_]+%s+defeats%s+the%s+highwind%.?$'

local state = nil
local state_file = nil
local player_name = nil
local pending_defeat_at = nil
local pending_defeat_killer = nil
local ui_messages = {}

local function default_state()
    return {
        version = 1,
        server = SERVER_NAME,
        character = player_name or 'Unknown',
        killedThisWeek = false,
        lastKillTimestamp = nil,
        lastKillerName = nil,
        lastKnownWeekId = nil,
        confidence = 'auto',
    }
end

local function serialize(value, indent)
    indent = indent or 0
    local t = type(value)
    if t == 'nil' then return 'nil' end
    if t == 'number' or t == 'boolean' then return tostring(value) end
    if t == 'string' then return string.format('%q', value) end
    if t ~= 'table' then return 'nil' end
    local pad = string.rep(' ', indent)
    local child = string.rep(' ', indent + 4)
    local parts = { '{' }
    for k, v in pairs(value) do
        local key
        if type(k) == 'string' and k:match('^[%a_][%w_]*$') then
            key = k
        else
            key = '[' .. serialize(k, 0) .. ']'
        end
        parts[#parts + 1] = ('\n%s%s = %s,'):format(child, key, serialize(v, indent + 4))
    end
    parts[#parts + 1] = '\n' .. pad .. '}'
    return table.concat(parts)
end

local function load_table(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    local loader = loadstring(content)
    if not loader then return nil end
    local ok, data = pcall(loader)
    if ok and type(data) == 'table' then return data end
    return nil
end

local function save_table(path, data)
    local f = io.open(path, 'w+')
    if not f then return false end
    f:write('return ')
    f:write(serialize(data, 0))
    f:write('\n')
    f:close()
    return true
end

local function normalize_loaded(loaded)
    local def = default_state()
    if type(loaded) ~= 'table' then return def end
    for k, v in pairs(def) do
        if loaded[k] == nil then loaded[k] = v end
    end
    loaded.server = SERVER_NAME
    loaded.character = player_name or loaded.character or 'Unknown'
    return loaded
end

local function save()
    if not (state and state_file) then return end
    state.character = player_name or state.character or 'Unknown'
    save_table(state_file, state)
end

local function jst_week_id(timestamp)
    timestamp = timestamp or os.time()
    local days = math.floor((timestamp + 9 * 3600) / 86400)
    -- Week boundary at JST Mon 00:00 (end of Sunday JST). Day index 4 = Monday.
    return math.floor((days - 4) / 7)
end

local function next_reset_timestamp(timestamp)
    timestamp = timestamp or os.time()
    local week = jst_week_id(timestamp)
    local next_monday_day = ((week + 1) * 7) + 4
    return (next_monday_day * 86400) - (9 * 3600)
end

function highwind.format_jst(ts)
    local jst = os.date('!*t', (ts or os.time()) + 9 * 3600)
    return ('%04d-%02d-%02d %02d:%02d JST'):format(jst.year, jst.month, jst.day, jst.hour, jst.min)
end

function highwind.format_local(ts)
    local lt = os.date('*t', ts or os.time())
    return ('%04d-%02d-%02d %02d:%02d'):format(lt.year, lt.month, lt.day, lt.hour, lt.min)
end

function highwind.next_reset_timestamp(ts)
    return next_reset_timestamp(ts)
end

local function push_message(text)
    ui_messages[#ui_messages + 1] = { time = os.time(), text = tostring(text or '') }
    while #ui_messages > MAX_MESSAGES do
        table.remove(ui_messages, 1)
    end
end

function highwind.push_message(t) push_message(t) end
function highwind.get_messages() return ui_messages end
function highwind.clear_messages() ui_messages = {} end

local function roll_week_if_needed()
    if not state then return end
    local wid = jst_week_id()
    if state.lastKnownWeekId == nil then
        state.lastKnownWeekId = wid
        save()
        return
    end
    if state.lastKnownWeekId ~= wid then
        state.lastKnownWeekId = wid
        state.killedThisWeek = false
        save()
        push_message('Weekly Highwind lock reset.')
    end
end

function highwind.get_state() return state end

function highwind.is_killed_this_week()
    if not state then return false end
    return state.killedThisWeek == true
end

function highwind.get_summary()
    if not state then return '' end
    if state.killedThisWeek then
        return 'Highwind: killed this week'
    end
    return 'Highwind: available'
end

function highwind.get_next_step()
    if not state then return '' end
    if state.killedThisWeek then
        return 'Wait for weekly reset (Sunday 23:59 JST).'
    end
    return 'Go fight the Highwind for your weekly kill.'
end

local function normalize_text(s)
    s = tostring(s or '')
    s = s:gsub('%[%d%d:%d%d:%d%d%]', ' ')
    s = s:gsub('%c', ' ')
    s = s:gsub('%s+', ' ')
    return s:lower():gsub('^%s+', ''):gsub('%s+$', '')
end

local function match_defeat(text)
    local killer = text:match('^([%w%-_]+)%s+defeats%s+the%s+highwind%.?$')
    return killer
end

local function match_local_xp_gain(text)
    if not player_name or player_name == '' then return false end
    local pn = player_name:lower()
    local first = text:match('^([%w%-_]+)%s+gains%s+%d+%s+experience%s+points?%.?$')
    if not first then return false end
    return first == pn
end

local function confirm_kill()
    if not state then return end
    if state.killedThisWeek then
        pending_defeat_at = nil
        pending_defeat_killer = nil
        return
    end
    state.killedThisWeek = true
    state.lastKillTimestamp = os.time()
    state.lastKillerName = pending_defeat_killer
    state.confidence = 'auto'
    save()
    push_message(('Highwind kill confirmed (killer: %s).'):format(pending_defeat_killer or '?'))
    pending_defeat_at = nil
    pending_defeat_killer = nil
end

function highwind.on_text(line)
    if not state then return end
    local norm = normalize_text(line)
    if norm == '' then return end

    roll_week_if_needed()

    local killer = match_defeat(norm)
    if killer then
        pending_defeat_at = os.time()
        pending_defeat_killer = killer
        return
    end

    if pending_defeat_at and match_local_xp_gain(norm) then
        if (os.time() - pending_defeat_at) <= XP_CONFIRM_WINDOW then
            confirm_kill()
        else
            pending_defeat_at = nil
            pending_defeat_killer = nil
        end
    end
end

function highwind.tick()
    if not state then return end
    roll_week_if_needed()
    if pending_defeat_at and (os.time() - pending_defeat_at) > XP_CONFIRM_WINDOW then
        pending_defeat_at = nil
        pending_defeat_killer = nil
    end
end

function highwind.mark_killed()
    if not state then return false, 'state not loaded' end
    state.killedThisWeek = true
    state.lastKillTimestamp = os.time()
    state.confidence = 'manual_override'
    save()
    return true
end

function highwind.undo()
    if not state then return false, 'state not loaded' end
    state.killedThisWeek = false
    state.confidence = 'manual_override'
    save()
    return true
end

function highwind.reset_week()
    if not state then return false, 'state not loaded' end
    state.killedThisWeek = false
    state.confidence = 'manual_override'
    save()
    return true
end

function highwind.reset_all()
    if not state then return false, 'state not loaded' end
    state = default_state()
    state.lastKnownWeekId = jst_week_id()
    state.confidence = 'manual_override'
    save()
    return true
end

function highwind.save() save() end

function highwind.init(pname, base_dir)
    if not pname or pname == '' then
        state = nil
        state_file = nil
        player_name = nil
        pending_defeat_at = nil
        pending_defeat_killer = nil
        return
    end
    if player_name == pname and state ~= nil then
        roll_week_if_needed()
        return
    end
    if state and state_file then save() end
    player_name = pname
    local weekly_dir = base_dir .. 'weekly\\'
    if not fs.exists(weekly_dir) then fs.create_dir(weekly_dir) end
    state_file = weekly_dir .. 'highwind.lua'
    state = normalize_loaded(load_table(state_file))
    pending_defeat_at = nil
    pending_defeat_killer = nil
    roll_week_if_needed()
    save()
end

return highwind
