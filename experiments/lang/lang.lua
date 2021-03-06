local lpeg = require("lpeg")
local re = require("re")
local utils = require("utils")

local FILE_TEMPLATE = [[
    local __LANGLIB = require("langlib")
    local __SHIORI_EVENTS = { }

    %s
    
    return __SHIORI_EVENTS
]]

-- TODO:
-- - script call stmt/expr(?) "call ident args"
-- - richer non-lua expressions? (binops)
-- - top-level vars in script files
-- - export functions, vars from script files

local GRAMMAR = re.compile([[
    s <- %s+
    lexpr <- {| {:tag: '' -> 'lexpr' } 'LUAEXPRESSION' |}
    lstmt <- {| {:tag: '' -> 'lstmt' } 'LUASTATEMENT' |}
    lkeyword <- 'and' / 'break' / 'do' / 'else' / 'elseif' / 'end' / 'false' / 'for' / 'function' / 'if' /
        'in' / 'local' / 'nil' / 'not' / 'or' / 'repeat' / 'return' / 'then' / 'true' / 'until' / 'while'
    
    keyword <- lkeyword / 'event' / 'script' / 'choose' / 'raise' / '__LANGLIB' / '__SHIORI_EVENTS'
    ident <- ([_%a][_%w]*) - keyword

    ilist <- s? (ident s? ',' s?)* ident? s?
    elist <- {| s? (anyexpr s? ',' s?)* anyexpr? s? |}

    slit <- {| {:text: [^\$%'] / (\[\']) :} |}
    dlit <- {| {:text: [^\$%"] / (\[\"]) :} |}
    interp <- {| {:text: '' -> '%s' :} ('%(' s? {:interp: anyexpr :} s? ')') / ('$(' s? {:interp: lexpr :} s? ')') |}
    interpesc <- {| '\'? {:text: [$%] :} |}
    sstr <- {| {:tag: '' -> 'string' :} {:quote: "'" :} {:segments: {| (slit / interp / interpesc)* |} :} "'" |}
    dstr <- {| {:tag: '' -> 'string' :} {:quote: '"' :} {:segments: {| (dlit / interp / interpesc)* |} :} '"' |}
    string <- sstr / dstr

    number <- {| {:tag: '' -> 'number' :} {:text: '-'? (%d*\.)? %d+ :} |}
    var <- {| {:tag: -> 'var' :} {:name: ident :} |}
    paren <- {| {:tag: '' -> 'paren' :} '(' s? {:inner: anyexpr :} s? ')' }
    field <- {| {:tag: -> 'field' :} {:obj: anyexpr :} "." {:field: ident :} |}
    call <- {| {:tag: '' -> 'call' :} {:callee: anyexpr :} '(' {:args: elist :} ')' |}
    say <- {| {:tag: '' -> 'say' :} {:char: ident } s {:expr: anyexpr } |}
    choose <- {| {:tag: '' -> 'choose' :} 'choose' s {:choices: elist :} 'end' |}

    expr <- string / number / var / paren / field / call / say / choose
    anyexpr <- expr / ('$(' s? lexpr s? ')')

    local <- {| {:tag: '' -> 'local' :} 'local' s {:name: ident :} s? (= s? {:expr: anyexpr :})? |}
    assign <- {| {:tag: '' -> 'assign' :} {:name: ident :} s? '=' s? {:expr: anyexpr :} |}
    if <- {| {:type: '' -> 'if' :} 'if' s {:cond: anyexpr :} s 'then' s {:body: {| stmt* |} :} |}
    elseif <- {| {:type: '' -> 'elseif' :} 'elseif' s {:cond: anyexpr :} s 'then' s {:body: {| stmt* |} :} |}
    else <- {| {:type: '' -> 'else' :} 'else' s {:body: {| stmt* |} :} |}
    ifstat <- {| {:tag: '' -> 'ifstmt' :} {:cases: {| if elseif* else? |} :} 'end' |}
    while <- {| {:tag: ('while' / 'until') :} s {:cond: anyexpr :} s 'do' s {:body: {| stmt* |} :} 'end'
    for <- {| {:tag: '' -> 'for' :} 'for' s {:var: ident s? (',' ilist)? :} s 'in' s {:iter: lexpr :} s 'do' s {:body: {| stmt* |} :} 'end' |}
    return <- {| {:tag: '' -> 'return' :} 'return' s {:val: anyexpr :} |}
    stmt <- (say / call / local / assign / ifstat / while / for / 'continue' / 'break' / return / ('$' s? lstmt)) s

    func <- {| {:type: ('event' / 'script' / 'function') } s {:name: ident :} ((s? '(' {:arglist: ilist :} ')' s?) / s) stmt* 'end' |}
    file <- func / ('$' s? lstat) 
]])

local compiler = { }

function compiler.compile(pattern, builder, ...)
    local params = {...}
    local pos, param = 1, 1
    while true do
        local s, e, func
        for pat, f in pairs(compiler.patterns) do
            func = f
            for prefix in {"^%%", "[^%%]%%"} do
                s, e = pattern:find(prefix .. pat, pos)
                if s ~= nil then break end
            end
            if s ~= nil then break end
        end
        if s == nil then break end
        builder.write(pattern:sub(pos, s - 1))
        func(params[param], builder)
        params = params + 1
        pos = e + 1
    end
    builder.write(pattern:sub(pos))
end

function compiler.compile_string(str, builder)
    local interps = nil
    for seg in str.segments do 
        if seg.interp ~= nil then 
            if interps == nil then interps = {} end
            interps[#interps + 1] = seg.interp
        end 
    end
    
    if interps ~= nil then
        for seg in str.segments do
            if seg.interp == nil then seg.text = seg.text:gsub("%", "%%") end
        end
        builder.write("string.format(")
    end

    builder.write(str.quote)
    for seg in str.segments do builder.write(seg.text) end
    builder.write(str.quote)

    if interps ~= nil then
        for expr in interps do
            builder.write(", ")
            compiler.compile_expr(expr, builder)
        end
        builder.write(")")
    end
end

function compiler.compile_expr(expr, builder)
    if expr.tag == "string" then
        compiler.compile_string(expr, builder)
    elseif expr.tag == "number" then
        builder.write(expr.text)
    elseif expr.tag == "var" then
        builder.write(expr.name)
    elseif expr.tag == "paren" then
        compiler.compile("(%e)", builder, expr.inner)
    elseif expr.tag == "say" then
        compiler.compile("script.say(%t, %e)", builder, expr.char, expr.expr)
    elseif expr.tag == "choose" then
        builder.write("__LANGLIB.choose{")
        for _, choice in ipairs(expr.choices) do compiler.compile("function() %e end,", builder, choice) end
        builder.write("}()")
    end
end

function compiler.compile_file(file)
    builder = utils.StringBuilder()
    for item in ipairs(file) do
        if item.tag == "func" then compiler.compile_func(item, builder)
        elseif item.tag == "gvar" then compiler.compile_gvar(item, builder) -- NYI
        elseif item.tag == "lstat" then builder.writeline(item[1]) end
    end
    return string.format(FILE_TEMPLATE, builder.build())
end

function compiler.compile_func(func, builder)
    local arglist = func.arglist or ""
    if func.type == "event" or func.type == "script" then
        if arglist ~= "" then arglist = string.format("script, %s", arglist) else arglist = "script" end
    end
    builder.writeline("local function %s(%s)", func.name, arglist)
    compiler.compile_stmts(func.body, builder)
    builder.writeline("end")
    if func.type == "event" then builder.writeline("__SHIORI_EVENTS['%s'] = %s", func.name) end
end

function compiler.compile_stmts(stmts, builder)
    for stmt in stmts do compiler.compile_stmt(stmt, builder) end
end

function compiler.compile_stmt(stmt, builder)
    local stmt = stmt[1]
    if stmt.tag == "say" then
        compiler.compile("script.say(%t, %e)", builder, stmt.char, stmt.expr)
    elseif stmt.tag == "local" then 
        builder.write("local %s", stmt.name)
        if stmt.expr ~= nil then compiler.compile(" = %e", builder, stmt.expr) end
        builder.writeline()
    elseif stmt.tag == "assign" then
        compiler.compile("%t = %e\n", builder, stmt.name, stmt.expr)
    elseif stmt.tag == "ifstmt" then
        for case in stmt.cases do
            builder.write(case.type)
            if case.cond then compiler.compile(" %e then\n", builder, case.cond, case.body) end
            compiler.compile_stmts(case.body)
        end
        builder.writeline("end")
    elseif stmt.tag == "while" or stmt.tag == "until" then
        builder.writeline("%s %s do", stmt.tag, stmt.cond)
        builder.compile_stmts(stmt.body)
        builder.writeline("end")
    elseif stmt.tag == "for" then
        builder.write("for %s in ", stmt.var)
        builder.compile_expr(stmt.iter)
        builder.writeline(" do")
        builder.compile_stmts(stmt.body)
        builder.writeline("end")
    elseif stmt.tag == "continue" or stmt.tag == "break" then
        builder.writeline(stmt.tag)
    elseif stmt.tag == "return" then
        builder.write("return ")
        builder.compile_expr(stmt.val)
        builder.writeline()
    elseif stmt.tag == "lstmt" then
        builder.write(stmt.lua)
    else
        error("Invalid statement!")
    end
end

compiler.patterns = { 
    t = function(a, b) b.write(tostring(a)) end, 
    e = compiler.compile_expr,
    s = compiler.compile_stmt,
    S = compiler.compile_stmts,
}

local lang = { path = "" }

function lang.compile(str)
    local ast = GRAMMAR:match(str)
    return compiler.compile_file(str)
end

function lang.load_str(str)
    return load(lang.compile(str))
end

function lang.load_file(path)
    local file = io.load_file(path, "rb")
    local content = file:read("*all")
    file:close()
    return lang.load_str(content)
end

package.loaders[#package.loaders + 1] = function(module)
    local file, err = package.searchpath(lang.path)
    if file == nil then 
        return err 
    else
        return function()
            return lang.load_file(file)
        end
    end
end

return lang