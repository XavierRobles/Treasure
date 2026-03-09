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

local LIMBUS_ZONES = {
    [37] = true, -- Temenos
    [38] = true, -- Apollyon
}

local function clean_name(name)
    return tostring(name or '')
            :gsub('%z', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
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

    local cur = math.max(1, tonumber(sess.limbus_floor) or 1)
    sess.limbus_floor = cur + 1
    sess.limbus_floor_changes = (tonumber(sess.limbus_floor_changes) or 0) + 1
    sess.limbus_last_floor_up_at = os.time()
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
    local was_started = (sess.limbus_run_started == true)
    if not was_started then
        -- First run signal seen for this zone visit/session.
        sess.start_time = os.time()
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
    end
    sess.limbus_run_started = true
    sess.limbus_run_ended = false
    sess.limbus_run_ended_at = nil
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
    sess.limbus_transition_pending = false
    sess.limbus_transition_pending_at = nil
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
    sess.ended = true
    store.save(sess, { force = true, event_id = limbus.id })
    return nil
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
        handle_timer_line(piece, sess)
        handle_gate_line(piece, sess)
    end

    if sess and sess.limbus_run_started == true then
        parser.handle_line(raw, sess)
    end
end

return limbus
