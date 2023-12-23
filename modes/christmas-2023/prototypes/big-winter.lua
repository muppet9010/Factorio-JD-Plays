local Constants = require('constants')
local Utils = require("utility.utils")

if settings.startup["jdplays_mode"].value ~= "christmas_2023" then
    return
end

if mods["BigWinter"] == nil then
    return
end

-- Grass-1 and Dirt-4 don't have their assets changed by BigWinter due to a bug/design choice. So do it here instead.
-- All code, graphics and values lifted from Big Winter version 1.1.2.



local pictures = {
    { picture = "__base__/graphics/terrain/grass-1.png",    folder = 'grass', name = 'grass-1.png' },
    { picture = "__base__/graphics/terrain/hr-grass-1.png", folder = 'grass', name = 'hr-grass-1.png' },
    { picture = "__base__/graphics/terrain/dirt-4.png",     folder = 'dirt',  name = 'dirt-4.png' },
    { picture = "__base__/graphics/terrain/hr-dirt-4.png",  folder = 'dirt',  name = 'hr-dirt-4.png' },
}

local tile_map_colors = {
    ["grass-1"] = { r = 157, g = 178, b = 211 },
    ["dirt-4"] = { r = 203, g = 213, b = 229 }
}

local tile = data.raw.tile['dirt-4']
if tile then
    tile.layer = 50 -- https://forums.factorio.com/viewtopic.php?f=25&t=75935&p=458283#p458283
end
for i, tile in pairs(data.raw.tile) do
    tile.transitions = Utils.DeepCopy(tile.transitions)
end

---@param handler data.TileSpriteWithProbability
---@return boolean
function try_replace(handler)
    for i, v in pairs(pictures) do
        if handler.picture == v.picture then
            local picture = Constants.AssetModName .. "/modes/christmas-2023/graphics/" .. v.name
            --	log ('replaced ["'..handler.picture..'"] to ["'..picture..'"]')
            handler.picture = picture
            return true
        end
    end
    return false
end

for tile_name, tile in pairs(data.raw.tile) do
    if tile_map_colors[tile_name] ~= nil and tile.variants and tile.variants.main then
        local main = tile.variants.main
        for j, v in pairs(main) do
            local handlers = { v, v.hr_version }
            for k, handler in pairs(handlers) do
                try_replace(handler)
            end
        end
    end

    if tile_map_colors[tile_name] then
        tile.map_color = tile_map_colors[tile_name]
    end
end
