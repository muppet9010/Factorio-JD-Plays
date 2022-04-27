local PlayerHome = {}

local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility.event-scheduler")
local Logging = require("utility/logging")
local Colors = require("utility.colors")

local SpawnXOffset = -256 -- Distance in from the coastline.

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
    EventScheduler.RegisterScheduledEventType("PlayerHome.DelayedPlayerCreated_Scheduled", PlayerHome.DelayedPlayerCreated_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_marked_for_deconstruction, "PlayerHome.OnMarkedForDeconstruction", PlayerHome.OnMarkedForDeconstruction)
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "PlayerHome.OnBuiltEntity", PlayerHome.OnBuiltEntity)
    Events.RegisterHandlerEvent(defines.events.on_market_item_purchased, "PlayerHome.OnMarketItemPurchased", PlayerHome.OnMarketItemPurchased)

    Commands.Register("spider_assign_player_to_team", {"api-description.jd_plays-jd_spider_race-spider_assign_player_to_team"}, PlayerHome.Command_AssignPlayerToTeam, true)
end

PlayerHome.OnStartup = function()
    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.divider.dividerMiddleYPos - (global.general.perTeamMapHeight / 2), SpawnXOffset)
        PlayerHome.CreateTeam("south", global.divider.dividerMiddleYPos + (global.general.perTeamMapHeight / 2), SpawnXOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["south"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["north"]

        -- Set JD and Mukkie to their initial teams.
        global.playerHome.teams["north"].playerNames["JD-Plays"] = "JD-Plays"
        global.playerHome.teams["south"].playerNames["mukkie"] = "mukkie"
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

--- When player first joins put thme in the waiting room.
---@param event on_player_created
PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end

    -- Check if the player has been pre-assigned to a team.
    for _, team in pairs(global.playerHome.teams) do
        if team.playerNames[player.name] ~= nil then
            -- Player is pre-assigned to this team.

            -- Record player to new team and update player's force.
            local playerId = player.index
            team.players[playerId] = player
            global.playerHome.playerIdToTeam[playerId] = team
            player.force = team.playerForce

            -- Move them to the surface and position them.
            PlayerHome.DelayedPlayerCreated_Scheduled({tick = event.tick, instanceId = playerId})

            return
        end
    end

    -- Store the players initial permission group name for use when assigning them to a force.
    global.playerHome.waitingRoomPlayers[event.player_index] = player.permission_group.name

    -- Place player in waiting room on the correct surface.
    player.character.destroy()
    player.teleport({0, 0}, global.general.surface)
    player.permission_group = game.permissions.get_group("JDWaitingRoom")

    player.print("Welcome! Waiting on an admin to put you on a team...")
    player.print("You might need to /shout to grab attention")
end

--- To create a pre-assigned player to a team. Supports delayed looping back to itself if it fails during initial map generation.
---@param event UtilityScheduledEvent_CallbackObject
PlayerHome.DelayedPlayerCreated_Scheduled = function(event)
    local playerId = event.instanceId
    local player = game.get_player(playerId)

    -- Move them to the surface and position them.
    if player.character ~= nil then
        player.character.destroy() -- Clears any starting inventory just like if the player isn't pre-assigned a team.
    end
    player.teleport({0, 0}, global.general.surface)
    player.create_character()
    local playerMovedOk = PlayerHome.MovePlayerToSpawn(player)
    if not playerMovedOk then
        -- Can happen if this is run during initial map generation. Will just wait a few seconds and try movign the player again.
        player.print("Trying to respawn you in a few seconds after map has generated more.", Colors.lightgreen)
        EventScheduler.ScheduleEventOnce(event.tick + 180, "PlayerHome.DelayedPlayerCreated_Scheduled", playerId)
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

--- Add a player's name to the team's list of players.
---@param playerName string
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

--- Moves the current player to the team.
---@param player LuaPlayer
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.MovePlayerToTeam = function(player, team)
    game.print("Player " .. player.name .. " is now on team: " .. team.id)
    local playerId = player.index

    -- Record player to new team and update player's force.
    team.players[playerId] = player
    global.playerHome.playerIdToTeam[playerId] = team
    player.force = team.playerForce

    -- Check if the player is in the waiting room at present and handle next steps accordingly.
    local playersOrigionalPermissionGroupName = global.playerHome.waitingRoomPlayers[playerId]
    local playerInWaitingRoom = playersOrigionalPermissionGroupName ~= nil
    if playerInWaitingRoom then
        -- Player is in the waiting room as we have a cached value for them.

        -- Take the player out of the waiting room and remove them from the waiting room player list.
        global.playerHome.waitingRoomPlayers[playerId] = nil
        player.permission_group = game.permissions.get_group(playersOrigionalPermissionGroupName)

        -- Give the player a character in the right spot.
        player.create_character()
        local playerMovedOk = PlayerHome.MovePlayerToSpawn(player)
        if not playerMovedOk then
            -- Can happen if this is run during initial map generation. Will just wait a few seconds and try movign the player again.
            player.print("Trying to respawn you in a few seconds after map has generated more.", Colors.lightgreen)
            EventScheduler.ScheduleEventOnce(game.tick + 180, "PlayerHome.DelayedPlayerCreated_Scheduled", playerId)
        end
    else
        -- Player wasn't in the waiting room, so must have been already assigned to a team and is in a normal state.

        -- So kill them and they will respawn on the new team. This will leave any current equipment on the old (correct) side of the map.
        if player.character ~= nil then
            -- If in Editor mode then no character.
            player.character.die()
        end
    end
end

--- Move the players character to the team's spawn area. As in most cases the player will be at {0,0} on the map currently.
---@param player LuaPlayer
---@return boolean playerMovedCorrectly @ Can be false if this runs during map generation for a pre-assigned player.
PlayerHome.MovePlayerToSpawn = function(player)
    local team = global.playerHome.playerIdToTeam[player.index]
    local targetPos, surface = team.spawnPosition, global.general.surface

    local foundPos = surface.find_non_colliding_position("character", targetPos, 50, 0.2)
    if foundPos == nil then
        Logging.LogPrint("ERROR: no position found for player '" .. player.name .. "' near '" .. Logging.PositionToString(targetPos) .. "' on surface '" .. surface.name .. "'")
        return false
    end
    local teleported = player.teleport(foundPos, surface)
    if teleported ~= true then
        Logging.LogPrint("ERROR: teleport failed for player '" .. player.name .. "' to '" .. Logging.PositionToString(foundPos) .. "' on surface '" .. surface.name .. "'")
        return false
    end

    return true
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

--- Called when a player purchases an item in the market. In our mod this will only ever be to nuke the other team.
---@param event on_market_item_purchased
PlayerHome.OnMarketItemPurchased = function(event)
    if remote.interfaces["JDGoesBoom"] == nil or remote.interfaces["JDGoesBoom"]["ForceGoesBoom"] == nil then
        game.print("JD Goes Boom mod not installed, so coin wasted", Colors.lightred)
        return
    end

    -- Trigger the nuke on the other team.
    local otherTeamName = global.playerHome.playerIdToTeam[event.player_index].otherTeam.id
    remote.call("JDGoesBoom", "ForceGoesBoom", otherTeamName, 50, 60)
    game.print({"message.jd_plays-jd_spider_race-blow_up_other_team", otherTeamName}, Colors.lightgreen)

    -- Remove the fake item the player just brought.
    local player = game.get_player(event.player_index)
    player.remove_item({name = "jd_plays-jd_spider_race-nuke_other_team"})
end

return PlayerHome
