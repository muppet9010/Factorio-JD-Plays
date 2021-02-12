if settings.startup["jdplays_mode"].value ~= "jd_p0ober_split_factory" then
    return
end

local refNuclearGroundTile = data.raw["tile"]["nuclear-ground"]

data:extend(
    {
        {
            type = "tile",
            name = "jd_plays-jd_p0ober_split_factory-divider_tile_land",
            order = "zzz1",
            collision_mask = {
                "ground-tile",
                "water-tile",
                "item-layer",
                "object-layer",
                "player-layer"
            },
            layer_group = refNuclearGroundTile.layer_group,
            layer = 200, -- Above ground tiles and player flooring.
            variants = refNuclearGroundTile.variants,
            map_color = refNuclearGroundTile.map_color,
            pollution_absorption_per_second = 0,
            transition_merges_with_tile = refNuclearGroundTile.transition_merges_with_tile,
            effect = refNuclearGroundTile.effect,
            effect_color = refNuclearGroundTile.effect_color,
            effect_color_secondary = refNuclearGroundTile.effect_color_secondary,
            draw_in_water_layer = refNuclearGroundTile.draw_in_water_layer,
            allowed_neighbors = refNuclearGroundTile.allowed_neighbors,
            trigger_effect = refNuclearGroundTile.trigger_effect,
            transitions = refNuclearGroundTile.transitions
        }
    }
)
