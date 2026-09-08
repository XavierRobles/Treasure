local formatter = {}

local DECORATION = {
    brackets = { '[', ']' }, parentheses = { '(', ')' }, braces = { '{', '}' },
    quotes = { '"', '"' }, angles = { '<', '>' },
}

local function decorate(cfg, part, value)
    value = tostring(value or '')
    local options = cfg and cfg.decoration
    local marks = options and options[part] == true and DECORATION[options.style]
    if not marks or value == '' then return value end
    return marks[1] .. value .. marks[2]
end

local HEALING = { [7] = true, [24] = true, [102] = true, [238] = true, [263] = true, [306] = true,
    [318] = true, [367] = true }
local DAMAGE = { [1] = true, [2] = true, [67] = true, [110] = true, [163] = true, [185] = true, [227] = true,
    [187] = true, [229] = true, [252] = true, [264] = true, [265] = true, [274] = true,
    [317] = true, [352] = true, [353] = true,
    [576] = true, [577] = true, [33] = true, [44] = true, [161] = true, [536] = true }
local STATUS = { [75] = true, [85] = true, [114] = true, [123] = true, [127] = true, [159] = true, [230] = true, [236] = true,
    [186] = true, [231] = true, [237] = true, [242] = true, [243] = true, [266] = true, [267] = true, [268] = true, [269] = true, [270] = true,
    [271] = true, [272] = true, [277] = true, [278] = true, [279] = true, [280] = true,
    [284] = true, [319] = true, [321] = true, [341] = true, [342] = true, [343] = true,
    [329] = true, [330] = true, [331] = true, [332] = true, [333] = true, [334] = true, [335] = true,
    [533] = true, [83] = true, [126] = true, [160] = true, [164] = true, [370] = true, [776] = true }

local NO_EFFECT = { [75] = true, [114] = true, [156] = true, [189] = true, [248] = true, [283] = true,
    [312] = true, [323] = true, [336] = true, [355] = true, [408] = true, [422] = true, [423] = true,
    [425] = true, [659] = true }
local RESISTED = { [85] = true, [284] = true, [653] = true, [654] = true, [655] = true, [656] = true }
local USED = { [100] = true, [101] = true, [115] = true, [116] = true, [119] = true, [120] = true, [121] = true }
local SELF_USED = { [100] = true, [115] = true, [116] = true, [120] = true, [121] = true }
local ROLL = { [420] = true, [421] = true, [424] = true, [426] = true, [427] = true }
local TP_REDUCED = { [226] = true, [362] = true, [363] = true }
local HP_DRAIN = { [161] = true, [187] = true, [227] = true, [274] = true }
local MP_DRAIN = { [162] = true, [225] = true, [228] = true, [275] = true, [366] = true, [750] = true, [751] = true }
local MP_RECOVERY = { [224] = true, [276] = true, [451] = true }
local TP_DRAIN = { [454] = true }
local STATUS_REMOVED = { [83] = true, [123] = true, [159] = true, [321] = true, [341] = true, [342] = true, [343] = true }
local EFFECTS_REMOVED_COUNT = { [231] = true }
local STAT_DRAIN = {
    [329] = 'STR', [330] = 'DEX', [331] = 'VIT', [332] = 'AGI',
    [333] = 'INT', [334] = 'MND', [335] = 'CHR', [533] = 'Accuracy',
}
local VANISHES = { [93] = true, [273] = true }
local TOO_FAR_AWAY = { [328] = true }
local ACTION_MISS = { [324] = true }
local STATUS_DRAIN = { [370] = true }
local STATUS_WEAR_OFF = { [206] = true }
local RECEIVES_ABILITY_EFFECT = { [441] = true }
local ATTACKS_ENHANCED = { [285] = true }
local ATTRIBUTE_ENHANCED = { [117] = 'defense enhanced', [118] = 'accuracy enhanced' }
local PET_POWERS_INCREASE = { [108] = true, [109] = true }
local CASTS_ON = { [309] = true }
local STATUS_SPIKES = { [374] = true }
local TARGET_SWITCHES = { [418] = true }
local ABILITIES_RECHARGED = { [435] = true, [436] = true, [437] = true, [438] = true }
local ABILITIES_RECHARGED_TP = { [437] = true, [438] = true }
local PARALYZED = { [84] = true }
local CRITICAL = { [67] = true, [353] = true }
local RETALIATION_DAMAGE = { [33] = true, [44] = true }
local SPIKE_DAMAGE = { [44] = true }
local MAGIC_BURST = { [252] = true, [265] = true, [268] = true, [269] = true, [271] = true,
    [272] = true, [274] = true, [275] = true, [750] = true, [751] = true }
local SHADOWS_ABSORBED = { [14] = true, [31] = true, [535] = true }
local DEFEAT = { [6] = true }
local STEAL_SUCCESS = { [125] = true }
local STEAL_FAILURE = { [153] = true }
local MUG_SUCCESS = { [129] = true }
local MUG_FAILURE = { [244] = true }
local CHARM_SUCCESS = { [136] = true }
local CHARM_FAILURE = { [137] = true }
local TAME_SUCCESS = { [138] = true }
local INTIMIDATED = { [106] = true }
local CAST_INTERRUPTED = { [78] = true }
local MANEUVER_OVERLOAD = { [798] = true }
local MANEUVER_OVERLOADED = { [799] = true }
local ENMITY_STOLEN = { [526] = true }
local FORTIFIED_ARCANA = { [131] = true, [134] = true, [287] = true }
local TP_INCREASED = { [409] = true }
local MAGIC_EFFECT_DRAINED = { [430] = true }
local SCAVENGE_SUCCESS = { [674] = true }
local SKILLCHAINS = {
    [288] = 'Light', [289] = 'Darkness', [290] = 'Gravitation', [291] = 'Fragmentation',
    [292] = 'Distortion', [293] = 'Fusion', [294] = 'Compression', [295] = 'Liquefaction',
    [296] = 'Induration', [297] = 'Reverberation', [298] = 'Transfixion', [299] = 'Scission',
    [300] = 'Detonation', [301] = 'Impaction', [302] = 'Cosmic Elucidation',
    [385] = 'Light', [386] = 'Darkness', [387] = 'Gravitation', [388] = 'Fragmentation',
    [389] = 'Distortion', [390] = 'Fusion', [391] = 'Compression', [392] = 'Liquefaction',
    [393] = 'Induration', [394] = 'Reverberation', [395] = 'Transfixion', [396] = 'Scission',
    [397] = 'Detonation', [398] = 'Impaction',
    [767] = 'Radiance', [768] = 'Umbra', [769] = 'Radiance', [770] = 'Umbra',
}
for message_id = 288, 302 do DAMAGE[message_id] = true end
for message_id = 384, 398 do HEALING[message_id] = true end
DAMAGE[767], DAMAGE[768] = true, true
HEALING[769], HEALING[770] = true, true

local FRIENDLY = { self = true, party = true, alliance = true, my_pet = true, party_pet = true, alliance_pet = true }

local function is_magic_burst(target)
    if target.magic_burst ~= nil then return target.magic_burst == true end
    return MAGIC_BURST[tonumber(target.message_id) or 0] == true
end

local function is_item_event(event)
    local category = tostring(event and event.action and event.action.category or '')
    return category == 'item' or category == 'item_ready'
end

local function entity_name_is_known(entity, fallback_prefix)
    local name = tostring(entity and entity.name or '')
    return name ~= '' and not name:find('^' .. fallback_prefix .. ' %d+$')
end

-- Full mode is deliberately conservative. A message is replaced only when
-- Treasure can preserve its useful meaning; everything else stays untouched
-- and is rendered by the game.
function formatter.supports_target(event, target)
    if type(event) ~= 'table' or type(target) ~= 'table' then return false end
    local category = tostring(event.action and event.action.category or '')
    local action_name = tostring(event.action and event.action.name or '')
    local generic_name = category:gsub('_', ' ')
    local name_is_known = action_name ~= '' and action_name ~= generic_name
            and not action_name:find(' #%d+$')
    local message_id = tonumber(target.message_id) or 0
    if event.kind == 'status_wear_off' then
        return STATUS_WEAR_OFF[message_id] == true
                and target.status_name ~= nil
                and entity_name_is_known(target, 'Target')
    end
    -- Self-use messages do not render a target. Allow the first such action
    -- after a reload even when the entity cache has not resolved its target.
    if SELF_USED[message_id] and #(event.targets or {}) == 1
            and name_is_known and entity_name_is_known(event.actor, 'Actor') then
        return true
    end
    -- Resource ids preserve action semantics, but server ids alone are not a
    -- useful entity label. If Ashita cannot currently resolve either side,
    -- retain the native game line instead of exposing Actor/Target 123456.
    if not entity_name_is_known(event.actor, 'Actor')
            or not entity_name_is_known(target, 'Target') then
        return false
    end
    if PARALYZED[message_id] or TOO_FAR_AWAY[message_id] or INTIMIDATED[message_id]
            or CAST_INTERRUPTED[message_id] or TARGET_SWITCHES[message_id] then return true end
    if category ~= 'melee' and category ~= 'ranged'
            and target.channel ~= 'spike' and not name_is_known then
        return false
    end
    if event.kind == 'cast_start' or event.kind == 'ability_ready' or event.kind == 'item_ready' then
        return message_id ~= 0 and name_is_known
                and (target.channel == nil or target.channel == 'main')
    end
    if target.outcome == 'miss' or (target.outcome ~= nil and target.outcome ~= 'hit' and target.outcome ~= 'unknown') then
        return true
    end
    return HEALING[message_id] == true or DAMAGE[message_id] == true or STATUS[message_id] == true
            or NO_EFFECT[message_id] == true or RESISTED[message_id] == true or USED[message_id] == true
            or ROLL[message_id] == true or TP_REDUCED[message_id] == true or MP_DRAIN[message_id] == true
            or MP_RECOVERY[message_id] == true or TP_DRAIN[message_id] == true
            or STATUS_REMOVED[message_id] == true
            or STAT_DRAIN[message_id] ~= nil or VANISHES[message_id] == true
            or ACTION_MISS[message_id] == true or STATUS_DRAIN[message_id] == true
            or RECEIVES_ABILITY_EFFECT[message_id] == true
            or ATTACKS_ENHANCED[message_id] == true or SHADOWS_ABSORBED[message_id] == true
            or ATTRIBUTE_ENHANCED[message_id] ~= nil or PET_POWERS_INCREASE[message_id] == true
            or CASTS_ON[message_id] == true
            or ABILITIES_RECHARGED[message_id] == true
            or DEFEAT[message_id] == true or STEAL_SUCCESS[message_id] == true or STEAL_FAILURE[message_id] == true
            or MUG_SUCCESS[message_id] == true or MUG_FAILURE[message_id] == true
            or FORTIFIED_ARCANA[message_id] == true or TP_INCREASED[message_id] == true
            or MAGIC_EFFECT_DRAINED[message_id] == true or SCAVENGE_SUCCESS[message_id] == true
            or STATUS_SPIKES[message_id] == true or CHARM_SUCCESS[message_id] == true
            or CHARM_FAILURE[message_id] == true or TAME_SUCCESS[message_id] == true
            or MANEUVER_OVERLOAD[message_id] == true or MANEUVER_OVERLOADED[message_id] == true
            or ENMITY_STOLEN[message_id] == true
end

local function filter_scope(relation)
    if relation == 'self' or relation == 'my_pet' then return 'self' end
    if relation == 'party' or relation == 'party_pet' then return 'party' end
    if relation == 'alliance' or relation == 'alliance_pet' then return 'alliance' end
    if relation == 'enemy' then return 'enemies' end
    return 'others'
end

local function matrix_allows(cfg, relation, key)
    local matrix = cfg and cfg.filter_matrix
    if type(matrix) ~= 'table' then return true end
    local row = matrix[filter_scope(relation)]
    return type(row) ~= 'table' or row[key] ~= false
end

local function target_identity(target)
    if target and target.server_id ~= nil then
        return 'id:' .. tostring(target.server_id)
    end
    local name = tostring(target and target.name or '')
    if name ~= '' then return 'name:' .. name end
    return nil
end

local function classify(target)
    local message_id = tonumber(target.message_id) or 0
    if HEALING[message_id] then return 'healing' end
    if MP_DRAIN[message_id] then return 'healing' end
    if MP_RECOVERY[message_id] then return 'healing' end
    if TP_DRAIN[message_id] then return 'healing' end
    if ACTION_MISS[message_id] then return 'misses' end
    if ROLL[message_id] then return 'status' end
    if ATTACKS_ENHANCED[message_id] then return 'status' end
    if ATTRIBUTE_ENHANCED[message_id] or PET_POWERS_INCREASE[message_id] then return 'status' end
    if ABILITIES_RECHARGED[message_id] then return 'status' end
    if FORTIFIED_ARCANA[message_id] or TP_INCREASED[message_id] then return 'status' end
    if CHARM_SUCCESS[message_id] or TAME_SUCCESS[message_id] then return 'status' end
    if DEFEAT[message_id] then return 'defeat' end
    if STEAL_SUCCESS[message_id] or STEAL_FAILURE[message_id] or MUG_SUCCESS[message_id]
            or MUG_FAILURE[message_id] or MANEUVER_OVERLOAD[message_id]
            or MANEUVER_OVERLOADED[message_id]
            or ENMITY_STOLEN[message_id] then return 'action' end
    if STATUS_SPIKES[message_id] then return 'status' end
    if STATUS_WEAR_OFF[message_id] then return 'status' end
    if CASTS_ON[message_id] then return 'action' end
    if CHARM_FAILURE[message_id] then return 'defenses' end
    if NO_EFFECT[message_id] or RESISTED[message_id] then return 'defenses' end
    if SHADOWS_ABSORBED[message_id] then return 'defenses' end
    if STATUS[message_id] then return 'status' end
    if is_magic_burst(target) and DAMAGE[message_id] then return 'damage' end
    if DAMAGE[message_id] and target.outcome ~= 'miss' then return 'damage' end
    if target.outcome == 'miss' then return 'misses' end
    if target.outcome ~= 'hit' then return 'defenses' end
    return 'action'
end

local function passes_filter(event, target, cfg)
    local filters = (cfg and cfg.filters) or {}
    if is_item_event(event) and filters.items == false then return false end
    local class = classify(target)
    local actor_relation = event.actor and event.actor.relation
    local target_relation = target.relation
    if class == 'healing' then
        return filters.healing ~= false and matrix_allows(cfg, target_relation, 'hp_gained')
    end
    if class == 'status' then
        return filters.status ~= false and matrix_allows(cfg, target_relation, 'status')
    end
    if class == 'misses' then
        return filters.misses ~= false and matrix_allows(cfg, actor_relation, 'misses')
    end
    if class == 'defenses' then
        return filters.misses ~= false and matrix_allows(cfg, target_relation, 'defenses')
    end
    if class == 'defeat' then
        return filters.defeats ~= false and matrix_allows(cfg, actor_relation, 'actions')
    end

    local actor_friendly = FRIENDLY[actor_relation] == true
    local target_friendly = FRIENDLY[target_relation] == true
    if class == 'damage' then
        -- Counter and spike results are retaliation: the action actor receives
        -- damage from the entity they attacked, so the filter direction reverses.
        if target.channel == 'spike' and RETALIATION_DAMAGE[tonumber(target.message_id) or 0] then
            if actor_friendly and filters.incoming_damage == false then return false end
            if not actor_friendly and target_friendly and filters.outgoing_damage == false then return false end
            return matrix_allows(cfg, target_relation, 'damage_dealt')
                    and matrix_allows(cfg, actor_relation, 'damage_received')
        end
        if actor_friendly and filters.outgoing_damage == false then return false end
        if not actor_friendly and target_friendly and filters.incoming_damage == false then return false end
        return matrix_allows(cfg, actor_relation, 'damage_dealt')
                and matrix_allows(cfg, target_relation, 'damage_received')
    end
    if type(cfg and cfg.filter_matrix) ~= 'table'
            and not actor_friendly and not target_friendly and filters.other_players == false then
        return false
    end
    return filters.abilities ~= false and matrix_allows(cfg, actor_relation, 'actions')
end

local function describe_result(target, item_event, cfg)
    local class = classify(target)
    local amount = tonumber(target.amount) or 0
    local message_id = tonumber(target.message_id) or 0
    local text
    if HP_DRAIN[message_id] then text = tostring(amount) .. ' HP drained'
    elseif MP_DRAIN[message_id] then text = tostring(amount) .. ' MP drained'
    elseif MP_RECOVERY[message_id] then text = '+' .. tostring(amount) .. ' MP'
    elseif TP_DRAIN[message_id] then text = tostring(amount) .. ' TP drained'
    elseif class == 'healing' then text = '+' .. tostring(amount) .. ' HP'
    elseif class == 'damage' then
        if CRITICAL[message_id] then
            text = 'critical: ' .. tostring(amount) .. ' damage'
            if target.outcome == 'guard' then text = text .. ' (guarded)' end
        elseif target.outcome == 'block' then
            text = tostring(amount) .. ' damage (blocked)'
        elseif target.outcome == 'guard' then
            text = tostring(amount) .. ' damage (guarded)'
        else
            text = tostring(amount) .. ' damage'
        end
    elseif NO_EFFECT[message_id] then text = 'no effect'
    elseif RESISTED[message_id] then text = 'resisted'
    elseif ACTION_MISS[message_id] then text = 'miss'
    elseif SHADOWS_ABSORBED[message_id] then
        text = tostring(amount) .. (amount == 1 and ' shadow absorbed' or ' shadows absorbed')
    elseif CHARM_FAILURE[message_id] then text = 'failed to charm'
    elseif class == 'misses' or class == 'defenses' then text = tostring(target.outcome or 'miss')
    elseif ROLL[message_id] then text = 'roll ' .. tostring(amount)
    elseif TP_REDUCED[message_id] then text = 'TP reduced to ' .. tostring(amount)
    elseif TP_INCREASED[message_id] then text = 'TP increased to ' .. tostring(amount)
    elseif FORTIFIED_ARCANA[message_id] then text = 'fortified against arcana'
    elseif MAGIC_EFFECT_DRAINED[message_id] then text = '1 magic effect drained'
    elseif SCAVENGE_SUCCESS[message_id] then
        text = 'finds ' .. tostring(target.item_name or ('item #' .. tostring(amount)))
    elseif ATTACKS_ENHANCED[message_id] then text = 'attacks enhanced'
    elseif ATTRIBUTE_ENHANCED[message_id] then text = ATTRIBUTE_ENHANCED[message_id]
    elseif PET_POWERS_INCREASE[message_id] then text = "pet's powers increase"
    elseif ABILITIES_RECHARGED_TP[message_id] then text = 'abilities recharged + TP increased'
    elseif ABILITIES_RECHARGED[message_id] then text = 'abilities recharged'
    elseif STAT_DRAIN[message_id] then text = STAT_DRAIN[message_id] .. ' drained'
    elseif VANISHES[message_id] then text = 'vanishes'
    elseif EFFECTS_REMOVED_COUNT[message_id] then
        text = string.format('%d %s removed', amount, amount == 1 and 'effect' or 'effects')
    elseif STATUS_REMOVED[message_id] then text = decorate(cfg, 'effect_lost', target.status_name or 'Effect') .. ' removed'
    elseif STATUS_DRAIN[message_id] then
        text = tostring(amount) .. (amount == 1 and ' status effect drained' or ' status effects drained')
    elseif RECEIVES_ABILITY_EFFECT[message_id] then text = 'receives the effect'
    elseif DEFEAT[message_id] then text = 'defeated'
    elseif STEAL_SUCCESS[message_id] then text = 'steals ' .. tostring(target.item_name or ('item #' .. tostring(amount)))
    elseif STEAL_FAILURE[message_id] then text = 'fails to steal'
    elseif MUG_SUCCESS[message_id] then text = 'mugs ' .. tostring(amount) .. ' gil'
    elseif MUG_FAILURE[message_id] then text = 'fails to mug'
    elseif CHARM_SUCCESS[message_id] then text = 'charmed'
    elseif TAME_SUCCESS[message_id] then text = 'seems friendlier'
    elseif MANEUVER_OVERLOAD[message_id] then text = 'overload chance ' .. tostring(amount) .. '%'
    elseif MANEUVER_OVERLOADED[message_id] then
        text = 'overload chance ' .. tostring(amount) .. '% (overloaded)'
    elseif ENMITY_STOLEN[message_id] then text = 'enmity stolen'
    elseif class == 'status' then text = 'gains ' .. decorate(cfg, 'effect_gained', target.status_name or 'an effect')
    elseif USED[message_id] or item_event then text = 'used'
    else text = amount ~= 0 and ('effect ' .. tostring(amount)) or 'used' end

    if SKILLCHAINS[message_id] then
        return SKILLCHAINS[message_id] .. ' skillchain: ' .. text
    elseif is_magic_burst(target) then
        return 'Magic Burst! ' .. text
    elseif target.channel == 'additional' then
        return 'additional: ' .. text
    elseif target.channel == 'spike' then
        if SPIKE_DAMAGE[message_id] then
            return 'spikes: ' .. text
        end
        return 'counter: ' .. text
    end
    return text
end

local function target_label(groups, cfg)
    if #groups == 1 then
        return decorate(cfg, 'target', groups[1].target.name or 'Unknown')
    end
    if cfg.display and cfg.display.target_names == true then
        local names = {}
        for _, group in ipairs(groups) do
            names[#names + 1] = decorate(cfg, 'target', group.target.name or 'Unknown')
        end
        return table.concat(names, ', ')
    end
    if cfg.display and cfg.display.target_count == false then
        return 'multiple targets'
    end
    return tostring(#groups) .. ' targets'
end

local function entity_label(entity, cfg, part)
    local label = tostring(entity and entity.name or 'Unknown')
    if cfg and cfg.display and cfg.display.pet_owner == true
            and entity and entity.owner_name and entity.owner_name ~= '' then
        label = label .. ' (' .. tostring(entity.owner_name) .. ')'
    end
    return decorate(cfg, part or 'target', label)
end

local function all_results_equal(results)
    for index = 2, #results do
        if results[index] ~= results[1] then
            return false
        end
    end
    return true
end

function formatter.format(event, cfg, action_name)
    if type(event) ~= 'table' or type(event.actor) ~= 'table' then
        return {}
    end
    local actor = entity_label(event.actor, cfg, 'actor')
    local action = tostring(action_name or (event.action and event.action.category) or 'action')
    local lines = {}

    if event.kind == 'status_wear_off' then
        local target = event.targets and event.targets[1]
        if target and target.replace_original ~= false and passes_filter(event, target, cfg) then
            return { string.format('%s: %s wears off', entity_label(target, cfg),
                    decorate(cfg, 'effect_lost', target.status_name or 'Effect')) }
        end
        return {}
    end

    -- The action packet category maps Steal and Mug ids through the weapon-skill
    -- resource table. Their result message ids are authoritative.
    for _, target in ipairs(event.targets or {}) do
        local message_id = tonumber(target.message_id) or 0
        if STEAL_SUCCESS[message_id] or STEAL_FAILURE[message_id] then
            action = 'Steal'
            break
        elseif MUG_SUCCESS[message_id] or MUG_FAILURE[message_id] then
            action = 'Mug'
            break
        end
    end
    action = decorate(cfg, 'action', action)

    -- Message 84 describes the actor being unable to act, even though magic
    -- packets retain the intended spell target in the target field.
    local first_target = event.targets and event.targets[1]
    if first_target and CASTS_ON[tonumber(first_target.message_id) or 0] then
        if passes_filter(event, first_target, cfg) then
            return { string.format('%s casts %s on %s', actor, action, entity_label(first_target, cfg)) }
        end
        return {}
    end
    if first_target and PET_POWERS_INCREASE[tonumber(first_target.message_id) or 0] then
        if passes_filter(event, first_target, cfg) then
            return { string.format("%s: %s: pet's powers increase", actor, action) }
        end
        return {}
    end
    if first_target and TARGET_SWITCHES[tonumber(first_target.message_id) or 0] then
        local filters = (cfg and cfg.filters) or {}
        if first_target.replace_original ~= false
                and filters.abilities ~= false and matrix_allows(cfg,
                event.actor and event.actor.relation, 'actions') then
            return { string.format('%s: %s -> %s: target switches to %s', actor, action,
                    entity_label(first_target, cfg), actor) }
        end
        return {}
    end
    if first_target and TOO_FAR_AWAY[tonumber(first_target.message_id) or 0] then
        local filters = (cfg and cfg.filters) or {}
        if filters.abilities ~= false and matrix_allows(cfg,
                event.actor and event.actor.relation, 'actions') then
            return { string.format('%s is too far away', entity_label(first_target, cfg)) }
        end
        return {}
    end
    if first_target and PARALYZED[tonumber(first_target.message_id) or 0] then
        local filters = (cfg and cfg.filters) or {}
        if filters.status ~= false and matrix_allows(cfg,
                event.actor and event.actor.relation, 'status') then
            return { string.format('%s is paralyzed', actor) }
        end
        return {}
    end
    if first_target and INTIMIDATED[tonumber(first_target.message_id) or 0] then
        local filters = (cfg and cfg.filters) or {}
        if filters.status ~= false and matrix_allows(cfg,
                event.actor and event.actor.relation, 'status') then
            return { string.format('%s is intimidated by %s', actor,
                    entity_label(first_target, cfg)) }
        end
        return {}
    end
    -- Interrupted enemy casts can arrive with action id 0, so the spell name
    -- is unavailable. Message 78 still identifies the outcome unambiguously.
    if first_target and CAST_INTERRUPTED[tonumber(first_target.message_id) or 0] then
        local filters = (cfg and cfg.filters) or {}
        if filters.abilities ~= false and matrix_allows(cfg,
                event.actor and event.actor.relation, 'actions') then
            return { string.format('%s: casting interrupted', actor) }
        end
        return {}
    end

    if event.kind == 'cast_start' or event.kind == 'ability_ready' then
        local target = event.targets and event.targets[1]
        local show_cast = event.kind ~= 'cast_start' or not cfg.filters or cfg.filters.casts ~= false
        if target and target.replace_original ~= false and show_cast
                and passes_filter(event, target, cfg) then
            if event.action and event.action.category == 'ranged_ready' then
                lines[1] = string.format('%s readies a ranged attack', actor)
            elseif event.kind == 'cast_start' then
                lines[1] = string.format('%s starts casting %s -> %s', actor, action, entity_label(target, cfg))
            elseif event.kind == 'item_ready' then
                lines[1] = string.format('%s prepares %s -> %s', actor, action, entity_label(target, cfg))
            else
                lines[1] = string.format('%s readies %s -> %s', actor, action, entity_label(target, cfg))
            end
        end
        return lines
    end

    -- Some dispels report both a provisional "no effect" and a confirmed
    -- removal for the same target. The successful removal is authoritative.
    local removed_by_target = {}
    local successful_effect_by_target = {}
    for _, target in ipairs(event.targets or {}) do
        local message_id = tonumber(target.message_id) or 0
        if STATUS_REMOVED[message_id]
                or (EFFECTS_REMOVED_COUNT[message_id] and (tonumber(target.amount) or 0) > 0) then
            local identity = target_identity(target)
            if identity then removed_by_target[identity] = true end
        end
        if ((STATUS[message_id] and not NO_EFFECT[message_id] and not RESISTED[message_id])
                or CHARM_SUCCESS[message_id] or TAME_SUCCESS[message_id]) then
            local identity = target_identity(target)
            if identity then successful_effect_by_target[identity] = true end
        end
    end

    local grouped = {}
    local order = {}
    local status_spike_lines = {}
    for _, target in ipairs(event.targets or {}) do
        local message_id = tonumber(target.message_id) or 0
        local identity = target_identity(target)
        local superseded_no_effect = NO_EFFECT[message_id]
                and identity and (removed_by_target[identity] == true
                    or successful_effect_by_target[identity] == true)
        if STATUS_SPIKES[message_id] then
            local filters = (cfg and cfg.filters) or {}
            if target.replace_original ~= false and filters.status ~= false
                    and matrix_allows(cfg, event.actor and event.actor.relation, 'status') then
                status_spike_lines[#status_spike_lines + 1] = string.format(
                        "%s's armor causes %s to gain %s", entity_label(target, cfg), actor,
                        decorate(cfg, 'effect_gained', target.status_name or 'an effect'))
            end
        elseif not superseded_no_effect and target.replace_original ~= false
                and passes_filter(event, target, cfg) then
            local key = tostring(target.server_id or target.name or #order + 1) .. ':'
                    .. classify(target) .. ':' .. tostring(target.channel or 'main')
            if classify(target) == 'damage' and cfg.aggregation
                    and cfg.aggregation.merge_criticals ~= true and CRITICAL[tonumber(target.message_id) or 0] then
                key = key .. ':critical'
            end
            if is_magic_burst(target) then
                key = key .. ':magic_burst'
            end
            if SHADOWS_ABSORBED[tonumber(target.message_id) or 0] then
                key = key .. ':shadows'
            end
            if classify(target) == 'damage' and target.outcome == 'block' then
                key = key .. ':blocked'
            end
            if classify(target) == 'damage' and target.outcome == 'guard' then
                key = key .. ':guarded'
            end
            local group = grouped[key]
            if not group then
                group = { target = target, results = {}, total = 0 }
                grouped[key] = group
                order[#order + 1] = key
            end
            group.results[#group.results + 1] = describe_result(target, is_item_event(event), cfg)
            group.total = group.total + (tonumber(target.amount) or 0)
        end
    end

    local output_groups = {}
    for _, key in ipairs(order) do
        local group = grouped[key]
        local result_text = table.concat(group.results, ' + ')
        local class = classify(group.target)
        local message_id = tonumber(group.target.message_id) or 0
        local compact_discrete_results = SHADOWS_ABSORBED[message_id]
                or (class == 'misses' and all_results_equal(group.results))
        if #group.results > 1 and ((cfg.aggregation and cfg.aggregation.sum_damage)
                or compact_discrete_results) then
            if class == 'damage' then
                local show_detail = not (cfg.display and cfg.display.show_totals == false)
                if SPIKE_DAMAGE[tonumber(group.target.message_id) or 0] then
                    result_text = show_detail and string.format('spikes: %d damage (%d hits)', group.total, #group.results)
                            or string.format('spikes: %d damage', group.total)
                elseif HP_DRAIN[tonumber(group.target.message_id) or 0] then
                    result_text = show_detail and string.format('%d HP drained (%d effects)', group.total, #group.results)
                            or string.format('%d HP drained', group.total)
                elseif CRITICAL[tonumber(group.target.message_id) or 0] then
                    if group.target.outcome == 'guard' then
                        result_text = show_detail
                                and string.format('critical: %d damage (%d guarded hits)', group.total, #group.results)
                                or string.format('critical: %d damage (guarded)', group.total)
                    else
                        result_text = show_detail and string.format('critical: %d damage (%d hits)', group.total, #group.results)
                                or string.format('critical: %d damage', group.total)
                    end
                elseif group.target.outcome == 'block' then
                    result_text = show_detail and string.format('%d damage (%d blocked hits)', group.total, #group.results)
                            or string.format('%d damage (blocked)', group.total)
                elseif group.target.outcome == 'guard' then
                    result_text = show_detail and string.format('%d damage (%d guarded hits)', group.total, #group.results)
                            or string.format('%d damage (guarded)', group.total)
                else
                    result_text = show_detail and string.format('%d damage (%d hits)', group.total, #group.results)
                            or string.format('%d damage', group.total)
                end
                if is_magic_burst(group.target) then
                    result_text = 'Magic Burst! ' .. result_text
                end
            elseif class == 'healing' then
                if MP_DRAIN[tonumber(group.target.message_id) or 0] then
                    result_text = (cfg.display and cfg.display.show_totals == false)
                            and string.format('%d MP drained', group.total)
                            or string.format('%d MP drained (%d effects)', group.total, #group.results)
                elseif TP_DRAIN[tonumber(group.target.message_id) or 0] then
                    result_text = (cfg.display and cfg.display.show_totals == false)
                            and string.format('%d TP drained', group.total)
                            or string.format('%d TP drained (%d effects)', group.total, #group.results)
                elseif MP_RECOVERY[tonumber(group.target.message_id) or 0] then
                    result_text = (cfg.display and cfg.display.show_totals == false)
                            and string.format('+%d MP', group.total)
                            or string.format('+%d MP (%d effects)', group.total, #group.results)
                else
                    result_text = (cfg.display and cfg.display.show_totals == false)
                            and string.format('+%d HP', group.total)
                            or string.format('+%d HP (%d effects)', group.total, #group.results)
                end
                if is_magic_burst(group.target) then
                    result_text = 'Magic Burst! ' .. result_text
                end
            elseif SHADOWS_ABSORBED[message_id] then
                result_text = string.format('%d %s absorbed', group.total,
                        group.total == 1 and 'shadow' or 'shadows')
            elseif (class == 'misses' or class == 'defenses') and all_results_equal(group.results) then
                local label = group.results[1] == 'miss' and 'misses' or (group.results[1] .. ' results')
                result_text = string.format('%d %s', #group.results, label)
            end
        end
        group.result_text = result_text
        output_groups[#output_groups + 1] = group
    end


    local by_target = {}
    local target_order = {}
    for _, group in ipairs(output_groups) do
        local key = tostring(group.target.server_id or group.target.name or #target_order + 1)
        local compact = by_target[key]
        if not compact then
            compact = { target = group.target, texts = {}, classes = {} }
            by_target[key] = compact
            target_order[#target_order + 1] = key
        end
        compact.texts[#compact.texts + 1] = group.result_text
        compact.classes[#compact.classes + 1] = classify(group.target)
    end
    output_groups = {}
    for _, key in ipairs(target_order) do
        local compact = by_target[key]
        compact.result_text = table.concat(compact.texts, ' + ')
        compact.class_key = table.concat(compact.classes, '+')
        output_groups[#output_groups + 1] = compact
    end

    if #output_groups == 1 and classify(output_groups[1].target) == 'defeat' then
        return { string.format('%s defeats %s', actor, entity_label(output_groups[1].target, cfg)) }
    end
    local only_message_id = #output_groups == 1
            and (tonumber(output_groups[1].target.message_id) or 0) or 0
    if #output_groups == 1 and (SELF_USED[only_message_id]
            or (only_message_id == 101 and not is_item_event(event))) then
        return { string.format('%s: %s: used', actor, action) }
    end

    local force_target_aggregation = #output_groups > 1
    if force_target_aggregation then
        for _, group in ipairs(output_groups) do
            if not ABILITIES_RECHARGED[tonumber(group.target.message_id) or 0] then
                force_target_aggregation = false
                break
            end
        end
    end
    if #output_groups > 1 and ((cfg.aggregation and cfg.aggregation.targets)
            or force_target_aggregation) then
        local merged = {}
        local merged_order = {}
        for _, group in ipairs(output_groups) do
            local key = group.class_key .. ':' .. group.result_text
            if not merged[key] then
                merged[key] = {}
                merged_order[#merged_order + 1] = key
            end
            merged[key][#merged[key] + 1] = group
        end
        for _, key in ipairs(merged_order) do
            local groups = merged[key]
            lines[#lines + 1] = string.format('%s: %s -> %s: %s', actor, action,
                target_label(groups, cfg), groups[1].result_text)
        end
    else
        for _, group in ipairs(output_groups) do
            lines[#lines + 1] = string.format('%s: %s -> %s: %s', actor, action,
                    entity_label(group.target, cfg), group.result_text)
        end
    end
    for _, line in ipairs(status_spike_lines) do
        lines[#lines + 1] = line
    end
    return lines
end

return formatter
