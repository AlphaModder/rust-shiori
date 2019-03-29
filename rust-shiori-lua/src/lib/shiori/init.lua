local path = (...):gsub('%.init$', '')

local events = require(path .. ".events")
local script = require(path .. ".script")

local shiori = {
    resume_on_event = events.resume_on_event,
    resume_on_events = events.resume_on_events,
    set_event_preprocessor = events.set_event_preprocessor,

    CharacterSet = script.CharacterSet,
    Script = script.Script,

    event = setmetatable({}, {
        __newindex = function(_, e, handler)
            if type(e) == "string" and type(handler) == "function" then
                events.push_event_handler(e, function(_) return coroutine.create(handler), false end)
            end
        end
    })
}

function shiori.error_bad_request(message, level)
    level = level or 0
    error({text=message or "", code=400}, 2 + level)
end

function shiori.error_generic(message, level)
    level = level or 0
    error({text=message or "", code=500}, 2 + level)
end

return shiori