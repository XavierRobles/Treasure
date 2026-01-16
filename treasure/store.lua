---------------------------------------------------------------------------
-- Treasure · store.lua · Waky
---------------------------------------------------------------------------

require('common')

local store = {}
local res = AshitaCore:GetResourceManager()
local root = ('%s\\config\\addons\\treasure\\sessions\\')
        :format(AshitaCore:GetInstallPath())
if not ashita.fs.exists(root) then
    ashita.fs.create_dir(root)
end

local zone_tag = {
    [134] = 'Beauc', [135] = 'Xarcabard', [185] = 'Sandy', [186] = 'Bastok',
    [187] = 'Windy', [188] = 'Jeuno',
    -- Dreamland zones (Dynamis - <zone>)
    [39] = 'Valkurm', [40] = 'Buburimu', [41] = 'Qufim', [42] = 'Tavnazia',
    -- Dynamis-Divergence cities
    [294] = 'Sandy[D]', [295] = 'Bastok[D]', [296] = 'Windy[D]', [297] = 'Jeuno[D]',
}

local function ztag(zid)
    if zone_tag[zid] then
        return zone_tag[zid]
    end

    local name = (res and res:GetString('zones.names', zid)) or ''
    if name ~= '' then
        -- Common forms: "Dynamis - Valkurm", "Dynamis - San d'Oria", "Dynamis - San d'Oria [D]"
        local part = name:match('^Dynamis%s*%-%s*(.+)$') or name:match('^Dynamis%s+(.+)$')
        if part and part ~= '' then
            local normalize = {
                ["San d'Oria"] = 'Sandy',
                ["Bastok"] = 'Bastok',
                ["Windurst"] = 'Windy',
                ["Jeuno"] = 'Jeuno',
                ["Beaucedine"] = 'Beauc',
                ["Beaucedine Glacier"] = 'Beauc',
                ["Xarcabard"] = 'Xarcabard',
            }
            return normalize[part] or part
        end
        return name
    end

    return tostring(zid)
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

-- Saves a session table to disk.
function store.save(sess)
    -- Get the current character name.
    local ent = GetPlayerEntity()
    local pname = (ent and ent.Name) or (sess and sess.player_name) or "UNKNOWN"
    if not pname or pname == "UNKNOWN" then
        -- print("[Treasure][store] Session not saved: player name is UNKNOWN")
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
        -- print("[Treasure][store] Session not loaded: player name is UNKNOWN")
        return nil
    end

    local today = os.date('%Y-%m-%d')
    local tag = ztag(zid)
    local pattern = ('Dynamis - %s - %s - %s.lua'):format(tag, today, pname)
    local fullpath = root .. pattern

    -- Backward-compat: old sessions may have been saved as "Dynamis - <zone_id> - ..."
    if not ashita.fs.exists(fullpath) then
        local fallback = ('Dynamis - %s - %s - %s.lua'):format(tostring(zid), today, pname)
        local fallback_path = root .. fallback
        if ashita.fs.exists(fallback_path) then
            pattern = fallback
            fullpath = fallback_path
        else
            return nil
        end
    end

    local ok, sess = pcall(dofile, fullpath)
    if not ok or not sess then
        return nil
    end
    if type(sess) == 'table' then
        sess._filename = pattern
        if not sess.player_name or sess.player_name == '' then
            local p2 = pattern:match(' %- ([^%-]+)%.lua$')
            sess.player_name = p2 or sess.player_name
        end
    end
    return sess
end

-- Returns a list of saved session filenames.
function store.list_sessions()
    local items = {}
    local sep = package.config:sub(1, 1)
    local cmd

    if sep == '\\' then
        cmd = 'dir /b "' .. root:gsub('/', '\\') .. '"'
    else
        cmd = 'ls -1 "' .. root .. '"'
    end

    local function date_key(fname)
        local y, m, d = fname:match('%s%-%s(%d%d%d%d)%-(%d%d)%-(%d%d)%s%-%s')
        if not y then
            return 0
        end
        return (tonumber(y) or 0) * 10000 + (tonumber(m) or 0) * 100 + (tonumber(d) or 0)
    end

    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            if line:match('%.lua$') then
                items[#items + 1] = { name = line, key = date_key(line) }
            end
        end
        p:close()
    end

    table.sort(items, function(a, b)
        if a.key ~= b.key then
            return a.key > b.key
        end
        return a.name < b.name
    end)

    local files = {}
    for i = 1, #items do
        files[#files + 1] = items[i].name
    end
    return files
end


-- Loads a session from a given filename.
function store.load_file(filename)
    if not filename or filename == '' then
        return nil
    end
    local path = root .. filename
    local ok, sess = pcall(dofile, path)
    if ok and type(sess) == 'table' then
        -- Filename convention:
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
