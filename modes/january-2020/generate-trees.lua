local GenerateTrees = {}
local Events = require("utility/events")
--local Logging = require("utility/logging")

local treeChance = 0.1

GenerateTrees.CreateGlobals = function()
    global.randomTrees = global.randomTrees or nil
end

GenerateTrees.OnLoad = function()
    Events.RegisterHandler(defines.events.on_chunk_generated, "GenerateTrees.OnChunkGenerated", GenerateTrees.OnChunkGenerated)
end

GenerateTrees.PopulateRandomTrees = function()
    global.randomTrees = {}
    for _, entityType in pairs(game.entity_prototypes) do
        if entityType.type == "tree" then
            table.insert(global.randomTrees, entityType.name)
        end
    end
end

GenerateTrees.OnChunkGenerated = function(event)
    local area = event.area
    local thisChunkTreeChance = treeChance
    local surface = event.surface
    local minX = area.left_top.x
    local minY = area.left_top.y
    local maxX = area.right_bottom.x
    local maxY = area.right_bottom.y

    if global.randomTrees == nil then
        GenerateTrees.PopulateRandomTrees()
    end

    for x = minX, maxX do
        for y = minY, maxY do
            if math.random() < thisChunkTreeChance then
                local position = {x, y}
                local tree_type
                if remote.interfaces["biter_reincarnation"] == nil then
                    tree_type = global.randomTrees[math.random(#global.randomTrees)]
                else
                    tree_type = remote.call("biter_reincarnation", "get_random_tree_type_for_position", surface, position)
                end
                if tree_type ~= nil and surface.can_place_entity {name = tree_type, position = position} then
                    surface.create_entity {name = tree_type, position = position}
                end
            end
        end
    end
end

return GenerateTrees
