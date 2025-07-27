---------------------------------------------------------------------------
-- Treasure · store.lua · Waky
---------------------------------------------------------------------------

require('common')

local store = {}
local root = ('%s\\config\\addons\\treasure\\sessions\\')
        :format(AshitaCore:GetInstallPath())
if not ashita.fs.exists(root) then
    ashita.fs.create_dir(root)
end

local zone_tag = {
    [134] = 'Beauc', [135] = 'Xarcabard', [185] = 'Sandy', [186] = 'Bastok',
    [187] = 'Windy', [188] = 'Jeuno',
}
local function ztag(zid)
    return zone_tag[zid] or tostring(zid)
end
local function fname(zid, ts, pname)
    return ('Dynamis - %s - %s - %s.lua')
            :format(ztag(zid), os.date('%Y-%m-%d', ts), pname)
end

local function dump(tbl, ind)
    ind = ind or ''
    local out = '{\n'
    for k, v in pairs(tbl) do
        if type(k) == 'number' then
            out = out .. ind .. '  [' .. k .. '] = '
        else
            out = out .. ind .. '  [' .. string.format('%q', k) .. '] = '
        end
        if type(v) == 'table' then
            out = out .. dump(v, ind .. '  ')
        elseif type(v) == 'string' then
            out = out .. string.format('%q', v)
        else
            out = out .. tostring(v)
        end
        out = out .. ',\n'
    end
    return out .. ind .. '}'
end

-- Save a session table to disk.
function store.save(sess)
    -- Obtain the player's current character name.
    local ent = GetPlayerEntity()
    local pname = (ent and ent.Name) or (sess and sess.player_name) or "UNKNOWN"
    if not pname or pname == "UNKNOWN" then
        -- print("[Treasure][store] No se guarda la sesión: nombre de jugador UNKNOWN")
        return false
    end
    sess.player_name = pname
    local filename
    if sess._filename and sess._filename ~= '' then
        filename = sess._filename
    else
        filename = fname(sess.zone_id, sess.start_time, pname)
        sess._filename = filename
    end
    local path = root .. filename
    local f = io.open(path, 'w+')
    if not f then
        return false
    end
    f:write('return ' .. dump(sess) .. '\n')
    f:close()
    return true
end

function store.load(zid)
    local ent = GetPlayerEntity()
    local pname = (ent and ent.Name)
    if not pname or pname == "UNKNOWN" then
        -- print("[Treasure][store] No se carga la sesión: nombre de jugador UNKNOWN")
        return nil
    end
    local path = root .. fname(zid, os.time(), pname)
    local pattern = ('Dynamis - %s - %s - %s.lua')
            :format(ztag(zid), os.date('%Y-%m-%d'), pname)
    local fullpath = root .. pattern
    if not ashita.fs.exists(fullpath) then
        return nil
    end
    local ok, sess = pcall(dofile, fullpath)
    if not ok or not sess then
        return nil
    end
    if type(sess) == 'table' then
        sess._filename = pattern
        if not sess.player_name or sess.player_name == '' then
            local pname = pattern:match(' %- ([^%-]+)%.lua$')
            sess.player_name = pname or sess.player_name
        end
    end
    return sess
end

-- Devuelve una lista de nombres de ficheros de sesión
function store.list_sessions()
    local files = {}
    local sep = package.config:sub(1, 1) -- '\\' en Windows, '/' en Unix
    local cmd
    if sep == '\\' then
        -- Comando DIR para Windows
        cmd = 'dir /b "' .. root:gsub('/', '\\') .. '"'
    else
        -- Comando ls para sistemas tipo Unix
        cmd = 'ls -1 "' .. root .. '"'
    end
    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            if line:match('%.lua$') then
                table.insert(files, line)
            end
        end
        p:close()
    end
    table.sort(files)
    return files
end

-- Carga una sesión guardada a partir de su nombre.
function store.load_file(filename)
    if not filename or filename == '' then
        return nil
    end
    local path = root .. filename
    local ok, sess = pcall(dofile, path)
    if ok and type(sess) == 'table' then
        -- filename.  The file naming convention is:
        -- "Dynamis - <zone_tag> - <YYYY-MM-DD> - <player>.lua"
        sess._filename = filename
        if not sess.player_name or sess.player_name == '' then
            local pname = filename:match(' %- ([^%-]+)%.lua$')
            sess.player_name = pname or sess.player_name
        end
        return sess
    end
    return nil
end

return store
