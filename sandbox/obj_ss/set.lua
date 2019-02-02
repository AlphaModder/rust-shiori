Set = { mt = {} }
    
function Set.new(table)
    local set = {}
    setmetatable(set, Set.mt)
    for _, l in ipairs(table) do set[l] = true end
    return set
end

function Set.mt.__le(a, b)    -- set containment
    for k in pairs(a) do
        if not b[k] then return false end
    end
    return true
end
  
function Set.mt.__lt(a, b)
    return a <= b and not (b <= a)
end

function Set.mt.__eq(a, b)
    return a <= b and b <= a
end

return Set