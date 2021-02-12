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
            characterEntity = LuaEntity of the character entity they gained in the other team's side.
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
            timeTransfered = game.tick,
            timeToDie = game.tick + TeleportedTTL
        }

        Teleporter.TeleportCharacter(player, playerTeam.otherTeam.spawnPosition)
        teleportedPlayerEntry.characterEntity = player.character

        --TODO: schedule a return
        --TODO: record for this characterEntity to have its death tracked and handled
        global.teleporter.teleportedPlayers[teleportedPlayerEntry.id] = teleportedPlayerEntry
    else
        -- Player is leaving the other team's side and returning to their team's side.
        --local teleportedPlayerEntry = global.teleporter.teleportedPlayers[player.index]

        Teleporter.TeleportCharacter(player, playerTeam.spawnPosition)

        --TODO: end the scheduled return and stop tracking the characters death
        global.teleporter.teleportedPlayers[player.index] = nil
    end
end

Teleporter.TeleportCharacter = function(player, targetPosition)
    local character = player.character

    -- Create corpse for player and move all items in to it.
    local corpseEntity = character.surface.create_entity {name = "character-corpse", position = player.position, force = player.force, player_index = player.index, inventory_size = 1000, player = player}
    local corpseInventory = corpseEntity.get_inventory(defines.inventory.character_corpse)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_main), corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_guns), corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_ammo), corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_armor), corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_vehicle), corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_trash), corpseInventory, false, 1)
    if corpseInventory.is_empty() then
        -- If corpse inventory is empty it will auto vanish in 1 tick, so place a corpse without an inventory as well that will last.
        corpseEntity = character.surface.create_entity {name = "character-corpse", position = player.position, force = player.force, player_index = player.index, player = player}
    end
    corpseEntity.character_corpse_death_cause = {"entity-name.jdplays_mode-jd_p0ober_split_factory-teleport"}

    -- Teleport empty character to new location and heal.
    local foundPosition = character.surface.find_non_colliding_position("character", targetPosition, 0, 0.2, false)
    player.teleport(foundPosition)
    character.health = 100000
end

return Teleporter
