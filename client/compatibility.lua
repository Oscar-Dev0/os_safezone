-- =================================================================
-- COMPATIBILIDAD CON RECURSOS ANTERIORES (pd-safe, Breezy_Safezones, wasd-safezone)
-- =================================================================

-- 1. Compatibilidad con pd-safe (Minijuego de Safe Cracking)
local isMinigame = false
local _onSpot = false
local _SafeCrackingStates = "Setup"
local SafeDialRotation = 0.0
local _safeLockStatus = {}
local _currentLockNum = 1
local _requiredDialRotationDirection = "Clockwise"
local _safeCombination = {}
local _initDialRotationDirection = "Clockwise"
local _currentDialRotationDirection = "Idle"
local _lastDialRotationDirection = "Idle"

local function playFx(dict, anim)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 3.0, 3.0, -1, 1, 0, 0, 0, 0)
end

local function GetCurrentSafeDialNumber(currentDialAngle)
    local number = math.floor(100 * (currentDialAngle / 360))
    if number > 0 then
        number = 100 - number
    end
    return math.abs(number)
end

local function IsSafeUnlocked()
    return _safeLockStatus[_currentLockNum] == nil
end

local function InitSafeLocks()
    if not _safeCombination then return {} end
    local locks = {}
    for i = 1, #_safeCombination do
        table.insert(locks, true)
    end
    return locks
end

local function RelockSafe()
    if not _safeCombination then return end
    _safeLockStatus = InitSafeLocks()
    _currentLockNum = 1
    _requiredDialRotationDirection = _initDialRotationDirection
    _onSpot = false
    for i = 1, #_safeCombination do
        _safeLockStatus[i] = true
    end
end

local function SetSafeDialStartNumber()
    local dialStartNumber = math.random(0, 100)
    SafeDialRotation = 3.6 * dialStartNumber
end

local function InitializeSafe(safeCombination)
    _initDialRotationDirection = "Clockwise"
    _safeCombination = safeCombination
    RelockSafe()
    SetSafeDialStartNumber()
end

local function DrawSprites(drawLocks)
    local textureDict = "MPSafeCracking"
    local _aspectRatio = GetAspectRatio(true)
    
    DrawSprite(textureDict, "Dial_BG", 0.48, 0.3, 0.3, _aspectRatio * 0.3, 0, 255, 255, 255, 255)
    DrawSprite(textureDict, "Dial", 0.48, 0.3, 0.3 * 0.5, _aspectRatio * 0.3 * 0.5, SafeDialRotation, 255, 255, 255, 255)

    if not drawLocks then return end

    local xPos = 0.6
    local yPos = (0.3 * 0.5) + 0.035
    for _, lockActive in pairs(_safeLockStatus) do
        local lockString = lockActive and "lock_closed" or "lock_open"
        DrawSprite(textureDict, lockString, xPos, yPos, 0.025, _aspectRatio * 0.015, 0, 231, 194, 81, 255)
        yPos = yPos + 0.05
    end
end

local function RotateSafeDial(rotationDirection)
    if rotationDirection == "Anticlockwise" or rotationDirection == "Clockwise" then
        local multiplier = rotationDirection == "Anticlockwise" and 1 or -1
        local rotationPerNumber = 3.6
        local rotationChange = multiplier * rotationPerNumber
        SafeDialRotation = SafeDialRotation + rotationChange
        PlaySoundFrontend(0, "TUMBLER_TURN", "SAFE_CRACK_SOUNDSET", true)
    end

    _currentDialRotationDirection = rotationDirection
    _lastDialRotationDirection = rotationDirection
end

local function HandleSafeDialMovement()
    if IsControlJustPressed(0, 34) then
        RotateSafeDial("Anticlockwise")
    elseif IsControlJustPressed(0, 35) then
        RotateSafeDial("Clockwise")
    else
        RotateSafeDial("Idle")
    end
end

local function ReleaseCurrentPin()
    _safeLockStatus[_currentLockNum] = false
    _currentLockNum = _currentLockNum + 1

    if _requiredDialRotationDirection == "Anticlockwise" then
        _requiredDialRotationDirection = "Clockwise"
    else
        _requiredDialRotationDirection = "Anticlockwise"
    end

    PlaySoundFrontend(0, "TUMBLER_PIN_FALL_FINAL", "SAFE_CRACK_SOUNDSET", true)
end

local function EndMiniGame(safeUnlocked)
    if safeUnlocked then
        PlaySoundFrontend(0, "SAFE_DOOR_OPEN", "SAFE_CRACK_SOUNDSET", true)
    else
        PlaySoundFrontend(0, "SAFE_DOOR_CLOSE", "SAFE_CRACK_SOUNDSET", true)
    end
    isMinigame = false
    _SafeCrackingStates = "Setup"
    ClearPedTasksImmediately(PlayerPedId())
end

local function RunMiniGame()
    if _SafeCrackingStates == "Setup" then
        _SafeCrackingStates = "Cracking"
    elseif _SafeCrackingStates == "Cracking" then
        local isDead = GetEntityHealth(PlayerPedId()) <= 101
        if isDead then
            EndMiniGame(false)
            return false
        end

        if IsControlJustPressed(0, 33) then
            EndMiniGame(false)
            return false
        end

        if IsControlJustPressed(0, 32) then
            if _onSpot then
                ReleaseCurrentPin()
                _onSpot = false
                if IsSafeUnlocked() then
                    EndMiniGame(true)
                    return true
                end
            else
                EndMiniGame(false)
                return false
            end
        end

        HandleSafeDialMovement()

        local incorrectMovement = _currentLockNum ~= 0 and _requiredDialRotationDirection ~= "Idle" and _currentDialRotationDirection ~= "Idle" and _currentDialRotationDirection ~= _requiredDialRotationDirection

        if not incorrectMovement then
            local currentDialNumber = GetCurrentSafeDialNumber(SafeDialRotation)
            local correctMovement = _requiredDialRotationDirection ~= "Idle" and (_currentDialRotationDirection == _requiredDialRotationDirection or _lastDialRotationDirection == _requiredDialRotationDirection)  
            if correctMovement then
                local pinUnlocked = _safeLockStatus[_currentLockNum] and currentDialNumber == _safeCombination[_currentLockNum]
                if pinUnlocked then
                    PlaySoundFrontend(0, "TUMBLER_PIN_FALL", "SAFE_CRACK_SOUNDSET", true)
                    _onSpot = true
                end
            end
        elseif incorrectMovement then
            _onSpot = false
        end
    end
end

local function createSafe(combination)
    local res
    isMinigame = not isMinigame
    RequestStreamedTextureDict("MPSafeCracking", false)
    RequestAmbientAudioBank("SAFE_CRACK", false)

    if isMinigame then
        InitializeSafe(combination)
        while isMinigame do
            playFx("mini@safe_cracking", "idle_base")
            DrawSprites(true)
            res = RunMiniGame()

            if res == true then
                return res
            elseif res == false then
                return res
            end

            Citizen.Wait(0)
        end
    end
end

-- Exportar nativo del recurso
exports("createSafe", createSafe)

-- =================================================================
-- INTERCEPCIÓN DINÁMICA DE EXPORTS CFX (BACKWARD COMPATIBILITY)
-- =================================================================

-- Intercepta llamadas de: exports['pd-safe']:createSafe(...)
AddEventHandler('__cfx_export_pd-safe_createSafe', function(setCB)
    setCB(createSafe)
end)

-- Intercepta llamadas de: exports['wasd-safezone']:IsPlayerInSafeZone()
AddEventHandler('__cfx_export_wasd-safezone_IsPlayerInSafeZone', function(setCB)
    setCB(function()
        return isInsideSafeZone
    end)
end)

-- Intercepta llamadas de: exports['Breezy_Safezones']:IsPlayerInSafeZone()
AddEventHandler('__cfx_export_Breezy_Safezones_IsPlayerInSafeZone', function(setCB)
    setCB(function()
        return isInsideSafeZone
    end)
end)
