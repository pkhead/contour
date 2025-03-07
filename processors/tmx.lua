local path = require("path")
local util = require("util")

local tiled = "tiled"
if jit.os == "Windows" then
    tiled = "C:\\Program Files\\Tiled\\tiled.exe"
end

tiled = os.getenv("TILED") or tiled

return function(inPath, exportDir, fileUid)
    local outPath = ("%s/%s_%s.lua"):format(exportDir, fileUid, path.getNameWithoutExtension(inPath))
    
    if util.isOutOfDate(inPath, outPath) then
        print(("[TMX] %s"):format(outPath))
        util.execute(tiled, inPath, "--export-map", outPath)
    end

    return outPath
end