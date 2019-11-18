local GenerateTrees = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")

local treeChance = 0.2
local treesStartThiningChunkNegativeY = 0 - math.floor(100000 / 32)
local treesBecomeNothingChunkNegativeY = 0 - math.floor(150000 / 32)
local variationChunkDistance = treesBecomeNothingChunkNegativeY - treesStartThiningChunkNegativeY

GenerateTrees.OnLoad = function()
    Events.RegisterHandler(defines.events.on_chunk_generated, "GenerateTrees.OnChunkGenerated", GenerateTrees.OnChunkGenerated)
end

GenerateTrees.OnChunkGenerated = function(event)
    local chunkPos = Utils.GetChunkPositionForTilePosition(event.area.left_top)
    if chunkPos.y <= treesBecomeNothingChunkNegativeY then
        Logging.Log("Nothing: " .. chunkPos.y .. " <= " .. treesBecomeNothingChunkNegativeY, chunkPos.x == 0)
        return
    end

    local thisChunkTreeChance = treeChance
    if chunkPos.y <= treesStartThiningChunkNegativeY then
        local multiplier = (chunkPos.y - treesStartThiningChunkNegativeY) / variationChunkDistance
        thisChunkTreeChance = thisChunkTreeChance - (thisChunkTreeChance * multiplier)
    end
    local surface = event.surface
    local minX = event.area.left_top.x
    local minY = event.area.left_top.y
    local maxX = event.area.right_bottom.x
    local maxY = event.area.right_bottom.y

    local trees = {}
    if remote.interfaces["biter_reincarnation"] == nil then
        for _, entityType in pairs(game.entity_prototypes) do
            if entityType.type == "tree" then
                table.insert(trees, entityType.name)
            end
        end
    end

    for x = minX, maxX do
        for y = minY, maxY do
            if math.random() < thisChunkTreeChance then
                local position = {x, y}
                local tree_type
                if #trees > 0 then
                    tree_type = trees[math.random(#trees)]
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
