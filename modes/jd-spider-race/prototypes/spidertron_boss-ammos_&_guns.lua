local Utils = require("utility.utils")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

local ammoFlags = {"hidden", "hide-from-bonus-gui"}

--------------------------------------------
-- Special flamethrower ammo that works like player held flamethrower for the spidertron. This means the spider will light the ground and trees on fire. But with FF disabled it won't hurt this biter forces units.
--------------------------------------------
local flamethrowerAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["flamethrower-ammo"])
flamethrowerAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_ammo"
flamethrowerAmmoForBossSpider.ammo_type[2] = nil -- Remove the special vehicle version so every user gets the player version.
flamethrowerAmmoForBossSpider.subgroup = nil
flamethrowerAmmoForBossSpider.flags = ammoFlags

--------------------------------------------
-- Special tank cannon with longer range to be the same as rockets. Really just anti turret as they don't jurt enemy spidertrons.
--------------------------------------------
local tankCannonGunForBossSpider = Utils.DeepCopy(data.raw["gun"]["tank-cannon"])
tankCannonGunForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-tank_cannon_gun"
tankCannonGunForBossSpider.attack_parameters.range = 36

--------------------------------------------
-- Special tank shells that only collide with enemy force entities. This way they can be shot by the spider safely without hitting biters or the spiders legs.
-- They also don't have accuracy and range deviation as this leads to them shooting short often whch looks odd for an AI unit.
-- Also increaed range on the cannon shell ammo so that they don't explode before the gun's increased max range and actually go a bit beyond them.
--------------------------------------------
local cannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["cannon-shell"])
cannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_ammo"
cannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_projectile"
cannonShellAmmoForBossSpider.subgroup = nil
cannonShellAmmoForBossSpider.flags = ammoFlags
cannonShellAmmoForBossSpider.ammo_type.action.action_delivery.max_range = 40
local cannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["cannon-projectile"])
cannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-cannon_shell_projectile"
cannonShellProjecticleForBossSpider.force_condition = "enemy"

local explosiveCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["explosive-cannon-shell"])
explosiveCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_ammo"
explosiveCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_projectile"
explosiveCannonShellAmmoForBossSpider.subgroup = nil
explosiveCannonShellAmmoForBossSpider.flags = ammoFlags
explosiveCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.max_range = 40
local explosiveCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["explosive-cannon-projectile"])
explosiveCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_cannon_shell_projectile"
explosiveCannonShellProjecticleForBossSpider.force_condition = "enemy"

local uraniumCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["uranium-cannon-shell"])
uraniumCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_ammo"
uraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_projectile"
uraniumCannonShellAmmoForBossSpider.subgroup = nil
uraniumCannonShellAmmoForBossSpider.flags = ammoFlags
uraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.max_range = 40
local uraniumCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["uranium-cannon-projectile"])
uraniumCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-uranium_cannon_shell_projectile"
uraniumCannonShellProjecticleForBossSpider.force_condition = "enemy"

local explosiveUraniumCannonShellAmmoForBossSpider = Utils.DeepCopy(data.raw["ammo"]["explosive-uranium-cannon-shell"])
explosiveUraniumCannonShellAmmoForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_ammo"
explosiveUraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.projectile = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_projectile"
explosiveUraniumCannonShellAmmoForBossSpider.subgroup = nil
explosiveUraniumCannonShellAmmoForBossSpider.flags = ammoFlags
explosiveUraniumCannonShellAmmoForBossSpider.ammo_type.action.action_delivery.max_range = 40
local explosiveUraniumCannonShellProjecticleForBossSpider = Utils.DeepCopy(data.raw["projectile"]["explosive-uranium-cannon-projectile"])
explosiveUraniumCannonShellProjecticleForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-explosive_uranium_cannon_shell_projectile"
explosiveUraniumCannonShellProjecticleForBossSpider.force_condition = "enemy"

--------------------------------------------
-- Special guns that have a naturally fast fire speed and thus don't rely upon the boss spider having ammo in all slots.
--------------------------------------------
tankCannonGunForBossSpider.attack_parameters.cooldown = 45 -- Half of default 90.
tankCannonGunForBossSpider.attack_parameters.movement_slow_down_factor = 1 -- Don't fire slower when moving.

local rocketLauncherGunForBossSpider = Utils.DeepCopy(data.raw["gun"]["rocket-launcher"])
rocketLauncherGunForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-rocket_launcher_gun"
rocketLauncherGunForBossSpider.attack_parameters.cooldown = 30 -- Half of default 60.
rocketLauncherGunForBossSpider.attack_parameters.movement_slow_down_factor = 1 -- Don't fire slower when moving.

local tankMachineGunGunForBossSpider = Utils.DeepCopy(data.raw["gun"]["tank-machine-gun"])
tankMachineGunGunForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-tank_machine_gun"
tankMachineGunGunForBossSpider.attack_parameters.cooldown = 2 -- Half of default 4
tankMachineGunGunForBossSpider.attack_parameters.movement_slow_down_factor = 1 -- Don't fire slower when moving.

local flamethrowerGunForBossSpider = Utils.DeepCopy(data.raw["gun"]["flamethrower"])
flamethrowerGunForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-flamethrower_gun"
flamethrowerGunForBossSpider.attack_parameters.cooldown = 0.5 -- Half of default 1
flamethrowerGunForBossSpider.attack_parameters.movement_slow_down_factor = 1 -- Don't fire slower when moving.

--------------------------------------------
-- Special basic ammo for each gun that never runs out.
--------------------------------------------
local firearmMagazineForBossSpider = Utils.DeepCopy(data.raw["ammo"]["firearm-magazine"])
firearmMagazineForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-firearm_magazine_ammo"
firearmMagazineForBossSpider.ammo_type.consumption_modifier = 0
firearmMagazineForBossSpider.subgroup = nil
firearmMagazineForBossSpider.flags = ammoFlags

local rocketForBossSpider = Utils.DeepCopy(data.raw["ammo"]["rocket"])
rocketForBossSpider.name = "jd_plays-jd_spider_race-spidertron_boss-rocket_ammo"
rocketForBossSpider.ammo_type.consumption_modifier = 0
rocketForBossSpider.subgroup = nil
rocketForBossSpider.flags = ammoFlags

cannonShellAmmoForBossSpider.ammo_type.consumption_modifier = 0

flamethrowerAmmoForBossSpider.ammo_type[1].consumption_modifier = 0

--------------------------------------------
-- Add the new prototypes to the game
--------------------------------------------

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
        explosiveUraniumCannonShellProjecticleForBossSpider,
        tankCannonGunForBossSpider,
        rocketLauncherGunForBossSpider,
        tankMachineGunGunForBossSpider,
        flamethrowerGunForBossSpider,
        firearmMagazineForBossSpider,
        rocketForBossSpider
    }
)
