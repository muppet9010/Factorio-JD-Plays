local Events = require("utility.events")

if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end

---@param event on_script_trigger_effect
local OnScriptTriggerEffectEvent = function(event)
    if event.effect_id == "rocket-projectile" then
        rendering.draw_light {
            sprite = "light_cone-one_sided",
            orientation = 0.5,
            scale = 0.5,
            intensity = 0.6,
            minimum_darkness = 0.3,
            oriented = true,
            target = event.source_entity,
            surface = event.surface_index
        }
    end
end

local function CreateGlobals()
end

local function OnLoad()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "OnScriptTriggerEffectEvent", OnScriptTriggerEffectEvent)
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
