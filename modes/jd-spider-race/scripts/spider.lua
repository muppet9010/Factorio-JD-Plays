--[[
    This code was developed independantly of other parts of the mod and so will as self contained as possible. With anything needed being hard coded in local variables at the top of the file.
]]
--

local Spider = {}
local Utils = require("utility.utils")
local EventScheduler = require("utility/event-scheduler")
local Colors = require("utility.colors")
local Commands = require("utility.commands")

---@class BossSpider
---@field id UnitNumber @ The UnitNumber of the boss spider entity. Also the key in global.spiders.
---@field state BossSpider_State
---@field playerTeam LuaForce
---@field playerTeamName string
---@field biterTeam LuaForce
---@field bossEntity LuaEntity @ The main spider boss entity.
---@field distanceFromSpawn uint @ How far from spawn the spiders area is centered on (positive number).
---@field damageTakenThisSecond float
---@field secondsWhenDamaged table<Second, float> @ Only has entries for seconds when damage was done. May have seconds in this table older than the spiderDamageSecondsConsidered, but these will be cleared out upon the next second with damage occuring and aren't incorrectly counted.
---@field roamingXMin uint -- Far left of its roaming area.
---@field roamingXMax uint -- Far rigt of its roaming area.
---@field roamingYMin uint -- Far top of its roaming area.
---@field roamingYMax uint -- Far bottom of its roaming area.
---@field movementTargetPosition MapPosition|null @ Only populated if the spider is actively moving to this position.
---@field spiderPositionLastSecond MapPosition @ The spiders position last second.
---@field spiderPlanRenderIds Id[] -- used mainly for debugging and testing. But needs to be bleed throughout the code so made proper.

---@class BossSpider_State
local BossSpider_State = {
    roaming = "roaming", -- Just idling wondering its area.
    fighting = "fighting", -- Not significantly moving, but actively being managed in a combat state.
    chasing = "chasing", -- Actively chasing after a military target.
    retreating = "retreating", -- Moving away from the threat.
    dead = "dead" -- Its dead.
}

local Settings = {
    bossSpiderStartingLeftDistance = 5000,
    bossSpiderStartingVerticalDistance = 256, -- Half the height of each teams map area.
    spiderDamageToRetreat = 1000,
    spiderDamageSecondsConsidered = 30, -- How many seconds in the past the spider will consider to see if it has sustained enough damage to retreat.
    spidersRoamingXRange = 100,
    spidersRoamingYRange = 230, -- Bit less than half the height of each teams map area.
    showSpiderPlans = true -- If enabled the plans of a spider are rendered.
}

-- Testing is for development and is very adhoc in what it changes to allow simplier testing.
local Testing = true
if Testing then
    Settings.bossSpiderStartingLeftDistance = 50
    Settings.bossSpiderStartingVerticalDistance = 30
    Settings.spidersRoamingXRange = 20
    Settings.spidersRoamingYRange = 40
    Settings.showSpiderPlans = true
end

-- This must be created after the first batch of testing value changes are applied.
---@class PlayerForcesDetails
local PlayerForcesDetails = {
    -- Set the color alphas to half as otherwise they become very dark.
    {
        name = "north",
        biterTeamName = "north_enemy",
        spiderStartingYPosition = -Settings.bossSpiderStartingVerticalDistance,
        spiderColor = {0, 0, 0, 200} -- Deep black, but some highlighting still visible.
    },
    {
        name = "south",
        biterTeamName = "south_enemy",
        spiderStartingYPosition = Settings.bossSpiderStartingVerticalDistance,
        spiderColor = {0, 0, 0, 200} -- Deep black, but some highlighting still visible.
    }
}

-- This testing manipualtes the PlayerForcesDetails table before its used for anything.
if Testing then
    PlayerForcesDetails[1].biterTeamName = "enemy" -- Theres no extra enemy force in this code yet.
    PlayerForcesDetails[2] = nil -- Just 1 spider for simplier movement testing.
-- PlayerForcesDetails[2].biterTeamName = "player" -- So the 2 spiders fight and we can see them in combat.
-- PlayerForcesDetails[2].spiderColor = {0, 100, 255, 128} -- A light blue color.
end

local PlayerForcesNameToDetails = {} ---@type table<string, PlayerForcesDetails>
for _, details in pairs(PlayerForcesDetails) do
    PlayerForcesNameToDetails[details.name] = details
end

Spider.CreateGlobals = function()
    global.spider = global.spider or {}
    global.spider.spiders = global.spider.spiders or {} ---@type table<UnitNumber, BossSpider> @ Key'd by spiders UnitNumber
    global.spider.playerTeamsSpider = global.spider.playerTeamsSpider or {} ---@type table<string, BossSpider> @ The player team to the spider they are fighting.
    global.spider.showSpiderPlans = global.spider.showSpiderPlans or Settings.showSpiderPlans ---@type boolean
    global.spider.surface = global.spider.surface or nil ---@type LuaSurface
    global.spider.constantMovementFromSpawnPerMinute = global.spider.constantMovementFromSpawnPerMinute or 3 ---@type number
end

Spider.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Spider.CheckSpiders_Scheduled", Spider.CheckSpiders_Scheduled) -- CODE NOTE: in ideal world this would be a re-occuring scheduled event every SECOND, but this Utils version doesn't have that feature. One schedule action per second shouldn't be too UPS heavy.
    Commands.Register("change_spider_distance", {"api-description.jd_plays-jd_spider_race-change_spider_distance"}, Spider.Command_ChangeDistanceFromSpawn, true)
    Commands.Register("set_spider_movement_per_minute", {"api-description.jd_plays-jd_spider_race-set_spider_movement_per_minute"}, Spider.Command_SetSpiderMovementPerMinute, true)
    EventScheduler.RegisterScheduledEventType("Spider.SpidersMoveAwayFromSpawn_Scheduled", Spider.SpidersMoveAwayFromSpawn_Scheduled) -- CODE NOTE: in ideal world this would be a re-occuring scheduled event every MINUTE, but this Utils version doesn't have that feature. One schedule action per MINUTE shouldn't be too UPS heavy.
end

Spider.OnStartup = function()
    -- Set the cached surface reference.
    global.spider.surface = game.surfaces[1] -- TODO: this may need updating to the one we use with the map generation settings when merged in to the main code.

    -- Create the spiders for each team if they don't exist.
    if next(global.spider.spiders) == nil then
        for _, playerForceDetails in pairs(PlayerForcesDetails) do
            Spider.CreateSpider(playerForceDetails.name, playerForceDetails.spiderStartingYPosition, playerForceDetails.spiderColor, playerForceDetails.biterTeamName)
        end

        Spider.SetSpiderForcesTechs()

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEvent((math.floor(game.tick / 60) * 60) + 60, "Spider.CheckSpiders_Scheduled")

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEvent((math.floor(game.tick / 3600) * 3600) + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
    end
end

--- Create a new spidertron for the specific player team to fight against.
---@param playerTeamName string
---@param spidersYPos uint
---@param spiderColor Color
---@param biterTeamName string
Spider.CreateSpider = function(playerTeamName, spidersYPos, spiderColor, biterTeamName)
    local playerteam = game.forces[playerTeamName]
    local biterTeam = game.forces[biterTeamName]
    local spiderPosition = {x = -Settings.bossSpiderStartingLeftDistance, y = spidersYPos}
    -- They can be created in chunks that don't exist as they have a radar and thus will generate the chunks around them.
    local bossEntity = global.spider.surface.create_entity {name = "jd_plays-jd_spider_race-spidertron_boss", position = spiderPosition, force = biterTeam}
    if bossEntity == nil then
        error("Failed to create boss spider for team " .. playerTeamName .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
    end
    bossEntity.color = spiderColor

    ---@type BossSpider
    local spider = {
        id = bossEntity.unit_number,
        bossEntity = bossEntity,
        state = BossSpider_State.roaming,
        playerTeam = playerteam,
        playerTeamName = playerTeamName,
        biterTeam = biterTeam,
        distanceFromSpawn = Settings.bossSpiderStartingLeftDistance,
        damageTakenThisSecond = 0,
        secondsWhenDamaged = {},
        roamingYMin = spidersYPos - Settings.spidersRoamingYRange,
        roamingYMax = spidersYPos + Settings.spidersRoamingYRange,
        spiderPlanRenderIds = {},
        spiderPositionLastSecond = spiderPosition
    }
    Spider.UpdateSpidersRoamingValues(spider)

    -- Fill the spiders equipment grid.
    local spiderEquipmentGrid = spider.bossEntity.grid
    for i = 1, 15 do
        spiderEquipmentGrid.put {name = "personal-laser-defense-equipment"}
    end
    for i = 1, 7 do
        spiderEquipmentGrid.put {name = "battery-mk2-equipment"}
    end
    for i = 1, 18 do
        spiderEquipmentGrid.put {name = "solar-panel-equipment"}
    end

    -- Record the spider to globals.
    global.spider.spiders[spider.id] = spider
    global.spider.playerTeamsSpider[playerTeamName] = spider
end

--- Give the forces of the spiders all the shooting sped upgrades, but no damage upgrades.
Spider.SetSpiderForcesTechs = function()
    for _, spider in pairs(global.spider.spiders) do
        local spiderForce = spider.biterTeam
        spiderForce.technologies["weapon-shooting-speed-6"].researched = true
        spiderForce.technologies["laser-shooting-speed-7"].researched = true
    end
end

--- Called when only a boss spider named entity type has been damaged.
---@param event on_entity_damaged
Spider.OnBossSpiderEntityDamaged = function(event)
    local spiderId = event.entity.unit_number
    global.spider.spiders[spiderId].damageTakenThisSecond = global.spider.spiders[spiderId].damageTakenThisSecond + event.final_damage_amount
end

--- Called when a spider has a new distance from spawn set and we need to change it's cached roaming values.
---@param spider BossSpider
Spider.UpdateSpidersRoamingValues = function(spider)
    spider.roamingXMin = -spider.distanceFromSpawn - Settings.spidersRoamingXRange
    spider.roamingXMax = -spider.distanceFromSpawn + Settings.spidersRoamingXRange
    -- The Y roaming values never change as they ahve to remain within the player team's lane.
end

--- Checks both spider's states and activity over the last second.
---@param event UtilityScheduledEvent_CallbackObject
Spider.CheckSpiders_Scheduled = function(event)
    for _, spider in pairs(global.spider.spiders) do
        -- If spider is dead then nothig to be done.
        if spider.state ~= BossSpider_State.dead then
            -- Check if spiders were damaged and if so react.
            if spider.damageTakenThisSecond ~= 0 then
                -- Was damaged over last second so need to log and react to it.
                Spider.WasDamagedInLastSecond(spider, event.tick)
            end

            -- Handle continuation of standard behaviours.
            local spidersCurrentPosition = spider.bossEntity.position
            if spider.state == BossSpider_State.roaming then
                Spider.CheckRoamingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.retreating then
                Spider.CheckRetreatingForSecond(spider, spidersCurrentPosition)
            end

            -- Update the spiders old position ready for the next second cycle.
            spider.spiderPositionLastSecond = spidersCurrentPosition

            -- Render the spiders current plans and state if enabled.
            if global.spider.showSpiderPlans then
                Spider.UpdatePlanRenders(spider)
            end
        end
    end

    -- Schedule the next seconds event. As the first instance of this schedule always occurs exactly on a second no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEvent(event.tick + 60, "Spider.CheckSpiders_Scheduled")
end

--- Called when the boss spider was damaged in the last second.
---@param spider BossSpider
Spider.WasDamagedInLastSecond = function(spider, currentTick)
    -- Log the damage.
    local thisSecond = currentTick / 60
    spider.secondsWhenDamaged[thisSecond] = spider.damageTakenThisSecond

    -- Reset current seconds counter ready for any damage over the next second.
    spider.damageTakenThisSecond = 0

    -- If the spider isn't currently retreating check if it should be as was just damaged. If it is already retreating then nothing needs doing.
    if spider.state ~= BossSpider_State.retreating then
        -- As the spider was damaged we need to check if it should retreat.
        local damageSufferedRecently, oldestSecondToConsider = 0, thisSecond - Settings.spiderDamageSecondsConsidered
        for second, secondsDamage in pairs(spider.secondsWhenDamaged) do
            if second <= oldestSecondToConsider then
                -- Too old to consider, so just remove it.
                -- We only need to clear up old damaged second values when we check them, no harm in leaving odd old value floating until then.
                spider.secondsWhenDamaged[second] = nil
            else
                -- Count this seconds damage.
                damageSufferedRecently = damageSufferedRecently + secondsDamage
            end
        end
        if damageSufferedRecently >= Settings.spiderDamageToRetreat then
            Spider.Retreat(spider)
        end
    end
end

--- Checks how the spiders roaming is going.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckRoamingForSecond = function(spider, spidersCurrentPosition)
    -- Do next action based on current state.
    if spider.movementTargetPosition == nil then
        -- No current target for the spider to move too.

        -- CODE NOTE: Without any water being on the map every tile should be reachable for the spider. So no validation of target required.
        Spider.MoveSpiderToPosition(spider, {x = math.random(spider.roamingXMin, spider.roamingXMax), y = math.random(spider.roamingYMin, spider.roamingYMax)})
    else
        -- Moving to the target at present.
        if spidersCurrentPosition.x == spider.spiderPositionLastSecond.x and spidersCurrentPosition.y == spider.spiderPositionLastSecond.y then
            -- The spider has stopped moving so its arrived or got as close as it can.
            -- CODE NOTE: This should detect if it ever got jammed in 1 spot and restart the cycle to find a new movement target and hopefully un-jam it.
            -- Clear the target position. The spider will sit here for another full second before the next cycle gives it a new position to move too.
            spider.movementTargetPosition = nil
        end
    end
end

--- Checks how the spiders retreating is going.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckRetreatingForSecond = function(spider, spidersCurrentPosition)
    -- Do nothing until the spider has reached its destination.
    if spidersCurrentPosition.x == spider.spiderPositionLastSecond.x and spidersCurrentPosition.y == spider.spiderPositionLastSecond.y then
        -- The spider has stopped moving so its arrived or got as close as it can.
        -- Clear the target position and return the spider to roaming. The spider will sit here for another full second before the next cycle starts the roaming logic and a new position to move too.
        spider.movementTargetPosition = nil
        spider.state = BossSpider_State.roaming
    end
end

--- Order the spider to move to a position. This will also handle updating any hidden entities that aren't part of the boss spider.
---@param spider BossSpider
---@param targetPosition MapPosition
Spider.MoveSpiderToPosition = function(spider, targetPosition)
    spider.movementTargetPosition = targetPosition
    spider.bossEntity.autopilot_destination = targetPosition
end

--- Other code logic believes the spider should retreat.
---@param spider BossSpider
Spider.Retreat = function(spider)
    if spider.state ~= BossSpider_State.retreating then
        spider.state = BossSpider_State.retreating
        Spider.MoveSpiderToPosition(spider, {x = spider.roamingXMin, y = math.random(spider.roamingYMin, spider.roamingYMax)})
    end
end

--- Render the spiders current plans and remove any old ones first. This is for debugging/testing and so doesn't matter than not optimal UPS.
---@param spider BossSpider
Spider.UpdatePlanRenders = function(spider)
    -- Just remove all the old renders.
    for _, renderId in pairs(spider.spiderPlanRenderIds) do
        rendering.destroy(renderId)
    end
    spider.spiderPlanRenderIds = {}

    -- Add any state specific renders for the spider.
    if spider.state == BossSpider_State.roaming or spider.state == BossSpider_State.retreating then
        if spider.movementTargetPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - moving", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.movementTargetPosition, surface = global.spider.surface})
        else
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - arrived", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
        end
    end
end

--- When the change_spider_distance command is called.
---@param commandEvent CustomCommandData
Spider.Command_ChangeDistanceFromSpawn = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: change_spider_distance command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args < 1 or #args > 2 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 1 or 2, got" .. #args, Colors.lightred)
        return
    end

    local distanceChange = args[1] ---@type number
    if type(distanceChange) ~= "number" then
        game.print(commandErrorMessagePrefix .. "First argument of distance to change by must be a number, recieved: " .. tostring(distanceChange), Colors.lightred)
        return
    end

    local playerTeamName = args[2] ---@type string
    if playerTeamName ~= nil and playerTeamName ~= "" then
        -- Optional team name is provided so check its valid.
        if PlayerForcesNameToDetails[playerTeamName] == nil then
            game.print(commandErrorMessagePrefix .. 'Second argument of player team name was invalid, either "north", "south", or blank/nil are allowed. Recieved: ' .. tostring(playerTeamName), Colors.lightred)
            return
        end
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == nil then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
            -- TODO: update distance GUI.
        end
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
        -- TODO: update distance GUI.
        local x = 1
    end

    -- TODO: show GUI message about update. At present Muppet GUI mod doesn't support command interface so need to add this.
end

--- When the set_spider_movement_per_minute command is called.
---@param commandEvent CustomCommandData
Spider.Command_SetSpiderMovementPerMinute = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: change_spider_distance command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 1 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 1, got" .. #args, Colors.lightred)
        return
    end

    local distance = args[1] ---@type number
    if type(distance) ~= "number" then
        game.print(commandErrorMessagePrefix .. "First argument of distance must be a number, recieved: " .. tostring(distance), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    global.spider.constantMovementFromSpawnPerMinute = distance
end

--- Move the spiders at a constant rate away from the players spawns every minute.
---@param event UtilityScheduledEvent_CallbackObject
Spider.SpidersMoveAwayFromSpawn_Scheduled = function(event)
    -- Update both team's spiders.
    for _, spider in pairs(global.spider.spiders) do
        spider.distanceFromSpawn = spider.distanceFromSpawn + global.spider.constantMovementFromSpawnPerMinute
        -- TODO: update distance GUI.
    end

    -- Schedule the next Minutes event. As the first instance of this schedule always occurs exactly on a minute no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEvent(event.tick + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
end

return Spider
