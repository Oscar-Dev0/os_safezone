isInsideSafeZone = false
CurrentSafeZone = nil

-- Copia profunda de tabla
local function CopyTable(tbl)
    if not tbl then return nil end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            copy[k] = CopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- ==========================================
-- PRIORIDAD Y RESOLUCIÓN DE REGLAS COINCIDENTES
-- ==========================================

function ResolveActiveSafeZone()
    local highestPriority = -9999
    local count = 0
    
    for id, zone in pairs(InsideZones) do
        count = count + 1
        local prio = zone.priority or 0
        if prio > highestPriority then
            highestPriority = prio
        end
    end
    
    -- Si no está dentro de ninguna zona
    if count == 0 then
        if isInsideSafeZone then
            isInsideSafeZone = false
            CurrentSafeZone = nil
            ForceRemoveRestrictions()
            RestoreWeapon()
            UI.ToggleSafeZoneUI(false)
            
            -- Sincronizar State Bag con el servidor
            LocalPlayer.state:set('inSafeZone', false, true)
            
            -- Redundancia de limpieza de invencibilidad y god-modes
            Citizen.SetTimeout(500, function()
                if not isInsideSafeZone then ForceRemoveRestrictions() end
            end)
            Citizen.SetTimeout(1500, function()
                if not isInsideSafeZone then ForceRemoveRestrictions() end
            end)
        end
        return
    end
    
    -- Si está dentro de una o más zonas
    local previousZone = CurrentSafeZone
    isInsideSafeZone = true
    
    -- Buscar todas las zonas con la prioridad más alta
    local tieZones = {}
    for id, zone in pairs(InsideZones) do
        if (zone.priority or 0) == highestPriority then
            table.insert(tieZones, zone)
        end
    end
    
    if #tieZones == 1 then
        CurrentSafeZone = tieZones[1]
    else
        -- Si hay empate de prioridades, se combinan las reglas de manera determinista (más restrictiva)
        local baseZone = tieZones[1]
        local mergedRules = CopyTable(baseZone.rules)
        
        for i = 2, #tieZones do
            mergedRules = Utils.MergeRules(mergedRules, tieZones[i].rules)
        end
        
        CurrentSafeZone = {
            id = baseZone.id,
            name = baseZone.name,
            roleplayType = baseZone.roleplayType,
            rules = mergedRules,
            visual = baseZone.visual,
            permissions = baseZone.permissions,
            priority = highestPriority
        }
    end
    
    -- Si acabamos de entrar a una zona (no había zona previa)
    if not previousZone then
        SaveAndHideWeapon()
    end
    
    -- Actualizar UI
    UI.ToggleSafeZoneUI(true, CurrentSafeZone)
    
    -- Sincronizar State Bag con el servidor (activo al estar dentro de cualquier zona segura)
    LocalPlayer.state:set('inSafeZone', true, true)
end

function OnPlayerEnterZone(id, zoneData)
    InsideZones[id] = zoneData
    Utils.LogDebug(("Entró a la zona segura: %s [ID: %d]"):format(zoneData.name, id))
    ResolveActiveSafeZone()
end

function OnPlayerExitZone(id, zoneData)
    InsideZones[id] = nil
    Utils.LogDebug(("Salió de la zona segura: %s [ID: %d]"):format(zoneData.name, id))
    ResolveActiveSafeZone()
end

-- ==========================================
-- EVENTOS DE SINCRONIZACIÓN Y RED
-- ==========================================

-- Helper para convertir ActiveZones en un array secuencial para la NUI
local function GetZonesArray()
    local zoneList = {}
    for _, zone in pairs(ActiveZones) do
        table.insert(zoneList, zone)
    end
    return zoneList
end

-- Sincronización completa al conectar
RegisterNetEvent('os_safezone:client:syncZones', function(zones)
    local start = GetGameTimer()
    
    -- Limpiar zonas existentes
    for id, _ in pairs(ActiveZones) do
        UnregisterWorldZone(id)
    end
    
    ActiveZones = {}
    InsideZones = {}
    
    for id, zone in pairs(zones) do
        local numId = tonumber(id) or id
        ActiveZones[numId] = zone
        RegisterWorldZone(numId, zone)
    end
    
    ResolveActiveSafeZone()
    Utils.LogDebug(("Zonas sincronizadas correctamente en %d ms"):format(GetGameTimer() - start))
end)

-- Añadir una nueva zona
RegisterNetEvent('os_safezone:client:addZone', function(zoneData)
    local zoneId = tonumber(zoneData.id) or zoneData.id
    ActiveZones[zoneId] = zoneData
    RegisterWorldZone(zoneId, zoneData)
    Utils.LogDebug(("Nueva zona añadida por el servidor: %s [ID: %d]"):format(zoneData.name, zoneId))
    
    -- Actualizar NUI
    SendNUIMessage({
        action = "updateZones",
        zones = GetZonesArray()
    })
end)

-- Actualizar una zona existente
RegisterNetEvent('os_safezone:client:updateZone', function(zoneId, zoneData)
    zoneId = tonumber(zoneId) or zoneId
    local wasInside = InsideZones[zoneId] ~= nil
    
    -- Registrar de nuevo la zona
    ActiveZones[zoneId] = zoneData
    RegisterWorldZone(zoneId, zoneData)
    
    -- Si el jugador estaba adentro, refrescar su copia en InsideZones
    if wasInside then
        InsideZones[zoneId] = zoneData
    end
    
    ResolveActiveSafeZone()
    Utils.LogDebug(("Zona ID %d actualizada en tiempo real."):format(zoneId))
    
    -- Actualizar NUI
    SendNUIMessage({
        action = "updateZones",
        zones = GetZonesArray()
    })
end)

-- Eliminar una zona
RegisterNetEvent('os_safezone:client:removeZone', function(zoneId)
    zoneId = tonumber(zoneId) or zoneId
    UnregisterWorldZone(zoneId)
    ActiveZones[zoneId] = nil
    InsideZones[zoneId] = nil
    
    ResolveActiveSafeZone()
    Utils.LogDebug(("Zona ID %d eliminada por el servidor."):format(zoneId))
    
    -- Actualizar NUI
    SendNUIMessage({
        action = "updateZones",
        zones = GetZonesArray()
    })
end)

-- Activar / Desactivar zona
RegisterNetEvent('os_safezone:client:toggleZone', function(zoneId, enabled)
    zoneId = tonumber(zoneId) or zoneId
    if ActiveZones[zoneId] then
        ActiveZones[zoneId].enabled = enabled
        if enabled then
            RegisterWorldZone(zoneId, ActiveZones[zoneId])
        else
            UnregisterWorldZone(zoneId)
            InsideZones[zoneId] = nil
        end
        ResolveActiveSafeZone()
        
        -- Actualizar NUI
        SendNUIMessage({
            action = "updateZones",
            zones = GetZonesArray()
        })
    end
end)

-- Carga inicial del script
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('os_safezone:server:requestSync')
end)

-- ==========================================
-- EXPORTS DEL CLIENTE
-- ==========================================

exports('IsPlayerInSafeZone', function()
    return isInsideSafeZone
end)

exports('GetCurrentSafeZone', function()
    return CurrentSafeZone
end)

exports('IsActionBlocked', function(action)
    if not isInsideSafeZone or not CurrentSafeZone or not CurrentSafeZone.rules then 
        return false 
    end
    
    local rules = CurrentSafeZone.rules
    
    if action == 'frisk' or action == 'patdown' then
        return rules.blockFrisk or rules.disableRoleplayActions
    elseif action == 'handcuff' or action == 'cuff' then
        return rules.blockHandcuffs or rules.disableRoleplayActions
    elseif action == 'kidnap' or action == 'carry' then
        return rules.blockKidnap or rules.disableRoleplayActions
    elseif action == 'inventory' then
        return rules.blockInventory
    elseif action == 'weapons' then
        return rules.disableWeapons
    elseif action == 'melee' then
        return rules.disableMelee
    end
    
    return false
end)

-- ==========================================
-- MENÚ ADMINISTRATIVO (NUI TABLET)
-- ==========================================

RegisterNetEvent('os_safezone:client:openAdminMenu', function()
    OpenAdminTablet()
end)

function OpenAdminTablet()
    SendNUIMessage({
        action = "openTablet",
        zones = GetZonesArray(),
        framework = Bridge.GetName(),
        debug = Config.Debug,
        locale = Config.Locale
    })
    SetNuiFocus(true, true)
    Utils.LogDebug("Tablet administrativa abierta.")
end

-- ==========================================
-- REGISTRO DE CALLBACKS NUI (TABLET INTERACTION)
-- ==========================================

RegisterNUICallback('closeTablet', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('teleportToZone', function(data, cb)
    local id = tonumber(data.id)
    local zone = ActiveZones[id]
    if zone then
        local coords = zone.coords
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        Bridge.Notify("Teletransportado a la zona segura " .. zone.name, "success")
    end
    cb('ok')
end)

RegisterNUICallback('createZone', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Usar coordenadas del jugador
    data.coords = coords
    
    -- Cargar perfiles por defecto si no están presentes
    data.rules = Config.Profiles[data.roleplayType] or Config.Profiles.IC
    data.visual = Constants.DefaultZoneVisual
    data.priority = 0
    data.enabled = true
    
    TriggerServerEvent('os_safezone:server:createZone', data)
    cb('ok')
end)

RegisterNUICallback('updateZone', function(data, cb)
    local id = tonumber(data.id)
    if id and data.data then
        TriggerServerEvent('os_safezone:server:updateZone', id, data.data)
    end
    cb('ok')
end)

RegisterNUICallback('deleteZone', function(data, cb)
    local id = tonumber(data.id)
    if id then
        TriggerServerEvent('os_safezone:server:deleteZone', id)
    end
    cb('ok')
end)

RegisterNUICallback('toggleZone', function(data, cb)
    local id = tonumber(data.id)
    if id then
        TriggerServerEvent('os_safezone:server:toggleZone', id, data.state)
    end
    cb('ok')
end)

RegisterNUICallback('drawPolygon', function(data, cb)
    -- Cerrar foco de NUI primero
    SetNuiFocus(false, false)
    
    local minZ = tonumber(data.dimensions.minZ)
    local maxZ = tonumber(data.dimensions.maxZ)
    
    StartDrawingPoly(function(points)
        if points and #points >= 3 then
            data.coords = GetEntityCoords(PlayerPedId())
            data.dimensions = { 
                minZ = minZ > 0 and minZ or (data.coords.z - 5.0), 
                maxZ = maxZ > 0 and maxZ or (data.coords.z + 15.0) 
            }
            data.points = points
            data.rules = Config.Profiles[data.roleplayType] or Config.Profiles.IC
            data.visual = Constants.DefaultZoneVisual
            data.priority = 0
            data.enabled = true
            
            TriggerServerEvent('os_safezone:server:createZone', data)
        end
    end)
    cb('ok')
end)

RegisterNUICallback('requestMyPos', function(data, cb)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    Bridge.Notify(("Tu posición: X: %.1f, Y: %.1f, Z: %.1f"):format(coords.x, coords.y, coords.z), "info")
    cb('ok')
end)
