local logger = rsl_require("logger")
local events = rsl_require("events")

local persistent = {}

events.push_static_event_handler("OnInitialize", function()
    _G.persistent = {}
    local file, data, err, code
    file, err, code = io.open(persistent.path, "rb")
    if file then 
        data, err, code = file:read("*all")
        file:close()
    end
    if data then 
        _G.persistent = eris.unpersist(data) 
    else
        logger.warn("Failed to load persistent data: %s %s", err, code)
    end
end)
    
events.push_static_event_handler("OnDestroy", function()
    local file, err, code = io.open(persistent.path, "wb")
    if file then
        _, err, code = file:write(eris.persist(_G.persistent))
        file:close()
    end
    if err then
        logger.warn("Failed to save persistent data: %s %s", err, code)
    end
end)

return persistent