data:extend(
    {
        {
            type = "simple-entity",
            name = "jd_plays-jd_p0ober_split_factory-divider_entity",
            collision_mask = {},
            flags = {"placeable-off-grid"},
            picture = {
                -- Temp graphics.
                filename = "__base__/graphics/entity/wall/wall-vertical.png",
                priority = "extra-high",
                width = 32,
                height = 68,
                variation_count = 5,
                line_length = 5,
                shift = util.by_pixel(0, 8),
                hr_version = {
                    filename = "__base__/graphics/entity/wall/hr-wall-vertical.png",
                    priority = "extra-high",
                    width = 64,
                    height = 134,
                    variation_count = 5,
                    line_length = 5,
                    shift = util.by_pixel(0, 8),
                    scale = 0.5
                }
            }
        }
    }
)
