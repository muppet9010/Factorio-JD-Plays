-- Makes copies of the boss spidertron for each gun type and hidden graghics. Are to act as extra gun platforms of the spidertron.
local Utils = require("utility.utils")

-- If TRUE the spiders are visible and selectable.
local Testing = true -- TODO

--[[
    Notes:
        - The spider's guns will all fire forwards rather than out of the sides of the spider as we have 1 gun per ammo type.
        - All the spiders gun will have a filter applied to their ammo type at entity creation time so that theres only 1 gun per ammo type. Saves having to make new ammo categories, ammo types and gun types.
]]
--

-- Make the base gun object of the boss spider. Doesn't need to be directly loaded as a prototype, as each variant will be. This is an invisible graphic version that can't be targetted.
local gunSpiderBase = Utils.DeepCopy(data.raw["spider-vehicle"]["jd_plays-jd_spider_race-spidertron_boss"])
gunSpiderBase.name = "jd_plays-jd_spider_race-spidertron_boss_gun"
gunSpiderBase.military_target = nil
if not Testing then
    -- Real usage settings.
    gunSpiderBase.graphics_set = {}
    gunSpiderBase.selectable_in_game = false
end
gunSpiderBase.guns = {}
gunSpiderBase.chunk_exploration_radius = 0 -- No need for this as the main boss spider will do it.
gunSpiderBase.minimap_representation = nil
for legCount, legObject in pairs(gunSpiderBase.spider_engine.legs) do
    -- Make a copy of the leg entity without the graphics.
    local legPrototype = Utils.DeepCopy(data.raw["spider-leg"]["jd_plays-jd_spider_race-spidertron_boss-leg-" .. legCount])
    legPrototype.name = gunSpiderBase.name .. "-leg-" .. legCount
    legPrototype.graphics_set = {}
    data:extend({legPrototype})

    -- Set this spider to use the new no-graphic leg.
    legObject.leg = legPrototype.name
    legObject.leg_hit_the_ground_trigger = nil
end

-- Make each weapon variant of the boss spider.
local gunSpiderRocketLauncher = Utils.DeepCopy(gunSpiderBase)
gunSpiderRocketLauncher.name = "jd_plays-jd_spider_race-spidertron_boss_gun-rocket_launcher"
gunSpiderRocketLauncher.guns = {"rocket-launcher", "rocket-launcher", "rocket-launcher"}

local gunSpiderMachineGun = Utils.DeepCopy(gunSpiderBase)
gunSpiderMachineGun.name = "jd_plays-jd_spider_race-spidertron_boss_gun-machine_gun"
gunSpiderMachineGun.guns = {"tank-machine-gun", "tank-machine-gun", "tank-machine-gun"}

local gunSpiderTankCannon = Utils.DeepCopy(gunSpiderBase)
gunSpiderTankCannon.name = "jd_plays-jd_spider_race-spidertron_boss_gun-tank_cannon"
gunSpiderTankCannon.guns = {"tank-cannon", "tank-cannon", "tank-cannon", "tank-cannon"}

local gunSpiderArtillery = Utils.DeepCopy(gunSpiderBase)
gunSpiderArtillery.name = "jd_plays-jd_spider_race-spidertron_boss_gun-artillery_wagon_cannon"
gunSpiderArtillery.guns = {"jd_plays-jd_spider_race-spidertron_boss-artillery_wagon_cannon"}

data:extend(
    {
        gunSpiderRocketLauncher,
        gunSpiderMachineGun,
        gunSpiderTankCannon,
        gunSpiderArtillery
    }
)
