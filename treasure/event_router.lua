---------------------------------------------------------------------------
-- Treasure · event_router.lua · Waky
---------------------------------------------------------------------------

local dynamis = require('event_dynamis')
local limbus = require('event_limbus')

local router = {}

local HANDLERS = {
    dynamis = dynamis,
    limbus = limbus,
}

local ORDER = { 'dynamis', 'limbus' }

local function normalize_id(event_id)
    local s = tostring(event_id or ''):lower()
    return s
end

local function title_case(s)
    return tostring(s or ''):gsub("(%a)([%w_']*)", function(a, b)
        return a:upper() .. b:lower()
    end)
end

function router.register(event_id, handler)
    local id = normalize_id(event_id)
    if id == '' or type(handler) ~= 'table' or type(handler.is_zone) ~= 'function' then
        return false
    end

    HANDLERS[id] = handler

    local exists = false
    for _, v in ipairs(ORDER) do
        if v == id then
            exists = true
            break
        end
    end
    if not exists then
        ORDER[#ORDER + 1] = id
    end
    return true
end

function router.get(event_id)
    local id = normalize_id(event_id)
    return HANDLERS[id]
end

function router.list()
    local out = {}
    for _, id in ipairs(ORDER) do
        if HANDLERS[id] then
            out[#out + 1] = id
        end
    end
    return out
end

function router.match_zone(zid)
    for _, id in ipairs(ORDER) do
        local h = HANDLERS[id]
        if h and h.is_zone and h.is_zone(zid) then
            return id, h
        end
    end
    return nil, nil
end

function router.title(event_id)
    local id = normalize_id(event_id)
    if id == '' then
        return 'Event'
    end
    local h = HANDLERS[id]
    if h and h.title and h.title ~= '' then
        return h.title
    end
    return title_case(id)
end

return router
