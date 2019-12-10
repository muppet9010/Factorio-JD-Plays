local Events = require("utility/events")
--local Logging = require("utility/logging")
local Utils = require("utility/utils")
local Commands = require("utility/commands")
local SharedPlayerDamage = {}

--[[-----------------------------------------------------------

    Only supports a single surface

-------------------------------------------------------------]]
local ticksSafeAfterRespawn = 60 * 60
local damageMultiplier = 0.75
local playerSpawnPos = {x = 0, y = 0}
local surfaceName = "nauvis"

SharedPlayerDamage.CreateGlobals = function()
    global.SharedPlayerDamage = global.SharedPlayerDamage or {}
    global.SharedPlayerDamage.enabled = global.SharedPlayerDamage.enabled or true
    global.SharedPlayerDamage.PlayersLastRespawnTick = global.SharedPlayerDamage.PlayersLastRespawnTick or {}
    global.SharedPlayerDamage.lastPlayerDamageSharedName = global.SharedPlayerDamage.lastPlayerDamageSharedName or nil
    global.SharedPlayerDamage.playerCausedOthersDeaths = global.SharedPlayerDamage.playerCausedOthersDeaths or {}
    global.SharedPlayerDamage.playerDeathsFromOthers = global.SharedPlayerDamage.playerDeathsFromOthers or {}
    if global.SharedPlayerDamage.farestGeneratedMapDistance == nil or global.SharedPlayerDamage.farestGeneratedMapDistance == 0 then
        SharedPlayerDamage.CalculateFarestCurrentMapDistance()
    end
end

SharedPlayerDamage.OnLoad = function()
    Events.RegisterHandler(defines.events.on_entity_damaged, "SharedPlayerDamage", SharedPlayerDamage.OnEntityDamagedFilteredCharacter, "type=character")
    Events.RegisterHandler(defines.events.on_player_respawned, "SharedPlayerDamage", SharedPlayerDamage.OnPlayerRespawned)
    Events.RegisterHandler(defines.events.on_player_died, "SharedPlayerDamage", SharedPlayerDamage.OnPlayerDied)
    Events.RegisterHandler(defines.events.on_chunk_generated, "SharedPlayerDamage", SharedPlayerDamage.OnChunkGenerated)
    Commands.Register("shared_damage_write_out_kills_deaths", {"api-description.jd_plays-december-2019-shared_damage_write_out_kills_deaths"}, SharedPlayerDamage.WriteOutSharedDamageKillsDeaths, false)
end

SharedPlayerDamage.OnStartup = function()
    if global.SharedPlayerDamage.scriptForce == nil then
        global.SharedPlayerDamage.scriptForce = game.create_force("sharedPlayerDamage")
    end
end

SharedPlayerDamage.OnEntityDamagedFilteredCharacter = function(event)
    if (not global.SharedPlayerDamage.enabled) or event.force == global.SharedPlayerDamage.scriptForce or event.original_damage_amount <= 0 then
        return
    end
    if event.damage_type ~= nil and (event.damage_type.name == "snowball") then
        return
    end
    local tick = event.tick
    local damageToDo = math.floor(event.original_damage_amount * damageMultiplier)
    local damagedPlayer = event.entity.player
    local damagedPlayerPos = damagedPlayer.position
    local fullDamageDistance = global.SharedPlayerDamage.farestGeneratedMapDistance
    global.SharedPlayerDamage.lastPlayerDamageSharedName = damagedPlayer.name
    for i, player in pairs(game.connected_players) do
        if player.index ~= damagedPlayer.index then
            if player.character ~= nil then
                local playerLastRespawn = global.SharedPlayerDamage.PlayersLastRespawnTick[player.index]
                local playerSafe = false
                if playerLastRespawn ~= nil then
                    if playerLastRespawn >= tick - ticksSafeAfterRespawn then
                        playerSafe = true
                    else
                        global.SharedPlayerDamage.PlayersLastRespawnTick[player.index] = nil
                    end
                end
                if not playerSafe then
                    local distance = Utils.GetDistance(damagedPlayerPos, player.position)
                    local thisPlayersDamageToDo = damageToDo - (damageToDo * (distance / fullDamageDistance))
                    player.character.damage(thisPlayersDamageToDo, global.SharedPlayerDamage.scriptForce, event.damage_type.name)
                end
            end
        end
    end
    global.SharedPlayerDamage.lastPlayerDamageSharedName = nil
end

SharedPlayerDamage.OnPlayerRespawned = function(event)
    local playerId = event.player_index
    global.SharedPlayerDamage.PlayersLastRespawnTick[playerId] = event.tick
    local player = game.get_player(playerId)
    player.print({"messages.jd_plays-december-2019-shared_damage_respawn", (ticksSafeAfterRespawn / 60)}, {r = 1, g = 0, b = 0, a = 1})
end

SharedPlayerDamage.OnPlayerDied = function(event)
    local deathCausingPlayer = global.SharedPlayerDamage.lastPlayerDamageSharedName
    if deathCausingPlayer == nil then
        return
    end
    if global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] == nil then
        global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] = 1
    else
        global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] = global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] + 1
    end
    local deathCausingPlayerCount = global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer]
    local deadPlayerName = game.get_player(event.player_index).name
    if global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayerName] == nil then
        global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayerName] = 1
    else
        global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayerName] = global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayerName] + 1
    end
    local deadPlayerCount = global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayerName]
    game.print({"messages.jd_plays-december-2019-shared_damage_died_by_player", deathCausingPlayer, deathCausingPlayerCount, deadPlayerName, deadPlayerCount})
end

SharedPlayerDamage.OnChunkGenerated = function(event)
    local topLeftTile = event.area.left_top
    local measureToPos = Utils.DeepCopy(topLeftTile)
    if topLeftTile.x >= 0 then
        measureToPos.x = measureToPos.x + 32
    end
    if topLeftTile.y >= 0 then
        measureToPos.y = measureToPos.y + 32
    end
    local distance = Utils.GetDistance(playerSpawnPos, measureToPos)
    if distance > global.SharedPlayerDamage.farestGeneratedMapDistance then
        global.SharedPlayerDamage.farestGeneratedMapDistance = distance
    end
end

SharedPlayerDamage.CalculateFarestCurrentMapDistance = function()
    global.SharedPlayerDamage.farestGeneratedMapDistance = 0
    for chunk in game.get_surface(surfaceName).get_chunks() do
        SharedPlayerDamage.OnChunkGenerated(chunk)
    end
end

SharedPlayerDamage.WriteOutSharedDamageKillsDeaths = function(commandData)
    local killsDeaths = {["other players killed"] = global.SharedPlayerDamage.playerCausedOthersDeaths, ["deaths caused by others"] = global.SharedPlayerDamage.playerDeathsFromOthers}
    game.write_file("Shared Damage Deaths Kills.txt", Utils.TableContentsToJSON(killsDeaths), false, commandData.player_index)
end

return SharedPlayerDamage
