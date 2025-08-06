--- Macula library.
-- Library for working with simple config language MACL. It is somewhat similiar to TOML.
-- macl format example:
-- @usage -- macl format example
-- -- Comment
-- bebra = ""
-- <somecategory>
-- pashalko = 744 -- indentation is optional
--      <somecategory.subcategory>
--      aboba = true
--      abobra = false
-- @usage -- maculib usage example with file above
-- local maculib = require "maculib"
-- local conf, dirty = maculib.loadconfig("example.macl",  
-- {
--     bebra = maculib.stringnonempty("aboba"),  
--     bebrila = maculib.type("string", "abobra"),  
--     somecategory = {
--         pashalko = maculib.type("number", 744),  
--         subcategory = {
--             aboba = maculib.type("number", 228), 
--             abobra = maculib.type("boolean", true)
--         }
--     } 
-- })  
-- print(dirty) -- true
-- print(conf.bebra) -- "aboba"
-- print(conf.bebrila) -- "abobra" -- bebrila was absent in config, so its type was nil. Due to maculib.type in proto, it is now string.
-- print(conf.somecategory.pashalko) -- 744
-- print(conf.somecategory.subcategory.aboba) -- 228
-- print(conf.somecategory.subcategory.abobra) -- false, because this exact value wasn't wrong.
-- @author Maksimka
-- @license MIT
-- @module maculib
-- @alias gr
-- @todo add support for category comments
-- @todo add support for arrays/lists
local gr = {}
--- Edition of Macula
gr.edition = "Lutea"
--- Version of Macula
gr.version = "1.3.8"
--- Name of Macula. Edition + version.
gr.name = gr.edition .. " v" .. gr.version

--- Category match
gr.categorymatch = "^%s*<%s*([%w_%-%.]*)%s*>%s*"
--- Category Formatstring
gr.categoryfmt = "< %s >\n"
--- Match for dot separated names
gr.dotseparatedmatch = "[%w_%-]+"
--- Match for string values
gr.stringvaluematch = "^%s*(%w+)%s*=%s*\"(.-)\"%s*"
--- Formatstring for number values
gr.stringvaluefmt = "%s = \"%s\"\n"
--- Match for boolean values
gr.numbervaluematch = "^%s*(%w+)%s*=%s*([+-]?[%d%.]+)%s*"
--- Formatstring for number values
gr.numbervaluefmt = "%s = %s\n"
--- Match for boolean values
gr.boolmatch = "^%s*(%w+)%s*=%s*([truefalsTRUEFALS]+)%s*"
--- Formatstring for boolean values
gr.boolfmt = "%s = %s\n"
--- Formatstring for comments
gr.commentfmt = "-- %s\n"

--- Checks config for errors and applies defaults
-- @param conf config
-- @param proto prototype. For each key in proto, looks for same value in conf and feeds it to value of this key in proto.
-- If value in proto is function, which completed without errors, sets conf[key] to it's second returned value if it's first returned value is not false or nil.
-- If value in proto is table, does literally same for each function in it.
-- @return true if config was changed
function gr.checkconfig(conf, proto)
    local dirty = false
    if conf == nil then conf = {} end
    for k, v in pairs(proto) do
        local val = conf[k]
        if type(val) == 'table' then
            dirty, conf[k] = dirty or gr.checkconfig(conf[k], proto[k])
        elseif type(v) == 'table' then
            for _, vf in pairs(v) do
                if type(v) ~= "function" then goto skip end
                local err, err2, def = pcall(v, val, k)
                local doov = err and err2
                dirty = dirty or (not err) or err2
                if doov then
                    conf[k] = def
                end
                ::skip::
            end
        elseif type(v) == 'function' then
            local err, err2, def = pcall(v, val, k)
            local doov = err and err2
            dirty = dirty or (not err) or err2
            if doov then
                conf[k] = def
            end
        end
    end
    return dirty, conf
end

--- Parses config file
-- @param data data
-- @param proto prototype, may be nil.
-- If not nil, runs maculib.checkconfig on resulting config before returning.
-- @return config
-- @see maculib.checkconfig
function gr.parseconfig(data, proto)
    local out, dirty = {}, false
    if data then
        local category = out
        for line in data:gmatch("[^\r\n]+") do -- thanks to wojbie for help
            local categoryname = line:match(gr.categorymatch)
            if categoryname then
                category = out
                for v in categoryname:gmatch(gr.dotseparatedmatch) do
                    if not category[v] then category[v] = {} end
                    category = category[v]
                end
                goto continue
            end
            local name, str = line:match(gr.stringvaluematch)
            if name and str then
                category[name] = str
                goto continue
            end
            local name, number = line:match(gr.numbervaluematch)
            if name and number then
                category[name] = tonumber(number)
                goto continue
            end
            local name, bool = line:match(gr.boolmatch)
            if name and bool then
                category[name] = bool:sub(1, 1):lower() == "t"
                goto continue
            end
            ::continue::
        end
    end
    if proto then dirty = gr.checkconfig(out, proto) end
    return out, dirty
end

--- Small utility function for indentation.
function gr.tabulate(depth)
    depth = math.max(depth, 0)
    return string.rep("    ", depth)
end

--- Serializes config to string.
-- @param conf config to serialize.
-- @param comm comments. Must be a table with keys corresponding to config keys. If value is string, it's used as comment. If value is table, each string in it is used as comment
-- @param prefix prefix. Used internally for categories
-- @param depth depth. Used internally for indentation
-- @treturn string Serialized config.
-- @see maculib.parseconfig
-- @see maculib.checkconfig
-- @todo add support for category comments
function gr.serializeconfig(conf, comm, prefix, depth)
    comm = (comm or conf.__comm) or {}
    depth = depth or 0
    local format = string.format
    local buffer = gr.tabulate(depth-1) .. (prefix and format(gr.categoryfmt, prefix) or "")
    local serializelater = {}
    for k, v in pairs(conf) do
        if comm[k] then
            if type(comm[k]) == 'table' then
                for _, v in ipairs(comm[k]) do
                    buffer = buffer .. gr.tabulate(depth) .. format(gr.commentfmt, v)
                end
            elseif type(comm[k]) == 'string' then
                buffer = buffer .. gr.tabulate(depth) .. format(gr.commentfmt, comm[k])
            end
        end
        if type(v) == 'table' then
            serializelater[k] = v
        elseif type(v) == 'string' then
            buffer = buffer .. gr.tabulate(depth) .. format(gr.stringvaluefmt, k, v)
        elseif type(v) == 'number' then
            buffer = buffer .. gr.tabulate(depth) .. format(gr.numbervaluefmt, k, v)
        elseif type(v) == 'boolean' then
            buffer = buffer .. gr.tabulate(depth) .. format(gr.boolfmt, k, v)
        end
    end
    for k, v in pairs(serializelater) do
        buffer = buffer .. gr.serializeconfig(v, comm[k], prefix and (prefix.."."..k) or k, depth + 1)
    end
    return buffer
end

--- Return path that will be used internally to save and load config.
-- @param path original path
-- @treturn string modified path
-- @usage maculib.confname("/home/user/config") -- "/home/user/config.macl"
function gr.confname(path)
    if not path:find("%.%w+$") then path = path .. ".macl" end -- "MAksim's Config Language"
    return path
end

--- Saves config to file.
-- @param conf config to save
-- @param path path to save to
-- @param comm comments. See maculib.serializeconfig
-- @see maculib.serializeconfig
function gr.saveconfig(conf, path, comm)
    path = gr.confname(path)
    local file = fs.open(path, "w+")
    file.write(gr.serializeconfig(conf, comm))
    file.close()
end

--- Loads config from file.
-- @param path path to load from
-- @param proto config prototype. See maculib.checkconfig
-- @treturn table config, loaded from file
-- @see maculib.checkconfig
function gr.loadconfig(path, proto)
    path = gr.confname(path)
    local file = fs.open(path, "r")
    local data = file and file.readAll() or ''
    if file then file.close() end
    return gr.parseconfig(data, proto)
end

--- Small utilities for config.  
-- sal.type(type, default) - type check.  
-- sal.stringnonempty(default) - nonempty string.
--- @usage maculib.loadconfig("bebra", {bebra = sal.type(number, 228)})
--- -- returns {bebra = 228} and true if bebra is not number
gr.sal = {}
function gr.sal.type(typec, def)
    return function(value)
        if type(value) == typec then return false end
        return true, def
    end
end
function gr.sal.stringnonempty(def)
    return function(value)
        if type(value) == 'string' and value:len() > 0 then return false end
        return true, def
    end
end
function gr.sal.hook(hook, f)
    return function(value)
        local err, err2, def = pcall(hook, value)
        hook(value, def)
        if not err then error(err2) else
            return err2, def
        end
    end
end
function gr.sal.log(dolog, fmt, fmt2)
    if not dolog then return function() end end
    return function(value, def)
        if def and fmt then print(string.format(fmt, value, def)) elseif fmt2 then print(string.format(fmt2, value)) end
    end
end
function gr.sal.presentin(list, def)
    for k, _ in pairs(list) do
        if k == def then goto after end
    end
    error("Default value is present in list")
    ::after::
    return function(value)
        for k, _ in pairs(list) do
            if k == value then return false end
        end
        return true, def
    end
    
end
return gr