--------------------------------------------------------------------------------
-- Addon: Treasure
-- Autor: Waky
-- Versión: 1.0.0
-- Descripción:
--   Registra en tiempo real todos los objetos en eventos y 
-- los muestra en una interfaz personalizable
--------------------------------------------------------------------------------

addon = addon or {}
addon.name = 'Treasure'
addon.author = 'Waky'
addon.version = '1.0.0'

require('common')
local settings = require('settings')
local core = require('core')
local parser = require('parser')
local store = require('store')
local ui = require('ui')
local fs = ashita.fs
local chat = require('chat')

local function is_ui_fully_hidden()
    local pattern_address = ashita.memory.find('FFXiMain.dll', 0,
            '8B4424046A016A0050B9????????E8????????F6D81BC040C3', 0, 0)
    if not pattern_address or pattern_address == 0 then
        return false
    end
    local ptr = ashita.memory.read_uint32(pattern_address + 10)
    if not ptr or ptr == 0 then
        return false
    end
    local flag = ashita.memory.read_uint8(ptr + 0xB4)
    return flag == 1
end

-- Conjunto de nombres de menús cuyos identificadores indican que debe ocultarse la UI.
local hidden_menus = {
    fulllog = true,
    equip = true,
    inventor = true,
    mnstorag = true,
    iuse = true,
    map0 = true,
    maplist = true,
    mapframe = true,
    scanlist = true,
    cnqframe = true,
    conf2win = true,
    cfilter = true,
    textcol1 = true,
    confyn = true,
    conf5m = true,
    conf5win = true,
    conf5w1 = true,
    conf5w2 = true,
    conf11m = true,
    conf11l = true,
    conf11s = true,
    conf3win = true,
    conf6win = true,
    conf12wi = true,
    conf13wi = true,
    fxfilter = true,
    conf7 = true,
    conf4 = true,
    link5 = true,
    link12 = true,
    link13 = true,
    link3 = true,
    scresult = true,
    evitem = true,
    statcom2 = true,
    auc1 = true,
    moneyctr = true,
    shopsell = true,
    comyn = true,
    auclist = true,
    auchisto = true,
    auc4 = true,
    post1 = true,
    post2 = true,
    stringdl = true,
    delivery = true,
    mcr1edlo = true,
    mcr2edlo = true,
    mcrbedit = true,
    mcresed = true,
    bank = true,
    handover = true,
    itmsortw = true,
    sortyn = true,
    itemctrl = true,
    loot = true,
    lootope = true,
    meritcat = true,
    merit1 = true,
    merit2 = true,
    merit3 = true,
    merityn = true,
    shop = true,
    automato = true,
    bluinven = true,
    bluequip = true,
    quest00 = true,
    quest01 = true,
    miss00 = true,
    faqsub = true,
    cmbhlst = true,
}

-- Detecta si hay un menú activo que debería ocultar la interfaz.
local function is_hiding_menu_active()
    local menu_address = ashita.memory.find('FFXiMain.dll', 0,
            '8B480C85C974??8B510885D274??3B05', 16, 0)
    if not menu_address or menu_address == 0 then
        return false
    end
    local pointer = ashita.memory.read_uint32(menu_address)
    if not pointer or pointer == 0 then
        return false
    end
    local pointer_value = ashita.memory.read_uint32(pointer)
    if not pointer_value or pointer_value == 0 then
        return false
    end
    local menu_header = ashita.memory.read_uint32(pointer_value + 4)
    if not menu_header or menu_header == 0 then
        return false
    end
    local raw_name = ashita.memory.read_string(menu_header + 0x46, 16)
    if not raw_name then
        return false
    end
    -- Quitar bytes nulos y el prefijo estándar "menu0000".
    local cleaned = raw_name:gsub('\x00', '')
    if #cleaned >= 9 then
        cleaned = cleaned:sub(9)
    else
        cleaned = ''
    end
    cleaned = cleaned:gsub(' ', '')
    return hidden_menus[cleaned] == true
end

------------------------------------------------- estado
local session, lastPool, lastSave = nil, 0, 0
local cfg

-- ---------------------------------------------------------------------------
-- Party / Alliance Detection
local party_members = {}

-- Última marca de tiempo de actualización para evitar refrescar en exceso
local lastPartyUpdate = 0

-- Actualiza la tabla `party_members`
local function update_party_members()
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party then
        return
    end
    local new_members = {}
    for slot = 0, 17 do
        if party:GetMemberIsActive(slot) == 1 then
            local name = party:GetMemberName(slot)
            if name and name:len() > 0 then
                -- Elimina caracteres nulos o espacios finales
                name = name:gsub('%z', ''):gsub('%s+$', '')
                new_members[name] = true
            end
        end
    end
    party_members = {}
    for nm, _ in pairs(new_members) do
        table.insert(party_members, nm)
    end
    table.sort(party_members)
    -- expone como variable global para consumo de la UI
    _G.TreasurePartyMembers = party_members
end

update_party_members()

-- Evento para actualizar la lista de party cuando llegan los paquetes.
ashita.events.register('packet_in', 'treasure_party_update', function(e)
    local pkt = e.id
    -- 0x0C8: Alliance update, 0x0DD: Party member update
    if pkt == 0x0C8 or pkt == 0x0DD then
        update_party_members()
    end
end)

------------------------------------------------- configuración por defecto
local DEFAULT_CONFIG = {
    visible = true,
    theme = "Default",
    alpha = 0.90,
    timeout = 30,
    colors = {
        QTY = { 1, 1, 1, 1 },
        CUR = { 0.1725, 1, 0.0431, 1 },
        ITEM = { 0, 1, 0.9961, 1 },
        HUNDO = { 1, 0.84, 0, 1 },
        NAME = { 0.55, 0.78, 1, 1 },
        LOST = { 1, 0.35, 0.35, 1 },
    },
    layout = {
        full = {
            window = { x = 536, y = 129, w = 605, h = 314 },
            cols = { 112.85, 112.96, 60.51, 302.68 },
            all_cols = { 109.93, 121.03, 121.03, 237.01 },
            cur_cols = { 201.71, 100.86, 100.86, 80.68 },
        },
        compact = {
            window = { x = 1784, y = 270, w = 266, h = 270 },
            cols = { 105.14, 55.42, 38.98, 50.46 },
        },
    },
}

------------------------------------------------- helpers
local function in_world()
    local ent = GetPlayerEntity()
    if not ent then
        return false
    end
    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    return zid ~= 0 and zid ~= 0xFFFF
end

local function ensure_settings()
    local base_dir = AshitaCore:GetInstallPath() .. '\\config\\addons\\treasure\\'
    if not fs.exists(base_dir) then
        fs.create_dir(base_dir)
    end
    local ok, loaded = pcall(settings.load, DEFAULT_CONFIG)
    if not ok or not loaded then
        loaded = DEFAULT_CONFIG;
        settings.save(loaded)
    end
    if not loaded.hasRun then
        loaded.visible = true;
        loaded.hasRun = true;
        settings.save(loaded)
    end
    return loaded
end

------------------------------------------------- eventos
ashita.events.register('command', 'tr_command', function(e)
    local args = e.command:args()
    -- Toggle visibility via the new `/tr` command.
    if args[1] ~= '/tr' then
        return
    end
    e.blocked = true
    cfg.visible = not cfg.visible
    settings.save(cfg)
end)

local rm = AshitaCore:GetResourceManager()

ashita.events.register('d3d_present', 'tr_pr', function()
    if not in_world() then
        return
    end

    if not cfg then
        cfg = ensure_settings()
    end

    local zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    local zoneName = rm:GetString('zones.names', zid) or ('Zone ' .. zid)

    if core.is_dynamis(zid) then
        -- Entramos en Dynamis: restaurar o crear sesión
        if not session then
            local now = os.time()
            local saved = store.load(zid, now)
            if saved then
                session = saved
                session.is_event = true
                session.management = session.management or {}
                local text = string.format('%s continues. Inventorys ready, ambition reloaded.', zoneName)
                print(chat.header('Treasure'):append(chat.message(text)))
            else
                session = parser.new_session(zid)
                session.is_event = true
                session.zone_id = zid
                session.start_time = now
                session.management = {}
                store.save(session)
                local text2 = string.format(
                        'Entering %s with 0 hope and 100%% hundo ambition..',
                        zoneName
                )
                print(chat.header('Treasure'):append(chat.message(text2)))
            end
            ui.compact = true
            ui.history_session = nil
            ui.history_idx = 0
        end
    else
        -- Salimos de Dynamis: guardamos y cerramos sesión
        if session and session.is_event then
            store.save(session)
        end
        session = nil
    end
    ------------------------------------------------------------------
    -- Selección de la sesión a mostrar en la UI.
    local draw_session
    local hist = ui.history_session
    if hist then
        draw_session = hist
    elseif session and session.is_event then
        draw_session = session
    else
        if not idle_session then
            idle_session = { drops = core.new_drop_state() }
        end
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
        update_party_members()
        lastPartyUpdate = os.clock()
    end

    -- Renderizado de la interfaz.
    local should_suppress = false
    if is_ui_fully_hidden() then
        should_suppress = true
    elseif is_hiding_menu_active() then
        should_suppress = true
    end
    if cfg.visible and not should_suppress then
        ui.render(draw_session, cfg)
    end

    -- Guardado automático y gestión de pausa en sesiones activas
    if session and session.is_event and ui.history_session == nil then
        if (os.clock() - lastSave) > 30 then
            store.save(session)
            lastSave = os.clock()
        end
        if session.paused and (os.time() - session.paused) > (cfg.timeout or 30) * 60 then
            store.save(session)
            session = nil
        end
    end
end)

ashita.events.register('zone_change', 'tr_zone', function(e)
    if session and session.is_event then
        store.save(session)
    end
    session = nil
end)

ashita.events.register('text_in', 'tr_text', function(e)
    if session and session.is_event then
        parser.handle_line(e.message_modified, session)
    end
end)

