local active = false
if Config.Framework == 'esx' then
    active = true
elseif Config.Framework == 'auto' and GetResourceState('es_extended') == 'started' then
    active = true
end

if active then
    Bridge.FrameworkName = 'esx'
    local ESX = exports['es_extended']:getSharedObject()

    -- Lógica del Servidor
    if IsDuplicityVersion() then
        function Bridge.GetPlayer(source)
            return ESX.GetPlayerFromId(source)
        end

        function Bridge.GetIdentifier(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            return xPlayer and xPlayer.getIdentifier() or nil
        end

        function Bridge.GetJob(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer and xPlayer.job then
                return {
                    name = xPlayer.job.name,
                    grade = xPlayer.job.grade
                }
            end
            return { name = 'unemployed', grade = 0 }
        end

        function Bridge.HasGroup(source, groupName)
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                if xPlayer.job and xPlayer.job.name == groupName then
                    return true
                end
            end
            return false
        end

        function Bridge.Notify(source, message, type)
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                xPlayer.showNotification(message, type)
            end
        end

        function Bridge.IsAdmin(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                local group = xPlayer.getGroup()
                if Config.AdminPermissions.FrameworkGroups[group] then
                    return true
                end
            end
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
            while ESX.GetPlayerData() == nil or ESX.GetPlayerData().job == nil do
                Wait(100)
            end
            PlayerData = ESX.GetPlayerData()
        end)

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            TriggerServerEvent('os_safezone:server:requestSync')
        end)

        RegisterNetEvent('esx:setJob', function(job)
            PlayerData.job = job
        end)

        function Bridge.GetJob()
            if PlayerData and PlayerData.job then
                return {
                    name = PlayerData.job.name,
                    grade = PlayerData.job.grade
                }
            end
            return { name = 'unemployed', grade = 0 }
        end

        function Bridge.HasGroup(groupName)
            if PlayerData and PlayerData.job and PlayerData.job.name == groupName then
                return true
            end
            return false
        end

        function Bridge.Notify(message, type)
            ESX.ShowNotification(message, type)
        end
    end
end
