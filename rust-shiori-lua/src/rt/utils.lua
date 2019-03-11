local utils = {}

local set_meta = {
    __lt = function(a, b) return a <= b and not (b <= a) end,
    __eq = function(a, b) return a <= b and b <= a end,
    __le = function(a, b)
        for k in pairs(a) do
            if not b[k] then return false end
        end
        return true
    end
}

function utils.Set(table)
    local set = {}
    setmetatable(set, set_meta)
    for _, l in ipairs(table) do set[l] = true end
    return set
end

function utils.StringBuilder()
    local strings = {}
    return {
        write = function(s, ...) strings[#strings + 1] = string.format(s or "", ...) end,
        writeline = function(s, ...) strings[#strings + 1] = (string.format(s or "", ...) .. "\n") end,
        build = function() return table.concat(strings) end
    }
end

function utils.tostring_or_nil(val) 
    if val ~= nil then return tostring(val) else return nil end
end

function utils.remove_nils(array)
    local new = {}
    for _, item in ipairs(array) do
        if item ~= nil then new[#new + 1] = item end
    end
    return new
end

function utils.contains(array, val)
    for _, value in ipairs(array) do
        if value == val then return true end
    end
    return false
end

function utils.dup(array)
    new = {}
    for _, item in ipairs(array) do new[#new + 1] = item end
    return new
end

function utils.extend(a1, a2)
    for _, item in ipairs(a2) do a1[#a1 + 1] = item end
end

function utils.choose(choices) return choices[math.rand(1, #choices)] end

return utils