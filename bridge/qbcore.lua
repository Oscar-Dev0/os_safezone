local active = false
if Config.Framework == 'qbcore' then
    active = true
elseif Config.Framework == 'auto' and GetResourceState('qb-core') == 'started' then
    active = true
end

if active then
    Bridge.FrameworkName = 'qbcore'
    local QBCore = exports['qb-core']:GetCoreObject()

    -- Lógica del Servidor
    if IsDuplicityVersion() then
        function Bridge.GetPlayer(source)
            return QBCore.Functions.GetPlayer(source)
        end

        function Bridge.GetIdentifier(source)
            local Player = QBCore.Functions.GetPlayer(source)
            return Player and Player.PlayerData.license or nil
        end

        function Bridge.GetJob(source)
            local Player = QBCore.Functions.GetPlayer(source)
            if Player and Player.PlayerData.job then
                return {
                    name = Player.PlayerData.job.name,
                    grade = Player.PlayerData.job.grade.level
                }
            end
            return { name = 'unemployed', grade = 0 }
        end

        function Bridge.HasGroup(source, groupName)
            local Player = QBCore.Functions.GetPlayer(source)
            if Player then
                if Player.PlayerData.job and Player.PlayerData.job.name == groupName then
                    return true
                end
                if Player.PlayerData.gang and Player.PlayerData.gang.name == groupName then
                    return true
                end
            end
            return false
        end

        function Bridge.Notify(source, message, type)
            TriggerClientEvent('QBCore:Notify', source, message, type)
        end

        function Bridge.IsAdmin(source)
            -- Comprobar si tiene permiso de QBCore
            for group, _ in pairs(Config.AdminPermissions.FrameworkGroups) do
                if QBCore.Functions.HasPermission(source, group) then
                    return true
                end
            end
            -- Fallback a ACE e Identificadores
            if Config.AdminPermissions.UseAce and IsPlayerAceAllowed(source, Config.AdminPermissions.AcePermission) then
                return true
            end
            local identifier = Bridge.GetIdentifier(source)
            if identifier then
                for _, adminId in ipairs(Config.AdminPermissions.Identifiers) do
                    if adminId == identifier then
                        return true
                    end
                end
            end
            return false
        end

    -- Lógica del Cliente
    else
        local PlayerData = {}

        CreateThread(function()
            while not QBCore.Functions.GetPlayerData() do
                Wait(100)
            end
            PlayerData = QBCore.Functions.GetPlayerData()
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
            TriggerServerEvent('os_safezone:server:requestSync')
        end)

        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerData.job = job
        end)

        RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
            PlayerData.gang = gang
        end)

        function Bridge.GetJob()
            if PlayerData and PlayerData.job then
                return {
                    name = PlayerData.job.name,
                    grade = PlayerData.job.grade.level
                }
            end
            return { name = 'unemployed', grade = 0 }
        end

        function Bridge.HasGroup(groupName)
            if PlayerData then
                if PlayerData.job and PlayerData.job.name == groupName then
                    return true
                end
                if PlayerData.gang and PlayerData.gang.name == groupName then
                    return true
                end
            end
            return false
        end

        function Bridge.Notify(message, type)
            QBCore.Functions.Notify(message, type)
        end
    end
end
