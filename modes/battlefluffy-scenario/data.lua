if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end

local graphicsPath = "__jd_plays__/graphics/battlefluffy-scenario/"

local BlankAnimation10Ticks = function()
    return {
        filename = graphicsPath .. "empty_10.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 10,
    }
end

data:extend({
    {
        type = "explosion",
        name = "light-explosion-bullet-source",
        animations = BlankAnimation10Ticks(),
        light = {
            {
                intensity = 0.3,
                size = 5,
                minimum_darkness = 0.3
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-rocket-source",
        animations = BlankAnimation10Ticks(),
        light = {
            {
                intensity = 0.6,
                size = 8,
                minimum_darkness = 0.3,
            }
        }
    }

})

--[[
data.raw["explosion"]["light-tank-shell-source"] = {}
data.raw["explosion"]["light-flamer-source"] = {}
data.raw["explosion"]["light-rocket-impact"] = {}
data.raw["explosion"]["light-rocket-explosive-impact"] = {}
data.raw["explosion"]["light-tank-shell-explosive-impact"] = {}
]]
--light = { intensity = 1, size = 3, color = { r = 1.0, g = 1.0, b = 1.0 } }

--TODO: fire lights, flamer stream.




-- Apply the lights to things. Projectiles can have a light on them or a light-explosion on the source or target. Items can have a light-explosion on the source or target.

local piercingAmmoInstantActionDelivery = data.raw["ammo"]["piercing-rounds-magazine"].ammo_type.action--[[@as DirectTriggerItem]] .action_delivery --[[@as InstantTriggerDelivery]]
piercingAmmoInstantActionDelivery.source_effects = { piercingAmmoInstantActionDelivery.source_effects, { type = "create-explosion", entity_name = "light-explosion-bullet-source" } }

local rocketAmmoInstantActionDelivery = data.raw["ammo"]["rocket"].ammo_type.action--[[@as DirectTriggerItem]] .action_delivery --[[@as InstantTriggerDelivery]]
rocketAmmoInstantActionDelivery.source_effects = { rocketAmmoInstantActionDelivery.source_effects, { type = "create-explosion", entity_name = "light-explosion-rocket-source" } }

--data.raw["gun"]["rocket-launcher"].attack_parameters.ammo_type = { action = { source_effects = {} } --[[@as InstantTriggerDelivery]] }


data.raw["projectile"]["rocket"].created_effect = {
    type = "direct",
    action_delivery = {
        type = "instant",
        source_effects = {
            type = "script",
            effect_id = "rocket-projectile"
        }
    }
}




data:extend({
    {
        type = "sprite",
        name = "light_cone-one_sided",
        filename = graphicsPath .. "light_cone-one_sided.png",
        priority = "extra-high",
        flags = { "light" },
        width = 400,
        height = 400
    }
})
