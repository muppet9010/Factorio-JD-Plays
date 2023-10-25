-- IF YOU FIND THIS DON'T POST IN DISCORD ABOUT IT. DIRECT MESSAGE MUPPET IF YOU WANT TO CHAT ABOUT IT.
--TODO: hidden feature for now.

local Constants = require('constants')

if 1 == 1 then
    return
end

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

-- Add the custom avatar gravestones. This will leave the remaining ones as the blank gravestone.
local graveWithHeadstonePrototype = data.raw["simple-entity"]["zombie_engineer-grave_with_headstone"]
if graveWithHeadstonePrototype ~= nil then
    for index, imageName in pairs({ "Bilbo", "BTG", "Fox", "Huff", "JD", "Muppet", "Sorahn" }) do
        graveWithHeadstonePrototype.pictures[index] =
        {
            filename = Constants.AssetModName .. "/modes/halloween-2023/graphics/zombie-engineer/" .. imageName .. ".png",
            width = 140,
            height = 181,
            scale = 0.5,
            shift = { 0.1, 0.3 }
        } --[[@as data.Sprite ]]
    end
end
