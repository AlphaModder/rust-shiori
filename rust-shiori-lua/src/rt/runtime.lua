local shiori = require("shiori")
local utils = require("utils")

local ok_codes = { GET = 300, NOTIFY = 204 }

local function init(script_path)
    local SCRIPT_ENV_META = {
        __index = function(table, key) 
            if key == "script" then return shiori.script end
            return _G[key]
        end
    }

    local SCRIPT_ENV = {
        shiori = shiori,
        sakura = require("sakura"),
        f = require("fstring"),
        choose = utils.choose,
        bad_request = shiori.error_bad_request,
        shiori_error = shiori.error_generic,
    }

    setmetatable(SCRIPT_ENV, SCRIPT_ENV_META)
    package.loaders[#package.loaders + 1] = function(module)
        local file, err = package.searchpath(script_path)
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
        local handlers = shiori.event_handlers[event["ID"]]
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
    return { response = nil, status = 204 }
end

local function resume_script(routine, event, method)
    local script = nil
    if method == "GET" then script = shiori.Script() end
    shiori.script = script
    local s, _ = coroutine.resume(routine, table.unpack(procevent))
    if not s then shiori.error_generic("attempt to resume dead coroutine") end
    local code = ok_codes[method] or shiori.error_bad_request("invalid request method")
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