local Utils = {}
--local Logging = require("utility/logging")

function Utils.KillAllObjectsInArea(surface, positionedBoundingBox, killerEntity, collisionBoxOnlyEntities)
    local entitiesFound = surface.find_entities(positionedBoundingBox)
    for k, entity in pairs(entitiesFound) do
        if entity.valid then
            if entity.health ~= nil and entity.destructible and ((collisionBoxOnlyEntities and Utils.IsCollisionBoxPopulated(entity.prototype.collision_box)) or (not collisionBoxOnlyEntities)) then
                entity.die("neutral", killerEntity)
            end
        end
    end
end

function Utils.ApplyBoundingBoxToPosition(centrePos, boundingBox, orientation)
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
    else
        game.print("Error: Diagonal orientations not supported by Utils.ApplyBoundingBoxToPosition()")
    end
end

function Utils.RotatePositionAround0(orientation, position)
    local deg = orientation * 360
    local rad = math.rad(deg)
    local cosValue = math.cos(rad)
    local sinValue = math.sin(rad)
    local rotatedX = position.x * cosValue - position.y * sinValue
    local rotatedY = position.x * sinValue + position.y * cosValue
    return {x = rotatedX, y = rotatedY}
end

function Utils.CalculateBoundingBoxFrom2Points(point1, point2)
    local minX = nil
    local maxX = nil
    local minY = nil
    local maxY = nil
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

function Utils.ApplyOffsetToPosition(position, offset)
    if offset == nil then
        return position
    end
    if offset.x ~= nil then
        position.x = position.x + offset.x
    end
    if offset.y ~= nil then
        position.y = position.y + offset.y
    end
    return position
end

function Utils.IsCollisionBoxPopulated(collisionBox)
    if collisionBox == nil then
        return false
    end
    if collisionBox.left_top.x ~= 0 and collisionBox.left_top.y ~= 0 and collisionBox.right_bottom.x ~= 0 and collisionBox.right_bottom.y ~= 0 then
        return true
    else
        return false
    end
end

function Utils.LogisticEquation(index, height, steepness)
    return height / (1 + math.exp(steepness * (index - 0)))
end

function Utils.ExponentialDecayEquation(index, multiplyer, scale)
    return multiplyer * math.exp(-index * scale)
end

function Utils.RoundNumberToDecimalPlaces(num, numDecimalPlaces)
    local result
    if numDecimalPlaces ~= nil and numDecimalPlaces > 0 then
        local mult = 10 ^ numDecimalPlaces
        result = math.floor(num * mult + 0.5) / mult
    else
        result = math.floor(num + 0.5)
    end
    if result == "nan" then
        result = 0
    end
    return result
end

--This doesn't guarentee correct on some of the edge cases, but is as close as possible assuming that 1/256 is the variance for the same number (Bilka, Dev on Discord)
function Utils.FuzzyCompareDoubles(num1, logic, num2)
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

function Utils.GetTableLength(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function Utils.GetTableNonNilLength(table)
    local count = 0
    for k, v in pairs(table) do
        if v ~= nil then
            count = count + 1
        end
    end
    return count
end

function Utils.GetMaxKey(table)
    local max_key = 0
    for k in pairs(table) do
        if k > max_key then
            max_key = k
        end
    end
    return max_key
end

function Utils.CalculateBoundingBoxFromPositionAndRange(position, range)
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

function Utils.CalculateTilesUnderPositionedBoundingBox(positionedBoundingBox)
    local tiles = {}
    for x = positionedBoundingBox.left_top.x, positionedBoundingBox.right_bottom.x do
        for y = positionedBoundingBox.left_top.y, positionedBoundingBox.right_bottom.y do
            table.insert(tiles, {x = math.floor(x), y = math.floor(y)})
        end
    end
    return tiles
end

function Utils.GetEntityReturnedToInventoryName(entity)
    if entity.prototype.mineable_properties ~= nil and entity.prototype.mineable_properties.products ~= nil and #entity.prototype.mineable_properties.products > 0 then
        return entity.prototype.mineable_properties.products[1].name
    else
        return entity.name
    end
end

function Utils.TableKeyToArray(aTable)
    local newArray = {}
    for key in pairs(aTable) do
        table.insert(newArray, key)
    end
    return newArray
end

function Utils.TableContentsToJSON(target_table, name)
    local tablesLogged = {}
    return Utils._TableContentsToJSON(target_table, name, tablesLogged)
end
function Utils._TableContentsToJSON(target_table, name, tablesLogged, indent, stop_traversing)
    indent = indent or 1
    local indentstring = string.rep(" ", (indent * 4))
    local table_id = string.gsub(tostring(target_table), "table: ", "")
    tablesLogged[table_id] = "logged"
    local table_contents = ""
    if Utils.GetTableLength(target_table) > 0 then
        for k, v in pairs(target_table) do
            local key, value
            if type(k) == "string" or type(k) == "number" or type(k) == "boolean" then
                key = '"' .. tostring(k) .. '"'
            elseif type(k) == "nil" then
                key = '"nil"'
            elseif type(k) == "table" then
                local sub_table_id = string.gsub(tostring(k), "table: ", "")
                if stop_traversing == true then
                    key = '"CIRCULAR LOOP TABLE'
                else
                    local sub_stop_traversing = nil
                    if tablesLogged[sub_table_id] ~= nil then
                        sub_stop_traversing = true
                    end
                    key = "{\r\n" .. Utils._TableContentsToJSON(k, name, tablesLogged, indent + 1, sub_stop_traversing) .. "\r\n" .. indentstring .. "}"
                end
            elseif type(k) == "function" then
                key = '"' .. tostring(k) .. '"'
            else
                key = '"unhandled type: ' .. type(k) .. '"'
            end
            if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                value = '"' .. tostring(v) .. '"'
            elseif type(v) == "nil" then
                value = '"nil"'
            elseif type(v) == "table" then
                local sub_table_id = string.gsub(tostring(v), "table: ", "")
                if stop_traversing == true then
                    value = '"CIRCULAR LOOP TABLE'
                else
                    local sub_stop_traversing = nil
                    if tablesLogged[sub_table_id] ~= nil then
                        sub_stop_traversing = true
                    end
                    value = "{\r\n" .. Utils._TableContentsToJSON(v, name, tablesLogged, indent + 1, sub_stop_traversing) .. "\r\n" .. indentstring .. "}"
                end
            elseif type(v) == "function" then
                value = '"' .. tostring(v) .. '"'
            else
                value = '"unhandled type: ' .. type(v) .. '"'
            end
            if table_contents ~= "" then
                table_contents = table_contents .. "," .. "\r\n"
            end
            table_contents = table_contents .. indentstring .. tostring(key) .. ":" .. tostring(value)
        end
    else
        table_contents = indentstring .. '"empty"'
    end
    if indent == 1 then
        return '"' .. name .. '":{' .. "\r\n" .. table_contents .. "\r\n" .. "}"
    else
        return table_contents
    end
end

function Utils.FormatPositionTableToString(positionTable)
    return positionTable.x .. "," .. positionTable.y
end

function Utils.GetTableKeyWithValue(theTable, value)
    for k, v in pairs(theTable) do
        if v == value then
            return k
        end
    end
    return nil
end

function Utils.GetRandomFloatInRange(lower, upper)
    return lower + math.random() * (upper - lower)
end

function Utils.WasCreativeModeInstantDeconstructionUsed(event)
    if event.instant_deconstruction ~= nil and event.instant_deconstruction == true then
        return true
    else
        return false
    end
end

function Utils.GetBiterType(modEnemyProbabilities, spawnerType, evolution)
    --modEnemyProbabilities argument is a global variable the utility function can use. do not set in any way
    modEnemyProbabilities = modEnemyProbabilities or {}
    if modEnemyProbabilities[spawnerType] == nil then
        modEnemyProbabilities[spawnerType] = {}
    end
    if modEnemyProbabilities[spawnerType].calculatedEvolution == nil or math.abs(modEnemyProbabilities[spawnerType].calculatedEvolution - evolution) > 0.001 then
        modEnemyProbabilities[spawnerType].calculatedEvolution = evolution
        modEnemyProbabilities[spawnerType].probabilities = Utils._CalculateSpecificBiterSelectionProbabilities(spawnerType, evolution)
    end

    local randNum = math.random()
    for _, probability in pairs(modEnemyProbabilities[spawnerType].probabilities) do
        if probability.top > 0 and randNum >= probability.bottom and randNum <= probability.top then
            return probability.unit
        end
    end
end

function Utils._CalculateSpecificBiterSelectionProbabilities(spawnerType, currentEvolution)
    local rawUnitProbs = game.entity_prototypes[spawnerType].result_units
    local currentEvolutionProbabilities = {}
    local currentEvolutionProbabilitiesTop = 0

    for _, possibility in pairs(rawUnitProbs) do
        local startSpawnPointIndex = nil
        for spawnPointIndex, spawnPoint in pairs(possibility.spawn_points) do
            if spawnPoint.evolution_factor <= currentEvolution then
                startSpawnPointIndex = spawnPointIndex
            end
        end
        if startSpawnPointIndex ~= nil then
            local startSpawnPoint = possibility.spawn_points[startSpawnPointIndex]
            local endSpawnPoint
            if possibility.spawn_points[startSpawnPointIndex + 1] ~= nil then
                endSpawnPoint = possibility.spawn_points[startSpawnPointIndex + 1]
            else
                endSpawnPoint = {evolution_factor = 1.0, weight = startSpawnPoint.weight}
            end

            local weight
            if startSpawnPoint.evolution_factor ~= endSpawnPoint.evolution_factor then
                local evoRange = endSpawnPoint.evolution_factor - startSpawnPoint.evolution_factor
                local weightRange = endSpawnPoint.weight - startSpawnPoint.weight
                local evoRangeMultiplier = (currentEvolution - startSpawnPoint.evolution_factor) / evoRange
                weight = (weightRange * evoRangeMultiplier) + startSpawnPoint.weight
            else
                weight = startSpawnPoint.weight
            end
            local probability = currentEvolutionProbabilitiesTop + weight
            table.insert(currentEvolutionProbabilities, {bottom = currentEvolutionProbabilitiesTop, top = probability, unit = possibility.unit})
            currentEvolutionProbabilitiesTop = probability
        end
    end

    local normalisedcurrentEvolutionProbabilities = {}
    local normaliseMultiplier = 1 / currentEvolutionProbabilitiesTop
    for index, probability in pairs(currentEvolutionProbabilities) do
        normalisedcurrentEvolutionProbabilities[index] = {
            bottom = probability.bottom * normaliseMultiplier,
            top = probability.top * normaliseMultiplier,
            unit = probability.unit
        }
    end

    return normalisedcurrentEvolutionProbabilities
end

--copied from Factorio core Util 0.17.21
function Utils.DeepCopy(outerObject)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            -- don't copy factorio rich objects
            return object
        elseif object.__self then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(outerObject)
end

function Utils.DisableSiloScript()
	--OnLoad
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
    local items = remote.call("silo_script", "get_tracked_items")
    for itemName in pairs(items) do
        remote.call("silo_script", "remove_tracked_item", itemName)
    end
end

function Utils.DisableWinOnRocket()
	--OnInit
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
end

function Utils.ClearSpawnRespawnItems()
	--OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_created_items", {})
    remote.call("freeplay", "set_respawn_items", {})
end

function Utils.SetStartingMapReveal(distance)
	--OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_chart_distance", distance)
end

function Utils.DisableIntroMessage()
	--OnInit
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_skip_intro", true)
end

function Utils.PadNumberToMinimumDigits(input, requiredLength)
    local shortBy = requiredLength - string.len(input)
    for i = 1, shortBy do
        input = "0" .. input
    end
    return input
end

function Utils.LocalisedStringOfTime(inputTicks, displayLargestTimeUnit, displaySmallestTimeUnit)
    local negativeSign = ""
    if inputTicks < 0 then
        negativeSign = "-"
        inputTicks = 0 - inputTicks
    end
    local hours = math.floor(inputTicks / 216000)
    local displayHours = Utils.PadNumberToMinimumDigits(hours, 2)
    inputTicks = inputTicks - (hours * 216000)
    local minutes = math.floor(inputTicks / 3600)
    local displayMinutes = Utils.PadNumberToMinimumDigits(minutes, 2)
    inputTicks = inputTicks - (minutes * 3600)
    local seconds = math.floor(inputTicks / 60)
    local displaySeconds = Utils.PadNumberToMinimumDigits(seconds, 2)

    if displayLargestTimeUnit == "auto" then
        if hours > 0 then
            displayLargestTimeUnit = "hour"
        elseif minutes > 0 then
            displayLargestTimeUnit = "minute"
        else
            displayLargestTimeUnit = "second"
        end
    end
    if displaySmallestTimeUnit == nil or displaySmallestTimeUnit == "" or displaySmallestTimeUnit == "auto" then
        displaySmallestTimeUnit = "second"
    end
    if not (displaySmallestTimeUnit == "hour" or displaySmallestTimeUnit == "minute" or displaySmallestTimeUnit == "second") then
        error("unrecognised displaySmallestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end

    if displayLargestTimeUnit == "hour" then
        return {"muppet-utils.time-hour-" .. displaySmallestTimeUnit, negativeSign .. displayHours, displayMinutes, displaySeconds}
    elseif displayLargestTimeUnit == "minute" then
        return {"muppet-utils.time-minute-" .. displaySmallestTimeUnit, negativeSign .. displayMinutes, displaySeconds}
    elseif displayLargestTimeUnit == "second" then
        return {"muppet-utils.time-second-" .. displaySmallestTimeUnit, negativeSign .. displaySeconds}
    else
        error("unrecognised displayLargestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end
end

return Utils
