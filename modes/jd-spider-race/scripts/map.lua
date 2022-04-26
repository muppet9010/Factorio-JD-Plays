local Map = {}

local Utils = require("utility/utils")
local Events = require("utility/events")

Map.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Map.OnChunkGenerated", Map.OnChunkGenerated)
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
end

--- Need to pale the market once the chunk at spawn has been generated.
---@param event on_chunk_generated
Map.OnChunkGenerated = function(event)
    if event.surface.name ~= global.general.surfaceName then
        -- Not our surface.
        return
    end

    -- If its the spawn chunk for a team create the market there.
    for _, team in pairs(global.playerHome.teams) do
        if event.area.left_top.x == team.spawnPosition.x and event.area.left_top.y == team.spawnPosition.y then
            -- Spawn point is in this chunk.
            Map.CreateMarketForTeam(team)
        end
    end
end

--- Create a market for the team at its spawn area. Fully configures the market.
---@param team JdSpiderRace_PlayerHome_Team
Map.CreateMarketForTeam = function(team)
    -- Add a market somewhere near spawn. But we don't want it on top of ore.
    local marketPosition = global.general.surface.find_non_colliding_position("jd_plays-jd_spider_race-market_placement_test", team.spawnPosition, 30, 1)
    if marketPosition == nil then
        error("No position found for market near spawn. UNACCEPTABLE")
    end
    local market = global.general.surface.create_entity {name = "market", position = marketPosition, force = team.playerForce, move_stuck_players = true}
    if market == nil then
        error("Market failed to create at found position. UNACCEPTABLE")
    end
    market.destructible = false

    -- Add our end of game item to the market. Use an item as then when its hovered in the market we can show a picture and text.
    market.add_market_item {price = {{"coin", 1}}, offer = {type = "give-item", item = "jd_plays-jd_spider_race-nuke_other_team"}}
end

return Map
