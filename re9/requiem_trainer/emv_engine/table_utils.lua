--[[
    table_utils.lua — Pure Lua Table Utilities
    EMV Engine Module (Phase 1)

    No RE Engine dependencies.
    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
    Reimplemented with clean module pattern.
]]

local TableUtils = {}

--- Merge src table into dst (shallow).
--- @param dst table
--- @param src table
--- @return table dst
function TableUtils.merge_tables(dst, src)
    if not dst or not src then return dst or {} end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

--- Deep copy a table (including nested tables and metatables).
--- @param orig table
--- @param copies table|nil  Internal cycle tracker
--- @return table
function TableUtils.deep_copy(orig, copies)
    copies = copies or {}
    if type(orig) ~= "table" then return orig end
    if copies[orig] then return copies[orig] end

    local copy = {}
    copies[orig] = copy
    for k, v in pairs(orig) do
        copy[TableUtils.deep_copy(k, copies)] = TableUtils.deep_copy(v, copies)
    end
    local mt = getmetatable(orig)
    if mt then setmetatable(copy, TableUtils.deep_copy(mt, copies)) end
    return copy
end

--- QuickSort a table in-place by a comparison function.
--- @param tbl table
--- @param compare function  function(a, b) → bool (a < b)
function TableUtils.qsort(tbl, compare)
    if not tbl or #tbl <= 1 then return end
    compare = compare or function(a, b) return a < b end
    table.sort(tbl, compare)
end

--- Binary insert into a sorted table.
--- @param tbl table       Sorted array
--- @param value any       Value to insert
--- @param compare function  Comparison function
function TableUtils.binsert(tbl, value, compare)
    compare = compare or function(a, b) return a < b end
    local lo, hi = 1, #tbl
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if compare(value, tbl[mid]) then
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    table.insert(tbl, lo, value)
end

--- Iterate table keys in sorted order.
--- @param tbl table
--- @return function  Iterator
function TableUtils.orderedPairs(tbl)
    if type(tbl) ~= "table" then return function() end end
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key ~= nil then return key, tbl[key] end
    end
end

--- Check if a table is an array (sequential integer keys).
--- @param tbl table
--- @return boolean
function TableUtils.isArray(tbl)
    if type(tbl) ~= "table" then return false end
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count == #tbl
end

--- Convert a vector userdata {x,y,z,[w]} to a plain Lua table.
--- @param vec userdata  Vector3f or Vector4f
--- @return table
function TableUtils.vector_to_table(vec)
    if not vec then return {x = 0, y = 0, z = 0} end
    local t = {}
    pcall(function() t.x = vec.x or 0 end)
    pcall(function() t.y = vec.y or 0 end)
    pcall(function() t.z = vec.z or 0 end)
    pcall(function() t.w = vec.w end)
    return t
end

--- Safely evaluate a Lua expression or statement string.
--- @param cmd string  Lua code string
--- @return any        Result of evaluation
function TableUtils.run_command(cmd)
    if type(cmd) ~= "string" then return nil end
    -- Try as expression first
    local fn, err = load("return " .. cmd)
    if not fn then
        fn, err = load(cmd)
    end
    if fn then
        local ok, result = pcall(fn)
        if ok then return result end
        return nil, result
    end
    return nil, err
end

--- Parse and execute a structured command string.
--- @param cmd string  Command in format "func arg1,arg2"
--- @return any
function TableUtils.parse_command(cmd)
    return TableUtils.run_command(cmd)
end

return TableUtils
