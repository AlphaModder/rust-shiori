local sakura = {}

local function contains(array, val)
    for _, value in ipairs(array) do
        if value == val then
            return true
        end
    end
    return false
end

local function copystrs(array)
    new = {}
    for _, str in ipairs(array) do
        new[#new + 1] = str
    end
    return new
end

sakura.COMMAND_PATTERNS = {"(\\(\\))", "(\\(%d))"} -- special cases have to come first
for _, e in ipairs({"%[([^%[%]]+)%]", "(%d)", "[^%[%d]", "$"}) do
    sakura.COMMAND_PATTERNS[#sakura.COMMAND_PATTERNS+1] = string.format("(\\(_?_?[a-zA-Z&!%%*%%-%%?%%+])%s)", e)
end

-- a segment is a table like the following:
-- { 
--  type = "command" or "text",
--  text = original text of segment
--  name = command name for commands
--  args = args for commands (array)
-- }
function sakura.parse(script)
    local segments = {}
    local pos = 1
    local done = false
    while not done do
        done = true
        for _, pattern in ipairs(sakura.COMMAND_PATTERNS) do
            s, e = text:find(pattern, pos)
            if s ~= nil then
                segments[#segments+1] = { type="text", text=script:sub(pos, s-1)}
                text, name, argstr = script:match(pattern, pos)
                args = {}
                if argstr ~= nil then for arg in argstr:gmatch("([^,]+),?") do args[#args+1] = arg end end
                segments[#segments+1] = { type="command", text=text, name=name, args=args }
                done = false
                pos = e+1
                break
            end
        end
    end
    segments[#segments+1] = { type="text", text=script:sub(pos) }
    return segments
end

-- check these: "![update,", "6", "7", "![execute", "![biff]", }
sakura.BRANCH_COMMANDS = {"q", "__q", "_a", "e", "-", "![raise", "![embed", }

function sakura.clean(segments)
    cleaned = {}
    for _, seg in ipairs(segments) do
        if seg.type == "command" then
            for _, cmd in ipairs(sakura.BRANCH_COMMANDS) do
                if seg.text:match("^" .. cmd) ~= nil then
                    cleaned[#cleaned + 1] = { type="command" text="\\\\", name="\\", args={}}
                    cleaned[#cleaned + 1] = { type="text", text=seg.text:sub(2)}
                else
                    cleaned[#cleaned + 1] = { type="command", text=seg.text, name=seg.name, args=copystrs(seg.args) }
                end
            end
        else
            cleaned[#cleaned + 1] = { type="text", text=seg.text }
        end
    end
    return cleaned
end

function sakura.write(segments)
    texts = {}
    for _, seg in ipairs(segments) do texts[#texts + 1] = seg.text end
    return table.concat(texts, "")
end

function sakura.clean_script(script)
    return sakura.write(sakura.clean(sakura.parse(script)))
end

return sakura