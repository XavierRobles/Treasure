--------------------------------------------------------------------------------
-- Addon: Treasure
-- Autor: Waky
-- Versión: 1.0.3
-- Descripción:
--   Registra en tiempo real todos los objetos en eventos y 
-- los muestra en una interfaz personalizable
--------------------------------------------------------------------------------

addon = addon or {}
addon.name = 'Treasure'
addon.author = 'Waky'
addon.version = '1.0.3'

require('common')
local settings = require('settings')
local core = require('core')
local parser = require('parser')
local store = require('store')
local ui = require('ui')
local fs = ashita.fs
local chat = require('chat')

------------------------------------------------------------------ utilidades
-- Serializar
local function _dump_cfg(tbl, ind)
    ind = ind or ''
    local out = '{\n'
    for k, v in pairs(tbl) do
        if (type(k) ~= 'string' or k:sub(1, 1) ~= '_') and type(v) ~= 'function' then
            out = out .. ind .. '  [' ..
                    (type(k) == 'number' and k or string.format('%q', k)) .. '] = '
            if type(v) == 'table' then
                out = out .. _dump_cfg(v, ind .. '  ')
            elseif type(v) == 'string' then
                out = out .. string.format('%q', v)
            else
                out = out .. tostring(v)
            end
            out = out .. ',\n'
        end
    end
    return out .. ind .. '}'
end

local SEP = "\xFD\x01\x02\x05\xA9\xFD"
local STAR = string.char(0x81, 0x9A)
local STAR_WHITE = string.char(0x81, 0x99) -- ☆
local DOT_HUGE = string.char(0x81, 0x9C) -- ●
local DOT_HUGE_OPEN = string.char(0x81, 0x9B) -- ○
local DOT_SMALL    = string.char(0x81, 0x45) -- ・
------------------------------------------------------------------ estado
local session, idle_session, lastPool, lastSave = nil, nil, 0, 0
local cfg, lastPrefSave = nil, 0

------------------------------------------------------------------ party chat queue (rate limit)
local party_chat_queue = {}
local last_party_chat_sent = 0
local PARTY_CHAT_DELAY = 2.0

local function enqueue_party_chat(msg)
    if not msg or msg == '' then
        return
    end
    party_chat_queue[#party_chat_queue + 1] = msg
end

local function process_party_chat_queue()
    if #party_chat_queue == 0 then
        return
    end
    if (os.clock() - last_party_chat_sent) < PARTY_CHAT_DELAY then
        return
    end

    local msg = table.remove(party_chat_queue, 1)
    AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. msg)
    last_party_chat_sent = os.clock()
end


------------------------------------------------------------------ helpers
local function is_ui_fully_hidden()
    local addr = ashita.memory.find('FFXiMain.dll', 0,
            '8B4424046A016A0050B9????????E8????????F6D81BC040C3', 0, 0)
    if addr == 0 then
        return false
    end
    local ptr = ashita.memory.read_uint32(addr + 10)
    return ptr ~= 0 and ashita.memory.read_uint8(ptr + 0xB4) == 1
end

local hidden_menus = { fulllog = true, equip = true, inventor = true, mnstorag = true, iuse = true,
                       map0 = true, maplist = true, mapframe = true, scanlist = true, cnqframe = true, conf2win = true,
                       cfilter = true, textcol1 = true, confyn = true, conf5m = true, conf5win = true, conf5w1 = true,
                       conf5w2 = true, conf11m = true, conf11l = true, conf11s = true, conf3win = true, conf6win = true,
                       conf12wi = true, conf13wi = true, fxfilter = true, conf7 = true, conf4 = true, link5 = true,
                       link12 = true, link13 = true, link3 = true, scresult = true, evitem = true, statcom2 = true,
                       auc1 = true, moneyctr = true, shopsell = true, comyn = true, auclist = true, auchisto = true,
                       auc4 = true, post1 = true, post2 = true, stringdl = true, delivery = true, mcr1edlo = true,
                       mcr2edlo = true, mcrbedit = true, mcresed = true, bank = true, handover = true, itmsortw = true,
                       sortyn = true, itemctrl = true, loot = true, lootope = true, meritcat = true, merit1 = true,
                       merit2 = true, merit3 = true, merityn = true, shop = true, automato = true, bluinven = true,
                       bluequip = true, quest00 = true, quest01 = true, miss00 = true, faqsub = true, cmbhlst = true }

local function is_hiding_menu_active()
    local addr = ashita.memory.find('FFXiMain.dll', 0,
            '8B480C85C974??8B510885D274??3B05', 16, 0)
    if addr == 0 then
        return false
    end

    local ptr = ashita.memory.read_uint32(addr)
    if ptr == 0 then
        return false
    end
    ptr = ashita.memory.read_uint32(ptr)
    if ptr == 0 then
        return false
    end

    local header = ashita.memory.read_uint32(ptr + 4)
    if header == 0 then
        return false
    end

    local raw = ashita.memory.read_string(header + 0x46, 16)
    if not raw then
        return false
    end

    local cleaned = raw:gsub('\0', '')
    if #cleaned >= 9 then
        cleaned = cleaned:sub(9)
    else
        cleaned = ''
    end
    cleaned = cleaned:gsub(' ', '')

    return hidden_menus[cleaned] == true
end

local function in_world()
    local ent = GetPlayerEntity()
    if not ent then
        return false
    end
    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    return zid ~= 0 and zid ~= 0xFFFF
end

------------------------------------------------------------------ default cfg
local DEFAULT_CONFIG = {
    visible = true, theme = 'Default', alpha = 0.90, timeout = 30,
    colors = {
        QTY = { 1, 1, 1, 1 }, CUR = { 0.1725, 1, 0.0431, 1 },
        ITEM = { 0, 1, 0.9961, 1 }, HUNDO = { 1, 0.84, 0, 1 },
        NAME = { 0.55, 0.78, 1, 1 }, LOST = { 1, 0.35, 0.35, 1 },
    },
    layout = {
        full = {
            window = { x = 536, y = 129, w = 605, h = 314 },
            cols = { 112.85, 112.96, 60.51, 302.68 },
            all_cols = { 109.93, 121.03, 121.03, 237.01 },
            cur_cols = { 201.71, 100.86, 100.86, 80.68 },
        },
        compact = {
            window = { x = 820, y = 270, w = 266, h = 270 },
            cols = { 105.14, 55.42, 38.98, 50.46 },
        },

    },
}

------------------------------------------------------------------ cfg loader
local function ensure_settings()
    ------------------------------------------------------------------------
    local ent = GetPlayerEntity()
    local pname = ent and ent.Name
    if not pname or pname == '' or pname == 'UNKNOWN' then
        local ok, loaded = pcall(settings.load, DEFAULT_CONFIG)
        return (ok and loaded) or DEFAULT_CONFIG
    end

    local sid = ent.ServerId or 0
    local base_dir = AshitaCore:GetInstallPath() .. '\\config\\addons\\treasure\\'
    if not fs.exists(base_dir) then
        fs.create_dir(base_dir)
    end

    local tag = string.format('%s_%u', pname, sid)
    local char_dir = base_dir .. tag .. '\\'
    if not fs.exists(char_dir) then
        fs.create_dir(char_dir)
    end

    local cfg_file = char_dir .. 'settings.lua'
    local cfg

    if fs.exists(cfg_file) then
        local ok, loaded = pcall(dofile, cfg_file)
        if ok and type(loaded) == 'table' then
            cfg = loaded
        end
    end

    if not cfg then
        local ok, loaded = pcall(settings.load, DEFAULT_CONFIG)
        if not ok or not loaded then
            loaded = DEFAULT_CONFIG
            settings.save(loaded)
        end
        cfg = loaded
    end

    cfg.player_name = pname
    cfg._config_file = cfg_file
    cfg.default_mode = cfg.default_mode or 'compact'
    ui.compact = (cfg.default_mode ~= 'full')
    return cfg
end

------------------------------------------------------------------ save cfg
-- Guarda cfg
local function save_character_settings(cfg)
    if not cfg then
        return
    end
    if cfg._config_file and cfg._config_file ~= '' then
        local dir = cfg._config_file:match('^(.*)[/\\]')
        if dir and not fs.exists(dir) then
            fs.create_dir(dir)
        end
        local f = io.open(cfg._config_file, 'w+')
        if f then
            f:write('return ' .. _dump_cfg(cfg) .. '\n')
            f:close()
        end
    elseif settings and settings.save then
        settings.save(cfg)
    end
end

------------------------------------------------------------------ reset all
local function reset_state_for_new_char()
    save_character_settings(cfg)
    cfg, session, idle_session = nil, nil, nil
    lastPool, lastSave = 0, 0
    ui.history_session, ui.history_idx = nil, 0
    ui._layout_mode, ui._tre_init = nil, false
    ui.tre_col_w, ui._last_compact_count = nil, nil
    ui._last_compact_height, ui._top_area = nil, nil
end

------------------------------------------------------------------ party list
local party_members, lastPartyUpdate = {}, 0
local function update_party_members()
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party then
        return
    end

    local tmp_all = {}
    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local nm = party:GetMemberName(i)
            if nm and #nm > 0 then
                nm = nm:gsub('%z', ''):gsub('%s+$', '')
                tmp_all[nm] = true
            end
        end
    end

    party_members = {}
    for n, _ in pairs(tmp_all) do
        party_members[#party_members + 1] = n
    end
    table.sort(party_members)
    _G.TreasurePartyMembers = party_members

    -- Only persist participants that are actually in the same zone as the event.
    if not (session and session.is_event and not session.ended and not ui.history_session) then
        return
    end

    local myZid = party:GetMemberZone(0)
    if not (core.is_dynamis(myZid) and session.zone_id == myZid) then
        return
    end

    session.participants = session.participants or {}
    session.drops = session.drops or core.new_drop_state()
    session.drops.by_player = session.drops.by_player or {}
    session.drops.equips_by_player = session.drops.equips_by_player or {}

    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local memberZid = party:GetMemberZone(i)
            if memberZid == session.zone_id then
                local nm = party:GetMemberName(i)
                if nm and #nm > 0 then
                    nm = nm:gsub('%z', ''):gsub('%s+$', '')
                    session.participants[nm] = true
                    session.drops.by_player[nm] = session.drops.by_player[nm] or {}
                    session.drops.equips_by_player[nm] = session.drops.equips_by_player[nm] or {}
                end
            end
        end
    end
end



------------------------------------------------------------------ comando /tr
ashita.events.register('command', 'treasure_cmd', function(e)
    local args = e.command:args()
    if not args or #args == 0 or args[1] ~= '/tr' then
        return
    end

    e.blocked = true

    local function norm(s)
        return (s or ''):gsub('%c', ''):lower():gsub('%s+', ' ')
                        :gsub('^%s+', ''):gsub('%s+$', '')
    end

    local function is_cur(name)
        local s = norm(name or '')
        return (s:find('bronzepiece') ~= nil)
                or (s:find('whiteshell') ~= nil)
                or (s:find('byne bill') ~= nil)
                or (s:find('silverpiece') ~= nil)
                or (s:find('jadeshell') ~= nil)
    end

    local function is_hundo(name)
        local s = norm(name)
        if s:find('byne bill') then
            return s:find('^100 ') ~= nil or s:find('one hundred') ~= nil
        end
        if s:find('silverpiece') then
            return s:find('montiont') ~= nil or s:find('m%.') ~= nil
        end
        if s:find('jadeshell') then
            return s:find('lungo%-nango') ~= nil or s:find('l%.') ~= nil
        end
        return false
    end

    local function to_units(name, qty)
        qty = tonumber(qty) or 0
        return is_hundo(name) and (100 * qty) or qty
    end

    local function base_cur(name)
        local s = norm(name)
        if s:find('byne bill') then
            return 'Byne Bill'
        end
        if s:find('whiteshell') then
            return 'Whiteshell'
        end
        if s:find('jadeshell') then
            return 'Whiteshell'
        end
        if s:find('bronzepiece') then
            return 'Bronzepiece'
        end
        if s:find('silverpiece') then
            return 'Bronzepiece'
        end
        return name or ''
    end

    local function display_cur(base)
        if base == 'Bronzepiece' then
            return 'Ordelle Bronzepiece', 'Bronze'
        end
        if base == 'Whiteshell' then
            return 'Tukuku Whiteshell', 'Tukus'
        end
        if base == 'Byne Bill' then
            return 'One Byne Bill', 'Byne'
        end
        return base, base
    end

    local function chat_party(msg)
        if not msg or msg == '' then
            return
        end
        enqueue_party_chat(msg)
    end

    local function print_local(msg)
        print(chat.header('Treasure'):append(chat.message(msg or '')))
    end

    local function ensure_event()
        if not (session and session.is_event and session.drops and session.drops.currency_total) then
            print_local('No active Dynamis session.')
            return false
        end
        return true
    end

    -- /tr  -> toggle ui
    if #args == 1 then
        cfg.visible = not cfg.visible
        save_character_settings(cfg)
        return
    end

    -- /tr c | /tr currency | /tr who
    local sub = (args[2] or ''):lower()
    local want_totals = (sub == 'c') or (sub == 'currency') or (sub == 'cur')
    local want_who = (sub == 'who')

    if want_totals or want_who then
        if not ensure_event() then
            return
        end

        -- /tr who  -> per-player currency drops
        if want_who then
            local byp = (session.drops and session.drops.by_player) or {}
            local any = false

            for player, bag in pairs(byp) do
                local agg = {}
                for item, qty in pairs(bag or {}) do
                    if is_cur(item) then
                        local base = base_cur(item)
                        agg[base] = (agg[base] or 0) + to_units(item, qty)
                    end
                end

                local parts = {}
                for _, base in ipairs({ 'Whiteshell', 'Bronzepiece', 'Byne Bill' }) do
                    local v = agg[base] or 0
                    if v > 0 then
                        local _, short = display_cur(base)
                        parts[#parts + 1] = string.format('%s%s%s%d', SEP, short, SEP, v)
                    end
                end

                if #parts > 0 then
                    any = true
                    chat_party(string.format('%s: %s', player, table.concat(parts, DOT_SMALL)))
                end
            end

            if not any then
                chat_party('No currency drops recorded by player.')
            end
            return
        end

        -- Totals per base currency (100s already included)
        local agg = {}
        local total = 0

        for item, qty in pairs(session.drops.currency_total or {}) do
            if is_cur(item) then
                local base = base_cur(item)
                local units = to_units(item, qty)
                agg[base] = (agg[base] or 0) + units
            end
        end

        for _, base in ipairs({ 'Whiteshell', 'Bronzepiece', 'Byne Bill' }) do
            local v = agg[base] or 0
            if v > 0 then
                local _, short = display_cur(base)
                chat_party(string.format('%s%s%s %s %d', SEP, short, SEP, STAR_WHITE, v))
                total = total + v
            end
        end


        chat_party(string.format('%sTotal%s %s %d %s', SEP, SEP, STAR, total, STAR))


        return
    end

    -- fallback: keep toggle behavior if unknown subcommand
    if not cfg then
        cfg = ensure_settings()
    end
    save_character_settings(cfg)
end)


------------------------------------------------------------------ login/logout
ashita.events.register('packet_in', 'login_detector', function(e)
    if e.id == 0x00A then
        -- login
        local ent = GetPlayerEntity();
        local nm = ent and ent.Name
        if nm and nm ~= '' and nm ~= 'UNKNOWN' and (not cfg or cfg.player_name ~= nm) then
            reset_state_for_new_char();
            cfg = ensure_settings()
            print(chat.header('Treasure'):append(chat.message(
                    'Configuración cargada para «' .. nm .. '».')))
        end
    elseif e.id == 0x00B then
        -- lobby
        reset_state_for_new_char()
    end
end)

------------------------------------------------------------------ main loop
local rm = AshitaCore:GetResourceManager()
ashita.events.register('d3d_present', 'treasure_present', function()
    if not in_world() then
        return
    end

    if not cfg then
        cfg = ensure_settings()
    end
    do
        local ent = GetPlayerEntity();
        local nm = ent and ent.Name
        if nm and nm ~= '' and nm ~= 'UNKNOWN' and cfg.player_name ~= nm then
            reset_state_for_new_char();
            cfg = ensure_settings()
        end
    end

    ---------------------------------------------------------------- session
    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = rm:GetString('zones.names', zid) or ('Zone ' .. zid)

    if core.is_dynamis(zid) then
        -- Entramos en Dynamis: restaurar o crear sesión
        if not session then
            local now = os.time()
            local saved = store.load(zid, now)

            if saved then
                ----------------------------------------------------------------
                -- Reanudamos una sesión guardada
                ----------------------------------------------------------------
                session = saved
                session.ended = false
                session.is_event = true
                session.management = session.management or {}
                session.split = session.split or { event_type = 'Custom', duration_minutes = 0 }

                print(chat.header('Treasure'):append(chat.message(
                        string.format('%s continues. Inventorys ready, ambition reloaded.', zoneName))))


            else
                ----------------------------------------------------------------
                -- Creamos una nueva sesión
                ----------------------------------------------------------------
                local new_session = parser.new_session(zid)
                if not new_session then
                    return
                end

                session = new_session
                session.is_event = true
                session.zone_id = zid
                session.start_time = now
                session.management = {}
                session.split = session.split or { event_type = 'Custom', duration_minutes = 0 }
                session.ended = false

                store.save(session)

                print(chat.header('Treasure'):append(chat.message(
                        string.format('Entering %s with 0 hope and 100%% hundo ambition..', zoneName))))
            end

            -- reiniciamos la vista de historial
            ui.history_session, ui.history_idx = nil, 0
        end

    else
        -- salimos de Dynamis (lock the session so it can't be modified anymore)
        if session and session.is_event then
            session.ended = true
            store.save(session)
        end
        session = nil
    end

    ---------------------------------------------------------------- draw
    local draw_session = ui.history_session
            or (session and session.is_event and session)
            or idle_session
    if not draw_session then
        idle_session = { drops = core.new_drop_state() };
        draw_session = idle_session
    end

    -- Actualización del pool vivo cada 0,5 s.
    if (os.clock() - lastPool) > 0.5 then
        if draw_session == session or draw_session == idle_session then
            parser.update_treasure_pool(draw_session)
        end
        lastPool = os.clock()
    end

    -- Actualiza la lista de party/alianza aproximadamente cada 2 segundos.
    if (os.clock() - lastPartyUpdate) > 2.0 then
        update_party_members();
        lastPartyUpdate = os.clock()
    end

    process_party_chat_queue()
    local hide = is_ui_fully_hidden() or is_hiding_menu_active()
    if cfg.visible and not hide then
        ui.render(draw_session, cfg)
    end

    if session and session.is_event and not ui.history_session then
        if (os.clock() - lastSave) > 30 then
            store.save(session);
            lastSave = os.clock()
        end
        if session.paused and (os.time() - session.paused) > (cfg.timeout or 30) * 60 then
            store.save(session);
            session = nil
        end
    end

    if ui.compact ~= (cfg.default_mode ~= 'full') and (os.clock() - lastPrefSave) > 1 then
        cfg.default_mode = ui.compact and 'compact' or 'full'
        save_character_settings(cfg);
        lastPrefSave = os.clock()
    end
end)

------------------------------------------------------------------ zone salida
ashita.events.register('zone_change', 'treasure_zone', function()
    if session and session.is_event then
        session.ended = true
        store.save(session)
    end
    session = nil
end)

------------------------------------------------------------------ texto chat
ashita.events.register('text_in', 'treasure_text', function(e)
    if session and session.is_event then
        parser.handle_line(e.message_modified, session)
    end
end)