local lpeg = require("lpeg")
local re = require("re")
local utils = require("utils")

local GRAMMAR = re.compile([[
    s <- %s+
    lexpr <-
    lstmt <-
    lkeyword <- 'and' / 'break' / 'do' / 'else' / 'elseif' / 'end' / 'false' / 'for' / 'function' / 'if' /
        'in' / 'local' / 'nil' / 'not' / 'or' / 'repeat' / 'return' / 'then' / 'true' / 'until' / 'while'
    
    keyword <- lkeyword / 'event' / 'script' / 'choose' / 'raise' / '__LANGLIB' / '__SHIORI_EVENTS'
    ident <- ([_%a][_%w]*) - keyword
    arglist <- '(' s? (ident s? ',' s?)* ident? s? ')'

    number <- '-'? (%d*\.)? %d+
    say <- ident s anyexpr
    simplestr <- ('"' .* '"') / ("'" [^\]* "'")
    longstr <- 

    string <- simplestr / longstr

    expr <- number / string / say
    anyexpr <- expr / ('$(' lexpr ')')

    local <- 'local' s ident s? = s? anyexpr
    assign <- ident s? '=' s? anyexpr
    if <- 'if' s anyexpr s 'then' s
    elseif <- 'elseif' s anyexpr s 'then' s stmt*
    else <- 'else' s stat*
    ifstat <- if elseif* else? 'end'
    while <- ('while' / 'until') s anyexpr s 'do' s stmt* 'end'
    for <- 'for' s lexpr s 'in' s lexpr s 'do' s stmt* 'end'
    return <- 'return' s anyexpr
    stmt <- (say / local / assign / ifstat / while / for / 'continue' / 'break' / return / ('$' lstmt)) s

    func <- ('event' / 'script' / 'function') s ident ((s? arglist? s?) / s) stmt* 'end
    file <- func / ('$' lstat) 
]])

local FILE_TEMPLATE = [[
    local __LANGLIB = require("langlib")
    local __SHIORI_EVENTS = { }

    %s
    
    return __SHIORI_EVENTS
]]

local compiler = {}

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
        builder.writeline("script.say(%s)", stmt.text)
    elseif stmt.tag == "local" then 
        builder.write("local %s = ", stmt.name)
        compiler.compile_expr(stmt.expr, builder)
        builder.writeline()
    elseif stmt.tag == "assign" then
        builder.write("%s = ", stmt.name)
        compiler.compile_expr(stmt.expr, builder)
        builder.writeline()
    elseif stmt.tag == "ifstmt" then
        for case in stmt.cases do
            builder.write("%s ", case.type)
            if case.cond then 
                compiler.compile_expr(case.cond) 
                builder.writeline(" then")
            end
            compiler.compile_stmts(case.body)
        end
        builder.writeline("end")
    elseif stmt.tag == "while" or stmt.tag == "until" then
        builder.writeline("%s %s do", stmt.tag, stmt.cond)
        builder.compile_stmts(stmt.body)
        builder.writeline("end")
    elseif stmt.tag == "for" then
        builder.writeline("for %s in %s do", stmt.var, stmt.iter)
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

local lang = {}

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

return lang