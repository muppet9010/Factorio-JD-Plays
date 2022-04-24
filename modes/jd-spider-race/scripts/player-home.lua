local PlayerHome = {}

local Commands = require("utility/commands")
local Events = require("utility/events")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local Colors = require("utility.colors")

local SpawnYOffset = 256
local SpawnXOffset = -256
local MapHeight = 1024 -- For both teams, so giving 512 tiles per team.

---@class JdSpiderRace_PlayerHome_Team
---@field id JdSpiderRace_PlayerHome_PlayerTeamNames
---@field playerForce LuaForce @ Ref to the player force for this team.
---@field enemyForce LuaForce @ The biter force in this teams lane of the map.
---@field enemyForceName string
---@field spawnPosition MapPosition @ Position of this team's spawn.
---@field players table<Id, LuaPlayer> @ Table of the player ids to player object who have joined this team.
---@field playerNames table<string, string> @ Table of player names (key and value) who will join this team on first connect.
---@field otherTeam JdSpiderRace_PlayerHome_Team @ Ref to the other teams global object.

---@alias JdSpiderRace_PlayerHome_PlayerTeamNames '"north"'|'"south"'

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}

    global.playerHome.teams = global.playerHome.teams or {} ---@type table<JdSpiderRace_PlayerHome_PlayerTeamNames, JdSpiderRace_PlayerHome_Team> @ Team name to team object.
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {} ---@type table<Id, JdSpiderRace_PlayerHome_Team> @ Player index to thier team object.
    global.playerHome.waitingRoomPlayers = global.playerHome.waitingRoomPlayers or {} ---@type table<Id, string> @ Player's index to their initial permissions group name from before they were put in the waiting room.
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
    Events.RegisterHandlerEvent(defines.events.on_marked_for_deconstruction, "PlayerHome.OnMarkedForDeconstruction", PlayerHome.OnMarkedForDeconstruction)
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "PlayerHome.OnBuiltEntity", PlayerHome.OnBuiltEntity)
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "PlayerHome.OnChunkGenerated", PlayerHome.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_market_item_purchased, "PlayerHome.OnMarketItemPurchased", PlayerHome.OnMarketItemPurchased)

    Commands.Register("spider_assign_player_to_team", {"api-description.jd_plays-jd_spider_race-spider_assign_player_to_team"}, PlayerHome.Command_AssignPlayerToTeam, true)
end

PlayerHome.OnStartup = function()
    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.divider.dividerMiddleYPos - SpawnYOffset, SpawnXOffset)
        PlayerHome.CreateTeam("south", global.divider.dividerMiddleYPos + SpawnYOffset, SpawnXOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["south"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["north"]
    end

    -- disable autofiring cross border
    local north = global.playerHome.teams["north"].playerForce
    local north_enemy = global.playerHome.teams["north"].enemyForce
    local south = global.playerHome.teams["south"].playerForce
    local south_enemy = global.playerHome.teams["south"].enemyForce
    north.set_cease_fire(south, true)
    north.set_cease_fire(south_enemy, true)
    south.set_cease_fire(north, true)
    south.set_cease_fire(north_enemy, true)
    north_enemy.set_cease_fire(south, true)
    north_enemy.set_cease_fire(south_enemy, true)
    south_enemy.set_cease_fire(north, true)
    south_enemy.set_cease_fire(north_enemy, true)

    -- don't allow firendly fire within the biter teams. To protect against spider nukes and flamethrower.
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
    if global.general.surface == nil then
        -- Use the nauvis settings, but with dual spawn
        local map_gen_settings = Utils.DeepCopy(game.surfaces["nauvis"].map_gen_settings)
        map_gen_settings.starting_points = {
            global.playerHome.teams["north"].spawnPosition,
            global.playerHome.teams["south"].spawnPosition
        }
        map_gen_settings.height = MapHeight -- Force the map to be 1024 tall and infinitely wide.
        map_gen_settings.water = 0 -- Disable water on the map.

        global.general.surface = game.create_surface(global.general.surfaceName, map_gen_settings)

        -- Set spawn points of our player forces.
        for _, team in pairs(global.playerHome.teams) do
            team.playerForce.set_spawn_position(team.spawnPosition, global.general.surface)
        end
    end
end

---@param event CustomCommandData
PlayerHome.Command_AssignPlayerToTeam = function(event)
    local args = Commands.GetArgumentsFromCommand(event.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_assign_player_to_team command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 2 then
        game.print(commandErrorMessagePrefix .. "Expecting two args.", Colors.lightred)
        return
    end

    local player_name = args[1]
    local team_name = args[2]

    local team = global.playerHome.teams[team_name]
    if team == nil then
        game.print(commandErrorMessagePrefix .. "Unknown team: " .. team_name, Colors.lightred)
        return
    end

    -- Record the named player to be on the team (now and in the future).
    PlayerHome.AddPlayerNameToTeam(player_name, team)

    -- If the player is currently on the server move them to the team now.
    local player = game.get_player(player_name)
    if player ~= nil then
        PlayerHome.MovePlayerToTeam(player, team)
    end
end

--- Called from central control.lua.
---@param event any
PlayerHome.OnEntityDamaged = function(event)
    -- Undo any damage done from one player team to the other.

    local event_force = event.force
    local event_entity = event.entity

    if event_force == nil or event_entity == nil then
        -- should never happen. Defensive coding
        return
    end

    local from_force_name = event_force.name
    local to_force_name = event_entity.force.name

    -- We could generically loop over all forces, but lets squeeze any
    -- performance we can out of this code
    if (from_force_name == "north" and to_force_name == "south") or (from_force_name == "south" and to_force_name == "north") then
        -- undo the damage done
        event_entity.health = event_entity.health + event.final_damage_amount

        return
    end
end

---@param teamId JdSpiderRace_PlayerHome_PlayerTeamNames
---@param spawnYPos float
---@param spawnXPos float
PlayerHome.CreateTeam = function(teamId, spawnYPos, spawnXPos)
    ---@type JdSpiderRace_PlayerHome_Team
    local team = {
        id = teamId,
        spawnPosition = {x = spawnXPos, y = spawnYPos},
        players = {},
        playerNames = {}
    }
    team.playerForce = game.create_force(teamId)
    team.enemyForceName = teamId .. "_enemy"
    team.enemyForce = game.create_force(team.enemyForceName)

    global.playerHome.teams[teamId] = team

    team.playerForce.technologies["landfill"].enabled = false
end

--- Add a player's name to the team's list of players.
---@param playerName string
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

--- Moves the player to the team.
---@param player LuaPlayer
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.MovePlayerToTeam = function(player, team)
    game.print("Player " .. player.name .. " is now on team: " .. team.id)
    local playerId = player.index

    -- Check if the player is in the waiting room at present.
    local playersOrigionalPermissionGroupName = global.playerHome.waitingRoomPlayers[playerId]
    if playersOrigionalPermissionGroupName ~= nil then
        -- player is in the waiting room as we have a cached value for them.

        -- Take the player out of the waiting room and remove them from the waiting room player list.
        global.playerHome.waitingRoomPlayers[playerId] = nil
        player.permission_group = game.permissions.get_group(playersOrigionalPermissionGroupName)
        player.create_character()
    end

    -- Record player to team.
    team.players[playerId] = player
    global.playerHome.playerIdToTeam[playerId] = team

    -- move player to correct spawn
    if playersOrigionalPermissionGroupName == nil then
        -- Player was origionally on a team and not in the waiting room.
        -- So kill them and they will respawn on the new team. This will leave any current equipment on the old (correct) side of the map.
        player.character.die()
    else
        -- Player was in the waiting room before being assigned to a team.
        PlayerHome.SpawnPlayer(player)
    end

    player.force = team.playerForce
end

--- When player first joins put thme in the waiting room.
---@param event on_player_created
PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end

    -- Store the players initial permission group name for use when assigning them to a force.
    global.playerHome.waitingRoomPlayers[event.player_index] = player.permission_group.name

    -- Place player in waiting room
    player.character.destroy()
    player.teleport({0, 0}, global.general.surface)
    player.permission_group = game.permissions.get_group("JDWaitingRoom")

    player.print("Welcome! Waiting on an admin to put you on a team...")
    player.print("You might need to /shout to grab attention")
end

--- Move the player's character to the correct team and spawn area.
---@param player LuaPlayer
PlayerHome.SpawnPlayer = function(player)
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

--- Stop deconstruction from the wrong side of the wall.
---@param event on_marked_for_deconstruction
PlayerHome.OnMarkedForDeconstruction = function(event)
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
        -- Entity marked for deconstruction was north side of divider.
        if team.id == "south" then
            entity.cancel_deconstruction(team.playerForce, player)
        end
    else
        -- Entity marked for deconstruction was south side of divider.
        if team.id == "north" then
            entity.cancel_deconstruction(team.playerForce, player)
        end
    end
end

-- Stop players building on the wrong side.
---@param event on_built_entity
PlayerHome.OnBuiltEntity = function(event)
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
        -- Entity built on north side of divider.
        if team.id == "south" then
            to_destroy = true
        end
    else
        -- Entity built on south side of divider.
        if team.id == "north" then
            to_destroy = true
        end
    end

    if to_destroy then
        entity.surface.create_entity({name = "flying-text", position = entity.position, text = "Cannot build on other side of wall"})

        if not player.mine_entity(entity, true) then
            entity.destroy()
        end
    end
end

--- Need to pale the market once the chunk at spawn has been generated.
---@param event on_chunk_generated
PlayerHome.OnChunkGenerated = function(event)
    if event.surface.name ~= global.general.surfaceName then
        -- Not our surface.
        return
    end

    -- If its the spawn chunk for a team create the market there.
    for _, team in pairs(global.playerHome.teams) do
        if event.area.left_top.x == team.spawnPosition.x and event.area.left_top.y == team.spawnPosition.y then
            -- Spawn point is in this chunk.
            PlayerHome.CreateMarketForTeam(team)
        end
    end
end

--- Create a market for the team at its spawn area. Fully configures the market.
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.CreateMarketForTeam = function(team)
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

--- Called when a player purchases an item in the market. In our mod this will only ever be to nuke the other team.
---@param event on_market_item_purchased
PlayerHome.OnMarketItemPurchased = function(event)
    if remote.interfaces["JDGoesBoom"] == nil or remote.interfaces["JDGoesBoom"]["ForceGoesBoom"] == nil then
        game.print("JD Goes Boom mod not installed, so coin wasted", Colors.lightred)
        return
    end

    -- Trigger the nuke on the other team.
    local otherTeamName = global.playerHome.playerIdToTeam[event.player_index].otherTeam.id
    remote.call("JDGoesBoom", "ForceGoesBoom", otherTeamName, 50, 15)
    game.print({"message.jd_plays-jd_spider_race-blow_up_other_team", otherTeamName}, Colors.lightgreen)

    -- Remove the fake item the player just brought.
    local player = game.get_player(event.player_index)
    player.remove_item({name = "jd_plays-jd_spider_race-nuke_other_team"})
end

return PlayerHome
