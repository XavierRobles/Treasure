---------------------------------------------------------------------------
-- Treasure · ui.lua · Waky
---------------------------------------------------------------------------
local imgui = require('imgui')
local ImGuiCol = imgui.Col

-- libs ----------------------------------------------------------
local SETTINGS_OK, settings = pcall(require, 'settings')   -- settings.lua
local THEMES_OK, ADDON_THEMES = pcall(require, 'ev_themes')  -- palette file
local store = require('store')
-------------------------------------------------------------------------------

--------------------------------------------------------------------
-- instant-save helper
--------------------------------------------------------------------
-- Serializar
local function _dump(tbl, ind)
    ind = ind or ''
    local out = '{\n'
    for k, v in pairs(tbl) do
        -- No serializar claves internas ni funciones
        if not (type(k) == 'string' and k:sub(1, 1) == '_') and type(v) ~= 'function' then
            if type(k) == 'number' then
                out = out .. ind .. '  [' .. k .. '] = '
            else
                out = out .. ind .. '  [' .. string.format('%q', k) .. '] = '
            end
            if type(v) == 'table' then
                out = out .. _dump(v, ind .. '  ')
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

local function _save_config_file(cfg)
    local path = cfg and cfg._config_file
    if not path or path == '' then
        return
    end
    local dir = path:match('^(.*)[/\\]')
    if dir then
        local ok = pcall(function()
            if not ashita.fs.exists(dir) then
                ashita.fs.create_dir(dir)
            end
        end)
    end
    local f, err = io.open(path, 'w+')
    if not f then
        return
    end
    -- Serializa la tabla y la escribe
    f:write('return ' .. _dump(cfg) .. '\n')
    f:close()
end

local function persist(cfg)
    if cfg and cfg._config_file then
        local ok = pcall(_save_config_file, cfg)
        return
    end
    if SETTINGS_OK and settings and settings.save then
        if not pcall(settings.save) then
            pcall(settings.save, cfg)
        end
        return
    end
    local core = rawget(_G, 'AshitaCore')
    if core then
        local ok, mgr = pcall(function()
            return core:GetSettingsManager()
        end)
        if ok and mgr then
            if mgr.SaveSettings then
                pcall(function()
                    mgr:SaveSettings()
                end);
                return
            elseif mgr.Save then
                pcall(function()
                    mgr:Save()
                end);
                return
            end
        end
    end
    local gs = rawget(_G, 'gSettings');
    if gs and gs.Save then
        pcall(function()
            gs:Save()
        end)
    end
end
--------------------------------------------------------------------
-- Layout helpers
--------------------------------------------------------------------
local function _get_xy(vec)
    if type(vec) == 'table' then
        -- tabla {x, y} o {x =, y =}
        return vec[1] or vec.x or 0,
        vec[2] or vec.y or 0
    end                                              -- userdata → "ImVec2(x,y)"
    local sx, sy = tostring(vec):match('%(([%d%.-]+),([%d%.-]+)%)')
    return tonumber(sx) or 0, tonumber(sy) or 0
end

-- Guarda posición, tamaño y anchos de columnas --------------------
local function save_layout(cfg, mode)
    cfg.layout = cfg.layout or {}
    cfg.layout[mode] = cfg.layout[mode] or {}

    -- posición y tamaño
    local px, py = imgui.GetWindowPos()                  -- devuelve 2 números
    if type(px) ~= 'number' then
        -- fallback
        px, py = _get_xy(px)
    end
    local wx, wy = imgui.GetWindowSize()
    cfg.layout[mode].window = { x = px, y = py, w = wx, h = wy }

    if cfg.tre_col_w then
        cfg.layout[mode].cols = { table.unpack(cfg.tre_col_w) }
    end

    persist(cfg) -- << escribe settings.xml
end

local function load_layout(cfg, mode)
    local prof = cfg.layout and cfg.layout[mode]
    if not prof then
        return
    end

    if prof.window then
        imgui.SetNextWindowPos({ prof.window.x, prof.window.y })
        imgui.SetNextWindowSize({ prof.window.w, prof.window.h })
    end
    if prof.cols then
        cfg.tre_col_w = { table.unpack(prof.cols) }
        cfg._tre_init = false
    end
end


--------------------------------------------------------------------
-- Helpers to fetch ImGui / Ashita constants
--------------------------------------------------------------------
local function WF(name)
    if rawget(imgui, name) then
        return imgui[name]
    end
    if rawget(imgui, 'WindowFlags_' .. name) then
        return imgui['WindowFlags_' .. name]
    end
    if imgui.WindowFlags and imgui.WindowFlags[name] then
        return imgui.WindowFlags[name]
    end
    if rawget(imgui, 'ImGuiWindowFlags_' .. name) then
        return imgui['ImGuiWindowFlags_' .. name]
    end
    return ({ NoTitleBar = 1, NoResize = 2, NoMove = 4,
              NoScrollbar = 8, NoCollapse = 32 })[name] or 0
end
local function S(name)
    return rawget(imgui, name) or (imgui.StyleVar and imgui.StyleVar[name]) or 0
end

--------------------------------------------------------------------
-- Flags / defaults
--------------------------------------------------------------------
local TF_BORDER = imgui.TableFlags_BordersOuter
        or (imgui.TableFlags and imgui.TableFlags.BordersOuter) or 0

local DEFAULT_COLORS = {
    NAME = { 0.55, 0.78, 1.00, 1 },
    ITEM = { 1, 1, 1, 1 },
    CUR = { 0.85, 0.85, 0.85, 1 },
    HUNDO = { 1, 0.84, 0, 1 },
    QTY = { 1, 1, 1, 1 },
    LOST = { 1, 0.35, 0.35, 1 },
}

--------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------
local function norm(s)
    return (s or ''):gsub('%c', ''):lower():gsub('%s+', ' ')
                    :gsub('^%s+', ''):gsub('%s+$', '')
end
local function title(s)
    return (s or ''):gsub("(%a)([%w_']*)",
            function(a, b)
                return a:upper() .. b:lower()
            end)
end
local function keys(t)
    local k = {};
    for n in pairs(t) do
        k[#k + 1] = n
    end ;
    table.sort(k);
    return k
end
local function lost_name(l)
    return (l:match('%d%d:%d%d:%d%d%s+(.+)%s+lost%.?')
            or l:match('^(.+)%s+lost%.?$')):gsub('%s+$', '')
end
local function is_cur(n)
    local s = norm(n);
    return s:find('bronzepiece') or s:find('whiteshell')
            or s:find('byne bill') or s:find('jadeshell') or s:find('silverpiece')
end
local function is_hundo(n)
    local s = norm(n)
    if s:find('byne bill') then
        return s:find('^100 ') or s:find('one hundred')
    end
    if s:find('silverpiece') then
        return s:find('montiont') or s:find('m%.')
    end
    if s:find('jadeshell') then
        return s:find('lungo%-nango') or s:find('l%.')
    end
    return false
end
local function to_units(name, qty)
    return is_hundo(name) and 100 * qty or qty
end


--------------------------------------------------------------------
-- Theme / window helpers
--------------------------------------------------------------------
local function push_theme(name)
    if not THEMES_OK then
        return 0
    end
    local th = ADDON_THEMES[name] or ADDON_THEMES.Default
    local n = 0
    if th then
        for col, val in pairs(th) do
            imgui.PushStyleColor(col, val);
            n = n + 1
        end
    end
    return n
end

local WF_FRAMELESS = bit.bor(
        WF('NoTitleBar')
-- WF('NoResize'),
-- WF('NoMove'),
-- WF('NoScrollbar'),
-- WF('NoCollapse')
)
local function push_frameless_style()
    local n = 0
    if S('WindowBorderSize') ~= 0 then
        imgui.PushStyleVar(S('WindowBorderSize'), 0);
        n = n + 1
    end
    if S('WindowRounding') ~= 0 then
        imgui.PushStyleVar(S('WindowRounding'), 0);
        n = n + 1
    end
    return n
end


--------------------------------------------------------------------
----------------------------------------------------------------
-- Canonical name for aggregation  (100‑piece y 1‑piece juntos)
----------------------------------------------------------------
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
    return title(name)
end
--------------------------------------------------------------
----------------------------------------------------------------
-- Friendly label to mostrar en la tabla “Split”
----------------------------------------------------------------
local function display_cur(base)
    if base == 'Bronzepiece' then
        return 'Ordelle Bronzepiece'
    end
    if base == 'Whiteshell' then
        return 'Tukuku Whiteshell'
    end
    if base == 'Byne Bill' then
        return 'One Byne Bill'
    end
    return base
end

-- Formatea 1234567  →  1 234 567
--------------------------------------------------------------
local function fmt_n(num)
    local s = tostring(num)
    while true do
        s, k = s:gsub('(%d)(%d%d%d)$', '%1,%2')
        if k == 0 then
            break
        end
    end
    return s
end

--------------------------------------------------------------------
-- UI state
--------------------------------------------------------------------
local ui = {
    filter = 'All',
    split_n = nil,
    compact = true,
    history_idx = 0,
    history_session = nil,
    glass_paid = {},
    currency_delivered = {},
    participation = {}
}


--------------------------------------------------------------------
-- Pintar columnas y resizables
--------------------------------------------------------------------
local function draw_treasure_table (sess, C, cfg)
    if not sess or not sess.drops then
        return
    end

    -- Anchos de columnas persistentes
    cfg.tre_col_w = cfg.tre_col_w or { 250, 150, 60, 60 }
    cfg._tre_init = cfg._tre_init or false

    ----------------------------------------------------------------
    -- Construir lista ordenada por slot
    ----------------------------------------------------------------
    local list, count = {}, 0
    for slot, info in pairs(sess.drops.pool_live or {}) do
        count = count + 1
        list[#list + 1] = {
            slot = slot,
            info = info,
            rest = math.max(0, math.floor(info.expire - os.clock()))
        }
    end
    table.sort(list, function(a, b)
        if a.rest ~= b.rest then
            return a.rest < b.rest
        end
        return a.slot < b.slot
    end)


    ----------------------------------------------------------------
    -- Altura de la región scroll (modo compacto = altura dinámica)
    ----------------------------------------------------------------
    local child_h = 200
    if ui.compact then
        local row_h = imgui.GetTextLineHeight() + imgui.GetStyle().FramePadding.y * 2
        local want_h = row_h * (count + 1)
        local min_child = row_h * 2
        local max_child = row_h * 12
        child_h = math.min(max_child, math.max(min_child, want_h))
    end

    ----------------------------------------------------------------
    -- Scroll‑region y columnas
    ----------------------------------------------------------------
    imgui.PushStyleColor(3, { 0, 0, 0, 0 })
    local sv = S and S('ScrollbarSize')
    if sv and sv ~= 0 then
        imgui.PushStyleVar(sv, 0)
    end

    imgui.BeginChild('treasure_scroll_region', { 0, child_h }, false, WF('NoScrollbar'))

    imgui.Columns(4, 'treasure_columns', true)
    if not cfg._tre_init then
        for i, w in ipairs(cfg.tre_col_w) do
            imgui.SetColumnWidth(i - 1, w)
        end
        cfg._tre_init = true
    end

    -- Cabeceras
    imgui.Text('Item');
    imgui.NextColumn()
    imgui.Text('Winner');
    imgui.NextColumn()
    imgui.Text('Lot');
    imgui.NextColumn()
    imgui.Text('Left');
    imgui.NextColumn()
    imgui.Separator()

    -- Filas
    for _, e in ipairs(list) do
        local info, rest = e.info, e.rest

        local rcol = (rest < 30 and { 1, 0.4, 0.4, 1 })
                or (rest < 120 and { 1, 0.85, 0.25, 1 })
                or { 0.3, 1, 0.3, 1 }
        local col = is_cur(info.name)
                and (is_hundo(info.name) and C.HUNDO or C.CUR)
                or C.ITEM

        imgui.TextColored(col, title(info.name));
        imgui.NextColumn()
        imgui.TextColored(C.NAME, info.winner or '');
        imgui.NextColumn()
        if info.lot and info.lot > 0 then
            imgui.TextColored(C.QTY, tostring(info.lot))
        else
            imgui.Text('')
        end
        imgui.NextColumn()
        imgui.TextColored(rcol, rest .. 's');
        imgui.NextColumn()
    end

    ----------------------------------------------------------------
    -- Guardar cambios de anchura de columnas
    ----------------------------------------------------------------
    do
        local changed = false
        for i = 1, 4 do
            local w = imgui.GetColumnWidth(i - 1)
            if w and w ~= cfg.tre_col_w[i] then
                cfg.tre_col_w[i], changed = w, true
            end
        end
        if changed then
            local mode = ui.compact and 'compact' or 'full'
            cfg.layout = cfg.layout or {}
            cfg.layout[mode] = cfg.layout[mode] or {}
            cfg.layout[mode].cols = { table.unpack(cfg.tre_col_w) }
            persist(cfg)
        end
    end

    imgui.Columns(1)
    imgui.EndChild()
    if sv and sv ~= 0 then
        imgui.PopStyleVar()
    end
    imgui.PopStyleColor()
end

local function draw_settings_panel(cfg, C)
    local changed = false
    local list = THEMES_OK and keys(ADDON_THEMES) or { cfg.theme }
    local sel = 1;
    for i, n in ipairs(list) do
        if n == cfg.theme then
            sel = i
        end
    end
    if imgui.BeginCombo('Theme', list[sel] or '?') then
        for i, nm in ipairs(list) do
            if imgui.Selectable(nm, sel == i) then
                cfg.theme = nm;
                changed = true
            end
        end
        imgui.EndCombo()
    end
    local a = { cfg.alpha }
    if imgui.SliderFloat('Opacity', a, 0.2, 1.0, '%.2f') then
        cfg.alpha = a[1];
        changed = true
    end
    -- Control deslizante para ajustar la escala de la fuente de la ventana.
    local fs = { cfg.font_scale or 1.0 }
    if imgui.SliderFloat('Font Scale', fs, 0.5, 2.0, '%.2f') then
        cfg.font_scale = fs[1]
        changed = true
    end
    imgui.Separator()
    local function picker(lbl, key)
        if imgui.ColorEdit4(lbl, cfg.colors[key], imgui.ColorEditFlags_NoInputs) then
            changed = true
        end
    end
    picker('Player names', 'NAME');
    picker('Equipment', 'ITEM');
    picker('Currency', 'CUR')
    picker('100-piece', 'HUNDO');
    picker('Qty / Total', 'QTY');
    picker('Lost count', 'LOST')
    if changed then
        persist(cfg)
    end
end

--------------------------------------------------------------------
-- MAIN RENDER
--------------------------------------------------------------------
function ui.render(sess, cfg)
    ----------------------------------------------------------------
    -- Defaults (colores, tema, opacidad)
    ----------------------------------------------------------------
    cfg.colors = cfg.colors or {}
    for k, v in pairs(DEFAULT_COLORS) do
        if not cfg.colors[k] then
            cfg.colors[k] = { table.unpack(v) }
        end
    end
    cfg.alpha = cfg.alpha or 0.9
    cfg.theme = cfg.theme or ((THEMES_OK and ADDON_THEMES.Default) and 'Default' or '')
    -- Ajuste de escala de fuente para toda la ventana. Valor por defecto 1.0 (sin escalado).
    cfg.font_scale = cfg.font_scale or 1.0
    local C = cfg.colors

    ----------------------------------------------------------------
    -- Layout tables
    ----------------------------------------------------------------
    cfg.layout = cfg.layout or {}
    cfg.layout.compact = cfg.layout.compact or {
        window = { w = 360, h = 420 },
        cols = { 250, 150, 60, 60 },
    }
    cfg.layout.full = cfg.layout.full or {
        window = { w = 600, h = 500 },
        cols = { 300, 200, 60, 60 },
    }

    ----------------------------------------------------------------
    -- Aplicar layout solo al entrar en un modo nuevo
    ----------------------------------------------------------------
    ui._layout_mode = ui._layout_mode or ''          -- estado interno
    local mode = ui.compact and 'compact' or 'full'
    if ui._layout_mode ~= mode then
        load_layout(cfg, mode)                       -- ← pos / tamaño / columnas
        ui._layout_mode = mode
    end

    ----------------------------------------------------------------
    -- Tema y estilo sin marco
    ----------------------------------------------------------------
    local pushed_theme = push_theme(cfg.theme)
    local pushed_style = push_frameless_style()

    ----------------------------------------------------------------
    -- Abrimos la ventana
    ----------------------------------------------------------------
    local window_flags = WF_FRAMELESS
    if ui.compact then
        window_flags = bit.bor(window_flags, WF('NoScrollbar'))
    end

    imgui.SetNextWindowBgAlpha(cfg.alpha)
    if not imgui.Begin('Treasure', false, window_flags) then
        imgui.End()
        if pushed_style > 0 then
            imgui.PopStyleVar(pushed_style)
        end
        if pushed_theme > 0 then
            imgui.PopStyleColor(pushed_theme)
        end
        return
    end
    if imgui.SetWindowFontScale and cfg.font_scale then
        local fs = cfg.font_scale
        if type(fs) ~= 'number' then
            fs = tonumber(fs) or 1.0
        end
        -- Evita valores extremadamente bajos que podrían hacer ilegible el texto.
        if fs < 0.2 then
            fs = 0.2
        end
        imgui.SetWindowFontScale(fs)
    end


    ----------------------------------------------------------------
    -- Guarda automáticamente
    ----------------------------------------------------------------
    do
        local px, py = imgui.GetWindowPos()
        local wx, wy = imgui.GetWindowSize()
        local win = cfg.layout[mode].window or {}
        if win.x ~= px or win.y ~= py or
                win.w ~= wx or win.h ~= wy then
            cfg.layout[mode].window = { x = px, y = py, w = wx, h = wy }
            persist(cfg)
        end
    end

    ----------------------------------------------------------------
    -- Si estamos fuera de Dynamis, aviso y salida
    ----------------------------------------------------------------
    if not sess then
        imgui.TextDisabled('Outside Dynamis.')
        imgui.End()
        if pushed_style > 0 then
            imgui.PopStyleVar(pushed_style)
        end
        if pushed_theme > 0 then
            imgui.PopStyleColor(pushed_theme)
        end
        return
    end

    ----------------------------------------------------------------
    -- Botones Dynamis / Back  y  Close ✕
    ----------------------------------------------------------------
    do
        local style = imgui.GetStyle()
        local pad = style.FramePadding.x
        local spacing = style.ItemInnerSpacing.x
        local win_w = imgui.GetWindowWidth()

        local lbl_toggle = ui.compact and 'Dynamis > ##toggle' or '< Back ##toggle'
        local txt1_w, _ = imgui.CalcTextSize(lbl_toggle)
        local btn1_w = txt1_w + pad * -10

        local lbl_close = 'X##close'
        local txt2_w, _ = imgui.CalcTextSize('X')
        local btn2_w = txt2_w + pad * 2

        imgui.SetCursorPosX(win_w - btn1_w - btn2_w - spacing - pad)

        -- Toggle compact / full
        if imgui.SmallButton(lbl_toggle) then
            -- guarda el layout actual antes de cambiar
            save_layout(cfg, mode)
            -- intercambia el modo
            ui.compact = not ui.compact
            ui._layout_mode = ''
            -- si cambia al modo compacto, restaura la sesión actual
            if ui.compact then
                ui.history_idx = 0
                ui.history_session = nil
            end
        end

        imgui.SameLine(0, spacing)
        if imgui.SmallButton(lbl_close) then
            cfg.visible = false
            persist(cfg)
            imgui.End()
            if pushed_style > 0 then
                imgui.PopStyleVar(pushed_style)
            end
            if pushed_theme > 0 then
                imgui.PopStyleColor(pushed_theme)
            end
            return
        end
    end

    ----------------------------------------------------------------
    -- Ajuste dinámico del alto de la ventana en modo compacto
    ----------------------------------------------------------------
    do
        if ui.compact then
            --------------------------------------------------------
            -- 1) nº de drops vivos
            --------------------------------------------------------
            local live = sess and sess.drops and sess.drops.pool_live or {}
            local cnt = 0;
            for _ in pairs(live) do
                cnt = cnt + 1
            end

            --------------------------------------------------------
            -- 2) altura de cada fila  +  cabecera
            --------------------------------------------------------
            local style = imgui.GetStyle()
            local row_h = imgui.GetTextLineHeight() + style.FramePadding.y * 2

            -- base: cabecera + n filas
            local child_h = row_h * (cnt + 1)

            if cnt <= 4 then
                child_h = child_h + row_h * 1        -- 1 fila entera
            else
                child_h = child_h + row_h * 0.5      -- ½ fila
            end

            -- límite superior: máx. 10 filas visibles (cabecera + 9 datos)
            child_h = math.min(row_h * 11, child_h)

            --------------------------------------------------------
            -- 3) parte fija (título + botones + pestaña)
            --------------------------------------------------------
            if not ui._top_area then
                ui._top_area = imgui.GetCursorPosY()
            end

            --------------------------------------------------------
            -- 4) aplica el alto total
            --------------------------------------------------------
            local total_h = ui._top_area + child_h + style.WindowPadding.y
            local w, _ = imgui.GetWindowSize()
            imgui.SetWindowSize({ w, total_h })

        else
            ui._top_area = nil  -- fuera del modo compacto
        end
    end


    ----------------------------------------------------------------
    -- Ajuste dinámico del alto de la ventana en modo compacto
    ----------------------------------------------------------------
    do
        local live = sess and sess.drops and sess.drops.pool_live
        if ui.compact and live then
            local cnt = 0;
            for _ in pairs(live) do
                cnt = cnt + 1
            end
            if cnt ~= ui._last_compact_count then
                ui._last_compact_count = cnt

                -- Altura por fila
                local row_h = imgui.GetTextLineHeight() + imgui.GetStyle().FramePadding.y * 2
                -- Región de tabla
                local child = math.min(row_h * 12, math.max(row_h * 2, row_h * (cnt + 2)))

                if not ui._top_area then
                    ui._top_area = row_h * 3
                end

                local new_h = math.floor(ui._top_area + child + 0.5)
                if not ui._last_compact_height or math.abs(new_h - ui._last_compact_height) > 1 then
                    local w, _ = imgui.GetWindowSize()
                    imgui.SetWindowSize({ w, new_h })
                    ui._last_compact_height = new_h
                end
            end
        else
            ui._last_compact_count = -1
            ui._last_compact_height = nil
            ui._top_area = nil
        end
    end

    imgui.Separator()

    ----------------------------------------------------------------
    -- Selector de sesiones históricas
    ----------------------------------------------------------------
    do
        if not ui.compact then
            local files = store.list_sessions() or {}
            if #files > 0 then
                -- Etiqueta que muestra la selección actual. la opción 0 representa
                -- el estado actual.
                local preview
                if ui.history_idx > 0 and ui.history_idx <= #files then
                    preview = files[ui.history_idx]
                else
                    preview = 'Current'
                end
                if imgui.BeginCombo('History', preview) then
                    local sel0 = (ui.history_idx == 0)
                    if imgui.Selectable('Current', sel0) then
                        ui.history_idx = 0
                        ui.history_session = nil
                    end
                    if sel0 then
                        imgui.SetItemDefaultFocus()
                    end
                    -- Opciones para cada archivo
                    for i, fname in ipairs(files) do
                        local selected = (ui.history_idx == i)
                        if imgui.Selectable(fname, selected) then
                            ui.history_idx = i
                            local sess_loaded = store.load_file(fname)
                            ui.history_session = sess_loaded
                        end
                        if selected then
                            imgui.SetItemDefaultFocus()
                        end
                    end
                    imgui.EndCombo()
                end
            end
        end
    end


    ----------------------------------------------------------------
    -- TAB BAR principal
    ----------------------------------------------------------------
    if imgui.BeginTabBar('##edtabs') then
        ----------------------------------------------------------------
        -- COMPACT ----------------------------------------------------
        ----------------------------------------------------------------
        if ui.compact then
            if imgui.BeginTabItem('Treasure') then
                draw_treasure_table(sess, C, cfg)
                imgui.EndTabItem()
            end
            ------------------------------------------------------------ FULL VIEW
        else
            ------------------------------------------------ ALL
            if imgui.BeginTabItem('All') then
                imgui.BeginTable('tbl_all', 4, TF_BORDER)
                imgui.TableSetupColumn('Item');
                imgui.TableSetupColumn('Qty')
                imgui.TableSetupColumn('Total');
                imgui.TableSetupColumn('Lost')
                imgui.TableHeadersRow()

                local acc = {}
                for n, q in pairs(sess.drops.currency_total) do
                    acc[n] = { q = q, e = 0, l = 0 }
                end
                for _, pl in pairs(sess.drops.equips_by_player) do
                    for _, it in ipairs(pl) do
                        local a = acc[it] or { q = 0, e = 0, l = 0 };
                        a.e = a.e + 1;
                        acc[it] = a
                    end
                end
                for _, ln in ipairs(sess.drops.lost) do
                    local it = lost_name(ln);
                    local a = acc[it] or { q = 0, e = 0, l = 0 };
                    a.l = a.l + 1;
                    acc[it] = a
                end
                for _, k in ipairs(keys(acc)) do
                    local a = acc[k]
                    local col = is_cur(k) and (is_hundo(k) and C.HUNDO or C.CUR) or C.ITEM
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0);
                    imgui.TextColored(col, title(k))
                    imgui.TableSetColumnIndex(1);
                    imgui.TextColored(C.QTY, a.q + a.e .. '')
                    imgui.TableSetColumnIndex(2);
                    imgui.TextColored(C.QTY, a.q + a.e + a.l .. '')
                    imgui.TableSetColumnIndex(3);
                    if a.l > 0 then
                        imgui.TextColored(C.LOST, a.l .. '')
                    end
                end
                imgui.EndTable();
                imgui.EndTabItem()
            end

            ------------------------------------------------ CURRENCY
            if imgui.BeginTabItem('Currency') then
                -- selector Split ----------------------------------------
                local comboW = 52
                local txtW = select(1, imgui.CalcTextSize('Split'))
                local spacing = imgui.GetStyle().ItemInnerSpacing.x
                local pad = imgui.GetStyle().FramePadding.x * 2
                imgui.SetCursorPosX(imgui.GetWindowWidth() - comboW - txtW - spacing - pad)
                imgui.TextUnformatted('Split');
                imgui.SameLine();
                imgui.PushItemWidth(comboW)
                local label = ui.split_n and string.format('%2d', ui.split_n) or '--'
                if imgui.BeginCombo('##split', label) then
                    if imgui.Selectable('None', ui.split_n == nil) then
                        ui.split_n = nil
                    end
                    imgui.Separator()
                    for i = 1, 36 do
                        if imgui.Selectable(string.format('%2d', i), ui.split_n == i) then
                            ui.split_n = i
                        end
                    end
                    imgui.EndCombo()
                end
                imgui.PopItemWidth();
                imgui.Separator()

                -------------- split table -------------------------------
                if ui.split_n then
                    imgui.TextUnformatted('Currency Split')
                    imgui.BeginTable('tbl_split', 4, TF_BORDER)
                    imgui.TableSetupColumn('Currency')
                    imgui.TableSetupColumn('Total units')
                    imgui.TableSetupColumn('Each member')
                    imgui.TableSetupColumn('Remainder')
                    imgui.TableHeadersRow()

                    -- agrupar unidades
                    local agg = {}
                    for _, cur in ipairs(keys(sess.drops.currency_total)) do
                        if is_cur(cur) then
                            local units = to_units(cur, sess.drops.currency_total[cur])
                            local base = base_cur(cur)
                            agg[base] = (agg[base] or 0) + units
                        end
                    end

                    for _, base in ipairs(keys(agg)) do
                        local units = agg[base]
                        local each = math.floor(units / ui.split_n)
                        local rem = units - each * ui.split_n
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0);
                        imgui.TextColored(C.CUR, display_cur(base))
                        imgui.TableSetColumnIndex(1);
                        imgui.TextColored(C.QTY, units .. '')
                        imgui.TableSetColumnIndex(2);
                        imgui.TextColored(C.QTY, each .. '')
                        imgui.TableSetColumnIndex(3);
                        if rem > 0 then
                            imgui.TextColored(C.LOST, rem .. '')
                        end
                    end

                    -- Timeless Hourglass
                    local th_each = math.floor(1000000 / ui.split_n)
                    local th_rem = 1000000 - th_each * ui.split_n
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0);
                    imgui.TextColored(C.ITEM, 'Timeless Hourglass')
                    imgui.TableSetColumnIndex(1);
                    imgui.TextColored(C.QTY, '1,000,000')
                    imgui.TableSetColumnIndex(2);
                    imgui.TextColored(C.QTY, '- ' .. fmt_n(th_each) .. ' gil')
                    imgui.TableSetColumnIndex(3);
                    if th_rem > 0 then
                        imgui.TextColored(C.LOST, th_rem .. '')
                    end

                    imgui.EndTable()
                    imgui.Separator()
                end

                -- tabla Currency original (tbl_cur) ----------------------
                imgui.BeginTable('tbl_cur', 4, TF_BORDER)
                imgui.TableSetupColumn('Currency');
                imgui.TableSetupColumn('Qty')
                imgui.TableSetupColumn('Total');
                imgui.TableSetupColumn('Lost')
                imgui.TableHeadersRow()
                local lost = {};
                for _, ln in ipairs(sess.drops.lost) do
                    local it = lost_name(ln);
                    lost[it] = (lost[it] or 0) + 1
                end
                for _, cur in ipairs(keys(sess.drops.currency_total)) do
                    if is_cur(cur) then
                        local qty = sess.drops.currency_total[cur]
                        local lst = lost[cur] or 0
                        local col = is_hundo(cur) and C.HUNDO or C.CUR
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0);
                        imgui.TextColored(col, title(cur))
                        imgui.TableSetColumnIndex(1);
                        imgui.TextColored(C.QTY, qty .. '')
                        imgui.TableSetColumnIndex(2);
                        imgui.TextColored(C.QTY, qty + lst .. '')
                        imgui.TableSetColumnIndex(3);
                        if lst > 0 then
                            imgui.TextColored(C.LOST, lst .. '')
                        end
                    end
                end
                imgui.EndTable()
                imgui.EndTabItem()
            end

            ---------------------------------------------------------------- PLAYERS
            if imgui.BeginTabItem('Players') then
                local plist = keys(sess.drops.by_player)
                if imgui.BeginCombo('Show player', ui.filter == 'All' and 'All players' or ui.filter) then
                    if imgui.Selectable('All players', ui.filter == 'All') then
                        ui.filter = 'All'
                    end
                    imgui.SetItemDefaultFocus()
                    for _, p in ipairs(plist) do
                        if imgui.Selectable(p, ui.filter == p) then
                            ui.filter = p
                        end
                    end
                    imgui.EndCombo()
                end
                imgui.Separator()
                local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                if ui.filter == 'All' then
                    for idx, pl in ipairs(plist) do
                        local bag = sess.drops.by_player[pl] or {}
                        if imgui.BeginTable('tbl_' .. pl, 3, TFLAGS) then
                            local stretch = imgui.TableColumnFlags_WidthStretch or 0
                            imgui.TableSetupColumn('Player', stretch)
                            imgui.TableSetupColumn('Item', stretch)
                            imgui.TableSetupColumn('Qty', stretch)
                            imgui.TableHeadersRow()
                            for _, it in ipairs(keys(bag)) do
                                local col = is_cur(it) and (is_hundo(it) and C.HUNDO or C.CUR) or C.ITEM
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0);
                                imgui.TextColored(C.NAME, pl)
                                imgui.TableSetColumnIndex(1);
                                imgui.TextColored(col, title(it))
                                imgui.TableSetColumnIndex(2);
                                imgui.TextColored(C.QTY, bag[it] .. '')
                            end
                            imgui.EndTable()
                        end
                        if idx < #plist then
                            imgui.Separator()
                        end
                    end
                else
                    local bag = sess.drops.by_player[ui.filter] or {}
                    if imgui.BeginTable('tbl_ply_single', 3, TFLAGS) then
                        imgui.TableSetupColumn('Player');
                        imgui.TableSetupColumn('Item');
                        imgui.TableSetupColumn('Qty')
                        imgui.TableHeadersRow()
                        for _, it in ipairs(keys(bag)) do
                            local col = is_cur(it) and (is_hundo(it) and C.HUNDO or C.CUR) or C.ITEM
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0);
                            imgui.TextColored(C.NAME, ui.filter)
                            imgui.TableSetColumnIndex(1);
                            imgui.TextColored(col, title(it))
                            imgui.TableSetColumnIndex(2);
                            imgui.TextColored(C.QTY, bag[it] .. '')
                        end
                        imgui.EndTable()
                    end
                end
                imgui.EndTabItem()
            end

            ---------------------------------------------------------------- ITEMS
            if imgui.BeginTabItem('Items') then
                local plist = keys(sess.drops.by_player)               -- mismos jugadores
                local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                for idx, pl in ipairs(plist) do
                    local bag = sess.drops.by_player[pl] or {}
                    if imgui.BeginTable('tbl_items_' .. pl, 3, TFLAGS) then
                        imgui.TableSetupColumn('Player')
                        imgui.TableSetupColumn('Item')
                        imgui.TableSetupColumn('Qty')
                        imgui.TableHeadersRow()
                        for _, it in ipairs(keys(bag)) do
                            if not is_cur(it) then
                                -- solo equipo
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0);
                                imgui.TextColored(C.NAME, pl)
                                imgui.TableSetColumnIndex(1);
                                imgui.TextColored(C.ITEM, title(it))
                                imgui.TableSetColumnIndex(2);
                                imgui.TextColored(C.QTY, bag[it] .. '')
                            end
                        end
                        imgui.EndTable()
                    end
                    if idx < #plist then
                        imgui.Separator()
                    end        -- barra divisoria
                end
                imgui.EndTabItem()
            end

            ---------------------------------------------------------------- LOST
            if imgui.BeginTabItem('Lost') then
                imgui.BeginTable('tbl_lost', 2, TF_BORDER)
                imgui.TableSetupColumn('Time');
                imgui.TableSetupColumn('Item')
                imgui.TableHeadersRow()
                for _, ln in ipairs(sess.drops.lost) do
                    local tm, it = ln:match('^(%d%d:%d%d:%d%d)%s+(.+)%s+lost')
                    local name = it or ln
                    local col = is_cur(name) and (is_hundo(name) and C.HUNDO or C.CUR) or C.ITEM
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0);
                    imgui.Text(tm or '--')
                    imgui.TableSetColumnIndex(1);
                    imgui.TextColored(col, title(name))
                end
                imgui.EndTable();
                imgui.EndTabItem()
            end

            ---------------------------------------------------------------- TREASURE
            if imgui.BeginTabItem('Treasure') then
                draw_treasure_table(sess, C, cfg)
                imgui.EndTabItem()
            end

            ---------------------------------------------------------------- MANAGEMENT
            -- Tab for managing participants and tracking payments/deliveries.
            if imgui.BeginTabItem('Management') then
                if not (sess and sess.is_event) then
                    imgui.TextDisabled('No active event')
                    imgui.EndTabItem()
                else
                    sess.management = sess.management or {}
                    -- Construye la lista de jugadores a mostrar:
                    local names_set = {}
                    if sess.drops and sess.drops.by_player then
                        for name, _ in pairs(sess.drops.by_player) do
                            names_set[name] = true
                        end
                    end
                    -- Jugadores ya registrados en la gestión
                    if sess.management then
                        for name, _ in pairs(sess.management) do
                            names_set[name] = true
                        end
                    end
                    -- Miembros de la party/alianza detectados por Treasure
                    if ui.history_session == nil then
                        local tm = rawget(_G, 'TreasurePartyMembers')
                        if tm then
                            for _, name in ipairs(tm) do
                                names_set[name] = true
                            end
                        end
                    end
                    -- Convierte el conjunto a lista ordenada alfabéticamente
                    local plist = {}
                    for name, _ in pairs(names_set) do
                        table.insert(plist, name)
                    end
                    table.sort(plist)
                    local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                    if imgui.BeginTable('tbl_manage', 4, TFLAGS) then
                        imgui.TableSetupColumn('Name')
                        imgui.TableSetupColumn('Glass paid')
                        imgui.TableSetupColumn('Currency delivered')
                        imgui.TableSetupColumn('Participation')
                        imgui.TableHeadersRow()
                        for _, pl in ipairs(plist) do
                            -- Inicializa los campos de gestión por jugador si no existen
                            sess.management[pl] = sess.management[pl] or {
                                glass_paid = false,
                                currency_delivered = false,
                                participation = 'Full',
                            }
                            local m = sess.management[pl]
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0);
                            imgui.TextColored(C.NAME, pl)
                            imgui.TableSetColumnIndex(1)
                            do
                                local val = { m.glass_paid }
                                if imgui.Checkbox('##gp_' .. pl, val) then
                                    m.glass_paid = val[1]
                                    sess.management[pl].glass_paid = val[1]
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end
                            imgui.TableSetColumnIndex(2)
                            do
                                local val = { m.currency_delivered }
                                if imgui.Checkbox('##cd_' .. pl, val) then
                                    m.currency_delivered = val[1]
                                    sess.management[pl].currency_delivered = val[1]
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end
                            imgui.TableSetColumnIndex(3)
                            do
                                local current = m.participation or 'Full'
                                local label = current
                                if imgui.BeginCombo('##part_' .. pl, label) then
                                    local options = {
                                        'Full',
                                        '4h', '3.5h', '3h', '2.5h', '2h', '1.5h', '1h', '0.5h', '0'
                                    }
                                    for _, opt in ipairs(options) do
                                        local selected = (current == opt)
                                        if imgui.Selectable(opt, selected) then
                                            m.participation = opt
                                            sess.management[pl].participation = opt
                                            current = opt
                                            if store and sess and sess.is_event then
                                                store.save(sess)
                                            end
                                        end
                                        if selected then
                                            imgui.SetItemDefaultFocus()
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            end
                        end
                        imgui.EndTable()
                    end
                    imgui.EndTabItem()
                end
            end

            ---------------------------------------------------------------- SETTINGS
            if imgui.BeginTabItem('Settings') then
                draw_settings_panel(cfg, C)
                imgui.EndTabItem()
            end
        end -- compact / full
        imgui.EndTabBar()
    end -- BeginTabBar

    imgui.End()
    if pushed_style > 0 then
        imgui.PopStyleVar(pushed_style)
    end
    if pushed_theme > 0 then
        imgui.PopStyleColor(pushed_theme)
    end
end

return ui