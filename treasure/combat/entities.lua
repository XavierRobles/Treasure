local entities = {}

local names = {}
local relations = {}
local party_slots = {}
local owner_names = {}
local last_refresh = -100
local scan_cursor = 0
local resource_name
local MAX_ENTITY_INDEX = 2302

local STATUS_MESSAGES = {
    [75] = true, [85] = true, [114] = true, [123] = true, [127] = true, [159] = true, [186] = true,
    [230] = true, [236] = true, [237] = true, [242] = true, [243] = true, [266] = true,
    [267] = true, [268] = true, [269] = true, [270] = true, [271] = true,
    [272] = true, [277] = true, [278] = true, [279] = true, [280] = true,
    [284] = true, [319] = true, [321] = true, [341] = true, [342] = true, [343] = true,
    [83] = true, [126] = true, [160] = true, [164] = true, [206] = true, [374] = true, [776] = true,
}

-- Message IDs distinguish job abilities emitted as SkillFinish.
local JOB_ABILITY_MESSAGES = { [100] = true, [317] = true, [324] = true }

local function clean_name(value)
    local name = tostring(value or ''):gsub('%z', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

local function is_player_entity(entity)
    local flags = tonumber(entity and entity.SpawnFlags) or 0
    return (flags % 2) == 1
end

local function entity_relation(entity)
    return is_player_entity(entity) and 'other' or 'enemy'
end

-- Ashita's entity table only exposes target indices 0..2302. Player server
-- ids do not reliably encode a valid target index in their low 12 bits, so
-- never pass an unchecked server-id-derived value to the native GetEntity
-- binding; an out-of-range read can raise an access violation that Lua's
-- pcall cannot catch.
local function get_entity(index)
    index = tonumber(index)
    if index == nil or index < 0 or index > MAX_ENTITY_INDEX or index ~= math.floor(index) then
        return nil
    end
    return GetEntity(index)
end

local function mark(id, name, relation, party_slot, owner_name)
    id = tonumber(id) or 0
    if id == 0 then
        return
    end
    names[id] = clean_name(name) or names[id]
    relations[id] = relation or relations[id]
    party_slots[id] = party_slot or party_slots[id]
    owner_names[id] = clean_name(owner_name) or owner_names[id]
end

local function resolve_direct(id)
    id = tonumber(id) or 0
    if id == 0 or names[id] then return end
    local entity = get_entity(id % 0x1000)
    if entity and tonumber(entity.ServerId) == id then
        mark(id, entity.Name, relations[id] or entity_relation(entity))
    end
end

local function resolve_index(id, index)
    id = tonumber(id) or 0
    local entity = get_entity(index)
    if id ~= 0 and entity and tonumber(entity.ServerId) == id then
        mark(id, entity.Name, relations[id] or entity_relation(entity))
    end
end

local function wanted_ids(events)
    if type(events) ~= 'table' then
        return nil
    end
    if events.actor then
        events = { events }
    end
    local wanted = {}
    for _, event in ipairs(events) do
        local actor_id = tonumber(event.actor and event.actor.server_id) or 0
        if actor_id ~= 0 then wanted[actor_id] = true end
        for _, target in ipairs(event.targets or {}) do
            local target_id = tonumber(target.server_id) or 0
            if target_id ~= 0 then wanted[target_id] = true end
        end
    end
    return wanted
end

local function resolve_wanted(wanted)
    if type(wanted) ~= 'table' then
        return
    end

    for id in pairs(wanted) do
        if not names[id] then
            local index = id % 0x1000
            local entity = get_entity(index)
            if entity and tonumber(entity.ServerId) == id then
                mark(id, entity.Name, relations[id] or entity_relation(entity))
            end
        end
    end
end

function entities.refresh(now, events)
    now = tonumber(now) or 0
    local wanted = wanted_ids(events)
    if (now - last_refresh) < 0.5 then
        resolve_wanted(wanted)
        return
    end
    last_refresh = now

    pcall(function()
        local player = GetPlayerEntity()
        if player then
            mark(player.ServerId, player.Name, 'self')
            local target = get_entity(player.TargetIndex)
            if target then
                mark(target.ServerId, target.Name, relations[target.ServerId] or entity_relation(target))
            end
            local pet_index = tonumber(player.PetTargetIndex) or 0
            if pet_index ~= 0 then
                local pet = get_entity(pet_index)
                if pet then
                    mark(pet.ServerId, pet.Name, 'my_pet', 1, player.Name)
                end
            end
        end

        local party = AshitaCore:GetMemoryManager():GetParty()
        if party then
            for index = 0, 17 do
                if party:GetMemberIsActive(index) ~= 0 then
                    local relation = (index == 0) and 'self' or ((index <= 5) and 'party' or 'alliance')
                    local pet_relation = (index == 0) and 'my_pet'
                            or ((index <= 5) and 'party_pet' or 'alliance_pet')
                    mark(party:GetMemberServerId(index), party:GetMemberName(index), relation,
                        index <= 5 and (index + 1) or nil)
                    local member = get_entity(party:GetMemberTargetIndex(index))
                    local member_target = get_entity(member and member.TargetIndex)
                    if member_target then
                        mark(member_target.ServerId, member_target.Name,
                            relations[member_target.ServerId] or entity_relation(member_target))
                    end
                    local pet_index = tonumber(member and member.PetTargetIndex) or 0
                    if pet_index ~= 0 then
                        local pet = get_entity(pet_index)
                        if pet then
                            mark(pet.ServerId, pet.Name, pet_relation, index <= 5 and (index + 1) or nil,
                                party:GetMemberName(index))
                        end
                    end
                end
            end
        end

    end)
    resolve_wanted(wanted)
end

-- Keep an id->name cache warm without ever scanning all 2303 slots in one
-- frame. At the default budget a full pass is spread across roughly 72
-- render ticks; party targets are resolved immediately by refresh above.
function entities.scan(budget)
    budget = math.max(1, math.min(tonumber(budget) or 32, 128))
    for _ = 1, budget do
        local entity = get_entity(scan_cursor)
        if entity and tonumber(entity.ServerId) and entity.ServerId ~= 0 then
            mark(entity.ServerId, entity.Name, relations[entity.ServerId] or entity_relation(entity))
        end
        scan_cursor = scan_cursor + 1
        if scan_cursor > MAX_ENTITY_INDEX then scan_cursor = 0 end
    end
end

function entities.resolve_event(event)
    if type(event) ~= 'table' then
        return event
    end
    local actor = event.actor or {}
    local actor_id = tonumber(actor.server_id) or 0
    actor.name = names[actor_id] or actor.name or ('Actor ' .. tostring(actor_id))
    actor.relation = relations[actor_id] or actor.relation or 'unknown'
    actor.party_slot = party_slots[actor_id] or actor.party_slot
    actor.owner_name = owner_names[actor_id] or actor.owner_name
    event.actor = actor

    -- Category 7 is shared by monster readying packets and pet readying
    -- packets. Its numeric id belongs to a different resource table for pets;
    -- resolving it as a monster skill turns Healing Breath III into Flame
    -- Breath (and Remove Poison into Poison Breath).
    local action = event.action or {}
    if action.category == 'monster_ability_ready' and actor.owner_name then
        local ok, ability = pcall(function()
            return AshitaCore:GetResourceManager():GetAbilityById(
                    (tonumber(action.id) or 0) + 512)
        end)
        local pet_action_name = ok and resource_name(ability) or nil
        if pet_action_name then
            action.category = 'pet_ability_ready'
            action.name = pet_action_name
            event.action = action
        end
    end

    for _, target in ipairs(event.targets or {}) do
        local target_id = tonumber(target.server_id) or 0
        target.name = names[target_id] or target.name or ('Target ' .. tostring(target_id))
        target.relation = relations[target_id] or target.relation or 'unknown'
        target.party_slot = party_slots[target_id] or target.party_slot
        target.owner_name = owner_names[target_id] or target.owner_name
        if STATUS_MESSAGES[tonumber(target.message_id) or 0] then
            local ok, value = pcall(function()
                return AshitaCore:GetResourceManager():GetString('buffs.names', tonumber(target.amount) or 0, 2)
            end)
            if ok then
                target.status_name = clean_name(value)
            end
        end
        if tonumber(target.message_id) == 125 or tonumber(target.message_id) == 674 then
            local ok, item = pcall(function()
                return AshitaCore:GetResourceManager():GetItemById(tonumber(target.amount) or 0)
            end)
            if ok then target.item_name = resource_name(item) end
        end
    end
    return event
end

-- Packet-time resolution must stay constant-cost. It tries only the entity
-- index encoded in ordinary monster ids. Neither packet-time nor deferred
-- combat resolution scans the global entity table; an unresolved name keeps
-- the original game line instead of risking a frame-time spike.
function entities.resolve_immediate(event)
    if type(event) ~= 'table' then return event end
    local raw = event.raw or {}
    resolve_index(event.actor and event.actor.server_id, raw.actor_index)
    for _, target in ipairs(event.targets or {}) do
        resolve_index(target.server_id, raw.target_index)
    end
    resolve_direct(event.actor and event.actor.server_id)
    for _, target in ipairs(event.targets or {}) do
        resolve_direct(target.server_id)
    end
    return entities.resolve_event(event)
end

resource_name = function(resource)
    if type(resource) ~= 'table' and type(resource) ~= 'userdata' then
        return nil
    end
    local ok, value = pcall(function()
        local list = resource.Name
        return list and (list[1] or list[2])
    end)
    return ok and clean_name(value) or nil
end

function entities.action_name(event)
    local action = event and event.action or {}
    local category = tostring(action.category or '')
    local id = tonumber(action.id) or 0
    local fallback = category:gsub('_', ' ')
    -- Steal and Mug arrive in the weapon-skill packet category on Horizon;
    -- their result message ids identify the actual job ability reliably.
    for _, target in ipairs((event and event.targets) or {}) do
        local message_id = tonumber(target.message_id) or 0
        if message_id == 125 or message_id == 153 then return 'Steal' end
        if message_id == 129 then return 'Mug' end
        if message_id == 352 or message_id == 353 or message_id == 354
                or message_id == 576 or message_id == 577 then return 'Ranged Attack' end
    end
    if category == 'melee' or category == 'ranged' or category == 'ranged_ready' then
        return fallback
    end
    if id == 0 then
        return fallback ~= '' and fallback or 'action'
    end

    local ok, value = pcall(function()
        local resources = AshitaCore:GetResourceManager()
        if category == 'magic' or category == 'cast_start' then
            return resource_name(resources:GetSpellById(id))
        elseif category == 'item' or category == 'item_ready' then
            return resource_name(resources:GetItemById(id))
        elseif category == 'monster_ability' or category == 'monster_ability_ready' then
            if id <= 256 then
                return resource_name(resources:GetAbilityById(id))
            end
            return clean_name(resources:GetString('monsters.abilities', id - 256, 2))
        elseif category == 'ability' or category == 'ability_ready' or category == 'pet_ability'
                or category == 'pet_ability_ready'
                or category == 'dancer_ability' or category == 'rune_ability' then
            return resource_name(resources:GetAbilityById(id + 512))
        end
        if category == 'weapon_skill' then
            for _, target in ipairs((event and event.targets) or {}) do
                if JOB_ABILITY_MESSAGES[tonumber(target.message_id) or 0] then
                    local ability_name = resource_name(resources:GetAbilityById(id + 512))
                    if ability_name then return ability_name end
                    break
                end
            end
        end
        return resource_name(resources:GetAbilityById(id))
    end)
    if ok and value then
        return value
    end
    return string.format('%s #%d', fallback ~= '' and fallback or 'action', id)
end

return entities
