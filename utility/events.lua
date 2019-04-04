local Utils = require("factorio-utils/utils")
local Events = {}
if MOD == nil then
    MOD = {}
end
if MOD.events == nil then
    MOD.events = {}
end
if MOD.customEventNameToId == nil then
    MOD.customEventNameToId = {}
end

function Events.RegisterEvent(eventName)
    local eventId
    if Utils.GetTableKeyWithValue(defines.events, eventName) ~= nil then
        eventId = eventName
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    script.on_event(eventId, Events.CallHandler)
end

function Events.RegisterHandler(eventName, handlerName, handlerFunction)
    local eventId
    if MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = eventName
    end
    if MOD.events[eventId] == nil then
        MOD.events[eventId] = {}
    end
    MOD.events[eventId][handlerName] = handlerFunction
end

function Events.RemoveHandler(eventName, handlerName)
    if MOD.events[eventName] == nil then
        return
    end
    MOD.events[eventName][handlerName] = nil
end

function Events.CallHandler(eventData)
    local eventId = eventData.name
    if MOD.events[eventId] == nil then
        return
    end
    for _, handlerFunction in pairs(MOD.events[eventId]) do
        handlerFunction(eventData)
    end
end

function Events.Fire(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if defines.events[eventName] ~= nil then
        script.raise_event(eventName, eventData)
    else
        local eventId = MOD.customEventNameToId[eventName]
        script.raise_event(eventId, eventData)
    end
end

return Events
