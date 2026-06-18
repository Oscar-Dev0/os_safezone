SafeZoneCache = {}
local ready = false

local function countZones()
    local count = 0
    for _ in pairs(SafeZoneCache) do count = count + 1 end
    return count
end

local function syncAll(eventName, ...)
    TriggerClientEvent(eventName, -1, ...)
end

local function operationResult(src, operation, success, message)
    if src and src > 0 then
        TriggerClientEvent('os_safezone:client:operationResult', src, operation, success == true, message)
    end
end

local function normalizeForStorage(raw, id, creator)
    local zone = SafeZoneSchema.Normalize(raw, id)
    zone.createdBy = creator or zone.createdBy
    local valid, reason = SafeZoneSchema.Validate(zone)
    return valid, reason, zone
end

CreateThread(function()
    Database.Initialize(function()
        Database.GetAllZones(function(zones)
            SafeZoneCache = zones or {}
            ready = true
            Utils.LogInfo(('Cargadas %d zonas seguras.'):format(countZones()))
            syncAll('os_safezone:client:syncZones', SafeZoneCache)
        end)
    end)
end)

RegisterNetEvent('os_safezone:server:requestSync', function()
    local src = source
    if not ready then
        CreateThread(function()
            local attempts = 0
            while not ready and attempts < 100 do
                attempts = attempts + 1
                Wait(100)
            end
            TriggerClientEvent('os_safezone:client:syncZones', src, SafeZoneCache)
        end)
        return
    end
    TriggerClientEvent('os_safezone:client:syncZones', src, SafeZoneCache)
end)

RegisterNetEvent('os_safezone:server:createZone', function(raw)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'create') then return operationResult(src, 'create', false, 'No tienes permisos para crear zonas.') end

    local valid, reason, zone = normalizeForStorage(raw, nil, GetPlayerName(src))
    if not valid then
        Bridge.Notify(src, reason, 'error')
        return operationResult(src, 'create', false, reason)
    end

    Database.InsertZone(zone, function(success, created)
        if not success or not created then
            Bridge.Notify(src, 'No se pudo crear la zona.', 'error')
            return operationResult(src, 'create', false, 'No se pudo crear la zona en la base de datos.')
        end
        SafeZoneCache[created.id] = created
        syncAll('os_safezone:client:addZone', created)
        Bridge.Notify(src, ('Zona creada: %s'):format(created.name), 'success')
        SafeZoneLogger.Write(src, 'CREAR ZONA', ('%s [ID %d]'):format(created.name, created.id))
        operationResult(src, 'create', true, ('Zona creada: %s'):format(created.name))
    end)
end)

RegisterNetEvent('os_safezone:server:updateZone', function(zoneId, raw)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'update') then return operationResult(src, 'update', false, 'No tienes permisos para editar zonas.') end
    zoneId = tonumber(zoneId)
    local current = zoneId and SafeZoneCache[zoneId]
    if not current then
        Bridge.Notify(src, 'La zona no existe.', 'error')
        return operationResult(src, 'update', false, 'La zona no existe.')
    end

    -- Conserva campos que la interfaz no haya enviado.
    raw = type(raw) == 'table' and raw or {}
    for key, value in pairs(current) do
        if raw[key] == nil then raw[key] = SafeZoneSchema.DeepCopy(value) end
    end

    local valid, reason, zone = normalizeForStorage(raw, zoneId, current.createdBy)
    if not valid then
        Bridge.Notify(src, reason, 'error')
        return operationResult(src, 'update', false, reason)
    end

    Database.UpdateZone(zoneId, zone, function(success)
        if not success then
            Bridge.Notify(src, 'No se pudo actualizar la zona.', 'error')
            return operationResult(src, 'update', false, 'No se pudo actualizar la zona en la base de datos.')
        end
        SafeZoneCache[zoneId] = zone
        syncAll('os_safezone:client:updateZone', zoneId, zone)
        Bridge.Notify(src, ('Zona actualizada: %s'):format(zone.name), 'success')
        SafeZoneLogger.Write(src, 'EDITAR ZONA', ('%s [ID %d]'):format(zone.name, zoneId))
        operationResult(src, 'update', true, ('Cambios guardados: %s'):format(zone.name))
    end)
end)

RegisterNetEvent('os_safezone:server:deleteZone', function(zoneId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'delete') then return operationResult(src, 'delete', false, 'No tienes permisos para eliminar zonas.') end
    zoneId = tonumber(zoneId)
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then
        Bridge.Notify(src, 'La zona no existe.', 'error')
        return operationResult(src, 'delete', false, 'La zona no existe o ya fue eliminada.')
    end

    Database.DeleteZone(zoneId, function(success)
        if not success then
            Bridge.Notify(src, 'No se pudo eliminar la zona.', 'error')
            return operationResult(src, 'delete', false, 'La base de datos no confirmó la eliminación.')
        end
        SafeZoneCache[zoneId] = nil
        syncAll('os_safezone:client:removeZone', zoneId)
        Bridge.Notify(src, ('Zona eliminada: %s'):format(zone.name), 'success')
        SafeZoneLogger.Write(src, 'ELIMINAR ZONA', ('%s [ID %d]'):format(zone.name, zoneId))
        operationResult(src, 'delete', true, ('Zona eliminada: %s'):format(zone.name))
    end)
end)

RegisterNetEvent('os_safezone:server:toggleZone', function(zoneId, state)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'toggle') then return operationResult(src, 'toggle', false, 'No tienes permisos para cambiar el estado.') end
    zoneId = tonumber(zoneId)
    state = state == true
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then
        Bridge.Notify(src, 'La zona no existe.', 'error')
        return operationResult(src, 'toggle', false, 'La zona no existe.')
    end

    Database.ToggleZone(zoneId, state, function(success)
        if not success then
            Bridge.Notify(src, 'No se pudo cambiar el estado.', 'error')
            return operationResult(src, 'toggle', false, 'La base de datos no confirmó el cambio.')
        end
        zone.enabled = state
        syncAll('os_safezone:client:toggleZone', zoneId, state)
        Bridge.Notify(src, state and 'Zona activada.' or 'Zona desactivada.', 'success')
        SafeZoneLogger.Write(src, 'CAMBIAR ESTADO', ('%s [ID %d] = %s'):format(zone.name, zoneId, tostring(state)))
        operationResult(src, 'toggle', true, state and 'Zona activada.' or 'Zona desactivada.')
    end)
end)

exports('GetSafeZones', function() return SafeZoneCache end)
exports('GetSafeZoneById', function(zoneId) return SafeZoneCache[tonumber(zoneId)] end)
exports('SetSafeZoneState', function(zoneId, state)
    zoneId = tonumber(zoneId)
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then return false end
    state = state == true
    Database.ToggleZone(zoneId, state, function(success)
        if success then
            zone.enabled = state
            syncAll('os_safezone:client:toggleZone', zoneId, state)
        end
    end)
    return true
end)
