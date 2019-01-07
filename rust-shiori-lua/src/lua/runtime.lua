shiori = require("shiori")

function respond(event)
    if event and event["ID"] then
        preprocessor = shiori.event_preprocessors[event["ID"]]
        if preprocessor then event = preprocessor(event) end
        handlers = shiori.event_handlers[event["ID"]]
        routine = nil
        for i, handler in ipairs(handlers) do
            co, remove = handler(event)
            if remove then handlers[i] = nil end
            if co then
                routine = co
                break
            end
        end
        shiori.event_handlers[event["ID"]] = remove_nils(handlers)
        if routine then 
            s, r = coroutine.resume(routine, event)
            if s then return r end
        end
    end
    return 
end

function remove_nils(array)
    new = {}
    for _, item in ipairs(array) do
        if item ~= nil then new[#new + 1] = item end
    end
    return new
end

return respond