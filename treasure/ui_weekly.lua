---------------------------------------------------------------------------
-- Treasure · ui_weekly.lua · Waky
-- Weekly tracker UI (Eco-War + Highwind today; UIG/ENM later).
---------------------------------------------------------------------------

local ecowar = require('weekly.ecowar')
local highwind = require('weekly.highwind')
local quests = require('weekly.quests')

local ui_weekly = {}

local ECO_DISPLAY = {
    sandy = "San d'Oria",
    windy = 'Windurst',
    bastok = 'Bastok',
}
local ECO_ORDER = { 'sandy', 'windy', 'bastok' }

local function fmt_reset_remaining(next_ts)
    local now = os.time()
    local rem = math.max(0, (next_ts or now) - now)
    local d = math.floor(rem / 86400)
    local h = math.floor((rem - d * 86400) / 3600)
    local m = math.floor((rem - d * 86400 - h * 3600) / 60)
    if d > 0 then
        return string.format('%dd %02dh %02dm', d, h, m)
    end
    return string.format('%02dh %02dm', h, m)
end

function ui_weekly.top_left_status(_)
    local st = ecowar.get_state()
    if not st then return nil end
    return 'Reset in ' .. fmt_reset_remaining(ecowar.next_reset_timestamp())
end

--------------------------------------------------------------------
-- Eco-War tab
--------------------------------------------------------------------
local function draw_ecowar_status_table(ctx)
    local imgui = ctx.imgui
    local C = ctx.C
    local TF_BORDER = ctx.TF_BORDER
    local st = ecowar.get_state()
    if not st then
        imgui.TextDisabled('Eco-Warrior state not loaded.')
        return
    end

    imgui.TextColored(C.ITEM, 'Eco-Warrior')
    imgui.SameLine()
    imgui.TextDisabled('| Reset in ' .. fmt_reset_remaining(ecowar.next_reset_timestamp()))

    imgui.Separator()
    imgui.TextUnformatted(ecowar.get_summary())
    imgui.TextColored(C.QTY or C.ITEM, 'Next: ' .. ecowar.get_next_step())
    imgui.Separator()

    if imgui.BeginTable('tbl_ecowar_status', 3, TF_BORDER) then
        imgui.TableSetupColumn('Nation')
        imgui.TableSetupColumn('Status')
        imgui.TableSetupColumn('Go to')
        imgui.TableHeadersRow()

        for _, eco in ipairs(ECO_ORDER) do
            local status = ecowar.get_status_for_eco(eco)
            local color
            if status == 'ACTIVE' then
                color = C.CUR or C.QTY
            elseif status == 'DONE THIS WEEK' or status == 'CYCLE DONE' then
                color = C.LOST or C.ITEM
            elseif status == 'AFTER RESET' then
                color = C.QTY or C.ITEM
            else
                color = C.QTY or C.ITEM
            end

            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.TextColored(C.NAME or C.ITEM, ECO_DISPLAY[eco])
            imgui.TableSetColumnIndex(1)
            imgui.TextColored(color, status)
            imgui.TableSetColumnIndex(2)
            imgui.TextDisabled(ecowar.current_target_npc(eco) or '')
        end
        imgui.EndTable()
    end
end

local function draw_ecowar_messages(ctx)
    local imgui = ctx.imgui
    local msgs = ecowar.get_messages()
    if not msgs or #msgs == 0 then return end
    imgui.Separator()
    imgui.TextDisabled('Recent triggers')
    for i = #msgs, 1, -1 do
        local m = msgs[i]
        if type(m) == 'table' then
            local time_txt = m.time and os.date('%H:%M:%S', m.time) or ''
            imgui.TextDisabled(time_txt .. '  ' .. tostring(m.text or ''))
        else
            imgui.TextDisabled(tostring(m))
        end
    end
end

--------------------------------------------------------------------
-- Highwind tab
--------------------------------------------------------------------
local function draw_highwind_status(ctx)
    local imgui = ctx.imgui
    local C = ctx.C
    local ui = ctx.ui
    local st = highwind.get_state()
    if not st then
        imgui.TextDisabled('Highwind state not loaded.')
        return
    end

    imgui.TextColored(C.ITEM, 'Highwind')
    imgui.SameLine()
    imgui.TextDisabled('| Reset in ' .. fmt_reset_remaining(highwind.next_reset_timestamp()))
    imgui.Separator()

    local is_alive = not highwind.is_killed_this_week()
    local icon_fn = ui and ui._draw_highwind_icon
    local icon_drawn = false
    if type(icon_fn) == 'function' then
        local ok, drew = pcall(icon_fn, is_alive, 72, { 1, 1, 1, 1 })
        icon_drawn = (ok and drew == true)
    end

    if icon_drawn then
        imgui.SameLine(0, 12)
        imgui.BeginGroup()
    end

    if is_alive then
        imgui.TextColored(C.CUR or C.ITEM, 'AVAILABLE')
        imgui.TextDisabled('Go fight Highwind for your weekly kill.')
    else
        imgui.TextColored(C.LOST or C.ITEM, 'KILLED THIS WEEK')
        if st.lastKillTimestamp then
            imgui.TextDisabled('Last kill: ' .. os.date('%Y-%m-%d %H:%M', st.lastKillTimestamp))
        end
        if st.lastKillerName and st.lastKillerName ~= '' then
            imgui.TextDisabled('Killer: ' .. tostring(st.lastKillerName))
        end
    end

    if icon_drawn then
        imgui.EndGroup()
    end
end

local function draw_highwind_messages(ctx)
    local imgui = ctx.imgui
    local msgs = highwind.get_messages()
    if not msgs or #msgs == 0 then return end
    imgui.Separator()
    imgui.TextDisabled('Recent triggers')
    for i = #msgs, 1, -1 do
        local m = msgs[i]
        if type(m) == 'table' then
            local time_txt = m.time and os.date('%H:%M:%S', m.time) or ''
            imgui.TextDisabled(time_txt .. '  ' .. tostring(m.text or ''))
        else
            imgui.TextDisabled(tostring(m))
        end
    end
end

--------------------------------------------------------------------
-- Quests tab
--------------------------------------------------------------------
local function color_for_quest_state(C, s)
    if s == 'completed_this_week' then return C.LOST or C.ITEM end
    if s == 'has_key_item' then return C.CUR or C.QTY end
    if s == 'has_key_item_available' then return C.CUR or C.QTY end
    if s == 'cooldown' then return C.CUR or C.QTY end
    if s == 'cooldown_no_ki' then return C.CUR or C.QTY end
    if s == 'started' then return C.ITEM or C.QTY end
    if s == 'reward_blocked_inventory' then return C.LOST or C.QTY end
    return C.ITEM
end

local function attach_tooltip(imgui, text)
    text = tostring(text or '')
    if text == '' or imgui.IsItemHovered == nil then return end
    local ok_hover, hovered = pcall(imgui.IsItemHovered)
    if not (ok_hover and hovered) then return end
    if imgui.SetTooltip ~= nil then
        pcall(imgui.SetTooltip, text)
        return
    end
    if imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil then
        local ok_begin, opened = pcall(imgui.BeginTooltip)
        if ok_begin and opened then
            if imgui.TextUnformatted ~= nil then
                imgui.TextUnformatted(text)
            else
                imgui.TextDisabled(text)
            end
            pcall(imgui.EndTooltip)
        end
    end
end

local function draw_quests_status_table(ctx)
    local imgui = ctx.imgui
    local C = ctx.C
    local TF_BORDER = ctx.TF_BORDER
    local st = quests.get_state()
    if not st then
        imgui.TextDisabled('Quests state not loaded.')
        return
    end

    imgui.TextColored(C.ITEM, 'Weekly Quests / Missions / ENM')
    imgui.SameLine()
    imgui.TextDisabled('| Reset in ' .. fmt_reset_remaining(quests.next_reset_timestamp()))
    imgui.Separator()
    imgui.TextUnformatted(quests.get_summary())
    imgui.Separator()

    if imgui.BeginTable('tbl_quests_status', 5, TF_BORDER) then
        imgui.TableSetupColumn('Quest')
        imgui.TableSetupColumn('Status')
        imgui.TableSetupColumn('NPC')
        imgui.TableSetupColumn('Zone')
        imgui.TableSetupColumn('Next')
        imgui.TableHeadersRow()

        for _, qdef in ipairs(quests.catalog()) do
            local q = quests.get_quest_state(qdef.id) or { state = 'available' }
            local label = quests.quest_state_label(qdef, q.state, q)
            local color = color_for_quest_state(C, q.state)

            imgui.TableNextRow()
            imgui.TableSetColumnIndex(0)
            imgui.TextColored(C.NAME or C.ITEM, qdef.label)
            imgui.TableSetColumnIndex(1)
            imgui.TextColored(color, label)
            imgui.TableSetColumnIndex(2)
            imgui.TextDisabled(qdef.npc or '')
            imgui.TableSetColumnIndex(3)
            imgui.TextDisabled(quests.get_quest_zone_hint(qdef.id) or '')
            imgui.TableSetColumnIndex(4)
            local next_step = quests.get_quest_next_step(qdef.id) or ''
            imgui.TextColored(C.ITEM or C.QTY, '?')
            attach_tooltip(imgui, next_step)
        end
        imgui.EndTable()
    end
end

local function draw_quests_messages(ctx)
    local imgui = ctx.imgui
    local msgs = quests.get_messages()
    if not msgs or #msgs == 0 then return end
    imgui.Separator()
    imgui.TextDisabled('Recent triggers')
    for i = #msgs, 1, -1 do
        local m = msgs[i]
        if type(m) == 'table' then
            local time_txt = m.time and os.date('%H:%M:%S', m.time) or ''
            imgui.TextDisabled(time_txt .. '  ' .. tostring(m.text or ''))
        else
            imgui.TextDisabled(tostring(m))
        end
    end
end

--------------------------------------------------------------------
-- Options tab (all manual overrides)
--------------------------------------------------------------------
local function draw_options(ctx)
    local imgui = ctx.imgui
    local C = ctx.C

    imgui.TextColored(C.ITEM, 'Eco-War · Active eco')
    for _, eco in ipairs(ECO_ORDER) do
        if imgui.SmallButton('Set ' .. ECO_DISPLAY[eco] .. '##ew_set_' .. eco) then
            ecowar.set_active(eco)
        end
        imgui.SameLine()
    end
    if imgui.SmallButton('Clear##ew_clear_active') then
        ecowar.set_active('none')
    end

    imgui.Separator()
    imgui.TextColored(C.ITEM, 'Eco-War · Mark / Undo')
    for _, eco in ipairs(ECO_ORDER) do
        imgui.TextUnformatted(ECO_DISPLAY[eco])
        imgui.SameLine()
        if imgui.SmallButton('Mark done##ew_done_' .. eco) then
            ecowar.mark_done(eco)
        end
        imgui.SameLine()
        if imgui.SmallButton('Undo##ew_undo_' .. eco) then
            ecowar.undo(eco)
        end
    end

    imgui.Separator()
    imgui.TextColored(C.ITEM, 'Eco-War · Resets')
    if imgui.SmallButton('Reset week##ew_reset_week') then
        ecowar.reset_week()
    end
    imgui.SameLine()
    if imgui.SmallButton('Reset cycle##ew_reset_cycle') then
        ecowar.reset_cycle()
    end
    imgui.SameLine()
    if imgui.SmallButton('Reset all##ew_reset_all') then
        ecowar.reset_all()
    end
    imgui.SameLine()
    if imgui.SmallButton('Clear log##ew_clear_msgs') then
        ecowar.clear_messages()
    end

    imgui.Separator()
    imgui.TextColored(C.ITEM, 'Highwind')
    if imgui.SmallButton('Mark killed##hw_done') then
        highwind.mark_killed()
    end
    imgui.SameLine()
    if imgui.SmallButton('Undo##hw_undo') then
        highwind.undo()
    end
    imgui.SameLine()
    if imgui.SmallButton('Reset week##hw_reset_week') then
        highwind.reset_week()
    end
    imgui.SameLine()
    if imgui.SmallButton('Reset all##hw_reset_all') then
        highwind.reset_all()
    end
    imgui.SameLine()
    if imgui.SmallButton('Clear log##hw_clear_msgs') then
        highwind.clear_messages()
    end

    imgui.Separator()
    imgui.TextColored(C.ITEM, 'Quests · Mark / Undo')
    for _, qdef in ipairs(quests.catalog()) do
        imgui.TextUnformatted(qdef.label)
        imgui.SameLine()
        if imgui.SmallButton('Mark done##q_done_' .. qdef.id) then
            quests.mark_done(qdef.id)
        end
        imgui.SameLine()
        if imgui.SmallButton('Undo##q_undo_' .. qdef.id) then
            quests.undo(qdef.id)
        end
    end

    imgui.Separator()
    imgui.TextColored(C.ITEM, 'Quests · Resets')
    if imgui.SmallButton('Reset week##q_reset_week') then
        quests.reset_week()
    end
    imgui.SameLine()
    if imgui.SmallButton('Reset all##q_reset_all') then
        quests.reset_all()
    end
    imgui.SameLine()
    if imgui.SmallButton('Clear log##q_clear_msgs') then
        quests.clear_messages()
    end
end

--------------------------------------------------------------------
function ui_weekly.render(ctx)
    local imgui = ctx.imgui
    local ui = ctx.ui

    local tab_bar_id = ui.compact and '##weekly_compact' or '##weekly_full'
    if not imgui.BeginTabBar(tab_bar_id) then return end

    if ui.compact then
        if imgui.BeginTabItem('Weekly') then
            local ec = ecowar.get_state()
            if ec then
                imgui.TextUnformatted(ecowar.get_summary())
                imgui.TextDisabled('Eco reset in ' .. fmt_reset_remaining(ecowar.next_reset_timestamp()))
            end
            imgui.Separator()
            local hw = highwind.get_state()
            if hw then
                imgui.TextUnformatted(highwind.get_summary())
                imgui.TextDisabled('HW reset in ' .. fmt_reset_remaining(highwind.next_reset_timestamp()))
            end
            imgui.Separator()
            local qst = quests.get_state()
            if qst then
                imgui.TextUnformatted(quests.get_summary())
            end
            imgui.EndTabItem()
        end
    else
        if imgui.BeginTabItem('Eco-War') then
            draw_ecowar_status_table(ctx)
            draw_ecowar_messages(ctx)
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Highwind') then
            draw_highwind_status(ctx)
            draw_highwind_messages(ctx)
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Quests') then
            draw_quests_status_table(ctx)
            draw_quests_messages(ctx)
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Options') then
            draw_options(ctx)
            imgui.EndTabItem()
        end
    end

    imgui.EndTabBar()
end

return ui_weekly
