local events = require("shiori.events")

local lua_type = type

local CURRENT_INPUT_ID = -1
local function next_input_id() -- Maybe replace this with a better algorithm.
    CURRENT_INPUT_ID = CURRENT_INPUT_ID + 1
    return tostring(CURRENT_INPUT_ID)
end

local DEFAULT_PATTERNS = {
    dateinput = "(%d%d%d%d)-(%d%d)-(%d%d)",
    timeinput = "(%d%d):(%d%d):(%d%d)"
}

local function parse_default(type, default)
    if default == nil then
        if type == "dateinput" or type == "timeinput" then return "", "", "" else return "" end
    end

    if (type == "inputbox" or type == "passwordinput") and lua_type(default) == "string" then return default end
    if type == "sliderinput" and lua_type(default) == "number" then return tostring(default) end
    if type == "dateinput" or type == "timeinput" then
        if lua_type(default) == "string" then return default:match(DEFAULT_PATTERNS[type]) end
        if lua_type(default) == "table" and #default == 3 then 
            if lua_type(default[1]) == "number" and lua_type(default[2]) == "number" and lua_type(default[3]) == "number" then
                return tostring(default[1]), tostring(default[2]), tostring(default[3])
            end
        end
    end
    error("Invalid default specification!")
end

local function parse_result(type, result)
    if type == "inputbox" or type == "passwordinput" then return result end
    if type == "sliderinput" then return tonumber(result) end
    local a, b, c = result:match("(%d+),(%d+),(%d+)")
    return {tonumber(a), tonumber(b), tonumber(c)}
end

local function wait_for_input(type, id)
    local event, params = events.resume_on_events { 
        OnUserInput = function(i, _) return i == id end,
        OnUserInputCancel = function(i, _) return i == id end,
    }
    if event == "OnUserInput" then return parse_result(type, event[1]) else return nil end
end

local function input_sync(write_command, args, id, cmd)
    write_command("!", "open", args.type, id, table.unpack(cmd))
    if not args.multiple then
       return wait_for_input(args.type, id)
    else
        local iter_func = function(_, _)
            local input = wait_for_input(args.type, id)
            return nil, input
        end
        return iter_func, nil, nil
    end
end

local function input_async(write_command, args, id, cmd)
    local to_resume = nil
    local routine = coroutine.create(function()
        local input = nil
        write_command("!", "open", args.type, id, table.unpack(params))
        if args.multiple then
            repeat
                input = wait_for_input(args.type, id)
                if input and args.callback(input) == false then
                    write_command("!", "close", args.type, id)
                    break
                end
            until input == nil
        else
            input = wait_for_input(args.type, id)
            args.callback(input)
        end
        if to_resume then coroutine.resume(to_resume) end
    end)
    coroutine.resume(routine)
    return {
        wait = function() 
            to_resume = coroutine.running()
            coroutine.yield()
        end
    }
end

-- The args parameter is a table specifying how to take the input. It supports the following keys:
-- type: one of "text", "password", "date", "slider", "time"
-- timeout (optional): if present and greater than 0, the length of time to display the input box.
-- multiple (optional): true if the input box should remain open for multiple inputs. Defaults to false.
-- clear (optional): true if the input box's contents should be cleared after each input. Defaults to true.
-- default (optional): specifies the initial value in the input box:
--      if type is "text" or "password", default is a string containing the initial text.
--      if type is "slider", a number defining the initial position.
--      if type is "time", default is either a string "yyyy-mm-dd" or an array of three numbers specifying the same.
--      if type is "date", default is either a string "hh:mm:ss", or an array of three numbers specifying the same.
-- Additionally, if type is "slider", the following keys are required:
-- minimum: The slider's minimum value
-- maximum: The slider's maximum value
local function input(write_command, args)
    args.type = args.type .. "input"
    if args.type == "textinput" then type = "inputbox" end
    args.timeout = args.timeout or 0
    if args.clear == nil then args.clear = true end

    local params = {tostring(args.timeout), parse_default(args.type, args.default)}
    if args.type == "sliderinput" then
        params[#params + 1] = tostring(args.minimum or error("Must specify a minimum value for slider input!"))
        params[#params + 1] = tostring(args.maximum or error("Must specify a maximum value for slider input!"))
    end
    if args.multiple then
        params[#params + 1] = "--option=noclose"
        if not args.clear then params[#params + 1] = "--option=noclear" end
    end

    local id = next_input_id()
    if args.callback == nil then 
        return input_sync(write_command, args, id, params)
    else
        return input_async(write_command, args, id, params)
    end
end

return Input
