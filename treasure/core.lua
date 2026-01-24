---------------------------------------------------------------------------
-- Treasure · core.lua · Waky
---------------------------------------------------------------------------

local core = {}
local res = AshitaCore:GetResourceManager()

-- IDs clásicos + Dynamis Divergence;
local IDS = {
    [134] = true, [135] = true, -- Beaucedine / Xarcabard
    [185] = true, [186] = true, [187] = true, [188] = true, -- San d'Oria/Bastok/Windurst/Jeuno
    [39] = true, [40] = true, [41] = true, [42] = true, -- Valkurm/Buburimu/Qufim/Tavnazia
    [294] = true, [295] = true, [296] = true, [297] = true  -- Divergence ciudades
}

function core.is_dynamis(zid)
    if not zid or zid == 0 or zid == 0xFFFF then
        return false
    end
    if IDS[zid] then
        return true
    end
    local name = res:GetString('zones.names', zid) or ''
    return name:find('Dynamis') and true or false
end

function core.dynamis_max_minutes(zid)
    zid = tonumber(zid)

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

function core.new_drop_state()
    return {
        currency_total = {}, -- { item = qty }
        by_player = {}, -- { player = { item = qty } }
        equips_by_player = {}, -- { player = {item1,item2} }
        lost = {}, -- { item = qty }
        pool_live = {}, -- treasure-pool activo
    }
end

return core
