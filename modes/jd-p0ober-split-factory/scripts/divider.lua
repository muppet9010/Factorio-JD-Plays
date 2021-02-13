local Divider = {}
local Events = require("utility/events")

Divider.CreateGlobals = function()
    global.divider = global.divider or {}
    -- The divider must all be within 1 chunk
    global.divider.dividerStartXPos = global.divider.dividerStartXPos or -18 -- X pos in world of divide tiles start.
    global.divider.dividerEndXPos = global.divider.dividerEndXPos or -17 -- X pos in world of divide tiles end.
    global.divider.dividerMiddleXPos = global.divider.dividerMiddleXPos or -17 -- X Pos of divide entity.
    global.divider.chunkXPos = global.divider.chunkXPos or -1 -- Chunk X pos when looking for chunks generated.
end

Divider.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Divider.OnChunkGenerated", Divider.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
end

Divider.OnChunkGenerated = function(event)
    -- This requires both tiles and entity to all be in the same chunk. So not centered down chunk border.
    if event.position.x ~= global.divider.chunkXPos then
        return
    end

    -- Place the blocking land tiles down. Ignore water tiles as catch when landfill is placed.
    -- Check beyond this chunk in the next 3 partially generated chunks (map gen weirdness) and fill them with our blocking tiles. Stops biters pathing around the top/bottom of the partially generated map.
    local surface, landTilesToReplace = event.surface, {}
    local yMin, yMax
    if event.area.left_top.y >= 0 then
        yMin = event.area.left_top.y
        yMax = event.area.left_top.y + 31 + 96
    else
        yMin = event.area.left_top.y - 96
        yMax = event.area.left_top.y + 31
    end
    for x = global.divider.dividerStartXPos, global.divider.dividerEndXPos do
        for y = yMin, yMax do
            local existingTileName = surface.get_tile(x, y).name
            if existingTileName ~= "water" and existingTileName ~= "deepwater" and existingTileName ~= "jd_plays-jd_p0ober_split_factory-divider_tile_land" then
                table.insert(landTilesToReplace, {name = "jd_plays-jd_p0ober_split_factory-divider_tile_land", position = {x = x, y = y}})
            end
        end
    end
    surface.set_tiles(landTilesToReplace, true, true, false, false)

    -- Place the blocking entities in the center of the 2 tiles.
    for y = event.area.left_top.y, event.area.left_top.y + 31 do
        local dividerEntity = surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-divider_entity", position = {x = global.divider.dividerMiddleXPos, y = y + 0.5}, create_build_effect_smoke = false, raise_built = false}
        dividerEntity.destructible = false
        local dividerEntitySpider = surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-divider_entity_spider_block", position = {x = global.divider.dividerMiddleXPos, y = y + 0.5}, create_build_effect_smoke = false, raise_built = false}
        dividerEntitySpider.destructible = false
    end

    -- Place the beam effect. Overlap by a tile as we have overlaped all the graphics bits of the beam prototype.
    surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-divider_beam", position = {0, 0}, target_position = {x = global.divider.dividerMiddleXPos, y = event.area.left_top.y - 1}, source_position = {x = global.divider.dividerMiddleXPos, y = event.area.left_top.y + 33}}
end

Divider.OnTilePlaced = function(event)
    if event.tile.name ~= "landfill" then
        return
    end
    local surface, landTilesToReplace = game.surfaces[event.surface_index], {}
    for _, tileReplaced in pairs(event.tiles) do
        if tileReplaced.position.x >= global.divider.dividerStartXPos and tileReplaced.position.x <= global.divider.dividerEndXPos then
            table.insert(landTilesToReplace, {name = "jd_plays-jd_p0ober_split_factory-divider_tile_land", position = tileReplaced.position})
        end
    end
    if #landTilesToReplace > 0 then
        surface.set_tiles(landTilesToReplace, true, true, false, false)
    end
end

return Divider
