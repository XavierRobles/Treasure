local action_message = {}

local function read_u16_le(data, offset)
    local b1, b2 = data:byte(offset + 1, offset + 2)
    if b1 == nil or b2 == nil then return nil end
    return b1 + (b2 * 0x100)
end

local function read_u32_le(data, offset)
    local b1, b2, b3, b4 = data:byte(offset + 1, offset + 4)
    if b1 == nil or b2 == nil or b3 == nil or b4 == nil then return nil end
    return b1 + (b2 * 0x100) + (b3 * 0x10000) + (b4 * 0x1000000)
end

function action_message.parse(data)
    if type(data) ~= 'string' or #data < 0x1A then return nil end
    return {
        actor_id = read_u32_le(data, 0x04),
        target_id = read_u32_le(data, 0x08),
        param = read_u32_le(data, 0x0C),
        param2 = read_u32_le(data, 0x10),
        actor_index = read_u16_le(data, 0x14),
        target_index = read_u16_le(data, 0x16),
        message_id = (read_u16_le(data, 0x18) or 0) % 0x8000,
    }
end

return action_message
