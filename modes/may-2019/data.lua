local Constants = require("constants")
local modeFilePath = "modes/may-2019"

if settings.startup["jdplays_mode"].value ~= "may-2019" then
    return
end

data.raw["character-corpse"]["character-corpse"].icon = Constants.AssetModName .. "/" .. modeFilePath .. "/graphics/character-corpse.png"
data.raw["character-corpse"]["character-corpse"].icon_size = 180

--[[data:extend(
    {
        {}
    }
)]]
