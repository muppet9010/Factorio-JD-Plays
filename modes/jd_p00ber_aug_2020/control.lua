local Events = require("utility/events")
--local Utils = require("utility/utils")
local Logging = require("utility/logging")
local Commands = require("utility/commands")

if settings.startup["jdplays_mode"].value ~= "jd_p00ber_aug_2020" then
    return
end

local function SetPlayerSpawn(command)
    local args = Commands.GetArgumentsFromCommand(command.parameter)
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print({"message.jd_plays-set_player_spawn-error_no_arguments"})
        return
    end

    local errored, playerName, xPos, yPos = false, args[1], args[2], args[3]
    if playerName == nil then
        game.print({"message.jd_plays-set_player_spawn-error_player_name"})
        errored = true
        playerName = "BLANK"
    end
    if xPos == nil or xPos == "" then
        game.print({"message.jd_plays-set_player_spawn-error_x_pos"})
        errored = true
        xPos = "BLANK"
    end
    if yPos == nil or yPos == "" then
        game.print({"message.jd_plays-set_player_spawn-error_y_pos"})
        errored = true
        yPos = "BLANK"
    end
    if errored then
        game.print({"message.jd_plays-set_player_spawn-error_submission", playerName, xPos, yPos})
        return
    end

    global.playerSpawnPoint[playerName] = {x = xPos, y = yPos}
    game.print({"message.jd_plays-set_player_spawn-completed", playerName, xPos, yPos})
end

local function GetPlayersSpawns()
    game.print({"message.jd_plays-get_players_spawns-header"})
    for playerName, spawnPos in pairs(global.playerSpawnPoint) do
        game.print({"message.jd_plays-get_players_spawns-rows", playerName, spawnPos.x, spawnPos.y})
    end
end

local function PlayerSpawn(event)
    local player = game.get_player(event.player_index)
    local targetPos = global.playerSpawnPoint[player.name]
    if targetPos == nil then
        return
    end
    local surface = player.surface

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

local function CreateGlobals()
    global.playerSpawnPoint = global.playerSpawnPoint or {}
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    Commands.Register("jd_plays_set_player_spawn", {"api-description.jd_plays-set_player_spawn"}, SetPlayerSpawn, true)
    Commands.Register("jd_plays_get_players_spawns", {"api-description.jd_plays-get_players_spawns"}, GetPlayersSpawns, true)
    Events.RegisterHandler(defines.events.on_player_respawned, "on_player_respawned", PlayerSpawn)
    Events.RegisterHandler(defines.events.on_player_created, "on_player_respawned", PlayerSpawn)
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
Events.RegisterEvent(defines.events.on_player_respawned)
Events.RegisterEvent(defines.events.on_player_created)
