Permissions = {}

-- Comprueba si el jugador tiene permisos de administrador generales
function Permissions.IsAdmin(source)
    return Bridge.IsAdmin(source)
end

-- Comprueba si un jugador tiene una excepción (bypass) configurada en una zona segura específica.
-- Esto permite que ciertos trabajos (ej. policía), grados o identificadores ignoren las restricciones.
function Permissions.PlayerHasException(source, zoneData)
    if not zoneData or not zoneData.permissions then 
        return false 
    end
    
    local bypass = zoneData.permissions.bypass
    if not bypass then 
        return false 
    end
    
    -- 1. Validar por identificador de jugador
    local identifier = Bridge.GetIdentifier(source)
    if identifier and bypass.identifiers and bypass.identifiers[identifier] then
        return true
    end
    
    -- 2. Validar por trabajo y grado
    local playerJob = Bridge.GetJob(source)
    if playerJob and playerJob.name and bypass.jobs and bypass.jobs[playerJob.name] then
        local requiredGrade = bypass.jobs[playerJob.name]
        
        -- Si es un booleano (true), cualquier rango de ese trabajo está exceptuado
        if type(requiredGrade) == "boolean" and requiredGrade then
            return true
        -- Si es un número, se requiere un grado igual o superior
        elseif type(requiredGrade) == "number" and playerJob.grade >= requiredGrade then
            return true
        end
    end
    
    return false
end

-- Exportación para que otros scripts comprueben excepciones
exports("PlayerHasException", function(source, zoneId)
    local zone = SafeZoneCache and SafeZoneCache[zoneId]
    if not zone then return false end
    return Permissions.PlayerHasException(source, zone)
end)
