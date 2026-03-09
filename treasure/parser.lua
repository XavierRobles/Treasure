---------------------------------------------------------------------------
-- Treasure · parser.lua · Waky
---------------------------------------------------------------------------
local core = require('core')
local store = require('store')
local timeutil = require('timeutil')
local parser = {}

------------------------ sesión
function parser.new_session(zid, opts)
    opts = opts or {}
    local event_id = tostring(opts.event_id or 'dynamis'):lower()
    local now = os.time()

    local sess = {
        event_id = event_id,
        zone_id = zid,
        start_time = now,
        drops = core.new_drop_state(),
        paused = nil,
        management = {},
    }

    if event_id == 'dynamis' then
        local max_min = core.dynamis_max_minutes(zid)
        sess.dynamis_timer = {
            expel_at = nil,          -- os.time() absolute
            pending_ext = 0,         -- seconds
            fallback_end_at = now + (max_min * 60),
            desynced = false,
            last_sync_at = nil,
        }
    end

    return sess
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

local STEAL_CURRENCIES = {
    'Tukuku Whiteshell',
    'Ordelle Bronzepiece',
    'One Byne Bill',
}

local function ensure_steal_personal_state(s)
    s.drops = s.drops or core.new_drop_state()
    s.drops.steal_personal = s.drops.steal_personal or {}

    local sp = s.drops.steal_personal
    sp.attempts = tonumber(sp.attempts) or 0
    sp.success = tonumber(sp.success) or 0
    sp.failed = tonumber(sp.failed) or 0
    sp.pending = tonumber(sp.pending) or 0
    sp.by_currency = sp.by_currency or {}

    for _, name in ipairs(STEAL_CURRENCIES) do
        sp.by_currency[name] = tonumber(sp.by_currency[name]) or 0
    end

    return sp
end

local function local_player_name(s)
    local ent = GetPlayerEntity()
    local from_memory = ent and ent.Name or ''
    from_memory = clean(strip(from_memory))
    if from_memory ~= '' and from_memory:lower() ~= 'unknown' then
        return from_memory
    end

    local from_session = clean(strip((s and s.player_name) or ''))
    if from_session ~= '' and from_session:lower() ~= 'unknown' then
        return from_session
    end

    return ''
end

local function is_local_player_line(s, player_name)
    local me = local_player_name(s)
    local other = clean(strip(player_name))
    if me == '' or other == '' then
        return false
    end
    return me:lower() == other:lower()
end

local function steal_currency_label(item_name)
    local n = (item_name or ''):lower()

    -- This tracker is intended for the 1-piece currency steals only.
    if n:find('silverpiece', 1, true) or n:find('jadeshell', 1, true) then
        return nil
    end
    if n:find('one hundred', 1, true) or n:find('100', 1, true) then
        return nil
    end

    if n:find('whiteshell', 1, true) then
        return 'Tukuku Whiteshell'
    end
    if n:find('bronzepiece', 1, true) then
        return 'Ordelle Bronzepiece'
    end
    if n:find('byne bill', 1, true) then
        return 'One Byne Bill'
    end
    return nil
end

------------------------ patrones de chat
local FIND_ON = 'You find an? ([%w%s\'%-]+) on the'
local FIND_BOX = 'You find an? ([%w%s\'%-]+)%.' -- treasure-pool

local OBTAIN = '([%w\'%-]+)%s+obtains?%s+(.+)'
local STEAL_USE = '^([%w\'%-]+)%s+uses%s+steal[%.!]*$'
local STEAL_OK = '^([%w\'%-]+)%s+steals%s+an?%s+(.+)%s+from%s+.+[%.!]*$'
local STEAL_FAIL = '^([%w\'%-]+)%s+fails%s+to%s+steal%s+from%s+.+[%.!]*$'
local STEAL_FAIL_ALT = '^([%w\'%-]+)%s+cannot%s+steal%s+anything%s+from%s+.+[%.!]*$'
local STEAL_DEDUPE_WINDOW = 1.25
local steal_seen = {}

local function should_skip_steal_event(kind, actor, detail)
    local now = timeutil.now()
    local key = string.format('%s|%s|%s',
            tostring(kind or ''),
            tostring(actor or ''):lower(),
            tostring(detail or ''):lower())

    local last = steal_seen[key]
    if last and (now - last) < STEAL_DEDUPE_WINDOW then
        return true
    end
    steal_seen[key] = now

    -- Light cleanup to keep table bounded.
    local count = 0
    for _ in pairs(steal_seen) do
        count = count + 1
    end
    if count > 96 then
        local cutoff = now - (STEAL_DEDUPE_WINDOW * 4)
        for k, ts in pairs(steal_seen) do
            if ts < cutoff then
                steal_seen[k] = nil
            end
        end
    end

    return false
end

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
    local ev = tostring(s.event_id or 'dynamis'):lower()
    if ev ~= 'dynamis' then
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
    local line_l = (line or ''):lower()
    local event_id = tostring((s and s.event_id) or 'dynamis'):lower()

    -- Ignore addon-generated chat output.
    if line_l:find('[treasure]', 1, true) then
        return
    end

    if handle_dynamis_timer_line(line, s) then
        return
    end

    ------------------------------------------------------ STEAL (Dynamis only, personal / local player)
    if event_id == 'dynamis' then
        local use_name = line_l:match(STEAL_USE)
        if use_name then
            if is_local_player_line(s, use_name) then
                if should_skip_steal_event('use', use_name) then
                    return
                end
                local sp = ensure_steal_personal_state(s)
                sp.attempts = sp.attempts + 1
                sp.pending = sp.pending + 1
                store.save(s)
                return
            end
        end

        local fail_name = line_l:match(STEAL_FAIL) or line_l:match(STEAL_FAIL_ALT)
        if fail_name then
            if is_local_player_line(s, fail_name) then
                if should_skip_steal_event('fail', fail_name) then
                    return
                end
                local sp = ensure_steal_personal_state(s)
                if sp.pending > 0 then
                    sp.pending = sp.pending - 1
                else
                    sp.attempts = sp.attempts + 1
                end
                sp.failed = sp.failed + 1
                store.save(s)
                return
            end
        end

        local steal_name, item_raw = line_l:match(STEAL_OK)
        if steal_name and item_raw then
            if is_local_player_line(s, steal_name) then
                local clean_item = clean(strip(item_raw))
                if should_skip_steal_event('ok', steal_name, clean_item) then
                    return
                end
                local sp = ensure_steal_personal_state(s)
                if sp.pending > 0 then
                    sp.pending = sp.pending - 1
                else
                    sp.attempts = sp.attempts + 1
                end
                sp.success = sp.success + 1

                local label = steal_currency_label(clean_item)
                if label then
                    sp.by_currency[label] = (sp.by_currency[label] or 0) + 1
                end

                store.save(s)
                return
            end
        end
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
        local raw = tostring(txt or '')
        raw = raw:gsub('\r\n', '\n'):gsub('\r', '\n')
        -- Some clients can deliver multiple timestamped chat lines glued together.
        raw = raw:gsub('(%S)(%[%d%d:%d%d:%d%d%])', '%1\n%2')

        for piece in raw:gmatch('[^\n]+') do
            local chunk = strip(piece)
            if chunk ~= '' then
                handle(chunk, s)
            end
        end
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
                item_id = t.ItemId,
                drop_time = tonumber(t.DropTime) or 0,
                lot = t.WinningLot,
                winner = t.WinningEntityName,
                expire = parser._exp[key],
            }
        end
    end
end

return parser
