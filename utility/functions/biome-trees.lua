--[[
    Used to get tile (biome) approperiate trees, rather than just select any old tree. Means they will generally fit in to the map better, although vanilla forest types don't always fully match the biome they are in.
    Will only nicely handle vanilla and Alient Biomes tiles and trees, modded tiles will get a random tree if they are a land-ish type tile.
    Usage:
        - Require the file at usage locations.
        - Call the BiomeTrees.OnStartup() for script.on_init and script.on_configuration_changed. This will load the meta tables of the mod fresh from the current tiles and trees.
        - Call the desired functions when needed (non _ functions at top of file).
    Supports specifically coded modded trees with meta data. If a tree has tile restrictions this is used for selection after temp and water, otherwise the tags of tile and tree are checked. This logic comes from suppporting alien biomes.
]]
local Utils = require("utility.utils")
local Logging = require("utility.logging")

local BaseGameData = require("utility.functions.biome-trees-data.base-game")
local AlienBiomesData = require("utility.functions.biome-trees-data.alien-biomes")

local BiomeTrees = {}
local logNonPositives = false
local logPositives = false
local logData = false
local logTags = false

BiomeTrees.OnStartup = function()
    -- Always recreate on game startup/config changed to handle any mod changed trees, tiles, etc.
    global.UTILITYBIOMETREES = {}
    global.UTILITYBIOMETREES.environmentData = BiomeTrees._GetEnvironmentData()
    global.UTILITYBIOMETREES.tileData = global.UTILITYBIOMETREES.environmentData.tileData
    global.UTILITYBIOMETREES.treeData = BiomeTrees._GetTreeData()
    if logData then
        Logging.LogPrint(serpent.block(global.UTILITYBIOMETREES.treeData))
        Logging.LogPrint(serpent.block(global.UTILITYBIOMETREES.tileData))
    end
end

BiomeTrees.GetBiomeTreeName = function(surface, position)
    -- Returns the tree name or nil if tile isn't land type
    local tile = surface.get_tile(position)
    local tileData = global.UTILITYBIOMETREES.tileData[tile.name]
    if tileData == nil then
        local tileName = tile.hidden_tile
        tileData = global.UTILITYBIOMETREES.tileData[tileName]
        if tileData == nil then
            Logging.LogPrint("Failed to get tile data for ''" .. tostring(tile.name) .. "'' and hidden tile '" .. tostring(tileName) .. "'", logNonPositives)
            return BiomeTrees.GetRandomTreeLastResort(tile)
        end
    end
    if tileData.type ~= "allow-trees" then
        return nil
    end

    local rangeInt = math.random(1, #tileData.tempRanges)
    local tempRange = tileData.tempRanges[rangeInt]
    local moistureRange = tileData.moistureRanges[rangeInt]
    local tileTemp = BiomeTrees._CalculateTileTemp(Utils.GetRandomFloatInRange(tempRange[1], tempRange[2]))
    local tileMoisture = Utils.GetRandomFloatInRange(moistureRange[1], moistureRange[2])

    local suitableTrees = BiomeTrees._SearchForSuitableTrees(tileData, tileTemp, tileMoisture)
    if #suitableTrees == 0 then
        Logging.LogPrint("No tree found for conditions: tile: " .. tileData.name .. "   temp: " .. tileTemp .. "    moisture: " .. tileMoisture, logNonPositives)
        return BiomeTrees.GetRandomTreeLastResort(tile)
    end
    Logging.LogPrint("trees found for conditions: tile: " .. tileData.name .. "   temp: " .. tileTemp .. "    moisture: " .. tileMoisture, logPositives)

    local highestChance, treeName, treeFound = suitableTrees[#suitableTrees].chanceEnd, nil, false
    local chanceValue = math.random() * highestChance
    for _, treeEntry in pairs(suitableTrees) do
        if chanceValue >= treeEntry.chanceStart and chanceValue <= treeEntry.chanceEnd then
            treeName = treeEntry.tree.name
            treeFound = true
            break
        end
    end
    if not treeFound then
        return nil
    end

    return treeName
end

BiomeTrees.AddBiomeTreeNearPosition = function(surface, position, distance)
    -- Returns the tree entity if one found and created or nil
    local treeType = BiomeTrees.GetBiomeTreeName(surface, position)
    if treeType == nil then
        Logging.LogPrint("no tree was found", logNonPositives)
        return nil
    end
    local newPosition = surface.find_non_colliding_position(treeType, position, distance, 0.2)
    if newPosition == nil then
        Logging.LogPrint("No position for new tree found", logNonPositives)
        return nil
    end
    local newTree = surface.create_entity {name = treeType, position = newPosition, force = "neutral", raise_built = true, create_build_effect_smoke = false}
    if newTree == nil then
        Logging.LogPrint("Failed to create tree at found position")
        return nil
    end
    Logging.LogPrint("tree added successfully, type: " .. treeType .. "    position: " .. newPosition.x .. ", " .. newPosition.y, logPositives)
    return newTree
end

BiomeTrees.GetRandomDeadTree = function(tile)
    if tile ~= nil and tile.collides_with("player-layer") then
        -- Is a non-land tile
        return nil
    else
        return global.UTILITYBIOMETREES.environmentData.deadTreeNames[math.random(#global.UTILITYBIOMETREES.environmentData.deadTreeNames)]
    end
end

BiomeTrees.GetTruelyRandomTree = function(tile)
    if tile ~= nil and tile.collides_with("player-layer") then
        -- Is a non-land tile
        return nil
    else
        return global.UTILITYBIOMETREES.treeData[math.random(#global.UTILITYBIOMETREES.treeData)].name
    end
end

BiomeTrees.GetRandomTreeLastResort = function(tile)
    -- Gets the a tree from the list of last resort based on the mod active.
    if global.UTILITYBIOMETREES.environmentData.randomTreeLastResort == "GetTruelyRandomTree" then
        return BiomeTrees.GetTruelyRandomTree(tile)
    elseif global.UTILITYBIOMETREES.environmentData.randomTreeLastResort == "GetRandomDeadTree" then
        return BiomeTrees.GetRandomDeadTree(tile)
    end
end

BiomeTrees._SearchForSuitableTrees = function(tileData, tileTemp, tileMoisture)
    local suitableTrees = {}
    local currentChance = 0
    -- Try to ensure we find a tree vaguely accurate. Start as accurate as possible and then become less precise.
    for accuracy = 1, 1.5, 0.1 do
        for _, tree in pairs(global.UTILITYBIOMETREES.treeData) do
            if tileTemp >= tree.tempRange[1] / accuracy and tileTemp <= tree.tempRange[2] * accuracy and tileMoisture >= tree.moistureRange[1] / accuracy and tileMoisture <= tree.moistureRange[2] * accuracy then
                local include = false
                if not Utils.IsTableEmpty(tree.tile_restrictions) then
                    if tree.tile_restrictions[tileData.name] then
                        Logging.LogPrint("tile restrictons match", logTags)
                        include = true
                    end
                else
                    if Utils.IsTableEmpty(tileData.tags) then
                        include = true
                    elseif not Utils.IsTableEmpty(tree.tags) then
                        for tileTag in pairs(tileData.tags) do
                            if tree.tags[tileTag] then
                                Logging.LogPrint("tile tags: " .. Utils.TableKeyToCommaString(tileData.tags) .. "  --- tree tags: " .. Utils.TableKeyToCommaString(tree.tags), logTags)
                                include = true
                                break
                            end
                        end
                    end
                end

                if (include) then
                    local treeEntry = {
                        chanceStart = currentChance,
                        chanceEnd = currentChance + tree.probability,
                        tree = tree
                    }
                    table.insert(suitableTrees, treeEntry)
                    currentChance = treeEntry.chanceEnd
                end
            end
        end
        if #suitableTrees > 0 then
            Logging.LogPrint(#suitableTrees .. " found on accuracy: " .. accuracy, logPositives)
            break
        end
    end

    return suitableTrees
end

BiomeTrees._GetEnvironmentData = function()
    -- Used to handle the differing tree to tile value relationships of mods vs base game.
    local environmentData = {}
    if game.active_mods["alien-biomes"] then
        environmentData.moistureRangeAttributeName = {optimal = "water_optimal", range = "water_max_range"}
        environmentData.tileTempCalculations = {
            -- on scale of -0.5 to 1.5 = -50 to 150. -15 is lowest temp tree +125 is highest temp tree.
            scaleMultiplyer = 100,
            max = 125,
            min = -15
        }
        environmentData.tileData = BiomeTrees._AddTilesDetails(AlienBiomesData.GetTileData())
        local tagToColors = AlienBiomesData.GetTileTagToTreeColors()
        for _, tile in pairs(environmentData.tileData) do
            if tile.tags ~= nil then
                if tagToColors[tile.tags] then
                    tile.tags = tagToColors[tile.tags]
                else
                    Logging.LogPrint("Failed to find tile to tree colour mapping for tile tag: ' " .. tile.tags .. "'")
                end
            end
        end
        environmentData.treeMetaData = AlienBiomesData.GetTreeMetaData()
        environmentData.deadTreeNames = {"dead-tree-desert", "dead-grey-trunk", "dead-dry-hairy-tree", "dry-hairy-tree", "dry-tree"}
        environmentData.randomTreeLastResort = "GetRandomDeadTree"
    else
        environmentData.moistureRangeAttributeName = {optimal = "water_optimal", range = "water_range"}
        environmentData.tileTempCalculations = {
            -- on scale of 0 to 1 = 0 to 35. 5 is the lowest tempt tree.
            scaleMultiplyer = 35,
            min = 5
        }
        environmentData.tileData = BiomeTrees._AddTilesDetails(BaseGameData.GetTileData())
        environmentData.treeMetaData = {}
        environmentData.deadTreeNames = {"dead-tree-desert", "dead-grey-trunk", "dead-dry-hairy-tree", "dry-hairy-tree", "dry-tree"}
        environmentData.randomTreeLastResort = "GetTruelyRandomTree"
    end

    return environmentData
end

BiomeTrees._GetTreeData = function()
    local treeDataArray, treeData = {}, {}
    local environmentData = global.UTILITYBIOMETREES.environmentData
    local moistureRangeAttributeName = global.UTILITYBIOMETREES.environmentData.moistureRangeAttributeName
    local treeEntities = game.get_filtered_entity_prototypes({{filter = "type", type = "tree"}, {mode = "and", filter = "autoplace"}})

    for _, prototype in pairs(treeEntities) do
        Logging.LogPrint(prototype.name, logData)
        local autoplace = nil
        for _, peak in pairs(prototype.autoplace_specification.peaks) do
            if peak.temperature_optimal ~= nil or peak[moistureRangeAttributeName.optimal] ~= nil then
                autoplace = peak
                break
            end
        end

        if autoplace ~= nil then
            -- Use really wide range defaults for missing moisture values as likely unspecified by mods to mean ALL.
            treeData = {
                name = prototype.name,
                tempRange = {
                    (autoplace.temperature_optimal or 0) - (autoplace.temperature_range or 0),
                    (autoplace.temperature_optimal or 1) + (autoplace.temperature_range or 0)
                },
                moistureRange = {
                    (autoplace[moistureRangeAttributeName.optimal] or 0) - (autoplace[moistureRangeAttributeName.range] or 0),
                    (autoplace[moistureRangeAttributeName.optimal] or 1) + (autoplace[moistureRangeAttributeName.range] or 0)
                },
                probability = prototype.autoplace_specification.max_probability or 0.01
            }
            if environmentData.treeMetaData[prototype.name] ~= nil then
                treeData.tags = environmentData.treeMetaData[prototype.name][1]
                treeData.tile_restrictions = environmentData.treeMetaData[prototype.name][2]
            end
            table.insert(treeDataArray, treeData)
        end
    end

    return treeDataArray
end

BiomeTrees._AddTileDetails = function(tileDetails, tileName, type, range1, range2, tags)
    local tempRanges = {}
    local moistureRanges = {}
    if range1 ~= nil then
        table.insert(tempRanges, {range1[1][1] or 0, range1[2][1] or 0})
        table.insert(moistureRanges, {range1[1][2] or 0, range1[2][2] or 0})
    end
    if range2 ~= nil then
        table.insert(tempRanges, {range2[1][1] or 0, range2[2][1] or 0})
        table.insert(moistureRanges, {range2[1][2] or 0, range2[2][2] or 0})
    end
    tileDetails[tileName] = {name = tileName, type = type, tempRanges = tempRanges, moistureRanges = moistureRanges, tags = tags}
end

BiomeTrees._AddTilesDetails = function(tilesDetails)
    local tileDetails = {}
    for name, details in pairs(tilesDetails) do
        BiomeTrees._AddTileDetails(tileDetails, name, details[1], details[2], details[3], details[4])
    end
    return tileDetails
end

BiomeTrees._CalculateTileTemp = function(tempBase)
    local tileTempCalculations = global.UTILITYBIOMETREES.environmentData.tileTempCalculations
    local temp = tempBase
    if tileTempCalculations.scaleMultiplyer ~= nil then
        temp = temp * tileTempCalculations.scaleMultiplyer
    end
    if tileTempCalculations.max ~= nil then
        temp = math.min(tileTempCalculations.max, temp)
    end
    if tileTempCalculations.min ~= nil then
        temp = math.max(tileTempCalculations.min, temp)
    end
    return temp
end

return BiomeTrees
