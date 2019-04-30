local utils = {}

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

function utils.append(array, val)
    array[#array + 1] = val
end

function utils.extend(a1, a2)
    for _, item in ipairs(a2) do utils.append(a1, item) end
end

function utils.dup(array)
    new = {}
    utils.extend(new, array)
    return new
end

function utils.choose(choices) return choices[math.rand(1, #choices)] end

local set_meta = {
    __lt = function(a, b) return a <= b and not (b <= a) end,
    __eq = function(a, b) return a <= b and b <= a end,
    __le = function(a, b)
        for k in pairs(a) do if not b[k] then return false end end
        return true
    end,
    __add = function(a, b)
        local new = utils.Set{}
        for k, v in pairs(a) do if v then new[k] = v end end
        for k, v in pairs(b) do if v then new[k] = v end end
        return new
    end,
    __len = function(s)
        local n = 0
        for k, v in pairs(s) do if v then n = n + 1 end end
        return n
    end
}

function utils.Set(table)
    local set = {}
    setmetatable(set, set_meta)
    for _, l in ipairs(table) do set[l] = true end
    return set
end

function utils.set_to_table(set)
    local table = {}
    for k, v in pairs(set) do if v == true then table[#table + 1] = k end end
    return table
end

function utils.set_to_string(set)
    return table.concat(utils.set_to_table(set), ", ")
end

function utils.StringBuilder()
    local strings = {}
    return {
        write = function(s, ...) strings[#strings + 1] = string.format(s or "", ...) end,
        writeline = function(s, ...) strings[#strings + 1] = (string.format(s or "", ...) .. "\n") end,
        build = function() return table.concat(strings) end
    }
end

function utils.istable(obj) return type(obj) == "table" end

function utils.second(_, b) return b end

return utils