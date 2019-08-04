local events = {
    event_handlers = {},
    event_preprocessors = {},
}

function events.push_event_handler(event, func)
    if not events.event_handlers[event] then events.event_handlers[event] = {} end
    table.insert(events.event_handlers[event], 1, func)
end

function events.push_static_event_handler(event, func)
    events.push_event_handler(event, function(_)
        -- strip the event ID from arguments
        local expand_params = function(_, params) return handler(table.unpack(params)) end
        return coroutine.create(expand_params), false 
    end)
end

function events.resume_on_event(event, filter)
    if filter == nil then filter = function(...) return true end end
    local _, params = events.resume_on_events({[event] = filter})
    return table.unpack(params)
end

function events.resume_on_events(event_table)
    local again = true -- Ensure the coroutine will only be resumed once. 
    local routine = coroutine.running()
    for event, filter in pairs(event_table) do

        -- If event_table has string array elements, use them as events to resume on unconditionally.
        if type(event) == "number" and type(filter) == "string" then 
            event = filter
            filter = function(...) return true end
        end

        events.push_event_handler(event,
            function(e)
                if again and filter(table.unpack(e)) then
                    again = false
                    return routine, true
                else
                    return nil, not again 
                end 
            end
        )
    end
    return coroutine.yield()
end

function events.set_event_preprocessor(event, preprocessor)
    events.event_preprocessors[event] = preprocessor
end

return events