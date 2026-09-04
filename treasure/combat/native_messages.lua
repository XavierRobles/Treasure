local native_messages = {}

-- Preserve these messages in 0x028 so the client can render floating text.
local non_block_ids = {
    1, 2, 7, 14, 15, 24, 25, 26, 30, 31, 32, 33, 44, 63, 67, 69, 70, 77,
    102, 103, 110, 122, 132, 152, 157, 158, 161, 162, 163, 165, 167, 185,
    187, 188, 196, 197, 223, 224, 225, 226, 227, 228, 229, 238, 245, 252,
    263, 264, 265, 274, 275, 276, 281, 282, 288, 289, 290, 291, 292, 293,
    294, 295, 296, 297, 298, 299, 300, 301, 302, 306, 317, 318, 324, 352,
    353, 354, 357, 358, 366, 367, 373, 379, 382, 383, 384, 385, 386, 387,
    388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 409, 413, 451,
    452, 454, 522, 535, 536, 537, 539, 576, 577, 587, 588, 592, 603, 606,
    648, 650, 651, 658, 732, 736, 746, 747, 748, 749, 750, 751, 752, 753,
    767, 768, 769, 770, 781,
}

local combat_modes = {
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
    40, 41, 42, 43, 56, 57, 59, 60, 61, 63, 104, 109, 114, 162, 163,
    164, 165, 181, 185, 186, 187, 188,
}

local function as_set(values)
    local result = {}
    for _, value in ipairs(values) do result[value] = true end
    return result
end

local non_block = as_set(non_block_ids)
local block_mode = as_set(combat_modes)

function native_messages.must_preserve(message_id)
    return non_block[tonumber(message_id) or 0] == true
end

function native_messages.is_combat_mode(mode)
    mode = tonumber(mode)
    if mode == nil then return false end
    return block_mode[mode] == true
end

return native_messages
