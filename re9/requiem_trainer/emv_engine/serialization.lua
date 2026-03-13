--[[
    serialization.lua — JSON Serialization / Deserialization
    EMV Engine Module (Phase 2)

    Tagged string encodings for engine types:
      "vec:x,y,z" → Vector3f | "vec4:x,y,z,w" → Vector4f
      "res:path type" → Resource | "obj:type" → Managed object
]]

local Serialization = {}
local CoreFunctions, TableUtils, ObjectCache

function Serialization.setup(deps)
    CoreFunctions = deps.CoreFunctions; TableUtils = deps.TableUtils; ObjectCache = deps.ObjectCache
end

function Serialization.jsonify_table(tbl, go_back, args)
    if type(tbl) ~= "table" then return tbl end
    for key, value in pairs(tbl) do
        local vtype = type(value)
        if vtype == "table" then
            Serialization.jsonify_table(value, go_back, args)
        elseif vtype == "userdata" and not go_back then
            tbl[key] = Serialization._encode_value(value)
        elseif vtype == "string" and go_back then
            local decoded = Serialization._decode_value(value)
            if decoded ~= nil then tbl[key] = decoded end
        end
    end
    return tbl
end

function Serialization._encode_value(value)
    if pcall(function() return value.x and value.y and value.z end) then
        local has_w = pcall(function() return value.w end)
        if has_w and value.w and value.w ~= 0 then
            return ("vec4:%.6f,%.6f,%.6f,%.6f"):format(value.x, value.y, value.z, value.w)
        end
        return ("vec:%.6f,%.6f,%.6f"):format(value.x, value.y, value.z)
    end
    if sdk.is_managed_object(value) then
        local tn = ""; pcall(function() tn = value:get_type_definition():get_full_name() end)
        return "obj:" .. tn
    end
    return tostring(value)
end

function Serialization._decode_value(str)
    if type(str) ~= "string" then return nil end
    if str:sub(1,4) == "vec:" then
        local x,y,z = str:sub(5):match("([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+)")
        if x then return Vector3f.new(tonumber(x), tonumber(y), tonumber(z)) end
    end
    if str:sub(1,5) == "vec4:" then
        local x,y,z,w = str:sub(6):match("([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+),([%d%.%-e]+)")
        if x then return Vector4f.new(tonumber(x), tonumber(y), tonumber(z), tonumber(w)) end
    end
    if str:sub(1,4) == "res:" then
        local path, rtype = str:sub(5):match("^(.+)%s+(.+)$")
        if path and CoreFunctions then return CoreFunctions.create_resource(path, rtype) end
    end
    return nil
end

function Serialization.obj_to_json(obj, metadata_only, args)
    if not obj or not sdk.is_managed_object(obj) then return nil end
    local result = {}
    pcall(function()
        local tdef = obj:get_type_definition()
        if not tdef then return end
        result.__type = tdef:get_full_name(); result.__fields = {}
        local fields = tdef:get_fields()
        if fields then for _, field in ipairs(fields) do
            if not field:is_static() then
                local fname = field:get_name()
                if metadata_only then
                    result.__fields[fname] = {type = field:get_type():get_full_name()}
                else pcall(function()
                    local val = obj:get_field(fname)
                    if val ~= nil then
                        if type(val) == "userdata" then result.__fields[fname] = Serialization._encode_value(val)
                        else result.__fields[fname] = val end
                    end
                end) end
            end
        end end
    end)
    return result
end

function Serialization.save_json(filepath, data)
    if not json or not filepath or not data then return false end
    local ok = pcall(function() json.dump_file(filepath, data) end); return ok
end

function Serialization.load_json(filepath)
    if not json or not filepath then return nil end
    local data; pcall(function() data = json.load_file(filepath) end); return data
end

return Serialization
