---------------------------------------------------------------------------
-- Treasure · ui_event_dynamis.lua · Waky
---------------------------------------------------------------------------

local core = require('core')
local dynamis = {}

local function fmt_hms(total_seconds)
    local s = math.max(0, tonumber(total_seconds) or 0)
    local h = math.floor(s / 3600)
    s = s - (h * 3600)
    local m = math.floor(s / 60)
    s = s - (m * 60)
    return string.format('%02d:%02d:%02d', h, m, s)
end

local function dynamis_time_left_text(sess)
    if not (sess and sess.dynamis_timer) then
        return nil
    end

    local now = os.time()
    local expel_at = tonumber(sess.dynamis_timer.expel_at)
    local fallback_end = tonumber(sess.dynamis_timer.fallback_end_at)

    if not fallback_end then
        local max_min = core.dynamis_max_minutes(sess.zone_id)
        fallback_end = (tonumber(sess.start_time) or now) + (max_min * 60)
        sess.dynamis_timer.fallback_end_at = fallback_end
    end

    local rem
    if expel_at then
        rem = expel_at - now
        if rem <= 0 then
            sess.dynamis_timer.desynced = true
            rem = fallback_end - now
        end
    else
        rem = fallback_end - now
    end

    local prefix = (sess.dynamis_timer.desynced and '~ ' or '')
    return prefix .. fmt_hms(rem)
end

function dynamis.top_left_status(ctx)
    local sess = ctx and ctx.sess
    return dynamis_time_left_text(sess)
end

function dynamis.render(ctx)
    local imgui = ctx.imgui
    local ui = ctx.ui
    local sess = ctx.sess
    local cfg = ctx.cfg
    local C = ctx.C
    local TF_BORDER = ctx.TF_BORDER
    local keys = ctx.keys
    local is_cur = ctx.is_cur
    local is_hundo = ctx.is_hundo
    local title = ctx.title
    local lost_name = ctx.lost_name
    local to_units = ctx.to_units
    local base_cur = ctx.base_cur
    local display_cur = ctx.display_cur
    local is_valid_player_name = ctx.is_valid_player_name
    local default_event_minutes = ctx.default_event_minutes
    local fmt_n = ctx.fmt_n
    local store = ctx.store
    local draw_treasure_table = ctx.draw_treasure_table
    local draw_settings_panel = ctx.draw_settings_panel

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
                local lost_list = sess.drops.lost or {}
                for _, ln in ipairs(lost_list) do
                    local it = lost_name(ln)
                    if it ~= '' then
                        local a = acc[it] or { q = 0, e = 0, l = 0 }
                        a.l = a.l + 1
                        acc[it] = a
                    end
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

                local lost = sess.drops.lost_total or {}
                if not sess.drops.lost_total then
                    lost = {}
                    for _, ln in ipairs(sess.drops.lost or {}) do
                        local it = lost_name(ln)
                        if it ~= '' then
                            lost[it] = (lost[it] or 0) + 1
                        end
                    end
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

                -- Personal THF steal tracker (single block, below Currency table).
                do
                    local sp = (sess.drops and sess.drops.steal_personal) or {}
                    local attempts = tonumber(sp.attempts) or 0

                    if attempts > 0 then
                        local success = tonumber(sp.success) or 0
                        local failed = tonumber(sp.failed) or 0
                        local success_rate = (attempts > 0) and ((success * 100.0) / attempts) or 0.0
                        local by_currency = sp.by_currency or {}
                        local order = {
                            'Tukuku Whiteshell',
                            'Ordelle Bronzepiece',
                            'One Byne Bill',
                        }

                        imgui.Separator()
                        imgui.TextColored(C.ITEM, 'Personal Steal (THF)')

                        if imgui.BeginTable('tbl_cur_steal_info', 2, TF_BORDER) then
                            imgui.TableSetupColumn('Info')
                            imgui.TableSetupColumn('Value')
                            imgui.TableHeadersRow()

                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextUnformatted('Attempts')
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.QTY, tostring(attempts))

                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextUnformatted('Success')
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.QTY, tostring(success))

                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextUnformatted('Failed')
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.LOST, tostring(failed))

                            imgui.TableNextRow()
                            imgui.TableSetColumnIndex(0)
                            imgui.TextUnformatted('Success %')
                            imgui.TableSetColumnIndex(1)
                            imgui.TextColored(C.QTY, string.format('%.1f%%', success_rate))

                            local total_stolen = 0
                            for _, name in ipairs(order) do
                                local qty = tonumber(by_currency[name]) or 0
                                if qty > 0 then
                                    total_stolen = total_stolen + qty

                                    imgui.TableNextRow()
                                    imgui.TableSetColumnIndex(0)
                                    imgui.TextColored(C.CUR, name)
                                    imgui.TableSetColumnIndex(1)
                                    imgui.TextColored(C.QTY, tostring(qty))
                                end
                            end

                            if total_stolen > 0 then
                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.ITEM, 'Total Stolen')
                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(C.QTY, tostring(total_stolen))
                            end

                            imgui.EndTable()
                        end
                    end
                end

                imgui.EndTabItem()
            end


            ---------------------------------------------------------------- PLAYERS
            -- ---------------------------------------------------------------- PLAYERS
            if imgui.BeginTabItem('Players') then
                local plist = {}
                for _, p in ipairs(keys(sess.drops.by_player or {})) do
                    if is_valid_player_name(p) then
                        plist[#plist + 1] = p
                    end
                end


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

                        for _, p in ipairs(plist) do
                            if imgui.Selectable(p, ui.filter == p) then
                                ui.filter = p
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
            if imgui.BeginTabItem('Items') then
                local plist = {}
                for _, p in ipairs(keys(sess.drops.by_player or {})) do
                    if is_valid_player_name(p) then
                        plist[#plist + 1] = p
                    end
                end

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
                for _, ln in ipairs(sess.drops.lost or {}) do
                    local name = lost_name(ln)
                    local tm = '--'
                    if type(ln) == 'table' and ln.time then
                        tm = os.date('%H:%M:%S', ln.time)
                    else
                        tm = tostring(ln):match('^(%d%d:%d%d:%d%d)') or '--'
                    end

                    local col = is_cur(name) and (is_hundo(name) and C.HUNDO or C.CUR) or C.ITEM
                    imgui.TableNextRow()
                    imgui.TableSetColumnIndex(0)
                    imgui.Text(tm)
                    imgui.TableSetColumnIndex(1)
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
                        -- Auto end (default). Will be disabled if user edits End.
                        sess.split._auto_end = true
                        sess.split._auto_end_zone = tonumber(sess.zone_id) or 0

                        local sh = tonumber(sess.split.start_h) or 0
                        local sm = tonumber(sess.split.start_m) or 0
                        local end_minutes = hm_to_minutes(sh, sm) + default_event_minutes(sess)
                        end_minutes = end_minutes % (24 * 60)
                        sess.split.end_h = math.floor(end_minutes / 60)
                        sess.split.end_m = end_minutes - sess.split.end_h * 60
                    end

                    -- Zone id may arrive late. If End is still auto, recompute once when zone becomes valid/changes.
                    do
                        local auto = (sess.split._auto_end == true)
                        local zid = tonumber(sess.zone_id) or 0
                        local lastz = tonumber(sess.split._auto_end_zone) or 0

                        if auto and zid ~= 0 and zid ~= lastz then
                            sess.split._auto_end_zone = zid

                            local sh = tonumber(sess.split.start_h) or 0
                            local sm = tonumber(sess.split.start_m) or 0
                            local end_minutes = hm_to_minutes(sh, sm) + default_event_minutes(sess)
                            end_minutes = end_minutes % (24 * 60)
                            sess.split.end_h = math.floor(end_minutes / 60)
                            sess.split.end_m = end_minutes - sess.split.end_h * 60

                            if store and sess and sess.is_event then
                                store.save(sess)
                            end
                        end
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

                        local sb = style2.ScrollbarSize or 0
                        imgui.SameLine()
                        imgui.SetCursorPosX(win_w2 - sb - total_w - pad2 - 4)

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

                        -- If user edits End, disable auto end for this session (prevents late zone_id from overriding).
                        if (eh ~= old_eh) or (em ~= old_em) then
                            sess.split._auto_end = false
                        end

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
                            if is_valid_player_name(name) then
                                names_set[name] = true
                            end
                        end
                    end
                    if sess.management then
                        for name, _ in pairs(sess.management) do
                            if is_valid_player_name(name) then
                                names_set[name] = true
                            end
                        end
                    end
                    if sess.participants then
                        for name, _ in pairs(sess.participants) do
                            if is_valid_player_name(name) then
                                names_set[name] = true
                            end
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

                    -- Manual currency (units)
                    sess.split.manual_units = sess.split.manual_units or {}

                    -- Drops total (units) (read-only)
                    local detected_units = {}
                    for name, qty in pairs(sess.drops.currency_total or {}) do
                        if is_cur(name) then
                            local units = to_units(name, qty)
                            local base = base_cur(name)
                            detected_units[base] = (detected_units[base] or 0) + units
                        end
                    end

                    do
                        imgui.TextUnformatted('Manual currency (units)')
                        imgui.SameLine()
                        if imgui.SmallButton('Reset manual') then
                            sess.split.manual_units = {}
                            if store and sess and sess.is_event then
                                store.save(sess)
                            end
                        end

                        local bases_known = { 'Bronzepiece', 'Whiteshell', 'Byne Bill' }

                        if imgui.BeginTable('tbl_manual_currency', 4, TF_BORDER) then
                            imgui.TableSetupColumn('Currency')
                            imgui.TableSetupColumn('Drops total')
                            imgui.TableSetupColumn('Add')
                            imgui.TableSetupColumn('Total')
                            imgui.TableHeadersRow()

                            for _, base in ipairs(bases_known) do
                                local drops_total = tonumber(detected_units[base]) or 0

                                local addv = tonumber(sess.split.manual_units[base]) or 0
                                if addv < 0 then addv = 0 end

                                local totalv = drops_total + addv

                                imgui.TableNextRow()
                                imgui.TableSetColumnIndex(0)
                                imgui.TextColored(C.CUR, display_cur(base))

                                imgui.TableSetColumnIndex(1)
                                imgui.TextColored(C.QTY, tostring(drops_total))

                                imgui.TableSetColumnIndex(2)
                                imgui.PushItemWidth(140)
                                local v = { addv }
                                if imgui.InputInt('##man_' .. base, v) then
                                    local nv = tonumber(v[1]) or 0
                                    if nv < 0 then nv = 0 end
                                    sess.split.manual_units[base] = nv
                                    if store and sess and sess.is_event then
                                        store.save(sess)
                                    end
                                end
                                imgui.PopItemWidth()

                                imgui.TableSetColumnIndex(3)
                                imgui.TextColored(C.QTY, tostring(totalv))
                            end

                            imgui.EndTable()
                        end

                        imgui.Separator()
                    end


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

                    for base, add in pairs(sess.split.manual_units or {}) do
                        local v = tonumber(add) or 0
                        if v > 0 then
                            agg[base] = (agg[base] or 0) + v
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
                draw_settings_panel(cfg, C, ctx.event_id or 'dynamis')
                imgui.EndTabItem()
            end
        end -- compact / full
        imgui.EndTabBar()
    end -- BeginTabBar
end

return dynamis
