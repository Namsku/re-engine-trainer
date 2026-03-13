--[[
    type_db.lua — RSZ Type Database runtime API
    EMV Engine Module

    Provides field definitions and enum name lookups using preprocessed
    data from rszre9.json and re9_enums.json.

    API:
        TypeDB.get_type(type_name) → { parent, fields }
        TypeDB.get_all_fields(type_name) → flat list of fields (walking parent chain)
        TypeDB.get_enum_name(enum_type, value) → string name or nil
        TypeDB.get_enum_values(enum_type) → { [value]=name, ... } or nil
        TypeDB.is_enum(type_name) → bool
]]

local TypeDB = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════════════

local rsz_types = nil   -- loaded lazily
local rsz_enums = nil   -- loaded lazily
local loaded = false
local load_error = nil

-- Cache for get_all_fields (flattened with parent chain)
local all_fields_cache = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- Loading
-- ═══════════════════════════════════════════════════════════════════════════

local _base_dir = nil

function TypeDB.setup(base_dir)
    _base_dir = base_dir
end

local function ensure_loaded()
    if loaded then return end
    loaded = true

    if not _base_dir then
        load_error = "TypeDB base_dir not set"
        return
    end

    -- Load types
    local types_path = _base_dir .. "/rsz_types.lua"
    local fn, err = loadfile(types_path)
    if fn then
        local ok, result = pcall(fn)
        if ok and type(result) == "table" then
            rsz_types = result
        else
            load_error = "rsz_types.lua failed: " .. tostring(result)
        end
    else
        load_error = "rsz_types.lua not found: " .. tostring(err)
    end

    -- Load enums
    local enums_path = _base_dir .. "/rsz_enums.lua"
    fn, err = loadfile(enums_path)
    if fn then
        local ok, result = pcall(fn)
        if ok and type(result) == "table" then
            rsz_enums = result
        else
            load_error = (load_error or "") .. "; rsz_enums.lua failed: " .. tostring(result)
        end
    else
        load_error = (load_error or "") .. "; rsz_enums.lua not found: " .. tostring(err)
    end

    local t_count = rsz_types and 0 or -1
    local e_count = rsz_enums and 0 or -1
    if rsz_types then for _ in pairs(rsz_types) do t_count = t_count + 1 end end
    if rsz_enums then for _ in pairs(rsz_enums) do e_count = e_count + 1 end end

    if log then
        log.info(("[TypeDB] Loaded %d types, %d enums"):format(t_count, e_count))
        if load_error then log.warn("[TypeDB] " .. load_error) end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Type Lookup
-- ═══════════════════════════════════════════════════════════════════════════

--- Get the RSZ type definition for a type name.
--- @param type_name string — e.g. "app.HitPoint"
--- @return table|nil — { parent=string, fields={...} }
function TypeDB.get_type(type_name)
    ensure_loaded()
    if not rsz_types then return nil end
    return rsz_types[type_name]
end

--- Get all fields for a type, walking the parent chain.
--- Fields are returned in parent-first order (base class fields first).
--- @param type_name string
--- @return table — array of { name, type, orig, array, size }
function TypeDB.get_all_fields(type_name)
    ensure_loaded()
    if not rsz_types then return {} end

    if all_fields_cache[type_name] then
        return all_fields_cache[type_name]
    end

    local result = {}
    local visited = {}
    local chain = {}

    -- Walk parent chain
    local current = type_name
    local safety = 0
    while current and current ~= "" and safety < 30 do
        if visited[current] then break end
        visited[current] = true
        safety = safety + 1

        local t = rsz_types[current]
        if t then
            table.insert(chain, 1, t)  -- prepend
            current = t.parent
        else
            break
        end
    end

    -- Flatten fields parent-first
    local seen_names = {}
    for _, t in ipairs(chain) do
        for _, f in ipairs(t.fields or {}) do
            if not seen_names[f.name] then
                seen_names[f.name] = true
                result[#result + 1] = f
            end
        end
    end

    all_fields_cache[type_name] = result
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enum Lookup
-- ═══════════════════════════════════════════════════════════════════════════

--- Check if a type name is a known enum.
--- @param type_name string — e.g. "app.PlayerDefine.PutWeaponPosition"
--- @return boolean
function TypeDB.is_enum(type_name)
    ensure_loaded()
    if not rsz_enums then return false end
    return rsz_enums[type_name] ~= nil
end

--- Get human-readable name for an enum value.
--- @param enum_type string — e.g. "app.PlayerDefine.PutWeaponPosition"
--- @param value number — e.g. 0
--- @return string|nil — e.g. "WaistRight"
function TypeDB.get_enum_name(enum_type, value)
    ensure_loaded()
    if not rsz_enums then return nil end
    local e = rsz_enums[enum_type]
    if not e then return nil end
    return e[value]
end

--- Get all values for an enum type.
--- @param enum_type string
--- @return table|nil — { [0]="WaistRight", [1]="WaistLeft", ... }
function TypeDB.get_enum_values(enum_type)
    ensure_loaded()
    if not rsz_enums then return nil end
    return rsz_enums[enum_type]
end

--- Build a sorted list of {value, name} pairs for imgui combo display.
--- @param enum_type string
--- @return table|nil — array of names, table of values_by_index
function TypeDB.get_enum_combo_data(enum_type)
    ensure_loaded()
    if not rsz_enums then return nil, nil end
    local e = rsz_enums[enum_type]
    if not e then return nil, nil end

    local items = {}
    for val, name in pairs(e) do
        items[#items + 1] = { value = val, name = name }
    end
    table.sort(items, function(a, b) return a.value < b.value end)

    local names = {}
    local values = {}
    for i, item in ipairs(items) do
        names[i] = item.name
        values[i] = item.value
    end
    return names, values
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Status
-- ═══════════════════════════════════════════════════════════════════════════

function TypeDB.is_loaded()
    ensure_loaded()
    return rsz_types ~= nil
end

function TypeDB.get_error()
    return load_error
end

function TypeDB.get_stats()
    ensure_loaded()
    local t_count, e_count = 0, 0
    if rsz_types then for _ in pairs(rsz_types) do t_count = t_count + 1 end end
    if rsz_enums then for _ in pairs(rsz_enums) do e_count = e_count + 1 end end
    return t_count, e_count
end

return TypeDB
