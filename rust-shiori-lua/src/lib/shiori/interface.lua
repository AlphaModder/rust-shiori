local utils = rsl_require("utils")
local script = rsl_require("script")
local input = rsl_require("shiori.input")

local interface = {}

function interface.ScriptInterface()
    local interface = {}
    
    function interface.passive_mode(enable)
        script.current.write_command("!", (enable and "enter") or "leave", "passivemode")
    end

    for _, i in ipairs{"text", "password", "slider", "date", "time"} do
        interface[i .. "_input"] = function(args)
            args = args or {}
            args.callback = nil
            args.type = i
            return input(args)
        end
        interface[i .. "_input_async"] = function(args)
            args = args or {}
            args.callback = args.callback or function() end
            args.type = i
            return input(args)
        end
    end

    return interface
end

function interface.CharacterSet(chars)
    local meta = {
        __call = function(_, text) return script.current.say(chars, text, 1) end,
        __add = function(rhs, lhs) return CharacterSet(rhs.chars + lhs.chars) end
    }
    return setmetatable({chars=chars}, meta)
end

return interface
