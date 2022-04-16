local Utils = require("utility.utils")

-- Spidertron generation functions copied from vanilla Factorio. Have to include prior to the mode check so there's no risk of a checksum mismatch.
require("__base__.prototypes.entity.spidertron-animations")
local sounds = require("__base__.prototypes.entity.sounds")

-- Check if this is the mode we are playing now.
if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

--[[
    Copy of spidertron generation functions from vanilla Factorio, but with some changes (commented): base\prototypes\entity\entities.lua
]]
--
function create_boss_spidertron(arguments)
    local scale = arguments.scale
    local leg_scale = scale * arguments.leg_scale
    data:extend(
        {
            {
                type = "spider-vehicle",
                name = arguments.name,
                collision_box = {{-1 * scale, -1 * scale}, {1 * scale, 1 * scale}},
                sticker_box = {{-1.5 * scale, -1.5 * scale}, {1.5 * scale, 1.5 * scale}},
                selection_box = {{-1 * scale, -1 * scale}, {1 * scale, 1 * scale}},
                drawing_box = {{-3 * scale, -4 * scale}, {3 * scale, 2 * scale}},
                icon = "__base__/graphics/icons/spidertron.png",
                mined_sound = {filename = "__core__/sound/deconstruct-large.ogg", volume = 0.8},
                open_sound = {filename = "__base__/sound/spidertron/spidertron-door-open.ogg", volume = 0.35},
                close_sound = {filename = "__base__/sound/spidertron/spidertron-door-close.ogg", volume = 0.4},
                sound_minimum_speed = 0.1,
                sound_scaling_ratio = 0.6,
                working_sound = {
                    sound = {
                        filename = "__base__/sound/spidertron/spidertron-vox.ogg",
                        volume = 0.35
                    },
                    activate_sound = {
                        filename = "__base__/sound/spidertron/spidertron-activate.ogg",
                        volume = 0.5
                    },
                    deactivate_sound = {
                        filename = "__base__/sound/spidertron/spidertron-deactivate.ogg",
                        volume = 0.5
                    },
                    match_speed_to_activity = true
                },
                icon_size = 64,
                icon_mipmaps = 4,
                weight = 1,
                braking_force = 1,
                friction_force = 1,
                flags = {"placeable-neutral", "player-creation", "placeable-off-grid"},
                collision_mask = {},
                minable = nil, -- Will never be mined.
                max_health = 10000, -- Increased to desired health level.
                resistances = {
                    {
                        type = "fire",
                        decrease = 15,
                        percent = 60
                    },
                    {
                        type = "physical",
                        decrease = 15,
                        percent = 60
                    },
                    {
                        type = "impact",
                        decrease = 50,
                        percent = 80
                    },
                    {
                        type = "explosion",
                        decrease = 20,
                        percent = 75
                    },
                    {
                        type = "acid",
                        decrease = 0,
                        percent = 70
                    },
                    {
                        type = "laser",
                        decrease = 0,
                        percent = 70
                    },
                    {
                        type = "electric",
                        decrease = 0,
                        percent = 70
                    }
                },
                minimap_representation = {
                    -- TODO: replace with custom image.
                    filename = "__base__/graphics/entity/spidertron/spidertron-map.png",
                    flags = {"icon"},
                    size = {128, 128},
                    scale = 0.5
                },
                corpse = "jd_plays-jd_spider_race-spidertron_boss_remnants", -- Changed to custom sized remnants.
                dying_explosion = "spidertron-explosion",
                energy_per_hit_point = 1,
                guns = {"spidertron-rocket-launcher-1", "spidertron-rocket-launcher-2", "spidertron-rocket-launcher-3", "spidertron-rocket-launcher-4"},
                inventory_size = 80,
                equipment_grid = "spidertron-equipment-grid",
                trash_inventory_size = 20,
                height = 1 * scale * leg_scale, -- Changed height from 1.5x to 1x, as otherwsie it tended to bob up and down excessively.
                torso_rotation_speed = 0.005,
                chunk_exploration_radius = 3,
                selection_priority = 51,
                graphics_set = spidertron_torso_graphics_set(scale),
                energy_source = {
                    type = "void"
                },
                movement_energy_consumption = "250kW",
                automatic_weapon_cycling = true,
                chain_shooting_cooldown_modifier = 0.5,
                spider_engine = {
                    legs = {
                        {
                            -- 1
                            leg = arguments.name .. "-leg-1",
                            mount_position = util.by_pixel(15 * scale, -22 * scale),
                            --{0.5, -0.75},
                            ground_position = {2.25 * leg_scale, -2.5 * leg_scale},
                            blocking_legs = {2},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 2
                            leg = arguments.name .. "-leg-2",
                            mount_position = util.by_pixel(23 * scale, -10 * scale),
                            --{0.75, -0.25},
                            ground_position = {3 * leg_scale, -1 * leg_scale},
                            blocking_legs = {1, 3},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 3
                            leg = arguments.name .. "-leg-3",
                            mount_position = util.by_pixel(25 * scale, 4 * scale),
                            --{0.75, 0.25},
                            ground_position = {3 * leg_scale, 1 * leg_scale},
                            blocking_legs = {2, 4},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 4
                            leg = arguments.name .. "-leg-4",
                            mount_position = util.by_pixel(15 * scale, 17 * scale),
                            --{0.5, 0.75},
                            ground_position = {2.25 * leg_scale, 2.5 * leg_scale},
                            blocking_legs = {3},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 5
                            leg = arguments.name .. "-leg-5",
                            mount_position = util.by_pixel(-15 * scale, -22 * scale),
                            --{-0.5, -0.75},
                            ground_position = {-2.25 * leg_scale, -2.5 * leg_scale},
                            blocking_legs = {6, 1},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 6
                            leg = arguments.name .. "-leg-6",
                            mount_position = util.by_pixel(-23 * scale, -10 * scale),
                            --{-0.75, -0.25},
                            ground_position = {-3 * leg_scale, -1 * leg_scale},
                            blocking_legs = {5, 7},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 7
                            leg = arguments.name .. "-leg-7",
                            mount_position = util.by_pixel(-25 * scale, 4 * scale),
                            --{-0.75, 0.25},
                            ground_position = {-3 * leg_scale, 1 * leg_scale},
                            blocking_legs = {6, 8},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        },
                        {
                            -- 8
                            leg = arguments.name .. "-leg-8",
                            mount_position = util.by_pixel(-15 * scale, 17 * scale),
                            --{-0.5, 0.75},
                            ground_position = {-2.25 * leg_scale, 2.5 * leg_scale},
                            blocking_legs = {7},
                            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
                        }
                    },
                    military_target = "spidertron-military-target"
                }
            },
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 1),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 2),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 3),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 4),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 5),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 6),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 7),
            make_spidertron_leg(arguments.name, leg_scale, arguments.leg_thickness, arguments.leg_movement_speed, 8)
        }
    )
end

function get_leg_hit_the_ground_trigger()
    return {
        {
            type = "create-trivial-smoke",
            smoke_name = "smoke-building",
            repeat_count = 4,
            starting_frame_deviation = 5,
            starting_frame_speed_deviation = 5,
            offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}},
            speed_from_center = 0.03
        }
    }
end

function make_spidertron_leg(spidertron_name, scale, leg_thickness, movement_speed, number, base_sprite, ending_sprite)
    return {
        type = "spider-leg",
        name = spidertron_name .. "-leg-" .. number,
        localised_name = {"entity-name.spidertron-leg"},
        collision_box = {{-0.05, -0.05}, {0.05, 0.05}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        icon = "__base__/graphics/icons/spidertron.png",
        icon_size = 64,
        icon_mipmaps = 4,
        walking_sound_volume_modifier = 0.6,
        target_position_randomisation_distance = 0.25 * scale,
        minimal_step_size = 1 * scale,
        working_sound = {
            match_progress_to_activity = true,
            sound = sounds.spidertron_leg,
            audible_distance_modifier = 0.5
        },
        part_length = 3.5 * scale,
        initial_movement_speed = 0.06 * movement_speed,
        movement_acceleration = 0.03 * movement_speed,
        max_health = 100,
        movement_based_position_selection_distance = 4 * scale,
        selectable_in_game = false,
        graphics_set = create_spidertron_leg_graphics_set(scale * leg_thickness, number)
    }
end
--[[
        End of copied spidertron creation code.
]]
--

-- Create our boss spidertron with custom settings.
create_boss_spidertron {
    name = "jd_plays-jd_spider_race-spidertron_boss",
    scale = 2,
    leg_scale = 1, -- relative to scale
    leg_thickness = 1, -- relative to leg_scale
    leg_movement_speed = 3 -- Same approximate real speed as a regular spider with 3 (max) legs.
}

-- Make remnants the right size for the boss spidertron.
local spidertronBossRemnants = Utils.DeepCopy(data.raw["corpse"]["spidertron-remnants"])
spidertronBossRemnants.name = "jd_plays-jd_spider_race-spidertron_boss_remnants"
spidertronBossRemnants.tile_width = 6
spidertronBossRemnants.tile_height = 6
spidertronBossRemnants.animation[1].layers[1].scale = 2
spidertronBossRemnants.animation[1].layers[1].hr_version.scale = 1
spidertronBossRemnants.animation[1].layers[2].scale = 2
spidertronBossRemnants.animation[1].layers[2].hr_version.scale = 1

data:extend(
    {
        spidertronBossRemnants
    }
)
