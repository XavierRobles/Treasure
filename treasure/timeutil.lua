---------------------------------------------------------------------------
-- Treasure · timeutil.lua · Waky
---------------------------------------------------------------------------

local timeutil = {}
local SOCKET_OK, socket = pcall(require, 'socket')

function timeutil.now()
    if SOCKET_OK and socket and type(socket.gettime) == 'function' then
        local ok, v = pcall(socket.gettime)
        if ok and type(v) == 'number' then
            return v
        end
    end
    return os.time()
end

return timeutil
