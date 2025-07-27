---------------------------------------------------------------------------
-- Treasure · parser.lua · Waky
---------------------------------------------------------------------------
local core = require('core')
local store = require('store')
local parser = {}

------------------------ sesión
function parser.new_session(zid)
    return {
        zone_id = zid,
        start_time = os.time(),
        drops = core.new_drop_state(),
        paused = nil,
    }
end

------------------------ helpers
local function strip(s)
    return (s or '')
            :gsub('\30.', '')
            :gsub('\31.', '')
            :gsub('[\0-\31]', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
end

local function clean(n)
    return n
            :gsub('^a pair of ', '')
            :gsub('^an? ', '')
            :gsub('^the ', '')
            :gsub('\127', '')
            :gsub('%.%d+$', '')
            :gsub('%.$', '')
end

local function add(tbl, key, qty)
    tbl[key] = (tbl[key] or 0) + qty
end

local function is_cur(i)
    i = i:lower()
    return i:find('bronzepiece')
            or i:find('whiteshell')
            or i:find('bill')
            or i:find('jadeshell')
            or i:find('silverpiece')
end

------------------------ patrones de chat
local FIND_ON = 'You find an? ([%w%s\'%-]+) on the'
local FIND_BOX = 'You find an? ([%w%s\'%-]+)%.'            -- treasure‑pool

local OBTAIN = '([%w\'%-]+)%s+obtains?%s+(.+)'

local LOST = 'You do not meet the requirements to obtain the ([%w%s\'\"%-]+)%.'

---------------------------------------------------------------------------
-- parser principal
---------------------------------------------------------------------------
local function handle(line, s)
    ------------------------------------------------------ LOST
    local lost_item = line:match(LOST)
    if lost_item then
        local item = clean(strip(lost_item))
        s.drops.lost = s.drops.lost or {}
        table.insert(s.drops.lost,
                string.format('%s  %s lost', os.date('%H:%M:%S'), item))
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
            qty = 1;
            item_raw = tail
        end

        local player = clean(strip(p_raw))
        local item = clean(strip(item_raw))

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
            local key = t.DropTime ~= 0 and t.DropTime or os.time() + slot
            parser._exp[key] = parser._exp[key] or os.clock() + 299
            s.drops.pool_live[slot] = {
                name = name,
                lot = t.WinningLot,
                winner = t.WinningEntityName,
                expire = parser._exp[key],
            }
        end
    end
end

function parser.new_session(zid)
    return {
        zone_id = zid,
        start_time = os.time(),
        drops = core.new_drop_state(),
        paused = nil,
        management = {},
    }
end

return parser
