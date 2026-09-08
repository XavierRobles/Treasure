--------------------------------------------------------------------------------
-- Addon: Treasure
-- Autor: Waky
-- Versión: 1.1.3
-- Descripción:
--   Registra en tiempo real todos los objetos en eventos y 
-- los muestra en una interfaz personalizable
--------------------------------------------------------------------------------

addon = addon or {}
addon.name = 'Treasure'
addon.author = 'Waky'
addon.version = '1.1.5'

require('common')
-- Refresh changed modules during addon reloads.
local treasure_reload_modules = {}
for module_name in pairs(package.loaded) do
    if module_name == 'ui' or module_name == 'ui_combat'
            or module_name == 'blue_learn_alert' or module_name == 'sound_volume'
            or module_name == 'parser' or module_name == 'key_items'
            or module_name == 'ui_event_router' or module_name == 'ui_event_limbus'
            or module_name:match('^combat%.') then
        treasure_reload_modules[#treasure_reload_modules + 1] = module_name
    end
end
for _, module_name in ipairs(treasure_reload_modules) do
    package.loaded[module_name] = nil
end
local core = require('core')
local parser = require('parser')
local key_items = require('key_items')
local store = require('store')
local ui = require('ui')
local ui_combat = require('ui_combat')
local combat = require('combat.init')
local combat_settings = require('combat.settings')
local event_router = require('event_router')
local weekly_router = require('weekly_router')
local ecowar = require('weekly.ecowar')
local highwind = require('weekly.highwind')
local timeutil = require('timeutil')
local persistence = require('persist')
local blue_learn_alert = require('blue_learn_alert')
local sound_volume = require('sound_volume')
local chatutil = require('chatutil')
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

local function _clone_cfg(v)
    if type(v) ~= 'table' then
        return v
    end
    local out = {}
    for k, val in pairs(v) do
        out[k] = _clone_cfg(val)
    end
    return out
end

local SEP = "\xFD\x01\x02\x05\xA9\xFD"
local STAR = string.char(0x81, 0x9A)
local STAR_WHITE = string.char(0x81, 0x99) -- ☆
local DOT_HUGE = string.char(0x81, 0x9C) -- ●
local DOT_HUGE_OPEN = string.char(0x81, 0x9B) -- ○
local DOT_SMALL    = string.char(0x81, 0x45) -- ・
------------------------------------------------------------------ estado
local session, idle_session, lastPool, lastSave = nil, nil, 0, 0
local lastWeeklyTick = 0
local cfg, lastPrefSave = nil, 0
local lastLimbusPoolProbe = 0
local limbusExitSeenAt = nil

local LIMBUS_POST_EXIT_GRACE = 20
local LIMBUS_POST_RUN_HOLD_SECONDS = 330

local function print_local(msg)
    print(chat.header('Treasure'):append(chat.message(msg or '')))
end

local function session_event_id(sess)
    local id = tostring((sess and sess.event_id) or ''):lower()
    if id == '' then
        return 'dynamis'
    end
    return id
end

local function dispatch_event_packet(direction, packet)
    if not (session and session.is_event and packet) then
        return
    end

    local ev_id = session_event_id(session)
    local handler = event_router.get(ev_id)
    if not handler then
        return
    end

    if direction == 'in' and handler.on_packet_in then
        handler.on_packet_in(packet, session)
    elseif direction == 'out' and handler.on_packet_out then
        handler.on_packet_out(packet, session)
    end
end

combat.subscribe('treasure_event_trackers', function(event)
    -- In Full mode the original action text is intentionally removed. Feed
    -- Treasure's event trackers from the untouched structured action first.
    if not combat.is_replacing_chat() or not (session and session.is_event) then
        return
    end
    local handler = event_router.get(session_event_id(session))
    if handler and handler.on_combat_event then
        handler.on_combat_event(event, session)
    end
end)

local function close_active_session(reason)
    if not (session and session.is_event) then
        limbusExitSeenAt = nil
        session = nil
        return
    end

    local ev_id = session_event_id(session)
    local handler = event_router.get(ev_id)
    if handler and handler.on_leave then
        handler.on_leave(session, { reason = reason })
    else
        session.ended = true
        store.save(session, { force = true })
    end
    limbusExitSeenAt = nil
    session = nil
end

local function count_live_pool_items(sess)
    local pool = sess and sess.drops and sess.drops.pool_live
    if type(pool) ~= 'table' then
        return 0
    end

    local count = 0
    for _, row in pairs(pool) do
        if type(row) == 'table' and (tonumber(row.item_id) or 0) ~= 0 then
            count = count + 1
        end
    end
    return count
end

local function should_keep_limbus_session(sess, now_tick, refresh_pool, allow_grace, force_refresh)
    if not (sess and sess.is_event and session_event_id(sess) == 'limbus') then
        return false
    end
    if sess.limbus_run_started ~= true then
        return false
    end
    if allow_grace == nil then
        allow_grace = true
    end

    local now_os = os.time()
    local ended = (sess.limbus_run_ended == true)
    if not ended then
        local lt = sess.limbus_timer or {}
        local end_at = tonumber(lt.end_at)
        local fallback_end = tonumber(lt.fallback_end_at)
        if (end_at and end_at <= now_os) or (fallback_end and fallback_end <= now_os) then
            ended = true
            sess.limbus_run_ended = true
            sess.limbus_run_ended_at = tonumber(sess.limbus_run_ended_at) or now_os
        end
    end
    if not ended then
        return false
    end

    local ended_at = tonumber(sess.limbus_run_ended_at) or now_os
    if (now_os - ended_at) < LIMBUS_POST_RUN_HOLD_SECONDS then
        if refresh_pool and (force_refresh or ((now_tick - lastLimbusPoolProbe) > 0.40)) then
            parser.update_treasure_pool(sess)
            lastLimbusPoolProbe = now_tick
        end
        limbusExitSeenAt = nil
        return true
    end

    if refresh_pool and (force_refresh or ((now_tick - lastLimbusPoolProbe) > 0.40)) then
        parser.update_treasure_pool(sess)
        lastLimbusPoolProbe = now_tick
    end

    if count_live_pool_items(sess) > 0 then
        limbusExitSeenAt = nil
        return true
    end

    if not allow_grace then
        limbusExitSeenAt = nil
        return false
    end

    local seen_at = tonumber(limbusExitSeenAt)
    if not seen_at then
        limbusExitSeenAt = now_tick
        return true
    end

    if (now_tick - seen_at) < LIMBUS_POST_EXIT_GRACE then
        return true
    end

    limbusExitSeenAt = nil
    return false
end

local function finalize_limbus_run(sess, reason)
    if not (sess and sess.is_event and session_event_id(sess) == 'limbus') then
        return
    end
    if not (sess.limbus_run_started == true and sess.limbus_run_ended == true) then
        return
    end

    sess.ended = true
    store.save(sess, { force = true, event_id = 'limbus' })

    -- Keep the zone session alive, but reset to "waiting for next run".
    sess.limbus_run_started = false
    sess.limbus_run_ended = false
    sess.limbus_run_ended_at = nil
    sess.limbus_start_participants = {}
    sess.limbus_start_participants_locked = false
    sess.limbus_gate_ready = false
    sess.limbus_gate_ready_until = nil
    sess.limbus_gate_count = 0
    sess.limbus_floor = 1
    sess.limbus_floor_changes = 0
    sess.limbus_floor_stats = {}
    sess.limbus_path_id = ''
    sess.limbus_path_label = ''
    sess.limbus_max_floor = nil
    sess.limbus_reward_chip = nil
    sess.limbus_reward_chip_key = nil
    sess.limbus_is_central = false
    sess.limbus_central_kind = ''
    sess.limbus_gunpod = nil
    sess.limbus_transition_pending = false
    sess.limbus_transition_pending_at = nil
    sess.limbus_sw_day_element = nil
    sess.limbus_sw_day_element_locked = false
    sess.limbus_sw_day_element_count = 0
    sess.limbus_sw_day_element_floor = nil
    sess.limbus_sw_day_element_detected_at = nil
    sess.limbus_sw_day_element_last_scan = 0
    sess.limbus_sw_day_element_not_before = nil
    sess.limbus_sw_day_element_candidate = nil
    sess.limbus_sw_day_element_candidate_hits = 0
    if sess.limbus_timer then
        sess.limbus_timer.end_at = nil
        sess.limbus_timer.fallback_end_at = nil
        sess.limbus_timer.desynced = false
        sess.limbus_timer.last_sync_at = nil
    end
    limbusExitSeenAt = nil
end


------------------------------------------------------------------ party chat queue (rate limit)
local party_chat_queue = {}
local last_party_chat_sent = 0
local PARTY_CHAT_DELAY = 2.0
local PARTY_CHAT_MAX_PENDING = 32

local function enqueue_party_chat(msg)
    if not msg or msg == '' then
        return
    end
    party_chat_queue[#party_chat_queue + 1] = msg
    while #party_chat_queue > PARTY_CHAT_MAX_PENDING do
        table.remove(party_chat_queue, 1)
    end
end

local function process_party_chat_queue()
    if #party_chat_queue == 0 then
        return
    end
    local now = timeutil.now()
    if (now - last_party_chat_sent) < PARTY_CHAT_DELAY then
        return
    end

    local msg = table.remove(party_chat_queue, 1)
    AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. msg)
    last_party_chat_sent = now
end


------------------------------------------------------------------ helpers
local ui_hidden_signature_addr = 0
local ui_hidden_signature_retry_at = 0
local menu_signature_addr = 0
local menu_signature_retry_at = 0

local function cached_signature(current, retry_at, pattern, offset)
    if current ~= 0 then
        return current, retry_at
    end
    local now = timeutil.now()
    if now < (tonumber(retry_at) or 0) then
        return 0, retry_at
    end
    local found = ashita.memory.find('FFXiMain.dll', 0, pattern, offset or 0, 0)
    if found == 0 then
        return 0, now + 5
    end
    return found, 0
end

local function is_ui_fully_hidden()
    ui_hidden_signature_addr, ui_hidden_signature_retry_at = cached_signature(
        ui_hidden_signature_addr,
        ui_hidden_signature_retry_at,
        '8B4424046A016A0050B9????????E8????????F6D81BC040C3',
        0)
    if ui_hidden_signature_addr == 0 then
        return false
    end
    local ptr = ashita.memory.read_uint32(ui_hidden_signature_addr + 10)
    return ptr ~= 0 and ashita.memory.read_uint8(ptr + 0xB4) == 1
end

local MENU_HIDE_GROUP_DEFS = {
    {
        key = 'logs',
        label = 'Log / Chat',
        hint = 'Full log window.',
        ids = { 'fulllog' },
    },
    {
        key = 'equipment',
        label = 'Equipment / Inventory',
        hint = 'Equip, inventory, item use and sorting.',
        ids = { 'equip', 'inventor', 'mnstorag', 'iuse', 'itmsortw', 'sortyn', 'itemctrl' },
    },
    {
        key = 'map',
        label = 'Map / Scan',
        hint = 'Map and related windows.',
        ids = { 'map0', 'maplist', 'mapframe', 'scanlist', 'cnqframe' },
    },
    {
        key = 'config',
        label = 'Config / Filters',
        hint = 'Game config and filter windows.',
        ids = {
            'conf2win', 'cfilter', 'textcol1', 'confyn', 'conf5m', 'conf5win', 'conf5w1', 'conf5w2',
            'conf11m', 'conf11l', 'conf11s', 'conf3win', 'conf6win', 'conf12wi', 'conf13wi', 'fxfilter',
            'conf7', 'conf4',
        },
    },
    {
        key = 'linkshell',
        label = 'Linkshell',
        hint = 'Linkshell windows.',
        ids = { 'link5', 'link12', 'link13', 'link3' },
    },
    {
        key = 'event_panels',
        label = 'Event Panels',
        hint = 'Event result / entry panels.',
        ids = { 'scresult', 'evitem', 'statcom2' },
    },
    {
        key = 'auction_delivery',
        label = 'Auction / Delivery / Bank',
        hint = 'AH, post, delivery, bank and money windows.',
        ids = {
            'auc1', 'moneyctr', 'shopsell', 'comyn', 'auclist', 'auchisto', 'auc4', 'post1', 'post2', 'stringdl',
            'delivery', 'mcr1edlo', 'mcr2edlo', 'mcrbedit', 'mcresed', 'bank', 'handover',
        },
    },
    {
        key = 'treasure_pool',
        label = 'Treasure Pool',
        hint = 'Treasure lot/pass windows.',
        ids = { 'loot', 'lootope' },
    },
    {
        key = 'merits',
        label = 'Merits',
        hint = 'Merit category and merit menus.',
        ids = { 'meritcat', 'merit1', 'merit2', 'merit3', 'merityn' },
    },
    {
        key = 'shop_job_menus',
        label = 'Shop / Job Menus',
        hint = 'Shop, automaton and blue-mage menus.',
        ids = { 'shop', 'automato', 'bluinven', 'bluequip' },
    },
    {
        key = 'quests_missions',
        label = 'Quest / Mission / Help',
        hint = 'Quest, mission and help windows.',
        ids = { 'quest00', 'quest01', 'miss00', 'faqsub', 'cmbhlst' },
    },
}

local MENU_HIDE_GROUP_BY_ID = {}
for _, group in ipairs(MENU_HIDE_GROUP_DEFS) do
    for _, id in ipairs(group.ids or {}) do
        MENU_HIDE_GROUP_BY_ID[id] = group.key
    end
end

local function default_menu_hide_groups()
    local out = {}
    for _, group in ipairs(MENU_HIDE_GROUP_DEFS) do
        out[group.key] = true
    end
    return out
end

local function ensure_menu_hide_cfg(cfg)
    if type(cfg) ~= 'table' then
        return false
    end

    local changed = false
    cfg.menu_hide = cfg.menu_hide or {}
    local mh = cfg.menu_hide

    if mh.hide_when_ui_hidden == nil then
        mh.hide_when_ui_hidden = true
        changed = true
    else
        mh.hide_when_ui_hidden = (mh.hide_when_ui_hidden == true)
    end

    if mh.hide_when_game_menu == nil then
        mh.hide_when_game_menu = true
        changed = true
    else
        mh.hide_when_game_menu = (mh.hide_when_game_menu == true)
    end

    if type(mh.groups) ~= 'table' then
        mh.groups = {}
        changed = true
    end
    for _, group in ipairs(MENU_HIDE_GROUP_DEFS) do
        if mh.groups[group.key] == nil then
            mh.groups[group.key] = true
            changed = true
        else
            mh.groups[group.key] = (mh.groups[group.key] == true)
        end
    end

    -- Runtime metadata for UI; excluded from serialization by _dump_cfg.
    cfg._menu_hide_group_defs = MENU_HIDE_GROUP_DEFS
    return changed
end

local function get_active_game_menu_id()
    menu_signature_addr, menu_signature_retry_at = cached_signature(
        menu_signature_addr,
        menu_signature_retry_at,
        '8B480C85C974??8B510885D274??3B05',
        16)
    if menu_signature_addr == 0 then
        return ''
    end

    local ptr = ashita.memory.read_uint32(menu_signature_addr)
    if ptr == 0 then
        return ''
    end
    ptr = ashita.memory.read_uint32(ptr)
    if ptr == 0 then
        return ''
    end

    local header = ashita.memory.read_uint32(ptr + 4)
    if header == 0 then
        return ''
    end

    local raw = ashita.memory.read_string(header + 0x46, 16)
    if not raw then
        return ''
    end

    local cleaned = raw:gsub('\0', '')
    if #cleaned >= 9 then
        cleaned = cleaned:sub(9)
    else
        cleaned = ''
    end
    cleaned = cleaned:gsub(' ', '')

    return cleaned
end

local function is_hiding_menu_active(cfg)
    local mh = (type(cfg) == 'table' and type(cfg.menu_hide) == 'table') and cfg.menu_hide or nil
    if mh and mh.hide_when_game_menu == false then
        return false
    end

    local menu_id = get_active_game_menu_id()
    if menu_id == '' then
        return false
    end

    local group_key = MENU_HIDE_GROUP_BY_ID[menu_id]
    if not group_key then
        return false
    end

    local groups = mh and mh.groups
    if type(groups) ~= 'table' then
        return true
    end
    if groups[group_key] == nil then
        return true
    end
    return (groups[group_key] == true)
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
    blue_magic_learn_alert = true,
    blue_magic_learn_volume = 100,
    menu_hide = {
        hide_when_ui_hidden = true,
        hide_when_game_menu = true,
        groups = default_menu_hide_groups(),
    },
    colors = {
        QTY = { 1, 1, 1, 1 }, CUR = { 0.1725, 1, 0.0431, 1 },
        ITEM = { 0, 1, 0.9961, 1 }, HUNDO = { 1, 0.84, 0, 1 },
        NAME = { 0.55, 0.78, 1, 1 }, LOST = { 1, 0.35, 0.35, 1 },
    },
    colors_dynamis = {
        QTY = { 1, 1, 1, 1 }, CUR = { 0.1725, 1, 0.0431, 1 },
        ITEM = { 0, 1, 0.9961, 1 }, HUNDO = { 1, 0.84, 0, 1 },
        NAME = { 0.55, 0.78, 1, 1 }, LOST = { 1, 0.35, 0.35, 1 },
    },
    colors_limbus = {
        QTY = { 1, 1, 1, 1 }, CUR = { 1.0, 0.839215686, 0.0, 1.0 }, -- #FFD600
        ITEM = { 0, 1, 0.9961, 1 }, HUNDO = { 1, 0.84, 0, 1 },
        NAME = { 0.55, 0.78, 1, 1 }, LOST = { 1, 0.35, 0.35, 1 },
    },
    chip_colors = {
        magenta = { 0.5255, 0.3373, 0.8471, 1.0 },
        smoky = { 0.4431, 0.5098, 0.5922, 1.0 },
        emerald = { 0.2118, 0.5608, 0.4510, 1.0 },
        scarlet = { 0.5961, 0.3255, 0.1373, 1.0 },
        ivory = { 0.6549, 0.5216, 0.0235, 1.0 },
        charcoal = { 0.4392, 0.5059, 0.5882, 1.0 },
        smalt = { 0.1294, 0.4980, 0.7176, 1.0 },
        orchid = { 0.5373, 0.3412, 0.8627, 1.0 },
        cerulean = { 0.1333, 0.5216, 0.7490, 1.0 },
        silver = { 0.4745, 0.5373, 0.6196, 1.0 },
        metal = { 0.62, 0.66, 0.72, 1.0 },
        niveous = { 0.93, 0.96, 1.00, 1.0 },
        crepuscular = { 0.60, 0.54, 0.68, 1.0 },
    },
    limbus_hp_bar_colors = {
        high = { 0.88, 0.47, 0.53, 0.96 },
        low = { 0.62, 0.12, 0.16, 0.96 },
    },
    limbus_icon_anim = {
        transition_pulse = true,
        vortex_open_spin = true,
        vortex_open_pulse = true,
        vortex_open_spin_speed = 1.8,
    },
    visual_colors = {
        HUD_TEXT = { 0.84, 0.87, 0.91, 1.00 },
        EVENT_DYNAMIS = { 1.00, 0.62, 0.26, 0.90 },
        EVENT_LIMBUS = { 0.18, 0.77, 0.71, 0.90 },
        STATE_OK = { 0.24, 0.86, 0.52, 1.00 },
        STATE_ALERT = { 1.00, 0.30, 0.31, 1.00 },
        WINDOW_BG = { 0.07, 0.08, 0.10, 0.94 },
        CONTENT_BG = { 0.10, 0.11, 0.13, 0.90 },
        HEADER_BG = { 0.09, 0.09, 0.10, 0.96 },
        HEADER_BORDER = { 0.45, 0.41, 0.30, 0.65 },
        HEADER_TEXT = { 0.90, 0.90, 0.91, 1.00 },
        CONTROL_BG = { 0.13, 0.14, 0.16, 0.92 },
        CONTROL_BG_HOVERED = { 0.16, 0.18, 0.21, 0.95 },
        CONTROL_BG_ACTIVE = { 0.20, 0.22, 0.26, 0.98 },
        TAB_BG = { 0.10, 0.10, 0.11, 0.96 },
        TAB_BG_HOVERED = { 0.14, 0.15, 0.18, 0.98 },
        TAB_BG_ACTIVE = { 0.18, 0.20, 0.24, 0.99 },
        TAB_BG_UNFOCUSED = { 0.08, 0.08, 0.09, 0.92 },
        TAB_BG_UNFOCUSED_ACTIVE = { 0.13, 0.14, 0.17, 0.95 },
        SEPARATOR = { 0.22, 0.22, 0.24, 0.85 },
    },
    button_style = {
        rounding = 9.0,
        height = 25.0,
        border_selected = 1.8,
        border_idle = 0.0,
        selected_bg = { 0.22, 0.20, 0.16, 0.96 },
        selected_border = { 0.180392, 0.768627, 0.709804, 0.901961 }, -- legacy/fallback (Limbus) #2EC4B5E6
        selected_border_dynamis = { 0.180392, 0.768627, 0.709804, 0.901961 }, -- #2EC4B5E6
        selected_border_limbus = { 1.000000, 0.701961, 0.278431, 0.901961 }, -- #FFB347E6
        selected_text = { 0.94, 0.90, 0.76, 1.00 },
        idle_bg = { 0.08, 0.08, 0.09, 0.95 },
        idle_border = { 0.35, 0.33, 0.28, 0.72 },
        idle_text = { 0.78, 0.78, 0.78, 1.00 },
    },
    limbus_icon_size = 28.0,
    layout = {
        full = {
            window = { x = 536, y = 129, w = 605, h = 314 },
            cols = { 112.85, 112.96, 60.51, 302.68 },
            all_cols = { 109.93, 121.03, 121.03, 237.01 },
            cur_cols = { 201.71, 100.86, 100.86, 80.68 },
        },
        compact = {
            window = { x = 820, y = 270, w = 298, h = 181 },
            cols = { 136.59790039063, 62.51375579834, 43.9694480896, 38.918895721436 },
        },

    },
}

------------------------------------------------------------------ cfg loader
local function ensure_settings()
    ------------------------------------------------------------------------
    local ent = GetPlayerEntity()
    local pname = ent and ent.Name
    if not pname or pname == '' or pname == 'UNKNOWN' then
        local loaded = _clone_cfg(DEFAULT_CONFIG)
        ensure_menu_hide_cfg(loaded)
        combat_settings.ensure(loaded)
        combat.configure(loaded.combat_log)
        loaded.default_mode = loaded.default_mode or 'compact'
        ui.compact = (loaded.default_mode ~= 'full')
        return loaded
    end

    local base_dir = AshitaCore:GetInstallPath() .. '\\config\\addons\\treasure\\'
    if not fs.exists(base_dir) then
        fs.create_dir(base_dir)
    end

    local char_dir = base_dir .. pname .. '\\'
    if not fs.exists(char_dir) then
        fs.create_dir(char_dir)
    end

    local cfg_file = char_dir .. 'settings.lua'
    local cfg

    if fs.exists(cfg_file) then
        local loaded = persistence.load_table(cfg_file)
        if type(loaded) == 'table' then
            cfg = loaded
        end
    end

    -- Legacy compatibility: previous builds used "<name>_<ServerId>" folders.
    if not cfg then
        local sid = ent.ServerId or 0
        local legacy_file = base_dir .. string.format('%s_%u\\settings.lua', pname, sid)
        if fs.exists(legacy_file) then
            local loaded = persistence.load_table(legacy_file)
            if type(loaded) == 'table' then
                cfg = loaded
            end
        end
    end

    if not cfg then
        cfg = _clone_cfg(DEFAULT_CONFIG)
    end

    if cfg.blue_magic_learn_alert == nil then
        cfg.blue_magic_learn_alert = true
    end
    cfg.blue_magic_learn_volume = math.max(0,
            math.min(100, tonumber(cfg.blue_magic_learn_volume) or 100))

    ensure_menu_hide_cfg(cfg)
    combat_settings.ensure(cfg)
    combat.configure(cfg.combat_log)
    cfg.player_name = pname
    cfg._config_file = cfg_file
    combat.set_character_context(char_dir)
    cfg.default_mode = cfg.default_mode or 'compact'
    ui.compact = (cfg.default_mode ~= 'full')
    weekly_router.init_all(pname, char_dir)
    return cfg
end

------------------------------------------------------------------ save cfg
-- Guarda cfg
local function save_character_settings(cfg)
    if not cfg then
        return
    end
    if not (cfg._config_file and cfg._config_file ~= '') then
        return
    end
    local dir = cfg._config_file:match('^(.*)[/\\]')
    if dir and not fs.exists(dir) then
        fs.create_dir(dir)
    end
    persistence.write_atomic(cfg._config_file, 'return ' .. _dump_cfg(cfg) .. '\n')
end

------------------------------------------------------------------ reset all
local function reset_state_for_new_char()
    if session and session.is_event then
        local ev_id = session_event_id(session)
        local can_persist = true
        if ev_id == 'limbus' and session.limbus_run_started ~= true then
            can_persist = false
        end
        if can_persist then
            store.save(session, { force = true, event_id = ev_id })
        end
    end
    save_character_settings(cfg)
    cfg, session, idle_session = nil, nil, nil
    combat.configure(nil)
    lastPool, lastSave = 0, 0
    ui.history_session, ui.history_idx = nil, 0
    ui._layout_mode, ui._tre_init = nil, false
    ui.tre_col_w, ui._last_compact_count = nil, nil
    ui._last_compact_height, ui._top_area = nil, nil
    ui.active_event = 'dynamis'
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
    local myEventId = event_router.match_zone(myZid)
    if not (myEventId and session.zone_id == myZid and myEventId == session_event_id(session)) then
        return
    end
    if session_event_id(session) == 'limbus' and session.limbus_run_started ~= true then
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

    if not cfg then
        cfg = ensure_settings()
    end

    local function norm(s)
        return (s or ''):gsub('%c', ''):lower():gsub('%s+', ' ')
                        :gsub('^%s+', ''):gsub('%s+$', '')
    end

    local report_session = nil
    if session and session.is_event then
        report_session = session
    elseif ui.history_session and ui.history_session.is_event then
        report_session = ui.history_session
    end

    local function is_cur(name)
        local s = norm(name or '')
        local report_event = session_event_id(report_session)
        if report_event == 'limbus' then
            return s:find('ancient beastcoin', 1, true) ~= nil
        end
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
        if s:find('ancient beastcoin', 1, true) then
            return 'Ancient Beastcoin'
        end
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
        if base == 'Ancient Beastcoin' then
            return base, 'Beastcoin'
        end
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

    local function ensure_event()
        if not (report_session and report_session.drops and report_session.drops.currency_total) then
            local ev_name = event_router.title(
                (report_session and report_session.event_id)
                or (ui.history_session and ui.history_session.event_id)
                or ui.active_event
            )
            print_local('No active ' .. tostring(ev_name) .. ' session.')
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

    -- /tr combat ... -> optional Combat Log configuration.
    if sub == 'combat' or sub == 'combatlog' then
        local action = (args[3] or 'config'):lower()
        if action == 'config' or action == 'show' then
            ui_combat.set_open(true)
            return
        end
        if action == 'on' then
            combat_settings.set_enabled(cfg, true)
        elseif action == 'off' then
            combat_settings.set_enabled(cfg, false)
        elseif action == 'reset' then
            combat_settings.reset(cfg)
        elseif action == 'status' then
            local cl = cfg.combat_log
            print_local(('Combat Log: %s, preset %s.'):format(cl.enabled and 'enabled' or 'off', cl.preset))
            local combat_stats = combat.get_stats()
            print_local(('Combat: all=%d last=0x%03X action028=%d decoded=%d errors=%d queued=%d pending=%d output=%d.'):format(
                combat_stats.packets_all, combat_stats.last_packet_id, combat_stats.packets_028,
                combat_stats.decoded, combat_stats.decode_errors,
                combat_stats.queued, combat_stats.pending, combat_stats.lines_output))
            if combat_stats.last_error ~= '' then
                print_local('Combat last error: ' .. combat_stats.last_error)
            end
            return
        else
            print_local('Combat Log: usage /tr combat <config|on|off|status|reset>')
            return
        end
        combat_settings.ensure(cfg)
        combat.configure(cfg.combat_log)
        save_character_settings(cfg)
        print_local(('Combat Log: %s.'):format(cfg.combat_log.enabled and 'enabled' or 'off'))
        return
    end

    local want_totals = (sub == 'c') or (sub == 'currency') or (sub == 'cur')
    local want_who = (sub == 'who')

    -- No steal command: keep steal stats UI-only and silent.
    if sub == 'steal' or sub == 'thf' then
        return
    end

    if want_totals or want_who then
        if not ensure_event() then
            return
        end
        -- A new report supersedes any unsent lines from an older report.
        party_chat_queue = {}
        local currency_order
        if session_event_id(report_session) == 'limbus' then
            currency_order = { 'Ancient Beastcoin' }
        else
            currency_order = { 'Whiteshell', 'Bronzepiece', 'Byne Bill' }
        end

        -- /tr who  -> per-player currency drops
        if want_who then
            local byp = (report_session.drops and report_session.drops.by_player) or {}
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
                for _, base in ipairs(currency_order) do
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

        for item, qty in pairs(report_session.drops.currency_total or {}) do
            if is_cur(item) then
                local base = base_cur(item)
                local units = to_units(item, qty)
                agg[base] = (agg[base] or 0) + units
            end
        end

        for _, base in ipairs(currency_order) do
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

    -- /tr ew ...  -> Eco-Warrior weekly tracker
    if sub == 'ew' or sub == 'ecowar' or sub == 'eco' then
        local function print_summary()
            print_local(ecowar.get_summary())
            print_local(ecowar.get_next_step())
            local ew_next = ecowar.next_reset_timestamp()
            print_local(('Next reset: %s local (%s)'):format(ecowar.format_local(ew_next), ecowar.format_jst(ew_next)))
        end

        local action = (args[3] or ''):lower()
        local target = (args[4] or ''):lower()

        if action == '' or action == 'show' or action == 'status' then
            print_summary()
            return
        end
        if action == 'set' or action == 'active' then
            local ok, err = ecowar.set_active(target ~= '' and target or 'none')
            if not ok then print_local('Eco-War: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'done' or action == 'mark' then
            local ok, err = ecowar.mark_done(target)
            if not ok then print_local('Eco-War: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'undo' then
            local ok, err = ecowar.undo(target)
            if not ok then print_local('Eco-War: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'phase' then
            local ok, err = ecowar.set_phase(target)
            if not ok then print_local('Eco-War: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'reset' then
            if target == 'week' then
                ecowar.reset_week()
            elseif target == 'cycle' then
                ecowar.reset_cycle()
            elseif target == 'all' then
                ecowar.reset_all()
            else
                print_local('Eco-War: usage /tr ew reset <week|cycle|all>')
                return
            end
            print_summary()
            return
        end
        print_local('Eco-War: unknown action "' .. tostring(action) .. '"')
        return
    end

    -- /tr hw ...  -> Highwind weekly tracker
    if sub == 'hw' or sub == 'highwind' then
        local function print_summary()
            print_local(highwind.get_summary())
            print_local(highwind.get_next_step())
            local hw_next = highwind.next_reset_timestamp()
            print_local(('Next reset: %s local (%s)'):format(highwind.format_local(hw_next), highwind.format_jst(hw_next)))
        end

        local action = (args[3] or ''):lower()

        if action == '' or action == 'show' or action == 'status' then
            print_summary()
            return
        end
        if action == 'mark' or action == 'done' or action == 'killed' then
            local ok, err = highwind.mark_killed()
            if not ok then print_local('Highwind: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'undo' then
            local ok, err = highwind.undo()
            if not ok then print_local('Highwind: ' .. tostring(err or 'failed')) end
            print_summary()
            return
        end
        if action == 'reset' then
            local target = (args[4] or 'week'):lower()
            if target == 'week' then
                highwind.reset_week()
            elseif target == 'all' then
                highwind.reset_all()
            else
                print_local('Highwind: usage /tr hw reset <week|all>')
                return
            end
            print_summary()
            return
        end
        print_local('Highwind: unknown action "' .. tostring(action) .. '"')
        return
    end

    -- fallback: keep toggle behavior if unknown subcommand
    if not cfg then
        cfg = ensure_settings()
    end
    cfg.visible = not cfg.visible
    save_character_settings(cfg)
end)


------------------------------------------------------------------ login/logout
local last_blue_magic_alert = { name = '', timestamp = 0 }

local function emit_blue_magic_learned(spell_id, fallback_name)
    if cfg ~= nil and cfg.blue_magic_learn_alert == false then
        return
    end

    local spell = spell_id ~= nil
            and AshitaCore:GetResourceManager():GetSpellById(spell_id) or nil
    local spell_name = (spell ~= nil and spell.Name ~= nil and spell.Name[1])
            or tostring(fallback_name or spell_id or '')
    if spell_name == '' then
        return
    end

    local now = timeutil.now()
    local normalized_name = spell_name:lower()
    if last_blue_magic_alert.name == normalized_name
            and (now - last_blue_magic_alert.timestamp) < 3 then
        return
    end
    last_blue_magic_alert.name = normalized_name
    last_blue_magic_alert.timestamp = now

    print(chat.header('Treasure'):append(chat.success(
            'Learned new Blue Magic spell: ' .. spell_name)))
    sound_volume.play(addon.path .. '\\sound\\Learned.wav',
            cfg and cfg.blue_magic_learn_volume or 100)
end

local function notify_blue_magic_learned(e)
    local entity = GetPlayerEntity()
    local spell_id = blue_learn_alert.learned_spell(e, entity and entity.TargetIndex)
    if spell_id ~= nil then
        emit_blue_magic_learned(spell_id)
    end
end

ashita.events.register('packet_in', 'login_detector', function(e)
    key_items.on_packet_in(e)
    -- Keep the learning alert independent from combat decoding. In particular,
    -- a failure or future early-exit in the combat path must not swallow 0x029.
    notify_blue_magic_learned(e)
    combat.on_packet_in(e)
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
        -- lobby / transient zone packet: only reset on actual lobby-like state.
        local ent = GetPlayerEntity()
        local nm = ent and ent.Name
        local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
        local no_world = (zid == 0 or zid == 0xFFFF)
        local no_name = (not nm or nm == '' or nm == 'UNKNOWN')
        if no_world and no_name then
            reset_state_for_new_char()
        end
    end
    dispatch_event_packet('in', e)
end)

ashita.events.register('packet_out', 'treasure_packet_out', function(e)
    dispatch_event_packet('out', e)
end)

------------------------------------------------------------------ main loop
local rm = AshitaCore:GetResourceManager()
local present_stage = 'idle'
ashita.events.register('d3d_present', 'treasure_present', function()
    present_stage = 'world_check'
    if not in_world() then
        present_stage = 'idle'
        return
    end

    present_stage = 'settings'
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
    local now_tick = timeutil.now()
    present_stage = 'combat_tick'
    combat.on_tick(now_tick)
    present_stage = 'sound_tick'
    sound_volume.tick()

    ---------------------------------------------------------------- session
    present_stage = 'session'
    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = rm:GetString('zones.names', zid) or ('Zone ' .. zid)
    local active_event_id, active_handler = event_router.match_zone(zid)

    if active_event_id and active_handler and active_handler.on_enter then
        ui.active_event = active_event_id

        local same_event_active = session
                and session.is_event
                and (session_event_id(session) == active_event_id)
                and (tonumber(session.zone_id) == tonumber(zid))

        if not same_event_active then
            close_active_session('switch')

            local now = os.time()
            local opened, banner = active_handler.on_enter({
                zid = zid,
                zone_name = zoneName,
                now = now,
            })

            if opened then
                session = opened
                session.is_event = true
                session.zone_id = zid
                session.event_id = active_event_id

                -- reiniciamos la vista de historial
                ui.history_session, ui.history_idx = nil, 0

                if banner and banner ~= '' then
                    print(chat.header('Treasure'):append(chat.message(banner)))
                end
            end
        elseif session_event_id(session) == 'limbus' then
            limbusExitSeenAt = nil
        end
    else
        -- Outside known event zones: close the active event session as soon as
        -- we are in a valid non-event zone. Keep session during transient
        -- zoning states (0 / 0xFFFF).
        if zid ~= 0 and zid ~= 0xFFFF then
            close_active_session('zone_exit')
        end
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
    if (now_tick - lastPool) > 0.5 then
        if draw_session == session or draw_session == idle_session then
            parser.update_treasure_pool(draw_session)
        end
        if session and session.is_event and session_event_id(session) == 'limbus' then
            if count_live_pool_items(session) > 0 then
                limbusExitSeenAt = nil
            end
        end
        lastPool = now_tick
    end

    -- Event runtime hooks (per-frame/lightweight polling).
    if session and session.is_event then
        local ev_id = session_event_id(session)
        local handler = event_router.get(ev_id)
        if handler and handler.on_tick then
            handler.on_tick(session, now_tick)
        end
    end

    -- Actualiza la lista de party/alianza aproximadamente cada 2 segundos.
    if (now_tick - lastPartyUpdate) > 2.0 then
        update_party_members();
        lastPartyUpdate = now_tick
    end

    -- Weekly trackers tick (JST roll-over). Cheap; every ~5s is plenty.
    if (now_tick - lastWeeklyTick) > 5.0 then
        weekly_router.tick()
        lastWeeklyTick = now_tick
    end

    present_stage = 'party_chat_queue'
    process_party_chat_queue()

    present_stage = 'ui_hidden_memory'
    local hide_ui = (cfg.menu_hide.hide_when_ui_hidden ~= false)
            and is_ui_fully_hidden()
    present_stage = 'game_menu_memory'
    local hide_menu = is_hiding_menu_active(cfg)
    local hide = hide_ui or hide_menu
    if cfg.visible and not hide then
        present_stage = 'main_ui_render'
        ui.render(draw_session, cfg)
    end
    if not hide then
        present_stage = 'combat_ui_render'
        ui_combat.render(cfg, function()
            combat.configure(cfg.combat_log)
            save_character_settings(cfg)
        end)
    end

    if session and session.is_event and not ui.history_session then
        present_stage = 'session_persist'
        if (now_tick - lastSave) > 30 then
            local can_persist = true
            if session_event_id(session) == 'limbus' and session.limbus_run_started ~= true then
                can_persist = false
            end
            if can_persist then
                store.save(session);
            end
            lastSave = now_tick
        end
        if session.paused and (os.time() - session.paused) > (cfg.timeout or 30) * 60 then
            close_active_session('timeout')
        end
    end

    if ui.compact ~= (cfg.default_mode ~= 'full') and (now_tick - lastPrefSave) > 1 then
        present_stage = 'preference_persist'
        cfg.default_mode = ui.compact and 'compact' or 'full'
        save_character_settings(cfg);
        lastPrefSave = now_tick
    end
    present_stage = 'idle'
end)

------------------------------------------------------------------ zone salida
ashita.events.register('zone_change', 'treasure_zone', function()
    if session and session.is_event and session_event_id(session) == 'limbus' then
        local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
        local next_event = event_router.match_zone(zid)
        local still_limbus = (next_event == 'limbus')
        if still_limbus then
            limbusExitSeenAt = nil
            return
        end
    end
    close_active_session('zone_change')
end)

------------------------------------------------------------------ texto chat
-- Keep this handler before treasure_text. The 0x028 packet must reach the
-- client for floating text; its native chat line is blocked here. Changes
-- require an in-game test for floating text, parsed chat and no original line.
ashita.events.register('text_in', 'treasure_combat_suppress', function(e)
    if not combat.is_replacing_chat() then return end
    local block_modes = {
        [20]=true,[21]=true,[22]=true,[23]=true,[24]=true,[25]=true,[26]=true,[27]=true,
        [28]=true,[29]=true,[30]=true,[31]=true,[32]=true,[33]=true,[34]=true,[35]=true,
        [40]=true,[41]=true,[42]=true,[43]=true,[56]=true,[57]=true,[59]=true,[60]=true,
        [61]=true,[63]=true,[104]=true,[109]=true,[114]=true,[162]=true,[163]=true,
        [164]=true,[165]=true,[181]=true,[185]=true,[186]=true,[187]=true,[188]=true,
    }
    if not block_modes[tonumber(e.mode)] or e.injected == true then return end
    local message = e.message
    if type(message) ~= 'string' or message:sub(-2) ~= string.char(0x7F, 0x31) then return end
    local has_1e = message:find(string.char(0x1E), 1, true) ~= nil
    local has_1f = message:find(string.char(0x1F), 1, true) ~= nil
    if not has_1e and not has_1f then
        e.blocked = true
    elseif has_1e then
        e.blocked = true
    end
end)

ashita.events.register('text_in', 'treasure_text', function(e)
    local original_message = e.message or e.message_modified
    combat.on_text_in(e)
    -- Horizon has emitted this native system line under more than one chat
    -- mode. The anchored local-player matcher rejects ordinary player chat,
    -- while injected addon output remains excluded.
    if e.injected ~= true then
        local entity = GetPlayerEntity()
        local player_name = entity and entity.Name
        local candidates = { original_message, e.message_modified }
        local seen = {}
        for _, candidate in ipairs(candidates) do
            if type(candidate) == 'string' and not seen[candidate] then
                seen[candidate] = true
                local learned_name = blue_learn_alert.learned_spell_from_text(candidate, player_name)
                if learned_name == nil then
                    local ok, parsed_message = pcall(function()
                        return AshitaCore:GetChatManager():ParseAutoTranslate(candidate, true)
                    end)
                    if ok and type(parsed_message) == 'string' then
                        learned_name = blue_learn_alert.learned_spell_from_text(parsed_message, player_name)
                    end
                end
                if learned_name ~= nil then
                    emit_blue_magic_learned(nil, learned_name)
                    break
                end
            end
        end
    end

    if combat.is_own_line(original_message) then
        return
    end
    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local text_context = {
        mode = e.mode,
        injected = e.injected,
        zone_name = rm:GetString('zones.names', zid) or '',
    }
    if not e.injected then
        weekly_router.on_text(original_message, text_context)
    end
    if session and session.is_event then
        local ev_id = session_event_id(session)
        local handler = event_router.get(ev_id)
        if handler and handler.on_text then
            handler.on_text(original_message, session, text_context)
        else
            parser.handle_line(original_message, session, text_context)
        end
    end
end)

ashita.events.register('unload', 'treasure_unload', function()
    if session and session.is_event then
        local can_persist = session_event_id(session) ~= 'limbus'
                or session.limbus_run_started == true
        if can_persist then
            store.save(session, { force = true, event_id = session_event_id(session) })
        end
    end
    weekly_router.save_all()
    save_character_settings(cfg)
    party_chat_queue = {}
    sound_volume.shutdown()
    combat.shutdown()
end)
