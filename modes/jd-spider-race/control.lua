local EventScheduler = require("utility/event-scheduler")
local Spider = require("modes.jd-spider-race.scripts.spider")

if settings.startup["jdplays_mode"].value ~= "jd_spider_race" then
    return
end

local function CreateGlobals()
    Spider.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    Spider.OnLoad()
end

--local function OnSettingChanged(event)
--if event == nil or event.setting == "xxxxx" then
--	local x = tonumber(settings.global["xxxxx"].value)
--end
--end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    --OnSettingChanged(nil)

    -- DO AFTER TEAMS ARE MADE
    Spider.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
