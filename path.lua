local path = {}
local strmatch = string.match
local strgmatch = string.gmatch

---Get the file extension of a path
---@param path string
---@return string? ext The file extension, or nil if non-existent.
function path.getExtension(path)
    return strmatch(path, "%.[^.]+$")
end

---Get the file name of a path
---@param path string
---@return string?
function path.getName(path)
    return strmatch(path, "[^/\\]+$")
end

---Get the path to the containing directory of the path
---@param path string
---@return string?
function path.getDirName(path)
    local idx = strmatch(path, "()[^/\\]+$")
    if idx == nil or idx == 1 then
        return nil
    end

    return string.sub(path, 1, idx - 1)
end

function path.split(path)
    local res = {}
    for v in strgmatch(path, "[^/\\]+") do
        res[#res+1] = v
    end
    return res
end

function path.splitIterator(path)
    return strgmatch(path, "[^/\\]+")
end

---Get the file name of a path without its extension
---@param path string
---@return string
function path.getNameWithoutExtension(path)
    path = strmatch(path, "[^/\\]+$")
    return strmatch(path, "(.*)%.[^.]+$")
end

function path.join(...)
    local t = ...
    if type(t) == "table" then
        return table.concat(t, "/")
    else
        return table.concat({...}, "/")
    end
end

function path.normalize(path)
    local stack = {}
    local depth = 0

    for v in strgmatch(path, "[^/\\]+") do
        if v == ".." then
            if depth <= 0 then
                stack[#stack+1] = v
            else
                stack[#stack] = nil
            end

            depth = depth - 1
        elseif v ~= "." then
            stack[#stack+1] = v
            depth = depth + 1
        end
    end

    if #stack == 0 then
        return "."
    else
        return table.concat(stack, "/")
    end
end

return path