---------------------------------------------------------------------------
-- Treasure · weekly/highwind.lua
-- Highwind weekly kill tracker (HorizonXI).
-- Signals:
--   * Official combat-mode defeat/fall message.
--   * Exact 3000 XP + 3000 gil reward pair inside an Airship zone.
---------------------------------------------------------------------------

local fs = ashita.fs
local persist = require('persist')
local chatutil = require('chatutil')

local highwind = {
    id = 'highwind',
    title = 'Highwind',
}

local SERVER_NAME = 'HorizonXI'
local MAX_MESSAGES = 6
local XP_CONFIRM_WINDOW = 5
local REWARD_CONFIRM_WINDOW = 5
local SERVER_DEFEAT_MODES = {
    [36] = true,  -- You defeat enemy.
    [37] = true,  -- Party member defeats enemy.
    [44] = true,  -- Other/pet defeat or enemy falls to the ground.
    [166] = true, -- Alliance member defeats enemy.
}
local state = nil
local state_file = nil
local player_name = nil
local pending_defeat_at = nil
local pending_defeat_killer = nil
local pending_reward_xp_at = nil
local pending_reward_gil_at = nil
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
    return persist.load_table(path)
end

local function save_table(path, data)
    return persist.write_atomic(path, 'return ' .. serialize(data, 0) .. '\n')
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

function highwind.is_killed_this_week(candidate)
    local current = type(candidate) == 'table' and candidate or state
    if not current then return false end
    return current.killedThisWeek == true
end

function highwind.get_summary(candidate)
    local current = type(candidate) == 'table' and candidate or state
    if not current then return '' end
    if current.killedThisWeek then
        return 'Highwind: killed this week'
    end
    return 'Highwind: available'
end

function highwind.prepare_view(loaded, character)
    local view = normalize_loaded(loaded)
    view.character = character or view.character or 'Unknown'
    local wid = jst_week_id()
    if view.lastKnownWeekId ~= nil and view.lastKnownWeekId ~= wid then
        view.killedThisWeek = false
    end
    view.lastKnownWeekId = wid
    return view
end

function highwind.get_next_step()
    if not state then return '' end
    if state.killedThisWeek then
        return 'Wait for weekly reset (Sunday 23:59 JST).'
    end
    return 'Go fight the Highwind for your weekly kill.'
end

local function normalize_text(s)
    return chatutil.normalize(s)
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

local function match_local_highwind_xp(text)
    if not player_name or player_name == '' then return false end
    local first, amount = text:match('^([%w%-_]+)%s+gains%s+(%d+)%s+experience%s+points?%.?$')
    return first == player_name:lower() and tonumber(amount) == 3000
end

local function match_highwind_gil(text)
    local amount = text:match('^obtained%s+(%d+)%s+gil%.?$')
    return tonumber(amount) == 3000
end

local function in_airship_zone(context)
    local zone_name = chatutil.normalize(context and context.zone_name or '')
    return zone_name:find('airship', 1, true) ~= nil
end

local function text_mode(context)
    return tonumber(context and context.mode)
end

local function clear_pending()
    pending_defeat_at = nil
    pending_defeat_killer = nil
    pending_reward_xp_at = nil
    pending_reward_gil_at = nil
end

local function confirm_kill(source)
    if not state then return end
    if state.killedThisWeek then
        clear_pending()
        return
    end
    state.killedThisWeek = true
    state.lastKillTimestamp = os.time()
    state.lastKillerName = pending_defeat_killer
    state.confidence = 'auto'
    save()
    if source == 'reward' then
        push_message('Highwind kill confirmed (3000 EXP + 3000 gil).')
    else
        push_message(('Highwind kill confirmed (killer: %s).'):format(pending_defeat_killer or '?'))
    end
    clear_pending()
end

function highwind.on_text(line, context)
    if not state then return end
    local norm = normalize_text(line)
    if norm == '' then return end

    roll_week_if_needed()

    local killer = match_defeat(norm)
    if killer then
        local mode = text_mode(context)
        if SERVER_DEFEAT_MODES[mode] then
            pending_defeat_killer = killer
            confirm_kill('defeat')
        elseif not chatutil.is_player_text_mode(mode) then
            -- Compatibility fallback for an unknown/missing combat mode:
            -- require the local XP line before accepting the defeat text.
            pending_defeat_at = os.time()
            pending_defeat_killer = killer
        end
        return
    end

    if norm == 'the highwind falls to the ground.' or norm == 'the highwind falls to the ground' then
        local mode = text_mode(context)
        if SERVER_DEFEAT_MODES[mode] then
            pending_defeat_killer = 'server'
            confirm_kill('defeat')
        elseif not chatutil.is_player_text_mode(mode) then
            pending_defeat_at = os.time()
            pending_defeat_killer = 'server'
        end
        return
    end

    if pending_defeat_at and match_local_xp_gain(norm) then
        if (os.time() - pending_defeat_at) <= XP_CONFIRM_WINDOW then
            confirm_kill('defeat')
        else
            pending_defeat_at = nil
            pending_defeat_killer = nil
        end
    end

    if in_airship_zone(context) then
        local now = os.time()
        if match_local_highwind_xp(norm) then
            pending_reward_xp_at = now
        elseif match_highwind_gil(norm) then
            pending_reward_gil_at = now
        end
        if pending_reward_xp_at and pending_reward_gil_at
                and math.abs(pending_reward_xp_at - pending_reward_gil_at) <= REWARD_CONFIRM_WINDOW then
            confirm_kill('reward')
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
    if pending_reward_xp_at and (os.time() - pending_reward_xp_at) > REWARD_CONFIRM_WINDOW then
        pending_reward_xp_at = nil
    end
    if pending_reward_gil_at and (os.time() - pending_reward_gil_at) > REWARD_CONFIRM_WINDOW then
        pending_reward_gil_at = nil
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
        pending_reward_xp_at = nil
        pending_reward_gil_at = nil
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
    pending_reward_xp_at = nil
    pending_reward_gil_at = nil
    roll_week_if_needed()
    save()
end

return highwind
