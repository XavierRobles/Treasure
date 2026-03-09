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

local GATE_ICONS = { loaded = false, open = nil, closed = nil }

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

local DEFAULT_TRE_COLS = {
    compact = { 250, 150, 60, 60 },
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

local DEFAULT_COLORS = {
    NAME = { 0.55, 0.78, 1.00, 1 },
    ITEM = { 0, 1, 0.9961, 1 },
    CUR = { 1, 0.84, 0, 1 },
    HUNDO = { 1, 0.84, 0, 1 },
    QTY = { 1, 1, 1, 1 },
    LOST = { 1, 0.35, 0.35, 1 },
}

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

local DEFAULT_VISUAL_COLORS = {
    HUD_TEXT = { 0.84, 0.87, 0.91, 1.00 },
    EVENT_DYNAMIS = { 1.00, 0.62, 0.26, 0.90 },
    EVENT_LIMBUS = { 0.18, 0.77, 0.71, 0.90 },
    STATE_OK = { 0.24, 0.86, 0.52, 1.00 },
    STATE_ALERT = { 1.00, 0.30, 0.31, 1.00 },
    WINDOW_BG = { 0.07, 0.08, 0.10, 0.94 },
    HEADER_BG = { 0.09, 0.09, 0.10, 0.96 },
    HEADER_BORDER = { 0.45, 0.41, 0.30, 0.65 },
    HEADER_TEXT = { 0.90, 0.90, 0.91, 1.00 },
}

local DEFAULT_BUTTON_STYLE = {
    rounding = 9.0,
    height = 25.0,
    border_selected = 1.8,
    border_idle = 0.0,
    selected_bg = { 0.22, 0.20, 0.16, 0.96 },
    selected_border = { 0.80, 0.69, 0.44, 0.92 },
    selected_text = { 0.94, 0.90, 0.76, 1.00 },
    idle_bg = { 0.08, 0.08, 0.09, 0.95 },
    idle_border = { 0.35, 0.33, 0.28, 0.72 },
    idle_text = { 0.78, 0.78, 0.78, 1.00 },
}

local function copy_rgba(src)
    return { src[1], src[2], src[3], src[4] }
end

local LEGACY_CUR_DEFAULT = { 0.1725, 1.0, 0.0431, 1.0 }
local LEGACY_ITEM_DEFAULT = { 1.0, 1.0, 1.0, 1.0 }

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
local function is_cur(name)
    local s = norm(name or '')
    return (s:find('bronzepiece') ~= nil)
            or (s:find('whiteshell') ~= nil)
            or (s:find('byne bill') ~= nil)
            or (s:find('silverpiece') ~= nil)
            or (s:find('jadeshell') ~= nil)
            or (s:find('beastcoin') ~= nil)
end

local CHIP_MATCH_ORDER = {
    'magenta', 'smoky', 'smokey', 'emerald', 'scarlet', 'ivory',
    'charcoal', 'smalt', 'orchid', 'cerulean', 'silver',
    'metal', 'niveous', 'crepuscular',
}

local function chip_color_for_item(name, cfg)
    local s = norm(name or '')
    if s:find('chip', 1, true) == nil then
        return nil
    end
    local map = (cfg and cfg.chip_colors) or DEFAULT_CHIP_COLORS
    for _, key in ipairs(CHIP_MATCH_ORDER) do
        if s:find(key, 1, true) then
            local k = (key == 'smokey') and 'smoky' or key
            return (map and map[k]) or DEFAULT_CHIP_COLORS[k]
        end
    end
    return nil
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
    GATE_ICONS.open = load_texture(root .. '\\addons\\treasure\\icons\\open.png')
    GATE_ICONS.closed = load_texture(root .. '\\addons\\treasure\\icons\\closed.png')
end

local function draw_gate_icon(is_open, size)
    ensure_gate_icons_loaded()
    if not FFI_OK then
        return false
    end

    local tex = is_open and GATE_ICONS.open or GATE_ICONS.closed
    if tex == nil then
        return false
    end

    local ptr = tonumber(ffi.cast('uint32_t', tex))
    if not ptr or ptr == 0 then
        return false
    end

    imgui.Image(ptr, { size, size }, { 0, 0 }, { 1, 1 }, { 1, 1, 1, 1 }, { 0, 0, 0, 0 })
    return true
end

local function push_tabs_style(event_id, cfg, C)
    local accent = cfg and cfg.visual_colors and cfg.visual_colors.EVENT_DYNAMIS or { 0.85, 0.58, 0.24, 1.0 }
    if tostring(event_id or '') == 'limbus' then
        accent = cfg and cfg.visual_colors and cfg.visual_colors.EVENT_LIMBUS or { 0.22, 0.72, 0.72, 1.0 }
    end

    -- Tie tab accent to the loot palette for stronger visual identity.
    local event_tone = (tostring(event_id or '') == 'limbus') and (C and C.HUNDO) or (C and C.ITEM)
    if event_tone then
        accent = mix_rgba(accent, event_tone, 0.55)
    end

    local tab_bg = { 0.10, 0.10, 0.11, 0.96 }
    local tab_hover = mix_rgba(tab_bg, accent, 0.35)
    local tab_active = mix_rgba(tab_bg, accent, 0.68)
    local tab_unfocus = { 0.08, 0.08, 0.09, 0.92 }
    local tab_unfocus_active = mix_rgba(tab_unfocus, accent, 0.45)
    local sep = mix_rgba({ 0.22, 0.22, 0.24, 0.85 }, accent, 0.35)

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
        count = count + 1
        list[#list + 1] = {
            slot = slot,
            info = info,
            rest = math.max(0, math.floor(info.expire - timeutil.now()))
        }
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
    for _, e in ipairs(list) do
        local info, rest = e.info, e.rest

        local rcol = (rest < 30 and { 1, 0.4, 0.4, 1 })
                or (rest < 120 and { 1, 0.85, 0.25, 1 })
                or { 0.3, 1, 0.3, 1 }
        local chip_col = chip_color_for_item(info.name, cfg)
        local col = is_cur(info.name)
                and (is_hundo(info.name) and C.HUNDO or C.CUR)
                or (chip_col or C.ITEM)

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

    imgui.Separator()
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

    imgui.Separator()
    imgui.TextUnformatted('Visual Theme Colors')
    local V = cfg.visual_colors or {}
    local function vpicker(lbl, key)
        if imgui.ColorEdit4(lbl, V[key], imgui.ColorEditFlags_NoInputs) then
            changed = true
        end
    end
    vpicker('HUD text', 'HUD_TEXT')
    vpicker('Dynamis accent', 'EVENT_DYNAMIS')
    vpicker('Limbus accent', 'EVENT_LIMBUS')
    vpicker('State OK', 'STATE_OK')
    vpicker('State alert', 'STATE_ALERT')
    vpicker('Window background', 'WINDOW_BG')
    vpicker('Header background', 'HEADER_BG')
    vpicker('Header border', 'HEADER_BORDER')
    vpicker('Header text', 'HEADER_TEXT')
    if imgui.SmallButton('Reset visual colors') then
        for k, v in pairs(DEFAULT_VISUAL_COLORS) do
            V[k] = copy_rgba(v)
        end
        cfg.visual_colors = V
        changed = true
    end

    imgui.Separator()
    imgui.TextUnformatted('Event Buttons')
    local B = cfg.button_style or {}

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
    bpicker('Active bg', 'selected_bg')
    bpicker('Active border color', 'selected_border')
    bpicker('Active text', 'selected_text')
    bpicker('Idle bg', 'idle_bg')
    bpicker('Idle border color', 'idle_border')
    bpicker('Idle text', 'idle_text')

    imgui.TextDisabled('Preview')
    do
        local bs_prev = B
        local function draw_preview_button(id, label, selected, accent)
            local base = selected and bs_prev.selected_bg or bs_prev.idle_bg
            local hovered = tint_rgba(base, 1.10, 0.03)
            local active = tint_rgba(base, 0.86, 0.00)

            local border = selected and mix_rgba(bs_prev.selected_border, accent, 0.65) or bs_prev.idle_border
            local text_col = selected and mix_rgba(bs_prev.selected_text, accent, 0.75) or bs_prev.idle_text
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

        draw_preview_button('dyna_sel', 'Dynamis', true, C.ITEM or DEFAULT_COLORS.ITEM)
        imgui.SameLine()
        draw_preview_button('lim_sel', 'Limbus', true, C.HUNDO or DEFAULT_COLORS.HUNDO)
        imgui.SameLine()
        draw_preview_button('idle', 'Idle', false, C.ITEM or DEFAULT_COLORS.ITEM)
    end

    if imgui.SmallButton('Reset button style') then
        for k, v in pairs(DEFAULT_BUTTON_STYLE) do
            if type(v) == 'table' then
                B[k] = copy_rgba(v)
            else
                B[k] = v
            end
        end
        changed = true
    end
    cfg.button_style = B

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
    local migrated_palette = false
    for k, v in pairs(DEFAULT_COLORS) do
        if not cfg.colors[k] then
            cfg.colors[k] = { table.unpack(v) }
            migrated_palette = true
        end
    end
    if rgba_equals(cfg.colors.CUR, LEGACY_CUR_DEFAULT) then
        cfg.colors.CUR = copy_rgba(DEFAULT_COLORS.HUNDO)
        migrated_palette = true
    end
    if rgba_equals(cfg.colors.ITEM, LEGACY_ITEM_DEFAULT) then
        cfg.colors.ITEM = copy_rgba(DEFAULT_COLORS.ITEM)
        migrated_palette = true
    end
    cfg.visual_colors = cfg.visual_colors or {}
    for k, v in pairs(DEFAULT_VISUAL_COLORS) do
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
    cfg.button_style.selected_text = sanitize_rgba(cfg.button_style.selected_text, DEFAULT_BUTTON_STYLE.selected_text)
    cfg.button_style.idle_bg = sanitize_rgba(cfg.button_style.idle_bg, DEFAULT_BUTTON_STYLE.idle_bg)
    cfg.button_style.idle_border = sanitize_rgba(cfg.button_style.idle_border, DEFAULT_BUTTON_STYLE.idle_border)
    cfg.button_style.idle_text = sanitize_rgba(cfg.button_style.idle_text, DEFAULT_BUTTON_STYLE.idle_text)
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
    end

    imgui.SetNextWindowBgAlpha(cfg.alpha)
    local pushed_window_bg = 0
    if COL_WINDOW_BG ~= nil then
        local win_bg = copy_rgba(cfg.visual_colors.WINDOW_BG or DEFAULT_VISUAL_COLORS.WINDOW_BG)
        win_bg[4] = clamp_num((tonumber(win_bg[4]) or 1.0) * (tonumber(cfg.alpha) or 1.0), 0.0, 1.0, 0.94)
        imgui.PushStyleColor(COL_WINDOW_BG, win_bg)
        pushed_window_bg = 1
    end

    if not imgui.Begin('Treasure', false, window_flags) then
        imgui.End()
        if pushed_window_bg > 0 then
            imgui.PopStyleColor(pushed_window_bg)
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
        if pushed_window_bg > 0 then
            imgui.PopStyleColor(pushed_window_bg)
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

        if not ui.compact then
            local event_id = tostring(ui.selected_event or zone_event)
            local event_name = (event_id == 'limbus' and 'Limbus')
                    or (event_id == 'dynamis' and 'Dynamis')
                    or title(event_id)
            local title = 'Treasure - ' .. tostring(event_name)
            local header_h = 28
            local bs = cfg.button_style or DEFAULT_BUTTON_STYLE
            local accent = (event_id == 'limbus') and (C.HUNDO or DEFAULT_COLORS.HUNDO) or (C.ITEM or DEFAULT_COLORS.ITEM)

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
                    local border = is_selected and mix_rgba(bs.selected_border, accent, 0.65) or bs.idle_border
                    local text_col = is_selected and mix_rgba(bs.selected_text, accent, 0.75) or bs.idle_text
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
                    ui._layout_mode = ''
                    ui._last_compact_count = nil
                    ui._last_compact_height = nil
                    ui._top_area = nil
                    mode_toggled = true
                    ui.history_idx = 0
                    ui.history_session = nil
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
                local accent = (id == 'limbus') and (C.HUNDO or DEFAULT_COLORS.HUNDO) or (C.ITEM or DEFAULT_COLORS.ITEM)
                local base, hovered, active, border, text_col
                if selected then
                    base = bs.selected_bg
                    hovered = tint_rgba(base, 1.10, 0.03)
                    active = tint_rgba(base, 0.86, 0.00)
                    border = mix_rgba(bs.selected_border, accent, 0.65)
                    text_col = mix_rgba(bs.selected_text, accent, 0.75)
                else
                    base = bs.idle_bg
                    hovered = tint_rgba(base, 1.12, 0.03)
                    active = tint_rgba(base, 0.88, 0.00)
                    border = bs.idle_border
                    text_col = bs.idle_text
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
                    ui.history_session = nil
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
                    imgui.TextColored(cfg.visual_colors.HUD_TEXT, clean_t)
                    imgui.SameLine()
                    local gate_open = (sess and sess.limbus_gate_ready == true)
                    local ok_icon, drew_icon = pcall(draw_gate_icon, gate_open, 14)
                    if not (ok_icon and drew_icon) then
                        local ok_col = cfg.visual_colors.STATE_OK or DEFAULT_VISUAL_COLORS.STATE_OK
                        local txt_col = cfg.visual_colors.HUD_TEXT or DEFAULT_VISUAL_COLORS.HUD_TEXT
                        imgui.TextColored(gate_open and ok_col or txt_col, gate_open and 'Open' or 'Closed')
                    end
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
        if pushed_window_bg > 0 then
            imgui.PopStyleColor(pushed_window_bg)
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
        if pushed_window_bg > 0 then
            imgui.PopStyleColor(pushed_window_bg)
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
                ui.history_session = nil
            end
            local files = store.list_sessions({ event_id = history_event }) or {}
            if #files > 0 then
                -- Etiqueta que muestra la selección actual. la opción 0 representa
                -- el estado actual.
                local preview
                if ui.history_idx > 0 and ui.history_idx <= #files then
                    preview = files[ui.history_idx]
                else
                    preview = 'Current'
                end

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
                if imgui.BeginCombo('##history_combo', preview) then
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
    local event_ctx = {
        imgui = imgui,
        ui = ui,
        sess = sess,
        event_id = ui.selected_event or (sess and sess.event_id) or ui.active_event,
        cfg = cfg,
        C = C,
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
        chip_color_for_item = function(name)
            return chip_color_for_item(name, cfg)
        end,
        draw_treasure_table = draw_treasure_table,
        draw_settings_panel = draw_settings_panel,
    }

    local tab_style_colors, tab_style_vars = push_tabs_style(event_ctx.event_id, cfg, C)
    event_router.render(ui, event_ctx)
    if tab_style_vars and tab_style_vars > 0 then
        imgui.PopStyleVar(tab_style_vars)
    end
    if tab_style_colors and tab_style_colors > 0 then
        imgui.PopStyleColor(tab_style_colors)
    end

    imgui.End()
    if pushed_window_bg > 0 then
        imgui.PopStyleColor(pushed_window_bg)
    end
    if pushed_style > 0 then
        imgui.PopStyleVar(pushed_style)
    end
    if pushed_theme > 0 then
        imgui.PopStyleColor(pushed_theme)
    end
end

return ui
