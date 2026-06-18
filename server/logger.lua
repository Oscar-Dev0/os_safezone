SafeZoneLogger = {}

function SafeZoneLogger.Write(source, action, details)
    local name = source == 0 and 'Consola' or (GetPlayerName(source) or ('ID ' .. tostring(source)))
    local identifier = source == 0 and 'SYSTEM' or (Bridge.GetIdentifier(source) or 'unknown')
    local message = ('Admin: %s (%s) | Acción: %s | %s'):format(name, identifier, action, details)

    if Config.Logs.Console then Utils.LogInfo(message) end

    if Config.Logs.File then
        local previous = LoadResourceFile(GetCurrentResourceName(), 'os_safezone.log') or ''
        local line = ('[%s] %s\n'):format(os.date('%Y-%m-%d %H:%M:%S'), message)
        -- Evita que el archivo crezca sin límite.
        if #previous > 1024 * 1024 then previous = previous:sub(-512 * 1024) end
        SaveResourceFile(GetCurrentResourceName(), 'os_safezone.log', previous .. line, -1)
    end

    local discord = Config.Logs.Discord
    if discord.Enabled and discord.Webhook and discord.Webhook ~= '' and discord.Webhook ~= 'TU_WEBHOOK_AQUI' then
        PerformHttpRequest(discord.Webhook, function() end, 'POST', json.encode({
            username = discord.Username,
            embeds = {{
                color = discord.Color,
                title = 'os_safezone Logs',
                description = message,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') }
            }}
        }), { ['Content-Type'] = 'application/json' })
    end

    TriggerEvent('os_safezone:server:onAdminAction', source, action, details)
end
