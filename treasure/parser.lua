---------------------------------------------------------------------------
-- Treasure · parser.lua · Waky
---------------------------------------------------------------------------
local core = require('core')
local store = require('store')
local timeutil = require('timeutil')
local parser = {}

------------------------ sesión
function parser.new_session(zid)
    local now = os.time()
    local max_min = core.dynamis_max_minutes(zid)

    return {
        zone_id = zid,
        start_time = now,
        drops = core.new_drop_state(),
        paused = nil,
        management = {},

        dynamis_timer = {
            expel_at = nil,          -- os.time() absolute
            pending_ext = 0,         -- seconds
            fallback_end_at = now + (max_min * 60),
            desynced = false,
            last_sync_at = nil,
        },
    }
end


------------------------ helpers
local function strip(s)
    s = (s or '')
            :gsub('\30.', '')
            :gsub('\31.', '')
            :gsub('[\0-\31]', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')

    -- remove leading timestamp: [19:44:25]
    s = s:gsub('^%[%d%d:%d%d:%d%d%]%s*', '')
    -- remove leading channel tag: (Test) / (Party) / etc.
    s = s:gsub('^%b()%s*', '')

    return s
end

local function clean(n)
    return (n or '')
            :gsub('^a pair of ', '')
            :gsub('^an? ', '')
            :gsub('^the ', '')
            :gsub('\127', '')
            :gsub('%.%d+$', '')
            :gsub('%.$', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
end

local function add(tbl, key, qty)
    tbl[key] = (tbl[key] or 0) + qty
end

local function is_cur(i)
    i = (i or ''):lower()
    return i:find('bronzepiece')
            or i:find('whiteshell')
            or i:find('bill')
            or i:find('jadeshell')
            or i:find('silverpiece')
end

------------------------ patrones de chat
local FIND_ON = 'You find an? ([%w%s\'%-]+) on the'
local FIND_BOX = 'You find an? ([%w%s\'%-]+)%.' -- treasure-pool

local OBTAIN = '([%w\'%-]+)%s+obtains?%s+(.+)'

local LOST_REQ = 'You do not meet the requirements to obtain the ([%w%s\'"%-]+)%.' -- system msg
local LOST_A = '^(.+)%s+lost%.$'
local LOST_B = '^(.+)%s+is%s+lost%.$'

local function parse_lost_item(line)
    line = strip(line)

    local it = line:match(LOST_REQ)
    if it then
        return clean(strip(it))
    end

    it = line:match(LOST_B)
    if it then
        return clean(strip(it))
    end

    it = line:match(LOST_A)
    if it then
        return clean(strip(it))
    end

    return nil
end

local DYN_EXPEL = 'you will be expelled from dynamis in%s+(%d+)%s+(%a+)'
local DYN_EXT   = 'your stay in dynamis has been extended by%s+(%d+)%s+(%a+)'

local function unit_to_seconds(n, unit)
    n = tonumber(n) or 0
    unit = (unit or ''):lower()

    if unit:find('second', 1, true) then
        return n
    end
    if unit:find('minute', 1, true) then
        return n * 60
    end

    return 0
end


local function ensure_dynamis_timer(s)
    if not s.dynamis_timer then
        local max_min = core.dynamis_max_minutes(s.zone_id)
        s.dynamis_timer = {
            expel_at = nil,
            pending_ext = 0,
            fallback_end_at = (tonumber(s.start_time) or os.time()) + (max_min * 60),
            desynced = false,
            last_sync_at = nil,
        }
        return
    end

    if not s.dynamis_timer.fallback_end_at then
        local max_min = core.dynamis_max_minutes(s.zone_id)
        s.dynamis_timer.fallback_end_at = (tonumber(s.start_time) or os.time()) + (max_min * 60)
    end
end

local function handle_dynamis_timer_line(line, s)
    if not s then
        return false
    end

    local l = (line or ''):lower()
    if l == '' then
        return false
    end

    ensure_dynamis_timer(s)

    local n1, u1 = l:match(DYN_EXPEL)
    if n1 and u1 then
        local now = os.time()
        local rem = unit_to_seconds(n1, u1)

        s.dynamis_timer.expel_at = now + rem + (tonumber(s.dynamis_timer.pending_ext) or 0)
        s.dynamis_timer.pending_ext = 0
        s.dynamis_timer.desynced = false
        s.dynamis_timer.last_sync_at = now

        if s.dynamis_timer.fallback_end_at and s.dynamis_timer.expel_at > s.dynamis_timer.fallback_end_at then
            s.dynamis_timer.fallback_end_at = s.dynamis_timer.expel_at
        end

        store.save(s)
        return true
    end

    local n2, u2 = l:match(DYN_EXT)
    if n2 and u2 then
        local ext = unit_to_seconds(n2, u2)

        if s.dynamis_timer.expel_at then
            s.dynamis_timer.expel_at = s.dynamis_timer.expel_at + ext
        else
            s.dynamis_timer.pending_ext = (tonumber(s.dynamis_timer.pending_ext) or 0) + ext
        end

        store.save(s)
        return true
    end

    return false
end


---------------------------------------------------------------------------
-- parser principal
---------------------------------------------------------------------------
local function handle(line, s)
    line = strip(line)

    if handle_dynamis_timer_line(line, s) then
        return
    end

    ------------------------------------------------------ LOST
    local lost_item = parse_lost_item(line)
    if lost_item and lost_item ~= '' then
        local item = lost_item
        s.drops.lost = s.drops.lost or {}
        s.drops.lost_total = s.drops.lost_total or {}

        table.insert(s.drops.lost,
                string.format('%s  %s lost', os.date('%H:%M:%S'), item))

        s.drops.lost_total[item] = (s.drops.lost_total[item] or 0) + 1

        store.save(s)
        return
    end

    ------------------------------------------------------ FIND
    if line:match(FIND_ON) or line:match(FIND_BOX) then
        return
    end

    ------------------------------------------------------ OBTAIN
    local p_raw, tail = line:match(OBTAIN)
    if p_raw and tail then
        local qty, item_raw = tail:match('^(%d+)%s+(.+)$')
        if qty then
            qty = tonumber(qty)
        else
            qty = 1
            item_raw = tail
        end

        local player = clean(strip(p_raw))
        local item = clean(strip(item_raw))

        -- Prevent bogus "to" entries (was polluting by_player / items / management)
        if player:lower() == 'to' then
            return
        end

        if is_cur(item) then
            -- divisa
            add(s.drops.currency_total, item, qty)
            s.drops.by_player[player] = s.drops.by_player[player] or {}
            add(s.drops.by_player[player], item, qty)
        else
            -- equipo
            -- lista de piezas sueltas
            s.drops.equips_by_player[player] = s.drops.equips_by_player[player] or {}
            table.insert(s.drops.equips_by_player[player], item)

            -- by_player
            s.drops.by_player[player] = s.drops.by_player[player] or {}
            add(s.drops.by_player[player], item, qty)
        end
        store.save(s)
    end
end

function parser.handle_line(txt, s)
    local ok, err = pcall(function()
        handle(strip(txt), s)
    end)
    if not ok then
        print('[ED][ERROR parser] ' .. tostring(err))
    end
end

------------------------ treasure pool
local mm = AshitaCore:GetMemoryManager()
local rm = AshitaCore:GetResourceManager()
parser._exp = parser._exp or {}

function parser.update_treasure_pool(s)
    if not s or not s.drops then
        return
    end
    s.drops.pool_live = {}
    local inv = mm:GetInventory()
    for slot = 0, 9 do
        local t = inv:GetTreasurePoolItem(slot)
        if t and t.ItemId ~= 0 then
            local name = (rm:GetItemById(t.ItemId) or {}).Name
            name = name and name[1] or ('ID:' .. t.ItemId)

            local key
            if t.DropTime ~= 0 then
                key = 'dt:' .. tostring(t.DropTime)
            else
                key = string.format('s:%d:%d', slot, t.ItemId)
            end

            parser._exp[key] = parser._exp[key] or (timeutil.now() + 299)
            s.drops.pool_live[slot] = {
                name = name,
                lot = t.WinningLot,
                winner = t.WinningEntityName,
                expire = parser._exp[key],
            }
        end
    end
end

return parser
