local Events = require("utility/events")
local SharedPlayerDamage = {}
local ticksSafeAfterRespawn = 60 * 60
local damageMultiplier = 0.75

SharedPlayerDamage.CreateGlobals = function()
    global.SharedPlayerDamage = global.SharedPlayerDamage or {}
    global.SharedPlayerDamage.enabled = global.SharedPlayerDamage.enabled or true
    global.SharedPlayerDamage.PlayersLastRespawnTick = global.SharedPlayerDamage.PlayersLastRespawnTick or {}
end

SharedPlayerDamage.OnLoad = function()
    Events.RegisterHandler(defines.events.on_entity_damaged, "SharedPlayerDamage", SharedPlayerDamage.OnEntityDamagedFilteredCharacter, "type=character")
    Events.RegisterHandler(defines.events.on_player_respawned, "SharedPlayerDamage", SharedPlayerDamage.OnPlayerRespawned)
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
    for i, player in pairs(game.connected_players) do
        if not (player.name == event.entity.player.name) then
            if player.character ~= nil then
                local playerLastRespawn = global.SharedPlayerDamage.PlayersLastRespawnTick[player.index]
                local playerSafe = false
                if playerLastRespawn ~= nil then
                    if playerLastRespawn >= event.tick - ticksSafeAfterRespawn then
                        playerSafe = true
                    else
                        global.SharedPlayerDamage.PlayersLastRespawnTick[player.index] = nil
                    end
                end
                if not playerSafe then
                    local damageToDo = math.floor(event.original_damage_amount * damageMultiplier)
                    player.character.damage(damageToDo, global.SharedPlayerDamage.scriptForce, event.damage_type.name)
                end
            end
        end
    end
end

SharedPlayerDamage.OnPlayerRespawned = function(event)
    local playerId = event.player_index
    global.SharedPlayerDamage.PlayersLastRespawnTick[playerId] = event.tick
    local player = game.get_player(playerId)
    player.print({"messages.jd_plays-december-2019-shared_damage_respawn", (ticksSafeAfterRespawn / 60)}, {r = 1, g = 0, b = 0, a = 1})
end

return SharedPlayerDamage
