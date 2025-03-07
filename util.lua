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

    os.execute(table.concat(args, " "))
end

return util