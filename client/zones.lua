ActiveZones = {}
InsideZones = {}
ClientCreatedZones = {}
ClientBlips = {}
ClientRadiusBlips = {}
UseOxLib = false

-- Comprobar disponibilidad de ox_lib para el manejo de zonas
CreateThread(function()
    if GetResourceState('ox_lib') == 'started' then
        UseOxLib = true
        Utils.LogInfo("Utilizando ox_lib zones para detección espacial.")
    else
        Utils.LogInfo("ox_lib no disponible. Cargando fallback de detección espacial optimizado.")
    end
end)

-- ==========================================
-- AYUDANTE DIBUJADO DE POLÍGONOS (ADMINISTRADOR)
-- ==========================================
local isDrawing = false
local drawingPoints = {}

function StartDrawingPoly(callback)
    if isDrawing then return end
    isDrawing = true
    drawingPoints = {}
    
    CreateThread(function()
        while isDrawing do
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            -- Dibujar instrucciones en pantalla
            SetTextComponentFormat("STRING")
            AddTextComponentString(_L("draw_instructions"))
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
            
            -- Dibujar marcadores en los puntos actuales
            for i, pt in ipairs(drawingPoints) do
                DrawMarker(28, pt.x, pt.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, 40, 180, 90, 200, false, false, 2, false, nil, nil, false)
                
                -- Conectar puntos con líneas
                if i < #drawingPoints then
                    local nextPt = drawingPoints[i + 1]
                    DrawLine(pt.x, pt.y, coords.z, nextPt.x, nextPt.y, coords.z, 40, 180, 90, 255)
                else
                    -- Línea de previsualización al jugador
                    DrawLine(pt.x, pt.y, coords.z, coords.x, coords.y, coords.z, 231, 194, 81, 150)
                end
            end
            
            -- Tecla E: Añadir punto
            if IsControlJustPressed(0, 38) then
                table.insert(drawingPoints, vector2(coords.x, coords.y))
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                Bridge.Notify(_L("point_added", #drawingPoints), "info")
                
            -- Tecla G: Borrar último punto
            elseif IsControlJustPressed(0, 47) then
                if #drawingPoints > 0 then
                    table.remove(drawingPoints)
                    PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                    Bridge.Notify(_L("point_removed"), "info")
                end
                
            -- Tecla ENTER: Confirmar
            elseif IsControlJustPressed(0, 201) then
                if #drawingPoints >= 3 then
                    isDrawing = false
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                    callback(drawingPoints)
                else
                    Bridge.Notify(_L("draw_min_points"), "error")
                end
                
            -- Tecla ESC / Backspace: Cancelar
            elseif IsControlJustPressed(0, 177) then
                isDrawing = false
                PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                Bridge.Notify(_L("draw_cancelled"), "error")
                callback(nil)
            end
        end
    end)
end

-- ==========================================
-- CREACIÓN Y GESTIÓN DE VISUALES (BLIPS Y MARKERS)
-- ==========================================

local function RemoveZoneVisuals(id)
    if ClientBlips[id] then
        RemoveBlip(ClientBlips[id])
        ClientBlips[id] = nil
    end
    if ClientRadiusBlips[id] then
        RemoveBlip(ClientRadiusBlips[id])
        ClientRadiusBlips[id] = nil
    end
end

local function CreateZoneVisuals(id, data)
    RemoveZoneVisuals(id)
    if not data.enabled then return end
    
    local visual = data.visual or Constants.DefaultZoneVisual
    local color = visual.color or Constants.DefaultZoneVisual.color
    local coords = data.coords
    
    -- 1. Blip principal
    if visual.blip then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, visual.sprite or 389)
        SetBlipScale(blip, visual.scale or 0.8)
        
        -- Si hay índice de color, usarlo; de lo contrario mapear verde por defecto
        SetBlipColour(blip, visual.colorIndex or 2) 
        SetBlipAsShortRange(blip, true)
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name)
        EndTextCommandSetBlipName(blip)
        ClientBlips[id] = blip
    end
    
    -- 2. Blip de radio (solo para círculos o boxes)
    if visual.radiusBlip then
        local radius = 0.0
        if data.zoneType == 'circle' and data.dimensions then
            radius = tonumber(data.dimensions.radius) or 0.0
        elseif data.zoneType == 'box' and data.dimensions then
            -- Usar el promedio de largo y ancho para el radio
            radius = ((tonumber(data.dimensions.x) or 0.0) + (tonumber(data.dimensions.y) or 0.0)) / 2
        end
        
        if radius > 0.0 then
            local rBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
            SetBlipColour(rBlip, visual.colorIndex or 2)
            SetBlipAlpha(rBlip, color.a or 80)
            ClientRadiusBlips[id] = rBlip
        end
    end
end

-- Thread para renderizar markers en 3D
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        for id, zone in pairs(ActiveZones) do
            if zone.enabled and zone.visual and zone.visual.marker then
                local dist = #(playerCoords - zone.coords)
                local maxDrawDist = 150.0
                
                if zone.zoneType == 'circle' and zone.dimensions then
                    maxDrawDist = (zone.dimensions.radius or 50.0) + 50.0
                elseif zone.zoneType == 'box' and zone.dimensions then
                    maxDrawDist = math.max(zone.dimensions.x or 50.0, zone.dimensions.y or 50.0) + 50.0
                end
                
                if dist < maxDrawDist then
                    sleep = 0
                    local color = zone.visual.color or Constants.DefaultZoneVisual.color
                    
                    if zone.zoneType == 'circle' and zone.dimensions then
                        local r = zone.dimensions.radius or 5.0
                        DrawMarker(1, zone.coords.x, zone.coords.y, zone.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, 6.0, color.r, color.g, color.b, color.a, false, false, 2, false, nil, nil, false)
                    elseif zone.zoneType == 'box' and zone.dimensions then
                        local size = zone.dimensions
                        DrawMarker(43, zone.coords.x, zone.coords.y, zone.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, (zone.dimensions and zone.dimensions.heading) or zone.rotation or 0.0, size.x or 1.0, size.y or 1.0, size.z or 1.0, color.r, color.g, color.b, color.a, false, false, 2, false, nil, nil, false)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ==========================================
-- REGISTRO DE ZONAS (OX_LIB O FALLBACK)
-- ==========================================

function RegisterWorldZone(id, zoneData)
    -- Remover zona existente si ya estaba registrada
    UnregisterWorldZone(id)
    
    if not zoneData.enabled then return end
    
    CreateZoneVisuals(id, zoneData)
    
    if UseOxLib then
        local zoneObj
        
        -- Configurar callbacks
        local onEnter = function() OnPlayerEnterZone(id, zoneData) end
        local onExit = function() OnPlayerExitZone(id, zoneData) end
        
        if zoneData.zoneType == 'circle' and zoneData.dimensions then
            zoneObj = lib.zones.sphere({
                coords = zoneData.coords,
                radius = zoneData.dimensions.radius,
                onEnter = onEnter,
                onExit = onExit
            })
        elseif zoneData.zoneType == 'box' and zoneData.dimensions then
            zoneObj = lib.zones.box({
                coords = zoneData.coords,
                size = zoneData.dimensions,
                rotation = zoneData.dimensions.heading or zoneData.rotation or 0.0,
                onEnter = onEnter,
                onExit = onExit
            })
        elseif zoneData.zoneType == 'poly' and zoneData.points and zoneData.dimensions then
            local pPoints = {}
            for _, pt in ipairs(zoneData.points) do
                table.insert(pPoints, vector3(pt.x, pt.y, ((zoneData.dimensions.minZ + zoneData.dimensions.maxZ) / 2.0)))
            end
            
            zoneObj = lib.zones.poly({
                points = pPoints,
                thickness = zoneData.dimensions.maxZ - zoneData.dimensions.minZ,
                onEnter = onEnter,
                onExit = onExit
            })
        end
        
        if zoneObj then
            ClientCreatedZones[id] = zoneObj
        end
    end
end

function UnregisterWorldZone(id)
    RemoveZoneVisuals(id)
    
    if UseOxLib then
        if ClientCreatedZones[id] then
            ClientCreatedZones[id]:remove()
            ClientCreatedZones[id] = nil
        end
    end
end

-- ==========================================
-- MOTOR FALLBACK DE DETECCION ESPACIAL
-- ==========================================

-- Comprueba si un punto 3D está dentro de una caja con rotación
local function IsPointInBox(point, center, size, heading)
    local rad = math.rad(-heading)
    local cosRad = math.cos(rad)
    local sinRad = math.sin(rad)
    
    local dx = point.x - center.x
    local dy = point.y - center.y
    local dz = point.z - center.z
    
    local rx = dx * cosRad - dy * sinRad
    local ry = dx * sinRad + dy * cosRad
    
    return math.abs(rx) <= (size.x / 2) and
           math.abs(ry) <= (size.y / 2) and
           math.abs(dz) <= (size.z / 2)
end

-- Comprueba si un punto 2D está dentro de un polígono (Ray-Casting Algorithm)
local function IsPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

-- Thread optimizado de cálculo espacial para standalone/sin ox_lib
local InsideFallbackZones = {}
CreateThread(function()
    while true do
        -- Esperar a que se determine si usamos ox_lib o no
        Wait(500)
        
        while not UseOxLib do
            local sleep = 1000
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearAny = false
            
            for id, zone in pairs(ActiveZones) do
                if zone.enabled then
                    local isInside = false
                    local dist = #(playerCoords - zone.coords)
                    
                    local checkDist = 150.0
                    if zone.zoneType == 'circle' and zone.dimensions then
                        checkDist = (zone.dimensions.radius or 50.0) + 50.0
                    elseif zone.zoneType == 'box' and zone.dimensions then
                        checkDist = math.max(zone.dimensions.x or 50.0, zone.dimensions.y or 50.0) + 50.0
                    end
                    
                    if dist < checkDist then
                        nearAny = true
                        
                        if zone.zoneType == 'circle' and zone.dimensions then
                            isInside = dist <= zone.dimensions.radius
                        elseif zone.zoneType == 'box' and zone.dimensions then
                            isInside = IsPointInBox(playerCoords, zone.coords, zone.dimensions, (zone.dimensions and zone.dimensions.heading) or zone.rotation or 0.0)
                        elseif zone.zoneType == 'poly' and zone.points and zone.dimensions then
                            local minZ = zone.dimensions.minZ or (zone.coords.z - 10.0)
                            local maxZ = zone.dimensions.maxZ or (zone.coords.z + 10.0)
                            
                            if playerCoords.z >= minZ and playerCoords.z <= maxZ then
                                isInside = IsPointInPolygon(vector2(playerCoords.x, playerCoords.y), zone.points)
                            end
                        end
                    end
                    
                    if isInside then
                        if not InsideFallbackZones[id] then
                            InsideFallbackZones[id] = true
                            OnPlayerEnterZone(id, zone)
                        end
                    else
                        if InsideFallbackZones[id] then
                            InsideFallbackZones[id] = nil
                            OnPlayerExitZone(id, zone)
                        end
                    end
                else
                    if InsideFallbackZones[id] then
                        InsideFallbackZones[id] = nil
                        OnPlayerExitZone(id, zone)
                    end
                end
            end
            
            if nearAny then
                sleep = 200
            end
            Wait(sleep)
        end
    end
end)

-- Limpieza al apagar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for id, _ in pairs(ActiveZones) do
        UnregisterWorldZone(id)
    end
    
    Utils.LogInfo("Visuales y zonas destruidas correctamente al detener el script.")
end)
