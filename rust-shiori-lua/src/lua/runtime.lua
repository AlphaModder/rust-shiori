shiori = require("shiori")

ok_codes = { GET = 300, NOTIFY = 204 }

function tostring_or_nil(x) 
    if x ~= nil then return tostring(x) end
    return nil
end

function remove_nils(array)
    new = {}
    for _, item in ipairs(array) do
        if item ~= nil then new[#new + 1] = item end
    end
    return new
end

function respond(event, method)
    if event and event["ID"] then
        local preprocessor = shiori.event_preprocessors[event["ID"]]
        if preprocessor then event = preprocessor(event) end
        local handlers = shiori.event_handlers[event["ID"]]
        local routine = nil
        for i, handler in ipairs(handlers) do
            local co, remove = handler(event)
            if remove then handlers[i] = nil end
            if co then
                routine = co
                break
            end
        end
        shiori.event_handlers[event["ID"]] = remove_nils(handlers)
        if routine then 
            return xpcall(resume_script, resume_error_handler, routine, event, method)
        end
    end
    return { response = nil, status = 204 }
end

function resume_script(routine, event, method)
    local s, r = coroutine.resume(routine, event)
    if not s then shiori.error_generic("attempt to resume dead coroutine") end
    local code = ok_codes[method] or shiori.error_bad_request("invalid request method")
    return { response = tostring(r), code = code )}
end

function resume_error_handler(e)
    if not istable(e) then e = { response = e } end
    return { response = tostring_or_nil(e.response), code = e.code or 500}
end

return respond