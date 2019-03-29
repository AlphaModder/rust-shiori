local dialect = {}

local function scan_table(scanner, arg)
    local data = {}
    local names = {}
    local i = 1
    repeat
       local name, value = scanner(arg, i)
       if name ~= nil then data[name], names[name] = value, true end
       i = i + 1
    until name == nil
    return data, names
end

local function create_expr_env(n)
    n = n or 1
    local env = {}
    env.locals, env.local_names = scan_table(debug.getlocal, 2 + n)
    env.upvalues, env.upvalue_names = scan_table(debug.getupvalue, debug.getinfo(1 + n, "f").func)
    env.outer = _ENV and (env.locals["_ENV"] or env.upvalues["_ENV"] or _ENV)

    return setmetatable(env, {
        __index = function(env, k) 
            if env.upvalue_names[k] then return env.upvalues[k] end
            if env.local_names[k] then return env.local_names[k] end
            return env.outer[k]
        end
    })
end

local function resolve_expr(expr, env)
    local fn, err = load("return "..expr, "expression `"..expr.."`", "t", env)
    if fn then return fn() else error(err, 0) end
end

-- breaks text into tokens like the following:
-- { 
--  type = "sakura", "begin_choice", "end_choice", "choice"
--  value = choice value for choices
--  text = text to display 
-- }
function dialect.tokenize(text, n)
    n = n or 1

    -- Avoid recomputing locals and upvalues for every expression.
    local env = create_expr_env(n + 1)

    -- Resolve substitutions
    text = text:gsub("$%b{}", function(block)
        local code, fmt = block:match("{(.*):(%%.*)}")
        code = code or block:match("{(.*)}")
        local content = resolve_expr(code, env)
        return fmt and string.format(fmt, content) or tostring(content)
    end)


end

