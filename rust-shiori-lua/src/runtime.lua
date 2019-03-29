local utils = require("utils")
local logger = require("logger")
local shiori = require("shiori")
local events = require("shiori.events")
local script = require("shiori.script")

local ok_codes = { GET = 200, NOTIFY = 204 }

local function init(init_module)
    local SCRIPT_ENV_META = {
        __index = function(table, key) 
            if key == "script" then return script.current end
            return logger[key] or _G[key]
        end
    }

    local SCRIPT_ENV = {
        _G = SCRIPT_ENV,

        shiori = shiori,
        event = shiori.event,
        bad_request = shiori.error_bad_request,
        script_error = shiori.error_generic,

        f = require("fstring").f,
        choose = utils.choose,
    }

    setmetatable(SCRIPT_ENV, SCRIPT_ENV_META)
    package.searchers[#package.searchers + 1] = function(module)
        local file, err = package.searchpath(module, package.script_path)
        if file == nil then return err end
        local mod, err = loadfile(file, "bt", SCRIPT_ENV)
        return (not err and mod) or ("\n\t" .. err)
    end

    require(init_module)
end

local function resume_script(routine, id, event, method)
    if method == "GET" then script.current = script.Script() else script.current = nil end
    local s, e = coroutine.resume(routine, id, table.unpack(event)) -- Deal with packing stuff here

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