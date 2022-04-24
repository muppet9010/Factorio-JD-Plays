local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

local spiderBlockCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

-- Do as 2 seperate entities as the spider needs a much larger area to be blocked than player or other buildines/units.
data:extend(
    {
        {
            type = "simple-entity",
            name = "jd_plays-jd_spider_race-divider_entity",
            collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
            collision_mask = {
                "water-tile",
                "item-layer",
                "object-layer",
                "player-layer"
            },
            flags = {"placeable-off-grid"},
            picture = Utils.EmptyRotatedSprite()
        },
        {
            type = "simple-entity",
            name = "jd_plays-jd_spider_race-divider_entity_spider_block",
            collision_box = {{-10, -1}, {10, 1}}, -- Wide enough a spider can't reach across with its legs.
            collision_mask = {spiderBlockCollisionLayer},
            flags = {"placeable-off-grid"},
            picture = Utils.EmptyRotatedSprite()
        }
    }
)

-- Add our custom collision layer to all the spider legs.
for _, spiderLeg in pairs(data.raw["spider-leg"]) do
    local spiderLegCollisionMask = CollisionMaskUtil.get_mask(spiderLeg)
    CollisionMaskUtil.add_layer(spiderLegCollisionMask, spiderBlockCollisionLayer)
    spiderLeg.collision_mask = spiderLegCollisionMask
end
