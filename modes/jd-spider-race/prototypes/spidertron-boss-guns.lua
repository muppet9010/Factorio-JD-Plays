local Utils = require("utility.utils")

-- Special rapid firing artillery gun.
-- TODO LATER: The artillery spider targets players, not just buildings. Only thing I can think of is to script in an artillery turret to the spiders position every second that the spider has artillery ammo.
local artilleryGunForBossSpider = Utils.DeepCopy(data.raw["gun"]["artillery-wagon-cannon"])
artilleryGunForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-artillery_wagon_cannon"
artilleryGunForBossSpider.attack_parameters.cooldown = 20 -- Defaults to 200.

data:extend(
    {
        artilleryGunForBossSpider
    }
)
