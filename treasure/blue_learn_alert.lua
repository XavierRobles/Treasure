local M = {}

local function strip_message(value)
    local message = tostring(value or '')
    message = message:gsub('[\30\31\127].', '')
    message = message:gsub('%c', ' ')
    message = message:gsub('%s+', ' ')
    return message:gsub('^%s+', ''):gsub('%s+$', '')
end

local function read_u16_le(data, offset)
    local b1, b2 = data:byte(offset + 1, offset + 2)
    if b1 == nil or b2 == nil then
        return nil
    end
    return b1 + (b2 * 0x100)
end

local function read_u32_le(data, offset)
    local b1, b2, b3, b4 = data:byte(offset + 1, offset + 4)
    if b1 == nil or b2 == nil or b3 == nil or b4 == nil then
        return nil
    end
    return b1 + (b2 * 0x100) + (b3 * 0x10000) + (b4 * 0x1000000)
end

function M.parse(data)
    if type(data) ~= 'string' or #data < 0x1A then
        return nil
    end

    return {
        spell_id = read_u32_le(data, 0x0C),
        sender_index = read_u16_le(data, 0x14),
        target_index = read_u16_le(data, 0x16),
        message_id = read_u16_le(data, 0x18),
    }
end

function M.learned_spell(event, player_index)
    if type(event) ~= 'table' or event.id ~= 0x029 or player_index == nil then
        return nil
    end

    local message = M.parse(event.data_modified or event.data)
    if message == nil or (message.message_id ~= 23 and message.message_id ~= 419) then
        return nil
    end
    if message.sender_index ~= player_index or message.target_index ~= player_index then
        return nil
    end
    return message.spell_id
end

function M.learned_spell_from_text(value, player_name)
    player_name = tostring(player_name or '')
    if player_name == '' then
        return nil
    end

    local actor, spell_name = strip_message(value):match('^(.+) learns (.+)!$')
    if actor == nil or actor:lower() ~= player_name:lower() then
        return nil
    end
    return spell_name
end

return M
