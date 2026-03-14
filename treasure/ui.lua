---------------------------------------------------------------------------
-- Treasure · ui.lua · Waky
---------------------------------------------------------------------------
local imgui = require('imgui')
local ImGuiCol = imgui.Col
local FFI_OK, ffi = pcall(require, 'ffi')
local D3D8_OK, d3d8 = pcall(require, 'd3d8')
local D3D8_DEVICE = (D3D8_OK and d3d8 and d3d8.get_device) and d3d8.get_device() or nil

local COL_BUTTON = (ImGuiCol and ImGuiCol.Button)
        or rawget(imgui, 'Col_Button')
        or rawget(_G, 'ImGuiCol_Button')
local COL_BUTTON_HOVERED = (ImGuiCol and ImGuiCol.ButtonHovered)
        or rawget(imgui, 'Col_ButtonHovered')
        or rawget(_G, 'ImGuiCol_ButtonHovered')
local COL_BUTTON_ACTIVE = (ImGuiCol and ImGuiCol.ButtonActive)
        or rawget(imgui, 'Col_ButtonActive')
        or rawget(_G, 'ImGuiCol_ButtonActive')
local COL_BORDER = (ImGuiCol and ImGuiCol.Border)
        or rawget(imgui, 'Col_Border')
        or rawget(_G, 'ImGuiCol_Border')
local COL_TEXT = (ImGuiCol and ImGuiCol.Text)
        or rawget(imgui, 'Col_Text')
        or rawget(_G, 'ImGuiCol_Text')
local COL_WINDOW_BG = (ImGuiCol and ImGuiCol.WindowBg)
        or rawget(imgui, 'Col_WindowBg')
        or rawget(_G, 'ImGuiCol_WindowBg')
local COL_CHILD_BG = (ImGuiCol and ImGuiCol.ChildBg)
        or rawget(imgui, 'Col_ChildBg')
        or rawget(_G, 'ImGuiCol_ChildBg')
local COL_FRAME_BG = (ImGuiCol and ImGuiCol.FrameBg)
        or rawget(imgui, 'Col_FrameBg')
        or rawget(_G, 'ImGuiCol_FrameBg')
local COL_FRAME_BG_HOVERED = (ImGuiCol and ImGuiCol.FrameBgHovered)
        or rawget(imgui, 'Col_FrameBgHovered')
        or rawget(_G, 'ImGuiCol_FrameBgHovered')
local COL_FRAME_BG_ACTIVE = (ImGuiCol and ImGuiCol.FrameBgActive)
        or rawget(imgui, 'Col_FrameBgActive')
        or rawget(_G, 'ImGuiCol_FrameBgActive')
local COL_TAB = (ImGuiCol and ImGuiCol.Tab)
        or rawget(imgui, 'Col_Tab')
        or rawget(_G, 'ImGuiCol_Tab')
local COL_TAB_HOVERED = (ImGuiCol and ImGuiCol.TabHovered)
        or rawget(imgui, 'Col_TabHovered')
        or rawget(_G, 'ImGuiCol_TabHovered')
local COL_TAB_ACTIVE = (ImGuiCol and ImGuiCol.TabActive)
        or rawget(imgui, 'Col_TabActive')
        or rawget(_G, 'ImGuiCol_TabActive')
local COL_TAB_UNFOCUSED = (ImGuiCol and ImGuiCol.TabUnfocused)
        or rawget(imgui, 'Col_TabUnfocused')
        or rawget(_G, 'ImGuiCol_TabUnfocused')
local COL_TAB_UNFOCUSED_ACTIVE = (ImGuiCol and ImGuiCol.TabUnfocusedActive)
        or rawget(imgui, 'Col_TabUnfocusedActive')
        or rawget(_G, 'ImGuiCol_TabUnfocusedActive')
local COL_SEPARATOR = (ImGuiCol and ImGuiCol.Separator)
        or rawget(imgui, 'Col_Separator')
        or rawget(_G, 'ImGuiCol_Separator')
local COL_PLOT_HISTOGRAM = (ImGuiCol and ImGuiCol.PlotHistogram)
        or rawget(imgui, 'Col_PlotHistogram')
        or rawget(_G, 'ImGuiCol_PlotHistogram')
local COL_PLOT_HISTOGRAM_HOVERED = (ImGuiCol and ImGuiCol.PlotHistogramHovered)
        or rawget(imgui, 'Col_PlotHistogramHovered')
        or rawget(_G, 'ImGuiCol_PlotHistogramHovered')

local SV_FRAME_ROUNDING = rawget(_G, 'ImGuiStyleVar_FrameRounding')
        or rawget(imgui, 'ImGuiStyleVar_FrameRounding')
        or rawget(imgui, 'StyleVar_FrameRounding')
        or (imgui.StyleVar and imgui.StyleVar.FrameRounding)
        or 11
local SV_FRAME_BORDER_SIZE = rawget(_G, 'ImGuiStyleVar_FrameBorderSize')
        or rawget(imgui, 'ImGuiStyleVar_FrameBorderSize')
        or rawget(imgui, 'StyleVar_FrameBorderSize')
        or (imgui.StyleVar and imgui.StyleVar.FrameBorderSize)
        or 12
local SV_CHILD_ROUNDING = rawget(_G, 'ImGuiStyleVar_ChildRounding')
        or rawget(imgui, 'ImGuiStyleVar_ChildRounding')
        or rawget(imgui, 'StyleVar_ChildRounding')
        or (imgui.StyleVar and imgui.StyleVar.ChildRounding)
        or 14
local SV_TAB_ROUNDING = rawget(_G, 'ImGuiStyleVar_TabRounding')
        or rawget(imgui, 'ImGuiStyleVar_TabRounding')
        or rawget(imgui, 'StyleVar_TabRounding')
        or (imgui.StyleVar and imgui.StyleVar.TabRounding)

local GATE_ICONS = {
    loaded = false,
    gate_open = nil,
    gate_closed = nil,
    vortex = nil,
    vortex_open = nil,
    vortex_closed = nil,
    transition = nil,
    ultima = nil,
    status_ok = nil,
    status_x = nil,
    chips = {},
    elementals = {},
    jobs = {},
    equip = {},
}
local ICON_TINT_WHITE = { 1.0, 1.0, 1.0, 1.0 }

-- libs ----------------------------------------------------------
local SETTINGS_OK, settings = pcall(require, 'settings')   -- settings.lua
local THEMES_OK, ADDON_THEMES = pcall(require, 'ev_themes')  -- palette file
local store = require('store')
local timeutil = require('timeutil')
local event_router = require('ui_event_router')
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
    if cfg then
        if cfg._config_file then
            pcall(_save_config_file, cfg)
        end
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

local DEFAULT_TRE_COLS = {
    compact = { 136.59790039063, 62.51375579834, 43.9694480896, 38.918895721436 },
    full = { 300, 200, 60, 60 },
}

local function copy_cols(src)
    return { src[1], src[2], src[3], src[4] }
end

local function sanitize_tre_cols(cols, mode)
    local fallback = copy_cols(DEFAULT_TRE_COLS[mode] or DEFAULT_TRE_COLS.full)
    if type(cols) ~= 'table' then
        return fallback
    end

    local out = {}
    for i = 1, 4 do
        local v = tonumber(cols[i])
        if v == nil then
            v = fallback[i]
        end
        out[i] = v
    end

    return out
end

-- Guarda posición, tamaño y anchos de columnas --------------------
local function save_layout(cfg, mode, win_snapshot)
    cfg.layout = cfg.layout or {}
    cfg.layout[mode] = cfg.layout[mode] or {}

    -- posición y tamaño
    local px, py, wx, wy
    if type(win_snapshot) == 'table' then
        px = win_snapshot.x
        py = win_snapshot.y
        wx = win_snapshot.w
        wy = win_snapshot.h
    else
        px, py = imgui.GetWindowPos()                  -- devuelve 2 números
        if type(px) ~= 'number' then
            -- fallback
            px, py = _get_xy(px)
        end
        wx, wy = imgui.GetWindowSize()
        if type(wx) ~= 'number' then
            wx, wy = _get_xy(wx)
        end
    end
    px = tonumber(px) or 0
    py = tonumber(py) or 0
    wx = tonumber(wx) or 0
    wy = tonumber(wy) or 0
    if mode == 'full' then
        -- Protect full profile from accidental tiny saves (eg. transient UI frame).
        wx = math.max(520, wx)
        wy = math.max(320, wy)
    else
        wx = math.max(220, wx)
        wy = math.max(120, wy)
    end
    cfg.layout[mode].window = { x = px, y = py, w = wx, h = wy }

    -- Guard against cross-mode overwrites when toggling.
    if cfg.tre_col_w and cfg._tre_cols_mode == mode then
        cfg.layout[mode].cols = sanitize_tre_cols(cfg.tre_col_w, mode)
    end

    persist(cfg) -- << escribe settings.xml
end

local function load_layout(cfg, mode)
    local prof = cfg.layout and cfg.layout[mode]
    if not prof then
        cfg.tre_col_w = sanitize_tre_cols(nil, mode)
        cfg._tre_init = false
        cfg._tre_cols_mode = mode
        return
    end

    if prof.window then
        local repaired = false
        local x = tonumber(prof.window.x)
        local y = tonumber(prof.window.y)
        local w = tonumber(prof.window.w)
        local h = tonumber(prof.window.h)
        if mode == 'full' then
            if w and w < 520 then
                w = 520
                repaired = true
            end
            if h and h < 320 then
                h = 320
                repaired = true
            end
        else
            if w and w < 220 then
                w = 220
                repaired = true
            end
            if h and h < 120 then
                h = 120
                repaired = true
            end
        end
        if repaired then
            prof.window.w = w
            prof.window.h = h
            persist(cfg)
        end
        if x and y then
            imgui.SetNextWindowPos({ x, y })
        end
        if w and h and w > 64 and h > 64 then
            imgui.SetNextWindowSize({ w, h })
        end
    end
    cfg.tre_col_w = sanitize_tre_cols(prof.cols, mode)
    cfg._tre_init = false
    cfg._tre_cols_mode = mode
end


--------------------------------------------------------------------
-- Helpers to fetch ImGui / Ashita constants
--------------------------------------------------------------------
local function WF(name)
    local gkey = 'ImGuiWindowFlags_' .. tostring(name)
    if rawget(_G, gkey) then
        return rawget(_G, gkey)
    end
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

local DEFAULT_COLORS_DYNAMIS = {
    NAME = { 0.55, 0.78, 1.00, 1 },
    ITEM = { 0, 1, 0.9961, 1 },
    CUR = { 0.1725, 1, 0.0431, 1 },
    HUNDO = { 1, 0.84, 0, 1 },
    QTY = { 1, 1, 1, 1 },
    LOST = { 1, 0.35, 0.35, 1 },
}

local DEFAULT_COLORS_LIMBUS = {
    NAME = { 0.55, 0.78, 1.00, 1 },
    ITEM = { 0, 1, 0.9961, 1 },
    CUR = { 1.0, 0.839215686, 0.0, 1.0 }, -- #FFD600
    HUNDO = { 1, 0.84, 0, 1 },
    QTY = { 1, 1, 1, 1 },
    LOST = { 1, 0.35, 0.35, 1 },
}

-- Legacy/default alias used by shared helpers (defaults to Dynamis).
local DEFAULT_COLORS = DEFAULT_COLORS_DYNAMIS

local DEFAULT_CHIP_COLORS = {
    magenta = { 0.5255, 0.3373, 0.8471, 1.0 },   -- #8656D8
    smoky = { 0.4431, 0.5098, 0.5922, 1.0 },     -- #718297
    emerald = { 0.2118, 0.5608, 0.4510, 1.0 },   -- #368F73
    scarlet = { 0.5961, 0.3255, 0.1373, 1.0 },   -- #985323
    ivory = { 0.6549, 0.5216, 0.0235, 1.0 },     -- #A78506
    charcoal = { 0.4392, 0.5059, 0.5882, 1.0 },  -- #708196
    smalt = { 0.1294, 0.4980, 0.7176, 1.0 },     -- #217FB7
    orchid = { 0.5373, 0.3412, 0.8627, 1.0 },    -- #8957DC
    cerulean = { 0.1333, 0.5216, 0.7490, 1.0 },  -- #2285BF
    silver = { 0.4745, 0.5373, 0.6196, 1.0 },    -- #79899E
    metal = { 0.62, 0.66, 0.72, 1.0 },
    niveous = { 0.93, 0.96, 1.00, 1.0 },
    crepuscular = { 0.60, 0.54, 0.68, 1.0 },
}

local DEFAULT_LIMBUS_HP_BAR_COLORS = {
    -- High HP base (darker rose).
    high = { 0.88, 0.47, 0.53, 0.96 },
    -- Low HP base (deep red).
    low = { 0.62, 0.12, 0.16, 0.96 },
}

local DEFAULT_LIMBUS_ICON_ANIM = {
    transition_pulse = true,
    vortex_open_spin = true,
    vortex_open_pulse = true,
    vortex_open_spin_speed = 1.8,
}

local CHIP_COLOR_KEYS = {
    'magenta', 'smoky', 'emerald', 'scarlet', 'ivory',
    'charcoal', 'smalt', 'orchid', 'cerulean', 'silver',
    'metal', 'niveous', 'crepuscular',
}

local CHIP_COLOR_LABELS = {
    magenta = 'Magenta Chip',
    smoky = 'Smoky Chip',
    emerald = 'Emerald Chip',
    scarlet = 'Scarlet Chip',
    ivory = 'Ivory Chip',
    charcoal = 'Charcoal Chip',
    smalt = 'Smalt Chip',
    orchid = 'Orchid Chip',
    cerulean = 'Cerulean Chip',
    silver = 'Silver Chip',
    metal = 'Metal Chip',
    niveous = 'Niveous Chip',
    crepuscular = 'Crepuscular Chip',
}

local DEFAULT_EVENT_ACCENT_DYNAMIS = { 1.00, 0.62, 0.26, 0.90 } -- #FF9E42
local DEFAULT_EVENT_ACCENT_LIMBUS = { 0.18, 0.77, 0.71, 0.90 }  -- #2EC4B5

local DEFAULT_VISUAL_COLORS = {
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
}

local DEFAULT_BUTTON_STYLE = {
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
}

local function copy_rgba(src)
    return { src[1], src[2], src[3], src[4] }
end

local CUR_FIX_WRONG = { 1.0, 0.84, 0.0, 1.0 }
local CUR_FIX_DYNAMIS = { 0.1725, 1.0, 0.0431, 1.0 }

local function rgba_equals(a, b, eps)
    eps = eps or 0.0005
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end
    return math.abs((tonumber(a[1]) or 0) - (tonumber(b[1]) or 0)) <= eps
            and math.abs((tonumber(a[2]) or 0) - (tonumber(b[2]) or 0)) <= eps
            and math.abs((tonumber(a[3]) or 0) - (tonumber(b[3]) or 0)) <= eps
            and math.abs((tonumber(a[4]) or 0) - (tonumber(b[4]) or 0)) <= eps
end

local function sanitize_rgba(src, fallback)
    local out = {}
    for i = 1, 4 do
        local v = tonumber(src and src[i])
        if v == nil then
            v = fallback[i]
        end
        if v < 0 then
            v = 0
        elseif v > 1 then
            v = 1
        end
        out[i] = v
    end
    return out
end

local function sanitize_color_map(src, fallback)
    local out = {}
    for k, v in pairs(fallback) do
        out[k] = sanitize_rgba(src and src[k], v)
    end
    return out
end

local function event_loot_colors(cfg, event_id)
    local id = tostring(event_id or ''):lower()
    if id == 'limbus' then
        return (cfg and cfg.colors_limbus) or (cfg and cfg.colors) or DEFAULT_COLORS_LIMBUS
    end
    return (cfg and cfg.colors_dynamis) or (cfg and cfg.colors) or DEFAULT_COLORS_DYNAMIS
end

local function selected_border_for_event(bs, event_id)
    local style = bs or DEFAULT_BUTTON_STYLE
    local id = tostring(event_id or ''):lower()
    local src = nil
    if id == 'limbus' then
        src = style.selected_border_limbus
                or style.selected_border
                or DEFAULT_BUTTON_STYLE.selected_border_limbus
    else
        src = style.selected_border_dynamis
                or style.selected_border
                or DEFAULT_BUTTON_STYLE.selected_border_dynamis
    end
    return copy_rgba(src or DEFAULT_BUTTON_STYLE.selected_border)
end

local function tint_rgba(src, mul, add_alpha)
    local out = {}
    for i = 1, 4 do
        local v = tonumber(src and src[i]) or 0
        if i <= 3 then
            v = v * (mul or 1)
        elseif add_alpha then
            v = v + add_alpha
        end
        if v < 0 then
            v = 0
        elseif v > 1 then
            v = 1
        end
        out[i] = v
    end
    return out
end

local function mix_rgba(a, b, t)
    local ta = 1.0 - (tonumber(t) or 0.5)
    local tb = tonumber(t) or 0.5
    local out = {}
    for i = 1, 4 do
        local va = tonumber(a and a[i]) or 0
        local vb = tonumber(b and b[i]) or 0
        local v = (va * ta) + (vb * tb)
        if v < 0 then
            v = 0
        elseif v > 1 then
            v = 1
        end
        out[i] = v
    end
    return out
end

local function hp_fill_rgba(frac, cfg)
    local f = tonumber(frac) or 0
    if f < 0 then
        f = 0
    elseif f > 1 then
        f = 1
    end
    local hp_cfg = cfg and cfg.limbus_hp_bar_colors
    local high = sanitize_rgba(hp_cfg and hp_cfg.high, DEFAULT_LIMBUS_HP_BAR_COLORS.high)
    local low = sanitize_rgba(hp_cfg and hp_cfg.low, DEFAULT_LIMBUS_HP_BAR_COLORS.low)
    return {
        low[1] + ((high[1] - low[1]) * f),
        low[2] + ((high[2] - low[2]) * f),
        low[3] + ((high[3] - low[3]) * f),
        low[4] + ((high[4] - low[4]) * f),
    }
end

local function draw_styled_hp_progress(frac, size, text_col, cfg)
    local f = tonumber(frac) or 0
    if f < 0 then
        f = 0
    elseif f > 1 then
        f = 1
    end

    local w = tonumber(size and size[1]) or 120
    local h = tonumber(size and size[2]) or 14
    if w < 16 then
        w = 16
    end
    if h < 8 then
        h = 8
    end

    local sx, sy = imgui.GetCursorPos()
    if type(sx) ~= 'number' then
        sx, sy = _get_xy(sx)
    end
    sx = tonumber(sx) or 0
    sy = tonumber(sy) or 0

    local pushed_colors = 0
    local pushed_vars = 0

    local fill = hp_fill_rgba(f, cfg)
    local bg = { 0.10, 0.12, 0.15, 0.92 }
    local hov = tint_rgba(fill, 1.06, 0.00)
    local border = mix_rgba(fill, bg, 0.35)
    border[4] = 0.95

    if COL_FRAME_BG ~= nil then
        imgui.PushStyleColor(COL_FRAME_BG, bg)
        pushed_colors = pushed_colors + 1
    end
    if COL_PLOT_HISTOGRAM ~= nil then
        imgui.PushStyleColor(COL_PLOT_HISTOGRAM, fill)
        pushed_colors = pushed_colors + 1
    end
    if COL_PLOT_HISTOGRAM_HOVERED ~= nil then
        imgui.PushStyleColor(COL_PLOT_HISTOGRAM_HOVERED, hov)
        pushed_colors = pushed_colors + 1
    end
    if COL_BORDER ~= nil then
        imgui.PushStyleColor(COL_BORDER, border)
        pushed_colors = pushed_colors + 1
    end
    if COL_TEXT ~= nil then
        -- Hide built-in progress text; we'll draw centered text ourselves.
        imgui.PushStyleColor(COL_TEXT, { 0, 0, 0, 0 })
        pushed_colors = pushed_colors + 1
    end
    if SV_FRAME_ROUNDING ~= nil then
        imgui.PushStyleVar(SV_FRAME_ROUNDING, math.max(4.0, h * 0.5))
        pushed_vars = pushed_vars + 1
    end
    if SV_FRAME_BORDER_SIZE ~= nil then
        imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, 1.15)
        pushed_vars = pushed_vars + 1
    end

    local ok_hide = pcall(imgui.ProgressBar, f, { w, h }, '')
    if not ok_hide then
        imgui.ProgressBar(f, { w, h })
    end

    local ex, ey = imgui.GetCursorPos()
    if type(ex) ~= 'number' then
        ex, ey = _get_xy(ex)
    end
    ex = tonumber(ex) or (sx + w)
    ey = tonumber(ey) or sy

    if pushed_vars > 0 then
        imgui.PopStyleVar(pushed_vars)
    end
    if pushed_colors > 0 then
        imgui.PopStyleColor(pushed_colors)
    end

    local pct = string.format('%d%%', math.floor((f * 100) + 0.5))
    local pct_text = pct:gsub('%%', '%%%%')
    local tw, th = imgui.CalcTextSize(pct)
    if type(tw) ~= 'number' then
        tw, th = _get_xy(tw)
    end
    tw = tonumber(tw) or 0
    th = tonumber(th) or (tonumber(imgui.GetTextLineHeight()) or h)
    local tx = sx + math.max(0, (w - tw) * 0.5)
    local ty = sy + math.max(0, (h - th) * 0.5)
    imgui.SetCursorPosX(tx)
    imgui.SetCursorPosY(ty)
    imgui.TextColored(text_col or { 0.92, 0.95, 1.00, 1.00 }, pct_text)
    imgui.SetCursorPosX(ex)
    imgui.SetCursorPosY(ey)
end

local function theme_col_rgba(theme_tbl, col_id, fallback)
    local src = theme_tbl and col_id and theme_tbl[col_id]
    if type(src) ~= 'table' then
        return copy_rgba(fallback)
    end
    return sanitize_rgba(src, fallback)
end

local function apply_theme_visual_preset(cfg, theme_name)
    if not (THEMES_OK and cfg) then
        return false
    end
    local th = ADDON_THEMES[theme_name] or ADDON_THEMES.Default
    if type(th) ~= 'table' then
        return false
    end

    cfg.visual_colors = cfg.visual_colors or {}
    local V = cfg.visual_colors

    local win = theme_col_rgba(th, COL_WINDOW_BG, DEFAULT_VISUAL_COLORS.WINDOW_BG)
    local frame = theme_col_rgba(th, COL_FRAME_BG, DEFAULT_VISUAL_COLORS.CONTROL_BG)
    local frame_h = theme_col_rgba(th, COL_FRAME_BG_HOVERED, DEFAULT_VISUAL_COLORS.CONTROL_BG_HOVERED)
    local frame_a = theme_col_rgba(th, COL_FRAME_BG_ACTIVE, DEFAULT_VISUAL_COLORS.CONTROL_BG_ACTIVE)
    local text = theme_col_rgba(th, COL_TEXT, DEFAULT_VISUAL_COLORS.HUD_TEXT)
    local border = theme_col_rgba(th, COL_BORDER, mix_rgba(frame_h, text, 0.18))
    local sep = theme_col_rgba(th, COL_SEPARATOR, mix_rgba(frame, border, 0.55))

    V.HUD_TEXT = text
    V.WINDOW_BG = win
    V.CONTENT_BG = mix_rgba(win, frame, 0.58)
    V.HEADER_BG = mix_rgba(win, frame, 0.34)
    V.HEADER_BORDER = mix_rgba(border, sep, 0.35)
    V.HEADER_TEXT = text
    V.CONTROL_BG = frame
    V.CONTROL_BG_HOVERED = frame_h
    V.CONTROL_BG_ACTIVE = frame_a
    V.TAB_BG = mix_rgba(frame, win, 0.38)
    V.TAB_BG_HOVERED = mix_rgba(frame_h, win, 0.28)
    V.TAB_BG_ACTIVE = mix_rgba(frame_a, win, 0.18)
    V.TAB_BG_UNFOCUSED = mix_rgba(win, frame, 0.14)
    V.TAB_BG_UNFOCUSED_ACTIVE = mix_rgba(frame, frame_h, 0.32)
    V.SEPARATOR = sep
    V.EVENT_DYNAMIS = mix_rgba(DEFAULT_EVENT_ACCENT_DYNAMIS, frame_h, 0.28)
    V.EVENT_LIMBUS = mix_rgba(DEFAULT_EVENT_ACCENT_LIMBUS, frame_a, 0.28)

    cfg.button_style = cfg.button_style or {}
    local B = cfg.button_style
    B.selected_bg = mix_rgba(frame_h, frame_a, 0.34)
    B.selected_border = mix_rgba(border, sep, 0.30)
    B.selected_text = text
    B.idle_bg = tint_rgba(frame, 0.86, 0.00)
    B.idle_border = mix_rgba(border, sep, 0.50)
    B.idle_text = mix_rgba(text, { 0.78, 0.80, 0.84, 1.0 }, 0.22)

    return true
end

local function clamp_num(v, min_v, max_v, fallback)
    local n = tonumber(v)
    if n == nil then
        n = tonumber(fallback) or min_v
    end
    if n < min_v then
        n = min_v
    elseif n > max_v then
        n = max_v
    end
    return n
end

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
local function is_valid_player_name(name)
    if not name or name == '' then
        return false
    end
    local s = norm(name)
    if s == '' then
        return false
    end
    if s == 'to' then
        return false
    end
    return true
end
local function lost_name(l)
    if type(l) == 'table' then
        return (l.item or ''):gsub('%s+$', '')
    end

    local s = tostring(l or '')
    local it = s:match('%d%d:%d%d:%d%d%s+(.+)%s+lost%.?')
            or s:match('^(.+)%s+lost%.?$')
            or s:match('^(.+)%s+is%s+lost%.?$')
    return (it or s):gsub('%s+$', '')
end

local function is_ancient_beastcoin_name(name)
    local s = norm(name or '')
    if s == '' then
        return false
    end
    return (s == 'ancient beastcoin')
            or (s == 'anc. beastcoin')
            or (s == 'anc beastcoin')
            or (s == 'anct. beastcoin')
            or (s == 'anct beastcoin')
end

local function is_cur(name)
    local s = norm(name or '')
    return (s:find('bronzepiece') ~= nil)
            or (s:find('whiteshell') ~= nil)
            or (s:find('byne bill') ~= nil)
            or (s:find('silverpiece') ~= nil)
            or (s:find('jadeshell') ~= nil)
            or is_ancient_beastcoin_name(name)
end

local function is_dynamis_currency_name(name)
    local s = norm(name or '')
    return (s:find('bronzepiece') ~= nil)
            or (s:find('whiteshell') ~= nil)
            or (s:find('byne bill') ~= nil)
            or (s:find('silverpiece') ~= nil)
            or (s:find('jadeshell') ~= nil)
end

local function is_limbus_currency_name(name)
    return is_ancient_beastcoin_name(name)
end

local function is_event_currency_name(name, event_id)
    local ev = norm(event_id or '')
    if ev == 'limbus' then
        return is_limbus_currency_name(name)
    end
    if ev == 'dynamis' then
        return is_dynamis_currency_name(name)
    end
    return is_cur(name)
end

local CHIP_MATCH_ORDER = {
    'magenta', 'smoky', 'smokey', 'emerald', 'scarlet', 'ivory',
    'charcoal', 'smalt', 'orchid', 'cerulean', 'silver',
    'metal', 'niveous', 'crepuscular',
}

local ELEMENT_LABELS = {
    fire = 'Fire',
    ice = 'Ice',
    wind = 'Wind',
    earth = 'Earth',
    thunder = 'Thunder',
    water = 'Water',
    light = 'Light',
    dark = 'Dark',
}

-- Limbus: tooltip data for pool_live item names (jobs / usage).
-- Only shown when current session is Limbus.
local LIMBUS_CHIP_HINT_BY_ID = {
    [1692] = 'Access item.',
    [1693] = 'Access item.',
    [1694] = 'Access item.',
    [1904] = 'Used to enter Central Temenos - 3rd Floor.',
    [1905] = 'Used to enter Central Temenos - 2nd Floor.',
    [1906] = 'Used to enter Central Temenos - 1st Floor.',
    [1907] = 'Used for Proto-Ultima fight.',
    [1908] = 'Used for Proto-Ultima fight.',
    [1909] = 'Used for Proto-Omega fight.',
    [1910] = 'Used for Proto-Omega fight.',
    [1986] = 'Used for Proto-Ultima fight.',
    [1987] = 'Used for Proto-Omega fight.',
    [1988] = 'Used for Proto-Omega fight.',
    [2127] = 'Access item.',
    [3854] = 'Access item.',
    [3855] = 'Access item.',
}

local LIMBUS_CHIP_HINT_BY_KEY = {
    ['magenta chip'] = 'Used for Proto-Omega fight.',
    ['smoky chip'] = 'Used for Proto-Omega fight.',
    ['smokey chip'] = 'Used for Proto-Omega fight.',
    ['charcoal chip'] = 'Used for Proto-Omega fight.',
    ['smalt chip'] = 'Used for Proto-Omega fight.',
    ['silver chip'] = 'Used for Proto-Ultima fight.',
    ['orchid chip'] = 'Used for Proto-Ultima fight.',
    ['cerulean chip'] = 'Used for Proto-Ultima fight.',
    ['emerald chip'] = 'Used to enter Central Temenos - 1st Floor.',
    ['scarlet chip'] = 'Used to enter Central Temenos - 2nd Floor.',
    ['ivory chip'] = 'Used to enter Central Temenos - 3rd Floor.',
    ['carmine chip'] = 'Access item.',
    ['cyan chip'] = 'Access item.',
    ['gray chip'] = 'Access item.',
    ['metal chip'] = 'Access item.',
    ['niveous chip'] = 'Access item.',
    ['crepuscular chip'] = 'Access item.',
}

local LIMBUS_BOSS_HINT_BY_ID = {
    [15240] = 'Homam Zucchetto',
    [14905] = 'Homam Manopolas',
    [15576] = 'Homam Cosciales',
    [15661] = 'Homam Gambieras',
    [14488] = 'Homam Corazza',

    [15241] = 'Nashira Turban',
    [14906] = 'Nashira Gages',
    [15577] = 'Nashira Seraweels',
    [15662] = 'Nashira Crackows',
    [14489] = 'Nashira Manteel',
}

local LIMBUS_BOSS_HINT_BY_KEY = {
    ['omega s eye'] = 'Homam Zucchetto',
    ['omegas eye'] = 'Homam Zucchetto',
    ['omega s foreleg'] = 'Homam Manopolas',
    ['omegas foreleg'] = 'Homam Manopolas',
    ['omega s hind leg'] = 'Homam Cosciales',
    ['omegas hind leg'] = 'Homam Cosciales',
    ['omega s tail'] = 'Homam Gambieras',
    ['omegas tail'] = 'Homam Gambieras',
    ['omega s heart'] = 'Homam Corazza',
    ['omegas heart'] = 'Homam Corazza',

    ['ultima s cerebrum'] = 'Nashira Turban',
    ['ultimas cerebrum'] = 'Nashira Turban',
    ['ultima s claw'] = 'Nashira Gages',
    ['ultimas claw'] = 'Nashira Gages',
    ['ultima s leg'] = 'Nashira Seraweels',
    ['ultimas leg'] = 'Nashira Seraweels',
    ['ultima s tail'] = 'Nashira Crackows',
    ['ultimas tail'] = 'Nashira Crackows',
    ['ultima s heart'] = 'Nashira Manteel',
    ['ultimas heart'] = 'Nashira Manteel',

    ['homam zucchetto'] = 'Homam Zucchetto',
    ['homam manopolas'] = 'Homam Manopolas',
    ['homam cosciales'] = 'Homam Cosciales',
    ['homam gambieras'] = 'Homam Gambieras',
    ['homam corazza'] = 'Homam Corazza',

    ['nashira turban'] = 'Nashira Turban',
    ['nashira gages'] = 'Nashira Gages',
    ['nashira seraweels'] = 'Nashira Seraweels',
    ['nashira crackows'] = 'Nashira Crackows',
    ['nashira manteel'] = 'Nashira Manteel',
}

local LIMBUS_BOSS_EQUIP_ICON_BY_HINT = {
    ['Homam Zucchetto'] = 'homam_zucchetto',
    ['Homam Manopolas'] = 'homam_manopolas',
    ['Homam Cosciales'] = 'homam_cosciales',
    ['Homam Gambieras'] = 'homam_gambieras',
    ['Homam Corazza'] = 'homam_corazza',
    ['Nashira Turban'] = 'nashira_turban',
    ['Nashira Gages'] = 'nashira_gages',
    ['Nashira Seraweels'] = 'nashira_seraweels',
    ['Nashira Crackows'] = 'nashira_crackows',
    ['Nashira Manteel'] = 'nashira_manteel',
}

local LIMBUS_AF1_JOB_BY_ITEM_KEY = {
    ['coiled yarn'] = 'BRD',
    ['brown doeskin'] = 'BRD',
    ['smalt leather'] = 'BST',
    ['fetid lanolin'] = 'BST',
    ['diabolic silk'] = 'BLM',
    ['diabolic yarn'] = 'BLM',
    ['dark orichalcum'] = 'DRK',
    ['black rivet'] = 'DRK',
    ['cbl myth sheet'] = 'DRG',
    ['cbl mythril sheet'] = 'DRG',
    ['blue rivet'] = 'DRG',
    ['ut gold thread'] = 'MNK',
    ['ancient brass'] = 'MNK',
    ['plaited cord'] = 'NIN',
    ['ebony lacquer'] = 'NIN',
    ['snowy cermet'] = 'PLD',
    ['white rivet'] = 'PLD',
    ['chameleon yarn'] = 'RNG',
    ['charcoal cotton'] = 'RNG',
    ['ruby silk thread'] = 'RDM',
    ['cardinal cloth'] = 'RDM',
    ['scarlet odoshi'] = 'SAM',
    ['kurogane'] = 'SAM',
    ['glittering yarn'] = 'SMN',
    ['astral leather'] = 'SMN',
    ['supple skin'] = 'THF',
    ['light filament'] = 'THF',
    ['ecarlate cloth'] = 'WAR',
    ['argyro rivet'] = 'WAR',
    ['benedict silk'] = 'WHM',
    ['benedict yarn'] = 'WHM',
}

local LIMBUS_AF1_JOB_BY_ITEM_ID = {
    [1930] = 'WAR', -- ecarlate_cloth
    [1931] = 'WAR', -- argyro_rivet
    [1932] = 'MNK', -- utopian_gold_thread
    [1933] = 'MNK', -- ancient_brass
    [1934] = 'WHM', -- benedict_silk
    [1935] = 'WHM', -- benedict_yarn
    [1936] = 'BLM', -- diabolic_silk
    [1937] = 'BLM', -- diabolic_yarn
    [1938] = 'RDM', -- ruby_silk_thread
    [1939] = 'RDM', -- cardinal_cloth
    [1940] = 'THF', -- supple_skin
    [1941] = 'THF', -- light_filament
    [1942] = 'PLD', -- snowy_cermet
    [1943] = 'PLD', -- white_rivet
    [1944] = 'DRK', -- dark_orichalcum
    [1945] = 'DRK', -- black_rivet
    [1946] = 'BST', -- smalt_leather
    [1947] = 'BST', -- fetid_lanolin
    [1948] = 'BRD', -- coiled_yarn
    [1949] = 'BRD', -- brown_doeskin
    [1950] = 'RNG', -- chameleon_yarn
    [1951] = 'RNG', -- charcoal_cotton
    [1952] = 'SAM', -- scarlet_odoshi
    [1953] = 'SAM', -- kurogane
    [1954] = 'NIN', -- plaited_cord
    [1955] = 'NIN', -- ebony_lacquer
    [1956] = 'DRG', -- cobalt_mythril_sheet
    [1957] = 'DRG', -- blue_rivet
    [1958] = 'SMN', -- glittering_yarn
    [1959] = 'SMN', -- astral_leather
}

local function chip_key_for_item(name)
    local s = norm(name or '')
    if s:find('chip', 1, true) == nil then
        return nil
    end
    for _, key in ipairs(CHIP_MATCH_ORDER) do
        if s:find(key, 1, true) then
            return (key == 'smokey') and 'smoky' or key
        end
    end
    return nil
end

local function chip_color_for_item(name, cfg)
    local k = chip_key_for_item(name)
    if not k then
        return nil
    end
    local map = (cfg and cfg.chip_colors) or DEFAULT_CHIP_COLORS
    return (map and map[k]) or DEFAULT_CHIP_COLORS[k]
end

local function limbus_sw_element_key(sess)
    if tostring(sess and sess.limbus_path_id or '') ~= 'apollyon_south_west' then
        return nil
    end
    local k = norm(tostring(sess and sess.limbus_sw_day_element or ''))
    if k == '' then
        return nil
    end
    if k == 'lightning' then
        k = 'thunder'
    end
    if ELEMENT_LABELS[k] then
        return k
    end
    return nil
end

local function limbus_item_key(name)
    local s = norm(name or '')
    if s == '' then
        return ''
    end
    s = s:gsub('_', ' ')
    s = s:gsub('[%.,%-%+%/%\\%[%]%(%)%:%;\'"]', ' ')
    s = s:gsub('%s+', ' ')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    return s
end

local function is_limbus_session(sess)
    local ev = norm(sess and sess.event_id or '')
    if ev == 'limbus' then
        return true
    end
    local zid = tonumber(sess and sess.zone_id) or 0
    if zid == 37 or zid == 38 then
        return true
    end
    return false
end

local function limbus_item_usage_tooltip(info)
    local function mk_tip(text, icon_kind, icon_key)
        local tip = tostring(text or '')
        if tip == '' then
            return nil
        end
        local out = { text = tip }
        if icon_kind ~= nil and icon_key ~= nil then
            local kind = tostring(icon_kind or '')
            local key = tostring(icon_key or '')
            if kind ~= '' and key ~= '' then
                out.icon_kind = kind
                out.icon_key = key
            end
        end
        return out
    end

    if type(info) ~= 'table' then
        return nil
    end

    local item_id = tonumber(info.item_id) or 0
    local chip_hint = LIMBUS_CHIP_HINT_BY_ID[item_id]
    if chip_hint ~= nil then
        return mk_tip(chip_hint)
    end

    local boss_hint_by_id = LIMBUS_BOSS_HINT_BY_ID[item_id]
    if boss_hint_by_id ~= nil then
        local equip_icon = LIMBUS_BOSS_EQUIP_ICON_BY_HINT[boss_hint_by_id]
        return mk_tip(boss_hint_by_id, 'equip', equip_icon)
    end

    local job_by_id = LIMBUS_AF1_JOB_BY_ITEM_ID[item_id]
    if job_by_id ~= nil and job_by_id ~= '' then
        return mk_tip('Used by job: ' .. job_by_id, 'job', tostring(job_by_id):lower())
    end

    local key = limbus_item_key(info.name)
    if key == '' then
        return nil
    end

    local chip_hint_by_key = LIMBUS_CHIP_HINT_BY_KEY[key]
    if chip_hint_by_key ~= nil then
        return mk_tip(chip_hint_by_key)
    end

    local boss_hint_by_key = LIMBUS_BOSS_HINT_BY_KEY[key]
    if boss_hint_by_key ~= nil then
        local equip_icon = LIMBUS_BOSS_EQUIP_ICON_BY_HINT[boss_hint_by_key]
        return mk_tip(boss_hint_by_key, 'equip', equip_icon)
    end

    local job = LIMBUS_AF1_JOB_BY_ITEM_KEY[key]
    if job ~= nil and job ~= '' then
        return mk_tip('Used by job: ' .. job, 'job', tostring(job):lower())
    end
    return nil
end

local function is_limbus_item_name(name)
    local lname = norm(name or '')
    if lname == '' then
        return false
    end

    if is_ancient_beastcoin_name(name) then
        return true
    end

    local key = limbus_item_key(name)
    if key ~= '' then
        if LIMBUS_CHIP_HINT_BY_KEY[key] ~= nil then
            return true
        end
        if LIMBUS_BOSS_HINT_BY_KEY[key] ~= nil then
            return true
        end
        if LIMBUS_AF1_JOB_BY_ITEM_KEY[key] ~= nil then
            return true
        end
    end

    if chip_key_for_item(name) ~= nil then
        return true
    end

    return false
end

local function is_limbus_pool_item(info)
    if type(info) ~= 'table' then
        return false
    end

    local item_id = tonumber(info.item_id) or 0
    if item_id ~= 0 then
        if LIMBUS_CHIP_HINT_BY_ID[item_id] ~= nil then
            return true
        end
        if LIMBUS_BOSS_HINT_BY_ID[item_id] ~= nil then
            return true
        end
        if LIMBUS_AF1_JOB_BY_ITEM_ID[item_id] ~= nil then
            return true
        end
    end

    return is_limbus_item_name(info.name)
end

local function item_name_matches_event(name, event_id)
    local ev = norm(event_id or '')
    if ev == 'limbus' then
        return is_limbus_item_name(name)
    end
    if ev == 'dynamis' then
        return not is_limbus_item_name(name)
    end
    return true
end

local function pool_item_matches_event(info, event_id, sess)
    local ev = norm(event_id or '')
    if not (sess and sess.is_event == true) then
        -- Outside active events (regular zones / lobby), the live treasure pool
        -- is global and should never be filtered by event tabs.
        return true
    end
    local sess_ev = norm((sess and sess.event_id) or '')
    if (sess_ev == 'dynamis' or sess_ev == 'limbus') and ev == sess_ev then
        -- If we're currently inside this event, show the real live pool as-is.
        return true
    end
    if ev == 'limbus' then
        return is_limbus_pool_item(info)
    end
    if ev == 'dynamis' then
        return not is_limbus_pool_item(info)
    end
    return true
end

local function default_event_minutes(sess)
    local zid = tonumber(sess and sess.zone_id)

    -- Cities: 3h30
    if zid == 185 or zid == 186 or zid == 187 or zid == 188 then
        return 210
    end

    -- Dreamlands: 2h
    if zid == 39 or zid == 40 or zid == 41 or zid == 42 then
        return 120
    end

    -- Northlands: 4h
    if zid == 134 or zid == 135 then
        return 240
    end

    -- Safe default
    return 240
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
        imgui.PushStyleVar(S('WindowBorderSize'), 0.8);
        n = n + 1
    end
    if S('WindowRounding') ~= 0 then
        imgui.PushStyleVar(S('WindowRounding'), 6.0);
        n = n + 1
    end
    if S('ChildRounding') ~= 0 then
        imgui.PushStyleVar(S('ChildRounding'), 5.0);
        n = n + 1
    end
    if S('FrameRounding') ~= 0 then
        imgui.PushStyleVar(S('FrameRounding'), 5.0);
        n = n + 1
    end
    if S('PopupRounding') ~= 0 then
        imgui.PushStyleVar(S('PopupRounding'), 5.0);
        n = n + 1
    end
    return n
end

local function ensure_gate_icons_loaded()
    if GATE_ICONS.loaded then
        return
    end
    GATE_ICONS.loaded = true

    if not (FFI_OK and D3D8_OK and d3d8 and D3D8_DEVICE) then
        return
    end

    pcall(function()
        ffi.C.D3DXCreateTextureFromFileInMemoryEx(nil, nil, 0, 0, 0, 0, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, nil)
    end)
    pcall(function()
        ffi.cdef([[
            HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
        ]])
    end)

    local function load_texture(file_path)
        local out = ffi.new('IDirect3DTexture8*[1]')
        local ok, hr = pcall(function()
            return ffi.C.D3DXCreateTextureFromFileA(D3D8_DEVICE, file_path, out)
        end)
        if not ok then
            return nil
        end
        if hr ~= ffi.C.S_OK or out[0] == nil then
            return nil
        end
        return d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]))
    end

    local root = tostring(AshitaCore:GetInstallPath() or '')
    if root == '' then
        return
    end

    local function load_first(rel_paths)
        for _, rel in ipairs(rel_paths) do
            local tex = load_texture(root .. rel)
            if tex ~= nil then
                return tex
            end
        end
        return nil
    end

    GATE_ICONS.gate_open = load_first({
        '\\addons\\treasure\\icons\\gate_open.png',
        '\\addons\\treasure\\icons\\gate_open.PNG',
    })
    GATE_ICONS.gate_closed = load_first({
        '\\addons\\treasure\\icons\\gate_closed.png',
        '\\addons\\treasure\\icons\\gate_closed.PNG',
    })
    GATE_ICONS.vortex = load_first({
        '\\addons\\treasure\\icons\\vortex.png',
        '\\addons\\treasure\\icons\\vortex.PNG',
    })
    GATE_ICONS.vortex_open = load_first({
        '\\addons\\treasure\\icons\\vortex_open.png',
        '\\addons\\treasure\\icons\\vortex_open.PNG',
    })
    GATE_ICONS.vortex_closed = load_first({
        '\\addons\\treasure\\icons\\vortex_closed.png',
        '\\addons\\treasure\\icons\\vortex_closed.PNG',
    })
    GATE_ICONS.transition = load_first({
        '\\addons\\treasure\\icons\\transicion.png',
        '\\addons\\treasure\\icons\\transicion.PNG',
        '\\addons\\treasure\\icons\\transition.png',
        '\\addons\\treasure\\icons\\transition.PNG',
    })
    GATE_ICONS.ultima = load_first({
        '\\addons\\treasure\\icons\\ultima.png',
        '\\addons\\treasure\\icons\\Ultima.png',
        '\\addons\\treasure\\icons\\ultima.webp',
        '\\addons\\treasure\\icons\\Ultima.webp',
        '\\addons\\treasure\\icons\\ultima.jpg',
        '\\addons\\treasure\\icons\\Ultima.jpg',
    })
    GATE_ICONS.status_ok = load_first({
        '\\addons\\treasure\\icons\\ok.png',
        '\\addons\\treasure\\icons\\OK.png',
    })
    GATE_ICONS.status_x = load_first({
        '\\addons\\treasure\\icons\\x.png',
        '\\addons\\treasure\\icons\\X.png',
    })

    local chip_icon_map = {
        magenta = { 'Magenta_Chip_icon', 'magenta_chip_icon' },
        smoky = { 'Smoky_Chip_icon', 'Smokey_Chip_icon', 'smoky_chip_icon', 'smokey_chip_icon' },
        emerald = { 'Emerald_Chip_icon', 'emerald_chip_icon' },
        scarlet = { 'Scarlet_Chip_icon', 'scarlet_chip_icon' },
        ivory = { 'Ivory_Chip_icon', 'ivory_chip_icon' },
        charcoal = { 'Charcoal_Chip_icon', 'charcoal_chip_icon' },
        smalt = { 'Smalt_Chip_icon', 'smalt_chip_icon' },
        orchid = { 'Orchid_Chip_icon', 'orchid_chip_icon' },
        cerulean = { 'Cerulean_Chip_icon', 'cerulean_chip_icon' },
        silver = { 'Silver_Chip_icon', 'silver_chip_icon' },
        metal = { 'Metal_Chip_icon', 'metal_chip_icon' },
        niveous = { 'Niveous_Chip_icon', 'niveous_chip_icon' },
        crepuscular = { 'Crepuscular_Chip_icon', 'crepuscular_chip_icon' },
    }
    for key, stems in pairs(chip_icon_map) do
        local candidates = {}
        for _, stem in ipairs(stems) do
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\chips\\' .. stem .. '.png'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\chips\\' .. stem .. '.PNG'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\' .. stem .. '.png'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\' .. stem .. '.PNG'
        end
        GATE_ICONS.chips[key] = load_first(candidates)
    end

    local elemental_icon_map = {
        fire = { 'Fire_Elemental', 'fire_elemental' },
        ice = { 'Ice_Elemental', 'ice_elemental' },
        wind = { 'Wind_Elemental', 'wind_elemental' },
        earth = { 'Earth_Elemental', 'earth_elemental' },
        thunder = { 'Thunder_Elemental', 'Lightning_Elemental', 'thunder_elemental', 'lightning_elemental' },
        water = { 'Water_Elemental', 'water_elemental' },
        light = { 'Light_Elemental', 'light_elemental' },
        dark = { 'Dark_Elemental', 'dark_elemental' },
    }
    for key, stems in pairs(elemental_icon_map) do
        local candidates = {}
        for _, stem in ipairs(stems) do
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\elementals\\' .. stem .. '.png'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\elementals\\' .. stem .. '.PNG'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\' .. stem .. '.png'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\' .. stem .. '.PNG'
        end
        GATE_ICONS.elementals[key] = load_first(candidates)
    end

    local job_icon_keys = {
        'war', 'mnk', 'whm', 'blm', 'rdm', 'thf', 'pld', 'drk', 'bst', 'brd',
        'rng', 'sam', 'nin', 'drg', 'smn', 'blu', 'cor', 'pup', 'dnc', 'sch',
        'geo', 'run',
    }
    for _, key in ipairs(job_icon_keys) do
        GATE_ICONS.jobs[key] = load_first({
            '\\addons\\treasure\\icons\\jobs\\' .. key .. '.png',
            '\\addons\\treasure\\icons\\jobs\\' .. key .. '.PNG',
        })
    end

    local equip_icon_map = {
        homam_zucchetto = { 'Homam_Zucchetto_icon', 'homam_zucchetto_icon' },
        homam_manopolas = { 'Homam_Manopolas_icon', 'homam_manopolas_icon' },
        homam_cosciales = { 'Homam_Cosciales_icon', 'homam_cosciales_icon' },
        homam_gambieras = { 'Homam_Gambieras_icon', 'homam_gambieras_icon' },
        homam_corazza = { 'Homam_Corazza_icon', 'homam_corazza_icon' },
        nashira_turban = { 'Nashira_Turban_icon', 'nashira_turban_icon' },
        nashira_gages = { 'Nashira_Gages_icon', 'nashira_gages_icon' },
        nashira_seraweels = { 'Nashira_Seraweels_icon', 'nashira_seraweels_icon' },
        nashira_crackows = { 'Nashira_Crackows_icon', 'nashira_crackows_icon' },
        nashira_manteel = { 'Nashira_Manteel_icon', 'nashira_manteel_icon' },
    }
    for key, stems in pairs(equip_icon_map) do
        local candidates = {}
        for _, stem in ipairs(stems) do
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\equip\\' .. stem .. '.png'
            candidates[#candidates + 1] = '\\addons\\treasure\\icons\\equip\\' .. stem .. '.PNG'
        end
        GATE_ICONS.equip[key] = load_first(candidates)
    end
end

local function limbus_door_icon_kind(sess)
    local zid = tonumber(sess and sess.zone_id) or 0
    local zone_name = norm(tostring(sess and sess.zone_name or ''))
    if zone_name:find('apollyon', 1, true) then
        return 'vortex'
    end
    if zone_name:find('temenos', 1, true) then
        return 'gate'
    end
    -- Zone ids fallback (server-specific mapping observed in live tests):
    -- 37 = Temenos, 38 = Apollyon.
    if zid == 37 then
        return 'gate'
    end
    if zid == 38 then
        return 'vortex'
    end
    return 'gate'
end

local function draw_gate_icon(sess, size, cfg)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local gate_open = (sess and sess.limbus_gate_ready == true)
    local is_transition = (sess and sess.limbus_transition_pending == true)
    local kind = limbus_door_icon_kind(sess)

    local base_size = tonumber(size) or 16
    local icon_size = base_size
    local tex = nil
    local tint = ICON_TINT_WHITE
    local uv0 = { 0, 0 }
    local uv1 = { 1, 1 }

    local anim = cfg and cfg.limbus_icon_anim
    local transition_pulse = DEFAULT_LIMBUS_ICON_ANIM.transition_pulse
    local vortex_open_spin = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin
    local vortex_open_pulse = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_pulse
    local vortex_open_spin_speed = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed
    if type(anim) == 'table' then
        if anim.transition_pulse ~= nil then
            transition_pulse = (anim.transition_pulse == true)
        end
        if anim.vortex_open_spin ~= nil then
            vortex_open_spin = (anim.vortex_open_spin == true)
        end
        if anim.vortex_open_pulse ~= nil then
            vortex_open_pulse = (anim.vortex_open_pulse == true)
        end
        vortex_open_spin_speed = clamp_num(anim.vortex_open_spin_speed, 0.2, 6.0, DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed)
    end

    if is_transition then
        tex = GATE_ICONS.transition
        if transition_pulse then
            -- Transition pulse animation (brightness + slight zoom).
            local pulse = (math.sin(os.clock() * 6.5) + 1.0) * 0.5
            local scale = 0.72 + (pulse * 0.52)
            icon_size = math.max(12, math.floor((icon_size * scale) + 0.5))
            tint = {
                0.50 + (0.45 * pulse),
                0.72 + (0.28 * pulse),
                1.00,
                0.74 + (0.26 * pulse),
            }
        end
    end
    if tex == nil then
        if kind == 'vortex' then
            if gate_open then
                tex = GATE_ICONS.vortex_open or GATE_ICONS.vortex or GATE_ICONS.vortex_closed
            else
                tex = GATE_ICONS.vortex_closed or GATE_ICONS.vortex or GATE_ICONS.vortex_open
            end
            tint = ICON_TINT_WHITE

            -- Open-vortex animation (configurable): pseudo-radial spin using UV phase
            -- plus optional pulse to keep visual motion clear.
            if gate_open and vortex_open_spin then
                local spins = os.clock() * vortex_open_spin_speed
                local phase = math.floor((spins * 4.0) % 4.0)
                if phase == 1 then
                    uv0 = { 1, 0 }
                    uv1 = { 0, 1 }
                elseif phase == 2 then
                    uv0 = { 1, 1 }
                    uv1 = { 0, 0 }
                elseif phase == 3 then
                    uv0 = { 0, 1 }
                    uv1 = { 1, 0 }
                end

                if vortex_open_pulse then
                    local pulse = (math.sin(os.clock() * 7.5) + 1.0) * 0.5
                    local scale = 0.88 + (pulse * 0.24)
                    icon_size = math.max(12, math.floor((base_size * scale) + 0.5))
                    tint = {
                        0.76 + (0.22 * pulse),
                        0.92 + (0.08 * pulse),
                        0.88 + (0.12 * pulse),
                        0.90 + (0.10 * pulse),
                    }
                end
            end
        else
            -- Prefer dedicated colored gate variants when available.
            tex = gate_open and GATE_ICONS.gate_open or GATE_ICONS.gate_closed
        end
    end
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    -- Keep transition scaling centered around the original icon anchor.
    if icon_size ~= base_size then
        local cx, cy = imgui.GetCursorPos()
        if type(cx) ~= 'number' then
            cx, cy = _get_xy(cx)
        end
        local off = (base_size - icon_size) * 0.5
        imgui.SetCursorPosX(cx + off)
        imgui.SetCursorPosY(cy + off)
    end

    imgui.Image(ptr, { icon_size, icon_size }, uv0, uv1, tint, { 0, 0, 0, 0 })
    return true
end

local function draw_chip_icon(chip_name, chip_key, size, tint)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local key = tostring(chip_key or '')
    if key == '' then
        key = tostring(chip_key_for_item(chip_name) or '')
    end
    if key == '' then
        return false
    end

    local tex = GATE_ICONS.chips and GATE_ICONS.chips[key] or nil
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    local icon_size = tonumber(size) or 16
    if icon_size < 12 then
        icon_size = 12
    end
    imgui.Image(ptr, { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, tint or ICON_TINT_WHITE, { 0, 0, 0, 0 })
    return true
end

local function draw_ultima_icon(size, tint)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local tex = GATE_ICONS.ultima
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    local icon_size = tonumber(size) or 16
    if icon_size < 12 then
        icon_size = 12
    end
    imgui.Image(ptr, { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, tint or ICON_TINT_WHITE, { 0, 0, 0, 0 })
    return true
end

local function draw_keyitem_status_icon(has_item, size, tint_ok, tint_x)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local tex = (has_item == true) and GATE_ICONS.status_ok or GATE_ICONS.status_x
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    local icon_size = tonumber(size) or 14
    if icon_size < 10 then
        icon_size = 10
    end
    local tint = (has_item == true) and (tint_ok or ICON_TINT_WHITE) or (tint_x or ICON_TINT_WHITE)
    imgui.Image(ptr, { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, tint, { 0, 0, 0, 0 })
    return true
end

local function draw_tooltip_icon(kind, key, size, tint)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end
    local k = norm(key or '')
    if k == '' then
        return false
    end

    local tex = nil
    local kind_norm = norm(kind or '')
    if kind_norm == 'job' then
        tex = GATE_ICONS.jobs and GATE_ICONS.jobs[k] or nil
    elseif kind_norm == 'equip' then
        tex = GATE_ICONS.equip and GATE_ICONS.equip[k] or nil
    else
        return false
    end
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    local icon_size = tonumber(size) or 18
    if icon_size < 12 then
        icon_size = 12
    end
    imgui.Image(ptr, { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, tint or ICON_TINT_WHITE, { 0, 0, 0, 0 })
    return true
end

local function draw_hover_tooltip(text, icon_kind, icon_key)
    local tip = ''
    local kind = icon_kind
    local key = icon_key
    if type(text) == 'table' then
        tip = tostring(text.text or '')
        kind = kind or text.icon_kind
        key = key or text.icon_key
    else
        tip = tostring(text or '')
    end
    if tip == '' then
        return
    end

    local hovered = false
    if imgui.IsItemHovered ~= nil then
        local ok_hover, res = pcall(imgui.IsItemHovered)
        hovered = (ok_hover and (res == true or tonumber(res) == 1))
    end
    if not hovered then
        return
    end

    local has_icon = (tostring(kind or '') ~= '' and tostring(key or '') ~= '')
    if not has_icon and imgui.SetTooltip ~= nil then
        pcall(imgui.SetTooltip, tip)
        return
    end
    if imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil then
        local ok_begin, opened = pcall(imgui.BeginTooltip)
        if ok_begin and opened ~= false then
            if has_icon then
                local drew = draw_tooltip_icon(kind, key, 18, ICON_TINT_WHITE)
                if drew and imgui.SameLine ~= nil then
                    pcall(imgui.SameLine)
                end
            end
            if imgui.TextUnformatted ~= nil then
                pcall(imgui.TextUnformatted, tip)
            else
                pcall(imgui.Text, tip)
            end
            pcall(imgui.EndTooltip)
        end
    end
end

local function draw_element_icon(element_key, size, tint)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local key = norm(element_key or '')
    if key == 'lightning' then
        key = 'thunder'
    end
    if key == '' then
        return false
    end

    local tex = GATE_ICONS.elementals and GATE_ICONS.elementals[key] or nil
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    local icon_size = tonumber(size) or 16
    if icon_size < 12 then
        icon_size = 12
    end
    imgui.Image(ptr, { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, tint or ICON_TINT_WHITE, { 0, 0, 0, 0 })

    local label = ELEMENT_LABELS[key]
    if label ~= nil then
        draw_hover_tooltip(label .. ' Elemental')
    end

    return true
end

local function push_tabs_style(event_id, cfg, C)
    local accent = cfg and cfg.visual_colors and cfg.visual_colors.EVENT_DYNAMIS or DEFAULT_EVENT_ACCENT_DYNAMIS
    if tostring(event_id or '') == 'limbus' then
        accent = cfg and cfg.visual_colors and cfg.visual_colors.EVENT_LIMBUS or DEFAULT_EVENT_ACCENT_LIMBUS
    end

    local V = (cfg and cfg.visual_colors) or DEFAULT_VISUAL_COLORS
    local tab_bg = copy_rgba(V.TAB_BG or DEFAULT_VISUAL_COLORS.TAB_BG)
    local tab_hover = mix_rgba(copy_rgba(V.TAB_BG_HOVERED or DEFAULT_VISUAL_COLORS.TAB_BG_HOVERED), accent, 0.24)
    local tab_active = mix_rgba(copy_rgba(V.TAB_BG_ACTIVE or DEFAULT_VISUAL_COLORS.TAB_BG_ACTIVE), accent, 0.32)
    local tab_unfocus = copy_rgba(V.TAB_BG_UNFOCUSED or DEFAULT_VISUAL_COLORS.TAB_BG_UNFOCUSED)
    local tab_unfocus_active = mix_rgba(copy_rgba(V.TAB_BG_UNFOCUSED_ACTIVE or DEFAULT_VISUAL_COLORS.TAB_BG_UNFOCUSED_ACTIVE), accent, 0.26)
    local sep = mix_rgba(copy_rgba(V.SEPARATOR or DEFAULT_VISUAL_COLORS.SEPARATOR), accent, 0.18)

    local pushed_colors = 0
    local function push_col(id, value)
        if id ~= nil then
            imgui.PushStyleColor(id, value)
            pushed_colors = pushed_colors + 1
        end
    end
    push_col(COL_TAB, tab_bg)
    push_col(COL_TAB_HOVERED, tab_hover)
    push_col(COL_TAB_ACTIVE, tab_active)
    push_col(COL_TAB_UNFOCUSED, tab_unfocus)
    push_col(COL_TAB_UNFOCUSED_ACTIVE, tab_unfocus_active)
    push_col(COL_SEPARATOR, sep)
    push_col(COL_BORDER, sep)

    local pushed_vars = 0
    if SV_TAB_ROUNDING ~= nil then
        imgui.PushStyleVar(SV_TAB_ROUNDING, 6.0)
        pushed_vars = pushed_vars + 1
    end

    return pushed_colors, pushed_vars
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
    active_event = 'dynamis',
    selected_event = nil,
    selected_event_user = false,
    history_idx = 0,
    history_file = nil,
    history_session = nil,
    _history_combo_open = false,
    _history_files = nil,
    glass_paid = {},
    currency_delivered = {},
    players_currency_only = false,
}

-- Avoid upvalue pressure in ui.render (Lua 5.1 limit: 60 upvalues).
ui._limbus_sw_element_key = limbus_sw_element_key
ui._draw_element_icon = draw_element_icon
ui._draw_ultima_icon = draw_ultima_icon
ui._draw_keyitem_status_icon = draw_keyitem_status_icon



--------------------------------------------------------------------
-- Pintar columnas y resizables
--------------------------------------------------------------------
local function draw_treasure_table (sess, C, cfg, event_id)
    if not sess or not sess.drops then
        return
    end

    -- Always resolve loot colors by explicit event to avoid cross-event palette bleed.
    C = event_loot_colors(cfg, event_id or (sess and sess.event_id) or 'dynamis')

    --Anchos de columnas persistentes
    local mode = ui.compact and 'compact' or 'full'
    if cfg._tre_cols_mode ~= mode then
        local prof_cols = cfg.layout and cfg.layout[mode] and cfg.layout[mode].cols
        cfg.tre_col_w = sanitize_tre_cols(prof_cols, mode)
        cfg._tre_init = false
        cfg._tre_cols_mode = mode
    else
        cfg.tre_col_w = sanitize_tre_cols(cfg.tre_col_w, mode)
    end
    cfg._tre_init = cfg._tre_init or false

    ----------------------------------------------------------------
    -- Construir lista ordenada por slot
    ----------------------------------------------------------------
    local list, count = {}, 0
    for slot, info in pairs(sess.drops.pool_live or {}) do
        if pool_item_matches_event(info, event_id, sess) then
            count = count + 1
            list[#list + 1] = {
                slot = slot,
                info = info,
                rest = math.max(0, math.floor(info.expire - timeutil.now()))
            }
        end
    end
    table.sort(list, function(a, b)
        local adt = tonumber((a.info and a.info.drop_time) or 0) or 0
        local bdt = tonumber((b.info and b.info.drop_time) or 0) or 0
        if adt ~= bdt then
            return adt < bdt
        end

        local aid = tonumber((a.info and a.info.item_id) or 0) or 0
        local bid = tonumber((b.info and b.info.item_id) or 0) or 0
        if aid ~= bid then
            return aid < bid
        end

        if a.rest ~= b.rest then
            return a.rest < b.rest
        end
        return a.slot < b.slot
    end)


    ----------------------------------------------------------------
    -- Scroll-region solo en compacto
    ----------------------------------------------------------------
    local using_child = ui.compact
    local sv = nil

    if using_child then
        local row_h = imgui.GetTextLineHeight() + imgui.GetStyle().FramePadding.y * 2
        local want_h = row_h * (count + 1)
        if count <= 4 then
            want_h = want_h + (row_h * 1.0)
        else
            want_h = want_h + (row_h * 0.5)
        end
        local min_child = row_h * 2
        local max_child = row_h * 12
        local child_h = math.min(max_child, math.max(min_child, want_h))

        imgui.PushStyleColor(3, { 0, 0, 0, 0 })
        sv = S and S('ScrollbarSize')
        if sv and sv ~= 0 then
            imgui.PushStyleVar(sv, 0)
        end
        imgui.BeginChild('treasure_scroll_region', { 0, child_h }, false, WF('NoScrollbar'))
    end

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
    local show_limbus_item_tooltips = (norm(event_id or '') == 'limbus')
    local ev_for_color = norm(event_id or '')
    for _, e in ipairs(list) do
        local info, rest = e.info, e.rest

        local rcol = (rest < 30 and { 1, 0.4, 0.4, 1 })
                or (rest < 120 and { 1, 0.85, 0.25, 1 })
                or { 0.3, 1, 0.3, 1 }
        local chip_col = chip_color_for_item(info.name, cfg)
        local cur_name = is_event_currency_name(info.name, ev_for_color)
        local use_hundo = (ev_for_color == 'dynamis') and is_hundo(info.name)
        local col = cur_name
                and (use_hundo and C.HUNDO or C.CUR)
                or (chip_col or C.ITEM)

        imgui.TextColored(col, title(info.name));
        if show_limbus_item_tooltips then
            local tip = limbus_item_usage_tooltip(info)
            if type(tip) == 'table' and tostring(tip.text or '') ~= '' then
                draw_hover_tooltip(tip)
            elseif type(tip) == 'string' and tip ~= '' then
                draw_hover_tooltip(tip)
            end
        end
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
            cfg.tre_col_w = sanitize_tre_cols(cfg.tre_col_w, mode)
            cfg._tre_cols_mode = mode
            cfg.layout = cfg.layout or {}
            cfg.layout[mode] = cfg.layout[mode] or {}
            cfg.layout[mode].cols = { table.unpack(cfg.tre_col_w) }
            persist(cfg)
        end
    end

    imgui.Columns(1)

    if using_child then
        imgui.EndChild()
        if sv and sv ~= 0 then
            imgui.PopStyleVar()
        end
        imgui.PopStyleColor()
    end
end

local function draw_settings_panel(cfg, C, event_id)
    local changed = false
    local active_event = tostring(event_id or ''):lower()
    if (active_event ~= 'dynamis') and (active_event ~= 'limbus') then
        active_event = tostring(ui.selected_event or ui.active_event or 'dynamis'):lower()
        if (active_event ~= 'dynamis') and (active_event ~= 'limbus') then
            active_event = 'dynamis'
        end
    end
    local dynC = sanitize_color_map(cfg.colors_dynamis or cfg.colors, DEFAULT_COLORS_DYNAMIS)
    local limC = sanitize_color_map(cfg.colors_limbus or cfg.colors, DEFAULT_COLORS_LIMBUS)
    local B = cfg.button_style or {}

    local function current_event_palette()
        if active_event == 'limbus' then
            return limC, DEFAULT_COLORS_LIMBUS, 'Limbus'
        end
        return dynC, DEFAULT_COLORS_DYNAMIS, 'Dynamis'
    end

    if imgui.BeginTabBar('##settings_sections_' .. active_event) then
        if imgui.BeginTabItem('Globals') then
            local _, _, event_label = current_event_palette()
            local list = THEMES_OK and keys(ADDON_THEMES) or { cfg.theme }
            local sel = 1
            for i, n in ipairs(list) do
                if n == cfg.theme then
                    sel = i
                end
            end
            if imgui.BeginCombo('Theme', list[sel] or '?') then
                for i, nm in ipairs(list) do
                    if imgui.Selectable(nm, sel == i) then
                        cfg.theme = nm
                        apply_theme_visual_preset(cfg, nm)
                        changed = true
                    end
                end
                imgui.EndCombo()
            end
            local a = { cfg.alpha }
            if imgui.SliderFloat('Opacity', a, 0.2, 1.0, '%.2f') then
                cfg.alpha = a[1]
                changed = true
            end
            local fs = { cfg.font_scale or 1.0 }
            if imgui.SliderFloat('Font Scale', fs, 0.5, 2.0, '%.2f') then
                cfg.font_scale = fs[1]
                changed = true
            end

            cfg.menu_hide = cfg.menu_hide or {}
            local mh = cfg.menu_hide
            if mh.hide_when_ui_hidden == nil then
                mh.hide_when_ui_hidden = true
                changed = true
            end
            if mh.hide_when_game_menu == nil then
                mh.hide_when_game_menu = true
                changed = true
            end
            if type(mh.groups) ~= 'table' then
                mh.groups = {}
                changed = true
            end
            local menu_group_defs = (type(cfg._menu_hide_group_defs) == 'table') and cfg._menu_hide_group_defs or {}
            for _, def in ipairs(menu_group_defs) do
                local key = tostring(def and def.key or '')
                if key ~= '' and mh.groups[key] == nil then
                    mh.groups[key] = true
                    changed = true
                end
            end

            imgui.Separator()
            imgui.TextUnformatted('Auto-hide')
            do
                local v_hidden = { mh.hide_when_ui_hidden == true }
                if imgui.Checkbox('Hide when game UI is hidden', v_hidden) then
                    mh.hide_when_ui_hidden = v_hidden[1]
                    changed = true
                end
            end
            do
                local v_menus = { mh.hide_when_game_menu == true }
                if imgui.Checkbox('Hide on selected game menus', v_menus) then
                    mh.hide_when_game_menu = v_menus[1]
                    changed = true
                end
            end
            if mh.hide_when_game_menu == true then
                if imgui.SmallButton('Enable all menu groups') then
                    for _, def in ipairs(menu_group_defs) do
                        local key = tostring(def and def.key or '')
                        if key ~= '' then
                            mh.groups[key] = true
                        end
                    end
                    changed = true
                end
                imgui.SameLine()
                if imgui.SmallButton('Disable all menu groups') then
                    for _, def in ipairs(menu_group_defs) do
                        local key = tostring(def and def.key or '')
                        if key ~= '' then
                            mh.groups[key] = false
                        end
                    end
                    changed = true
                end

                if #menu_group_defs > 0 then
                    local child_h = math.min(220, math.max(110, (#menu_group_defs * 24) + 8))
                    imgui.BeginChild('menu_hide_groups_cfg', { 0, child_h }, true)
                    for _, def in ipairs(menu_group_defs) do
                        local key = tostring(def and def.key or '')
                        if key ~= '' then
                            local label = tostring(def.label or key)
                            local hint = tostring(def.hint or '')
                            local v_group = { mh.groups[key] == true }
                            if imgui.Checkbox(label .. '##menu_hide_' .. key, v_group) then
                                mh.groups[key] = v_group[1]
                                changed = true
                            end
                            if hint ~= '' then
                                imgui.SameLine()
                                imgui.TextDisabled(hint)
                            end
                        end
                    end
                    imgui.EndChild()
                else
                    imgui.TextDisabled('No menu groups available.')
                end
            end

            if active_event == 'limbus' then
                imgui.Separator()
                imgui.TextUnformatted('Limbus Status Icon')
                local isz = { tonumber(cfg.limbus_icon_size) or 28.0 }
                if imgui.SliderFloat('Icon size (px)', isz, 16.0, 56.0, '%.0f') then
                    cfg.limbus_icon_size = clamp_num(isz[1], 16.0, 56.0, 28.0)
                    changed = true
                end
                if imgui.SmallButton('Reset icon size') then
                    cfg.limbus_icon_size = 28.0
                    changed = true
                end

                imgui.TextDisabled('Preview')
                local preview_size = math.max(12, math.floor((tonumber(cfg.limbus_icon_size) or 28) + 0.5))
                local function preview_icon(label, preview_sess)
                    imgui.BeginGroup()
                    local ok_draw, drew = pcall(draw_gate_icon, preview_sess, preview_size, cfg)
                    if not (ok_draw and drew) then
                        imgui.TextUnformatted('[]')
                    end
                    imgui.TextDisabled(label)
                    imgui.EndGroup()
                end

                cfg.limbus_icon_anim = cfg.limbus_icon_anim or {}
                if cfg.limbus_icon_anim.transition_pulse == nil then
                    cfg.limbus_icon_anim.transition_pulse = DEFAULT_LIMBUS_ICON_ANIM.transition_pulse
                end
                if cfg.limbus_icon_anim.vortex_open_spin == nil then
                    cfg.limbus_icon_anim.vortex_open_spin = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin
                end
                if cfg.limbus_icon_anim.vortex_open_pulse == nil then
                    cfg.limbus_icon_anim.vortex_open_pulse = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_pulse
                end
                cfg.limbus_icon_anim.vortex_open_spin_speed = clamp_num(
                        cfg.limbus_icon_anim.vortex_open_spin_speed,
                        0.2,
                        6.0,
                        DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed
                )

                imgui.TextDisabled('Gate')
                preview_icon('Closed', {
                    zone_name = 'Temenos',
                    zone_id = 37,
                    limbus_gate_ready = false,
                    limbus_transition_pending = false,
                })
                imgui.SameLine()
                preview_icon('Open', {
                    zone_name = 'Temenos',
                    zone_id = 37,
                    limbus_gate_ready = true,
                    limbus_transition_pending = false,
                })

                local v_anim = { cfg.limbus_icon_anim.vortex_open_spin == true }
                if imgui.Checkbox('Animate vortex open', v_anim) then
                    cfg.limbus_icon_anim.vortex_open_spin = v_anim[1]
                    changed = true
                end
                local v_pulse = { cfg.limbus_icon_anim.vortex_open_pulse == true }
                if imgui.Checkbox('Pulse vortex open', v_pulse) then
                    cfg.limbus_icon_anim.vortex_open_pulse = v_pulse[1]
                    changed = true
                end
                local v_speed = { tonumber(cfg.limbus_icon_anim.vortex_open_spin_speed) or DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed }
                if imgui.SliderFloat('Vortex spin speed', v_speed, 0.2, 6.0, '%.1f') then
                    cfg.limbus_icon_anim.vortex_open_spin_speed = clamp_num(v_speed[1], 0.2, 6.0, DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed)
                    changed = true
                end

                if imgui.SmallButton('Reset icon animation') then
                    cfg.limbus_icon_anim.transition_pulse = DEFAULT_LIMBUS_ICON_ANIM.transition_pulse
                    cfg.limbus_icon_anim.vortex_open_spin = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin
                    cfg.limbus_icon_anim.vortex_open_pulse = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_pulse
                    cfg.limbus_icon_anim.vortex_open_spin_speed = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed
                    changed = true
                end

                imgui.Separator()
                imgui.TextUnformatted('Gunpod HP Bar')
                cfg.limbus_hp_bar_colors = cfg.limbus_hp_bar_colors or {}
                cfg.limbus_hp_bar_colors.high = sanitize_rgba(cfg.limbus_hp_bar_colors.high, DEFAULT_LIMBUS_HP_BAR_COLORS.high)
                cfg.limbus_hp_bar_colors.low = sanitize_rgba(cfg.limbus_hp_bar_colors.low, DEFAULT_LIMBUS_HP_BAR_COLORS.low)
                if imgui.ColorEdit4('HP color (high)', cfg.limbus_hp_bar_colors.high, imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
                if imgui.ColorEdit4('HP color (low)', cfg.limbus_hp_bar_colors.low, imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
                if imgui.SmallButton('Reset HP bar colors') then
                    cfg.limbus_hp_bar_colors.high = copy_rgba(DEFAULT_LIMBUS_HP_BAR_COLORS.high)
                    cfg.limbus_hp_bar_colors.low = copy_rgba(DEFAULT_LIMBUS_HP_BAR_COLORS.low)
                    changed = true
                end
            end

            imgui.Separator()
            imgui.TextUnformatted('Visual Theme Colors')
            local V = cfg.visual_colors or {}
            local accent_key = (active_event == 'limbus') and 'EVENT_LIMBUS' or 'EVENT_DYNAMIS'
            local accent_label = (active_event == 'limbus') and 'Limbus accent' or 'Dynamis accent'
            local function vpicker(lbl, key)
                if imgui.ColorEdit4(lbl, V[key], imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
            end
            vpicker('HUD text', 'HUD_TEXT')
            vpicker(accent_label, accent_key)
            vpicker('State OK', 'STATE_OK')
            vpicker('State alert', 'STATE_ALERT')
            vpicker('Window background', 'WINDOW_BG')
            vpicker('Header background', 'HEADER_BG')
            vpicker('Header border', 'HEADER_BORDER')
            vpicker('Header text', 'HEADER_TEXT')
            vpicker('Content background', 'CONTENT_BG')
            vpicker('Control bg', 'CONTROL_BG')
            vpicker('Control bg hovered', 'CONTROL_BG_HOVERED')
            vpicker('Control bg active', 'CONTROL_BG_ACTIVE')
            vpicker('Tab bg', 'TAB_BG')
            vpicker('Tab bg hovered', 'TAB_BG_HOVERED')
            vpicker('Tab bg active', 'TAB_BG_ACTIVE')
            vpicker('Tab unfocused', 'TAB_BG_UNFOCUSED')
            vpicker('Tab unfocused active', 'TAB_BG_UNFOCUSED_ACTIVE')
            vpicker('Separator', 'SEPARATOR')
            if imgui.SmallButton('Reset visual colors (' .. event_label .. ')') then
                local reset_keys = {
                    'HUD_TEXT',
                    accent_key,
                    'STATE_OK',
                    'STATE_ALERT',
                    'WINDOW_BG',
                    'HEADER_BG',
                    'HEADER_BORDER',
                    'HEADER_TEXT',
                    'CONTENT_BG',
                    'CONTROL_BG',
                    'CONTROL_BG_HOVERED',
                    'CONTROL_BG_ACTIVE',
                    'TAB_BG',
                    'TAB_BG_HOVERED',
                    'TAB_BG_ACTIVE',
                    'TAB_BG_UNFOCUSED',
                    'TAB_BG_UNFOCUSED_ACTIVE',
                    'SEPARATOR',
                }
                for _, key in ipairs(reset_keys) do
                    V[key] = copy_rgba(DEFAULT_VISUAL_COLORS[key])
                end
                cfg.visual_colors = V
                changed = true
            end

            imgui.Separator()
            imgui.TextUnformatted('Event Buttons')
            local rr = { tonumber(B.rounding) or DEFAULT_BUTTON_STYLE.rounding }
            if imgui.SliderFloat('Roundness (px)', rr, 0.0, 16.0, '%.1f') then
                B.rounding = rr[1]
                changed = true
            end
            local hh = { tonumber(B.height) or DEFAULT_BUTTON_STYLE.height }
            if imgui.SliderFloat('Height (px)', hh, 18.0, 36.0, '%.0f') then
                B.height = hh[1]
                changed = true
            end
            local bs = { tonumber(B.border_selected) or DEFAULT_BUTTON_STYLE.border_selected }
            if imgui.SliderFloat('Active border', bs, 0.8, 3.0, '%.1f') then
                B.border_selected = bs[1]
                changed = true
            end
            local bi = { tonumber(B.border_idle) or DEFAULT_BUTTON_STYLE.border_idle }
            if imgui.SliderFloat('Idle border', bi, 0.0, 2.4, '%.1f') then
                B.border_idle = bi[1]
                changed = true
            end

            local function bpicker(lbl, key)
                if imgui.ColorEdit4(lbl, B[key], imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
            end
            local active_border_key = (active_event == 'limbus') and 'selected_border_limbus' or 'selected_border_dynamis'
            local active_border_label = (active_event == 'limbus')
                    and 'Active border color (Limbus)'
                    or 'Active border color (Dynamis)'
            bpicker('Active bg', 'selected_bg')
            bpicker(active_border_label, active_border_key)
            bpicker('Active text', 'selected_text')
            bpicker('Idle bg', 'idle_bg')
            bpicker('Idle border color', 'idle_border')
            bpicker('Idle text', 'idle_text')

            imgui.TextDisabled('Preview')
            do
                local bs_prev = B
                local function draw_preview_button(id, label, selected, event_for_border)
                    local base = selected and bs_prev.selected_bg or bs_prev.idle_bg
                    local hovered = tint_rgba(base, 1.10, 0.03)
                    local active = tint_rgba(base, 0.86, 0.00)

                    local border = selected and selected_border_for_event(bs_prev, event_for_border) or copy_rgba(bs_prev.idle_border)
                    local text_col = selected and copy_rgba(bs_prev.selected_text) or copy_rgba(bs_prev.idle_text)
                    local border_sz = selected and (bs_prev.border_selected or DEFAULT_BUTTON_STYLE.border_selected) or (bs_prev.border_idle or DEFAULT_BUTTON_STYLE.border_idle)

                    local pushed = 0
                    if (COL_BUTTON ~= nil) and (COL_BUTTON_HOVERED ~= nil) and (COL_BUTTON_ACTIVE ~= nil) then
                        imgui.PushStyleColor(COL_BUTTON, base)
                        imgui.PushStyleColor(COL_BUTTON_HOVERED, hovered)
                        imgui.PushStyleColor(COL_BUTTON_ACTIVE, active)
                        pushed = pushed + 3
                    end
                    if COL_BORDER ~= nil then
                        imgui.PushStyleColor(COL_BORDER, border)
                        pushed = pushed + 1
                    end
                    if COL_TEXT ~= nil then
                        imgui.PushStyleColor(COL_TEXT, text_col)
                        pushed = pushed + 1
                    end

                    local pushed_style = 0
                    if SV_FRAME_ROUNDING ~= nil then
                        imgui.PushStyleVar(SV_FRAME_ROUNDING, bs_prev.rounding or DEFAULT_BUTTON_STYLE.rounding)
                        pushed_style = pushed_style + 1
                    end
                    if SV_FRAME_BORDER_SIZE ~= nil then
                        imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, border_sz)
                        pushed_style = pushed_style + 1
                    end

                    local h = bs_prev.height or DEFAULT_BUTTON_STYLE.height
                    local ok_preview = pcall(imgui.Button, label .. '##btn_preview_' .. id, { 90, h })
                    if not ok_preview then
                        imgui.Button(label .. '##btn_preview_' .. id)
                    end

                    if pushed_style > 0 then
                        imgui.PopStyleVar(pushed_style)
                    end
                    if pushed > 0 then
                        imgui.PopStyleColor(pushed)
                    end
                end

                local dyn_sel = (active_event == 'dynamis')
                local lim_sel = (active_event == 'limbus')
                draw_preview_button('dyna_sel', 'Dynamis', dyn_sel, 'dynamis')
                imgui.SameLine()
                draw_preview_button('lim_sel', 'Limbus', lim_sel, 'limbus')
            end

            if imgui.SmallButton('Reset button style (' .. event_label .. ')') then
                local reset_keys = {
                    'rounding',
                    'height',
                    'border_selected',
                    'border_idle',
                    'selected_bg',
                    active_border_key,
                    'selected_text',
                    'idle_bg',
                    'idle_border',
                    'idle_text',
                }
                for _, k in ipairs(reset_keys) do
                    local v = DEFAULT_BUTTON_STYLE[k]
                    if type(v) == 'table' then
                        B[k] = copy_rgba(v)
                    else
                        B[k] = v
                    end
                end
                -- Keep legacy field aligned with Dynamis border fallback.
                B.selected_border = copy_rgba(B.selected_border_dynamis or DEFAULT_BUTTON_STYLE.selected_border_dynamis)
                changed = true
            end

            imgui.EndTabItem()
        end

        if imgui.BeginTabItem('Loots') then
            local editC, defaultsC, event_label = current_event_palette()
            imgui.TextUnformatted(event_label .. ' Loot Colors')

            local function picker(map, lbl, key)
                if imgui.ColorEdit4(lbl, map[key], imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
            end

            picker(editC, 'Player names', 'NAME')
            picker(editC, 'Equipment', 'ITEM')
            if active_event == 'limbus' then
                picker(editC, 'Ancient Beastcoin', 'CUR')
            else
                picker(editC, 'Currency', 'CUR')
                picker(editC, '100-piece', 'HUNDO')
            end
            picker(editC, 'Qty / Total', 'QTY')
            picker(editC, 'Lost count', 'LOST')

            if imgui.SmallButton('Reset ' .. event_label .. ' colors') then
                editC = sanitize_color_map(defaultsC, defaultsC)
                changed = true
            end

            if active_event == 'limbus' then
                limC = editC
            else
                dynC = editC
            end

            imgui.EndTabItem()
        end

        if active_event == 'limbus' and imgui.BeginTabItem('Chips') then
            imgui.TextUnformatted('Limbus Chip Colors')
            local CC = cfg.chip_colors or {}
            local function cpicker(key)
                local label = CHIP_COLOR_LABELS[key] or (title(key) .. ' Chip')
                if imgui.ColorEdit4(label, CC[key], imgui.ColorEditFlags_NoInputs) then
                    changed = true
                end
            end
            for _, key in ipairs(CHIP_COLOR_KEYS) do
                cpicker(key)
            end
            if imgui.SmallButton('Reset chip colors') then
                for _, key in ipairs(CHIP_COLOR_KEYS) do
                    CC[key] = copy_rgba(DEFAULT_CHIP_COLORS[key])
                end
                changed = true
            end
            cfg.chip_colors = CC
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end

    cfg.colors_dynamis = dynC
    cfg.colors_limbus = limC
    -- Legacy compatibility: keep cfg.colors mapped to Dynamis palette.
    cfg.colors = cfg.colors_dynamis
    cfg.button_style = B

    if changed then
        persist(cfg)
    end
end

local function build_event_context(sess, cfg)
    local zone_event_id = tostring((sess and sess.event_id) or ''):lower()
    if zone_event_id ~= 'dynamis' and zone_event_id ~= 'limbus' then
        zone_event_id = ''
    end

    local event_id
    if ui.compact and zone_event_id ~= '' then
        -- Compact mode always follows the active zone event.
        event_id = zone_event_id
    else
        event_id = ui.selected_event or (zone_event_id ~= '' and zone_event_id) or ui.active_event
    end

    return {
        imgui = imgui,
        ui = ui,
        sess = sess,
        event_id = event_id,
        cfg = cfg,
        C = event_loot_colors(cfg, event_id),
        event_loot_colors = function(ev_id)
            return event_loot_colors(cfg, ev_id)
        end,
        V = cfg.visual_colors,
        TF_BORDER = TF_BORDER,
        keys = keys,
        is_cur = is_cur,
        is_hundo = is_hundo,
        title = title,
        lost_name = lost_name,
        to_units = to_units,
        base_cur = base_cur,
        display_cur = display_cur,
        is_valid_player_name = is_valid_player_name,
        default_event_minutes = default_event_minutes,
        fmt_n = fmt_n,
        store = store,
        item_matches_event = function(name, ev_id)
            return item_name_matches_event(name, ev_id)
        end,
        chip_color_for_item = function(name)
            return chip_color_for_item(name, cfg)
        end,
        draw_styled_hp_progress = function(frac, size, text_col)
            draw_styled_hp_progress(frac, size, text_col, cfg)
        end,
        draw_gate_icon = function(sess_i, size_i)
            return draw_gate_icon(sess_i, size_i, cfg)
        end,
        draw_chip_icon = function(chip_name, chip_key, size_i, tint)
            return draw_chip_icon(chip_name, chip_key, size_i, tint)
        end,
        draw_element_icon = function(element_key, size_i, tint)
            return draw_element_icon(element_key, size_i, tint)
        end,
        draw_keyitem_status_icon = function(has_item, size_i, tint_ok, tint_x)
            return draw_keyitem_status_icon(has_item, size_i, tint_ok, tint_x)
        end,
        draw_treasure_table = draw_treasure_table,
        draw_settings_panel = draw_settings_panel,
    }
end

--------------------------------------------------------------------
-- MAIN RENDER
--------------------------------------------------------------------
function ui.render(sess, cfg)
    ----------------------------------------------------------------
    -- Defaults (colores, tema, opacidad)
    ----------------------------------------------------------------
    cfg.colors = cfg.colors or {}
    local migrated_palette = false
    for k, v in pairs(DEFAULT_COLORS_DYNAMIS) do
        if not cfg.colors[k] then
            cfg.colors[k] = { table.unpack(v) }
            migrated_palette = true
        end
    end
    -- Restore Dynamis default CUR when the Limbus-era mismatch made CUR = HUNDO.
    if rgba_equals(cfg.colors.CUR, CUR_FIX_WRONG) and rgba_equals(cfg.colors.HUNDO, CUR_FIX_WRONG) then
        cfg.colors.CUR = copy_rgba(CUR_FIX_DYNAMIS)
        migrated_palette = true
    end

    if type(cfg.colors_dynamis) ~= 'table' then
        cfg.colors_dynamis = {}
        migrated_palette = true
    end
    for k, v in pairs(DEFAULT_COLORS_DYNAMIS) do
        if cfg.colors_dynamis[k] == nil then
            cfg.colors_dynamis[k] = sanitize_rgba(cfg.colors[k], v)
            migrated_palette = true
        else
            cfg.colors_dynamis[k] = sanitize_rgba(cfg.colors_dynamis[k], v)
        end
    end

    if type(cfg.colors_limbus) ~= 'table' then
        cfg.colors_limbus = {}
        migrated_palette = true
    end
    for k, v in pairs(DEFAULT_COLORS_LIMBUS) do
        if cfg.colors_limbus[k] == nil then
            cfg.colors_limbus[k] = sanitize_rgba(v, v)
            migrated_palette = true
        else
            cfg.colors_limbus[k] = sanitize_rgba(cfg.colors_limbus[k], v)
        end
    end

    -- One-time migration: old configs could mirror Limbus colors from Dynamis.
    -- If so, restore Limbus defaults (notably Ancient Beastcoin CUR color).
    if cfg._limbus_palette_seeded == nil then
        local limbus_equals_dynamis = true
        for k, _ in pairs(DEFAULT_COLORS_LIMBUS) do
            if not rgba_equals(cfg.colors_limbus[k], cfg.colors_dynamis[k]) then
                limbus_equals_dynamis = false
                break
            end
        end
        if limbus_equals_dynamis then
            for k, v in pairs(DEFAULT_COLORS_LIMBUS) do
                cfg.colors_limbus[k] = copy_rgba(v)
            end
            migrated_palette = true
        end
        cfg._limbus_palette_seeded = true
        migrated_palette = true
    end

    -- Legacy compatibility: keep cfg.colors mirroring Dynamis palette.
    for k, _ in pairs(DEFAULT_COLORS_DYNAMIS) do
        if not rgba_equals(cfg.colors[k], cfg.colors_dynamis[k]) then
            cfg.colors[k] = copy_rgba(cfg.colors_dynamis[k])
            migrated_palette = true
        end
    end
    cfg.visual_colors = cfg.visual_colors or {}
    for k, v in pairs(DEFAULT_VISUAL_COLORS) do
        if cfg.visual_colors[k] == nil then
            migrated_palette = true
        end
        cfg.visual_colors[k] = sanitize_rgba(cfg.visual_colors[k], v)
    end
    cfg.chip_colors = cfg.chip_colors or {}
    if (cfg.chip_colors.smoky == nil) and (cfg.chip_colors.smokey ~= nil) then
        cfg.chip_colors.smoky = cfg.chip_colors.smokey
        migrated_palette = true
    end
    for _, key in ipairs(CHIP_COLOR_KEYS) do
        if cfg.chip_colors[key] == nil then
            migrated_palette = true
        end
        cfg.chip_colors[key] = sanitize_rgba(cfg.chip_colors[key], DEFAULT_CHIP_COLORS[key])
    end
    if type(cfg.limbus_hp_bar_colors) ~= 'table' then
        cfg.limbus_hp_bar_colors = {}
        migrated_palette = true
    end
    if cfg.limbus_hp_bar_colors.high == nil then
        migrated_palette = true
    end
    if cfg.limbus_hp_bar_colors.low == nil then
        migrated_palette = true
    end
    cfg.limbus_hp_bar_colors.high = sanitize_rgba(cfg.limbus_hp_bar_colors.high, DEFAULT_LIMBUS_HP_BAR_COLORS.high)
    cfg.limbus_hp_bar_colors.low = sanitize_rgba(cfg.limbus_hp_bar_colors.low, DEFAULT_LIMBUS_HP_BAR_COLORS.low)
    if type(cfg.limbus_icon_anim) ~= 'table' then
        cfg.limbus_icon_anim = {}
        migrated_palette = true
    end
    if cfg.limbus_icon_anim.transition_pulse == nil then
        cfg.limbus_icon_anim.transition_pulse = DEFAULT_LIMBUS_ICON_ANIM.transition_pulse
        migrated_palette = true
    else
        cfg.limbus_icon_anim.transition_pulse = (cfg.limbus_icon_anim.transition_pulse == true)
    end
    if cfg.limbus_icon_anim.vortex_open_spin == nil then
        cfg.limbus_icon_anim.vortex_open_spin = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin
        migrated_palette = true
    else
        cfg.limbus_icon_anim.vortex_open_spin = (cfg.limbus_icon_anim.vortex_open_spin == true)
    end
    if cfg.limbus_icon_anim.vortex_open_pulse == nil then
        cfg.limbus_icon_anim.vortex_open_pulse = DEFAULT_LIMBUS_ICON_ANIM.vortex_open_pulse
        migrated_palette = true
    else
        cfg.limbus_icon_anim.vortex_open_pulse = (cfg.limbus_icon_anim.vortex_open_pulse == true)
    end
    do
        local spd = clamp_num(cfg.limbus_icon_anim.vortex_open_spin_speed, 0.2, 6.0, DEFAULT_LIMBUS_ICON_ANIM.vortex_open_spin_speed)
        if tonumber(cfg.limbus_icon_anim.vortex_open_spin_speed) ~= spd then
            cfg.limbus_icon_anim.vortex_open_spin_speed = spd
            migrated_palette = true
        else
            cfg.limbus_icon_anim.vortex_open_spin_speed = spd
        end
    end
    do
        local icon_sz = clamp_num(cfg.limbus_icon_size, 16.0, 56.0, 28.0)
        if tonumber(cfg.limbus_icon_size) ~= icon_sz then
            cfg.limbus_icon_size = icon_sz
            migrated_palette = true
        end
    end
    if migrated_palette then
        persist(cfg)
    end
    cfg.button_style = cfg.button_style or {}
    cfg.button_style.rounding = clamp_num(cfg.button_style.rounding, 0.0, 16.0, DEFAULT_BUTTON_STYLE.rounding)
    cfg.button_style.height = clamp_num(cfg.button_style.height, 18.0, 36.0, DEFAULT_BUTTON_STYLE.height)
    cfg.button_style.border_selected = clamp_num(cfg.button_style.border_selected, 0.8, 3.0, DEFAULT_BUTTON_STYLE.border_selected)
    cfg.button_style.border_idle = clamp_num(cfg.button_style.border_idle, 0.0, 2.4, DEFAULT_BUTTON_STYLE.border_idle)
    cfg.button_style.selected_bg = sanitize_rgba(cfg.button_style.selected_bg, DEFAULT_BUTTON_STYLE.selected_bg)
    cfg.button_style.selected_border = sanitize_rgba(cfg.button_style.selected_border, DEFAULT_BUTTON_STYLE.selected_border)
    cfg.button_style.selected_border_dynamis = sanitize_rgba(
            cfg.button_style.selected_border_dynamis,
            DEFAULT_BUTTON_STYLE.selected_border_dynamis or DEFAULT_BUTTON_STYLE.selected_border
    )
    cfg.button_style.selected_border_limbus = sanitize_rgba(
            cfg.button_style.selected_border_limbus,
            DEFAULT_BUTTON_STYLE.selected_border_limbus or DEFAULT_BUTTON_STYLE.selected_border
    )
    cfg.button_style.selected_text = sanitize_rgba(cfg.button_style.selected_text, DEFAULT_BUTTON_STYLE.selected_text)
    cfg.button_style.idle_bg = sanitize_rgba(cfg.button_style.idle_bg, DEFAULT_BUTTON_STYLE.idle_bg)
    cfg.button_style.idle_border = sanitize_rgba(cfg.button_style.idle_border, DEFAULT_BUTTON_STYLE.idle_border)
    cfg.button_style.idle_text = sanitize_rgba(cfg.button_style.idle_text, DEFAULT_BUTTON_STYLE.idle_text)
    cfg.alpha = cfg.alpha or 0.9
    cfg.theme = cfg.theme or ((THEMES_OK and ADDON_THEMES.Default) and 'Default' or '')
    -- Ajuste de escala de fuente para toda la ventana. Valor por defecto 1.0 (sin escalado).
    cfg.font_scale = cfg.font_scale or 1.0
    cfg.limbus_icon_size = clamp_num(cfg.limbus_icon_size, 16.0, 56.0, 28.0)
    local active_event = tostring(ui.selected_event or (sess and sess.event_id) or ui.active_event or 'dynamis'):lower()
    local C = event_loot_colors(cfg, active_event)

    ----------------------------------------------------------------
    -- Layout tables
    ----------------------------------------------------------------
    cfg.layout = cfg.layout or {}
    cfg.layout.compact = cfg.layout.compact or {
        window = { x = 820, y = 270, w = 298, h = 181 },
        cols = copy_cols(DEFAULT_TRE_COLS.compact),
    }
    cfg.layout.full = cfg.layout.full or {
        window = { w = 600, h = 500 },
        cols = copy_cols(DEFAULT_TRE_COLS.full),
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
    else
        -- Full mode scroll is handled by an internal child to avoid parent scroll jumps.
        window_flags = bit.bor(window_flags, WF('NoScrollbar'), WF('NoScrollWithMouse'))
    end

    imgui.SetNextWindowBgAlpha(cfg.alpha)
    local pushed_visual_bg = 0
    local function push_visual(id, rgba)
        if id ~= nil and type(rgba) == 'table' then
            imgui.PushStyleColor(id, rgba)
            pushed_visual_bg = pushed_visual_bg + 1
        end
    end
    local function themed_bg(key, default_key)
        local src = cfg.visual_colors[key] or DEFAULT_VISUAL_COLORS[default_key or key]
        local out = copy_rgba(src)
        out[4] = clamp_num((tonumber(out[4]) or 1.0) * (tonumber(cfg.alpha) or 1.0), 0.0, 1.0, 1.0)
        return out
    end
    push_visual(COL_WINDOW_BG, themed_bg('WINDOW_BG'))
    push_visual(COL_CHILD_BG, themed_bg('CONTENT_BG'))
    push_visual(COL_FRAME_BG, themed_bg('CONTROL_BG'))
    push_visual(COL_FRAME_BG_HOVERED, themed_bg('CONTROL_BG_HOVERED'))
    push_visual(COL_FRAME_BG_ACTIVE, themed_bg('CONTROL_BG_ACTIVE'))
    push_visual(COL_TAB, themed_bg('TAB_BG'))
    push_visual(COL_TAB_HOVERED, themed_bg('TAB_BG_HOVERED'))
    push_visual(COL_TAB_ACTIVE, themed_bg('TAB_BG_ACTIVE'))
    push_visual(COL_TAB_UNFOCUSED, themed_bg('TAB_BG_UNFOCUSED'))
    push_visual(COL_TAB_UNFOCUSED_ACTIVE, themed_bg('TAB_BG_UNFOCUSED_ACTIVE'))
    push_visual(COL_SEPARATOR, themed_bg('SEPARATOR'))

    if not imgui.Begin('Treasure', false, window_flags) then
        imgui.End()
        if pushed_visual_bg > 0 then
            imgui.PopStyleColor(pushed_visual_bg)
        end
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
    local root_window = nil
    do
        local px, py = imgui.GetWindowPos()
        local wx, wy = imgui.GetWindowSize()
        if type(px) ~= 'number' then
            px, py = _get_xy(px)
        end
        if type(wx) ~= 'number' then
            wx, wy = _get_xy(wx)
        end
        px = tonumber(px) or 0
        py = tonumber(py) or 0
        wx = tonumber(wx) or 0
        wy = tonumber(wy) or 0
        local win = cfg.layout[mode].window or {}
        if mode == 'full' then
            -- Keep last sane full size if current frame reports a tiny transient size.
            if wx < 520 then
                wx = math.max(520, tonumber(win.w) or 0)
            end
            if wy < 320 then
                wy = math.max(320, tonumber(win.h) or 0)
            end
        else
            wx = math.max(220, wx)
            wy = math.max(120, wy)
        end
        root_window = { x = px, y = py, w = wx, h = wy }
        local h_changed = (not ui.compact) and (win.h ~= wy)
        if win.x ~= px or win.y ~= py or win.w ~= wx or h_changed then
            cfg.layout[mode].window = { x = px, y = py, w = wx, h = wy }
            persist(cfg)
        end
    end

    ----------------------------------------------------------------
    -- Si estamos fuera de un evento, aviso y salida
    ----------------------------------------------------------------
    if not sess then
        imgui.TextDisabled('Outside event area.')
        imgui.End()
        if pushed_visual_bg > 0 then
            imgui.PopStyleColor(pushed_visual_bg)
        end
        if pushed_style > 0 then
            imgui.PopStyleVar(pushed_style)
        end
        if pushed_theme > 0 then
            imgui.PopStyleColor(pushed_theme)
        end
        return
    end

    ----------------------------------------------------------------
    -- Botones de vista / cerrar
    ----------------------------------------------------------------
    local mode_toggled = false
    local close_requested = false
    do
        local style = imgui.GetStyle()
        local pad = style.FramePadding.x
        local spacing = style.ItemInnerSpacing.x

        local zone_event = tostring((sess and sess.event_id) or ''):lower()
        if zone_event ~= 'dynamis' and zone_event ~= 'limbus' then
            zone_event = ''
        end
        if (not ui.selected_event_user) or (not ui.selected_event) or ui.selected_event == '' then
            ui.selected_event = (zone_event ~= '' and zone_event) or tostring(event_router.get_active(ui))
        end

        local function limbus_run_header_text_for_compact()
            local sess_event = tostring((sess and sess.event_id) or ''):lower()
            if sess_event ~= 'limbus' then
                return nil
            end
            local route_label = tostring(sess and sess.limbus_path_label or '')
            local zone_label = tostring(sess and sess.zone_name or '')
            local base_label = route_label ~= '' and route_label or zone_label
            if base_label ~= '' then
                return base_label
            end
            return nil
        end

        if not ui.compact then
            local event_id = tostring(ui.selected_event or zone_event)
            local event_name = (event_id == 'limbus' and 'Limbus')
                    or (event_id == 'dynamis' and 'Dynamis')
                    or title(event_id)
            local title = 'Treasure - ' .. tostring(event_name)
            local header_h = 28
            local bs = cfg.button_style or DEFAULT_BUTTON_STYLE
            local hdr_col = 0
            if COL_CHILD_BG ~= nil then
                imgui.PushStyleColor(COL_CHILD_BG, cfg.visual_colors.HEADER_BG or DEFAULT_VISUAL_COLORS.HEADER_BG)
                hdr_col = hdr_col + 1
            end
            if COL_BORDER ~= nil then
                imgui.PushStyleColor(COL_BORDER, cfg.visual_colors.HEADER_BORDER or DEFAULT_VISUAL_COLORS.HEADER_BORDER)
                hdr_col = hdr_col + 1
            end

            local hdr_var = 0
            if SV_CHILD_ROUNDING ~= nil then
                imgui.PushStyleVar(SV_CHILD_ROUNDING, 5.0)
                hdr_var = hdr_var + 1
            end
            if SV_FRAME_BORDER_SIZE ~= nil then
                imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, 1.0)
                hdr_var = hdr_var + 1
            end

            local ok_child, began_child = pcall(imgui.BeginChild, 'treasure_full_header', { 0, header_h }, false, WF('NoScrollbar'))
            if not ok_child then
                began_child = imgui.BeginChild('treasure_full_header', { 0, header_h }, false)
            end
            if began_child then
                imgui.SetCursorPosX(8)
                imgui.SetCursorPosY(6)
                if COL_TEXT ~= nil then
                    imgui.PushStyleColor(COL_TEXT, cfg.visual_colors.HEADER_TEXT or DEFAULT_VISUAL_COLORS.HEADER_TEXT)
                    imgui.TextUnformatted(title)
                    imgui.PopStyleColor(1)
                else
                    imgui.TextUnformatted(title)
                end

                local tw_back, _ = imgui.CalcTextSize('Back')
                local tw_close, _ = imgui.CalcTextSize('X')
                local bw_back = math.max(56, tw_back + (pad * 2))
                local bw_close = math.max(26, tw_close + (pad * 2))
                local header_gap = math.max(spacing + 6, 16)
                local child_w = imgui.GetWindowWidth()
                local x_close = math.max(8, child_w - bw_close - 12)
                local x_back = math.max(8, x_close - header_gap - bw_back)

                local function draw_header_button(id, label, is_close_btn, width_px)
                    local is_selected = not is_close_btn
                    local base = is_selected and bs.selected_bg or bs.idle_bg
                    local hovered = tint_rgba(base, 1.10, 0.03)
                    local active = tint_rgba(base, 0.86, 0.00)
                    local border = is_selected and selected_border_for_event(bs, event_id) or copy_rgba(bs.idle_border)
                    local text_col = is_selected and copy_rgba(bs.selected_text) or copy_rgba(bs.idle_text)
                    local border_sz = is_selected and (bs.border_selected or DEFAULT_BUTTON_STYLE.border_selected) or (bs.border_idle or DEFAULT_BUTTON_STYLE.border_idle)

                    local pcol = 0
                    if (COL_BUTTON ~= nil) and (COL_BUTTON_HOVERED ~= nil) and (COL_BUTTON_ACTIVE ~= nil) then
                        imgui.PushStyleColor(COL_BUTTON, base)
                        imgui.PushStyleColor(COL_BUTTON_HOVERED, hovered)
                        imgui.PushStyleColor(COL_BUTTON_ACTIVE, active)
                        pcol = pcol + 3
                    end
                    if COL_BORDER ~= nil then
                        imgui.PushStyleColor(COL_BORDER, border)
                        pcol = pcol + 1
                    end
                    if COL_TEXT ~= nil then
                        imgui.PushStyleColor(COL_TEXT, text_col)
                        pcol = pcol + 1
                    end

                    local pvar = 0
                    if SV_FRAME_ROUNDING ~= nil then
                        imgui.PushStyleVar(SV_FRAME_ROUNDING, bs.rounding or DEFAULT_BUTTON_STYLE.rounding)
                        pvar = pvar + 1
                    end
                    if SV_FRAME_BORDER_SIZE ~= nil then
                        imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, border_sz)
                        pvar = pvar + 1
                    end

                    local clicked = false
                    local ok_btn, res_btn = pcall(imgui.Button, label .. '##full_hdr_' .. id, { width_px, bs.height or DEFAULT_BUTTON_STYLE.height })
                    if ok_btn then
                        clicked = (res_btn == true)
                    else
                        clicked = imgui.Button(label .. '##full_hdr_' .. id)
                    end

                    if pvar > 0 then
                        imgui.PopStyleVar(pvar)
                    end
                    if pcol > 0 then
                        imgui.PopStyleColor(pcol)
                    end
                    return clicked
                end

                imgui.SetCursorPosX(x_back)
                imgui.SetCursorPosY(3)
                if draw_header_button('back', 'Back', false, bw_back) then
                    save_layout(cfg, mode, root_window)
                    ui.compact = true
                    ui.selected_event_user = false
                    if zone_event ~= '' then
                        ui.selected_event = zone_event
                        event_router.set_active(ui, zone_event)
                    else
                        ui.selected_event = tostring(event_router.get_active(ui))
                    end
                    ui._layout_mode = ''
                    ui._last_compact_count = nil
                    ui._last_compact_height = nil
                    ui._top_area = nil
                    mode_toggled = true
                    ui.history_idx = 0
                    ui.history_file = nil
                    ui.history_session = nil
                    ui._history_combo_open = false
                    ui._history_files = nil
                end

                imgui.SetCursorPosX(x_close)
                imgui.SetCursorPosY(3)
                if draw_header_button('close', 'X', true, bw_close) then
                    close_requested = true
                end

                imgui.EndChild()
            end

            if hdr_var > 0 then
                imgui.PopStyleVar(hdr_var)
            end
            if hdr_col > 0 then
                imgui.PopStyleColor(hdr_col)
            end
        end

        if ui.compact then
            local chip_selected_event = zone_event -- fixed highlight: current zone event only
            local function draw_event_chip(id, label, chip_w)
                local selected = (chip_selected_event ~= '' and chip_selected_event == id)
                local bs = cfg.button_style or DEFAULT_BUTTON_STYLE
                local base, hovered, active, border, text_col
                if selected then
                    base = bs.selected_bg
                    hovered = tint_rgba(base, 1.10, 0.03)
                    active = tint_rgba(base, 0.86, 0.00)
                    border = selected_border_for_event(bs, id)
                    text_col = copy_rgba(bs.selected_text)
                else
                    base = bs.idle_bg
                    hovered = tint_rgba(base, 1.12, 0.03)
                    active = tint_rgba(base, 0.88, 0.00)
                    border = copy_rgba(bs.idle_border)
                    text_col = copy_rgba(bs.idle_text)
                end

                local pushed = 0
                if (COL_BUTTON ~= nil) and (COL_BUTTON_HOVERED ~= nil) and (COL_BUTTON_ACTIVE ~= nil) then
                    imgui.PushStyleColor(COL_BUTTON, base)
                    imgui.PushStyleColor(COL_BUTTON_HOVERED, hovered)
                    imgui.PushStyleColor(COL_BUTTON_ACTIVE, active)
                    pushed = 3
                end
                if COL_BORDER ~= nil then
                    imgui.PushStyleColor(COL_BORDER, border)
                    pushed = pushed + 1
                end
                if COL_TEXT ~= nil then
                    imgui.PushStyleColor(COL_TEXT, text_col)
                    pushed = pushed + 1
                end

                local pushed_style = 0
                if SV_FRAME_ROUNDING ~= nil then
                    imgui.PushStyleVar(SV_FRAME_ROUNDING, bs.rounding or DEFAULT_BUTTON_STYLE.rounding)
                    pushed_style = pushed_style + 1
                end
                if SV_FRAME_BORDER_SIZE ~= nil then
                    local border_sz = selected and (bs.border_selected or DEFAULT_BUTTON_STYLE.border_selected) or (bs.border_idle or DEFAULT_BUTTON_STYLE.border_idle)
                    imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, border_sz)
                    pushed_style = pushed_style + 1
                end

                local clicked = false
                local btn_h = bs.height or DEFAULT_BUTTON_STYLE.height
                local ok_btn, res_btn = pcall(imgui.Button, label .. '##chip_' .. id, { chip_w, btn_h })
                if ok_btn then
                    clicked = (res_btn == true)
                else
                    clicked = imgui.Button(label .. '##chip_' .. id)
                end
                if pushed_style > 0 then
                    imgui.PopStyleVar(pushed_style)
                end
                if pushed > 0 then
                    imgui.PopStyleColor(pushed)
                end

                if clicked then
                    ui.selected_event = id
                    ui.selected_event_user = true
                    event_router.set_active(ui, id)

                    -- Compact => Full using selected event.
                    save_layout(cfg, mode, root_window)
                    ui.compact = false
                    ui._layout_mode = ''
                    ui._last_compact_count = nil
                    ui._last_compact_height = nil
                    ui._top_area = nil
                    ui.history_idx = 0
                    ui.history_file = nil
                    ui.history_session = nil
                    ui._history_combo_open = false
                    ui._history_files = nil
                    mode_toggled = true
                end
            end

            imgui.SetCursorPosX(pad)
            imgui.Dummy({ 0, 2 })
            local t = nil
            if sess and sess.is_event then
                t = event_router.top_left_status(ui, {
                    sess = sess,
                    event_id = sess and sess.event_id or ui.selected_event or ui.active_event,
                })
            end
            if t and t ~= '' then
                local zid = tonumber(sess and sess.zone_id) or 0
                local is_limbus = (tostring((sess and sess.event_id) or ''):lower() == 'limbus')
                        or (zid == 37 or zid == 38)
                        or (sess and sess.limbus_timer ~= nil)
                if is_limbus then
                    local clean_t = tostring(t):gsub(':OPEN', ''):gsub(':CLOSED', '')
                    local time_txt = clean_t
                    local floor_num = math.max(1, tonumber(sess and sess.limbus_floor) or 1)
                    local floor_cap = tonumber(sess and sess.limbus_max_floor)
                    if floor_cap and floor_cap > 0 then
                        floor_cap = math.floor(floor_cap)
                    else
                        floor_cap = nil
                    end
                    local floor_txt = (floor_cap and floor_cap > 0)
                            and ('Floor ' .. tostring(math.floor(floor_num)) .. '/' .. tostring(floor_cap))
                            or ('Floor ' .. tostring(math.floor(floor_num)))
                    do
                        local p_time = clean_t:match('^%s*([^|]+)')
                        if p_time and p_time ~= '' then
                            time_txt = p_time:gsub('%s+$', '')
                        end
                    end
                    local chip_name = tostring(sess and sess.limbus_reward_chip or '')
                    if chip_name == '' then
                        chip_name = nil
                    end
                    local chip_phase = (chip_name ~= nil and floor_cap ~= nil and floor_num >= floor_cap)
                    local sw_key_fn = ui._limbus_sw_element_key
                    local sw_element_key = (type(sw_key_fn) == 'function') and sw_key_fn(sess) or nil
                    local path_id = tostring(sess and sess.limbus_path_id or '')
                    local is_central = (path_id == 'apollyon_central')
                    local is_proto_ultima = (path_id == 'temenos_central_4')
                    local gp = (sess and sess.limbus_gunpod) or {}
                    local gp_max = math.max(1, tonumber(gp.max_spawns) or 5)
                    local gp_total = math.max(0, tonumber(gp.total_spawns) or 0)
                    if gp_total > gp_max then
                        gp_max = gp_total
                    end
                    local gp_hp = tonumber(gp.active_hp)
                    if gp_hp then
                        if gp_hp < 0 then
                            gp_hp = 0
                        elseif gp_hp > 100 then
                            gp_hp = 100
                        end
                    end

                    local header_txt = time_txt
                    if not is_central then
                        header_txt = header_txt .. ' | ' .. floor_txt
                    end
                    if is_central then
                        header_txt = header_txt .. ' | Gunpod ' .. tostring(gp_total) .. '/' .. tostring(gp_max)
                    elseif chip_phase and chip_name then
                        header_txt = header_txt .. ' | ' .. chip_name
                    elseif is_proto_ultima then
                        header_txt = header_txt .. ' | Proto-Ultima'
                    end

                    local status_col = cfg.visual_colors.HUD_TEXT or DEFAULT_VISUAL_COLORS.HUD_TEXT
                    local icon_size = math.max(12, math.floor((tonumber(cfg.limbus_icon_size) or 28) + 0.5))
                    local bar_h = 14
                    local text_h = tonumber(imgui.GetTextLineHeight()) or 0
                    local line_h = math.max(text_h, icon_size, bar_h)
                    local sx, sy = imgui.GetCursorPos()
                    if type(sx) ~= 'number' then
                        sx, sy = _get_xy(sx)
                    end
                    sx = tonumber(sx) or 0
                    sy = tonumber(sy) or 0

                    local avail_x2, _ = imgui.GetContentRegionAvail()
                    if type(avail_x2) ~= 'number' then
                        avail_x2 = _get_xy(avail_x2)
                    end
                    local avail_w2 = tonumber(avail_x2) or 0

                    local function text_width(text)
                        local tw, _ = imgui.CalcTextSize(text or '')
                        if type(tw) ~= 'number' then
                            tw = _get_xy(tw)
                        end
                        return tonumber(tw) or 0
                    end

                    local icon_x = sx + math.max(0, avail_w2 - icon_size)

                    local text_y = sy + math.max(0, (line_h - text_h) * 0.5)
                    do
                        local run_subtitle = limbus_run_header_text_for_compact()
                        if run_subtitle and run_subtitle ~= '' and imgui.SetWindowFontScale ~= nil then
                            local base_scale = tonumber(cfg.font_scale) or 1.0
                            if base_scale <= 0 then
                                base_scale = 1.0
                            end
                            local sub_scale = math.max(0.70, math.min(base_scale, base_scale * 0.82))
                            local sub_h = math.max(1, text_h * (sub_scale / base_scale))
                            local sub_y = math.max(0, sy - math.floor(sub_h + 1.5))
                            local sub_col = copy_rgba(status_col)
                            sub_col[4] = math.max(0.15, math.min(1.0, (tonumber(sub_col[4]) or 1.0) * 0.72))
                            pcall(imgui.SetWindowFontScale, sub_scale)
                            imgui.SetCursorPosX(sx)
                            imgui.SetCursorPosY(sub_y)
                            imgui.TextColored(sub_col, run_subtitle)
                            pcall(imgui.SetWindowFontScale, base_scale)
                        end
                    end
                    local icon_y = sy + math.max(0, (line_h - icon_size) * 0.5)
                    local bar_w = math.max(96, math.floor(avail_w2 * 0.40))
                    if bar_w > 180 then
                        bar_w = 180
                    end
                    local bar_x = sx + math.max(0, avail_w2 - bar_w)
                    local bar_y = sy + math.max(0, (line_h - bar_h) * 0.5)

                    imgui.SetCursorPosX(sx)
                    imgui.SetCursorPosY(text_y)
                    imgui.TextColored(status_col, header_txt)

                    if is_central then
                        if gp_hp ~= nil then
                            local hp_frac = math.max(0.0, math.min(1.0, gp_hp / 100.0))
                            imgui.SetCursorPosX(bar_x)
                            imgui.SetCursorPosY(bar_y)
                            draw_styled_hp_progress(hp_frac, { bar_w, bar_h }, status_col, cfg)
                        end
                    elseif chip_phase and chip_name then
                        local chip_col = chip_color_for_item(chip_name, cfg)
                                or (cfg.colors_limbus and cfg.colors_limbus.CUR)
                                or DEFAULT_COLORS_LIMBUS.CUR
                        local chip_key = tostring(sess and sess.limbus_reward_chip_key or '')
                        if chip_key == '' then
                            chip_key = nil
                        end
                        local show_element_icon = (sw_element_key ~= nil and sw_element_key ~= '')
                        local icon_gap = 4
                        local chip_icon_x = icon_x
                        local elem_icon_x = nil
                        if show_element_icon then
                            local duo_w = (icon_size * 2) + icon_gap
                            chip_icon_x = sx + math.max(0, avail_w2 - duo_w)
                            elem_icon_x = chip_icon_x + icon_size + icon_gap
                        end
                        imgui.SetCursorPosX(chip_icon_x)
                        imgui.SetCursorPosY(icon_y)
                        local ok_chip, drew_chip = pcall(draw_chip_icon, chip_name, chip_key, icon_size, chip_col)
                        local drew_elem = false
                        if show_element_icon then
                            imgui.SetCursorPosX(elem_icon_x or icon_x)
                            imgui.SetCursorPosY(icon_y)
                            local elem_fn = ui._draw_element_icon
                            if type(elem_fn) == 'function' then
                                local ok_elem, elem_res = pcall(elem_fn, sw_element_key, icon_size, { 1, 1, 1, 1 })
                                drew_elem = (ok_elem and elem_res == true)
                            end
                        end
                        if not (ok_chip and drew_chip) then
                            local badge = '[C]'
                            local bw = text_width(badge)
                            local tx = sx + math.max(0, avail_w2 - bw)
                            if show_element_icon then
                                tx = tx - (icon_size + icon_gap)
                            end
                            imgui.SetCursorPosX(tx)
                            imgui.SetCursorPosY(text_y)
                            imgui.TextColored(chip_col, badge)
                        end
                        -- Elemental helper is icon-only by design (no text fallback).
                    elseif is_proto_ultima then
                        imgui.SetCursorPosX(icon_x)
                        imgui.SetCursorPosY(icon_y)
                        local ultima_fn = ui._draw_ultima_icon
                        local ok_ult, drew_ult = false, false
                        if type(ultima_fn) == 'function' then
                            ok_ult, drew_ult = pcall(ultima_fn, icon_size, { 1, 1, 1, 1 })
                        end
                        if ok_ult and drew_ult then
                            local hovered = false
                            if imgui.IsItemHovered ~= nil then
                                local ok_hover, hover_res = pcall(imgui.IsItemHovered)
                                hovered = (ok_hover and (hover_res == true or tonumber(hover_res) == 1))
                            end
                            if hovered then
                                if imgui.SetTooltip ~= nil then
                                    pcall(imgui.SetTooltip, 'Proto-Ultima fight')
                                elseif imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil then
                                    local ok_begin, opened = pcall(imgui.BeginTooltip)
                                    if ok_begin and opened ~= false then
                                        if imgui.TextUnformatted ~= nil then
                                            pcall(imgui.TextUnformatted, 'Proto-Ultima fight')
                                        else
                                            pcall(imgui.Text, 'Proto-Ultima fight')
                                        end
                                        pcall(imgui.EndTooltip)
                                    end
                                end
                            end
                        else
                            local badge = '[U]'
                            local bw = text_width(badge)
                            local tx = sx + math.max(0, avail_w2 - bw)
                            imgui.SetCursorPosX(tx)
                            imgui.SetCursorPosY(text_y)
                            imgui.TextColored(status_col, badge)
                        end
                    else
                        local gate_open = (sess and sess.limbus_gate_ready == true)
                        local is_transition = (sess and sess.limbus_transition_pending == true)
                        local zone_name_tip = tostring(sess and sess.zone_name or ''):lower()
                        local door_label = (zone_name_tip:find('apollyon', 1, true) ~= nil) and 'Vortex' or 'Gate'
                        local status_tip = is_transition and (door_label .. ' TRANSITION')
                                or (gate_open and (door_label .. ' OPEN - You can go up now.') or (door_label .. ' CLOSED'))
                        imgui.SetCursorPosX(icon_x)
                        imgui.SetCursorPosY(icon_y)
                        local ok_icon, drew_icon = pcall(draw_gate_icon, sess, icon_size, cfg)
                        if ok_icon and drew_icon then
                            local hovered = false
                            if imgui.IsItemHovered ~= nil then
                                local ok_hover, hover_res = pcall(imgui.IsItemHovered)
                                hovered = (ok_hover and (hover_res == true or tonumber(hover_res) == 1))
                            end
                            if hovered then
                                if imgui.SetTooltip ~= nil then
                                    pcall(imgui.SetTooltip, status_tip)
                                elseif imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil then
                                    local ok_begin, opened = pcall(imgui.BeginTooltip)
                                    if ok_begin and opened ~= false then
                                        if imgui.TextUnformatted ~= nil then
                                            pcall(imgui.TextUnformatted, status_tip)
                                        else
                                            pcall(imgui.Text, status_tip)
                                        end
                                        pcall(imgui.EndTooltip)
                                    end
                                end
                            end
                        else
                            local ok_col = cfg.visual_colors.STATE_OK or DEFAULT_VISUAL_COLORS.STATE_OK
                            local fall_col = status_col
                            local fall_txt = is_transition and 'Transition' or (gate_open and 'Open' or 'Closed')
                            local fw = text_width(fall_txt)
                            imgui.SetCursorPosX(sx + math.max(0, avail_w2 - fw))
                            imgui.SetCursorPosY(text_y)
                            imgui.TextColored(is_transition and fall_col or (gate_open and ok_col or fall_col), fall_txt)
                        end
                    end

                    imgui.SetCursorPosX(pad)
                    imgui.SetCursorPosY(sy + line_h + 2)
                else
                    imgui.TextColored(cfg.visual_colors.HUD_TEXT, t)
                end
            end

            imgui.SetCursorPosX(pad)
            local avail_x, _ = imgui.GetContentRegionAvail()
            if type(avail_x) ~= 'number' then
                avail_x = _get_xy(avail_x)
            end
            local avail_w = tonumber(avail_x) or 0
            local gap = spacing
            local chip_w = math.floor((avail_w - gap) / 2)
            if chip_w < 110 then
                chip_w = 110
            end
            draw_event_chip('dynamis', 'Dynamis', chip_w)
            imgui.SameLine(0, gap)
            draw_event_chip('limbus', 'Limbus', chip_w)
        end
    end

    if close_requested then
        cfg.visible = false
        persist(cfg)
        imgui.End()
        if pushed_visual_bg > 0 then
            imgui.PopStyleColor(pushed_visual_bg)
        end
        if pushed_style > 0 then
            imgui.PopStyleVar(pushed_style)
        end
        if pushed_theme > 0 then
            imgui.PopStyleColor(pushed_theme)
        end
        return
    end

    if mode_toggled then
        imgui.End()
        if pushed_visual_bg > 0 then
            imgui.PopStyleColor(pushed_visual_bg)
        end
        if pushed_style > 0 then
            imgui.PopStyleVar(pushed_style)
        end
        if pushed_theme > 0 then
            imgui.PopStyleColor(pushed_theme)
        end
        return
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

            -- Recompute on item-count changes AND when top compact block changes
            -- (e.g. Limbus status line appears/disappears).
            local top_area = imgui.GetCursorPosY()
            if type(top_area) ~= 'number' then
                local _, ty = _get_xy(top_area)
                top_area = ty
            end
            top_area = tonumber(top_area) or 0
            local top_changed = (ui._top_area == nil) or (math.abs(top_area - (tonumber(ui._top_area) or 0)) > 1)

            if (cnt ~= ui._last_compact_count) or top_changed then
                ui._last_compact_count = cnt
                ui._top_area = top_area

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

                local total_h = math.floor(ui._top_area + child_h + style.WindowPadding.y + 0.5)

                -- Avoid tiny jitter
                if (not ui._last_compact_height) or math.abs(total_h - ui._last_compact_height) > 1 then
                    local px, py = imgui.GetWindowPos()
                    if type(px) ~= 'number' then
                        px, py = _get_xy(px)
                    end
                    px = tonumber(px) or 0
                    py = tonumber(py) or 0
                    local w, _ = imgui.GetWindowSize()
                    imgui.SetWindowSize({ w, total_h })
                    imgui.SetWindowPos({ px, py })
                    ui._last_compact_height = total_h
                end
            end
        else
            ui._last_compact_count = nil
            ui._last_compact_height = nil
            ui._top_area = nil
        end
    end

    local full_body_child = false
    if not ui.compact then
        local ok_child, _ = pcall(imgui.BeginChild, 'treasure_full_body', { 0, 0 }, false)
        if ok_child then
            full_body_child = true
        else
            imgui.BeginChild('treasure_full_body', { 0, 0 }, false)
            full_body_child = true
        end
    end

    if not ui.compact then
        local event_id = tostring(ui.selected_event or (sess and sess.event_id) or ui.active_event or 'dynamis')
        local status_top = event_router.top_left_status(ui, {
            sess = sess,
            event_id = event_id,
        })
        if status_top and status_top ~= '' then
            imgui.TextColored(cfg.visual_colors.HUD_TEXT, status_top)
        end
    end

    imgui.Separator()

    ----------------------------------------------------------------
    -- Selector de sesiones históricas
    ----------------------------------------------------------------
    do
        if not ui.compact then
            local history_event = ui.selected_event or (sess and sess.event_id) or ui.active_event
            if ui._history_event ~= history_event then
                ui._history_event = history_event
                ui.history_idx = 0
                ui.history_file = nil
                ui.history_session = nil
                ui._history_combo_open = false
                ui._history_files = nil
            end
            local live_files = store.list_sessions({ event_id = history_event }) or {}
            if not ui._history_combo_open then
                ui._history_files = nil
            end
            local files = live_files
            if ui._history_combo_open and type(ui._history_files) == 'table' and #ui._history_files > 0 then
                files = ui._history_files
            end
            if #files > 0 then
                -- Etiqueta que muestra la selección actual. la opción 0 representa
                -- el estado actual.
                local selected_name = ui.history_file
                if (selected_name == nil or selected_name == '') and ui.history_idx > 0 and ui.history_idx <= #files then
                    selected_name = files[ui.history_idx]
                end
                local selected_idx = 0
                if selected_name and selected_name ~= '' then
                    for i, fname in ipairs(files) do
                        if fname == selected_name then
                            selected_idx = i
                            break
                        end
                    end
                    if selected_idx == 0 then
                        selected_name = nil
                    end
                end
                ui.history_idx = selected_idx
                ui.history_file = selected_name
                local preview = selected_name or 'Current'

                local sel_bg = { 0.10, 0.10, 0.11, 0.96 }
                local sel_hover = { 0.14, 0.14, 0.15, 0.98 }
                local sel_active = { 0.12, 0.12, 0.13, 1.00 }
                local sel_border = { 0.36, 0.36, 0.38, 0.92 }

                imgui.TextDisabled('Session')
                imgui.SameLine()

                local sel_col = 0
                local sel_var = 0
                if COL_FRAME_BG ~= nil then
                    imgui.PushStyleColor(COL_FRAME_BG, sel_bg)
                    sel_col = sel_col + 1
                end
                if COL_FRAME_BG_HOVERED ~= nil then
                    imgui.PushStyleColor(COL_FRAME_BG_HOVERED, sel_hover)
                    sel_col = sel_col + 1
                end
                if COL_FRAME_BG_ACTIVE ~= nil then
                    imgui.PushStyleColor(COL_FRAME_BG_ACTIVE, sel_active)
                    sel_col = sel_col + 1
                end
                if COL_BORDER ~= nil then
                    imgui.PushStyleColor(COL_BORDER, sel_border)
                    sel_col = sel_col + 1
                end
                if SV_FRAME_ROUNDING ~= nil then
                    imgui.PushStyleVar(SV_FRAME_ROUNDING, 6.0)
                    sel_var = sel_var + 1
                end
                if SV_FRAME_BORDER_SIZE ~= nil then
                    imgui.PushStyleVar(SV_FRAME_BORDER_SIZE, 1.1)
                    sel_var = sel_var + 1
                end

                imgui.PushItemWidth(460)
                local combo_open = imgui.BeginCombo('##history_combo', preview)
                if combo_open then
                    ui._history_combo_open = true
                    if type(ui._history_files) ~= 'table' then
                        ui._history_files = {}
                        for i = 1, #live_files do
                            ui._history_files[i] = live_files[i]
                        end
                    end
                    local list_files = ui._history_files

                    local sel0 = (ui.history_file == nil or ui.history_file == '')
                    if imgui.Selectable('Current', sel0) then
                        ui.history_idx = 0
                        ui.history_file = nil
                        ui.history_session = nil
                    end
                    -- Opciones para cada archivo
                    for i, fname in ipairs(list_files) do
                        local selected = (ui.history_file == fname)
                        if imgui.Selectable(fname, selected) then
                            ui.history_idx = i
                            ui.history_file = fname
                            local sess_loaded = store.load_file(fname)
                            ui.history_session = sess_loaded
                        end
                    end
                    imgui.EndCombo()
                else
                    ui._history_combo_open = false
                    ui._history_files = nil
                end
                imgui.PopItemWidth()
                if sel_var > 0 then
                    imgui.PopStyleVar(sel_var)
                end
                if sel_col > 0 then
                    imgui.PopStyleColor(sel_col)
                end
            end
        end
    end


    ----------------------------------------------------------------
    -- TAB BAR principal
    ----------------------------------------------------------------
        -- Event-specific tabs/body.
    local event_ctx = build_event_context(sess, cfg)

    local tab_style_colors, tab_style_vars = push_tabs_style(event_ctx.event_id, cfg, C)
    event_router.render(ui, event_ctx)
    if tab_style_vars and tab_style_vars > 0 then
        imgui.PopStyleVar(tab_style_vars)
    end
    if tab_style_colors and tab_style_colors > 0 then
        imgui.PopStyleColor(tab_style_colors)
    end

    if full_body_child then
        imgui.EndChild()
    end

    imgui.End()
    if pushed_visual_bg > 0 then
        imgui.PopStyleColor(pushed_visual_bg)
    end
    if pushed_style > 0 then
        imgui.PopStyleVar(pushed_style)
    end
    if pushed_theme > 0 then
        imgui.PopStyleColor(pushed_theme)
    end
end

return ui
