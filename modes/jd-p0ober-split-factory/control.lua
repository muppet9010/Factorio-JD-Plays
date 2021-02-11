local EventScheduler = require("utility/event-scheduler")
local PlayerHome = require("modes/jd-p0ober-split-factory/scripts/player-home")
local Divider = require("modes/jd-p0ober-split-factory/scripts/divider")
local Teleporter = require("modes/jd-p0ober-split-factory/scripts/teleporter")

if settings.startup["jdplays_mode"].value ~= "jd_p0ober_split_factory" then
    return
end

local function CreateGlobals()
    PlayerHome.CreateGlobals()
    Divider.CreateGlobals()
    Teleporter.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    PlayerHome.OnLoad()
    Divider.OnLoad()
    Teleporter.OnLoad()
end

local function OnSettingChanged(event)
    --if event == nil or event.setting == "xxxxx" then
    --	local x = tonumber(settings.global["xxxxx"].value)
    --end
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    OnSettingChanged(nil)

    PlayerHome.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
