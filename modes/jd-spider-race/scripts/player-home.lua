local PlayerHome = {}

local Utils = require("utility.utils")
local Commands = require("utility/commands")
local Events = require("utility/events")
local EventScheduler = require("utility.event-scheduler")
local Logging = require("utility/logging")
local Colors = require("utility.colors")
local GuiUtil = require("utility.gui-util")
local GuiActionsClick = require("utility.gui-actions-click")
local MuppetStyles = require("utility.style-data").MuppetStyles

---@class JdSpiderRace_PlayerHome_Team
---@field id JdSpiderRace_PlayerHome_PlayerTeamNames
---@field prettyName string @ The nice name to use in GUIs and messages. Can be set at runtime via the approperiate command.
---@field playerForce LuaForce @ Ref to the player force for this team.
---@field enemyForce LuaForce @ The biter force in this teams lane of the map.
---@field enemyForceName string
---@field spawnPosition MapPosition @ Position of this team's spawn.
---@field spawnChunk ChunkPosition @ Chunk with the spawn in it.
---@field players table<PlayerIndex, LuaPlayer> @ Table of the player who have joined this team.
---@field playerNames table<string, boolean> @ Table of player names who will/are on this team, with the value being if they ahve already joined the server yet. Player names can be pre-assigned and to a team so they are auto assigned on joining.
---@field otherTeam JdSpiderRace_PlayerHome_Team @ Ref to the other teams global object.
---@field mostLeftBuiltEntityXPosition double @ The most left built entity of this team. Used in spider Score GUI.

---@alias JdSpiderRace_PlayerHome_PlayerTeamNames '"north"'|'"south"'

---@class JdSpiderRace_PlayerHome_WaitingPlayerDetails
---@field id PlayerIndex
---@field player LuaPlayer
---@field playerName string
---@field origionalPermissionGroup LuaPermissionGroup

PlayerHome.CreateGlobals = function()
    global.playerHome = global.playerHome or {}

    global.playerHome.teams = global.playerHome.teams or {} ---@type table<JdSpiderRace_PlayerHome_PlayerTeamNames, JdSpiderRace_PlayerHome_Team> @ Team name to team object.
    global.playerHome.playerIdToTeam = global.playerHome.playerIdToTeam or {} ---@type table<PlayerIndex, JdSpiderRace_PlayerHome_Team> @ Player to their team object.
    global.playerHome.waitingRoomPlayers = global.playerHome.waitingRoomPlayers or {} ---@type table<PlayerIndex, JdSpiderRace_PlayerHome_WaitingPlayerDetails> @ Player's initial permissions group name from before they were put in the waiting room.
    global.playerHome.playerManagerGuiOpened = global.playerHome.playerManagerGuiOpened or {} ---@type table<PlayerIndex, LuaPlayer>

    global.playerHome.spawnXOffset = -256 -- Distance in from the coastline.
end

PlayerHome.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_player_created, "PlayerHome.OnPlayerCreated", PlayerHome.OnPlayerCreated)
    EventScheduler.RegisterScheduledEventType("PlayerHome.DelayedPlayerCreated_Scheduled", PlayerHome.DelayedPlayerCreated_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_marked_for_deconstruction, "PlayerHome.OnMarkedForDeconstruction", PlayerHome.OnMarkedForDeconstruction)
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "PlayerHome.OnBuiltEntity", PlayerHome.OnBuiltEntity)
    Events.RegisterHandlerEvent(defines.events.on_market_item_purchased, "PlayerHome.OnMarketItemPurchased", PlayerHome.OnMarketItemPurchased)

    Commands.Register("spider_assign_player_to_team", {"api-description.jd_plays-jd_spider_race-spider_assign_player_to_team"}, PlayerHome.Command_AssignPlayerToTeam, true)
    Commands.Register("spider_set_teams_pretty_name", {"api-description.jd_plays-jd_spider_race-spider_set_teams_pretty_name"}, PlayerHome.Command_SetTeamsPrettyName, true)

    Events.RegisterHandlerEvent(defines.events.on_lua_shortcut, "PlayerHome.OnLuaShortcut", PlayerHome.OnLuaShortcut)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PlayerHome.On_PlayerManagerCloseButtonClicked", PlayerHome.On_PlayerManagerCloseButtonClicked)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PlayerHome.On_PlayerManagerPlayerNameClicked", PlayerHome.On_PlayerManagerPlayerNameClicked)
    GuiActionsClick.LinkGuiClickActionNameToFunction("PlayerHome.On_PlayerManagerAssignPlayerClicked", PlayerHome.On_PlayerManagerAssignPlayerClicked)
end

PlayerHome.OnStartup = function()
    if global.playerHome.teams["north"] == nil then
        PlayerHome.CreateTeam("north", global.map.dividerMiddleYPos - (global.general.perTeamMapHeight / 2), global.playerHome.spawnXOffset)
        PlayerHome.CreateTeam("south", global.map.dividerMiddleYPos + (global.general.perTeamMapHeight / 2), global.playerHome.spawnXOffset)
        global.playerHome.teams["north"].otherTeam = global.playerHome.teams["south"]
        global.playerHome.teams["south"].otherTeam = global.playerHome.teams["north"]

        -- Set JD and Mukkie to their initial teams.
        global.playerHome.teams["north"].playerNames["JD-Plays"] = false
        global.playerHome.teams["south"].playerNames["mukkie"] = false
    end

    -- Disable autofiring cross border. Manual damage is undone in reaction to the on_damaged_event.
    local north = global.playerHome.teams["north"].playerForce
    local north_enemy = global.playerHome.teams["north"].enemyForce
    local south = global.playerHome.teams["south"].playerForce
    local south_enemy = global.playerHome.teams["south"].enemyForce
    north.set_cease_fire(south, true)
    north.set_cease_fire(south_enemy, true)
    south.set_cease_fire(north, true)
    south.set_cease_fire(north_enemy, true)
    north_enemy.set_cease_fire(south, true)
    north_enemy.set_cease_fire(south_enemy, true)
    south_enemy.set_cease_fire(north, true)
    south_enemy.set_cease_fire(north_enemy, true)

    -- Don't allow firendly fire within the biter teams. To protect against spider nukes and flamethrower.
    north_enemy.friendly_fire = false
    south_enemy.friendly_fire = false

    -- Create permission group for waiting room
    local group = game.permissions.get_group("JDWaitingRoom") or game.permissions.create_group("JDWaitingRoom")
    for _, perm in pairs(defines.input_action) do
        group.set_allows_action(perm, false)
    end
    group.set_allows_action(defines.input_action.write_to_console, true) -- Allow spamming of chat if forgotten to be placed in a group.
    group.set_allows_action(defines.input_action.edit_permission_group, true) -- Needed for when the console command to assign a player is used the mod script can change the player's permission group, otherwise it fails. It wors fine ffor the GUI without this permission though. While admins could load up the default Factorio permission GUI and move themselves groups this would break other parts of the mod most likely.
    group.set_allows_action(defines.input_action.lua_shortcut, true) -- So admins can access the Player Manager GUI.
    group.set_allows_action(defines.input_action.gui_click, true) -- So admins can use the Player Manager GUI.
end

---@param teamId JdSpiderRace_PlayerHome_PlayerTeamNames
---@param spawnYPos float
---@param spawnXPos float
PlayerHome.CreateTeam = function(teamId, spawnYPos, spawnXPos)
    ---@type JdSpiderRace_PlayerHome_Team
    local team = {
        id = teamId,
        prettyName = string.gsub(teamId .. " team", "^%l", string.upper), -- Default starting value with a capitalied first letter.
        spawnPosition = {x = spawnXPos, y = spawnYPos},
        spawnChunk = Utils.GetChunkPositionForTilePosition({x = spawnXPos, y = spawnYPos}),
        players = {},
        playerNames = {},
        enemyForce = nil, -- Set later in this function.
        enemyForceName = teamId .. "_enemy",
        playerForce = nil, -- Set later in this function.
        otherTeam = nil, -- Set later in this function.
        mostLeftBuiltEntityXPosition = spawnXPos -- Starts at effectively 0 when.
    }
    team.playerForce = game.create_force(teamId)
    team.enemyForce = game.create_force(team.enemyForceName)

    global.playerHome.teams[teamId] = team

    team.playerForce.technologies["landfill"].enabled = false
end

--- When player first joins put thme in the waiting room.
---@param event on_player_created
PlayerHome.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    if player.controller_type == defines.controllers.cutscene then
        -- So we have a player character to teleport.
        player.exit_cutscene()
    end

    local playerName = player.name

    -- Check if the player has been pre-assigned to a team.
    for _, team in pairs(global.playerHome.teams) do
        if team.playerNames[playerName] ~= nil then
            -- Player is pre-assigned to this team.

            -- Record player to new team and update player's force.
            local playerId = player.index
            team.players[playerId] = player
            global.playerHome.playerIdToTeam[playerId] = team
            player.force = team.playerForce
            team.playerNames[playerName] = true

            -- Move them to the surface and position them.
            PlayerHome.DelayedPlayerCreated_Scheduled({tick = event.tick, instanceId = playerId})

            PlayerHome.UpdateAllOpenPlayerManagerGuis()
            return
        end
    end

    -- Store the players initial permission group name for use when assigning them to a force.
    global.playerHome.waitingRoomPlayers[event.player_index] = {
        id = event.player_index,
        player = player,
        playerName = playerName,
        origionalPermissionGroup = player.permission_group
    }

    -- Place player in waiting room on the correct surface.
    player.character.destroy()
    player.teleport({0, 0}, global.general.surface)
    player.permission_group = game.permissions.get_group("JDWaitingRoom")

    player.print({"message.jd_plays-jd_spider_race-player_home_welcome_1"}, Colors.lightgreen)
    player.print({"message.jd_plays-jd_spider_race-player_home_welcome_2"}, Colors.lightgreen)

    -- Update any player listing GUIs.
    PlayerHome.UpdateAllOpenPlayerManagerGuis()
end

--- To create a pre-assigned player to a team. Supports delayed looping back to itself if it fails during initial map generation.
---@param event UtilityScheduledEvent_CallbackObject
PlayerHome.DelayedPlayerCreated_Scheduled = function(event)
    local playerId = event.instanceId
    local player = game.get_player(playerId)

    -- Move them to the surface and position them.
    if player.character ~= nil then
        player.character.destroy() -- Clears any starting inventory just like if the player isn't pre-assigned a team.
    end
    player.teleport({0, 0}, global.general.surface)
    player.create_character()
    local playerMovedOk = PlayerHome.MovePlayerToSpawn(player)
    if not playerMovedOk then
        -- Can happen if this is run during initial map generation. Will just wait a few seconds and try movign the player again.
        player.print("Trying to respawn you in a few seconds after map has generated more.", Colors.lightgreen)
        EventScheduler.ScheduleEventOnce(event.tick + 180, "PlayerHome.DelayedPlayerCreated_Scheduled", playerId)
    end
end

--- Command to assign a player (current or future) to a team.
---@param event CustomCommandData
PlayerHome.Command_AssignPlayerToTeam = function(event)
    local args = Commands.GetArgumentsFromCommand(event.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_assign_player_to_team command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 2 then
        game.print(commandErrorMessagePrefix .. "Expecting two args.", Colors.lightred)
        return
    end

    local playerName = args[1]
    local teamName = args[2]

    local team = global.playerHome.teams[teamName]
    if team == nil then
        game.print(commandErrorMessagePrefix .. "Unknown team: " .. teamName, Colors.lightred)
        return
    end

    local assignedPlayer = game.get_player(playerName)
    PlayerHome.AssignPlayerToTeam(playerName, assignedPlayer, team)

    -- If player not on server report that the player was pre-assigned to the team. If the player was on the server this would have been reported as part of moving them already.
    if assignedPlayer == nil then
        game.print({"message.jd_plays-jd_spider_race-preassigned_player_to_team", playerName, team.prettyName})
    end
end

--- Assign the player to the team.
---@param playerName string
---@param player LuaPlayer|nil
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.AssignPlayerToTeam = function(playerName, player, team)
    -- Record the named player to be on the team (now and in the future).
    PlayerHome.AddPlayerNameToTeam(playerName, team)

    -- If the player has connected to the server move them to the team now.
    if player ~= nil then
        PlayerHome.MovePlayerToTeam(player, team, playerName)
    end

    -- Update all the GUIs that need to know.
    PlayerHome.UpdateAllOpenPlayerManagerGuis()
end

--- Add a player's name to the team's list of players and remove from the other team.
---@param playerName string
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.AddPlayerNameToTeam = function(playerName, team)
    team.playerNames[playerName] = false
    team.otherTeam.playerNames[playerName] = nil
end

--- Moves the current player to the team.
---@param player LuaPlayer
---@param team JdSpiderRace_PlayerHome_Team
PlayerHome.MovePlayerToTeam = function(player, team, playerName)
    game.print({"message.jd_plays-jd_spider_race-player_moved_to_team", playerName, team.prettyName})
    local playerId = player.index

    -- Record player to new team and update player's force.
    team.players[playerId] = player
    global.playerHome.playerIdToTeam[playerId] = team
    player.force = team.playerForce
    team.playerNames[playerName] = true

    -- Remove player from old team.
    team.otherTeam.players[playerId] = nil

    -- Check if the player is in the waiting room at present and handle next steps accordingly.
    local playerInWaitingRoomDetails = global.playerHome.waitingRoomPlayers[playerId]
    if playerInWaitingRoomDetails then
        -- Player is in the waiting room as we have a cached value for them.

        -- Take the player out of the waiting room (permission groups) and remove them from the waiting room player list.
        player.permission_group = playerInWaitingRoomDetails.origionalPermissionGroup
        global.playerHome.waitingRoomPlayers[playerId] = nil

        -- Give the player a character in the right spot.
        player.create_character()
        local playerMovedOk = PlayerHome.MovePlayerToSpawn(player)
        if not playerMovedOk then
            -- Can happen if this is run during initial map generation. Will just wait a few seconds and try movign the player again.
            player.print("Trying to respawn you in a few seconds after map has generated more.", Colors.lightgreen)
            EventScheduler.ScheduleEventOnce(game.tick + 180, "PlayerHome.DelayedPlayerCreated_Scheduled", playerId)
        end
    else
        -- Player wasn't in the waiting room, so must have been already assigned to a team and is in a normal state.

        -- So kill them and they will respawn on the new team. This will leave any current equipment on the old (correct) side of the map.
        if player.character ~= nil then
            -- If in Editor mode then no character.
            player.character.die()
        end
    end
end

--- Move the players character to the team's spawn area. As in most cases the player will be at {0,0} on the map currently.
---@param player LuaPlayer
---@return boolean playerMovedCorrectly @ Can be false if this runs during map generation for a pre-assigned player.
PlayerHome.MovePlayerToSpawn = function(player)
    local team = global.playerHome.playerIdToTeam[player.index]
    local targetPos, surface = team.spawnPosition, global.general.surface

    local foundPos = surface.find_non_colliding_position("character", targetPos, 50, 0.2)
    if foundPos == nil then
        Logging.LogPrint("ERROR: no position found for player '" .. player.name .. "' near '" .. Logging.PositionToString(targetPos) .. "' on surface '" .. surface.name .. "'")
        return false
    end
    local teleported = player.teleport(foundPos, surface)
    if teleported ~= true then
        Logging.LogPrint("ERROR: teleport failed for player '" .. player.name .. "' to '" .. Logging.PositionToString(foundPos) .. "' on surface '" .. surface.name .. "'")
        return false
    end

    return true
end

--- Called from central control.lua.
---@param event on_entity_damaged
PlayerHome.OnEntityDamaged = function(event)
    -- Undo any damage done from one player team to the other.

    local event_force = event.force
    local event_entity = event.entity

    if event_force == nil or event_entity == nil then
        -- should never happen. Defensive coding
        return
    end

    local from_force_name = event_force.name
    local to_force_name = event_entity.force.name

    -- We could generically loop over all forces, but lets squeeze any
    -- performance we can out of this code
    if (from_force_name == "north" and to_force_name == "south") or (from_force_name == "south" and to_force_name == "north") then
        -- undo the damage done
        event_entity.health = event_entity.health + event.final_damage_amount

        return
    end
end

--- Stop deconstruction from the wrong side of the wall.
---@param event on_marked_for_deconstruction
PlayerHome.OnMarkedForDeconstruction = function(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if player == nil then
        return
    end

    local team = global.playerHome.playerIdToTeam[player.index]
    if team == nil or entity == nil or not entity.valid then
        return
    end

    if event.entity.position.y < 0 then
        -- Entity marked for deconstruction was north side of divider.
        if team.id == "south" then
            entity.cancel_deconstruction(team.playerForce, player)
        end
    else
        -- Entity marked for deconstruction was south side of divider.
        if team.id == "north" then
            entity.cancel_deconstruction(team.playerForce, player)
        end
    end
end

-- Stop players building on the wrong side.
---@param event on_built_entity
PlayerHome.OnBuiltEntity = function(event)
    local player = game.get_player(event.player_index)

    if player == nil then
        return
    end

    local team = global.playerHome.playerIdToTeam[player.index]
    local entity = event.created_entity

    if team == nil or entity == nil or not entity.valid then
        return
    end

    local to_destroy = false
    local entity_position = entity.position
    if entity_position.y < 0 then
        -- Entity built on north side of divider.
        if team.id == "south" then
            to_destroy = true
        end
    else
        -- Entity built on south side of divider.
        if team.id == "north" then
            to_destroy = true
        end
    end

    if to_destroy then
        -- Entity invalid so remove it.
        entity.surface.create_entity({name = "flying-text", position = entity_position, text = "Cannot build on other side of wall"})

        if not player.mine_entity(entity, true) then
            entity.destroy()
        end
    else
        -- Entity valid so leave it be.

        -- If this is the left most built entity for this team record its x position and notify spider code.
        if entity_position.x < team.mostLeftBuiltEntityXPosition then
            team.mostLeftBuiltEntityXPosition = entity_position.x
            MOD.Interfaces.Spider.OnNewMostWestEntityBuilt(team, entity_position)
        end
    end
end

--- Called when a player purchases an item in the market. In our mod this will only ever be to nuke the other team.
---@param event on_market_item_purchased
PlayerHome.OnMarketItemPurchased = function(event)
    if remote.interfaces["JDGoesBoom"] == nil or remote.interfaces["JDGoesBoom"]["ForceGoesBoom"] == nil then
        game.print("JD Goes Boom mod not installed, so coin wasted", Colors.lightred)
        return
    end

    -- Trigger the nuke on the other team.
    local otherTeam = global.playerHome.playerIdToTeam[event.player_index].otherTeam
    remote.call("JDGoesBoom", "ForceGoesBoom", otherTeam.id, 60, 60)
    game.print({"message.jd_plays-jd_spider_race-blow_up_other_team", otherTeam.prettyName}, Colors.lightgreen)

    -- Remove the fake item the player just brought.
    local player = game.get_player(event.player_index)
    player.remove_item({name = "jd_plays-jd_spider_race-nuke_other_team"})
end

--- Called when a shortcut is used by a player. Check if it was a shortcut we are monitoring.
---@param event on_lua_shortcut
PlayerHome.OnLuaShortcut = function(event)
    local shortcutName = event.prototype_name
    if shortcutName == "jd_plays-jd_spider_race-player_manager-gui_button" then
        local player = game.get_player(event.player_index)
        if player.admin then
            if global.playerHome.playerManagerGuiOpened[event.player_index] ~= nil then
                PlayerHome.Gui_ClosePlayerManagerForPlayer(player, event.player_index)
            else
                PlayerHome.Gui_OpenPlayerManagerForPlayer(player, event.player_index)
            end
        else
            player.print("Only admins can open the Player Manager GUI", Colors.lightred)
        end
    end
end

--- Open the Player Manager GUI for the player.
---@param player LuaPlayer
---@param playerIndex PlayerIndex
PlayerHome.Gui_OpenPlayerManagerForPlayer = function(player, playerIndex)
    global.playerHome.playerManagerGuiOpened[playerIndex] = player
    player.set_shortcut_toggled("jd_plays-jd_spider_race-player_manager-gui_button", true)

    -- Code notes:
    --      In names "pm" stands for "PlayerManager".
    --      All caption and tooltip names must be manually defined and be prefixed with "jd_plays-jd_spider_race-" so the locale names don't conflict with other modes. As only the mod name is pulled through in to the auto generated names, not the mode name.
    GuiUtil.AddElement(
        {
            parent = player.gui.screen,
            descriptiveName = "pm_main",
            type = "frame",
            direction = "vertical",
            style = MuppetStyles.frame.main_shadowRisen.paddingBR,
            storeName = "PlayerManager",
            attributes = {
                auto_center = true
            },
            children = {
                {
                    -- Header bar of the GUI.
                    type = "flow",
                    direction = "horizontal",
                    style = MuppetStyles.flow.horizontal.marginTL,
                    styling = {horizontal_align = "left", right_padding = 4},
                    children = {
                        {
                            type = "label",
                            style = MuppetStyles.label.heading.large.bold_paddingSides,
                            caption = {"gui-caption.jd_plays-jd_spider_race-pm_title"}
                        },
                        {
                            descriptiveName = "pm_dragBar",
                            type = "empty-widget",
                            style = "draggable_space",
                            styling = {horizontally_stretchable = true, height = 20, top_margin = 4, minimal_width = 80},
                            attributes = {
                                drag_target = function()
                                    return GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "PlayerManager", "pm_main", "frame")
                                end
                            }
                        },
                        {
                            type = "flow",
                            direction = "horizontal",
                            style = MuppetStyles.flow.horizontal.spaced,
                            styling = {horizontal_align = "right", top_margin = 4},
                            children = {
                                {
                                    descriptiveName = "pm_closeButton",
                                    type = "sprite-button",
                                    sprite = "utility/close_white",
                                    style = MuppetStyles.spriteButton.frameCloseButtonClickable,
                                    registerClick = {actionName = "PlayerHome.On_PlayerManagerCloseButtonClicked"}
                                }
                            }
                        }
                    }
                },
                {
                    -- Contents container.
                    type = "flow",
                    direction = "vertical",
                    style = MuppetStyles.flow.vertical.plain,
                    children = {
                        {
                            -- Player lists area.
                            type = "flow",
                            direction = "horizontal",
                            style = MuppetStyles.flow.horizontal.plain,
                            children = {
                                {
                                    -- North player container.
                                    type = "frame",
                                    direction = "vertical",
                                    style = MuppetStyles.frame.content_shadowSunken.marginTL_paddingBR,
                                    styling = {horizontally_stretchable = true, width = 400, height = 400},
                                    children = {
                                        {
                                            -- North player title
                                            type = "label",
                                            style = MuppetStyles.label.text.medium.semibold_paddingSides,
                                            caption = global.playerHome.teams["north"].prettyName
                                        },
                                        {
                                            -- North players list.
                                            type = "frame",
                                            direction = "vertical",
                                            style = MuppetStyles.frame.contentInnerDark_shadowSunken.marginTL,
                                            children = {
                                                {
                                                    descriptiveName = "pm_north_players",
                                                    type = "scroll-pane",
                                                    direction = "vertical",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.scroll.plain,
                                                    styling = {horizontally_stretchable = true, vertically_stretchable = true}
                                                }
                                            }
                                        }
                                    }
                                },
                                {
                                    -- Waiting player container.
                                    type = "frame",
                                    direction = "vertical",
                                    style = MuppetStyles.frame.content_shadowSunken.marginTL_paddingBR,
                                    styling = {horizontally_stretchable = true, width = 400, height = 400},
                                    children = {
                                        {
                                            -- Waiting player title
                                            type = "label",
                                            style = MuppetStyles.label.text.medium.semibold_paddingSides,
                                            caption = {"gui-caption.jd_plays-jd_spider_race-waiting_title"}
                                        },
                                        {
                                            -- Waiting players list.
                                            type = "frame",
                                            direction = "vertical",
                                            style = MuppetStyles.frame.contentInnerDark_shadowSunken.marginTL,
                                            children = {
                                                {
                                                    descriptiveName = "pm_waiting_players",
                                                    type = "scroll-pane",
                                                    direction = "vertical",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.scroll.plain,
                                                    styling = {horizontally_stretchable = true, vertically_stretchable = true}
                                                }
                                            }
                                        }
                                    }
                                },
                                {
                                    -- South player container.
                                    type = "frame",
                                    direction = "vertical",
                                    style = MuppetStyles.frame.content_shadowSunken.marginTL_paddingBR,
                                    styling = {horizontally_stretchable = true, width = 400, height = 400},
                                    children = {
                                        {
                                            -- South player title
                                            type = "label",
                                            style = MuppetStyles.label.text.medium.semibold_paddingSides,
                                            caption = global.playerHome.teams["south"].prettyName
                                        },
                                        {
                                            -- South players list.
                                            type = "frame",
                                            direction = "vertical",
                                            style = MuppetStyles.frame.contentInnerDark_shadowSunken.marginTL,
                                            children = {
                                                {
                                                    descriptiveName = "pm_south_players",
                                                    type = "scroll-pane",
                                                    direction = "vertical",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.scroll.plain,
                                                    styling = {horizontally_stretchable = true, vertically_stretchable = true}
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        {
                            -- Player assignment area.
                            type = "frame",
                            direction = "vertical",
                            style = MuppetStyles.frame.content_shadowSunken.marginTL,
                            styling = {horizontally_stretchable = true, vertically_stretchable = true},
                            children = {
                                {
                                    -- Player assignment button area.
                                    type = "flow",
                                    direction = "horizontal",
                                    style = MuppetStyles.flow.horizontal.marginTL,
                                    children = {
                                        {
                                            type = "flow",
                                            direction = "horizontal",
                                            style = MuppetStyles.flow.horizontal.plain,
                                            styling = {horizontal_align = "center", width = 400},
                                            children = {
                                                {
                                                    descriptiveName = "pm_assign_player_north",
                                                    type = "button",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.button.text.medium.paddingSides,
                                                    styling = {width = 200},
                                                    caption = {"gui-caption.jd_plays-jd_spider_race-assign_player_north"},
                                                    registerClick = {actionName = "PlayerHome.On_PlayerManagerAssignPlayerClicked", data = "north"},
                                                    enabled = false
                                                }
                                            }
                                        },
                                        {
                                            type = "frame",
                                            direction = "horizontal",
                                            style = MuppetStyles.frame.contentInnerDark.plain,
                                            styling = {horizontal_align = "center", width = 400, vertical_align = "center"},
                                            children = {
                                                {
                                                    descriptiveName = "pm_selected_player_name",
                                                    type = "label",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.label.text.medium.plain,
                                                    caption = {"gui-caption.jd_plays-jd_spider_race-pm_no_player_selected"}
                                                }
                                            }
                                        },
                                        {
                                            type = "flow",
                                            direction = "horizontal",
                                            style = MuppetStyles.flow.horizontal.plain,
                                            styling = {horizontal_align = "center", width = 400},
                                            children = {
                                                {
                                                    descriptiveName = "pm_assign_player_south",
                                                    type = "button",
                                                    storeName = "PlayerManager",
                                                    style = MuppetStyles.button.text.medium.paddingSides,
                                                    styling = {width = 200},
                                                    caption = {"gui-caption.jd_plays-jd_spider_race-assign_player_south"},
                                                    registerClick = {actionName = "PlayerHome.On_PlayerManagerAssignPlayerClicked", data = "south"},
                                                    enabled = false
                                                }
                                            }
                                        }
                                    }
                                },
                                {
                                    -- Assign player instructions.
                                    type = "label",
                                    style = MuppetStyles.label.text.small.marginTL_paddingSides,
                                    styling = {width = 1200},
                                    caption = {"gui-caption.jd_plays-jd_spider_race-pm_instructions"}
                                }
                            }
                        }
                    }
                }
            }
        }
    )

    PlayerHome.UpdatePlayersInPlayerManagerGui(playerIndex)
end

--- When the player clicks the close button on their Player Manager GUI.
---@param event UtilityGuiActionsClick_ActionData
PlayerHome.On_PlayerManagerCloseButtonClicked = function(event)
    PlayerHome.Gui_ClosePlayerManagerForPlayer(global.playerHome.playerManagerGuiOpened[event.playerIndex], event.playerIndex)
end

--- Called to close a player's Player Manager GUI.
---@param player LuaPlayer
---@param playerIndex PlayerIndex
PlayerHome.Gui_ClosePlayerManagerForPlayer = function(player, playerIndex)
    GuiUtil.DestroyPlayersReferenceStorage(playerIndex, "PlayerManager")
    global.playerHome.playerManagerGuiOpened[playerIndex] = nil
    player.set_shortcut_toggled("jd_plays-jd_spider_race-player_manager-gui_button", false)
end

--- Called when a player changes team or joins the server so anyone with the Player Manager GUI open needs to be updated.
PlayerHome.UpdateAllOpenPlayerManagerGuis = function()
    for playerIndex, player in pairs(global.playerHome.playerManagerGuiOpened) do
        -- If the admin player is online then refresh their GUI, but if they are offline just close the GUI to avoid it being checked again.
        if player.connected then
            PlayerHome.UpdatePlayersInPlayerManagerGui(playerIndex)
        else
            PlayerHome.Gui_ClosePlayerManagerForPlayer(player, playerIndex)
        end
    end
end

--- Called to update the player's list in the Player Manager GUI for an admin player who has the GUI currently open.
---@param playerIndex PlayerIndex
PlayerHome.UpdatePlayersInPlayerManagerGui = function(playerIndex)
    -- Check the GUI is still there (valid) as we expect it to be.
    local playerManagerGuiElement = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "PlayerManager", "pm_main", "frame")
    if playerManagerGuiElement == nil or not playerManagerGuiElement.valid then
        -- GUI isn't present, so re-open it. This will also re-call this function to show the curernt players.
        PlayerHome.Gui_OpenPlayerManagerForPlayer(global.playerHome.playerManagerGuiOpened[playerIndex], playerIndex)
        return
    end

    local northPlayerListGui = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "PlayerManager", "pm_north_players", "scroll-pane")
    northPlayerListGui.clear()
    for playerName, connectedToServer in pairs(global.playerHome.teams["north"].playerNames) do
        PlayerHome.AddPlayerToListInPlayerManagerGui(northPlayerListGui, playerName, connectedToServer)
    end

    local waitingPlayerListGui = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "PlayerManager", "pm_waiting_players", "scroll-pane")
    waitingPlayerListGui.clear()
    for _, waitingPlayerDetails in pairs(global.playerHome.waitingRoomPlayers) do
        PlayerHome.AddPlayerToListInPlayerManagerGui(waitingPlayerListGui, waitingPlayerDetails.playerName, true)
    end

    local southPlayerListGui = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "PlayerManager", "pm_south_players", "scroll-pane")
    southPlayerListGui.clear()
    for playerName, connectedToServer in pairs(global.playerHome.teams["south"].playerNames) do
        PlayerHome.AddPlayerToListInPlayerManagerGui(southPlayerListGui, playerName, connectedToServer)
    end
end

--- Adds a player button/label to a player list.
---@param playerListGui LuaGuiElement
---@param playerName string
---@param connectedToServer boolean
PlayerHome.AddPlayerToListInPlayerManagerGui = function(playerListGui, playerName, connectedToServer)
    if connectedToServer then
        GuiUtil.AddElement(
            {
                parent = playerListGui,
                descriptiveName = "pm_player_name" .. playerName,
                type = "button",
                style = MuppetStyles.button.text.medium.paddingSides,
                styling = {height = 24, top_padding = -2},
                caption = playerName,
                registerClick = {actionName = "PlayerHome.On_PlayerManagerPlayerNameClicked", data = playerName}
            }
        )
    else
        GuiUtil.AddElement(
            {
                parent = playerListGui,
                type = "label",
                style = MuppetStyles.label.text.medium.plain,
                styling = {horizontally_stretchable = true},
                caption = {"gui-caption.jd_plays-jd_spider_race-pm_player_not_connected", playerName}
            }
        )
    end
end

-- When an admin clicks on a player's name in the Player Manager GUI. The player's name is the event.data.
---@param event UtilityGuiActionsClick_ActionData
PlayerHome.On_PlayerManagerPlayerNameClicked = function(event)
    local playerName, adminPlayerIndex = event.data, event.playerIndex

    -- Update the GUI to show this admin the player they have clicked on.
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_selected_player_name", "label", {caption = playerName}, false)

    -- Enable the 2 assignment buttons.
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_assign_player_north", "button", {enabled = true}, false)
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_assign_player_south", "button", {enabled = true}, false)
end

-- When an admin clicks to assign a player to a team via the Player Manager GUI. The assigned team is the event.data.
---@param event UtilityGuiActionsClick_ActionData
PlayerHome.On_PlayerManagerAssignPlayerClicked = function(event)
    local newTeamName, adminPlayerIndex = event.data, event.playerIndex
    local playerName = GuiUtil.GetElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_selected_player_name", "label").caption
    local player = game.get_player(playerName)

    -- Move the player if they are not currently on the assigned team.
    local playersCurrentTeam = global.playerHome.playerIdToTeam[player.index]
    if playersCurrentTeam == nil or newTeamName ~= playersCurrentTeam.id then
        -- Player not currently on the selected team, so move them.
        PlayerHome.AssignPlayerToTeam(playerName, player, global.playerHome.teams[newTeamName])
    end

    -- Reset our GUI in all cases.
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_selected_player_name", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-pm_no_player_selected"}}, false)
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_assign_player_north", "button", {enabled = false}, false)
    GuiUtil.UpdateElementFromPlayersReferenceStorage(adminPlayerIndex, "PlayerManager", "pm_assign_player_south", "button", {enabled = false}, false)
end

---@param event CustomCommandData
PlayerHome.Command_SetTeamsPrettyName = function(event)
    local args = Commands.GetArgumentsFromCommand(event.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_set_teams_pretty_name command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args < 2 then
        game.print(commandErrorMessagePrefix .. "Expecting two args.", Colors.lightred)
        return
    end
    if #args > 2 then
        game.print(commandErrorMessagePrefix .. "Expecting two args. Try wrapping a team name with spaces in it within quotes. i.e. 'my team name'", Colors.lightred)
        return
    end

    local teamName = args[1]
    local prettyName = args[2]

    local team = global.playerHome.teams[teamName]
    if team == nil then
        game.print(commandErrorMessagePrefix .. "Unknown team: " .. teamName, Colors.lightred)
        return
    end

    team.prettyName = prettyName or "" -- Never let nil go in.
    game.print({"message.jd_plays-jd_spider_race-team_pretty_name_set", teamName, prettyName})
end

return PlayerHome
