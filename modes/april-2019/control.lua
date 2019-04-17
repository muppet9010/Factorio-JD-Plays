if settings.startup["jdplays_mode"].value ~= "april-2019" then
    return
end

local function ClearPlayerInventories(player)
    player.get_main_inventory().clear()
    player.get_inventory(defines.inventory.player_ammo).clear()
    player.get_inventory(defines.inventory.player_guns).clear()
end

local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)

    ClearPlayerInventories(player)
    player.insert {name = "submachine-gun", count = 1}
    player.insert {name = "piercing-rounds-magazine", count = 10}
    player.insert {name = "iron-plate", count = 10}
    player.insert {name = "centrifuge", count = 5}
    player.insert {name = "burner-mining-drill", count = 3}
    player.insert {name = "stone-furnace", count = 3}
    player.insert {name = "medium-electric-pole", count = 10}

    player.print("Welcome to April, here is egg in your face...")
end

local function OnPlayerRespawned(event)
    local player = game.get_player(event.player_index)
    ClearPlayerInventories(player)
    player.insert {name = "submachine-gun", count = 1}
    player.insert {name = "piercing-rounds-magazine", count = 10}
end

local function OnStartup()
    if game.forces["player"].recipes["stone-enrichment-process"] ~= nil then
        game.forces["player"].recipes["stone-enrichment-process"].enabled = true
    end
end

local rockTypes = {
    "rock-huge",
    "rock-big"
}
local function GenerateRocks(surface, area)
    local chance = 0.2
    local minx = area.left_top.x
    local miny = area.left_top.y
    local maxx = area.right_bottom.x
    local maxy = area.right_bottom.y

    for x = minx, maxx do
        for y = miny, maxy do
            if math.random() < chance then
                local entityType = rockTypes[math.random(#rockTypes)]
                if surface.can_place_entity {name = entityType, position = {x, y}} then
                    surface.create_entity {name = entityType, position = {x, y}}
                end
            end
        end
    end
end

local function OnChunkGenerated(event)
    local surface = event.surface
    local area = event.area
    GenerateRocks(surface, area)
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_player_created, OnPlayerCreated)
script.on_event(defines.events.on_player_respawned, OnPlayerRespawned)
script.on_event(defines.events.on_chunk_generated, OnChunkGenerated)
