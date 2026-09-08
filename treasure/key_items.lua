local key_items = {}
local bit = require('bit')

local TRACKED_IDS = {
    [349] = true, -- White Card
    [350] = true, -- Red Card
    [351] = true, -- Black Card
    [734] = true, -- Cosmo-Cleanse
}

local held = {}
local tables_seen = {}

local function u16le(data, offset)
    local b1, b2 = data:byte(offset, offset + 1)
    return b1 + (b2 * 0x100)
end

local function u32le(data, offset)
    local b1, b2, b3, b4 = data:byte(offset, offset + 3)
    return b1 + (b2 * 0x100) + (b3 * 0x10000) + (b4 * 0x1000000)
end

function key_items.reset()
    held = {}
    tables_seen = {}
end

function key_items.has(id)
    id = tonumber(id)
    if not id or not TRACKED_IDS[id] then
        return nil
    end

    local table_type = math.floor(id / 512)
    if not tables_seen[table_type] then
        return nil
    end
    return held[id] == true
end

function key_items.on_packet_in(packet)
    if not packet or packet.injected then
        return false
    end

    if packet.id == 0x00A then
        key_items.reset()
        return false
    elseif packet.id == 0x00B then
        local data = packet.data
        if type(data) == 'string' and data:byte(0x04 + 1) == 1 then
            key_items.reset()
        end
        return false
    elseif packet.id ~= 0x055 then
        return false
    end

    local data = type(packet.data) == 'string' and packet.data or packet.data_modified
    if type(data) ~= 'string' or #data < 0x88 then
        return false
    end

    local table_type = u16le(data, 0x84 + 1)
    if table_type ~= 0 and table_type ~= 1 then
        return false
    end

    local updated = {}
    for id in pairs(TRACKED_IDS) do
        if math.floor(id / 512) == table_type then
            local relative_id = id % 512
            local dword_index = math.floor(relative_id / 32)
            local bit_offset = relative_id % 32
            local value = u32le(data, 0x04 + 1 + (dword_index * 4))
            updated[id] = bit.band(value, bit.lshift(1, bit_offset)) ~= 0
        end
    end

    for id, value in pairs(updated) do
        held[id] = value
    end
    tables_seen[table_type] = true
    return true
end

return key_items
