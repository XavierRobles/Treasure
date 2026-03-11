---------------------------------------------------------------------------
-- Treasure · ui_event_limbus.lua · Waky
---------------------------------------------------------------------------

local ui_limbus = {}
local bit = require('bit')
local TRANSITION_PENDING_SECONDS = 6
local rm = AshitaCore:GetResourceManager()

local KEY_ITEMS = {
    { label = 'Cosmo-Cleanse', names = { 'Cosmo-Cleanse', 'Cosmo Cleanse' }, fallback_id = 734 },
    { label = 'Red Card',      names = { 'Red Card' } },
    { label = 'Black Card',    names = { 'Black Card' } },
    { label = 'White Card',    names = { 'White Card' } },
}

local cached_ki_ids = {}

local function is_coin_name(name)
    local s = tostring(name or '')
            :gsub('%c', '')
            :lower()
            :gsub('%s+', ' ')
            :gsub('^%s+', '')
            :gsub('%s+$', '')
    if s == '' then
        return false
    end
    return (s == 'ancient beastcoin')
            or (s == 'anc. beastcoin')
            or (s == 'anc beastcoin')
            or (s == 'anct. beastcoin')
            or (s == 'anct beastcoin')
end

local function limbus_item_color(item_name, C, chip_color_for_item)
    if is_coin_name(item_name) then
        return C.CUR
    end

    if chip_color_for_item then
        local custom_chip = chip_color_for_item(item_name)
        if custom_chip then
            return custom_chip
        end
    end
    return C.ITEM
end

local function fmt_hms(total_seconds)
    local s = math.max(0, tonumber(total_seconds) or 0)
    local h = math.floor(s / 3600)
    s = s - (h * 3600)
    local m = math.floor(s / 60)
    s = s - (m * 60)
    return string.format('%02d:%02d:%02d', h, m, s)
end

local function limbus_time_left_text(sess)
    if not (sess and sess.limbus_timer) then
        return nil
    end
    if sess.limbus_run_started ~= true then
        return nil
    end

    local now = os.time()
    local end_at = tonumber(sess.limbus_timer.end_at)
    local fallback_end = tonumber(sess.limbus_timer.fallback_end_at)

    if not fallback_end then
        local base = tonumber(sess.limbus_timer.base_minutes) or 30
        fallback_end = (tonumber(sess.start_time) or now) + (base * 60)
        sess.limbus_timer.fallback_end_at = fallback_end
    end

    local rem
    if end_at then
        rem = end_at - now
        if rem <= 0 then
            sess.limbus_timer.desynced = true
            rem = fallback_end - now
        end
    else
        rem = fallback_end - now
    end

    local prefix = (sess.limbus_timer.desynced and '~ ' or '')
    return prefix .. fmt_hms(rem)
end

local function limbus_gate_state(sess)
    if not sess then
        return false, 0, 0
    end

    local opens = math.max(0, tonumber(sess.limbus_gate_count) or 0)
    local ready = (sess.limbus_gate_ready == true)
    return ready, 0, opens
end

local function limbus_floor_state(sess)
    local floor = math.max(1, tonumber(sess and sess.limbus_floor) or 1)
    local pending = (sess and sess.limbus_transition_pending == true)
    if pending then
        local at = tonumber(sess and sess.limbus_transition_pending_at) or 0
        if (at <= 0) or ((os.time() - at) > TRANSITION_PENDING_SECONDS) then
            pending = false
        end
    end
    return floor, pending
end

local function limbus_door_label(sess)
    local zid = tonumber(sess and sess.zone_id) or 0
    if zid == 38 then
        return 'Vortex'
    end
    if zid == 37 then
        return 'Gate'
    end

    local name = rm and rm:GetString('zones.names', zid) or ''
    name = tostring(name or ''):lower()
    if name:find('apollyon', 1, true) then
        return 'Vortex'
    end
    if name:find('temenos', 1, true) then
        return 'Gate'
    end
    return 'Door'
end

local function limbus_floor_cap(sess)
    local n = tonumber(sess and sess.limbus_max_floor)
    if not n or n < 1 then
        return nil
    end
    return math.floor(n)
end

local function limbus_chip_name(sess)
    local s = tostring(sess and sess.limbus_reward_chip or '')
    if s == '' then
        return nil
    end
    return s
end

local function limbus_is_chip_phase(sess)
    if not sess then
        return false
    end
    local cap = limbus_floor_cap(sess)
    local chip = limbus_chip_name(sess)
    local floor = math.max(1, tonumber(sess.limbus_floor) or 1)
    return (cap ~= nil and chip ~= nil and floor >= cap)
end

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

local function limbus_sw_element_key(sess)
    if tostring(sess and sess.limbus_path_id or '') ~= 'apollyon_south_west' then
        return nil
    end
    local k = tostring(sess and sess.limbus_sw_day_element or ''):lower()
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

local function limbus_sw_element_label(sess)
    local key = limbus_sw_element_key(sess)
    if not key then
        return nil
    end
    return ELEMENT_LABELS[key]
end

local function limbus_gunpod_status(sess)
    local gp = sess and sess.limbus_gunpod
    local max_spawns = math.max(1, tonumber(gp and gp.max_spawns) or 5)
    local total_spawns = math.max(0, tonumber(gp and gp.total_spawns) or 0)
    if total_spawns > max_spawns then
        max_spawns = total_spawns
    end
    local active_count = math.max(0, tonumber(gp and gp.active_count) or 0)
    local active_hp = tonumber(gp and gp.active_hp) or nil
    if active_hp then
        if active_hp < 0 then
            active_hp = 0
        elseif active_hp > 100 then
            active_hp = 100
        end
    end
    return {
        max_spawns = max_spawns,
        total_spawns = total_spawns,
        active_count = active_count,
        active_hp = active_hp,
    }
end

local function collect_player_names(sess, keys, is_valid_player_name)
    local out = {}
    for _, p in ipairs(keys(sess and sess.drops and sess.drops.by_player or {})) do
        if is_valid_player_name(p) then
            out[#out + 1] = p
        end
    end
    return out
end

local function aggregate_items(sess, keys, want_coin, item_ok)
    local acc = {}
    local by_player = sess and sess.drops and sess.drops.by_player or {}
    local allow = item_ok or function()
        return true
    end
    for _, pl in ipairs(keys(by_player)) do
        local bag = by_player[pl] or {}
        for _, it in ipairs(keys(bag)) do
            local qty = tonumber(bag[it]) or 0
            local is_coin = is_coin_name(it)
            if qty > 0 and allow(it) and ((want_coin and is_coin) or ((not want_coin) and (not is_coin))) then
                acc[it] = (acc[it] or 0) + qty
            end
        end
    end
    return acc
end

local function aggregate_lost(sess, keys, lost_name, want_coin, item_ok)
    local allow = item_ok or function()
        return true
    end
    local lost = sess and sess.drops and sess.drops.lost_total
    if type(lost) == 'table' then
        local out = {}
        for _, it in ipairs(keys(lost)) do
            local is_coin = is_coin_name(it)
            if allow(it) and ((want_coin and is_coin) or ((not want_coin) and (not is_coin))) then
                out[it] = tonumber(lost[it]) or 0
            end
        end
        return out
    end

    local out = {}
    for _, ln in ipairs((sess and sess.drops and sess.drops.lost) or {}) do
        local it = lost_name(ln)
        local is_coin = is_coin_name(it)
        if allow(it) and ((want_coin and is_coin) or ((not want_coin) and (not is_coin))) then
            out[it] = (out[it] or 0) + 1
        end
    end
    return out
end

local function split_participants(sess, keys, is_valid_player_name)
    local out = {}
    local seen = {}

    local locked = sess and sess.limbus_start_participants
    if type(locked) == 'table' then
        for name in pairs(locked) do
            if is_valid_player_name(name) then
                seen[name] = true
            end
        end
    end

    if next(seen) == nil then
        for _, name in ipairs(keys(sess and sess.participants or {})) do
            if is_valid_player_name(name) then
                seen[name] = true
            end
        end
    end

    if next(seen) == nil then
        for _, name in ipairs(keys(sess and sess.drops and sess.drops.by_player or {})) do
            if is_valid_player_name(name) then
                seen[name] = true
            end
        end
    end

    for name in pairs(seen) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

local function resolve_key_item_id(entry)
    local key = entry.label
    if cached_ki_ids[key] ~= nil then
        return cached_ki_ids[key]
    end

    local rm = AshitaCore:GetResourceManager()
    local found = nil
    for _, name in ipairs(entry.names or {}) do
        local id = rm and rm:GetString('keyitems.names', name, 2)
        if type(id) == 'number' and id > 0 then
            found = id
            break
        end
    end

    if not found then
        found = tonumber(entry.fallback_id) or -1
    end

    cached_ki_ids[key] = found
    return found
end

local function has_key_item(id)
    id = tonumber(id) or -1
    if id <= 0 then
        return nil
    end
    local pm = AshitaCore:GetMemoryManager():GetPlayer()
    if not (pm and pm.HasKeyItem) then
        return nil
    end
    return pm:HasKeyItem(id) == true
end

function ui_limbus.top_left_status(ctx)
    local sess = ctx and ctx.sess
    local run_active = (sess and sess.is_event and sess.limbus_run_started == true and sess.limbus_run_ended ~= true)
    if not run_active then
        return nil
    end
    local t = limbus_time_left_text(sess)
    local floor = limbus_floor_state(sess)
    local floor_txt = 'Floor ' .. tostring(floor)
    local tail = nil

    if limbus_is_chip_phase(sess) then
        local chip = limbus_chip_name(sess) or 'Chip'
        tail = floor_txt .. ' | ' .. chip
    elseif tostring(sess and sess.limbus_path_id or '') == 'apollyon_central' then
        local gp = limbus_gunpod_status(sess)
        tail = 'Gunpod ' .. tostring(gp.total_spawns) .. '/' .. tostring(gp.max_spawns)
    else
        local door_label = limbus_door_label(sess)
        tail = floor_txt .. ' | ' .. door_label
    end

    if t and t ~= '' then
        return t .. ' | ' .. tail
    end
    return '--:--:-- | ' .. tail
end

function ui_limbus.render(ctx)
    local imgui = ctx.imgui
    local ui = ctx.ui
    local sess = ctx.sess
    local cfg = ctx.cfg
    local C = ctx.C
    local get_event_loot_colors = ctx.event_loot_colors
    if type(get_event_loot_colors) == 'function' then
        C = get_event_loot_colors('limbus') or C
    end
    local V = ctx.V or {}
    local TF_BORDER = ctx.TF_BORDER
    local keys = ctx.keys
    local title = ctx.title
    local lost_name = ctx.lost_name
    local is_valid_player_name = ctx.is_valid_player_name
    local fmt_n = ctx.fmt_n
    local store = ctx.store
    local chip_color_for_item = ctx.chip_color_for_item
    local draw_styled_hp_progress = ctx.draw_styled_hp_progress
    local draw_chip_icon = ctx.draw_chip_icon
    local draw_element_icon = ctx.draw_element_icon
    local draw_keyitem_status_icon = ctx.draw_keyitem_status_icon
    local draw_treasure_table = ctx.draw_treasure_table
    local draw_settings_panel = ctx.draw_settings_panel
    local item_matches_event = ctx.item_matches_event or function()
        return true
    end
    local sess_event = tostring((sess and sess.event_id) or ''):lower()
    local function limbus_item_ok(name)
        if sess_event == 'limbus' then
            return true
        end
        return item_matches_event(name, 'limbus')
    end
    local gate_ready = limbus_gate_state(sess)
    local floor_now, floor_pending = limbus_floor_state(sess)
    local run_started = (sess and sess.is_event and sess.limbus_run_started == true and sess.limbus_run_ended ~= true)
    local door_label = limbus_door_label(sess)
    local state_ok = V.STATE_OK or { 0.20, 0.85, 0.20, 1.0 }
    local state_alert = V.STATE_ALERT or { 0.95, 0.30, 0.30, 1.0 }

    if (not ui.compact) and run_started then
        local chip_phase = limbus_is_chip_phase(sess)
        local floor_cap = limbus_floor_cap(sess)
        if tostring(sess and sess.limbus_path_id or '') == 'apollyon_central' then
            local gp = limbus_gunpod_status(sess)
            imgui.TextColored(state_ok, 'Gunpod ' .. tostring(gp.total_spawns) .. '/' .. tostring(gp.max_spawns))
            if gp.active_count > 1 then
                imgui.SameLine()
                imgui.TextDisabled('Active: ' .. tostring(gp.active_count))
            end
            if gp.active_hp ~= nil then
                imgui.SameLine()
                local hp_frac = math.max(0.0, math.min(1.0, (tonumber(gp.active_hp) or 0) / 100.0))
                if type(draw_styled_hp_progress) == 'function' then
                    draw_styled_hp_progress(hp_frac, { 170, 14 }, V.HUD_TEXT)
                else
                    imgui.ProgressBar(hp_frac, { 170, 14 })
                    imgui.SameLine()
                    imgui.TextDisabled(string.format('%d%%%%', math.floor((gp.active_hp or 0) + 0.5)))
                end
            else
                imgui.SameLine()
                imgui.TextDisabled('No active Gunpod')
            end
        elseif chip_phase then
            local chip_name = limbus_chip_name(sess) or 'Chip'
            local chip_col = limbus_item_color(chip_name, C, chip_color_for_item)
            local chip_key = tostring(sess and sess.limbus_reward_chip_key or '')
            local sw_element_key = limbus_sw_element_key(sess)
            if chip_key == '' then
                chip_key = nil
            end
            local drew_chip_icon = false
            local icon_size = math.max(14, math.floor(((tonumber(cfg.limbus_icon_size) or 28) * 0.72) + 0.5))
            if type(draw_chip_icon) == 'function' then
                local ok_chip, icon_res = pcall(draw_chip_icon, chip_name, chip_key, icon_size, chip_col)
                drew_chip_icon = (ok_chip and icon_res == true)
            end
            if drew_chip_icon then
                imgui.SameLine()
                imgui.TextColored(chip_col, chip_name)
            else
                imgui.TextColored(chip_col, '[C] ' .. chip_name)
            end
            if sw_element_key ~= nil then
                imgui.SameLine()
                if type(draw_element_icon) == 'function' then
                    pcall(draw_element_icon, sw_element_key, icon_size, { 1, 1, 1, 1 })
                end
            end
            imgui.SameLine()
            if floor_cap and floor_cap > 0 then
                imgui.TextDisabled('Floor: ' .. tostring(floor_now) .. '/' .. tostring(floor_cap))
            else
                imgui.TextDisabled('Floor: ' .. tostring(floor_now))
            end
        else
            local is_transition = (sess and sess.limbus_transition_pending == true) or floor_pending
            if is_transition then
                imgui.TextDisabled(door_label .. ' TRANSITION')
            elseif gate_ready then
                imgui.TextColored(state_ok, door_label .. ' OPEN - You can go up now.')
            else
                imgui.TextColored(state_alert, door_label .. ' CLOSED')
            end
            imgui.SameLine()
            if floor_cap and floor_cap > 0 then
                imgui.TextDisabled('Floor: ' .. tostring(floor_now) .. '/' .. tostring(floor_cap) .. (floor_pending and ' (transitioning...)' or ''))
            else
                imgui.TextDisabled('Floor: ' .. tostring(floor_now) .. (floor_pending and ' (transitioning...)' or ''))
            end
        end
        imgui.Separator()
    end

    if imgui.BeginTabBar('##edtabs') then
        if ui.compact then
            if imgui.BeginTabItem('Treasure') then
                draw_treasure_table(sess, C, cfg, 'limbus')
                imgui.EndTabItem()
            end
        else
            if imgui.BeginTabItem('All') then
                local totals_coin = aggregate_items(sess, keys, true, limbus_item_ok)
                local totals_item = aggregate_items(sess, keys, false, limbus_item_ok)
                local lost_coin = aggregate_lost(sess, keys, lost_name, true, limbus_item_ok)
                local lost_item = aggregate_lost(sess, keys, lost_name, false, limbus_item_ok)

                local acc = {}
                local function merge_into(map, field)
                    for _, n in ipairs(keys(map)) do
                        local v = tonumber(map[n]) or 0
                        if v > 0 then
                            local row = acc[n] or { q = 0, l = 0 }
                            row[field] = (row[field] or 0) + v
                            acc[n] = row
                        end
                    end
                end
                merge_into(totals_coin, 'q')
                merge_into(totals_item, 'q')
                merge_into(lost_coin, 'l')
                merge_into(lost_item, 'l')

                if imgui.BeginTable('tbl_limbus_all', 4, TF_BORDER) then
                    imgui.TableSetupColumn('Item')
                    imgui.TableSetupColumn('Qty')
                    imgui.TableSetupColumn('Total')
                    imgui.TableSetupColumn('Lost')
                    imgui.TableHeadersRow()

                    local printed = false
                    for _, n in ipairs(keys(acc)) do
                        local row = acc[n] or { q = 0, l = 0 }
                        local qty = tonumber(row.q) or 0
                        local lost = tonumber(row.l) or 0
                        if qty > 0 or lost > 0 then
                            printed = true
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(limbus_item_color(n, C, chip_color_for_item), title(n))
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.QTY, tostring(qty))
                            imgui.TableSetColumnIndex(2)
                            imgui.TextColored(C.QTY, tostring(qty + lost))
                            imgui.TableSetColumnIndex(3)
                            if lost > 0 then
                                imgui.TextColored(C.LOST, tostring(lost))
                            end
                        end
                    end

                    if not printed then
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextDisabled('No drops recorded.')
                    end

                    imgui.EndTable()
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Coins') then
                local totals = aggregate_items(sess, keys, true, limbus_item_ok)
                local lost = aggregate_lost(sess, keys, lost_name, true, limbus_item_ok)

                if imgui.BeginTable('tbl_limbus_coins', 4, TF_BORDER) then
                    imgui.TableSetupColumn('Coin')
                    imgui.TableSetupColumn('Qty')
                    imgui.TableSetupColumn('Total')
                    imgui.TableSetupColumn('Lost')
                    imgui.TableHeadersRow()

                    local printed = false
                    local names = {}
                    for _, n in ipairs(keys(totals)) do names[#names + 1] = n end
                    for _, n in ipairs(keys(lost)) do
                        if totals[n] == nil then
                            names[#names + 1] = n
                        end
                    end
                    table.sort(names)

                    for _, n in ipairs(names) do
                        local qty = tonumber(totals[n]) or 0
                        local lst = tonumber(lost[n]) or 0
                        if qty > 0 or lst > 0 then
                            printed = true
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(C.CUR, title(n))
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

                    if not printed then
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextDisabled('No coins recorded.')
                    end

                    imgui.EndTable()
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Items') then
                local totals = aggregate_items(sess, keys, false, limbus_item_ok)
                local lost = aggregate_lost(sess, keys, lost_name, false, limbus_item_ok)

                if imgui.BeginTable('tbl_limbus_items', 4, TF_BORDER) then
                    imgui.TableSetupColumn('Item')
                    imgui.TableSetupColumn('Qty')
                    imgui.TableSetupColumn('Total')
                    imgui.TableSetupColumn('Lost')
                    imgui.TableHeadersRow()

                    local printed = false
                    local names = {}
                    for _, n in ipairs(keys(totals)) do names[#names + 1] = n end
                    for _, n in ipairs(keys(lost)) do
                        if totals[n] == nil then
                            names[#names + 1] = n
                        end
                    end
                    table.sort(names)

                    for _, n in ipairs(names) do
                        local qty = tonumber(totals[n]) or 0
                        local lst = tonumber(lost[n]) or 0
                        if qty > 0 or lst > 0 then
                            printed = true
                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextColored(limbus_item_color(n, C, chip_color_for_item), title(n))
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

                    if not printed then
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextDisabled('No items recorded.')
                    end

                    imgui.EndTable()
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Players') then
                local plist = {}
                do
                    local by_player = sess and sess.drops and sess.drops.by_player or {}
                    for _, p in ipairs(collect_player_names(sess, keys, is_valid_player_name)) do
                        local bag = by_player[p] or {}
                        local include = false
                        for _, it in ipairs(keys(bag)) do
                            if limbus_item_ok(it) and (tonumber(bag[it]) or 0) > 0 then
                                include = true
                                break
                            end
                        end
                        if include then
                            plist[#plist + 1] = p
                        end
                    end
                end

                local vv = { ui.players_currency_only == true }
                if imgui.Checkbox('Coins only', vv) then
                    ui.players_currency_only = vv[1]
                end

                local preview = (ui.filter == 'All') and 'All players' or ui.filter
                imgui.SameLine()
                imgui.PushItemWidth(180)
                if imgui.BeginCombo('##limbus_show_player', preview) then
                    if imgui.Selectable('All players', ui.filter == 'All') then
                        ui.filter = 'All'
                    end
                    for _, p in ipairs(plist) do
                        if imgui.Selectable(p, ui.filter == p) then
                            ui.filter = p
                        end
                    end
                    imgui.EndCombo()
                end
                imgui.PopItemWidth()

                imgui.Separator()
                local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                local by_player = sess and sess.drops and sess.drops.by_player or {}

                local function show_item(it)
                    if not limbus_item_ok(it) then
                        return false
                    end
                    if not ui.players_currency_only then
                        return true
                    end
                    return is_coin_name(it)
                end

                local function rows_for_player(pl)
                    local rows = {}
                    for _, it in ipairs(keys(by_player[pl] or {})) do
                        if show_item(it) then
                            local qty = tonumber((by_player[pl] or {})[it]) or 0
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
                        local rows = rows_for_player(pl)
                        if #rows > 0 then
                            printed_any = true
                            if imgui.BeginTable('tbl_limbus_players_' .. pl, 3, TFLAGS) then
                                imgui.TableSetupColumn('Player')
                                imgui.TableSetupColumn('Item')
                                imgui.TableSetupColumn('Qty')
                                imgui.TableHeadersRow()
                                for _, r in ipairs(rows) do
                                    imgui.TableNextRow()
                                    imgui.TableSetColumnIndex(0)
                                    imgui.TextColored(C.NAME, pl)
                                    imgui.TableSetColumnIndex(1)
                                    imgui.TextColored(limbus_item_color(r.item, C, chip_color_for_item), title(r.item))
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
                    local rows = rows_for_player(pl)
                    if #rows == 0 then
                        imgui.TextDisabled('No items to show for this player.')
                    else
                        if imgui.BeginTable('tbl_limbus_players_single', 3, TFLAGS) then
                            imgui.TableSetupColumn('Player')
                            imgui.TableSetupColumn('Item')
                            imgui.TableSetupColumn('Qty')
                            imgui.TableHeadersRow()
                            for _, r in ipairs(rows) do
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.NAME, pl)
                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(limbus_item_color(r.item, C, chip_color_for_item), title(r.item))
                                imgui.TableSetColumnIndex(2)
                                imgui.TextColored(C.QTY, tostring(r.qty))
                            end
                            imgui.EndTable()
                        end
                    end
                end

                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Key Items') then
                if imgui.BeginTable('tbl_limbus_ki', 2, TF_BORDER) then
                    imgui.TableSetupColumn('Key Item')
                    imgui.TableSetupColumn('Status')
                    imgui.TableHeadersRow()

                    for _, ki in ipairs(KEY_ITEMS) do
                        local id = resolve_key_item_id(ki)
                        local have = has_key_item(id)
                        imgui.TableNextRow()
                        imgui.TableSetColumnIndex(0)
                        imgui.TextColored(C.ITEM, ki.label)
                        imgui.TableSetColumnIndex(1)
                        local drew_status_icon = false
                        if type(draw_keyitem_status_icon) == 'function' then
                            local ok_icon, icon_res = pcall(draw_keyitem_status_icon, have == true, 28)
                            drew_status_icon = (ok_icon and icon_res == true)
                        end
                        if not drew_status_icon then
                            if have == true then
                                imgui.TextColored(state_ok, '[v]')
                            else
                                imgui.TextColored(state_alert, '[X]')
                            end
                        end
                    end

                    imgui.EndTable()
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Treasure') then
                draw_treasure_table(sess, C, cfg, 'limbus')
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Management') then
                if not (sess and sess.is_event) then
                    imgui.TextDisabled('No active event.')
                else
                    sess.management = sess.management or {}
                    sess.limbus_split = sess.limbus_split or {}

                    local plist = split_participants(sess, keys, is_valid_player_name)

                    if #plist == 0 then
                        imgui.TextDisabled('No participants available for split.')
                    else
                        if imgui.SmallButton('Include all') then
                            for _, pl in ipairs(plist) do
                                local m = sess.management[pl] or {}
                                m.include = true
                                m.currency_delivered = (m.currency_delivered == true)
                                sess.management[pl] = m
                            end
                            if store and sess and sess.is_event then
                                store.save(sess)
                            end
                        end
                        imgui.SameLine()
                        if imgui.SmallButton('Exclude all') then
                            for _, pl in ipairs(plist) do
                                local m = sess.management[pl] or {}
                                m.include = false
                                m.currency_delivered = (m.currency_delivered == true)
                                sess.management[pl] = m
                            end
                            if store and sess and sess.is_event then
                                store.save(sess)
                            end
                        end

                        imgui.Separator()

                        local TFLAGS = bit.bor(TF_BORDER, imgui.TableFlags_Resizable or 0)
                        if imgui.BeginTable('tbl_limbus_manage', 3, TFLAGS) then
                            imgui.TableSetupColumn('Name')
                            imgui.TableSetupColumn('Include')
                            imgui.TableSetupColumn('Coins delivered')
                            imgui.TableHeadersRow()

                            for _, pl in ipairs(plist) do
                                local m = sess.management[pl]
                                if m == nil then
                                    m = {
                                        include = true,
                                        currency_delivered = false,
                                    }
                                    sess.management[pl] = m
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                                if m.include == nil then
                                    m.include = true
                                end
                                if m.currency_delivered == nil then
                                    m.currency_delivered = false
                                end

                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.NAME, pl)

                                imgui.TableSetColumnIndex(1)
                                do
                                    local v = { m.include == true }
                                    if imgui.Checkbox('##lim_inc_' .. pl, v) then
                                        m.include = v[1]
                                        if store and sess and sess.is_event then
                                            store.save(sess)
                                        end
                                    end
                                end

                                imgui.TableSetColumnIndex(2)
                                do
                                    local v = { m.currency_delivered == true }
                                    if imgui.Checkbox('##lim_del_' .. pl, v) then
                                        m.currency_delivered = v[1]
                                        if store and sess and sess.is_event then
                                            store.save(sess)
                                        end
                                    end
                                end
                            end

                            imgui.EndTable()
                        end

                        imgui.Separator()

                        local totals = aggregate_items(sess, keys, true, limbus_item_ok)
                        local coin_names = keys(totals)
                        local included = {}
                        for _, pl in ipairs(plist) do
                            local m = sess.management[pl] or {}
                            if m.include ~= false then
                                included[#included + 1] = pl
                            end
                        end

                        if #coin_names == 0 then
                            imgui.TextDisabled('No coins recorded yet.')
                        elseif #included == 0 then
                            imgui.TextDisabled('No included players for split.')
                        else
                            local per_player = {}
                            local remainder = {}

                            for _, pl in ipairs(plist) do
                                per_player[pl] = { by_coin = {}, total = 0 }
                            end

                            for _, coin in ipairs(coin_names) do
                                local total = tonumber(totals[coin]) or 0
                                local each = math.floor(total / #included)
                                local used = each * #included
                                remainder[coin] = total - used

                                for _, pl in ipairs(included) do
                                    local row = per_player[pl]
                                    row.by_coin[coin] = each
                                    row.total = row.total + each
                                end
                            end

                            imgui.TextUnformatted('Split')
                            local cols = 2 + #coin_names
                            if imgui.BeginTable('tbl_limbus_split', cols, TF_BORDER) then
                                imgui.TableSetupColumn('Player')
                                for _, coin in ipairs(coin_names) do
                                    imgui.TableSetupColumn(title(coin))
                                end
                                imgui.TableSetupColumn('Total')
                                imgui.TableHeadersRow()

                                for _, pl in ipairs(plist) do
                                    local row = per_player[pl]
                                    imgui.TableNextRow()
                                    imgui.TableSetColumnIndex(0)
                                    imgui.TextColored(C.NAME, pl)

                                    local col = 1
                                    for _, coin in ipairs(coin_names) do
                                        imgui.TableSetColumnIndex(col)
                                        imgui.TextColored(C.QTY, tostring(tonumber(row.by_coin[coin]) or 0))
                                        col = col + 1
                                    end

                                    imgui.TableSetColumnIndex(col)
                                    imgui.TextColored(C.QTY, fmt_n(tonumber(row.total) or 0))
                                end

                                imgui.EndTable()
                            end

                            imgui.Separator()
                            imgui.TextUnformatted('Remainder')
                            if imgui.BeginTable('tbl_limbus_remainder', 2, TF_BORDER) then
                                imgui.TableSetupColumn('Coin')
                                imgui.TableSetupColumn('Units')
                                imgui.TableHeadersRow()

                                for _, coin in ipairs(coin_names) do
                                    local rem = tonumber(remainder[coin]) or 0
                                    imgui.TableNextRow()
                                    imgui.TableSetColumnIndex(0)
                                    imgui.TextColored(C.CUR, title(coin))
                                    imgui.TableSetColumnIndex(1)
                                    imgui.TextColored(rem > 0 and C.LOST or C.QTY, tostring(rem))
                                end

                                imgui.EndTable()
                            end
                        end
                    end
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Settings') then
                draw_settings_panel(cfg, C, ctx.event_id or 'limbus')
                imgui.EndTabItem()
            end
        end

        imgui.EndTabBar()
    end
end

return ui_limbus
