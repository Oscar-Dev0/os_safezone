local SavedWeaponHash = nil
local SavedWeaponAmmo = 0
local LastSafezoneVehicle = nil

-- Guarda y guarda el arma equipada actual
function SaveAndHideWeapon()
    local ped = PlayerPedId()
    
    -- Compatibilidad con ox_inventory
    if GetResourceState('ox_inventory') == 'started' then
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon ~= `WEAPON_UNARMED` and not Config.WhitelistedWeapons[currentWeapon] then
            local bypass = false
            if CurrentSafeZone and CurrentSafeZone.rules and CurrentSafeZone.rules.allowEmergencyWeapons then
                local job = Bridge.GetJob()
                if Config.EmergencyJobs[job.name] then
                    bypass = true
                end
            end
            
            if not bypass then
                TriggerEvent('ox_inventory:disarm')
                Utils.LogDebug("ox_inventory: Arma guardada automáticamente al entrar a la zona segura.")
            end
        end
        return
    end

    -- Lógica normal para otros inventarios
    local currentWeapon = GetSelectedPedWeapon(ped)
    if currentWeapon ~= `WEAPON_UNARMED` and not Config.WhitelistedWeapons[currentWeapon] then
        SavedWeaponHash = currentWeapon
        local _, ammo = GetAmmoInPedWeapon(ped, currentWeapon)
        SavedWeaponAmmo = ammo
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        Utils.LogDebug(("Arma guardada al entrar: Hash %s (Balas: %s)"):format(currentWeapon, ammo))
    else
        SavedWeaponHash = nil
    end
end

-- Restaura el arma guardada al salir
function RestoreWeapon()
    -- Con ox_inventory no forzamos re-equipar para evitar desincronizaciones de slots
    if GetResourceState('ox_inventory') == 'started' then
        return
    end

    if SavedWeaponHash and SavedWeaponHash ~= `WEAPON_UNARMED` then
        local ped = PlayerPedId()
        GiveWeaponToPed(ped, SavedWeaponHash, SavedWeaponAmmo, true, true)
        Utils.LogDebug("Arma restaurada al salir de la zona segura.")
        SavedWeaponHash = nil
    end
end

-- Escuchar evento de ox_inventory al cambiar/equipar arma
RegisterNetEvent('ox_inventory:currentWeapon', function(weapon)
    if weapon and weapon.hash and isInsideSafeZone and CurrentSafeZone and CurrentSafeZone.rules then
        local rules = CurrentSafeZone.rules
        if rules.disableWeapons then
            local bypass = false
            
            -- Bypass de servicios de emergencia
            if rules.allowEmergencyWeapons then
                local job = Bridge.GetJob()
                if Config.EmergencyJobs[job.name] then
                    bypass = true
                end
            end
            
            if not bypass and not Config.WhitelistedWeapons[weapon.hash] then
                -- Forzar desequipar arma en ox_inventory
                TriggerEvent('ox_inventory:disarm')
                Utils.LogDebug("ox_inventory: Bloqueado equipamiento de arma en zona segura.")
            end
        end
    end
end)

-- Secuencia redundante de seguridad para remover invencibilidad y reestablecer estados
function ForceRemoveRestrictions()
    local playerPed = PlayerPedId()
    local playerId = PlayerId()
    
    -- Quitar invencibilidad y efectos de modo pasivo
    SetPlayerInvincible(playerId, false)
    SetEntityInvincible(playerPed, false)
    SetEntityCanBeDamaged(playerPed, true)
    SetEntityOnlyDamagedByPlayer(playerPed, false)
    SetEntityProofs(playerPed, false, false, false, false, false, false, false, false)
    SetPedCanRagdoll(playerPed, true)
    SetPedConfigFlag(playerPed, 17, false)
    ResetEntityAlpha(playerPed)
    
    -- Limpiar State Bags y tracking de vehículos de no colisión
    LocalPlayer.state:set('noCollision', false, true)
    if LastSafezoneVehicle then
        if DoesEntityExist(LastSafezoneVehicle) then
            Entity(LastSafezoneVehicle).state:set('noCollision', false, true)
            ResetEntityAlpha(LastSafezoneVehicle)
        end
        LastSafezoneVehicle = nil
    end
    
    -- Reestablecer límites de velocidad de vehículos
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle ~= 0 then
        SetEntityMaxSpeed(vehicle, 1000.0) -- Quitar límite de velocidad
        SetEntityCanBeDamaged(vehicle, true)
        SetEntityInvincible(vehicle, false)
        SetEntityProofs(vehicle, false, false, false, false, false, false, false, false)
        SetVehicleTyresCanBurst(vehicle, true)
        ResetEntityAlpha(vehicle)
        Entity(vehicle).state:set('noCollision', false, true)
    end
    
    -- Reestablecer disparos
    SetPlayerCanDoDriveBy(playerId, true)
    DisablePlayerFiring(playerPed, false)
    
    Utils.LogDebug("Restricciones removidas completamente.")
end

-- Hilo principal para la aplicación de restricciones y reglas en tiempo real (0ms)
CreateThread(function()
    while true do
        local sleep = 500
        
        if isInsideSafeZone and CurrentSafeZone and CurrentSafeZone.rules then
            sleep = 0
            local ped = PlayerPedId()
            local playerId = PlayerId()
            local rules = CurrentSafeZone.rules
            local myVeh = GetVehiclePedIsIn(ped, false)
            
            -- Calcular alfa
            local alphaVal = 255
            if rules.passiveAlpha then
                alphaVal = math.max(0, math.min(255, math.floor(tonumber(rules.passiveAlpha) or 255)))
            end
            
            -- 1. Regla: Invencibilidad de Jugador (Modo Pasivo GTA Online)
            if rules.invinciblePlayers then
                SetPlayerInvincible(playerId, true)
                SetEntityInvincible(ped, true)
                SetEntityCanBeDamaged(ped, false)
                SetEntityProofs(ped, true, true, true, true, true, true, true, true)
                SetEntityHealth(ped, GetEntityMaxHealth(ped))
                
                if not GetPlayerInvincible(playerId) then
                    SetPedCanRagdoll(ped, false)
                    SetPedConfigFlag(ped, 17, true)
                end
            else
                -- Si la zona no especifica invencibilidad activa, aplicar protección básica contra armas (balas/melee/explosiones)
                -- para evitar que los maten desde fuera, pero manteniendo vulnerabilidad IC normal (caídas, etc.)
                SetEntityProofs(ped, true, false, true, false, true, false, false, false)
                
                if GetPlayerInvincible(playerId) then
                    SetPlayerInvincible(playerId, false)
                    SetEntityInvincible(ped, false)
                    SetEntityCanBeDamaged(ped, true)
                end
            end
            
            -- Aplicar transparencia (alfa) y registrar no colisión si está activado el modo pasivo o sin colisiones
            if rules.invinciblePlayers or rules.disableCollisions then
                SetEntityAlpha(ped, alphaVal, false)
                LocalPlayer.state:set('noCollision', true, true)
                
                if myVeh ~= 0 then
                    if LastSafezoneVehicle and LastSafezoneVehicle ~= myVeh then
                        if DoesEntityExist(LastSafezoneVehicle) then
                            Entity(LastSafezoneVehicle).state:set('noCollision', false, true)
                            ResetEntityAlpha(LastSafezoneVehicle)
                        end
                    end
                    LastSafezoneVehicle = myVeh
                    Entity(myVeh).state:set('noCollision', true, true)
                    SetEntityAlpha(myVeh, alphaVal, false)
                else
                    if LastSafezoneVehicle then
                        if DoesEntityExist(LastSafezoneVehicle) then
                            Entity(LastSafezoneVehicle).state:set('noCollision', false, true)
                            ResetEntityAlpha(LastSafezoneVehicle)
                        end
                        LastSafezoneVehicle = nil
                    end
                end
            else
                ResetEntityAlpha(ped)
                LocalPlayer.state:set('noCollision', false, true)
                
                if LastSafezoneVehicle then
                    if DoesEntityExist(LastSafezoneVehicle) then
                        Entity(LastSafezoneVehicle).state:set('noCollision', false, true)
                        ResetEntityAlpha(LastSafezoneVehicle)
                    end
                    LastSafezoneVehicle = nil
                end
                if myVeh ~= 0 then
                    Entity(myVeh).state:set('noCollision', false, true)
                    ResetEntityAlpha(myVeh)
                end
            end
            
            -- 2. Regla: Desarmar y guardar armas
            if rules.disableWeapons then
                -- Deshabilitar selección de armas (evita flickering y animaciones glitch)
                DisableControlAction(0, 37, true) -- Rueda de armas
                for i = 157, 165 do
                    DisableControlAction(0, i, true) -- Teclas 1-9 de armas
                end
                
                local currentWeapon = GetSelectedPedWeapon(ped)
                if currentWeapon ~= `WEAPON_UNARMED` and not Config.WhitelistedWeapons[currentWeapon] then
                    local bypass = false
                    
                    -- Bypass de servicios de emergencia
                    if rules.allowEmergencyWeapons then
                        local job = Bridge.GetJob()
                        if Config.EmergencyJobs[job.name] then
                            bypass = true
                        end
                    end
                    
                    if not bypass then
                        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                    end
                end
            end
            
            -- 3. Regla: Deshabilitar disparos de armas
            if rules.disableFiring then
                DisablePlayerFiring(ped, true)
                DisableControlAction(0, 24, true)  -- Attack
                DisableControlAction(0, 25, true)  -- Aim
                DisableControlAction(0, 257, true) -- Attack 2
            end
            
            -- 4. Regla: Deshabilitar golpes / combate cuerpo a cuerpo
            if rules.disableMelee then
                DisableControlAction(0, 140, true) -- Light punch
                DisableControlAction(0, 141, true) -- Heavy punch
                DisableControlAction(0, 142, true) -- Melee Attack
                DisableControlAction(0, 263, true) -- Melee 1
                DisableControlAction(0, 264, true) -- Melee 2
            end
            
            -- 5. Regla: Deshabilitar disparos desde vehículos (DriveBy)
            if rules.disableDriveBy then
                SetPlayerCanDoDriveBy(playerId, false)
            end
            
            -- Restricciones de vehículos
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 then
                -- 6. Regla: Invencibilidad de vehículos
                if rules.invincibleVehicles then
                    SetEntityInvincible(vehicle, true)
                    SetEntityCanBeDamaged(vehicle, false)
                    SetEntityProofs(vehicle, true, true, true, true, true, true, true, true)
                    SetVehicleTyresCanBurst(vehicle, false)
                    SetVehicleBodyHealth(vehicle, 1000.0)
                    SetVehicleEngineHealth(vehicle, 1000.0)
                end
                
                -- 7. Regla: Sin colisiones de vehículos (Anti-Raming) - Manejado globalmente por el hilo de fondo
                
                -- 8. Regla: Velocidad máxima
                if rules.maxVehicleSpeed and rules.maxVehicleSpeed > 0 then
                    local maxSpeedMs = rules.maxVehicleSpeed / 3.6
                    local currentSpeed = GetEntitySpeed(vehicle)
                    
                    if currentSpeed > maxSpeedMs then
                        -- Forzar velocidad del vehículo
                        SetEntityMaxSpeed(vehicle, maxSpeedMs)
                        local vel = GetEntityVelocity(vehicle)
                        local mult = maxSpeedMs / currentSpeed
                        SetEntityVelocity(vehicle, vel.x * mult, vel.y * mult, vel.z * mult)
                    end
                end
            end
            
            -- 9. Regla: Bloquear robo de vehículos (jacking)
            if rules.blockVehicleTheft then
                if GetVehiclePedIsTryingToEnter(ped) ~= 0 then
                    local targetVeh = GetVehiclePedIsTryingToEnter(ped)
                    local driver = GetPedInVehicleSeat(targetVeh, -1)
                    if driver ~= 0 and driver ~= ped then
                        ClearPedTasksImmediately(ped)
                        UI.ShowActionBlockedMessage(_L("theft_blocked"))
                    end
                end
            end
            
            -- 10. Regla: Bloquear inventario
            if rules.blockInventory then
                DisableControlAction(0, 37, true)  -- Tab / Rueda de armas
                DisableControlAction(0, 289, true) -- F2 (Común en inventarios de FiveM)
                
                if IsDisabledControlJustPressed(0, 37) or IsDisabledControlJustPressed(0, 289) then
                    UI.ShowActionBlockedMessage(_L("inventory_blocked"))
                end
            end
            
            -- 11. Regla: Bloquear acciones de Rol / Comandos específicos
            -- (Los comandos se filtran también en el cliente o servidor)
            if rules.disableRoleplayActions then
                -- Bloquear el cacheo, esposas y secuestros en la lógica general
            end
        end
        
        Wait(sleep)
    end
end)

-- Red de seguridad absoluta para evitar daño por desincronización o disparos desde fuera de la zona (OneSync)
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        
        if victim == PlayerPedId() and isInsideSafeZone then
            if CurrentSafeZone and CurrentSafeZone.rules and CurrentSafeZone.rules.invinciblePlayers then
                -- Restaurar salud inmediatamente al máximo para contrarrestar daño sincronizado de armas de fuego
                local maxHealth = GetEntityMaxHealth(victim)
                SetEntityHealth(victim, maxHealth)
                -- Limpiar marcas de sangre y heridas visuales en la ropa/cuerpo
                ClearPedLastDamageEntity(victim)
                ResetPedVisibleDamage(victim)
            end
        end
    end
end)

-- Hilo de resolución de colisiones en segundo plano basado en State Bags
CreateThread(function()
    while true do
        local sleep = 500
        local myPed = PlayerPedId()
        local myVeh = GetVehiclePedIsIn(myPed, false)
        local isLocalNoCollision = LocalPlayer.state.noCollision
        
        -- Loop active players to disable collision if they (or we) have noCollision
        local activePlayers = GetActivePlayers()
        for i = 1, #activePlayers do
            local player = activePlayers[i]
            if player ~= PlayerId() then
                local targetPed = GetPlayerPed(player)
                if targetPed ~= 0 then
                    local serverId = GetPlayerServerId(player)
                    if isLocalNoCollision or Player(serverId).state.noCollision then
                        sleep = 0
                        SetEntityNoCollisionEntity(myPed, targetPed, true)
                        if myVeh ~= 0 then
                            SetEntityNoCollisionEntity(myVeh, targetPed, true)
                        end
                        
                        -- Deshabilitar colisión también si el target está en un vehículo
                        local targetVeh = GetVehiclePedIsIn(targetPed, false)
                        if targetVeh ~= 0 then
                            SetEntityNoCollisionEntity(myPed, targetVeh, true)
                            if myVeh ~= 0 and myVeh ~= targetVeh then
                                SetEntityNoCollisionEntity(myVeh, targetVeh, true)
                            end
                        end
                    end
                end
            end
        end
        
        -- Loop vehicles in pool to disable collision if they (or we) have noCollision
        local vehicles = GetGamePool('CVehicle')
        for i = 1, #vehicles do
            local otherVeh = vehicles[i]
            if otherVeh ~= myVeh then
                if isLocalNoCollision or Entity(otherVeh).state.noCollision then
                    sleep = 0
                    SetEntityNoCollisionEntity(myPed, otherVeh, true)
                    if myVeh ~= 0 then
                        SetEntityNoCollisionEntity(myVeh, otherVeh, true)
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)
