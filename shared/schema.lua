SafeZoneSchema = {}

local validZoneTypes = { circle = true, box = true, poly = true }
local validRoleplayTypes = { IC = true, OOC = true, MIXED = true, CUSTOM = true }

local function finiteNumber(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return value
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function SafeZoneSchema.DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[SafeZoneSchema.DeepCopy(key, seen)] = SafeZoneSchema.DeepCopy(item, seen)
    end
    return copy
end

function SafeZoneSchema.NormalizeRules(input, roleplayType)
    local profile = Config.Profiles[roleplayType] or Config.Profiles.IC or Constants.DefaultZoneRules
    local rules = SafeZoneSchema.DeepCopy(profile)
    input = type(input) == 'table' and input or {}

    for key, default in pairs(Constants.DefaultZoneRules) do
        local value = input[key]
        if type(default) == 'boolean' then
            if type(value) == 'boolean' then rules[key] = value end
        elseif type(default) == 'number' then
            rules[key] = finiteNumber(value, rules[key] or default)
        end
    end

    rules.maxVehicleSpeed = clamp(rules.maxVehicleSpeed or -1.0, -1.0, 500.0)
    rules.passiveAlpha = math.floor(clamp(rules.passiveAlpha or 255, 0, 255))
    return rules
end

function SafeZoneSchema.NormalizeVisual(input)
    local visual = SafeZoneSchema.DeepCopy(Constants.DefaultZoneVisual)
    input = type(input) == 'table' and input or {}

    for _, key in ipairs({ 'blip', 'radiusBlip', 'marker' }) do
        if type(input[key]) == 'boolean' then visual[key] = input[key] end
    end
    visual.sprite = math.floor(clamp(finiteNumber(input.sprite, visual.sprite), 0, 1000))
    visual.scale = clamp(finiteNumber(input.scale, visual.scale), 0.1, 10.0)

    local color = type(input.color) == 'table' and input.color or {}
    visual.color = {
        r = math.floor(clamp(finiteNumber(color.r, visual.color.r), 0, 255)),
        g = math.floor(clamp(finiteNumber(color.g, visual.color.g), 0, 255)),
        b = math.floor(clamp(finiteNumber(color.b, visual.color.b), 0, 255)),
        a = math.floor(clamp(finiteNumber(color.a, visual.color.a), 0, 255))
    }
    return visual
end

function SafeZoneSchema.NormalizePermissions(input)
    input = type(input) == 'table' and input or {}
    local bypass = type(input.bypass) == 'table' and input.bypass or {}
    return {
        bypass = {
            jobs = type(bypass.jobs) == 'table' and bypass.jobs or {},
            identifiers = type(bypass.identifiers) == 'table' and bypass.identifiers or {}
        }
    }
end

function SafeZoneSchema.Normalize(raw, existingId)
    raw = type(raw) == 'table' and raw or {}
    local roleplayType = validRoleplayTypes[tostring(raw.roleplayType or ''):upper()] and tostring(raw.roleplayType):upper() or 'IC'
    local zoneType = validZoneTypes[tostring(raw.zoneType or ''):lower()] and tostring(raw.zoneType):lower() or 'circle'
    local coords = raw.coords or {}

    local zone = {
        id = existingId and tonumber(existingId) or tonumber(raw.id),
        name = tostring(raw.name or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, (Config.ZoneLimits and Config.ZoneLimits.MaxNameLength) or 100),
        zoneType = zoneType,
        roleplayType = roleplayType,
        coords = {
            x = finiteNumber(coords.x or coords[1], 0.0),
            y = finiteNumber(coords.y or coords[2], 0.0),
            z = finiteNumber(coords.z or coords[3], 0.0)
        },
        dimensions = type(raw.dimensions) == 'table' and SafeZoneSchema.DeepCopy(raw.dimensions) or {},
        points = {},
        rules = SafeZoneSchema.NormalizeRules(raw.rules, roleplayType),
        visual = SafeZoneSchema.NormalizeVisual(raw.visual),
        permissions = SafeZoneSchema.NormalizePermissions(raw.permissions),
        schedule = type(raw.schedule) == 'table' and SafeZoneSchema.DeepCopy(raw.schedule) or {},
        priority = math.floor(clamp(finiteNumber(raw.priority, 0), -1000, 1000)),
        enabled = raw.enabled ~= false,
        createdBy = raw.createdBy and tostring(raw.createdBy):sub(1, 100) or nil
    }

    if zoneType == 'circle' then
        zone.dimensions.radius = clamp(finiteNumber(zone.dimensions.radius, 25.0), 0.5, (Config.ZoneLimits and Config.ZoneLimits.MaxRadius) or 2500.0)
    elseif zoneType == 'box' then
        local maxSize = (Config.ZoneLimits and Config.ZoneLimits.MaxBoxSize) or 2500.0
        local length = finiteNumber(zone.dimensions.length or zone.dimensions.x, 20.0)
        local width = finiteNumber(zone.dimensions.width or zone.dimensions.y, 20.0)
        local height = finiteNumber(zone.dimensions.height or zone.dimensions.z, 15.0)
        local heading = finiteNumber(zone.dimensions.heading or raw.rotation, 0.0) % 360.0
        zone.dimensions.length = clamp(length, 0.5, maxSize)
        zone.dimensions.width = clamp(width, 0.5, maxSize)
        zone.dimensions.height = clamp(height, 0.5, maxSize)
        -- Alias canónicos para ox_lib y el detector fallback.
        zone.dimensions.x = zone.dimensions.length
        zone.dimensions.y = zone.dimensions.width
        zone.dimensions.z = zone.dimensions.height
        zone.dimensions.heading = heading
        zone.dimensions.minZ = finiteNumber(zone.dimensions.minZ, zone.coords.z - (zone.dimensions.height / 2.0))
        zone.dimensions.maxZ = finiteNumber(zone.dimensions.maxZ, zone.coords.z + (zone.dimensions.height / 2.0))
    else
        zone.dimensions.minZ = finiteNumber(zone.dimensions.minZ, zone.coords.z - 5.0)
        zone.dimensions.maxZ = finiteNumber(zone.dimensions.maxZ, zone.coords.z + 10.0)
        for index, point in ipairs(type(raw.points) == 'table' and raw.points or {}) do
            if index > ((Config.ZoneLimits and Config.ZoneLimits.MaxPolygonPoints) or 64) then break end
            if type(point) == 'table' then
                zone.points[#zone.points + 1] = {
                    x = finiteNumber(point.x or point[1], 0.0),
                    y = finiteNumber(point.y or point[2], 0.0)
                }
            end
        end
    end

    return zone
end

function SafeZoneSchema.Validate(zone)
    if type(zone.name) ~= 'string' or #zone.name < 3 then
        return false, 'El nombre debe tener entre 3 y 100 caracteres.'
    end
    if not validZoneTypes[zone.zoneType] then return false, 'Tipo de zona inválido.' end
    if not validRoleplayTypes[zone.roleplayType] then return false, 'Tipo de rol inválido.' end
    if zone.zoneType == 'poly' and #zone.points < 3 then
        return false, 'Un polígono necesita al menos 3 puntos.'
    end
    if (zone.zoneType == 'poly' or zone.zoneType == 'box') and zone.dimensions.minZ >= zone.dimensions.maxZ then
        return false, 'minZ debe ser menor que maxZ.'
    end
    if math.abs(zone.coords.x) > 10000.0 or math.abs(zone.coords.y) > 10000.0 or math.abs(zone.coords.z) > 5000.0 then
        return false, 'Las coordenadas están fuera de los límites válidos del mapa.'
    end
    return true
end
