local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local modeFilePath = "modes/december-2019"
local BiterHuntGroup = require(modeFilePath .. "/scripts/biter-hunt-group")
local TechAppropriateGear = require(modeFilePath .. "/scripts/tech-appropriate-gear")
local SharedPlayerDamage = require(modeFilePath .. "/scripts/shared-player-damage")
local RocketSilo = require(modeFilePath .. "/scripts/rocket-silo")
local WaterBarrier = require(modeFilePath .. "/scripts/water-barrier")
local GenerateTrees = require(modeFilePath .. "/scripts/generate-trees")
local RocksToBiterEggs = require(modeFilePath .. "/scripts/rocks-to-biter-eggs")
local MapCleanse = require(modeFilePath .. "/scripts/map-cleanse")
local Commands = require("utility/commands")
local Logging = require("utility/logging")

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
    RocketSilo.CreateGlobals()
    WaterBarrier.CreateGlobals()
    RocksToBiterEggs.CreateGlobals()
    MapCleanse.CreateGlobals()
end

local function OnLoad()
    Events.RegisterHandler(defines.events.on_player_created, "control", OnPlayerCreated)
    Utils.DisableSiloScript()

    TechAppropriateGear.OnLoad()
    BiterHuntGroup.OnLoad()
    SharedPlayerDamage.OnLoad()
    RocketSilo.OnLoad()
    WaterBarrier.OnLoad()
    GenerateTrees.OnLoad()
    RocksToBiterEggs.OnLoad()
    MapCleanse.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    Utils.DisableWinOnRocket()
    Utils.DisableIntroMessage()
    Utils.ClearSpawnRespawnItems()

    BiterHuntGroup.OnStartup()
    SharedPlayerDamage.OnStartup()
    RocketSilo.OnStartup()
    WaterBarrier.OnStartup()
    RocksToBiterEggs.OnStartup()
end

--[[
    A command to be used as a one off to remove the old duplicate & bad scheduled events and to trigger them to be re-added cleanly. The changes to fix scheduled event crashes is what stops the issue re-occuring.
]]
local function FixScheduledEvents()
    Logging.Log(Utils.TableContentsToJSON(global.UTILITYSCHEDULEDFUNCTIONS, "scheduled stuff before:"))
    EventScheduler.RemoveScheduledEvents("WaterBarrier.CheckPlayerPositions", nil, nil)
    EventScheduler.RemoveScheduledEvents("WaterBarrier.DamageThings", nil, nil)
    EventScheduler.RemoveScheduledEvents("BiterHuntGroup.On10Ticks", nil, nil)
    WaterBarrier.OnStartup()
    BiterHuntGroup.OnStartup()
    Logging.Log(Utils.TableContentsToJSON(global.UTILITYSCHEDULEDFUNCTIONS, "scheduled stuff after:"))
    game.print("Scheduled Events Fixed")
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
Events.RegisterEvent(defines.events.on_chunk_generated)
Events.RegisterEvent(defines.events.on_built_entity)
Events.RegisterEvent(defines.events.on_robot_built_entity)
Events.RegisterEvent(defines.events.on_player_driving_changed_state)
Events.RegisterEvent(defines.events.on_player_left_game)
EventScheduler.RegisterScheduler()
Commands.Register("december_2019_fix_scheduled_events", ": fix scheduled events from previous versions", FixScheduledEvents, true)
