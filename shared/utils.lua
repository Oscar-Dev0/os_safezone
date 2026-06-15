Utils = {}

-- Imprime un log informativo
function Utils.LogInfo(msg)
    print(("^4[os_safezone:INFO] %s^7"):format(msg))
end

-- Imprime un log de error
function Utils.LogError(msg)
    print(("^1[os_safezone:ERROR] %s^7"):format(msg))
end

-- Imprime un log de depuración (solo si Config.Debug está activo)
function Utils.LogDebug(msg)
    if Config.Debug then
        print(("^2[os_safezone:DEBUG] %s^7"):format(msg))
    end
end

-- Decodificación JSON segura con tolerancia a errores y fallback a tabla vacía
function Utils.SafeDecode(value)
    if not value or value == "" or value == "null" then
        return {}
    end
    
    local success, decoded = pcall(json.decode, value)
    if not success or type(decoded) ~= 'table' then
        Utils.LogError("Error al decodificar JSON: " .. tostring(value))
        return {}
    end
    
    return Utils.ReconstructVectors(decoded)
end

-- Codificación JSON segura
function Utils.SafeEncode(tbl)
    local success, encoded = pcall(json.encode, tbl)
    if not success then
        Utils.LogError("Error al codificar tabla a JSON")
        return "{}"
    end
    return encoded
end

-- Reconstruye recursivamente vectores nativos de FiveM (vector3, vector2) desde tablas JSON
function Utils.ReconstructVectors(tbl)
    if type(tbl) ~= 'table' then return tbl end
    
    -- Si la tabla tiene x, y, z y no tiene r (para evitar confundir con color)
    if tbl.x and tbl.y and tbl.z and not tbl.r then
        return vector3(tonumber(tbl.x) or 0.0, tonumber(tbl.y) or 0.0, tonumber(tbl.z) or 0.0)
    elseif tbl.x and tbl.y and not tbl.z then
        return vector2(tonumber(tbl.x) or 0.0, tonumber(tbl.y) or 0.0)
    end
    
    for k, v in pairs(tbl) do
        tbl[k] = Utils.ReconstructVectors(v)
    end
    
    return tbl
end

-- Convierte una tabla simple de coordenadas o un vector3 a un vector3 nativo
function Utils.ToVector3(data)
    if not data then return nil end
    if type(data) == 'vector3' then return data end
    if type(data) == 'table' then
        return vector3(
            tonumber(data.x or data[1]) or 0.0,
            tonumber(data.y or data[2]) or 0.0,
            tonumber(data.z or data[3]) or 0.0
        )
    end
    return nil
end

-- Fusiona de forma determinista dos tablas de reglas. 
-- Si hay un conflicto, la opción más restrictiva (true para deshabilitar o bloquear) prevalece.
function Utils.MergeRules(rulesA, rulesB)
    local merged = {}
    for k, v in pairs(Constants.DefaultZoneRules) do
        local valA = rulesA[k]
        local valB = rulesB[k]
        
        -- Si uno es nulo, toma el otro; si ambos son nulos, toma el default
        if valA == nil then valA = v end
        if valB == nil then valB = v end
        
        if type(v) == "boolean" then
            -- Para restricciones booleanas, si alguno es true (bloqueado/deshabilitado), queda bloqueado
            if k == "allowEmergencyWeapons" then
                -- Bypass es una ventaja: si una zona NO permite y otra SI, es más seguro no permitirlo (o viceversa)
                -- Tomamos la regla más restrictiva (false)
                merged[k] = valA and valB
            else
                merged[k] = valA or valB
            end
        elseif type(v) == "number" then
            -- Para velocidad máxima, tomamos la velocidad más baja configurada (más restrictiva) mayor a 0
            if valA > 0 and valB > 0 then
                merged[k] = math.min(valA, valB)
            elseif valA > 0 then
                merged[k] = valA
            else
                merged[k] = valB
            end
        else
            merged[k] = valA
        end
    end
    return merged
end
