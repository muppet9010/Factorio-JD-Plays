--- Random utility functions that don't fit in to any other category.
--- These functions won't include input validation as in most cases its a waste of UPS.

--[[
    Future Improvements:
        - Break out in to seperate files.
        - Make use of ProtoTypeAttributes library to cache prototype data automatically. Present in the new train functions already.
--]]
--

local Utils = {}
local factorioUtil = require("__core__.lualib.util")
local PrototypeAttributes = require("utility.prototype-attributes")

local math_min, math_max, math_floor, math_ceil, math_sqrt, math_abs, math_random, math_exp, math_rad, math_cos, math_sin = math.min, math.max, math.floor, math.ceil, math.sqrt, math.abs, math.random, math.exp, math.rad, math.cos, math.sin
local string_match, string_rep, string_find, string_sub, string_len, string_gsub, string_lower = string.match, string.rep, string.find, string.sub, string.len, string.gsub, string.lower

--- Copies a table and all of its children all the way down.
---@type fun(object:table):table
Utils.DeepCopy = factorioUtil.table.deepcopy

--- Takes an array of tables and returns a new table with copies of their contents. Merges children when they are tables togeather, but non table data types will have the latest value as the result.
---@type fun(tables:table[]):table
Utils.TableMergeCopies = factorioUtil.merge

--- Takes an array of tables and returns a new table with references to their top level contents. Does a shallow merge, so just the top level key/values. Last duplicate key's value processed will be the final result.
---@param sourceTables table[]
---@return table mergedTable
Utils.TableMergeOrigionalsShallow = function(sourceTables)
    local mergedTable = {}
    for _, sourceTable in pairs(sourceTables) do
        for k in pairs(sourceTable) do
            mergedTable[k] = sourceTable[k]
        end
    end
    return mergedTable
end

--- Uses unit number if both support it, otherwise has to compare a lot of attributes to try and work out if they are the same base entity. Assumes the entity won't ever move or change.
---@param entity1 LuaEntity
---@param entity2 LuaEntity
Utils.Are2EntitiesTheSame = function(entity1, entity2)
    if not entity1.valid or not entity2.valid then
        return false
    end
    if entity1.unit_number ~= nil and entity2.unit_number ~= nil then
        if entity1.unit_number == entity2.unit_number then
            return true
        else
            return false
        end
    else
        if entity1.type == entity2.type and entity1.name == entity2.name and entity1.surface.index == entity2.surface.index and entity1.position.x == entity2.position.x and entity1.position.y == entity2.position.y and entity1.force.index == entity2.force.index and entity1.health == entity2.health then
            return true
        else
            return false
        end
    end
end

---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean
Utils.ArePositionsTheSame = function(pos1, pos2)
    if (pos1.x or pos1[1]) == (pos2.x or pos2[1]) and (pos1.y or pos1[2]) == (pos2.y or pos2[2]) then
        return true
    else
        return false
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected? LuaForce|null
---@param onlyDestructible boolean
---@param onlyKillable boolean
---@param entitiesExcluded? LuaEntity[]|null
---@return table<int, LuaEntity>
Utils.ReturnAllObjectsInArea = function(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, onlyDestructible, onlyKillable, entitiesExcluded)
    local entitiesFound, filteredEntitiesFound = surface.find_entities(positionedBoundingBox), {}
    for k, entity in pairs(entitiesFound) do
        if entity.valid then
            local entityExcluded = false
            if entitiesExcluded ~= nil and #entitiesExcluded > 0 then
                for _, excludedEntity in pairs(entitiesExcluded) do
                    if Utils.Are2EntitiesTheSame(entity, excludedEntity) then
                        entityExcluded = true
                        break
                    end
                end
            end
            if not entityExcluded then
                if (onlyForceAffected == nil) or (entity.force == onlyForceAffected) then
                    if (not onlyDestructible) or (entity.destructible) then
                        if (not onlyKillable) or (entity.health ~= nil) then
                            if (not collisionBoxOnlyEntities) or (Utils.IsCollisionBoxPopulated(entity.prototype.collision_box)) then
                                table.insert(filteredEntitiesFound, entity)
                            end
                        end
                    end
                end
            end
        end
    end
    return filteredEntitiesFound
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param killerEntity? LuaEntity|null
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected boolean
---@param entitiesExcluded? LuaEntity[]|null
---@param killerForce? LuaForce|null
Utils.KillAllKillableObjectsInArea = function(surface, positionedBoundingBox, killerEntity, collisionBoxOnlyEntities, onlyForceAffected, entitiesExcluded, killerForce)
    if killerForce == nil then
        killerForce = "neutral"
    end
    for _, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, true, true, entitiesExcluded)) do
        if killerEntity ~= nil then
            entity.die(killerForce, killerEntity)
        else
            entity.die(killerForce)
        end
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param killerEntity? LuaEntity|null
---@param onlyForceAffected boolean
---@param entitiesExcluded? LuaEntity[]|null
---@param killerForce? LuaForce|null
Utils.KillAllObjectsInArea = function(surface, positionedBoundingBox, killerEntity, onlyForceAffected, entitiesExcluded, killerForce)
    if killerForce == nil then
        killerForce = "neutral"
    end
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, false, onlyForceAffected, false, false, entitiesExcluded)) do
        if entity.destructible then
            if killerEntity ~= nil then
                entity.die(killerForce, killerEntity)
            else
                entity.die(killerForce)
            end
        else
            entity.destroy {do_cliff_correction = true, raise_destroy = true}
        end
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param collisionBoxOnlyEntities boolean
---@param onlyForceAffected boolean
---@param entitiesExcluded? LuaEntity[]|null
Utils.DestroyAllKillableObjectsInArea = function(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, entitiesExcluded)
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, collisionBoxOnlyEntities, onlyForceAffected, true, true, entitiesExcluded)) do
        entity.destroy {do_cliff_correction = true, raise_destroy = true}
    end
end

---@param surface LuaSurface
---@param positionedBoundingBox BoundingBox
---@param onlyForceAffected boolean
---@param entitiesExcluded? LuaEntity[]|null
Utils.DestroyAllObjectsInArea = function(surface, positionedBoundingBox, onlyForceAffected, entitiesExcluded)
    for k, entity in pairs(Utils.ReturnAllObjectsInArea(surface, positionedBoundingBox, false, onlyForceAffected, false, false, entitiesExcluded)) do
        entity.destroy {do_cliff_correction = true, raise_destroy = true}
    end
end

--- Kills any carriages that would prevent the rail from being removed. If a carriage is not destructable make it so, so it can be killed normally and appear in death stats, etc.
---@param railEntity LuaEntity
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
---@param surface LuaSurface
Utils.DestroyCarriagesOnRailEntity = function(railEntity, killForce, killerCauseEntity, surface)
    -- Check if any carriage prevents the rail from being removed before just killing all carriages within the rails collision boxes as this is more like vanilla behaviour.
    if not railEntity.can_be_destroyed() then
        local railEntityCollisionBox = PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, railEntity.name, "collision_box")
        local positionedCollisionBox = Utils.ApplyBoundingBoxToPosition(railEntity.position, railEntityCollisionBox, railEntity.orientation)
        local carriagesFound = surface.find_entities_filtered {area = positionedCollisionBox, type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
        for _, carriage in pairs(carriagesFound) do
            -- If the carriage is currently not destructable make it so, so we can kill it normally.
            if not carriage.destructible then
                carriage.destructible = true
            end
            Utils.EntityDie(carriage, killForce, killerCauseEntity)
        end
        if railEntity.type == "curved-rail" then
            railEntityCollisionBox = PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, railEntity.name, "secondary_collision_box")
            positionedCollisionBox = Utils.ApplyBoundingBoxToPosition(railEntity.position, railEntityCollisionBox, railEntity.orientation)
            carriagesFound = surface.find_entities_filtered {area = positionedCollisionBox, type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
            for _, carriage in pairs(carriagesFound) do
                -- If the carriage is currently not destructable make it so, so we can kill it normally.
                if not carriage.destructible then
                    carriage.destructible = true
                end
                Utils.EntityDie(carriage, killForce, killerCauseEntity)
            end
        end
    end
end

--- Mines any carriages that would prevent the rail from being removed.
---@param railEntity LuaEntity
---@param surface LuaSurface
---@param ignoreMinableEntityFlag boolean @ If TRUE an entities "minable" attribute will be ignored and the entity mined. If FALSE then the entities "minable" attribute will be honoured.
---@param destinationInventory LuaInventory
---@param stopTrain boolean @ If TRUE stops the train that it will try and mine.
Utils.MineCarriagesOnRailEntity = function(railEntity, surface, ignoreMinableEntityFlag, destinationInventory, stopTrain)
    -- Check if any carriage prevents the rail from being removed before just killing all carriages within the rails collision boxes as this is more like vanilla behaviour.
    if not railEntity.can_be_destroyed() then
        local railEntityCollisionBox = PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, railEntity.name, "collision_box")
        local positionedCollisionBox = Utils.ApplyBoundingBoxToPosition(railEntity.position, railEntityCollisionBox, railEntity.orientation)
        local carriagesFound = surface.find_entities_filtered {area = positionedCollisionBox, type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
        for _, carriage in pairs(carriagesFound) do
            -- If stopTrain is enabled and the carriage is currently moving stop its train.
            if stopTrain then
                if carriage.speed ~= 0 then
                    carriage.train.speed = 0
                    carriage.train.manual_mode = true
                end
            end
            carriage.mine {inventory = destinationInventory, ignore_minable = ignoreMinableEntityFlag, raise_destroyed = true}
        end
        if railEntity.type == "curved-rail" then
            railEntityCollisionBox = PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, railEntity.name, "secondary_collision_box")
            positionedCollisionBox = Utils.ApplyBoundingBoxToPosition(railEntity.position, railEntityCollisionBox, railEntity.orientation)
            carriagesFound = surface.find_entities_filtered {area = positionedCollisionBox, type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
            for _, carriage in pairs(carriagesFound) do
                -- If stopTrain is enabled and the carriage is currently moving stop its train.
                if stopTrain then
                    if carriage.speed ~= 0 then
                        carriage.train.speed = 0
                        carriage.train.manual_mode = true
                    end
                end
                carriage.mine {inventory = destinationInventory, ignore_minable = ignoreMinableEntityFlag, raise_destroyed = true}
            end
        end
    end
end

---@param thing table
---@return boolean
Utils.IsTableValidPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return true
    else
        return false
    end
end

---@param thing table
---@return MapPosition
Utils.TableToProperPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return thing
        else
            return nil
        end
    end
    if #thing ~= 2 then
        return nil
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return {x = thing[1], y = thing[2]}
    else
        return nil
    end
end

---@param thing table
---@return boolean
Utils.IsTableValidBoundingBox = function(thing)
    if thing.left_top ~= nil and thing.right_bottom ~= nil then
        if Utils.IsTableValidPosition(thing.left_top) and Utils.IsTableValidPosition(thing.right_bottom) then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if Utils.IsTableValidPosition(thing[1]) and Utils.IsTableValidPosition(thing[2]) then
        return true
    else
        return false
    end
end

---@param thing table
---@return BoundingBox
Utils.TableToProperBoundingBox = function(thing)
    if not Utils.IsTableValidBoundingBox(thing) then
        return nil
    elseif thing.left_top ~= nil and thing.right_bottom ~= nil then
        return {left_top = Utils.TableToProperPosition(thing.left_top), right_bottom = Utils.TableToProperPosition(thing.right_bottom)}
    else
        return {left_top = Utils.TableToProperPosition(thing[1]), right_bottom = Utils.TableToProperPosition(thing[2])}
    end
end

---@param centrePos MapPosition
---@param boundingBox BoundingBox
---@param orientation RealOrientation
---@return BoundingBox
Utils.ApplyBoundingBoxToPosition = function(centrePos, boundingBox, orientation)
    centrePos = Utils.TableToProperPosition(centrePos)
    boundingBox = Utils.TableToProperBoundingBox(boundingBox)
    if orientation == nil or orientation == 0 or orientation == 1 then
        return {
            left_top = {
                x = centrePos.x + boundingBox.left_top.x,
                y = centrePos.y + boundingBox.left_top.y
            },
            right_bottom = {
                x = centrePos.x + boundingBox.right_bottom.x,
                y = centrePos.y + boundingBox.right_bottom.y
            }
        }
    elseif orientation == 0.25 or orientation == 0.5 or orientation == 0.75 then
        local rotatedPoint1 = Utils.RotatePositionAround0(orientation, boundingBox.left_top)
        local rotatedPoint2 = Utils.RotatePositionAround0(orientation, boundingBox.right_bottom)
        local rotatedBoundingBox = Utils.CalculateBoundingBoxFrom2Points(rotatedPoint1, rotatedPoint2)
        return {
            left_top = {
                x = centrePos.x + rotatedBoundingBox.left_top.x,
                y = centrePos.y + rotatedBoundingBox.left_top.y
            },
            right_bottom = {
                x = centrePos.x + rotatedBoundingBox.right_bottom.x,
                y = centrePos.y + rotatedBoundingBox.right_bottom.y
            }
        }
    end
end

---@param pos MapPosition
---@param numDecimalPlaces uint
---@return MapPosition
Utils.RoundPosition = function(pos, numDecimalPlaces)
    return {x = Utils.RoundNumberToDecimalPlaces(pos.x, numDecimalPlaces), y = Utils.RoundNumberToDecimalPlaces(pos.y, numDecimalPlaces)}
end

---@param pos MapPosition
---@return ChunkPosition
Utils.GetChunkPositionForTilePosition = function(pos)
    return {x = math_floor(pos.x / 32), y = math_floor(pos.y / 32)}
end

---@param chunkPos ChunkPosition
---@return MapPosition
Utils.GetLeftTopTilePositionForChunkPosition = function(chunkPos)
    return {x = chunkPos.x * 32, y = chunkPos.y * 32}
end

--- Rotates an offset around position of {0,0}.
---@param orientation RealOrientation
---@param position MapPosition
---@return MapPosition
Utils.RotatePositionAround0 = function(orientation, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return position
    elseif orientation == 0.25 then
        return {
            x = -position.y,
            y = position.x
        }
    elseif orientation == 0.5 then
        return {
            x = -position.x,
            y = -position.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.y,
            y = -position.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return {x = rotatedX, y = rotatedY}
end

--- Rotates an offset around a position. Combines Utils.RotatePositionAround0() and Utils.ApplyOffsetToPosition() to save UPS.
---@param orientation RealOrientation
---@param offset MapPosition @ the position to be rotated by the orientation.
---@param position MapPosition @ the position the rotated offset is applied to.
---@return MapPosition
Utils.RotateOffsetAroundPosition = function(orientation, offset, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return {
            x = position.x + offset.x,
            y = position.y + offset.y
        }
    elseif orientation == 0.25 then
        return {
            x = position.x - offset.y,
            y = position.y + offset.x
        }
    elseif orientation == 0.5 then
        return {
            x = position.x - offset.x,
            y = position.y - offset.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.x + offset.y,
            y = position.y - offset.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return {x = position.x + rotatedX, y = position.y + rotatedY}
end

--- Rotates the directionToRotate by a direction difference from the referenceDirection to the appliedDirection. Useful for rotating entities direction in proportion to a parent's direction change from known direction.
---
--- Should be done locally if called frequently.
---@param directionToRotate defines.direction
---@param referenceDirection defines.direction
---@param appliedDirection defines.direction
Utils.RotateDirectionByDirection = function(directionToRotate, referenceDirection, appliedDirection)
    local directionDif = appliedDirection - referenceDirection
    local directionValue = directionToRotate + directionDif
    -- Hard coded copy of Utils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return 0 - (7 - directionValue) - 1
    elseif directionValue < 0 then
        return 7 + (directionValue - 7) + 1
    else
        return directionValue
    end
end

---@param point1 MapPosition
---@param point2 MapPosition
---@return BoundingBox
Utils.CalculateBoundingBoxFrom2Points = function(point1, point2)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    if minX == nil or point1.x < minX then
        minX = point1.x
    end
    if maxX == nil or point1.x > maxX then
        maxX = point1.x
    end
    if minY == nil or point1.y < minY then
        minY = point1.y
    end
    if maxY == nil or point1.y > maxY then
        maxY = point1.y
    end
    if minX == nil or point2.x < minX then
        minX = point2.x
    end
    if maxX == nil or point2.x > maxX then
        maxX = point2.x
    end
    if minY == nil or point2.y < minY then
        minY = point2.y
    end
    if maxY == nil or point2.y > maxY then
        maxY = point2.y
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

---@param listOfBoundingBoxs BoundingBox[]
---@return BoundingBox
Utils.CalculateBoundingBoxToIncludeAllBoundingBoxs = function(listOfBoundingBoxs)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for _, boundingBox in pairs(listOfBoundingBoxs) do
        for _, point in pairs({boundingBox.left_top, boundingBox.right_bottom}) do
            if minX == nil or point.x < minX then
                minX = point.x
            end
            if maxX == nil or point.x > maxX then
                maxX = point.x
            end
            if minY == nil or point.y < minY then
                minY = point.y
            end
            if maxY == nil or point.y > maxY then
                maxY = point.y
            end
        end
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

-- Applies an offset to a position. If you are rotating the offset first consider using Utils.RotateOffsetAroundPosition() as lower UPS than the 2 seperate function calls.
---@param position MapPosition
---@param offset MapPosition
---@return MapPosition
Utils.ApplyOffsetToPosition = function(position, offset)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y
    }
end

Utils.GrowBoundingBox = function(boundingBox, growthX, growthY)
    return {
        left_top = {
            x = boundingBox.left_top.x - growthX,
            y = boundingBox.left_top.y - growthY
        },
        right_bottom = {
            x = boundingBox.right_bottom.x + growthX,
            y = boundingBox.right_bottom.y + growthY
        }
    }
end

Utils.IsCollisionBoxPopulated = function(collisionBox)
    if collisionBox == nil then
        return false
    end
    if collisionBox.left_top.x ~= 0 and collisionBox.left_top.y ~= 0 and collisionBox.right_bottom.x ~= 0 and collisionBox.right_bottom.y ~= 0 then
        return true
    else
        return false
    end
end

Utils.LogisticEquation = function(index, height, steepness)
    return height / (1 + math_exp(steepness * (index - 0)))
end

Utils.ExponentialDecayEquation = function(index, multiplier, scale)
    return multiplier * math_exp(-index * scale)
end

Utils.RoundNumberToDecimalPlaces = function(num, numDecimalPlaces)
    local result
    if numDecimalPlaces ~= nil and numDecimalPlaces > 0 then
        local mult = 10 ^ numDecimalPlaces
        result = math_floor(num * mult + 0.5) / mult
    else
        result = math_floor(num + 0.5)
    end
    if result ~= result then
        -- Result is NaN so set it to 0.
        result = 0
    end
    return result
end

--- Checks if the provided number is a NaN value.
---
--- Should be done locally if called frequently.
---@param value number
---@return boolean valueIsANan
Utils.IsNumberNan = function(value)
    if value ~= value then
        return true
    else
        return false
    end
end

-- This steps through the ints with min and max being seperatee steps.
---@param value int
---@param min int
---@param max int
---@return int
Utils.LoopIntValueWithinRange = function(value, min, max)
    if value > max then
        return min - (max - value) - 1
    elseif value < min then
        return max + (value - min) + 1
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. Depending on starting input value you get either the min or max value at the border.
---@param value number
---@param min number
---@param max number
---@return number
Utils.LoopFloatValueWithinRange = function(value, min, max)
    if value > max then
        return min + (value - max)
    elseif value < min then
        return max - (value - min)
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. But maxExclusive will give the minInclusive value. So maxExclsuive can never be returned.
---
--- Should be done locally if called frequently.
---@param value number
---@param minInclusive number
---@param maxExclusive number
---@return number
Utils.LoopFloatValueWithinRangeMaxExclusive = function(value, minInclusive, maxExclusive)
    if value >= maxExclusive then
        return minInclusive + (value - maxExclusive)
    elseif value < minInclusive then
        return maxExclusive - (value - minInclusive)
    else
        return value
    end
end

--- Return the passed in number clamped to within the max and min limits inclusively.
---@param value number
---@param min number
---@param max number
---@return number
Utils.ClampNumber = function(value, min, max)
    return math_min(math_max(value, min), max)
end

--- Takes a orientation (0-1) and returns a direction (int 0-7).
---
--- Should be done locally if called frequently.
---@param orientation RealOrientation @ Will be rounded to the nearest cardinal or intercardinal direction.
---@return defines.direction
Utils.OrientationToDirection = function(orientation)
    local directionValue = Utils.RoundNumberToDecimalPlaces(orientation * 8, 0)
    -- Hard coded copy of Utils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return 0 - (7 - directionValue) - 1
    elseif directionValue < 0 then
        return 7 + (directionValue - 7) + 1
    else
        return directionValue
    end
end

--- Takes a direction (int 0-7) and returns an orientation (0-1).
---
--- Should be done locally if called frequently.
---@param directionValue defines.direction
---@return RealOrientation
Utils.DirectionToOrientation = function(directionValue)
    return directionValue / 8
end

--- A dictionary of directionValue key's (0-7) to their direction name (label's of defines.direction).
Utils.DirectionValueToName = {
    [0] = "north",
    [1] = "northeast",
    [2] = "east",
    [3] = "southeast",
    [4] = "south",
    [5] = "southwest",
    [6] = "west",
    [7] = "northwest"
}

--- Takes a direction input value and if it's greater/less than the allowed orientation range it loops it back within the range.
---@param directionValue defines.direction @ A number from 0-7.
---@return defines.direction
Utils.LoopDirectionValue = function(directionValue)
    -- Hard coded copy of Utils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return 0 - (7 - directionValue) - 1
    elseif directionValue < 0 then
        return 7 + (directionValue - 7) + 1
    else
        return directionValue
    end
end

--- Takes an orientation input value and if it's greater/less than the allowed orientation range it loops it back within the range.
---
--- Should be done locally if called frequently.
---@param orientationValue RealOrientation
---@return RealOrientation
Utils.LoopOrientationValue = function(orientationValue)
    -- Hard coded copy of Utils.LoopFloatValueWithinRangeMaxExclusive().
    if orientationValue >= 1 then
        return 0 + (orientationValue - 1)
    elseif orientationValue < 0 then
        return 1 - (orientationValue - 0)
    else
        return orientationValue
    end
end

Utils.HandleFloatNumberAsChancedValue = function(value)
    local intValue = math_floor(value)
    local partialValue = value - intValue
    local chancedValue = intValue
    if partialValue ~= 0 then
        local rand = math_random()
        if rand >= partialValue then
            chancedValue = chancedValue + 1
        end
    end
    return chancedValue
end

-- This doesn't guarentee correct on some of the edge cases, but is as close as possible assuming that 1/256 is the variance for the same number (Bilka, Dev on Discord)
Utils.FuzzyCompareDoubles = function(num1, logic, num2)
    local numDif = num1 - num2
    local variance = 1 / 256
    if logic == "=" then
        if numDif < variance and numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "!=" then
        if numDif < variance and numDif > -variance then
            return false
        else
            return true
        end
    elseif logic == ">" then
        if numDif > variance then
            return true
        else
            return false
        end
    elseif logic == ">=" then
        if numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "<" then
        if numDif < -variance then
            return true
        else
            return false
        end
    elseif logic == "<=" then
        if numDif < variance then
            return true
        else
            return false
        end
    end
end

---@param table table
---@return boolean
Utils.IsTableEmpty = function(table)
    if table == nil or next(table) == nil then
        return true
    else
        return false
    end
end

Utils.GetTableNonNilLength = function(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

---@param table table
---@return StringOrNumber
Utils.GetFirstTableKey = function(table)
    return next(table)
end

---@param table table
---@return any
Utils.GetFirstTableValue = function(table)
    return table[next(table)]
end

---@param table table
---@return uint
Utils.GetMaxKey = function(table)
    local max_key = 0
    for k in pairs(table) do
        if k > max_key then
            max_key = k
        end
    end
    return max_key
end

Utils.GetTableValueByIndexCount = function(table, indexCount)
    local count = 0
    for _, v in pairs(table) do
        count = count + 1
        if count == indexCount then
            return v
        end
    end
end

Utils.CalculateBoundingBoxFromPositionAndRange = function(position, range)
    return {
        left_top = {
            x = position.x - range,
            y = position.y - range
        },
        right_bottom = {
            x = position.x + range,
            y = position.y + range
        }
    }
end

Utils.CalculateTilesUnderPositionedBoundingBox = function(positionedBoundingBox)
    local tiles = {}
    for x = positionedBoundingBox.left_top.x, positionedBoundingBox.right_bottom.x do
        for y = positionedBoundingBox.left_top.y, positionedBoundingBox.right_bottom.y do
            table.insert(tiles, {x = math_floor(x), y = math_floor(y)})
        end
    end
    return tiles
end

-- Gets the distance between the 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number @ is inheriently a positive number.
Utils.GetDistance = function(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math_sqrt(dx * dx + dy * dy)
end

-- Gets the distance between a single axis of 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param axis Axis
---@return number @ is inheriently a positive number.
Utils.GetDistanceSingleAxis = function(pos1, pos2, axis)
    return math_abs(pos1[axis] - pos2[axis])
end

-- Returns the offset for the first position in relation to the second position.
---@param newPosition MapPosition
---@param basePosition MapPosition
---@return MapPosition
Utils.GetOffsetForPositionFromPosition = function(newPosition, basePosition)
    return {x = newPosition.x - basePosition.x, y = newPosition.y - basePosition.y}
end

--- Get a direction heading from a start point to an end point that is a on an exact cardinal direction.
---@param startPos MapPosition
---@param endPos MapPosition
---@return defines.direction|int @ Returns -1 if the startPos and endPos are the same. Returns -2 if the positions not on a cardinal direction difference.
Utils.GetCardinalDirectionHeadingToPosition = function(startPos, endPos)
    if startPos.x == endPos.x then
        if startPos.y > endPos.y then
            return 0
        elseif startPos.y < endPos.y then
            return 4
        else
            return -1
        end
    elseif startPos.y == endPos.y then
        if startPos.x > endPos.x then
            return 6
        elseif startPos.x < endPos.x then
            return 2
        else
            return -1
        end
    else
        return -2
    end
end

---@param position MapPosition
---@param boundingBox BoundingBox
---@param safeTiling? boolean|null @ If enabled the boundingbox can be tiled without risk of an entity on the border being in 2 result sets, i.e. for use on each chunk.
---@return boolean
Utils.IsPositionInBoundingBox = function(position, boundingBox, safeTiling)
    if safeTiling == nil or not safeTiling then
        if position.x >= boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y >= boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    else
        if position.x > boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y > boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    end
end

--- Returns the item name for the provided entity.
---@param entity LuaEntity
---@return string
Utils.GetEntityReturnedToInventoryName = function(entity)
    if entity.prototype.mineable_properties ~= nil and entity.prototype.mineable_properties.products ~= nil and #entity.prototype.mineable_properties.products > 0 then
        return entity.prototype.mineable_properties.products[1].name
    else
        return entity.name
    end
end

--- Makes a list of the input table's keys in their current order.
---@param aTable table
---@return StringOrNumber[]
Utils.TableKeyToArray = function(aTable)
    local newArray = {}
    for key in pairs(aTable) do
        table.insert(newArray, key)
    end
    return newArray
end

--- Makes a comma seperated text string from a table's keys. Includes spaces after each comma.
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.
---@return string
Utils.TableKeyToCommaString = function(aTable)
    local newString
    if Utils.IsTableEmpty(aTable) then
        return ""
    end
    for key in pairs(aTable) do
        if newString == nil then
            newString = tostring(key)
        else
            newString = newString .. ", " .. tostring(key)
        end
    end
    return newString
end

--- Makes a comma seperated text string from a table's values. Includes spaces after each comma.
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.
---@return string
Utils.TableValueToCommaString = function(aTable)
    local newString
    if Utils.IsTableEmpty(aTable) then
        return ""
    end
    for _, value in pairs(aTable) do
        if newString == nil then
            newString = tostring(value)
        else
            newString = newString .. ", " .. tostring(value)
        end
    end
    return newString
end

--- Makes a numbered text string from a table's keys with the keys wrapped in single quotes.
---
--- i.e. 1: 'firstKey', 2: 'secondKey'
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.t
---@return string
Utils.TableKeyToNumberedListString = function(aTable)
    local newString
    if Utils.IsTableEmpty(aTable) then
        return ""
    end
    local count = 1
    for key in pairs(aTable) do
        if newString == nil then
            newString = count .. ": '" .. tostring(key) .. "'"
        else
            newString = newString .. ", " .. count .. ": '" .. tostring(key) .. "'"
        end
        count = count + 1
    end
    return newString
end

--- Makes a numbered text string from a table's values with the values wrapped in single quotes.
---
--- i.e. 1: 'firstValue', 2: 'secondValue'
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.t
---@return string
Utils.TableValueToNumberedListString = function(aTable)
    local newString
    if Utils.IsTableEmpty(aTable) then
        return ""
    end
    local count = 1
    for _, value in pairs(aTable) do
        if newString == nil then
            newString = count .. ": '" .. tostring(value) .. "'"
        else
            newString = newString .. ", " .. count .. ": '" .. tostring(value) .. "'"
        end
    end
    return newString
end

-- Stringify a table in to a JSON text string. Options to make it pretty printable.
---@param targetTable table
---@param name? string|null @ If provided will appear as a "name:JSONData" output.
---@param singleLineOutput? boolean|null @ If provided and true removes all lines and spacing from the output.
---@return string
Utils.TableContentsToJSON = function(targetTable, name, singleLineOutput)
    singleLineOutput = singleLineOutput or false
    local tablesLogged = {}
    return Utils._TableContentsToJSON(targetTable, name, singleLineOutput, tablesLogged)
end
Utils._TableContentsToJSON = function(targetTable, name, singleLineOutput, tablesLogged, indent, stopTraversing)
    local newLineCharacter = "\r\n"
    indent = indent or 1
    local indentstring = string_rep(" ", (indent * 4))
    if singleLineOutput then
        newLineCharacter = ""
        indentstring = ""
    end
    tablesLogged[targetTable] = "logged"
    local table_contents = ""
    if Utils.GetTableNonNilLength(targetTable) > 0 then
        for k, v in pairs(targetTable) do
            local key, value
            if type(k) == "string" or type(k) == "number" or type(k) == "boolean" then -- keys are always strings
                key = '"' .. tostring(k) .. '"'
            elseif type(k) == "nil" then
                key = '"nil"'
            elseif type(k) == "table" then
                if stopTraversing == true then
                    key = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing = nil
                    if tablesLogged[k] ~= nil then
                        subStopTraversing = true
                    end
                    key = "{" .. newLineCharacter .. Utils._TableContentsToJSON(k, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(k) == "function" then
                key = '"' .. tostring(k) .. '"'
            else
                key = '"unhandled type: ' .. type(k) .. '"'
            end
            if type(v) == "string" then
                value = '"' .. tostring(v) .. '"'
            elseif type(v) == "number" or type(v) == "boolean" then
                value = tostring(v)
            elseif type(v) == "nil" then
                value = '"nil"'
            elseif type(v) == "table" then
                if stopTraversing == true then
                    value = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing = nil
                    if tablesLogged[v] ~= nil then
                        subStopTraversing = true
                    end
                    value = "{" .. newLineCharacter .. Utils._TableContentsToJSON(v, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(v) == "function" then
                value = '"' .. tostring(v) .. '"'
            else
                value = '"unhandled type: ' .. type(v) .. '"'
            end
            if table_contents ~= "" then
                table_contents = table_contents .. "," .. newLineCharacter
            end
            table_contents = table_contents .. indentstring .. tostring(key) .. ":" .. tostring(value)
        end
    else
        table_contents = indentstring .. ""
    end
    if indent == 1 then
        local resultString = ""
        if name ~= nil then
            resultString = '"' .. name .. '":'
        end
        resultString = resultString .. "{" .. newLineCharacter .. table_contents .. newLineCharacter .. "}"
        return resultString
    else
        return table_contents
    end
end

--- Makes a string of a position.
---@param position MapPosition
---@return string
Utils.FormatPositionToString = function(position)
    return position.x .. "," .. position.y
end

--- Makes a string of the surface Id and position to allow easy table lookup.
---@param surfaceId uint
---@param positionTable MapPosition
---@return SurfacePositionString
Utils.FormatSurfacePositionToString = function(surfaceId, positionTable)
    return surfaceId .. "_" .. positionTable.x .. "," .. positionTable.y
end

--- Backwards converts a SurfacePositionString to usable data. This is ineffecient and should only be used for debugging.
---@param surfacePositionString SurfacePositionString
---@return uint surfaceIndex
---@return MapPosition position
Utils.SurfacePositionStringToSurfaceAndPosition = function(surfacePositionString)
    local underscoreIndex = string_find(surfacePositionString, "_")
    local surfaceId = tonumber(string_sub(surfacePositionString, 1, underscoreIndex - 1))
    local commaIndex = string_find(surfacePositionString, ",")
    local positionX = tonumber(string_sub(surfacePositionString, underscoreIndex + 1, commaIndex - 1))
    local positionY = tonumber(string_sub(surfacePositionString, commaIndex + 1, string_len(surfacePositionString)))
    return surfaceId, {x = positionX, y = positionY}
end

---@param theTable table
---@param value StringOrNumber
---@param returnMultipleResults? boolean|null @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|null @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @ table of keys.
Utils.GetTableKeyWithValue = function(theTable, value, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, v in pairs(theTable) do
        if not isValueAList then
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults? boolean|null @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|null @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @ table of keys.
Utils.GetTableKeyWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, innerTable in pairs(theTable) do
        if not isValueAList then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults? boolean|null @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|null @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return table[] @ table of values, which must be a table to have an inner key/value.
Utils.GetTableValueWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local valuesFound = {}
    for _, innerTable in pairs(theTable) do
        if not isValueAList then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return innerTable
                end
                table.insert(valuesFound, innerTable)
            end
        else
            for _, valueInList in pairs(innerValue) do
                if innerTable[innerKey] ~= nil and innerTable[innerKey] == valueInList then
                    if not returnMultipleResults then
                        return innerTable
                    end
                    table.insert(valuesFound, innerTable)
                end
            end
        end
    end
    return valuesFound
end

Utils.TableValuesToKey = function(tableWithValues)
    if tableWithValues == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(tableWithValues) do
        newTable[value] = value
    end
    return newTable
end

Utils.TableInnerValueToKey = function(refTable, innerValueAttributeName)
    if refTable == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(refTable) do
        newTable[value[innerValueAttributeName]] = value
    end
    return newTable
end

Utils.GetRandomFloatInRange = function(lower, upper)
    return lower + math_random() * (upper - lower)
end

Utils.WasCreativeModeInstantDeconstructionUsed = function(event)
    if event.instant_deconstruction ~= nil and event.instant_deconstruction == true then
        return true
    else
        return false
    end
end

--- Updates the 'chancePropertyName' named attribute of each entry in the referenced `dataSet` table to be proportional of a combined dataSet value of 1.
---
--- The dataset is a table of entries. Each entry has various keys that are used in the calling scope and ignored by this funciton. It also has a key of the name passed in as the chancePropertyName parameter that defines the chance of this result.
---@param dataSet table[] @ The dataSet to be reviewed and updated.
---@param chancePropertyName string @ The attribute name that has the chance value per dataSet entry.
---@param skipFillingEmptyChance? boolean @ Defaults to FALSE. If TRUE then total chance below 1 will not be scaled up, so that nil results can be had in random selection.
---@return table[] @ Same object passed in by reference as dataSet, so technically no return is needed, legacy.
Utils.NormaliseChanceList = function(dataSet, chancePropertyName, skipFillingEmptyChance)
    local totalChance = 0
    for _, v in pairs(dataSet) do
        totalChance = totalChance + v[chancePropertyName]
    end
    local multiplier = 1
    if not skipFillingEmptyChance or (skipFillingEmptyChance and totalChance > 1) then
        multiplier = 1 / totalChance
    end
    for _, v in pairs(dataSet) do
        v[chancePropertyName] = v[chancePropertyName] * multiplier
    end
    return dataSet
end

Utils.GetRandomEntryFromNormalisedDataSet = function(dataSet, chancePropertyName)
    local random = math_random()
    local chanceRangeLow = 0
    local chanceRangeHigh
    for _, v in pairs(dataSet) do
        chanceRangeHigh = chanceRangeLow + v[chancePropertyName]
        if random >= chanceRangeLow and random <= chanceRangeHigh then
            return v
        end
        chanceRangeLow = chanceRangeHigh
    end
    return nil
end

-- called from OnInit
Utils.DisableWinOnRocket = function()
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
end

-- called from OnInit
Utils.ClearSpawnRespawnItems = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_created_items", {})
    remote.call("freeplay", "set_respawn_items", {})
end

-- called from OnInit
---@param distanceTiles uint
Utils.SetStartingMapReveal = function(distanceTiles)
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_chart_distance", distanceTiles)
end

-- called from OnInit
Utils.DisableIntroMessage = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_skip_intro", true)
end

Utils.PadNumberToMinimumDigits = function(input, requiredLength)
    local shortBy = requiredLength - string_len(input)
    for i = 1, shortBy do
        input = "0" .. input
    end
    return input
end

Utils.DisplayNumberPretty = function(number)
    if number == nil then
        return ""
    end
    local formatted = number
    local k
    while true do
        formatted, k = string_gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if (k == 0) then
            break
        end
    end
    return formatted
end

-- display time units: hour, minute, second
Utils.DisplayTimeOfTicks = function(inputTicks, displayLargestTimeUnit, displaySmallestTimeUnit)
    if inputTicks == nil then
        return ""
    end
    local negativeSign = ""
    if inputTicks < 0 then
        negativeSign = "-"
        inputTicks = -inputTicks
    end
    local hours = math_floor(inputTicks / 216000)
    local displayHours = Utils.PadNumberToMinimumDigits(hours, 2)
    inputTicks = inputTicks - (hours * 216000)
    local minutes = math_floor(inputTicks / 3600)
    local displayMinutes = Utils.PadNumberToMinimumDigits(minutes, 2)
    inputTicks = inputTicks - (minutes * 3600)
    local seconds = math_floor(inputTicks / 60)
    local displaySeconds = Utils.PadNumberToMinimumDigits(seconds, 2)

    if displayLargestTimeUnit == nil or displayLargestTimeUnit == "" or displayLargestTimeUnit == "auto" then
        if hours > 0 then
            displayLargestTimeUnit = "hour"
        elseif minutes > 0 then
            displayLargestTimeUnit = "minute"
        else
            displayLargestTimeUnit = "second"
        end
    end
    if not (displayLargestTimeUnit == "hour" or displayLargestTimeUnit == "minute" or displayLargestTimeUnit == "second") then
        error("unrecognised displayLargestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end
    if displaySmallestTimeUnit == nil or displaySmallestTimeUnit == "" or displaySmallestTimeUnit == "auto" then
        displaySmallestTimeUnit = "second"
    end
    if not (displaySmallestTimeUnit == "hour" or displaySmallestTimeUnit == "minute" or displaySmallestTimeUnit == "second") then
        error("unrecognised displaySmallestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end

    local timeUnitIndex = {second = 1, minute = 2, hour = 3}
    local displayLargestTimeUnitIndex = timeUnitIndex[displayLargestTimeUnit]
    local displaySmallestTimeUnitIndex = timeUnitIndex[displaySmallestTimeUnit]
    local timeUnitRange = displayLargestTimeUnitIndex - displaySmallestTimeUnitIndex

    if timeUnitRange == 2 then
        return (negativeSign .. displayHours .. ":" .. displayMinutes .. ":" .. displaySeconds)
    elseif timeUnitRange == 1 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours .. ":" .. displayMinutes)
        else
            return (negativeSign .. displayMinutes .. ":" .. displaySeconds)
        end
    elseif timeUnitRange == 0 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours)
        elseif displayLargestTimeUnit == "minute" then
            return (negativeSign .. displayMinutes)
        else
            return (negativeSign .. displaySeconds)
        end
    else
        error("time unit range is negative in Utils.MakeLocalisedStringDisplayOfTime")
    end
end

-- Doesn't handle mipmaps at all presently. Also ignores any of the extra data in an icons table of "Types/IconData". Think this should just duplicate the target icons table entry.
---@param entityToClone table @ Any entity prototype.
---@param newEntityName string
---@param subgroup string
---@param collisionMask CollisionMask
---@return table @ A simple entity prototype.
Utils.CreatePlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup, collisionMask)
    local clonedIcon = entityToClone.icon
    local clonedIconSize = entityToClone.icon_size
    if clonedIcon == nil then
        clonedIcon = entityToClone.icons[1].icon
        clonedIconSize = entityToClone.icons[1].icon_size
    end
    return {
        type = "simple-entity",
        name = newEntityName,
        subgroup = subgroup,
        order = "zzz",
        icons = {
            {
                icon = clonedIcon,
                icon_size = clonedIconSize
            },
            {
                icon = "__core__/graphics/cancel.png",
                icon_size = 64,
                scale = (clonedIconSize / 64) * 0.5
            }
        },
        flags = entityToClone.flags,
        selection_box = entityToClone.selection_box,
        collision_box = entityToClone.collision_box,
        collision_mask = collisionMask,
        picture = {
            filename = "__core__/graphics/cancel.png",
            height = 64,
            width = 64
        }
    }
end

Utils.CreateLandPlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup)
    subgroup = subgroup or "other"
    return Utils.CreatePlacementTestEntityPrototype(entityToClone, newEntityName, subgroup, {"water-tile", "colliding-with-tiles-only"})
end

Utils.CreateWaterPlacementTestEntityPrototype = function(entityToClone, newEntityName, subgroup)
    subgroup = subgroup or "other"
    return Utils.CreatePlacementTestEntityPrototype(entityToClone, newEntityName, subgroup, {"ground-tile", "colliding-with-tiles-only"})
end

--- Tries to converts a non boolean to a boolean value.
---@param text string|int|boolean @ The input to check.
---@return boolean|null @ If successful converted then the boolean of the value, or nil if not a convertable input.
Utils.ToBoolean = function(text)
    if text == nil then
        return nil
    end
    local textType = type(text)
    if textType == "string" then
        text = string_lower(text)
        if text == "true" then
            return true
        elseif text == "false" then
            return false
        else
            return nil
        end
    elseif textType == "number" then
        if text == 0 then
            return false
        elseif text == 1 then
            return true
        else
            return nil
        end
    elseif textType == "boolean" then
        return text
    else
        return nil
    end
end

Utils.RandomLocationInRadius = function(centrePos, maxRadius, minRadius)
    local angle = math_random(0, 360)
    minRadius = minRadius or 0
    local radiusMultiplier = maxRadius - minRadius
    local distance = minRadius + (math_random() * radiusMultiplier)
    return Utils.GetPositionForAngledDistance(centrePos, distance, angle)
end

Utils.GetPositionForAngledDistance = function(startingPos, distance, angle)
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

---@param startingPos MapPosition
---@param distance number
---@param orientation RealOrientation
---@return MapPosition
Utils.GetPositionForOrientationDistance = function(startingPos, distance, orientation)
    local angle = orientation * 360
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

--- Gets the position for a distance along a line from a starting positon towards a target position.
---@param startingPos MapPosition
---@param targetPos MapPosition
---@param distance number
---@return MapPosition
Utils.GetPositionForDistanceBetween2Points = function(startingPos, targetPos, distance)
    local angleRad = -math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x) + 1.5707963267949 -- Static value is to re-align it from east to north as 0 value.
    -- equivilent to: math.rad(math.deg(-math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x)) + 90)

    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

Utils.FindWhereLineCrossesCircle = function(radius, slope, yIntercept)
    local centerPos = {x = 0, y = 0}
    local A = 1 + slope * slope
    local B = -2 * centerPos.x + 2 * slope * yIntercept - 2 * centerPos.y * slope
    local C = centerPos.x * centerPos.x + yIntercept * yIntercept + centerPos.y * centerPos.y - 2 * centerPos.y * yIntercept - radius * radius
    local delta = B * B - 4 * A * C

    if delta < 0 then
        return nil, nil
    else
        local x1 = (-B + math_sqrt(delta)) / (2 * A)

        local x2 = (-B - math_sqrt(delta)) / (2 * A)

        local y1 = slope * x1 + yIntercept

        local y2 = slope * x2 + yIntercept

        local pos1 = {x = x1, y = y1}
        local pos2 = {x = x2, y = y2}
        if pos1 == pos2 then
            return pos1, nil
        else
            return pos1, pos2
        end
    end
end

Utils.IsPositionWithinCircled = function(circleCenter, radius, position)
    local deltaX = math_abs(position.x - circleCenter.x)
    local deltaY = math_abs(position.y - circleCenter.y)
    if deltaX + deltaY <= radius then
        return true
    elseif deltaX > radius then
        return false
    elseif deltaY > radius then
        return false
    elseif deltaX ^ 2 + deltaY ^ 2 <= radius ^ 2 then
        return true
    else
        return false
    end
end

Utils.GetValueAndUnitFromString = function(text)
    return string_match(text, "%d+%.?%d*"), string_match(text, "%a+")
end

--- Moves the full Lua Item Stacks from the source to the target inventories if possible. So handles items with data and other complicated items. --- Updates the source inventory counts in inventory object.
---@param sourceInventory LuaInventory
---@param targetInventory LuaInventory
---@param dropUnmovedOnGround? boolean|null @ If TRUE then ALL items not moved are dropped on the ground (regardless of ratioToMove value). If FALSE then unmoved items are left in the source inventory. If not provided then defaults to FALSE.
---@param ratioToMove? double|null @ Ratio of the item count to try and move. Float number from 0 to 1. If not provided it defaults to 1. Number of items moved is rounded up.
---@return boolean everythingMoved @ If all items were moved successfully in to the targetInventory. Ignores if things were dumped on the ground.
---@return boolean anythingMoved @ If any items were moved successfully in to the targetInventory. Ignores if things were dumped on the ground.
Utils.TryMoveInventoriesLuaItemStacks = function(sourceInventory, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Set default values.
    ---@typelist LuaEntity, boolean, boolean
    local sourceOwner, itemAllMoved, anythingMoved = nil, true, false
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end

    -- Clamp ratio to between 0 and 1.
    ratioToMove = math_min(math_max(ratioToMove, 0), 1)

    -- Handle simple returns that don't require item moving.
    if sourceInventory == nil or sourceInventory.is_empty() then
        return true, false
    end
    if ratioToMove == 0 then
        return false, false
    end

    --Do the actual item moving.
    for index = 1, #sourceInventory do
        local itemStack = sourceInventory[index] ---@type LuaItemStack
        if itemStack.valid_for_read then
            -- Work out how many to try and move.
            local itemStack_origionalCount = itemStack.count
            local maxToMoveCount = math_ceil(itemStack_origionalCount * ratioToMove)

            -- Have to set the source count to be the max amount to move, try the insert, and then set the source count back to the required final result. As this is a game object and so I can't just clone it to try the insert with without losing its associated data.
            itemStack.count = maxToMoveCount
            local movedCount = targetInventory.insert(itemStack)
            itemStack.count = itemStack_origionalCount - movedCount

            -- Check what was moved and any next steps.
            if movedCount > 0 then
                anythingMoved = true
            end
            if movedCount < maxToMoveCount then
                itemAllMoved = false
                if dropUnmovedOnGround then
                    sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                    sourceOwner.surface.spill_item_stack(sourceOwner.position, itemStack, true, sourceOwner.force, false)
                    itemStack.count = 0
                end
            end
        end
    end

    return itemAllMoved, anythingMoved
end

--- Try and move all equipment from a grid to an inventory.
---
--- Can only move the item name and count via API, Factorio doesn't support putting equipment objects in an inventory. Updates the passed in grid object.
---@param sourceGrid LuaEquipmentGrid
---@param targetInventory LuaInventory
---@param dropUnmovedOnGround? boolean|null @ If TRUE then ALL items not moved are dropped on the ground. If FALSE then unmoved items are left in the source inventory. If not provided then defaults to FALSE.
---@return boolean everythingMoved @ If all items were moved successfully or not.
Utils.TryTakeGridsItems = function(sourceGrid, targetInventory, dropUnmovedOnGround)
    -- Set default values.
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end

    -- Handle simple returns that don't require item moving.
    if sourceGrid == nil then
        return
    end

    --Do the actual item moving.
    for _, equipment in pairs(sourceGrid.equipment) do
        local moved = targetInventory.insert({name = equipment.name, count = 1})
        if moved > 0 then
            sourceGrid.take({equipment = equipment})
        end
        if moved == 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = equipment.name, count = 1}, true, sourceOwner.force, false)
                sourceGrid.take({equipment = equipment})
            end
        end
    end
    return itemAllMoved
end

--- Just takes a list of item names and counts that you get from the inventory.get_contents(). Updates the passed in contents object.
---@param contents table<string, uint> @ A table of item names to counts, as returned by LuaInventory.get_contents().
---@param targetInventory LuaInventory
---@param dropUnmovedOnGround? boolean|null @ If TRUE then ALL items not moved are dropped on the ground. If FALSE then unmoved items are left in the source inventory. If not provided then defaults to FALSE.
---@param ratioToMove? double|null @ Ratio of the item count to try and move. Float number from 0 to 1. If not provided it defaults to 1. Number of items moved is rounded up.
---@return boolean  everythingMoved @ If all items were moved successfully or not.
Utils.TryInsertInventoryContents = function(contents, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Set default values.
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end

    -- Clamp ratio to between 0 and 1.
    ratioToMove = math_min(math_max(ratioToMove, 0), 1)

    -- Handle simple returns that don't require item moving.
    if Utils.IsTableEmpty(contents) then
        return
    end
    if ratioToMove == 0 then
        return false, false
    end

    --Do the actual item moving.
    for name, count in pairs(contents) do
        local toMove = math_ceil(count * ratioToMove)
        local moved = targetInventory.insert({name = name, count = toMove})
        local remaining = count - moved
        if moved > 0 then
            contents[name] = remaining
        end
        if remaining > 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = name, count = remaining}, true, sourceOwner.force, false)
                contents[name] = 0
            end
        end
    end
    return itemAllMoved
end

--- Takes an array of SimpleItemStack and inserts them in to an inventory. Updates each SimpleItemStack passed in with the new count.
---@param simpleItemStacks SimpleItemStack[]
---@param targetInventory LuaInventory
---@param dropUnmovedOnGround? boolean|null @ If TRUE then ALL items not moved are dropped on the ground. If FALSE then unmoved items are left in the source inventory. If not provided then defaults to FALSE.
---@param ratioToMove? double|null @ Ratio of the item count to try and move. Float number from 0 to 1. If not provided it defaults to 1. Number of items moved is rounded up.
---@return boolean everythingMoved @ If all items were moved successfully or not.
Utils.TryInsertSimpleItems = function(simpleItemStacks, targetInventory, dropUnmovedOnGround, ratioToMove)
    -- Set default values.
    local sourceOwner, itemAllMoved = nil, true
    if dropUnmovedOnGround == nil then
        dropUnmovedOnGround = false
    end
    if ratioToMove == nil then
        ratioToMove = 1
    end

    -- Clamp ratio to between 0 and 1.
    ratioToMove = math_min(math_max(ratioToMove, 0), 1)

    -- Handle simple returns that don't require item moving.
    if simpleItemStacks == nil or #simpleItemStacks == 0 then
        return
    end
    if ratioToMove == 0 then
        return false, false
    end

    --Do the actual item moving.
    for index, simpleItemStack in pairs(simpleItemStacks) do
        local toMove = math_ceil(simpleItemStack.count * ratioToMove)
        local moved = targetInventory.insert({name = simpleItemStack.name, count = toMove, health = simpleItemStack.health, ammo = simpleItemStack.ammo})
        local remaining = simpleItemStack.count - moved
        if moved > 0 then
            simpleItemStacks[index].count = remaining
        end
        if remaining > 0 then
            itemAllMoved = false
            if dropUnmovedOnGround then
                sourceOwner = sourceOwner or targetInventory.entity_owner or targetInventory.player_owner
                sourceOwner.surface.spill_item_stack(sourceOwner.position, {name = simpleItemStack.name, count = remaining}, true, sourceOwner.force, false)
                simpleItemStacks[index].count = 0
            end
        end
    end
    return itemAllMoved
end

--- Get the builder/miner player/construction robot or nil if script placed.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive|on_pre_player_mined_item|on_robot_pre_mined
---@return EntityActioner placer
Utils.GetActionerFromEvent = function(event)
    if event.robot ~= nil then
        -- Construction robots
        return event.robot
    elseif event.player_index ~= nil then
        -- Player
        return game.get_player(event.player_index)
    else
        -- Script placed
        return nil
    end
end

--- Get the inventory of the builder (player, bot, or god controller).
---@param builder EntityActioner
Utils.GetBuilderInventory = function(builder)
    if builder.is_player() then
        return builder.get_main_inventory()
    elseif builder.type ~= nil and builder.type == "construction-robot" then
        return builder.get_inventory(defines.inventory.robot_cargo)
    else
        return builder
    end
end

--- Returns either tha player or force for robots from the EntityActioner. If script then returns neither.
---
--- Useful for passing in to rendering player/force filters or for returning items to them.
---@param actioner EntityActioner
---@return LuaPlayer|null
---@return LuaForce|null
Utils.GetPlayerForceFromActioner = function(actioner)
    if actioner == nil then
        -- Is a script.
        return nil, nil
    elseif actioner.is_player() then
        -- Is a player.
        return actioner, nil
    else
        -- Is construction bot.
        return nil, actioner.force
    end
end

---@param repeat_count? int|null @ Defaults to 1 if not provided
---@return Sprite
Utils.EmptyRotatedSprite = function(repeat_count)
    return {
        direction_count = 1,
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1,
        repeat_count = repeat_count or 1
    }
end

--[[
    This function will set trackingTable to have the below entry. Query these keys in calling function:
        trackingTable {
            fuelName = STRING,
            fuelCount = INT,
            fuelValue = INT,
        }
--]]
---@param trackingTable table @ Reference to an existing table that the function will populate.
---@param itemName string
---@param itemCount uint
---@return boolean|null @ Returns true when the fuel is a new best and false when its not. Returns nil if the item isn't a fuel type.
Utils.TrackBestFuelCount = function(trackingTable, itemName, itemCount)
    local itemPrototype = game.item_prototypes[itemName]
    local fuelValue = itemPrototype.fuel_value
    if fuelValue == nil then
        return nil
    end
    if trackingTable.fuelValue == nil or fuelValue > trackingTable.fuelValue then
        trackingTable.fuelName = itemName
        trackingTable.fuelCount = itemCount
        trackingTable.fuelValue = fuelValue
        return true
    end
    if trackingTable.fuelName == itemName and itemCount > trackingTable.fuelCount then
        trackingTable.fuelCount = itemCount
        return true
    end
    return false
end

--[[
    Takes tables of the various recipe types (normal, expensive and ingredients) and makes the required recipe prototypes from them. Only makes the version if the ingredientsList includes the type. So supplying just energyLists types doesn't make new versions.
    ingredientLists is a table with optional tables for "normal", "expensive" and "ingredients" tables within them. Often generatered by Utils.GetRecipeIngredientsAddedTogeather().
    energyLists is a table with optional keys for "normal", "expensive" and "ingredients". The value of the keys is the energy_required value.
]]
Utils.MakeRecipePrototype = function(recipeName, resultItemName, enabled, ingredientLists, energyLists)
    local recipePrototype = {
        type = "recipe",
        name = recipeName
    }
    if ingredientLists.ingredients ~= nil then
        recipePrototype.energy_required = energyLists.ingredients
        recipePrototype.enabled = enabled
        recipePrototype.result = resultItemName
        recipePrototype.ingredients = ingredientLists.ingredients
    end
    if ingredientLists.normal ~= nil then
        recipePrototype.normal = {
            energy_required = energyLists.normal or energyLists.ingredients,
            enabled = enabled,
            result = resultItemName,
            ingredients = ingredientLists.normal
        }
    end
    if ingredientLists.expensive ~= nil then
        recipePrototype.expensive = {
            energy_required = energyLists.expensive or energyLists.ingredients,
            enabled = enabled,
            result = resultItemName,
            ingredients = ingredientLists.expensive
        }
    end
    return recipePrototype
end

--[[
    Is for handling a mix of recipes and ingredient list. Supports recipe ingredients, normal and expensive.
    Returns the widest range of types fed in as a table of result tables (nil for non required returns): {ingredients, normal, expensive}
    Takes a table (list) of entries. Each entry is a table (list) of recipe/ingredients, handling type and ratioMultiplier (optional), i.e. {{ingredients1, "add"}, {recipe1, "add", 0.5}, {ingredients2, "highest", 2}}
    handling types:
        - add: adds the ingredients from a list to the total
        - subtract: removes the ingredients in this list from the total
        - highest: just takes the highest counts of each ingredients across the 2 lists.
    ratioMultiplier item counts for recipes are rounded up. Defaults to ration of 1 if not provided.
]]
Utils.GetRecipeIngredientsAddedTogeather = function(recipeIngredientHandlingTables)
    local ingredientsTable, ingredientTypes = {}, {}
    for _, recipeIngredientHandlingTable in pairs(recipeIngredientHandlingTables) do
        if recipeIngredientHandlingTable[1].normal ~= nil then
            ingredientTypes.normal = true
        end
        if recipeIngredientHandlingTable[1].expensive ~= nil then
            ingredientTypes.expensive = true
        end
    end
    if Utils.IsTableEmpty(ingredientTypes) then
        ingredientTypes.ingredients = true
    end

    for ingredientType in pairs(ingredientTypes) do
        local ingredientsList = {}
        for _, recipeIngredientHandlingTable in pairs(recipeIngredientHandlingTables) do
            local ingredients  --try to find the correct ingredients for our desired type, if not found just try all of them to find one to use. Assume its a simple ingredient list last.
            if recipeIngredientHandlingTable[1][ingredientType] ~= nil then
                ingredients = recipeIngredientHandlingTable[1][ingredientType].ingredients or recipeIngredientHandlingTable[1][ingredientType]
            elseif recipeIngredientHandlingTable[1]["ingredients"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["ingredients"]
            elseif recipeIngredientHandlingTable[1]["normal"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["normal"].ingredients
            elseif recipeIngredientHandlingTable[1]["expensive"] ~= nil then
                ingredients = recipeIngredientHandlingTable[1]["expensive"].ingredients
            else
                ingredients = recipeIngredientHandlingTable[1]
            end
            local handling, ratioMultiplier = recipeIngredientHandlingTable[2], recipeIngredientHandlingTable[3]
            if ratioMultiplier == nil then
                ratioMultiplier = 1
            end
            for _, details in pairs(ingredients) do
                local name, count = details[1] or details.name, math_ceil((details[2] or details.amount) * ratioMultiplier)
                if handling == "add" then
                    ingredientsList[name] = (ingredientsList[name] or 0) + count
                elseif handling == "subtract" then
                    if ingredientsList[name] ~= nil then
                        ingredientsList[name] = ingredientsList[name] - count
                    end
                elseif handling == "highest" then
                    if count > (ingredientsList[name] or 0) then
                        ingredientsList[name] = count
                    end
                end
            end
        end
        ingredientsTable[ingredientType] = {}
        for name, count in pairs(ingredientsList) do
            if ingredientsList[name] > 0 then
                table.insert(ingredientsTable[ingredientType], {name, count})
            end
        end
    end
    return ingredientsTable
end

--[[
    Returns the attributeName for the recipeCostType if available, otherwise the inline ingredients version.
    recipeType defaults to the no cost type if not supplied. Values are: "ingredients", "normal" and "expensive".
--]]
Utils.GetRecipeAttribute = function(recipe, attributeName, recipeCostType, defaultValue)
    recipeCostType = recipeCostType or "ingredients"
    if recipeCostType == "ingredients" and recipe[attributeName] ~= nil then
        return recipe[attributeName]
    elseif recipe[recipeCostType] ~= nil and recipe[recipeCostType][attributeName] ~= nil then
        return recipe[recipeCostType][attributeName]
    end

    if recipe[attributeName] ~= nil then
        return recipe[attributeName]
    elseif recipe["normal"] ~= nil and recipe["normal"][attributeName] ~= nil then
        return recipe["normal"][attributeName]
    elseif recipe["expensive"] ~= nil and recipe["expensive"][attributeName] ~= nil then
        return recipe["expensive"][attributeName]
    end

    return defaultValue -- may well be nil
end

Utils.DoesRecipeResultsIncludeItemName = function(recipePrototype, itemName)
    for _, recipeBase in pairs({recipePrototype, recipePrototype.normal, recipePrototype.expensive}) do
        if recipeBase ~= nil then
            if recipeBase.result ~= nil and recipeBase.result == itemName then
                return true
            elseif recipeBase.results ~= nil and #Utils.GetTableKeyWithInnerKeyValue(recipeBase.results, "name", itemName) > 0 then
                return true
            end
        end
    end
    return false
end

--[[
    From the provided technology list remove all provided recipes from being unlocked that create an item that can place a given entity prototype.
    Returns a table of the technologies affected or a blank table if no technologies are affected.
]]
Utils.RemoveEntitiesRecipesFromTechnologies = function(entityPrototype, recipes, technolgies)
    local technologiesChanged = {}
    local placedByItemName
    if entityPrototype.minable ~= nil and entityPrototype.minable.result ~= nil then
        placedByItemName = entityPrototype.minable.result
    else
        return technologiesChanged
    end
    for _, recipePrototype in pairs(recipes) do
        if Utils.DoesRecipeResultsIncludeItemName(recipePrototype, placedByItemName) then
            recipePrototype.enabled = false
            for _, technologyPrototype in pairs(technolgies) do
                if technologyPrototype.effects ~= nil then
                    for effectIndex, effect in pairs(technologyPrototype.effects) do
                        if effect.type == "unlock-recipe" and effect.recipe ~= nil and effect.recipe == recipePrototype.name then
                            table.remove(technologyPrototype.effects, effectIndex)
                            table.insert(technologiesChanged, technologyPrototype)
                        end
                    end
                end
            end
        end
    end
    return technologiesChanged
end

--- Split a string on the specified characters. The splitting characters aren't included in the output. The results are trimmed of blank spaces.
---@param text string
---@param splitCharacters string
---@param returnAsKey? boolean|null @ If nil or false then an array of strings are returned. If true then a table with the string as the keys and the value as boolean true are returned.
---@return string[]|table<string, True>
Utils.SplitStringOnCharacters = function(text, splitCharacters, returnAsKey)
    local list = {}
    local results = text:gmatch("[^" .. splitCharacters .. "]*")
    for phrase in results do
        -- Trim spaces from the phrase text. Code from Utils.StringTrim()
        phrase = string_match(phrase, "^()%s*$") and "" or string_match(phrase, "^%s*(.*%S)")

        if phrase ~= nil and phrase ~= "" then
            if returnAsKey ~= nil and returnAsKey == true then
                list[phrase] = true
            else
                table.insert(list, phrase)
            end
        end
    end
    return list
end

-- trim6 from http://lua-users.org/wiki/StringTrim
Utils.StringTrim = function(text)
    return string_match(text, "^()%s*$") and "" or string_match(text, "^%s*(.*%S)")
end

-- Kills an entity and handles the optional arguments as Facotrio API doesn't accept nil arguments.
---@param entity LuaEntity
---@param killerForce LuaForce
---@param killerCauseEntity? LuaEntity|null
Utils.EntityDie = function(entity, killerForce, killerCauseEntity)
    if killerCauseEntity ~= nil then
        entity.die(killerForce, killerCauseEntity)
    else
        entity.die(killerForce)
    end
end

--- Returns a luaObject if its valid, else nil. Convientent for inline usage when rarely called.
---
--- Should be done locally if called frequently.
---@param luaObject LuaBaseClass
---@return LuaBaseClass|null
Utils.ReturnValidLuaObjectOrNil = function(luaObject)
    if luaObject == nil or not luaObject.valid then
        return nil
    else
        return luaObject
    end
end

--- Gets the carriage at the head (leading) the train in its current direction.
---
--- Should be done locally if called frequently.
---@param train LuaTrain
---@param isFrontStockLeading boolean @ If the trains speed is > 0 then pass in true, if speed < 0 then pass in false.
---@return LuaEntity
Utils.GetLeadingCarriageOfTrain = function(train, isFrontStockLeading)
    if isFrontStockLeading then
        return train.front_stock
    else
        return train.back_stock
    end
end

--- Checks the locomtive for its current fuel and returns it's prototype. Checks fuel inventories if nothing is currently burning.
---@param locomotive LuaEntity
---@return LuaItemPrototype|null currentFuelPrototype @ Will be nil if there's no current fuel in the locomotive.
Utils.GetLocomotivesCurrentFuelPrototype = function(locomotive)
    local loco_burner = locomotive.burner

    -- Check any currently burning fuel inventory first.
    local currentFuelItem = loco_burner.currently_burning
    if currentFuelItem ~= nil then
        return currentFuelItem
    end

    -- Check the fuel inventories as this will be burnt next.
    local burner_inventory = loco_burner.inventory
    local currentFuelStack
    for i = 1, #burner_inventory do
        currentFuelStack = burner_inventory[i] ---@type LuaItemStack
        if currentFuelStack ~= nil and currentFuelStack.valid_for_read then
            return currentFuelStack.prototype
        end
    end

    -- No fuel found.
    return nil
end

--- Gets the length of a rail entity.
---@param entityType string
---@param entityDirection defines.direction
---@return double railLength
Utils.GetRailEntityLength = function(entityType, entityDirection)
    if entityType == "straight-rail" then
        if entityDirection == defines.direction.north or entityDirection == defines.direction.east or entityDirection == defines.direction.south or entityDirection == defines.direction.west then
            -- Cardinal direction rail.
            return 2
        else
            -- Diagonal rail.
            return 1.415
        end
    else
        -- Curved rail.
        -- Old value worked out somehow was: 7.842081225095, but new value is based on a train's path length reported in the game.
        return 7.84
    end
end

---@class Utils_TrainSpeedCalculationData @ Data the Utils functions need to calculate and estimate its future speed, time to cover distance, etc.
---@field trainWeight double @ The total weight of the train.
---@field trainFrictionForce double @ The total friction force of the train.
---@field trainWeightedFrictionForce double @ The train's friction force divided by train weight.
---@field locomotiveFuelAccelerationPower double @ The max acceleration power per tick the train can add for the fuel type on last data update.
---@field locomotiveAccelerationPower double @ The max raw acceleration power per tick the train can add (ignoring fuel bonus).
---@field trainAirResistanceReductionMultiplier double @ The air resistance of the train (lead carriage in current direction).
---@field maxSpeed double @ The max speed the train can achieve on current fuel type.
---@field trainRawBrakingForce double @ The total braking force of the train ignoring any force bonus percentage from LuaForce.train_braking_force_bonus.
---@field forwardFacingLocoCount uint @ The number of locomotives facing forwards. Used when recalcultaing locomotiveFuelAccelerationPower.

---@class Utils_TrainCarriageData @ Data array of cached details on a train's carriages. Allows only obtaining required data once per carriage. Only populate carriage data when required.
---@field entity LuaEntity @ Minimum this must be populated and the functions will populate other details if they are requried during each function's operation.
---@field prototypeType? string|null
---@field prototypeName? string|null
---@field faceingFrontOfTrain? boolean|null @ If the carriage is facing the front of the train. If true then carriage speed and orientation is the same as the train's.

--- Get the data other Utils functions need for calculating and estimating; a trains future speed, time to cover distance, etc.
---
--- This is only accurate while the train is heading in the same direction as when this data was gathered and requires the train to be moving.
---
--- Assumes all forward facing locomotives have the same fuel as the first one found. If no fuel is found in any locomotive then a default value of 1 is used and the return "noFuelFound" will indicate this.
---
--- Either trainCarriagesDataArray or train_carriages needs to be provided.
---@param train LuaTrain
---@param train_speed double @ Must not be 0 (stationary train).
---@param trainCarriagesDataArray? Utils_TrainCarriageData[]|null @ An array of carriage data for this train in the Utils_TrainCarriageData format in the same order as the train's internal carriage order. If provided and it doesn't include the required attribute data on the carriages it will be obtained and added in to the cache table.
---@param train_carriages? LuaEntity[]|null @ If trainCarriagesDataArray isn't provided then the train's carriage array will need to be provided. The required attribute data on each carriage will have to be obtainedm, but not cached or passed out.
---@return Utils_TrainSpeedCalculationData trainSpeedCalculationData
---@return boolean noFuelFound @ TRUE if no fuel was found in any forward moving locomotive. Generally FALSE is returned when all is normal.
Utils.GetTrainSpeedCalculationData = function(train, train_speed, trainCarriagesDataArray, train_carriages)
    if train_speed == 0 then
        -- We can't work out what way is forward for counting locomotives that can assist with acceleration.
        error("Utils.GetTrainSpeedCalculationData() doesn't work for 0 speed train")
    end

    -- If trainCarriagesDataArray is nil we'll build it up as we go from the train_carriages array. This means that the functions logic only has 1 data structure to worry about. The trainCarriagesDataArray isn't passed out as a return and so while we build up the cache object it is dropped at the end of the function.
    if trainCarriagesDataArray == nil then
        trainCarriagesDataArray = {}
        for i, entity in pairs(train_carriages) do
            trainCarriagesDataArray[i] = {entity = entity}
        end
    end

    local trainWeight = train.weight
    local trainFrictionForce, forwardFacingLocoCount, fuelAccelerationBonus, trainRawBrakingForce, trainAirResistanceReductionMultiplier = 0, 0, nil, 0, nil
    local trainMovingForwards = train_speed > 0

    -- Work out which way to iterate down the train's carriage array. Starting with the lead carriage.
    local minCarriageIndex, maxCarriageIndex, carriageIterator
    local carriageCount = #trainCarriagesDataArray
    if trainMovingForwards then
        minCarriageIndex, maxCarriageIndex, carriageIterator = 1, carriageCount, 1
    elseif not trainMovingForwards then
        minCarriageIndex, maxCarriageIndex, carriageIterator = carriageCount, 1, -1
    end

    local firstCarriage = true
    ---@typelist Utils_TrainCarriageData, string, string, boolean
    local carriageCachedData, carriage_type, carriage_name, carriage_faceingFrontOfTrain
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        carriageCachedData = trainCarriagesDataArray[currentSourceTrainCarriageIndex]
        carriage_type = carriageCachedData.prototypeType
        carriage_name = carriageCachedData.prototypeName
        if carriage_type == nil then
            -- Data not known so obtain and cache.
            carriage_type = carriageCachedData.entity.type
            carriageCachedData.prototypeType = carriage_type
        end
        if carriage_name == nil then
            -- Data not known so obtain and cache.
            carriage_name = carriageCachedData.entity.name
            carriageCachedData.prototypeName = carriage_name
        end

        trainFrictionForce = trainFrictionForce + PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, carriage_name, "friction_force")
        trainRawBrakingForce = trainRawBrakingForce + PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, carriage_name, "braking_force")

        if firstCarriage then
            firstCarriage = false
            trainAirResistanceReductionMultiplier = 1 - (PrototypeAttributes.GetAttribute(PrototypeAttributes.PrototypeTypes.entity, carriage_name, "air_resistance") / (trainWeight / 1000))
        end

        if carriage_type == "locomotive" then
            carriage_faceingFrontOfTrain = carriageCachedData.faceingFrontOfTrain
            if carriage_faceingFrontOfTrain == nil then
                -- Data not known so obtain and cache.
                if carriageCachedData.entity.speed == train_speed then
                    carriage_faceingFrontOfTrain = true
                else
                    carriage_faceingFrontOfTrain = false
                end
                carriageCachedData.faceingFrontOfTrain = carriage_faceingFrontOfTrain
            end

            -- Only process locomotives that are powering the trains movement.
            if trainMovingForwards == carriage_faceingFrontOfTrain then
                -- Count all forward moving loco's. Just assume they all have the same fuel to avoid inspecting each one.
                forwardFacingLocoCount = forwardFacingLocoCount + 1
            end
        end
    end

    -- Record all the data in to the cache object.
    ---@type Utils_TrainSpeedCalculationData
    local trainData = {
        trainWeight = trainWeight,
        trainFrictionForce = trainFrictionForce,
        trainWeightedFrictionForce = (trainFrictionForce / trainWeight),
        -- This assumes all loco's are the same power and have the same fuel. The 10 is for a 600 kW max_power of a vanilla locomotive.
        locomotiveAccelerationPower = 10 * forwardFacingLocoCount / trainWeight,
        trainAirResistanceReductionMultiplier = trainAirResistanceReductionMultiplier,
        forwardFacingLocoCount = forwardFacingLocoCount,
        trainRawBrakingForce = trainRawBrakingForce
    }

    -- Update the train's data taht depends upon the trains current fuel.
    local noFuelFound = Utils.UpdateTrainSpeedCalculationDataForCurrentFuel(trainData, trainCarriagesDataArray, trainMovingForwards, train)

    return trainData, noFuelFound
end

--- Updates a train speed calcualtion data object (Utils_TrainSpeedCalculationData) for the current fuel the train is utilising to power it. Updates max achievable speed and the acceleration data.
---@param trainSpeedCalculationData Utils_TrainSpeedCalculationData
---@param trainCarriagesDataArray Utils_TrainCarriageData[]
---@param trainMovingForwardsToCacheData boolean @ If the train is moving forwards in relation to the facing of the cached carriage data.
---@param train LuaTrain
---@return boolean noFuelFound @ TRUE if no fuel was found in any forward moving locomotive. Generally FALSE is returned when all is normal.
Utils.UpdateTrainSpeedCalculationDataForCurrentFuel = function(trainSpeedCalculationData, trainCarriagesDataArray, trainMovingForwardsToCacheData, train)
    -- Get a current fuel for the forwards movement of the train.
    local fuelPrototype
    local noFuelFound = true
    for _, carriageCachedData in pairs(trainCarriagesDataArray) do
        -- Only process locomotives that are powering the trains movement.
        if carriageCachedData.prototypeType == "locomotive" and trainMovingForwardsToCacheData == carriageCachedData.faceingFrontOfTrain then
            local carriage = carriageCachedData.entity
            -- Coding Note: No point caching this as we only get 1 attribute of the prototype and we'd have to additionally get its name each time to utilsie a cache.
            fuelPrototype = Utils.GetLocomotivesCurrentFuelPrototype(carriage)
            if fuelPrototype ~= nil then
                -- Just get fuel from one forward facing loco that has fuel. Have to check the inventory as the train will be braking for the signal theres no currently burning.
                noFuelFound = false
                break
            end
        end
    end

    -- Update the acceleration data.
    local fuelAccelerationBonus
    if fuelPrototype ~= nil then
        fuelAccelerationBonus = fuelPrototype.fuel_acceleration_multiplier
    else
        fuelAccelerationBonus = 1
    end
    trainSpeedCalculationData.locomotiveFuelAccelerationPower = trainSpeedCalculationData.locomotiveAccelerationPower * fuelAccelerationBonus

    -- Have to get the right prototype max speed as they're not identical at runtime even if the train is symetrical. This API result includes the fuel type currently being burnt.
    local trainPrototypeMaxSpeedIncludesFuelBonus
    if trainMovingForwardsToCacheData then
        trainPrototypeMaxSpeedIncludesFuelBonus = train.max_forward_speed
    elseif not trainMovingForwardsToCacheData then
        trainPrototypeMaxSpeedIncludesFuelBonus = train.max_backward_speed
    end

    -- Work out the achievable max speed of the train.
    -- Maths way based on knowing that its acceleration result will be 0 once its at max speed.
    --   0=s - ((s+a)*r)   in to Wolf Ram Alpha and re-arranged for s.
    local maxSpeedForFuelBonus = -((((trainSpeedCalculationData.locomotiveFuelAccelerationPower) - trainSpeedCalculationData.trainWeightedFrictionForce) * trainSpeedCalculationData.trainAirResistanceReductionMultiplier) / (trainSpeedCalculationData.trainAirResistanceReductionMultiplier - 1))
    trainSpeedCalculationData.maxSpeed = math_min(maxSpeedForFuelBonus, trainPrototypeMaxSpeedIncludesFuelBonus)

    return noFuelFound
end

--- Calculates the speed of a train for 1 tick as if accelerating. This doesn't match vanilla trains perfectly, but is very close with vanilla trains and accounts for everything known accurately. From https://wiki.factorio.com/Locomotive
---
-- Often this is copied in to code inline for repeated calling.
---@param trainData Utils_TrainSpeedCalculationData
---@param initialSpeedAbsolute double
---@return number newAbsoluteSpeed
Utils.CalculateAcceleratingTrainSpeedForSingleTick = function(trainData, initialSpeedAbsolute)
    return math_min((math_max(0, initialSpeedAbsolute - trainData.trainWeightedFrictionForce) + trainData.locomotiveFuelAccelerationPower) * trainData.trainAirResistanceReductionMultiplier, trainData.maxSpeed)
end

--- Estimates how long an accelerating train takes to cover a distance and its final speed. Approximately accounts for air resistence, but final value will be a little off.
---
--- Note: none of the train speed/ticks/distance estimation functions give quite the same results as each other.
---@param trainData Utils_TrainSpeedCalculationData
---@param initialSpeedAbsolute double
---@param distance double
---@return Tick ticks @ Rounded up.
---@return number absoluteFinalSpeed
Utils.EstimateAcceleratingTrainTicksAndFinalSpeedToCoverDistance = function(trainData, initialSpeedAbsolute, distance)
    -- Work out how long it will take to accelerate over the distance. This doesn't (can't) limit the train to its max speed.
    local initialSpeedAirResistence = (1 - trainData.trainAirResistanceReductionMultiplier) * initialSpeedAbsolute
    local acceleration = trainData.locomotiveFuelAccelerationPower - trainData.trainWeightedFrictionForce - initialSpeedAirResistence
    local ticks = math_ceil((math_sqrt(2 * acceleration * distance + (initialSpeedAbsolute ^ 2)) - initialSpeedAbsolute) / acceleration)

    -- Check how fast the train would have been going at the end of this period. This may be greater than max speed.
    local finalSpeed = initialSpeedAbsolute + (acceleration * ticks)

    -- If the train would be going faster than max speed at the end then cap at max speed and estimate extra time at this speed.
    if finalSpeed > trainData.maxSpeed then
        -- Work out how long and the distance covered it will take to get up to max speed. Code logic copied From Utils.EstimateAcceleratingTrainTicksAndDistanceFromInitialToFinalSpeed().
        local ticksToMaxSpeed = math_ceil((trainData.maxSpeed - initialSpeedAbsolute) / acceleration)
        local distanceToMaxSpeed = (ticksToMaxSpeed * initialSpeedAbsolute) + (((trainData.maxSpeed - initialSpeedAbsolute) * ticksToMaxSpeed) / 2)

        -- Work out how long it will take to cover the remaining distance at max speed.
        local ticksAtMaxSpeed = math_ceil((distance - distanceToMaxSpeed) / trainData.maxSpeed)

        -- Set the final results.
        ticks = ticksToMaxSpeed + ticksAtMaxSpeed
        finalSpeed = trainData.maxSpeed
    end

    return ticks, finalSpeed
end

--- Estimates train speed and distance covered after set number of ticks. Approximately accounts for air resistence, but final value will be a little off.
---
--- Note: none of the train speed/ticks/distance estimation functions give quite the same results as each other.
---@param trainData Utils_TrainSpeedCalculationData
---@param initialSpeedAbsolute double
---@param ticks Tick
---@return double finalSpeedAbsolute
---@return double distanceCovered
Utils.EstimateAcceleratingTrainSpeedAndDistanceForTicks = function(trainData, initialSpeedAbsolute, ticks)
    local initialSpeedAirResistence = (1 - trainData.trainAirResistanceReductionMultiplier) * initialSpeedAbsolute
    local acceleration = trainData.locomotiveFuelAccelerationPower - trainData.trainWeightedFrictionForce - initialSpeedAirResistence
    local newSpeedAbsolute = math_min(initialSpeedAbsolute + (acceleration * ticks), trainData.maxSpeed)
    local distanceTravelled = (ticks * initialSpeedAbsolute) + (((newSpeedAbsolute - initialSpeedAbsolute) * ticks) / 2)
    return newSpeedAbsolute, distanceTravelled
end

--- Estimate how long it takes in ticks and distance for a train to accelerate from a starting speed to a final speed.
---
--- Note: none of the train speed/ticks/distance estimation functions give quite the same results as each other.
---@param trainData Utils_TrainSpeedCalculationData
---@param initialSpeedAbsolute double
---@param requiredSpeedAbsolute double
---@return Tick ticksTaken @ Rounded up.
---@return double distanceCovered
Utils.EstimateAcceleratingTrainTicksAndDistanceFromInitialToFinalSpeed = function(trainData, initialSpeedAbsolute, requiredSpeedAbsolute)
    local initialSpeedAirResistence = (1 - trainData.trainAirResistanceReductionMultiplier) * initialSpeedAbsolute
    local acceleration = trainData.locomotiveFuelAccelerationPower - trainData.trainWeightedFrictionForce - initialSpeedAirResistence
    local ticks = math_ceil((requiredSpeedAbsolute - initialSpeedAbsolute) / acceleration)
    local distance = (ticks * initialSpeedAbsolute) + (((requiredSpeedAbsolute - initialSpeedAbsolute) * ticks) / 2)
    return ticks, distance
end

--- Estimate how fast a train can go a distance while starting and ending the distance with the same speed, so it accelerates and brakes over the distance. Train speed durign this is capped to it's max speed.
---
--- Note: none of the train speed/ticks/distance estimation functions give quite the same results as each other.
---@param trainData Utils_TrainSpeedCalculationData
---@param targetSpeedAbsolute double
---@param distance double
---@param forcesBrakingForceBonus double @ The force's train_braking_force_bonus.
---@return Tick ticks @ Rounded up.
Utils.EstimateTrainTicksToCoverDistanceWithSameStartAndEndSpeed = function(trainData, targetSpeedAbsolute, distance, forcesBrakingForceBonus)
    -- Get the acceleration and braking force per tick.
    local initialSpeedAirResistence = (1 - trainData.trainAirResistanceReductionMultiplier) * targetSpeedAbsolute
    local accelerationForcePerTick = trainData.locomotiveFuelAccelerationPower - trainData.trainWeightedFrictionForce - initialSpeedAirResistence
    local trainForceBrakingForce = trainData.trainRawBrakingForce + (trainData.trainRawBrakingForce * forcesBrakingForceBonus)
    local brakingForcePerTick = (trainForceBrakingForce + trainData.trainFrictionForce) / trainData.trainWeight

    -- This estimates distance that has to be spent on the speed change action. So a greater ratio of acceleration to braking force means more distance will be spent braking than accelerating.
    local accelerationToBrakingForceRatio = accelerationForcePerTick / (accelerationForcePerTick + brakingForcePerTick)
    local accelerationDistance = distance * (1 - accelerationToBrakingForceRatio)

    -- Estimate how long it would take to accelerate over this distance and how fast the train would have been going at the end of this period. This may be greater than max speed.
    local accelerationTicks = (math_sqrt(2 * accelerationForcePerTick * accelerationDistance + (targetSpeedAbsolute ^ 2)) - targetSpeedAbsolute) / accelerationForcePerTick
    local finalSpeed = targetSpeedAbsolute + (accelerationForcePerTick * accelerationTicks)

    -- Based on if the train would be going faster than its max speed handle the braking time part differently.
    local ticks
    if finalSpeed > trainData.maxSpeed then
        -- The train would be going faster than max speed at the end so re-estimate acceleration up to the max speed cap and then the time it will take at max speed to cover the required distance.

        -- Work out how long and the distance covered it will take to get up to max speed. Code logic copied From Utils.EstimateAcceleratingTrainTicksAndDistanceFromInitialToFinalSpeed().
        local ticksToMaxSpeed = (trainData.maxSpeed - targetSpeedAbsolute) / accelerationForcePerTick
        local distanceToMaxSpeed = (ticksToMaxSpeed * targetSpeedAbsolute) + (((trainData.maxSpeed - targetSpeedAbsolute) * ticksToMaxSpeed) / 2)

        -- Work out how long it will take to brake from max speed back to the required finish speed.
        local ticksToBrake = (trainData.maxSpeed - targetSpeedAbsolute) / brakingForcePerTick
        local distanceToBrake = (ticksToBrake * targetSpeedAbsolute) + (((trainData.maxSpeed - targetSpeedAbsolute) * ticksToBrake) / 2)

        -- Work out how long it will take to cover the remaining distance at max speed.
        local ticksAtMaxSpeed = (distance - distanceToMaxSpeed - distanceToBrake) / trainData.maxSpeed

        -- Update the final results.
        ticks = math.ceil(ticksToMaxSpeed + ticksAtMaxSpeed + ticksToBrake)
    else
        -- The train didn't reach max speed when accelerating so stopping ticks is for just the braking ratio of distance.
        local brakingDistance = distance * accelerationToBrakingForceRatio
        local brakingTicks = (math_sqrt(2 * brakingForcePerTick * brakingDistance + (targetSpeedAbsolute ^ 2)) - targetSpeedAbsolute) / brakingForcePerTick
        ticks = math.ceil(accelerationTicks + brakingTicks)
    end

    return ticks
end

--- Calculates the braking distance and ticks for a train at a given speed to brake to a required speed.
---@param trainData Utils_TrainSpeedCalculationData
---@param initialSpeedAbsolute double
---@param requiredSpeedAbsolute double
---@param forcesBrakingForceBonus double @ The force's train_braking_force_bonus.
---@return Tick ticksToStop @ Rounded up.
---@return double brakingDistance
Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed = function(trainData, initialSpeedAbsolute, requiredSpeedAbsolute, forcesBrakingForceBonus)
    local speedToDropAbsolute = initialSpeedAbsolute - requiredSpeedAbsolute
    local trainForceBrakingForce = trainData.trainRawBrakingForce + (trainData.trainRawBrakingForce * forcesBrakingForceBonus)
    local ticksToStop = math_ceil(speedToDropAbsolute / ((trainForceBrakingForce + trainData.trainFrictionForce) / trainData.trainWeight))
    local brakingDistance = (ticksToStop * requiredSpeedAbsolute) + ((ticksToStop / 2.0) * speedToDropAbsolute)
    return ticksToStop, brakingDistance
end

--- Calculates the final train speed and distance covered if it brakes for a time period.
---@param trainData Utils_TrainSpeedCalculationData
---@param currentSpeedAbsolute double
---@param forcesBrakingForceBonus double @ The force's train_braking_force_bonus.
---@param ticksToBrake Tick
---@return double newSpeedAbsolute
---@return double distanceCovered
Utils.CalculateBrakingTrainSpeedAndDistanceCoveredForTime = function(trainData, currentSpeedAbsolute, forcesBrakingForceBonus, ticksToBrake)
    local trainForceBrakingForce = trainData.trainRawBrakingForce + (trainData.trainRawBrakingForce * forcesBrakingForceBonus)
    local tickBrakingReduction = (trainForceBrakingForce + trainData.trainFrictionForce) / trainData.trainWeight
    local newSpeedAbsolute = currentSpeedAbsolute - (tickBrakingReduction * ticksToBrake)
    local speedDropped = currentSpeedAbsolute - newSpeedAbsolute
    local distanceCovered = (ticksToBrake * newSpeedAbsolute) + ((ticksToBrake / 2.0) * speedDropped)
    return newSpeedAbsolute, distanceCovered
end

--- Calculates a train's time taken and intial speed to brake to a final speed over a distance.
---
--- Caps the intial speed generated at the trains max speed.
---@param trainData Utils_TrainSpeedCalculationData
---@param distance double
---@param finalSpeedAbsolute double
---@param forcesBrakingForceBonus double @ The force's train_braking_force_bonus.
---@return Tick ticksToBrakeOverDistance @ Rounded up.
---@return double initialAbsoluteSpeed
Utils.CalculateBrakingTrainsTimeAndStartingSpeedToBrakeToFinalSpeedOverDistance = function(trainData, distance, finalSpeedAbsolute, forcesBrakingForceBonus)
    local trainForceBrakingForce = trainData.trainRawBrakingForce + (trainData.trainRawBrakingForce * forcesBrakingForceBonus)
    local tickBrakingReduction = (trainForceBrakingForce + trainData.trainFrictionForce) / trainData.trainWeight
    local initialSpeed = math_sqrt((finalSpeedAbsolute ^ 2) + (2 * tickBrakingReduction * distance))

    if initialSpeed > trainData.maxSpeed then
        -- Initial speed is greater than max speed so cap the inital speed to max speed.
        initialSpeed = trainData.maxSpeed
    end

    local speedToDropAbsolute = initialSpeed - finalSpeedAbsolute
    local ticks = math_ceil(speedToDropAbsolute / tickBrakingReduction)

    return ticks, initialSpeed
end

--- Returns the new absolute speed for the train in 1 tick from current speed to stop within the required distance. This ignores any train data and will stop the train in time regardless of its braking force. The result can be applied to the current speed each tick to get the new speed.
---@param currentSpeedAbsolute double
---@param distance double
---@return double brakingForceSpeedMultiplier
Utils.CalculateBrakingTrainSpeedForSingleTickToStopWithinDistance = function(currentSpeedAbsolute, distance)
    -- Use a mass of 1.
    local brakingSpeedReduction = (0.5 * 1 * currentSpeedAbsolute * currentSpeedAbsolute) / distance
    return currentSpeedAbsolute - brakingSpeedReduction
end

return Utils
