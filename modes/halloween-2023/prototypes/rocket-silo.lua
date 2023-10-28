local rocketSiloTech = data.raw["technology"]["rocket-silo"]
for index, effect in pairs(rocketSiloTech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "rocket-silo" then
        rocketSiloTech.effects[index] = nil
    end
end
