local Events = require("utility/events")
--local Logging = require("utility/logging")
local SharedPlayerDamage = {}
local ticksSafeAfterRespawn = 60 * 60
local damageMultiplier = 0.75

SharedPlayerDamage.CreateGlobals = function()
    global.SharedPlayerDamage = global.SharedPlayerDamage or {}
    global.SharedPlayerDamage.enabled = global.SharedPlayerDamage.enabled or true
    global.SharedPlayerDamage.PlayersLastRespawnTick = global.SharedPlayerDamage.PlayersLastRespawnTick or {}
    global.SharedPlayerDamage.lastPlayerDamageSharedName = global.SharedPlayerDamage.lastPlayerDamageSharedName or nil
    global.SharedPlayerDamage.playerCausedOthersDeaths = global.SharedPlayerDamage.playerCausedOthersDeaths or {}
    global.SharedPlayerDamage.playerDeathsFromOthers = global.SharedPlayerDamage.playerDeathsFromOthers or {}
end

SharedPlayerDamage.OnLoad = function()
    Events.RegisterHandler(defines.events.on_entity_damaged, "SharedPlayerDamage", SharedPlayerDamage.OnEntityDamagedFilteredCharacter, "type=character")
    Events.RegisterHandler(defines.events.on_player_respawned, "SharedPlayerDamage", SharedPlayerDamage.OnPlayerRespawned)
    Events.RegisterHandler(defines.events.on_player_died, "SharedPlayerDamage", SharedPlayerDamage.OnPlayerDied)
end

SharedPlayerDamage.OnStartup = function()
    if global.SharedPlayerDamage.scriptForce == nil then
        global.SharedPlayerDamage.scriptForce = game.create_force("sharedPlayerDamage")
    end
end

SharedPlayerDamage.OnEntityDamagedFilteredCharacter = function(event)
    if (not global.SharedPlayerDamage.enabled) or event.force == global.SharedPlayerDamage.scriptForce then
        return
    end
    if event.damage_type ~= nil and (event.damage_type == "snowball") then
        return
    end
    local tick = event.tick
    local damageToDo = math.floor(event.original_damage_amount * damageMultiplier)
    local damagedPlayer = event.entity.player
    global.SharedPlayerDamage.lastPlayerDamageSharedName = damagedPlayer.name
    for i, player in pairs(game.connected_players) do
        if not (player.index == damagedPlayer.index) then
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
                    player.character.damage(damageToDo, global.SharedPlayerDamage.scriptForce, event.damage_type.name)
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
    local deadPlayer = game.get_player(event.player_index)
    game.print({"messages.jd_plays-december-2019-shared_damage_died_by_player", deadPlayer.name, deathCausingPlayer})
    if global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] == nil then
        global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] = 1
    else
        global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] = global.SharedPlayerDamage.playerCausedOthersDeaths[deathCausingPlayer] + 1
    end
    if global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayer.name] == nil then
        global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayer.name] = 1
    else
        global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayer.name] = global.SharedPlayerDamage.playerDeathsFromOthers[deadPlayer.name] + 1
    end
end

return SharedPlayerDamage
