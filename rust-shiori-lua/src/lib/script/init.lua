-- rust-shiori-lua's script system is built up in several layers. 
-- In descending order, they are:

-- script (script.lua)
-- Defines the script object, which wraps a writeable buffer of SakuraScript segments with
-- various state-tracking functionality and utility methods during GET events.

-- interpolate (interpolate.lua) 
-- Preprocesses lua source files to enable the interpolation of dialogue tags directly into
-- string literals. Called by the runtime when loading files from the ghost's script directory.

-- dtags (dtags.lua)
-- Defines an interface for 'dialogue tags', objects that can be serialized into fragments of
-- SakuraScript and written to a script object.

-- sakura (sakura.lua)
-- Handles low-level parsing and cleaning of SakuraScript before it is sent to the host.

local utils = rsl_require("utils")
local events = rsl_require("events")
local sakura = rsl_require("script.sakura")
local dtags = rsl_require("script.dtags")
local interpolate = rsl_require("script.interpolate")

local script = {
    current = nil,
}

local Set = utils.Set

function script.Script()
    local segments = {}
    local active_chars = Set{}

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

        -- Strip whitespace after non-sakura newlines for multiline strings
        text = text:gsub("\n[\t ]+", "\n"):gsub("^[\t ]+", "")

        local tokens = dtags.todtags(text)

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

return script