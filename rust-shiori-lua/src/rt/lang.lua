local lang = {}
local lpeg = require("lpeg")
local re = require("re")

local GRAMMAR = re.compile([[
    s <- %s+
    lexp <-
    lstat <-
    lkeyword <- 'and' / 'break' / 'do' / 'else' / 'elseif' / 'end' / 'false' / 'for' / 'function' / 'if' /
        'in' / 'local' / 'nil' / 'not' / 'or' / 'repeat' / 'return' / 'then' / 'true' / 'until' / 'while'
    
    keyword <- lkeyword / 'event' / 'script' / 'choose' / 'raise' 
    ident <- ([_%a][_%w]*) - keyword
    arglist <- '(' s? (ident s? ',' s?)* ident? s? ')'

    say <- ident s? anyexp 
    
    exp <- say
    anyexp <- exp / ('$(' lexp ')')

    local <- 'local' s ident s? = s? anyexp
    if <- 'if' s anyexp s 'then' s
    elseif <- 'elseif' s anyexp s 'then' s stat*
    else <- 'else' s stat*
    ifstat <- if elseif* else? 'end'
    while <- ('while' / 'until') s anyexp s 'do' s stat* 'end'
    for <- 'for' s lexp s 'in' s lexp s 'do' s stat* 'end'
    return <- 'return' s anyexp
    stat <- (say / var / while / ifstat / for / return / 'continue' / 'break' / ('$' lstat)) s
   
    func <- ('event' / 'script' / 'function') s ident ((s? arglist? s?) / s) stat* 'end
    file <- func / ('$' lstat) 
]])

local PRELUDE = [[
    shiori = require("shiori")

]]

local KEYWORDS = {"$", "event", "script", "local", "goto"}

local function parse_lines(str)
    str = str:gsub("(\\*)(/?)[\r\n]+", 
        function(bslashes, fslash)
            if fslash == "/" and string.len(bslashes) % 2 == 0 then return "" else return nil end
        end
    )
    local lines = {}
    for s in str:gmatch("[^\r\n]+") do table.insert(lines, s) end
    return lines
end

function lang.load_file(path)
    local file = io.load_file(path, "rb")
    local content = file:read("*all")
    file:close()
    return lang.load_str(content)
end

function lang.load_str(str)
    text = ""
    lines = parse_lines(str)
end

function Parser(str)

end


return lang