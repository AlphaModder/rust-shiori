Object = {}

local function create_public_metatable(table, public_names)
    local meta = {}
    for key in public do
        meta[key] = function(this, ...)
            setmetatable(this, table)
            this[key](this, ...)
            setmetatable(this, meta)
        end
    end
    meta.__index = meta
    return meta
end

local function make_constructor(name, init, metatable)
    table = {}
    table[name] = function(...)
        obj = init(...)
        setmetatable(obj, metatable)
        return obj
    end
end

function Object.extend()
    
end

return Object