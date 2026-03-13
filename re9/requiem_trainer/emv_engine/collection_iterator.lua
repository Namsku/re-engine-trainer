--[[
    collection_iterator.lua — Safe Collection Enumeration
    EMV Engine Module (Phase 1)

    Abstracts over RE9's ConcurrentDictionary, Generic.List, raw arrays,
    and generic IEnumerable — providing a single enumerate() entry point.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
]]

local CollectionIterator = {}

--- Detect collection type and enumerate safely.
--- @param collection userdata  RE Engine collection
--- @param callback function    function(index, value) — return false to stop
--- @return table               Array of collected values
function CollectionIterator.enumerate(collection, callback)
    if not collection then return {} end

    local results = {}
    local ok = pcall(function()
        local tdef = collection:get_type_definition()
        if not tdef then return end
        local type_name = tdef:get_full_name()

        if type_name:find("ConcurrentDictionary") then
            results = CollectionIterator._enumerate_concurrent_dict(collection, callback)
        elseif type_name:find("Generic.List") or type_name:find("Collections.Generic.List") then
            results = CollectionIterator._enumerate_list(collection, callback)
        elseif type_name:find("%[%]") then
            results = CollectionIterator._enumerate_array(collection, callback)
        else
            results = CollectionIterator._enumerate_generic(collection, callback)
        end
    end)

    return results
end

--- Enumerate a ConcurrentDictionary (RE9 primary collection type).
function CollectionIterator._enumerate_concurrent_dict(dict, callback)
    local results = {}

    -- Strategy 1: ToArray
    pcall(function()
        local arr = dict:call("ToArray")
        if arr then
            local count = arr:call("get_Length") or arr:call("get_Count") or 0
            for i = 0, count - 1 do
                pcall(function()
                    local pair = arr:call("Get", i)
                    if pair then
                        local val = pair:get_field("value") or pair:get_field("Value")
                        if val ~= nil then
                            results[#results + 1] = val
                            if callback then callback(#results, val) end
                        end
                    end
                end)
            end
        end
    end)

    if #results > 0 then return results end

    -- Strategy 2: get_Values → iterate
    pcall(function()
        local values = dict:call("get_Values")
        if values then
            local count = values:call("get_Count") or 0
            for i = 0, count - 1 do
                pcall(function()
                    local val = values:call("Get", i) or values:call("get_Item", i)
                    if val ~= nil then
                        results[#results + 1] = val
                        if callback then callback(#results, val) end
                    end
                end)
            end
        end
    end)

    return results
end

--- Enumerate a Generic.List.
function CollectionIterator._enumerate_list(list, callback)
    local results = {}
    pcall(function()
        local count = list:call("get_Count") or 0
        for i = 0, count - 1 do
            pcall(function()
                local val = list:call("get_Item", i)
                if val ~= nil then
                    results[#results + 1] = val
                    if callback then callback(#results, val) end
                end
            end)
        end
    end)
    return results
end

--- Enumerate a raw array.
function CollectionIterator._enumerate_array(arr, callback)
    local results = {}
    pcall(function()
        local count = arr:call("get_Length") or arr:call("get_Count") or 0
        for i = 0, count - 1 do
            pcall(function()
                local val = arr:call("Get", i)
                if val ~= nil then
                    results[#results + 1] = val
                    if callback then callback(#results, val) end
                end
            end)
        end
    end)
    return results
end

--- Fallback: try GetEnumerator pattern.
function CollectionIterator._enumerate_generic(collection, callback)
    local results = {}
    pcall(function()
        local enumerator = collection:call("GetEnumerator")
        if enumerator then
            local max_iter = 10000
            local i = 0
            while i < max_iter do
                local has_next = enumerator:call("MoveNext")
                if not has_next then break end
                local val = enumerator:call("get_Current")
                if val ~= nil then
                    results[#results + 1] = val
                    if callback then callback(#results, val) end
                end
                i = i + 1
            end
        end
    end)
    return results
end

return CollectionIterator
