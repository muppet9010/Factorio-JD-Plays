--local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = {}
MOD = MOD or {}
MOD.scheduledEventNames = MOD.scheduledEventNames or {}

local function GetDefaultInstanceId(instanceId)
    return instanceId or ""
end

function EventScheduler.RegisterScheduler()
    script.on_event(defines.events.on_tick, EventScheduler.OnSchedulerCycle)
end

function EventScheduler.OnSchedulerCycle(event)
    local tick = event.tick
    if global.UTILITYSCHEDULEDFUNCTIONS == nil then
        return
    end
    if global.UTILITYSCHEDULEDFUNCTIONS[tick] ~= nil then
        for eventName, instances in pairs(global.UTILITYSCHEDULEDFUNCTIONS[tick]) do
            for instanceId, scheduledFunctionData in pairs(instances) do
                local eventData = {tick = tick, name = eventName, instanceId = instanceId, data = scheduledFunctionData}
                if MOD.scheduledEventNames[eventName] ~= nil then
                    MOD.scheduledEventNames[eventName](eventData)
                else
                    error("WARNING: schedule event called that doesn't exist: '" .. eventName .. "' id: '" .. instanceId .. "' at tick: " .. tick)
                end
            end
        end
        global.UTILITYSCHEDULEDFUNCTIONS[tick] = nil
    end
end

function EventScheduler.RegisterScheduledEventType(eventName, eventFunction)
    if eventName == nil or eventFunction == nil then
        error("EventScheduler.RegisterScheduledEventType called with missing arguments")
    end
    MOD.scheduledEventNames[eventName] = eventFunction
end

function EventScheduler.ScheduleEvent(eventTick, eventName, instanceId, eventData)
    if eventName == nil then
        error("EventScheduler.ScheduleEvent called with missing arguments")
    end
    local nowTick = game.tick
    if eventTick == nil or eventTick <= nowTick then
        eventTick = nowTick + 1
    end
    instanceId = GetDefaultInstanceId(instanceId)
    eventData = eventData or {}
    global.UTILITYSCHEDULEDFUNCTIONS = global.UTILITYSCHEDULEDFUNCTIONS or {}
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick] = global.UTILITYSCHEDULEDFUNCTIONS[eventTick] or {}
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName] = global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName] or {}
    if global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName][instanceId] ~= nil then
        error("WARNING: Overridden schedule event: '" .. eventName .. "' id: '" .. instanceId .. "' at tick: " .. eventTick)
    end
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName][instanceId] = eventData
end

function EventScheduler.RemoveScheduledEvents(targetEventName, targetInstanceId, targetTick)
    if targetEventName == nil then
        error("EventScheduler.RemoveScheduledEvents called with missing arguments")
    end
    targetInstanceId = GetDefaultInstanceId(targetInstanceId)
    if targetTick == nil then
        for tick, events in pairs(global.UTILITYSCHEDULEDFUNCTIONS) do
            EventScheduler._RemoveScheduledEventsFromTickEntry(events, targetEventName, targetInstanceId)
            if Utils.GetTableNonNilLength(events) == 0 then
                global.UTILITYSCHEDULEDFUNCTIONS[tick] = nil
            end
        end
    else
        local events = global.UTILITYSCHEDULEDFUNCTIONS[targetTick]
        if events ~= nil then
            EventScheduler._RemoveScheduledEventsFromTickEntry(events, targetEventName, targetInstanceId)
            if Utils.GetTableNonNilLength(events) == 0 then
                global.UTILITYSCHEDULEDFUNCTIONS[targetTick] = nil
            end
        end
    end
end

function EventScheduler._RemoveScheduledEventsFromTickEntry(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil then
        events[targetEventName][targetInstanceId] = nil
        if Utils.GetTableNonNilLength(events[targetEventName]) == 0 then
            events[targetEventName] = nil
        end
    end
end

function EventScheduler.IsEventScheduled(targetEventName, targetInstanceId, targetTick)
    if targetEventName == nil then
        error("EventScheduler.IsEventScheduled called with missing arguments")
    end
    if global.UTILITYSCHEDULEDFUNCTIONS == nil then
        return false
    end
    targetInstanceId = GetDefaultInstanceId(targetInstanceId)
    if targetTick == nil then
        for _, events in pairs(global.UTILITYSCHEDULEDFUNCTIONS) do
            if EventScheduler._IsEventScheduledInTickEntry(events, targetEventName, targetInstanceId) then
                return true
            end
        end
    else
        local events = global.UTILITYSCHEDULEDFUNCTIONS[targetTick]
        if events ~= nil then
            if EventScheduler._IsEventScheduledInTickEntry(events, targetEventName, targetInstanceId) then
                return true
            end
        end
    end
    return false
end

function EventScheduler._IsEventScheduledInTickEntry(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil and events[targetEventName][targetInstanceId] ~= nil then
        return true
    end
end

return EventScheduler
