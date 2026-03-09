---------------------------------------------------------------------------
-- Treasure · event_dynamis.lua · Waky
---------------------------------------------------------------------------

local core = require('core')
local parser = require('parser')
local store = require('store')

local dynamis = {
    id = 'dynamis',
    title = 'Dynamis',
}

local function ensure_timer(sess, zid)
    if not sess then
        return
    end

    sess.dynamis_timer = sess.dynamis_timer or {
        expel_at = nil,
        pending_ext = 0,
        fallback_end_at = nil,
        desynced = false,
        last_sync_at = nil,
    }

    local start = tonumber(sess.start_time) or os.time()
    sess.start_time = start

    local max_min = core.dynamis_max_minutes(zid or sess.zone_id)
    sess.dynamis_timer.fallback_end_at = start + (max_min * 60)

    if sess.dynamis_timer.expel_at and sess.dynamis_timer.expel_at > sess.dynamis_timer.fallback_end_at then
        sess.dynamis_timer.fallback_end_at = sess.dynamis_timer.expel_at
    end
end

function dynamis.is_zone(zid)
    return core.is_dynamis(zid)
end

function dynamis.on_enter(ctx)
    local zid = tonumber(ctx and ctx.zid) or 0
    local now = tonumber(ctx and ctx.now) or os.time()
    local zone_name = tostring((ctx and ctx.zone_name) or ('Zone ' .. tostring(zid)))

    local saved = store.load(zid, { event_id = dynamis.id, only_active = true })
    if saved then
        saved.event_id = dynamis.id
        ensure_timer(saved, zid)
        saved.ended = false
        saved.is_event = true
        saved.management = saved.management or {}
        saved.split = saved.split or { event_type = 'Custom', duration_minutes = 0 }
        return saved, string.format('%s continues. Inventorys ready, ambition reloaded.', zone_name)
    end

    local sess = parser.new_session(zid, { event_id = dynamis.id })
    if not sess then
        return nil, nil
    end

    sess.event_id = dynamis.id
    ensure_timer(sess, zid)
    sess.is_event = true
    sess.zone_id = zid
    sess.start_time = now
    sess.management = {}
    sess.split = sess.split or { event_type = 'Custom', duration_minutes = 0 }
    sess.ended = false

    store.save(sess, { event_id = dynamis.id })
    return sess, string.format('Entering %s with 0 hope and 100%% hundo ambition..', zone_name)
end

function dynamis.on_leave(sess, opts)
    if not (sess and sess.is_event) then
        return nil
    end
    sess.ended = true
    store.save(sess, { force = true, event_id = dynamis.id })
    return nil
end

function dynamis.on_text(line, sess)
    parser.handle_line(line, sess)
end

return dynamis
