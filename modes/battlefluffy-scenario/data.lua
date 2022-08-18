if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end

--[[
    Lasers and electric type weapons just work.
    Atomic bombs (rockets) just work.
]]

local bulletLight = {
    intensity = 0.3,
    size = 5,
    minimum_darkness = 0.3
}


local graphicsPath = "__jd_plays__/graphics/battlefluffy-scenario/"


-- Create the blank animations that set how long light-explosions last and thus how long the light is visible for.
local BlankAnimation10Ticks = {
    filename = graphicsPath .. "empty_10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 10,
}
local BlankAnimation20Ticks = {
    filename = graphicsPath .. "empty_30.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 20,
}
local BlankAnimation30Ticks = {
    filename = graphicsPath .. "empty_30.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    frame_count = 30,
}


-- Create the various light-explosions. Used to create a short light when something is shot.
data:extend({
    {
        type = "explosion",
        name = "light-explosion-bullet-source",
        animations = BlankAnimation10Ticks,
        light = {
            bulletLight
        }
    },
    {
        type = "explosion",
        name = "light-explosion-rocket-source",
        animations = BlankAnimation10Ticks,
        light = {
            {
                intensity = 0.6,
                size = 8,
                minimum_darkness = 0.3,
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-tank-source",
        animations = BlankAnimation20Ticks,
        light = {
            {
                intensity = 1,
                size = 30,
                minimum_darkness = 0.3,
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-artillery-source",
        animations = BlankAnimation30Ticks,
        light = {
            {
                intensity = 1,
                size = 60,
                minimum_darkness = 0.3,
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-explosive-impact",
        animations = BlankAnimation10Ticks,
        light = {
            {
                intensity = 1,
                size = 20,
                minimum_darkness = 0.3,
            }
        }
    }

})



-- Increase the light from fire on the ground and trees. As the default is too low for these very dark maps.
for _, prototype in pairs(data.raw["fire"]) do
    -- Only a fire type that that does fire damage, so excludes acid spit.
    if prototype.damage_per_tick ~= nil and prototype.damage_per_tick.type --[[@as string]] ~= nil and prototype.damage_per_tick.type --[[@as string]] == "fire" then
        -- Default is: light = {intensity = 0.2, size = 8, color = {1, 0.5, 0}},
        prototype.light = { { intensity = 0.4, size = 30, color = { 1, 0.5, 0 } } }
    end
end



-- Apply the lights to things. Projectiles can have an area light on them (or rotated via rendering) or a light-explosion on the source or target. Items can have a light-explosion on the source or target.


--- Ensures a prototypes field is an array rather than a single entry and that it exists.
---@param container table<string, any>
---@param fieldName string
local EnsureFieldIsArrayInContainer = function(container, fieldName)
    local thing = container[fieldName]
    if thing == nil then
        -- Non existant, so create the empty table so the later code works.
        container[fieldName] = {}
    elseif type(next(thing)) == "string" then
        -- Is a single entry rather than a table of entries so we will convert it to a table of entries so we can handle it in a standard way.
        container[fieldName] = { thing }
    end
end

local ProjectilesToModify = {} ---@type table<string, string> # projectileName to its ammo category.

--- Record the prototypes that this ammo type creates.
---@param action TriggerItem[]
---@param ammoCategory string
local RecordProjectileNameToAmmoCategory = function(action, ammoCategory)
    for _, triggerItem in pairs(action) do
        EnsureFieldIsArrayInContainer(triggerItem, "action_delivery")
        for _, triggerDelivery in pairs(triggerItem.action_delivery--[[@as TriggerDelivery[] ]] ) do
            if triggerDelivery.type == "projectile" then
                ---@cast triggerDelivery ProjectileTriggerDelivery
                ProjectilesToModify[triggerDelivery.projectile] = ammoCategory
            end
        end
    end
end

-- Go over each ammo prototype and add what we need based on its category. We just add a new action to avoid any conflicts with others.
-- Also capture all of the projectiles that we need to modify based on the ammo's of the correct type that create them.
for _, prototype in pairs(data.raw["ammo"]) do
    local ammoCategory = prototype.ammo_type.category
    if ammoCategory == "bullet" or ammoCategory == "shotgun-shell" then
        -- Does machine guns and shotguns for shooting.
        EnsureFieldIsArrayInContainer(prototype.ammo_type, "action")
        local action = prototype.ammo_type.action
        action[#action + 1] = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = { type = "create-explosion", entity_name = "light-explosion-bullet-source" }
            }
        }
    elseif ammoCategory == "rocket" then
        -- Does all rockets for shooting.
        EnsureFieldIsArrayInContainer(prototype.ammo_type, "action")
        local action = prototype.ammo_type.action --[[@cast action - nil # We made sure its not nil in above function]]
        action[#action + 1] = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = { type = "create-explosion", entity_name = "light-explosion-rocket-source" }
            }
        }
        RecordProjectileNameToAmmoCategory(action, ammoCategory)
    elseif ammoCategory == "cannon-shell" then
        -- Does all tank shells for shooting.
        EnsureFieldIsArrayInContainer(prototype.ammo_type, "action")
        local action = prototype.ammo_type.action --[[@cast action - nil # We made sure its not nil in above function]]
        action[#action + 1] = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = { type = "create-explosion", entity_name = "light-explosion-tank-source" }
            }
        }
        RecordProjectileNameToAmmoCategory(action, ammoCategory)
    elseif ammoCategory == "artillery-shell" then
        -- Does all artillery shells for shooting.
        EnsureFieldIsArrayInContainer(prototype.ammo_type, "action")
        local action = prototype.ammo_type.action --[[@cast action - nil # We made sure its not nil in above function]]
        action[#action + 1] = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = { type = "create-explosion", entity_name = "light-explosion-artillery-source" }
            }
        }
        RecordProjectileNameToAmmoCategory(action, ammoCategory)
    end
end


-- Go over each projectile prototype and if it was flagged by the ammo type that made it add what we need based on its ammo category. We just add a new action to avoid any conflicts with others.
-- CODE NOTE: If doing the specific explosions types doesn't work out, check in both action and final_action for nested area effect then include light on the impact. need to do this so we can control how long the light is there.
for projectileName, prototype in pairs(data.raw["projectile"]) do
    local projectileModifyType = ProjectilesToModify[projectileName]
    if projectileModifyType == "rocket" then
        -- Is a type of rocket.
        if prototype.created_effect ~= nil then
            error("we don't handle this")
        end
        prototype.created_effect = {
            type = "direct",
            action_delivery = {
                type = "instant",
                source_effects = {
                    {
                        type = "script",
                        effect_id = "rocket-projectile"
                    },
                }
            }
        }
        prototype.light = {
            {
                intensity = 0.2,
                size = 3,
                minimum_darkness = 0.3,
                shift = { 0, -1 }
            }
        }
    elseif projectileModifyType == "tank-shell" then
    elseif projectileModifyType == "artillery-shell" then
    end
end


-- Go over the stream types and add light to the fire ones.
for _, prototype in pairs(data.raw["stream"]) do
    -- Only fire streams have smoke from them.
    if prototype.smoke_sources ~= nil then
        prototype.stream_light = { intensity = 0.3, size = 12, color = { 1, 0.5, 0 } }
        -- ground_light is terrible
    end
end



-- Add lights to the larger explosions that are only cause by explosives and not just projectile impacts.
-- TODO: move these to be our own explosions as we can't control how long the light is present for with these.
data.raw["explosion"]["big-explosion"].light = {
    {
        intensity = 1,
        size = 30,
        minimum_darkness = 0.3,
    }
}
data.raw["explosion"]["uranium-cannon-shell-explosion"].light = {
    {
        intensity = 1,
        size = 30,
        minimum_darkness = 0.3,
    }
}
data.raw["explosion"]["big-artillery-explosion"].light = {
    {
        intensity = 1,
        size = 30,
        minimum_darkness = 0.3,
    }
}



-- Flying robots that shoot bullets we can pickup via their use of the source shooting explosion
data.raw["explosion"]["explosion-gunshot-small"].light = {
    bulletLight
}



-- Sprites used by Rendering as can't do rotations correctly from prototype lights.
--[[
    - Image has to have a black background to stop any auto cropping of the sprite pre rotating to the projectile's position.
    - Square image size so it rotates cleanly.
]]

data:extend({
    {
        type = "sprite",
        name = "light_cone-rear_ended",
        filename = graphicsPath .. "light_cone-rear_ended.png",
        priority = "extra-high",
        flags = { "light" },
        width = 400,
        height = 400
    }
})
