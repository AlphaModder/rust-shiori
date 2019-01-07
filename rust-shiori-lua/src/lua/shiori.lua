local shiori = {
    event_handlers = {}
    event_preprocessors = {}
    parse_error = false,
}

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

function shiori:set_event_preprocess(event, preprocessor)
    self.event_preprocessors[event] = preprocessor
end

function shiori:flag_parse_error()
    self.parse_error = true
end
    
return shiori
