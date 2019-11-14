local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local BiterHuntGroup = require("modes/december-2019/scripts/biter-hunt-group")
local TechAppropriateGear = require("modes/december-2019/scripts/tech-appropriate-gear")
local SharedPlayerDamage = require("modes/december-2019/scripts/shared-player-damage")

if settings.startup["jdplays_mode"].value ~= "december-2019" then
    return
end

local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)
    player.print({"messages.jd_plays-december-2019-welcome1"})
end

local function CreateGlobals()
    TechAppropriateGear.CreateGlobals()
    BiterHuntGroup.CreateGlobals()
    SharedPlayerDamage.CreateGlobals()
end

local function OnLoad()
    Events.RegisterHandler(defines.events.on_player_created, "control", OnPlayerCreated)
    Utils.DisableSiloScript()

    TechAppropriateGear.OnLoad()
    BiterHuntGroup.OnLoad()
    SharedPlayerDamage.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    Utils.DisableWinOnRocket()
    Utils.DisableIntroMessage()
    Utils.ClearSpawnRespawnItems()

    BiterHuntGroup.OnStartup()
    SharedPlayerDamage.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
Events.RegisterEvent(defines.events.on_player_created)
Events.RegisterEvent(defines.events.on_player_respawned)
Events.RegisterEvent(defines.events.on_research_finished)
Events.RegisterEvent(defines.events.on_player_joined_game)
Events.RegisterEvent(defines.events.on_player_died)
Events.RegisterEvent(defines.events.on_entity_damaged, "type=character", {{filter = "type", type = "character"}})
EventScheduler.RegisterScheduler()
