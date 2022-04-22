local Utils = require("utility.utils")

-- Special flamethrower ammo that works like player held flamethrower for the spidertron. This means the spider will light the ground and trees on fire. But with FF disabled it won';'t hurt this biter forces units.
local flamethrowerAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["flamethrower-ammo"])
flamethrowerAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo"
flamethrowerAmmoForBossSpider.ammo_type[2] = nil -- Remove the special vehicle version so every user gets the player version.
flamethrowerAmmoForBossSpider.subgroup = nil
flamethrowerAmmoForBossSpider.flags = {"hidden"}

-- Special tank shells that only collide with enemy force entities. This way they can be shot by the spider safely without hitting biters or the spiders legs.
local cannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["cannon-shell"])
cannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo"
cannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_projectile"
cannonShellAmmoForBossSpider.subgroup = nil
cannonShellAmmoForBossSpider.flags = {"hidden"}
local cannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["cannon-projectile"])
cannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_projectile"
cannonShellProjecticleForBossSpider.force_condition = "enemy"

local explosiveCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["explosive-cannon-shell"])
explosiveCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo"
explosiveCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_projectile"
explosiveCannonShellAmmoForBossSpider.subgroup = nil
explosiveCannonShellAmmoForBossSpider.flags = {"hidden"}
local explosiveCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["explosive-cannon-projectile"])
explosiveCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_projectile"
explosiveCannonShellProjecticleForBossSpider.force_condition = "enemy"

local uraniumCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["uranium-cannon-shell"])
uraniumCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo"
uraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_projectile"
uraniumCannonShellAmmoForBossSpider.subgroup = nil
uraniumCannonShellAmmoForBossSpider.flags = {"hidden"}
local uraniumCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["uranium-cannon-projectile"])
uraniumCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_projectile"
uraniumCannonShellProjecticleForBossSpider.force_condition = "enemy"

local explosiveUraniumCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["explosive-uranium-cannon-shell"])
explosiveUraniumCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo"
explosiveUraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_projectile"
explosiveUraniumCannonShellAmmoForBossSpider.subgroup = nil
explosiveUraniumCannonShellAmmoForBossSpider.flags = {"hidden"}
local explosiveUraniumCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["explosive-uranium-cannon-projectile"])
explosiveUraniumCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_projectile"
explosiveUraniumCannonShellProjecticleForBossSpider.force_condition = "enemy"

data:extend(
    {
        flamethrowerAmmoForBossSpider,
        cannonShellAmmoForBossSpider,
        cannonShellProjecticleForBossSpider,
        explosiveCannonShellAmmoForBossSpider,
        explosiveCannonShellProjecticleForBossSpider,
        uraniumCannonShellAmmoForBossSpider,
        uraniumCannonShellProjecticleForBossSpider,
        explosiveUraniumCannonShellAmmoForBossSpider,
        explosiveUraniumCannonShellProjecticleForBossSpider
    }
)
