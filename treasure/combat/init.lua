local combat = {}
local decoder = require('combat.decoder')
local action_message = require('combat.action_message')
local event_builder = require('combat.event')
local entities = require('combat.entities')
local formatter = require('combat.formatter')
local magic_burst = require('combat.magic_burst')
local chat_colors = require('combat.chat_colors')
local unknowns = require('combat.unknowns')
local timeutil = require('timeutil')
local chatutil = require('chatutil')

local subscribers = {}
local current_settings = nil
local sequence = 0
local pending_visual = {}
local pending_visual_head = 1
local pending_visual_tail = 0
local pending_groups = {}
local pending_group_order = {}
local MAX_PENDING_VISUAL = 100
local OWN_PREFIX = '[Treasure Compare] '
local CHAT_RESET = string.char(0x1E, 1)
-- A normal game line can begin with one or two reset controls. Use a longer
-- invisible signature so original combat text is never mistaken for our own.
local FULL_MARKER = string.rep(CHAT_RESET, 6)
local DEBUG_PREFIX = '[Treasure Combat Debug] '
local last_debug_packets = -1
local last_debug_all = -1
local last_debug_at = -100
local FORCE_DIAGNOSTICS = false
local stats = {
    packets_all = 0,
    last_packet_id = 0,
    packets_028 = 0,
    decoded = 0,
    decode_errors = 0,
    queued = 0,
    lines_output = 0,
    last_error = '',
}

local function clone(value)
    if type(value) ~= 'table' then
        return value
    end
    local out = {}
    for key, child in pairs(value) do
        out[key] = clone(child)
    end
    return out
end

local function pending_visual_size()
    return math.max(0, pending_visual_tail - pending_visual_head + 1)
end

local function clear_pending_visual()
    pending_visual = {}
    pending_visual_head = 1
    pending_visual_tail = 0
end

local function push_pending_visual(event)
    if pending_visual_size() >= MAX_PENDING_VISUAL then
        pending_visual[pending_visual_head] = nil
        pending_visual_head = pending_visual_head + 1
    end
    pending_visual_tail = pending_visual_tail + 1
    pending_visual[pending_visual_tail] = event
end

local function pop_pending_visual()
    if pending_visual_head > pending_visual_tail then
        return nil
    end
    local event = pending_visual[pending_visual_head]
    pending_visual[pending_visual_head] = nil
    pending_visual_head = pending_visual_head + 1
    if pending_visual_head > pending_visual_tail then
        clear_pending_visual()
    end
    return event
end

function combat.configure(cfg)
    current_settings = cfg
    unknowns.configure(type(cfg) == 'table' and cfg.capture_unknown ~= false, nil,
        type(cfg) == 'table' and cfg.capture_all == true)
    if not combat.is_visual_enabled() then
        clear_pending_visual()
        pending_groups = {}
        pending_group_order = {}
    end
end

function combat.set_character_context(character_dir)
    magic_burst.reset()
    unknowns.configure(type(current_settings) == 'table' and current_settings.capture_unknown ~= false,
        character_dir, type(current_settings) == 'table' and current_settings.capture_all == true)
end

function combat.is_visual_enabled()
    return type(current_settings) == 'table'
            and current_settings.enabled == true
            and current_settings.mode ~= 'off'
end

function combat.is_replacing_chat()
    return combat.is_visual_enabled()
            and current_settings.mode == 'full'
end

function combat.is_own_line(message)
    return type(message) == 'string'
            and (message:sub(1, #OWN_PREFIX) == OWN_PREFIX
                or message:sub(1, #FULL_MARKER) == FULL_MARKER
                or message:sub(1, #DEBUG_PREFIX) == DEBUG_PREFIX)
end

function combat.get_stats()
    local unknown_stats = unknowns.get_stats()
    return {
        packets_all = stats.packets_all,
        last_packet_id = stats.last_packet_id,
        packets_028 = stats.packets_028,
        decoded = stats.decoded,
        decode_errors = stats.decode_errors,
        queued = stats.queued,
        pending = pending_visual_size(),
        lines_output = stats.lines_output,
        last_error = stats.last_error,
        unknown_signatures = unknown_stats.signatures,
        unknown_observations = unknown_stats.observations,
        unsupported_signatures = unknown_stats.unsupported_signatures,
        unsupported_observations = unknown_stats.unsupported_observations,
        supported_observations = unknown_stats.supported_observations,
        unknown_dropped = unknown_stats.dropped,
        unknown_path = unknown_stats.path,
        audit_path = unknown_stats.audit_path,
        capture_all = unknown_stats.capture_all,
    }
end

function combat.subscribe(name, callback)
    if type(name) ~= 'string' or name == '' or type(callback) ~= 'function' then
        return false
    end
    subscribers[name] = callback
    return true
end

function combat.unsubscribe(name)
    subscribers[name] = nil
end

function combat.emit(event)
    if type(event) ~= 'table' then
        return false
    end
    local canonical = clone(event)
    sequence = sequence + 1
    canonical.schema_version = tonumber(canonical.schema_version) or 1
    canonical.sequence = tonumber(canonical.sequence) or sequence
    canonical.timestamp = tonumber(canonical.timestamp) or os.clock()

    local delivered = false
    for _, callback in pairs(subscribers) do
        local ok = pcall(callback, clone(canonical))
        delivered = ok or delivered
    end
    return delivered
end

-- Decode the original action once and selectively replace only messages the
-- formatter can reconstruct without losing their meaning.
function combat.on_packet_in(_event)
    if _event == nil then
        return false
    end
    stats.packets_all = stats.packets_all + 1
    stats.last_packet_id = tonumber(_event.id) or 0
    if _event.id == 0x029 then
        if not combat.is_visual_enabled() then return false end
        local parsed = action_message.parse(_event.data)
        if parsed == nil or parsed.message_id ~= 206 then return false end

        local packet_now = timeutil.now()
        local structured = {
            schema_version = 1,
            timestamp = packet_now,
            source = 'packet_0x029',
            kind = 'status_wear_off',
            actor = { server_id = parsed.target_id },
            action = { category = 'status', id = parsed.param, name = 'status wear off' },
            targets = { {
                server_id = parsed.target_id,
                message_id = parsed.message_id,
                amount = parsed.param,
                outcome = 'hit',
                channel = 'main',
            } },
            raw = {
                packet_id = 0x029,
                actor_id = parsed.actor_id,
                actor_index = parsed.actor_index,
                target_index = parsed.target_index,
            },
        }
        entities.resolve_immediate(structured)
        local target = structured.targets[1]
        target.replace_original = formatter.supports_target(structured, target)
        if not target.replace_original then return false end
        structured.action.name = target.status_name

        if current_settings.mode == 'full' then
            -- Unlike 0x028 action-result fields, message id 0 in an orphan
            -- 0x029 packet is rendered by the client as the resource text
            -- "dummy". Block only this fully reconstructed wear-off packet.
            _event.blocked = true
        end
        stats.decoded = stats.decoded + 1
        combat.emit(structured)
        structured.sequence = sequence
        push_pending_visual(structured)
        stats.queued = stats.queued + 1
        return true
    end
    if _event.id ~= 0x028 then
        return false
    end
    stats.packets_028 = stats.packets_028 + 1
    if not combat.is_visual_enabled() then
        return false
    end

    -- Decode the immutable packet supplied by Ashita. Other addons may already
    -- have changed data_modified, but that must never alter Treasure's event.
    local data = _event.data
    local action, decode_error = decoder.decode_action(data)
    if not action then
        stats.decode_errors = stats.decode_errors + 1
        stats.last_error = tostring(decode_error or 'unknown decoder error')
        return false
    end
    stats.decoded = stats.decoded + 1
    local structured = event_builder.from_action(action)
    if not structured then
        return false
    end
    local packet_now = timeutil.now()
    -- Refresh and resolve entities before deciding which original fields are
    -- safe to neutralize. Resolution is repeated on the render tick, but by
    -- then the client message has already been accepted or suppressed.
    entities.resolve_immediate(structured)
    structured.action.name = entities.action_name(structured)
    local ok_zone, zone_id = pcall(function()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    end)
    structured.raw.zone_id = ok_zone and (tonumber(zone_id) or 0) or 0
    local suppression_source = _event.data_modified or data
    local target_index = 0
    local has_visual_target = false
    local function should_replace(message_id, channel)
        target_index = target_index + 1
        local target = structured.targets[target_index]
        if not target then return false end
        target.channel = channel or target.channel
        target.message_id = tonumber(message_id) or target.message_id
        target.replace_original = formatter.supports_target(structured, target)
        -- Capture every decoded result, including messages Treasure currently
        -- considers safe, so semantic losses remain auditable later.
        unknowns.record(structured, target, data, suppression_source, target.replace_original)
        has_visual_target = has_visual_target or target.replace_original
        return target.replace_original
    end
    if current_settings and current_settings.mode == 'full' then
        local modified, suppress_error = decoder.suppress_messages(suppression_source, action, should_replace)
        if modified then
            _event.data_modified = modified
        elseif not modified then
            stats.last_error = tostring(suppress_error or 'message suppression error')
        end
    end
    structured.timestamp = packet_now
    combat.emit(structured)
    -- combat.emit keeps its caller immutable, so copy the assigned envelope
    -- sequence back only to this private queued instance for audit correlation.
    structured.sequence = sequence
    if has_visual_target or (current_settings and current_settings.capture_all == true) then
        push_pending_visual(structured)
        stats.queued = stats.queued + 1
    end
    return true
end

local function output_event(event, action_name)
    local lines = formatter.format(event, current_settings, action_name)
    local prefix = current_settings.mode == 'full' and FULL_MARKER or OWN_PREFIX
    for _, line in ipairs(lines) do
        unknowns.record_line('treasure', line, 8)
        if current_settings.mode == 'full' then
            line = chat_colors.colorize(line, event, current_settings.chat_colors or {}, action_name)
        end
        local ok, output_error = pcall(function()
            AshitaCore:GetChatManager():AddChatMessage(8, false, prefix .. line)
        end)
        if ok then
            stats.lines_output = stats.lines_output + 1
        else
            stats.last_error = tostring(output_error or 'chat output error')
        end
    end
end

local function audit_decoded_event(event, action_name)
    if not (current_settings and current_settings.capture_all == true) then return end
    local action = event.action or {}
    local actor = event.actor or {}
    for _, target in ipairs(event.targets or {}) do
        local packet_id = tonumber(event.raw and event.raw.packet_id) or 0x028
        unknowns.record_line('decoded', string.format(
            'seq=%d kind=%s category=%s action_id=%d action=%s actor_id=%d actor=%s target_id=%d target=%s message=%d channel=%s outcome=%s amount=%d animation=%d effect=%d scale=%d supported=%s burst=%s status=%s',
            tonumber(event.sequence) or 0,
            tostring(event.kind or ''), tostring(action.category or ''),
            tonumber(action.id) or 0, tostring(action_name or action.name or ''),
            tonumber(actor.server_id) or 0, tostring(actor.name or ''),
            tonumber(target.server_id) or 0, tostring(target.name or ''),
            tonumber(target.message_id) or 0, tostring(target.channel or 'main'),
            tostring(target.outcome or ''), tonumber(target.amount) or 0,
            tonumber(target.animation) or 0, tonumber(target.effect) or 0,
            tonumber(target.scale) or 0, tostring(target.replace_original == true),
            target.magic_burst == nil and 'packet' or tostring(target.magic_burst == true),
            tostring(target.status_name or '')), string.format('0x%03X', packet_id))
    end
end

local function queue_grouped_event(event, action_name, now)
    local aggregation = current_settings.aggregation or {}
    if aggregation.damage ~= true or event.kind == 'cast_start'
            or event.kind == 'ability_ready' or event.kind == 'item_ready' then
        output_event(event, action_name)
        return
    end
    local key = table.concat({
        tostring(event.actor and event.actor.server_id or 0),
        tostring(event.action and event.action.category or ''),
        tostring(event.action and event.action.id or 0),
        tostring(action_name or ''), tostring(event.kind or ''),
    }, '|')
    local group = pending_groups[key]
    if not group then
        group = {
            event = event,
            action_name = action_name,
            deadline = (tonumber(event.timestamp) or now)
                    + ((tonumber(aggregation.window_ms) or 100) / 1000),
        }
        pending_groups[key] = group
        pending_group_order[#pending_group_order + 1] = key
        return
    end
    for _, target in ipairs(event.targets or {}) do
        group.event.targets[#group.event.targets + 1] = target
    end
end

local function flush_grouped_events(now, force)
    local keep = {}
    for _, key in ipairs(pending_group_order) do
        local group = pending_groups[key]
        if group and (force or now >= group.deadline) then
            output_event(group.event, group.action_name)
            pending_groups[key] = nil
        elseif group then
            keep[#keep + 1] = key
        end
    end
    pending_group_order = keep
end

function combat.on_text_in(_event)
    if type(_event) ~= 'table' then return false end
    local raw_message = _event.message
    local message = _event.message_modified or raw_message
    if combat.is_own_line(message) then return false end
    local has_game_parameter = type(raw_message) == 'string'
            and (raw_message:find(string.char(0x1E), 1, true)
                or raw_message:find(string.char(0x1F), 1, true))
    if _event.injected ~= true and chatutil.is_player_text_mode(_event.mode) and not has_game_parameter then
        return false
    end
    unknowns.record_line(_event.injected == true and 'addon' or 'original',
        chatutil.strip(message), _event.mode)
    return false
end

function combat.on_tick(_now)
    unknowns.flush(_now, false)
    if not combat.is_visual_enabled() then
        clear_pending_visual()
        pending_groups = {}
        pending_group_order = {}
        return
    end
    -- Amortize the entity cache over frames. This restores enemy names needed
    -- for safe replacement without the former one-frame global scan.
    entities.scan(32)
    local now = tonumber(_now) or 0
    local debug_changed = last_debug_packets ~= stats.packets_028 or last_debug_all ~= stats.packets_all
    if (FORCE_DIAGNOSTICS or current_settings.diagnostics == true)
            and debug_changed and (last_debug_all < 0 or (now - last_debug_at) >= 1.0) then
        last_debug_packets = stats.packets_028
        last_debug_all = stats.packets_all
        last_debug_at = now
        local debug_line = string.format('active mode=%s all=%d last_id=0x%03X action028=%d decoded=%d errors=%d queued=%d output=%d last=%s',
            tostring(current_settings.mode), stats.packets_all, stats.last_packet_id, stats.packets_028,
            stats.decoded, stats.decode_errors, stats.queued, stats.lines_output,
            stats.last_error ~= '' and stats.last_error or 'none')
        pcall(function()
            AshitaCore:GetChatManager():AddChatMessage(8, false, DEBUG_PREFIX .. debug_line)
        end)
    end
    local pending_count = pending_visual_size()
    if pending_count == 0 then
        flush_grouped_events(now, false)
        return
    end
    local count = math.min(64, pending_count)
    local batch = {}
    for index = 1, count do
        batch[index] = pending_visual[pending_visual_head + index - 1]
    end
    local refresh_batch = {}
    for _, event in ipairs(batch) do
        if event.kind ~= 'status_wear_off' then
            refresh_batch[#refresh_batch + 1] = event
        end
    end
    if #refresh_batch > 0 then
        entities.refresh(_now, refresh_batch)
    end
    for _ = 1, count do
        local event = pop_pending_visual()
        entities.resolve_event(event)
        magic_burst.annotate(event)
        local action_name = (event.action and event.action.name) or entities.action_name(event)
        audit_decoded_event(event, action_name)
        queue_grouped_event(event, action_name, now)
    end
    flush_grouped_events(now, false)
end

function combat.shutdown()
    if current_settings then
        flush_grouped_events(math.huge, true)
    end
    subscribers = {}
    current_settings = nil
    clear_pending_visual()
    pending_groups = {}
    pending_group_order = {}
    last_debug_packets = -1
    last_debug_all = -1
    last_debug_at = -100
    unknowns.shutdown()
    magic_burst.reset()
end

return combat
