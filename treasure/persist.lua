---------------------------------------------------------------------------
-- Treasure · persist.lua
-- Safe loading and atomic replacement for serialized Lua tables.
---------------------------------------------------------------------------

local persist = {}

local function file_exists(path)
    local f = io.open(path, 'rb')
    if not f then return false end
    f:close()
    return true
end

local function load_one(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local content = f:read('*a')
    f:close()

    local loader = loadstring(content)
    if not loader then return nil end
    if setfenv then
        setfenv(loader, {})
    end
    local ok, data = pcall(loader)
    if ok and type(data) == 'table' then
        return data
    end
    return nil
end

function persist.load_table(path)
    return load_one(path) or load_one(path .. '.bak')
end

function persist.write_atomic(path, content)
    if not path or path == '' then return false, 'invalid path' end

    local tmp = path .. '.tmp'
    local bak = path .. '.bak'
    local f, err = io.open(tmp, 'wb')
    if not f then return false, err end

    local ok_write, write_err = f:write(content or '')
    local ok_close, close_err = f:close()
    if not ok_write or not ok_close then
        os.remove(tmp)
        return false, write_err or close_err or 'write failed'
    end

    os.remove(bak)
    local had_original = file_exists(path)
    if had_original then
        local ok_backup, backup_err = os.rename(path, bak)
        if not ok_backup then
            os.remove(tmp)
            return false, backup_err or 'backup failed'
        end
    end

    local ok_replace, replace_err = os.rename(tmp, path)
    if not ok_replace then
        if had_original then
            os.rename(bak, path)
        end
        os.remove(tmp)
        return false, replace_err or 'replace failed'
    end

    return true
end

return persist
