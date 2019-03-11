local math = require("math")
local utils = require("utils")
local sakura = require("sakura")

local shiori = {
    event_handlers = {},
    event_preprocessors = {},
}

function shiori.error_bad_request(message, level)
    level = level or 0
    error({message=message or "", code=400}, 2 + level)
end

function shiori.error_generic(message, level)
    level = level or 0
    error({message=message or "", code=500}, 2 + level)
end

function shiori.push_notify_handler(event, handler)
    handler = function(_, ...) return handler(...) end
    table.insert(shiori.event_handlers, 1, 
        function(method, event)
            if method == "NOTIFY" then return coroutine.create(handler), false end
            return nil, false
        end
    )
end

function shiori.push_get_handler(event, handler)
    table.insert(shiori.event_handlers, 1, 
        function(method, event)
            if method == "GET" then return coroutine.create(handler), false end
            return nil, false
        end
    )
end

function shiori.push_event_handler(event, handler)
    table.insert(shiori.event_handlers, 1, function(method, event) return coroutine.create(handler), false end)
end

function shiori.resume_on_event(event, routine, filter)
    table.insert(shiori.event_handlers, 1, 
        function(method, event)
            if filter(table.unpack(event)) then
                return routine, true
            end
            return nil, false
        end
    )
    coroutine.yield()
end

function shiori.set_event_preprocessor(event, preprocessor)
    shiori.event_preprocessors[event] = preprocessor
end

function shiori.Script()
    local segments = {}
    local active_chars = {}

    local function write_command(name, ...)
        local args = {...}
        local text
        if #args then 
            text = string.format("\\%s[%s]", name, table.concat(args, ","))
        else
            text = string.format("\\%s", name)
        end
        segments[#segments + 1] = {
            type = "command",
            text = text,
            name = name,
            args = args,
        }
    end

    local function update_chars(characters)
        if active_chars ~= new_chars then
            if #active_chars > 0 then write_command("_s") end
            if new_chars == Set{0} then 
                write_command("0")
            elseif new_chars == Set{1} then 
                write_command("1")
            elseif new_chars == Set{0, 1} or new_chars == Set{1, 0} then 
                write_command("_s")
            else
                write_command("_s", table.unpack(new_chars))
            end
        end
    end

    local function say(characters, text)
        update_chars(utils.Set(characters))
        for _, segment in ipairs(sakura.clean(sakura.parse(text))) do segments[#segments + 1] = segment end
    end

    local function raise(event, ...)
        write_command("!", "raise", ...)
    end

    local function to_sakura() return sakura.write(segments) end

    return {
        say = say,
        raise = raise,
        to_sakura = to_sakura,
    }
end

return shiori
