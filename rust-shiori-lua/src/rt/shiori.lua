local math = require("math")
local utils = require("utils")
local sakura = require("sakura")
local fstring = require("fstring")
local Set = utils.Set

local shiori = {
    logger = {},
    event_handlers = {},
    event_preprocessors = {},
    script = nil,
}

function shiori.logger.log_inner(level, text, params, stack)
    text = string.format(text, table.unpack(params))
    stack = stack or 1
    info = debug.getinfo(1 + stack, "Sl")
    _log(level, text, info.short_src, info.currentline)
end

function shiori.logger.log(level, text, ...) shiori.logger.log_inner(level, text, {...}, 2) end

for _, level in ipairs({"trace", "debug", "info", "warn", "error"}) do
    shiori.logger[level] = function(text, ...) shiori.logger.log_inner(level, text, {...}, 2) end
end

local function return_errors(func, handler) return function(...) xpcall(func,  ...) end end

function shiori.error_bad_request(message, level)
    level = level or 0
    error({text=message or "", code=400}, 2 + level)
end

function shiori.error_generic(message, level)
    level = level or 0
    error({text=message or "", code=500}, 2 + level)
end

function shiori.push_event_handler(event, handler)
    if not shiori.event_handlers[event] then shiori.event_handlers[event] = {} end
    table.insert(shiori.event_handlers[event], 1, function(event) return coroutine.create(handler), false end)
end

function shiori.resume_on_event(event, routine, filter)
    if not shiori.event_handlers[event] then shiori.event_handlers[event] = {} end
    table.insert(shiori.event_handlers[event], 1, 
        function(event) if filter(table.unpack(event)) then return routine, true else return nil, false end end
    )
    coroutine.yield()
end

function shiori.set_event_preprocessor(event, preprocessor)
    shiori.event_preprocessors[event] = preprocessor
end

local function _CharacterSet(chars)
    local meta = {
        __call = function(_, text) shiori.script.say(chars, text, 3) end,
        __add = function(rhs, lhs) return _CharacterSet(rhs.chars + lhs.chars) end
    }
    return setmetatable({chars=chars}, meta)
end

function shiori.CharacterSet(...)
    return _CharacterSet(Set{...})
end

local function switch_escape(s)
    local len = string.len(s)
    return string.rep("$", len // 2) .. string.rep("\\", len % 2) 
end

local function sakura_escape(text)
    return text:gsub("\n", "$n"):gsub("\\", "$\\"):gsub("[$]+", switch_escape)
end

function shiori.Script()
    local segments = {}
    local active_chars = {}

    local function write_command(name, ...)
        local args = {...}
        local text
        if #args > 0 then 
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

    local function update_chars(new_chars)
        if active_chars ~= new_chars then
            if #active_chars > 0 then write_command("_s") end
            if new_chars == Set{0} then
                write_command("0")
            elseif new_chars == Set{1} then 
                write_command("1")
            elseif new_chars == Set{0, 1} or new_chars == Set{1, 0} then 
                write_command("_s")
            else
                write_command("_s", table.unpack(utils.set_to_table(new_chars)))
            end
        end
    end

    local function say(characters, text, n)
        n = n or 2
        update_chars(characters)
        text = sakura_escape(fstring.f(text, n))
        for _, segment in ipairs(sakura.clean(sakura.parse(text))) do segments[#segments + 1] = segment end
    end

    local function raise(event, ...)
        write_command("!", "raise", ...)
    end

    local function to_sakura() return sakura.write(segments) end

    local script = {
        say = say,
        raise = raise,
        to_sakura = to_sakura,
    }
    -- TODO: Don't hardcode this.
    script.chars = {shiori.CharacterSet(0), shiori.CharacterSet(1)}
    return script
end

return shiori
