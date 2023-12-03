-- IF YOU FIND THIS DON'T POST IN DISCORD ABOUT IT. DIRECT MESSAGE MUPPET IF YOU WANT TO CHAT ABOUT IT.
-- It's a hidden feature for revealing on stream.

local Constants = require('constants')

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

-- Add the custom avatar gravestones. The base game has 10 variations, so replace those we have new ones for. This will leave the remaining ones as the blank gravestone. TO go above 10 we will need to do some sort of script update in a migration to all current graves and shuffle them.
---@class halloween_2023-gravestoneGraphic
---@field main string
---@field corpse string
---@type halloween_2023-gravestoneGraphic[]
local gravestoneGraphics = { { main = "Bilbo", corpse = "Bilbo Destroyed" }, { main = "BTG", corpse = "JD Destroyed" }, { main = "Fox", corpse = "Fox Destroyed" }, { main = "Huff", corpse = "Huff Destroyed" }, { main = "JD", corpse = "JD Destroyed" }, { main = "Rubble", corpse = "Bilbo Destroyed" }, { main = "Muppet", corpse = "Bilbo Destroyed" }, { main = "Sassy", corpse = "Huff Destroyed" }, { main = "Sorahn", corpse = "Huff Destroyed" } }
local graveWithHeadstonePrototype = data.raw["simple-entity-with-force"]["zombie_engineer-grave_with_headstone"]
if graveWithHeadstonePrototype ~= nil then
    local defaultGraphic = graveWithHeadstonePrototype.picture --[[@as data.Sprite # We only specify it as a simple 1 directional sprite in the main Zombie Engineer mod.]]
    graveWithHeadstonePrototype.picture = nil
    graveWithHeadstonePrototype.pictures = {}
    for index, gravestoneGraphic in pairs(gravestoneGraphics) do
        graveWithHeadstonePrototype.pictures[index] =
        {
            filename = Constants.AssetModName ..
                "/modes/halloween-2023/graphics/zombie-engineer/" .. gravestoneGraphic.main .. ".png",
            width = 140,
            height = 181,
            scale = 0.5,
            shift = { 0.1, 0.3 }
        }
    end
    graveWithHeadstonePrototype.pictures[#graveWithHeadstonePrototype.pictures + 1] = defaultGraphic
end
-- The custom corpse images are matched on headstone color.
local graveWithHeadstoneCorpsePrototype = data.raw["corpse"]["zombie_engineer-grave_with_headstone-corpse"]
if graveWithHeadstoneCorpsePrototype ~= nil then
    local defaultGraphic = graveWithHeadstoneCorpsePrototype.animation
    graveWithHeadstoneCorpsePrototype.animation = nil
    graveWithHeadstoneCorpsePrototype.animation = {}
    for index, gravestoneGraphic in pairs(gravestoneGraphics) do
        graveWithHeadstoneCorpsePrototype.animation[index] =
        {
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/zombie-engineer/" .. gravestoneGraphic.corpse .. ".png",
            width = 140,
            height = 181,
            scale = 0.5,
            shift = { 0.1, 0.3 },
            frame_count = 1,
            direction_count = 1
        }
    end
    graveWithHeadstoneCorpsePrototype.animation[#graveWithHeadstoneCorpsePrototype.animation + 1] = defaultGraphic
end
