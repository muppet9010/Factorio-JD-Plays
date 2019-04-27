local BiterHuntGroup = {}
local GUIUtil = require("utility/gui-util")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local biterHuntGroupFrequencyRange = {
    --[[20]] 0.1 * 60 * 60,
    --[[45]] 0.1 * 60 * 60
}
local biterHuntGroupSize = 80
local biterHuntGroupEvolutionAddition = 0.1
local biterHuntGroupRadius --[[100]] = 20
local biterHuntGroupTunnelTime = 180
local biterHuntGroupState = {start = "start", groundMovement = "groundMovement"}

BiterHuntGroup.ScheduleNextBiterHuntGroup = function()
    global.nextBiterHuntGroupTick = global.nextBiterHuntGroupTick + math.random(biterHuntGroupFrequencyRange[1], biterHuntGroupFrequencyRange[2])
end

BiterHuntGroup.CreateBiterHuntGroup = function()
    BiterHuntGroup.ScheduleNextBiterHuntGroup()
    global.biterHuntGroupTargetEntity = BiterHuntGroup.SelectTarget()
    global.biterHuntGroupTargetName = global.biterHuntGroupTargetEntity.name
    global.biterHuntGroupState = biterHuntGroupState.start
end

BiterHuntGroup.SelectTarget = function()
    local targets = game.connected_players
    return targets[math.random(1, #targets)]
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
    local targetNameString = global.nextBiterHuntGroupTargetName
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
            BiterHuntGroup.CreateGroundMovement()
        elseif global.biterHuntGroupState == biterHuntGroupState.groundMovement and tick >= global.biterHuntGroupStateChangeTick then
            global.biterHuntGroupState = nil
            global.biterHuntGroupStateChangeTick = nil
            BiterHuntGroup.SpawnEnemies()
        end
    end
end

BiterHuntGroup.CreateGroundMovement = function()
    local biterPositions = {}
    local angle = 360 / biterHuntGroupSize
    local centerPosition = global.biterHuntGroupTargetEntity.position
    local distance = biterHuntGroupRadius
    local surface = global.biterHuntGroupTargetEntity.surface
    for i = 1, biterHuntGroupSize do
        local x = centerPosition.x + (distance * math.cos(angle * i))
        local y = centerPosition.y + (distance * math.sin(angle * i))
        local foundPosition = surface.find_non_colliding_position("rock-big", {x, y}, 2, 1, true)
        if foundPosition ~= nil then
            table.insert(biterPositions, foundPosition)
        end
    end

    if #biterPositions < biterHuntGroupSize then
    --add more biters to random valid spots until all done
    end

    global.BiterHuntGroupGroundMovementEffects = {}
    for _, position in pairs(biterPositions) do
        local effect = surface.create_entity {name = "rock-big", position = position}
        if effect == nil then
            game.print("failed to make effect at: " .. Logging.PositionToString(position))
        else
            table.insert(global.BiterHuntGroupGroundMovementEffects, effect)
        end
    end
end

BiterHuntGroup.SpawnEnemies = function()
    local target = global.biterHuntGroupTargetEntity
    local surface = target.surface
    local biterForce = game.forces["enemy"]
    local spawnerTypes = {"biter-spawner", "spitter-spawner"}
    local evolution = Utils.RoundNumberToDecimalPlaces(biterForce.evolution_factor + biterHuntGroupEvolutionAddition, 3)
    global.BiterHuntGroupUnits = {}
    for _, groundEffect in pairs(global.BiterHuntGroupGroundMovementEffects) do
        local position = groundEffect.position
        groundEffect.destroy()
        local spawnerType = spawnerTypes[math.random(2)]
        local enemyType = Utils.GetBiterType(global.biterHuntGroupEnemyProbabilities, spawnerType, evolution)
        game.print(enemyType)
        local unit = surface.create_entity {name = enemyType, position = position, force = biterForce --[[, target = target]]}
        if unit == nil then
            game.print("failed to make unit at: " .. Logging.PositionToString(position))
        else
            table.insert(global.BiterHuntGroupUnits, unit)
        end
    end
end

return BiterHuntGroup
