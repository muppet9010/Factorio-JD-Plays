local WaterBarrier = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Constants = require("constants")

local barrierOrientations = {horizontal = "horizontal", vertical = "vertical"}
local barrierDirections = {positive = "positive", negative = "negative"}

local barrierOrientation = barrierOrientations.vertical
local barrierDirection = barrierDirections.positive
local barrierChunkStart = 2 --math.floor(200 / 32)
local edgeVariation = 20
local firstWaterTypeWidthMin = 3
local firstWaterTypeWidthMax = 20
local coastlinePerTileVariation = 1
local damageDistanceModifier = 0.1

WaterBarrier.CreateGlobals = function()
    global.WaterBarrier = global.WaterBarrier or {}
    --These must be -1 so that when we check the top left corner tile of new chunks we generate both sides.
    global.WaterBarrier.barrierVectorEdgeMinCalculated = global.WaterBarrier.barrierVectorEdgeMinCalculated or -1
    global.WaterBarrier.barrierVectorEdgeMaxCalculated = global.WaterBarrier.barrierVectorEdgeMaxCalculated or -1
end

WaterBarrier.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "WaterBarrier", WaterBarrier.OnChunkGenerated)
end

WaterBarrier.OnStartup = function()
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            global.WaterBarrier.waterChunkYStart = 0 + barrierChunkStart
            global.WaterBarrier.waterTileYMin = global.WaterBarrier.waterChunkYStart * 32
            global.WaterBarrier.waterTileYMax = global.WaterBarrier.waterTileYMin + edgeVariation
            global.WaterBarrier.waterInnerEdgeTiles = global.WaterBarrier.waterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterTileYMin + math.random(edgeVariation)}
            global.WaterBarrier.deepWaterInnerEdgeTiles = global.WaterBarrier.deepWaterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterInnerEdgeTiles[-1] + math.random(firstWaterTypeWidthMin, firstWaterTypeWidthMax)}
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            global.WaterBarrier.waterChunkXStart = 0 + barrierChunkStart
            global.WaterBarrier.waterTileXMin = global.WaterBarrier.waterChunkXStart * 32
            global.WaterBarrier.waterTileXMax = global.WaterBarrier.waterTileXMin + edgeVariation
            global.WaterBarrier.waterInnerEdgeTiles = global.WaterBarrier.waterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterTileXMin + math.random(edgeVariation)}
            global.WaterBarrier.deepWaterInnerEdgeTiles = global.WaterBarrier.deepWaterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterInnerEdgeTiles[-1] + math.random(firstWaterTypeWidthMin, firstWaterTypeWidthMax)}
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
end

WaterBarrier.OnChunkGenerated = function(event)
    local leftTopTileInChunk = event.area.left_top
    local chunkPos = Utils.GetChunkPositionForTilePosition(leftTopTileInChunk)
    local surface = event.surface
    if WaterBarrier.IsChunkBeyondBarrierChunkStart(chunkPos) then
        WaterBarrier.CalculateShorelinesForVector(leftTopTileInChunk)
        WaterBarrier.ApplyBarrierTiles(leftTopTileInChunk, surface, chunkPos)
    end
end

WaterBarrier.IsChunkBeyondBarrierChunkStart = function(chunkPos)
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            if chunkPos.y >= global.WaterBarrier.waterChunkYStart then
                return true
            else
                return false
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            if chunkPos.x >= global.WaterBarrier.waterChunkXStart then
                return true
            else
                return false
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
end

WaterBarrier.CalculateShorelinesForVector = function(leftTopTileInChunk)
    local debug = false
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            local leftTopTileInChunkX = leftTopTileInChunk.x
            Logging.Log("new chunk X range: " .. leftTopTileInChunkX .. " to " .. (leftTopTileInChunkX + 31), debug)
            if global.WaterBarrier.waterInnerEdgeTiles[leftTopTileInChunkX] == nil then
                if leftTopTileInChunkX < global.WaterBarrier.barrierVectorEdgeMinCalculated then
                    --to the left of the lowested already calculated
                    Logging.Log("lowest X calculated: " .. global.WaterBarrier.barrierVectorEdgeMinCalculated, debug)
                    local lastVectorPos = global.WaterBarrier.barrierVectorEdgeMinCalculated
                    local lastWaterDistance = global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos]
                    local lastDeepWaterDistance = global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos]
                    while lastVectorPos > leftTopTileInChunkX do
                        lastVectorPos = lastVectorPos - 1
                        lastWaterDistance = WaterBarrier.GetNextWaterDistance(lastWaterDistance)
                        global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos] = lastWaterDistance
                        lastDeepWaterDistance = WaterBarrier.GetNextDeepWaterDistance(lastWaterDistance, lastDeepWaterDistance)
                        global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos] = lastDeepWaterDistance
                    end
                    global.WaterBarrier.barrierVectorEdgeMinCalculated = lastVectorPos
                    Logging.Log("ending data: " .. Utils.TableContentsToJSON(global.WaterBarrier.waterInnerEdgeTiles) .. "\r\n" .. Utils.TableContentsToJSON(global.WaterBarrier.deepWaterInnerEdgeTiles), debug)
                elseif leftTopTileInChunkX > global.WaterBarrier.barrierVectorEdgeMaxCalculated then
                    --to the right of the lowested already calculated
                    Logging.Log("highest X calculated: " .. global.WaterBarrier.barrierVectorEdgeMaxCalculated, debug)
                    local lastVectorPos = global.WaterBarrier.barrierVectorEdgeMaxCalculated
                    local lastWaterDistance = global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos]
                    local lastDeepWaterDistance = global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos]
                    while lastVectorPos < leftTopTileInChunkX + 31 do
                        lastVectorPos = lastVectorPos + 1
                        lastWaterDistance = WaterBarrier.GetNextWaterDistance(lastWaterDistance)
                        global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos] = lastWaterDistance
                        lastDeepWaterDistance = WaterBarrier.GetNextDeepWaterDistance(lastWaterDistance, lastDeepWaterDistance)
                        global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos] = lastDeepWaterDistance
                    end
                    global.WaterBarrier.barrierVectorEdgeMaxCalculated = lastVectorPos
                    Logging.Log("ending data: " .. Utils.TableContentsToJSON(global.WaterBarrier.waterInnerEdgeTiles) .. "\r\n" .. Utils.TableContentsToJSON(global.WaterBarrier.deepWaterInnerEdgeTiles), debug)
                end
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            local leftTopTileInChunkY = leftTopTileInChunk.y
            Logging.Log("new chunk Y range: " .. leftTopTileInChunkY .. " to " .. (leftTopTileInChunkY + 31), debug)
            if global.WaterBarrier.waterInnerEdgeTiles[leftTopTileInChunkY] == nil then
                if leftTopTileInChunkY < global.WaterBarrier.barrierVectorEdgeMinCalculated then
                    --to the left of the lowested already calculated
                    Logging.Log("lowest Y calculated: " .. global.WaterBarrier.barrierVectorEdgeMinCalculated, debug)
                    local lastVectorPos = global.WaterBarrier.barrierVectorEdgeMinCalculated
                    local lastWaterDistance = global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos]
                    local lastDeepWaterDistance = global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos]
                    while lastVectorPos > leftTopTileInChunkY do
                        lastVectorPos = lastVectorPos - 1
                        lastWaterDistance = WaterBarrier.GetNextWaterDistance(lastWaterDistance)
                        global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos] = lastWaterDistance
                        lastDeepWaterDistance = WaterBarrier.GetNextDeepWaterDistance(lastWaterDistance, lastDeepWaterDistance)
                        global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos] = lastDeepWaterDistance
                    end
                    global.WaterBarrier.barrierVectorEdgeMinCalculated = lastVectorPos
                    Logging.Log("ending data: " .. Utils.TableContentsToJSON(global.WaterBarrier.waterInnerEdgeTiles) .. "\r\n" .. Utils.TableContentsToJSON(global.WaterBarrier.deepWaterInnerEdgeTiles), debug)
                elseif leftTopTileInChunkY > global.WaterBarrier.barrierVectorEdgeMaxCalculated then
                    --to the right of the lowested already calculated
                    Logging.Log("highest Y calculated: " .. global.WaterBarrier.barrierVectorEdgeMaxCalculated, debug)
                    local lastVectorPos = global.WaterBarrier.barrierVectorEdgeMaxCalculated
                    local lastWaterDistance = global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos]
                    local lastDeepWaterDistance = global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos]
                    while lastVectorPos < leftTopTileInChunkY + 31 do
                        lastVectorPos = lastVectorPos + 1
                        lastWaterDistance = WaterBarrier.GetNextWaterDistance(lastWaterDistance)
                        global.WaterBarrier.waterInnerEdgeTiles[lastVectorPos] = lastWaterDistance
                        lastDeepWaterDistance = WaterBarrier.GetNextDeepWaterDistance(lastWaterDistance, lastDeepWaterDistance)
                        global.WaterBarrier.deepWaterInnerEdgeTiles[lastVectorPos] = lastDeepWaterDistance
                    end
                    global.WaterBarrier.barrierVectorEdgeMaxCalculated = lastVectorPos
                    Logging.Log("ending data: " .. Utils.TableContentsToJSON(global.WaterBarrier.waterInnerEdgeTiles) .. "\r\n" .. Utils.TableContentsToJSON(global.WaterBarrier.deepWaterInnerEdgeTiles), debug)
                end
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
end

WaterBarrier.GetNextWaterDistance = function(lastWaterDistance)
    local nextDistanceOptions = {lastWaterDistance}
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            table.insert(nextDistanceOptions, math.random(math.max(global.WaterBarrier.waterTileYMin, lastWaterDistance - coastlinePerTileVariation), math.min(global.WaterBarrier.waterTileYMax, lastWaterDistance + coastlinePerTileVariation)))
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            table.insert(nextDistanceOptions, math.random(math.max(global.WaterBarrier.waterTileXMin, lastWaterDistance - coastlinePerTileVariation), math.min(global.WaterBarrier.waterTileXMax, lastWaterDistance + coastlinePerTileVariation)))
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
    return nextDistanceOptions[math.random(#nextDistanceOptions)]
end

WaterBarrier.GetNextDeepWaterDistance = function(lastWaterDistance, lastDeepWaterDistance)
    local nextDistanceOptions = {}
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            local min = math.min(math.max(lastWaterDistance + firstWaterTypeWidthMin, lastDeepWaterDistance - coastlinePerTileVariation), lastWaterDistance + firstWaterTypeWidthMax)
            local max = math.min(lastWaterDistance + firstWaterTypeWidthMax, lastDeepWaterDistance + coastlinePerTileVariation)
            table.insert(nextDistanceOptions, math.random(min, max))
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            local min = math.min(math.max(lastWaterDistance + firstWaterTypeWidthMin, lastDeepWaterDistance - coastlinePerTileVariation), lastWaterDistance + firstWaterTypeWidthMax)
            local max = math.min(lastWaterDistance + firstWaterTypeWidthMax, lastDeepWaterDistance + coastlinePerTileVariation)
            table.insert(nextDistanceOptions, math.random(min, max))
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
    return nextDistanceOptions[math.random(#nextDistanceOptions)]
end

WaterBarrier.ApplyBarrierTiles = function(leftTopTileInChunk, surface, chunkPos)
    local tilesToChange = {}
    if barrierOrientation == barrierOrientations.horizontal then
        if barrierDirection == barrierDirections.positive then
            local xVectorFoundLand = {}
            local mapWidthMin = 0 - (surface.map_gen_settings.width / 2)
            local mapWidthMax = surface.map_gen_settings.width / 2
            local mapHeightMin = 0 - (surface.map_gen_settings.height / 2)
            local mapHeightMax = surface.map_gen_settings.height / 2
            for x = leftTopTileInChunk.x, leftTopTileInChunk.x + 31 do
                if x >= mapWidthMin and x < mapWidthMax then
                    for y = leftTopTileInChunk.y, leftTopTileInChunk.y + 31 do
                        if y >= mapHeightMin and y < mapHeightMax then
                            if y >= global.WaterBarrier.deepWaterInnerEdgeTiles[x] then
                                table.insert(tilesToChange, {name = "deepwater", position = {x, y}})
                            elseif y >= global.WaterBarrier.waterInnerEdgeTiles[x] then
                                local replaceToWater = false
                                if xVectorFoundLand[x] == nil then
                                    local aboveTileName = surface.get_tile(x, y - 1).name
                                    if aboveTileName ~= "water" and aboveTileName ~= "deepwater" then
                                        xVectorFoundLand[x] = true
                                        replaceToWater = true
                                    else
                                        xVectorFoundLand[x] = false
                                    end
                                end
                                if xVectorFoundLand[x] == true then
                                    replaceToWater = true
                                else
                                    local thisTileName = surface.get_tile(x, y).name
                                    if thisTileName ~= "water" and thisTileName ~= "deepwater" then
                                        replaceToWater = true
                                    end
                                end
                                if replaceToWater then
                                    table.insert(tilesToChange, {name = "water", position = {x, y}})
                                end
                            end
                        end
                    end
                end
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.horizontal barrierDirections.negative NOT DONE YET")
        end
    elseif barrierOrientation == barrierOrientations.vertical then
        if barrierDirection == barrierDirections.positive then
            local yVectorFoundLand = {}
            local mapWidthMin = 0 - (surface.map_gen_settings.width / 2)
            local mapWidthMax = surface.map_gen_settings.width / 2
            local mapHeightMin = 0 - (surface.map_gen_settings.height / 2)
            local mapHeightMax = surface.map_gen_settings.height / 2
            for x = leftTopTileInChunk.x, leftTopTileInChunk.x + 31 do
                if x >= mapWidthMin and x < mapWidthMax then
                    for y = leftTopTileInChunk.y, leftTopTileInChunk.y + 31 do
                        if y >= mapHeightMin and y < mapHeightMax then
                            if x >= global.WaterBarrier.deepWaterInnerEdgeTiles[y] then
                                table.insert(tilesToChange, {name = "deepwater", position = {x, y}})
                            elseif x >= global.WaterBarrier.waterInnerEdgeTiles[y] then
                                local replaceToWater = false
                                if yVectorFoundLand[y] == nil then
                                    local aboveTileName = surface.get_tile(x - 1, y).name
                                    if aboveTileName ~= "water" and aboveTileName ~= "deepwater" then
                                        yVectorFoundLand[y] = true
                                        replaceToWater = true
                                    else
                                        yVectorFoundLand[y] = false
                                    end
                                end
                                if yVectorFoundLand[y] == true then
                                    replaceToWater = true
                                else
                                    local thisTileName = surface.get_tile(x, y).name
                                    if thisTileName ~= "water" and thisTileName ~= "deepwater" then
                                        replaceToWater = true
                                    end
                                end
                                if replaceToWater then
                                    table.insert(tilesToChange, {name = "water", position = {x, y}})
                                end
                            end
                        end
                    end
                end
            end
        elseif barrierDirection == barrierDirections.negative then
            Logging.LogPrint("barrierOrientations.vertical barrierDirections.negative NOT DONE YET")
        end
    end
    surface.set_tiles(tilesToChange)
    surface.regenerate_entity({"fish"}, {chunkPos})
end

return WaterBarrier
