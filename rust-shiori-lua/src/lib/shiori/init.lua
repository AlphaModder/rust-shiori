local path = (...):gsub('%.init$', '')

local utils = require("utils")
local events = require(path .. ".events")
local script = require(path .. ".script")

local SYSTEM_EVENTS = {"OnUserInput", "OnUserInputCancel", "inputbox.autocomplete"}

local shiori = {
    resume_on_event = events.resume_on_event,
    resume_on_events = events.resume_on_events,
    set_event_preprocessor = events.set_event_preprocessor,

    CharacterSet = script.CharacterSet,
    Script = script.Script,

    -- The main way for ghosts to register event handlers is by assigning to functions to this table.
    event = setmetatable({}, {
        __newindex = function(_, e, handler)
            if utils.contains(SYSTEM_EVENTS, e) then 
                shiori.script_error(("Cannot register handler for %s because it is a system event!"):format(e))
            end
            if type(e) == "string" and type(handler) == "function" then
                events.push_event_handler(e, function(_)
                    return coroutine.create(function(_, params) -- ignore the ID
                        return handler(table.unpack(params)), false 
                    end) 
                end)
            end
        end
    })
}

function shiori.bad_request(message, level)
    level = level or 0
    error({text=message or "", code=400}, 2 + level)
end

function shiori.script_error(message, level)
    level = level or 0
    error({text=message or "", code=500}, 2 + level)
end

return shiori