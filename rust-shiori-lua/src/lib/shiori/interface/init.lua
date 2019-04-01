local path = (...):gsub('%.init$', '')

local script = rsl_require("shiori.script")
local input = rsl_require(path .. ".input")

local function ScriptInterface()
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

return ScriptInterface
