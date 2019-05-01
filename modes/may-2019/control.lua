local BiterHuntGroup = require("modes/may-2019/biter-hunt-group")
local GUIUtil = require("utility/gui-util")

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

    --TODO testing
    player.insert {name = "grenade", count = 10}
    player.insert {name = "modular-armor", count = 1}

    player.print({"messages.jd_plays_welcome1"})
end

local function OnPlayerRespawned(event)
    local player = game.get_player(event.player_index)
    ClearPlayerInventories(player)
    player.insert {name = global.SpawnItems["gun"], count = 1}
    player.insert {name = global.SpawnItems["ammo"], count = 10}

    --TODO testing
    player.insert {name = "grenade", count = 10}
    player.insert {name = "modular-armor", count = 1}
end

local function OnStartup()
    global.SpawnItems = global.SpawnItems or {}
    global.SpawnItems["gun"] = global.SpawnItems["gun"] or "pistol"
    global.SpawnItems["ammo"] = global.SpawnItems["ammo"] or "firearm-magazine"
    global.BiterHuntGroupUnits = global.BiterHuntGroupUnits or {}
    global.BiterHuntGroupResults = global.BiterHuntGroupResults or {}
    global.biterHuntGroupId = global.biterHuntGroupId or 0
    if global.nextBiterHuntGroupTick == nil then
        global.nextBiterHuntGroupTick = game.tick
        BiterHuntGroup.ScheduleNextBiterHuntGroup()
    end
    GUIUtil.CreateAllPlayersElementReferenceStorage()
    BiterHuntGroup.GuiRecreateAll()
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

local function OnPlayerJoinedGame(event)
    local player = game.get_player(event.player_index)
    BiterHuntGroup.GuiCreate(player)
end

local function OnPlayerLeftGame(event)
    local player = game.get_player(event.player_index)
    BiterHuntGroup.GuiDestroy(player)
end

local function On60Ticks()
    BiterHuntGroup.GuiUpdateAll()
end

local function OnFrequentTicks(event)
    local tick = event.tick
    BiterHuntGroup.FrequentTick(tick)
end

local function OnPlayerDied(event)
    local player = game.get_player(event.player_index)
    BiterHuntGroup.PlayerDied(player)
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_player_created, OnPlayerCreated)
script.on_event(defines.events.on_player_respawned, OnPlayerRespawned)
script.on_event(defines.events.on_research_finished, OnResearchFinished)
script.on_event(defines.events.on_player_joined_game, OnPlayerJoinedGame)
script.on_event(defines.events.on_player_left_game, OnPlayerLeftGame)
script.on_event(defines.events.on_player_died, OnPlayerDied)
script.on_nth_tick(60, On60Ticks)
script.on_nth_tick(10, OnFrequentTicks)
