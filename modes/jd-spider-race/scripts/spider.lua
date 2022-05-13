--[[
    The spiders mangement is done as a very light touch and as such its movements are a bit all or nothing. But it does perform far better in combat than if it just mindlessly followed a target until it was made to retreat. Its designed to be primarily reactive, with only limited simple proactive behaviour in certain combat situations.
    Spiders movement accuracy looks to be based on it's speed and leg length, so as ours is fast and has is large with long legs it seems to be very inaccurate in its stopping position. This can lead to it dancing back and fourth sometimes, but as soon as it kills the "odd" target it will return to regular behavour. It has ended up like this as a comprise to avoid it being damaged by base defences given its inaccurate movement. Also the invisble spiders may have taken the exact position and so the real spider ends up slightly offset.
    The inviisbel spiders tend to shuffle/float around the main spider when its fighting as they can't reach the exact target position. So this should even out any brief range issues when a gun spider is further away from a target than the real spider. The less invisble spiders the better for this. The invisble spiders have to have legs, etc so they move at the same speed as the real spider when crossing larger distances.
]]
--

local Spider = {}
local Utils = require("utility.utils")
local EventScheduler = require("utility/event-scheduler")
local Colors = require("utility.colors")
local Commands = require("utility.commands")
local Events = require("utility.events")
local GuiUtil = require("utility.gui-util")
local MuppetStyles = require("utility.style-data").MuppetStyles
local math_min, math_max, math_floor, math_ceil, math_random = math.min, math.max, math.floor, math.ceil, math.random

---@class JdSpiderRace_BossSpider
---@field unitNumber UnitNumber|null @ The UnitNumber of the boss spider entity once the entity has been created, otherwise nil.
---@field state JdSpiderRace_BossSpider_State
---@field playerTeam JdSpiderRace_PlayerHome_Team
---@field bossEntity LuaEntity|null @ The main spider boss entity once the entity has been created, otherwise nil.
---@field gunSpiders table<JdSpiderRace_BossSpider_GunSpiderType, JdSpiderRace_GunSpider> @ The hidden spiders that move with the main spider. They are present just to carry the extra gun types. They are created once the boss spider entity has been created, otherwise the table is empty.
---@field turrets table<JdSpiderRace_BossSpider_TurretType, JdSpiderRace_BossSpider_Turret> @ The hidden turrets that are moved once per second cycle to the spiders current position. The weapons on these should be happy to be out of sync with the spiders exact position. They are created once the boss spider entity has been created, otherwise the table is empty.
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
---@field spiderPositionLastSecond MapPosition|null @ The spiders position last second once the boss spider entity has been created, otherwise nil. Used by various state's cycle functions.
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
---@field lastSentBitersToAttackTick Tick @ Last tick that biters were sent to attack the player in response to the spider being attacked.
---@field leftMostXChunkPositionGeneratedByTeamAwayFromDivide ChunkPosition @ The left (west) most chunk generated that is the >=7 chunks from the divide required to create the spider entities. Updated on every chunk generated and used when a spiders distance from spawn is moved negative.
---@field ammoForCreationTime table<JdSpiderRace_BossSpider_RconAmmoName, uint> @ The ammo given to a spider by RCON before it is created.
---@field spiderFullyArmCountForCreationTime uint @ How many times the spider should be given a full rearm count when its created.
---@field lastFiredNukeTick Tick @ Last tick that the boss spider fired a nuke at an enemy.
---@field nukeAmmo uint @ How many nukes the spider has left.

---@class JdSpiderRace_GunSpider
---@field type JdSpiderRace_BossSpider_GunSpiderType
---@field entity LuaEntity

---@class JdSpiderRace_BossSpider_Turret
---@field type JdSpiderRace_BossSpider_TurretType
---@field entity LuaEntity

---@class JdSpiderRace_BossSpider_State
local BossSpider_State = {
    roaming = "roaming", -- Just idling wondering its area.
    fighting = "fighting", -- Not significantly moving, but actively being managed in a combat state.
    chasing = "chasing", -- Actively chasing after a military target that attacked it.
    retreating = "retreating", -- Moving away from the threat.
    dead = "dead", -- Its dead.
    notCreatedYet = "notCreatedYet" -- Spider entity not created yet.
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
            [1] = "jd_plays-jd_spider_race-spidertron_boss-firearm_magazine_ammo",
            [2] = "piercing-rounds-magazine",
            [3] = "uranium-rounds-magazine"
        }
    },
    [BossSpider_GunSpiderType.rocketLauncher] = {
        name = "jd_plays-jd_spider_race-spidertron_boss_gun-rocket_launcher",
        gunFilters = {
            [1] = "jd_plays-jd_spider_race-spidertron_boss-rocket_ammo",
            [2] = "explosive-rocket"
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
    {name = "atomic-bomb", count = 10}
}

---@type table<JdSpiderRace_BossSpider_GunSpiderType, ItemStackDefinition[]>
local BossSpider_GunSpiderRearm = {
    [BossSpider_GunSpiderType.machineGun] = {
        {name = "piercing-rounds-magazine", count = 200},
        {name = "uranium-rounds-magazine", count = 200}
    },
    [BossSpider_GunSpiderType.rocketLauncher] = {
        {name = "explosive-rocket", count = 200}
    },
    [BossSpider_GunSpiderType.tankCannon] = {
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

---@class JdSpiderRace_BossSpider_RconAmmoName
local BossSpider_RconAmmoNames = {piercingBullet = "piercingBullet", uraniumBullet = "uraniumBullet", explosiveRocket = "explosiveRocket", atomicRocket = "atomicRocket", explosiveCannonShell = "explosiveCannonShell", uraniumCannonShell = "uraniumCannonShell", explosiveUraniumCannonShell = "explosiveUraniumCannonShell", artilleryShell = "artilleryShell"}

---@class JdSpiderRace_BossSpider_RconAmmoType
---@field ammoItemName string @ The item prototype name in Factorio.
---@field ammoItemPrettyName JdSpiderRace_BossSpider_RconAmmoName @ The player printable name (with spaces).
---@field gunType JdSpiderRace_BossSpider_GunSpiderType|null
---@field bossSpider boolean|null
---@field turretType JdSpiderRace_BossSpider_TurretType|null

---@type table<JdSpiderRace_BossSpider_RconAmmoName, JdSpiderRace_BossSpider_RconAmmoType> @ Command friendly name to item name.
local BossSpider_RconAmmoTypes = {
    piercingBullet = {ammoItemName = "piercing-rounds-magazine", gunType = BossSpider_GunSpiderType.machineGun, ammoItemPrettyName = "piercing bullet"},
    uraniumBullet = {ammoItemName = "uranium-rounds-magazine", gunType = BossSpider_GunSpiderType.machineGun, ammoItemPrettyName = "uranium bullet"},
    explosiveRocket = {ammoItemName = "explosive-rocket", gunType = BossSpider_GunSpiderType.rocketLauncher, ammoItemPrettyName = "explosive rocket"},
    atomicRocket = {ammoItemName = "atomic-bomb", bossSpider = true, ammoItemPrettyName = "atomic rocket"},
    explosiveCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon, ammoItemPrettyName = "explosive cannon shell"},
    uraniumCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon, ammoItemPrettyName = "uranium cannon shell"},
    explosiveUraniumCannonShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo", gunType = BossSpider_GunSpiderType.tankCannon, ammoItemPrettyName = "explosive uranium cannon shell"},
    artilleryShell = {ammoItemName = "jd_plays-jd_spider_race-spidertron_boss-artillery_shell", turretType = BossSpider_TurretType.artillery, ammoItemPrettyName = "artillery shell"}
}

---@class JdSpiderRace_BossSpider_ScoreGuiData
---@field northSpiderTargetDistance string
---@field northSpiderClearedDistance string
---@field northSpiderDistancePercentage uint
---@field northSpiderMaxHealth string
---@field northSpiderCurrentHealth string
---@field northSpiderHealthPercentage uint
---@field southSpiderMaxHealth string
---@field southSpiderCurrentHealth string
---@field southSpiderHealthPercentage uint
---@field southSpiderTargetDistance string
---@field southSpiderClearedDistance string
---@field southSpiderDistancePercentage uint

local Settings = {
    bossSpiderStartingLeftDistance = 5000, -- How far left of spawn the center of the spiders area starts the game at.
    spiderDamageToRetreat = 10000,
    spiderDamageSecondsConsidered = 600, -- How many seconds in the past the spider will consider to see if it has sustained enough damage to retreat. Set to 10 minutes to try and counter players doing slow damage to the spider to try and avoid it retreating.
    spiderDistanceToRetreat = 1000, -- How far to increment a spider's distance to the left by when it is forced to retreat.
    spidersRoamingXRange = 500, -- How far left and right from the centre of a teams lane the spider will roam.
    spidersFightingXRange = 2000, -- Random limit to stop it chasing infinitely.
    spidersFightingStepDistance = 5, -- How far the spider will move away from its current location when fighting per second. - value of 2 or lower known to cause weird failed leg movement actions.
    distanceToCheckForEnemiesNearby = 60, -- How far around it the spider will look for enemies nearby before considering other actions when fighting. This is a bit above how far the spider can move in a second plus its max weapons range, to try and avoid it stepping forwards and then next second stepping backwards.
    distanceSpiderMovesinSecond = 21, -- Approximate distance a full speed boss spider will cover over 1 second. This is based o the spiders current speed and not for adhoc changing.
    showSpiderPlans = false, -- If enabled the plans of a spider are rendered.
    markSpiderAreas = false, -- If enabled the roaming and fighting areas of the spiders are marked with lines. Blue for roaming and red for fighting.
    bitersSentToRetaliateMaxFrequency = 18000, -- The max frequency all biters near the spider can be sent at the players in retaliation for attacking the spider. 18,000 is 5 minutes.
    spiderArtilleryWeaponRange = 560, -- The hard coded range of the spiders artillery gun.
    spiderNukeMaxFrequency = 240, -- One nuke no more frequently than every 4 seconds to try and avoiding double firing at a target at max distance. JD wanted this value rather than the 5 I knew was safe.
    spiderEngagementRange = 34 -- This is just within the tank cannon and rocket range. We go short of max range as the invisible gun spiders will be within a tile or so of the main spider.
}

-- Testing is for development and is very adhoc in what it changes to allow simplier testing.
local Testing = true
if Testing then
    Settings.bossSpiderStartingLeftDistance = 1000
    Settings.spidersRoamingXRange = 100
    Settings.spidersFightingXRange = 300
    Settings.showSpiderPlans = true
    Settings.markSpiderAreas = true
--BossSpider_GunSpiderRearm[BossSpider_GunSpiderType.rocketLauncher][3] = nil -- No atomic weapons.
--BossSpider_TurretRearm[BossSpider_TurretType.artillery] = {} -- No artillery shells.
end

Spider.CreateGlobals = function()
    global.spider = global.spider or {}
    global.spider.spiders = global.spider.spiders or {} ---@type JdSpiderRace_BossSpider[]
    global.spider.spiderUnitNumberToSpider = global.spider.spiderUnitNumberToSpider or {} ---@type table<UnitNumber, JdSpiderRace_BossSpider>
    global.spider.playerTeamsSpider = global.spider.playerTeamsSpider or {} ---@type table<JdSpiderRace_PlayerHome_PlayerTeamNames, JdSpiderRace_BossSpider> @ The player team name to the spider they are fighting.
    global.spider.showSpiderPlans = global.spider.showSpiderPlans or Settings.showSpiderPlans ---@type boolean
    global.spider.constantMovementFromSpawnPerMinute = global.spider.constantMovementFromSpawnPerMinute or 3 ---@type number @ Should be >= 0. Less thab 0 isn't tested and will have some logic gaps.
    global.spider.playersMessageGuiEnabled = global.spider.playersMessageGuiEnabled or {} ---@type table<PlayerIndex, LuaPlayer> @ The players who have set that they want to recieve Message GUI notifications.
    global.spider.playersScoreGuiEnabled = global.spider.playersScoreGuiEnabled or {} ---@type table<PlayerIndex, LuaPlayer> @ The players who have set that they want the Scrore GUI enabled.
    global.spider.messageGuiId = global.spider.messageGuiId or 0 ---@type uint
end

Spider.OnLoad = function()
    MOD.Interfaces.Spider = MOD.Interfaces.Spider or {}

    EventScheduler.RegisterScheduledEventType("Spider.CheckSpiders_Scheduled", Spider.CheckSpiders_Scheduled)
    EventScheduler.RegisterScheduledEventType("Spider.SpidersMoveAwayFromSpawn_Scheduled", Spider.SpidersMoveAwayFromSpawn_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Spider.OnChunkGenerated", Spider.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Spider.OnSpiderDied", Spider.OnSpiderDied, {{filter = "name", name = "jd_plays-jd_spider_race-spidertron_boss"}})
    MOD.Interfaces.Spider.OnNewMostWestEntityBuilt = Spider.OnNewMostWestEntityBuilt

    Commands.Register("spider_incrememt_distance_from_spawn", {"api-description.jd_plays-jd_spider_race-spider_incrememt_distance_from_spawn"}, Spider.Command_IncrementDistanceFromSpawn, true)
    Commands.Register("spider_set_movement_per_minute", {"api-description.jd_plays-jd_spider_race-spider_set_movement_per_minute"}, Spider.Command_SetSpiderMovementPerMinute, true)
    Commands.Register("spider_reset_state", {"api-description.jd_plays-jd_spider_race-spider_reset_state"}, Spider.Command_ResetSpiderState, true)
    Commands.Register("spider_full_rearm", {"api-description.jd_plays-jd_spider_race-spider_full_rearm"}, Spider.Command_FullyRearmSpider, true)
    Commands.Register("spider_give_ammo", {"api-description.jd_plays-jd_spider_race-spider_give_ammo"}, Spider.Command_GiveSpiderAmmo, true)

    Events.RegisterHandlerEvent(defines.events.on_lua_shortcut, "Spider.OnLuaShortcut", Spider.OnLuaShortcut)
    EventScheduler.RegisterScheduledEventType("Spider.RemoveMessageFromPlayers_Scheduled", Spider.RemoveMessageFromPlayers_Scheduled)

    Events.RegisterHandlerEvent(defines.events.on_player_created, "Spider.OnPlayerCreated", Spider.OnPlayerCreated)
    Events.RegisterHandlerEvent(defines.events.on_player_joined_game, "Spider.OnPlayerJoinedGame", Spider.OnPlayerJoinedGame)
end

Spider.OnStartup = function()
    -- Create the spiders for each team if they don't exist.
    if next(global.spider.spiders) == nil then
        for _, playerTeam in pairs(global.playerHome.teams) do
            Spider.CreateSpiderObject(playerTeam)
        end

        Spider.SetSpiderForcesTechs()

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEventOnce((math_floor(game.tick / 60) * 60) + 60, "Spider.CheckSpiders_Scheduled")

        -- Schedule it to occur at the start of every second. Makes later re-occuring rescheduling logic simplier as can just divide now by 60.
        EventScheduler.ScheduleEventOnce((math_floor(game.tick / 3600) * 3600) + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
    end
end

--- Create a new boss spider object for the specific player team to compete against.
--- Doesn't create the actual entity, this is done when the player gets near. This avoids chunks with low evo biters being pre-generated.
---@param playerTeam JdSpiderRace_PlayerHome_Team
Spider.CreateSpiderObject = function(playerTeam)
    ---@type JdSpiderRace_BossSpider
    local spider = {
        unitNumber = nil, -- Populated when the spider's entities are created.
        bossEntity = nil, -- Populated when the spider's entities are created.
        state = BossSpider_State.notCreatedYet,
        playerTeam = playerTeam,
        distanceFromSpawn = Settings.bossSpiderStartingLeftDistance,
        damageTakenThisSecond = 0,
        previousDamageToConsider = 0,
        secondsWhenDamaged = {},
        roamingXMin = nil, -- Populated later in creation function.
        roamingXMax = nil, -- Populated later in creation function.
        roamingYMin = playerTeam.spawnPosition.y - (global.general.perTeamMapHeight / 2) + 26, -- Nearly to the edge of the team's lane.
        roamingYMax = playerTeam.spawnPosition.y + (global.general.perTeamMapHeight / 2) - 26, -- Nearly to the edge of the team's lane.
        fightingXMin = -1000000, -- Can move as far left as it wants to chase a target.
        fightingXMax = nil, -- Populated later in creation function.
        fightingYMin = playerTeam.spawnPosition.y - (global.general.perTeamMapHeight / 2), -- Right up to the edge of the team's lane.
        fightingYMax = playerTeam.spawnPosition.y + (global.general.perTeamMapHeight / 2), -- Right up to the edge of the team's lane.
        spiderPlanRenderIds = {},
        spiderAreasRenderIds = {},
        spiderPositionLastSecond = nil, -- Populated when the spider's entities are created.
        gunSpiders = {}, -- Populated when the spider's entities are created.
        turrets = {}, -- Populated when the spider's entities are created.
        roamingTargetPosition = nil,
        retreatingTargetPosition = nil,
        lastDamagedByPlayer = nil,
        lastDamagedByEntity = nil,
        lastDamagedFromPosition = nil,
        chasingPlayer = nil,
        chasingEntity = nil,
        chasingEntityLastPosition = nil,
        lastSentBitersToAttackTick = -999999, -- Set to ages ago so first trigger attempt always works.
        leftMostXChunkPositionGeneratedByTeamAwayFromDivide = 0, -- Default starting value.
        ammoForCreationTime = {}, -- Populated via RCON commands.
        spiderFullyArmCountForCreationTime = 1, -- Increased via RCON commands. Start the spider with 1 full ammo count.
        lastFiredNukeTick = -999999, -- Set to ages ago so first trigger attempt always works.
        nukeAmmo = 0
    }

    Spider.UpdateSpidersRoamingValues(spider)

    -- Record the spider to globals.
    table.insert(global.spider.spiders, spider)
    global.spider.playerTeamsSpider[playerTeam.id] = spider
end

--- Called for each chunk being generated. Used to track if  we need to create the spider entities and do the extra chunk generation.
---@param event on_chunk_generated
Spider.OnChunkGenerated = function(event)
    -- Check if the chunk generated needs to trigger a spider to be created. This just checks if the chunk contains some of the team's spider's roaming area. Anything within artillery range is handled as part of a valid entity being built on the correct side of the divide.
    for _, spider in pairs(global.spider.spiders) do
        -- If the spider doesn't have any entities yet then we inspect and record the further west chunks generated.
        -- CODE NOTE: This is 7 chunks or more in from the divider, anything closer to the divider is ignored. This should stop teams from triggering each others spider generation unintentionally when clearing their own lanes, but does mean in theory a player running right down the egde of the divider wouldn't trigger the spider to appear on their own side. This seems to be an unavoidable comprimise.
        if spider.state == BossSpider_State.notCreatedYet and ((spider.playerTeam.spawnPosition.y < 0 and event.position.y <= -7) or (spider.playerTeam.spawnPosition.y > 0 and event.position.y >= 7)) then
            -- This is a chunk that could generate spider entities depending on where the spiders roaming area is (now or in future).

            -- Keep a record of the left most potentially generating spider chunk incase the spiders distance is moved backwards.
            if event.position.x < spider.leftMostXChunkPositionGeneratedByTeamAwayFromDivide then
                spider.leftMostXChunkPositionGeneratedByTeamAwayFromDivide = event.position.x

                -- If this chunk is within the roaming area then make the spiders entities now.
                if event.area.right_bottom.x <= spider.roamingXMax then
                    Spider.CreateSpiderEntities(spider)
                end
            end
        end
    end
end

--- Called when a new most westward valid entity is built for a team. As this may trigger the need for spider entities to be created.
---@param team JdSpiderRace_PlayerHome_Team
---@param position MapPosition
Spider.OnNewMostWestEntityBuilt = function(team, position)
    local spider = global.spider.playerTeamsSpider[team.id]
    if spider.state ~= BossSpider_State.notCreatedYet then
        -- Spider already exists for this team.
        return
    end

    -- Check east from the spiders roaming max X range to cover the spiders artillery weapon range. See if the etity we just built is within this range.
    if spider.roamingXMax + Settings.spiderArtilleryWeaponRange >= position.x then
        -- This position is within the potential range of the spiders artillery so create the spider.
        Spider.CreateSpiderEntities(spider)
    end
end

--- Called to make the actual spider entities
---@param spider JdSpiderRace_BossSpider
Spider.CreateSpiderEntities = function(spider)
    local spiderPosition = {x = spider.playerTeam.spawnPosition.x - spider.distanceFromSpawn, y = spider.playerTeam.spawnPosition.y}

    -- Create the boss spider entity.
    -- CODE NOTE: They can be created in chunks that don't exist as they have a radar and thus will generate the chunks around them.
    local bossEntity = global.general.surface.create_entity {name = "jd_plays-jd_spider_race-spidertron_boss", position = spiderPosition, force = spider.playerTeam.enemyForce}
    if bossEntity == nil then
        error("Failed to create boss spider for team " .. spider.playerTeam.id .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
        return
    end
    bossEntity.color = {0, 0, 0, 200} -- Deep black, but some highlighting still visible.

    -- Update spider object and globals to their proper active spider values.
    spider.unitNumber = bossEntity.unit_number
    spider.bossEntity = bossEntity
    spider.state = BossSpider_State.roaming
    spider.spiderPositionLastSecond = spiderPosition
    global.spider.spiderUnitNumberToSpider[spider.unitNumber] = spider

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
        local gunSpiderEntity = global.general.surface.create_entity {name = entityDetails.name, position = spiderPosition, force = spider.playerTeam.enemyForce}
        if gunSpiderEntity == nil then
            error("Failed to create gun spider " .. shortName .. " for team " .. spider.playerTeam.id .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
            return
        end
        gunSpiderEntity.destructible = false
        local ammoInventory = gunSpiderEntity.get_inventory(defines.inventory.spider_ammo)
        for gunIndex, filterName in pairs(entityDetails.gunFilters) do
            ammoInventory.set_filter(gunIndex, filterName)
        end
        spider.gunSpiders[shortName] = {type = shortName, entity = gunSpiderEntity}
    end

    -- Add the extra turrets.
    for shortName, entityDetails in pairs(BossSpider_TurretDetails) do
        local turretEntity = global.general.surface.create_entity {name = entityDetails.name, position = spiderPosition, force = spider.playerTeam.enemyForce}
        if turretEntity == nil then
            error("Failed to create turret " .. shortName .. " for team " .. spider.playerTeam.id .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
        end
        turretEntity.destructible = false
        spider.turrets[shortName] = {type = shortName, entity = turretEntity}
    end

    -- Give the spider the special never ending basic ammos.
    spider.bossEntity.insert({name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo", count = 1})
    spider.gunSpiders[BossSpider_GunSpiderType.machineGun].entity.insert({name = "jd_plays-jd_spider_race-spidertron_boss-firearm_magazine_ammo", count = 1})
    spider.gunSpiders[BossSpider_GunSpiderType.rocketLauncher].entity.insert({name = "jd_plays-jd_spider_race-spidertron_boss-rocket_ammo", count = 1})
    spider.gunSpiders[BossSpider_GunSpiderType.tankCannon].entity.insert({name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo", count = 1})

    -- Give the spider the accumilated full ammo sets.
    for i = 1, spider.spiderFullyArmCountForCreationTime do
        Spider.GiveSpiderFullAmmo(spider)
    end
    spider.spiderFullyArmCountForCreationTime = 0

    -- Give the spider the accumilated adhock ammo counts.
    for ammoFriendlyName, quantity in pairs(spider.ammoForCreationTime) do
        Spider.GiveSpiderSpecificAmmo(spider, ammoFriendlyName, BossSpider_RconAmmoTypes[ammoFriendlyName], quantity)
    end
    spider.ammoForCreationTime = {}

    -- Triggers the map chunks past the spider to be generated now, rather than waiting for the next distance from spawn movement event.
    Spider.UpdateSpidersRoamingValues(spider)
end

--- Give the forces of the spiders all the shooting speed upgrades and damage upgrades.
Spider.SetSpiderForcesTechs = function()
    for _, spider in pairs(global.spider.spiders) do
        local spiderForce = spider.playerTeam.enemyForce
        -- Have to give each tech rather than just the final one as they each add a bonus (cumulative).
        for techName, maxLevel in pairs({["weapon-shooting-speed-"] = 6, ["laser-shooting-speed-"] = 7, ["physical-projectile-damage-"] = 6, ["refined-flammables-"] = 6, ["stronger-explosives-"] = 6, ["energy-weapons-damage-"] = 6}) do
            for level = 1, maxLevel do
                spiderForce.technologies[techName .. level].researched = true
            end
        end
    end
end

--- Called when a spider has a new distance from spawn set and we need to change it's cached roaming values.
---@param spider JdSpiderRace_BossSpider
Spider.UpdateSpidersRoamingValues = function(spider)
    -- Code Note: a lot of these vaues start off as negatives in our usage case. Hence why adding values togeather to go left (more negative).
    spider.roamingXMin = spider.playerTeam.spawnPosition.x - (spider.distanceFromSpawn + Settings.spidersRoamingXRange)
    spider.roamingXMax = spider.playerTeam.spawnPosition.x - (spider.distanceFromSpawn - Settings.spidersRoamingXRange)
    spider.fightingXMax = spider.playerTeam.spawnPosition.x - (spider.distanceFromSpawn - Settings.spidersFightingXRange)
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

    -- Create chunks for the spider if it exists.
    if spider.state ~= BossSpider_State.notCreatedYet and spider.state ~= BossSpider_State.dead then
        -- Request the chunks to be generated around this spider area. The ones beyond the spider center will be important if the spider is attacked as we want bases to be there so the spider can call biters from them. Do a series of chunk requests to covered approximately 600 tiles west of the spider's raoming area as this is roughly how far it can call for reinforcements from.
        -- Only done if the spider exists so that we don't generate chunks with very low evo unnecessarily early.
        local laneChunksHeight = math.ceil((global.general.perTeamMapHeight / 32) / 2) -- may be 1 chunk further out than the lane in some map width sizes.
        global.general.surface.request_to_generate_chunks({x = spider.roamingXMin, y = spider.playerTeam.spawnPosition.y}, laneChunksHeight)
        global.general.surface.request_to_generate_chunks({x = spider.roamingXMin - 180, y = spider.playerTeam.spawnPosition.y}, laneChunksHeight)
        global.general.surface.request_to_generate_chunks({x = spider.roamingXMin - 360, y = spider.playerTeam.spawnPosition.y}, laneChunksHeight)
    end
end

--- Called when only a boss spider named entity type has been damaged.
---@param event on_entity_damaged
Spider.OnBossSpiderEntityDamaged = function(event)
    local spider = global.spider.spiderUnitNumberToSpider[event.entity.unit_number]
    if spider == nil then
        -- Either spider doesn't exist yet or a testing spider entity (non monitored).
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

        -- If the target position is within the allowed fighting area then react to it, otherwise it is ignored.
        if Spider.IsFightingTargetPositionWithinAllowedFightingArea(spider, lastDamagedFromPosition) then
            local spidersCurrentPosition = spider.bossEntity.position

            -- Work out what to record this valid attacker as on the spiders target list.
            if spider.chasingEntityLastPosition == nil then
                -- Spider wasn't already chasing anything, so start now.
                spider.chasingPlayer = Spider.GetEntitiesControllingPlayer(event.cause)
                spider.chasingEntity = event.cause
                spider.chasingEntityLastPosition = lastDamagedFromPosition

                Spider.CallNearbyBitersForHelp(spider, event.tick, event.force, spidersCurrentPosition)
            else
                -- Spider was already chasing something, so just record the damage originator for the short term fighting.
                spider.lastDamagedByPlayer = Spider.GetEntitiesControllingPlayer(event.cause)
                spider.lastDamagedByEntity = event.cause
                spider.lastDamagedFromPosition = lastDamagedFromPosition
            end
            Spider.ChargeAtAttacker(spider, spidersCurrentPosition, event.tick)

            return
        end
    end

    -- If theres no cause then theres no reaction we can take to this. So just leave the spider to continue whatever it was doing before.
end

--- Checks both spider's states and activity over the last second.
---@param event UtilityScheduledEvent_CallbackObject
Spider.CheckSpiders_Scheduled = function(event)
    local updateScoreGuis = false

    for _, spider in pairs(global.spider.spiders) do
        -- If spider doesn't exist or is dead then nothing to be done for it.
        if spider.state ~= BossSpider_State.notCreatedYet and spider.state ~= BossSpider_State.dead then
            -- Log the damage taken this second.
            local thisSecond = event.tick / 60
            if spider.damageTakenThisSecond > 0 then
                -- Only record the second if damage was done. Keeps the table smaller.
                spider.secondsWhenDamaged[thisSecond] = spider.damageTakenThisSecond

                -- Only update the score GUIs with the spiders health if its taken damage.
                updateScoreGuis = true
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

            local spidersCurrentPosition = spider.bossEntity.position

            -- Check for anything within nuke range right now and shoot if approperaite. This won't change spider's behavour under any situation. As any target found will either be outside of regular enaggement range, or regular engagement range checks will detect and handle the wider variety of dangers within each behaviour appropriately.
            Spider.HandleNukeTargets(spider, event.tick, spidersCurrentPosition)

            -- Handle continuation of standard behaviours.
            if spider.state == BossSpider_State.roaming then
                Spider.CheckRoamingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.retreating then
                Spider.CheckRetreatingForSecond(spider, spidersCurrentPosition)
            elseif spider.state == BossSpider_State.chasing then
                Spider.CheckChasingForSecond(spider, spidersCurrentPosition, event.tick)
            elseif spider.state == BossSpider_State.fighting then
                Spider.ManageFightingForSecond(spider, spidersCurrentPosition, event.tick)
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

    -- Refresh the Score GUI if a spider has been damaged in the last second or every minute.
    if updateScoreGuis or event.tick % 3600 == 0 then
        Spider.UpdateAllScoreGuis()
    end

    -- Schedule the next seconds event. As the first instance of this schedule always occurs exactly on a second no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEventOnce(event.tick + 60, "Spider.CheckSpiders_Scheduled")
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

        if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider.roamingTargetPosition) then
            -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
            return
        end

        Spider.OrderSpiderToStartMovingToPosition(spider, spider.roamingTargetPosition)
    else
        -- Moving to the target at present.

        if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider.roamingTargetPosition) then
            -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
            return
        end

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
---@param currentTick Tick
Spider.CheckChasingForSecond = function(spider, spidersCurrentPosition, currentTick)
    Spider.UpdateTargetsDetails(spider, "chasing")

    -- Handle if the target is gone.
    if spider.chasingEntityLastPosition == nil then
        -- Chasing target is gone.
        -- As the spider hasn't already been attacked then go in to fighting mode. This will handle working out what to do next.
        Spider.StartFighting(spider, spidersCurrentPosition, currentTick)
        return
    end

    -- Check if the spider has got close enough to its target.
    if Utils.GetDistance(spidersCurrentPosition, spider.chasingEntityLastPosition) < 10 then
        -- Spider is very close to where it's going. Set up next action rather than waiting for it to have stopped for a full second.
        Spider.StartFighting(spider, spidersCurrentPosition, currentTick)
    else
        -- Spider is still moving towards its existing target location.

        if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider.chasingEntityLastPosition) then
            -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
            return
        end

        -- A spider can't "follow" another entity, it can only have its destination updated to the entities current position. This is how vanilla Factorio works.
        Spider.OrderSpiderToStartMovingToPosition(spider, spider.chasingEntityLastPosition)
    end
end

--- Manages the spiders fighting for this second. Will react to taking damage, having things to fight or looking for near by things to attack. As a last resort it will return home.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
---@param currentTick Tick
Spider.ManageFightingForSecond = function(spider, spidersCurrentPosition, currentTick)
    -- The spider will "dance" to keep engaging targets with its longer range weapons until its killed the real target or retreats. It will be a bit crude as otherwise it needs far more active managemnt.

    -- Generic values that may be cached within the function.
    ---@typelist LuaEntity
    local nearestEnemyWithinRange = nil

    -- Initial reactions based on of the spider is taking damage at present.
    if spider.damageTakenThisSecond == 0 then
        -- The spider isn't taking damage so try to move towards the target.

        -- Ensure the short term target data is valid and remove it if not.
        Spider.UpdateTargetsDetails(spider, "lastDamaged")

        -- Initial handling logic based on if a short term target exists.
        if spider.lastDamagedByEntity == nil then
            -- No short term target exists.

            -- Check if there is anything to fight at the current location within weapons range. As we aren't being damaged so may as well kill anything we can before doing any longer term actions which may expose us to damage.
            nearestEnemyWithinRange = nearestEnemyWithinRange or global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = Settings.spiderEngagementRange, force = spider.playerTeam.enemyForce} or "none" -- The find_nearest_enemy() returns nil if nothing found, but that won't be cached correctly, so use "none" as value of last resort.
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
            Spider.FightTargetTypeWhileNotBeingDamaged(spider, spidersCurrentPosition, "lastDamaged", currentTick)
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
            -- There is a long term target so handle it.
            Spider.FightTargetTypeWhileNotBeingDamaged(spider, spidersCurrentPosition, "chasing", currentTick)
            return
        end
    else
        -- The spider is taking damage, so will stay in a fighting state for now. Just need to decide how to maneuver in reaction to being damaged.
        -- As we are taking damage we aren't worried about pursuing any target initially.

        -- Check if an enemy is within current weapons range.
        nearestEnemyWithinRange = nearestEnemyWithinRange or global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = Settings.spiderEngagementRange, force = spider.playerTeam.enemyForce} or "none" -- The find_nearest_enemy() returns nil if nothing found, but that won't be cached correctly, so use "none" as value of last resort.

        -- Advance only if we are currently out of weapon range. We don't want to close in otherwise.
        if nearestEnemyWithinRange ~= "none" then
            -- An enemy already within weapon range.

            -- Check how far away the target is and react based on this. We want to stay as far away from them while remaining within weapons range to return fire on them.
            local nearestEnemyWithinRangePosition = nearestEnemyWithinRange.position
            local distanceToTarget = Utils.GetDistance(spidersCurrentPosition, nearestEnemyWithinRangePosition)
            if distanceToTarget + Settings.spidersFightingStepDistance < Settings.spiderEngagementRange then
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
                if distanceToTarget <= Settings.spiderEngagementRange + Settings.distanceSpiderMovesinSecond then
                    -- Target near by so just advance a bit towards it.
                    Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.lastDamagedFromPosition, spidersCurrentPosition))
                    return
                else
                    -- Target far away and within the fightinwg area, so resume the chase on it. This will run away from whatever is shooting at us at present until we next take damage and then the chase will be broken.
                    Spider.ChargeAtAttacker(spider, spidersCurrentPosition, currentTick)
                    return
                end
            else
                -- No valid target within fighting area.
                -- So do fallback behaviour.
            end
        end
    end

    -- As spider can't pursue the short term target look for anything near by to attack first, otherwise return to chasing the origional target if there was one, or return to roaming. Means the spider will attack down a line of defences, etc, before returning to a longer term behaviour.

    -- Look for nearest target nearby and set them as the new target entity.
    local nearbyEnemy = global.general.surface.find_nearest_enemy {position = spidersCurrentPosition, max_distance = Settings.distanceToCheckForEnemiesNearby, force = spider.playerTeam.enemyForce}

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
            if distanceToTarget <= Settings.spiderEngagementRange + Settings.distanceSpiderMovesinSecond then
                -- Target near by so just advance a bit.

                if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider.lastDamagedFromPosition) then
                    -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
                    return
                end

                Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.lastDamagedFromPosition, spidersCurrentPosition))
                return
            else
                -- Target far away, so start chasing it.
                Spider.ChargeAtAttacker(spider, spidersCurrentPosition, currentTick)
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
        if distanceToTarget <= Settings.spiderEngagementRange + Settings.distanceSpiderMovesinSecond then
            -- Target near by so just advance a bit.

            if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider.chasingEntityLastPosition) then
                -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
                return
            end

            Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider.chasingEntityLastPosition, spidersCurrentPosition))
            return
        else
            -- Target far away, so start chasing it.
            Spider.ChargeAtAttacker(spider, spidersCurrentPosition, currentTick)
            return
        end
    end

    -- Fallback behaviour is to go home.
    if Settings.showSpiderPlans then
        rendering.draw_text {text = "going home as last resort", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
    end
    Spider.StartRoaming(spider, spidersCurrentPosition)
end

-- Fire a nuke at a suitable target if nuke cooldown allows and theres anything worth nuking nearby. Doesn't prioritise nearest targets by design.
---@param spider JdSpiderRace_BossSpider
---@param currentTick Tick
---@param spidersCurrentPosition MapPosition
Spider.HandleNukeTargets = function(spider, currentTick, spidersCurrentPosition)
    -- CODE NOTE: Nuke ammo has x1.5 range of regular rockets in Factorio. So rocket launchers 36 range becomes 54 for atomic rockets.

    if spider.nukeAmmo > 0 and currentTick >= spider.lastFiredNukeTick + Settings.spiderNukeMaxFrequency then
        -- Check for any high priority singular target first, then try looking for any groups of turrets.
        local nukeTarget
        local singularTargetEntities = global.general.surface.find_entities_filtered {position = spidersCurrentPosition, radius = 54, force = spider.playerTeam.playerForce, type = {"character", "spider-vehicle"}}
        if #singularTargetEntities > 0 then
            -- Nuke a random priority target.
            nukeTarget = singularTargetEntities[math.random(1, #singularTargetEntities)]
        else
            -- As no singular target found look for a clump of turrets togeather.
            -- Get all the turrets nearby.
            local turretsNearby = global.general.surface.find_entities_filtered {position = spidersCurrentPosition, radius = 54, force = spider.playerTeam.playerForce, type = {"turret", "ammo-turret", "electric-turret", "fluid-turret"}}

            -- Check up to 3 of the turrets found to see if any are part of a clump.
            if #turretsNearby > 0 then
                for _ = 1, 3 do
                    local targetTurret_index = math.random(1, #turretsNearby)
                    local targetTurret = turretsNearby[targetTurret_index]

                    -- See how many other turrets are within the high damage from a nuke explosion of the target turret.
                    local targetTurretsNeighbousCount = global.general.surface.count_entities_filtered {position = targetTurret.position, radius = 30, force = spider.playerTeam.playerForce, type = {"turret", "ammo-turret", "electric-turret", "fluid-turret"}}
                    if targetTurretsNeighbousCount > 30 then
                        -- This is a clump of turrets so nuke them.
                        nukeTarget = targetTurret
                        break
                    else
                        -- Not enough turrets so don't nuke them.
                        table.remove(turretsNearby, targetTurret_index)
                        if #turretsNearby == 0 then
                            break
                        end
                    end
                end
            end
        end

        if nukeTarget ~= nil then
            global.general.surface.create_entity {name = "atomic-rocket", position = spidersCurrentPosition, force = spider.playerTeam.enemyForce, target = nukeTarget, source = spider.bossEntity, speed = 0.05, max_range = 54}
            spider.nukeAmmo = spider.nukeAmmo - 1
            spider.lastFiredNukeTick = currentTick
        end
    end
end

--- Handle how to fight against a specific target type which is always currently valid.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
---@param chasingOrLastDamaged '"chasing"'|'"lastDamaged"'
---@param currentTick Tick
---@return boolean completed
---@return LuaEntity|'"none"' nearestEnemyWithinRange
Spider.FightTargetTypeWhileNotBeingDamaged = function(spider, spidersCurrentPosition, chasingOrLastDamaged, currentTick)
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
    if distanceToTarget <= Settings.spiderEngagementRange + Settings.distanceSpiderMovesinSecond then
        -- Target near by so just advance a bit.

        -- Make sure we don;t walk in to range of other things whne chasing our target.
        if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, spider[positionRefName]) then
            -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
            return
        end

        Spider.OrderSpiderToStartMovingToPosition(spider, Spider.GetNewPositionForAdvancingOnTarget(spider, spider[positionRefName], spidersCurrentPosition))
        return
    else
        -- Target far away so start chase it as we aren't taking damage.
        Spider.ChargeAtAttacker(spider, spidersCurrentPosition, currentTick)
        return
    end
end

--- Check a chased/lastDamaged target is still valid. If chasing a player it updates the target entity. Always updates target position. If the entity isn't valid or has left the fighting area it blanks out all target data. To make the chasing ad fighting logic simplier.
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

    Spider.UpdateSpiderDistanceFromSpawn(spider, Settings.spiderDistanceToRetreat)
    game.print({"message.jd_plays-jd_spider_race-spider_retreated", spider.playerTeam.prettyName}, Colors.lightgreen)

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
---@param currentTick Tick
Spider.ChargeAtAttacker = function(spider, spidersCurrentPosition, currentTick)
    Spider.ClearNonFightingStateVariables(spider)

    -- Prioritise charging at the more recent damage causer.
    local currentTargetPosition
    if spider.lastDamagedFromPosition ~= nil then
        currentTargetPosition = spider.lastDamagedFromPosition
    else
        currentTargetPosition = spider.chasingEntityLastPosition
    end

    if Utils.GetDistance(spidersCurrentPosition, currentTargetPosition) <= Settings.spiderEngagementRange then
        -- Attacker is close enough to start fighting already.
        Spider.StartFighting(spider, spidersCurrentPosition, currentTick)
    else
        -- Spider will start moving to the position the last attacking enemy was at.

        if Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget(spider, spidersCurrentPosition, currentTargetPosition) then
            -- Spider has stopped short of the target position and is in the fighting state now ready for the next second cycle to handle future actions.
            return
        end

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
---@param currentTick Tick
Spider.StartFighting = function(spider, spidersCurrentPosition, currentTick)
    spider.state = BossSpider_State.fighting
    Spider.ManageFightingForSecond(spider, spidersCurrentPosition, currentTick)
    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end
end

--- Check if there is anything the spider needs to fight for where it will be in 1 seconds time while heading towards its target. This is to avoid it chasing straight in to the middle of static defences before they wake up and start shooting the spider.
--- If something is found the spider will be ordered to stop at the correct range from this enemy and enter the fighting state for the remainder of this second. Then next second cycle the fighting state will manage its future actions.
---@param spider JdSpiderRace_BossSpider
---@param spidersCurrentPosition MapPosition
---@param targetPosition MapPosition
---@return boolean targetFound
Spider.CheckIfWillEncounterEnemiesWhileMovingTowardsTarget = function(spider, spidersCurrentPosition, targetPosition)
    local approximateSpiderPositionIn1Second = Utils.GetPositionForDistanceBetween2Points(spidersCurrentPosition, targetPosition, Settings.distanceSpiderMovesinSecond)
    local nearestEnemyIn1Second = global.general.surface.find_nearest_enemy {position = approximateSpiderPositionIn1Second, max_distance = Settings.spiderEngagementRange, force = spider.playerTeam.enemyForce}

    if nearestEnemyIn1Second ~= nil then
        -- Will be within range of an enemy in 1 second.

        -- Order the spider to move to just within weapons range of the target and set the state for fighting so that the next 1 second cycle it will start fighting from the correct position. Don't enter fighting now as nothing will be in range until it's done this extra movement (distance up to the spiders movement per second).
        -- Note that a spider has to slow down and so will likely overshoot the distance a bit.
        local positionToStopAt = Utils.GetPositionForDistanceBetween2Points(nearestEnemyIn1Second.position, spidersCurrentPosition, Settings.spiderEngagementRange) -- Aim to stop a few tiles short of the target as this movement tends to overshoot the most. The fightng will shuffle it forwards a tad if needed.
        Spider.ClearNonFightingStateVariables(spider)
        Spider.OrderSpiderToStartMovingToPosition(spider, positionToStopAt)
        spider.state = BossSpider_State.fighting
        if Settings.showSpiderPlans then
            rendering.draw_text {text = "stopping charge before walking in to enemy", surface = global.general.surface, target = spider.bossEntity, color = Colors.white, scale_with_zoom = true, time_to_live = 60, vertical_alignment = "baseline"} -- Vertial alignment so it doesn't overlap the state text.
            Spider.UpdatePlanRenders(spider, positionToStopAt)
        end
        return true
    else
        -- Nothing in range where the spider will be in 1 seconds time.
        return false
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
        -- Is a vehicle of some type.
        local driverCharacter = entity.get_driver()
        if driverCharacter ~= nil then
            if driverCharacter.is_player() then
                return driverCharacter -- Editor mode.
            else
                return driverCharacter.player
            end
        else
            local passengerCharacter = entity.get_passenger()
            if passengerCharacter ~= nil then
                if passengerCharacter.is_player() then
                    return passengerCharacter -- Editor mode.
                else
                    return passengerCharacter.player
                end
            else
                return nil
            end
        end
    else
        -- Is anything else.
        return nil
    end
end

--- Send all the biters in a very large area towards the players spawn direction. Is only activated periodically with more frequent requests being ignored.
--- Currently only being called when a new main target is defined.
---@param spider JdSpiderRace_BossSpider
---@param currentTick Tick
---@param attackingForce LuaForce
---@param spidersCurrentPosition MapPosition
Spider.CallNearbyBitersForHelp = function(spider, currentTick, attackingForce, spidersCurrentPosition)
    if currentTick > spider.lastSentBitersToAttackTick + Settings.bitersSentToRetaliateMaxFrequency then
        -- Send all the biters in a very large area 1,000 tiles east of the spider.
        -- CODE NOTES:
        --    - Creates a number of medium sized groups. Configured for use with biter attracter entity call_for_help_radius of 200. Also the chunk generation west of spider is set aroud these values.
        --    - Does 1,000 tiles as targetting spawn from far west (i.e. 10k+) caused considerable pathing delay. So the 1,000 tiles should be enough to hit any players or infrastrcuture nearish to the spider. This is a bit adhoc compared to manually controlling the biters, but that needs a lot more active management.
        ---@typelist MapPosition, LuaEntity
        local position, summoningWorm
        local rowsStart
        local mapHeightPlacementUnits = math.floor(global.general.perTeamMapHeight / 250) * 250
        if spider.playerTeam.spawnPosition.y < 0 then
            rowsStart = -mapHeightPlacementUnits + 125
        else
            rowsStart = 125
        end
        -- Do as a series of biter attracters so that they don't try and form mega groups as these tend to get bogged down and delay the groups arrival.
        for rows = rowsStart, rowsStart + mapHeightPlacementUnits - 250, 250 do
            local biterTargetEntity = global.general.surface.create_entity {name = "gun-turret", position = {x = spidersCurrentPosition.x + 1000, y = rows}, force = spider.playerTeam.playerForce}
            for columns = -500, 500, 250 do
                position = {x = spidersCurrentPosition.x + columns, y = rows}
                summoningWorm = global.general.surface.create_entity {name = "jd_plays-jd_spider_race-biter_attracter_turret", position = position, force = spider.playerTeam.enemyForce}
                summoningWorm.damage(100000000, attackingForce, "impact", biterTargetEntity)
                --rendering.draw_circle {color = Colors.green, filled = true, draw_on_ground = true, radius = 200, surface = global.general.surface, target = position}
            end
            biterTargetEntity.destroy()
        end

        -- Record each time this is used, for calculating the next time it can be used.
        spider.lastSentBitersToAttackTick = currentTick
    end
end

--- Clear all variables related to a spider's state.
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
--- White lines for standard movement, red lines for chasing specific target, yellow lines for short movements (within same second).
---@param spider JdSpiderRace_BossSpider
---@param shortTermSpiderTargetPosition? MapPosition @ The very short term position the spider is moving too. This isn't recorded in its state, i.e. position to stop at this second before walking in to enemies.
Spider.UpdatePlanRenders = function(spider, shortTermSpiderTargetPosition)
    -- Just remove all the old renders.
    for _, renderId in pairs(spider.spiderPlanRenderIds) do
        rendering.destroy(renderId)
    end
    spider.spiderPlanRenderIds = {}

    -- If there is a very short terms movement target draw this in yellow line for just 1 second. This isn't correctly stateful across spider behavour changes and so just lasts 1 second in all cases.
    if shortTermSpiderTargetPosition ~= nil then
        rendering.draw_line {color = Colors.yellow, width = 2, from = spider.bossEntity, to = shortTermSpiderTargetPosition, surface = global.general.surface, time_to_live = 60}
    end

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
    if playerTeamName ~= "both" and global.playerHome.teams[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    local distanceChange = args[2] ---@type number
    if type(distanceChange) ~= "number" then
        game.print(commandErrorMessagePrefix .. "Second argument of distance to change by must be a number, recieved: " .. tostring(distanceChange), Colors.lightred)
        return
    end
    distanceChange = math_ceil(distanceChange) -- Must be in whole tiles, so round it.

    -- Impliment command as any errors would have bene flagged by now.
    local messageLocalisedString
    if distanceChange > 0 then
        messageLocalisedString = {"message.jd_plays-jd_spider_race-spider_moved_away_from_spawn", Utils.DisplayNumberPretty(distanceChange)}
    else
        messageLocalisedString = {"message.jd_plays-jd_spider_race-spider_moved_towards_spawn", Utils.DisplayNumberPretty(-distanceChange)}
    end
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            Spider.UpdateSpiderDistanceFromSpawn(spider, distanceChange)
            Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, messageLocalisedString)
        end
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        Spider.UpdateSpiderDistanceFromSpawn(spider, distanceChange)
        Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, messageLocalisedString)
    end

    -- Do one scoreboard update for all spiders.
    Spider.UpdateAllScoreGuis()
end

--- Update the spiders distance from spawn for a change amount and do the follow up tasks.
---@param spider JdSpiderRace_BossSpider
---@param distanceChange double
Spider.UpdateSpiderDistanceFromSpawn = function(spider, distanceChange)
    -- If the change was negative and the spider entity doesn't exist yet, check if the reduced spider's distance means we should now create the entities. As the players last built and generated chunk is now much closer than before.
    -- Do this before we update the spiders distance so we create the spider at the old distance and then let it roam back towards its new roaming area. This behaviour will match if it had already existed when the distance was moved backwards.
    if distanceChange < 0 and spider.state == BossSpider_State.notCreatedYet then
        -- We need to check if the spider should be made now.
        local makeSpiderEntities = false

        -- CODE NOTE: Use the bottom right tile within the chunk as the on_chunk_generated event does (hence +1 to stored chunk number.)
        -- CODE NOTE: distance is subtracted as its a negative number, but we want to add it to the XPosition.
        if (spider.leftMostXChunkPositionGeneratedByTeamAwayFromDivide + 1) * 32 <= spider.roamingXMax - distanceChange then
            -- Left most chunk is within the spiders roaming area.
            makeSpiderEntities = true
        elseif (spider.roamingXMax - distanceChange) + Settings.spiderArtilleryWeaponRange >= spider.playerTeam.mostLeftBuiltEntityXPosition then
            -- Left most built entity is within the artillery's weapon range.
            makeSpiderEntities = true
        end

        if makeSpiderEntities then
            Spider.CreateSpiderEntities(spider)
        end
    end

    spider.distanceFromSpawn = spider.distanceFromSpawn + distanceChange
    Spider.UpdateSpidersRoamingValues(spider)
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
    if distance < 0 then
        game.print(commandErrorMessagePrefix .. "First argument of distance must be a positive number, recieved: " .. tostring(distance), Colors.lightred)
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
        Spider.UpdateSpiderDistanceFromSpawn(spider, global.spider.constantMovementFromSpawnPerMinute)
    end

    -- Schedule the next Minutes event. As the first instance of this schedule always occurs exactly on a minute no fancy logic is needed for each reschedule.
    EventScheduler.ScheduleEventOnce(event.tick + 3600, "Spider.SpidersMoveAwayFromSpawn_Scheduled")
end

--- Gives the boss spider and its gun spiders 1 set of ammo.
---@param spider JdSpiderRace_BossSpider
Spider.GiveSpiderFullAmmo = function(spider)
    if spider.state == BossSpider_State.dead then
        return
    end

    -- If the spider entity doesn't exist yet just add the ammo to the spider object for when it is created, otherwise arm the spider now.
    if spider.state == BossSpider_State.notCreatedYet then
        spider.spiderFullyArmCountForCreationTime = spider.spiderFullyArmCountForCreationTime + 1
        return
    end

    -- Arm the boss spider.
    for _, ammo in pairs(BossSpider_Rearm) do
        if ammo.name == "atomic-bomb" then
            -- Atomic bombs are just stored virtually as fired via script.
            spider.nukeAmmo = spider.nukeAmmo + ammo.count
        else
            -- All real weapon ammos.
            spider.bossEntity.insert(ammo)
        end
    end

    -- Arm each of the gun spiders.
    for bossSpiderGunType, ammoItems in pairs(BossSpider_GunSpiderRearm) do
        for _, ammo in pairs(ammoItems) do
            spider.gunSpiders[bossSpiderGunType].entity.insert(ammo)
        end
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
Spider.Command_FullyRearmSpider = function(commandEvent)
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
    if playerTeamName ~= "both" and global.playerHome.teams[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            Spider.GiveSpiderFullAmmo(spider)
            Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, {"message.jd_plays-jd_spider_race-spider_fully_rearmed"})
        end
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        Spider.GiveSpiderFullAmmo(spider)
        Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, {"message.jd_plays-jd_spider_race-spider_fully_rearmed"})
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
    if playerTeamName ~= "both" and global.playerHome.teams[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'First argument of player team name was invalid, either "north", "south" or "both". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    local ammoName_raw = args[2] ---@type string
    local ammoFriendlyName = BossSpider_RconAmmoNames[ammoName_raw]
    if ammoFriendlyName == nil then
        game.print(commandErrorMessagePrefix .. "Second argument of ammoName must be one of the specific ammo types, recieved: " .. tostring(ammoName_raw) .. ". Options: piercingBullet, uraniumBullet, explosiveRocket, atomicRocket, explosiveCannonShell, uraniumCannonShell, explosiveUraniumCannonShell, artilleryShell", Colors.lightred)
        return
    end
    local rconAmmoType = BossSpider_RconAmmoTypes[ammoFriendlyName]

    local quantity = args[3] ---@type number
    if type(quantity) ~= "number" then
        game.print(commandErrorMessagePrefix .. "Third argument of quantity must be a number, recieved: " .. tostring(quantity), Colors.lightred)
        return
    end
    quantity = math_floor(quantity)

    if quantity <= 0 then
        game.print(commandErrorMessagePrefix .. "Quantity of 0 or less is ignored, recieved after rounding down: " .. tostring(quantity), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have bene flagged by now.
    if playerTeamName == "both" then
        -- Update both team's spiders.
        for _, spider in pairs(global.spider.spiders) do
            Spider.GiveSpiderSpecificAmmo(spider, ammoFriendlyName, rconAmmoType, quantity)
            Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, {"message.jd_plays-jd_spider_race-spider_give_ammo", quantity, rconAmmoType.ammoItemPrettyName})
        end
    else
        -- Just update the 1 team's spider.
        local spider = global.spider.playerTeamsSpider[playerTeamName]
        Spider.GiveSpiderSpecificAmmo(spider, ammoFriendlyName, rconAmmoType, quantity)
        Spider.ShowMessageToEnabledTeamPlayers(spider.playerTeam, {"message.jd_plays-jd_spider_race-spider_give_ammo", quantity, rconAmmoType.ammoItemPrettyName})
    end
end

--- Gives a spider a specific ammo type and count. Works out which entity to put the ammo in.
---@param spider JdSpiderRace_BossSpider
---@param ammoFriendlyName JdSpiderRace_BossSpider_RconAmmoName
---@param rconAmmoType JdSpiderRace_BossSpider_RconAmmoType
---@param quantity uint
Spider.GiveSpiderSpecificAmmo = function(spider, ammoFriendlyName, rconAmmoType, quantity)
    if spider.state == BossSpider_State.dead then
        return
    end

    -- If the spider entity doesn't exist yet just add the ammo to the spider object for when it is created, otherwise arm the spider now.
    if spider.state == BossSpider_State.notCreatedYet then
        spider.ammoForCreationTime[ammoFriendlyName] = (spider.ammoForCreationTime[ammoFriendlyName] or 0) + quantity
        return
    end

    if rconAmmoType.bossSpider then
        if rconAmmoType.ammoItemName == "atomic-bomb" then
            -- Atomic bombs are just stored virtually as fired via script.
            spider.nukeAmmo = spider.nukeAmmo + quantity
        else
            -- All real weapon ammos.
            spider.bossEntity.insert({name = rconAmmoType.ammoItemName, count = quantity})
        end
    elseif rconAmmoType.gunType then
        spider.gunSpiders[rconAmmoType.gunType].entity.insert({name = rconAmmoType.ammoItemName, count = quantity})
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

    local spider = global.spider.spiderUnitNumberToSpider[event.entity.unit_number]
    if spider == nil then
        -- Either spider doesn't exist yet or a testing spider entity (non monitored).
        return
    end

    -- Record spiders new state as this will stop other processing ocurring in future.
    spider.state = BossSpider_State.dead

    -- Remove all the hidden entities related to the spider as many of these will attack on their own.
    for _, gunSpiderDetails in pairs(spider.gunSpiders) do
        gunSpiderDetails.entity.destroy()
    end
    for _, turretDetails in pairs(spider.turrets) do
        turretDetails.entity.destroy()
    end

    if Settings.showSpiderPlans then
        Spider.UpdatePlanRenders(spider)
    end

    -- Coin is dropped as loot automatically.

    -- Announce the death in chat and update the Score GUI.
    game.print({"message.jd_plays-jd_spider_race-spider_killed", spider.playerTeam.prettyName}, Colors.lightgreen)
    Spider.UpdateAllScoreGuis()
end

--- When the spider_reset_state command is called. Resets it's state variables and teleports it home to try and fix any odd state it may have got into.
--- This is an inheritently risky command and "should" work.
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
    if global.playerHome.teams[playerTeamName] == nil then
        game.print(commandErrorMessagePrefix .. 'Argument of player team name was invalid, either "north" or "south". Recieved: ' .. tostring(playerTeamName), Colors.lightred)
        return
    end

    -- Impliment command as any errors would have been flagged by now.
    local spider = global.spider.playerTeamsSpider[playerTeamName]

    -- Clear the variables back to defaults.
    Spider.ClearStateVariables(spider)
    spider.damageTakenThisSecond = 0
    spider.previousDamageToConsider = 0
    spider.secondsWhenDamaged = {}

    -- Handle spider entities if they exist.
    if spider.state ~= BossSpider_State.notCreatedYet and spider.state ~= BossSpider_State.dead then
        -- Teleport the spider home.
        local teleportPosition = {
            x = ((spider.roamingXMax - spider.roamingXMin) / 2) + spider.roamingXMin,
            y = ((spider.roamingYMax - spider.roamingYMin) / 2) + spider.roamingYMin
        }
        spider.bossEntity.teleport(teleportPosition)
        for _, gunSpider in pairs(spider.gunSpiders) do
            gunSpider.entity.teleport(teleportPosition)
        end

        -- Return the spider to roaming.
        Spider.StartRoaming(spider, teleportPosition)
    end
end

--- Called for each new player who joins the server.
---@param event on_player_created
Spider.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    -- Set Mesasge GUI to be enabled by default.
    global.spider.playersMessageGuiEnabled[event.player_index] = player
    player.set_shortcut_toggled("jd_plays-jd_spider_race-message-gui_button", true)

    -- Set Score GUI to be enabled by default.
    global.spider.playersScoreGuiEnabled[event.player_index] = player
    player.set_shortcut_toggled("jd_plays-jd_spider_race-score-gui_button", true)
    Spider.Gui_ShowScoreGuiForPlayer(player, event.player_index)

    player.print({"message.jd_plays-jd_spider_race-spider_welcome_1"}, Colors.lightgreen)
end

--- Called each time a player joins the game (goes connected).
---@param event on_player_joined_game
Spider.OnPlayerJoinedGame = function(event)
    -- If the player has the Score GUI open refresh it.
    local scoreEnabledPlayer = global.spider.playersScoreGuiEnabled[event.player_index]
    if scoreEnabledPlayer ~= nil then
        Spider.UpdatePlayersScoreGui(event.player_index, scoreEnabledPlayer, Spider.GetScoreGuiData())
    end
end

--- Called when a shortcut is used by a player. Check if it was a shortcut we are monitoring.
---@param event on_lua_shortcut
Spider.OnLuaShortcut = function(event)
    local shortcutName = event.prototype_name
    if shortcutName == "jd_plays-jd_spider_race-score-gui_button" then
        local enabledPlayer = global.spider.playersScoreGuiEnabled[event.player_index]
        if enabledPlayer ~= nil then
            -- Already open, so close it.
            GuiUtil.DestroyPlayersReferenceStorage(event.player_index, "Score")
            global.spider.playersScoreGuiEnabled[event.player_index] = nil
            enabledPlayer.set_shortcut_toggled("jd_plays-jd_spider_race-score-gui_button", false)
        else
            -- Not open, so open it.
            local player = game.get_player(event.player_index)
            global.spider.playersScoreGuiEnabled[event.player_index] = player
            player.set_shortcut_toggled("jd_plays-jd_spider_race-score-gui_button", true)
            Spider.Gui_ShowScoreGuiForPlayer(player, event.player_index)
        end
    elseif shortcutName == "jd_plays-jd_spider_race-message-gui_button" then
        -- Just toggle the stored state for the player.
        local enabledPlayer = global.spider.playersMessageGuiEnabled[event.player_index]
        if enabledPlayer ~= nil then
            -- Already enabled, so turn it off.
            global.spider.playersMessageGuiEnabled[event.player_index] = nil
            enabledPlayer.set_shortcut_toggled("jd_plays-jd_spider_race-message-gui_button", false)
        else
            -- Not enabled, so turn it on.
            local player = game.get_player(event.player_index)
            global.spider.playersMessageGuiEnabled[event.player_index] = player
            player.set_shortcut_toggled("jd_plays-jd_spider_race-message-gui_button", true)
        end
    end
end

--- Open the Score GUI for the player. They must be on a team when this is done.
---@param player LuaPlayer
---@param playerIndex PlayerIndex
Spider.Gui_ShowScoreGuiForPlayer = function(player, playerIndex)
    -- Code notes:
    --      All caption and tooltip names must be manually defined and be prefixed with "[TYPE].jd_plays-jd_spider_race-" so the locale names don't conflict with other modes. As only the mod name is pulled through in to the auto generated names, not the mode name. i.e. {"gui-caption.jd_plays-jd_spider_race-score_test"}.
    GuiUtil.AddElement(
        {
            parent = player.gui.left,
            descriptiveName = "score_main",
            type = "frame",
            storeName = "Score",
            direction = "vertical",
            style = MuppetStyles.frame.main_shadowRisen.marginTL,
            styling = {width = 266}, -- Width of the starting GUI size so the inner frames can stretch to fill it without the entire GUI growing when other large GUIs are added to the left of screen.
            children = {
                {
                    -- Header title
                    type = "label",
                    style = MuppetStyles.label.heading.large.bold_paddingSides,
                    caption = {"gui-caption.jd_plays-jd_spider_race-score_title"}
                },
                {
                    -- North team container.
                    type = "frame",
                    direction = "vertical",
                    style = MuppetStyles.frame.content_shadowSunken.plain,
                    styling = {horizontally_stretchable = true},
                    children = {
                        {
                            -- North team title
                            type = "label",
                            style = MuppetStyles.label.heading.medium.semibold_paddingSides,
                            caption = global.playerHome.teams["north"].prettyName
                        },
                        {
                            -- North score details table.
                            type = "table",
                            direction = "vertical",
                            style = MuppetStyles.table.horizontalSpaced,
                            styling = {left_margin = 4, right_margin = 4},
                            column_count = 2,
                            children = {
                                {
                                    type = "label",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = {"gui-caption.jd_plays-jd_spider_race-score_distance_label"}
                                },
                                {
                                    descriptiveName = "score_north_distance",
                                    type = "label",
                                    storeName = "Score",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = nil,
                                    tooltip = nil
                                },
                                {
                                    type = "label",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_label"}
                                },
                                {
                                    descriptiveName = "score_north_spider_health",
                                    type = "label",
                                    storeName = "Score",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = nil
                                }
                            }
                        }
                    }
                },
                {
                    -- South team container.
                    type = "frame",
                    direction = "vertical",
                    style = MuppetStyles.frame.content_shadowSunken.plain,
                    styling = {horizontally_stretchable = true},
                    children = {
                        {
                            -- South team title
                            type = "label",
                            style = MuppetStyles.label.heading.medium.semibold_paddingSides,
                            caption = global.playerHome.teams["south"].prettyName
                        },
                        {
                            -- South score details table.
                            type = "table",
                            direction = "vertical",
                            style = MuppetStyles.table.horizontalSpaced,
                            styling = {left_margin = 4, right_margin = 4},
                            column_count = 2,
                            children = {
                                {
                                    type = "label",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = {"gui-caption.jd_plays-jd_spider_race-score_distance_label"},
                                    tooltip = {"gui-tooltip.jd_plays-jd_spider_race-score_distance_information"}
                                },
                                {
                                    descriptiveName = "score_south_distance",
                                    type = "label",
                                    storeName = "Score",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = nil,
                                    tooltip = {"gui-tooltip.jd_plays-jd_spider_race-score_distance_information"}
                                },
                                {
                                    type = "label",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_label"}
                                },
                                {
                                    descriptiveName = "score_south_spider_health",
                                    type = "label",
                                    storeName = "Score",
                                    style = MuppetStyles.label.text.medium.plain,
                                    caption = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    )

    Spider.UpdatePlayersScoreGui(playerIndex, player, Spider.GetScoreGuiData())
end

--- Called when one or both teams score values change and their score GUI needs to be updated for all players with it open.
--- Called in the below situations: distance increment RCON command, every second the spider has taken damage, every minute (via spider state check schedule) to catch gradual spider distance changes and built entities.
Spider.UpdateAllScoreGuis = function()
    local scoreGuiData = Spider.GetScoreGuiData()
    for playerIndex, player in pairs(global.spider.playersScoreGuiEnabled) do
        -- If the player is online then refresh their GUI. Just leave it as-is if they are offline. We will trigger an update when they rejoin.
        if player.connected then
            Spider.UpdatePlayersScoreGui(playerIndex, player, scoreGuiData)
        end
    end
end

--- Called to update a specific player's Score GUI.
---@param playerIndex PlayerIndex
---@param player LuaPlayer
---@param scoreGuiData JdSpiderRace_BossSpider_ScoreGuiData
Spider.UpdatePlayersScoreGui = function(playerIndex, player, scoreGuiData)
    -- Check the GUI is still there (valid) as we expect it to be.
    local scoreMainLuaElement = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, "Score", "score_main", "frame")
    if scoreMainLuaElement == nil or not scoreMainLuaElement.valid then
        -- GUI isn't present, so re-open it. This will also re-call this function to show the curernt players.
        Spider.Gui_ShowScoreGuiForPlayer(player, playerIndex)
        return
    end

    -- Update the north's values.
    GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_north_distance", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_distance_value", scoreGuiData.northSpiderDistancePercentage, scoreGuiData.northSpiderTargetDistance}, tooltip = {"gui-tooltip.jd_plays-jd_spider_race-score_distance_value", scoreGuiData.northSpiderClearedDistance, scoreGuiData.northSpiderTargetDistance}}, false)
    if scoreGuiData.northSpiderCurrentHealth ~= "0" then
        GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_north_spider_health", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_value", scoreGuiData.northSpiderHealthPercentage, scoreGuiData.northSpiderMaxHealth}}, false)
    else
        GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_north_spider_health", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_value_dead"}}, false)
    end

    -- Update the south's values.
    GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_south_distance", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_distance_value", scoreGuiData.southSpiderDistancePercentage, scoreGuiData.southSpiderTargetDistance}, tooltip = {"gui-tooltip.jd_plays-jd_spider_race-score_distance_value", scoreGuiData.southSpiderClearedDistance, scoreGuiData.southSpiderTargetDistance}}, false)
    if scoreGuiData.southSpiderCurrentHealth ~= "0" then
        GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_south_spider_health", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_value", scoreGuiData.southSpiderHealthPercentage, scoreGuiData.southSpiderMaxHealth}}, false)
    else
        GuiUtil.UpdateElementFromPlayersReferenceStorage(playerIndex, "Score", "score_south_spider_health", "label", {caption = {"gui-caption.jd_plays-jd_spider_race-score_spider_health_value_dead"}}, false)
    end
end

--- Gets the data needed for the Score GUI. Just call it once for all players having their GUI updated at once time to avoid excessive API calls.
---@return JdSpiderRace_BossSpider_ScoreGuiData
Spider.GetScoreGuiData = function()
    local spiderMaxHealth = game.entity_prototypes["jd_plays-jd_spider_race-spidertron_boss"].max_health
    local northSpiderObject, southSpiderObject = global.spider.playerTeamsSpider["north"], global.spider.playerTeamsSpider["south"]
    local northSpiderCurrentHealth, southSpiderCurrentHealth
    if northSpiderObject.state == BossSpider_State.notCreatedYet then
        northSpiderCurrentHealth = spiderMaxHealth
    elseif northSpiderObject.state == BossSpider_State.dead then
        northSpiderCurrentHealth = 0
    else
        northSpiderCurrentHealth = northSpiderObject.bossEntity.health
    end
    if southSpiderObject.state == BossSpider_State.notCreatedYet then
        southSpiderCurrentHealth = spiderMaxHealth
    elseif southSpiderObject.state == BossSpider_State.dead then
        southSpiderCurrentHealth = 0
    else
        southSpiderCurrentHealth = southSpiderObject.bossEntity.health
    end
    local northMostLeftBuiltEntityYDistance, southMostLeftBuiltEntityYDistance = 0 - math_floor(global.playerHome.teams["north"].mostLeftBuiltEntityXPosition - global.playerHome.spawnXOffset), 0 - math_floor(global.playerHome.teams["south"].mostLeftBuiltEntityXPosition - global.playerHome.spawnXOffset)

    ---@type JdSpiderRace_BossSpider_ScoreGuiData
    local scoreGuiData = {
        northSpiderCurrentHealth = Utils.DisplayNumberPretty(math_ceil(northSpiderCurrentHealth)),
        northSpiderMaxHealth = Utils.DisplayNumberPretty(spiderMaxHealth),
        northSpiderHealthPercentage = math_ceil((northSpiderCurrentHealth / spiderMaxHealth) * 100),
        southSpiderCurrentHealth = Utils.DisplayNumberPretty(math_ceil(southSpiderCurrentHealth)),
        southSpiderMaxHealth = Utils.DisplayNumberPretty(spiderMaxHealth),
        southSpiderHealthPercentage = math_ceil((southSpiderCurrentHealth / spiderMaxHealth) * 100),
        northSpiderTargetDistance = Utils.DisplayNumberPretty(northSpiderObject.distanceFromSpawn),
        northSpiderClearedDistance = Utils.DisplayNumberPretty(northMostLeftBuiltEntityYDistance),
        northSpiderDistancePercentage = math_ceil((northMostLeftBuiltEntityYDistance / northSpiderObject.distanceFromSpawn) * 100),
        southSpiderTargetDistance = Utils.DisplayNumberPretty(southSpiderObject.distanceFromSpawn),
        southSpiderClearedDistance = Utils.DisplayNumberPretty(southMostLeftBuiltEntityYDistance),
        southSpiderDistancePercentage = math_ceil((southMostLeftBuiltEntityYDistance / southSpiderObject.distanceFromSpawn) * 100)
    }
    return scoreGuiData
end

--- Shows a message GUI to the players on a team who have GUI Messages enabled.
---@param team JdSpiderRace_PlayerHome_Team
---@param message LocalisedString
Spider.ShowMessageToEnabledTeamPlayers = function(team, message)
    global.spider.messageGuiId = global.spider.messageGuiId + 1

    local playersMessageGuiElements = {}
    for playerIndex, player in pairs(team.players) do
        if global.spider.playersMessageGuiEnabled[playerIndex] ~= nil and player.connected then
            -- Player should be shown message.
            local guiElementsCreated =
                GuiUtil.AddElement(
                {
                    parent = player.gui.left,
                    descriptiveName = "message_" .. global.spider.messageGuiId,
                    type = "frame",
                    style = MuppetStyles.frame.content.marginTL,
                    returnElement = true,
                    children = {
                        {
                            type = "label",
                            style = MuppetStyles.label.text.medium.plain,
                            caption = message
                        }
                    }
                }
            )
            playersMessageGuiElements[playerIndex] = guiElementsCreated[next(guiElementsCreated)]
        end
    end

    EventScheduler.ScheduleEventOnce(game.tick + 600, "Spider.RemoveMessageFromPlayers_Scheduled", global.spider.messageGuiId, playersMessageGuiElements)
end

--- Scheduled to remove Message GUI from those players who were shown them.
---@param event UtilityScheduledEvent_CallbackObject
Spider.RemoveMessageFromPlayers_Scheduled = function(event)
    local playersMessageGuiElements = event.data ---@type table<PlayerIndex, LuaGuiElement>
    for _, guiElement in pairs(playersMessageGuiElements) do
        if guiElement.valid then
            guiElement.destroy()
        end
    end
end

return Spider
