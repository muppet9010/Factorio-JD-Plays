local Events = require("utility.events")

if settings.startup["jdplays_mode"].value ~= "halloween_2023" then
    return
end

---@class Class-halloween_2023-CombatLighting
local CombatLighting = {}


-- Just have to add this via rendering and not data stage as oriented lights on Projectiles ignore the orientation and just face north.
-- the below should all be the same as in data.
local ExplosionColor = { r = 246.0, g = 248.0, b = 182.0 }
local MinimumDarkness = 0.2
local DirectLight_Size_Multiplier = 1
local DirectLight_Intensity_Multiplier = 1

CombatLighting.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "OnScriptTriggerEffectEvent", CombatLighting.OnScriptTriggerEffectEvent)
end

---@param event EventData.on_script_trigger_effect
CombatLighting.OnScriptTriggerEffectEvent = function(event)
    if event.effect_id == "rocket-projectile" then
        rendering.draw_light {
            sprite = "light_cone-rear_ended",
            orientation = 0.5,
            scale = 0.4 * DirectLight_Size_Multiplier,
            intensity = 0.4 * DirectLight_Intensity_Multiplier,
            minimum_darkness = MinimumDarkness,
            oriented = true,
            color = ExplosionColor,
            target = event.source_entity,
            target_offset = { 0, -1 }, -- Needed as projectile images are 1 tile offset from their real position to give the appearance of height.
            surface = event.surface_index
        }
    end
end

return CombatLighting
