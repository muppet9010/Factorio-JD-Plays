local BiterHuntGroup = {}
local GUIUtil = require("utility/gui-util")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local biterHuntGroupFrequencyRangeTicks = {
    20 * 60 * 60,
    45 * 60 * 60
}
local biterHuntGroupSize = 80
local biterHuntGroupEvolutionAddition = 0.1
local biterHuntGroupRadius = 100
local biterHuntGroupPreTunnelEffectTime = 10
local biterHuntGroupTunnelTime = 180
local incomingBitersWarningTime = 600
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement", preBitersActiveEffect = "preBitersActiveEffect", bitersActive = "bitersActive"}

local testing = false
if testing then
    biterHuntGroupFrequencyRangeTicks = {1200, 1200}
    biterHuntGroupSize = 2
    biterHuntGroupRadius = 5
end

BiterHuntGroup.ScheduleNextBiterHuntGroup = function()
    global.nextBiterHuntGroupTick = global.nextBiterHuntGroupTick + math.random(biterHuntGroupFrequencyRangeTicks[1], biterHuntGroupFrequencyRangeTicks[2])
    global.nextBiterHuntGroupTickWarning = global.nextBiterHuntGroupTick - incomingBitersWarningTime
end

BiterHuntGroup.ValidSurface = function(surface)
    if string.find(surface.name, "spaceship", 0, true) then
        return false
    end
    if string.find(surface.name, "Orbit", 0, true) then
        return false
    end
    return true
end

BiterHuntGroup.SelectTarget = function()
    local players = game.connected_players
    local validPlayers = {}
    for _, player in pairs(players) do
        if player.character and BiterHuntGroup.ValidSurface(player.surface) then
            table.insert(validPlayers, player)
        end
    end
    if #validPlayers >= 1 then
        local target = validPlayers[math.random(1, #validPlayers)]
        global.biterHuntGroupTargetPlayerID = target.index
        global.biterHuntGroupTargetEntity = target.character
        global.biterHuntGroupTargetName = target.name
        global.biterHuntGroupSurface = target.surface
    else
        global.biterHuntGroupTargetPlayerID = nil
        global.biterHuntGroupTargetEntity = nil
        global.biterHuntGroupTargetName = "at Spawn"
        global.biterHuntGroupSurface = game.surfaces[1]
    end
    BiterHuntGroup.GuiUpdateAll()
end

BiterHuntGroup.GuiCreate = function(player)
    GUIUtil.CreatePlayersElementReferenceStorage(player.index)
    BiterHuntGroup.GuiUpdateAll(player.index)
end

BiterHuntGroup.GuiDestroy = function(player)
    GUIUtil.DestroyElementInPlayersReferenceStorage(player.index, "biterhuntgroup", "frame")
    GUIUtil.RemovePlayersReferenceStorage(player.index)
end

BiterHuntGroup.GuiRecreate = function(player)
    BiterHuntGroup.GuiDestroy(player)
    BiterHuntGroup.GuiCreate(player)
end

BiterHuntGroup.GuiRecreateAll = function()
    for _, player in pairs(game.connected_players) do
        BiterHuntGroup.GuiRecreate(player)
    end
end

BiterHuntGroup.GuiUpdateAll = function(specificPlayerIndex)
    local warningLocalisedString
    if global.showIncomingBiterHuntGroupWarning ~= nil then
        warningLocalisedString = {"gui-caption.jd_plays-warning-label"}
    end
    local targetLocalisedString
    if global.biterHuntGroupTargetName ~= nil and global.biterHuntGroupSurface ~= nil then
        targetLocalisedString = {"gui-caption.jd_plays-target-label", global.biterHuntGroupTargetName, global.biterHuntGroupSurface.name}
    end
    for _, player in pairs(game.connected_players) do
        if specificPlayerIndex == nil or (specificPlayerIndex ~= nil and specificPlayerIndex == player.index) then
            BiterHuntGroup.GuiUpdatePlayerWithData(player, warningLocalisedString, targetLocalisedString)
        end
    end
end

BiterHuntGroup.GuiUpdatePlayerWithData = function(player, warningLocalisedString, targetLocalisedString)
    local playerIndex = player.index
    local frameElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "biterhuntgroup", "frame")
    local childElementPresent = false

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "warning", "label")
    if warningLocalisedString ~= nil then
        if frameElement == nil then
            frameElement = GUIUtil.AddElement({parent = player.gui.left, name = "biterhuntgroup", type = "frame", direction = "vertical"}, true)
        end
        GUIUtil.AddElement({parent = frameElement, name = "warning", type = "label", caption = warningLocalisedString, style = "jd_plays-biterwarning-text"}, true)
        childElementPresent = true
    end

    GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "target", "label")
    if targetLocalisedString ~= nil then
        if frameElement == nil then
            frameElement = GUIUtil.AddElement({parent = player.gui.left, name = "biterhuntgroup", type = "frame", direction = "vertical"}, true)
        end

        GUIUtil.AddElement({parent = frameElement, name = "target", type = "label", caption = targetLocalisedString, style = "muppet_bold_text"}, true)
        childElementPresent = true
    end

    if not childElementPresent then
        GUIUtil.DestroyElementInPlayersReferenceStorage(playerIndex, "biterhuntgroup", "frame")
    end
end

BiterHuntGroup.On10Ticks = function(tick)
    if tick >= global.nextBiterHuntGroupTickWarning and not global.showIncomingBiterHuntGroupWarning then
        global.showIncomingBiterHuntGroupWarning = true
        BiterHuntGroup.GuiUpdateAll()
    elseif tick >= global.nextBiterHuntGroupTick then
        global.showIncomingBiterHuntGroupWarning = nil
        if global.BiterHuntGroupResults[global.biterHuntGroupId] ~= nil and global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin == nil then
            game.print("[img=entity.medium-biter]      [img=entity.character]" .. global.biterHuntGroupTargetName .. " draw")
        end
        BiterHuntGroup.ClearGlobals()
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
        global.biterHuntGroupState = biterHuntGroupState.groundMovement
        global.biterHuntGroupStateChangeTick = tick + biterHuntGroupTunnelTime - biterHuntGroupPreTunnelEffectTime
        BiterHuntGroup.SelectTarget()
        game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter]" .. " hunting " .. global.biterHuntGroupTargetName)
        BiterHuntGroup.CreateGroundMovement()
    elseif global.biterHuntGroupState == biterHuntGroupState.groundMovement then
        if tick < (global.biterHuntGroupStateChangeTick) then
            BiterHuntGroup.EnsureValidateTarget()
        else
            global.biterHuntGroupState = biterHuntGroupState.preBitersActiveEffect
            global.biterHuntGroupStateChangeTick = tick + biterHuntGroupPreTunnelEffectTime
            BiterHuntGroup.EnsureValidateTarget()
            BiterHuntGroup.SpawnEnemyPreEffects()
        end
    elseif global.biterHuntGroupState == biterHuntGroupState.preBitersActiveEffect then
        if tick < (global.biterHuntGroupStateChangeTick) then
            BiterHuntGroup.EnsureValidateTarget()
        else
            global.biterHuntGroupState = biterHuntGroupState.bitersActive
            global.biterHuntGroupStateChangeTick = nil
            BiterHuntGroup.EnsureValidateTarget()
            global.biterHuntGroupId = global.biterHuntGroupId + 1
            global.BiterHuntGroupResults[global.biterHuntGroupId] = {playerWin = nil, targetName = global.biterHuntGroupTargetName}
            BiterHuntGroup.SpawnEnemies()
        end
    elseif global.biterHuntGroupState == biterHuntGroupState.bitersActive then
        for i, biter in pairs(global.BiterHuntGroupUnits) do
            if not biter.valid then
                global.BiterHuntGroupUnits[i] = nil
            end
        end
        if #global.BiterHuntGroupUnits == 0 then
            if global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin == nil then
                global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin = true
                game.print("[img=entity.medium-biter-corpse]      [img=entity.character]" .. global.biterHuntGroupTargetName .. " won")
            end
            BiterHuntGroup.ClearGlobals()
        end
    end
end

BiterHuntGroup.PlayerDied = function(playerID)
    if playerID == global.biterHuntGroupTargetPlayerID and global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin == nil then
        global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin = false
        game.print("[img=entity.medium-biter]      [img=entity.character-corpse]" .. global.biterHuntGroupTargetName .. " lost")
        BiterHuntGroup.ClearGlobals()
    end
end

BiterHuntGroup.ClearGlobals = function()
    global.biterHuntGroupState = nil
    global.biterHuntGroupTargetPlayerID = nil
    global.biterHuntGroupTargetEntity = nil
    global.biterHuntGroupTargetName = nil
    global.biterHuntGroupSurface = nil
    BiterHuntGroup.GuiUpdateAll()
end

BiterHuntGroup.EnsureValidateTarget = function()
    local targetEntity = global.biterHuntGroupTargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        global.biterHuntGroupTargetPlayerID = nil
        global.biterHuntGroupTargetEntity = nil
        global.biterHuntGroupTargetName = "Spawn"
        BiterHuntGroup.GuiUpdateAll()
    end
end

BiterHuntGroup.GetPositionForTarget = function(surface)
    local targetEntity = global.biterHuntGroupTargetEntity
    if targetEntity ~= nil and targetEntity.valid then
        return targetEntity.position
    else
        return game.forces["player"].get_spawn_position(surface)
    end
end

BiterHuntGroup.CreateGroundMovement = function()
    BiterHuntGroup._CreateGroundMovement()
end
BiterHuntGroup._CreateGroundMovement = function(distance, attempts)
    local biterPositions = {}
    local angleRad = math.rad(360 / biterHuntGroupSize)
    local surface = global.biterHuntGroupSurface
    local centerPosition = BiterHuntGroup.GetPositionForTarget(surface)
    distance = distance or biterHuntGroupRadius
    for i = 1, biterHuntGroupSize do
        local x = centerPosition.x + (distance * math.cos(angleRad * i))
        local y = centerPosition.y + (distance * math.sin(angleRad * i))
        local foundPosition = surface.find_non_colliding_position("biter-ground-movement", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
        end
    end
    Logging.Log("initial #biterPositions: " .. #biterPositions, debug)

    if #biterPositions < (biterHuntGroupSize / 2) then
        distance = distance * 0.75
        attempts = attempts or 0
        attempts = attempts + 1
        Logging.Log("not enough places on attempt: " .. attempts, debug)
        if attempts > 3 then
            Logging.LogPrint("failed to find enough places to spawn enemies around " .. Logging.PositionToString(centerPosition))
            return
        else
            BiterHuntGroup._CreateGroundMovement(distance, attempts)
            return
        end
    end

    global.BiterHuntGroupGroundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        BiterHuntGroup.SpawnGroundMovementEffect(surface, position)
    end

    local maxAttempts = (biterHuntGroupSize - #biterPositions) * 5
    local currentAttempts = 0
    Logging.Log("maxAttempts: " .. maxAttempts, debug)
    while #biterPositions < biterHuntGroupSize do
        local positionToTry = biterPositions[math.random(1, #biterPositions)]
        local foundPosition = surface.find_non_colliding_position("biter-ground-movement", positionToTry, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
            BiterHuntGroup.SpawnGroundMovementEffect(surface, foundPosition)
        end
        currentAttempts = currentAttempts + 1
        if currentAttempts > maxAttempts then
            Logging.Log("currentAttempts > maxAttempts", debug)
            break
        end
    end
    Logging.Log("final #biterPositions: " .. #biterPositions, debug)
end

BiterHuntGroup.SpawnGroundMovementEffect = function(surface, position)
    local effect = surface.create_entity {name = "biter-ground-movement", position = position}
    if effect == nil then
        Logging.LogPrint("failed to make effect at: " .. Logging.PositionToString(position))
    else
        effect.destructible = false
        table.insert(global.BiterHuntGroupGroundMovementEffects, effect)
    end
end

BiterHuntGroup.SpawnEnemyPreEffects = function()
    local surface = global.biterHuntGroupSurface
    for _, groundEffect in pairs(global.BiterHuntGroupGroundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no SpawnEnemiePreEffects can be made")
        else
            local position = groundEffect.position
            surface.create_entity {name = "biter-ground-rise-effect", position = position}
        end
    end
end

BiterHuntGroup.SpawnEnemies = function()
    local targetEntity = global.biterHuntGroupTargetEntity
    local surface = global.biterHuntGroupSurface
    local biterForce = game.forces["enemy"]
    local spawnerTypes = {"biter-spawner", "spitter-spawner"}
    local evolution = Utils.RoundNumberToDecimalPlaces(biterForce.evolution_factor + biterHuntGroupEvolutionAddition, 3)
    global.BiterHuntGroupUnits = {}
    local attackCommand
    if targetEntity ~= nil then
        attackCommand = {type = defines.command.attack, target = targetEntity}
    else
        attackCommand = {type = defines.command.attack_area, destination = BiterHuntGroup.GetPositionForTarget(surface), radius = 20}
    end
    for _, groundEffect in pairs(global.BiterHuntGroupGroundMovementEffects) do
        if not groundEffect.valid then
            Logging.LogPrint("ground effect has been removed by something, no biter can be made")
        else
            local position = groundEffect.position
            groundEffect.destroy()
            local spawnerType = spawnerTypes[math.random(2)]
            local enemyType = Utils.GetBiterType(global.biterHuntGroupEnemyProbabilities, spawnerType, evolution)
            local unit = surface.create_entity {name = enemyType, position = position, force = biterForce}
            if unit == nil then
                Logging.LogPrint("failed to make unit at: " .. Logging.PositionToString(position))
            else
                unit.set_command(attackCommand)
                table.insert(global.BiterHuntGroupUnits, unit)
            end
        end
    end
end

return BiterHuntGroup
