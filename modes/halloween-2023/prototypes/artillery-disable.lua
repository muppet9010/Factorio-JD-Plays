if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

local artilleryTechnologyPrototype = data.raw["technology"]["artillery"]
artilleryTechnologyPrototype.hidden = true
artilleryTechnologyPrototype.enabled = false

local artillerySpeedTechnologyPrototype = data.raw["technology"]["artillery-shell-speed-1"]
artillerySpeedTechnologyPrototype.hidden = true
artillerySpeedTechnologyPrototype.enabled = false

local artilleryRangeTechnologyPrototype = data.raw["technology"]["artillery-shell-range-1"]
artilleryRangeTechnologyPrototype.hidden = true
artilleryRangeTechnologyPrototype.enabled = false
