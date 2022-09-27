local Teleporter = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Logging = require("utility/logging")

---@class JDSplitFactory_Teleporter_TeleportedPlayer
---@field id uint # Player index.
---@field characterEntity LuaEntity # LuaEntity of the character entity they gained in the other team's side.
---@field timeTransferred Tick # Tick they transferred across.
---@field timeToDie Tick # Time of this teleported character to die.

local TeleportedTTL = 15 * 60 * 60

Teleporter.CreateGlobals = function()
    global.teleporter = global.teleporter or {} ---@class JDSplitFactory_Teleporter_Global
    global.teleporter.teleporterIdToTeam = global.teleporter.teleporterIdToTeam or {} ---@type table<uint, JDSplitFactory_PlayerHome_Team> # Key'd by teleporter unit number.
    global.teleporter.teleportedPlayers = global.teleporter.teleportedPlayers or {} ---@type table<uint, JDSplitFactory_Teleporter_TeleportedPlayer> # Key'd by player index.
    global.teleporter.teleportedPlayersToReturnHome = global.teleporter.teleportedPlayersToReturnHome or {} ---@type table<uint, true> # List players by index who are offline when their timer expires and so need returning home the moment they return to the server.
end

Teleporter.OnLoad = function()
    MOD.Interfaces.Teleporter = MOD.Interfaces.Teleporter or {}

    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "Teleporter.OnScriptTriggerEffect", Teleporter.OnScriptTriggerEffect)
    MOD.Interfaces.Teleporter.AddTeleporter = Teleporter.AddTeleporter
    EventScheduler.RegisterScheduledEventType("Teleporter.OnTimeToDieReached", Teleporter.OnTimeToDieReached)
    Events.RegisterHandlerEvent(defines.events.on_player_died, "Teleporter.OnPlayerDied", Teleporter.OnPlayerDied)
    Events.RegisterHandlerEvent(defines.events.on_player_joined_game, "Teleporter.OnPlayerJoined", Teleporter.OnPlayerJoined)
end

--- Called by team creation to add a teleporter.
---@param ownerTeam JDSplitFactory_PlayerHome_Team
---@param surface LuaSurface
---@param position MapPosition
---@return LuaEntity|nil
Teleporter.AddTeleporter = function(ownerTeam, surface, position)
    local teleporterEntity = surface.create_entity { name = "jd_plays-jd_split_factory-teleporter", position = position, force = "player" }
    if teleporterEntity == nil then
        game.print("Failed to create teleporter at hard coded location: " .. Logging.PositionToString(position), { r = 1.0, g = 0.0, b = 0.0, a = 1.0 })
        return nil
    end

    teleporterEntity.destructible = false
    global.teleporter.teleporterIdToTeam[teleporterEntity.unit_number--[[@as uint]] ] = ownerTeam

    local hazardTilesToSet = {}
    for x = teleporterEntity.position.x - 2, teleporterEntity.position.x + 1 do
        for y = teleporterEntity.position.y - 2, teleporterEntity.position.y + 1 do
            table.insert(hazardTilesToSet, { name = "hazard-concrete-left", position = { x = x, y = y } })
        end
    end
    surface.set_tiles(hazardTilesToSet, true, true, false, false)

    return teleporterEntity
end

--- Called when a script trigger effect goes off. In our case someone hopefully triggered a teleporter usage detection mine.
---@param event EventData.on_script_trigger_effect
Teleporter.OnScriptTriggerEffect = function(event)
    if event.effect_id == "jd_plays-jd_split_factory-teleporter-affected_target" then
        local triggerEntity = event.target_entity ---@cast triggerEntity - nil
        -- A triggerEntity with no player is a left behind character, so just ignore these.
        if triggerEntity.valid and triggerEntity.name == "character" and triggerEntity.player ~= nil then
            Teleporter.PlayerOnTeleporter(triggerEntity, event.source_entity)
        end
    end
end

--- Player triggered a teleporter.
---@param characterEntity LuaEntity
---@param teleporterEntity LuaEntity
Teleporter.PlayerOnTeleporter = function(characterEntity, teleporterEntity)
    local player, teleporterTeam = characterEntity.player, global.teleporter.teleporterIdToTeam[teleporterEntity.unit_number--[[@as uint]] ] ---@cast player - nil
    local playerTeam = global.playerHome.playerIdToTeam[player.index]

    if playerTeam.id == teleporterTeam.id then
        -- Player is leaving their team's side and going to the other team's side.
        local teleportedPlayerEntry = {
            id = player.index,
            timeTransferred = game.tick,
            timeToDie = game.tick + TeleportedTTL --[[@as Tick]]
        }

        Teleporter.TeleportCharacter(player, playerTeam.otherTeam.spawnPosition)
        teleportedPlayerEntry.characterEntity = player.character

        EventScheduler.ScheduleEventOnce(teleportedPlayerEntry.timeToDie, "Teleporter.OnTimeToDieReached", teleportedPlayerEntry.id--[[@as StringOrNumber]] )
        global.teleporter.teleportedPlayers[teleportedPlayerEntry.id] = teleportedPlayerEntry
    else
        -- Player is leaving the other team's side and returning to their team's side.
        Teleporter.ReturnPlayerHome(player)
    end
end

--- Called to teleport a character from their side to the other team's side.
---@param player LuaPlayer
---@param targetPosition MapPosition
Teleporter.TeleportCharacter = function(player, targetPosition)
    local character, surface = player.character, player.surface ---@cast character - nil # The player had to have a character to trigger the landmine.

    -- Create corpse for player and move all items in to it.
    local corpseEntity = surface.create_entity { name = "character-corpse", position = player.position, force = player.force, player_index = player.index, inventory_size = 1000, player = player } ---@cast corpseEntity - nil # Corpse will always succeed in creation.
    local corpseInventory = corpseEntity.get_inventory(defines.inventory.character_corpse) ---@cast corpseInventory - nil # Corpse will always have an inventory.
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_main)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_guns)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_ammo)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_armor)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_vehicle)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    Utils.TryMoveInventoriesLuaItemStacks(character.get_inventory(defines.inventory.character_trash)--[[@as LuaInventory # Even if it doesn't exist the receiving function accepts it.]] , corpseInventory, false, 1)
    if corpseInventory.is_empty() then
        -- If corpse inventory is empty it will auto vanish in 1 tick, so place a corpse without an inventory as well that will last.
        corpseEntity = surface.create_entity { name = "character-corpse", position = player.position, force = player.force, player_index = player.index, player = player }
    end
    corpseEntity.character_corpse_death_cause = { "entity-name.jdplays_mode-jd_split_factory-teleport" }

    -- Teleport now empty character to new location and reset.
    local foundPosition = surface.find_non_colliding_position("character", targetPosition, 0, 0.2, false) ---@cast foundPosition - nil # Searches whole map so will find somewhere.
    player.teleport(foundPosition)
    character.health = 100000.0
    if character.stickers ~= nil then
        for _, sticker in pairs(character.stickers) do
            sticker.destroy()
        end
    end

    surface.create_entity { name = "jd_plays-jd_split_factory-teleporter-player_moved", position = foundPosition }
end

--- When the time has expired for a player who teleported to the other side.
---@param event UtilityScheduledEvent_CallbackObject
Teleporter.OnTimeToDieReached = function(event)
    local playerIndex = event.instanceId --[[@as uint]]
    local player = game.get_player(playerIndex) ---@cast player - nil
    local teleportedPlayerEntry = global.teleporter.teleportedPlayers[playerIndex]
    if event.tick ~= teleportedPlayerEntry.timeToDie then
        -- Some how the event has been called on the wrong tick, likely not tidied up for some edge case. So just abort the function to be safe.
        Logging.LogPrint("WARNING: teleport on time to die reached for player '" .. player.name .. "' when it wasn't active any more. Called on tick " .. event.tick .. ", but scheduled for this player next on tick " .. tostring(teleportedPlayerEntry.timeToDie) .. ".")
        return
    end
    if player.character then
        Teleporter.ReturnPlayerHome(player)
    else
        -- Player is offline and so has no character and this event hasn't been cancelled already, so delay it for their return.
        global.teleporter.teleportedPlayersToReturnHome[playerIndex] = true
    end
end

--- Return a player back to their own side from the other team's side.
---@param player LuaPlayer
Teleporter.ReturnPlayerHome = function(player)
    local playerTeam = global.playerHome.playerIdToTeam[player.index]
    player.driving = false
    Teleporter.TeleportCharacter(player, playerTeam.spawnPosition)
    Teleporter.TidyUpTeleportedEntry(player)
end

--- When a player dies.
---@param event EventData.on_player_died
Teleporter.OnPlayerDied = function(event)
    local player = game.get_player(event.player_index) ---@cast player - nil
    Teleporter.TidyUpTeleportedEntry(player)
end

--- When a player has died or other situation that we need to check if they were on the other side and thus had a time tracker on them that needs to be removed.
---@param player LuaPlayer
Teleporter.TidyUpTeleportedEntry = function(player)
    local teleportedPlayerEntry = global.teleporter.teleportedPlayers[player.index]
    if teleportedPlayerEntry ~= nil then
        EventScheduler.RemoveScheduledOnceEvents("Teleporter.OnTimeToDieReached", teleportedPlayerEntry.id--[[@as StringOrNumber]] , teleportedPlayerEntry.timeToDie)
    end
    global.teleporter.teleportedPlayers[player.index] = nil
end

--- When a player joins the game.
---@param event EventData.on_player_joined_game
Teleporter.OnPlayerJoined = function(event)
    if global.teleporter.teleportedPlayersToReturnHome[event.player_index] == nil then
        return
    end
    local player = game.get_player(event.player_index) ---@cast player - nil
    Teleporter.ReturnPlayerHome(player)
end

return Teleporter
