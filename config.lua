Config = {}

-- Framework a utilizar. Valores: 'auto', 'standalone', 'qbcore', 'qbox', 'esx'
-- 'auto' detectará automáticamente el framework cargado.
Config.Framework = 'auto'

-- Activar modo depuración para mostrar logs en consola y previsualizaciones adicionales
Config.Debug = false

-- Comando para abrir el menú de administración (ox_lib)
Config.AdminCommand = 'safezones'

-- Anti-spam para acciones administrativas enviadas desde NUI.
Config.AdminRateLimitMs = 750

-- Idioma por defecto. Corresponde a los definidos en shared/locales.lua
Config.Locale = 'es'

-- Lista de armas y herramientas permitidas (whitelisted) dentro de cualquier zona segura.
-- Por defecto se permiten objetos no letales, extintores, linternas, paracaídas, etc.
Config.WhitelistedWeapons = {
    [`WEAPON_UNARMED`] = true,
    [`WEAPON_FIREEXTINGUISHER`] = true,
    [`WEAPON_PETROLCAN`] = true,
    [`WEAPON_FLASHLIGHT`] = true,
    [`WEAPON_NIGHTSTICK`] = true,
    [`WEAPON_PARACHUTE`] = true,
    [`WEAPON_HAZARDCAN`] = true,
}

-- Configuración de permisos administrativos para el panel de control
Config.AdminPermissions = {
    -- Si está en true, verificará permisos ACE (ej. `add_ace group.admin command.safezones allow` o `safezones.admin`)
    UseAce = true,
    AcePermission = 'safezones.admin',

    -- Rangos de frameworks autorizados a usar el menú
    FrameworkGroups = {
        ['admin'] = true,
        ['superadmin'] = true,
        ['god'] = true,
        ['owner'] = true
    },

    -- Identificadores específicos de Rockstar/Steam/Discord con acceso total de administración
    Identifiers = {
        -- 'license:xxxxxxxxx',
        -- 'discord:xxxxxxxxx'
    }
}

-- Perfiles de reglas por defecto. Las zonas pueden heredar un perfil y sobrescribir reglas específicas.
Config.Profiles = {
    IC = {
        disableWeapons = true,
        disableFiring = true,
        disableMelee = true,
        disableDriveBy = true,
        disableVehicleDamage = true,
        invinciblePlayers = true,
        invincibleVehicles = true,
        disableCollisions = true,
        maxVehicleSpeed = 60.0, -- km/h
        allowEmergencyWeapons = true, -- Permite a policías/médicos usar armas
        hideWeaponOnEnter = true,
        restoreWeaponOnExit = true,
        blockVehicleTheft = true,
        blockFrisk = true,
        blockHandcuffs = true,
        blockKidnap = true,
        blockInventory = true,
        disableRoleplayActions = false,
        passiveAlpha = 255
    },

    OOC = {
        disableWeapons = false,
        disableFiring = false,
        disableMelee = false,
        disableDriveBy = false,
        disableVehicleDamage = false,
        invinciblePlayers = false,
        invincibleVehicles = false,
        disableCollisions = false,
        maxVehicleSpeed = 30.0, -- km/h
        allowEmergencyWeapons = false,
        hideWeaponOnEnter = true,
        restoreWeaponOnExit = true,
        blockVehicleTheft = true,
        blockFrisk = true,
        blockHandcuffs = true,
        blockKidnap = true,
        blockInventory = true,
        disableRoleplayActions = true,
        passiveAlpha = 150
    },

    MIXED = {
        disableWeapons = true,
        disableFiring = true,
        disableMelee = true,
        disableDriveBy = true,
        disableVehicleDamage = false,
        invinciblePlayers = false,
        invincibleVehicles = false,
        disableCollisions = false,
        maxVehicleSpeed = 50.0,
        allowEmergencyWeapons = true,
        hideWeaponOnEnter = true,
        restoreWeaponOnExit = true,
        blockVehicleTheft = true,
        blockFrisk = false,
        blockHandcuffs = true,
        blockKidnap = true,
        blockInventory = false,
        disableRoleplayActions = false,
        passiveAlpha = 200
    },

    CUSTOM = {
        disableWeapons = false,
        disableFiring = false,
        disableMelee = false,
        disableDriveBy = false,
        disableVehicleDamage = false,
        invinciblePlayers = false,
        invincibleVehicles = false,
        disableCollisions = false,
        maxVehicleSpeed = -1.0, -- Desactivado
        allowEmergencyWeapons = false,
        hideWeaponOnEnter = false,
        restoreWeaponOnExit = false,
        blockVehicleTheft = false,
        blockFrisk = false,
        blockHandcuffs = false,
        blockKidnap = false,
        blockInventory = false,
        disableRoleplayActions = false,
        passiveAlpha = 255
    }
}

-- Configuración de Logs administrativos
Config.Logs = {
    Console = true,           -- Mostrar logs en la consola del servidor
    File = true,              -- Guardar logs en un archivo local ('os_safezone.log')
    Discord = {
        Enabled = false,
        Webhook = 'TU_WEBHOOK_AQUI',
        Color = 3447003,       -- Color del embed (decimal)
        Username = 'os_safezone Logs'
    }
}

-- Configuración de tipos de trabajos considerados "servicios de emergencia"
Config.EmergencyJobs = {
    ['police'] = true,
    ['sheriff'] = true,
    ['ambulance'] = true,
    ['medical'] = true,
}
