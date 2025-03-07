-- IMPORTANT: run like
--
--    lovec contour
--
-- i.e., with cwd being the project root directory
local VERSION = "1.2"

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

---@param str string
---@return string
local function escapeString(str)
    local res = string.gsub(str, "\"", "\\\"")
    return res
end

---@type fun(value: any): string
local serialize
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
            table.insert(out, escapeString(t))
            table.insert(out, "\"")
        else
            table.insert(out, tostring(t))
        end
    end

    function serialize(value)
        local out = {}
        rec(out, "", value)
        return table.concat(out)
    end
end

local function tfind(t, v)
    for i, testV in pairs(t) do
        if testV == v then
            return i
        end
    end
    return nil
end

local exportDirectory = "contour/export"

local function processContent()
    local conf = require("contour.conconf")

    local oldDbChunk = nativefs.load("contour/db.lua")
    local oldDb = nil
    if oldDbChunk ~= nil then
        oldDb = oldDbChunk()
    end

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
                newDb.uids[path] = util.generateUid()
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

    nativefs.write("contour/db.lua", "return " .. serialize(newDb))
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

function love.load(args)
    if args[1] ~= nil then
        if args[1] == "--help" or args[1] == "-h" or args[1] == "/?" or args[1] == "help" then
            local helpText = love.filesystem.read("string", "help.txt")
            io.write(helpText)
            io.write("\n")

        elseif args[1] == "--version" or args[1] == "-v" then
            io.write(VERSION)
            io.write("\n")

        elseif args[1] == "clean" then
            nativefs.remove("contour/db.lua")
            removeDirectory(exportDirectory)
        end
    else
        processContent()
    end

    os.exit(0)
end