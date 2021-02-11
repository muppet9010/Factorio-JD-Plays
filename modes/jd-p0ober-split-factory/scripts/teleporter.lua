local Teleporter = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")

local TeleportedTTL = 15 * 60 * 60

Teleporter.CreateGlobals = function()
    global.teleporter = global.teleporter or {}
    global.teleporter.teleporterIdToTeam = global.teleporter.teleporterIdToTeam or {}
    global.teleporter.teleportedPlayers = global.teleporter.teleportedPlayers or {}
    --[[
        [id] = {
            id = player index.
            oldCharacter = LuaEntity of the character entity they left in their own team's side.
            newCharacter = LuaEntity of the character entity they gained in the other team's side.
            timeTransfered = tick they transferred across.
            timeToDie = time of this teleported character to die.
        }
    ]]
end

Teleporter.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "Teleporter.OnScriptTriggerEffect", Teleporter.OnScriptTriggerEffect)
    Interfaces.RegisterInterface("Teleporter.AddTeleporter", Teleporter.AddTeleporter)
end

Teleporter.AddTeleporter = function(ownerTeam, surface, position)
    local teleporterEntity = surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-teleporter", position = position, force = "player"}
    teleporterEntity.destructible = false
    global.teleporter.teleporterIdToTeam[teleporterEntity.unit_number] = ownerTeam

    return teleporterEntity
end

Teleporter.OnScriptTriggerEffect = function(event)
    if event.effect_id == "jd_plays-jd_p0ober_split_factory-teleporter-affected_target" then
        local triggerEntity = event.target_entity
        -- A triggerEntity with no player is a left behind character, so just ignore these.
        if triggerEntity.valid and triggerEntity.player ~= nil then
            Teleporter.TeleportPlayer(triggerEntity, event.source_entity)
        end
    end
end

Teleporter.TeleportPlayer = function(characterEntity, teleporterEntity)
    local player, teleporterTeam = characterEntity.player, global.teleporter.teleporterIdToTeam[teleporterEntity.unit_number]
    local playerTeam = global.playerHome.playerIdToTeam[player.index]

    if playerTeam.id == teleporterTeam.id then
        -- Player is leaving their team's side and going to the other team's side.
        local teleportedPlayerEntry = {
            id = player.index,
            oldCharacter = characterEntity,
            timeTransfered = game.tick,
            timeToDie = game.tick + TeleportedTTL
        }

        -- Detach and handle old character entity.
        player.character = nil
        --TODO: find valid spot first
        characterEntity.teleport(playerTeam.spawnPosition)
        characterEntity.walking_state = {walking = false}

        -- Move to new position and create character there.
        --TODO: find valid spot first
        player.teleport(playerTeam.otherTeam.spawnPosition)
        player.create_character()
        teleportedPlayerEntry.newCharacter = player.character

        --TODO: schedule a return
        --TODO: record for this newCharacter to have its death tracked and handled
        global.teleporter.teleportedPlayers[teleportedPlayerEntry.id] = teleportedPlayerEntry
    else
        -- Player is leaving the other team's side and returning to their team's side.
        local teleportedPlayerEntry = global.teleporter.teleportedPlayers[player.index]
        player.character = teleportedPlayerEntry.oldCharacter
        --TODO: drop all inventories on the ground
        teleportedPlayerEntry.newCharacter.destroy() -- Don't kill as messes up death statistics.
        --TODO: end the scheduled return
        global.teleporter.teleportedPlayers[player.index] = nil
    end
end

return Teleporter
