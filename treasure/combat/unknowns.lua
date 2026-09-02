local persist = require('persist')

local unknowns = {}

local MAX_SIGNATURES = 4096
local MAX_SAMPLES = 8
local MAX_PACKET_SAMPLES = 4
local FLUSH_INTERVAL = 30
local AUDIT_WRITE_INTERVAL = 0.5
local MAX_AUDIT_BUFFER_BYTES = 64 * 1024
local MAX_AUDIT_BYTES = 8 * 1024 * 1024
local MAX_AUDIT_ARCHIVES = 2

local enabled = true
local capture_all = false
local path = nil
local audit_path = nil
local audit_bytes = 0
local audit_pending = {}
local audit_pending_bytes = 0
local last_audit_flush = 0
local dirty = false
local last_flush = 0
local state = nil
local audit_size
local flush_audit

local function fresh_state()
    return {
        schema_version = 2,
        total_observations = 0,
        dropped_signatures = 0,
        signature_count = 0,
        records = {},
    }
end

local function normalize(loaded)
    local result = type(loaded) == 'table' and loaded or fresh_state()
    result.schema_version = 2
    result.total_observations = math.max(0, tonumber(result.total_observations) or 0)
    result.dropped_signatures = math.max(0, tonumber(result.dropped_signatures) or 0)
    if type(result.records) ~= 'table' then result.records = {} end
    local count = 0
    for _, entry in pairs(result.records) do
        count = count + 1
        if entry.supported_observations == nil and entry.unsupported_observations == nil then
            entry.supported_observations = 0
            entry.unsupported_observations = math.max(0, tonumber(entry.count) or 0)
            entry.last_supported = false
        else
            entry.supported_observations = math.max(0, tonumber(entry.supported_observations) or 0)
            entry.unsupported_observations = math.max(0, tonumber(entry.unsupported_observations) or 0)
        end
    end
    result.signature_count = count
    return result
end

local function serialize(value, indent)
    indent = indent or 0
    local kind = type(value)
    if kind == 'number' or kind == 'boolean' then return tostring(value) end
    if kind == 'string' then return string.format('%q', value) end
    if kind ~= 'table' then return 'nil' end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local pad = string.rep(' ', indent)
    local child = string.rep(' ', indent + 2)
    local out = { '{' }
    for _, key in ipairs(keys) do
        out[#out + 1] = string.format('\n%s[%s] = %s,', child, serialize(key), serialize(value[key], indent + 2))
    end
    if #keys > 0 then out[#out + 1] = '\n' .. pad end
    out[#out + 1] = '}'
    return table.concat(out)
end

local function record_count()
    return math.max(0, tonumber(state.signature_count) or 0)
end

local function add_sample(samples, amount)
    amount = tonumber(amount) or 0
    for _, value in ipairs(samples) do
        if value == amount then return end
    end
    if #samples < MAX_SAMPLES then samples[#samples + 1] = amount end
end

local function to_hex(data)
    if type(data) ~= 'string' then return '' end
    return (data:gsub('.', function(char) return string.format('%02X', string.byte(char)) end))
end

local function add_packet_sample(samples, original_data, modified_data)
    local original_hex = to_hex(original_data)
    if original_hex == '' then return end
    local modified_hex = to_hex(modified_data)
    if modified_hex == original_hex then modified_hex = '' end
    local signature = original_hex .. '|' .. modified_hex
    for _, sample in ipairs(samples) do
        if tostring(sample.original_hex or '') .. '|' .. tostring(sample.modified_hex or '') == signature then return end
    end
    if #samples < MAX_PACKET_SAMPLES then
        samples[#samples + 1] = {
            original_hex = original_hex,
            modified_hex = modified_hex,
        }
    end
end

function unknowns.configure(capture_enabled, character_dir, capture_all_enabled)
    capture_all = capture_all_enabled == true
    enabled = capture_enabled ~= false or capture_all
    if type(character_dir) == 'string' and character_dir ~= '' then
        local next_path = character_dir .. 'combat_unknown.lua'
        local next_audit_path = character_dir .. 'combat_audit.tsv'
        if next_path ~= path then
            unknowns.flush(nil, true)
            path = next_path
            audit_path = next_audit_path
            audit_bytes = audit_size()
            audit_pending = {}
            audit_pending_bytes = 0
            last_audit_flush = 0
            state = normalize(persist.load_table(path))
            dirty = false
            last_flush = 0
        end
    elseif state == nil then
        state = fresh_state()
    end
end

function unknowns.record(event, target, original_data, modified_data, supported)
    if not enabled or not path or type(event) ~= 'table' or type(target) ~= 'table' then return false end
    if supported == true and not capture_all then return false end
    local message_id = tonumber(target.message_id) or 0
    if message_id == 0 then return false end
    state = state or fresh_state()
    local action = event.action or {}
    local raw = event.raw or {}
    local key = table.concat({
        tostring(tonumber(raw.category) or 0),
        tostring(tonumber(action.id) or 0),
        tostring(message_id),
        tostring(target.channel or 'main'),
        tostring(target.outcome or 'unknown'),
        tostring(tonumber(target.animation) or 0),
        tostring(tonumber(target.effect) or 0),
        tostring(tonumber(target.scale) or 0),
    }, '|')
    local entry = state.records[key]
    if not entry then
        if record_count() >= MAX_SIGNATURES then
            state.dropped_signatures = state.dropped_signatures + 1
            state.total_observations = state.total_observations + 1
            dirty = true
            return false
        end
        entry = {
            count = 0,
            first_seen = os.time(),
            last_seen = os.time(),
            category = tostring(action.category or 'unknown'),
            category_id = tonumber(raw.category) or 0,
            action_id = tonumber(action.id) or 0,
            action_name = tostring(action.name or ''),
            event_kind = tostring(event.kind or ''),
            message_id = message_id,
            channel = tostring(target.channel or 'main'),
            outcome = tostring(target.outcome or 'unknown'),
            animation = tonumber(target.animation) or 0,
            effect = tonumber(target.effect) or 0,
            scale = tonumber(target.scale) or 0,
            result_kind = tonumber(target.result_kind) or 0,
            raw_unknown = tonumber(target.raw_unknown) or 0,
            recast = tonumber(raw.recast) or 0,
            packet_target_count = tonumber(raw.target_count) or 0,
            zone_id = tonumber(raw.zone_id) or 0,
            actor_server_id = tonumber(event.actor and event.actor.server_id) or 0,
            target_server_id = tonumber(target.server_id) or 0,
            has_additional_effect = event.flags and event.flags.additional_effect == true or false,
            has_spike_effect = event.flags and event.flags.spike_effect == true or false,
            amount_samples = {},
            packet_samples = {},
            supported_observations = 0,
            unsupported_observations = 0,
        }
        state.records[key] = entry
        state.signature_count = record_count() + 1
    end
    entry.count = math.max(0, tonumber(entry.count) or 0) + 1
    entry.last_seen = os.time()
    entry.last_supported = supported == true
    if supported == true then
        entry.supported_observations = math.max(0, tonumber(entry.supported_observations) or 0) + 1
    else
        entry.unsupported_observations = math.max(0, tonumber(entry.unsupported_observations) or 0) + 1
    end
    add_sample(entry.amount_samples, target.amount)
    add_packet_sample(entry.packet_samples, original_data, modified_data)
    state.total_observations = state.total_observations + 1
    dirty = true
    return true
end

local function audit_escape(value)
    local escaped = tostring(value or '')
    escaped = escaped:gsub('\\', '\\\\')
    escaped = escaped:gsub('\t', '\\t')
    escaped = escaped:gsub('\r', '\\r')
    escaped = escaped:gsub('\n', '\\n')
    return escaped
end

audit_size = function()
    if not audit_path then return 0 end
    local file = io.open(audit_path, 'rb')
    if not file then return 0 end
    local size = file:seek('end') or 0
    file:close()
    return tonumber(size) or 0
end

local function rotate_audit_if_needed()
    if not audit_path or audit_bytes < MAX_AUDIT_BYTES then return end
    os.remove(audit_path .. '.' .. tostring(MAX_AUDIT_ARCHIVES))
    for index = MAX_AUDIT_ARCHIVES - 1, 1, -1 do
        os.rename(audit_path .. '.' .. tostring(index),
                audit_path .. '.' .. tostring(index + 1))
    end
    if os.rename(audit_path, audit_path .. '.1') then
        audit_bytes = 0
    else
        audit_bytes = audit_size()
    end
end

function unknowns.record_line(source, message, mode)
    if not capture_all or not audit_path or type(message) ~= 'string' or message == '' then return false end
    local line = table.concat({
        tostring(os.time()), audit_escape(source), audit_escape(mode), audit_escape(message),
    }, '\t') .. '\n'
    audit_pending[#audit_pending + 1] = line
    audit_pending_bytes = audit_pending_bytes + #line
    return true
end

flush_audit = function(now, force)
    if audit_pending_bytes == 0 or not audit_path then return true end
    now = tonumber(now) or os.clock()
    if not force and audit_pending_bytes < MAX_AUDIT_BUFFER_BYTES
            and last_audit_flush > 0 and (now - last_audit_flush) < AUDIT_WRITE_INTERVAL then
        return false
    end
    rotate_audit_if_needed()
    local file = io.open(audit_path, 'ab')
    if not file then return false end
    local data = table.concat(audit_pending)
    local ok = file:write(data)
    local closed = file:close()
    if ok == nil or closed == nil then return false end
    audit_bytes = audit_bytes + #data
    audit_pending = {}
    audit_pending_bytes = 0
    last_audit_flush = now
    return true
end

function unknowns.flush(now, force)
    local audit_ok = flush_audit(now, force == true)
    if not dirty or not path or not state then return audit_ok end
    -- A complete audit can hold thousands of signatures and packet samples.
    -- Serializing that table on Ashita's render tick causes a periodic hitch;
    -- its chronological TSV is still flushed continuously, while the large
    -- aggregate snapshot is persisted only during reload/shutdown.
    if capture_all and not force then return audit_ok end
    now = tonumber(now) or os.time()
    if not force and last_flush > 0 and (now - last_flush) < FLUSH_INTERVAL then return false end
    local ok = persist.write_atomic(path, 'return ' .. serialize(state) .. '\n')
    if ok then
        dirty = false
        last_flush = now
        return audit_ok
    end
    return false
end

function unknowns.get_stats()
    state = state or fresh_state()
    local unsupported_signatures = 0
    local supported_observations = 0
    local unsupported_observations = 0
    for _, entry in pairs(state.records or {}) do
        local unsupported = math.max(0, tonumber(entry.unsupported_observations) or 0)
        if unsupported > 0 then unsupported_signatures = unsupported_signatures + 1 end
        supported_observations = supported_observations
                + math.max(0, tonumber(entry.supported_observations) or 0)
        unsupported_observations = unsupported_observations + unsupported
    end
    return {
        enabled = enabled,
        capture_all = capture_all,
        signatures = record_count(),
        observations = tonumber(state.total_observations) or 0,
        supported_observations = supported_observations,
        unsupported_signatures = unsupported_signatures,
        unsupported_observations = unsupported_observations,
        dropped = tonumber(state.dropped_signatures) or 0,
        path = path or '',
        audit_path = audit_path or '',
        dirty = dirty,
    }
end

function unknowns.shutdown()
    unknowns.flush(nil, true)
    path = nil
    audit_path = nil
    audit_bytes = 0
    audit_pending = {}
    audit_pending_bytes = 0
    last_audit_flush = 0
    state = nil
    capture_all = false
    dirty = false
    last_flush = 0
end

return unknowns
