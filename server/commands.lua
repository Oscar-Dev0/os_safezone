-- Comando principal de administración
RegisterCommand(Config.AdminCommand, function(source, args, rawCommand)
    -- Si se ejecuta desde la consola del servidor (RCON)
    if source == 0 then
        Utils.LogError("El panel administrativo solo puede abrirse desde el cliente del juego.")
        return
    end

    -- Validar si el jugador tiene permisos de administrador
    if Permissions.IsAdmin(source) then
        TriggerClientEvent('os_safezone:client:openAdminMenu', source)
        Utils.LogDebug(("Administrador %s (ID: %s) abrió el menú de safezones."):format(GetPlayerName(source), source))
    else
        Bridge.Notify(source, _L("action_blocked"), "error")
    end
end, false)

-- Si se utiliza sistema ACE, podemos sugerir el comando al sistema de sugerencias de FiveM
CreateThread(function()
    if Config.AdminPermissions.UseAce then
        -- Opcional: registrar el comando con el asertor de ACE en el motor
        -- Esto permite que GTA lo autocomplete solo si se tienen permisos
        -- RegisterKeyMapping u otras utilidades.
    end
end)
