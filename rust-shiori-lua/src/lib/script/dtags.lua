local utils = rsl_require("utils")
local sakura = rsl_require("script.sakura")

local dtags = { public = {} }

local TAG_LIST_METATABLE = {
    __dtags = function(list) return list end,
}

local function TagList(tags) return setmetatable(tags, TAG_LIST_METATABLE) end

TAG_LIST_METATABLE.__concat = function(a, b)
    local tags = TagList{}
    utils.extend(tags, dtags.todtags(a))
    utils.extend(tags, dtags.todtags(b))
    return tags
end

function dtags.todtags(obj)
    if getmetatable(obj) and getmetatable(obj).__dtags then 
        return getmetatable(obj).__dtags(obj)
    end
    return TagList{dtags.public.SakuraScript(tostring(obj))}
end

local TAG_METATABLE = {
    __dtags = function(tag) return TagList{tag} end,
    __concat = TAG_LIST_METATABLE.__concat,
} 

local function TagBase() return setmetatable({}, TAG_METATABLE) end

dtags.TAGS = {
    ["([^$])$"] = {
        [".*"] = "%s" -- general substitution
    },
    ["([^${])"] = {
        ["cy"] = "_tags.ChoiceTag(function() return true end)",
        ["cn"] = "_tags.ChoiceTag(function() return false end)",
        ["c:(.*)"] = "_tags.ChoiceTag(function() return %s end)",
        ["/c"] = "_tags.CloseChoiceTag()",
    }
}

local function switch_escape(s)
    local len = string.len(s)
    return string.rep("$", len // 2) .. string.rep("\\", len % 2) 
end

local function sakura_escape(text)
    return text:gsub("\n", "$n"):gsub("\\", "$\\"):gsub("[$]+", switch_escape)
end

function dtags.public.SakuraScript(script)
    local tag = TagBase()

    function tag.to_sakura(i)
        -- Strip whitespace after non-sakura newlines for multiline strings
        local script = script:gsub("\n[\t ]+", "\n")
        if i == 1 then script = script:gsub("^[\t ]+", "") end
        return sakura.clean(sakura.parse(sakura_escape(script)))
    end

    return tag
end

function dtags.public.ChoiceTag(result)
    local tag = TagBase()

    function tag.to_sakura(i)
        return sakura.parse(("\\__q[Choice%s]"):format(i)) 
    end

    tag.is_choice = true
    tag.choose = result

    return tag
end

function dtags.public.CloseChoiceTag()
    local tag = TagBase()

    function tag.to_sakura(_)
        return sakura.parse("\\__q")
    end

    return tag
end

return dtags