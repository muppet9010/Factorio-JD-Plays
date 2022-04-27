--[[
    Notes:
        - This is based on a copy of an older divider feature from the JD-Plays mod with many changes and additions made to it.
]]
--

local Divider = {}
local Events = require("utility/events")
local EventScheduler = require("utility.event-scheduler")
local Colors = require("utility.colors")

Divider.CreateGlobals = function()
    global.divider = global.divider or {}
    -- The divider must all be within 1 chunk
    -- Placing the divider at exactly 0, gives an even gap for ribbon world
    global.divider.dividerStartYPos = global.divider.dividerStartYPos or -1 -- Y pos in world of divide tiles start.
    global.divider.dividerEndYPos = global.divider.dividerEndYPos or 0 -- Y pos in world of divide tiles end.
    global.divider.dividerMiddleYPos = global.divider.dividerMiddleYPos or 0 -- Y Pos of divide entity.
    global.divider.chunkYPos = global.divider.chunkYPos or 0 -- Chunk Y pos when looking for chunks generated.
end

Divider.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Divider.OnChunkGenerated", Divider.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_tile, "Divider.OnTilePlaced", Divider.OnTilePlaced)
    EventScheduler.RegisterScheduledEventType("Divider.CheckForDivideCrossedPlayers_Scheduled", Divider.CheckForDivideCrossedPlayers_Scheduled)
end

Divider.OnStartup = function()
    -- Make sure a player on wrong side of divide is scheduled.
    if not EventScheduler.IsEventScheduledOnce(Divider.CheckForDivideCrossedPlayers_Scheduled, nil, nil) then
        EventScheduler.ScheduleEventOnce(game.tick + 18000, "Divider.CheckForDivideCrossedPlayers_Scheduled")
    end
end

---@param event on_chunk_generated
Divider.OnChunkGenerated = function(event)
    local surface, area = event.surface, event.area

    -- Force biters to be on the correct force
    for _, base_entity in pairs(surface.find_entities_filtered({area = area, force = "enemy"})) do
        if base_entity.valid then
            if base_entity.position.y <= 0 then
                base_entity.force = "north_enemy"
            else
                base_entity.force = "south_enemy"
            end
        end
    end

    -- This requires both tiles and entity to all be in the same chunk. So not centered down chunk border.
    if event.position.y ~= global.divider.chunkYPos then
        return
    end

    -- Place the blocking land tiles down. Ignore water tiles as catch when landfill is placed.
    -- Check beyond this chunk in the next 3 partially generated chunks (map gen weirdness) and fill them with our blocking tiles. Stops biters pathing around the top/bottom of the partially generated map.
    local landTilesToReplace = {}
    local xMin, xMax
    if event.area.left_top.x >= 0 then
        xMin = event.area.left_top.x
        xMax = event.area.left_top.x + 31 + 96
    else
        xMin = event.area.left_top.x - 96
        xMax = event.area.left_top.x + 31
    end
    for y = global.divider.dividerStartYPos, global.divider.dividerEndYPos do
        for x = xMin, xMax do
            local existingTileName = surface.get_tile(x, y).name
            if existingTileName ~= "water" and existingTileName ~= "deepwater" and existingTileName ~= "jd_plays-jd_spider_race-divider_tile_land" then
                table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = {x = x, y = y}})
            end
        end
    end
    surface.set_tiles(landTilesToReplace, true, true, false, false)

    -- Place the blocking entities in the center of the 2 tiles.
    for x = event.area.left_top.x, event.area.left_top.x + 31 do
        local dividerEntity = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity", position = {x = x + 0.5, y = global.divider.dividerMiddleYPos}, create_build_effect_smoke = false, raise_built = false}
        dividerEntity.destructible = false
        local dividerEntitySpider = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity_spider_block", position = {x = x + 0.5, y = global.divider.dividerMiddleYPos}, create_build_effect_smoke = false, raise_built = false}
        dividerEntitySpider.destructible = false
    end

    -- Place the beam effect. Overlap by a tile as we have overlaped all the graphics bits of the beam prototype.
    surface.create_entity {name = "jd_plays-jd_spider_race-divider_beam", position = {0, 0}, target_position = {x = event.area.left_top.x - 1, y = global.divider.dividerMiddleYPos}, source_position = {x = event.area.left_top.x + 33, y = global.divider.dividerMiddleYPos}}
end

---@param event on_player_built_tile|on_robot_built_tile
Divider.OnTilePlaced = function(event)
    if event.tile.name ~= "landfill" then
        return
    end
    local surface, landTilesToReplace = game.surfaces[event.surface_index], {}
    for _, tileReplaced in pairs(event.tiles) do
        if tileReplaced.position.y >= global.divider.dividerStartYPos and tileReplaced.position.y <= global.divider.dividerEndYPos then
            table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = tileReplaced.position})
        end
    end
    if #landTilesToReplace > 0 then
        surface.set_tiles(landTilesToReplace, true, true, false, false)
    end
end

--- Check for any players who have ended up on the wrong side of the divide and bring them home.
---@param event UtilityScheduledEvent_CallbackObject
Divider.CheckForDivideCrossedPlayers_Scheduled = function(event)
    -- Check each connected player if they are on the wrong side and fix it if they are.
    ---@typelist JdSpiderRace_PlayerHome_Team, MapPosition, int, LuaEntity, MapPosition
    local team, player_position, correctYPos, teleportEntity, teleportTarget
    for _, player in pairs(game.connected_players) do
        team = global.playerHome.playerIdToTeam[player.index]
        if team ~= nil then
            -- Player is on a team and not in the waiting room.
            player_position = player.position
            if team.id == "north" and player_position.y > 0 then
                correctYPos = -20
            elseif team.id == "south" and player_position.y < 0 then
                correctYPos = 20
            end

            if correctYPos ~= nil then
                -- Player on wrong side, so send them back to their side.
                teleportEntity = player.vehicle or player.character

                -- Teleport back the player's vehicle or character if they have either. If they're dead then they will respawn on their side anyways.
                if teleportEntity ~= nil then
                    teleportTarget = global.general.surface.find_non_colliding_position(teleportEntity.name, {x = player_position.x, y = correctYPos}, 100, 0.5)
                    if teleportTarget ~= nil then
                        teleportEntity.teleport(teleportTarget)
                        game.print({"message.jd_plays-jd_spider_race-moved_player_right_side_of_divide", player.name}, Colors.lightgreen)
                    else
                        game.print("ERROR: failed to teleport player " .. player.name .. " back to their side of the divide for their " .. teleportEntity.name, Colors.lightred)
                    end
                end

                correctXPos, teleportEntity, teleportTarget = nil, nil, nil -- Reset for next players check.
            end
        end
    end

    -- Reschedule for another 5 minutes time.
    EventScheduler.ScheduleEventOnce(event.tick + 18000, "Divider.CheckForDivideCrossedPlayers_Scheduled")
end

return Divider
