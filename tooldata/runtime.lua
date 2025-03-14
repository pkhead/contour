-- runtime support for [contour](https://github.com/pkhead/contour)
--
-- Copyright 2025 pkhead
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software
-- and associated documentation files (the “Software”), to deal in the Software without
-- restriction, including without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
-- BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local contour = {}

local db
do
    local chunk = love.filesystem.load(require("contour.conconf").exportDirectory .. "/" .. ".db")
    db = chunk and chunk()
end

local strgmatch = string.gmatch
local function normalizePath(path)
    local stack = {}
    local depth = 0

    for v in strgmatch(path, "[^/]+") do
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

---Obtain the mapped file path.
---@param path string The path to a file.
---@return string path The mapped path to the file, or the source file if the file isn't mapped.
local function getPath(path)
    path = normalizePath(path)

    if db.map[path] ~= nil or db.map["/" .. path] ~= nil then
        return db.map[path]
    else
        return path
    end
end

---Check if a file path is mapped.
---@param path string The path to a file.
---@return boolean status True if the path is mapped, false if not.
local function isMapped(path)
    path = normalizePath(path)
    return db.map[path] ~= nil or db.map["/" .. path] ~= nil
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

    local fs_lines = love.filesystem.lines
    function love.filesystem.lines(name)
        return fs_lines(getPath(name))
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
