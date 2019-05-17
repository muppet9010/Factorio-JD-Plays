if settings.startup["jdplays_mode"].value ~= "jd-p00ber-may-2019" then
    return
end

data:extend(
    {
        {
            type = "item",
            name = "jd-p00ber-may-2019-escape-pod",
            icon = "__base__/graphics/technology/demo/analyse-ship.png",
            icon_size = 128,
            subgroup = "intermediate-product",
            order = "m[satellite]a",
            place_result = "jd-p00ber-may-2019-escape-pod",
            stack_size = 1
        },
        {
            type = "recipe",
            name = "jd-p00ber-may-2019-escape-pod",
            energy_required = 5,
            enabled = false,
            category = "crafting",
            ingredients = {
                {"low-density-structure", 100},
                {"solar-panel", 100},
                {"accumulator", 100},
                {"radar", 5},
                {"processing-unit", 100},
                {"rocket-fuel", 50},
                {"raw-fish", 1}
            },
            result = "jd-p00ber-may-2019-escape-pod",
            requester_paste_multiplier = 1
        },
        {
            type = "car",
            name = "jd-p00ber-may-2019-escape-pod",
            icon = "__base__/graphics/technology/demo/analyse-ship.png",
            icon_size = 128,
            flags = {"hide-alt-info"},
            collision_box = {{-1, -1}, {1, 1}},
            collision_mask = {"ground-tile", "water-tile"},
            weight = 1,
            braking_force = 1,
            friction = 1,
            energy_per_hit_point = 1,
            animation = {
                width = 1,
                height = 1,
                frame_count = 1,
                direction_count = 1,
                filename = "__core__/graphics/empty.png"
            },
            effectivity = 0.6,
            consumption = "0kW",
            rotation_speed = 0,
            energy_source = {
                type = "void"
            },
            inventory_size = 0
        }
    }
)

table.insert(data.raw["technology"]["rocket-silo"].effects, {type = "unlock-recipe", recipe = "jd-p00ber-may-2019-escape-pod"})
