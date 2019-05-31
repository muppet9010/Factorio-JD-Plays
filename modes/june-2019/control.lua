local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "june-2019" then
    return
end

function GenerateTrees(event)
	local tree_chance = 0.2
	local surface = event.surface
	local minX = event.area.left_top.x
	local minY = event.area.left_top.y
	local maxX = event.area.right_bottom.x
    local maxY = event.area.right_bottom.y

    local trees = {}
    if remote.interfaces["biter_reincarnation"] == nil then
        for _, entityType in pairs(game.entity_prototypes) do
            if entityType.type == "tree" then
                table.insert(trees, entityType.name)
            end
        end
    end

	for x = minX, maxX do
		for y = minY, maxY do
            if math.random() < tree_chance then
                local position = {x, y}
                local tree_type = nil
                if #trees > 0 then
                    tree_type = trees[math.random(#trees)]
                else
                    tree_type = remote.call("biter_reincarnation", "get_random_tree_type_for_position", surface, position)
                end
                if tree_type ~= nil and surface.can_place_entity{name = tree_type, position = position} then
					surface.create_entity{name = tree_type, position = position}
				end
			end
		end
	end
end

local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)

    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}
    player.insert {name = "iron-plate", count = 8}
    player.insert {name = "wood", count = 1}
    player.insert {name = "burner-mining-drill", count = 1}
    player.insert {name = "stone-furnace", count = 1}

    player.print({"messages.jd_plays-june-2019-welcome1"})
end

local function OnPlayerRespawned(event)
    local player = game.get_player(event.player_index)
    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}
end

local function OnResearchFinished(event)
    local technology = event.research
    if technology.name == "military" then
        global.SpawnItems["gun"] = "submachine-gun"
    elseif technology.name == "military-2" then
        global.SpawnItems["ammo"] = "piercing-rounds-magazine"
    elseif technology.name == "uranium-ammo" then
        global.SpawnItems["ammo"] = "uranium-rounds-magazine"
    end
end

local function OnStartup()
    global.SpawnItems = global.SpawnItems or {}
    global.SpawnItems["gun"] = global.SpawnItems["gun"] or "pistol"
    global.SpawnItems["ammo"] = global.SpawnItems["ammo"] or "firearm-magazine"
    Utils.SetStartingMapReveal(10)
    Utils.ClearSpawnRespawnItems()
    Utils.DisableIntroMessage()
    Utils.DisableWinOnRocket()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_player_created, OnPlayerCreated)
script.on_event(defines.events.on_player_respawned, OnPlayerRespawned)
script.on_event(defines.events.on_research_finished, OnResearchFinished)
script.on_event(defines.events.on_chunk_generated, GenerateTrees)