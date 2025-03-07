-- IMPORTANT: run like
--
--    lovec contour
--
-- i.e., with cwd being the project root directory

local nativefs = require("nativefs")
local pathm = require("path")

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

local function escapeString(str)
    return string.gsub(str, "\"", "\\\"")
end

local conf = require("contour.conconf")
local fileIndex = 1

local dbList = {"return {\n"}

for procId, globs in pairs(conf.processors) do
    local processor = require("contour.processors." .. procId)

    local paths = {}
    for _, assetDir in ipairs(conf.assetDirectories) do
        for _, glob in ipairs(globs) do
            for _, v in ipairs(evalGlob(assetDir, glob)) do
                paths[#paths+1] = v
            end
        end
    end

    for _, path in pairs(paths) do
        local outPath = processor(path, "contour/export", fileIndex)
        fileIndex = fileIndex + 1

        if outPath ~= nil then
            dbList[#dbList+1] = "\t[\""
            dbList[#dbList+1] = path
            dbList[#dbList+1] = "\"] = \""
            dbList[#dbList+1] = escapeString(outPath)
            dbList[#dbList+1] = "\",\n"
        end
    end
end

dbList[#dbList+1] = "}"

nativefs.write("contour/db.lua", table.concat(dbList))

os.exit(0)