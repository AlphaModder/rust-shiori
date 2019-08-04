local utils, events, script, ScriptInterface

local interface = nil

local function init(init_module, searcher, persistent_path)
    local loaded = {}
    _G.rsl_require = function(module)
        if not loaded[module] then
            local loader = searcher(module)
            if loader then loaded[module] = loader(module) end
        end
        return loaded[module] or error(("Could not load internal module %s!"):format(module))
    end

    utils = rsl_require("utils")
    events = rsl_require("events")
    script = rsl_require("script")
    ScriptInterface = rsl_require("shiori.interface").ScriptInterface

    local logger = rsl_require("logger")
    local interpolate = rsl_require("script.interpolate")
    local dtags = rsl_require("script.dtags")
    local shiori = rsl_require("shiori")
    local persistent = rsl_require("persistent")

    persistent.path = persistent_path

    local SCRIPT_ENV_META = {
        __index = function(table, key)
            if key == "rsl_require" then return nil end
            if key == "script" then return interface end
            return logger[key] or _G[key]
        end
    }

    local SCRIPT_ENV = {
        _G = SCRIPT_ENV,

        shiori = shiori,
        event = shiori.event,
        bad_request = shiori.bad_request,
        script_error = shiori.script_error,

        choose = utils.choose,

        _tags = dtags.public,
    }

    setmetatable(SCRIPT_ENV, SCRIPT_ENV_META)
    package.searchers[#package.searchers + 1] = function(module)
        local path, err = package.searchpath(module, package.script_path)
        if path == nil then return ("\n\t" .. err) end
        local file, err = io.open(path, "r")
        if file == nil then return ("\n\t" .. err) end
        local script = interpolate.process_file(file:read("*all"))
        local mod, err = load(script, "@" .. path, "t", SCRIPT_ENV)
        file:close()
        return (not err and mod) or ("\n\t" .. err)
    end

    require(init_module)
end

local ok_codes = { GET = 200, NOTIFY = 204 }

local function resume_script(routine, id, event, method)
    if method == "GET" then script.current = script.Script() else script.current = nil end
    interface = script.current and ScriptInterface()

    local s, e = coroutine.resume(routine, id, event)
    if not s then
        if e == "cannot resume dead coroutine" then
            return { text = "Attempt to resume a script that has already ended.", code = 500 }
        else
            if not utils.istable(e) then e = { response = e } end
            local error_msg = ("%s\n%s"):format(utils.tostring_or_nil(e.response), debug.traceback(routine))
            return { text = error_msg, code = e.code or 500 }
        end
    end
    
    return { text = script.current and script.current.to_sakura(), code = ok_codes[method] }
end

local function respond(event, method)
    if event and event["ID"] then
        local preprocessor = events.event_preprocessors[event["ID"]]
        local procevent = {event}
        if preprocessor then procevent = table.pack(preprocessor(event)) end
        local handlers = events.event_handlers[event["ID"]] or {}
        local routine = nil
        for i, handler in ipairs(handlers) do
            local remove
            routine, remove = handler(procevent)
            if remove then handlers[i] = nil end
            if routine then break end
        end
        events.event_handlers[event["ID"]] = utils.remove_nils(handlers)
        if routine then
            return resume_script(routine, event["ID"], procevent, method)
        end
    end
    return { text = nil, code = 204 }
end

return {
    respond = respond,
    init = init,
}