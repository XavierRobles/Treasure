local decoder = {}

local function new_reader(data)
    return {
        data = data,
        bit = 40, -- Ashita packet header is five bytes.
        limit = #data * 8,
    }
end

local function read_bits(reader, count)
    if count < 0 or (reader.bit + count) > reader.limit then
        return nil
    end
    local value = 0
    local weight = 1
    for _ = 1, count do
        local byte_index = math.floor(reader.bit / 8) + 1
        local bit_index = reader.bit % 8
        local byte = string.byte(reader.data, byte_index)
        if byte == nil then
            return nil
        end
        local bit_value = math.floor(byte / (2 ^ bit_index)) % 2
        value = value + (bit_value * weight)
        weight = weight * 2
        reader.bit = reader.bit + 1
    end
    return value
end

local function required(reader, count, field)
    local value = read_bits(reader, count)
    if value == nil then
        error('truncated 0x028 field: ' .. field)
    end
    return value
end

local function decode_result(reader)
    local result = {
        reaction = required(reader, 3, 'reaction'),
        kind = required(reader, 2, 'kind'),
        animation = required(reader, 12, 'animation'),
        effect = required(reader, 5, 'effect'),
        scale = required(reader, 5, 'scale'),
        param = required(reader, 17, 'param'),
    }
    result._message_bit = reader.bit
    result.message_id = required(reader, 10, 'message_id')
    result.unknown = required(reader, 31, 'unknown')

    result.has_additional_effect = required(reader, 1, 'has_additional_effect') == 1
    if result.has_additional_effect then
        result.additional_effect = {
            animation = required(reader, 6, 'additional_animation'),
            effect = required(reader, 4, 'additional_effect'),
            param = required(reader, 17, 'additional_param'),
        }
        result.additional_effect._message_bit = reader.bit
        result.additional_effect.message_id = required(reader, 10, 'additional_message')
    end

    result.has_spike_effect = required(reader, 1, 'has_spike_effect') == 1
    if result.has_spike_effect then
        result.spike_effect = {
            animation = required(reader, 6, 'spike_animation'),
            effect = required(reader, 4, 'spike_effect'),
            param = required(reader, 14, 'spike_param'),
        }
        result.spike_effect._message_bit = reader.bit
        result.spike_effect.message_id = required(reader, 10, 'spike_message')
    end
    return result
end

local function clear_bits(bytes, offset, count)
    for bit = offset, offset + count - 1 do
        local byte_index = math.floor(bit / 8) + 1
        local bit_index = bit % 8
        local value = bytes[byte_index]
        if value == nil then return false end
        local mask = 2 ^ bit_index
        if math.floor(value / mask) % 2 == 1 then
            bytes[byte_index] = value - mask
        end
    end
    return true
end

function decoder.suppress_messages(data, action, should_suppress)
    if type(data) ~= 'string' or type(action) ~= 'table' then
        return nil, 'invalid action suppression input'
    end
    local bytes = { string.byte(data, 1, #data) }
    for _, target in ipairs(action.targets or {}) do
        for _, result in ipairs(target.actions or {}) do
            local allow_main = should_suppress == nil or should_suppress(result.message_id, 'main', result)
            if allow_main and result._message_bit and not clear_bits(bytes, result._message_bit, 10) then
                return nil, 'modified action packet is shorter than the original'
            end
            if result.additional_effect and result.additional_effect._message_bit then
                local allow_additional = should_suppress == nil
                        or should_suppress(result.additional_effect.message_id, 'additional', result.additional_effect)
                if allow_additional and not clear_bits(bytes, result.additional_effect._message_bit, 10) then
                    return nil, 'modified action packet is shorter than the original'
                end
            end
            if result.spike_effect and result.spike_effect._message_bit then
                local allow_spike = should_suppress == nil
                        or should_suppress(result.spike_effect.message_id, 'spike', result.spike_effect)
                if allow_spike and not clear_bits(bytes, result.spike_effect._message_bit, 10) then
                    return nil, 'modified action packet is shorter than the original'
                end
            end
        end
    end
    local chars = {}
    for index = 1, #bytes do
        chars[index] = string.char(bytes[index])
    end
    return table.concat(chars)
end

function decoder.decode_action(data)
    if type(data) ~= 'string' or #data < 19 or string.byte(data, 1) ~= 0x28 then
        return nil, 'not a valid 0x028 packet'
    end

    local ok, result = pcall(function()
        local reader = new_reader(data)
        local action = {
            actor_id = required(reader, 32, 'actor_id'),
            target_count = required(reader, 6, 'target_count'),
            reserved = required(reader, 4, 'reserved'),
            category = required(reader, 4, 'category'),
            param = required(reader, 32, 'param'),
            recast = required(reader, 32, 'recast'),
            targets = {},
        }

        if action.target_count > 64 then
            error('invalid 0x028 target count')
        end
        for target_index = 1, action.target_count do
            local target = {
                server_id = required(reader, 32, 'target_id'),
                action_count = required(reader, 4, 'action_count'),
                actions = {},
            }
            if target.action_count > 15 then
                error('invalid 0x028 action count')
            end
            for action_index = 1, target.action_count do
                target.actions[action_index] = decode_result(reader)
            end
            action.targets[target_index] = target
        end
        action.bits_read = reader.bit
        return action
    end)

    if not ok then
        return nil, tostring(result)
    end
    return result
end

return decoder
