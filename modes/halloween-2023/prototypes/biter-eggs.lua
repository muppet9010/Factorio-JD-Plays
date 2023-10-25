-- These are very quick and dirty from AI generated images from JD-Plays.
-- Nest corpse hasn't been updated, but meh.

local Constants = require("constants")

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

local smallEggNestPrototype = data.raw["simple-entity-with-force"]["biter-egg-nest-small"]
smallEggNestPrototype.picture = {
    layers = {
        {
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/biter-eggs/small_nest_replacement.png",
            width = 150,
            height = 120,
        }
    }
}

local smallEggNestCorpsePrototype = data.raw["corpse"]["biter-egg-nest-small-corpse"]
smallEggNestCorpsePrototype.animation = {
    layers = {
        {
            width = 125,
            height = 100,
            scale = 1.2,
            frame_count = 1,
            direction_count = 1,
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/biter-eggs/small_nest_replacement_corpse.png"
        }
    }
}




local largeEggNestPrototype = data.raw["simple-entity-with-force"]["biter-egg-nest-large"]
largeEggNestPrototype.picture = {
    layers = {
        {
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/biter-eggs/large_nest_replacement.png",
            width = 360,
            height = 180,
            scale = 0.9
        }
    }
}


local largeEggNestCorpsePrototype = data.raw["corpse"]["biter-egg-nest-large-corpse"]
largeEggNestCorpsePrototype.animation = {
    layers = {
        {
            width = 600,
            height = 300,
            scale = 0.54,
            frame_count = 1,
            direction_count = 1,
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/biter-eggs/large_nest_replacement_corpse.png"
        }
    }
}
