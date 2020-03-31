local MapCleanse = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
--local Logging = require("utility/logging")

local cleanseFrom = math.floor(-100000 / 32)
local cleanseBehind = math.floor(50000 / 32)

MapCleanse.CreateGlobals = function()
    global.MapCleanse = global.MapCleanse or {}
    global.MapCleanse.yChunksDone = global.MapCleanse.yChunksDone or {}
end

MapCleanse.OnLoad = function()
    Events.RegisterHandler(defines.events.on_chunk_generated, "MapCleanse.OnChunkGenerated", MapCleanse.OnChunkGenerated)
end

MapCleanse.OnChunkGenerated = function(event)
    local chunksYValue = Utils.GetChunkPositionForTilePosition(event.area.left_top).y
    local cleanseY = chunksYValue + cleanseBehind
    local surface = event.surface
    if global.MapCleanse.yChunksDone[chunksYValue] ~= nil then
        MapCleanse.CleanseArea(event.area, surface)
    end
    if cleanseY > cleanseFrom or global.MapCleanse.yChunksDone[cleanseY] ~= nil then
        return
    end
    global.MapCleanse.yChunksDone[cleanseY] = true
    local cleanseArea = {
        left_top = {
            x = 0 - game.default_map_gen_settings.width,
            y = cleanseY * 32
        },
        right_bottom = {
            x = game.default_map_gen_settings.width,
            y = (cleanseY * 32) + 32
        }
    }
    MapCleanse.CleanseArea(cleanseArea, surface)
end

MapCleanse.CleanseArea = function(area, surface)
    surface.destroy_decoratives({area = area})
    local entityTypesToRemove = surface.find_entities_filtered({area = area, type = {"tree", "corpse", "simple-entity", "resource", "cliff"}})
    for _, entity in pairs(entityTypesToRemove) do
        entity.destroy()
    end
    local entityNamesToRemove = surface.find_entities_filtered({area = area, name = {"item-on-ground", "fish"}})
    for _, entity in pairs(entityNamesToRemove) do
        entity.destroy()
    end
end

return MapCleanse
