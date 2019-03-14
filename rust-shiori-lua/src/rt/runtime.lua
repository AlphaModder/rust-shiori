local shiori = require("shiori")
local utils = require("utils")

local ok_codes = { GET = 300, NOTIFY = 204 }

local function init()
    local SCRIPT_ENV_META = {
        __index = function(table, key) 
            if key == "script" then return shiori.script end
            return _G[key]
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
        debug = nil,
    }

    setmetatable(SCRIPT_ENV, SCRIPT_ENV_META)
    package.searchers[#package.searchers + 1] = function(module)
        local file, err = package.searchpath(module, package.script_path)
        if file == nil then 
            return err 
        else
            return loadfile(file, "bt", SCRIPT_ENV)
        end
    end

    require("ghost") -- Search for and execute ghost.lua in the ghost folder.
end

local function respond(event, method)
    if event and event["ID"] then
        local preprocessor = shiori.event_preprocessors[event["ID"]]
        local procevent = {event}
        if preprocessor then procevent = table.pack(preprocessor(event)) end
        local handlers = shiori.event_handlers[event["ID"]] or {}
        local routine = nil
        for i, handler in ipairs(handlers) do
            local co, remove = handler(method, procevent)
            if remove then handlers[i] = nil end
            if co then
                routine = co
                break
            end
        end
        shiori.event_handlers[event["ID"]] = utils.remove_nils(handlers)
        if routine then 
            return xpcall(resume_script, resume_error_handler, routine, procevent, method)
        end
    end
    return { response = nil, code = 204 }
end

local function resume_script(routine, event, method)
    local script = nil
    if method == "GET" then script = shiori.Script() end
    shiori.script = script
    local s, _ = coroutine.resume(routine, table.unpack(procevent))
    if not s then shiori.error_generic("Attempt to resume a script that has already ended.") end
    local code = ok_codes[method] or shiori.error_bad_request("Recieved a request with an invalid method.")
    return { response = script.to_sakura(), code = code }
end

local function resume_error_handler(e)
    if not istable(e) then e = { response = e } end
    return { response = utils.tostring_or_nil(e.response), code = e.code or 500}
end

return {
    respond = respond,
    init = init,
}