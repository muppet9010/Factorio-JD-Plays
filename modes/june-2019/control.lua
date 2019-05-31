local testing = false

if settings.startup["jdplays_mode"].value ~= "june-2019" then
    return
end



local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)

    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}
    player.insert {name = "iron-plate", count = 8}
    player.insert {name = "wood", count = 1}
    player.insert {name = "burner-mining-drill", count = 1}
    player.insert {name = "stone-furnace", count = 1}

    if testing then
        player.insert {name = "grenade", count = 10}
        player.insert {name = "modular-armor", count = 1}
    end

    player.print({"messages.jd_plays-june-2019-welcome1"})
end

local function OnPlayerRespawned(event)
    local player = game.get_player(event.player_index)
    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}

    if testing then
        player.insert {name = "grenade", count = 10}
        player.insert {name = "modular-armor", count = 1}
    end
end

script.on_event(defines.events.on_player_created, OnPlayerCreated)
script.on_event(defines.events.on_player_respawned, OnPlayerRespawned)