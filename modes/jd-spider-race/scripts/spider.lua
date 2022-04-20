--[[
    This code was developed independantly of other parts of the mod and so will as self contained as possible. With anything needed being hard coded in local variables at the top of the file.
]]
--

--[[
    TODO LATER:
        - Check the TODO's in this file. Either lift them up here or do them next.
        - Lot of LATER tags in code for things to be added as part of future wider functionality.
]]
--

local Spider = {}
local Utils = require("utility.utils")
local EventScheduler = require("utility/event-scheduler")
local Colors = require("utility.colors")
local Commands = require("utility.commands")
local Events = require("utility.events")
local math_min, math_max, math_floor, math_random = math.min, math.max, math.floor, math.random

---@class BossSpider
---@field id UnitNumber @ The UnitNumber of the boss spider entity. Also the key in global.spiders.
---@field state BossSpider_State
---@field playerTeam LuaForce
---@field playerTeamName string
---@field biterTeam LuaForce
---@field bossEntity LuaEntity @ The main spider boss entity.
---@field hasAmmo boolean @ Cache of if the spider is last known to have ammo or not. Updated on re-arming and on calculating fighting engagement distance.
---@field gunSpiders table<BossSpider_GunType, GunSpider>
---@field distanceFromSpawn uint @ How far from spawn the spiders area is centered on (positive number).
---@field damageTakenThisSecond float @ Damage taken so far this second (in between spider monitoring cycles).
---@field previousDamageToConsider float @ Damage taken in the previous whole seconds that the Settings.spiderDamageSecondsConsidered covers. Used whne the spider takes damage to simply track damage to consider retreat.
---@field secondsWhenDamaged table<Second, float> @ Only has entries for seconds when damage was done. May have seconds in this table older than the spiderDamageSecondsConsidered, but these will be cleared out upon the next second with damage occuring and aren't incorrectly counted.
---@field roamingXMin uint @ Far left of its roaming area.
---@field roamingXMax uint @ Far right of its roaming area.
---@field roamingYMin uint @ Far top of its roaming area.
---@field roamingYMax uint @ Far bottom of its roaming area.
---@field fightingXMin uint @ Far left of its fighting area.
---@field fightingXMax uint @ Far right of its fighting area.
---@field fightingYMin uint @ Far top of its fighting area.
---@field fightingYMax uint @ Far bottom of its fighting area.
---@field spiderPositionLastSecond MapPosition @ The spiders position last second. Used by various state's cycle functions.
---@field spiderPlanRenderIds Id[] -- used mainly for debugging and testing. But needs to be bleed throughout the code so made proper.
---@field roamingTargetPosition MapPosition|null @ The target position the spider is roaming to.
---@field retreatingTargetPosition MapPosition|null @ The target position the spider is retreating to.
---@field lastDamagedByEntity LuaEntity|null @ The last known entity that caused damage to the boss spider when it wasn't fighting. Recorded when the damage is done to a spider and so may become invalid during runtime, if so it will be set back to nil. Only recorded if it is within the spiders attacking range.
---@field lastDamagedFromPosition MapPosition|null @ The last known position of the lastDamagedByEntity. To act as a fallback for if the entity is no longer valid. Only recorded/updated if it is within the spiders attacking range.
---@field chasingEntity LuaEntity|null @ The initial target entity that the boss spider is trying to hunt down. It may get distracted and fight other things on the way to this. Recorded when the initial damage is done to a non fighting spider and so may become invalid during runtime, if so it will be set back to nil. Only recorded if it is within the spiders attacking range.
---@field chasingEntityLastPosition MapPosition|null @ The last known position of the chasingEntity. To act as a fallback for if the entity is no longer valid. Only recorded/updated if it is within the spiders attacking range.

---@class GunSpider
---@field type BossSpider_GunType
---@field entity LuaEntity
---@field hasAmmo boolean @ Cache of if the spider is last known to have ammo or not. Updated on re-arming and on calculating fighting engagement distance.

---@class BossSpider_State
local BossSpider_State = {
    roaming = "roaming", -- Just idling wondering its area.
    fighting = "fighting", -- Not significantly moving, but actively being managed in a combat state.
    chasing = "chasing", -- Actively chasing after a military target that attacked it.
    retreating = "retreating", -- Moving away from the threat.
    dead = "dead" -- Its dead.
}

---@class BossSpider_GunType
local BossSpider_GunType = {
    artillery = "artillery",
    rocketLauncher = "rocketLauncher",
    tankCannon = "tankCannon",
    machineGun = "machineGun"
}

---@class BossSpider_GunEntityDetails
---@field entityName string @ The entity prototype name of this gun spider.
---@field gunFilters table<Id, string> @ A list of the gun slots and what filter they should each have (if any).

---@alias BossSpider_GunDetails table<BossSpider_GunType,BossSpider_GunEntityDetails>
local BossSpider_GunDetails = {
    [BossSpider_GunType.artillery] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-artillery_wagon_cannon",
        gunFilters = {}
    },
    [BossSpider_GunType.machineGun] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-machine_gun",
        gunFilters = {
            [1] = "firearm-magazine",
            [2] = "piercing-rounds-magazine",
            [3] = "uranium-rounds-magazine"
        }
    },
    [BossSpider_GunType.rocketLauncher] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-rocket_launcher",
        gunFilters = {
            [1] = "rocket",
            [2] = "explosive-rocket",
            [3] = "atomic-bomb"
        }
    },
    [BossSpider_GunType.tankCannon] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-tank_cannon",
        gunFilters = {
            [1] = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo",
            [2] = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo",
            [3] = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo",
            [4] = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo"
        }
    }
}

---@alias BossSpider_Rearm ItemStackDefinition[]
local BossSpider_Rearm = {
    {name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo", count = 100}
}

---@alias BossSpider_GunRearm table<BossSpider_GunType, ItemStackDefinition[]>
local BossSpider_GunRearm = {
    --[[    [BossSpider_GunType.artillery] = {
{name = "artillery-shell", count = 10} -- LATER: doesn't work as desired. Plan is to use an artillery turret and teleport it to the spider frequently. Will need a really fast aiming and firing time, but a slower cooldown. Have a really large inventory size for it as if the shells were being stored in a spider. Exact stored ammo count for each weapon to be confirmed later.
    },   ]]
    [BossSpider_GunType.machineGun] = {
        {name = "firearm-magazine", count = 200},
        {name = "piercing-rounds-magazine", count = 200},
        {name = "uranium-rounds-magazine", count = 200},
        {name = "explosive-rocket", count = 200}
    },
    [BossSpider_GunType.rocketLauncher] = {
        {name = "rocket", count = 200},
        {name = "explosive-rocket", count = 200},
        {name = "atomic-bomb", count = 10}
    },
    [BossSpider_GunType.tankCannon] = {
        {name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo", count = 200}
    }
}

local Settings = {
    bossSpiderStartingLeftDistance = 5000,
    bossSpiderStartingVerticalDistance = 256, -- Half the height of each teams map area.
    spiderDamageToRetreat = 1000,
    spiderDamageSecondsConsidered = 30, -- How many seconds in the past the spider will consider to see if it has sustained enough damage to retreat.
    spidersRoamingXRange = 100,
    spidersRoamingYRange = 230, -- Bit less than half the height of each teams map area.
    spidersFightingXRange = 500, -- Random limit to stop it chasing infinitely.
    spidersFightingYRange = 256, -- Spider can move right up to the edge for when looking to chase a target to fight. It shouldn't ever actually reach this far in however.
    spidersFightingStepDistance = 3, -- How far the spider will move away from its current location when fighting per second.
    distanceToCheckForEnemiesWhenBeingDamaged = 50, -- How far the spider will look for enemies when it is being damaged, but there's no enemies within its current weapon ammo range.
    showSpiderPlans = true -- If enabled the plans of a spider are rendered.
}

-- Testing is for development and is very adhoc in what it changes to allow simplier testing.
local Testing = true
if Testing then
    Settings.bossSpiderStartingLeftDistance = 50
    Settings.bossSpiderStartingVerticalDistance = 30
    Settings.spidersRoamingXRange = 20
    Settings.spidersRoamingYRange = 40
    Settings.spidersFightingXRange = 200
    Settings.spidersFightingYRange = 50
    Settings.showSpiderPlans = true
    BossSpider_GunRearm[BossSpider_GunType.rocketLauncher][3] = nil -- No atomic weapons.
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
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Spider.OnSpiderDied", Spider.OnSpiderDied, "bossSpiders", {{filter = "name", name = "jd_plays-jd_spider_race-spidertron_boss"}})
end

Spider.OnStartup = function()
    -- Set the cached surface reference.
    global.spider.surface = game.surfaces[1] -- LATER: this may need updating to the one we use with the map generation settings when merged in to the main code.

    -- Create the spiders for each team if they don't exist.
    if next(global.spider.spiders) == nil then
        for _, playerForceDetails in pairs(PlayerForcesDetails) do
            Spider.CreateSpider(playerForceDetails.name, playerForceDetails.spiderStartingYPosition, playerForceDetails.spiderColor, playerForceDetails.biterTeamName)
        end

        Spider.SetSpiderForcesTechs()

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEvent((math_floor(game.tick / 60) * 60) + 60, "Spider.CheckSpiders_Scheduled")

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEvent((math_floor(game.tick / 3600) * 3600) + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
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
        previousDamageToConsider = 0,
        secondsWhenDamaged = {},
        roamingXMin = nil, -- Populated later in creation function.
        roamingXMax = nil, -- Populated later in creation function.
        roamingYMin = spidersYPos - Settings.spidersRoamingYRange,
        roamingYMax = spidersYPos + Settings.spidersRoamingYRange,
        fightingXMin = -2147483647, -- Can move as far left as it wants to chase a target.
        fightingXMax = nil, -- Populated later in creation function.
        fightingYMin = spidersYPos - Settings.spidersFightingYRange,
        fightingYMax = spidersYPos + Settings.spidersFightingYRange,
        spiderPlanRenderIds = {},
        spiderPositionLastSecond = spiderPosition,
        gunSpiders = {}, -- Populated later in creation function.
        roamingTargetPosition = nil,
        retreatingTargetPosition = nil,
        lastDamagedByEntity = nil,
        lastDamagedFromPosition = nil,
        chasingEntity = nil,
        chasingEntityLastPosition = nil,
        hasAmmo = nil -- Populated later in creation function.
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

    -- Add the extra gun spiders.
    for shortName, entityDetails in pairs(BossSpider_GunDetails) do
        local gunSpiderEntity = global.spider.surface.create_entity {name = entityDetails.name, position = spiderPosition, force = biterTeam}
        if gunSpiderEntity == nil then
            error("Failed to create gun spider " .. shortName .. " for team " .. playerTeamName .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
        end
        gunSpiderEntity.destructible = false
        local ammoInventory = gunSpiderEntity.get_inventory(defines.inventory.spider_ammo)
        for gunIndex, filterName in pairs(entityDetails.gunFilters) do
            ammoInventory.set_filter(gunIndex, filterName)
        end
        spider.gunSpiders[shortName] = {type = shortName, entity = gunSpiderEntity, hasAmmo = true}
    end

    Spider.GiveSpiderAmmo(spider)

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
    local spider = global.spider.spiders[event.entity.unit_number]
    if spider == nil then
        -- Non monitored spider, i.e. testing one.
        return
    end

    spider.damageTakenThisSecond = spider.damageTakenThisSecond + event.final_damage_amount

    -- If the spider is currently retreating then nothing further needs doing.
    if spider.state == BossSpider_State.retreating then
        return
    end

    -- If the spider has taken enough damage to retreat then do it. If so no further action needed.
    if spider.damageTakenThisSecond + spider.previousDamageToConsider >= Settings.spiderDamageToRetreat then
        Spider.Retreat(spider)
        return
    end

    -- If not already in fighting the spider will need to chase towards the attacker, assuming the attacker is known. This may superseed a previous target it was chasing. If the target position isn't within the allowed movement range then ignore it.
    if spider.state ~= BossSpider_State.fighting and event.cause ~= nil then
        local lastDamagedFromPosition = event.cause.position
        if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, lastDamagedFromPosition) then
            if spider.chasingEntity == nil and spider.chasingEntityLastPosition == nil then
                -- Spider wasn't already chasing anything, so start now.
                spider.chasingEntity = event.cause
                spider.chasingEntityLastPosition = lastDamagedFromPosition
            else
                -- Spider was already chasing something, so just record the damage originator for the short term fighting.
                spider.lastDamagedByEntity = event.cause
                spider.lastDamagedFromPosition = lastDamagedFromPosition
            end
            Spider.ChargeAtAttacker(spider, spider.bossEntity.position)
            return
        end
    end

    -- If theres no cause then theres no reaction we can take to this. So just leave the spider to continue whatever it was doing before.
end

--- Called when a spider has a new distance from spawn set and we need to change it's cached roaming values.
---@param spider BossSpider
Spider.UpdateSpidersRoamingValues = function(spider)
    spider.roamingXMin = -spider.distanceFromSpawn - Settings.spidersRoamingXRange
    spider.roamingXMax = -spider.distanceFromSpawn + Settings.spidersRoamingXRange
    spider.fightingXMax = -spider.distanceFromSpawn + Settings.spidersFightingXRange
    -- The Y roaming values never change as they have to remain within the player team's lane.
end

--- Checks both spider's states and activity over the last second.
---@param event UtilityScheduledEvent_CallbackObject
Spider.CheckSpiders_Scheduled = function(event)
    for _, spider in pairs(global.spider.spiders) do
        -- If spider is dead then nothing to be done.
        if spider.state ~= BossSpider_State.dead then
            -- Log the damage taken this second.
            local thisSecond = event.tick / 60
            if spider.damageTakenThisSecond > 0 then
                -- Only record the second if damage was done. Keeps the table smaller.
                spider.secondsWhenDamaged[thisSecond] = spider.damageTakenThisSecond
            end

            -- Update the previous damage to consider for this upcoming second.
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
            spider.previousDamageToConsider = damageSufferedRecently

            -- Handle continuation of standard behaviours.
            local spidersCurrentPosition = spider.bossEntity.position
            if spider.state == BossSpider_State.roaming then
                Spider.CheckRoamingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.retreating then
                Spider.CheckRetreatingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.chasing then
                Spider.CheckChasingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.fighting then
                Spider.ManageFightingForSecond(spider, spidersCurrentPosition)
            end

            -- Update the spiders old position ready for the next second cycle.
            spider.spiderPositionLastSecond = spidersCurrentPosition

            -- Reset the damage taken this second ready for the upcoming second. Do after the state management functions so they can utilise it.
            spider.damageTakenThisSecond = 0

            -- Render the spiders current plans and state if enabled.
            if global.spider.showSpiderPlans then
                Spider.UpdatePlanRenders(spider)
            end
        end
    end

    -- Schedule the next seconds event. As the first instance of this schedule always occurs exactly on a second no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEvent(event.tick + 60, "Spider.CheckSpiders_Scheduled")
end

--- Checks how the spiders roaming is going.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckRoamingForSecond = function(spider, spidersCurrentPosition)
    -- Do next action based on current state.
    if spider.roamingTargetPosition == nil then
        -- No current target for the spider to move too.

        -- CODE NOTE: Without any water being on the map every tile should be reachable for the spider. So no validation of target required.
        spider.roamingTargetPosition = {x = math_random(spider.roamingXMin, spider.roamingXMax), y = math_random(spider.roamingYMin, spider.roamingYMax)}
        Spider.MoveSpiderToPosition(spider, spider.roamingTargetPosition)
    else
        -- Moving to the target at present.
        if spidersCurrentPosition.x == spider.spiderPositionLastSecond.x and spidersCurrentPosition.y == spider.spiderPositionLastSecond.y then
            -- The spider has stopped moving so its arrived or got as close as it can.
            -- CODE NOTE: This should detect if it ever got jammed in 1 spot and restart the cycle to find a new movement target and hopefully un-jam it.
            -- Clear the roaming target position. The spider will sit here for this full second before the next cycle gives it a new position to move too.
            spider.roamingTargetPosition = nil
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

        -- Clear the old damage seconds so it starts counting from 0 health, otherwise it can just instantly start retreating again if attacked.
        spider.damageTakenThisSecond = 0
        spider.previousDamageToConsider = 0
        spider.secondsWhenDamaged = {}

        -- Return the spider to roaming. The spider will sit here for another full second before the next cycle starts the roaming logic and a new position to move too.
        Spider.StartRoaming(spider, spidersCurrentPosition)
    end
end

--- Checks how the spiders chasing is going. If it gets damaged on route it will be changed to the fighting state as part of the damage reaction event.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckChasingForSecond = function(spider, spidersCurrentPosition)
    -- Check if the spider has got close enough to its target.
    if Utils.GetDistance(spidersCurrentPosition, spider.chasingEntityLastPosition) < 10 then
        -- Spider is very close to where it's going. Set up next action rather than waiting for it to have stopped for a full second.

        -- If the spider was chasing an entity check the entity is still valid.
        -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
        if spider.chasingEntity ~= nil and not spider.chasingEntity.valid then
            -- Target isn't valid any more, so clear it out to make later code simplier.
            spider.chasingEntity = nil
        end

        -- Next action based on what the spider is chasing.
        if spider.chasingEntity == nil then
            -- No entity to chase, so was just moving to the position.
            -- If it's got here and hasn't already been attacked then go in to fighting mode. This will handle working out what to do next.
            Spider.StartFighting(spider, spidersCurrentPosition)
        else
            -- Continue chasing the attacker to their new location.
            -- A spider can't "follow" another entity, it can only have its destination updated to the entities current position. This is how vanilla Factorio works.
            -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
            local newTargetPosition = spider.chasingEntity.position
            if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, newTargetPosition) then
                -- New position is within the allowed fighting area, so set to move to this position to continue the chase.
                spider.chasingEntityLastPosition = newTargetPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                Spider.MoveSpiderToPosition(spider, newTargetPosition)
            else
                -- New target is outside of the allowed fighting area.
                -- Return the spider back to roaming as it can't follow the target.
                if Settings.showSpiderPlans then
                    rendering.draw_text {text = "target outside of fighting area", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
                end
                Spider.StartRoaming(spider, spidersCurrentPosition)
            end
        end
    else
        -- Spider is still moving towards its target so await a further state change or cycle check.
    end
end

--- Manages the spiders fighting for this second.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.ManageFightingForSecond = function(spider, spidersCurrentPosition)
    -- The spider will "dance" to keep engaging targets with its longer range weapons until its killed the real target or retreats. It will be a bit crude as otherwise it needs far more active managemnt.

    -- Initial reactions based on of the spider is taking damage at present.
    if spider.damageTakenThisSecond == 0 then
        -- The spider isn't taking damage so try to move towards the target.

        -- If the spider was targetting a short term entity check the entity is still valid.
        -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
        if spider.lastDamagedByEntity ~= nil and not spider.lastDamagedByEntity.valid then
            -- Target isn't valid any more, so clear it out to make later code simplier.
            spider.lastDamagedByEntity = nil
        end
        -- Initial handling logic based on short term target existing.
        if spider.lastDamagedByEntity == nil then
            -- No short term target to react to at present.
            -- So do fallback behavour.
            spider.lastDamagedFromPosition = nil
        else
            -- There is still a short term target so check its distance.
            local targetsCurrentPosition = spider.lastDamagedByEntity.position
            local distanceToAttacker = Utils.GetDistance(spidersCurrentPosition, targetsCurrentPosition)
            if distanceToAttacker <= Spider.GetSpidersEngagementRange(spider) then
                -- Target near by so just advance a bit.
                spider.lastDamagedFromPosition = Spider.GetNewPositionForAdvancingOnTarget(spider, targetsCurrentPosition, spidersCurrentPosition)
                Spider.MoveSpiderToPosition(spider, spider.lastDamagedFromPosition)
                return
            else
                -- Target far away so try to chase it as we aren't taking damage.
                if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
                    -- Target is at a chasable distance.
                    spider.lastDamagedFromPosition = targetsCurrentPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                    Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                    return
                else
                    -- Can't pursue short term target as its now outside of the allowed fighting area.
                    -- So do fallback behavour.
                    spider.lastDamagedByEntity = nil
                    spider.lastDamagedFromPosition = nil
                end
            end
        end

        -- Now check if there was a long term target as we aren't taking any damage.
        -- If the spider was targetting an entity check the entity is still valid.
        -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
        if spider.chasingEntity ~= nil and not spider.chasingEntity.valid then
            -- Chasing target isn't valid any more, so clear it out to make later code simplier.
            spider.chasingEntity = nil
        end
        if spider.chasingEntity == nil then
            -- No chasing target to react to at present.
            -- So do fallback behavour.
        else
            -- There is still a chasing target so check its distance.
            local targetsCurrentPosition = spider.chasingEntity.position
            local distanceToAttacker = Utils.GetDistance(spidersCurrentPosition, targetsCurrentPosition)
            if distanceToAttacker <= Spider.GetSpidersEngagementRange(spider) then
                -- Chasing target near by so just advance a bit.
                spider.chasingEntityLastPosition = Spider.GetNewPositionForAdvancingOnTarget(spider, targetsCurrentPosition, spidersCurrentPosition)
                Spider.MoveSpiderToPosition(spider, spider.chasingEntityLastPosition)
                return
            else
                -- Chasing target far away so try to chase it as we aren't taking damage.
                if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
                    -- Target is at a chasable distance.
                    spider.chasingEntityLastPosition = targetsCurrentPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                    Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                    return
                else
                    -- Can't pursue chasing target as its now outside of the allowed fighting area.
                    -- So do fallback behavour.
                    spider.chasingEntity = nil
                    spider.chasingEntityLastPosition = nil
                end
            end
        end
    else
        -- The spider is taking damage, so will stay in a fighting state for now. Just need to decide if to maneuver forwards or not.

        -- Get current weapons range and if enemy within this range.
        local spidersMaxShootingRange = Spider.GetSpidersEngagementRange(spider)
        local nearestEnemyWithinRange = global.spider.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = spidersMaxShootingRange, force = spider.biterTeam}

        -- Advance only if we are currently out of weapon range. We don't want to close in otherwise.
        if nearestEnemyWithinRange ~= nil then
            -- An enemy already within weapon range.

            -- Check how far away the target is and react based on this.
            local nearestEnemyWithinRangePosition = nearestEnemyWithinRange.position
            local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, nearestEnemyWithinRangePosition)
            if distanceToTarget + Settings.spidersFightingStepDistance < spidersMaxShootingRange then
                -- Step backwards to try and get out of being damaged while remaining within shooting range.

                -- Don'd update the last damaged position as we will want to advance again as a default in the future.
                Spider.MoveSpiderToPosition(spider, Spider.GetNewPositionForReversingFromTarget(spider, nearestEnemyWithinRangePosition, spidersCurrentPosition))
                return
            else
                -- Just stay here and fight for now.
                Spider.MoveSpiderToPosition(spider, spidersCurrentPosition) -- Cancel any current movement order of the spider so it stops here.
                return
            end
        else
            -- Nothing in range so advance a bit towards something...

            -- If the spider was targetting an entity check the entity is still valid.
            -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
            if spider.lastDamagedByEntity ~= nil and not spider.lastDamagedByEntity.valid then
                -- Target isn't valid any more, so clear it out to make later code simplier.
                spider.lastDamagedByEntity = nil
            end

            -- If old target still exists try to react to it.
            if spider.lastDamagedByEntity ~= nil then
                -- The old target is still active

                -- If the target is within the fighting area react to it.
                local targetsCurrentPosition = spider.lastDamagedByEntity.position
                if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
                    -- Target is within fighting area.

                    -- Check how far away the target is and react based on this.
                    local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, targetsCurrentPosition)
                    if distanceToTarget <= spidersMaxShootingRange then
                        -- Target near by so just advance a bit.
                        spider.lastDamagedFromPosition = Spider.GetNewPositionForAdvancingOnTarget(spider, targetsCurrentPosition, spidersCurrentPosition)
                        Spider.MoveSpiderToPosition(spider, spider.lastDamagedFromPosition)
                        return
                    else
                        -- Target far away and within the fighting area, so resume the chase on it. This will run away from whatever is shooting at us at present until we next take damage and then the chase will be broken.
                        spider.lastDamagedFromPosition = targetsCurrentPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                        Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                        return
                    end
                else
                    -- Can't pursue target as its now outside of the allowed fighting area.
                    -- So do fallback behavour.
                    spider.lastDamagedByEntity = nil
                    spider.lastDamagedFromPosition = nil
                end
            end
        end
    end

    --As spider can't pursue the current target look for anything near by to attack, otherwise return to chasing the origional target if there was one, or return to roaming. Means the spider will attack down a line of defences, etc, before returning to a longer term behaviour.

    -- Look for nearest target nearby.
    spider.lastDamagedByEntity = global.spider.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = Settings.distanceToCheckForEnemiesWhenBeingDamaged, force = spider.biterTeam}

    -- Decide final action based on nearby target found.
    if spider.lastDamagedByEntity ~= nil then
        -- Theres a new target.
        local targetsCurrentPosition = spider.lastDamagedByEntity.position

        -- Check the target is within the fighting area.
        if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
            -- Target within fighting area.
            if Settings.showSpiderPlans then
                rendering.draw_text {text = "found target near by to attack", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
            end

            -- React based on how far away it is.
            local distanceToAttacker = Utils.GetDistance(spidersCurrentPosition, targetsCurrentPosition)
            if distanceToAttacker <= Spider.GetSpidersEngagementRange(spider) then
                -- Target near by so just advance a bit.
                spider.lastDamagedFromPosition = Spider.GetNewPositionForAdvancingOnTarget(spider, targetsCurrentPosition, spidersCurrentPosition)
                Spider.MoveSpiderToPosition(spider, spider.lastDamagedFromPosition)
                return
            else
                -- Target far away, so start chasing it.
                spider.lastDamagedFromPosition = targetsCurrentPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                return
            end
        else
            -- Target not within fighting area
            -- Do fallback action.
        end
    end

    -- Theres no valid target near by the spider, so do a secondary action.

    -- If the spider was chasing an entity check if the entity is still valid.
    -- TODO: if its a player doing the damage in/out of a vehicle and they change driving state make sure it keeps tracking the player.
    if spider.chasingEntity ~= nil and not spider.chasingEntity.valid then
        -- Chasing target isn't valid any more, so clear it out to make later code simplier.
        spider.chasingEntity = nil
    end

    -- If there is something to chase look at doing that.
    if spider.chasingEntity == nil then
        -- No chasing target to react to at present.
        -- So do fallback behavour.
    else
        -- There is still a chasing target so check its distance.
        local targetsCurrentPosition = spider.chasingEntity.position
        local distanceToAttacker = Utils.GetDistance(spidersCurrentPosition, targetsCurrentPosition)
        if distanceToAttacker <= Spider.GetSpidersEngagementRange(spider) then
            -- Chasing target near by so just advance a bit.
            spider.chasingEntityLastPosition = Spider.GetNewPositionForAdvancingOnTarget(spider, targetsCurrentPosition, spidersCurrentPosition)
            Spider.MoveSpiderToPosition(spider, spider.chasingEntityLastPosition)
            return
        else
            -- Chasing target far away so try to chase it as we aren't taking damage.
            if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
                -- Target is at a chasable distance.
                spider.chasingEntityLastPosition = targetsCurrentPosition -- Set this as the new targetLocation in case the target entity vanishes while on route, etc.
                Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                return
            else
                -- Can't pursue chasing target as its now outside of the allowed fighting area.
                -- So do fallback behavour.
                spider.chasingEntity = nil
                spider.chasingEntityLastPosition = nil
            end
        end
    end

    -- Fallback behaviour is to go home.
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "going home as last resort", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
    end
    Spider.StartRoaming(spider, spidersCurrentPosition)
end

--- Advance roughly towards the target. Stays within the allowed fighting area.
--- Will wobble around them when very close (within Settings.spidersFightingStepDistance) of them. Intended to be very basic and simple initially.
---@param spider BossSpider
---@param targetsCurrentPosition MapPosition
---@param spidersCurrentPosition MapPosition
Spider.GetNewPositionForAdvancingOnTarget = function(spider, targetsCurrentPosition, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "advancing on target", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
    end

    local xPositonModifier, yPositonModifier
    if targetsCurrentPosition.x > spidersCurrentPosition.x then
        xPositonModifier = 1
    else
        xPositonModifier = -1
    end
    if targetsCurrentPosition.y > spidersCurrentPosition.y then
        yPositonModifier = 1
    else
        yPositonModifier = -1
    end
    return {
        x = math_max(math_min(spidersCurrentPosition.x + (Settings.spidersFightingStepDistance * xPositonModifier), spider.fightingXMax), spider.fightingXMin),
        y = math_max(math_min(spidersCurrentPosition.y + (Settings.spidersFightingStepDistance * yPositonModifier), spider.fightingYMax), spider.fightingYMin)
    }
end

--- Advance roughly away from the target. Stays within the allowed fighting area.
--- Intended to be very basic and simple initially.
--- The spider should step backwards the way it came. As it tends to run quite close to turrets as they take a while to wake up and start shooting, so it gets very close before its damaged and goes in to fighting mode.
---@param spider BossSpider
---@param targetsCurrentPosition MapPosition
---@param spidersCurrentPosition MapPosition
Spider.GetNewPositionForReversingFromTarget = function(spider, targetsCurrentPosition, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "reversing from target", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
    end

    -- TODO: this should actually look at the previous seconds position and go back in that direction. Once started going back just keep on going back in that same orientation until it stops going back. Use variables to store and clear this orientation.
    local xPositonModifier, yPositonModifier
    if targetsCurrentPosition.x > spidersCurrentPosition.x then
        xPositonModifier = 1
    else
        xPositonModifier = -1
    end
    if targetsCurrentPosition.y > spidersCurrentPosition.y then
        yPositonModifier = 1
    else
        yPositonModifier = -1
    end
    return {
        x = math_max(math_min(spidersCurrentPosition.x - (Settings.spidersFightingStepDistance * xPositonModifier), spider.fightingXMax), spider.fightingXMin),
        y = math_max(math_min(spidersCurrentPosition.y - (Settings.spidersFightingStepDistance * yPositonModifier), spider.fightingYMax), spider.fightingYMin)
    }
end

--- Order the spider to move to a position. This will also handle updating any hidden entities that aren't part of the boss spider.
---@param spider BossSpider
---@param targetPosition MapPosition
Spider.MoveSpiderToPosition = function(spider, targetPosition)
    -- Give the various spider entities their order.
    spider.bossEntity.autopilot_destination = targetPosition
    for _, gunSpider in pairs(spider.gunSpiders) do
        gunSpider.entity.autopilot_destination = targetPosition
    end
end

--- Set the spider to start roaming.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.StartRoaming = function(spider, spidersCurrentPosition)
    Spider.ClearStateVariables(spider)

    spider.state = BossSpider_State.roaming
    Spider.CheckRoamingForSecond(spider, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Make the spider retreat.
---@param spider BossSpider
Spider.Retreat = function(spider)
    Spider.ClearStateVariables(spider)

    spider.state = BossSpider_State.retreating
    spider.retreatingTargetPosition = {x = spider.roamingXMin, y = math_random(spider.roamingYMin, spider.roamingYMax)}
    Spider.MoveSpiderToPosition(spider, spider.retreatingTargetPosition)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Set the spider to charge towards its latest attacker and start fighting there. Will starting moving there if needed, otherwise just enter fighting mode.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.ChargeAtAttacker = function(spider, spidersCurrentPosition)
    Spider.ClearNonFightingStateVariables(spider)

    -- Prioritise charging at the more recent damage causer.
    local currentTargetPosition
    if spider.lastDamagedFromPosition ~= nil then
        currentTargetPosition = spider.lastDamagedFromPosition
    else
        currentTargetPosition = spider.chasingEntityLastPosition
    end

    local distanceToAttacker = Utils.GetDistance(spidersCurrentPosition, currentTargetPosition)
    if distanceToAttacker <= Spider.GetSpidersEngagementRange(spider) then
        -- Attacker is close enough to start fighting already.
        Spider.StartFighting(spider, spidersCurrentPosition)
    else
        -- Spider will start moving to the position the last attacking enemy was at.
        spider.state = BossSpider_State.chasing
        Spider.MoveSpiderToPosition(spider, currentTargetPosition)
        if Settings.showSpiderPlans then
            Spider.UpdatePlanRenders(spider)
        end
    end
end

--- Set the spider to start fighting in the area its currently at.
---@param spider BossSpider
---@param spidersCurrentPosition MapPosition
Spider.StartFighting = function(spider, spidersCurrentPosition)
    spider.state = BossSpider_State.fighting
    Spider.ManageFightingForSecond(spider, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Clear all state variables.
---@param spider BossSpider
Spider.ClearStateVariables = function(spider)
    spider.chasingEntity = nil
    spider.chasingEntityLastPosition = nil
    spider.lastDamagedByEntity = nil
    spider.lastDamagedFromPosition = nil
    spider.retreatingTargetPosition = nil
    spider.roamingTargetPosition = nil
end

--- Clear the non fighting state variables.
---@param spider BossSpider
Spider.ClearNonFightingStateVariables = function(spider)
    spider.retreatingTargetPosition = nil
    spider.roamingTargetPosition = nil
end

--- Gets the max distance the spider can fight from right now based on the weapons it has ammo for.
---@param spider BossSpider
---@return double maxEngagementRange
Spider.GetSpidersEngagementRange = function(spider)
    if spider.gunSpiders[BossSpider_GunType.rocketLauncher].hasAmmo then
        if not spider.gunSpiders[BossSpider_GunType.rocketLauncher].entity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            return 36
        else
            spider.gunSpiders[BossSpider_GunType.rocketLauncher].hasAmmo = false
        end
    end
    if spider.gunSpiders[BossSpider_GunType.tankCannon].hasAmmo then
        if not spider.gunSpiders[BossSpider_GunType.tankCannon].entity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            return 30
        else
            spider.gunSpiders[BossSpider_GunType.tankCannon].hasAmmo = false
        end
    end
    if spider.gunSpiders[BossSpider_GunType.machineGun].hasAmmo then
        if not spider.gunSpiders[BossSpider_GunType.machineGun].entity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            return 20
        else
            spider.gunSpiders[BossSpider_GunType.machineGun].hasAmmo = false
        end
    end
    if spider.hasAmmo then
        -- Flamer
        if not spider.bossEntity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            return 15
        else
            spider.hasAmmo = false
        end
    end
    -- Lasers (Personal equipment)
    return 15
end

--- Checks if the target position if its within the allowed fighting area.
---@param spider BossSpider
---@param targetPosition MapPosition
---@return boolean positionIsValid
Spider.IsFightingTargetPositionWithinAllowedFightingArea = function(spider, targetPosition)
    if targetPosition.x < spider.fightingXMin or targetPosition.x > spider.fightingXMax then
        return false
    elseif targetPosition.y < spider.fightingYMin and targetPosition.y > spider.fightingYMax then
        return false
    else
        return true
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
    if spider.state == BossSpider_State.roaming then
        if spider.roamingTargetPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - moving", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.roamingTargetPosition, surface = global.spider.surface})
        else
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - arrived", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
        end
    elseif spider.state == BossSpider_State.retreating then
        table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state, surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
        table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.retreatingTargetPosition, surface = global.spider.surface})
    elseif spider.state == BossSpider_State.dead then
        -- The entity still exists the moment this is called, but not afterwards. So set it to the position and not the entity itself.
        table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state, surface = global.spider.surface, target = spider.bossEntity.position, color = Colors.white, scale_with_zoom = true})
    elseif spider.state == BossSpider_State.chasing then
        if spider.lastDamagedByEntity ~= nil and spider.lastDamagedByEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent entity", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedByEntity, surface = global.spider.surface})
        elseif spider.lastDamagedFromPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent area", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedFromPosition, surface = global.spider.surface})
        elseif spider.chasingEntity ~= nil and spider.chasingEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional entity", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntity, surface = global.spider.surface})
        elseif spider.chasingEntityLastPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional area", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntityLastPosition, surface = global.spider.surface})
        end
    elseif spider.state == BossSpider_State.fighting then
        if spider.lastDamagedByEntity ~= nil and spider.lastDamagedByEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent entity", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedByEntity, surface = global.spider.surface})
        elseif spider.lastDamagedFromPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent area", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedFromPosition, surface = global.spider.surface})
        elseif spider.chasingEntity ~= nil and spider.chasingEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional entity", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntity, surface = global.spider.surface})
        elseif spider.chasingEntityLastPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional area", surface = global.spider.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntityLastPosition, surface = global.spider.surface})
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
            -- LATER: update distance GUI.
        end
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
        -- LATER: update distance GUI.
        local x = 1
    end

    -- LATER: show GUI message about update.
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
        -- LATER: update distance GUI.
    end

    -- Schedule the next Minutes event. As the first instance of this schedule always occurs exactly on a minute no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEvent(event.tick + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
end

--- Gives the boss spider and its gun spiders 1 set of ammo.
---@param spider BossSpider
Spider.GiveSpiderAmmo = function(spider)
    if spider.state == BossSpider_State.dead then
        return
    end

    -- Arm the boss spider.
    for _, ammo in pairs(BossSpider_Rearm) do
        spider.bossEntity.insert(ammo)
    end
    spider.hasAmmo = true

    -- Arm each of the gun spiders.
    for bossSpiderGunType, ammoItems in pairs(BossSpider_GunRearm) do
        for _, ammo in pairs(ammoItems) do
            spider.gunSpiders[bossSpiderGunType].entity.insert(ammo)
        end
        spider.gunSpiders[bossSpiderGunType].hasAmmo = true
    end
end

--- Called when a spider is killed by on_event.
---@param event on_entity_died
Spider.OnSpiderDied = function(event)
    if event.entity.name ~= "jd_plays-jd_spider_race-spidertron_boss" then
        -- Other filter triggered event handler.
        return
    end

    local spider = global.spider.spiders[event.entity.unit_number]
    if spider == nil then
        -- Non monitored spider, i.e. testing one.
        return
    end

    Spider.UpdatePlanRenders(spider)

    spider.state = BossSpider_State.dead
    -- Coin is dropped as loot automatically.
    game.print("HYPE - boss spider of team " .. spider.playerTeamName .. " killed !!!", Colors.green)

    -- LATER: announce the death and do any GUI stuff, etc. Maybe freeze all spider distance changes and lock the scoreboard?
end

return Spider
