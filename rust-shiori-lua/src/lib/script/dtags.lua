local utils = rsl_require("utils")
local sakura = rsl_require("script.sakura")

local dtags = { public = {} }

local TAG_LIST_METATABLE = { 
    __dtags = function(obj) return obj end,
    __concat = function(a, b) return utils.extend(dtags.todtags(a), dtags.todtags(b)) end
}

local function TagList(tags) return setmetatable(tags, TAG_LIST_METATABLE) end

function dtags.todtags(obj)
    if getmetatable(obj) and getmetatable(obj).__dtags then 
        return getmetatable(obj).__dtags(obj)
    end
    return TagList{tostring(obj)}
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