SafeZoneCache = SafeZoneCache or {}

local ready = false
local revision = 0
local syncRequests = {}
local writeLocks = {}

local function countZones()
    local count = 0
    for _ in pairs(SafeZoneCache) do count = count + 1 end
    return count
end

local function snapshot()
    return SafeZoneSchema.DeepCopy(SafeZoneCache)
end

local function nextRevision()
    revision = revision + 1
    return revision
end

local function result(src, operation, success, message, requestId)
    if src and src > 0 then
        TriggerClientEvent('os_safezone:client:operationResult', src, operation, success == true, message, requestId, revision)
    end
end

local function notify(src, message, kind)
    if Bridge and Bridge.Notify then Bridge.Notify(src, message, kind) end
end

local function broadcast(eventName, ...)
    TriggerClientEvent(eventName, -1, ..., revision)
end

local function normalize(raw, id, creator)
    local zone = SafeZoneSchema.Normalize(raw, id)
    zone.createdBy = creator or zone.createdBy
    local valid, reason = SafeZoneSchema.Validate(zone)
    return valid, reason, zone
end

local function acquire(id)
    id = tostring(id or 'global')
    if writeLocks[id] then return false end
    writeLocks[id] = true
    return true
end

local function release(id)
    writeLocks[tostring(id or 'global')] = nil
end

local function canAddZone()
    return countZones() < ((Config.Sync and Config.Sync.MaxZones) or 500)
end

CreateThread(function()
    Database.Initialize(function(ok)
        if ok == false then
            Utils.LogError('No fue posible inicializar la base de datos.')
            return
        end
        Database.GetAllZones(function(zones, err)
            if err then Utils.LogError(('Carga de zonas finalizó con error: %s'):format(err)) end
            SafeZoneCache = zones or {}
            ready = true
            nextRevision()
            Utils.LogInfo(('Cargadas %d zonas seguras. Revisión %d.'):format(countZones(), revision))
            TriggerClientEvent('os_safezone:client:syncZones', -1, snapshot(), revision)
        end)
    end)
end)

RegisterNetEvent('os_safezone:server:requestSync', function()
    local src = source
    local now = GetGameTimer()
    local cooldown = (Config.Sync and Config.Sync.RequestCooldownMs) or 1500
    if syncRequests[src] and now - syncRequests[src] < cooldown then return end
    syncRequests[src] = now

    CreateThread(function()
        local attempts = 0
        while not ready and attempts < 100 do attempts = attempts + 1 Wait(100) end
        if GetPlayerName(src) then
            TriggerClientEvent('os_safezone:client:syncZones', src, snapshot(), revision)
        end
    end)
end)

RegisterNetEvent('os_safezone:server:createZone', function(raw, requestId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'create') then return result(src, 'create', false, 'No tienes permisos para crear zonas.', requestId) end
    if not ready then return result(src, 'create', false, 'El sistema todavía está iniciando.', requestId) end
    if not canAddZone() then return result(src, 'create', false, 'Se alcanzó el límite máximo de zonas.', requestId) end
    if not acquire('create') then return result(src, 'create', false, 'Ya hay una creación en proceso.', requestId) end

    local valid, reason, zone = normalize(raw, nil, GetPlayerName(src))
    if not valid then release('create') return result(src, 'create', false, reason, requestId) end

    Database.InsertZone(zone, function(success, created)
        release('create')
        if not success or not created then
            notify(src, 'No se pudo crear la zona.', 'error')
            return result(src, 'create', false, 'MySQL no confirmó la creación.', requestId)
        end
        SafeZoneCache[created.id] = created
        nextRevision()
        broadcast('os_safezone:client:addZone', SafeZoneSchema.DeepCopy(created))
        notify(src, ('Zona creada: %s'):format(created.name), 'success')
        SafeZoneLogger.Write(src, 'CREAR ZONA', ('%s [ID %d]'):format(created.name, created.id))
        result(src, 'create', true, ('Zona creada: %s'):format(created.name), requestId)
    end)
end)

RegisterNetEvent('os_safezone:server:updateZone', function(zoneId, raw, requestId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'update') then return result(src, 'update', false, 'No tienes permisos para editar zonas.', requestId) end
    zoneId = tonumber(zoneId)
    local current = zoneId and SafeZoneCache[zoneId]
    if not current then return result(src, 'update', false, 'La zona no existe.', requestId) end
    if not acquire(zoneId) then return result(src, 'update', false, 'La zona está siendo modificada.', requestId) end

    raw = type(raw) == 'table' and SafeZoneSchema.DeepCopy(raw) or {}
    for key, value in pairs(current) do
        if raw[key] == nil then raw[key] = SafeZoneSchema.DeepCopy(value) end
    end

    local valid, reason, zone = normalize(raw, zoneId, current.createdBy)
    if not valid then release(zoneId) return result(src, 'update', false, reason, requestId) end

    Database.UpdateZone(zoneId, zone, function(success)
        release(zoneId)
        if not success then return result(src, 'update', false, 'MySQL no confirmó la actualización.', requestId) end
        SafeZoneCache[zoneId] = zone
        nextRevision()
        broadcast('os_safezone:client:updateZone', zoneId, SafeZoneSchema.DeepCopy(zone))
        SafeZoneLogger.Write(src, 'EDITAR ZONA', ('%s [ID %d]'):format(zone.name, zoneId))
        result(src, 'update', true, ('Cambios guardados: %s'):format(zone.name), requestId)
    end)
end)

RegisterNetEvent('os_safezone:server:deleteZone', function(zoneId, requestId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'delete') then return result(src, 'delete', false, 'No tienes permisos para eliminar zonas.', requestId) end
    zoneId = tonumber(zoneId)
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then return result(src, 'delete', false, 'La zona no existe o ya fue eliminada.', requestId) end
    if not acquire(zoneId) then return result(src, 'delete', false, 'La zona está siendo modificada.', requestId) end

    Database.DeleteZone(zoneId, function(success)
        release(zoneId)
        if not success then return result(src, 'delete', false, 'MySQL no confirmó la eliminación.', requestId) end
        SafeZoneCache[zoneId] = nil
        nextRevision()
        broadcast('os_safezone:client:removeZone', zoneId)
        SafeZoneLogger.Write(src, 'ELIMINAR ZONA', ('%s [ID %d]'):format(zone.name, zoneId))
        result(src, 'delete', true, ('Zona eliminada: %s'):format(zone.name), requestId)
    end)
end)

RegisterNetEvent('os_safezone:server:toggleZone', function(zoneId, state, requestId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'toggle') then return result(src, 'toggle', false, 'No tienes permisos para cambiar el estado.', requestId) end
    zoneId = tonumber(zoneId)
    state = state == true
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then return result(src, 'toggle', false, 'La zona no existe.', requestId) end
    if zone.enabled == state then return result(src, 'toggle', true, state and 'La zona ya estaba activa.' or 'La zona ya estaba desactivada.', requestId) end
    if not acquire(zoneId) then return result(src, 'toggle', false, 'La zona está siendo modificada.', requestId) end

    Database.ToggleZone(zoneId, state, function(success)
        release(zoneId)
        if not success then return result(src, 'toggle', false, 'MySQL no confirmó el cambio.', requestId) end
        zone.enabled = state
        nextRevision()
        broadcast('os_safezone:client:toggleZone', zoneId, state)
        SafeZoneLogger.Write(src, 'CAMBIAR ESTADO', ('%s [ID %d] = %s'):format(zone.name, zoneId, tostring(state)))
        result(src, 'toggle', true, state and 'Zona activada.' or 'Zona desactivada.', requestId)
    end)
end)

RegisterNetEvent('os_safezone:server:teleportToZone', function(zoneId)
    local src = source
    if not SafeZoneSecurity.IsAdmin(src, 'teleport') then return end
    zoneId = tonumber(zoneId)
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then return notify(src, 'La zona no existe.', 'error') end
    TriggerClientEvent('os_safezone:client:authorizedTeleport', src, SafeZoneSchema.DeepCopy(zone.coords), zone.name)
end)

AddEventHandler('playerDropped', function()
    syncRequests[source] = nil
end)

exports('GetSafeZones', function() return snapshot() end)
exports('GetSafeZoneById', function(zoneId)
    local zone = SafeZoneCache[tonumber(zoneId)]
    return zone and SafeZoneSchema.DeepCopy(zone) or nil
end)
exports('SetSafeZoneState', function(zoneId, state)
    zoneId = tonumber(zoneId)
    local zone = zoneId and SafeZoneCache[zoneId]
    if not zone then return false, 'not_found' end
    state = state == true
    if zone.enabled == state then return true end
    Database.ToggleZone(zoneId, state, function(success)
        if success then
            zone.enabled = state
            nextRevision()
            broadcast('os_safezone:client:toggleZone', zoneId, state)
        end
    end)
    return true
end)
