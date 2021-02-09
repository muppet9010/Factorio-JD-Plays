local Divider = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local EventScheduler = require("utility/event-scheduler")

Divider.CreateGlobals = function()
    global.divider = global.divider or {}
end

Divider.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Divider.OnChunkGenerated", Divider.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
end

Divider.OnStartup = function()
end

Divider.OnChunkGenerated = function(event)
    if event.position.x ~= 0 then
        return
    end

    -- Place the blocking land tiles down. Ignore water tiles as catch when landfill is placed.
    local surface, landTilesToReplace = event.surface, {}
    for x = 0, 1 do
        for y = event.area.left_top.y, event.area.left_top.y + 31 do
            local existingTileName = surface.get_tile(x, y).name
            if existingTileName ~= "water" and existingTileName ~= "deepwater" then
                table.insert(landTilesToReplace, {name = "jd_plays-jd_p0ober_split_factory-divider_tile_land", position = {x = x, y = y}})
            end
        end
    end
    surface.set_tiles(landTilesToReplace, true, true, false, false)

    -- Place the blocking entity in the center of the 2 tiles.
    for y = event.area.left_top.y, event.area.left_top.y + 31 do
        surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-divider_entity", position = {x = 1, y = y + 0.5}, create_build_effect_smoke = false, raise_built = false}
    end
end

Divider.OnTilePlaced = function(event)
    if event.tile.name ~= "landfill" then
        return
    end
    local surface, landTilesToReplace = game.surfaces[event.surface_index], {}
    for _, tileReplaced in pairs(event.tiles) do
        if tileReplaced.position.x == 0 or tileReplaced.position.x == 1 then
            table.insert(landTilesToReplace, {name = "jd_plays-jd_p0ober_split_factory-divider_tile_land", position = tileReplaced.position})
        end
    end
    if #landTilesToReplace > 0 then
        surface.set_tiles(landTilesToReplace, true, true, false, false)
    end
end

return Divider
