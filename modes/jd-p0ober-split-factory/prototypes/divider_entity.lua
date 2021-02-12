local CollisionMaskUtil = require("__core__/lualib/collision-mask-util")
local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "jd_p0ober_split_factory" then
    return
end

local spiderBlockCollisionLayer = CollisionMaskUtil.get_first_unused_layer()

data:extend(
    {
        {
            type = "simple-entity",
            name = "jd_plays-jd_p0ober_split_factory-divider_entity",
            collision_box = {{-10, -1}, {10, 1}}, -- Wide enough a spider can't reach across with its legs.
            collision_mask = {spiderBlockCollisionLayer},
            flags = {"placeable-off-grid"},
            picture = Utils.EmptyRotatedSprite()
        }
    }
)

-- Add out custom collision layer to all the spider legs.
for _, spiderLeg in pairs(data.raw["spider-leg"]) do
    local spiderLegCollisionMask = CollisionMaskUtil.get_mask(spiderLeg)
    CollisionMaskUtil.add_layer(spiderLegCollisionMask, spiderBlockCollisionLayer)
    spiderLeg.collision_mask = spiderLegCollisionMask
end
