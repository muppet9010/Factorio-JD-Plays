local Utils = require("utility.utils")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

-- Make a test placement entity for a market, but it needs to avoid being placed on ore by colliding with it as well as entities and water.

local marketPlacementTestCollisionMask = {"item-layer", "object-layer", "player-layer", "water-tile"} -- Defaults from wiki.
table.insert(marketPlacementTestCollisionMask, "resource-layer")
local marketPlacementTest = Utils.CreatePlacementTestEntityPrototype(data.raw["market"]["market"], "jd_plays-jd_spider_race-market_placement_test", "other", marketPlacementTestCollisionMask)

data:extend({marketPlacementTest})
