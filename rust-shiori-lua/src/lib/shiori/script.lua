local utils = require("utils")
local events = require("shiori.events")
local fstring = require("fstring")
local sakura = require("sakura")

local Set = utils.Set

local script_mod = {
    current = nil,
}

local function _CharacterSet(chars)
    local meta = {
        __call = function(_, text) script_mod.current.say(chars, text, 3) end,
        __add = function(rhs, lhs) return _CharacterSet(rhs.chars + lhs.chars) end
    }
    return setmetatable({chars=chars}, meta)
end

function script_mod.CharacterSet(...) return _CharacterSet(Set{...}) end

local function switch_escape(s)
    local len = string.len(s)
    return string.rep("$", len // 2) .. string.rep("\\", len % 2) 
end

local function sakura_escape(text)
    return text:gsub("\n", "$n"):gsub("\\", "$\\"):gsub("[$]+", switch_escape)
end

function script_mod.Script()
    local segments = {}
    local active_chars = Set{}
    local in_choice_group = false

    local script = {}

    -- Private functions

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
            elseif #new_chars == 1 then
                write_command("p", utils.set_to_table(new_chars)[0]) 
            else
                write_command("_s", table.unpack(utils.set_to_table(new_chars)))
            end
            active_chars = new_chars
        end
    end

    -- Public functions

    function script.say(characters, text, n)
        n = n or 2
        update_chars(characters)
        text = sakura_escape(fstring.f(text, n))
        for _, segment in ipairs(sakura.clean(sakura.parse(text))) do segments[#segments + 1] = segment end
    end

    function script.raise(event, ...)
        write_command("!", "raise", ...)
    end

    function script.passive_mode(enable)
        write_command("!", (enable and "enter") or "leave", "passivemode")
    end

    function script.communicate(default_text)
        if default_text ~= nil then 
            write_command("!", "open", "communicatebox", default_text)
        else
            write_command("!", "open", "communicatebox")
        end

        local event, params = events.resume_on_events { "OnCommunicate", "OnCommunicateInputCancel" }
 
        if event == "OnCommunicate" then return params[0] else return nil end
    end

    function script.to_sakura() return sakura.write(segments) end

    return script
end

return script_mod