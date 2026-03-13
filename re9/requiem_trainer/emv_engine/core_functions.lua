--[[
    core_functions.lua — Core EMV Functions for RE9
    EMV Engine Module (Phase 2)

    Scene discovery, player access, component traversal, resource management,
    input system, and transform math utilities.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
    Reimplemented for RE9 with modular architecture.
]]

local CoreFunctions = {}

-- Module references
local RE9_OFFSETS       = nil
local SafeMemory        = nil
local ObjectCache       = nil
local CollectionIterator = nil

function CoreFunctions.setup(deps)
    RE9_OFFSETS        = deps.RE9_OFFSETS
    SafeMemory         = deps.SafeMemory
    ObjectCache        = deps.ObjectCache
    CollectionIterator = deps.CollectionIterator
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Globals / Static Cache
-- ═══════════════════════════════════════════════════════════════════════════

CoreFunctions.static_objs = {}
CoreFunctions.RSCache = {}
CoreFunctions.RN = { pfb = {} }

-- ═══════════════════════════════════════════════════════════════════════════
-- Game Detection
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.detect_game()
    _G.isRE9 = false
    _G.isRE8 = false
    _G.game_name = "unknown"

    pcall(function()
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        if cm then
            local tdef = cm:get_type_definition()
            if tdef then
                local method = tdef:get_method("getPlayerContextRef")
                if method then
                    _G.isRE9 = true
                    _G.game_name = "RE9"
                    return
                end
            end
        end
    end)

    if not _G.isRE9 then
        pcall(function()
            local em = sdk.get_managed_singleton("app.EnemyManager")
            if em then
                _G.isRE8 = true
                _G.game_name = "RE8"
            end
        end)
    end

    if log then
        log.info(("[EMV] Game detected: %s (isRE9=%s, isRE8=%s)"):format(
            _G.game_name, tostring(_G.isRE9), tostring(_G.isRE8)))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scene Initialization
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.init_scene()
    pcall(function()
        CoreFunctions.static_objs.scene = sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"),
            "get_CurrentScene")
    end)

    pcall(function()
        CoreFunctions.static_objs.main_view = sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"),
            "get_MainView")
    end)
end

--- Get the current scene (cached, refreshes if nil).
--- @return userdata|nil  via.Scene
function CoreFunctions.get_scene()
    if not CoreFunctions.static_objs.scene then
        CoreFunctions.init_scene()
    end
    return CoreFunctions.static_objs.scene
end

--- Refresh static singletons.
function CoreFunctions.generate_statics(type_list)
    type_list = type_list or {}
    for _, type_name in ipairs(type_list) do
        pcall(function()
            CoreFunctions.static_objs[type_name] = sdk.get_managed_singleton(type_name)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Object Validity
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.is_valid_obj(obj)
    if not obj then return false end
    local ok, result = pcall(sdk.is_managed_object, obj)
    return ok and result == true
end

function CoreFunctions.is_only_my_ref(obj)
    if not CoreFunctions.is_valid_obj(obj) then return true end
    local ref = nil
    pcall(function() ref = obj:read_dword(0x8) end)
    return ref ~= nil and ref <= 1
end

function CoreFunctions.can_index(obj)
    if not obj then return false end
    local ok = pcall(function() local _ = obj.x end)
    return ok
end

function CoreFunctions.get_valid(obj)
    return CoreFunctions.is_valid_obj(obj) and obj or nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Component Chain Traversal
-- ═══════════════════════════════════════════════════════════════════════════

--- Get the parent GameObject from a component.
--- Replaces raw read_qword(0x8) / read_qword(0x10) with offset registry.
function CoreFunctions.get_GameObject(comp, name_only)
    if not comp then return nil end
    local result = nil

    pcall(function()
        local tdef = comp:get_type_definition()
        if tdef then
            local go_method = tdef:get_method("get_GameObject")
            if go_method then
                result = comp:call("get_GameObject()")
                if name_only and result then
                    result = result:call("get_Name()") or "?"
                end
                return
            end
        end

        -- Fallback: offset
        if RE9_OFFSETS then
            local go_addr = SafeMemory and SafeMemory.read_qword(comp, "gameobject_base")
            if go_addr and go_addr ~= 0 then
                result = sdk.to_managed_object(go_addr)
                if name_only and result then
                    pcall(function() result = result:call("get_Name()") or "?" end)
                end
            end
        end
    end)

    return result
end

--- Get all components from a transform.
--- Replaces raw read_qword(0x10) with safe memory access.
function CoreFunctions.lua_get_components(xform)
    if not xform or not CoreFunctions.is_valid_obj(xform) then return {} end

    local components = {}
    pcall(function()
        local go = CoreFunctions.get_GameObject(xform)
        if not go then return end

        local comp = go:call("get_Transform()")
        if not comp then return end

        local max_iter = 256
        local i = 0
        while comp and i < max_iter do
            if CoreFunctions.is_valid_obj(comp) then
                components[#components + 1] = comp
            end
            local next_comp = nil
            pcall(function() next_comp = comp:call("get_Next()") end)
            if not next_comp and RE9_OFFSETS and SafeMemory then
                next_comp = SafeMemory.read_qword(comp, "component_next")
                if next_comp and next_comp ~= 0 then
                    pcall(function() next_comp = sdk.to_managed_object(next_comp) end)
                else
                    next_comp = nil
                end
            end
            comp = next_comp
            i = i + 1
        end
    end)

    return components
end

--- Find a specific component by type name.
function CoreFunctions.lua_find_component(xform, type_name)
    local comps = CoreFunctions.lua_get_components(xform)
    for _, comp in ipairs(comps) do
        local matches = false
        pcall(function()
            local tdef = comp:get_type_definition()
            if tdef and tdef:get_full_name() == type_name then
                matches = true
            end
        end)
        if matches then return comp end
    end
    return nil
end

--- Delete a component from the chain.
function CoreFunctions.delete_component(gameobj, comp)
    if not gameobj or not comp then return false end
    local ok = pcall(function()
        gameobj:call("destroyComponent", comp)
    end)
    return ok
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scene Discovery
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.find(type_name)
    if not type_name then return {} end
    local results = {}
    pcall(function()
        local tdef = sdk.find_type_definition(type_name)
        if tdef then
            results = sdk.find_managed_objects(type_name) or {}
        end
    end)
    return results
end

function CoreFunctions.findc(type_name)
    if not type_name then return {} end
    local results = {}
    pcall(function()
        results = CoreFunctions.find(type_name)
    end)
    return results
end

function CoreFunctions.search(name)
    if not name then return {} end
    local results = {}
    pcall(function()
        local all = sdk.find_managed_objects("via.Transform") or {}
        local search_lower = name:lower()
        for _, xform in ipairs(all) do
            pcall(function()
                local go = CoreFunctions.get_GameObject(xform)
                if go then
                    local go_name = go:call("get_Name()") or ""
                    if go_name:lower():find(search_lower, 1, true) then
                        results[#results + 1] = xform
                    end
                end
            end)
        end
    end)
    return results
end

function CoreFunctions.sort(transforms)
    if not transforms or #transforms == 0 then return transforms end
    local cam_pos = nil
    pcall(function()
        if CoreFunctions.static_objs.main_view then
            local cam = CoreFunctions.static_objs.main_view:call("get_PrimaryCamera")
            if cam then
                local cgo = cam:call("get_GameObject()")
                if cgo then
                    local cxf = cgo:call("get_Transform()")
                    if cxf then cam_pos = cxf:call("get_Position") end
                end
            end
        end
    end)
    if not cam_pos then return transforms end

    local scored = {}
    for _, xform in ipairs(transforms) do
        local dist = 999999
        pcall(function()
            local pos = xform:call("get_Position")
            if pos then
                local dx = pos.x - cam_pos.x
                local dy = pos.y - cam_pos.y
                local dz = pos.z - cam_pos.z
                dist = dx*dx + dy*dy + dz*dz
            end
        end)
        scored[#scored + 1] = {xform = xform, dist = dist}
    end
    table.sort(scored, function(a, b) return a.dist < b.dist end)
    local result = {}
    for _, s in ipairs(scored) do result[#result + 1] = s.xform end
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Access
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.get_player(as_anim_object)
    local player = nil
    pcall(function()
        if _G.isRE9 then
            local cm = sdk.get_managed_singleton("app.CharacterManager")
            if cm then
                local ctx = cm:call("getPlayerContextRef")
                if ctx then player = ctx:call("get_Body") end
            end
        else
            local pm = sdk.get_managed_singleton("app.PlayerManager")
            if pm then player = pm:call("get_CurrentPlayer") end
        end
    end)
    return player
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Resource Management
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.create_resource(path, type_name)
    if not path then return nil end
    local key = path .. "::" .. (type_name or "")
    if CoreFunctions.RSCache[key] then return CoreFunctions.RSCache[key] end

    local resource = nil
    pcall(function()
        resource = sdk.create_resource(type_name or "via.Prefab", path)
        if resource then
            resource:add_ref()
            CoreFunctions.RSCache[key] = resource
        end
    end)
    return resource
end

function CoreFunctions.add_resource_to_cache(resource, path, type_name)
    if resource and path then
        CoreFunctions.RSCache[path .. "::" .. (type_name or "")] = resource
    end
end

function CoreFunctions.add_pfb_to_cache(path)
    if not path then return nil end
    local pfb = CoreFunctions.create_resource(path, "via.Prefab")
    if pfb then
        CoreFunctions.RN.pfb[#CoreFunctions.RN.pfb + 1] = path
    end
    return pfb
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Input System
-- ═══════════════════════════════════════════════════════════════════════════

local prev_keys = {}

function CoreFunctions.check_key_released(key_code, wait)
    if not key_code or key_code <= 0 then return false end
    local down = false
    pcall(function() down = reframework:is_key_down(key_code) end)

    local was_down = prev_keys[key_code] or false
    prev_keys[key_code] = down

    return was_down and not down
end

local mouse_state = {delta_x = 0, delta_y = 0, btn_down = {}}

function CoreFunctions.update_mouse_state()
    pcall(function()
        local dev = CoreFunctions.get_mouse_device()
        if dev then
            mouse_state.delta_x = dev:call("get_DeltaMove"):get_field("x") or 0
            mouse_state.delta_y = dev:call("get_DeltaMove"):get_field("y") or 0
        end
    end)
    return mouse_state
end

function CoreFunctions.get_mouse_device()
    local dev = nil
    pcall(function()
        dev = sdk.call_native_func(
            sdk.get_native_singleton("via.InputManager"),
            sdk.find_type_definition("via.InputManager"),
            "getMouse")
    end)
    return dev
end

function CoreFunctions.Hotkey(key_name)
    local code = 0
    if type(key_name) == "number" then return key_name end
    return code
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Hashing (MurmurHash3)
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.hashing_method(str)
    if not str then return 0 end
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 0x7FFFFFFF
    end
    return hash
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform Math Utilities
-- ═══════════════════════════════════════════════════════════════════════════

function CoreFunctions.mat4_to_trs(mat4)
    if not mat4 then return nil end
    local trs = {}
    pcall(function()
        trs.pos = mat4[3] or Vector3f.new(0,0,0)
        trs.rot = mat4:to_quat()
        trs.scale = Vector3f.new(1,1,1)
    end)
    return trs
end

function CoreFunctions.trs_to_mat4(trs)
    if not trs then return nil end
    local mat = nil
    pcall(function()
        mat = Matrix4x4f.identity()
        if trs.rot then mat = trs.rot:to_mat4() end
        if trs.pos then
            mat[3] = trs.pos
        end
    end)
    return mat
end

function CoreFunctions.get_trs(xform)
    if not xform then return nil end
    local trs = {}
    pcall(function()
        trs.pos = xform:call("get_Position")
        trs.rot = xform:call("get_Rotation")
        trs.scale = xform:call("get_LocalScale")
    end)
    return trs
end

return CoreFunctions
