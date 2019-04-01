local utils = rsl_require("utils")
local events = rsl_require("shiori.events")
local fstring = rsl_require("fstring")
local sakura = rsl_require("sakura")

local Set = utils.Set

local script = {
    current = nil,
}

local function switch_escape(s)
    local len = string.len(s)
    return string.rep("$", len // 2) .. string.rep("\\", len % 2) 
end

local function sakura_escape(text)
    return text:gsub("\n", "$n"):gsub("\\", "$\\"):gsub("[$]+", switch_escape)
end

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
        n = n or 2
        update_chars(characters)
        text = sakura_escape(fstring.f(text, n))
        for _, segment in ipairs(sakura.clean(sakura.parse(text))) do segments[#segments + 1] = segment end
    end

    function methods.to_sakura() return sakura.write(segments) end

    return methods
end

function script.CharacterSet(chars)
    local meta = {
        __call = function(_, text) script.current.say(chars, text, 3) end,
        __add = function(rhs, lhs) return script.CharacterSet(rhs.chars + lhs.chars) end
    }
    return setmetatable({chars=chars}, meta)
end

return script