Locales = {}

Locales['es'] = {
    -- Alertas de Zonas
    entered_ic = 'Has entrado a una zona segura (IC). Mantén el rol de entorno.',
    entered_ooc = 'Has entrado a una zona segura (OOC). Rol de combate deshabilitado.',
    entered_mixed = 'Has entrado a una zona segura mixta.',
    entered_custom = 'Has entrado a una zona de reglas personalizadas.',
    exited = 'Has salido de la zona segura.',
    
    -- Mensajes de Restricciones
    action_blocked = 'Esta acción está bloqueada dentro de esta zona.',
    weapon_blocked = 'No puedes desenfundar armas en esta zona.',
    melee_blocked = 'Los golpes están deshabilitados en esta zona.',
    driveby_blocked = 'Los disparos desde vehículos están deshabilitados en esta zona.',
    speed_limited = 'Velocidad regulada a %s km/h en esta zona.',
    theft_blocked = 'El robo de vehículos está bloqueado aquí.',
    inventory_blocked = 'No puedes abrir tu inventario en esta zona.',
    command_blocked = 'El comando %s está bloqueado en esta zona.',
    
    -- Menú Administrativo
    admin_title = 'Administración de Zonas Seguras',
    manage_zones = 'Gestionar Zonas Existentes',
    create_zone = 'Crear Nueva Zona',
    zone_list = 'Lista de Zonas',
    zone_details = 'Detalles de la Zona: %s',
    zone_name = 'Nombre de la Zona',
    zone_type = 'Tipo de Zona',
    rp_type = 'Tipo de Rol (IC/OOC/MIXED/CUSTOM)',
    rules_setup = 'Configurar Reglas',
    visual_setup = 'Configurar Visuales',
    permissions_setup = 'Configurar Permisos/Excepciones',
    save = 'Guardar Zona',
    delete = 'Eliminar Zona',
    confirm_delete = '¿Estás seguro de eliminar esta zona?',
    teleport = 'Teletransportarse a la zona',
    toggle_enabled = 'Activar / Desactivar',
    duplicate = 'Duplicar Zona',
    
    -- Dibujado de Zonas (Points Creator)
    draw_instructions = 'Presiona [E] para añadir punto | [G] para borrar último | [ENTER] para confirmar | [ESC] para cancelar',
    point_added = 'Punto añadido (#%s)',
    point_removed = 'Último punto eliminado',
    draw_min_points = 'Debes añadir al menos 3 puntos para un polígono.',
    draw_cancelled = 'Dibujo de zona cancelado.',
    draw_success = 'Polígono dibujado correctamente con %s puntos.',
    
    -- Notificaciones de logs del servidor
    log_created = '[os_safezone] El administrador %s creó la zona "%s" (ID: %s)',
    log_updated = '[os_safezone] El administrador %s actualizó la zona "%s" (ID: %s)',
    log_deleted = '[os_safezone] El administrador %s eliminó la zona "%s" (ID: %s)',
    log_toggled = '[os_safezone] El administrador %s cambió el estado de la zona "%s" (ID: %s) a %s',
}

Locales['en'] = {
    -- Zone Alerts
    entered_ic = 'You entered a safe zone (IC). Maintain environment roleplay.',
    entered_ooc = 'You entered a safe zone (OOC). Combat roleplay is disabled.',
    entered_mixed = 'You entered a mixed safe zone.',
    entered_custom = 'You entered a custom rules safe zone.',
    exited = 'You left the safe zone.',
    
    -- Restriction Messages
    action_blocked = 'This action is blocked inside this zone.',
    weapon_blocked = 'You cannot draw weapons in this zone.',
    melee_blocked = 'Melee combat is disabled in this zone.',
    driveby_blocked = 'Drive-by shooting is disabled in this zone.',
    speed_limited = 'Speed limited to %s km/h in this zone.',
    theft_blocked = 'Vehicle theft is blocked here.',
    inventory_blocked = 'You cannot open your inventory in this zone.',
    command_blocked = 'Command %s is blocked in this zone.',
    
    -- Administrative Menu
    admin_title = 'Safe Zone Administration',
    manage_zones = 'Manage Existing Zones',
    create_zone = 'Create New Zone',
    zone_list = 'Zone List',
    zone_details = 'Zone Details: %s',
    zone_name = 'Zone Name',
    zone_type = 'Zone Type',
    rp_type = 'Roleplay Type (IC/OOC/MIXED/CUSTOM)',
    rules_setup = 'Configure Rules',
    visual_setup = 'Configure Visuals',
    permissions_setup = 'Configure Permissions/Exceptions',
    save = 'Save Zone',
    delete = 'Delete Zone',
    confirm_delete = 'Are you sure you want to delete this zone?',
    teleport = 'Teleport to zone',
    toggle_enabled = 'Toggle Active / Inactive',
    duplicate = 'Duplicate Zone',
    
    -- Drawing tool (Points Creator)
    draw_instructions = 'Press [E] to add point | [G] to delete last | [ENTER] to confirm | [ESC] to cancel',
    point_added = 'Point added (#%s)',
    point_removed = 'Last point removed',
    draw_min_points = 'You must add at least 3 points for a polygon.',
    draw_cancelled = 'Zone drawing cancelled.',
    draw_success = 'Polygon successfully drawn with %s points.',
    
    -- Server Logs
    log_created = '[os_safezone] Admin %s created zone "%s" (ID: %s)',
    log_updated = '[os_safezone] Admin %s updated zone "%s" (ID: %s)',
    log_deleted = '[os_safezone] Admin %s deleted zone "%s" (ID: %s)',
    log_toggled = '[os_safezone] Admin %s toggled zone "%s" (ID: %s) state to %s',
}

-- Función global para obtener strings localizados
function _L(key, ...)
    local lang = Config.Locale or 'es'
    local dict = Locales[lang] or Locales['es']
    local str = dict[key] or key
    if ... then
        return str:format(...)
    end
    return str
end
