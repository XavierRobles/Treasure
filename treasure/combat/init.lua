local combat = {}
local decoder = require('combat.decoder')
local action_message = require('combat.action_message')
local event_builder = require('combat.event')
local entities = require('combat.entities')
local formatter = require('combat.formatter')
local magic_burst = require('combat.magic_burst')
local chat_colors = require('combat.chat_colors')
local timeutil = require('timeutil')
local chatutil = require('chatutil')
local native_messages = require('combat.native_messages')

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
local NATIVE_END = string.char(0x7F, 0x31)
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

local function is_native_action_line(message)
    if type(message) ~= 'string' or message:sub(-#NATIVE_END) ~= NATIVE_END then
        return false
    end
    local has_parameter = message:find(string.char(0x1E), 1, true) ~= nil
            or message:find(string.char(0x1F), 1, true) ~= nil
    return not has_parameter or message:find(string.char(0x1E), 1, true) ~= nil
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
    if not combat.is_visual_enabled() then
        clear_pending_visual()
        pending_groups = {}
        pending_group_order = {}
    end
end

function combat.set_character_context(_character_dir)
    magic_burst.reset()
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
                )
end

function combat.get_stats()
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
        if parsed == nil or (parsed.message_id ~= 206 and parsed.message_id ~= 6) then return false end

        local packet_now = timeutil.now()
        local is_wear_off = parsed.message_id == 206
        local structured = {
            schema_version = 1,
            timestamp = packet_now,
            source = 'packet_0x029',
            kind = is_wear_off and 'status_wear_off' or 'action_use',
            actor = { server_id = is_wear_off and parsed.target_id or parsed.actor_id },
            action = is_wear_off
                    and { category = 'status', id = parsed.param, name = 'status wear off' }
                    or { category = 'melee', id = 0, name = 'melee' },
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
        if is_wear_off then
            structured.action.name = target.status_name
        end

        if current_settings.mode == 'full' then
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
        has_visual_target = has_visual_target or target.replace_original
        if target.replace_original and native_messages.must_preserve(message_id) then
            target.preserve_client_message = true
            return false
        end
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
    structured.sequence = sequence
    if has_visual_target then
        push_pending_visual(structured)
        stats.queued = stats.queued + 1
    end
    return true
end

local function output_event(event, action_name)
    local lines = formatter.format(event, current_settings, action_name)
    local prefix = current_settings.mode == 'full' and FULL_MARKER or OWN_PREFIX
    for _, line in ipairs(lines) do
        if current_settings.mode == 'full' then
            local plain_line = line
            local ok_color, colored_line = pcall(chat_colors.colorize, line, event,
                    current_settings.chat_colors or {}, action_name,
                    current_settings.decoration or {}, current_settings.display or {})
            if ok_color and type(colored_line) == 'string' then
                line = colored_line
            else
                line = plain_line
                stats.last_error = tostring(colored_line or 'chat color error')
            end
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

function combat.should_block_native_text(_event)
    if type(_event) ~= 'table' or not combat.is_replacing_chat()
            or _event.injected == true
            or not native_messages.is_combat_mode(_event.mode)
            or not is_native_action_line(_event.message) then
        return false
    end
    _event.blocked = true
    return true
end

function combat.on_text_in(_event)
    if type(_event) ~= 'table' then return false end
    local raw_message = _event.message
    local message = _event.message_modified or raw_message
    if combat.is_own_line(message) then return false end
    local block_native = combat.should_block_native_text(_event)
    local has_game_parameter = type(raw_message) == 'string'
            and (raw_message:find(string.char(0x1E), 1, true)
                or raw_message:find(string.char(0x1F), 1, true))
    if _event.injected ~= true and chatutil.is_player_text_mode(_event.mode) and not has_game_parameter then
        return false
    end
    if block_native then
        _event.blocked = true
        return true
    end
    return false
end

function combat.on_tick(_now)
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
    magic_burst.reset()
end

return combat
