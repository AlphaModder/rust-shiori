local sakura = require("sakura")
local shiori = require("shiori")
local utils = require("utils")

local langlib = {}

local function langlib.Script()
    segments = {}
    active_chars = {}

    local function write_command(name, ...)
        local args = {...}
        local text
        if #args then 
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

    local function update_chars(characters)
        if active_chars ~= new_chars then
            if #active_chars > 0 then write_command("_s") end
            if new_chars == Set{0} then 
                write_command("0")
            else if new_chars == Set{1} then 
                write_command("1")
            else if new_chars == Set{0, 1} or new_chars == Set{1, 0} then 
                write_command("_s")
            else
                write_command("_s", table.unpack(new_chars))
            end
        end
    end

    local function say(characters, text)
        update_chars(utils.Set(characters))
        for _, segment in ipairs(sakura.clean(sakura.parse(text))) do segments[#segments + 1] = segment end
    end

    local function raise(event, ...)
        write_command("!", "raise", ...)
    end

    local function to_sakura() return sakura.write(segments) end

    return {
        say = say,
        raise = raise,
        to_sakura = to_sakura,
    }
end

return langlib