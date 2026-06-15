fx_version 'cerulean'
game 'gta5'

author 'Oscar / Antigravity'
description 'Sistema avanzado de zonas seguras modular, configurable y persistente'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/locales.lua'
}

client_scripts {
    'bridge/standalone.lua',
    'bridge/qbcore.lua',
    'bridge/qbox.lua',
    'bridge/esx.lua',
    'client/ui.lua',
    'client/restrictions.lua',
    'client/zones.lua',
    'client/compatibility.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/standalone.lua',
    'bridge/qbcore.lua',
    'bridge/qbox.lua',
    'bridge/esx.lua',
    'server/permissions.lua',
    'server/database.lua',
    'server/commands.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

exports {
    -- Client Exports
    'IsPlayerInSafeZone',
    'GetCurrentSafeZone',
    'IsActionBlocked',
    'createSafe',
    
    -- Server Exports
    'GetSafeZones',
    'GetSafeZoneById',
    'SetSafeZoneState'
}
