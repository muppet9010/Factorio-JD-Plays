local Events = require("utility.events")

if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end

local ExplosionColor = { r = 246.0, g = 248.0, b = 182.0 } -- Same as in data.

---@param event on_script_trigger_effect
local OnScriptTriggerEffectEvent = function(event)
    if event.effect_id == "rocket-projectile" then
        rendering.draw_light {
            sprite = "light_cone-rear_ended",
            orientation = 0.5,
            scale = 0.3,
            intensity = 0.3,
            minimum_darkness = 0.3,
            oriented = true,
            color = ExplosionColor,
            target = event.source_entity,
            target_offset = { 0, -1 }, -- Needed as projectile images are 1 tile offset from their real position to give the appearance of height.
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
