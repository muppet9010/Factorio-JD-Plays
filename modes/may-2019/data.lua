local Constants = require("constants")
local modeFilePath = "modes/may-2019"

if settings.startup["jdplays_mode"].value ~= "may-2019" then
    return
end

data.raw["character-corpse"]["character-corpse"].icon = Constants.AssetModName .. "/" .. modeFilePath .. "/graphics/character-corpse.png"
data.raw["character-corpse"]["character-corpse"].icon_size = 180

data:extend(
    {
        {
            type = "explosion",
            name = "biter-ground-rise-effect",
            animations = {
                filename = "__core__/graphics/empty.png",
                width = 1,
                height = 1,
                frame_count = 1
            },
            created_effect = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-particle",
                            repeat_count = 100,
                            entity_name = "stone-particle",
                            initial_height = 0.5,
                            speed_from_center = 0.03,
                            speed_from_center_deviation = 0.05,
                            initial_vertical_speed = 0.10,
                            initial_vertical_speed_deviation = 0.05,
                            offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}}
                        }
                    }
                }
            }
        },
        {
            type = "trivial-smoke",
            name = "biter-rise-smoke",
            flags = {"not-on-map"},
            show_when_smoke_off = true,
            animation = {
                width = 152,
                height = 120,
                line_length = 5,
                frame_count = 60,
                animation_speed = 0.25,
                filename = "__base__/graphics/entity/smoke/smoke.png"
            },
            affected_by_wind = false,
            color = {r = 0.66, g = 0.58, b = 0.49, a = 1},
            duration = 240,
            fade_away_duration = 30
        },
        {
            type = "simple-entity",
            name = "biter-ground-movement",
            collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
            collision_maxk = {"object-layer", "player-layer", "water-tile"},
            selectable_in_game = false,
            animations = {
                filename = "__core__/graphics/empty.png",
                width = 1,
                height = 1,
                frame_count = 1
            },
            created_effect = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-trivial-smoke",
                            smoke_name = "biter-rise-smoke",
                            repeat_count = 3,
                            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
                            starting_frame_deviation = 10
                        }
                    }
                }
            }
        }
    }
)
