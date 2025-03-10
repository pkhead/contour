local VERSION = "2.1.0"

local nativefs = require("nativefs")
local pathm = require("path")
local util = require("util")

---@type fun(globDesc: string): fun(v: string)
local createGlobChecker
do
    local specialChars = {
        ["."] = true,
        ["+"] = true,
        ["-"] = true,
        ["*"] = true,
        ["?"] = true,
        ["^"] = true,
        ["$"] = true,
        ["%"] = true,
        ["("] = true,
        [")"] = true,
        ["["] = true,
        ["]"] = true,
    }

    local function globToPattern(globStr)
        local t = {"^"}
        
        for i=1, string.len(globStr) do
            local char = string.sub(globStr, i, i)

            if char == "*" then
                t[#t+1] = ".*"
            elseif specialChars[char] then
                t[#t+1] = "%"
                t[#t+1] = char
            else
                t[#t+1] = char
            end
        end

        t[#t+1] = "$"
        return table.concat(t)
    end

    function createGlobChecker(globDesc)
        globDesc = pathm.normalize(globDesc)

        -- local paths = pathm.split(globDesc)
        -- local fileGlob = paths[#paths]
        --print(fileGlob)

        local searchPattern
        if string.sub(globDesc, 1, 1) == "." then
            searchPattern = globToPattern("*" .. globDesc)
        else
            searchPattern = globToPattern(globDesc)
        end

        return function(queryPath)
            queryPath = pathm.normalize(queryPath)
            return string.match(queryPath, searchPattern) ~= nil
            -- local querySplit = pathm.split(pathm.normalize(queryPath))
            -- local queryName = querySplit[#querySplit]

            -- if paths[2] ~= nil then
            --     if #querySplit ~= #paths then
            --         return false
            --     end

            --     for i, v in pairs(querySplit) do
            --         if paths[i] ~= querySplit[i] then
            --             return false
            --         end
            --     end
            -- end
            
            -- local qName, qExt = string.match(fileGlob, "^(.*)%.(.*)$")
            -- return string.match(qName, searchPattern) ~= nil
        end
    end
    
end

---@type fun(srcDir: string, globPath: string): string[]
local evalGlob
do
    local function rec(srcDir, globCheck, searchDir, output)
        for _, name in pairs(nativefs.getDirectoryItems(searchDir)) do
            local path = searchDir .. "/" .. name
            local type = nativefs.getInfo(path).type
    
            if type == "file" then
                if globCheck(path) then
                    output[#output+1] = path
                end
            end
        end
    
        for _, name in pairs(nativefs.getDirectoryItems(searchDir)) do
            local path = searchDir .. "/" .. name
            local type = nativefs.getInfo(path).type
    
            if type == "directory" then
                rec(srcDir, globCheck, path, output)
            end
        end
    end

    function evalGlob(srcDir, glob)
        local out = {}
        rec(srcDir, createGlobChecker(glob), srcDir, out)
        return out
    end
end

---@class Database
---@field map {[string]: string}
---@field uids {[string]: string}

---@class ContourConfig
---@field assetDirectories string[]
---@field exportDirectory string
---@field processors {[string]: string[]}

---@param conf ContourConfig
---@return Database?
local function loadDatabase(conf)
    local path = pathm.join(conf.exportDirectory, ".db")
    local chunk = nativefs.load(path)
    return chunk and chunk()
end

---@return ContourConfig
local function loadConfig()
    local chunk = nativefs.load("contour/conconf.lua")
    if chunk == nil then
        error("contour/conconf.lua: file does not exist", 1)
    end

    return chunk()
end

local function processContent()
    local conf = loadConfig()

    local exportDirectory = assert(conf.exportDirectory, "conconf.lua: missing exportDirectory string")
    assert(conf.assetDirectories, "conconf.lua: missing assetDirectories table")
    assert(conf.processors, "conconf.lua: missing processors table")

    local oldDb = loadDatabase(conf)

    local newDb = {
        map = {}
    }

    if oldDb ~= nil then
        newDb.uids = oldDb.uids
    else
        newDb.uids = {}
    end

    nativefs.createDirectory(exportDirectory)

    -- make sure files that have already been processed are always reprocessed before
    -- newly created files
    ---@type fun(a: string, b: string): boolean
    local function pathSortFunc(a, b)
        local aUid = newDb.uids[a]
        local bUid = newDb.uids[b]
        return aUid < bUid
    end

    -- ensure processers are ran in a specific order
    local procOrder = {}
    for procId, _ in pairs(conf.processors) do
        table.insert(procOrder, procId)
    end
    table.sort(procOrder)

    for _, procId in ipairs(procOrder) do
        local globs = conf.processors[procId]
        local processor = require("contour.processors." .. procId)

        local paths = {}
        for _, assetDir in ipairs(conf.assetDirectories) do
            for _, glob in ipairs(globs) do
                for _, v in ipairs(evalGlob(assetDir, glob)) do
                    table.insert(paths, v)
                end
            end
        end

        -- assign a uid for each file if it doesn't already exist
        for _, path in pairs(paths) do
            if newDb.uids[path] == nil then
                local uid
                while true do
                    uid = util.generateUid()

                    local success = true
                    for _, testUid in pairs(newDb.uids) do
                        if uid == testUid then
                            success = false
                            break
                        end
                    end

                    if success then break end
                end

                newDb.uids[path] = uid
            end
        end

        table.sort(paths, pathSortFunc)

        for _, path in ipairs(paths) do
            local outPath = processor(path, exportDirectory, newDb.uids[path])

            if outPath ~= nil then
                newDb.map[path] = outPath
            end
        end
    end

    -- remove uids that no longer are referenced
    local uidsToRemove = {}
    for path, uid in pairs(newDb.uids) do
        if newDb.map[path] == nil then
            table.insert(uidsToRemove, path)
        end
    end

    for _, path in pairs(uidsToRemove) do
        newDb.uids[path] = nil
    end

    nativefs.write(pathm.join(conf.exportDirectory, ".db"), "return " .. util.serialize(newDb))
end

local function removeDirectory(dirPath)
    if nativefs.getInfo(dirPath) == nil then return end

    for _, name in pairs(nativefs.getDirectoryItems(dirPath)) do
        local path = dirPath .. "/" .. name
        local info = nativefs.getInfo(path)

        if info.type == "directory" then
            removeDirectory(path)
        else
            os.remove(path)
        end
    end

    if jit.os == "Windows" then
        dirPath = string.gsub(dirPath, "/", "\\")
    end
    os.execute("rmdir " .. dirPath)
end

local function copyFileToProject(srcFile, destFile)
    local f = nativefs.newFile(destFile)
    f:open("w")
    for line in love.filesystem.lines(srcFile) do
        f:write(line)
        f:write("\n")
    end
    f:close()
end

function love.load(args)
    -- dumb command parser
    local scStart = nil
    local i=1
    while i <= #args do
        if args[i] == "-C" then
            nativefs.setWorkingDirectory(args[i+1])
            i=i+2
        else
            if scStart == nil then
                scStart = i
            end

            i=i+1
        end
    end

    if scStart ~= nil then
        if args[scStart] == "--help" or args[scStart] == "-h" or args[scStart] == "/?" or args[scStart] == "help" then
            local helpText = love.filesystem.read("string", "tooldata/help.txt")
            io.write(helpText)
            io.write("\n")

        elseif args[scStart] == "--version" or args[scStart] == "-v" then
            io.write(VERSION)
            io.write("\n")
        
        elseif args[scStart] == "init" then
            -- create directory structure
            nativefs.createDirectory("contour")
            nativefs.createDirectory("contour/processors")

            -- copy tmx processor
            copyFileToProject("tooldata/tmx-processor.lua", "contour/processors/tmx.lua")
            
            -- copy contour runtime lib to project
            copyFileToProject("tooldata/runtime.lua", "contour/init.lua")

            -- copy default conconf.lua to project
            if nativefs.getInfo("contour/conconf.lua") == nil then
                copyFileToProject("tooldata/default-conf.lua", "contour/conconf.lua")
            end
        
        elseif args[scStart] == "list-mapped" then
            local db = loadDatabase(loadConfig())
            if db then 
                local keys = {}
                for k, v in pairs(db.map) do
                    table.insert(keys, k)
                end

                for _, k in ipairs(keys) do
                    io.write(k)
                    io.write("\n")
                end
            end

        elseif args[scStart] == "clean" then
            local conf = loadConfig()
            removeDirectory(conf.exportDirectory)
        else
            print("unknown command: " .. args[scStart])
            os.exit(1)
        end
    else
        processContent()
    end

    os.exit(0)
end