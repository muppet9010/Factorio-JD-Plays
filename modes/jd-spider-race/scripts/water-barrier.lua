--[[
    Notes:
        - This is a copy of an older water barrier feature from the JD-Plays mod. Its being used on a different orientation (added) and doesn't have the killing fog effect.
        - The code is fundermentally unchanged and has just had some readability improvements made to it.
]]
--

local WaterBarrier = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")

---@class Spider_WaterBarrier_BarrierOrientations
local BarrierOrientations = {horizontal = "horizontal", vertical = "vertical"}

---@class Spider_WaterBarrier_BarrierDirections
local BarrierDirections = {positive = "positive", negative = "negative"}

--- Options for this mods shoreline generation.
local BarrierOrientation = BarrierOrientations.vertical
local barrierDirection = BarrierDirections.positive
local BarrierChunkStart = 2 --math.floor(200 / 32)
local EdgeVariation = 20
local FirstWaterTypeWidthMin = 3
local FirstWaterTypeWidthMax = 20
local CoastlinePerTileVariation = 1

WaterBarrier.CreateGlobals = function()
    global.WaterBarrier = global.WaterBarrier or {}

    --These must be -1 so that when we check the top left corner tile of new chunks we generate both sides.
    global.WaterBarrier.barrierVectorEdgeMinCalculated = global.WaterBarrier.barrierVectorEdgeMinCalculated or -1 ---@type int
    global.WaterBarrier.barrierVectorEdgeMaxCalculated = global.WaterBarrier.barrierVectorEdgeMaxCalculated or -1 ---@type int

    -- Just placeholders so I can type them.
    global.WaterBarrier.waterChunkXStart = global.WaterBarrier.waterChunkXStart or nil ---@type int
    global.WaterBarrier.waterTileXMin = global.WaterBarrier.waterTileXMin or nil ---@type int
    global.WaterBarrier.waterTileXMax = global.WaterBarrier.waterTileXMax or nil ---@type int
    global.WaterBarrier.waterChunkYStart = global.WaterBarrier.waterChunkYStart or nil ---@type int
    global.WaterBarrier.waterTileYMin = global.WaterBarrier.waterTileYMin or nil ---@type int
    global.WaterBarrier.waterTileYMax = global.WaterBarrier.waterTileYMax or nil ---@type int
    global.WaterBarrier.waterInnerEdgeTiles = global.WaterBarrier.waterInnerEdgeTiles or nil ---@type table<int, int> @ Mapping of shoreline axis (x or y) to the distance the water is from the minimum position on the other axis.
    global.WaterBarrier.deepWaterInnerEdgeTiles = global.WaterBarrier.deepWaterInnerEdgeTiles or nil ---@type table<int, int> @ Mapping of shoreline axis (x or y) to the distance the deep water is from the minimum position on the other axis.
end

WaterBarrier.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "WaterBarrier", WaterBarrier.OnChunkGenerated)
end

WaterBarrier.OnStartup = function()
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
            global.WaterBarrier.waterChunkYStart = 0 + BarrierChunkStart
            global.WaterBarrier.waterTileYMin = global.WaterBarrier.waterChunkYStart * 32
            global.WaterBarrier.waterTileYMax = global.WaterBarrier.waterTileYMin + EdgeVariation
            global.WaterBarrier.waterInnerEdgeTiles = global.WaterBarrier.waterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterTileYMin + math.random(EdgeVariation)}
            global.WaterBarrier.deepWaterInnerEdgeTiles = global.WaterBarrier.deepWaterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterInnerEdgeTiles[-1] + math.random(FirstWaterTypeWidthMin, FirstWaterTypeWidthMax)}
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
            global.WaterBarrier.waterChunkXStart = 0 + BarrierChunkStart
            global.WaterBarrier.waterTileXMin = global.WaterBarrier.waterChunkXStart * 32
            global.WaterBarrier.waterTileXMax = global.WaterBarrier.waterTileXMin + EdgeVariation
            global.WaterBarrier.waterInnerEdgeTiles = global.WaterBarrier.waterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterTileXMin + math.random(EdgeVariation)}
            global.WaterBarrier.deepWaterInnerEdgeTiles = global.WaterBarrier.deepWaterInnerEdgeTiles or {[-1] = global.WaterBarrier.waterInnerEdgeTiles[-1] + math.random(FirstWaterTypeWidthMin, FirstWaterTypeWidthMax)}
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
end

---@param event on_chunk_generated
WaterBarrier.OnChunkGenerated = function(event)
    local leftTopTileInChunk = event.area.left_top
    local chunkPos = Utils.GetChunkPositionForTilePosition(leftTopTileInChunk)
    local surface = event.surface
    if WaterBarrier.IsChunkBeyondBarrierChunkStart(chunkPos) then
        WaterBarrier.CalculateShorelinesForVector(leftTopTileInChunk)
        WaterBarrier.ApplyBarrierTiles(leftTopTileInChunk, surface, chunkPos)
    end
end

---@param chunkPos ChunkPosition
---@return boolean
WaterBarrier.IsChunkBeyondBarrierChunkStart = function(chunkPos)
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
            if chunkPos.y >= global.WaterBarrier.waterChunkYStart then
                return true
            else
                return false
            end
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
            if chunkPos.x >= global.WaterBarrier.waterChunkXStart then
                return true
            else
                return false
            end
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
end

---@param leftTopTileInChunk MapPosition
WaterBarrier.CalculateShorelinesForVector = function(leftTopTileInChunk)
    local debug = false
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
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
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
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
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
end

---@param lastWaterDistance int
---@return int nextWaterDistance
WaterBarrier.GetNextWaterDistance = function(lastWaterDistance)
    local nextDistanceOptions = {lastWaterDistance}
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
            table.insert(nextDistanceOptions, math.random(math.max(global.WaterBarrier.waterTileYMin, lastWaterDistance - CoastlinePerTileVariation), math.min(global.WaterBarrier.waterTileYMax, lastWaterDistance + CoastlinePerTileVariation)))
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
            table.insert(nextDistanceOptions, math.random(math.max(global.WaterBarrier.waterTileXMin, lastWaterDistance - CoastlinePerTileVariation), math.min(global.WaterBarrier.waterTileXMax, lastWaterDistance + CoastlinePerTileVariation)))
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
    return nextDistanceOptions[math.random(#nextDistanceOptions)]
end

---@param lastWaterDistance int
---@param lastDeepWaterDistance int
---@return int nextDeepWaterDistance
WaterBarrier.GetNextDeepWaterDistance = function(lastWaterDistance, lastDeepWaterDistance)
    local nextDistanceOptions = {}
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
            local min = math.min(math.max(lastWaterDistance + FirstWaterTypeWidthMin, lastDeepWaterDistance - CoastlinePerTileVariation), lastWaterDistance + FirstWaterTypeWidthMax)
            local max = math.min(lastWaterDistance + FirstWaterTypeWidthMax, lastDeepWaterDistance + CoastlinePerTileVariation)
            table.insert(nextDistanceOptions, math.random(min, max))
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
            local min = math.min(math.max(lastWaterDistance + FirstWaterTypeWidthMin, lastDeepWaterDistance - CoastlinePerTileVariation), lastWaterDistance + FirstWaterTypeWidthMax)
            local max = math.min(lastWaterDistance + FirstWaterTypeWidthMax, lastDeepWaterDistance + CoastlinePerTileVariation)
            table.insert(nextDistanceOptions, math.random(min, max))
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
    return nextDistanceOptions[math.random(#nextDistanceOptions)]
end

---@param leftTopTileInChunk MapPosition
---@param surface LuaSurface
---@param chunkPos ChunkPosition
WaterBarrier.ApplyBarrierTiles = function(leftTopTileInChunk, surface, chunkPos)
    local tilesToChange = {}
    if BarrierOrientation == BarrierOrientations.horizontal then
        if barrierDirection == BarrierDirections.positive then
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
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.horizontal BarrierDirections.negative NOT DONE YET")
        end
    elseif BarrierOrientation == BarrierOrientations.vertical then
        if barrierDirection == BarrierDirections.positive then
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
        elseif barrierDirection == BarrierDirections.negative then
            Logging.LogPrint("BarrierOrientations.vertical BarrierDirections.negative NOT DONE YET")
        end
    end
    surface.set_tiles(tilesToChange)
    surface.regenerate_entity({"fish"}, {chunkPos})
end

return WaterBarrier
