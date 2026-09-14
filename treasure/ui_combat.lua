local imgui = require('imgui')
local combat_settings = require('combat.settings')
local combat_chat_colors = require('combat.chat_colors')

local CHILD_BORDER = rawget(_G, 'ImGuiChildFlags_Borders')
        or rawget(imgui, 'ImGuiChildFlags_Borders')
        or (imgui.ChildFlags and imgui.ChildFlags.Borders)
        or 1

local ui_combat = {
    open = false,
    size_initialized = false,
}

local GLOBAL_FILTERS = {
    { 'casts', 'Casting', 'Spell preparation messages.' },
    { 'items', 'Items', 'Supported combat item messages. Unknown game messages remain visible for safety.' },
    { 'defeats', 'Defeats', 'Defeat and kill messages.' },
}

local FILTER_SCOPES = {
    { 'self', 'You', 'You and your pet.', 'you or your pet' },
    { 'party', 'Party', 'Party members and their pets.', 'party members or their pets' },
    { 'alliance', 'Alliance', 'Alliance members and their pets.', 'alliance members or their pets' },
    { 'others', 'Other players', 'Players outside your party and alliance.', 'players outside your alliance' },
    { 'enemies', 'Enemies', 'Monsters and hostile NPCs.', 'enemies' },
}

local SCOPE_FILTERS = {
    { 'misses', 'Misses', 'Attacks by %s that miss.' },
    { 'defenses', 'Defenses', 'Evades, parries, guards, blocks and resists by %s.' },
    { 'damage_dealt', 'Damage dealt', 'Damage caused by %s.' },
    { 'damage_received', 'Damage received', 'Damage taken by %s.' },
    { 'actions', 'Actions', 'Attacks, abilities, casting and readying by %s.' },
    { 'hp_gained', 'HP gained', 'Healing and HP recovery received by %s.' },
    { 'status', 'Status effects', 'Effects gained, resisted or removed on %s.' },
}

local CHAT_COLOR_ROWS = {
    { 'p1', 'P1 (first party position)', 'Color assigned to the player in the first party slot.' },
    { 'p2', 'P2', 'Color assigned to the second party slot.' },
    { 'p3', 'P3', 'Color assigned to the third party slot.' },
    { 'p4', 'P4', 'Color assigned to the fourth party slot.' },
    { 'p5', 'P5', 'Color assigned to the fifth party slot.' },
    { 'p6', 'P6', 'Color assigned to the sixth party slot.' },
    { 'enemy', 'Enemies', 'Color used for monsters and hostile NPC names.' },
    { 'other', 'Alliance / others', 'Color used for alliance members and players outside your party.' },
    { 'damage', 'Damage / HP lost', 'Color used for damage numbers and HP loss.' },
    { 'healing', 'Healing / recovery', 'Color used for healing and recovered HP.' },
    { 'mp', 'MP recovered', 'Color used when a character recovers MP.' },
    { 'action', 'Actions, casting and verbs', 'Color used for abilities and verbs such as casting, readying and gains.' },
    { 'critical', 'Critical hits', 'Color used to make critical damage stand out.' },
    { 'status', 'Status effects and rolls', 'Color used for buffs, debuffs, resisted effects and rolls.' },
    { 'decoration_actor', 'Actor delimiters', 'Optional color for delimiters around actors.' },
    { 'decoration_action', 'Action delimiters', 'Optional color for delimiters around actions.' },
    { 'decoration_target', 'Target delimiters', 'Optional color for delimiters around targets.' },
    { 'decoration_effect_gained', 'Gained-effect delimiters', 'Optional color for delimiters around gained effects.' },
    { 'decoration_effect_lost', 'Lost-effect delimiters', 'Optional color for delimiters around lost effects.' },
}

local PRESETS = {
    { 'all', 'Everything', 'Shows every supported combat category for every group.' },
    { 'group', 'Group', 'Shows your party and alliance while hiding unrelated players.' },
    { 'compact', 'Compact', 'Hides low-value messages such as misses and most preparation text.' },
    { 'support', 'Support', 'Prioritizes healing, status effects and incoming combat information.' },
}

local DECORATION_STYLES = {
    { 'none', 'None' }, { 'brackets', '[Square brackets]' },
    { 'parentheses', '(Parentheses)' }, { 'braces', '{Braces}' },
    { 'quotes', '"Quotes"' }, { 'angles', '<Angle brackets>' },
}

local DECORATION_PARTS = {
    { 'actor', 'Actors' }, { 'action', 'Actions' }, { 'target', 'Targets' },
    { 'effect_gained', 'Effects gained' }, { 'effect_lost', 'Effects lost' },
}

local function notify_changed(callback)
    if type(callback) == 'function' then
        callback()
    end
end

local function attach_tooltip(text)
    text = tostring(text or '')
    if text == '' or imgui.IsItemHovered == nil then return end
    local ok_hover, hovered = pcall(imgui.IsItemHovered)
    if not (ok_hover and (hovered == true or tonumber(hovered) == 1)) then return end
    if imgui.SetTooltip ~= nil then
        pcall(imgui.SetTooltip, text)
    elseif imgui.BeginTooltip ~= nil and imgui.EndTooltip ~= nil then
        local ok_begin, opened = pcall(imgui.BeginTooltip)
        if ok_begin and opened ~= false then
            pcall(imgui.TextUnformatted, text)
            pcall(imgui.EndTooltip)
        end
    end
end

local function checkbox(label, value, on_change, tooltip)
    local ref = { value == true }
    local changed = imgui.Checkbox(label, ref)
    attach_tooltip(tooltip)
    if changed then
        on_change(ref[1])
        return true
    end
    return false
end

local function palette_combo(key, entry, tooltip)
    local changed = false
    imgui.SetNextItemWidth(190)
    if imgui.BeginCombo('##combat_chat_palette_' .. key, combat_chat_colors.palette_name(entry.index)) then
        for _, option in ipairs(combat_chat_colors.palette()) do
            if imgui.Selectable(option[2] .. '##combat_palette_' .. key .. '_' .. tostring(option[1]),
                    tonumber(entry.index) == option[1]) then
                entry.index = option[1]
                changed = true
            end
        end
        imgui.EndCombo()
    end
    attach_tooltip(tooltip)
    return changed
end

local function preset_selector(root)
    local cfg = root.combat_log
    local changed = false
    imgui.TextUnformatted('Start with a preset')
    for index, entry in ipairs(PRESETS) do
        if index > 1 then
            imgui.SameLine()
        end
        local selected = cfg.preset == entry[1]
        local label = selected and ('[' .. entry[2] .. ']') or entry[2]
        if imgui.Button(label .. '##combat_preset_' .. entry[1]) then
            combat_settings.apply_preset(root, entry[1])
            changed = true
        end
        attach_tooltip(entry[3])
    end
    if cfg.preset == 'custom' then
        imgui.TextDisabled('Preset: Custom (your filters are preserved)')
    end
    return changed
end

local function draw_preview(cfg)
    local palette = cfg.chat_colors or {}
    local function preview(key, fallback)
        local entry = palette[key]
        if palette.enabled == false or (entry and entry.enabled == false) then return { 1, 1, 1, 1 } end
        return combat_chat_colors.preview_rgba(entry, fallback)
    end
    local function decorated(part, value)
        local marks = {
            brackets = { '[', ']' }, parentheses = { '(', ')' }, braces = { '{', '}' },
            quotes = { '"', '"' }, angles = { '<', '>' },
        }
        local options = cfg.decoration or {}
        local pair = options[part] == true and marks[options.style]
        return pair and (pair[1] .. value .. pair[2]) or value
    end
    local function draw_decorated(part, value, base_color)
        local options = cfg.decoration or {}
        local marks = {
            brackets = { '[', ']' }, parentheses = { '(', ')' }, braces = { '{', '}' },
            quotes = { '"', '"' }, angles = { '<', '>' },
        }
        local pair = options[part] == true and marks[options.style]
        local delimiter = palette['decoration_' .. part]
        if not pair or not delimiter or delimiter.enabled == false or palette.enabled == false then
            imgui.TextColored(base_color, decorated(part, value))
            return
        end
        local delimiter_color = combat_chat_colors.preview_rgba(delimiter, { 1, 1, 1, 1 })
        imgui.TextColored(delimiter_color, pair[1])
        imgui.SameLine(0, 0)
        imgui.TextColored(base_color, value)
        imgui.SameLine(0, 0)
        imgui.TextColored(delimiter_color, pair[2])
    end
    imgui.TextUnformatted('Live preview')
    imgui.BeginChild('combat_preview', { 0, 164 }, CHILD_BORDER, 0)
    if cfg.enabled ~= true then
        imgui.TextDisabled('Combat Log is off. Original game messages remain unchanged.')
    else
        imgui.TextDisabled('Enabled: decoded combat is replaced locally by Treasure.')
        draw_decorated('actor', 'Waky', preview('p1', cfg.colors.self))
        imgui.SameLine(0, 4)
        imgui.TextDisabled(' -> ')
        imgui.SameLine(0, 4)
        draw_decorated('target', 'Goblin', preview('enemy', cfg.colors.enemy))
        imgui.SameLine(0, 4)
        imgui.TextColored(preview('damage', cfg.colors.damage), ': 32 + 41 + 29 damage (102)')

        draw_decorated('actor', 'Alice', preview('p2', cfg.colors.party))
        imgui.SameLine(0, 4)
        imgui.TextColored(preview('action', cfg.colors.status), ' casts ')
        imgui.SameLine(0, 0)
        draw_decorated('action', 'Cure III', preview('action', cfg.colors.status))
        imgui.SameLine(0, 0)
        imgui.TextColored(preview('action', cfg.colors.status), ' -> ')
        imgui.SameLine(0, 0)
        draw_decorated('target', 'Waky', preview('p1', cfg.colors.self))
        imgui.SameLine(0, 0)
        imgui.TextColored(preview('healing', cfg.colors.healing), ': +184 HP')
        imgui.SameLine(0, 4)
        imgui.TextColored(preview('mp', cfg.colors.mp), '/ +50 MP')

        imgui.TextColored(preview('status', cfg.colors.status), 'Haste')
        imgui.SameLine(0, 4)
        imgui.TextColored(cfg.colors.muted, ' -> Alice, Bob and Carol')

        imgui.TextColored(preview('p2', cfg.colors.party), 'Alice gains ')
        imgui.SameLine(0, 0)
        draw_decorated('effect_gained', 'Haste', preview('status', cfg.colors.status))

        draw_decorated('effect_lost', 'Poison', preview('status', cfg.colors.status))
        imgui.SameLine(0, 4)
        imgui.TextColored(preview('action', cfg.colors.status), 'removed')
    end
    imgui.EndChild()
end

function ui_combat.set_open(value)
    ui_combat.open = (value == true)
end

function ui_combat.toggle()
    ui_combat.open = not ui_combat.open
end

local function render_configuration(root, on_change, embedded)
    if type(root) ~= 'table' or (not embedded and not ui_combat.open) then
        return
    end

    combat_settings.ensure(root)
    local cfg = root.combat_log
    if not embedded and not ui_combat.size_initialized then
        imgui.SetNextWindowSize({ 680, 700 })
        ui_combat.size_initialized = true
    end
    if not embedded then
        if not imgui.Begin('Treasure Combat Log - Configuration', false, 0) then
            imgui.End()
            return
        end
    end

    local changed = false
    imgui.TextUnformatted('Simple to start, precise when you need it.')
    imgui.TextDisabled('Hover any option to see what it changes. Nothing is replaced until you enable Combat Log.')
    imgui.Separator()

    changed = checkbox('Enable Combat Log', cfg.enabled, function(value)
        combat_settings.set_enabled(root, value)
    end, 'Replaces supported game combat messages locally with Treasure formatting. Turn it off to restore the original game chat.') or changed
    if cfg.enabled then
        imgui.SameLine()
        imgui.TextDisabled('On - replaces supported combat messages')
    else
        imgui.SameLine()
        imgui.TextDisabled('Off - original game chat is untouched')
    end
    imgui.Separator()
    changed = preset_selector(root) or changed

    if imgui.BeginTabBar('combat_config_sections') then
        if imgui.BeginTabItem('What to show') then
            imgui.TextDisabled('Filter each kind of combat message separately for every group.')
            if imgui.BeginTabBar('combat_filter_scopes') then
                for _, scope in ipairs(FILTER_SCOPES) do
                    if imgui.BeginTabItem(scope[2]) then
                        imgui.TextDisabled(scope[3])
                        imgui.Separator()
                        local row = cfg.filter_matrix[scope[1]]
                        for _, def in ipairs(SCOPE_FILTERS) do
                            if checkbox(def[2] .. '##combat_filter_' .. scope[1] .. '_' .. def[1], row[def[1]], function(value)
                                row[def[1]] = value
                                combat_settings.mark_custom(root)
                            end, string.format(def[3], scope[4])) then
                                changed = true
                            end
                            imgui.SameLine()
                            imgui.TextDisabled(string.format(def[3], scope[4]))
                        end
                        imgui.EndTabItem()
                    end
                end
                imgui.EndTabBar()
            end
            imgui.Separator()
            imgui.TextUnformatted('Global message types')
            for _, def in ipairs(GLOBAL_FILTERS) do
                if checkbox(def[2] .. '##combat_global_filter_' .. def[1], cfg.filters[def[1]], function(value)
                    cfg.filters[def[1]] = value
                    combat_settings.mark_custom(root)
                end, def[3]) then changed = true end
                imgui.SameLine()
                imgui.TextDisabled(def[3])
            end
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem('Grouping') then
            changed = checkbox('Group repeated actions', cfg.aggregation.damage, function(value)
                cfg.aggregation.damage = value
            end, 'Combines matching combat actions that arrive close together into one shorter line.') or changed
            changed = checkbox('Group multiple targets', cfg.aggregation.targets, function(value)
                cfg.aggregation.targets = value
            end, 'Combines equal results on several targets instead of printing one line per target.') or changed
            changed = checkbox('Show a summed total', cfg.aggregation.sum_damage, function(value)
                cfg.aggregation.sum_damage = value
            end, 'Adds the combined damage or healing total when several results share one line.') or changed
            changed = checkbox('Merge critical and normal hits', cfg.aggregation.merge_criticals, function(value)
                cfg.aggregation.merge_criticals = value
            end, 'Allows critical and normal hits to share a grouped line. Disable it to keep critical hits visually separate.') or changed
            local window = { tonumber(cfg.aggregation.window_ms) or 100 }
            if imgui.SliderFloat('Grouping window (ms)', window, 25, 1000, '%.0f') then
                cfg.aggregation.window_ms = math.floor(window[1] + 0.5)
                changed = true
            end
            attach_tooltip('How long Treasure waits for matching results. Lower values appear sooner; higher values can combine more messages.')
            imgui.TextDisabled('Shorter windows feel immediate; longer windows combine more lines.')
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem('Details') then
            changed = checkbox('Show pet owner', cfg.display.pet_owner, function(value)
                cfg.display.pet_owner = value
            end, 'Shows which player owns a pet when Treasure can identify the owner.') or changed
            changed = checkbox('Show target count', cfg.display.target_count, function(value)
                cfg.display.target_count = value
            end, 'Shows how many targets are represented by a combined message.') or changed
            changed = checkbox('Show target names', cfg.display.target_names, function(value)
                cfg.display.target_names = value
            end, 'Lists target names in combined messages when space allows.') or changed
            changed = checkbox('Show hit / effect counts', cfg.display.show_totals, function(value)
                cfg.display.show_totals = value
            end, 'Shows hit or effect counts beside grouped damage and healing totals.') or changed
            imgui.Separator()
            imgui.TextUnformatted('Text decoration')
            local current_style = cfg.decoration.style or 'none'
            local current_label = 'None'
            for _, option in ipairs(DECORATION_STYLES) do
                if option[1] == current_style then current_label = option[2] end
            end
            imgui.SetNextItemWidth(210)
            if imgui.BeginCombo('Style##combat_decoration_style', current_label) then
                for _, option in ipairs(DECORATION_STYLES) do
                    if imgui.Selectable(option[2] .. '##combat_decoration_' .. option[1], current_style == option[1]) then
                        cfg.decoration.style = option[1]
                        current_style = option[1]
                        changed = true
                    end
                end
                imgui.EndCombo()
            end
            local all_decorated = true
            for _, part in ipairs(DECORATION_PARTS) do
                all_decorated = all_decorated and cfg.decoration[part[1]] == true
            end
            changed = checkbox('All##combat_decoration_all', all_decorated, function(value)
                for _, part in ipairs(DECORATION_PARTS) do cfg.decoration[part[1]] = value end
            end, 'Applies the selected style to every supported part.') or changed
            for _, part in ipairs(DECORATION_PARTS) do
                changed = checkbox(part[2] .. '##combat_decoration_' .. part[1], cfg.decoration[part[1]], function(value)
                    cfg.decoration[part[1]] = value
                end, 'Applies the selected style only to ' .. part[2]:lower() .. '.') or changed
            end
            imgui.EndTabItem()
        end

        if imgui.BeginTabItem('Colors') then
            imgui.TextDisabled('FFXI chat uses its internal palette. Every color can be changed or disabled.')
            changed = checkbox('Enable colors in combat chat', cfg.chat_colors.enabled, function(value)
                cfg.chat_colors.enabled = value
            end, 'Master switch for Treasure combat colors. Formatting and filters continue working when colors are off.') or changed
            imgui.Separator()
            for _, def in ipairs(CHAT_COLOR_ROWS) do
                local entry = cfg.chat_colors[def[1]]
                if checkbox('Use##combat_chat_use_' .. def[1], entry.enabled, function(value)
                    entry.enabled = value
                end, def[3]) then changed = true end
                imgui.SameLine()
                imgui.TextUnformatted(def[2])
                attach_tooltip(def[3])
                imgui.SameLine(285)
                changed = palette_combo(def[1], entry, def[3]) or changed
            end
            imgui.EndTabItem()
        end

        imgui.EndTabBar()
    end

    imgui.Separator()
    draw_preview(cfg)
    if imgui.Button('Restore safe defaults') then
        combat_settings.reset(root)
        cfg = root.combat_log
        changed = true
    end
    attach_tooltip('Resets every Combat Log option and turns the module off. Other Treasure settings are not changed.')
    if not embedded then
        imgui.SameLine()
        if imgui.Button('Close') then
            ui_combat.open = false
        end
    end

    if not embedded then imgui.End() end
    if changed then
        combat_settings.ensure(root)
        notify_changed(on_change)
    end
end

function ui_combat.render(root, on_change)
    render_configuration(root, on_change, false)
end

function ui_combat.render_embedded(root, on_change)
    render_configuration(root, on_change, true)
end

return ui_combat
