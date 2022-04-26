local Utils = require("utility.utils")

local refArtilleryTurret = data.raw["artillery-turret"]["artillery-turret"]
local refArtilleryTurretGun = data.raw["gun"]["artillery-wagon-cannon"]

-- If TRUE the turrets are visible and selectable.
local Testing = false

-- Special invisible artillery turret that has to be teleported to the spider each time its allowed to fire.
-- Has to be a turret and not a spider so it will only target military buildings and not military units.
local spiderArtilleryTurret = {
    type = "artillery-turret",
    name = "jd_plays-jd_spider_race-spidertron_boss-artillery_turret",
    localised_name = {"entity-name.jd_plays-jd_spider_race-spidertron_boss"}, -- Shows up when it kills a player.
    icon = refArtilleryTurret.icon,
    icon_size = refArtilleryTurret.icon_size,
    icon_mipmaps = refArtilleryTurret.icon_mipmaps,
    gun = "jd_plays-jd_spider_race-spidertron_boss-artillery_turret_gun",
    inventory_size = 1,
    ammo_stack_limit = 100000, -- How we are setting how many shells can fit in it.
    automated_ammo_count = 1, -- No idea what this done.
    turret_rotation_speed = 100, -- This is instant turning.
    manual_range_modifier = 1,
    flags = {"placeable-off-grid", "hidden", "not-on-map"},
    selectable_in_game = false,
    collision_mask = {},
    alert_when_attacking = false,
    cannon_parking_speed = 0
}
if Testing then
    spiderArtilleryTurret.cannon_barrel_pictures = refArtilleryTurret.cannon_barrel_pictures
    spiderArtilleryTurret.cannon_base_pictures = refArtilleryTurret.cannon_base_pictures
    spiderArtilleryTurret.selectable_in_game = true
    spiderArtilleryTurret.selection_box = {{-1, -1}, {1, 1}}
end

local spiderArtilleryTurretGun = {
    type = "gun",
    name = "jd_plays-jd_spider_race-spidertron_boss-artillery_turret_gun",
    icon = refArtilleryTurretGun.icon,
    icon_size = refArtilleryTurretGun.icon_size,
    icon_mipmaps = refArtilleryTurretGun.icon_mipmaps,
    flags = {"hidden", "hide-from-bonus-gui"},
    stack_size = 1,
    attack_parameters = {
        type = "projectile",
        ammo_category = "artillery-shell",
        cooldown = 20,
        range = refArtilleryTurretGun.attack_parameters.range * data.raw["artillery-turret"]["artillery-turret"].manual_range_modifier, -- So same range as a default artillery under manual fire control.
        min_range = refArtilleryTurretGun.attack_parameters.min_range,
        sound = refArtilleryTurretGun.attack_parameters.sound
    }
}

local spiderArtilleryShell = Utils.DeepCopy(data.raw["ammo"]["artillery-shell"])
spiderArtilleryShell.name = "jd_plays-jd_spider_race-spidertron_boss-artillery_shell"
spiderArtilleryShell.flags = {"hidden", "hide-from-bonus-gui"}
spiderArtilleryShell.subgroup = nil
spiderArtilleryShell.ammo_type.action.action_delivery.source_effects = nil -- Remove the flash when the shell is fired. As it won't match up to the spider.

data:extend(
    {
        spiderArtilleryTurret,
        spiderArtilleryTurretGun,
        spiderArtilleryShell
    }
)
