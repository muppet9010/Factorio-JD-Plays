local Events = require("utility.events")
local EventScheduler = require("utility.event-scheduler")

if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end



-- Just have to add this via rendering and not data stage as oriented lights on Projectiles ignore the orientation and just face north.
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



--[[
    Modify the camp-fire entity if its present from the fire-place mod.
    This is for JD's play through only. We will create them purely via Muppet Streamer mod's Spawn Around Player feature.
    We want to give it fuel on creaton (so Muppet Streamer doesn't need changing), and then remove it after a set period once its been created.
]]
local campFireTTLTicksMin, campFireTTLRandomMax = 1800, 1800 -- Between 330 and 60 seconds.

---@class BattlefluffyScenario_RemoveCampFire_Scheduled_EventData
---@field entity LuaEntity

--- Called when a camp fire is created so we can auto fuel it and register it for automatic future removal.
---@param event on_built_entity|script_raised_built|script_raised_revive|on_robot_built_entity
local CampFireBuilt = function(event)
    local entity = event.entity or event.created_entity
    entity.insert({ name = "nuclear-fuel", count = 2 }) -- Will run for a long time.
    entity.operable = false

    local removeTick = event.tick + campFireTTLTicksMin + math.random(0, campFireTTLRandomMax) ---@cast removeTick Tick
    EventScheduler.ScheduleEventOnce(removeTick, "RemoveCampFire_Scheduled", entity.unit_number--[[@as StringOrNumber]] , { entity = entity })
end

--- Called to remove a specific camp fire.
---@param event UtilityScheduledEvent_CallbackObject
local RemoveCampFire_Scheduled = function(event)
    local data = event.data ---@type BattlefluffyScenario_RemoveCampFire_Scheduled_EventData
    if data.entity.valid then
        data.entity.destroy({ raise_destroy = true })
    end
end



local function CreateGlobals()
end

local function OnLoad()
    Events.RegisterHandlerEvent(defines.events.on_script_trigger_effect, "OnScriptTriggerEffectEvent", OnScriptTriggerEffectEvent)

    local builtFilter = {
        { filter = "name", name = "camp-fire" },
    }
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "CampFireBuilt", CampFireBuilt, builtFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "CampFireBuilt", CampFireBuilt, builtFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "CampFireBuilt", CampFireBuilt, builtFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "CampFireBuilt", CampFireBuilt, builtFilter)

    EventScheduler.RegisterScheduler()
    EventScheduler.RegisterScheduledEventType("RemoveCampFire_Scheduled", RemoveCampFire_Scheduled)
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
