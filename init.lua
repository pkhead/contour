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

---Replace love functions to read from the mapped files if possible.
function contour.exportApi()
    -- i question my sanity
    local fs_load = love.filesystem.load
    function love.filesystem.load(name, mode)
        return fs_load(getPath(name), mode)
    end

    local fs_newFile = love.filesystem.newFile
    function love.filesystem.newFile(filename, mode)
        return fs_newFile(getPath(filename), mode)
    end

    local fs_newFileData = love.filesystem.newFileData
    function love.filesystem.newFileData(originaldata, name)
        if name == nil then
            return fs_newFileData(getPath(originaldata))
        else
            return fs_newFileData(originaldata, getPath(name))
        end
    end

    local fs_read = love.filesystem.read
    function love.filesystem.read(container, name, size)
        if size == nil then
            return fs_read(getPath(container), name)
        else
            return fs_read(container, getPath(name), size)
        end
    end

    local au_newSource = love.audio.newSource
    function love.audio.newSource(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end

        return au_newSource(filename, ...)
    end

    local fn_newBMFontRasterizer = love.font.newBMFontRasterizer
    function love.font.newBMFontRasterizer(fileName, ...)
        if type(fileName) == "string" then
            fileName = getPath(fileName)
        end

        return fn_newBMFontRasterizer(fileName, ...)
    end

    local fn_newRasterizer = love.font.newRasterizer
    function love.font.newRasterizer(fileName, ...)
        if type(fileName) == "string" then
            fileName = getPath(fileName)
        end
        
        return fn_newRasterizer(fileName, ...)
    end

    local fn_newTrueTypeRasterizer = love.font.newTrueTypeRasterizer
    function love.font.newTrueTypeRasterizer(fileName, ...)
        if type(fileName) == "string" then
            fileName = getPath(fileName)
        end
        
        return fn_newTrueTypeRasterizer(fileName, ...)
    end

    local gfx_setNewFont = love.graphics.setNewFont
    function love.graphics.setNewFont(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return gfx_setNewFont(filename, ...)
    end
    
    local gfx_validateShader = love.graphics.validateShader -- 2nd and 3rd args
    function love.graphics.validateShader(gles, vtx, frag)
        if type(vtx) == "string" then
            vtx = getPath(vtx)
        end
        if type(frag) == "string" then
            frag = getPath(frag)
        end
        return gfx_validateShader(gles, vtx, frag)
    end

    local gfx_newFont = love.graphics.newFont
    function love.graphics.newFont(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return gfx_newFont(filename, ...)
    end

    local gfx_newImage = love.graphics.newImage
    function love.graphics.newImage(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end

        return gfx_newImage(filename, ...)
    end

    local gfx_newImageFont = love.graphics.newImageFont
    function love.graphics.newImageFont(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end

        return gfx_newImageFont(filename, ...)
    end

    local gfx_newShader = love.graphics.newShader -- 1st and 2nd args
    function love.graphics.newShader(vtx, pix)
        if type(vtx) == "string" then
            vtx = getPath(vtx)
        end

        if type(pix) == "string" then
            pix = getPath(pix)
        end

        return gfx_newShader(vtx, pix)
    end

    local gfx_newVideo = love.graphics.newVideo
    function love.graphics.newVideo(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return gfx_newVideo(filename, ...)
    end

    local img_newCompressedData = love.image.newCompressedData
    function love.image.newCompressedData(filename)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return img_newCompressedData(filename)
    end

    local img_newImageData = love.image.newImageData
    function love.image.newImageData(filename)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return img_newImageData(filename)
    end

    local snd_newDecoder = love.sound.newDecoder
    function love.sound.newDecoder(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return snd_newDecoder(filename, ...)
    end

    local snd_newSoundData = love.sound.newSoundData
    function love.sound.newSoundData(filename, ...)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return snd_newSoundData(filename, ...)
    end

    local vid_newVideoStream = love.video.newVideoStream
    function love.video.newVideoStream(filename)
        if type(filename) == "string" then
            filename = getPath(filename)
        end
        return vid_newVideoStream(filename)
    end
end

return contour