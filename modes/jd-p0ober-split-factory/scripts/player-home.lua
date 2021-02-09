local PlayerHome = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")
local EventScheduler = require("utility/event-scheduler")

local SpawnXMiddle = 1 -- This is 1 so that both the 2 divider tiles are in the same chunk.
local SpawnXOffset = 20

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}
    global.playerHome.team = global.playerHome.team or {}
    --[[
        [teamId] = {
            teamId = string team of either "west" or "east".
            spawnPoint = spawnPoint of this team.
            playerNames = table of player names on this team.
        }
    ]]
    global.playerHome.playerNameToTeam = global.playerHome.playerNameToTeam or {}
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "PlayerHome.OnPlayerSpawn", PlayerHome.OnPlayerSpawn)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
end

PlayerHome.OnStartup = function()
    if global.playerHome.team["west"] == nil then
        PlayerHome.CreateTeam("west", SpawnXMiddle - SpawnXOffset, {"P0ober", "muppet9010"})
    end
    if global.playerHome.team["east"] == nil then
        PlayerHome.CreateTeam("east", SpawnXMiddle + SpawnXOffset, {"JDPlays"})
    end
end

PlayerHome.CreateTeam = function(teamId, spawnXPos, defaultPlayersOnTeam)
    local team = {
        teamId = teamId,
        spawnPosition = {x = spawnXPos, y = 0},
        playerNames = {}
    }
    for _, playerName in pairs(defaultPlayersOnTeam) do
        team.playerNames[playerName] = playerName
        global.playerHome.playerNameToTeam[playerName] = team
    end

    global.playerHome.team[teamId] = team
end

PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end
    PlayerHome.OnPlayerSpawn(event)
end

PlayerHome.OnPlayerSpawn = function(event)
    local player = game.get_player(event.player_index)
    local team = global.playerHome.playerNameToTeam[player.name]
    if team == nil then
        game.print("Player '" .. player.name .. "' isn't on any team !!!")
        return
    end
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
