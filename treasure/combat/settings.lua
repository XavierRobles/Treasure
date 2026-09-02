local settings = {}

local DEFAULTS = {
    schema_version = 5,
    enabled = false,
    mode = 'off',
    preset = 'group',
    aggregation = {
        damage = true,
        targets = true,
        sum_damage = true,
        merge_criticals = false,
        window_ms = 100,
    },
    display = {
        pet_owner = true,
        target_count = true,
        target_names = false,
        show_totals = true,
    },
    filters = {
        outgoing_damage = true,
        incoming_damage = true,
        healing = true,
        misses = true,
        status = true,
        casts = true,
        abilities = true,
        items = true,
        defeats = true,
        other_players = false,
    },
    filter_matrix = {
        self = { misses = true, defenses = true, damage_dealt = true, damage_received = true, actions = true, hp_gained = true, status = true },
        party = { misses = true, defenses = true, damage_dealt = true, damage_received = true, actions = true, hp_gained = true, status = true },
        alliance = { misses = true, defenses = true, damage_dealt = true, damage_received = true, actions = true, hp_gained = true, status = true },
        others = { misses = false, defenses = false, damage_dealt = false, damage_received = false, actions = false, hp_gained = false, status = false },
        enemies = { misses = true, defenses = true, damage_dealt = true, damage_received = true, actions = true, hp_gained = true, status = true },
    },
    colors = {
        self = { 0.45, 0.78, 1.00, 1.00 },
        party = { 0.42, 0.92, 0.62, 1.00 },
        alliance = { 0.64, 0.82, 1.00, 1.00 },
        enemy = { 1.00, 0.42, 0.38, 1.00 },
        damage = { 1.00, 0.82, 0.28, 1.00 },
        healing = { 0.35, 1.00, 0.48, 1.00 },
        status = { 0.76, 0.58, 1.00, 1.00 },
        muted = { 0.62, 0.65, 0.70, 1.00 },
    },
    chat_colors = {
        enabled = true,
        p1 = { enabled = true, index = 82 },
        p2 = { enabled = true, index = 2 },
        p3 = { enabled = true, index = 3 },
        p4 = { enabled = true, index = 5 },
        p5 = { enabled = true, index = 7 },
        p6 = { enabled = true, index = 73 },
        enemy = { enabled = true, index = 68 },
        other = { enabled = true, index = 67 },
        damage = { enabled = true, index = 76 },
        healing = { enabled = true, index = 2 },
        action = { enabled = true, index = 69 },
        critical = { enabled = true, index = 8 },
        status = { enabled = true, index = 81 },
    },
    diagnostics = false,
    capture_unknown = true,
    capture_all = false,
}

local MODES = { off = true, full = true }
local PRESETS = { all = true, group = true, compact = true, support = true, custom = true }

local PRESET_FILTERS = {
    all = {
        outgoing_damage = true, incoming_damage = true, healing = true,
        misses = true, status = true, casts = true, abilities = true,
        items = true, defeats = true, other_players = true,
    },
    group = {
        outgoing_damage = true, incoming_damage = true, healing = true,
        misses = true, status = true, casts = true, abilities = true,
        items = true, defeats = true, other_players = false,
    },
    compact = {
        outgoing_damage = true, incoming_damage = true, healing = true,
        misses = true, status = true, casts = false, abilities = true,
        items = false, defeats = true, other_players = false,
    },
    support = {
        outgoing_damage = true, incoming_damage = true, healing = true,
        misses = true, status = true, casts = true, abilities = true,
        items = true, defeats = true, other_players = false,
    },
}

local MATRIX_KEYS = { 'misses', 'defenses', 'damage_dealt', 'damage_received', 'actions', 'hp_gained', 'status' }
local MATRIX_SCOPES = { 'self', 'party', 'alliance', 'others', 'enemies' }

local function matrix_values(default_value, overrides)
    local result = {}
    for _, scope in ipairs(MATRIX_SCOPES) do
        result[scope] = {}
        for _, key in ipairs(MATRIX_KEYS) do
            result[scope][key] = default_value
        end
    end
    for scope, values in pairs(overrides or {}) do
        for key, value in pairs(values) do
            result[scope][key] = value
        end
    end
    return result
end

local PRESET_MATRIX = {
    all = matrix_values(true),
    group = matrix_values(true, {
        others = { misses = false, defenses = false, damage_dealt = false, damage_received = false,
            actions = false, hp_gained = false, status = false },
    }),
    compact = matrix_values(true, {
        self = { misses = false, defenses = false },
        party = { misses = false, defenses = false },
        alliance = { misses = false, defenses = false },
        others = { misses = false, defenses = false, damage_dealt = false, damage_received = false,
            actions = false, hp_gained = false, status = false },
        enemies = { misses = false, defenses = false },
    }),
    support = matrix_values(true, {
        self = { misses = false, defenses = false, damage_dealt = false },
        party = { misses = false, defenses = false, damage_dealt = false },
        alliance = { misses = false, defenses = false, damage_dealt = false },
        others = { misses = false, defenses = false, damage_dealt = false, damage_received = false,
            actions = false, hp_gained = false, status = false },
        enemies = { misses = false, defenses = false },
    }),
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

local function clamp(value, low, high, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback
    end
    return math.max(low, math.min(high, value))
end

local function ensure_table(parent, key)
    if type(parent[key]) ~= 'table' then
        parent[key] = {}
        return true
    end
    return false
end

local function ensure_bool(parent, key, fallback)
    if type(parent[key]) ~= 'boolean' then
        parent[key] = fallback
        return true
    end
    return false
end

local function ensure_color(parent, key, fallback)
    local source = parent[key]
    local is_table = type(source) == 'table'
    local changed = not is_table
    local out = {}
    for i = 1, 4 do
        local raw = is_table and source[i] or nil
        local value = tonumber(raw)
        if value == nil then
            changed = true
            value = fallback[i]
        end
        out[i] = math.max(0, math.min(1, value))
        if raw ~= out[i] then
            changed = true
        end
    end
    if changed then
        parent[key] = out
        return true
    end
    for i = 1, 4 do
        source[i] = out[i]
    end
    return false
end

function settings.defaults()
    return clone(DEFAULTS)
end

function settings.ensure(root)
    if type(root) ~= 'table' then
        return false
    end

    local changed = ensure_table(root, 'combat_log')
    local cfg = root.combat_log
    local previous_schema = tonumber(cfg.schema_version)

    if tonumber(cfg.schema_version) ~= DEFAULTS.schema_version then
        cfg.schema_version = DEFAULTS.schema_version
        changed = true
    end
    changed = ensure_bool(cfg, 'enabled', DEFAULTS.enabled) or changed

    if not MODES[cfg.mode] then
        cfg.mode = cfg.enabled and 'full' or 'off'
        changed = true
    end
    if cfg.enabled ~= true and cfg.mode ~= 'off' then
        cfg.mode = 'off'
        changed = true
    elseif cfg.mode == 'off' and cfg.enabled == true then
        cfg.enabled = false
        changed = true
    end

    if not PRESETS[cfg.preset] then
        cfg.preset = DEFAULTS.preset
        changed = true
    end

    for _, section in ipairs({ 'aggregation', 'display', 'filters', 'filter_matrix', 'colors', 'chat_colors' }) do
        changed = ensure_table(cfg, section) or changed
    end

    for key, fallback in pairs(DEFAULTS.aggregation) do
        if key == 'window_ms' then
            local value = clamp(cfg.aggregation[key], 25, 1000, fallback)
            if cfg.aggregation[key] ~= value then
                cfg.aggregation[key] = value
                changed = true
            end
        else
            changed = ensure_bool(cfg.aggregation, key, fallback) or changed
        end
    end
    if previous_schema ~= nil and previous_schema < 4 and cfg.aggregation.window_ms == 250 then
        cfg.aggregation.window_ms = DEFAULTS.aggregation.window_ms
        changed = true
    end
    for key, fallback in pairs(DEFAULTS.display) do
        changed = ensure_bool(cfg.display, key, fallback) or changed
    end
    for key, fallback in pairs(DEFAULTS.filters) do
        changed = ensure_bool(cfg.filters, key, fallback) or changed
    end
    for _, scope in ipairs(MATRIX_SCOPES) do
        changed = ensure_table(cfg.filter_matrix, scope) or changed
        for _, key in ipairs(MATRIX_KEYS) do
            changed = ensure_bool(cfg.filter_matrix[scope], key, DEFAULTS.filter_matrix[scope][key]) or changed
        end
    end
    if previous_schema ~= nil and previous_schema < 2 then
        local legacy = cfg.filters
        for _, scope in ipairs(MATRIX_SCOPES) do
            if legacy.misses == false then
                cfg.filter_matrix[scope].misses = false
                cfg.filter_matrix[scope].defenses = false
            end
            if legacy.healing == false then cfg.filter_matrix[scope].hp_gained = false end
            if legacy.status == false then cfg.filter_matrix[scope].status = false end
            if legacy.abilities == false then cfg.filter_matrix[scope].actions = false end
        end
        for _, scope in ipairs({ 'self', 'party', 'alliance' }) do
            if legacy.outgoing_damage == false then cfg.filter_matrix[scope].damage_dealt = false end
            if legacy.incoming_damage == false then cfg.filter_matrix[scope].damage_received = false end
        end
        if legacy.other_players == false then
            for _, key in ipairs(MATRIX_KEYS) do cfg.filter_matrix.others[key] = false end
        end
        for _, key in ipairs({ 'outgoing_damage', 'incoming_damage', 'healing', 'misses', 'status', 'abilities' }) do
            cfg.filters[key] = true
        end
        changed = true
    end
    for key, fallback in pairs(DEFAULTS.colors) do
        changed = ensure_color(cfg.colors, key, fallback) or changed
    end
    changed = ensure_bool(cfg.chat_colors, 'enabled', DEFAULTS.chat_colors.enabled) or changed
    for key, fallback in pairs(DEFAULTS.chat_colors) do
        if key ~= 'enabled' then
            changed = ensure_table(cfg.chat_colors, key) or changed
            changed = ensure_bool(cfg.chat_colors[key], 'enabled', fallback.enabled) or changed
            local index = math.floor(clamp(cfg.chat_colors[key].index, 1, 255, fallback.index) + 0.5)
            if cfg.chat_colors[key].index ~= index then
                cfg.chat_colors[key].index = index
                changed = true
            end
        end
    end
    changed = ensure_bool(cfg, 'diagnostics', DEFAULTS.diagnostics) or changed
    changed = ensure_bool(cfg, 'capture_unknown', DEFAULTS.capture_unknown) or changed
    changed = ensure_bool(cfg, 'capture_all', DEFAULTS.capture_all) or changed

    return changed
end

function settings.set_enabled(root, enabled)
    settings.ensure(root)
    local cfg = root.combat_log
    cfg.enabled = (enabled == true)
    cfg.mode = cfg.enabled and 'full' or 'off'
end

function settings.set_mode(root, mode)
    settings.ensure(root)
    mode = MODES[mode] and mode or 'off'
    root.combat_log.mode = mode
    root.combat_log.enabled = (mode ~= 'off')
end

function settings.apply_preset(root, preset)
    settings.ensure(root)
    local values = PRESET_FILTERS[preset]
    if not values then
        return false
    end
    local cfg = root.combat_log
    cfg.preset = preset
    for key, value in pairs(values) do
        cfg.filters[key] = value
    end
    for scope, scope_values in pairs(PRESET_MATRIX[preset]) do
        for key, value in pairs(scope_values) do
            cfg.filter_matrix[scope][key] = value
        end
    end
    cfg.aggregation.damage = (preset ~= 'all')
    cfg.aggregation.targets = (preset ~= 'all')
    cfg.aggregation.sum_damage = (preset ~= 'all')
    return true
end

function settings.mark_custom(root)
    settings.ensure(root)
    root.combat_log.preset = 'custom'
end

function settings.reset(root)
    if type(root) ~= 'table' then
        return false
    end
    root.combat_log = settings.defaults()
    return true
end

return settings
