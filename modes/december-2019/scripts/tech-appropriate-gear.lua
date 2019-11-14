local Events = require("utility/events")
local TechAppropriateGear = {}
local testing = false

local function ClearPlayerInventories(player)
    player.get_main_inventory().clear()
    player.get_inventory(defines.inventory.character_ammo).clear()
    player.get_inventory(defines.inventory.character_guns).clear()
end

TechAppropriateGear.CreateGlobals = function()
    global.TechAppropriateGear = global.TechAppropriateGear or {}
    global.TechAppropriateGear.SpawnItems = global.TechAppropriateGear.SpawnItems or {}
    global.TechAppropriateGear.SpawnItems["gun"] = global.TechAppropriateGear.SpawnItems["gun"] or "pistol"
    global.TechAppropriateGear.SpawnItems["ammo"] = global.TechAppropriateGear.SpawnItems["ammo"] or "firearm-magazine"
end

TechAppropriateGear.OnLoad = function()
    Events.RegisterHandler(defines.events.on_research_finished, "TechAppropriateGear", TechAppropriateGear.OnResearchFinished)
    Events.RegisterHandler(defines.events.on_player_created, "TechAppropriateGear", TechAppropriateGear.OnPlayerCreated)
    Events.RegisterHandler(defines.events.on_player_respawned, "TechAppropriateGear", TechAppropriateGear.OnPlayerRespawned)
end

TechAppropriateGear.OnPlayerCreated = function(event)
    local player = game.get_player(event.player_index)

    ClearPlayerInventories(player)
    player.insert {name = global.TechAppropriateGear.SpawnItems["gun"], count = 1}
    player.insert {name = global.TechAppropriateGear.SpawnItems["ammo"], count = 10}
    player.insert {name = "iron-plate", count = 8}
    player.insert {name = "wood", count = 1}
    player.insert {name = "burner-mining-drill", count = 1}
    player.insert {name = "stone-furnace", count = 1}

    if testing then
        player.insert {name = "grenade", count = 10}
        player.insert {name = "modular-armor", count = 1}
    end
end

TechAppropriateGear.OnPlayerRespawned = function(event)
    local player = game.get_player(event.player_index)
    ClearPlayerInventories(player)
    player.insert {name = global.TechAppropriateGear.SpawnItems["gun"], count = 1}
    player.insert {name = global.TechAppropriateGear.SpawnItems["ammo"], count = 10}

    if testing then
        player.insert {name = "grenade", count = 10}
        player.insert {name = "modular-armor", count = 1}
    end
end

TechAppropriateGear.OnResearchFinished = function(event)
    local technology = event.research
    if technology.name == "military" then
        global.SpawnItems["gun"] = "submachine-gun"
    elseif technology.name == "military-2" then
        global.SpawnItems["ammo"] = "piercing-rounds-magazine"
    elseif technology.name == "uranium-ammo" then
        global.SpawnItems["ammo"] = "uranium-rounds-magazine"
    end
end

return TechAppropriateGear
