local ok_codes = { GET = 200, NOTIFY = 204 }

local function Responder(init_module, searcher, persistent_path)
    local loaded_rsl_modules = {}
    function _G.rsl_require()
        if not loaded_rsl_modules[module] then
            local loader = searcher(module)
            if loader then loaded_rsl_modules[module] = loader(module) end
        end
        return loaded_rsl_modules[module] or error(("Could not load internal module %s!"):format(module))
    end

    local utils = rsl_require("utils")
    local events = rsl_require("events")
    local script = rsl_require("script")
    local ScriptInterface = rsl_require("shiori.interface").ScriptInterface
    local logger = rsl_require("logger")
    local interpolate = rsl_require("script.interpolate")
    local dtags = rsl_require("script.dtags")
    local shiori = rsl_require("shiori")
    local Persistent = rsl_require("persistent").Persistent

    local persistent = Persistent(persistent_path)
    persistent.load()
    logger.debug("Loaded persistent data.")
    events.push_static_event_handler("OnDestroy", persistent.save)
    
    local interface = nil

    local function create_script_env()
        local script_env_meta = {
            __index = function(table, key)
                if key == "rsl_require" then return nil end
                if key == "script" then return interface end
                return logger[key] or _G[key]
            end
        }

        local script_env = {
            _G = script_env,
            shiori = shiori,

            bad_request = shiori.bad_request,
            choose = utils.choose,
            event = shiori.event,
            persistent = persistent.data,
            script_error = shiori.script_error,
            
            _tags = dtags.public,
        }

        return setmetatable(script_env, script_env_meta)
    end

    local function ScriptSearcher()
        local env = create_script_env()
        logger.debug("Created script environment.")

        return function(module)
            local path, err = package.searchpath(module, package.script_path)
            if path == nil then return ("\n\t" .. err) end
            local file, err = io.open(path, "r")
            if file == nil then return ("\n\t" .. err) end
            local script = interpolate.process_file(file:read("*all"))
            local mod, err = load(script, "@" .. path, "t", env)
            file:close()
            return (not err and mod) or ("\n\t" .. err)
        end
    end

    package.searchers[#package.searchers + 1] = ScriptSearcher()
    logger.debug("Installed script searcher.")

    local function resume_script(routine, id, event, method)
        if method == "GET" then script.current = script.Script() else script.current = nil end
        interface = script.current and ScriptInterface()

        local s, e = coroutine.resume(routine, id, event)
        if not s then
            if e == "cannot resume dead coroutine" then
                return { text = "Attempt to resume a script that has already ended.", code = 500 }
            else
                if (not utils.istable(e)) or (not e.message) then e = { message = e } end
                local error_msg = ("%s\n%s"):format(utils.tostring_or_nil(e.message), debug.traceback(routine))
                return { text = error_msg, code = e.code or 500 }
            end
        end
        
        return { text = script.current and script.current.to_sakura(), code = ok_codes[method] }
    end

    local function respond(event, method)
        local result = { text = nil, code = 204 }
        if event and event["ID"] then
            local preprocessor = events.event_preprocessors[event["ID"]]
            local processed_event = {event}
            if preprocessor then procevent = table.pack(preprocessor(event)) end
            local handlers = events.event_handlers[event["ID"]] or {}
            local routine = nil
            for i, handlers in ipairs(handlers) do
                local remove
                routine, remove = handler(procevent)
                if remove then handlers[i] = nil end
                if routine then 
                    result = resume_script(routine, event["ID"], procevent, method)
                    if result.code ~= 204 then break end
                end
            end
            events.event_handlers[event["ID"]] = utils.remove_nils(handlers)
        end
        return result
    end

    require(init_module)
    logger.debug("Initialized scripts.")

    return respond
end

return Responder