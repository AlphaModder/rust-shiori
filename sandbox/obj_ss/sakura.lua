-- WIP safe interface to SakuraScript
-- Use sakura_qad for minimal raw version

color = require("color")

local SakuraScript = {}
function SakuraScript.empty()
    self = {}
    
    function self.write_command(name, ...)
        local args = {...}
        if #args then
            self.text = self.text .. string.format("\\%s[%s]", name, table.concat(args, ","))
        else
            self.text = self.text .. string.format("\\%s", name)
        end 
    end
    
    function update_characters(new_chars)
        if type(new_chars) == "number" then new_chars = {new_chars} end
        new_chars = Set.new(new_chars)
        
        if self.active_chars ~= new_chars then
            if #self.active_chars > 0 then
                self:write_command("_s")
            end
    
            if new_chars == Set.new{0} then 
                self.write_command("0")
            else if new_chars == Set.new{1} then 
                self.write_command("1")
            else if new_chars == Set.new{0, 1} or new_chars == Set.new{1, 0} then 
                self.write_command("_s")
            else
                self.write_command("_s", table.unpack(new_chars))
            end
        end
    
        self.active_chars = new_chars
    end

    function 

    return self
end

local FormatSet = {}
function FormatSet.empty()
    self = {}
    local DEFAULT = {"DEFAULT"}

    local function add_prop_with_default(name, func)
        func = func or function(x) self[name] = x end
        self:add_simple_prop(name, func)
        self["default_" .. name] = function()
            self[name] = DEFAULT
            return self
        end
    end
    
    local function add_simple_prop(name, func)
        func = func or function(x) self[name] = x end
        self["with_" .. name] = function(...) 
            self[name] = func(...)
            return self
        end
    end

    local function encode_bool(b)
        if b then return "1" else return "default"
    end

    add_simple_prop("outline")
    add_simple_prop("bold")
    add_simple_prop("italic")
    add_simple_prop("strike")
    add_simple_prop("underline")
    add_simple_prop("sub")
    add_simple_prop("sup")
    add_prop_with_default("color", color.from)
    add_prop_with_default("shadow_color", color.from)
    add_prop_with_default("font", function(name, filename) return {name=name, filename=filename} end)
    add_prop_with_default("font_size", function(fsize) 
        size, relative, percent = fsize:match("[%+%-]?%d+%%?")
        return {size = tonumber(size), relative = relative, percent = percent}
    end)

    function self.no_shadow()
        self.shadow_color = {}
    end

    function self.write_commands(script)
        if self.outline ~= nil then script.write_command("f", "outline", encode_bool(self.outline)) end
        if self.bold ~= nil then script.write_command("f", "bold", encode_bool(self.bold)) end
        if self.italic ~= nil then script.write_command("f", "italic", encode_bool(self.italic)) end
        if self.strike ~= nil then script.write_command("f", "strike", encode_bool(self.strike)) end
        if self.underline ~= nil then script.write_command("f", "underline", encode_bool(self.underline)) end
        if self.sub ~= nil then script.write_command("f", "sub", encode_bool(self.sub)) end
        if self.sup ~= nil then script.write_command("f", "sup", encode_bool(self.sup)) end

        if self.color ~= nil then
            if self.color == DEFAULT then
                script.write_command("f", "color", "default")
            else
                script.write_command("f", "color", floor(color.r * 255), floor(color.g * 255), floor(color.b * 255))
            end
        end

        if self.shadow_color ~= nil then
            if self.shadow_color == DEFAULT then
                script.write_command("f", "shadowcolor", "default")
            else if #self.shadow_color == 0 then
                script.write_command("f", "shadowcolor", "none")
            else
                script.write_command("f", "shadowcolor", floor(color.r * 255), floor(color.g * 255), floor(color.b * 255))
            end
        end

        if self.font ~= nil then script.write_command("f", "font", self.font.name, self.font.filename) end
        if self.font_size ~= nil then
            script.write_command("f", "height", string.format("%s%s%s", self.font_size.relative, self.font_size.size, self.font_size.percent))
        end
    end

    return self
end

function FormatSet.default()
    self = {}
    function self.write_commands(script)
        script.write_command("f", "default")
    end
end

return {
    SakuraScript = SakuraScript,
    FormatSet = FormatSet
}

