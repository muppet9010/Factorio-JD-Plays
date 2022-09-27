-- This is copied from the Teleporters mod by Klonan. https://github.com/Klonan/Teleporters
local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "jd_split_factory" then
    return
end

data:extend(
    {
        {
            type = "land-mine",
            name = "jd_plays-jd_split_factory-teleporter",
            localised_name = { "entity-name.jdplays_mode-jd_split_factory-teleport" },
            trigger_radius = 1,
            timeout = 1,
            max_health = 200,
            dying_explosion = nil,
            action = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "script",
                            effect_id = "jd_plays-jd_split_factory-teleporter-affected_target"
                        }
                    }
                }
            },
            force_die_on_attack = false,
            trigger_force = "same",
            picture_safe = {
                filename = "__jd_plays__/modes/jd-split-factory/graphics/teleporter-closed.png",
                priority = "medium",
                width = 97,
                height = 77,
                scale = 0.75
            },
            picture_set = {
                filename = "__jd_plays__/modes/jd-split-factory/graphics/teleporter-closed.png",
                priority = "medium",
                width = 97,
                height = 77,
                scale = 0.75
            },
            picture_set_enemy = {
                filename = "__jd_plays__/modes/jd-split-factory/graphics/teleporter-closed.png",
                priority = "medium",
                width = 97,
                height = 77,
                scale = 0.75
            },
            collision_box = { { -1, -1 }, { 1, 1 } },
            selection_box = { { -1, -1 }, { 1, 1 } },
            map_color = { r = 0.5, g = 1, b = 1 }
        },
        {
            -- Used to just play the sound.
            type = "explosion",
            name = "jd_plays-jd_split_factory-teleporter-player_moved",
            animations = Utils.EmptyRotatedSprite(),
            sound = {
                filename = "__jd_plays__/modes/jd-split-factory/sounds/teleporter-player-moved.ogg",
                volume = 1
            }
        }
    }
)
