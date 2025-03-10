local path = require("path")
local util = require("util")
local nativefs = require("nativefs")

-- get path to tiled executable.
-- it will read from the TILED env variable, but if unset
-- the path will be set to "C:\Program Files\Tiled\tiled.exe" on windows and simply "tiled"
-- on other operating systems (i.e. it will look through the command search path).
local tiled = "tiled"
if jit.os == "Windows" then
    tiled = "C:\\Program Files\\Tiled\\tiled.exe"
end
tiled = os.getenv("TILED") or tiled

return function(inPath, exportDir, fileUid)
    -- file name is in format [uid]_[name].lua
    local outName = ("%s_%s.lua"):format(fileUid, path.getNameWithoutExtension(inPath))

    -- this is the path to the exported file
    local outPath = path.join(exportDir, outName)

    if util.isOutOfDate(inPath, outPath) then
        print(("[TMX] %s"):format(inPath))

        -- tiled writes file references in the export relative to the export path,
        -- but i think it would be more useful if it were relative to the input file path.
        -- so first, i have to export the lua file to the same directory as the source file.
        local tmpPath = path.join(path.getDirName(inPath), outName)
        util.execute(tiled, inPath, "--export-map", tmpPath)
        
        -- then, i copy the temporary file to the final export location and delete the temporary file.
        nativefs.write(outPath, nativefs.read("data", tmpPath))
        os.remove(tmpPath)
    end

    return outPath
end