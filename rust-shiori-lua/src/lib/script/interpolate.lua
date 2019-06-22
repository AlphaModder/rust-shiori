local utils = rsl_require("utils")
local dtags = rsl_require("script.dtags")

-- If expanding a multiline string could cause a delimiter conflict, this function
-- will automatically increase the number of equals signs in its delimiters until
-- this is no longer a possibility.
local function prepare_string(str, open, close)
    local content = str:match("^%[=*%[(.*)%]=*%]$")
    if content then
        local ne = ""
        content:gsub("%](=*)", function(e) if ne:len() <= e:len() then ne = e .. "=" end end)
        return ("[%s[%s]%s]"):format(ne, content, ne), ("[%s["):format(ne), ("]%s]"):format(ne)
    end
    return str, open, close
end

-- Because multiline strings ignore the first character after their open brace when it is a newline,
-- splitting a multiline string can delete line breaks. This function duplicates all line breaks that
-- follow such an open brace, except for the very first, which was present in the original and really
-- should be ignored.
local function fix_newlines(str, open)
    local open_pat = open:gsub("%[", "%%[")
    return str:gsub(open_pat .. "\n", open .. "\n\n"):gsub("^" .. open_pat .. "\n\n", open .. "\n")
end

local function expand_string(str, open, close, escapes)
    local str, open, close = prepare_string(str, open, close)
    for prefix, tags in pairs(dtags.TAGS) do
        local pattern = ("(\\*)(%s)(%%b{})"):format(prefix)
        str = str:gsub(pattern, function(slashes, pfull, pkeep, body)
            if (not escapes) or (slashes .. pfull):match("\\*"):len() % 2 == 0 then 
                for tag, expr in pairs(tags) do
                    local tag_match = {body:sub(2, #body - 1):match(tag)}
                    if tag_match[1] ~= nil then return ("%s%s%s .. %s .. %s"):format(
                        slashes, pkeep, close, expr:format(table.unpack(tag_match)), open
                    ) end
                end
            end
            return ("%s%s{%s}"):format(slashes, pfull, body)
        end)
    end
    return ("(%s)"):format(fix_newlines(str, open))
end

local string_types = {
    {"'", "\\*'", function(o, c) return c:len() % 2 == 1 end, true},
    {'"', '\\*"', function(o, c) return c:len() % 2 == 1 end, true},
    {'%[=*%[', '%]=*%]', function(o, c) return o:len() == c:len() end, false},
}

local function find_open(file, pos)
    local os, oe, stype
    for _, st in ipairs(string_types) do
        local s, e = file:find(st[1], pos)
        if s and (os == nil or s < os) then 
            os, oe, stype = s, e, st
        end
    end
    return os, oe, stype
end

local function find_close(file, os, oe, stype)
    local pos = oe + 1
    while true do
        local cs, ce = file:find(stype[2], pos)
        if not cs then return nil end
        if stype[3](file:sub(os, oe), file:sub(cs, ce)) then return cs, ce else pos = ce + 1 end
    end
end

local function process_file(file)
    local buf = {}
    local pos = 1
    while true do
        local os, oe, stype = find_open(file, pos)
        if not os then break end
        local cs, ce = find_close(file, os, oe, stype)
        if not cs then break end
        utils.append(buf, file:sub(pos, os - 1))
        utils.append(buf, expand_string(file:sub(os, ce), file:sub(os, oe), file:sub(cs, ce), stype[4]))
        pos = ce + 1
    end
    utils.append(buf, file:sub(pos))
    return table.concat(buf)
end



return {
    process_file = process_file,
    public = public,
}