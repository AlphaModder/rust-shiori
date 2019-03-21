local shiori = require("shiori")
local utils = require("utils")

local logger = shiori.logger

local ok_codes = { GET = 200, NOTIFY = 204 }

local function init()
    local SCRIPT_ENV_META = {
        __index = function(table, key) 
            if key == "script" then return shiori.script end
            return shiori.logger[key] or _G[key]
        end
    }

    local SCRIPT_ENV = {
        _G = SCRIPT_ENV,
        shiori = shiori,
        sakura = require("sakura"),
        f = require("fstring").f,
        choose = utils.choose,
        bad_request = shiori.error_bad_request,
        shiori_error = shiori.error_generic,
    }

    setmetatable(SCRIPT_ENV, SCRIPT_ENV_META)
    package.searchers[#package.searchers + 1] = function(module)
        local file, err = package.searchpath(module, package.script_path)
        if file == nil then return err end
        local mod, err = loadfile(file, "bt", SCRIPT_ENV)
        return (not err and mod) or ("\n\t" .. err)
    end

    require("ghost") -- Search for and execute ghost.lua in the ghost folder.
end

local function resume_script(routine, event, method)
    local script = nil
    if method == "GET" then script = shiori.Script() end
    shiori.script = script
    local s, e = coroutine.resume(routine, table.unpack(event))

    if not s then
        if e == "cannot resume dead coroutine" then
            return { text = "Attempt to resume a script that has already ended.", code = 500 }
        else
            if not utils.istable(e) then e = { response = e } end
            local error_msg = ("%s\n%s"):format(utils.tostring_or_nil(e.response), debug.traceback(routine))
            return { text = error_msg, code = e.code or 500 }
        end
    end
    
    return { text = (script and script.to_sakura()) or nil, code = ok_codes[method] }
end

local function respond(event, method)
    if event and event["ID"] then
        local preprocessor = shiori.event_preprocessors[event["ID"]]
        local procevent = {event}
        if preprocessor then procevent = table.pack(preprocessor(event)) end
        local handlers = shiori.event_handlers[event["ID"]] or {}
        local routine = nil
        for i, handler in ipairs(handlers) do
            local remove
            routine, remove = handler(procevent)
            if remove then handlers[i] = nil end
            if routine then break end
        end
        shiori.event_handlers[event["ID"]] = utils.remove_nils(handlers)
        if routine then
            return resume_script(routine, procevent, method)
        end
    end
    return { text = nil, code = 204 }
end

return {
    respond = respond,
    init = init,
}