local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

-- Double all the graphic scales, some were on 1 and some on 0.5 in vanilla beam copied.
-- The graphics overlap one another after scaled, but it makes a thicker effect in game.
local dividerBeam = Utils.DeepCopy(data.raw["beam"]["electric-beam"])
dividerBeam.name = "jd_plays-jd_spider_race-divider_beam"
dividerBeam.random_target_offset = true
dividerBeam.target_offset = nil
dividerBeam.action = nil
dividerBeam.start = nil
dividerBeam.ending = nil
dividerBeam.damage_interval = Utils.MaxUInt
dividerBeam.head = Utils.EmptyRotatedSprite(16)
dividerBeam.tail = Utils.EmptyRotatedSprite(16)
for _, bodyPart in pairs(dividerBeam.body) do
    bodyPart.scale = 2
end
dividerBeam.light_animations = {body = dividerBeam.body}
dividerBeam.ground_light_animations.head = nil
dividerBeam.ground_light_animations.tail = nil
dividerBeam.ground_light_animations.body.scale = 1

data:extend({dividerBeam})
