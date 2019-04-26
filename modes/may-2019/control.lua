if settings.startup["jdplays_mode"].value ~= "may-2019" then
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
    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}
    player.insert {name = "iron-plate", count = 8}
    player.insert {name = "wood", count = 1}
    player.insert {name = "burner-mining-drill", count = 1}
    player.insert {name = "stone-furnace", count = 1}

    player.print({"messages.welcome1"})
end

local function OnPlayerRespawned(event)
    local player = game.get_player(event.player_index)
    ClearPlayerInventories(player)
    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}
end

local function OnStartup()
    global.SpawnItems = global.SpawnItems or {}
    global.SpawnItems["gun"] = global.SpawnItems["gun"] or "pistol"
    global.SpawnItems["ammo"] = global.SpawnItems["ammo"] or "firearm-magazine"
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

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_player_created, OnPlayerCreated)
script.on_event(defines.events.on_player_respawned, OnPlayerRespawned)
script.on_event(defines.events.on_research_finished, OnResearchFinished)
