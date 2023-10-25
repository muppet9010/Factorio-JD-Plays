if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

local woodKilnDryingTechnologyPrototype = data.raw["technology"]["wood-kiln-drying"]
woodKilnDryingTechnologyPrototype.hidden = true
woodKilnDryingTechnologyPrototype.enabled = false

local inVesselCompostingTechnologyPrototype = data.raw["technology"]["in-vessel-composting"]
inVesselCompostingTechnologyPrototype.hidden = true
inVesselCompostingTechnologyPrototype.enabled = false

local landfillTechnologyPrototype = data.raw["technology"]["landfill"]
landfillTechnologyPrototype.hidden = true
landfillTechnologyPrototype.enabled = false

local mazeTerraformingTechnologyPrototype = data.raw["technology"]["maze-terraforming"]
mazeTerraformingTechnologyPrototype.hidden = true
mazeTerraformingTechnologyPrototype.enabled = false

local mangroveHarvestingTechnologyPrototype = data.raw["technology"]["mangrove-harvesting"]
mangroveHarvestingTechnologyPrototype.hidden = true
mangroveHarvestingTechnologyPrototype.enabled = false
