--[[
    This code was developed independantly of other parts of the mod and so will as self contained as possible. With anything needed being hard coded in local variables at the top of the file.

    The spiders mangement is done as a very light touch and as such its movements are a bit all or nothing. But it does perform far better in combat than if it just mindlessly followed a target until it was made to retreat. Its designed to be primarily reactive, with only limited simple proactive behaviour in certain combat situations.
]]
--

--[[
    TODO LATER:
        - Lot of LATER tags in code for things to be added as part of future wider functionality:
            - GUIs
        - Use active danger checking when moving:
            - When we charge at a target we should target the position half weapons distance away from it. As we actually "arrive" when 10 tiles near the target position and then go in to a fighting stance if the enemy is vaguely close. This should stop the spider walking too close to turrets it knows about.
            - When the spider is chasing (moving for combat?) have it do a target scan around its current position and where it will roughly reach in the next second. Should just be looking for any enemies that will attack it. If found should go in to combat state against them. Really just to stop it running so deep in to turret lines when chasing or charging at targets. When its roaming should it do the same?
]]
--

local Spider = {}
local Utils = require("utility.utils")
local EventScheduler = require("utility/event-scheduler")
local Colors = require("utility.colors")
local Commands = require("utility.commands")
local Events = require("utility.events")
local math_min, math_max, math_floor, math_random = math.min, math.max, math.floor, math.random

---@class JdSpiderRace_BossSpider
---@field id UnitNumber @ The UnitNumber of the boss spider entity. Also the key in global.spiders.
---@field state JdSpiderRace_BossSpider_State
---@field playerTeam JdSpiderRace_PlayerHome_Team
---@field playerTeamName string
---@field bossEntity LuaEntity @ The main spider boss entity.
---@field hasAmmo boolean @ Cache of if the spider is last known to have ammo or not. Updated on re-arming and on calculating fighting engagement distance.
---@field gunSpiders table<JdSpiderRace_BossSpider_GunSpiderType, JdSpiderRace_GunSpider> @ The hidden spiders that move with the main spider. They are present just to carry the extra gun types.
---@field turrets table<JdSpiderRace_BossSpider_TurretType, JdSpiderRace_BossSpider_Turret> @ The hidden turrets that are moved once per second cycle to the spiders current position. The weapons on these should be happy to be out of sync with the spiders exact position.
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
---@field spiderPlanRenderIds Id[] -- Used for debugging and testing. But needs to be bleed throughout the code so made proper.
---@field spiderAreasRenderIds Id[] -- Used for debugging and testing. But needs to be bleed throughout the code so made proper.
---@field roamingTargetPosition MapPosition|null @ The target position the spider is roaming to.
---@field retreatingTargetPosition MapPosition|null @ The target position the spider is retreating to.
---@field lastDamagedByEntity LuaEntity|null @ The last known entity that caused damage to the boss spider when it wasn't fighting. Recorded when the damage is done to a spider and so may become invalid during runtime, if so it will be set back to nil. Only recorded if it is within the spiders attacking range.
---@field lastDamagedByPlayer LuaPlayer|null @ If the lastDamagedByEntity was a player controlled entity then this references the player to allow tracking across multiple entities (vehicles/character).
---@field lastDamagedFromPosition MapPosition|null @ The last known position of the lastDamagedByEntity. To act as a fallback for if the entity is no longer valid. Only recorded/updated if it is within the spiders attacking range.
---@field chasingEntity LuaEntity|null @ The initial target entity that the boss spider is trying to hunt down. It may get distracted and fight other things on the way to this. Recorded when the initial damage is done to a non fighting spider and so may become invalid during runtime, if so it will be set back to nil. Only recorded if it is within the spiders attacking range.
---@field chasingPlayer LuaPlayer|null @ If the chasingEntity was a player controlled entity then this references the player to allow tracking across multiple entities (vehicles/character).
---@field chasingEntityLastPosition MapPosition|null @ The last known position of the chasingEntity. To act as a fallback for if the entity is no longer valid. Only recorded/updated if it is within the spiders attacking range.

---@class JdSpiderRace_GunSpider
---@field type JdSpiderRace_BossSpider_GunSpiderType
---@field entity LuaEntity
---@field hasAmmo boolean @ Cache of if the spider is last known to have ammo or not. Updated on re-arming and on calculating fighting engagement distance.

---@class JdSpiderRace_BossSpider_Turret
---@field type JdSpiderRace_BossSpider_TurretType
---@field entity LuaEntity

---@class JdSpiderRace_BossSpider_State
local BossSpider_State = {
    roaming = "roaming", -- Just idling wondering its area.
    fighting = "fighting", -- Not significantly moving, but actively being managed in a combat state.
    chasing = "chasing", -- Actively chasing after a military target that attacked it.
    retreating = "retreating", -- Moving away from the threat.
    dead = "dead" -- Its dead.
}

---@class JdSpiderRace_BossSpider_GunSpiderType
local BossSpider_GunSpiderType = {
    rocketLauncher = "rocketLauncher",
    tankCannon = "tankCannon",
    machineGun = "machineGun"
}

---@class JdSpiderRace_BossSpider_GunEntityDetails
---@field entityName string @ The entity prototype name of this gun spider.
---@field gunFilters table<Id, string> @ A list of the gun slots and what filter they should each have (if any).

---@type table<JdSpiderRace_BossSpider_GunSpiderType, JdSpiderRace_BossSpider_GunEntityDetails>
local BossSpider_GunSpiderDetails = {
    [BossSpider_GunSpiderType.machineGun] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-machine_gun",
        gunFilters = {
            [1] = "firearm-magazine",
            [2] = "piercing-rounds-magazine",
            [3] = "uranium-rounds-magazine"
        }
    },
    [BossSpider_GunSpiderType.rocketLauncher] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-rocket_launcher",
        gunFilters = {
            [1] = "rocket",
            [2] = "explosive-rocket",
            [3] = "atomic-bomb"
        }
    },
    [BossSpider_GunSpiderType.tankCannon] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-tank_cannon",
        gunFilters = {
            [1] = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo",
            [2] = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo",
            [3] = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo",
            [4] = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo"
        }
    }
}

---@class JdSpiderRace_BossSpider_TurretType
local BossSpider_TurretType = {
    artillery = "artillery"
}

---@class JdSpiderRace_BossSpider_TurretEntityDetails
---@field entityName string @ The entity prototype name of this turret.

---@type table<JdSpiderRace_BossSpider_TurretType, JdSpiderRace_BossSpider_TurretEntityDetails>
local BossSpider_TurretDetails = {
    [BossSpider_TurretType.artillery] = {
        name = "jd_plays-jd_spider_race-spidertron_boss-artillery_turret"
    }
}

---@type ItemStackDefinition[]
local BossSpider_Rearm = {
    {name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo", count = 100}
}

---@type table<JdSpiderRace_BossSpider_GunSpiderType, ItemStackDefinition[]>
local BossSpider_GunSpiderRearm = {
    [BossSpider_GunSpiderType.machineGun] = {
        {name = "firearm-magazine", count = 200},
        {name = "piercing-rounds-magazine", count = 200},
        {name = "uranium-rounds-magazine", count = 200}
    },
    [BossSpider_GunSpiderType.rocketLauncher] = {
        {name = "rocket", count = 200},
        {name = "explosive-rocket", count = 200},
        {name = "atomic-bomb", count = 10}
    },
    [BossSpider_GunSpiderType.tankCannon] = {
        {name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo", count = 200},
        {name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo", count = 200}
    }
}

---@type table<JdSpiderRace_BossSpider_TurretType, ItemStackDefinition[]>
local BossSpider_TurretRearm = {
    [BossSpider_TurretType.artillery] = {
        {name = "jd_plays-jd_spider_race-spidertron_boss-artillery_shell", count = 10}
    }
}

---@class JdSpiderRace_BossSpider_RconAmmoType
---@field ammoItemName string
---@field gunType JdSpiderRace_BossSpider_GunSpiderType|null
---@field bossSpider boolean|null
---@field turretType JdSpiderRace_BossSpider_TurretType|null

---@type table<string, JdSpiderRace_BossSpider_RconAmmoType> @ Command friendly name to item name.
local BossSpider_RconAmmoNames = {
    bullet = {ammoItemName = "firearm-magazine", gunType = BossSpider_GunSpiderType.machineGun},
    piercingBullet = {ammoItemName = "piercing-rounds-magazine", gunType = BossSpider_GunSpiderType.machineGun},
    uraniumBullet = {ammoItemName = "uranium-rounds-magazine", gunType = BossSpider_GunSpiderType.machineGun},
    rocket = {ammoItemName = "rocket", gunType = BossSpider_GunSpiderType.rocketLauncher},
    explosiveRocket = {ammoItemName = "explosive-rocket", gunType = BossSpider_GunSpiderType.rocketLauncher},
    atomicRocket = {ammoItemName = "atomic-bomb", gunType = BossSpider_GunSpiderType.rocketLauncher},
    cannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon},
    explosiveCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon},
    uraniumCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon},
    explosiveUraniumCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon},
    artilleryShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-artillery_shell", turretType = BossSpider_TurretType.artillery},
    flamethrowerAmmo = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo", bossSpider = true}
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
    spidersFightingStepDistance = 5, -- How far the spider will move away from its current location when fighting per second. - value of 2 or lower known to cause weird failed leg movement actions.
    distanceToCheckForEnemiesWhenBeingDamaged = 50, -- How far the spider will look for enemies when it is being damaged, but there's no enemies within its current weapon ammo range.
    showSpiderPlans = false, -- If enabled the plans of a spider are rendered.
    markSpiderAreas = false -- If enabled the roaming and fighting areas of the spiders are marked with lines. Blue for roaming and red for fighting.
}

-- Testing is for development and is very adhoc in what it changes to allow simplier testing.
local Testing = true
if Testing then
    Settings.bossSpiderStartingLeftDistance = 400
    --Settings.bossSpiderStartingVerticalDistance = 30
    --Settings.spidersRoamingXRange = 20
    --Settings.spidersRoamingYRange = 40
    Settings.spidersFightingXRange = 200
    --Settings.spidersFightingYRange = 60
    Settings.showSpiderPlans = true
    Settings.markSpiderAreas = true
    BossSpider_GunSpiderRearm[BossSpider_GunSpiderType.rocketLauncher][3] = nil -- No atomic weapons.
--BossSpider_GunSpiderRearm[BossSpider_GunSpiderType.rocketLauncher] = {} -- Test short range weapon spider.
--BossSpider_GunSpiderRearm[BossSpider_GunSpiderType.tankCannon] = {} -- Test short range weapon spider.
--BossSpider_TurretRearm[BossSpider_TurretType.artillery] = {} -- No artillery shells.
end

-- This must be created after the first batch of testing value changes are applied.
---@class JdSpiderRace_BossSpider_PlayerForcesDetails
local PlayerForcesDetails = {
    -- Set the color alphas to half as otherwise they become very dark.
    {
        name = "north",
        biterTeamName = "north_enemy",
        spiderStartingYPosition = -Settings.bossSpiderStartingVerticalDistance
    },
    {
        name = "south",
        biterTeamName = "south_enemy",
        spiderStartingYPosition = Settings.bossSpiderStartingVerticalDistance
    }
}

-- This testing manipualtes the PlayerForcesDetails table before its used for anything.
if Testing then
--PlayerForcesDetails[1].biterTeamName = "enemy" -- Theres no extra enemy force in this code yet.
--PlayerForcesDetails[2] = nil -- Just 1 spider for simplier movement testing.
-- PlayerForcesDetails[2].biterTeamName = "player" -- So the 2 spiders fight and we can see them in combat.
-- PlayerForcesDetails[2].spiderColor = {0, 100, 255, 128} -- A light blue color.
end

local PlayerForcesNameToDetails = {} ---@type table<string, JdSpiderRace_BossSpider_PlayerForcesDetails>
for _, details in pairs(PlayerForcesDetails) do
    PlayerForcesNameToDetails[details.name] = details
end

Spider.CreateGlobals = function()
    global.spider = global.spider or {}
    global.spider.spiders = global.spider.spiders or {} ---@type table<UnitNumber, JdSpiderRace_BossSpider> @ Key'd by spiders UnitNumber
    global.spider.playerTeamsSpider = global.spider.playerTeamsSpider or {} ---@type table<string, JdSpiderRace_BossSpider> @ The player team name to the spider they are fighting.
    global.spider.showSpiderPlans = global.spider.showSpiderPlans or Settings.showSpiderPlans ---@type boolean
    global.spider.constantMovementFromSpawnPerMinute = global.spider.constantMovementFromSpawnPerMinute or 3 ---@type number
end

Spider.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Spider.CheckSpiders_Scheduled", Spider.CheckSpiders_Scheduled) -- CODE NOTE: in ideal world this would be a re-occuring scheduled event every SECOND, but this Utils version doesn't have that feature. One schedule action per second shouldn't be too UPS heavy.
    Commands.Register("spider_incrememt_distance_from_spawn", {"api-description.jd_plays-jd_spider_race-spider_incrememt_distance_from_spawn"}, Spider.Command_IncrementDistanceFromSpawn, true)
    Commands.Register("spider_set_movement_per_minute", {"api-description.jd_plays-jd_spider_race-spider_set_movement_per_minute"}, Spider.Command_SetSpiderMovementPerMinute, true)
    EventScheduler.RegisterScheduledEventType("Spider.SpidersMoveAwayFromSpawn_Scheduled", Spider.SpidersMoveAwayFromSpawn_Scheduled) -- CODE NOTE: in ideal world this would be a re-occuring scheduled event every MINUTE, but this Utils version doesn't have that feature. One schedule action per MINUTE shouldn't be too UPS heavy.
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Spider.OnSpiderDied", Spider.OnSpiderDied, "bossSpiders", {{filter = "name", name = "jd_plays-jd_spider_race-spidertron_boss"}})
    Commands.Register("spider_reset_state", {"api-description.jd_plays-jd_spider_race-spider_reset_state"}, Spider.Command_ResetSpiderState, true)
    Commands.Register("spider_full_rearm", {"api-description.jd_plays-jd_spider_race-spider_full_rearm"}, Spider.Command_RearmSpider, true)
    Commands.Register("spider_give_ammo", {"api-description.jd_plays-jd_spider_race-spider_give_ammo"}, Spider.Command_GiveSpiderAmmo, true)
end

Spider.OnStartup = function()
    -- Create the spiders for each team if they don't exist.
    if next(global.spider.spiders) == nil then
        for _, playerForceDetails in pairs(PlayerForcesDetails) do
            Spider.CreateSpider(playerForceDetails.name, playerForceDetails.spiderStartingYPosition, playerForceDetails.biterTeamName)
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
---@param biterTeamName string
Spider.CreateSpider = function(playerTeamName, spidersYPos, biterTeamName)
    local playerTeam = global.playerHome.teams[playerTeamName]
    local spiderPosition = {x = -Settings.bossSpiderStartingLeftDistance, y = spidersYPos}
    -- They can be created in chunks that don't exist as they have a radar and thus will generate the chunks around them.
    local bossEntity = global.general.surface.create_entity {name = "jd_plays-jd_spider_race-spidertron_boss", position = spiderPosition, force = playerTeam.enemyForce}
    if bossEntity == nil then
        error("Failed to create boss spider for team " .. playerTeamName .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
    end
    bossEntity.color = {0, 0, 0, 200} -- Deep black, but some highlighting still visible.

    ---@type JdSpiderRace_BossSpider
    local spider = {
        id = bossEntity.unit_number,
        bossEntity = bossEntity,
        state = BossSpider_State.roaming,
        playerTeam = playerTeam,
        playerTeamName = playerTeamName,
        distanceFromSpawn = Settings.bossSpiderStartingLeftDistance,
        damageTakenThisSecond = 0,
        previousDamageToConsider = 0,
        secondsWhenDamaged = {},
        roamingXMin = nil, -- Populated later in creation function.
        roamingXMax = nil, -- Populated later in creation function.
        roamingYMin = spidersYPos - Settings.spidersRoamingYRange,
        roamingYMax = spidersYPos + Settings.spidersRoamingYRange,
        fightingXMin = -1000000, -- Can move as far left as it wants to chase a target.
        fightingXMax = nil, -- Populated later in creation function.
        fightingYMin = spidersYPos - Settings.spidersFightingYRange,
        fightingYMax = spidersYPos + Settings.spidersFightingYRange,
        spiderPlanRenderIds = {},
        spiderAreasRenderIds = {},
        spiderPositionLastSecond = spiderPosition,
        gunSpiders = {}, -- Populated later in creation function.
        turrets = {}, -- Populated later in creation function.
        roamingTargetPosition = nil,
        retreatingTargetPosition = nil,
        lastDamagedByPlayer = nil,
        lastDamagedByEntity = nil,
        lastDamagedFromPosition = nil,
        chasingPlayer = nil,
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
    for shortName, entityDetails in pairs(BossSpider_GunSpiderDetails) do
        local gunSpiderEntity = global.general.surface.create_entity {name = entityDetails.name, position = spiderPosition, force = playerTeam.enemyForce}
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

    -- Add the extra turrets.
    for shortName, entityDetails in pairs(BossSpider_TurretDetails) do
        local turretEntity = global.general.surface.create_entity {name = entityDetails.name, position = spiderPosition, force = playerTeam.enemyForce}
        if turretEntity == nil then
            error("Failed to create turret " .. shortName .. " for team " .. playerTeamName .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
        end
        turretEntity.destructible = false
        spider.turrets[shortName] = {type = shortName, entity = turretEntity}
    end

    Spider.GiveSpiderFullAmmo(spider)

    -- Record the spider to globals.
    global.spider.spiders[spider.id] = spider
    global.spider.playerTeamsSpider[playerTeamName] = spider
end

--- Give the forces of the spiders all the shooting sped upgrades, but no damage upgrades.
Spider.SetSpiderForcesTechs = function()
    for _, spider in pairs(global.spider.spiders) do
        local spiderForce = spider.playerTeam.enemyForce
        spiderForce.technologies["weapon-shooting-speed-6"].researched = true
        spiderForce.technologies["laser-shooting-speed-7"].researched = true
    end
end

--- Called when a spider has a new distance from spawn set and we need to change it's cached roaming values.
---@param spider JdSpiderRace_BossSpider
Spider.UpdateSpidersRoamingValues = function(spider)
    spider.roamingXMin = -spider.distanceFromSpawn - Settings.spidersRoamingXRange
    spider.roamingXMax = -spider.distanceFromSpawn + Settings.spidersRoamingXRange
    spider.fightingXMax = -spider.distanceFromSpawn + Settings.spidersFightingXRange
    -- The Y roaming values never change as they have to remain within the player team's lane.

    if Settings.markSpiderAreas then
        -- Remove any current areas rendered.
        for _, renderId in pairs(spider.spiderAreasRenderIds) do
            rendering.destroy(renderId)
        end
        spider.spiderAreasRenderIds = {}

        -- Add the current areas.
        table.insert(spider.spiderAreasRenderIds, rendering.draw_rectangle {color = Colors.blue, filled = false, width = 10, left_top = {x = spider.roamingXMin, y = spider.roamingYMin}, right_bottom = {x = spider.roamingXMax, y = spider.roamingYMax}, surface = global.general.surface, draw_on_ground = true})
        table.insert(spider.spiderAreasRenderIds, rendering.draw_rectangle {color = Colors.red, filled = false, width = 10, left_top = {x = spider.fightingXMin, y = spider.fightingYMin}, right_bottom = {x = spider.fightingXMax, y = spider.fightingYMax}, surface = global.general.surface, draw_on_ground = true})
    end

    -- LATER: update distance GUI for this spider's player team.
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

    -- If not already in fighting the spider will need to chase towards the attacker, assuming the attacker is known. This may superseed a previous target it was chasing.
    if spider.state ~= BossSpider_State.fighting and event.cause ~= nil then
        local lastDamagedFromPosition = event.cause.position

        -- The various spiders can cause friendly fire to themselves with explosions if the taget is at their feet. So just ingore the damage source if the causes name starts with a boss spider. For some reason string.find() doesn't count as a match if its the whole string.
        local causeEntityName = event.cause.name
        if causeEntityName == "jd_plays-jd_spider_race-spidertron_boss" or string.find(causeEntityName, "^jd_plays-jd_spider_race-spidertron_boss") ~= nil then
            return
        end

        -- If the target position isn't within the allowed fighting area then ignore it.
        if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, lastDamagedFromPosition) then
            if spider.chasingEntityLastPosition == nil then
                -- Spider wasn't already chasing anything, so start now.
                spider.chasingPlayer = Spider.GetEntitiesControllingPlayer(event.cause)
                spider.chasingEntity = event.cause
                spider.chasingEntityLastPosition = lastDamagedFromPosition
            else
                -- Spider was already chasing something, so just record the damage originator for the short term fighting.
                spider.lastDamagedByPlayer = Spider.GetEntitiesControllingPlayer(event.cause)
                spider.lastDamagedByEntity = event.cause
                spider.lastDamagedFromPosition = lastDamagedFromPosition
            end
            Spider.ChargeAtAttacker(spider, spider.bossEntity.position)
            return
        end
    end

    -- If theres no cause then theres no reaction we can take to this. So just leave the spider to continue whatever it was doing before.
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

            -- Move the turrets.
            for _, turretDetails in pairs(spider.turrets) do
                turretDetails.entity.teleport(spidersCurrentPosition)
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
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckRoamingForSecond = function(spider, spidersCurrentPosition)
    -- Do next action based on current state.
    if spider.roamingTargetPosition == nil then
        -- No current target for the spider to move too.

        -- CODE NOTE: Without any water being on the map every tile should be reachable for the spider. So no validation of target required.
        spider.roamingTargetPosition = {x = math_random(spider.roamingXMin, spider.roamingXMax), y = math_random(spider.roamingYMin, spider.roamingYMax)}
        Spider.OrderSpiderToStartMovingToPosition(spider, spider.roamingTargetPosition)
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
---@param spider JdSpiderRace_BossSpider
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

--- Checks how the spiders chasing to a target location is going and gives new orders one it reaches the target area. If it gets damaged on route it will be changed to the fighting state as part of the damage reaction event.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
Spider.CheckChasingForSecond = function(spider, spidersCurrentPosition)
    Spider.UpdateTargetsDetails(spider, "chasing")

    -- Handle if the target is gone.
    if spider.chasingEntityLastPosition == nil then
        -- Chasing target is gone.
        -- As the spider hasn't already been attacked then go in to fighting mode. This will handle working out what to do next.
        Spider.StartFighting(spider, spidersCurrentPosition)
        return
    end

    -- Check if the spider has got close enough to its target.
    if Utils.GetDistance(spidersCurrentPosition, spider.chasingEntityLastPosition) < 10 then
        -- Spider is very close to where it's going. Set up next action rather than waiting for it to have stopped for a full second.
        Spider.StartFighting(spider, spidersCurrentPosition)
    else
        -- Spider is still moving towards its existing target location.
        -- A spider can't "follow" another entity, it can only have its destination updated to the entities current position. This is how vanilla Factorio works.
        Spider.OrderSpiderToStartMovingToPosition(spider, spider.chasingEntityLastPosition)
    end
end

--- Manages the spiders fighting for this second. Will react to taking damage, having things to fight or looking for near by things to attack. As a last resort it will return home.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
Spider.ManageFightingForSecond = function(spider, spidersCurrentPosition)
    -- The spider will "dance" to keep engaging targets with its longer range weapons until its killed the real target or retreats. It will be a bit crude as otherwise it needs far more active managemnt.

    -- Generic values that may be cached within the function.
    ---@typelist LuaEntity
    local nearestEnemyWithinRange = nil

    local spidersMaxShootingRange = Spider.GetSpidersEngagementRange(spider)

    -- Initial reactions based on of the spider is taking damage at present.
    if spider.damageTakenThisSecond == 0 then
        -- The spider isn't taking damage so try to move towards the target.

        -- Ensure the short term target data is valid and remove it if not.
        Spider.UpdateTargetsDetails(spider, "lastDamaged")

        -- Initial handling logic based on if a short term target exists.
        if spider.lastDamagedByEntity == nil then
            -- No short term target exists.

            -- Check if there is anything to fight at the current location within weapons range. As we aren't being damaged so may as well kill anything we can before doing any longer term actions which may expose us to damage.
            nearestEnemyWithinRange = nearestEnemyWithinRange or global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = spidersMaxShootingRange, force = spider.playerTeam.enemyForce} or "none" -- The find_nearest_enemy() returns nil if nothing found, but that won't be cached correctly, so use "none" as value of last resort.
            if nearestEnemyWithinRange ~= "none" then
                -- There's enemies within current weapons range so just stand still and fight them.
                -- There's no movement or retargeting involved here so no need to check fighting area.
                Spider.OrderSpiderToStartMovingToPosition(spider, spidersCurrentPosition) -- Cancel any current movement order of the spider so it stops here.
                if Settings.showSpiderPlans then
                    rendering.draw_text {text = "standing to fight", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
                end
                return
            else
                -- Nothing found within current weapon range.
                -- So do fallback behaviour.
            end
        else
            -- There is a short term target so handle it.
            Spider.FightTargetTypeWhileNotBeingDamaged(spider, spidersCurrentPosition, "lastDamaged", spidersMaxShootingRange)
            return
        end

        -- Ensure the longer term target data is valid and remove it if not.
        Spider.UpdateTargetsDetails(spider, "chasing")

        -- Now check if there was a long term target.
        if spider.chasingEntity == nil then
            -- No long term target exists.
            -- No need to check if theres anything to kill within weapons range as we check for nearby enemies on next stage of fallback behaviour.
            -- So do fallback behaviour.
        else
            -- There is a short term target so handle it.
            Spider.FightTargetTypeWhileNotBeingDamaged(spider, spidersCurrentPosition, "chasing", spidersMaxShootingRange)
            return
        end
    else
        -- The spider is taking damage, so will stay in a fighting state for now. Just need to decide how to maneuver in reaction to being damaged.
        -- As we are taking damage we aren't worried about pursuing any target initially.

        -- Check if an enemy is within current weapons range.
        nearestEnemyWithinRange = nearestEnemyWithinRange or global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = spidersMaxShootingRange, force = spider.playerTeam.enemyForce} or "none" -- The find_nearest_enemy() returns nil if nothing found, but that won't be cached correctly, so use "none" as value of last resort.

        -- Advance only if we are currently out of weapon range. We don't want to close in otherwise.
        if nearestEnemyWithinRange ~= "none" then
            -- An enemy already within weapon range.

            -- Check how far away the target is and react based on this. We want to stay as far away from them while remaining within weapons range to return fire on them.
            local nearestEnemyWithinRangePosition = nearestEnemyWithinRange.position
            local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, nearestEnemyWithinRangePosition)
            if distanceToTarget + Settings.spidersFightingStepDistance < spidersMaxShootingRange then
                -- Step backwards to try and get out of being damaged while remaining within our weapons range.
                Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForReversingFromTarget(spider, nearestEnemyWithinRangePosition, spidersCurrentPosition))
                return
            else
                -- Just stay here and fight for now. As moving forwards to use more weapons will probably get the spider shot by more defences.
                Spider.OrderSpiderToStartMovingToPosition(spider, spidersCurrentPosition) -- Cancel any current movement order of the spider so it stops here.
                if Settings.showSpiderPlans then
                    rendering.draw_text {text = "standing to fight", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
                end
                return
            end
        else
            -- Nothing in range so advance a bit towards something...

            -- Ensure the shorter term target data is valid and remove it if not.
            Spider.UpdateTargetsDetails(spider, "lastDamaged")

            -- If old target still exists try to react to it.
            if spider.lastDamagedByEntity ~= nil then
                -- The old short target is still active and thus within the fighting area.

                -- Check how far away the target is and react based on this.
                local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, spider.lastDamagedFromPosition)
                if distanceToTarget <= (spidersMaxShootingRange * 2) then
                    -- Target near by so just advance a bit towards it.
                    Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.lastDamagedFromPosition, spidersCurrentPosition))
                    return
                else
                    -- Target far away and within the fighting area, so resume the chase on it. This will run away from whatever is shooting at us at present until we next take damage and then the chase will be broken.
                    Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                    return
                end
            else
                -- No valid target within fighting area.
                -- So do fallback behaviour.
            end
        end
    end

    -- As spider can't pursue the current target look for anything near by to attack first, otherwise return to chasing the origional target if there was one, or return to roaming. Means the spider will attack down a line of defences, etc, before returning to a longer term behaviour.

    -- Look for nearest target nearby and set them as the new target entity.
    local nearbyEnemy = global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = Settings.distanceToCheckForEnemiesWhenBeingDamaged, force = spider.playerTeam.enemyForce}

    -- Decide final action based on if a nearby target is found.
    if nearbyEnemy ~= nil then
        local targetsCurrentPosition = nearbyEnemy.position

        -- Check if the new target is within the fighting area.
        if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, targetsCurrentPosition) then
            -- Target within fighting area.

            spider.lastDamagedByEntity = nearbyEnemy
            spider.lastDamagedFromPosition = targetsCurrentPosition
            if Settings.showSpiderPlans then
                rendering.draw_text {text = "found target near by to attack", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
            end

            -- React based on how far away it is.
            local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, spider.lastDamagedFromPosition)
            if distanceToTarget <= (spidersMaxShootingRange * 2) then
                -- Target near by so just advance a bit.
                Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.lastDamagedFromPosition, spidersCurrentPosition))
                return
            else
                -- Target far away, so start chasing it.
                Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
                return
            end
        else
            -- Target not within fighting area
            -- Do fallback action.
        end
    end

    -- Theres no valid target found near the spider, so do a secondary action.

    -- Ensure the longer term target data is valid and remove it if not.
    Spider.UpdateTargetsDetails(spider, "chasing")

    -- If there is something to chase look at doing that.
    if spider.chasingEntity == nil then
        -- No chasing target to react to at present.
        -- So do fallback behaviour.
    else
        -- There is still a chasing target so check its distance.
        local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, spider.chasingEntityLastPosition)
        if distanceToTarget <= (spidersMaxShootingRange * 2) then
            -- Target near by so just advance a bit.
            Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.chasingEntityLastPosition, spidersCurrentPosition))
            return
        else
            -- Target far away, so start chasing it.
            Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
            return
        end
    end

    -- Fallback behaviour is to go home.
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "going home as last resort", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
    end
    Spider.StartRoaming(spider, spidersCurrentPosition)
end

--- Handle how to fight against a specific target type which is always currently valid.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
---@param chasingOrLastDamaged '"chasing"'|'"lastDamaged"'
---@param spidersMaxShootingRange uint
---@return boolean completed
---@return LuaEntity|'"none"' nearestEnemyWithinRange
Spider.FightTargetTypeWhileNotBeingDamaged = function(spider, spidersCurrentPosition, chasingOrLastDamaged, spidersMaxShootingRange)
    ---@typelist string, string, string
    local positionRefName
    if chasingOrLastDamaged == "chasing" then
        positionRefName = "chasingEntityLastPosition"
    elseif chasingOrLastDamaged == "lastDamaged" then
        positionRefName = "lastDamagedFromPosition"
    else
        error("chasingOrLastDamaged not 'chasing' or 'lastDamaged'")
    end

    local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, spider[positionRefName])

    -- Check if the spider has reached its target location.
    if distanceToTarget < 10 then
        -- The spider has reached its target position and so this must be in range of the targetted entity.

        -- Stop here to fight the target and anything else near by.
        Spider.OrderSpiderToStartMovingToPosition(spider, spidersCurrentPosition) -- Cancel any current movement order of the spider so it stops here.
        if Settings.showSpiderPlans then
            rendering.draw_text {text = "standing to fight", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
        end
        return
    end

    -- Spider hasn't reached target area yet.

    -- React based on if the target is near by or not.
    if distanceToTarget <= (spidersMaxShootingRange * 2) then
        -- Target near by so just advance a bit.
        Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider[positionRefName], spidersCurrentPosition))
        return
    else
        -- Target far away so start chase it as we aren't taking damage.
        Spider.ChargeAtAttacker(spider, spidersCurrentPosition)
        return
    end
end

--- Check a chased/lastDamaged target is still valid. If chasign a player it updates the target entity. Always updates target position. If the entity isn't valid or has left the fighting area it blanks out all target data. To make the chasing ad fighting logic simplier.
---@param spider JdSpiderRace_BossSpider
---@param chasingOrLastDamaged '"chasing"'|'"lastDamaged"'
Spider.UpdateTargetsDetails = function(spider, chasingOrLastDamaged)
    ---@typelist string, string, string
    local playerRefname, entityRefName, positionRefName
    if chasingOrLastDamaged == "chasing" then
        playerRefname, entityRefName, positionRefName = "chasingPlayer", "chasingEntity", "chasingEntityLastPosition"
    elseif chasingOrLastDamaged == "lastDamaged" then
        playerRefname, entityRefName, positionRefName = "lastDamagedByPlayer", "lastDamagedByEntity", "lastDamagedFromPosition"
    else
        error("chasingOrLastDamaged not 'chasing' or 'lastDamaged'")
    end

    -- Check if chasing a player first, then if just chasing an entity. Update the target position if player/entity is still valid. If entity ends up being invalid/blank it will have its position cleared later in code.
    if spider[playerRefname] ~= nil then
        -- A player was being chased.
        if spider[playerRefname].connected then
            -- A connected player is being chased so update the entity and position.
            spider[entityRefName] = spider[playerRefname].vehicle or spider[playerRefname].character
            if spider[entityRefName] == nil then
                -- Player is dead or not in a controller state to be chased. So stop chasing them.
                spider[playerRefname] = nil
            end
        else
            -- Player isn't connected so stop chasing them.
            spider[playerRefname] = nil
            -- If the target player was in a vehicle check if it's still a valid target.
            if spider[entityRefName] ~= nil and not spider[entityRefName].valid then
                -- Target entity isn't valid any more, so clear it out.
                spider[entityRefName] = nil
            end
        end
    elseif spider[entityRefName] ~= nil then
        -- Check if an entity being chased is still valid.
        if not spider[entityRefName].valid then
            -- Target entity isn't valid any more, so clear it out.
            spider[entityRefName] = nil
        end
    end

    -- If there's still a target entity check its new position is within the fighting area. Otherwise set the target position to blank.
    if spider[entityRefName] ~= nil then
        spider[positionRefName] = spider[entityRefName].position
        if not Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, spider[positionRefName]) then
            -- Target isn't in valid location so forget about the target.
            spider[positionRefName] = nil
            spider[entityRefName] = nil
            spider[playerRefname] = nil
        end
    else
        -- No entity targetted, so blank any position value.
        spider[positionRefName] = nil
    end
end

--- Advance roughly towards the target. Stays within the allowed fighting area.
--- Will wobble around them when very close (within Settings.spidersFightingStepDistance) of them. Intended to be very basic and simple initially.
---@param spider JdSpiderRace_BossSpider
---@param targetsCurrentPosition MapPosition
---@param spidersCurrentPosition MapPosition
Spider.GetNewPositionForAdvancingOnTarget = function(spider, targetsCurrentPosition, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "advancing on target", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
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
---@param spider JdSpiderRace_BossSpider
---@param targetsCurrentPosition MapPosition
---@param spidersCurrentPosition MapPosition
Spider.GetNewPositionForReversingFromTarget = function(spider, targetsCurrentPosition, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "reversing from target", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
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
        x = math_max(math_min(spidersCurrentPosition.x - (Settings.spidersFightingStepDistance * xPositonModifier), spider.fightingXMax), spider.fightingXMin),
        y = math_max(math_min(spidersCurrentPosition.y - (Settings.spidersFightingStepDistance * yPositonModifier), spider.fightingYMax), spider.fightingYMin)
    }
end

--- Order the spider to move to a position. This will also handle updating any hidden entities that aren't part of the boss spider.
---@param spider JdSpiderRace_BossSpider
---@param targetPosition MapPosition
Spider.OrderSpiderToStartMovingToPosition = function(spider, targetPosition)
    -- Give the various spider entities their order.
    spider.bossEntity.autopilot_destination = targetPosition
    for _, gunSpider in pairs(spider.gunSpiders) do
        gunSpider.entity.autopilot_destination = targetPosition
    end
end

--- Set the spider to start roaming.
---@param spider JdSpiderRace_BossSpider
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
---@param spider JdSpiderRace_BossSpider
Spider.Retreat = function(spider)
    Spider.ClearStateVariables(spider)

    spider.state = BossSpider_State.retreating
    spider.retreatingTargetPosition = {x = spider.roamingXMin, y = math_random(spider.roamingYMin, spider.roamingYMax)}
    Spider.OrderSpiderToStartMovingToPosition(spider, spider.retreatingTargetPosition)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Set the spider to charge towards its latest attacker and start fighting there. Will starting moving there if needed, otherwise just enter fighting mode.
---@param spider JdSpiderRace_BossSpider
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
        Spider.OrderSpiderToStartMovingToPosition(spider, currentTargetPosition)
        if Settings.showSpiderPlans then
            Spider.UpdatePlanRenders(spider)
        end
    end
end

--- Set the spider to start fighting in the area its currently at.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
Spider.StartFighting = function(spider, spidersCurrentPosition)
    spider.state = BossSpider_State.fighting
    Spider.ManageFightingForSecond(spider, spidersCurrentPosition)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Gets the player controlling an entity if there is one. This includes finding the primary player in a vehicle.
---@param entity LuaEntity
---@return LuaPlayer|null controllingPlayer
Spider.GetEntitiesControllingPlayer = function(entity)
    local entityType = entity.type
    if entityType == "character" then
        -- This will be the player controlling the character entity or nil.
        return entity.player
    elseif entityType == "spider-vehicle" or entityType == "car" or entityType == "artillery-wagon" or entityType == "cargo-wagon" or entityType == "fluid-wagon" or entityType == "locomotive" then
        local driverCharacter = entity.get_driver()
        if driverCharacter ~= nil then
            return driverCharacter.player
        else
            local passengerCharacter = entity.get_passenger()
            if passengerCharacter ~= nil then
                return passengerCharacter.player
            else
                return nil
            end
        end
    else
        return nil
    end
end

--- Clear all state variables.
---@param spider JdSpiderRace_BossSpider
Spider.ClearStateVariables = function(spider)
    spider.chasingPlayer = nil
    spider.chasingEntity = nil
    spider.chasingEntityLastPosition = nil
    spider.lastDamagedByPlayer = nil
    spider.lastDamagedByEntity = nil
    spider.lastDamagedFromPosition = nil
    spider.retreatingTargetPosition = nil
    spider.roamingTargetPosition = nil
end

--- Clear the non fighting state variables.
---@param spider JdSpiderRace_BossSpider
Spider.ClearNonFightingStateVariables = function(spider)
    spider.retreatingTargetPosition = nil
    spider.roamingTargetPosition = nil
end

--- Gets the max distance the spider can fight from right now based on the weapons it has ammo for. This is either long (30) or short (15), rather than being truely maximum single weapon range.
---@param spider JdSpiderRace_BossSpider
---@return double maxEngagementRange
Spider.GetSpidersEngagementRange = function(spider)
    if spider.gunSpiders[BossSpider_GunSpiderType.rocketLauncher].hasAmmo then
        if not spider.gunSpiders[BossSpider_GunSpiderType.rocketLauncher].entity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            -- Intentionally return the cannon range rather than the missile one. Just so the spider tries to engage with both weapons when ammo allows. As this range is still more than laser turrets. This is the long range value.
            return 30
        else
            spider.gunSpiders[BossSpider_GunSpiderType.rocketLauncher].hasAmmo = false
        end
    end
    if spider.gunSpiders[BossSpider_GunSpiderType.tankCannon].hasAmmo then
        if not spider.gunSpiders[BossSpider_GunSpiderType.tankCannon].entity.get_inventory(defines.inventory.spider_ammo).is_empty() then
            -- This is the long range value.
            return 30
        else
            spider.gunSpiders[BossSpider_GunSpiderType.tankCannon].hasAmmo = false
        end
    end

    -- Otherwise just return the short distance.
    return 15
end

--- Checks if the target position if its within the allowed fighting area.
---@param spider JdSpiderRace_BossSpider
---@param targetPosition MapPosition
---@return boolean positionIsValid
Spider.IsFightingTargetPositionWithinAllowedFightingArea = function(spider, targetPosition)
    if targetPosition.x < spider.fightingXMin or targetPosition.x > spider.fightingXMax then
        return false
    elseif targetPosition.y < spider.fightingYMin or targetPosition.y > spider.fightingYMax then
        return false
    else
        return true
    end
end

--- Render the spiders current plans and remove any old ones first. This is for debugging/testing and so doesn't matter than not optimal UPS.
---@param spider JdSpiderRace_BossSpider
Spider.UpdatePlanRenders = function(spider)
    -- Just remove all the old renders.
    for _, renderId in pairs(spider.spiderPlanRenderIds) do
        rendering.destroy(renderId)
    end
    spider.spiderPlanRenderIds = {}

    -- Add any state specific renders for the spider.
    if spider.state == BossSpider_State.roaming then
        if spider.roamingTargetPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - moving", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.roamingTargetPosition, surface = global.general.surface})
        else
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - arrived", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
        end
    elseif spider.state == BossSpider_State.retreating then
        table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state, surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
        table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.retreatingTargetPosition, surface = global.general.surface})
    elseif spider.state == BossSpider_State.dead then
        -- The entity still exists the moment this is called, but not afterwards. So set it to the position and not the entity itself.
        table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state, surface = global.general.surface, target = spider.bossEntity.position, color = Colors.white, scale_with_zoom = true})
    elseif spider.state == BossSpider_State.chasing then
        if spider.lastDamagedFromPosition ~= nil then
            if spider.lastDamagedByEntity ~= nil and spider.lastDamagedByEntity.valid then
                table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent entity", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
                table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.red, width = 2, from = spider.bossEntity, to = spider.lastDamagedByEntity, surface = global.general.surface})
            else
                table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent area", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            end

            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedFromPosition, surface = global.general.surface})
        elseif spider.chasingEntityLastPosition ~= nil then
            if spider.chasingEntity ~= nil and spider.chasingEntity.valid then
                table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional entity", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
                table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.red, width = 2, from = spider.bossEntity, to = spider.chasingEntity, surface = global.general.surface})
            else
                table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional area", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            end

            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntityLastPosition, surface = global.general.surface})
        end
    elseif spider.state == BossSpider_State.fighting then
        if spider.lastDamagedByEntity ~= nil and spider.lastDamagedByEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent entity", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedByEntity, surface = global.general.surface})
        elseif spider.lastDamagedFromPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - recent area", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.lastDamagedFromPosition, surface = global.general.surface})
        elseif spider.chasingEntity ~= nil and spider.chasingEntity.valid then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional entity", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntity, surface = global.general.surface})
        elseif spider.chasingEntityLastPosition ~= nil then
            table.insert(spider.spiderPlanRenderIds, rendering.draw_text {text = spider.state .. " - origional area", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true})
            table.insert(spider.spiderPlanRenderIds, rendering.draw_line {color = Colors.white, width = 2, from = spider.bossEntity, to = spider.chasingEntityLastPosition, surface = global.general.surface})
        end
    end
end

--- When the spider_incrememt_distance_from_spawn command is called.
---@param commandEvent CustomCommandData
Spider.Command_IncrementDistanceFromSpawn = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_incrememt_distance_from_spawn command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 2 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 2, got" .. #args, Colors.lightred)
        return
    end

    local playerTeamName = args[1] ---@type string
    if playerTeamName ~= "both" and PlayerForcesNameToDetails[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    local distanceChange = args[2] ---@type number
    if type(distanceChange) ~= "number" then
        game.print(commandErrorMessagePrefix .. "Second argument of distance to change by must be a number, recieved: " .. tostring(distanceChange), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
            Spider.UpdateSpidersRoamingValues(spider)
        end
        -- LATER: show GUI message about update.
        local x = 1
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
        Spider.UpdateSpidersRoamingValues(spider)
        -- LATER: show GUI message about update.
        local x = 1
    end
end

--- When the spider_set_movement_per_minute command is called.
---@param commandEvent CustomCommandData
Spider.Command_SetSpiderMovementPerMinute = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_set_movement_per_minute command - "
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
        Spider.UpdateSpidersRoamingValues(spider)
    end

    -- Schedule the next Minutes event. As the first instance of this schedule always occurs exactly on a minute no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEvent(event.tick + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
end

--- Gives the boss spider and its gun spiders 1 set of ammo.
---@param spider JdSpiderRace_BossSpider
Spider.GiveSpiderFullAmmo = function(spider)
    if spider.state == BossSpider_State.dead then
        return
    end

    -- Arm the boss spider.
    for _, ammo in pairs(BossSpider_Rearm) do
        spider.bossEntity.insert(ammo)
    end
    spider.hasAmmo = true

    -- Arm each of the gun spiders.
    for bossSpiderGunType, ammoItems in pairs(BossSpider_GunSpiderRearm) do
        for _, ammo in pairs(ammoItems) do
            spider.gunSpiders[bossSpiderGunType].entity.insert(ammo)
        end
        spider.gunSpiders[bossSpiderGunType].hasAmmo = true
    end

    -- Arm each of the turrets.
    for turretType, ammoItems in pairs(BossSpider_TurretRearm) do
        for _, ammo in pairs(ammoItems) do
            spider.turrets[turretType].entity.insert(ammo)
        end
    end
end

--- When the spider_full_rearm command is called to give the spider a full set of ammo.
---@param commandEvent CustomCommandData
Spider.Command_RearmSpider = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_full_rearm command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 1 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 1, got" .. #args, Colors.lightred)
        return
    end

    local playerTeamName = args[1] ---@type string
    if playerTeamName ~= "both" and PlayerForcesNameToDetails[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            Spider.GiveSpiderFullAmmo(spider)
        end
        -- LATER: show GUI message about update.
        local x = 1
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        Spider.GiveSpiderFullAmmo(spider)
        -- LATER: show GUI message about update.
        local x = 1
    end
end

--- When the spider_give_ammo command is called to give the spider a specific type and count of ammo.
---@param commandEvent CustomCommandData
Spider.Command_GiveSpiderAmmo = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_full_rearm command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 3 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 3, got" .. #args, Colors.lightred)
        return
    end

    local playerTeamName = args[1] ---@type string
    if playerTeamName ~= "both" and PlayerForcesNameToDetails[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    local ammoFriendlyName = args[2] ---@type string
    local rconAmmoType = BossSpider_RconAmmoNames[ammoFriendlyName]
    if rconAmmoType == nil then
        game.print(commandErrorMessagePrefix .. "Second argument of ammoName must be one of the specific ammo types, recieved: " .. tostring(ammoFriendlyName) .. ". Options: bullet, piercingBullet, uraniumBullet, rocket, explosiveRocket, atomicRocket, cannonShell, explosiveCannonShell, uraniumCannonShell, explosiveUraniumCannonShell, artilleryShell, flamethrowerAmmo", Colors.lightred)
        return
    end

    local quantity = args[3] ---@type number
    if type(quantity) ~= "number" then
        game.print(commandErrorMessagePrefix .. "Third argument of quantity must be a number, recieved: " .. tostring(quantity), Colors.lightred)
        return
    end
    quantity = math.floor(quantity)

    if quantity <= 0 then
        game.print(commandErrorMessagePrefix .. "Quantity of 0 or less is ignored, recieved after rounding down: " .. tostring(quantity), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            Spider.GiveSpiderSpecificAmmo(spider, rconAmmoType, quantity)
        end
        -- LATER: show GUI message about update.
        local x = 1
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        Spider.GiveSpiderSpecificAmmo(spider, rconAmmoType, quantity)
        -- LATER: show GUI message about update.
        local x = 1
    end
end

--- Gives a spider a specific ammo type and count. Works out which entity to put the ammo in.
---@param spider JdSpiderRace_BossSpider
---@param rconAmmoType JdSpiderRace_BossSpider_RconAmmoType
---@param quantity uint
Spider.GiveSpiderSpecificAmmo = function(spider, rconAmmoType, quantity)
    if rconAmmoType.bossSpider then
        spider.bossEntity.insert({name = rconAmmoType.ammoItemName, count = quantity})
        spider.hasAmmo = true
    elseif rconAmmoType.gunType then
        spider.gunSpiders[rconAmmoType.gunType].entity.insert({name = rconAmmoType.ammoItemName, count = quantity})
        spider.gunSpiders[rconAmmoType.gunType].hasAmmo = true
    elseif rconAmmoType.turretType then
        spider.turrets[rconAmmoType.turretType].entity.insert({name = rconAmmoType.ammoItemName, count = quantity})
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

    spider.state = BossSpider_State.dead
    for _, gunSpiderDetails in pairs(spider.gunSpiders) do
        gunSpiderDetails.entity.destroy()
    end
    for _, turretDetails in pairs(spider.turrets) do
        turretDetails.entity.destroy()
    end

    Spider.UpdatePlanRenders(spider)

    -- Coin is dropped as loot automatically.
    game.print("HYPE - boss spider of team " .. spider.playerTeamName .. " killed !!!", Colors.green)

    -- LATER: announce the death and do any GUI stuff, etc. Maybe freeze all spider distance changes and lock the scoreboard?
end

--- When the spider_reset_state command is called. Resets it's state variables and teleports it home to fix any odd state it may have got into.
---@param commandEvent CustomCommandData
Spider.Command_ResetSpiderState = function(commandEvent)
    local args = Commands.GetArgumentsFromCommand(commandEvent.parameter)
    local commandErrorMessagePrefix = "ERROR: spider_reset_state command - "
    if args == nil or type(args) ~= "table" or #args == 0 then
        game.print(commandErrorMessagePrefix .. "No arguments provided.", Colors.lightred)
        return
    end
    if #args ~= 1 then
        game.print(commandErrorMessagePrefix .. "Wrong number of arguments provided. Expected 1, got" .. #args, Colors.lightred)
        return
    end

    local playerTeamName = args[1] ---@type string
    if PlayerForcesNameToDetails[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'Argument of player team name was invalid, either "north" or "south". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have been flagged by now.
    local spider = global.spider.playerTeamsSpider[playerTeamName]
    Spider.ClearStateVariables(spider)
    local teleportPosition = {
        x = ((spider.roamingXMax - spider.roamingXMin) / 2) + spider.roamingXMin,
        y = ((spider.roamingYMax - spider.roamingYMin) / 2) + spider.roamingYMin
    }
    spider.bossEntity.teleport(teleportPosition)
    for _, gunSpider in pairs(spider.gunSpiders) do
        gunSpider.entity.teleport(teleportPosition)
    end
    Spider.StartRoaming(spider, teleportPosition)
end

return Spider
