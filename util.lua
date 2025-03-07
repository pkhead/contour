local nativefs = require("nativefs")
local util = {}

---Compare modification times to determine if an output file is out of date.
---@param srcPath string The path to the source file.
---@param dstPath string The path to the file generated using the source file.
---@return boolean status True if the source file was modified later than the destination file, or if the destination file does not exist.
function util.isOutOfDate(srcPath, dstPath)
    local srcInfo = assert(nativefs.getInfo(srcPath), ("path '%s' does not exist"):format(srcPath))
    local dstInfo = nativefs.getInfo(dstPath)

    if dstInfo == nil or dstInfo.modtime == nil or srcInfo.modtime == nil then
        return true
    end

    return srcInfo.modtime >= dstInfo.modtime
end

---Execute a command
---@param programName string Name or path of the program.
---@param ... string The arguments to pass into the program.
function util.execute(programName, ...)
    local args = {programName, ...}

    for i=1, #args do
        args[i] = "\"" .. args[i] .. "\""
    end
    
    if jit.os == "Windows" then
        os.execute("\"" .. table.concat(args, " ") .. "\"")
    else
        os.execute(table.concat(args, " "))
    end
end

local rng = love.math.newRandomGenerator(os.time())
local possibleChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
function util.generateUid()
    local t = {}
    for i=1, 8 do
        t[i] = string.byte(possibleChars, rng:random(1, string.len(possibleChars)))
    end
    return string.char(unpack(t))
end

---Escapes special characters in a given string so that it is able to be correctly parsed as a string literal in a Lua parser.
---@param str string
---@return string
function util.escapeString(str)
    local res = str
        :gsub("\a", "\\\a")
        :gsub("\b", "\\\b")
        :gsub("\f", "\\\f")
        :gsub("\n", "\\\n")
        :gsub("\r", "\\\r")
        :gsub("\v", "\\\v")
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\t", "\\\t")
    local res = string.gsub(str, "\"", "\\\"")
    return res
end

do
    local tinsert = table.insert
    local tab = "    "

    local function rec(out, indent, t)
        if type(t) == "function" or type(t) == "userdata" or type(t) == "thread" then
            error(("%s is not serializable"):format(type(t)))
        end

        if type(t) == "table" then
            tinsert(out, "{\n")
            local indent2 = indent .. tab
            
            -- numeric list
            if t[1] ~= nil then
                for i, v in ipairs(t) do
                    tinsert(out, indent2)
                    rec(out, indent2, v)
                    tinsert(out, ",\n")
                end
            else
                local keys = {}
                for k, _ in pairs(t) do
                    table.insert(keys, k)
                end
                table.sort(keys)

                for _, k in ipairs(keys) do
                    local v = t[k]
                    if type(k) == "table" then
                        error("table is not serializable as a key")
                    end

                    tinsert(out, indent2)
                    tinsert(out, "[")
                    rec(out, 0, k)
                    tinsert(out, "] = ")
                    rec(out, indent2, v)
                    tinsert(out, ",\n")
                end
            end

            tinsert(out, indent)
            tinsert(out, "}")
        
        elseif type(t) == "string" then
            table.insert(out, "\"")
            table.insert(out, util.escapeString(t))
            table.insert(out, "\"")
        else
            table.insert(out, tostring(t))
        end
    end

    ---Serialize a Lua value (including tables) into a string
    ---@param value any The value to serialize
    ---@return string res
    function util.serialize(value)
        local out = {}
        rec(out, "", value)
        return table.concat(out)
    end
end

return util