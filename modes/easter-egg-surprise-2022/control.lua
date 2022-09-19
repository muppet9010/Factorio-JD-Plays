local Events = require("utility/events")
local Utils = require("utility/utils")

if settings.startup["jdplays_mode"].value ~= "easter_egg_surprise_2022" then
    return
end

local IncludedItems = {
    "iron-plate",
    "copper-plate",
    "steel-plate",
    "electronic-circuit",
    "iron-gear-wheel",
    "pipe",
    "pipe-to-ground",
    "firearm-magazine",
    "stone-wall",
    "gun-turret"
}

local function SelectItemName(previousItems)
    local itemName
    while itemName == nil do
        itemName = IncludedItems[math.random(1, #IncludedItems)]
        if previousItems[itemName] ~= nil then
            -- This item has already been included.
            itemName = nil
        end
    end
    return itemName
end

local function OnEggNestDestroyed(event)
    local actionName, eggNestDetails = event.actionName, event.eggNestDetails
    if actionName ~= nil then
        -- Something was already created, so no rewards will be added.
        return
    end

    local surface, targetPos, previousItems = eggNestDetails.surface, eggNestDetails.position, {}
    if eggNestDetails.entityType == "biter-egg-nest-small" then
        local pos = Utils.RandomLocationInRadius(targetPos, 1, 0)
        local itemName = SelectItemName(previousItems)
        surface.spill_item_stack(pos, { name = itemName, count = 1 }, true, nil, false)
    elseif eggNestDetails.entityType == "biter-egg-nest-large" then
        local itemCount, xDistanceFromLeft = math.random(1, 3), 3
        xDistanceFromLeft = xDistanceFromLeft / itemCount
        for count = 1, itemCount do
            local xOffsetBase = (count - 1) * xDistanceFromLeft
            local randomXOffset = -1.5 + ((math.random() * xDistanceFromLeft) + xOffsetBase)
            local pos = Utils.RandomLocationInRadius(Utils.ApplyOffsetToPosition(targetPos, { x = randomXOffset, y = 0 }), 1, 0)
            local itemName = SelectItemName(previousItems)
            previousItems[itemName] = true
            surface.spill_item_stack(pos, { name = itemName, count = 1 }, true, nil, false)
        end
    end
end

local function CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    if remote.interfaces["biter_eggs"] ~= nil then
        local eggNestDestroyedEventId = remote.call("biter_eggs", "get_egg_post_destroyed_event_id")
        Events.RegisterHandlerEvent(eggNestDestroyedEventId, "Control.OnEggNestDestroyed", OnEggNestDestroyed)
    end
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
