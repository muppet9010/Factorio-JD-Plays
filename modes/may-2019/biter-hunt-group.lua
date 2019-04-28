local BiterHuntGroup = {}
local GUIUtil = require("utility/gui-util")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local biterHuntGroupFrequencyRangeTicks = {
    --[[20 * 60 * 60]] 300,
    --[[45 * 60 * 60]] 300
}
local biterHuntGroupSize = 10 --80
local biterHuntGroupEvolutionAddition = 0.1
local biterHuntGroupRadius = 10 --100
local biterHuntGroupTunnelTime = 180
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement", bitersActive = "bitersActive"}

BiterHuntGroup.ScheduleNextBiterHuntGroup = function()
    global.nextBiterHuntGroupTick = global.nextBiterHuntGroupTick + math.random(biterHuntGroupFrequencyRangeTicks[1], biterHuntGroupFrequencyRangeTicks[2])
end

BiterHuntGroup.SelectTarget = function()
    local players = game.connected_players
    local validPlayers = {}
    for _, player in pairs(players) do
        if player.character then
            table.insert(validPlayers, player)
        end
    end
    if #validPlayers >= 1 then
        local target = validPlayers[math.random(1, #validPlayers)]
        global.biterHuntGroupTargetPlayer = target
        global.biterHuntGroupTargetEntity = target.character
        global.biterHuntGroupTargetName = target.name
        global.biterHuntGroupSurface = target.surface
    else
        global.biterHuntGroupTargetPlayer = nil
        global.biterHuntGroupTargetEntity = nil
        global.biterHuntGroupTargetName = "Spawn"
        global.biterHuntGroupSurface = game.surfaces[1]
    end
end

BiterHuntGroup.GuiCreate = function(player)
    GUIUtil.CreatePlayersElementReferenceStorage(player.index)
    local frame = GUIUtil.AddElement({parent = player.gui.left, name = "biterhuntgroup", type = "frame", direction = "vertical"}, true)
    GUIUtil.AddElement({parent = frame, name = "countdown", type = "label"}, true)
    GUIUtil.AddElement({parent = frame, name = "target", type = "label"}, true)
    BiterHuntGroup.GuiUpdateAll(player.index)
end

BiterHuntGroup.GuiDestroy = function(player)
    GUIUtil.GetElementFromPlayersReferenceStorage(player.index, "biterhuntgroup", "frame").destroy()
    GUIUtil.RemovePlayersReferenceStorage(player.index)
end

BiterHuntGroup.GuiUpdateAll = function(specificPlayerIndex)
    local countdownTimeLocalisedString = {"gui-caption.jd_plays-countdown-label", Utils.LocalisedStringOfTime(global.nextBiterHuntGroupTick - game.tick, "auto")}
    local targetLocalisedString
    if global.biterHuntGroupTargetName ~= nil and global.biterHuntGroupSurface ~= nil then
        targetLocalisedString = {"gui-caption.jd_plays-target-label", global.biterHuntGroupTargetName, global.biterHuntGroupSurface.name}
    end
    for _, player in pairs(game.connected_players) do
        if specificPlayerIndex == nil or (specificPlayerIndex ~= nil and specificPlayerIndex == player.index) then
            BiterHuntGroup.GuiUpdatePlayerWithData(player.index, countdownTimeLocalisedString, targetLocalisedString)
        end
    end
end

BiterHuntGroup.GuiUpdatePlayerWithData = function(playerIndex, countdownTimeLocalisedString, targetLocalisedString)
    local countdownElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "countdown", "label")
    countdownElement.caption = countdownTimeLocalisedString
    local targetElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "target", "label")
    if targetLocalisedString ~= nil then
        targetElement.caption = targetLocalisedString
    else
        targetElement.caption = ""
    end
end

BiterHuntGroup.FrequentTick = function(tick)
    if tick >= global.nextBiterHuntGroupTick then
        if global.BiterHuntGroupResults[global.biterHuntGroupId] ~= nil and global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin == nil then
            game.print("[img=entity.medium-biter-corpse]      [img=entity.player-corpse]" .. global.biterHuntGroupTargetName)
        end
        BiterHuntGroup.ClearGlobals()
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
        global.biterHuntGroupState = biterHuntGroupState.groundMovement
        global.biterHuntGroupStateChangeTick = tick + biterHuntGroupTunnelTime
        BiterHuntGroup.SelectTarget()
        game.print("[img=entity.medium-biter][img=entity.medium-biter][img=entity.medium-biter]      [img=entity.player]" .. global.biterHuntGroupTargetName)
        BiterHuntGroup.CreateGroundMovement()
    elseif global.biterHuntGroupState == biterHuntGroupState.groundMovement then
        if tick < global.biterHuntGroupStateChangeTick then
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
                game.print("[img=entity.medium-biter-corpse]      [img=entity.player]" .. global.biterHuntGroupTargetName)
            end
            BiterHuntGroup.ClearGlobals()
        end
    end
end

BiterHuntGroup.PlayerDied = function(player)
    if player == global.biterHuntGroupTargetPlayer and global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin == nil then
        global.BiterHuntGroupResults[global.biterHuntGroupId].playerWin = false
        game.print("[img=entity.medium-biter]      [img=entity.character-corpse]" .. global.biterHuntGroupTargetName)
        BiterHuntGroup.ClearGlobals()
    end
end

BiterHuntGroup.ClearGlobals = function()
    global.biterHuntGroupState = nil
    global.biterHuntGroupTargetPlayer = nil
    global.biterHuntGroupTargetEntity = nil
    global.biterHuntGroupTargetName = nil
    global.biterHuntGroupSurface = nil
end

BiterHuntGroup.EnsureValidateTarget = function()
    local targetEntity = global.biterHuntGroupTargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        global.biterHuntGroupTargetPlayer = nil
        global.biterHuntGroupTargetEntity = nil
        global.biterHuntGroupTargetName = "Spawn"
    end
end

BiterHuntGroup.GetPositionForTarget = function(surface)
    local targetEntity = global.biterHuntGroupTargetEntity
    if targetEntity ~= nil then
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
        local foundPosition = surface.find_non_colliding_position("rock-big", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
        end
    end

    if #biterPositions < (biterHuntGroupSize / 2) then
        distance = distance / 2
        attempts = attempts or 0
        attempts = attempts + 1
        if attempts > 3 then
            Logging.LogPrint("failed to find enough places to spawn enemies around " .. Logging.PositionToString(centerPosition))
            return
        else
            BiterHuntGroup._CreateGroundMovement(distance, attempts)
        end
    end

    global.BiterHuntGroupGroundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        BiterHuntGroup.SpawnGroundMovementEffect(surface, position)
    end

    while #biterPositions < biterHuntGroupSize do
        local positionToTry = biterPositions[math.random(1, #biterPositions)]
        local foundPosition = surface.find_non_colliding_position("rock-big", positionToTry, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
            BiterHuntGroup.SpawnGroundMovementEffect(surface, foundPosition)
        end
    end
end

BiterHuntGroup.SpawnGroundMovementEffect = function(surface, position)
    local effect = surface.create_entity {name = "rock-big", position = position}
    if effect == nil then
        Logging.LogPrint("failed to make effect at: " .. Logging.PositionToString(position))
    else
        table.insert(global.BiterHuntGroupGroundMovementEffects, effect)
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

return BiterHuntGroup
