local Constants = require('constants')

if settings.startup["jdplays_mode"].value ~= "christmas_2023" then
    return
end

-- Replace regular train techs with unlocking mini trains.
if mods["Mini_Trains"] ~= nil then
    local railwayTech = data.raw["technology"]["railway"] ---@type data.TechnologyPrototype
    railwayTech.effects = {
        {
            type = "unlock-recipe",
            recipe = "rail"
        },
        {
            type = "unlock-recipe",
            recipe = "mini-locomotive"
        },
        {
            type = "unlock-recipe",
            recipe = "mini-cargo-wagon"
        }
    }
    railwayTech.icon = Constants.AssetModName .. "/modes/christmas-2023/graphics/railway-tech.png"

    local railwayTech = data.raw["technology"]["fluid-wagon"] ---@type data.TechnologyPrototype
    railwayTech.effects = {
        {
            type = "unlock-recipe",
            recipe = "mini-fluid-wagon"
        }
    }
    railwayTech.icon = Constants.AssetModName .. "/modes/christmas-2023/graphics/fluid-wagon-tech.png"

    local miniTrainTech = data.raw["technology"]["mini-trains"] ---@type data.TechnologyPrototype
    miniTrainTech.hidden = true
end
