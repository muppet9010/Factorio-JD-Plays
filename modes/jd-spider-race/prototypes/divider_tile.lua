--[[
    Only block units (biters) to make the pathfinder effecient as it views it like water in preliminary pathfinder. Blocking everything else can be done with entities fine. Blocking any other layer will prevent cliff placement.
    Have to use new layer to just block biters and then apply it all units.
]]
local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

local refNuclearGroundTile = data.raw["tile"]["nuclear-ground"]
local unitBlockCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

data:extend(
    {
        {
            type = "tile",
            name = "jd_plays-jd_spider_race-divider_tile_land",
            order = "zzz1",
            collision_mask = {"ground-tile", unitBlockCollisionLayer},
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

for _, unit in pairs(data.raw["unit"]) do
    local unitLegCollisionMask = CollisionMaskUtil.get_mask(unit)
    CollisionMaskUtil.add_layer(unitLegCollisionMask, unitBlockCollisionLayer)
    unit.collision_mask = unitLegCollisionMask
end
