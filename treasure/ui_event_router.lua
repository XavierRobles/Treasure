---------------------------------------------------------------------------
-- Treasure · ui_event_router.lua · Waky
---------------------------------------------------------------------------

local dynamis = require('ui_event_dynamis')
local limbus = require('ui_event_limbus')

local router = {}

local HANDLERS = {
    dynamis = dynamis,
    limbus = limbus,
}

local function normalize_event_id(id)
    local s = tostring(id or ''):lower()
    if s == '' then
        return 'dynamis'
    end
    return s
end

function router.list()
    local out = {}
    for id in pairs(HANDLERS) do
        out[#out + 1] = id
    end
    table.sort(out)
    return out
end

function router.register(event_id, handler)
    local id = tostring(event_id or ''):lower()
    if id == '' or type(handler) ~= 'table' or type(handler.render) ~= 'function' then
        return false
    end
    HANDLERS[id] = handler
    return true
end

function router.set_active(ui, event_id)
    local id = normalize_event_id(event_id)
    if HANDLERS[id] then
        ui.active_event = id
        return true
    end
    return false
end

function router.get_active(ui)
    local id = normalize_event_id(ui and ui.active_event)
    if HANDLERS[id] then
        return id
    end
    return 'dynamis'
end

function router.get(event_id)
    local id = normalize_event_id(event_id)
    return HANDLERS[id]
end

local function select_event_id(ui, ctx)
    local from_ctx = tostring((ctx and ctx.event_id) or ''):lower()
    if from_ctx ~= '' and HANDLERS[from_ctx] then
        return from_ctx
    end
    return router.get_active(ui)
end

function router.top_left_status(ui, ctx)
    local id = select_event_id(ui, ctx)
    local handler = HANDLERS[id]
    if handler and handler.top_left_status then
        return handler.top_left_status(ctx)
    end
    return nil
end

function router.render(ui, ctx)
    local id = select_event_id(ui, ctx)
    local handler = HANDLERS[id]
    if handler and handler.render then
        handler.render(ctx)
    end
end

return router
