local PlayerHome = {}

local Commands = require("utility/commands")
local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Logging = require("utility/logging")
local Utils = require("utility/utils")

local SpawnYOffset = 100
local SpawnXOffset = -100

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}

    global.playerHome.teams = global.playerHome.teams or {}
    --[[
        [id] = {
            id = string team of either "north" or "south".
            spawnPosition = position of this team's spawn.
            playerIds = table of the player ids who have joined this team.
            playerNames = table of player names who will join this team on first connect.
            otherTeam = ref to the other teams global object.
        }
    ]]
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {}
    global.playerHome.waitingRoomPlayers = global.playerHome.waitingRoomPlayers or {}

end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_surface_created, "PlayerHome.OnSurfaceCreated", PlayerHome.OnSurfaceCreated)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
    Events.RegisterHandlerEvent(defines.events.on_marked_for_deconstruction, "PlayerHome.OnMarkedForDeconstruction", PlayerHome.OnMarkedForDeconstruction)
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "PlayerHome.OnBuiltEntity", PlayerHome.OnBuiltEntity)

    -- use direct api as micro optimization
    Events.RegisterHandlerEvent(defines.events.on_entity_damaged, "PlayerHome.OnEntityDamaged", PlayerHome.OnEntityDamaged, {
        -- Don't give us biter damage events
        -- Worms are "turrents". So this filter doesn't include them :(
        {filter = "type", type = "unit", invert = true},
        {filter = "type", type = "unit-spawner", invert = true, mode = "and"},
    })

    Commands.Register("jd_spider_race_team", "Assign <player> to team <team>", PlayerHome.AssignTeam, true)
end

PlayerHome.OnStartup = function()
    Utils.DisableIntroMessage()

    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.divider.dividerMiddleYPos - SpawnYOffset, SpawnXOffset)
        PlayerHome.CreateTeam("south", global.divider.dividerMiddleYPos + SpawnYOffset, SpawnXOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["south"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["north"]
    end

    -- disable autofiring cross border
    local north = game.forces["north"]
    local north_enemy = game.forces["north_enemy"]
    local south = game.forces["south"]
    local south_enemy = game.forces["south_enemy"]
    north.set_cease_fire(south, true)
    north.set_cease_fire(south_enemy, true)
    south.set_cease_fire(north, true)
    south.set_cease_fire(north_enemy, true)
    north_enemy.set_cease_fire(south, true)
    north_enemy.set_cease_fire(south_enemy, true)
    south_enemy.set_cease_fire(north, true)
    south_enemy.set_cease_fire(north_enemy, true)

    -- don't allow firendly fire from spider nukes
    north_enemy.friendly_fire = false
    south_enemy.friendly_fire = false

    -- Create permission group for waiting room
    local group = game.permissions.get_group("JDWaitingRoom") or game.permissions.create_group("JDWaitingRoom")
    for _, perm in pairs(defines.input_action) do
        group.set_allows_action(perm, false)
    end

    -- Allow spamming of chat if forgotten to be placed in a group
    group.set_allows_action(defines.input_action.write_to_console, true)

    -- For admins, if things go badly wrong
    group.set_allows_action(defines.input_action.edit_permission_group, true)

    -- Create the surface with the same parameters as nauvis
    local surface = game.surfaces["jd-spider-race"]
    if surface == nil then
        -- Use the nauvis settings, but with dual spawn
        local map_gen_settings = Utils.DeepCopy(game.surfaces["nauvis"].map_gen_settings)
        map_gen_settings.starting_points = {
            global.playerHome.teams["north"].spawnPosition,
            global.playerHome.teams["south"].spawnPosition,
        }

        surface = game.create_surface("jd-spider-race", map_gen_settings)

        -- wft factorio. Why no surface created event???
        PlayerHome.OnSurfaceCreated({surface_index=surface.index})
    end
end

PlayerHome.OnSurfaceCreated = function(event)
    local surface = nil

    if event ~= nil then
        surface = game.surfaces[event.surface_index]
        if surface == nil or not surface.valid then
            return
        end
    else
        surface = game.surfaces["nauvis"]
    end

    -- Set spawn points of our forces
    game.forces["north"].set_spawn_position(
        global.playerHome.teams["north"].spawnPosition, surface
    )
    game.forces["south"].set_spawn_position(
        global.playerHome.teams["south"].spawnPosition, surface
    )
end

PlayerHome.AssignTeam = function(event)
    local args = Commands.GetArgumentsFromCommand(event.parameter)
    if #args ~= 2 then
        game.print("ERROR: expecting two args!")
        return
    end

    local player_name = args[1]
    local team_name = args[2]

    local team = global.playerHome.teams[team_name]
    if team == nil then
        game.print("ERROR: Unknown team: "..team_name)
        return
    end

    PlayerHome.AddPlayerNameToTeam(player_name, team)

    local player = game.players[player_name]
    if player ~= nil then
        PlayerHome.UpdateTeam(player, team)
    end
end

PlayerHome.OnEntityDamaged = function(event)
    -- Undo any damage done to the opposing team

    local event_force = event.force
    local event_entity = event.entity

    if event_force == nil or event_entity == nil then
        -- should never happen. Defensive coding
        return false
    end

    local from_force_name = event_force.name
    local to_force_name = event_entity.force.name

    -- We could generically loop over all forces, but lets squeeze any
    -- performance we can out of this code
    if (from_force_name == "north" and to_force_name == "south") or
            (from_force_name == "south" and to_force_name == "north") then

        -- undo the damage done
        event_entity.health = event_entity.health + event.final_damage_amount

        return true
    end

    return false
end


PlayerHome.CreateTeam = function(teamId, spawnYPos, spawnXPos)
    local team = {
        id = teamId,
        spawnPosition = {x = spawnXPos, y = spawnYPos},
        playerIds = {},
        playerNames = {}
    }

    local force = game.create_force(teamId)
    local enemy_force = game.create_force(teamId.."_enemy")

    global.playerHome.teams[teamId] = team
end

PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

PlayerHome.UpdateTeam = function(player, team)
    game.print("Player "..player.name.." is now on team: "..team.id)

    local expected_perms = global.playerHome.waitingRoomPlayers[player.index]
    if expected_perms ~= nil then
        -- player is in the waiting room
        global.playerHome.waitingRoomPlayers[player.index] = nil

        player.permission_group = game.permissions.get_group(expected_perms)
        player.create_character()
    end

    team.playerIds[player.index] = player
    global.playerHome.playerIdToTeam[player.index] = team

    -- move player to correct spawn
    if expected_perms == nil then
        player.character.die()
    else
        PlayerHome.OnPlayerSpawn({player_index=player.index})
    end

    player.force = game.forces[team.id]
end

PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end

    -- Place player in waiting room
    global.playerHome.waitingRoomPlayers[player.index] = player.permission_group.name
    player.character.destroy()
    player.teleport({0, 0}, game.surfaces["jd-spider-race"])
    player.permission_group = game.permissions.get_group("JDWaitingRoom")
    player.print("Welcome! Waiting on an admin to put you on a team...")
    player.print("You might need to /shout to grab attention")
end

PlayerHome.OnPlayerSpawn = function(event)
    local player = game.get_player(event.player_index)
    local team = global.playerHome.playerIdToTeam[player.index]
    local targetPos, surface = team.spawnPosition, player.surface

    local foundPos = surface.find_non_colliding_position("character", targetPos, 0, 0.2)
    if foundPos == nil then
        Logging.LogPrint("ERROR: no position found for player '" .. player.name .. "' near '" .. Logging.PositionToString(targetPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
    local teleported = player.teleport(foundPos, surface)
    if teleported ~= true then
        Logging.LogPrint("ERROR: teleport failed for player '" .. player.name .. "' to '" .. Logging.PositionToString(foundPos) .. "' on surface '" .. surface.name .. "'")
        return
    end
end



PlayerHome.OnMarkedForDeconstruction = function(event)
    -- stop deconstruction from the wrong side of the wall

    local player = game.get_player(event.player_index)
    local entity = event.entity

    if player == nil then
        return
    end

    local team = global.playerHome.playerIdToTeam[player.index]
    if team == nil or entity == nil or not entity.valid then
        return
    end

    if event.entity.position.y < 0 then
        if team.id == "south" then
            entity.cancel_deconstruction(player.force, player)
        end
    elseif team.id == "north" then
        entity.cancel_deconstruction(player.force, player)
    end
end


PlayerHome.OnBuiltEntity = function(event)
    -- stop building on the wrong side
    local player = game.get_player(event.player_index)

    if player == nil then
        return
    end
    
    local team = global.playerHome.playerIdToTeam[player.index]
    local entity = event.created_entity

    if team == nil or entity == nil or not entity.valid then
        return
    end

    local to_destroy = false
    if entity.position.y < 0 then
        if team.id == "south" then
            to_destroy = true
         end
    elseif team.id == "north" then
        to_destroy = true
    end

    if to_destroy then
        entity.surface.create_entity({name="flying-text", position=entity.position, text="Cannot build on other side of wall"})

        if not player.mine_entity(entity, true) then
            entity.destroy()
        end
    end
end

return PlayerHome
