local BiterHuntGroup = {}
local GUIUtil = require("utility/gui-util")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local biterHuntGroupFrequencyRangeTicks = {
    --[[20 * 60 * 60]] 900,
    --[[45 * 60 * 60]] 900
}
local biterHuntGroupSize = 80
local biterHuntGroupEvolutionAddition = 0.1
local biterHuntGroupRadius = 50 --100
local biterHuntGroupTunnelTime = 180
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement", bitersActive = "bitersActive"}

BiterHuntGroup.ScheduleNextBiterHuntGroup = function()
    global.nextBiterHuntGroupTick = global.nextBiterHuntGroupTick + math.random(biterHuntGroupFrequencyRangeTicks[1], biterHuntGroupFrequencyRangeTicks[2])
end

BiterHuntGroup.CreateBiterHuntGroup = function()
    BiterHuntGroup.ScheduleNextBiterHuntGroup()
    global.biterHuntGroupState = biterHuntGroupState.start
end

BiterHuntGroup.SelectTarget = function()
    local players = game.connected_players
    local validTargets = {}
    for _, player in pairs(players) do
        if player.character then
            table.insert(validTargets, player)
        end
    end
    if #validTargets >= 1 then
        local target = validTargets[math.random(1, #validTargets)]
        global.biterHuntGroupTargetEntity = target.character
        global.biterHuntGroupTargetName = target.name
        global.biterHuntGroupSurface = target.surface
    else
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
    local countdownTimeString = Utils.LocalisedStringOfTime(global.nextBiterHuntGroupTick - game.tick, "auto")
    local targetNameString = global.biterHuntGroupTargetName
    for _, player in pairs(game.connected_players) do
        if specificPlayerIndex == nil or (specificPlayerIndex ~= nil and specificPlayerIndex == player.index) then
            BiterHuntGroup.GuiUpdatePlayer(player.index, countdownTimeString, targetNameString)
        end
    end
end

BiterHuntGroup.GuiUpdatePlayer = function(playerIndex, countdownTimeString, targetNameString)
    local countdownElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "countdown", "label")
    countdownElement.caption = {"gui-caption.jd_plays-countdown-label", countdownTimeString}
    local targetElement = GUIUtil.GetElementFromPlayersReferenceStorage(playerIndex, "target", "label")
    if targetNameString ~= nil then
        targetElement.caption = {"gui-caption.jd_plays-target-label", targetNameString}
    else
        targetElement.caption = ""
    end
end

BiterHuntGroup.FrequentTick = function(tick)
    if tick >= global.nextBiterHuntGroupTick then
        BiterHuntGroup.CreateBiterHuntGroup()
    end
    if global.biterHuntGroupState ~= nil then
        if global.biterHuntGroupState == biterHuntGroupState.start then
            global.biterHuntGroupState = biterHuntGroupState.groundMovement
            global.biterHuntGroupStateChangeTick = tick + biterHuntGroupTunnelTime
            BiterHuntGroup.SelectTarget()
            BiterHuntGroup.CreateGroundMovement()
        elseif global.biterHuntGroupState == biterHuntGroupState.groundMovement then
            if tick < global.biterHuntGroupStateChangeTick then
                BiterHuntGroup.EnsureValidateTarget()
            else
                global.biterHuntGroupState = biterHuntGroupState.bitersActive
                global.biterHuntGroupStateChangeTick = nil
                BiterHuntGroup.EnsureValidateTarget()
                BiterHuntGroup.SpawnEnemies()
            end
        elseif global.biterHuntGroupState == biterHuntGroupState.bitersActive then
            for i, biter in pairs(global.BiterHuntGroupUnits) do
                if not biter.valid then
                    global.BiterHuntGroupUnits[i] = nil
                end
            end
            if #global.BiterHuntGroupUnits == 0 then
                global.biterHuntGroupState = nil
                global.biterHuntGroupTargetEntity = nil
                global.biterHuntGroupTargetName = nil
            end
        end
    end
end

BiterHuntGroup.EnsureValidateTarget = function()
    local targetEntity = global.biterHuntGroupTargetEntity
    if targetEntity ~= nil and (not targetEntity.valid) then
        BiterHuntGroup.SelectTarget()
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
    local biterPositions = {}
    local angleRad = math.rad(360 / biterHuntGroupSize)
    local surface = global.biterHuntGroupSurface
    local centerPosition = BiterHuntGroup.GetPositionForTarget(surface)
    local distance = biterHuntGroupRadius
    for i = 1, biterHuntGroupSize do
        local x = centerPosition.x + (distance * math.cos(angleRad * i))
        local y = centerPosition.y + (distance * math.sin(angleRad * i))
        local foundPosition = surface.find_non_colliding_position("rock-big", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
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
