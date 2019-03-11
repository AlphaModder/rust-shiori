shiori = require("shiori")
math = require("math")

local function isint(num)
    return type(num) == "number" and math.floor(num) == num
end

local function map_fields(...)
    local fieldnames = {...}
    return function(event)
        local fields = {}
        for _, fieldname in ipairs(fieldnames) do
            if isint(fieldname) then fieldname = string.format("Reference%.f", fieldname) end
            fields[#fields + 1] = event[fieldname] 
        end
        return unpack(fields)
    end
end

-- event OnMouseDoubleClick(x, y, character, hit, clicktype)
shiori.set_event_preprocessor("OnMouseDoubleClick", map_fields(0, 1, 3, 4, 5))