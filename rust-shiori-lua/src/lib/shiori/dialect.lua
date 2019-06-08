-- This file's implementation of interpolated strings is based on the following:
-- https://github.com/hishamhm/f-strings/blob/master/F.lua. 
-- Many thanks to hishamhm for writing it!

local utils = rsl_require("utils")
local events = rsl_require("shiori.events")
local sakura = rsl_require("sakura")
local logger = rsl_require("logger")

local dialect = {}

local function scan_table(scanner, arg)
    local data = {}
    local names = {}
    local i = 1
    repeat
       local name, value = scanner(arg, i)
       if name ~= nil then
        logger.debug("found %s", name)
        data[name], names[name] = value, true 
       end
       i = i + 1
    until name == nil
    return data, names
end

local function create_expr_env(n)
    n = n or 1
    local env = {}
    env.locals, env.local_names = scan_table(debug.getlocal, 2 + n)
    env.upvalues, env.upvalue_names = scan_table(debug.getupvalue, debug.getinfo(1 + n, "f").func)
    env.outer = env.locals["_ENV"] or env.upvalues["_ENV"]
    logger.debug(debug.traceback())
    logger.debug("level %s", n)
    return setmetatable(env, {
        __index = function(env, k)
            if env.local_names[k] then return env.locals[k] end
            if env.upvalue_names[k] then return env.upvalues[k] end
            return env.outer[k]
        end
    })
end

local function resolve_expr(expr, env)
    local fn, err = load("return "..expr, "expression `"..expr.."`", "t", env)
    if fn then return fn() else error(err, 0) end
end

local function switch_escape(s)
    local len = string.len(s)
    return string.rep("$", len // 2) .. string.rep("\\", len % 2) 
end

local function sakura_escape(text)
    return text:gsub("\n", "$n"):gsub("\\", "$\\"):gsub("[$]+", switch_escape)
end

local function ChoiceTag(result)
    return {
        to_sakura = function(i) return sakura.parse(("\\__q[Choice%s]"):format(i)) end,
        is_choice = true,
        choose = result,
    }
end

local function CloseChoiceTag()
    return { to_sakura = function(_) return sakura.parse("\\__q") end }
end

local function SakuraScript(script)
    return { to_sakura = function(_) return sakura.clean(sakura.parse(sakura_escape(script))) end }
end

local TAG_PATTERNS = {
    ["cy"] = function(_) return ChoiceTag(function() return true end) end,
    ["cn"] = function(_) return ChoiceTag(function() return false end) end,
    ["c:(.+)"] = function(env, expr) return ChoiceTag(function() return resolve_expr(expr, env) end) end,
    ["/c"] = function(_) return CloseChoiceTag() end,
}

dialect.substitute = debug.notail(function(text, n)
    n = n or 1

    -- Avoid recomputing locals and upvalues for every expression.
    local env = create_expr_env(n + 1)

    -- Resolve substitutions
    return text:gsub("$%b{}", function(block)
        local code, fmt = block:match("{(.*):(%%.*)}")
        code = code or block:match("{(.*)}")
        local content = resolve_expr(code, env)
        return fmt and string.format(fmt, content) or tostring(content)
    end)
end)

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

    -- Tokenize
    local tokens = {}
    local pos = 1
    local s, e = text:find("%b{}", pos)
    while s ~= nil do
        local contents = text:sub(s+1, e-1)
        local found_tag = false
        for pattern, tag in pairs(TAG_PATTERNS) do
            local tag_body = {contents:match(pattern)}
            if tag_body[1] ~= nil then
                found_tag = true
                utils.append(tokens, SakuraScript(text:sub(pos, s-1)))
                utils.append(tokens, tag(env, table.unpack(tag_body)))
                break
            end
        end
        if not found_tag then utils.append(tokens, SakuraScript(text:sub(pos, e))) end
        pos = e+1
        s, e = text:find("%b{}", pos)
    end
    utils.append(tokens, SakuraScript(text:sub(pos)))
    return tokens
end

return dialect