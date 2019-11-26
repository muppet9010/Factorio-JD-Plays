local Constants = require("constants")
local modeFilePath = "modes/december-2019"
local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "december-2019" then
    return
end

local waterBarrierSmokeLight = {
    type = "animation",
    name = Constants.ModName .. "-water_barrier_smoke_light",
    filename = Constants.AssetModName .. "/" .. modeFilePath .. "/graphics/large-smoke-white.png",
    width = 152,
    height = 120,
    line_length = 5,
    frame_count = 60,
    direction_count = 1,
    priority = "high",
    animation_speed = 0.125,
    flags = {"smoke"},
    tint = {r = 0.2, g = 0.2, b = 0.2},
    shift = {-4, -4},
    scale = 18,
    blend_mode = "additive"
}
local waterBarrierSmokeHeavy = Utils.DeepCopy(waterBarrierSmokeLight)
waterBarrierSmokeHeavy.name = Constants.ModName .. "-water_barrier_smoke_heavy"
waterBarrierSmokeHeavy.tint = {r = 0.4, g = 0.4, b = 0.4}
data:extend(
    {
        waterBarrierSmokeLight,
        waterBarrierSmokeHeavy
    }
)
