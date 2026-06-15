Constants = {}

-- Nombres y descripciones de las reglas para mostrarlas en el menú administrativo
Constants.RuleDefinitions = {
    disableWeapons = { label = "Desarmar al entrar", desc = "Guarda las armas automáticamente" },
    disableFiring = { label = "Bloquear disparos", desc = "Deshabilita el disparo de armas" },
    disableMelee = { label = "Bloquear combate cuerpo a cuerpo", desc = "Previene golpes físicos y con objetos" },
    disableDriveBy = { label = "Bloquear disparos desde vehículos", desc = "Deshabilita driveby" },
    disableVehicleDamage = { label = "Vehículos indestructibles", desc = "Previene daño a vehículos dentro" },
    invinciblePlayers = { label = "Jugadores invencibles", desc = "El jugador no recibe ningún tipo de daño" },
    invincibleVehicles = { label = "Vehículos invencibles", desc = "El vehículo no recibe daño estructural o de motor" },
    disableCollisions = { label = "Sin colisiones de vehículos", desc = "Deshabilita choques entre vehículos" },
    maxVehicleSpeed = { label = "Velocidad máxima de vehículos", desc = "Límite de velocidad en km/h" },
    allowEmergencyWeapons = { label = "Bypass servicios de emergencia", desc = "Policías y médicos pueden portar armas" },
    hideWeaponOnEnter = { label = "Guardar arma al entrar", desc = "Oculta el arma del jugador al ingresar" },
    restoreWeaponOnExit = { label = "Restaurar arma al salir", desc = "Equipa el arma anterior al salir" },
    blockVehicleTheft = { label = "Bloquear robo de vehículos", desc = "Previene jacking/robar vehículos de otros" },
    blockFrisk = { label = "Bloquear cacheos", desc = "Previene cachear o registrar al jugador" },
    blockHandcuffs = { label = "Bloquear esposas", desc = "Previene que esposen al jugador" },
    blockKidnap = { label = "Bloquear secuestros", desc = "Previene cargar o secuestrar al jugador" },
    blockInventory = { label = "Bloquear inventario", desc = "Previene abrir mochilas/inventario" },
    disableRoleplayActions = { label = "Bloquear acciones de Rol", desc = "Restringe esposas, cacheos y secuestros por completo" }
}

-- Configuración por defecto para inicializar una nueva zona
Constants.DefaultZoneRules = {
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
    blockHandcuffs = false,
    blockKidnap = false,
    blockInventory = false,
    disableRoleplayActions = false
}

Constants.DefaultZoneVisual = {
    blip = true,
    radiusBlip = true,
    marker = false,
    color = { r = 40, g = 180, b = 90, a = 100 },
    sprite = 389, -- Escudo por defecto
    scale = 0.8
}

Constants.DefaultZonePermissions = {
    bypass = {
        jobs = {},
        identifiers = {}
    }
}
