---------------------------------------------------------------------------
-- Treasure · event_limbus.lua · Waky
---------------------------------------------------------------------------

local parser = require('parser')
local core = require('core')
local store = require('store')

local limbus = {
    id = 'limbus',
    title = 'Limbus',
}

local TRANSITION_CONFIRM_SECONDS = 6
local GUNPOD_SCAN_INTERVAL = 0.30
local GUNPOD_MAX_SPAWNS = 5
local GUNPOD_CROSS_SOURCE_DEDUPE_SECONDS = 12.0
local GUNPOD_MESSAGE_DEDUPE_SECONDS = 8
local GUNPOD_MESSAGE_PRIORITY_SECONDS = 15
local ENTITY_MAX_INDEX = 2303
local SW_ELEMENTAL_SCAN_INTERVAL = 0.40

local VANA_DAY_KEYS = {
    'fire',
    'earth',
    'water',
    'wind',
    'ice',
    'thunder',
    'light',
    'dark',
}
local VANA_DAY_LABELS = {
    'Firesday',
    'Earthsday',
    'Watersday',
    'Windsday',
    'Iceday',
    'Lightningsday',
    'Lightsday',
    'Darksday',
}

local VANA_TIME_PTR_SIG = 0
local VANA_TIME_SIG_SCANNED = false

local LIMBUS_ZONES = {
    [37] = true, -- Temenos
    [38] = true, -- Apollyon
}

local APOLLYON_PROFILES = {
    apollyon_west = {
        id = 'apollyon_west',
        label = 'Apollyon West',
        max_floor = 5,
        reward_chip = 'Magenta Chip',
        reward_chip_key = 'magenta',
        central = false,
    },
    apollyon_east = {
        id = 'apollyon_east',
        label = 'Apollyon East',
        max_floor = 5,
        reward_chip = 'Smoky Chip',
        reward_chip_key = 'smoky',
        central = false,
    },
    apollyon_south_west = {
        id = 'apollyon_south_west',
        label = 'Apollyon South West',
        max_floor = 4,
        reward_chip = 'Charcoal Chip',
        reward_chip_key = 'charcoal',
        central = false,
    },
    apollyon_south_east = {
        id = 'apollyon_south_east',
        label = 'Apollyon South East',
        max_floor = 4,
        reward_chip = 'Smalt Chip',
        reward_chip_key = 'smalt',
        central = false,
    },
    apollyon_central = {
        id = 'apollyon_central',
        label = 'Central Apollyon',
        max_floor = 1,
        reward_chip = nil,
        reward_chip_key = nil,
        central = true,
        central_kind = 'apollyon',
    },
}

local TEMENOS_PROFILES = {
    temenos_west = {
        id = 'temenos_west',
        label = 'Temenos West',
        max_floor = 7,
        reward_chip = 'Emerald Chip',
        reward_chip_key = 'emerald',
        central = false,
    },
    temenos_east = {
        id = 'temenos_east',
        label = 'Temenos East',
        max_floor = 7,
        reward_chip = 'Scarlet Chip',
        reward_chip_key = 'scarlet',
        central = false,
    },
    temenos_north = {
        id = 'temenos_north',
        label = 'Temenos North',
        max_floor = 7,
        reward_chip = 'Ivory Chip',
        reward_chip_key = 'ivory',
        central = false,
    },
    temenos_central_1 = {
        id = 'temenos_central_1',
        label = 'Central Temenos - 1st Floor',
        max_floor = 1,
        reward_chip = 'Orchid Chip',
        reward_chip_key = 'orchid',
        central = true,
        central_kind = 'temenos',
    },
    temenos_central_2 = {
        id = 'temenos_central_2',
        label = 'Central Temenos - 2nd Floor',
        max_floor = 1,
        reward_chip = 'Cerulean Chip',
        reward_chip_key = 'cerulean',
        central = true,
        central_kind = 'temenos',
    },
    temenos_central_3 = {
        id = 'temenos_central_3',
        label = 'Central Temenos - 3rd Floor',
        max_floor = 1,
        reward_chip = 'Silver Chip',
        reward_chip_key = 'silver',
        central = true,
        central_kind = 'temenos',
    },
    temenos_central_4 = {
        id = 'temenos_central_4',
        label = 'Central Temenos - 4th Floor',
        max_floor = 1,
        reward_chip = nil,
        reward_chip_key = nil,
        central = true,
        central_kind = 'temenos',
    },
}

local LIMBUS_PROFILE_BY_ID = {}
do
    for _, p in pairs(APOLLYON_PROFILES) do
        if p and p.id then
            LIMBUS_PROFILE_BY_ID[tostring(p.id)] = p
        end
    end
    for _, p in pairs(TEMENOS_PROFILES) do
        if p and p.id then
            LIMBUS_PROFILE_BY_ID[tostring(p.id)] = p
        end
    end
end

local function current_limbus_time_left_seconds(sess)
    if not (sess and sess.limbus_timer) then
        return nil
    end
    local now = os.time()
    local end_at = tonumber(sess.limbus_timer.end_at)
    local fallback_end = tonumber(sess.limbus_timer.fallback_end_at)
    local target = end_at or fallback_end
    if not target then
        return nil
    end
    return math.max(0, target - now)
end

local function ensure_floor_stats(sess)
    if not sess then
        return
    end
    if type(sess.limbus_floor_stats) ~= 'table' then
        sess.limbus_floor_stats = {}
    end
    local f = math.max(1, tonumber(sess.limbus_floor) or 1)
    local fs = sess.limbus_floor_stats[f]
    if type(fs) ~= 'table' then
        fs = {
            floor = f,
            enter_at = nil,
            leave_at = nil,
            gate_opens = 0,
            transitions = 0,
            first_time_left = nil,
            last_time_left = nil,
        }
        sess.limbus_floor_stats[f] = fs
    else
        fs.floor = f
        fs.enter_at = tonumber(fs.enter_at) or nil
        fs.leave_at = tonumber(fs.leave_at) or nil
        fs.gate_opens = math.max(0, tonumber(fs.gate_opens) or 0)
        fs.transitions = math.max(0, tonumber(fs.transitions) or 0)
        fs.first_time_left = tonumber(fs.first_time_left) or nil
        fs.last_time_left = tonumber(fs.last_time_left) or nil
    end
end

local function mark_floor_enter(sess, floor_num, now_ts)
    if not sess then
        return
    end
    now_ts = tonumber(now_ts) or os.time()
    local f = math.max(1, tonumber(floor_num) or math.max(1, tonumber(sess.limbus_floor) or 1))
    sess.limbus_floor = f
    ensure_floor_stats(sess)
    local fs = sess.limbus_floor_stats[f]
    if type(fs) ~= 'table' then
        return
    end
    if not fs.enter_at then
        fs.enter_at = now_ts
        local rem = current_limbus_time_left_seconds(sess)
        if rem then
            fs.first_time_left = rem
            fs.last_time_left = rem
        end
    end
end

local function mark_floor_leave(sess, floor_num, now_ts)
    if not sess then
        return
    end
    now_ts = tonumber(now_ts) or os.time()
    local f = math.max(1, tonumber(floor_num) or math.max(1, tonumber(sess.limbus_floor) or 1))
    ensure_floor_stats(sess)
    local fs = sess.limbus_floor_stats[f]
    if type(fs) ~= 'table' then
        return
    end
    -- Preserve the first floor-exit timestamp to avoid inflating floor duration
    -- after run end (pool cleanup / zone-out can trigger additional leave paths).
    local prev_leave = tonumber(fs.leave_at)
    if not prev_leave or prev_leave <= 0 then
        fs.leave_at = now_ts
    else
        fs.leave_at = math.min(prev_leave, now_ts)
    end
    local rem = current_limbus_time_left_seconds(sess)
    if rem then
        fs.last_time_left = rem
    end
end

local function clean_name(name)
    return tostring(name or '')
            :gsub('%z', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
end

local function normalize_plain(s)
    s = tostring(s or ''):lower()
    s = s:gsub('%z', '')
    s = s:gsub('[%[%]%(%)%.,!:%-_/\\]', ' ')
    s = s:gsub('%s+', ' ')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s
end

local function token_find(padded, token)
    if padded == nil or token == nil or token == '' then
        return false
    end
    return padded:find(' ' .. token .. ' ', 1, true) ~= nil
end

local function clear_sw_day_element(sess)
    if not sess then
        return
    end
    sess.limbus_sw_day_element = nil
    sess.limbus_sw_day_element_locked = false
    sess.limbus_sw_day_element_count = 0
    sess.limbus_sw_day_element_floor = nil
    sess.limbus_sw_day_element_detected_at = nil
    sess.limbus_sw_day_element_last_scan = 0
    sess.limbus_sw_day_element_not_before = nil
    sess.limbus_sw_day_element_candidate = nil
    sess.limbus_sw_day_element_candidate_hits = 0
end

local function detect_element_key_from_name(name)
    local s = normalize_plain(name)
    if s == '' then
        return nil
    end
    if s:find('elemental', 1, true) == nil then
        return nil
    end
    local p = ' ' .. s .. ' '
    if token_find(p, 'fire') then
        return 'fire'
    end
    if token_find(p, 'ice') then
        return 'ice'
    end
    if token_find(p, 'wind') then
        return 'wind'
    end
    if token_find(p, 'earth') then
        return 'earth'
    end
    if token_find(p, 'thunder') or token_find(p, 'lightning') then
        return 'thunder'
    end
    if token_find(p, 'water') then
        return 'water'
    end
    if token_find(p, 'light') then
        return 'light'
    end
    if token_find(p, 'dark') then
        return 'dark'
    end
    return nil
end

local function read_vana_day_from_memory()
    if not (ashita and ashita.memory) then
        return nil, nil, 'ashita.memory unavailable'
    end

    if not VANA_TIME_SIG_SCANNED then
        VANA_TIME_SIG_SCANNED = true
        local ok_find, sig = pcall(ashita.memory.find, 'FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0x34, 0)
        if ok_find then
            VANA_TIME_PTR_SIG = tonumber(sig) or 0
        else
            VANA_TIME_PTR_SIG = 0
        end
    end
    if not VANA_TIME_PTR_SIG or VANA_TIME_PTR_SIG == 0 then
        return nil, nil, 'vana pointer signature not found'
    end

    local ok_base, base_ptr = pcall(ashita.memory.read_uint32, VANA_TIME_PTR_SIG)
    if not ok_base or not base_ptr or base_ptr == 0 then
        return nil, nil, 'vana base pointer invalid'
    end

    local ok_raw, raw = pcall(ashita.memory.read_uint32, base_ptr + 0x0C)
    if not ok_raw or raw == nil then
        return nil, nil, 'vana raw time unavailable'
    end

    local ts = (tonumber(raw) + 92514960) * 25
    local day_idx = math.floor(ts / 86400) % 8
    if day_idx < 0 then
        day_idx = day_idx + 8
    end

    local key = VANA_DAY_KEYS[(day_idx % 8) + 1]
    local label = VANA_DAY_LABELS[(day_idx % 8) + 1]
    if not key then
        return nil, nil, 'vana day index out of range'
    end
    return key, label, nil
end

local function detect_apollyon_profile_from_line(line)
    local s = normalize_plain(line)
    if s == '' or s:find('apollyon', 1, true) == nil then
        return nil
    end
    -- Avoid matching lobby-only generic lines.
    if s == 'you have entered apollyon' or s == 'apollyon' then
        return nil
    end

    local p = ' ' .. s .. ' '

    if token_find(p, 'central') or token_find(p, 'cs') then
        return APOLLYON_PROFILES.apollyon_central
    end

    if token_find(p, 'south west') or token_find(p, 'southwest') or token_find(p, 'sw') then
        return APOLLYON_PROFILES.apollyon_south_west
    end

    if token_find(p, 'south east') or token_find(p, 'southeast') or token_find(p, 'se') then
        return APOLLYON_PROFILES.apollyon_south_east
    end

    if token_find(p, 'north west') or token_find(p, 'northwest') or token_find(p, 'nw') or token_find(p, 'west') then
        return APOLLYON_PROFILES.apollyon_west
    end

    if token_find(p, 'north east') or token_find(p, 'northeast') or token_find(p, 'ne') or token_find(p, 'east') then
        return APOLLYON_PROFILES.apollyon_east
    end

    return nil
end

local function plain_has_any(s, patterns)
    if s == nil or patterns == nil then
        return false
    end
    for _, pat in ipairs(patterns) do
        if pat and pat ~= '' and s:find(pat, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function detect_temenos_profile_from_line(line)
    local s = normalize_plain(line)
    if s == '' or s:find('temenos', 1, true) == nil then
        return nil
    end
    -- Avoid matching lobby-only generic lines.
    if s == 'you have entered temenos' or s == 'temenos' then
        return nil
    end

    local p = ' ' .. s .. ' '

    if token_find(p, 'central') or plain_has_any(s, { 'central temenos', 'temenos central' }) then
        if plain_has_any(s, { '1st', 'first', '1 floor', 'floor 1' }) then
            return TEMENOS_PROFILES.temenos_central_1
        end
        if plain_has_any(s, { '2nd', 'second', '2 floor', 'floor 2' }) then
            return TEMENOS_PROFILES.temenos_central_2
        end
        if plain_has_any(s, { '3rd', 'third', '3 floor', 'floor 3' }) then
            return TEMENOS_PROFILES.temenos_central_3
        end
        if plain_has_any(s, { '4th', 'fourth', '4 floor', 'floor 4' }) then
            return TEMENOS_PROFILES.temenos_central_4
        end
        return nil
    end

    if plain_has_any(s, { 'western tower', 'west tower', 'temenos west', 'temenos western' })
            or token_find(p, 'western') or token_find(p, 'west') then
        return TEMENOS_PROFILES.temenos_west
    end
    if plain_has_any(s, { 'eastern tower', 'east tower', 'temenos east', 'temenos eastern' })
            or token_find(p, 'eastern') or token_find(p, 'east') then
        return TEMENOS_PROFILES.temenos_east
    end
    if plain_has_any(s, { 'northern tower', 'north tower', 'temenos north', 'temenos northern' })
            or token_find(p, 'northern') or token_find(p, 'north') then
        return TEMENOS_PROFILES.temenos_north
    end

    return nil
end

local function detect_limbus_profile_from_line(line)
    local profile = detect_apollyon_profile_from_line(line)
    if profile then
        return profile
    end
    return detect_temenos_profile_from_line(line)
end

local function ensure_gunpod_state(sess)
    if not sess then
        return nil
    end
    if type(sess.limbus_gunpod) ~= 'table' then
        sess.limbus_gunpod = {}
    end
    local gp = sess.limbus_gunpod
    gp.max_spawns = math.max(1, tonumber(gp.max_spawns) or GUNPOD_MAX_SPAWNS)
    gp.total_spawns = math.max(0, tonumber(gp.total_spawns) or 0)
    gp.active_count = math.max(0, tonumber(gp.active_count) or 0)
    gp.active_hp = tonumber(gp.active_hp) or nil
    gp.last_scan = tonumber(gp.last_scan) or 0
    gp.spawn_messages = math.max(0, tonumber(gp.spawn_messages) or 0)
    if gp.total_spawns > gp.max_spawns then
        gp.max_spawns = gp.total_spawns
    end
    if gp.spawn_messages > gp.max_spawns then
        gp.max_spawns = gp.spawn_messages
    end
    gp.last_spawn_msg_at = tonumber(gp.last_spawn_msg_at) or 0
    gp.last_spawn_msg_sig = tostring(gp.last_spawn_msg_sig or '')
    gp.last_spawn_event_tick = tonumber(gp.last_spawn_event_tick) or 0
    gp.last_spawn_event_source = tostring(gp.last_spawn_event_source or '')
    if type(gp.seen_ids) ~= 'table' then
        gp.seen_ids = {}
    end
    if type(gp.active_keys) ~= 'table' then
        gp.active_keys = {}
    end
    if type(gp.last_hp_by_key) ~= 'table' then
        gp.last_hp_by_key = {}
    end
    return gp
end

local function reset_gunpod_state(sess)
    if not sess then
        return
    end
    sess.limbus_gunpod = {
        max_spawns = GUNPOD_MAX_SPAWNS,
        total_spawns = 0,
        active_count = 0,
        active_hp = nil,
        last_scan = 0,
        spawn_messages = 0,
        last_spawn_msg_at = 0,
        last_spawn_msg_sig = '',
        last_spawn_event_tick = 0,
        last_spawn_event_source = '',
        seen_ids = {},
        active_keys = {},
        last_hp_by_key = {},
    }
end

local function add_gunpod_spawns(gp, source, delta, now_tick)
    if type(gp) ~= 'table' then
        return false
    end

    local n = math.max(0, math.floor(tonumber(delta) or 0))
    if n <= 0 then
        return false
    end

    local before = math.max(0, tonumber(gp.total_spawns) or 0)
    local max_spawns = math.max(1, tonumber(gp.max_spawns) or GUNPOD_MAX_SPAWNS)
    local src = tostring(source or '')
    local nowv = tonumber(now_tick) or os.clock()

    local last_tick = tonumber(gp.last_spawn_event_tick) or 0
    local last_src = tostring(gp.last_spawn_event_source or '')

    -- If different sources report near-simultaneously, keep only the first one.
    if last_tick > 0 and nowv >= last_tick and (nowv - last_tick) <= GUNPOD_CROSS_SOURCE_DEDUPE_SECONDS then
        if last_src ~= '' and src ~= '' and last_src ~= src then
            return false
        end
    end

    local target_total = before + n
    if target_total > max_spawns then
        max_spawns = target_total
        gp.max_spawns = max_spawns
    end
    gp.total_spawns = target_total
    if gp.total_spawns ~= before then
        gp.last_spawn_event_tick = nowv
        gp.last_spawn_event_source = src
        return true
    end
    return false
end

local function is_apollyon_central(sess)
    if not sess then
        return false
    end
    if tostring(sess.limbus_path_id or '') == 'apollyon_central' then
        return true
    end
    return (sess.limbus_is_central == true and tostring(sess.limbus_central_kind or '') == 'apollyon')
end

local function hydrate_profile_from_id(sess)
    if not sess then
        return
    end
    local pid = tostring(sess.limbus_path_id or '')
    if pid == '' then
        return
    end
    local profile = LIMBUS_PROFILE_BY_ID[pid]
    if not profile then
        return
    end

    if tostring(sess.limbus_path_label or '') == '' then
        sess.limbus_path_label = tostring(profile.label or '')
    end
    if tonumber(sess.limbus_max_floor) == nil and tonumber(profile.max_floor) ~= nil then
        sess.limbus_max_floor = tonumber(profile.max_floor)
    end

    local chip_name = tostring(sess.limbus_reward_chip or '')
    if chip_name == '' and profile.reward_chip ~= nil then
        sess.limbus_reward_chip = profile.reward_chip
    end
    local chip_key = tostring(sess.limbus_reward_chip_key or '')
    if chip_key == '' and profile.reward_chip_key ~= nil then
        sess.limbus_reward_chip_key = profile.reward_chip_key
    end

    if profile.central == true and sess.limbus_is_central ~= true then
        sess.limbus_is_central = true
    end
    if sess.limbus_is_central == true and tostring(sess.limbus_central_kind or '') == '' then
        sess.limbus_central_kind = tostring(profile.central_kind or '')
    end
end

local function apply_limbus_profile(sess, profile)
    if not (sess and profile) then
        return false
    end

    local prev = tostring(sess.limbus_path_id or '')
    local next_id = tostring(profile.id or '')
    local changed = (prev ~= next_id)

    sess.limbus_path_id = next_id
    sess.limbus_path_label = tostring(profile.label or '')
    sess.limbus_max_floor = tonumber(profile.max_floor) or nil
    sess.limbus_reward_chip = profile.reward_chip or nil
    sess.limbus_reward_chip_key = profile.reward_chip_key or nil
    sess.limbus_is_central = (profile.central == true)
    if sess.limbus_is_central then
        sess.limbus_central_kind = tostring(profile.central_kind or '')
    else
        sess.limbus_central_kind = ''
    end

    if is_apollyon_central(sess) then
        ensure_gunpod_state(sess)
    else
        sess.limbus_gunpod = nil
    end
    if next_id ~= 'apollyon_south_west' then
        clear_sw_day_element(sess)
    end

    return changed
end

local function handle_run_area_line(line, sess)
    if not (sess and line and line ~= '') then
        return false
    end
    local profile = detect_limbus_profile_from_line(line)
    if not profile then
        return false
    end

    -- Route does not change inside a run. Once detected, keep it fixed to
    -- avoid noisy chat lines overriding Central -> non-Central mid-run.
    if sess.limbus_run_started == true then
        local locked_id = tostring(sess.limbus_path_id or '')
        local new_id = tostring(profile.id or '')
        if locked_id ~= '' and new_id ~= '' and locked_id ~= new_id then
            return false
        end
    end

    local changed = apply_limbus_profile(sess, profile)
    if changed and sess.limbus_run_started == true then
        store.save(sess)
    end
    return true
end

local function handle_gunpod_line(line, sess)
    if not (sess and line and line ~= '') then
        return false
    end
    if sess.limbus_run_started ~= true or sess.limbus_run_ended == true or not is_apollyon_central(sess) then
        return false
    end

    local l = normalize_plain(line)
    if l == '' then
        return false
    end

    local gp = ensure_gunpod_state(sess)
    if not gp then
        return false
    end

    local spawned = false
    local sig = nil

    -- Most reliable trigger on this server (Central Apollyon).
    if l:find('pod ejection', 1, true) ~= nil and l:find('readies', 1, true) ~= nil then
        spawned = true
        sig = 'pod_ejection'
    end

    -- Fallback for servers that print explicit Gunpod spawn lines.
    if (not spawned) and l:find('gunpod', 1, true) ~= nil then
        spawned = (l:find('materializes', 1, true) ~= nil)
                or (l:find('appears', 1, true) ~= nil)
                or (l:find('emerges', 1, true) ~= nil)
                or (l:find('is summoned', 1, true) ~= nil)
                or (l:find('calls forth', 1, true) ~= nil)
                or (l:find('spawns', 1, true) ~= nil)
        if spawned then
            sig = 'gunpod_spawn'
        end
    end

    if spawned then
        local now = os.time()
        local last_at = tonumber(gp.last_spawn_msg_at) or 0
        local last_sig = tostring(gp.last_spawn_msg_sig or '')
        if sig and last_sig == sig and last_at > 0 and (now - last_at) <= GUNPOD_MESSAGE_DEDUPE_SECONDS then
            return true
        end

        gp.spawn_messages = math.max(0, tonumber(gp.spawn_messages) or 0) + 1
        if gp.spawn_messages > (tonumber(gp.max_spawns) or GUNPOD_MAX_SPAWNS) then
            gp.max_spawns = gp.spawn_messages
        end
        local changed_total = add_gunpod_spawns(gp, 'msg', 1, os.clock())
        gp.last_spawn_msg_at = now
        gp.last_spawn_msg_sig = tostring(sig or '')
        if changed_total then
            store.save(sess)
        end
        return true
    end

    return false
end

local function snapshot_party_in_zone(zid)
    local out = {}
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party then
        return out
    end

    local z = tonumber(zid) or 0
    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local mz = tonumber(party:GetMemberZone(i)) or -1
            if z ~= 0 and mz == z then
                local nm = clean_name(party:GetMemberName(i))
                if nm ~= '' and nm:lower() ~= 'unknown' then
                    out[nm] = true
                end
            end
        end
    end

    return out
end

local function ensure_run_markers(sess)
    if not sess then
        return
    end
    sess.limbus_run_started = (sess.limbus_run_started == true)
    sess.limbus_run_ended = (sess.limbus_run_ended == true)
    sess.limbus_run_ended_at = tonumber(sess.limbus_run_ended_at) or nil

    if type(sess.limbus_start_participants) ~= 'table' then
        sess.limbus_start_participants = {}
    end

    if sess.limbus_start_participants_locked == nil then
        sess.limbus_start_participants_locked = (next(sess.limbus_start_participants) ~= nil)
    else
        sess.limbus_start_participants_locked = (sess.limbus_start_participants_locked == true)
    end

    sess.limbus_gate_ready = (sess.limbus_gate_ready == true)
    sess.limbus_gate_ready_until = tonumber(sess.limbus_gate_ready_until) or nil
    sess.limbus_gate_count = math.max(0, tonumber(sess.limbus_gate_count) or 0)
    sess.limbus_floor = math.max(1, tonumber(sess.limbus_floor) or 1)
    sess.limbus_floor_changes = math.max(0, tonumber(sess.limbus_floor_changes) or 0)
    sess.limbus_transition_pending = (sess.limbus_transition_pending == true)
    sess.limbus_transition_pending_at = tonumber(sess.limbus_transition_pending_at) or nil
    sess.limbus_path_id = tostring(sess.limbus_path_id or '')
    if sess.limbus_path_id == '' then
        local z_profile = detect_limbus_profile_from_line(tostring(sess.zone_name or ''))
        if z_profile then
            apply_limbus_profile(sess, z_profile)
            sess.limbus_path_id = tostring(sess.limbus_path_id or '')
        end
    end
    sess.limbus_path_label = tostring(sess.limbus_path_label or '')
    sess.limbus_max_floor = tonumber(sess.limbus_max_floor) or nil
    if sess.limbus_reward_chip ~= nil then
        sess.limbus_reward_chip = tostring(sess.limbus_reward_chip)
        if sess.limbus_reward_chip == '' then
            sess.limbus_reward_chip = nil
        end
    end
    if sess.limbus_reward_chip_key ~= nil then
        sess.limbus_reward_chip_key = tostring(sess.limbus_reward_chip_key)
        if sess.limbus_reward_chip_key == '' then
            sess.limbus_reward_chip_key = nil
        end
    end
    if sess.limbus_sw_day_element ~= nil then
        sess.limbus_sw_day_element = tostring(sess.limbus_sw_day_element)
        if sess.limbus_sw_day_element == '' then
            sess.limbus_sw_day_element = nil
        end
    end
    sess.limbus_sw_day_element_locked = (sess.limbus_sw_day_element_locked == true)
    sess.limbus_sw_day_element_count = math.max(0, tonumber(sess.limbus_sw_day_element_count) or 0)
    sess.limbus_sw_day_element_floor = tonumber(sess.limbus_sw_day_element_floor) or nil
    sess.limbus_sw_day_element_detected_at = tonumber(sess.limbus_sw_day_element_detected_at) or nil
    sess.limbus_sw_day_element_last_scan = tonumber(sess.limbus_sw_day_element_last_scan) or 0
    sess.limbus_sw_day_element_not_before = tonumber(sess.limbus_sw_day_element_not_before) or nil
    if sess.limbus_sw_day_element_candidate ~= nil then
        sess.limbus_sw_day_element_candidate = tostring(sess.limbus_sw_day_element_candidate)
        if sess.limbus_sw_day_element_candidate == '' then
            sess.limbus_sw_day_element_candidate = nil
        end
    end
    sess.limbus_sw_day_element_candidate_hits = math.max(0, tonumber(sess.limbus_sw_day_element_candidate_hits) or 0)
    sess.limbus_central_kind = tostring(sess.limbus_central_kind or '')
    sess.limbus_is_central = (sess.limbus_is_central == true)
    hydrate_profile_from_id(sess)
    local pid = tostring(sess.limbus_path_id or '')
    if (sess.limbus_is_central ~= true)
            and (pid == 'apollyon_central' or pid:find('temenos_central_', 1, true) == 1) then
        sess.limbus_is_central = true
    end
    if sess.limbus_is_central == true and sess.limbus_central_kind == '' then
        if pid == 'apollyon_central' then
            sess.limbus_central_kind = 'apollyon'
        elseif pid:find('temenos_central_', 1, true) == 1 then
            sess.limbus_central_kind = 'temenos'
        else
            local zname = normalize_plain(tostring(sess.zone_name or ''))
            if zname:find('apollyon', 1, true) ~= nil then
                sess.limbus_central_kind = 'apollyon'
            elseif zname:find('temenos', 1, true) ~= nil then
                sess.limbus_central_kind = 'temenos'
            end
        end
    end
    if sess.limbus_is_central ~= true then
        sess.limbus_central_kind = ''
    end
    if tostring(sess.limbus_path_id or '') ~= 'apollyon_south_west' then
        clear_sw_day_element(sess)
    end

    if not sess.limbus_gate_ready then
        sess.limbus_gate_ready_until = nil
    end

    if sess.limbus_transition_pending then
        local at = tonumber(sess.limbus_transition_pending_at) or 0
        if (at <= 0) or ((os.time() - at) > TRANSITION_CONFIRM_SECONDS) then
            sess.limbus_transition_pending = false
            sess.limbus_transition_pending_at = nil
        end
    else
        sess.limbus_transition_pending_at = nil
    end

    ensure_floor_stats(sess)
    if sess.limbus_run_started == true then
        mark_floor_enter(sess, sess.limbus_floor, os.time())
    end

    if is_apollyon_central(sess) then
        ensure_gunpod_state(sess)
    else
        sess.limbus_gunpod = nil
    end
end

local function clear_transition_pending(sess)
    if not sess then
        return
    end
    ensure_run_markers(sess)
    sess.limbus_transition_pending = false
    sess.limbus_transition_pending_at = nil
end

local function mark_gate_ready(sess)
    if not sess then
        return
    end
    ensure_run_markers(sess)
    sess.limbus_gate_ready = true
    sess.limbus_gate_ready_until = nil
    sess.limbus_gate_count = (tonumber(sess.limbus_gate_count) or 0) + 1
    ensure_floor_stats(sess)
    local f = math.max(1, tonumber(sess.limbus_floor) or 1)
    local fs = sess.limbus_floor_stats[f]
    if type(fs) == 'table' then
        fs.gate_opens = math.max(0, tonumber(fs.gate_opens) or 0) + 1
        local rem = current_limbus_time_left_seconds(sess)
        if rem then
            if not fs.first_time_left then
                fs.first_time_left = rem
            end
            fs.last_time_left = rem
        end
    end
end

local function clear_gate_ready(sess)
    if not sess then
        return
    end
    ensure_run_markers(sess)
    sess.limbus_gate_ready = false
    sess.limbus_gate_ready_until = nil
end

local function normalize_chat_line(line)
    return tostring(line or '')
            :gsub('\30.', '')
            :gsub('\31.', '')
            :gsub('[\0-\31]', '')
            :gsub('^%[%d%d:%d%d:%d%d%]%s*', '')
            :gsub('^%b()%s*', '')
            :lower()
end

local function packet_blob(pkt)
    if type(pkt) ~= 'table' then
        return nil
    end
    local blob = pkt.data_modified
    if type(blob) ~= 'string' or blob == '' then
        blob = pkt.data
    end
    if type(blob) ~= 'string' or blob == '' then
        blob = pkt.data_raw
    end
    if type(blob) ~= 'string' or blob == '' then
        return nil
    end
    return blob
end

local function rd_u16le(data, ofs)
    if type(data) ~= 'string' then
        return nil
    end
    local i = (tonumber(ofs) or 0) + 1
    local b1, b2 = data:byte(i, i + 1)
    if not b2 then
        return nil
    end
    return b1 + (b2 * 256)
end

local function rd_u32le(data, ofs)
    if type(data) ~= 'string' then
        return nil
    end
    local i = (tonumber(ofs) or 0) + 1
    local b1, b2, b3, b4 = data:byte(i, i + 3)
    if not b4 then
        return nil
    end
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function mark_transition_pending(sess, menu_id, zone_id)
    if not sess then
        return
    end
    ensure_run_markers(sess)
    sess.limbus_transition_pending = true
    sess.limbus_transition_pending_at = os.time()
    sess.limbus_last_menu_id = tonumber(menu_id) or sess.limbus_last_menu_id
    sess.limbus_last_menu_zone = tonumber(zone_id) or sess.limbus_last_menu_zone
    clear_gate_ready(sess)
end

local function confirm_floor_transition(sess)
    if not sess then
        return false
    end
    ensure_run_markers(sess)
    if sess.limbus_run_started ~= true then
        clear_transition_pending(sess)
        return false
    end

    local now = os.time()
    local cur = math.max(1, tonumber(sess.limbus_floor) or 1)
    mark_floor_leave(sess, cur, now)
    local cur_stats = sess.limbus_floor_stats and sess.limbus_floor_stats[cur]
    if type(cur_stats) == 'table' then
        cur_stats.transitions = math.max(0, tonumber(cur_stats.transitions) or 0) + 1
    end
    sess.limbus_floor = cur + 1
    sess.limbus_floor_changes = (tonumber(sess.limbus_floor_changes) or 0) + 1
    sess.limbus_last_floor_up_at = now
    mark_floor_enter(sess, sess.limbus_floor, now)
    if tostring(sess.limbus_path_id or '') == 'apollyon_south_west' then
        local cap = tonumber(sess.limbus_max_floor) or 4
        if cap < 1 then
            cap = 4
        end
        if (tonumber(sess.limbus_floor) or 1) >= cap then
            clear_sw_day_element(sess)
            sess.limbus_sw_day_element_floor = math.max(1, tonumber(sess.limbus_floor) or 1)
            sess.limbus_sw_day_element_not_before = nil
        end
    end
    clear_transition_pending(sess)
    return true
end

local function lock_start_participants(sess, force)
    if not sess then
        return false
    end
    ensure_run_markers(sess)
    if (not force) and sess.limbus_start_participants_locked then
        return false
    end

    local zid = tonumber(sess.zone_id)
    if not zid or zid == 0 then
        local party = AshitaCore:GetMemoryManager():GetParty()
        zid = party and tonumber(party:GetMemberZone(0)) or 0
    end

    sess.limbus_start_participants = snapshot_party_in_zone(zid)
    sess.limbus_start_participants_locked = true
    return true
end

local function mark_run_started(sess, with_lock)
    ensure_run_markers(sess)
    if tostring(sess.limbus_path_id or '') == '' then
        local z_profile = detect_limbus_profile_from_line(tostring(sess.zone_name or ''))
        if z_profile then
            apply_limbus_profile(sess, z_profile)
        end
    end
    local was_started = (sess.limbus_run_started == true)
    local now = os.time()
    if not was_started then
        -- First run signal seen for this zone visit/session.
        sess.start_time = now
        sess.drops = core.new_drop_state()
        sess._filename = nil
        sess.run_index = nil
        sess.ended = false
        sess.limbus_gate_ready = false
        sess.limbus_gate_ready_until = nil
        sess.limbus_gate_count = 0
        sess.limbus_floor = 1
        sess.limbus_floor_changes = 0
        sess.limbus_transition_pending = false
        sess.limbus_transition_pending_at = nil
        sess.limbus_floor_stats = {}
        sess.limbus_gunpod = nil
        clear_sw_day_element(sess)
    end
    sess.limbus_run_started = true
    sess.limbus_run_ended = false
    sess.limbus_run_ended_at = nil
    mark_floor_enter(sess, sess.limbus_floor, now)
    if not was_started then
        if is_apollyon_central(sess) then
            reset_gunpod_state(sess)
        else
            sess.limbus_gunpod = nil
        end
    end
    if with_lock then
        -- The run starts here (vortex message), not when entering Apollyon/Temenos.
        lock_start_participants(sess, true)
        sess.management = {}
        sess.limbus_split = {}
    end
end

local function ensure_timer(sess, base_minutes, activate)
    if not sess then
        return
    end

    local start = tonumber(sess.start_time) or os.time()
    sess.start_time = start

    local base = tonumber(base_minutes)
            or tonumber(sess.limbus_timer and sess.limbus_timer.base_minutes)
            or 30
    if base < 1 then
        base = 30
    end

    sess.limbus_timer = sess.limbus_timer or {
        end_at = nil,
        fallback_end_at = nil,
        base_minutes = base,
        desynced = false,
        last_sync_at = nil,
    }

    sess.limbus_timer.base_minutes = base
    if (activate == true) and (not sess.limbus_timer.fallback_end_at) then
        sess.limbus_timer.fallback_end_at = start + (base * 60)
    end

    local end_at = tonumber(sess.limbus_timer.end_at)
    local fallback_end = tonumber(sess.limbus_timer.fallback_end_at)
    if end_at and ((not fallback_end) or end_at > fallback_end) then
        sess.limbus_timer.fallback_end_at = end_at
    end

    ensure_run_markers(sess)
end

local function set_start_time(sess, minutes)
    local mins = tonumber(minutes) or 30
    if mins < 1 then
        mins = 30
    end

    ensure_timer(sess, mins, true)
    local now = os.time()

    sess.limbus_timer.base_minutes = mins
    sess.limbus_timer.end_at = now + (mins * 60)
    sess.limbus_timer.fallback_end_at = sess.limbus_timer.end_at
    sess.limbus_timer.desynced = false
    sess.limbus_timer.last_sync_at = now
end

local function add_extension(sess, minutes)
    local mins = tonumber(minutes) or 0
    if mins <= 0 then
        return
    end

    ensure_timer(sess, nil, true)
    local ext = mins * 60

    if sess.limbus_timer.end_at then
        sess.limbus_timer.end_at = sess.limbus_timer.end_at + ext
    else
        sess.limbus_timer.fallback_end_at = (tonumber(sess.limbus_timer.fallback_end_at) or os.time()) + ext
    end

    if sess.limbus_timer.end_at and sess.limbus_timer.end_at > sess.limbus_timer.fallback_end_at then
        sess.limbus_timer.fallback_end_at = sess.limbus_timer.end_at
    end
end

local function handle_timer_line(line, sess)
    if not (sess and line and line ~= '') then
        return false
    end

    local l = normalize_chat_line(line)

    local start_min = l:match('you may stay in limbus for%s+(%d+)%s+minutes?')
    if start_min then
        set_start_time(sess, start_min)
        mark_run_started(sess, true)
        store.save(sess)
        return true
    end

    local ext_min = l:match('your stay in limbus has been extended by%s+(%d+)%s+minutes?')
            or l:match('your time in limbus has been extended%s+(%d+)%s+minutes?')
    if ext_min then
        add_extension(sess, ext_min)
        mark_run_started(sess, false)
        store.save(sess)
        return true
    end

    local left_min = l:match('you have%s+(%d+)%s+minutes?%s+left%s+in%s+limbus')
    if left_min then
        ensure_timer(sess, nil, true)
        local now = os.time()
        local rem = (tonumber(left_min) or 0) * 60
        sess.limbus_timer.end_at = now + rem
        sess.limbus_timer.fallback_end_at = sess.limbus_timer.end_at
        sess.limbus_timer.desynced = false
        sess.limbus_timer.last_sync_at = now
        mark_run_started(sess, false)
        store.save(sess)
        return true
    end

    -- Some servers emit periodic messages like:
    --   "Time left: (0:10:00)"
    local hh, mm, ss = l:match('time%s+left:%s*%((%d+):(%d+):(%d+)%)')
    if not hh then
        hh, mm, ss = l:match('time%s+left:%s*(%d+):(%d+):(%d+)')
    end
    if hh and mm and ss then
        ensure_timer(sess, nil, true)
        local now = os.time()
        local rem = ((tonumber(hh) or 0) * 3600) + ((tonumber(mm) or 0) * 60) + (tonumber(ss) or 0)
        sess.limbus_timer.end_at = now + math.max(0, rem)
        sess.limbus_timer.fallback_end_at = sess.limbus_timer.end_at
        sess.limbus_timer.desynced = false
        sess.limbus_timer.last_sync_at = now
        mark_run_started(sess, false)
        store.save(sess)
        return true
    end

    if l:find('you can no longer hear a faint hum', 1, true) then
        ensure_timer(sess, nil, true)
        local now = os.time()
        sess.limbus_timer.end_at = now
        sess.limbus_timer.fallback_end_at = now
        sess.limbus_timer.desynced = false
        sess.limbus_timer.last_sync_at = now
        sess.limbus_run_started = true
        sess.limbus_run_ended = true
        sess.limbus_run_ended_at = now
        mark_floor_leave(sess, sess.limbus_floor, now)
        clear_gate_ready(sess)
        clear_transition_pending(sess)
        store.save(sess, { force = true, event_id = limbus.id })
        return true
    end

    return false
end

local function handle_gate_line(line, sess)
    if not (sess and sess.limbus_run_started == true and line and line ~= '') then
        return false
    end

    local l = normalize_chat_line(line)
    if l == '' then
        return false
    end

    local gate_opened = (l:find('gate opens', 1, true) ~= nil)
            or (l:find('portal opens', 1, true) ~= nil)
            or (l:find('portal has opened', 1, true) ~= nil)
            or (l:find('door opens', 1, true) ~= nil)
            or (l:find('vortex materializes', 1, true) ~= nil)
            or (l:find('vortex appears', 1, true) ~= nil)
            or (l:find('vortex opens', 1, true) ~= nil)
            or (l:find('vortex has opened', 1, true) ~= nil)
    if gate_opened then
        mark_gate_ready(sess)
        store.save(sess)
        return true
    end

    return false
end

function limbus.is_zone(zid)
    zid = tonumber(zid)
    if not zid or zid == 0 or zid == 0xFFFF then
        return false
    end
    if LIMBUS_ZONES[zid] then
        return true
    end

    local name = AshitaCore:GetResourceManager():GetString('zones.names', zid) or ''
    name = tostring(name):lower()
    return (name:find('apollyon', 1, true) ~= nil)
            or (name:find('temenos', 1, true) ~= nil)
            or (name:find('limbus', 1, true) ~= nil)
end

function limbus.on_enter(ctx)
    local zid = tonumber(ctx and ctx.zid) or 0
    local now = tonumber(ctx and ctx.now) or os.time()
    local zone_name = tostring((ctx and ctx.zone_name) or ('Zone ' .. tostring(zid)))

    local saved = store.load(zid, { event_id = limbus.id, only_active = true })
    if saved and saved.limbus_run_started ~= true then
        saved = nil
    end
    if saved then
        saved.event_id = limbus.id
        ensure_timer(saved, nil, true)
        ensure_run_markers(saved)
        local now_ts = os.time()
        local end_at = tonumber(saved.limbus_timer and saved.limbus_timer.end_at)
        if end_at and end_at <= now_ts then
            saved.limbus_run_ended = true
            saved.limbus_run_ended_at = saved.limbus_run_ended_at or end_at
        end
        saved.ended = false
        saved.is_event = true
        saved.management = saved.management or {}
        return saved, string.format('%s continues. Ready for Ancient Beastcoins.', zone_name)
    end

    local sess = parser.new_session(zid, { event_id = limbus.id })
    if not sess then
        return nil, nil
    end

    sess.event_id = limbus.id
    sess.is_event = true
    sess.zone_id = zid
    sess.start_time = now
    sess.management = {}
    sess.ended = false
    sess.limbus_run_started = false
    sess.limbus_run_ended = false
    sess.limbus_run_ended_at = nil
    sess.limbus_start_participants = {}
    sess.limbus_start_participants_locked = false
    sess.limbus_gate_ready = false
    sess.limbus_gate_ready_until = nil
    sess.limbus_gate_count = 0
    sess.limbus_floor = 1
    sess.limbus_floor_changes = 0
    sess.limbus_floor_stats = {}
    sess.limbus_path_id = ''
    sess.limbus_path_label = ''
    sess.limbus_max_floor = nil
    sess.limbus_reward_chip = nil
    sess.limbus_reward_chip_key = nil
    sess.limbus_is_central = false
    sess.limbus_central_kind = ''
    sess.limbus_gunpod = nil
    sess.limbus_transition_pending = false
    sess.limbus_transition_pending_at = nil
    sess.limbus_sw_day_element = nil
    sess.limbus_sw_day_element_locked = false
    sess.limbus_sw_day_element_count = 0
    sess.limbus_sw_day_element_floor = nil
    sess.limbus_sw_day_element_detected_at = nil
    sess.limbus_sw_day_element_last_scan = 0
    sess.limbus_sw_day_element_not_before = nil
    sess.limbus_sw_day_element_candidate = nil
    sess.limbus_sw_day_element_candidate_hits = 0
    ensure_timer(sess, 30, false)

    -- Do not persist a run here; wait for the real run-start message.
    return sess, string.format('Entering %s. Waiting for Limbus run start.', zone_name)
end

function limbus.on_leave(sess, opts)
    if not (sess and sess.is_event) then
        return nil
    end
    if sess.limbus_run_started ~= true then
        -- Left zone before starting the run.
        return nil
    end
    mark_floor_leave(sess, sess.limbus_floor, os.time())
    sess.ended = true
    store.save(sess, { force = true, event_id = limbus.id })
    return nil
end

local function scan_central_gunpod(sess, now_tick)
    if not sess then
        return false
    end
    if sess.limbus_run_started ~= true or sess.limbus_run_ended == true or not is_apollyon_central(sess) then
        return false
    end

    local gp = ensure_gunpod_state(sess)
    if not gp then
        return false
    end

    now_tick = tonumber(now_tick) or os.clock()
    local last = tonumber(gp.last_scan) or 0
    if (now_tick - last) < GUNPOD_SCAN_INTERVAL then
        return false
    end
    gp.last_scan = now_tick

    local ent_mgr = AshitaCore:GetMemoryManager():GetEntity()
    if not ent_mgr or not ent_mgr.GetName then
        return false
    end

    local active_count = 0
    local best_hp = nil
    local total_before = gp.total_spawns
    local prev_active_keys = gp.active_keys or {}
    local prev_hp_by_key = gp.last_hp_by_key or {}
    local now_active_keys = {}
    local now_hp_by_key = {}
    local spawn_delta = 0
    local changed = false

    for i = 0, ENTITY_MAX_INDEX do
        local name = clean_name(ent_mgr:GetName(i))
        if name ~= '' and name:lower() == 'gunpod' then
            local sid = nil
            if ent_mgr.GetServerId then
                sid = tonumber(ent_mgr:GetServerId(i))
            end

            local hp = nil
            if ent_mgr.GetHPPercent then
                hp = tonumber(ent_mgr:GetHPPercent(i))
            end
            if hp and hp > 0 then
                local key
                if sid and sid > 0 then
                    key = 'sid:' .. tostring(sid)
                else
                    key = 'idx:' .. tostring(i)
                end

                local is_new_key_this_scan = (now_active_keys[key] ~= true)
                if is_new_key_this_scan then
                    now_active_keys[key] = true
                    now_hp_by_key[key] = hp

                    -- Fallback spawn detection by entity state:
                    -- new alive key OR HP reset near full on same key.
                    if prev_active_keys[key] ~= true then
                        spawn_delta = spawn_delta + 1
                    else
                        local prev_hp = tonumber(prev_hp_by_key[key])
                        if prev_hp and hp >= 95 and prev_hp <= 80 and (hp - prev_hp) >= 20 then
                            spawn_delta = spawn_delta + 1
                        end
                    end

                    active_count = active_count + 1
                else
                    local prev_now_hp = tonumber(now_hp_by_key[key]) or 0
                    if hp > prev_now_hp then
                        now_hp_by_key[key] = hp
                    end
                end

                local key_hp = tonumber(now_hp_by_key[key]) or hp
                if (not best_hp) or key_hp > best_hp then
                    best_hp = key_hp
                end
            end
        end
    end

    if spawn_delta > 0 then
        -- Message is authoritative when present; entity fallback only if
        -- we have not seen a recent Pod Ejection line.
        local last_msg_at = tonumber(gp.last_spawn_msg_at) or 0
        local now_sec = os.time()
        local recent_msg = (last_msg_at > 0 and (now_sec - last_msg_at) <= GUNPOD_MESSAGE_PRIORITY_SECONDS)
        if not recent_msg then
            if add_gunpod_spawns(gp, 'entity', spawn_delta, now_tick) then
                changed = true
            end
        end
    end

    if gp.total_spawns < (tonumber(gp.spawn_messages) or 0) then
        local msg_total = math.max(0, tonumber(gp.spawn_messages) or 0)
        if msg_total > (tonumber(gp.max_spawns) or GUNPOD_MAX_SPAWNS) then
            gp.max_spawns = msg_total
        end
        gp.total_spawns = msg_total
        changed = true
    end

    local prev_active_count = tonumber(gp.active_count) or 0
    local prev_active_hp = tonumber(gp.active_hp)
    gp.active_keys = now_active_keys
    gp.last_hp_by_key = now_hp_by_key
    gp.active_count = active_count
    gp.active_hp = best_hp

    if prev_active_count ~= active_count then
        changed = true
    end
    if (prev_active_hp or -1) ~= (best_hp or -1) then
        changed = true
    end

    if changed and gp.total_spawns ~= total_before then
        store.save(sess)
    end
    return changed
end

local function is_sw_chip_floor(sess)
    if not sess then
        return false
    end
    if sess.limbus_run_started ~= true or sess.limbus_run_ended == true then
        return false
    end
    if tostring(sess.limbus_path_id or '') ~= 'apollyon_south_west' then
        return false
    end
    local cap = tonumber(sess.limbus_max_floor) or 4
    if cap < 1 then
        cap = 4
    end
    local floor = math.max(1, tonumber(sess.limbus_floor) or 1)
    return floor >= cap
end

local function scan_sw_day_element(sess, now_tick)
    if not is_sw_chip_floor(sess) then
        return false
    end
    if sess.limbus_sw_day_element_locked == true and tostring(sess.limbus_sw_day_element or '') ~= '' then
        return false
    end
    local not_before = tonumber(sess.limbus_sw_day_element_not_before)
    if not_before and os.time() < not_before then
        return false
    end

    now_tick = tonumber(now_tick) or os.clock()
    local last = tonumber(sess.limbus_sw_day_element_last_scan) or 0
    if (now_tick - last) < SW_ELEMENTAL_SCAN_INTERVAL then
        return false
    end
    sess.limbus_sw_day_element_last_scan = now_tick

    local day_key = read_vana_day_from_memory()
    if not day_key then
        return false
    end

    local changed = false
    if tostring(sess.limbus_sw_day_element or '') ~= day_key then
        sess.limbus_sw_day_element = day_key
        changed = true
    end
    if sess.limbus_sw_day_element_locked ~= true then
        sess.limbus_sw_day_element_locked = true
        changed = true
    end
    if tonumber(sess.limbus_sw_day_element_count) ~= 0 then
        sess.limbus_sw_day_element_count = 0
        changed = true
    end
    local floor = math.max(1, tonumber(sess.limbus_floor) or 1)
    if tonumber(sess.limbus_sw_day_element_floor) ~= floor then
        sess.limbus_sw_day_element_floor = floor
        changed = true
    end
    local now_sec = os.time()
    if tonumber(sess.limbus_sw_day_element_detected_at) ~= now_sec then
        sess.limbus_sw_day_element_detected_at = now_sec
        changed = true
    end
    if sess.limbus_sw_day_element_not_before ~= nil then
        sess.limbus_sw_day_element_not_before = nil
        changed = true
    end
    if sess.limbus_sw_day_element_candidate ~= nil then
        sess.limbus_sw_day_element_candidate = nil
        changed = true
    end
    if (tonumber(sess.limbus_sw_day_element_candidate_hits) or 0) ~= 0 then
        sess.limbus_sw_day_element_candidate_hits = 0
        changed = true
    end

    if changed then
        store.save(sess)
    end
    return changed
end

function limbus.on_tick(sess, now_tick)
    if not sess or not sess.is_event then
        return
    end
    ensure_run_markers(sess)
    scan_central_gunpod(sess, now_tick)
    scan_sw_day_element(sess, now_tick)
end

function limbus.on_packet_out(pkt, sess)
    if not (sess and sess.is_event and sess.limbus_run_started == true and sess.limbus_run_ended ~= true) then
        return
    end
    if not pkt or pkt.injected then
        return
    end

    ensure_run_markers(sess)
    local id = tonumber(pkt.id) or -1
    -- 0x05B: dialog choice (Yes/No menu like "Use the device?")
    if id == 0x05B then
        local data = packet_blob(pkt)
        if data then
            sess.limbus_last_menu_option = rd_u16le(data, 0x08) or sess.limbus_last_menu_option
            sess.limbus_last_menu_zone = rd_u16le(data, 0x10) or sess.limbus_last_menu_zone
            sess.limbus_last_menu_id = rd_u16le(data, 0x12) or sess.limbus_last_menu_id
        end
        sess.limbus_last_menu_at = os.time()

        -- In Limbus floor devices, a Yes/No dialog can be the only explicit signal before transition.
        if sess.limbus_gate_ready == true then
            mark_transition_pending(sess, sess.limbus_last_menu_id, sess.limbus_last_menu_zone)
            store.save(sess)
        end
        return
    end

    -- 0x05C: warp request (device/portal accepted)
    if id == 0x05C then
        local data = packet_blob(pkt)
        local zone_id, menu_id = nil, nil
        if data then
            zone_id = rd_u16le(data, 0x18)
            menu_id = rd_u16le(data, 0x1A)
        end
        mark_transition_pending(sess, menu_id, zone_id)
        store.save(sess)
    end
end

function limbus.on_packet_in(pkt, sess)
    if not (sess and sess.is_event and sess.limbus_run_started == true and sess.limbus_run_ended ~= true) then
        return
    end
    if not pkt or pkt.injected then
        return
    end

    ensure_run_markers(sess)
    local id = tonumber(pkt.id) or -1
    -- Menu context (useful to keep current menu id/zone context around transitions).
    if id == 0x032 then
        local data = packet_blob(pkt)
        if data then
            sess.limbus_last_menu_zone = rd_u16le(data, 0x0A) or sess.limbus_last_menu_zone
            sess.limbus_last_menu_id = rd_u16le(data, 0x0C) or sess.limbus_last_menu_id
        end
        sess.limbus_last_menu_at = os.time()
        return
    end
    if id == 0x033 then
        local data = packet_blob(pkt)
        if data then
            sess.limbus_last_menu_zone = rd_u16le(data, 0x0A) or sess.limbus_last_menu_zone
            sess.limbus_last_menu_id = rd_u16le(data, 0x0C) or sess.limbus_last_menu_id
        end
        sess.limbus_last_menu_at = os.time()
        return
    end
    if id == 0x034 then
        local data = packet_blob(pkt)
        if data then
            sess.limbus_last_menu_zone = rd_u16le(data, 0x2A) or sess.limbus_last_menu_zone
            sess.limbus_last_menu_id = rd_u16le(data, 0x2C) or sess.limbus_last_menu_id
        end
        sess.limbus_last_menu_at = os.time()
        return
    end

    -- 0x065: repositioning, confirms internal floor transition without zone change.
    if id == 0x065 and sess.limbus_transition_pending == true then
        local now = os.time()
        local pending_at = tonumber(sess.limbus_transition_pending_at) or 0
        if (pending_at <= 0) or ((now - pending_at) > TRANSITION_CONFIRM_SECONDS) then
            clear_transition_pending(sess)
            return
        end

        local data = packet_blob(pkt)
        if data then
            local pkt_id = rd_u32le(data, 0x10)
            local pkt_idx = rd_u16le(data, 0x14)
            local ent = GetPlayerEntity()
            local my_id = ent and tonumber(ent.ServerId) or 0
            local party = AshitaCore:GetMemoryManager():GetParty()
            local my_idx = (party and tonumber(party:GetMemberTargetIndex(0))) or 0

            local id_match = (my_id > 0 and pkt_id and pkt_id == my_id)
            local idx_match = (my_idx > 0 and pkt_idx and pkt_idx == my_idx)

            if (my_id > 0 or my_idx > 0) and not (id_match or idx_match) then
                return
            end
        end

        if confirm_floor_transition(sess) then
            store.save(sess)
        end
    end
end

function limbus.on_text(line, sess)
    local raw = tostring(line or '')
    raw = raw:gsub('\r\n', '\n'):gsub('\r', '\n')
    raw = raw:gsub('(%S)(%[%d%d:%d%d:%d%d%])', '%1\n%2')

    for piece in raw:gmatch('[^\n]+') do
        handle_run_area_line(piece, sess)
        handle_timer_line(piece, sess)
        handle_gate_line(piece, sess)
        handle_gunpod_line(piece, sess)
    end

    if sess and sess.limbus_run_started == true then
        parser.handle_line(raw, sess)
    end
end

return limbus
