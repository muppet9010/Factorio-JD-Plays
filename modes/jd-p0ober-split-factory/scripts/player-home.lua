local PlayerHome = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local EventScheduler = require("utility/event-scheduler")
local Interfaces = require("utility/interfaces")

local SpawnXOffset = 20

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}
    global.playerHome.teams = global.playerHome.teams or {}
    --[[
        [id] = {
            id = string team of either "west" or "east".
            spawnPosition = position of this team's spawn.
            playerIds = table of the player ids who have joined this team.
            playerNames = table of player names who will join this team on first connect.
            teleporterEntity = entity of the teleporter.
            otherTeam = ref to the other teams global object.
        }
    ]]
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {}
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "PlayerHome.OnPlayerSpawn", PlayerHome.OnPlayerSpawn)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
end

PlayerHome.OnStartup = function()
    Utils.DisableIntroMessage()
    if global.playerHome.teams["west"] == nil then
        PlayerHome.CreateTeam("west", global.divider.dividerMiddleXPos - SpawnXOffset, {"Poober"})
        PlayerHome.CreateTeam("east", global.divider.dividerMiddleXPos + SpawnXOffset, {"JD-Plays"})
        global.playerHome.teams["west"].otherTeam = global.playerHome.teams["east"]
        global.playerHome.teams["east"].otherTeam = global.playerHome.teams["west"]
    end
end

PlayerHome.CreateTeam = function(teamId, spawnXPos, defaultPlayersOnTeam)
    local team = {
        id = teamId,
        spawnPosition = {x = spawnXPos, y = 0},
        playerIds = {},
        playerNames = {}
    }
    for _, playerName in pairs(defaultPlayersOnTeam) do
        PlayerHome.AddPlayerNameToTeam(playerName, team)
    end
    team.teleporterEntity = Interfaces.Call("Teleporter.AddTeleporter", team, game.surfaces["nauvis"], {x = spawnXPos, y = 20})

    global.playerHome.teams[teamId] = team
end

PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end
    -- Check if player is on the named list.
    local team
    for _, teamToCheck in pairs(global.playerHome.teams) do
        if teamToCheck.playerNames[player.name] ~= nil then
            team = teamToCheck
            break
        end
    end
    -- If player isn't named give them a random team.
    if team == nil then
        local teamNames = Utils.TableKeyToArray(global.playerHome.teams)
        team = global.playerHome.teams[teamNames[math.random(1, 2)]]
        PlayerHome.AddPlayerNameToTeam(player.name, team)
        game.print("Player '" .. player.name .. "' isn't set on a team, so added to the '" .. team.id .. "' randomly")
    end
    --Record the player ID to the team, rather than relying on names.
    team.playerIds[player.index] = player
    global.playerHome.playerIdToTeam[player.index] = team

    PlayerHome.OnPlayerSpawn(event)
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

return PlayerHome
