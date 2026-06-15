UI = {}
local isUIVisible = false

-- Mostrar u ocultar la UI premium de zona segura
function UI.ToggleSafeZoneUI(state, zoneData)
    if state == isUIVisible then
        -- Evitar recargar la UI innecesariamente si no hay cambios
        if not state then return end
    end
    
    isUIVisible = state
    
    if state and zoneData then
        -- Enviar mensaje NUI al frontend HTML
        SendNUIMessage({
            action = "showSafezone",
            state = true,
            zoneName = zoneData.name,
            roleplayType = zoneData.roleplayType,
            rules = zoneData.rules
        })
        
        -- Mostrar notificación al entrar según el tipo de zona
        local enterMsg = _L("entered_custom")
        if zoneData.roleplayType == 'IC' then
            enterMsg = _L("entered_ic")
        elseif zoneData.roleplayType == 'OOC' then
            enterMsg = _L("entered_ooc")
        elseif zoneData.roleplayType == 'MIXED' then
            enterMsg = _L("entered_mixed")
        end
        
        Bridge.Notify(enterMsg, "success")
        Utils.LogDebug(("UI de zona segura activada para: %s (%s)"):format(zoneData.name, zoneData.roleplayType))
    else
        SendNUIMessage({
            action = "showSafezone",
            state = false
        })
        
        Bridge.Notify(_L("exited"), "warning")
        Utils.LogDebug("UI de zona segura desactivada.")
    end
end

-- Muestra un mensaje flotante de error/advertencia de acción bloqueada
function UI.ShowActionBlockedMessage(message)
    Bridge.Notify(message or _L("action_blocked"), "error")
    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 1)
end
