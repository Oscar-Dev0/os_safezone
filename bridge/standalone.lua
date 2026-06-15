Bridge = Bridge or {}
Bridge.FrameworkName = 'standalone'

function Bridge.GetName()
    return Bridge.FrameworkName
end

-- Lógica del Servidor
if IsDuplicityVersion() then
    function Bridge.GetPlayer(source)
        return nil
    end

    function Bridge.GetIdentifier(source)
        for i = 0, GetNumPlayerIdentifiers(source) - 1 do
            local id = GetPlayerIdentifier(source, i)
            if string.match(id, "license:") then
                return id
            end
        end
        return GetPlayerIdentifier(source, 0)
    end

    function Bridge.GetJob(source)
        return { name = 'unemployed', grade = 0 }
    end

    function Bridge.HasGroup(source, groupName)
        return false
    end

    function Bridge.Notify(source, message, type)
        TriggerClientEvent('os_safezone:client:Notify', source, message, type)
    end

    function Bridge.IsAdmin(source)
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
    function Bridge.GetJob()
        return { name = 'unemployed', grade = 0 }
    end

    function Bridge.HasGroup(groupName)
        return false
    end

    function Bridge.Notify(message, type)
        if GetResourceState('ox_lib') == 'started' then
            lib.notify({
                title = 'os_safezone',
                description = message,
                type = type or 'info'
            })
        else
            -- Notificación nativa de GTA V
            SetNotificationTextEntry("STRING")
            AddTextComponentString(message)
            DrawNotification(true, false)
        end
    end

    RegisterNetEvent('os_safezone:client:Notify', function(message, type)
        Bridge.Notify(message, type)
    end)
end
