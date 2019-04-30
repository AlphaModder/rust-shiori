local utils = rsl_require("utils")
local events = rsl_require("shiori.events")
local dialect = rsl_require("shiori.dialect")
local sakura = rsl_require("sakura")
local logger = rsl_require("logger")

local Set = utils.Set

local script = {
    current = nil,
}

function script.Script()
    local segments = {}
    local active_chars = Set{}
    local in_choice_group = false

    local methods = {}

    function methods.write_command(name, ...)
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
            if #active_chars > 0 then methods.write_command("_s") end
            if new_chars == Set{0} then
                methods.write_command("0")
            elseif new_chars == Set{1} then 
                methods.write_command("1")
            elseif new_chars == Set{0, 1} or new_chars == Set{1, 0} then 
                methods.write_command("_s")
            elseif #new_chars == 1 then
                methods.write_command("p", utils.set_to_table(new_chars)[0]) 
            else
                methods.write_command("_s", table.unpack(utils.set_to_table(new_chars)))
            end
            active_chars = new_chars
        end
    end

    function methods.say(characters, text, n)
        n = n or 1
        update_chars(characters)

        local tokens = dialect.tokenize(text, n + 1)

        local has_choice = false
        for i, token in ipairs(tokens) do 
            utils.extend(segments, token.to_sakura(i))
            has_choice = has_choice or token.is_choice
        end
        
        if has_choice then
            local event, params = events.resume_on_events { "OnChoiceSelect", "OnChoiceTimeout" }
 
            if event == "OnChoiceSelect" then
                local choice = tonumber(params[1]:match("Choice(%d+)"))
                return tokens[choice].choose()
            elseif event == "OnChoiceTimeout" then
                return nil
            end
        end
    end

    function methods.to_sakura() return sakura.write(segments) end

    return methods
end

function script.CharacterSet(chars)
    local meta = {
        __call = function(_, text) return script.current.say(chars, text, 2) end,
        __add = function(rhs, lhs) return script.CharacterSet(rhs.chars + lhs.chars) end
    }
    return setmetatable({chars=chars}, meta)
end

return script