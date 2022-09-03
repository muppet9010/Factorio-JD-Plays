--[[
    Do all of these changes in final fixes so hopefully other mods have created all of their bits and we can overwrite them. When made a standalone mod we can always add them as hidden optional dependencies so that we run after them if really needed.

    Lasers and electric type weapons just work.
    Lights are based on Factorio's shooting and impact explosion graphics. So grenades have a light to match their base game explosion graphic (overly large).
]]


if settings.startup["jdplays_mode"].value ~= "battlefluffy-scenario" then
    return
end




local GraphicsPath = "__jd_plays__/graphics/battlefluffy-scenario/"
local WhiteColor = { 1, 1, 1 }
local ForestFireColor = { 255, 140, 0 }
local OilFireColor = { 255, 225, 0 }
local ExplosionColor = { r = 246.0, g = 248.0, b = 182.0 } -- Mirrored to control.


-- These should be mod settings, but we will just hardcode them here.
-- In a standalone mod these should probably be per weapon grouping: player weapons, large weapons (tanks, arty), impact explosions, fires.
-- Many of these are mirrored to control.
local DirectLight_Time_Multiplier = 1
local DirectLight_Size_Multiplier = 1
local DirectLight_Intensity_Multiplier = 1
local IndirectLight_Time_Multiplier = 1
local IndirectLight_Size_Multiplier = 1
local IndirectLight_Intensity_Multiplier = 1
local FireLight_Size_Multiplier = 1
local FireLight_Intensity_Multiplier = 1


local MinimumDarkness = 0

---@class BattleFluffy_LightExplosionDefinitions
---@field type "direct"|"indirect"
---@field name string
---@field length uint
---@field intensity double
---@field size double
---@field color? Color
---@field shift MapPosition.1

---@type BattleFluffy_LightExplosionDefinitions[]
local LightExplosionDefinitions = {
    {
        type = "direct",
        name = "light-explosion-bullet-source",
        length = 10,
        intensity = 0.3,
        size = 5,
        color = WhiteColor,
        shift = { 0, -1 }
    },
    {
        type = "indirect",
        name = "light-explosion-bullet-source",
        length = 10,
        intensity = 0.1,
        size = 10,
        color = WhiteColor,
        shift = { 0, -1 }
    },
    {
        type = "direct",
        name = "light-explosion-rocket-source",
        length = 20,
        intensity = 0.4,
        size = 20,
        color = ExplosionColor,
        shift = { 0, -1 }
    },
    {
        type = "indirect",
        name = "light-explosion-rocket-source",
        length = 20,
        intensity = 0.3,
        size = 30,
        color = WhiteColor,
        shift = { 0, -1 }
    },
    {
        type = "direct",
        name = "light-explosion-tank-source",
        length = 30,
        intensity = 0.6,
        size = 30,
        color = ExplosionColor,
        shift = { 0, -1 }
    },
    {
        type = "indirect",
        name = "light-explosion-tank-source",
        length = 30,
        intensity = 0.3,
        size = 60,
        color = WhiteColor,
        shift = { 0, -1 }
    },
    {
        type = "direct",
        name = "light-explosion-artillery-source",
        length = 40,
        intensity = 0.6,
        size = 40,
        color = ExplosionColor,
        shift = { 0, -1 }
    },
    {
        type = "indirect",
        name = "light-explosion-artillery-source",
        length = 40,
        intensity = 0.3,
        size = 80,
        color = WhiteColor,
        shift = { 0, -1 }
    },
    {
        type = "direct",
        name = "light-explosion-small-explosive-impact",
        length = 30,
        intensity = 0.3,
        size = 5,
        color = ExplosionColor,
        shift = { 0, -0.5 }
    },
    {
        type = "indirect",
        name = "light-explosion-small-explosive-impact",
        length = 40,
        intensity = 0.3,
        size = 10,
        color = WhiteColor,
        shift = { 0, -0.5 }
    },
    {
        type = "direct",
        name = "light-explosion-medium-explosive-impact",
        length = 30,
        intensity = 0.4,
        size = 10,
        color = ExplosionColor,
        shift = { 0, -0.5 }
    },
    {
        type = "indirect",
        name = "light-explosion-medium-explosive-impact",
        length = 50,
        intensity = 0.3,
        size = 25,
        color = WhiteColor,
        shift = { 0, -0.5 }
    },
    {
        type = "direct",
        name = "light-explosion-large-explosive-impact",
        length = 30,
        intensity = 0.5,
        size = 20,
        color = ExplosionColor,
        shift = { 0, 0 }
    },
    {
        type = "indirect",
        name = "light-explosion-large-explosive-impact",
        length = 50,
        intensity = 0.3,
        size = 40,
        color = WhiteColor,
        shift = { 0, 0 }
    },
    {
        type = "direct",
        name = "light-explosion-massive-explosive-impact",
        length = 50,
        intensity = 0.5,
        size = 30,
        color = ExplosionColor,
        shift = { 0, 0 }
    },
    {
        type = "indirect",
        name = "light-explosion-massive-explosive-impact",
        length = 80,
        intensity = 0.3,
        size = 60,
        color = WhiteColor,
        shift = { 0, 0 }
    },
    {
        type = "direct",
        name = "light-explosion-nuke-explosive-impact",
        length = 200,
        intensity = 0.6,
        size = 80,
        color = ExplosionColor,
        shift = { 0, 0 }
    },
    {
        type = "indirect",
        name = "light-explosion-nuke-explosive-impact",
        length = 250,
        intensity = 0.3,
        size = 160,
        color = WhiteColor,
        shift = { 0, 0 }
    }
}





-- Create the various light-explosions. Used to create a short light when something is shot.
local BlankAnimations = {} ---@type table<uint, Animation>
for _, lightExplosionDefinition in pairs(LightExplosionDefinitions) do

    -- Get the right multipliers for this type.
    local time_Multiplier, intensity_Multiplier, size_Multiplier
    if lightExplosionDefinition.type == "direct" then
        time_Multiplier, intensity_Multiplier, size_Multiplier = DirectLight_Time_Multiplier, DirectLight_Intensity_Multiplier, DirectLight_Size_Multiplier
    elseif lightExplosionDefinition.type == "indirect" then
        time_Multiplier, intensity_Multiplier, size_Multiplier = IndirectLight_Time_Multiplier, IndirectLight_Intensity_Multiplier, IndirectLight_Size_Multiplier
    else
        error("unsupported type")
    end

    -- Create the blank animations that set how long light-explosions last and thus how long the light is visible for.
    local length = math.max(math.floor(lightExplosionDefinition.length * time_Multiplier), 0) --[[@as uint]]
    local blankAnimation = BlankAnimations[length]
    if blankAnimation == nil then
        local frames, animationSpeed = length, 1
        if frames > 100 then
            animationSpeed = 100 / frames
            frames = 100
        end
        blankAnimation = {
            frame_count = frames,
            animation_speed = animationSpeed,
            filename = GraphicsPath .. "empty_10x10.png",
            priority = "extra-high",
            width = 1,
            height = 1,
            line_length = 10
        }
        BlankAnimations[length] = blankAnimation
    end

    -- Create the explosion prototype.
    data:extend({
        {
            type = "explosion",
            name = lightExplosionDefinition.type .. "-" .. lightExplosionDefinition.name,
            animations = blankAnimation,
            light = {
                {
                    intensity = lightExplosionDefinition.intensity * intensity_Multiplier,
                    size = lightExplosionDefinition.size * size_Multiplier,
                    color = lightExplosionDefinition.color,
                    minimum_darkness = MinimumDarkness,
                    shift = lightExplosionDefinition.shift
                }
            }
        }
    })
end





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
        -- Do tree fires differently from fire flames.
        if prototype.small_tree_fire_pictures ~= nil then
            -- Is a tree fire. These are only ever so many close together.
            prototype.light = {
                { intensity = 0.4 * FireLight_Intensity_Multiplier, size = 10 * FireLight_Size_Multiplier, color = ForestFireColor, minimum_darkness = MinimumDarkness },
                { intensity = 0.2 * FireLight_Intensity_Multiplier, size = 20 * FireLight_Size_Multiplier, color = ForestFireColor, minimum_darkness = MinimumDarkness },
                { intensity = 0.1 * FireLight_Intensity_Multiplier, size = 60 * FireLight_Size_Multiplier, color = ForestFireColor, minimum_darkness = MinimumDarkness },
            }
        else
            -- Is a regular fire flame. There isn't a separation in Factorio between the number of flames on a point, so the light of a single fire flame and many flames on a single point are equal. So this light has to be a balance between one very very alight point and many smaller fires all near each other. As the light is the same size, but a high flame sprite will be larger than a small lighted area.
            prototype.light = {
                { intensity = 2 * FireLight_Intensity_Multiplier, size = 8 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness },
                { intensity = 0.2 * FireLight_Intensity_Multiplier, size = 60 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness },
            }
        end
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
                source_effects = {
                    { type = "create-explosion", entity_name = "direct-light-explosion-bullet-source" },
                    { type = "create-explosion", entity_name = "indirect-light-explosion-bullet-source" }
                }
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
                source_effects = {
                    { type = "create-explosion", entity_name = "direct-light-explosion-rocket-source" },
                    { type = "create-explosion", entity_name = "indirect-light-explosion-rocket-source" }
                }
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
                source_effects = {
                    { type = "create-explosion", entity_name = "direct-light-explosion-tank-source" },
                    { type = "create-explosion", entity_name = "indirect-light-explosion-tank-source" }
                }
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
                source_effects = {
                    { type = "create-explosion", entity_name = "direct-light-explosion-artillery-source" },
                    { type = "create-explosion", entity_name = "indirect-light-explosion-artillery-source" }
                }
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
        -- The stream_light does have a weird spreading out as it reaches the target, I assume its mean to represent it getting close to the ground.
        prototype.stream_light = {
            { intensity = 0.2 * FireLight_Intensity_Multiplier, size = 5 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness },
            { intensity = 0.1 * FireLight_Intensity_Multiplier, size = 10 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness }
        }
        -- ground_light is terrible
    end
end


-- Go over the turrets and add better lighting to the flame turret nozzles.
for _, prototype in pairs(data.raw["fluid-turret"]) do
    if prototype.attack_parameters ~= nil and prototype.attack_parameters.ammo_type ~= nil and prototype.attack_parameters.ammo_type.category == "flamethrower" then
        -- Is a flame turret.
        prototype.muzzle_light = {
            { intensity = 0.4 * FireLight_Intensity_Multiplier, size = 3 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness },
            { intensity = 0.1 * FireLight_Intensity_Multiplier, size = 10 * FireLight_Size_Multiplier, color = OilFireColor, minimum_darkness = MinimumDarkness }
        }
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
                    -- Small buildings (1 tile) dying.
                    smallLightExplosionNames[#smallLightExplosionNames + 1] = prototypeName
                elseif string.sub(filename, #filename - 21) == "medium-explosion-1.png" then
                    -- Medium buildings (2 tiles) dying.
                    mediumLightExplosionNames[#mediumLightExplosionNames + 1] = prototypeName
                elseif string.sub(filename, #filename - 16) == "big-explosion.png" then
                    -- Explosive rockets and tank shells, larger building (3-4 tiles) dying.
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
                        -- Massive buildings (5-6 tiles) and spidertrons dying.
                        massiveLightExplosionNames[#massiveLightExplosionNames + 1] = prototypeName
                    elseif string.sub(filename, #filename - 25) == "bigass-explosion-36f-1.png" then
                        -- Artillery shell hitting.
                        largeLightExplosionNames[#largeLightExplosionNames + 1] = prototypeName
                    elseif string.sub(filename, #filename - 19) == "nuke-explosion-1.png" then
                        -- Nuclear explosion.
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
                    source_effects = {
                        { type = "create-explosion", entity_name = "direct-" .. lightExplosionName },
                        { type = "create-explosion", entity_name = "indirect-" .. lightExplosionName }
                    }
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
        source_effects = {
            { type = "create-explosion", entity_name = "direct-light-explosion-bullet-source" },
            { type = "create-explosion", entity_name = "indirect-light-explosion-bullet-source" }
        }
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
    We don't want them on when its basically fully bright, but on the time its not bright as it gets dark fast.
]]

for _, prototype in pairs(data.raw["lamp"]) do
    prototype.darkness_for_all_lamps_on = 0.1 -- default is 0.5
    prototype.darkness_for_all_lamps_off = 0.05 -- default is 0.3
end
