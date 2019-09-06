local logger = rsl_require("logger")
local events = rsl_require("events")
local eris = require("eris")

return {
    Persistent = function(persistent_path)
        local persistent = {
            save_path = persistent_path,
            data = {},
        }
    
        function persistent.load()
            local file, data, err, code
            file, err, code = io.open(persistent.save_path, "rb")
            if file then 
                data, err, code = file:read("*all")
                file:close()
            end
            if data then 
                persistent.data = eris.unpersist(data) 
            else
                logger.warn("Failed to load persistent data: %s %s", err, code)
            end
        end
    
        function persistent.save()
            local file, err, code = io.open(persistent.save_path, "wb")
            if file then
                _, err, code = file:write(eris.persist(persistent.data))
                file:close()
            end
            if err then
                logger.warn("Failed to save persistent data: %s %s", err, code)
            end
        end
    
        return persistent
    end
}