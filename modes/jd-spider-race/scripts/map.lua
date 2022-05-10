--[[
    Notes:
        - The divider part is based on a copy of an older divider feature from the JD-Plays mod with many changes and additions made to it.
]]
--

local Map = {}

local Utils = require("utility/utils")
local Events = require("utility/events")
local EventScheduler = require("utility.event-scheduler")
local Colors = require("utility.colors")

Map.CreateGlobals = function()
    global.map = global.map or {}
    -- The divider must all be within 1 chunk
    -- Placing the divider at exactly 0, gives an even gap for ribbon world
    global.map.dividerStartYPos = global.map.dividerStartYPos or -1 -- Y pos in world of divide tiles start.
    global.map.dividerEndYPos = global.map.dividerEndYPos or 0 -- Y pos in world of divide tiles end.
    global.map.dividerMiddleYPos = global.map.dividerMiddleYPos or 0 -- Y Pos of divide entity.
    global.map.chunkYPos = global.map.chunkYPos or 0 -- Chunk Y pos when looking for chunks generated.
end

Map.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Map.OnChunkGenerated", Map.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_player_built_tile, "Map.OnTilePlaced", Map.OnTilePlaced)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_tile, "Map.OnTilePlaced", Map.OnTilePlaced)
    EventScheduler.RegisterScheduledEventType("Map.CheckForDivideCrossedPlayers_Scheduled", Map.CheckForDivideCrossedPlayers_Scheduled)
end

Map.OnStartup = function()
    -- Create the surface with the same parameters as nauvis.
    if global.general.surface == nil then
        -- Use the nauvis settings, but with dual spawn.
        local map_gen_settings = Utils.DeepCopy(game.surfaces["nauvis"].map_gen_settings)
        map_gen_settings.starting_points = {
            global.playerHome.teams["north"].spawnPosition,
            global.playerHome.teams["south"].spawnPosition
        }
        map_gen_settings.height = global.general.perTeamMapHeight * 2
        map_gen_settings.water = 0 -- Disable water on the map.

        global.general.surface = game.create_surface(global.general.surfaceName, map_gen_settings)

        -- Set spawn points of our player forces and request the spawn chunks are generated quickly so players can be teleported there very soon.
        for _, team in pairs(global.playerHome.teams) do
            team.playerForce.set_spawn_position(team.spawnPosition, global.general.surface)
            global.general.surface.request_to_generate_chunks(team.spawnPosition, 1)
        end
    end

    -- Make sure a player on wrong side of divide is scheduled.
    if not EventScheduler.IsEventScheduledOnce("Map.CheckForDivideCrossedPlayers_Scheduled", nil, nil) then
        EventScheduler.ScheduleEventOnce(game.tick + 18000, "Map.CheckForDivideCrossedPlayers_Scheduled")
    end
end

--- Called for every chunk being generated on the map.
---@param event on_chunk_generated
Map.OnChunkGenerated = function(event)
    if event.surface.name ~= global.general.surfaceName then
        -- Not our surface.
        return
    end

    -- Check if for either team this is the chunk south east 1 chunk of spawn chunk. As if so then the spawn chunk for that team is generated and we can place their market now.
    for _, team in pairs(global.playerHome.teams) do
        if event.position.x == team.spawnChunk.x + 1 and event.position.y == team.spawnChunk.y + 1 then
            -- Chunk is 1 chunk south eastof the team's spawn chunk.
            Map.CreateMarketForTeam(team, {x = event.area.left_top.x - 16, y = event.area.left_top.y - 16})
        end
    end

    -- Force biters to be on the correct force
    local position
    for _, base_entity in pairs(event.surface.find_entities_filtered({area = event.area, force = "enemy"})) do
        if base_entity.valid then
            position = base_entity.position

            -- If the nest/worm is centered near the divide then remove it. As otherwise its biters can spawn on the wrong side of the divide and mess up group behaviour.
            -- Otherwise set the force to be correct based on which side of the divide it is.
            if position.y >= -5 and position.y <= 5 then
                -- Remove it.
                base_entity.destroy({raise_destroy = true})
            else
                -- Set the buildings force to be correct.
                if position.y <= 0 then
                    base_entity.force = "north_enemy"
                else
                    base_entity.force = "south_enemy"
                end
            end
        end
    end

    -- Place the divider parts if approperiate.
    -- This requires both tiles and entity to all be in the same chunk. So not centered down chunk border.
    if event.position.y == global.map.chunkYPos then
        Map.PlaceTeamDividerForChunkGenerated(event.surface, event.area)
    end
end

--- Create a market for the team at its spawn area. Fully configures the market.
---@param team JdSpiderRace_PlayerHome_Team
---@param spawnChunkCenterPosition MapPosition
Map.CreateMarketForTeam = function(team, spawnChunkCenterPosition)
    -- Add a market within the spawn chunk or one of the sorrounding chunks. It won't create on top of ore (resources), entities or water.
    -- CODE NOTE: Have to limit to a distance within spawn chunk and 1 chunk around it, as the chunks are generated in an outward spiral from spawn chunk.
    local marketPosition = global.general.surface.find_non_colliding_position("jd_plays-jd_spider_race-market_placement_test", spawnChunkCenterPosition, 40, 1)
    if marketPosition == nil then
        error("No position found for market near spawn. UNACCEPTABLE")
        return
    end
    local market = global.general.surface.create_entity {name = "market", position = marketPosition, force = team.playerForce, move_stuck_players = true}
    if market == nil then
        error("Market failed to create at found position. UNACCEPTABLE")
        return
    end
    market.destructible = false

    -- Add our end of game item to the market. Use an item as then when its hovered in the market we can show a picture and text.
    market.add_market_item {price = {{"coin", 1}}, offer = {type = "give-item", item = "jd_plays-jd_spider_race-nuke_other_team"}}
end

---@param surface LuaSurface
---@param area BoundingBox
Map.PlaceTeamDividerForChunkGenerated = function(surface, area)
    -- Place the blocking land tiles down. Ignore water tiles as catch when landfill is placed.
    -- Check beyond this chunk in the next 3 partially generated chunks (map gen weirdness) and fill them with our blocking tiles. Stops biters pathing around the top/bottom of the partially generated map.
    local landTilesToReplace = {}
    local xMin, xMax
    if area.left_top.x >= 0 then
        xMin = area.left_top.x
        xMax = area.left_top.x + 31 + 96
    else
        xMin = area.left_top.x - 96
        xMax = area.left_top.x + 31
    end
    for y = global.map.dividerStartYPos, global.map.dividerEndYPos do
        for x = xMin, xMax do
            local existingTileName = surface.get_tile(x, y).name
            if existingTileName ~= "water" and existingTileName ~= "deepwater" and existingTileName ~= "jd_plays-jd_spider_race-divider_tile_land" then
                table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = {x = x, y = y}})
            end
        end
    end
    surface.set_tiles(landTilesToReplace, true, true, false, false)

    -- Place the blocking entities in the center of the 2 tiles.
    for x = area.left_top.x, area.left_top.x + 31 do
        local dividerEntity = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity", position = {x = x + 0.5, y = global.map.dividerMiddleYPos}, force = "neutral", create_build_effect_smoke = false, raise_built = false}
        dividerEntity.destructible = false
        local dividerEntitySpider = surface.create_entity {name = "jd_plays-jd_spider_race-divider_entity_spider_block", position = {x = x + 0.5, y = global.map.dividerMiddleYPos}, force = "neutral", create_build_effect_smoke = false, raise_built = false}
        dividerEntitySpider.destructible = false
    end

    -- Place the beam effect. Overlap by a tile as we have overlaped all the graphics bits of the beam prototype.
    surface.create_entity {name = "jd_plays-jd_spider_race-divider_beam", position = {0, 0}, target_position = {x = area.left_top.x - 1, y = global.map.dividerMiddleYPos}, source_position = {x = area.left_top.x + 33, y = global.map.dividerMiddleYPos}, force = "neutral"}
end

---@param event on_player_built_tile|on_robot_built_tile
Map.OnTilePlaced = function(event)
    if event.tile.name ~= "landfill" then
        return
    end
    local surface, landTilesToReplace = game.surfaces[event.surface_index], {}
    for _, tileReplaced in pairs(event.tiles) do
        if tileReplaced.position.y >= global.map.dividerStartYPos and tileReplaced.position.y <= global.map.dividerEndYPos then
            table.insert(landTilesToReplace, {name = "jd_plays-jd_spider_race-divider_tile_land", position = tileReplaced.position})
        end
    end
    if #landTilesToReplace > 0 then
        surface.set_tiles(landTilesToReplace, true, true, false, false)
    end
end

--- Check for any players who have ended up on the wrong side of the divide and bring them home.
---@param event UtilityScheduledEvent_CallbackObject
Map.CheckForDivideCrossedPlayers_Scheduled = function(event)
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

                correctYPos = nil -- Reset for next players check.
            end
        end
    end

    -- Reschedule for another 5 minutes time.
    EventScheduler.ScheduleEventOnce(event.tick + 18000, "Map.CheckForDivideCrossedPlayers_Scheduled")
end

return Map
