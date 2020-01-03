local Events = require("utility/events")
local Utils = require("utility/utils")
local modeFilePath = "modes/january-2020"
local GenerateTrees = require(modeFilePath .. "/generate-trees")

if settings.startup["jdplays_mode"].value ~= "january-2020" then
    return
end

local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)
    player.print({"messages.jd_plays-january-2020-welcome1"})
end

local function CreateGlobals()
end

local function OnLoad()
    Events.RegisterHandler(defines.events.on_player_created, "control", OnPlayerCreated)

    GenerateTrees.OnLoad()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    Utils.DisableWinOnRocket()
    Utils.DisableIntroMessage()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
Events.RegisterEvent(defines.events.on_player_created)
Events.RegisterEvent(defines.events.on_chunk_generated)
