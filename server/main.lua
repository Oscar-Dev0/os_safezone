SafeZoneCache = {}
local LastRequestTime = {}
local RATE_LIMIT_MS = 1000 -- Máximo 1 solicitud administrativa por segundo por jugador

-- Inicializar base de datos y cargar zonas
CreateThread(function()
    Database.Initialize()
    
    -- Esperar un poco para asegurar que las conexiones estén listas
    Wait(1000)
    
    Database.GetAllZones(function(zones)
        SafeZoneCache = zones
        local count = 0
        for _ in pairs(SafeZoneCache) do count = count + 1 end
        Utils.LogInfo(("Cargadas %d zonas seguras en memoria caché."):format(count))
    end)
end)

-- Sistema de Logs Administrativos (Consola, Webhook de Discord y Archivo)
local function LogAction(source, action, details)
    local adminName = source == 0 and "Consola del Servidor" or GetPlayerName(source)
    local identifier = source == 0 and "SYSTEM" or Bridge.GetIdentifier(source)
    
    local logMsg = ("Admin: %s (%s) | Acción: %s | Detalles: %s"):format(adminName, identifier, action, details)
    
    if Config.Logs.Console then
        Utils.LogInfo(logMsg)
    end
    
    if Config.Logs.File then
        local file = io.open("os_safezone.log", "a")
        if file then
            file:write(("[%s] %s\n"):format(os.date("%Y-%m-%d %H:%M:%S"), logMsg))
            file:close()
        end
    end
    
    if Config.Logs.Discord.Enabled and Config.Logs.Discord.Webhook ~= 'TU_WEBHOOK_AQUI' then
        local embed = {
            {
                ["color"] = Config.Logs.Discord.Color,
                ["title"] = "os_safezone Logs",
                ["description"] = logMsg,
                ["footer"] = {
                    ["text"] = "os_safezone - " .. os.date("%Y-%m-%d %H:%M:%S")
                }
            }
        }
        PerformHttpRequest(Config.Logs.Discord.Webhook, function(status, text, headers) end, 'POST', 
            json.encode({username = Config.Logs.Discord.Username, embeds = embed}), 
            { ['Content-Type'] = 'application/json' }
        )
    end
    
    -- Evento externo para integraciones de logs
    TriggerEvent('os_safezone:server:onAdminAction', source, action, details)
end

-- Validaciones de seguridad en el servidor para payloads de zonas
local function ValidateZonePayload(zoneData)
    if not zoneData then return false, "Datos de zona inválidos (nil)" end
    if type(zoneData.name) ~= "string" or #zoneData.name < 3 or #zoneData.name > 100 then
        return false, "Nombre de zona inválido (debe tener entre 3 y 100 caracteres)"
    end
    if type(zoneData.zoneType) ~= "string" or not (zoneData.zoneType == "circle" or zoneData.zoneType == "box" or zoneData.zoneType == "poly") then
        return false, "Tipo de zona inválido"
    end
    if type(zoneData.roleplayType) ~= "string" or not (zoneData.roleplayType == "IC" or zoneData.roleplayType == "OOC" or zoneData.roleplayType == "MIXED" or zoneData.roleplayType == "CUSTOM") then
        return false, "Tipo de Rol inválido"
    end
    if not zoneData.coords or (type(zoneData.coords) ~= "table" and type(zoneData.coords) ~= "vector3") then
        return false, "Coordenadas inválidas"
    end
    if type(zoneData.rules) ~= "table" then
        return false, "Reglas inválidas"
    end
    if type(zoneData.visual) ~= "table" then
        return false, "Visuales inválidos"
    end
    if zoneData.zoneType == "poly" and (type(zoneData.points) ~= "table" or #zoneData.points < 3) then
        return false, "Los polígonos requieren al menos 3 puntos"
    end
    if zoneData.zoneType == "poly" and #zoneData.points > 100 then
        return false, "Límite máximo de 100 puntos excedido en polígono"
    end
    if zoneData.rules.maxVehicleSpeed and type(zoneData.rules.maxVehicleSpeed) ~= "number" then
        return false, "Regla de velocidad máxima debe ser un número"
    end
    if zoneData.rules.passiveAlpha and type(zoneData.rules.passiveAlpha) ~= "number" then
        return false, "La opacidad pasiva debe ser un número"
    end
    
    return true, nil
end

-- Rate limiting y comprobación de rol administrativo
local function IsAuthorizedAdmin(source)
    local now = GetGameTimer()
    if LastRequestTime[source] and (now - LastRequestTime[source]) < RATE_LIMIT_MS then
        Bridge.Notify(source, "Demasiado rápido. Espera un momento.", "error")
        return false
    end
    LastRequestTime[source] = now
    
    if not Permissions.IsAdmin(source) then
        LogAction(source, "ACCESO NO AUTORIZADO", "Intentó ejecutar un comando/evento administrativo sin permisos.")
        return false
    end
    return true
end

-- Sincronización al conectar/iniciar
RegisterNetEvent('os_safezone:server:requestSync', function()
    local src = source
    TriggerClientEvent('os_safezone:client:syncZones', src, SafeZoneCache)
    Utils.LogDebug(("Sincronizadas todas las zonas para el jugador %s (ID: %s)"):format(GetPlayerName(src), src))
end)

-- Evento para CREAR zona
RegisterNetEvent('os_safezone:server:createZone', function(zoneData)
    local src = source
    if not IsAuthorizedAdmin(src) then return end
    
    -- Rellenar defaults para reglas/visuales que falten
    zoneData.rules = zoneData.rules or {}
    zoneData.visual = zoneData.visual or {}
    zoneData.permissions = zoneData.permissions or Constants.DefaultZonePermissions
    zoneData.schedule = zoneData.schedule or {}
    zoneData.enabled = zoneData.enabled ~= false
    zoneData.createdBy = GetPlayerName(src)
    
    -- Validar datos del payload
    local isValid, err = ValidateZonePayload(zoneData)
    if not isValid then
        Bridge.Notify(src, "Error: " .. err, "error")
        return
    end
    
    Database.InsertZone(zoneData, function(success, createdZone)
        if success and createdZone then
            SafeZoneCache[createdZone.id] = createdZone
            -- Enviar solo la nueva zona a todos los clientes conectados
            TriggerClientEvent('os_safezone:client:addZone', -1, createdZone)
            Bridge.Notify(src, "Zona creada correctamente: " .. createdZone.name, "success")
            LogAction(src, "CREAR ZONA", ("Creó zona '%s' con ID %d"):format(createdZone.name, createdZone.id))
        else
            Bridge.Notify(src, "Error al insertar la zona en la base de datos.", "error")
        end
    end)
end)

-- Evento para EDITAR/ACTUALIZAR zona
RegisterNetEvent('os_safezone:server:updateZone', function(zoneId, zoneData)
    local src = source
    if not IsAuthorizedAdmin(src) then return end
    
    zoneId = tonumber(zoneId)
    if not zoneId or not SafeZoneCache[zoneId] then
        Bridge.Notify(src, "ID de zona inválido", "error")
        return
    end
    
    -- Validar datos
    local isValid, err = ValidateZonePayload(zoneData)
    if not isValid then
        Bridge.Notify(src, "Error: " .. err, "error")
        return
    end
    
    zoneData.id = zoneId
    Database.UpdateZone(zoneId, zoneData, function(success)
        if success then
            SafeZoneCache[zoneId] = zoneData
            -- Sincronizar actualización a todos los clientes conectados
            TriggerClientEvent('os_safezone:client:updateZone', -1, zoneId, zoneData)
            Bridge.Notify(src, "Zona actualizada correctamente: " .. zoneData.name, "success")
            LogAction(src, "MODIFICAR ZONA", ("Modificó la zona '%s' (ID: %d)"):format(zoneData.name, zoneId))
        else
            Bridge.Notify(src, "Error al actualizar la zona en base de datos.", "error")
        end
    end)
end)

-- Evento para ELIMINAR zona
RegisterNetEvent('os_safezone:server:deleteZone', function(zoneId)
    local src = source
    if not IsAuthorizedAdmin(src) then return end
    
    zoneId = tonumber(zoneId)
    if not zoneId or not SafeZoneCache[zoneId] then
        Bridge.Notify(src, "ID de zona inválido", "error")
        return
    end
    
    local zoneName = SafeZoneCache[zoneId].name
    Database.DeleteZone(zoneId, function(success)
        if success then
            SafeZoneCache[zoneId] = nil
            -- Sincronizar eliminación con clientes
            TriggerClientEvent('os_safezone:client:removeZone', -1, zoneId)
            Bridge.Notify(src, "Zona eliminada correctamente: " .. zoneName, "success")
            LogAction(src, "ELIMINAR ZONA", ("Eliminó la zona '%s' (ID: %d)"):format(zoneName, zoneId))
        else
            Bridge.Notify(src, "Error al eliminar la zona en base de datos.", "error")
        end
    end)
end)

-- Evento para ACTIVAR/DESACTIVAR zona
RegisterNetEvent('os_safezone:server:toggleZone', function(zoneId, state)
    local src = source
    if not IsAuthorizedAdmin(src) then return end
    
    zoneId = tonumber(zoneId)
    if not zoneId or not SafeZoneCache[zoneId] then
        Bridge.Notify(src, "ID de zona inválido", "error")
        return
    end
    
    local zone = SafeZoneCache[zoneId]
    Database.ToggleZone(zoneId, state, function(success)
        if success then
            zone.enabled = state
            TriggerClientEvent('os_safezone:client:toggleZone', -1, zoneId, state)
            local statusStr = state and "ACTIVA" or "INACTIVA"
            Bridge.Notify(src, ("Zona '%s' cambiada a %s"):format(zone.name, statusStr), "info")
            LogAction(src, "TOGGLE ZONA", ("Cambió estado de la zona '%s' (ID: %d) a %s"):format(zone.name, zoneId, statusStr))
        else
            Bridge.Notify(src, "Error al cambiar estado de la zona en base de datos.", "error")
        end
    end)
end)

-- Evento puente para activaciones temporales o externas de estado
RegisterNetEvent('os_safezone:server:setZoneState', function(zoneId, state)
    exports['os_safezone']:SetSafeZoneState(zoneId, state)
end)

-- ==========================================
-- EXPORTS DEL SERVIDOR
-- ==========================================

exports('GetSafeZones', function()
    return SafeZoneCache
end)

exports('GetSafeZoneById', function(zoneId)
    return SafeZoneCache[tonumber(zoneId)]
end)

exports('SetSafeZoneState', function(zoneId, state)
    zoneId = tonumber(zoneId)
    if not zoneId or not SafeZoneCache[zoneId] then return false end
    
    local zone = SafeZoneCache[zoneId]
    Database.ToggleZone(zoneId, state, function(success)
        if success then
            zone.enabled = state
            TriggerClientEvent('os_safezone:client:toggleZone', -1, zoneId, state)
            LogAction(0, "EXPORT SET STATE", ("Cambió estado de zona '%s' (ID: %d) a %s"):format(zone.name, zoneId, state and "ACTIVA" or "INACTIVA"))
        end
    end)
    return true
end)

-- Interceptar daño de armas en el servidor y cancelarlo si la víctima está en zona segura (Modo Pasivo)
AddEventHandler('weaponDamageEvent', function(sender, ev)
    local hitEntity = NetworkGetEntityFromNetworkId(ev.hitGlobalId)
    if DoesEntityExist(hitEntity) and IsEntityAPed(hitEntity) and IsPedAPlayer(hitEntity) then
        local targetPlayer = NetworkGetEntityOwner(hitEntity)
        if targetPlayer and targetPlayer ~= 0 then
            -- Verificar si el State Bag indica que la víctima está en zona segura protegida
            if Player(targetPlayer).state.inSafeZone then
                CancelEvent()
            end
        end
    end
end)
