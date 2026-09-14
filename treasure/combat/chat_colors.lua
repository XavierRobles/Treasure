local chat_colors = {}

local RESET_INDEX = 1
local PALETTE = {
    { 1, 'White', { 1.00, 1.00, 1.00, 1.00 } },
    { 2, 'Lawn green', { 0.49, 1.00, 0.28, 1.00 } },
    { 3, 'Slate blue', { 0.48, 0.41, 0.93, 1.00 } },
    { 5, 'Magenta', { 1.00, 0.25, 1.00, 1.00 } },
    { 6, 'Cyan', { 0.25, 0.95, 1.00, 1.00 } },
    { 7, 'Moccasin', { 1.00, 0.89, 0.71, 1.00 } },
    { 8, 'Coral', { 1.00, 0.50, 0.31, 1.00 } },
    { 65, 'Dim grey', { 0.41, 0.41, 0.41, 1.00 } },
    { 67, 'Grey', { 0.67, 0.67, 0.67, 1.00 } },
    { 68, 'Salmon', { 0.98, 0.50, 0.45, 1.00 } },
    { 69, 'Intense yellow', { 1.00, 0.92, 0.18, 1.00 } },
    { 71, 'Royal blue', { 0.25, 0.41, 0.88, 1.00 } },
    { 73, 'Violet', { 0.93, 0.51, 0.93, 1.00 } },
    { 76, 'Tomato red', { 1.00, 0.25, 0.18, 1.00 } },
    { 79, 'Lime', { 0.25, 1.00, 0.25, 1.00 } },
    { 81, 'Purple', { 0.73, 0.33, 0.83, 1.00 } },
    { 82, 'Aqua', { 0.20, 0.90, 0.95, 1.00 } },
    { 83, 'Spring green', { 0.20, 1.00, 0.50, 1.00 } },
    { 89, 'Medium purple', { 0.58, 0.44, 0.86, 1.00 } },
    { 96, 'Pale yellow', { 0.98, 0.95, 0.65, 1.00 } },
}

local function escape_pattern(value)
    return tostring(value or ''):gsub('([^%w])', '%%%1')
end

local function entry_enabled(entry)
    return type(entry) == 'table' and entry.enabled ~= false
end

local function colored(entry, text)
    if not entry_enabled(entry) or text == '' then
        return text
    end
    local index = math.max(1, math.min(255, math.floor((tonumber(entry.index) or RESET_INDEX) + 0.5)))
    return string.char(0x1E, index) .. text .. string.char(0x1E, RESET_INDEX)
end

local function add_token(state, text, entry)
    state.count = state.count + 1
    local token = string.format('\7TC%03d\7', state.count)
    state.values[token] = colored(entry, text)
    return token
end

local function replace_pattern(line, pattern, state, entry)
    if not entry_enabled(entry) then return line end
    return line:gsub(pattern, function(text)
        return add_token(state, text, entry)
    end)
end

local function color_status_verb(line, verb, state, action_entry, status_entry)
    return line:gsub(verb .. '%s+([^+]+)', function(effect_and_space)
        local effect = effect_and_space:gsub('%s+$', '')
        local trailing_space = effect_and_space:sub(#effect + 1)
        return add_token(state, verb, action_entry) .. ' '
                .. add_token(state, effect, status_entry) .. trailing_space
    end)
end

local function color_removed_status(line, state, action_entry, status_entry)
    return line:gsub('([^%s:+][^:+]-)%s+removed', function(effect)
        return add_token(state, effect, status_entry) .. ' '
                .. add_token(state, 'removed', action_entry)
    end)
end

local function color_worn_status(line, state, action_entry, status_entry)
    return line:gsub('([^%s:+][^:+]-)%s+wears off', function(effect)
        return add_token(state, effect, status_entry) .. ' '
                .. add_token(state, 'wears off', action_entry)
    end)
end

local function entity_color(cfg, entity)
    local slot = tonumber(entity and entity.party_slot)
    if slot and slot >= 1 and slot <= 6 then
        return cfg['p' .. tostring(slot)]
    end
    local relation = entity and entity.relation
    if relation == 'enemy' or relation == 'unknown' then return cfg.enemy end
    return cfg.other
end

local DECORATION = {
    brackets = { '[', ']' }, parentheses = { '(', ')' }, braces = { '{', '}' },
    quotes = { '"', '"' }, angles = { '<', '>' },
}

local function color_decoration(line, value, marks, state, delimiter_entry, value_entry, limit)
    value = tostring(value or '')
    if value == '' or not marks then return line end
    local marks_entry = entry_enabled(delimiter_entry) and delimiter_entry or value_entry
    local pattern = escape_pattern(marks[1] .. value .. marks[2])
    return line:gsub(pattern, function()
        return add_token(state, marks[1], marks_entry)
                .. add_token(state, value, value_entry)
                .. add_token(state, marks[2], marks_entry)
    end, limit)
end

local function entity_label(entity, display)
    local label = tostring(entity and entity.name or '')
    if display and display.pet_owner == true and entity and entity.owner_name and entity.owner_name ~= '' then
        label = label .. ' (' .. tostring(entity.owner_name) .. ')'
    end
    return label
end

function chat_colors.colorize(line, event, cfg, action_name, decoration, display)
    if type(line) ~= 'string' or type(cfg) ~= 'table' or cfg.enabled == false then
        return line
    end
    local state = { count = 0, values = {} }

    local marks = DECORATION[decoration and decoration.style]
    if marks then
        if decoration.actor == true then
            line = color_decoration(line, entity_label(event and event.actor, display), marks, state,
                    cfg.decoration_actor, entity_color(cfg, event and event.actor), 1)
        end
        if decoration.action == true then
            line = color_decoration(line, action_name, marks, state, cfg.decoration_action, cfg.action)
        end
        for _, target in ipairs((event and event.targets) or {}) do
            if decoration.target == true then
                line = color_decoration(line, entity_label(target, display), marks, state,
                        cfg.decoration_target, entity_color(cfg, target), 1)
            end
            local status = target and target.status_name
            local wrapped = status and (marks[1] .. status .. marks[2]) or ''
            if decoration.effect_gained == true and line:find('gains ' .. wrapped, 1, true) then
                line = color_decoration(line, status, marks, state,
                        cfg.decoration_effect_gained, cfg.status, 1)
            end
            if decoration.effect_lost == true
                    and (line:find(wrapped .. ' removed', 1, true)
                        or line:find(wrapped .. ' wears off', 1, true)) then
                line = color_decoration(line, status, marks, state,
                        cfg.decoration_effect_lost, cfg.status, 1)
            end
        end
    end

    line = replace_pattern(line, 'critical: %d+ damage', state, cfg.critical)
    line = replace_pattern(line, '%+%d+ HP', state, cfg.healing)
    line = replace_pattern(line, '%+%d+ MP', state, cfg.mp)
    line = replace_pattern(line, '%d+ HP drained', state, cfg.healing)
    line = replace_pattern(line, '%d+ MP drained', state, cfg.healing)
    line = replace_pattern(line, '%d+ damage', state, cfg.damage)
    line = replace_pattern(line, 'spikes:', state, cfg.action)
    line = replace_pattern(line, 'starts casting', state, cfg.action)
    line = replace_pattern(line, 'readies', state, cfg.action)
    line = color_status_verb(line, 'gains', state, cfg.action, cfg.status)
    line = color_status_verb(line, 'loses', state, cfg.action, cfg.status)
    line = color_removed_status(line, state, cfg.action, cfg.status)
    line = color_worn_status(line, state, cfg.action, cfg.status)
    line = replace_pattern(line, 'resisted', state, cfg.status)
    line = replace_pattern(line, 'no effect', state, cfg.status)
    line = replace_pattern(line, 'TP reduced to %d+', state, cfg.status)
    line = replace_pattern(line, 'roll %d+', state, cfg.status)
    line = replace_pattern(line, 'attacks enhanced', state, cfg.status)
    line = replace_pattern(line, 'is paralyzed', state, cfg.status)
    for _, stat in ipairs({ 'STR', 'DEX', 'VIT', 'AGI', 'INT', 'MND', 'CHR', 'Accuracy' }) do
        line = replace_pattern(line, stat .. ' drained', state, cfg.status)
    end

    local action = tostring(action_name or '')
    if action ~= '' and entry_enabled(cfg.action) then
        line = line:gsub(escape_pattern(action), function(text)
            return add_token(state, text, cfg.action)
        end)
    end

    local seen = {}
    local entities = { event and event.actor }
    for _, target in ipairs((event and event.targets) or {}) do entities[#entities + 1] = target end
    for _, entity in ipairs(entities) do
        local name = tostring(entity and entity.name or '')
        if name ~= '' and not seen[name] then
            seen[name] = true
            local entry = entity_color(cfg, entity)
            if entry_enabled(entry) then
                line = line:gsub(escape_pattern(name), function(text)
                    return add_token(state, text, entry)
                end)
            end
        end
    end

    for index = state.count, 1, -1 do
        local token = string.format('\7TC%03d\7', index)
        local value = state.values[token]
        line = line:gsub(token, function() return value end)
    end
    return line
end

function chat_colors.palette()
    return PALETTE
end

function chat_colors.palette_name(index)
    index = tonumber(index) or RESET_INDEX
    for _, entry in ipairs(PALETTE) do
        if entry[1] == index then return entry[2] end
    end
    return 'Palette ' .. tostring(index)
end

function chat_colors.preview_rgba(entry, fallback)
    local index = type(entry) == 'table' and tonumber(entry.index) or nil
    for _, option in ipairs(PALETTE) do
        if option[1] == index then return option[3] end
    end
    return fallback or { 1, 1, 1, 1 }
end

return chat_colors
