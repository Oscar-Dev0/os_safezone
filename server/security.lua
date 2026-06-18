SafeZoneSecurity = {}
local requests = {}

function SafeZoneSecurity.IsAdmin(source, bucket)
    if source == 0 then return true end
    local now = GetGameTimer()
    local key = ('%s:%s'):format(source, bucket or 'default')
    local cooldown = tonumber(Config.AdminRateLimitMs) or 750
    if requests[key] and now - requests[key] < cooldown then
        Bridge.Notify(source, 'Espera un momento antes de repetir esta acción.', 'error')
        return false
    end
    requests[key] = now

    if Permissions.IsAdmin(source) then return true end
    SafeZoneLogger.Write(source, 'ACCESO DENEGADO', 'Intentó ejecutar una acción administrativa.')
    return false
end

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    for key in pairs(requests) do
        if key:sub(1, #prefix) == prefix then requests[key] = nil end
    end
end)
