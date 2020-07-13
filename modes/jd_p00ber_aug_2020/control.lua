local Events = require("utility/events")
local Utils = require("utility/utils")
local Logging = require("utility/logging")

if settings.startup["jdplays_mode"].value ~= "jd_p00ber_aug_2020" then
    return
end

local function CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
Events.RegisterEvent(defines.events.on_player_created)
