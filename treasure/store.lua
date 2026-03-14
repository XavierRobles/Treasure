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

local LIMBUS_PATH_FILE_TAG = {
    apollyon_west = 'Apollyon-NW',
    apollyon_east = 'Apollyon-NE',
    apollyon_south_west = 'Apollyon-SW',
    apollyon_south_east = 'Apollyon-SE',
    apollyon_central = 'Apollyon-Central',
    temenos_west = 'Temenos-West',
    temenos_east = 'Temenos-East',
    temenos_north = 'Temenos-North',
    temenos_central_1 = 'Temenos-Central1',
    temenos_central_2 = 'Temenos-Central2',
    temenos_central_3 = 'Temenos-Central3',
    temenos_central_4 = 'Temenos-Central4',
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

local function normalize_event_id(event_id)
    local id = tostring(event_id or ''):lower()
    if id == '' then
        return 'dynamis'
    end
    return id
end

local function title_case(s)
    return tostring(s or ''):gsub("(%a)([%w_']*)", function(a, b)
        return a:upper() .. b:lower()
    end)
end

local function event_prefix(event_id)
    local id = normalize_event_id(event_id)
    if id == 'dynamis' then
        return 'Dynamis'
    end
    return title_case(id)
end

local function fname(event_id, zid, ts, pname, run_index, zone_override)
    local ev_id = normalize_event_id(event_id)
    local zone_name = tostring(zone_override or '')
    if zone_name == '' then
        zone_name = ztag(zid)
    end
    if ev_id == 'dynamis' then
        return ('%s - %s - %s - %s.lua')
                :format(event_prefix(ev_id), zone_name, os.date('%Y-%m-%d', ts), pname)
    end
    local run = tonumber(run_index) or 1
    if run < 1 then
        run = 1
    end
    return ('%s - %s - %s - Run %d - %s.lua')
            :format(event_prefix(ev_id), zone_name, os.date('%Y-%m-%d', ts), run, pname)
end

local function esc_lua_pattern(s)
    return tostring(s or ''):gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
end

local function parse_filename_meta(filename)
    local f = tostring(filename or '')

    local ev, zone, date, run, player = f:match('^(.-)%s%-%s(.-)%s%-%s(%d%d%d%d%-%d%d%-%d%d)%s%-%s[Rr]un%s+(%d+)%s%-%s(.+)%.lua$')
    if ev and zone and date and run and player then
        return {
            event_prefix = ev,
            zone_tag = zone,
            date = date,
            run_index = tonumber(run) or 1,
            has_run = true,
            player = player,
        }
    end

    -- Legacy format: "<Event> - <zone> - <date> - <player>.lua"
    ev, zone, date, player = f:match('^(.-)%s%-%s(.-)%s%-%s(%d%d%d%d%-%d%d%-%d%d)%s%-%s(.+)%.lua$')
    if ev and zone and date and player then
        return {
            event_prefix = ev,
            zone_tag = zone,
            date = date,
            run_index = 1,
            has_run = false,
            player = player,
        }
    end

    return nil
end

local function scan_session_files()
    local files = {}
    local sep = package.config:sub(1, 1)
    local cmd

    if sep == '\\' then
        cmd = 'dir /b "' .. root:gsub('/', '\\') .. '"'
    else
        cmd = 'ls -1 "' .. root .. '"'
    end

    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            if line:match('%.lua$') then
                files[#files + 1] = line
            end
        end
        p:close()
    end

    return files
end

local function matching_run_files(event_id, zid, pname, day)
    local out = {}
    local prefix = event_prefix(event_id)
    local tag1 = ztag(zid)
    local tag2 = tostring(zid)
    local pref_pat = '^' .. esc_lua_pattern(prefix) .. '%s%-%s'

    for _, file in ipairs(scan_session_files()) do
        if file:match(pref_pat) then
            local meta = parse_filename_meta(file)
            if meta and meta.date == day and meta.player == pname then
                local zone_ok = (meta.zone_tag == tag1) or (meta.zone_tag == tag2)
                if (not zone_ok) and event_id == 'limbus' then
                    local mz = tostring(meta.zone_tag or '')
                    if (tag1 ~= '' and mz:sub(1, #tag1 + 1) == (tag1 .. '-'))
                            or (tag2 ~= '' and mz:sub(1, #tag2 + 1) == (tag2 .. '-')) then
                        zone_ok = true
                    end
                end
                if zone_ok then
                    out[#out + 1] = {
                        name = file,
                        run_index = tonumber(meta.run_index) or 1,
                        has_run = (meta.has_run == true),
                    }
                end
            end
        end
    end

    local ev_id = normalize_event_id(event_id)
    if ev_id == 'dynamis' then
        table.sort(out, function(a, b)
            local ar = (a.has_run == true)
            local br = (b.has_run == true)
            if ar ~= br then
                -- Prefer canonical Dynamis filenames without "Run N".
                return (not ar) and br
            end
            return tostring(a.name) > tostring(b.name)
        end)
    else
        table.sort(out, function(a, b)
            local ra = tonumber(a.run_index) or 1
            local rb = tonumber(b.run_index) or 1
            if ra ~= rb then
                return ra > rb
            end
            return tostring(a.name) > tostring(b.name)
        end)
    end

    return out
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
    local event_id_opt = nil
    if opts == true then
        force = true
    elseif type(opts) == 'table' then
        force = opts.force == true
        if tonumber(opts.min_interval) then
            min_interval = math.max(0, tonumber(opts.min_interval))
        end
        if type(opts.event_id) == 'string' then
            event_id_opt = opts.event_id
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

    local ev_id = normalize_event_id(sess.event_id or event_id_opt)
    local filename
    if ev_id == 'dynamis' then
        -- Policy: one Dynamis file per day and zone; no Run suffix.
        sess.run_index = 1
        filename = fname(ev_id, sess.zone_id, tonumber(sess.start_time) or os.time(), pname, 1)
        sess._filename = filename
    elseif sess._filename and sess._filename ~= '' then
        filename = sess._filename
    else
        local day = os.date('%Y-%m-%d', tonumber(sess.start_time) or os.time())
        local run_idx = tonumber(sess.run_index)
        if not run_idx or run_idx < 1 then
            local used = {}
            for _, it in ipairs(matching_run_files(ev_id, sess.zone_id, pname, day)) do
                local idx = tonumber(it.run_index) or 1
                used[idx] = true
            end
            run_idx = 1
            while used[run_idx] do
                run_idx = run_idx + 1
            end
            sess.run_index = run_idx
        end
        local zone_part = nil
        if ev_id == 'limbus' then
            local pid = tostring(sess.limbus_path_id or '')
            local mapped = LIMBUS_PATH_FILE_TAG[pid]
            if mapped and mapped ~= '' then
                zone_part = mapped
            end
        end
        filename = fname(ev_id, sess.zone_id, sess.start_time, pname, run_idx, zone_part)
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


function store.load(zid, opts)
    local ent = GetPlayerEntity()
    local pname = (ent and ent.Name)
    if not pname or pname == "UNKNOWN" then
        -- print("[Treasure][store] Session not loaded: player name is UNKNOWN")
        return nil
    end

    local ev_id = 'dynamis'
    if type(opts) == 'string' then
        ev_id = normalize_event_id(opts)
    elseif type(opts) == 'table' then
        if type(opts.event_id) == 'string' then
            ev_id = normalize_event_id(opts.event_id)
        end
    end

    local only_active = true
    if type(opts) == 'table' and opts.only_active ~= nil then
        only_active = (opts.only_active == true)
    end

    local today = os.date('%Y-%m-%d')
    local candidates = matching_run_files(ev_id, zid, pname, today)
    if #candidates == 0 then
        return nil
    end

    for _, cand in ipairs(candidates) do
        local fullpath = root .. cand.name
        local ok, sess = pcall(dofile, fullpath)
        if ok and type(sess) == 'table' then
            local can_use = ((not only_active) or (sess.ended ~= true))
            if only_active and ev_id == 'dynamis' then
                -- Policy: always resume today's Dynamis file for this zone/player.
                can_use = true
            end

            if can_use then
                sess._filename = cand.name

                if not sess.event_id or sess.event_id == '' then
                    local meta = parse_filename_meta(cand.name)
                    local pref = meta and meta.event_prefix or cand.name:match('^(.-)%s%-%s')
                    sess.event_id = normalize_event_id(pref)
                end
                if not sess.player_name or sess.player_name == '' then
                    local meta = parse_filename_meta(cand.name)
                    sess.player_name = (meta and meta.player) or sess.player_name
                end
                if not sess.run_index then
                    local meta = parse_filename_meta(cand.name)
                    sess.run_index = (meta and meta.run_index) or cand.run_index or 1
                end

                return sess
            end
        end
    end

    return nil
end

-- Returns a list of saved session filenames.
-- opts:
--   { event_id = 'dynamis' | 'limbus' | ... }  -- optional filter
function store.list_sessions(opts)
    local filter_event = nil
    if type(opts) == 'string' then
        filter_event = normalize_event_id(opts)
    elseif type(opts) == 'table' and type(opts.event_id) == 'string' then
        filter_event = normalize_event_id(opts.event_id)
    end

    local now = timeutil.now()
    if list_cache.files and (now - (list_cache.at or 0) <= LIST_CACHE_TTL) then
        local copy = {}
        local want_prefix = filter_event and (event_prefix(filter_event) .. ' - ') or nil
        for i = 1, #list_cache.files do
            local n = list_cache.files[i]
            if (not want_prefix) or (n:sub(1, #want_prefix) == want_prefix) then
                copy[#copy + 1] = n
            end
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

    local function run_key(fname)
        local meta = parse_filename_meta(fname)
        return (meta and tonumber(meta.run_index)) or 1
    end

    local p = io.popen(cmd)
    if p then
        for line in p:lines() do
            if line:match('%.lua$') then
                items[#items + 1] = { name = line, key = date_key(line), run = run_key(line) }
            end
        end
        p:close()
    end

    table.sort(items, function(a, b)
        if a.key ~= b.key then
            return a.key > b.key
        end
        if (a.run or 1) ~= (b.run or 1) then
            return (a.run or 1) > (b.run or 1)
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

    if not filter_event then
        return files
    end

    local out = {}
    local want_prefix = event_prefix(filter_event) .. ' - '
    for i = 1, #files do
        local n = files[i]
        if n:sub(1, #want_prefix) == want_prefix then
            out[#out + 1] = n
        end
    end
    return out
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
        -- "<Event> - <zone_tag> - <YYYY-MM-DD> - Run <n> - <player>.lua"
        -- Legacy: "<Event> - <zone_tag> - <YYYY-MM-DD> - <player>.lua"
        sess._filename = filename
        local meta = parse_filename_meta(filename)
        if not sess.event_id or sess.event_id == '' then
            local pref = (meta and meta.event_prefix) or filename:match('^(.-)%s%-%s')
            sess.event_id = normalize_event_id(pref)
        end
        if not sess.player_name or sess.player_name == '' then
            sess.player_name = (meta and meta.player) or sess.player_name
        end
        if not sess.run_index then
            sess.run_index = (meta and meta.run_index) or 1
        end
        return sess
    end
    return nil
end

return store
