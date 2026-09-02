local persist = require('persist')

local viewer = {}

local function base_dir()
    return AshitaCore:GetInstallPath() .. '\\config\\addons\\treasure\\'
end

local function valid_character(name)
    return type(name) == 'string' and name:match('^[%a][%a%d_%-]*$') ~= nil
end

local function weekly_path(name)
    return base_dir() .. name .. '\\weekly\\'
end

function viewer.list(current_character)
    local found = {}
    local result = {}
    local function add(name)
        if valid_character(name) and not found[name:lower()] then
            found[name:lower()] = true
            result[#result + 1] = name
        end
    end

    add(current_character)
    local directories = ashita.fs.get_directory(base_dir()) or {}
    for _, name in ipairs(directories) do
        if valid_character(name) then
            local path = weekly_path(name)
            if ashita.fs.exists(path .. 'ecowar.lua')
                    or ashita.fs.exists(path .. 'highwind.lua')
                    or ashita.fs.exists(path .. 'quests.lua') then
                add(name)
            end
        end
    end

    table.sort(result, function(a, b)
        if current_character and a:lower() == current_character:lower() then return true end
        if current_character and b:lower() == current_character:lower() then return false end
        return a:lower() < b:lower()
    end)
    return result
end

function viewer.load(character)
    if not valid_character(character) then return nil, 'invalid character' end
    local path = weekly_path(character)
    return {
        character = character,
        ecowar = persist.load_table(path .. 'ecowar.lua'),
        highwind = persist.load_table(path .. 'highwind.lua'),
        quests = persist.load_table(path .. 'quests.lua'),
    }
end

return viewer
