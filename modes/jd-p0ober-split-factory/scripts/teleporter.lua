local Teleporter = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local EventScheduler = require("utility/event-scheduler")
local Logging = require("utility/logging")

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
    EventScheduler.RegisterScheduledEventType("Teleporter.OnTimeToDieReached", Teleporter.OnTimeToDieReached)
    Events.RegisterHandlerEvent(defines.events.on_player_died, "Teleporter.OnPlayerDied", Teleporter.OnPlayerDied)
end

Teleporter.AddTeleporter = function(ownerTeam, surface, position)
    local teleporterEntity = surface.create_entity {name = "jd_plays-jd_p0ober_split_factory-teleporter", position = position, force = "player"}
    teleporterEntity.destructible = false
    global.teleporter.teleporterIdToTeam[teleporterEntity.unit_number] = ownerTeam

    local hazardTilesToSet = {}
    for x = teleporterEntity.position.x - 2, teleporterEntity.position.x + 1 do
        for y = teleporterEntity.position.y - 2, teleporterEntity.position.y + 1 do
            table.insert(hazardTilesToSet, {name = "hazard-concrete-left", position = {x = x, y = y}})
        end
    end
    surface.set_tiles(hazardTilesToSet, true, true, false, false)

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

        EventScheduler.ScheduleEvent(teleportedPlayerEntry.timeToDie, "Teleporter.OnTimeToDieReached", teleportedPlayerEntry.id)
        global.teleporter.teleportedPlayers[teleportedPlayerEntry.id] = teleportedPlayerEntry
    else
        -- Player is leaving the other team's side and returning to their team's side.
        Teleporter.TeleportCharacter(player, playerTeam.spawnPosition)
        Teleporter.OnPlayerDied({player_index = player.index}) -- Called as same actions to be done.
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

    -- Teleport now empty character to new location and reset.
    local foundPosition = character.surface.find_non_colliding_position("character", targetPosition, 0, 0.2, false)
    player.teleport(foundPosition)
    character.health = 100000
    if character.stickers ~= nil then
        for _, sticker in pairs(character.stickers) do
            sticker.destroy()
        end
    end
end

Teleporter.OnTimeToDieReached = function(event)
    local player = event.instanceId
    local teleportedPlayerEntry = global.teleporter.teleportedPlayers[event.instanceId]
    if event.tick ~= teleportedPlayerEntry.timeToDie then
        -- Some how the event has been called on the wrong tick, likely not tidied up for some edge case. So just abort the function to be safe.
        Logging.LogPrint("WARNING: teleport on time to die reached for player '" .. player.name .. "' when it wasn't active any more. Called on tick " .. event.tick .. ", but scheduled for this player next on tick " .. tostring(teleportedPlayerEntry.timeToDie) .. ".")
        return
    end
    local playerTeam = global.playerHome.playerIdToTeam[player.index]
    player.character.die(player.force, playerTeam.teleporterEntity)
end

Teleporter.OnPlayerDied = function(event)
    local player = game.get_player(event.player_index)
    local teleportedPlayerEntry = global.teleporter.teleportedPlayers[player.index]
    if teleportedPlayerEntry ~= nil then
        EventScheduler.RemoveScheduledEvents("Teleporter.OnTimeToDieReached", teleportedPlayerEntry.id, teleportedPlayerEntry.timeToDie)
    end
    global.teleporter.teleportedPlayers[player.index] = nil
end

return Teleporter
