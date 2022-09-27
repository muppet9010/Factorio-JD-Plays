local PlayerHome = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")

local SpawnXOffset = 20

---@class JDSplitFactory_PlayerHome_Team
---@field id JDSplitFactory_PlayerHome_TeamId
---@field spawnPosition MapPosition
---@field playerIds table<uint, LuaPlayer> # Table of the player indexes who have joined this team.
---@field playerNames table<string, string> # Table of player names (key and value) who will join this team on first connect.
---@field teleporterEntity LuaEntity
---@field otherTeam JDSplitFactory_PlayerHome_Team # Reference to the other team's global object.

---@alias JDSplitFactory_PlayerHome_TeamId "east"|"west"


PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {} ---@class JDSplitFactory_PlayerHome_Global
    global.playerHome.teams = global.playerHome.teams or {} ---@type table<JDSplitFactory_PlayerHome_TeamId, JDSplitFactory_PlayerHome_Team>
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {} ---@type table<uint, JDSplitFactory_PlayerHome_Team>
    global.playerHome.defaultTeamForUnknownPlayers = global.playerHome.defaultTeamForUnknownPlayers or nil ---@type JDSplitFactory_PlayerHome_Team
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_respawned, "PlayerHome.OnPlayerSpawn", PlayerHome.OnPlayerSpawn)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
end

PlayerHome.OnStartup = function()
    Utils.DisableIntroMessage()
    if global.playerHome.teams["west"] == nil then
        PlayerHome.CreateTeam("west", global.divider.dividerMiddleXPos - SpawnXOffset, { "Poober", "mukkie" }, true)
        PlayerHome.CreateTeam("east", global.divider.dividerMiddleXPos + SpawnXOffset, { "JD-Plays" }, false)
        global.playerHome.teams["west"].otherTeam = global.playerHome.teams["east"] ---@type JDSplitFactory_PlayerHome_Team
        global.playerHome.teams["east"].otherTeam = global.playerHome.teams["west"] ---@type JDSplitFactory_PlayerHome_Team
    end
end

--- Create a team in to global.
---@param teamId JDSplitFactory_PlayerHome_TeamId
---@param spawnXPos double
---@param defaultPlayersOnTeam string[]
---@param defaultTeamForUnknownPlayers boolean
PlayerHome.CreateTeam = function(teamId, spawnXPos, defaultPlayersOnTeam, defaultTeamForUnknownPlayers)
    local team = {
        id = teamId,
        spawnPosition = { x = spawnXPos, y = 0 },
        playerIds = {},
        playerNames = {}
    }
    for _, playerName in pairs(defaultPlayersOnTeam) do
        PlayerHome.AddPlayerNameToTeam(playerName, team)
    end
    team.teleporterEntity = MOD.Interfaces.Teleporter.AddTeleporter(team, game.surfaces["nauvis"], { x = spawnXPos, y = 20 })
    if team.teleporterEntity == nil then
        game.print("Team setup failed for '" .. teamId .. "'", { r = 1.0, g = 0.0, b = 0.0, a = 1.0 })
    end

    global.playerHome.teams[teamId] = team

    if defaultTeamForUnknownPlayers then
        global.playerHome.defaultTeamForUnknownPlayers = team
    end
end

--- Add a players name to a team's expected player list.
---@param playerName string
---@param team JDSplitFactory_PlayerHome_Team
PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = playerName
end

--- When a player first joins the server and their character is created.
---@param event EventData.on_player_created
PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index) ---@cast player - nil

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

    -- If player isn't named check for the default team and put them on it.
    if team == nil and global.playerHome.defaultTeamForUnknownPlayers ~= nil then
        team = global.playerHome.defaultTeamForUnknownPlayers
        PlayerHome.AddPlayerNameToTeam(player.name, team)
        game.print("Player '" .. player.name .. "' added to the default team of '" .. team.id .. "'")
    end

    -- If still no team then give them a random team.
    if team == nil then
        local teamNames = Utils.TableKeyToArray(global.playerHome.teams) ---@type table<uint, JDSplitFactory_PlayerHome_TeamId>
        team = global.playerHome.teams[teamNames[math.random(1, 2)]]
        PlayerHome.AddPlayerNameToTeam(player.name, team)
        game.print("Player '" .. player.name .. "' isn't set on a team, so added to the '" .. team.id .. "' randomly")
    end

    --Record the player ID to the team, rather than relying on names.
    team.playerIds[player.index] = player
    global.playerHome.playerIdToTeam[player.index] = team

    PlayerHome.OnPlayerSpawn(event)
end

--- When a player spawns each time.
---@param event any
PlayerHome.OnPlayerSpawn = function(event)
    local player = game.get_player(event.player_index) ---@cast player - nil
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
