local Events = require("utility/events")
local Utils = require("utility/utils")
--local Logging = require("utility/logging")

if settings.startup["jdplays_mode"].value ~= "march-2020" then
    return
end

local excludedItems = {
    ["infinity-chest"] = true,
    ["infinity-pipe"] = true,
    ["player-port"] = true,
    ["simple-entity-with-force"] = true,
    ["simple-entity-with-owner"] = true,
    ["computer"] = true,
    ["selection-tool"] = true,
    ["item-with-inventory"] = true,
    ["item-with-label"] = true,
    ["item-with-tags"] = true,
    ["blueprint"] = true,
    ["deconstruction-planner"] = true,
    ["upgrade-planner"] = true,
    ["blueprint-book"] = true,
    ["copy-paste-tool"] = true,
    ["cut-paste-tool"] = true,
    ["dummy-steel-axe"] = true
}

local function SelectItemName(previousItems)
    local items = game.item_prototypes
    local gameItemsCount = Utils.GetTableNonNilLength(items)
    local randomIndex = math.random(gameItemsCount)
    local itemName = Utils.GetTableValueByIndexCount(items, randomIndex).name
    if previousItems[itemName] ~= nil or excludedItems[itemName] ~= nil then
        itemName = SelectItemName(previousItems)
    end
    return itemName
end

local function OnEggNestDestroyed(event)
    local actionName, eggNestDetails = event.actionName, event.eggNestDetails
    if actionName ~= nil then
        return
    end

    local surface, targetPos, previousItems = eggNestDetails.surface, eggNestDetails.position, {}
    if eggNestDetails.entityType == "biter-egg-nest-small" then
        local pos = Utils.RandomLocationInRadius(targetPos, 1, 0)
        local itemName = SelectItemName(previousItems)
        surface.spill_item_stack(pos, {name = itemName, count = 1}, true, nil, false)
    elseif eggNestDetails.entityType == "biter-egg-nest-large" then
        local itemCount, xDistanceFromLeft = math.random(1, 3), 3
        xDistanceFromLeft = xDistanceFromLeft / itemCount
        for count = 1, itemCount do
            local xOffsetBase = (count - 1) * xDistanceFromLeft
            local randomXOffset = -1.5 + ((math.random() * xDistanceFromLeft) + xOffsetBase)
            local pos = Utils.RandomLocationInRadius(Utils.ApplyOffsetToPosition(targetPos, {x = randomXOffset, y = 0}), 1, 0)
            local itemName = SelectItemName(previousItems)
            previousItems[itemName] = true
            surface.spill_item_stack(pos, {name = itemName, count = 1}, true, nil, false)
        end
    end
end

local function OnPlayerCreated(event)
    local player = game.get_player(event.player_index)
    player.print({"messages.jd_plays-march-2020-welcome1"})
end

local function CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    Events.RegisterHandler(defines.events.on_player_created, "Control.OnPlayerCreated", OnPlayerCreated)

    if remote.interfaces["biter_eggs"] ~= nil then
        local eggNestDestroyedEventId = remote.call("biter_eggs", "get_egg_post_destroyed_event_id")
        Events.RegisterEvent(eggNestDestroyedEventId)
        Events.RegisterHandler(eggNestDestroyedEventId, "Control.OnEggNestDestroyed", OnEggNestDestroyed)
    end
end

local function OnStartup()
    CreateGlobals()
    OnLoad()

    Utils.DisableIntroMessage()
    Utils.DisableWinOnRocket()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
Events.RegisterEvent(defines.events.on_player_created)
