---------------------------------------------------------------------------
-- Treasure · store.lua · Waky
---------------------------------------------------------------------------

require('common')
local timeutil = require('timeutil')

local store = {}
local res = AshitaCore:GetResourceManager()
local root = ('%s\\config\\addons\\treasure\\sessions\\')
        :format(AshitaCore:GetInstallPath())
if not ashita.fs.exists(root) then
    ashita.fs.create_dir(root)
end

local SAVE_MIN_INTERVAL = 0.5
local LIST_CACHE_TTL = 2.0

local save_gate = setmetatable({}, { __mode = 'k' })
local list_cache = {
    at = 0,
    files = nil,
}

local function invalidate_list_cache()
    list_cache.at = 0
    list_cache.files = nil
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
-- opts:
--   true / { force = true } => bypass debounce guard.
--   { min_interval = <seconds> } => custom debounce interval.
function store.save(sess, opts)
    if type(sess) ~= 'table' then
        return false
    end

    local force = false
    local min_interval = SAVE_MIN_INTERVAL
    if opts == true then
        force = true
    elseif type(opts) == 'table' then
        force = opts.force == true
        if tonumber(opts.min_interval) then
            min_interval = math.max(0, tonumber(opts.min_interval))
        end
    end

    local now = timeutil.now()
    local last = save_gate[sess] or 0
    if (not force) and ((now - last) < min_interval) then
        return true
    end

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

    -- Do not persist live pool cache (recomputed from memory).
    local pool_live_bak = nil
    if sess.drops and sess.drops.pool_live then
        pool_live_bak = sess.drops.pool_live
        sess.drops.pool_live = nil
    end

    f:write('return ' .. dump(sess) .. '\n')
    f:close()

    if pool_live_bak then
        sess.drops.pool_live = pool_live_bak
    end

    save_gate[sess] = now
    invalidate_list_cache()

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
    local now = timeutil.now()
    if list_cache.files and (now - (list_cache.at or 0) <= LIST_CACHE_TTL) then
        local copy = {}
        for i = 1, #list_cache.files do
            copy[i] = list_cache.files[i]
        end
        return copy
    end

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

    list_cache.files = {}
    for i = 1, #files do
        list_cache.files[i] = files[i]
    end
    list_cache.at = now

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
