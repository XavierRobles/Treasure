---------------------------------------------------------------------------
-- Treasure · weekly/ecowar.lua
-- Eco-Warrior weekly tracker (HorizonXI).
-- Ported from the standalone "ecowar" addon to live inside Treasure.
---------------------------------------------------------------------------

local fs = ashita.fs

local ecowar = {
    id = 'ecowar',
    title = 'Eco-War',
}

local SERVER_NAME = 'HorizonXI'
local ALL_ECOS = { 'sandy', 'windy', 'bastok' }
local ECO_LABELS = {
    sandy = "San d'Oria",
    windy = 'Windurst',
    bastok = 'Bastok',
}
local FIELD_NPCS = {
    sandy = "Rojaireaut in Ordelle's Caves",
    windy = 'Ahko Mhalijikhari in Maze of Shakhrami',
    bastok = 'Degga in Gusgen Mines',
}
local CITY_NPCS = {
    sandy = "Norejaie in Southern San d'Oria",
    windy = 'Lumomo in Windurst',
    bastok = 'Raifa in Bastok',
}
local PHASES = {
    none = true,
    accepted = true,
    field_agent_started = true,
    nm_ready = true,
    key_item_obtained = true,
    field_agent_confirmed = true,
    completed = true,
    blocked = true,
}
local PHASE_LABELS = {
    none = 'None',
    accepted = 'Accepted',
    field_agent_started = 'Field NPC started',
    nm_ready = 'NM ready',
    key_item_obtained = 'Key item obtained',
    field_agent_confirmed = 'Reward ready',
    completed = 'Completed',
    blocked = 'Blocked',
}
local MAX_MESSAGES = 6
local MAX_BUFFER = 8
local DEBOUNCE_SECONDS = 3

local state = nil
local state_file = nil
local player_name = nil
local text_buffer = {}
local debounce_map = {}
local ui_messages = {}

local function default_state()
    return {
        version = 1,
        server = SERVER_NAME,
        character = player_name or 'Unknown',
        activeEco = 'none',
        phase = 'none',
        cycleCompleted = {},
        currentWeekCompleted = 'none',
        lastKnownWeekId = nil,
        lastRewardTimestampJst = nil,
        hasKeyItem = false,
        fieldAgentConfirmed = false,
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
    if type(loaded.cycleCompleted) ~= 'table' then loaded.cycleCompleted = {} end
    if PHASES[loaded.phase] ~= true then loaded.phase = 'none' end
    if loaded.activeEco == nil then loaded.activeEco = 'none' end
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
    -- Reset at JST Mon 00:00 (= end of Sunday JST). Day index 4 = Monday (epoch JST day 0 = Thursday).
    local next_monday_day = ((week + 1) * 7) + 4
    return (next_monday_day * 86400) - (9 * 3600)
end

function ecowar.format_jst(ts)
    local jst = os.date('!*t', (ts or os.time()) + 9 * 3600)
    return ('%04d-%02d-%02d %02d:%02d JST'):format(jst.year, jst.month, jst.day, jst.hour, jst.min)
end

function ecowar.format_local(ts)
    local lt = os.date('*t', ts or os.time())
    return ('%04d-%02d-%02d %02d:%02d'):format(lt.year, lt.month, lt.day, lt.hour, lt.min)
end

function ecowar.next_reset_timestamp(ts)
    return next_reset_timestamp(ts)
end

local function push_message(text)
    ui_messages[#ui_messages + 1] = { time = os.time(), text = tostring(text or '') }
    while #ui_messages > MAX_MESSAGES do
        table.remove(ui_messages, 1)
    end
end

function ecowar.push_message(t) push_message(t) end
function ecowar.get_messages() return ui_messages end
function ecowar.clear_messages() ui_messages = {} end

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
        state.currentWeekCompleted = 'none'
        save()
        push_message('Weekly Eco-War lock reset. Cycle progress kept.')
    end
end

local function eco_label(eco) return ECO_LABELS[eco] or tostring(eco or 'none') end

local function eco_list_string(list)
    if not list or #list == 0 then return 'none' end
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = eco_label(e) end
    return table.concat(out, ', ')
end

function ecowar.eco_label(eco) return eco_label(eco) end
function ecowar.eco_list_string(list) return eco_list_string(list) end
function ecowar.field_npc(eco) return FIELD_NPCS[eco] end
function ecowar.city_npc(eco) return CITY_NPCS[eco] end
function ecowar.all_ecos() return ALL_ECOS end

function ecowar.is_cycle_complete()
    if not state then return false end
    return state.cycleCompleted.sandy == true
            and state.cycleCompleted.windy == true
            and state.cycleCompleted.bastok == true
end

function ecowar.get_available_by_cycle()
    if not state then return {} end
    if ecowar.is_cycle_complete() then return { 'sandy', 'windy', 'bastok' } end
    local out = {}
    for _, e in ipairs(ALL_ECOS) do
        if state.cycleCompleted[e] ~= true then out[#out + 1] = e end
    end
    return out
end

function ecowar.get_completed_list()
    if not state then return {} end
    local out = {}
    for _, e in ipairs(ALL_ECOS) do
        if state.cycleCompleted[e] == true then out[#out + 1] = e end
    end
    return out
end

function ecowar.get_state() return state end

function ecowar.get_phase_label()
    if not state then return 'None' end
    return PHASE_LABELS[state.phase] or tostring(state.phase or 'none')
end

function ecowar.get_summary()
    if not state then return '' end
    if state.activeEco ~= 'none' then
        return ('Eco: %s | %s'):format(eco_label(state.activeEco), ecowar.get_phase_label())
    end
    if state.currentWeekCompleted ~= 'none' then
        return ('Eco: %s done'):format(eco_label(state.currentWeekCompleted))
    end
    local avail = ecowar.get_available_by_cycle()
    if #avail == 0 then return 'Eco: cycle done' end
    return ('Eco: %s open'):format(eco_list_string(avail))
end

function ecowar.get_accept_now_string()
    if not state then return 'none' end
    if state.activeEco ~= 'none' then return 'none, active quest in progress' end
    if state.currentWeekCompleted ~= 'none' then return 'none until next reset' end
    return eco_list_string(ecowar.get_available_by_cycle())
end

function ecowar.get_next_step()
    if not state then return '' end
    if state.activeEco == 'none' then
        if state.currentWeekCompleted ~= 'none' then
            return 'Wait for weekly reset (Sunday 23:59 JST).'
        end
        return 'Choose: ' .. eco_list_string(ecowar.get_available_by_cycle()) .. '.'
    end
    if state.phase == 'accepted' then return 'Talk to ' .. FIELD_NPCS[state.activeEco] .. '.' end
    if state.phase == 'field_agent_started' then return 'Accept ointment/level sync, then kill the NM.' end
    if state.phase == 'nm_ready' then return 'Kill the NM and touch ??? for the key item.' end
    if state.phase == 'key_item_obtained' then return 'Return to ' .. FIELD_NPCS[state.activeEco] .. '.' end
    if state.phase == 'field_agent_confirmed' then return 'Return to ' .. CITY_NPCS[state.activeEco] .. ' for reward.' end
    if state.phase == 'blocked' then return 'Blocked by weekly lock or active quest.' end
    return 'Talk to Eeko-Weeko or continue the quest.'
end

function ecowar.get_status_for_eco(eco)
    if not state then return 'OPEN' end
    if state.activeEco == eco then return 'ACTIVE' end
    if state.cycleCompleted[eco] == true then return 'DONE' end
    return 'OPEN'
end

local function normalize_text(s)
    s = tostring(s or '')
    s = s:gsub('%[%d%d:%d%d:%d%d%]', ' ')
    s = s:gsub('%c', ' ')
    s = s:gsub('%s+', ' ')
    return s:lower()
end

local function contains(text, needle) return text:find(needle, 1, true) ~= nil end

local function contains_all(text, needles)
    for _, n in ipairs(needles) do
        if not contains(text, n) then return false end
    end
    return true
end

local function debounced(key)
    local now = os.clock()
    local prev = debounce_map[key]
    if prev and (now - prev) < DEBOUNCE_SECONDS then return true end
    debounce_map[key] = now
    return false
end

local function buffer_add(line)
    text_buffer[#text_buffer + 1] = line
    while #text_buffer > MAX_BUFFER do
        table.remove(text_buffer, 1)
    end
    return table.concat(text_buffer, ' ')
end

local function buffer_clear() text_buffer = {} end

local function set_phase_internal(eco, phase)
    roll_week_if_needed()
    if eco ~= nil then state.activeEco = eco end
    state.phase = phase
    if phase == 'key_item_obtained' then
        state.hasKeyItem = true
    elseif phase == 'field_agent_confirmed' then
        state.hasKeyItem = true
        state.fieldAgentConfirmed = true
    end
    state.confidence = 'auto'
    save()
end

local function complete_eco_internal(eco)
    roll_week_if_needed()
    if state.currentWeekCompleted == eco and state.phase == 'completed' then return end
    if ecowar.is_cycle_complete() then state.cycleCompleted = {} end
    state.cycleCompleted[eco] = true
    state.currentWeekCompleted = eco
    state.activeEco = 'none'
    state.phase = 'completed'
    state.hasKeyItem = false
    state.fieldAgentConfirmed = false
    state.lastRewardTimestampJst = os.time() + 9 * 3600
    state.confidence = 'auto'
    save()
    push_message(('%s complete. Locked until %s.'):format(eco_label(eco), ecowar.format_jst(next_reset_timestamp())))
end

local function sync_cycle_internal(completed)
    roll_week_if_needed()
    state.cycleCompleted = {}
    for _, e in ipairs(completed) do state.cycleCompleted[e] = true end
    state.confidence = 'auto'
    save()
    local remaining = ecowar.get_available_by_cycle()
    push_message(('Eeko-Weeko sync. Done: %s | Remaining: %s.'):format(
            eco_list_string(ecowar.get_completed_list()),
            eco_list_string(remaining)))
end

local function apply(key, cb)
    if debounced(key) then return true end
    cb()
    return true
end

local function process_eeko(text)
    if contains_all(text, {
        'judging by all the buzzy-wuzzy at the consulates',
        "all three nation's vermin representatives could use a bravey-wavey adventurer this week",
    }) then
        return apply('eeko_all', function() sync_cycle_internal({}) end)
    end
    if contains(text, 'i seem to remember-member it coming from the direction of') then
        local done = {}
        if contains(text, "san d'oria consulate") then done[#done + 1] = 'sandy' end
        if contains(text, 'bastok consulate') then done[#done + 1] = 'bastok' end
        if contains(text, 'windurst consulate') then done[#done + 1] = 'windy' end
        if #done > 0 then
            return apply('eeko_completed_' .. table.concat(done, '_'), function() sync_cycle_internal(done) end)
        end
    end
    return false
end

local function process_triggers(text)
    roll_week_if_needed()
    if contains_all(text, { 'obtained: page from the dragon chronicles', 'obtained: tale of the wandering heroes' }) then
        local eco = state.activeEco
        if eco == 'sandy' or eco == 'windy' or eco == 'bastok' then
            return apply('reward_' .. eco, function() complete_eco_internal(eco) end)
        end
    end
    if contains_all(text, { 'how...lovely. a chunk of indigested meat', 'take it back to lumomo' }) then
        return apply('postki_windy', function()
            set_phase_internal('windy', 'field_agent_confirmed')
            push_message('Windurst ready. Return to Lumomo.')
        end)
    end
    if contains_all(text, { 'lemme see that... huh, an indigested ore', 'take it on back to raifa' }) then
        return apply('postki_bastok', function()
            set_phase_internal('bastok', 'field_agent_confirmed')
            push_message('Bastok ready. Return to Raifa.')
        end)
    end
    if contains_all(text, { "what's that you have there? an indigested stalagmite", "take it back to her in san d'oria" }) then
        return apply('postki_sandy', function()
            set_phase_internal('sandy', 'field_agent_confirmed')
            push_message("San d'Oria ready. Return to Norejaie.")
        end)
    end
    if contains(text, 'obtained key item: indigested meat') then
        return apply('ki_windy', function()
            set_phase_internal('windy', 'key_item_obtained')
            push_message('Windurst KI obtained. Return to Ahko Mhalijikhari.')
        end)
    end
    if contains(text, 'obtained key item: indigested ore') then
        return apply('ki_bastok', function()
            set_phase_internal('bastok', 'key_item_obtained')
            push_message('Bastok KI obtained. Return to Degga.')
        end)
    end
    if contains(text, 'obtained key item: indigested stalagmite') then
        return apply('ki_sandy', function()
            set_phase_internal('sandy', 'key_item_obtained')
            push_message("San d'Oria KI obtained. Return to Rojaireaut.")
        end)
    end
    if contains(text, "now, close your eyes for a moment. this won't hurt a bit") then
        return apply('nmready_sandy', function()
            set_phase_internal('sandy', 'nm_ready')
            push_message("San d'Oria NM ready.")
        end)
    end
    if contains_all(text, { 'rrright, here we go', 'close your eyes' }) then
        return apply('nmready_windy', function()
            set_phase_internal('windy', 'nm_ready')
            push_message('Windurst NM ready.')
        end)
    end
    if contains(text, 'now, just close your eyes for a moment') then
        local eco = (state.activeEco == 'windy') and 'windy' or 'bastok'
        return apply('nmready_' .. eco, function()
            set_phase_internal(eco, 'nm_ready')
            push_message(eco_label(eco) .. ' NM ready.')
        end)
    end
    if contains_all(text, { "you're here for the v.e.r.m.i.n. extermination operation", 'we want you to find and defeat the fiend' }) then
        return apply('fieldstart_sandy', function()
            set_phase_internal('sandy', 'field_agent_started')
            push_message("San d'Oria field step started.")
        end)
    end
    if contains_all(text, { "here's what we want you to do", 'defeat the creatures that are infesting the scrap materials' }) then
        return apply('fieldstart_bastok', function()
            set_phase_internal('bastok', 'field_agent_started')
            push_message('Bastok field step started.')
        end)
    end
    if contains_all(text, { "ah, you're here at last", 'v.e.r.m.i.n. assignment' })
            or contains_all(text, { "find and defeat the creatures that've been rrrunning amok", 'proof of their demise to lumomo' }) then
        return apply('fieldstart_windy', function()
            set_phase_internal('windy', 'field_agent_started')
            push_message('Windurst field step started.')
        end)
    end
    if contains_all(text, { "i knew you'd come through for us", 'rojaireaut, our v.e.r.m.i.n. agent in the field' }) then
        return apply('accepted_sandy', function()
            set_phase_internal('sandy', 'accepted')
            push_message("San d'Oria accepted. Next: Rojaireaut.")
        end)
    end
    if contains_all(text, { 'excellentaru! bring me back proof', 'trouncy-wounced the beasties' }) then
        return apply('accepted_windy', function()
            set_phase_internal('windy', 'accepted')
            push_message('Windurst accepted. Next: Ahko Mhalijikhari.')
        end)
    end
    if contains_all(text, { 'i knew you would help', 'degga, one of our v.e.r.m.i.n. field agents' }) then
        return apply('accepted_bastok', function()
            set_phase_internal('bastok', 'accepted')
            push_message('Bastok accepted. Next: Degga.')
        end)
    end
    if contains(text, 'you can get more details on the assignment from ahko mhalijikhari') then
        return apply('alreadyactive_windy', function()
            set_phase_internal('windy', 'accepted')
            push_message('Windurst already active.')
        end)
    end
    if contains_all(text, { 'hey, mister adventurer', 'you already look kinda busy-wusy' }) then
        return apply('blocked_windy', function()
            set_phase_internal('windy', 'blocked')
            push_message('Windurst unavailable right now.')
        end)
    end
    if process_eeko(text) then return true end
    return false
end

function ecowar.on_text(line)
    if not state then return end
    local norm = normalize_text(line)
    if norm == '' then return end
    local combined = buffer_add(norm)
    if process_triggers(combined) then buffer_clear() end
end

function ecowar.set_active(eco)
    if not state then return false, 'state not loaded' end
    eco = (eco or 'none'):lower()
    if eco ~= 'none' and ECO_LABELS[eco] == nil then return false, 'invalid eco' end
    state.activeEco = eco
    if eco == 'none' then
        state.phase = 'none'
    elseif state.phase == 'none' or state.phase == 'completed' then
        state.phase = 'accepted'
    end
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.set_phase(phase)
    if not state then return false, 'state not loaded' end
    phase = (phase or 'none'):lower()
    if PHASES[phase] ~= true then return false, 'invalid phase' end
    state.phase = phase
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.mark_done(eco)
    if not state then return false, 'state not loaded' end
    eco = (eco or ''):lower()
    if ECO_LABELS[eco] == nil then return false, 'invalid eco' end
    if ecowar.is_cycle_complete() then state.cycleCompleted = {} end
    state.cycleCompleted[eco] = true
    state.currentWeekCompleted = eco
    state.activeEco = 'none'
    state.phase = 'completed'
    state.hasKeyItem = false
    state.fieldAgentConfirmed = false
    state.lastRewardTimestampJst = os.time() + 9 * 3600
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.undo(eco)
    if not state then return false, 'state not loaded' end
    eco = (eco or ''):lower()
    if ECO_LABELS[eco] == nil then return false, 'invalid eco' end
    state.cycleCompleted[eco] = nil
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.reset_week()
    if not state then return false, 'state not loaded' end
    state.currentWeekCompleted = 'none'
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.reset_cycle()
    if not state then return false, 'state not loaded' end
    state.cycleCompleted = {}
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.reset_all()
    if not state then return false, 'state not loaded' end
    state = default_state()
    state.lastKnownWeekId = jst_week_id()
    state.confidence = 'manual_override'
    save()
    return true
end

function ecowar.init(pname, base_dir)
    if not pname or pname == '' then
        state = nil
        state_file = nil
        player_name = nil
        text_buffer = {}
        debounce_map = {}
        return
    end
    if player_name == pname and state ~= nil then
        roll_week_if_needed()
        return
    end
    -- New character or first load.
    if state and state_file then save() end
    player_name = pname
    local weekly_dir = base_dir .. 'weekly\\'
    if not fs.exists(weekly_dir) then fs.create_dir(weekly_dir) end
    state_file = weekly_dir .. 'ecowar.lua'
    state = normalize_loaded(load_table(state_file))
    text_buffer = {}
    debounce_map = {}
    roll_week_if_needed()
    save()
end

function ecowar.tick()
    if not state then return end
    roll_week_if_needed()
end

function ecowar.save() save() end

return ecowar
