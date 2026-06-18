Database = {}

-- Inicialización y creación de tabla si no existe
function Database.Initialize(callback)
    local sql = [[
        CREATE TABLE IF NOT EXISTS `os_safezones` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NOT NULL,
            `zone_type` VARCHAR(20) NOT NULL,
            `roleplay_type` VARCHAR(20) NOT NULL DEFAULT 'IC',
            `coords` LONGTEXT NOT NULL,
            `dimensions` LONGTEXT NULL,
            `points` LONGTEXT NULL,
            `rules` LONGTEXT NOT NULL,
            `visual` LONGTEXT NULL,
            `permissions` LONGTEXT NULL,
            `schedule` LONGTEXT NULL,
            `priority` INT NOT NULL DEFAULT 0,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `created_by` VARCHAR(100) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
    
    MySQL.ready(function()
        MySQL.query(sql, {}, function(result)
            Utils.LogInfo("Base de datos inicializada y lista.")
            MySQL.query("ALTER TABLE `os_safezones` ADD COLUMN IF NOT EXISTS `priority` INT NOT NULL DEFAULT 0", {}, function()
                if callback then callback(true) end
            end)
        end)
    end)
end

-- Cargar todas las zonas desde la base de datos
function Database.GetAllZones(callback)
    MySQL.query("SELECT * FROM os_safezones", {}, function(results)
        -- Si no hay resultados o la tabla está vacía, ejecutar auto-inyección de configuraciones previas
        if not results or #results == 0 then
            Database.AutoInjectDefaultZones(function()
                Database.GetAllZones(callback)
            end)
            return
        end
        
        local loadedZones = {}
        for _, row in ipairs(results) do
            local zone = {
                id = tonumber(row.id),
                name = row.name,
                zoneType = row.zone_type,
                roleplayType = row.roleplay_type,
                coords = Utils.SafeDecode(row.coords),
                dimensions = Utils.SafeDecode(row.dimensions),
                points = Utils.SafeDecode(row.points),
                rules = Utils.SafeDecode(row.rules),
                visual = Utils.SafeDecode(row.visual),
                permissions = Utils.SafeDecode(row.permissions),
                schedule = Utils.SafeDecode(row.schedule),
                priority = tonumber(row.priority) or 0,
                enabled = row.enabled == 1 or row.enabled == true,
                createdBy = row.created_by
            }
            
            -- Asegurar que las coordenadas y puntos sean del tipo vector de GTA si es necesario
            zone.coords = Utils.ToVector3(zone.coords)
            if zone.points and type(zone.points) == 'table' then
                for i, pt in ipairs(zone.points) do
                    -- Si es un polígono, los puntos son vector2 (x, y)
                    zone.points[i] = vector2(tonumber(pt.x or pt[1]) or 0.0, tonumber(pt.y or pt[2]) or 0.0)
                end
            end
            
            loadedZones[zone.id] = zone
        end
        callback(loadedZones)
    end)
end

-- Inyección automática de zonas desde las bases previas si la base de datos está vacía
function Database.AutoInjectDefaultZones(callback)
    Utils.LogInfo("Base de datos de safezones vacía. Iniciando inyección automática de configuraciones Breezy y WASD...")
    
    local defaultZones = {
        -- Zonas de Breezy_Safezones (Círculos)
        {
            name = "Breezy Sandy PD",
            zoneType = "circle",
            roleplayType = "IC",
            coords = { x = -1113.36, y = -2091.06, z = 13.36 },
            dimensions = { radius = 50.0 },
            points = {},
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "Breezy Zona 2",
            zoneType = "circle",
            roleplayType = "IC",
            coords = { x = -202.59, y = -1322.84, z = 30.90 },
            dimensions = { radius = 50.0 },
            points = {},
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "Breezy Zona 3",
            zoneType = "circle",
            roleplayType = "IC",
            coords = { x = -1571.12, y = 215.74, z = 58.85 },
            dimensions = { radius = 50.0 },
            points = {},
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "Breezy Zona 4",
            zoneType = "circle",
            roleplayType = "IC",
            coords = { x = 76.6212, y = -1774.1268, z = 28.7199 },
            dimensions = { radius = 50.0 },
            points = {},
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "Breezy Zona 5",
            zoneType = "circle",
            roleplayType = "IC",
            coords = { x = -203.6701, y = -1170.9114, z = 23.7336 },
            dimensions = { radius = 50.0 },
            points = {},
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        -- Zonas de wasd-safezone (Polígonos)
        {
            name = "Legion Square - hospital",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = 262.585, y = -689.195, z = 35.0 },
            dimensions = { minZ = 10.0, maxZ = 60.0 },
            points = {
                { x = 245.50, y = -550.87 },
                { x = 371.75, y = -575.22 },
                { x = 273.71, y = -835.79 },
                { x = 159.39, y = -794.90 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "DiscotecaV2",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = 372.76, y = 280.75, z = 80.19 },
            dimensions = { minZ = 50.0, maxZ = 110.39 },
            points = {
                { x = 358.87, y = 304.23 },
                { x = 343.16, y = 270.01 },
                { x = 388.46, y = 257.58 },
                { x = 400.56, y = 291.18 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "barco",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = -1410.85, y = 6749.36, z = 15.69 },
            dimensions = { minZ = 1.0, maxZ = 30.39 },
            points = {
                { x = -1365.42, y = 6726.70 },
                { x = -1458.74, y = 6757.12 },
                { x = -1456.95, y = 6771.36 },
                { x = -1362.28, y = 6742.25 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "PaintballV7",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = -433.32, y = 1118.09, z = 322.5 },
            dimensions = { minZ = 310.0, maxZ = 335.0 },
            points = {
                { x = -380.25, y = 1165.78 },
                { x = -466.75, y = 1183.62 },
                { x = -486.01, y = 1075.69 },
                { x = -400.29, y = 1047.26 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "taller abuelo",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = 66.56, y = -1592.31, z = 35.0 },
            dimensions = { minZ = 10.0, maxZ = 60.0 },
            points = {
                { x = 145.52, y = -1596.01 },
                { x = 53.55, y = -1648.91 },
                { x = -0.47, y = -1602.40 },
                { x = 67.66, y = -1521.92 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "garage uni",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = -1330.57, y = 272.61, z = 65.0 },
            dimensions = { minZ = 40.0, maxZ = 90.0 },
            points = {
                { x = -1376.98, y = 222.37 },
                { x = -1414.56, y = 295.71 },
                { x = -1278.34, y = 328.48 },
                { x = -1252.39, y = 243.88 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "taller srt",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = -1129.99, y = -2067.99, z = 40.13 },
            dimensions = { minZ = 0.26, maxZ = 80.0 },
            points = {
                { x = -1145.24, y = -2079.61 },
                { x = -1138.46, y = -2073.78 },
                { x = -1131.03, y = -2068.46 },
                { x = -1125.59, y = -2060.76 },
                { x = -1118.00, y = -2054.84 },
                { x = -1111.65, y = -2070.50 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        },
        {
            name = "Hospital",
            zoneType = "poly",
            roleplayType = "IC",
            coords = { x = -2806.84, y = -59.18, z = 32.5 },
            dimensions = { minZ = 5.0, maxZ = 60.0 },
            points = {
                { x = -2702.3682, y = -66.5232 },
                { x = -2743.8655, y = -119.6870 },
                { x = -2834.9749, y = -138.6021 },
                { x = -2911.7410, y = -62.3335 },
                { x = -2843.4153, y = 13.9784 },
                { x = -2804.6797, y = 18.0802 }
            },
            rules = Constants.DefaultZoneRules,
            visual = Constants.DefaultZoneVisual,
            permissions = Constants.DefaultZonePermissions,
            schedule = {},
            enabled = true,
            createdBy = "Sistema (Auto-Inyección)"
        }
    }
    
    local query = [[
        INSERT INTO os_safezones 
        (name, zone_type, roleplay_type, coords, dimensions, points, rules, visual, permissions, schedule, priority, enabled, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local total = #defaultZones
    local completed = 0
    
    for _, z in ipairs(defaultZones) do
        local params = {
            z.name,
            z.zoneType,
            z.roleplayType,
            Utils.SafeEncode(z.coords),
            Utils.SafeEncode(z.dimensions),
            Utils.SafeEncode(z.points),
            Utils.SafeEncode(z.rules),
            Utils.SafeEncode(z.visual),
            Utils.SafeEncode(z.permissions),
            Utils.SafeEncode(z.schedule),
            tonumber(z.priority) or 0,
            z.enabled and 1 or 0,
            z.createdBy
        }
        MySQL.insert(query, params, function(insertId)
            completed = completed + 1
            if completed == total then
                Utils.LogInfo("Auto-inyección completada con éxito. Insertadas " .. total .. " zonas en la base de datos.")
                callback()
            end
        end)
    end
end

-- Insertar una nueva zona en la base de datos
function Database.InsertZone(zoneData, callback)
    local query = [[
        INSERT INTO os_safezones 
        (name, zone_type, roleplay_type, coords, dimensions, points, rules, visual, permissions, schedule, priority, enabled, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local params = {
        zoneData.name,
        zoneData.zoneType,
        zoneData.roleplayType,
        Utils.SafeEncode(zoneData.coords),
        Utils.SafeEncode(zoneData.dimensions),
        Utils.SafeEncode(zoneData.points),
        Utils.SafeEncode(zoneData.rules),
        Utils.SafeEncode(zoneData.visual),
        Utils.SafeEncode(zoneData.permissions),
        Utils.SafeEncode(zoneData.schedule),
        tonumber(zoneData.priority) or 0,
        zoneData.enabled and 1 or 0,
        zoneData.createdBy
    }
    
    MySQL.insert(query, params, function(insertId)
        if insertId then
            zoneData.id = insertId
            callback(true, zoneData)
        else
            callback(false, nil)
        end
    end)
end

-- Actualizar una zona existente
function Database.UpdateZone(zoneId, zoneData, callback)
    local query = [[
        UPDATE os_safezones SET 
        name = ?, zone_type = ?, roleplay_type = ?, coords = ?, dimensions = ?, 
        points = ?, rules = ?, visual = ?, permissions = ?, schedule = ?, priority = ?, enabled = ?
        WHERE id = ?
    ]]
    
    local params = {
        zoneData.name,
        zoneData.zoneType,
        zoneData.roleplayType,
        Utils.SafeEncode(zoneData.coords),
        Utils.SafeEncode(zoneData.dimensions),
        Utils.SafeEncode(zoneData.points),
        Utils.SafeEncode(zoneData.rules),
        Utils.SafeEncode(zoneData.visual),
        Utils.SafeEncode(zoneData.permissions),
        Utils.SafeEncode(zoneData.schedule),
        tonumber(zoneData.priority) or 0,
        zoneData.enabled and 1 or 0,
        zoneId
    }
    
    MySQL.update(query, params, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

-- Eliminar una zona
function Database.DeleteZone(zoneId, callback)
    MySQL.update("DELETE FROM os_safezones WHERE id = ?", { zoneId }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

-- Activar / Desactivar zona
function Database.ToggleZone(zoneId, enabled, callback)
    local state = enabled and 1 or 0
    MySQL.update("UPDATE os_safezones SET enabled = ? WHERE id = ?", { state, zoneId }, function(affectedRows)
        callback(affectedRows > 0)
    end)
end
