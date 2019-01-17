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

function shiori:push_event_handler(event, handler)
    table.insert(self.event_handlers, 1, function(event) return coroutine.create(handler) end)
end

function shiori:resume_on_event(event, routine, filter)
    table.insert(self.event_handlers, 1, 
        function(event)
            if filter(event) then
                return routine, true
            end
            return nil, false
        end
    )
end

function shiori:set_event_preprocessor(event, preprocessor)
    self.event_preprocessors[event] = preprocessor
end

return shiori
