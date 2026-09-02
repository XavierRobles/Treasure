local M = {}

local WINDOW_SECONDS = 10
local SKILLCHAIN = {}
for message_id = 288, 302 do SKILLCHAIN[message_id] = true end
for message_id = 385, 398 do SKILLCHAIN[message_id] = true end
for message_id = 767, 770 do SKILLCHAIN[message_id] = true end

local BURST = {
    [252] = true, [265] = true, [268] = true, [269] = true, [271] = true,
    [272] = true, [274] = true, [275] = true, [750] = true, [751] = true,
}

local windows = {}

local function target_id(target)
    local value = tonumber(target and target.server_id) or 0
    return value > 0 and value or nil
end

function M.reset()
    windows = {}
end

-- Horizon can copy a primary target's Magic Burst message id to every target
-- of an AoE spell. Only override the packet when an observed skillchain window
-- proves that some, but not all, of those targets can burst.
function M.annotate(event)
    if type(event) ~= 'table' then return event end
    local now = tonumber(event.timestamp) or 0
    for id, expires in pairs(windows) do
        if expires < now then windows[id] = nil end
    end

    for _, target in ipairs(event.targets or {}) do
        local message_id = tonumber(target.message_id) or 0
        local id = target_id(target)
        if id and SKILLCHAIN[message_id] then
            windows[id] = now + WINDOW_SECONDS
        end
    end

    local burst_targets = {}
    local active_count = 0
    for _, target in ipairs(event.targets or {}) do
        if BURST[tonumber(target.message_id) or 0] then
            burst_targets[#burst_targets + 1] = target
            local id = target_id(target)
            if id and windows[id] and windows[id] >= now then
                active_count = active_count + 1
            end
        end
    end
    if #burst_targets > 1 and active_count > 0 and active_count < #burst_targets then
        for _, target in ipairs(burst_targets) do
            local id = target_id(target)
            target.magic_burst = id ~= nil and windows[id] ~= nil and windows[id] >= now
        end
    end
    return event
end

return M
