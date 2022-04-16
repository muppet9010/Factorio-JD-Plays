--[[
    This code was developed independantly of other parts of the mod and so will as self contained as possible. With anything needed being hard coded in local variables at the top of the file.
]]
--

local Spider = {}
local Utils = require("utility.utils")

---@class BossSpider
---@field id uint @ The UnitNumber of the spider. Also the key in global.spiders.
---@field state BossSpider_State
---@field playerTeam LuaForce
---@field playerTeamName string
---@field biterTeam LuaForce
---@field bossEntity LuaEntity @ The main spider boss entity.
---@field distanceFromSpawn uint @ How far from spawn the spiders area is centered on (positive number).

---@class BossSpider_State
local BossSpider_State = {
    roaming = "roaming", -- Just idling wondering its area.
    fighting = "fighting", -- Not significantly moving, but actively being managed in a combat state.
    chasing = "chasing", -- Actively chasing after a military target.
    retreating = "retreating", -- Moving away from the threat.
    dead = "dead" -- Its dead.
}

local Surface  ---@type LuaSurface
local bossSpiderStartingLeftDistance = 5000
local bossSpiderStartingVerticalDistance = 256
local biterForceSuffixes = "_enemy"

local debugging = true
if debugging then
    bossSpiderStartingLeftDistance = 20
    bossSpiderStartingVerticalDistance = 10
end

local playerForceDetails = {
    {
        name = "north",
        spiderStartingYPosition = -bossSpiderStartingVerticalDistance,
        spiderColor = {255, 10, 10, 128} -- A light red color.
    },
    {
        name = "south",
        spiderStartingYPosition = bossSpiderStartingVerticalDistance,
        spiderColor = {0, 100, 255, 128} -- A light blue color.
    }
}

Spider.CreateGlobals = function()
    global.spider = global.spider or {}
    global.spider.spiders = global.spider.spiders or {} ---@type table<uint, BossSpider> @ Key'd by spiders UnitNumber
    global.spider.playerTeamsSpider = global.spider.playerTeamsSpider or {} ---@type table<string, BossSpider> @ The player team to the spider they are fighting.
end

Spider.OnLoad = function()
end

Spider.OnStartup = function()
    -- Set the cached surface reference.
    Surface = game.surfaces[1] -- TODO: this may need updating to the one we use with the map generation settings when merged in to the main code.

    -- Create the spiders for each team if they don't exist. They can be created in chunks that don't exist as they have a radar and thus will generate the chunks around them.
    if #global.spider.spiders == 0 then
        -- Set the color alphas to half as otherwise they become very dark.
        Spider.CreateSpider(playerForceDetails[1].name, playerForceDetails[1].spiderStartingYPosition, playerForceDetails[1].spiderColor)
        Spider.CreateSpider(playerForceDetails[2].name, playerForceDetails[2].spiderStartingYPosition, playerForceDetails[2].spiderColor)
    end

    Spider.SetSpiderForcesTechs()
end

--- Create a new spidertron for the specific player team to fight against.
---@param playerTeamName string
---@param yPos uint
---@param color Color
Spider.CreateSpider = function(playerTeamName, yPos, color)
    local playerteam = game.forces[playerTeamName]
    local biterTeam = game.forces[playerTeamName .. biterForceSuffixes]
    if debugging then
        biterTeam = game.forces["enemy"] -- No biter forces in this code branch yet so make sure its on the enemy so the player can test fighting against it.
        if playerTeamName == "south" then
            biterTeam = game.forces["player"] -- So the 2 spiders will fight when placed near each other.
        end
    end
    local spiderPosition = {x = -bossSpiderStartingLeftDistance, y = yPos}
    local bossEntity = Surface.create_entity {name = "jd_plays-jd_spider_race-spidertron_boss", position = spiderPosition, force = biterTeam}
    if bossEntity == nil then
        error("Failed to create boss spider for team " .. playerTeamName .. " at: " .. Utils.FormatPositionTableToString(spiderPosition))
    end
    bossEntity.color = color

    ---@type BossSpider
    local spider = {
        id = bossEntity.unit_number,
        bossEntity = bossEntity,
        state = BossSpider_State.roaming,
        playerTeam = playerteam,
        playerTeamName = playerTeamName,
        biterTeam = biterTeam,
        distanceFromSpawn = bossSpiderStartingLeftDistance
    }

    -- Fill the spiders equipment grid.
    local spiderEquipmentGrid = spider.bossEntity.grid
    for i = 1, 10 do
        spiderEquipmentGrid.put {name = "personal-laser-defense-equipment"}
    end
    for i = 1, 1 do
        spiderEquipmentGrid.put {name = "battery-mk2-equipment"}
    end
    for i = 1, 20 do
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

return Spider
