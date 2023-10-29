if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

local woodKilnDryingTechnologyPrototype = data.raw["technology"]["wood-kiln-drying"]
if woodKilnDryingTechnologyPrototype ~= nil then
    woodKilnDryingTechnologyPrototype.hidden = true
    woodKilnDryingTechnologyPrototype.enabled = false
end

local inVesselCompostingTechnologyPrototype = data.raw["technology"]["in-vessel-composting"]
if inVesselCompostingTechnologyPrototype ~= nil then
    inVesselCompostingTechnologyPrototype.hidden = true
    inVesselCompostingTechnologyPrototype.enabled = false
end

-- Return landfill to vanilla.
data.raw["technology"]["landfill"] = {
    type = "technology",
    name = "landfill",
    icon_size = 256,
    icon_mipmaps = 4,
    icon = "__base__/graphics/technology/landfill.png",
    prerequisites = { "logistic-science-pack" },
    unit =
    {
        count = 50,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack",   1 }
        },
        time = 30
    },
    effects =
    {
        {
            type = "unlock-recipe",
            recipe = "landfill"
        }
    },
    order = "b-d"
} --[[@as data.TechnologyPrototype]]
data.raw["recipe"]["landfill"] = {
    type = "recipe",
    name = "landfill",
    energy_required = 0.5,
    enabled = false,
    category = "crafting",
    ingredients =
    {
        { "stone", 20 }
    },
    result = "landfill",
    result_count = 1
} --[[@as data.RecipePrototype]]

local mazeTerraformingTechnologyPrototype = data.raw["technology"]["maze-terraforming"]
if mazeTerraformingTechnologyPrototype ~= nil then
    mazeTerraformingTechnologyPrototype.hidden = true
    mazeTerraformingTechnologyPrototype.enabled = false
end

local mangroveHarvestingTechnologyPrototype = data.raw["technology"]["mangrove-harvesting"]
if mangroveHarvestingTechnologyPrototype ~= nil then
    mangroveHarvestingTechnologyPrototype.hidden = true
    mangroveHarvestingTechnologyPrototype.enabled = false
end
