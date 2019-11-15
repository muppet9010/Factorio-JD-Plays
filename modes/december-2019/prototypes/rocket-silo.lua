if settings.startup["jdplays_mode"].value ~= "december-2019" then
    return
end

local rocketSiloTechnologyPrototype = data.raw["technology"]["rocket-silo"]
for k, effect in pairs(rocketSiloTechnologyPrototype.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "rocket-silo" then
        table.remove(rocketSiloTechnologyPrototype.effects, k)
        break
    end
end
