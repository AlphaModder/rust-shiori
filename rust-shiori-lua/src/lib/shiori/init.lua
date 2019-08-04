local utils = rsl_require("utils")
local events = rsl_require("events")
local interface = rsl_require("shiori.interface")

local SYSTEM_EVENTS = {
    "OnInitialize", "OnDestroy", "OnUserInput", "OnUserInputCancel", "inputbox.autocomplete",
}

local shiori = {
    resume_on_event = events.resume_on_event,
    resume_on_events = events.resume_on_events,
    set_event_preprocessor = events.set_event_preprocessor,

    CharacterSet = function(...) return interface.CharacterSet(utils.Set{...}) end,

    -- The main way for ghosts to register event handlers is by assigning to functions to this table.
    event = setmetatable({}, {
        __newindex = function(_, e, handler)
            if utils.contains(SYSTEM_EVENTS, e) then 
                shiori.script_error(("Cannot register handler for %s because it is a system event!"):format(e))
            end
            if type(e) == "string" and type(handler) == "function" then
                events.push_static_event_handler(e, handler)
            end
        end
    })
}

function shiori.bad_request(message, level)
    level = level or 1
    error({text=message or "", code=400}, 1 + level)
end

function shiori.script_error(message, level)
    level = level or 1
    error({text=message or "", code=500}, 1 + level)
end

return shiori