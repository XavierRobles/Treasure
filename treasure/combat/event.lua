local event = {}

local CATEGORIES = {
    [0] = 'none',
    [1] = 'melee',
    [2] = 'ranged',
    [3] = 'weapon_skill',
    [4] = 'magic',
    [5] = 'item',
    [6] = 'ability',
    [7] = 'monster_ability_ready',
    [8] = 'cast_start',
    [9] = 'item_ready',
    [10] = 'ability_ready',
    [11] = 'monster_ability',
    [12] = 'ranged_ready',
    [13] = 'pet_ability',
    [14] = 'dancer_ability',
    [15] = 'rune_ability',
}

local PREPARATION_KINDS = {
    [7] = 'ability_ready',
    [8] = 'cast_start',
    [9] = 'item_ready',
    [10] = 'ability_ready',
    [12] = 'ability_ready',
}

local OUTCOMES = {
    [0] = 'hit',
    [1] = 'miss',
    [2] = 'guard',
    [3] = 'parry',
    [4] = 'block',
    [9] = 'evade',
}

function event.from_action(action)
    if type(action) ~= 'table' then
        return nil
    end

    local targets = {}
    local first_message = 0
    local all_failed = true
    local has_additional_effect = false
    local has_spike_effect = false
    for _, target in ipairs(action.targets or {}) do
        for _, result in ipairs(target.actions or {}) do
            local outcome = OUTCOMES[result.reaction] or 'unknown'
            if outcome == 'hit' then
                all_failed = false
            end
            first_message = (first_message ~= 0 and first_message) or (tonumber(result.message_id) or 0)
            has_additional_effect = has_additional_effect or (result.has_additional_effect == true)
            has_spike_effect = has_spike_effect or (result.has_spike_effect == true)
            targets[#targets + 1] = {
                server_id = tonumber(target.server_id) or 0,
                channel = 'main',
                outcome = outcome,
                amount = tonumber(result.param) or 0,
                message_id = tonumber(result.message_id) or 0,
                animation = tonumber(result.animation) or 0,
                effect = tonumber(result.effect) or 0,
                scale = tonumber(result.scale) or 0,
                result_kind = tonumber(result.kind) or 0,
                raw_unknown = tonumber(result.unknown) or 0,
                additional_effect = result.additional_effect,
                spike_effect = result.spike_effect,
            }
            if result.additional_effect and tonumber(result.additional_effect.message_id) ~= 0 then
                targets[#targets + 1] = {
                    server_id = tonumber(target.server_id) or 0,
                    channel = 'additional',
                    outcome = 'hit',
                    amount = tonumber(result.additional_effect.param) or 0,
                    message_id = tonumber(result.additional_effect.message_id) or 0,
                    animation = tonumber(result.additional_effect.animation) or 0,
                    effect = tonumber(result.additional_effect.effect) or 0,
                    result_kind = 0,
                }
            end
            if result.spike_effect and tonumber(result.spike_effect.message_id) ~= 0 then
                targets[#targets + 1] = {
                    server_id = tonumber(target.server_id) or 0,
                    channel = 'spike',
                    outcome = 'hit',
                    amount = tonumber(result.spike_effect.param) or 0,
                    message_id = tonumber(result.spike_effect.message_id) or 0,
                    animation = tonumber(result.spike_effect.animation) or 0,
                    effect = tonumber(result.spike_effect.effect) or 0,
                    result_kind = 0,
                }
            end
        end
    end

    local kind = PREPARATION_KINDS[action.category] or 'action_use'
    if #targets > 0 and all_failed then
        kind = 'miss'
    end

    local action_id = tonumber(action.param) or 0
    if action.category == 1 or action.category == 2 or action.category == 12 then
        -- These categories do not carry a resource id in action.param.
        action_id = 0
    end
    if (action.category == 7 or action.category == 8 or action.category == 9 or action.category == 10)
            and targets[1] then
        action_id = tonumber(targets[1].amount) or action_id
    end

    return {
        source = 'packet_0x028',
        kind = kind,
        actor = {
            server_id = tonumber(action.actor_id) or 0,
            relation = 'unknown',
        },
        targets = targets,
        action = {
            category = CATEGORIES[action.category] or 'unknown',
            id = action_id,
        },
        message_id = first_message,
        flags = {
            additional_effect = has_additional_effect,
            spike_effect = has_spike_effect,
        },
        raw = {
            packet_id = 0x028,
            category = tonumber(action.category) or 0,
            recast = tonumber(action.recast) or 0,
            target_count = tonumber(action.target_count) or 0,
        },
    }
end

return event
