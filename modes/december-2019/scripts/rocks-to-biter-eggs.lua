local RocksToBiterEggs = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
--local Logging = require("utility/logging")

local rocksToBiterEggConversion = {
    ["rock-huge"] = "biter-egg-nest-large",
    ["sand-rock-huge"] = "biter-egg-nest-large",
    ["rock-big"] = "biter-egg-nest-small",
    ["sand-rock-big"] = "biter-egg-nest-small"
}
local rocksToBeConverted = Utils.TableKeyToArray(rocksToBiterEggConversion)

RocksToBiterEggs.CreateGlobals = function()
    global.RocksToBiterEggs = global.RocksToBiterEggs or {}
    global.RocksToBiterEggs.biterEggModPresent = global.RocksToBiterEggs.biterEggModPresent or false
	global.RocksToBiterEggs.eggNestCollisonBoxes = global.RocksToBiterEggs.eggNestCollisonBoxes or {}
end

RocksToBiterEggs.OnLoad = function()
    Events.RegisterHandler(defines.events.on_chunk_generated, "RocksToBiterEggs.OnChunkGenerated", RocksToBiterEggs.OnChunkGenerated)
end

RocksToBiterEggs.OnStartup = function()
    for modName, _ in pairs(game.active_mods) do
        if modName == "biter_eggs" then
            global.RocksToBiterEggs.biterEggModPresent = true
            break
        end
    end
	for _, eggNestName in pairs(rocksToBiterEggConversion) do
		global.RocksToBiterEggs.eggNestCollisonBoxes[eggNestName] = game.entity_prototypes[eggNestName].collision_box
	end
end

RocksToBiterEggs.OnChunkGenerated = function(event)
    if not global.RocksToBiterEggs.biterEggModPresent then
        return
    end

    local surface = event.surface
    local rocksInChunk = surface.find_entities_filtered {area = event.area, name = rocksToBeConverted}
    for _, rockEntity in pairs(rocksInChunk) do
        local pos = rockEntity.position
        local eggNestName = rocksToBiterEggConversion[rockEntity.name]
        local entityFootprint = Utils.ApplyBoundingBoxToPosition(pos, global.RocksToBiterEggs.eggNestCollisonBoxes[eggNestName])
		surface.destroy_decoratives{area = entityFootprint}
        local createdEggNest = surface.create_entity {name = eggNestName, position = pos, force = "enemy"}
        if createdEggNest == nil then
            pos = surface.find_non_colliding_position(eggNestName, pos, 5, 0.1)
            if pos ~= nil then
                surface.create_entity {name = eggNestName, position = pos, force = "enemy"}
            end
        end
    end
end

return RocksToBiterEggs
