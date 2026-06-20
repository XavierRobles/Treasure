---------------------------------------------------------------------------
-- Treasure · weekly/quests.lua
-- Weekly mission/quest/ENM tracker (HorizonXI).
-- Per-character; resets at JST Mon 00:00 (= Sun 23:59 JST end).
---------------------------------------------------------------------------

local fs = ashita.fs

local quests = {
    id = 'quests',
    title = 'Quests',
}

local SERVER_NAME = 'HorizonXI'
local MAX_MESSAGES = 6
local MAX_BUFFER = 12
local DEBOUNCE_SECONDS = 3
local HANDIN_WINDOW = 20
local DAY_SECONDS = 86400

-- Quest catalog. Add new entries here and the router/UI pick them up.
--
-- Trigger fields are lowercased substrings matched against a normalized chat
-- buffer (see normalize_text). `instant_complete = true` finalizes on handin
-- without waiting for a fixed Obtained line (used for random-reward quests).
-- `flow` separates access-permit, collect-and-deliver KI, and KI cooldown content.
local CATALOG = {
    {
        id = 'spice_gals',
        label = 'Spice Gals',
        flow = 'ki_delivery',
        npc = 'Rouva',
        zone_hint = "Southern San d'Oria",
        zone_started = 'Riverne - Site #B01',
        zone_has_key_item = "Southern San d'Oria",
        start_phrases = {
            'thanks to your unselfish act of kindness',
            'collect another sprig of rivernewort',
            'if, by some wonderful miracle, you find yourself in possession of a sprig of rivernewort',
            'prepare lady femitte some authentic tavnazian dishes once again',
        },
        ki_phrases = { 'obtained key item: rivernewort' },
        handin_phrases = {
            'why, this is rivernewort',
            'garnish my dishes with this succulent spice',
        },
        success_phrases = { "obtained: page from miratete's memoirs" },
        block_phrases = { 'come back after sorting your inventory', 'cannot obtain the page' },
        achievement_phrase = "achievement unlocked: complete 'spice gals'",
        instant_complete = false,
        next_available = 'Talk to Rouva to start.',
        next_started = 'Obtain key item: Rivernewort.',
        next_has_key_item = 'Return to Rouva and deliver Rivernewort.',
        next_blocked = 'Free inventory, then talk to Rouva again.',
    },
    {
        id = 'uninvited_guests',
        label = 'Uninvited Guests',
        flow = 'access_permit',
        npc = 'Justinius',
        zone_hint = 'Tavnazian Safehold',
        zone_has_key_item = 'Monarch Linn',
        start_phrases = {
            'do you remember those black-robed intruders',
            'excellent. take this and make your way to monarch linn',
        },
        ki_phrases = { 'obtained key item: monarch linn patrol permit' },
        handin_phrases = {
            'so, you have routed those black-robed menaces from monarch linn',
            'your reward--for a job well done',
            'you deserve something for putting your neck on the line',
        },
        success_phrases = {},
        block_phrases = { 'come back after sorting your inventory' },
        achievement_phrase = "achievement unlocked: complete 'uninvited guests'",
        instant_complete = true,
        next_available = 'Talk to Justinius to accept.',
        next_started = 'Get Monarch Linn Patrol Permit from Justinius.',
        next_has_key_item = 'Use the permit at Monarch Linn and route the intruders.',
        next_blocked = 'Free inventory, then talk to Justinius again.',
        has_key_item_label = 'Ready to fight',
    },
    {
        id = 'secrets_of_ovens_lost',
        label = 'Secrets of Ovens Lost',
        flow = 'ki_delivery',
        npc = 'Jonette',
        zone_hint = 'Tavnazian Safehold',
        zone_started = 'Sacrarium / Phomiuna Aqueducts',
        zone_has_key_item = 'Tavnazian Safehold',
        start_phrases = {
            'the information you have brought me on tavnazian cuisine',
            'if you happen to find any more, the children would be so delighted',
        },
        ki_phrases = { 'obtained key item: tavnazian cookbook' },
        handin_phrases = {
            'a tavnazian cookbook!',
            'this is exactly the information i have been searching for',
        },
        success_phrases = { "obtained: page from miratete's memoirs" },
        block_phrases = {
            'come back after sorting your inventory',
            'cannot obtain the page from miratete',
        },
        achievement_phrase = "achievement unlocked: complete 'secrets of ovens lost'",
        instant_complete = false,
        next_available = 'Talk to Jonette to start.',
        next_started = 'Find Tavnazian cookbook in Sacrarium or Phomiuna Aqueducts.',
        next_has_key_item = 'Return to Jonette and deliver the cookbook.',
        next_blocked = 'Free inventory, then talk to Jonette again.',
    },
    {
        id = 'monarch_linn_enm',
        label = 'Monarch Linn ENM',
        flow = 'ki_cooldown',
        npc = 'Morangeart',
        zone_hint = 'Tavnazian Safehold G-10',
        zone_cooldown = 'Monarch Linn',
        zone_has_key_item_available = 'Monarch Linn / Tavnazian Safehold',
        start_phrases = {},
        ki_phrases = { 'obtained key item: monarch beard' },
        lost_ki_phrases = { 'lost key item: monarch beard' },
        handin_phrases = {},
        success_phrases = {},
        block_phrases = {},
        achievement_phrase = nil,
        instant_complete = false,
        cooldown_days = 5,
        next_available = 'Talk to Morangeart and obtain Monarch Beard.',
        next_cooldown = 'Use at Monarch Linn.',
        next_cooldown_no_ki = 'Wait, then talk to Morangeart.',
        next_has_key_item_available = 'Use held beard or pick another after spending it.',
        cooldown_label = 'Has KI',
        ready_with_ki_label = 'Has KI +1',
    },
}

local CATALOG_BY_ID = {}
local CATALOG_ORDER = {}
for _, q in ipairs(CATALOG) do
    CATALOG_BY_ID[q.id] = q
    CATALOG_ORDER[#CATALOG_ORDER + 1] = q.id
end

local STATES = {
    available = true,
    started = true,
    has_key_item = true,
    has_key_item_available = true,
    cooldown_no_ki = true,
    cooldown = true,
    reward_blocked_inventory = true,
    completed_this_week = true,
}

-- Promotion ranks. Higher numbers cannot be replaced by lower except via
-- explicit overrides (mark done, undo, reset). This keeps a flapping chat
-- buffer from demoting "completed_this_week" back to "started" mid-frame.
local STATE_RANK = {
    available = 0,
    started = 1,
    has_key_item = 2,
    has_key_item_available = 3,
    cooldown_no_ki = 3,
    reward_blocked_inventory = 3,
    cooldown = 4,
    completed_this_week = 4,
}

local STATE_LABEL = {
    available = 'Available',
    started = 'Started',
    has_key_item = 'Has KI',
    has_key_item_available = 'Has KI + Ready',
    cooldown_no_ki = 'Cooldown',
    cooldown = 'Cooldown',
    reward_blocked_inventory = 'Inventory full',
    completed_this_week = 'Done',
}

local state = nil
local state_file = nil
local player_name = nil
local text_buffer = {}
local debounce_map = {}
local ui_messages = {}
local pending_handin = {}

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

local function default_quest_state()
    return {
        state = 'available',
        completed_this_week = false,
        last_completed = nil,
        obtained_at = nil,
        available_at = nil,
    }
end

local function default_state()
    local q = {}
    for _, def in ipairs(CATALOG) do
        q[def.id] = default_quest_state()
    end
    return {
        version = 1,
        server = SERVER_NAME,
        character = player_name or 'Unknown',
        lastKnownWeekId = nil,
        quests = q,
        confidence = 'auto',
    }
end

local function normalize_loaded(loaded)
    local def = default_state()
    if type(loaded) ~= 'table' then return def end
    for k, v in pairs(def) do
        if loaded[k] == nil then loaded[k] = v end
    end
    if type(loaded.quests) ~= 'table' then loaded.quests = {} end
    -- Backfill any new catalog entries onto loaded state.
    for _, qdef in ipairs(CATALOG) do
        local q = loaded.quests[qdef.id]
        if type(q) ~= 'table' then
            loaded.quests[qdef.id] = default_quest_state()
        else
            if STATES[q.state] ~= true then q.state = 'available' end
            if q.completed_this_week == nil then q.completed_this_week = false end
            if q.obtained_at == nil then q.obtained_at = nil end
            if q.available_at == nil then q.available_at = nil end
        end
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
    return math.floor((days - 4) / 7)
end

local function next_reset_timestamp(timestamp)
    timestamp = timestamp or os.time()
    local week = jst_week_id(timestamp)
    local next_monday_day = ((week + 1) * 7) + 4
    return (next_monday_day * 86400) - (9 * 3600)
end

function quests.format_jst(ts)
    local jst = os.date('!*t', (ts or os.time()) + 9 * 3600)
    return ('%04d-%02d-%02d %02d:%02d JST'):format(jst.year, jst.month, jst.day, jst.hour, jst.min)
end

function quests.format_local(ts)
    local lt = os.date('*t', ts or os.time())
    return ('%04d-%02d-%02d %02d:%02d'):format(lt.year, lt.month, lt.day, lt.hour, lt.min)
end

function quests.format_remaining(ts)
    local rem = math.max(0, (ts or os.time()) - os.time())
    local d = math.floor(rem / DAY_SECONDS)
    local h = math.floor((rem - d * DAY_SECONDS) / 3600)
    local m = math.floor((rem - d * DAY_SECONDS - h * 3600) / 60)
    if d > 0 then
        return ('%dd %02dh %02dm'):format(d, h, m)
    end
    return ('%02dh %02dm'):format(h, m)
end

function quests.next_reset_timestamp(ts)
    return next_reset_timestamp(ts)
end

local function push_message(text)
    ui_messages[#ui_messages + 1] = { time = os.time(), text = tostring(text or '') }
    while #ui_messages > MAX_MESSAGES do
        table.remove(ui_messages, 1)
    end
end

function quests.push_message(t) push_message(t) end
function quests.get_messages() return ui_messages end
function quests.clear_messages() ui_messages = {} end

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
        for _, qdef in ipairs(CATALOG) do
            local q = state.quests[qdef.id] or default_quest_state()
            if qdef.flow ~= 'ki_cooldown' then
                q.completed_this_week = false
                q.state = 'available'
                q.last_completed = nil
                q.obtained_at = nil
                q.available_at = nil
            end
            state.quests[qdef.id] = q
        end
        pending_handin = {}
        save()
        push_message('Weekly quests lock reset.')
    end
end

function quests.get_state() return state end
function quests.catalog() return CATALOG end
function quests.state_label(s) return STATE_LABEL[s] or tostring(s or '?') end

function quests.quest_state_label(qdef, s, q)
    if type(qdef) == 'table' and s == 'cooldown' and qdef.cooldown_label then
        return qdef.cooldown_label
    end
    if type(qdef) == 'table' and s == 'cooldown_no_ki' then
        if type(q) == 'table' and q.available_at then
            return quests.format_remaining(q.available_at)
        end
        return qdef.cooldown_no_ki_label or quests.state_label(s)
    end
    if type(qdef) == 'table' and s == 'has_key_item_available' and qdef.ready_with_ki_label then
        return qdef.ready_with_ki_label
    end
    if type(qdef) == 'table' and s == 'has_key_item' and qdef.has_key_item_label then
        return qdef.has_key_item_label
    end
    return quests.state_label(s)
end

function quests.get_quest_zone_hint(quest_id)
    local qdef = CATALOG_BY_ID[quest_id]
    local q = quests.get_quest_state(quest_id)
    if not qdef or not q then return '' end
    if q.state == 'cooldown' or q.state == 'cooldown_no_ki' then return qdef.zone_cooldown or qdef.zone_hint or '' end
    if q.state == 'has_key_item_available' then return qdef.zone_has_key_item_available or qdef.zone_cooldown or qdef.zone_hint or '' end
    if q.state == 'has_key_item' then return qdef.zone_has_key_item or qdef.zone_hint or '' end
    if q.state == 'started' then return qdef.zone_started or qdef.zone_hint or '' end
    return qdef.zone_hint or ''
end

function quests.get_quest_next_step(quest_id)
    local qdef = CATALOG_BY_ID[quest_id]
    local q = quests.get_quest_state(quest_id)
    if not qdef or not q then return '' end
    if q.state == 'cooldown' then
        if q.available_at then
            return ('Next beard: %s. Available: %s local (%s). %s'):format(
                    quests.format_remaining(q.available_at),
                    quests.format_local(q.available_at),
                    quests.format_jst(q.available_at),
                    qdef.next_cooldown or 'On cooldown.')
        end
        return qdef.next_cooldown or 'On cooldown.'
    end
    if q.state == 'cooldown_no_ki' then
        if q.available_at then
            return ('Next beard: %s. Available: %s local (%s). %s'):format(
                    quests.format_remaining(q.available_at),
                    quests.format_local(q.available_at),
                    quests.format_jst(q.available_at),
                    qdef.next_cooldown_no_ki or 'On cooldown.')
        end
        return qdef.next_cooldown_no_ki or 'On cooldown.'
    end
    if q.state == 'has_key_item_available' then
        return qdef.next_has_key_item_available or 'Has KI and cooldown is ready.'
    end
    if q.state == 'completed_this_week' then
        local reset_at = next_reset_timestamp()
        return ('Done. Reset: %s. Available: %s local (%s).'):format(
                quests.format_remaining(reset_at),
                quests.format_local(reset_at),
                quests.format_jst(reset_at))
    end
    if q.state == 'reward_blocked_inventory' then return qdef.next_blocked or 'Free inventory, then claim the reward again.' end
    if q.state == 'has_key_item' then return qdef.next_has_key_item or 'Return to the NPC and complete the quest.' end
    if q.state == 'started' then return qdef.next_started or 'Continue the quest objective.' end
    return qdef.next_available or 'Talk to the NPC to start.'
end

function quests.get_quest_state(quest_id)
    if not state then return nil end
    return state.quests[quest_id]
end

function quests.get_summary()
    if not state then return '' end
    local done, active, total = 0, 0, #CATALOG
    for _, qdef in ipairs(CATALOG) do
        local q = state.quests[qdef.id]
        if q then
            if q.completed_this_week then
                done = done + 1
            elseif q.state ~= 'available' then
                active = active + 1
            end
        end
    end
    return ('Quests/ENM: %d/%d done | %d active'):format(done, total, active)
end

local function normalize_text(s)
    s = tostring(s or '')
    s = s:gsub('%[%d%d:%d%d:%d%d%]', ' ')
    s = s:gsub('%c', ' ')
    s = s:gsub('%s+', ' ')
    return s:lower()
end

local function contains(text, needle) return text:find(needle, 1, true) ~= nil end

local function any_match(text, list)
    if type(list) ~= 'table' then return false end
    for _, n in ipairs(list) do
        if contains(text, n) then return true end
    end
    return false
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

local function promote(quest_id, target_state, reason)
    local q = state.quests[quest_id]
    if not q then return false end
    local cur_rank = STATE_RANK[q.state] or 0
    local new_rank = STATE_RANK[target_state] or 0
    -- completed_this_week is terminal until reset.
    if q.state == 'completed_this_week' then return false end
    if new_rank <= cur_rank then return false end
    q.state = target_state
    if target_state == 'completed_this_week' then
        q.completed_this_week = true
        q.last_completed = os.time()
    end
    state.confidence = 'auto'
    save()
    if reason then push_message(reason) end
    return true
end

local function finalize_completion(quest_id, qdef)
    pending_handin[quest_id] = nil
    promote(quest_id, 'completed_this_week',
        ('%s complete. Locked until reset.'):format(qdef.label))
end

local function finalize_block(quest_id, qdef)
    pending_handin[quest_id] = nil
    local q = state.quests[quest_id]
    if not q or q.state == 'completed_this_week' then return end
    -- Only set blocked if we're not already past it; allow downgrade from
    -- has_key_item to blocked since "blocked" carries useful info for the UI.
    q.state = 'reward_blocked_inventory'
    state.confidence = 'auto'
    save()
    push_message(('%s reward blocked (inventory full).'):format(qdef.label))
end

local function set_cooldown(quest_id, qdef)
    local q = state.quests[quest_id]
    if not q then return false end
    local now = os.time()
    local days = tonumber(qdef.cooldown_days or 0) or 0
    q.state = 'cooldown'
    q.completed_this_week = false
    q.last_completed = nil
    q.obtained_at = now
    q.available_at = now + (days * DAY_SECONDS)
    state.confidence = 'auto'
    save()
    push_message(('%s cooldown started. Available after %s local.'):format(
            qdef.label,
            quests.format_local(q.available_at)))
    return true
end

local function refresh_cooldowns()
    local changed = false
    local now = os.time()
    for _, qdef in ipairs(CATALOG) do
        if qdef.flow == 'ki_cooldown' then
            local q = state.quests[qdef.id]
            if q and q.state == 'cooldown' and q.available_at and now >= q.available_at then
                q.state = 'has_key_item_available'
                changed = true
                push_message(('%s cooldown ended. KI may still be held; next obtain will restart the 5-day timer.'):format(qdef.label))
            elseif q and q.state == 'cooldown_no_ki' and q.available_at and now >= q.available_at then
                q.state = 'available'
                q.obtained_at = nil
                q.available_at = nil
                changed = true
                push_message(('%s is available again.'):format(qdef.label))
            end
        end
    end
    if changed then
        state.confidence = 'auto'
        save()
    end
end

local function process_quest(text, qdef)
    local id = qdef.id
    local q = state.quests[id]
    if not q then return false end
    if q.state == 'completed_this_week' then return false end

    if qdef.flow == 'ki_cooldown' then
        if any_match(text, qdef.lost_ki_phrases) and not debounced('lostki_' .. id) then
            if q.state == 'cooldown' or q.state == 'has_key_item_available' then
                q.state = (q.available_at and os.time() < q.available_at) and 'cooldown_no_ki' or 'available'
                if q.state == 'available' then
                    q.obtained_at = nil
                    q.available_at = nil
                end
                state.confidence = 'auto'
                save()
                push_message(('%s key item spent.'):format(qdef.label))
                return true
            end
        end
        if any_match(text, qdef.ki_phrases) and not debounced('ki_' .. id) then
            return set_cooldown(id, qdef)
        end
        return false
    end

    if #qdef.start_phrases > 0 and any_match(text, qdef.start_phrases) then
        if not debounced('start_' .. id) then
            promote(id, 'started', ('%s started.'):format(qdef.label))
        end
    end

    if any_match(text, qdef.ki_phrases) then
        if not debounced('ki_' .. id) then
            promote(id, 'has_key_item', ('%s key item obtained.'):format(qdef.label))
        end
    end

    if any_match(text, qdef.handin_phrases) then
        if not debounced('handin_' .. id) then
            pending_handin[id] = os.time()
            if qdef.instant_complete then
                -- Random-reward quests finalize on handin unless a block message
                -- shows up in the same buffer window (covered below).
                if not any_match(text, qdef.block_phrases) then
                    finalize_completion(id, qdef)
                end
            end
        end
    end

    if pending_handin[id] then
        if any_match(text, qdef.block_phrases) then
            finalize_block(id, qdef)
            return true
        end
        if #qdef.success_phrases > 0 and any_match(text, qdef.success_phrases) then
            finalize_completion(id, qdef)
            return true
        end
        if qdef.achievement_phrase and contains(text, qdef.achievement_phrase) then
            finalize_completion(id, qdef)
            return true
        end
    end
    return false
end

function quests.on_text(line)
    if not state then return end
    local norm = normalize_text(line)
    if norm == '' then return end
    local combined = buffer_add(norm)
    local matched_any = false
    for _, qdef in ipairs(CATALOG) do
        if process_quest(combined, qdef) then matched_any = true end
    end
    if matched_any then buffer_clear() end
end

function quests.tick()
    if not state then return end
    roll_week_if_needed()
    refresh_cooldowns()
    local now = os.time()
    for id, ts in pairs(pending_handin) do
        if (now - ts) > HANDIN_WINDOW then
            pending_handin[id] = nil
        end
    end
end

function quests.save() save() end

--[[ manual overrides ]]--

function quests.set_quest_state(quest_id, new_state)
    if not state then return false, 'state not loaded' end
    local qdef = CATALOG_BY_ID[quest_id]
    if not qdef then return false, 'unknown quest' end
    if STATES[new_state] ~= true then return false, 'invalid state' end
    local q = state.quests[quest_id]
    if new_state == 'cooldown' and qdef.flow == 'ki_cooldown' then
        set_cooldown(quest_id, qdef)
        state.confidence = 'manual_override'
        save()
        return true
    end
    q.state = new_state
    if new_state == 'completed_this_week' then
        q.completed_this_week = true
        q.last_completed = os.time()
    elseif new_state == 'available' then
        q.completed_this_week = false
        q.last_completed = nil
        q.obtained_at = nil
        q.available_at = nil
    end
    state.confidence = 'manual_override'
    save()
    return true
end

function quests.mark_done(quest_id)
    local qdef = CATALOG_BY_ID[quest_id]
    if qdef and qdef.flow == 'ki_cooldown' then
        return quests.set_quest_state(quest_id, 'cooldown')
    end
    return quests.set_quest_state(quest_id, 'completed_this_week')
end

function quests.undo(quest_id)
    return quests.set_quest_state(quest_id, 'available')
end

function quests.reset_week()
    if not state then return false, 'state not loaded' end
    for _, qdef in ipairs(CATALOG) do
        local q = state.quests[qdef.id]
        if qdef.flow ~= 'ki_cooldown' then
            q.completed_this_week = false
            q.state = 'available'
            q.last_completed = nil
            q.obtained_at = nil
            q.available_at = nil
        end
    end
    pending_handin = {}
    state.confidence = 'manual_override'
    save()
    return true
end

function quests.reset_all()
    if not state then return false, 'state not loaded' end
    state = default_state()
    state.lastKnownWeekId = jst_week_id()
    state.confidence = 'manual_override'
    pending_handin = {}
    save()
    return true
end

function quests.init(pname, base_dir)
    if not pname or pname == '' then
        state = nil
        state_file = nil
        player_name = nil
        text_buffer = {}
        debounce_map = {}
        pending_handin = {}
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
    state_file = weekly_dir .. 'quests.lua'
    state = normalize_loaded(load_table(state_file))
    text_buffer = {}
    debounce_map = {}
    pending_handin = {}
    roll_week_if_needed()
    refresh_cooldowns()
    save()
end

return quests
