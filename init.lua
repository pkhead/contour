local Path = require("contour.path")
local db = require("contour.db")

local contour = {}

---Obtain the mapped file path.
---@param path string The path to a file.
---@return string path The mapped path to the file, or the source file if the file isn't mapped.
local function getPath(path)
    path = Path.normalize(path)

    if db[path] ~= nil or db["/" .. path] ~= nil then
        return db[path]
    else
        return path
    end
end

---Check if a file path is mapped.
---@param path string The path to a file.
---@return boolean status True if the path is mapped, false if not.
local function isMapped(path)
    path = Path.normalize(path)
    return db[path] ~= nil or db["/" .. path] ~= nil
end

contour.getPath = getPath
contour.isMapped = isMapped

---Replace the love.filesystem functions to read from the mapped files if possible.
function contour.exportApi()
    local fs_load = love.filesystem.load
    local fs_newFile = love.filesystem.newFile
    local fs_newFileData = love.filesystem.newFileData
    local fs_read = love.filesystem.read

    function love.filesystem.load(name, mode)
        return fs_load(getPath(name), mode)
    end

    function love.filesystem.newFile(filename, mode)
        return fs_newFile(getPath(filename), mode)
    end

    function love.filesystem.newFileData(originaldata, name)
        if name == nil then
            return fs_newFileData(getPath(originaldata))
        else
            return fs_newFileData(originaldata, getPath(name))
        end
    end

    function love.filesystem.read(container, name, size)
        if size == nil then
            return fs_read(getPath(container), name)
        else
            return fs_read(container, getPath(name), size)
        end
    end
end

return contour