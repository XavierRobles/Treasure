---------------------------------------------------------------------------
-- Treasure · log.lua · Waky
---------------------------------------------------------------------------

local fs = ashita.fs
local dir = ('%s\\config\\treasure\\summary\\')
        :format(AshitaCore:GetInstallPath())
if not fs.exists(dir) then
    fs.create_dir(dir)
end

local file = nil

local function open_file(sess)
    local name = os.date('%Y%m%d_%H%M%S_', sess.start_time)
            .. tostring(sess.zone_id) .. '.csv'
    file = io.open(dir .. name, 'w+')
    if file then
        file:write('Tipo,Jugador,Ítem,Cantidad\n')
    end
end

local function write_row(tipo, player, item, qty)
    if file then
        file:write(string.format('%s,%s,%s,%d\n',
                tipo, player or '', item, qty or 1))
    end
end

local log = {}

function log.open(sess)
    open_file(sess)
end

function log.append(sess, info)
    -- info = {a=action(FIND/OBTAIN/LOST), p=player, i=item, q=qty}
    write_row(info.a, info.p, info.i, info.q or 1)
end

function log.close(sess)
    if not file then
        return
    end
    for item, qty in pairs(sess.drops.currency_total) do
        write_row('TOTAL', '', item, qty)
    end
    for p, cur in pairs(sess.drops.by_player) do
        for it, qt in pairs(cur) do
            write_row('PLAYER', p, it, qt)
        end
    end
    for p, items in pairs(sess.drops.equips_by_player) do
        for _, it in ipairs(items) do
            write_row('EQUIP', p, it, 1)
        end
    end
    file:close();
    file = nil
end

return log
