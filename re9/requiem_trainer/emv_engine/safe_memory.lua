--[[
    safe_memory.lua — Safe Memory Access Wrappers
    EMV Engine Module (Phase 1)

    All raw memory reads/writes are routed through these wrappers, which add:
      - pcall protection against crashes
      - Managed object validation via sdk.is_managed_object()
      - 16-byte alignment checks for vector operations (AVX-512 compliance)

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
]]

local SafeMemory = {}

-- Module references
local RE9_OFFSETS = nil

function SafeMemory.setup(deps)
    RE9_OFFSETS = deps.RE9_OFFSETS
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Validation Helpers
-- ═══════════════════════════════════════════════════════════════════════════

--- Check if an object is a valid managed object.
--- @param obj any  Value to check
--- @return boolean
function SafeMemory.validate_obj(obj)
    if obj == nil then return false end
    if type(obj) ~= "userdata" then return false end
    local ok, result = pcall(sdk.is_managed_object, obj)
    return ok and result == true
end

--- Check if an address is 16-byte aligned (required for AVX-512 vector ops).
--- @param addr number  Address to check
--- @return boolean
function SafeMemory.is_aligned_16(addr)
    if type(addr) ~= "number" then return false end
    return (addr % 16) == 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Safe Read
-- ═══════════════════════════════════════════════════════════════════════════

--- Safely read a qword (8-byte pointer) at an offset from a managed object.
--- @param obj userdata     Source object
--- @param offset_name string  Offset name in RE9_OFFSETS, or raw number
--- @return any|nil          Read value, or nil on failure
function SafeMemory.read_qword(obj, offset_name)
    if not SafeMemory.validate_obj(obj) then return nil end

    local offset = offset_name
    if type(offset_name) == "string" and RE9_OFFSETS then
        offset = RE9_OFFSETS.get(offset_name)
    end
    if type(offset) ~= "number" or offset < 0 then return nil end

    local result = nil
    pcall(function()
        result = obj:read_qword(offset)
    end)
    return result
end

--- Safely read a dword (4-byte integer) at an offset.
--- @param obj userdata     Source object
--- @param offset number    Byte offset
--- @return number|nil
function SafeMemory.read_dword(obj, offset)
    if not SafeMemory.validate_obj(obj) then return nil end
    local result = nil
    pcall(function()
        result = obj:read_dword(offset)
    end)
    return result
end

--- Safely read a float at an offset.
--- @param obj userdata     Source object
--- @param offset number    Byte offset
--- @return number|nil
function SafeMemory.read_float(obj, offset)
    if not SafeMemory.validate_obj(obj) then return nil end
    local result = nil
    pcall(function()
        result = obj:read_float(offset)
    end)
    return result
end

--- Safely read a Vector3f/Vector4f at an offset, with alignment check.
--- @param obj userdata     Source object
--- @param offset number    Byte offset (must be 16-byte aligned)
--- @return table|nil        {x, y, z, [w]}
function SafeMemory.read_vec34(obj, offset)
    if not SafeMemory.validate_obj(obj) then return nil end
    if type(offset) ~= "number" or offset < 0 then return nil end

    local result = nil
    pcall(function()
        local addr = obj:get_address() + offset
        if not SafeMemory.is_aligned_16(addr) then
            if log then log.warn("[EMV] read_vec34: unaligned address " .. string.format("0x%X", addr)) end
            return  -- bail instead of reading unaligned
        end
        local x = obj:read_float(offset)
        local y = obj:read_float(offset + 4)
        local z = obj:read_float(offset + 8)
        local w = obj:read_float(offset + 12)
        result = {x = x, y = y, z = z, w = w}
    end)
    return result
end

--- Safely read a 4x4 matrix at an offset.
--- @param obj userdata     Source object
--- @param offset number    Byte offset
--- @return table|nil        16-element flat array
function SafeMemory.read_mat4(obj, offset)
    if not SafeMemory.validate_obj(obj) then return nil end

    local mat = {}
    local ok = pcall(function()
        for i = 0, 15 do
            mat[i + 1] = obj:read_float(offset + i * 4)
        end
    end)
    return ok and mat or nil
end
return SafeMemory
