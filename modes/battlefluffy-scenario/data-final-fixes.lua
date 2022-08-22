--[[
    Do all of these changes in final fixes so hopefully other mods have created all of their bits and we can overwrite them. When made a standalone mod we can always add them as hidden optional dependencies so that we run after them if really needed.

    Lasers and electric type weapons just work.
    Lights are based on Factorio's shooting and impact explosion graphics. So grenades have a light to match their base game explosion graphic (overly large).
]]


if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end




local GraphicsPath = "__jd_plays__/graphics/battlefluffy-scenario/"
local FireColor = { 1, 0.5, 0 }
local ExplosionColor = { r = 246.0, g = 248.0, b = 182.0 } -- Mirrored to control.


-- Create the blank animations that set how long light-explosions last and thus how long the light is visible for.
local BlankAnimation10Ticks = {
    frame_count = 10,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}
local BlankAnimation20Ticks = {
    frame_count = 20,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}
local BlankAnimation30Ticks = {
    frame_count = 30,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}
local BlankAnimation40Ticks = {
    frame_count = 40,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}
local BlankAnimation50Ticks = {
    frame_count = 50,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}
local BlankAnimation200Ticks = {
    frame_count = 100,
    repeat_count = 2,
    filename = GraphicsPath .. "empty_10x10.png",
    priority = "extra-high",
    width = 1,
    height = 1,
    line_length = 10
}



-- Create the various light-explosions. Used to create a short light when something is shot.
data:extend({
    {
        type = "explosion",
        name = "light-explosion-bullet-source",
        animations = BlankAnimation10Ticks,
        light = {
            {
                intensity = 0.3,
                size = 5,
                minimum_darkness = 0.2,
                shift = { 0, -1 }
            }
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
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, -1 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-tank-source",
        animations = BlankAnimation20Ticks,
        light = {
            {
                intensity = 0.8,
                size = 30,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, -1 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-artillery-source",
        animations = BlankAnimation20Ticks,
        light = {
            {
                intensity = 0.8,
                size = 60,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, -1 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-small-explosive-impact",
        animations = BlankAnimation20Ticks,
        light = {
            {
                intensity = 0.6,
                size = 7,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, -0.5 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-medium-explosive-impact",
        animations = BlankAnimation30Ticks,
        light = {
            {
                intensity = 0.7,
                size = 10,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, -0.5 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-large-explosive-impact",
        animations = BlankAnimation40Ticks,
        light = {
            {
                intensity = 0.8,
                size = 15,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, 0 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-massive-explosive-impact",
        animations = BlankAnimation50Ticks,
        light = {
            {
                intensity = 0.8,
                size = 20,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, 0 }
            }
        }
    },
    {
        type = "explosion",
        name = "light-explosion-nuke-explosive-impact",
        animations = BlankAnimation200Ticks,
        light = {
            {
                intensity = 0.8,
                size = 60,
                minimum_darkness = 0.2,
                color = ExplosionColor,
                shift = { 0, 0 }
            }
        }
    }
})



--- Removes the glow from a sprite and its child fields they have it or even exist.
---@param sprite Sprite
local function RemoveGlowFromSpriteContents(sprite)
    if sprite.draw_as_glow ~= nil then sprite.draw_as_glow = false end
    if sprite.hr_version ~= nil then
        if sprite.hr_version.draw_as_glow ~= nil then sprite.hr_version.draw_as_glow = false end
    end
end

--- Removes the glow from an Animation and its child fields they have it or even exist.
---@param animation Animation
local function RemoveGlowFromAnimationContents(animation)
    if animation.draw_as_glow ~= nil then animation.draw_as_glow = false end
    if animation.layers ~= nil then
        for _, layer in pairs(animation.layers) do
            RemoveGlowFromAnimationContents(layer)
        end
    end
    if animation.hr_version ~= nil then
        RemoveGlowFromAnimationContents(animation.hr_version)
    end
end

--- Removes the glow from an Animation Variation and its child fields they have it or even exist.
---@param animationVariations AnimationVariations[]
local function RemoveGlowFromAnimationVariationsContents(animationVariations)
    if type(next(animationVariations)) == "string" then
        -- Is just a straight animation.
        RemoveGlowFromAnimationContents(animationVariations)
    else
        -- Is an array of animations.
        for _, animation in pairs(animationVariations) do
            RemoveGlowFromAnimationContents(animation)
        end
    end
end

--- Removes the draw_as_glow from all of the places this prototype could have it set. So the graphics always respect the light level.
---@param prototype Prototype.Projectile|Prototype.FluidStream|Prototype.FireFlame|Prototype.ArtilleryProjectile|Prototype.Explosion
local function RemoveGlowFromPictures(prototype)
    if prototype.animation ~= nil then RemoveGlowFromAnimationContents(prototype.animation) end -- Projectile & Fluid Stream
    if prototype.animations ~= nil then RemoveGlowFromAnimationVariationsContents(prototype.animations) end -- Explosions
    if prototype.picture ~= nil then RemoveGlowFromSpriteContents(prototype.picture) end -- Artillery Projectile
    if prototype.pictures ~= nil then RemoveGlowFromAnimationVariationsContents(prototype.pictures) end -- Fire
    if prototype.small_tree_fire_pictures ~= nil then RemoveGlowFromAnimationVariationsContents(prototype.small_tree_fire_pictures) end -- Fire
    if prototype.secondary_pictures ~= nil then RemoveGlowFromAnimationVariationsContents(prototype.secondary_pictures) end -- Fire
    if prototype.smoke_source_pictures ~= nil then RemoveGlowFromAnimationVariationsContents(prototype.smoke_source_pictures) end -- Fire
end

-- Increase the light from fire on the ground and trees. As the default is too low for these very dark maps.
for _, prototype in pairs(data.raw["fire"]) do
    RemoveGlowFromPictures(prototype)

    -- Only a fire type that that does fire damage, so excludes acid spit.
    if prototype.damage_per_tick ~= nil and prototype.damage_per_tick.type ~= nil and prototype.damage_per_tick.type == "fire" then
        -- Default is: light = {intensity = 0.2, size = 8, color = {1, 0.5, 0}},
        prototype.light = { { intensity = 0.4, size = 30, color = FireColor, minimum_darkness = 0.2 } }
    end
end



-- Apply the lights to things. Projectiles can have an area light on them (or rotated via rendering) or a light-explosion on the source or target. Items can have a light-explosion on the source or target.


--- Ensures a prototypes field is an array rather than a single entry and that it exists.
---@param container table<string, any>
---@param fieldName string
local function EnsureFieldIsArrayInContainer(container, fieldName)
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
local function RecordProjectileNameToAmmoCategory(action, ammoCategory)
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
-- Currently we only add shooting light through this directly. Any in-flight or hit explosions are added later as require much more filtering.
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
    RemoveGlowFromPictures(prototype)

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
        RemoveGlowFromPictures(prototype)

        --CODE NOTE: action check would go here if we can't just tack it on to the specific explosion types nicely.
    elseif projectileModifyType == "tank-shell" then
        -- Is a type of tank shell.

        --CODE NOTE: action check would go here if we can't just tack it on to the specific explosion types nicely.
    end
end


-- Go over each artillery projectile prototype and if it was flagged by the ammo type that made it add what we need based on its ammo category. We just add a new action to avoid any conflicts with others.
for projectileName, prototype in pairs(data.raw["artillery-projectile"]) do
    RemoveGlowFromPictures(prototype)

    local projectileModifyType = ProjectilesToModify[projectileName]
    if projectileModifyType == "artillery-shell" then
        -- Is a type of artillery-shell.

        --CODE NOTE: action check would go here if we can't just tack it on to the specific explosion types nicely.
    end
end



-- Go over the stream types and add light to the fire ones.
for _, prototype in pairs(data.raw["stream"]) do
    RemoveGlowFromPictures(prototype)

    -- Only fire streams have smoke from them.
    if prototype.smoke_sources ~= nil then
        prototype.stream_light = { intensity = 0.3, size = 12, color = FireColor, minimum_darkness = 0.2 }
        -- ground_light is terrible
    end
end


-- Go over the explosions and remove the glow from them all. So they don't just appear in the darkness. We add lights to the ones that should have them.
for _, prototype in pairs(data.raw["explosion"]) do
    RemoveGlowFromPictures(prototype)
end


-- Add lights to the explosions from projectiles that do explosive damage type. By adding them as their own light-explosions to the regular explosion we can set our own TTL and avoid any complicated checks on the Projectile prototypes.
-- Also does Death explosions. Should have light if they have a fireball type explosion, but not if they don't. i.e. inserters and belts have small fireball explosions, but wooden chests and stone furnaces don't.
-- Don't do "explosion" as this occurs when things are hurt by explosive weapons, i.e. a grenade exploding and damaging a wall creates an "explosion" one each wall piece.
-- This only handles stock explosion animation graphics and doesn't detect or handle modded explosion graphics. But I assume most modders will use existing explosions, or at least the existing graphic files in a proportionate way.
local smallLightExplosionNames = {} ---@type table<int, string>
local mediumLightExplosionNames = {} ---@type table<int, string>
local largeLightExplosionNames = {} ---@type table<int, string>
local massiveLightExplosionNames = {} ---@type table<int, string>
local nukeLightExplosionNames = {} ---@type table<int, string>
local explosionLists = { [smallLightExplosionNames] = "light-explosion-small-explosive-impact", [mediumLightExplosionNames] = "light-explosion-medium-explosive-impact", [largeLightExplosionNames] = "light-explosion-large-explosive-impact", [massiveLightExplosionNames] = "light-explosion-massive-explosive-impact", [nukeLightExplosionNames] = "light-explosion-nuke-explosive-impact" } ---@type table<table<int, string>, string> # A table of array of explosion names, to the light explosion to be added to the array's named explosions.

-- Populate the lists based on the explosion animation images.
for prototypeName, prototype in pairs(data.raw["explosion"]) do
    if prototype.animations ~= nil then
        -- Has an animation so see if its one of our recognised explosion pictures.
        local firstAnimation = prototype.animations[1] or prototype.animations
        if firstAnimation ~= nil and firstAnimation.filename ~= nil then
            local filename = firstAnimation.filename
            if filename ~= nil then
                if string.sub(filename, #filename - 20) == "small-explosion-1.png" then
                    smallLightExplosionNames[#smallLightExplosionNames + 1] = prototypeName
                elseif string.sub(filename, #filename - 21) == "medium-explosion-1.png" then
                    mediumLightExplosionNames[#mediumLightExplosionNames + 1] = prototypeName
                elseif string.sub(filename, #filename - 16) == "big-explosion.png" then
                    largeLightExplosionNames[#largeLightExplosionNames + 1] = prototypeName
                end
            end
        end
        if firstAnimation ~= nil and firstAnimation.stripes ~= nil then
            local firstStripe = firstAnimation.stripes[1] or firstAnimation.stripes
            if firstStripe ~= nil and firstStripe.filename ~= nil then
                local filename = firstStripe.filename
                if filename ~= nil then
                    if string.sub(filename, #filename - 22) == "massive-explosion-1.png" then
                        massiveLightExplosionNames[#massiveLightExplosionNames + 1] = prototypeName
                    elseif string.sub(filename, #filename - 25) == "bigass-explosion-36f-1.png" then
                        largeLightExplosionNames[#largeLightExplosionNames + 1] = prototypeName
                    elseif string.sub(filename, #filename - 19) == "nuke-explosion-1.png" then
                        nukeLightExplosionNames[#nukeLightExplosionNames + 1] = prototypeName
                    end
                end
            end
        end
    end
end

-- Add each light explosion to the animation explosion in the lists.
for listExplosionNames, lightExplosionName in pairs(explosionLists) do
    for _, explosionName in pairs(listExplosionNames) do
        local prototype = data.raw["explosion"][explosionName]
        if prototype ~= nil then
            EnsureFieldIsArrayInContainer(prototype, "created_effect")
            prototype.created_effect = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    source_effects = { type = "create-explosion", entity_name = lightExplosionName }
                }
            }
        end
    end
end






-- Flying robots that shoot bullets we can pickup via their use of the source shooting explosion and just add a light to this to mirror a bullet guns. If we add them as their own light-explosions we can set our own TTL and avoid any complicated checks on the Projectile prototypes.
data.raw["explosion"]["explosion-gunshot-small"].created_effect = {
    type = "direct",
    action_delivery = {
        type = "instant",
        source_effects = { type = "create-explosion", entity_name = "light-explosion-bullet-source" }
    }
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
        filename = GraphicsPath .. "light_area-rear_ended.png",
        priority = "extra-high",
        flags = { "light" },
        width = 400,
        height = 400
    }
})



--[[
    Modify the camp-fire entity if its present from the fire-place mod.
    This is for JD's play through only. We will create them purely via Muppet Streamer mod's Spawn Around Player feature.
    We want to hide it from being crafted and make it un-minable.
]]

local campFireRecipe = data.raw["recipe"]["camp-fire"]
if campFireRecipe ~= nil then
    campFireRecipe.enabled = false
end

local campFireEntity = data.raw["furnace"]["camp-fire"]
if campFireEntity ~= nil then
    campFireEntity.minable = nil
end




--[[
    Modify all lamps to turn on earlier. So they don't flash on post dusk.
]]

for _, prototype in pairs(data.raw["lamp"]) do
    prototype.darkness_for_all_lamps_on = 0.25 -- default is 0.5
    prototype.darkness_for_all_lamps_off = 0.15 -- default is 0.3
end
