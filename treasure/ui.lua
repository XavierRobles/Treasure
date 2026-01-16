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
local function is_cur(name)
    local s = norm(name or '')
    return (s:find('bronzepiece') ~= nil)
            or (s:find('whiteshell') ~= nil)
            or (s:find('byne bill') ~= nil)
            or (s:find('silverpiece') ~= nil)
            or (s:find('jadeshell') ~= nil)
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
        return 'Byne Bill'          -- includes 100 Byne Bill
    end
    if s:find('whiteshell') then
        return 'Whiteshell'         -- includes Lungo-Nango Jadeshell
    end
    if s:find('jadeshell') then
        return 'Whiteshell'
    end
    if s:find('bronzepiece') then
        return 'Bronzepiece'        -- includes Montiont Silverpiece
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
        local n
        s, n = s:gsub('(%d)(%d%d%d)$', '%1,%2')
        if n == 0 then
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
    compact = true,
    history_idx = 0,
    history_session = nil,
    glass_paid = {},
    currency_delivered = {},
    players_currency_only = false,
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
        local h_changed = (not ui.compact) and (win.h ~= wy)
        if win.x ~= px or win.y ~= py or win.w ~= wx or h_changed then
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
        local btn1_w = txt1_w + pad * 2

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
    -- Dynamic height in compact mode (single, non-duplicated block)
    ----------------------------------------------------------------
    do
        local live = sess and sess.drops and sess.drops.pool_live or {}

        if ui.compact then
            local cnt = 0
            for _ in pairs(live) do
                cnt = cnt + 1
            end

            -- Only recompute / apply when count changes
            if cnt ~= ui._last_compact_count then
                ui._last_compact_count = cnt

                local style = imgui.GetStyle()
                local row_h = imgui.GetTextLineHeight() + style.FramePadding.y * 2

                -- Table region height (header + rows), with small padding tweak
                local child_h = row_h * (cnt + 1)
                if cnt <= 4 then
                    child_h = child_h + row_h * 1
                else
                    child_h = child_h + row_h * 0.5
                end
                child_h = math.min(row_h * 11, child_h) -- cap

                -- Capture top area once (title/buttons/tabs)
                if not ui._top_area then
                    ui._top_area = imgui.GetCursorPosY()
                end

                local total_h = math.floor(ui._top_area + child_h + style.WindowPadding.y + 0.5)

                -- Avoid tiny jitter
                if (not ui._last_compact_height) or math.abs(total_h - ui._last_compact_height) > 1 then
                    local w, _ = imgui.GetWindowSize()
                    imgui.SetWindowSize({ w, total_h })
                    ui._last_compact_height = total_h
                end
            end
        else
            ui._last_compact_count = nil
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
                -- Summary (total units per base currency)
                do
                    local agg = {}
                    local total_units = 0

                    for name, qty in pairs(sess.drops.currency_total or {}) do
                        if is_cur(name) then
                            local units = to_units(name, qty)
                            local base = base_cur(name)
                            agg[base] = (agg[base] or 0) + units
                        end
                    end

                    for _, base in ipairs(keys(agg)) do
                        total_units = total_units + (agg[base] or 0)
                    end

                    if imgui.BeginTable('tbl_cur_summary', 2, TF_BORDER) then
                        imgui.TableSetupColumn('Currency')
                        imgui.TableSetupColumn('Total units')
                        imgui.TableHeadersRow()

                        for _, base in ipairs(keys(agg)) do
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(C.CUR, display_cur(base))
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.QTY, tostring(agg[base] or 0))
                        end

                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextColored(C.ITEM, 'Total')
                        imgui.TableSetColumnIndex(1)
                        imgui.TextColored(C.QTY, tostring(total_units))

                        imgui.EndTable()
                    end

                    imgui.Separator()
                end

                -- Original currency table (tbl_cur)
                imgui.BeginTable('tbl_cur', 4, TF_BORDER)
                imgui.TableSetupColumn('Currency')
                imgui.TableSetupColumn('Qty')
                imgui.TableSetupColumn('Total')
                imgui.TableSetupColumn('Lost')
                imgui.TableHeadersRow()

                local lost = {}
                for _, ln in ipairs(sess.drops.lost or {}) do
                    local it = lost_name(ln)
                    lost[it] = (lost[it] or 0) + 1
                end

                for _, cur in ipairs(keys(sess.drops.currency_total or {})) do
                    if is_cur(cur) then
                        local qty = sess.drops.currency_total[cur] or 0
                        local lst = lost[cur] or 0
                        local col = is_hundo(cur) and C.HUNDO or C.CUR

                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextColored(col, title(cur))
                        imgui.TableSetColumnIndex(1)
                        imgui.TextColored(C.QTY, tostring(qty))
                        imgui.TableSetColumnIndex(2)
                        imgui.TextColored(C.QTY, tostring(qty + lst))
                        imgui.TableSetColumnIndex(3)
                        if lst > 0 then
                            imgui.TextColored(C.LOST, tostring(lst))
                        end
                    end
                end

                imgui.EndTable()
                imgui.EndTabItem()
            end


            ---------------------------------------------------------------- PLAYERS
            -- ---------------------------------------------------------------- PLAYERS
            if imgui.BeginTabItem('Players') then
                local plist = keys(sess.drops.by_player or {})

                -- Toggle currency-only + combo
                do
                    local style = imgui.GetStyle()
                    local spacing = style.ItemInnerSpacing.x
                    local pad = style.FramePadding.x
                    local win_w = imgui.GetWindowWidth()

                    local v = { ui.players_currency_only == true }
                    if imgui.Checkbox('Currency only', v) then
                        ui.players_currency_only = v[1]
                    end

                    local preview = (ui.filter == 'All') and 'All players' or ui.filter

                    local lbl = 'Show player'
                    local lbl_w, _ = imgui.CalcTextSize(lbl)
                    local prev_w, _ = imgui.CalcTextSize(preview)

                    local combo_w = math.max(160, prev_w + pad * 6)
                    local total_w = lbl_w + spacing + combo_w

                    imgui.SameLine(0, spacing * 2)
                    imgui.SetCursorPosX(win_w - total_w - pad)

                    imgui.TextUnformatted(lbl)
                    imgui.SameLine()
                    imgui.PushItemWidth(combo_w)
                    if imgui.BeginCombo('##show_player', preview) then
                        if imgui.Selectable('All players', ui.filter == 'All') then
                            ui.filter = 'All'
                        end
                        if ui.filter == 'All' then
                            imgui.SetItemDefaultFocus()
                        end

                        for _, p in ipairs(plist) do
                            if imgui.Selectable(p, ui.filter == p) then
                                ui.filter = p
                            end
                            if ui.filter == p then
                                imgui.SetItemDefaultFocus()
                            end
                        end
                        imgui.EndCombo()
                    end
                    imgui.PopItemWidth()
                end

                imgui.Separator()

                local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)

                local function should_show_item(it)
                    if not ui.players_currency_only then
                        return true
                    end
                    return is_cur(it)
                end

                local function build_rows_for_player(pl)
                    local bag = sess.drops.by_player[pl] or {}
                    local rows = {}
                    for _, it in ipairs(keys(bag)) do
                        if should_show_item(it) then
                            local qty = tonumber(bag[it]) or 0
                            if qty > 0 then
                                rows[#rows + 1] = { item = it, qty = qty }
                            end
                        end
                    end
                    return rows
                end

                if ui.filter == 'All' then
                    local printed_any = false

                    for _, pl in ipairs(plist) do
                        local rows = build_rows_for_player(pl)
                        if #rows > 0 then
                            printed_any = true

                            if imgui.BeginTable('tbl_' .. pl, 3, TFLAGS) then
                                local stretch = imgui.TableColumnFlags_WidthStretch or 0
                                imgui.TableSetupColumn('Player', stretch)
                                imgui.TableSetupColumn('Item', stretch)
                                imgui.TableSetupColumn('Qty', stretch)
                                imgui.TableHeadersRow()

                                for _, r in ipairs(rows) do
                                    local col = is_cur(r.item) and (is_hundo(r.item) and C.HUNDO or C.CUR) or C.ITEM
                                    imgui.TableNextRow()
                                    imgui.TableSetColumnIndex(0)
                                    imgui.TextColored(C.NAME, pl)
                                    imgui.TableSetColumnIndex(1)
                                    imgui.TextColored(col, title(r.item))
                                    imgui.TableSetColumnIndex(2)
                                    imgui.TextColored(C.QTY, tostring(r.qty))
                                end

                                imgui.EndTable()
                            end

                            imgui.Separator()
                        end
                    end

                    if not printed_any then
                        imgui.TextDisabled('No items to show for any player.')
                    end
                else
                    local pl = ui.filter
                    local rows = build_rows_for_player(pl)

                    if #rows == 0 then
                        imgui.TextDisabled('No items to show for this player.')
                    else
                        if imgui.BeginTable('tbl_ply_single', 3, TFLAGS) then
                            imgui.TableSetupColumn('Player')
                            imgui.TableSetupColumn('Item')
                            imgui.TableSetupColumn('Qty')
                            imgui.TableHeadersRow()

                            for _, r in ipairs(rows) do
                                local col = is_cur(r.item) and (is_hundo(r.item) and C.HUNDO or C.CUR) or C.ITEM
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.NAME, pl)
                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(col, title(r.item))
                                imgui.TableSetColumnIndex(2)
                                imgui.TextColored(C.QTY, tostring(r.qty))
                            end

                            imgui.EndTable()
                        end
                    end
                end

                imgui.EndTabItem()
            end


            ---------------------------------------------------------------- ITEMS
            -- ---------------------------------------------------------------- ITEMS
            if imgui.BeginTabItem('Items') then
                local plist = keys(sess.drops.by_player or {})
                local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)

                local printed_any = false

                for _, pl in ipairs(plist) do
                    local bag = sess.drops.by_player[pl] or {}

                    local rows = {}
                    for _, it in ipairs(keys(bag)) do
                        if not is_cur(it) then
                            local qty = tonumber(bag[it]) or 0
                            if qty > 0 then
                                rows[#rows + 1] = { item = it, qty = qty }
                            end
                        end
                    end

                    if #rows > 0 then
                        printed_any = true

                        if imgui.BeginTable('tbl_items_' .. pl, 3, TFLAGS) then
                            imgui.TableSetupColumn('Player')
                            imgui.TableSetupColumn('Item')
                            imgui.TableSetupColumn('Qty')
                            imgui.TableHeadersRow()

                            for _, r in ipairs(rows) do
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.NAME, pl)
                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(C.ITEM, title(r.item))
                                imgui.TableSetColumnIndex(2)
                                imgui.TextColored(C.QTY, tostring(r.qty))
                            end

                            imgui.EndTable()
                        end

                        imgui.Separator()
                    end
                end

                if not printed_any then
                    imgui.TextDisabled('No equipment items recorded.')
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
                    sess.split = sess.split or {}
                    sess.management = sess.management or {}

                    local function ts_to_hm(ts)
                        local t = os.date('*t', ts or os.time())
                        return t.hour or 0, t.min or 0
                    end

                    local function hm_to_minutes(h, m)
                        h = tonumber(h) or 0
                        m = tonumber(m) or 0
                        if h < 0 then h = 0 end
                        if m < 0 then m = 0 end
                        return h * 60 + m
                    end

                    local function calc_duration(start_h, start_m, end_h, end_m)
                        local a = hm_to_minutes(start_h, start_m)
                        local b = hm_to_minutes(end_h, end_m)
                        local d = b - a
                        if d < 0 then
                            d = d + 24 * 60
                        end
                        return math.max(1, d)
                    end

                    local function combo_int(id, current, minv, maxv, fmt)
                        local label = fmt and string.format(fmt, current) or tostring(current)
                        if imgui.BeginCombo(id, label) then
                            for v = minv, maxv do
                                local sel = (v == current)
                                local vlabel = fmt and string.format(fmt, v) or tostring(v)
                                if imgui.Selectable(vlabel, sel) then
                                    current = v
                                end
                                if sel then
                                    imgui.SetItemDefaultFocus()
                                end
                            end
                            imgui.EndCombo()
                        end
                        return current
                    end

                    -- Defaults for Start/End
                    if sess.split.start_h == nil or sess.split.start_m == nil then
                        local sh, sm = ts_to_hm(sess.start_time or os.time())
                        sess.split.start_h, sess.split.start_m = sh, sm
                    end
                    if sess.split.end_h == nil or sess.split.end_m == nil then
                        local sh = tonumber(sess.split.start_h) or 0
                        local sm = tonumber(sess.split.start_m) or 0
                        local end_minutes = hm_to_minutes(sh, sm) + 240
                        end_minutes = end_minutes % (24 * 60)
                        sess.split.end_h = math.floor(end_minutes / 60)
                        sess.split.end_m = end_minutes - sess.split.end_h * 60
                    end

                    -- Start / End UI
                    do
                        local old_sh = tonumber(sess.split.start_h) or 0
                        local old_sm = tonumber(sess.split.start_m) or 0
                        local old_eh = tonumber(sess.split.end_h) or 0
                        local old_em = tonumber(sess.split.end_m) or 0
                        local old_dur = tonumber(sess.split.duration_minutes) or 0
                        local old_gp  = tonumber(sess.split.glass_price) or 1000000

                        imgui.TextUnformatted('Start')
                        imgui.SameLine()
                        imgui.PushItemWidth(55)
                        sess.split.start_h = combo_int('##st_h', old_sh, 0, 23, nil)
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.TextUnformatted('h')
                        imgui.SameLine()
                        imgui.PushItemWidth(55)
                        sess.split.start_m = combo_int('##st_m', old_sm, 0, 55, '%02d')
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.TextUnformatted('m')

                        imgui.SameLine()
                        imgui.TextUnformatted('   End')
                        imgui.SameLine()
                        imgui.PushItemWidth(55)
                        sess.split.end_h = combo_int('##en_h', old_eh, 0, 23, nil)
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.TextUnformatted('h')
                        imgui.SameLine()
                        imgui.PushItemWidth(55)
                        sess.split.end_m = combo_int('##en_m', old_em, 0, 55, '%02d')
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.TextUnformatted('m')

                        if sess.split.glass_price == nil then
                            sess.split.glass_price = 1000000
                        end

                        local glass_price = tonumber(sess.split.glass_price) or 1000000
                        if glass_price < 0 then glass_price = 0 end

                        local style2 = imgui.GetStyle()
                        local win_w2 = imgui.GetWindowWidth()
                        local pad2 = style2.FramePadding.x
                        local spacing2 = style2.ItemInnerSpacing.x

                        local lbl_gp = 'Glass'
                        local lbl_w, _ = imgui.CalcTextSize(lbl_gp)

                        local input_w = 110
                        local total_w = lbl_w + spacing2 + input_w

                        imgui.SameLine()
                        imgui.SetCursorPosX(win_w2 - total_w - pad2)

                        imgui.TextUnformatted(lbl_gp)
                        imgui.SameLine()
                        imgui.PushItemWidth(input_w)
                        local gp = { glass_price }
                        if imgui.InputInt('##glass_price', gp) then
                            local new_price = gp[1]
                            if new_price < 0 then new_price = 0 end
                            glass_price = new_price
                            sess.split.glass_price = glass_price
                        end
                        imgui.PopItemWidth()

                        local new_dur = calc_duration(
                                sess.split.start_h, sess.split.start_m,
                                sess.split.end_h, sess.split.end_m
                        )
                        local dur_num = tonumber(new_dur) or 1
                        sess.split.duration_minutes = dur_num

                        local sh = tonumber(sess.split.start_h) or 0
                        local sm = tonumber(sess.split.start_m) or 0
                        local eh = tonumber(sess.split.end_h) or 0
                        local em = tonumber(sess.split.end_m) or 0

                        sess.split.start_h, sess.split.start_m = sh, sm
                        sess.split.end_h, sess.split.end_m = eh, em

                        local changed =
                        (sh ~= old_sh) or (sm ~= old_sm) or
                                (eh ~= old_eh) or (em ~= old_em) or
                                (dur_num ~= old_dur) or
                                (glass_price ~= old_gp)

                        if changed then
                            if store and sess and sess.is_event then
                                store.save(sess)
                            end
                        end

                        imgui.Separator()
                        imgui.TextUnformatted('Duration: ' .. tostring(dur_num) .. ' mins')
                        imgui.Separator()
                    end



                    -- Build player list
                    local names_set = {}
                    if sess.drops and sess.drops.by_player then
                        for name, _ in pairs(sess.drops.by_player) do
                            names_set[name] = true
                        end
                    end
                    if sess.management then
                        for name, _ in pairs(sess.management) do
                            names_set[name] = true
                        end
                    end
                    if sess.participants then
                        for name, _ in pairs(sess.participants) do
                            names_set[name] = true
                        end
                    end

                    local plist = {}
                    for name, _ in pairs(names_set) do
                        plist[#plist + 1] = name
                    end
                    table.sort(plist)

                    local duration = tonumber(sess.split.duration_minutes) or 1

                    -- Button: set all included players to full duration
                    if imgui.SmallButton('Set all time = full') then
                        for _, pl in ipairs(plist) do
                            local m = sess.management[pl]
                            if m then
                                if m.include ~= false then
                                    m.minutes = duration
                                end
                            end
                        end
                        if store and sess and sess.is_event then
                            store.save(sess)
                        end
                    end

                    imgui.Separator()

                    -- Management table (Include + Time + Paid/Delivered)
                    local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                    if imgui.BeginTable('tbl_manage', 5, TFLAGS) then
                        imgui.TableSetupColumn('Name')
                        imgui.TableSetupColumn('Include')
                        imgui.TableSetupColumn('Time')
                        imgui.TableSetupColumn('Glass paid')
                        imgui.TableSetupColumn('Currency delivered')
                        imgui.TableHeadersRow()

                        for _, pl in ipairs(plist) do
                            local m = sess.management[pl]
                            if m == nil then
                                sess.management[pl] = {
                                    include = true,
                                    minutes = duration,
                                    glass_paid = false,
                                    currency_delivered = false,
                                }
                                m = sess.management[pl]
                                if store and sess and sess.is_event then
                                    store.save(sess)
                                end
                            end

                            if type(m.minutes) ~= 'number' then
                                m.minutes = duration
                            end
                            if m.minutes < 0 then
                                m.minutes = 0
                            end
                            if m.include == nil then
                                m.include = true
                            end

                            imgui.TableNextRow()

                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(C.NAME, pl)

                            imgui.TableSetColumnIndex(1)
                            do
                                local val = { m.include == true }
                                if imgui.Checkbox('##inc_' .. pl, val) then
                                    m.include = val[1]
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end

                            imgui.TableSetColumnIndex(2)
                            do
                                local h = math.floor(m.minutes / 60)
                                local mi = m.minutes - h * 60

                                imgui.PushItemWidth(50)
                                local new_h = combo_int('##mh_' .. pl, h, 0, 12, nil)
                                imgui.PopItemWidth()

                                imgui.SameLine()
                                imgui.TextUnformatted('h')
                                imgui.SameLine()

                                imgui.PushItemWidth(50)
                                local new_m = combo_int('##mm_' .. pl, mi, 0, 55, '%02d')
                                imgui.PopItemWidth()

                                if new_h ~= h or new_m ~= mi then
                                    m.minutes = new_h * 60 + new_m
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end

                            imgui.TableSetColumnIndex(3)
                            do
                                local val = { m.glass_paid == true }
                                if imgui.Checkbox('##gp_' .. pl, val) then
                                    m.glass_paid = val[1]
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end

                            imgui.TableSetColumnIndex(4)
                            do
                                local val = { m.currency_delivered == true }
                                if imgui.Checkbox('##cd_' .. pl, val) then
                                    m.currency_delivered = val[1]
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                            end
                        end

                        imgui.EndTable()
                    end

                    imgui.Separator()

                    -- Compute split (time-weighted, only included players)
                    local glass_price = tonumber(sess.split and sess.split.glass_price) or 1000000
                    if glass_price < 0 then glass_price = 0 end
                    local agg = {}
                    for name, qty in pairs(sess.drops.currency_total or {}) do
                        if is_cur(name) then
                            local units = to_units(name, qty)
                            local base = base_cur(name)
                            agg[base] = (agg[base] or 0) + units
                        end
                    end
                    local bases = keys(agg)

                    local total_weight = 0
                    for _, pl in ipairs(plist) do
                        local m = sess.management[pl]
                        if m and m.include ~= false then
                            total_weight = total_weight + (m.minutes or 0)
                        end
                    end

                    if total_weight <= 0 then
                        imgui.TextDisabled('No included time set.')
                    else
                        local used = {}
                        for _, base in ipairs(bases) do
                            used[base] = 0
                        end
                        local used_glass = 0

                        local per_player = {}
                        for _, pl in ipairs(plist) do
                            local m = sess.management[pl] or {}
                            local mins = (m.include ~= false) and (m.minutes or 0) or 0
                            local share = {}

                            for _, base in ipairs(bases) do
                                local units = agg[base] or 0
                                local v = math.floor((units * mins) / total_weight)
                                share[base] = v
                                used[base] = (used[base] or 0) + v
                            end

                            local glass = math.floor((glass_price * mins) / total_weight)
                            used_glass = used_glass + glass

                            per_player[pl] = { mins = mins, share = share, glass = glass }
                        end

                        imgui.TextUnformatted('Split')
                        local cols = 2 + #bases + 1
                        if imgui.BeginTable('tbl_time_split', cols, TF_BORDER) then
                            imgui.TableSetupColumn('Player')
                            imgui.TableSetupColumn('Mins')
                            for _, base in ipairs(bases) do
                                imgui.TableSetupColumn(display_cur(base))
                            end
                            imgui.TableSetupColumn('Glass (gil)')
                            imgui.TableHeadersRow()

                            for _, pl in ipairs(plist) do
                                local row = per_player[pl]
                                imgui.TableNextRow()

                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.NAME, pl)

                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(C.QTY, tostring(row.mins))

                                local col = 2
                                for _, base in ipairs(bases) do
                                    imgui.TableSetColumnIndex(col)
                                    imgui.TextColored(C.QTY, tostring(row.share[base] or 0))
                                    col = col + 1
                                end

                                imgui.TableSetColumnIndex(col)
                                imgui.TextColored(C.QTY, fmt_n(row.glass))
                            end

                            imgui.EndTable()
                        end

                        imgui.Separator()
                        imgui.TextUnformatted('Remainder')

                        if imgui.BeginTable('tbl_remainder', 2, TF_BORDER) then
                            imgui.TableSetupColumn('Item')
                            imgui.TableSetupColumn('Units')
                            imgui.TableHeadersRow()

                            for _, base in ipairs(bases) do
                                local rem = (agg[base] or 0) - (used[base] or 0)
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.CUR, display_cur(base))
                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(rem > 0 and C.LOST or C.QTY, tostring(rem))
                            end

                            local rem_glass = glass_price - used_glass
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(C.ITEM, 'Timeless Hourglass')
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(rem_glass > 0 and C.LOST or C.QTY, fmt_n(rem_glass))

                            imgui.EndTable()
                        end
                    end -- <-- THIS end closes: else (total_weight > 0)
                end -- <-- closes: if not (sess and sess.is_event) then ... else ...

                imgui.EndTabItem()
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