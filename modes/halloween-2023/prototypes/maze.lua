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

local landfillTechnologyPrototype = data.raw["technology"]["landfill"]
if landfillTechnologyPrototype ~= nil then
    landfillTechnologyPrototype.hidden = true
    landfillTechnologyPrototype.enabled = false
end

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
