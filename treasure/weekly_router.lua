---------------------------------------------------------------------------
-- Treasure · weekly_router.lua · Waky
-- Dispatcher for weekly/twice-weekly trackers (Eco-War, UIG, ENM...).
---------------------------------------------------------------------------

local ecowar = require('weekly.ecowar')
local highwind = require('weekly.highwind')
local quests = require('weekly.quests')

local router = {}

local HANDLERS = {
    ecowar = ecowar,
    highwind = highwind,
    quests = quests,
}

local ORDER = { 'ecowar', 'highwind', 'quests' }

local function normalize_id(id)
    return tostring(id or ''):lower()
end

function router.register(tracker_id, handler)
    local id = normalize_id(tracker_id)
    if id == '' or type(handler) ~= 'table' then return false end
    HANDLERS[id] = handler
    local exists = false
    for _, v in ipairs(ORDER) do
        if v == id then exists = true; break end
    end
    if not exists then ORDER[#ORDER + 1] = id end
    return true
end

function router.get(tracker_id)
    return HANDLERS[normalize_id(tracker_id)]
end

function router.list()
    local out = {}
    for _, id in ipairs(ORDER) do
        if HANDLERS[id] then out[#out + 1] = id end
    end
    return out
end

function router.init_all(player_name, base_dir)
    for _, id in ipairs(ORDER) do
        local h = HANDLERS[id]
        if h and h.init then h.init(player_name, base_dir) end
    end
end

local function dispatch(piece)
    for _, id in ipairs(ORDER) do
        local h = HANDLERS[id]
        if h and h.on_text then h.on_text(piece) end
    end
end

function router.on_text(line)
    if not line or line == '' then return end
    local raw = tostring(line):gsub('\r\n', '\n'):gsub('\r', '\n')
    -- Same un-glue as parser.handle_line: split glued timestamped chat lines.
    raw = raw:gsub('(%S)(%[%d%d:%d%d:%d%d%])', '%1\n%2')
    if raw:find('\n', 1, true) then
        for piece in raw:gmatch('[^\n]+') do
            if piece ~= '' then dispatch(piece) end
        end
    else
        dispatch(raw)
    end
end

function router.tick()
    for _, id in ipairs(ORDER) do
        local h = HANDLERS[id]
        if h and h.tick then h.tick() end
    end
end

function router.save_all()
    for _, id in ipairs(ORDER) do
        local h = HANDLERS[id]
        if h and h.save then h.save() end
    end
end

return router
