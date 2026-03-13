-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Gravity Gun Module (RE9 Hardened)
-- Grab, move, and throw GameObjects via physics raycasting
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Usage:  Loaded by requiem_trainer.lua via dofile/loadfile
--         Expects T = trainer table with T.C (config), T.R (runtime),
--         T.toast, T.pctx, T.ppos, T.pxf
--
-- Controls:
--   Middle Mouse (0x04)  — Grab / Release (throw on release)
--   Numpad +  (0x6B)     — Increase grab distance
--   Numpad -  (0x6D)     — Decrease grab distance
--   Z (0x5A)             — Cycle grab mode (pos only / pos+rot)
--
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local toast = T.toast
local get_scene = T.get_scene

-- ═══════════════════════════════════════════════════════════════════════════
-- Module State
-- ═══════════════════════════════════════════════════════════════════════════

local GravityGun = {}

-- Internal state (not persisted)
local state = {
    -- Grabbed object
    target_go       = nil,   -- via.GameObject
    target_xf       = nil,   -- via.Transform
    target_name     = "",    -- string (display name)
    grab_offset     = nil,   -- Vector3f offset from camera at grab time
    grab_distance   = 5.0,   -- current grab distance (meters)
    grab_rotation   = nil,   -- Quaternion at grab time (for rot mode)
    is_grabbing     = false,
    
    -- Input tracking (edge detection)
    mmb_was_down    = false,
    plus_was_down   = false,
    minus_was_down  = false,
    z_was_down      = false,
    
    -- Raycast result cache
    last_ray_hit    = nil,   -- {pos=Vector3f, go=GameObject, name=string}
    last_ray_time   = 0,
    
    -- Status
    status          = "Idle",
    error_msg       = nil,
    error_time      = 0,
    
    -- Counters
    grab_count      = 0,
    throw_count     = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Config Defaults (merged into C on init)
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG_DEFAULTS = {
    gravity_gun_enabled  = false,
    gg_grab_distance     = 5.0,
    gg_grab_dist_min     = 1.0,
    gg_grab_dist_max     = 50.0,
    gg_grab_dist_step    = 0.5,
    gg_throw_force       = 15.0,
    gg_lerp_speed        = 12.0,    -- how fast object follows target pos
    gg_ray_distance      = 100.0,   -- max raycast distance
    gg_grab_mode         = 1,       -- 1=position only, 2=position+rotation
    gg_show_debug        = true,    -- show grab line / crosshair
    gg_key_grab          = 0x04,    -- Middle mouse button
    gg_key_dist_up       = 0x6B,    -- Numpad +
    gg_key_dist_down     = 0x6D,    -- Numpad -
    gg_key_mode          = 0x5A,    -- Z key
}

-- ═══════════════════════════════════════════════════════════════════════════
-- via.Transform Method Handles (Native Call Trap Workaround)
-- RE9: transform.Position direct Lua indexing, NOT .call("set_Position")
-- Cache method handles at load time for reliable access
-- ═══════════════════════════════════════════════════════════════════════════

local xf_type        = nil
local m_xf_get_pos   = nil
local m_xf_set_pos   = nil
local m_xf_get_rot   = nil
local m_xf_set_rot   = nil

-- Track which transforms we've grabbed (so we can block game overrides)
local grabbed_transforms = {}  -- [transform] = true
local is_writing = false       -- flag so our OWN writes go through the hooks

local function init_transform_methods()
    if xf_type then return true end
    local ok = pcall(function()
        xf_type = sdk.find_type_definition("via.Transform")
        if xf_type then
            m_xf_get_pos = xf_type:get_method("get_Position")
            m_xf_set_pos = xf_type:get_method("set_Position")
            m_xf_get_rot = xf_type:get_method("get_Rotation")
            m_xf_set_rot = xf_type:get_method("set_Rotation")
        end
    end)
    return ok and xf_type ~= nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform Intercept Hooks
-- Block the game from overriding position/rotation on grabbed objects
-- ═══════════════════════════════════════════════════════════════════════════

local function on_pre_set_transform(args)
    if is_writing then return end
    if not C.gravity_gun_enabled then return end
    local ok, xform = pcall(sdk.to_managed_object, args[2])
    if ok and xform and grabbed_transforms[xform] then
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
end

--- RAII helper: guarantees is_writing is always reset, even on exceptions
local function with_writing(fn)
    is_writing = true
    local ok, err = pcall(fn)
    is_writing = false
    return ok, err
end

local function on_post_noop(retval) return retval end

pcall(function()
    local td = sdk.find_type_definition("via.Transform")
    if td then
        local methods = {"set_Position", "set_LocalPosition", "set_Rotation", "set_LocalScale"}
        for _, mname in ipairs(methods) do
            local m = td:get_method(mname)
            if m then
                sdk.hook(m, on_pre_set_transform, on_post_noop)
            end
        end
        log.info("[GravityGun] Transform intercept hooks installed")
    end
end)

--- Safe method handle call with pcall wrapping
local function call_handle(handle, ...)
    if not handle then return nil, false end
    local ok, result = pcall(function(...) return handle:call(...) end, ...)
    return result, ok
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Vector / Quaternion Math Helpers
-- (Mirrors NoClip helpers from features.lua for consistency)
-- ═══════════════════════════════════════════════════════════════════════════

local function vec_len(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function vec_norm(v)
    local l = vec_len(v)
    if l < 0.00001 then return Vector3f.new(0, 0, 0) end
    return Vector3f.new(v.x / l, v.y / l, v.z / l)
end

local function vec_add(a, b)
    return Vector3f.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function vec_sub(a, b)
    return Vector3f.new(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function vec_scale(v, s)
    return Vector3f.new(v.x * s, v.y * s, v.z * s)
end

local function vec_lerp(a, b, t)
    t = math.max(0, math.min(1, t))
    return Vector3f.new(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

local function vec_dist(a, b)
    return vec_len(vec_sub(a, b))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Camera Utilities
-- (Reuses camera approach from NoClip in features.lua)
-- ═══════════════════════════════════════════════════════════════════════════

--- Get camera position from WorldMatrix row 3
local function get_camera_position()
    local cam = nil
    pcall(function() cam = sdk.get_primary_camera() end)
    if not cam then return nil end

    local ok_m, matrix = pcall(function() return cam:call("get_WorldMatrix") end)
    if ok_m and matrix then
        local ok_r, row = pcall(function() return matrix[3] end)
        if ok_r and row and row.x and row.y and row.z then
            return Vector3f.new(row.x, row.y, row.z)
        end
    end
    return nil
end

--- Get camera forward direction from WorldMatrix row 2 (negated Z)
local function get_camera_forward()
    local cam = nil
    pcall(function() cam = sdk.get_primary_camera() end)
    if not cam then return nil end

    local ok_m, matrix = pcall(function() return cam:call("get_WorldMatrix") end)
    if ok_m and matrix then
        -- Row 2 is the forward axis (negated for look direction)
        local ok_r, row = pcall(function() return matrix[2] end)
        if ok_r and row and row.x and row.y and row.z then
            return vec_norm(Vector3f.new(-row.x, -row.y, -row.z))
        end
    end
    return nil
end

--- Get camera rotation quaternion from WorldMatrix
local function get_camera_rotation()
    local cam = nil
    pcall(function() cam = sdk.get_primary_camera() end)
    if not cam then return nil end

    local ok_m, matrix = pcall(function() return cam:call("get_WorldMatrix") end)
    if ok_m and matrix then
        local ok_q, quat = pcall(function() return matrix:to_quat() end)
        if ok_q and quat then return quat end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform Read/Write Helpers
-- ═══════════════════════════════════════════════════════════════════════════

--- Read position from a transform (with fallback chain)
local function read_position(xf)
    if not xf then return nil end
    -- Primary: direct colon syntax (proven RE9 pattern from noclip)
    local ok1, p1 = pcall(function() return xf:get_Position() end)
    if ok1 and p1 then return p1 end
    -- Fallback: cached method handle
    local pos, ok = call_handle(m_xf_get_pos, xf)
    if ok and pos then return pos end
    -- Fallback: direct Lua property
    local ok2, p = pcall(function() return xf.Position end)
    if ok2 and p then return p end
    return nil
end

--- Write position to a transform — with diagnostics
local write_method_used = "none"  -- track which method works for debug UI
local function write_position(xf, pos)
    if not xf or not pos then return false end
    -- NOTE: caller must wrap in with_writing() — this function does NOT manage is_writing

    -- Strategy 1: sdk.call_native_func (lowest level, most reliable)
    local ok1 = pcall(function()
        sdk.call_native_func(xf, xf_type, "set_Position", pos)
    end)
    if ok1 then write_method_used = "native_func"; return true end

    -- Strategy 2: cached method handle
    local _, ok2 = call_handle(m_xf_set_pos, xf, pos)
    if ok2 then write_method_used = "method_handle"; return true end

    -- Strategy 3: direct colon syntax (noclip fallback)
    local ok3 = pcall(function() xf:set_position(pos, true) end)
    if ok3 then write_method_used = "colon_syntax"; return true end

    -- Strategy 4: property assignment
    local ok4 = pcall(function() xf.Position = pos end)
    if ok4 then write_method_used = "property"; return true end

    -- Strategy 5: call string
    local ok5 = pcall(function() xf:call("set_Position", pos) end)
    if ok5 then write_method_used = "call_string"; return true end

    write_method_used = "ALL FAILED"
    return false
end

--- Write rotation to a transform
local function write_rotation(xf, rot)
    if not xf or not rot then return false end
    -- NOTE: caller must wrap in with_writing() — this function does NOT manage is_writing
    local ok1 = pcall(function() xf:set_rotation(rot, true) end)
    if ok1 then return true end
    local _, ok = call_handle(m_xf_set_rot, xf, rot)
    if ok then return true end
    local ok2 = pcall(function() xf:call("set_Rotation", rot) end)
    return ok2
end

--- Read rotation from a transform
local function read_rotation(xf)
    if not xf then return nil end
    local ok1, r1 = pcall(function() return xf:get_Rotation() end)
    if ok1 and r1 then return r1 end
    local rot, ok = call_handle(m_xf_get_rot, xf)
    if ok and rot then return rot end
    local ok2, r = pcall(function() return xf:call("get_Rotation") end)
    if ok2 and r then return r end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Raycasting
-- Uses scene-based collision query via via.physics or findGameObjectByRay
-- ═══════════════════════════════════════════════════════════════════════════

--- Attempt raycast from origin along direction, return hit info or nil
local function do_raycast(origin, direction, max_dist)
    if not origin or not direction then return nil end
    max_dist = max_dist or C.gg_ray_distance or 100.0

    -- Strategy 1: sdk.call_native_func on via.Physics (preferred)
    local hit = nil
    pcall(function()
        local physics_td = sdk.find_type_definition("via.physics.System")
        if not physics_td then return end
        local cast_m = physics_td:get_method("castRay(via.vec3, via.vec3, System.Single)")
            or physics_td:get_method("castRay")
        if not cast_m then return end

        local physics = sdk.get_native_singleton("via.physics.System")
        if not physics then return end

        local endpoint = vec_add(origin, vec_scale(direction, max_dist))
        local result = sdk.call_native_func(physics, physics_td,
            "castRay(via.vec3, via.vec3, System.Single)",
            origin, endpoint, max_dist)
        if result then
            hit = result
        end
    end)
    if hit then return hit end

    -- Strategy 2: Scene-based findGameObjectByRay
    pcall(function()
        local scene = get_scene()
        if not scene then return end

        -- Try sweep/ray methods on the scene
        local ray_m = nil
        pcall(function()
            local scene_td = scene:get_type_definition()
            if scene_td then
                ray_m = scene_td:get_method("findGameObjectByRay")
                    or scene_td:get_method("castRay")
            end
        end)
        if ray_m then
            local endpoint = vec_add(origin, vec_scale(direction, max_dist))
            local result = ray_m:call(scene, origin, endpoint)
            if result then hit = result end
        end
    end)
    if hit then return hit end

    -- Strategy 3: Manual proximity check against scene GameObjects
    -- (Fallback — find closest GO along ray via transform proximity)
    pcall(function()
        local scene = get_scene()
        if not scene then return end

        -- Get all transforms in the scene
        local xf_rt = sdk.typeof("via.Transform")
        if not xf_rt then return end
        local comps = scene:call("findComponents(System.Type)", xf_rt)
        if not comps then return end
        local ok_c, count = pcall(comps.call, comps, "get_Count")
        if not ok_c or not count or count <= 0 then return end

        local best_go = nil
        local best_dist = math.huge
        local best_pos = nil
        local ray_end = vec_add(origin, vec_scale(direction, max_dist))

        -- Only check a limited number to avoid frame stalls
        local check_limit = math.min(count - 1, 500)
        for i = 0, check_limit do
            pcall(function()
                local xf = comps:call("get_Item", i)
                if not xf then return end
                local pos = read_position(xf)
                if not pos then return end

                -- Point-to-ray distance check
                local to_point = vec_sub(pos, origin)
                local dot = to_point.x * direction.x + to_point.y * direction.y + to_point.z * direction.z
                if dot < 0.5 or dot > max_dist then return end -- behind camera or too far

                local proj = vec_add(origin, vec_scale(direction, dot))
                local perp_dist = vec_dist(pos, proj)

                if perp_dist < 2.0 and dot < best_dist then
                    local go = xf:call("get_GameObject")
                    if go then
                        local is_draw = true
                        pcall(function() is_draw = go:call("get_Draw") end)
                        if is_draw then
                            best_go = go
                            best_dist = dot
                            best_pos = pos
                        end
                    end
                end
            end)
        end

        if best_go then
            local name = ""
            pcall(function() name = tostring(best_go:call("get_Name") or "Object") end)
            hit = {
                go = best_go,
                pos = best_pos,
                distance = best_dist,
                name = name,
            }
        end
    end)

    return hit
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Grab / Release / Throw Logic
-- ═══════════════════════════════════════════════════════════════════════════

local function set_error(msg)
    state.error_msg = msg
    state.error_time = os.clock()
    log.warn("[GravityGun] " .. msg)
end

local function clear_error()
    if state.error_msg and (os.clock() - state.error_time) > 3.0 then
        state.error_msg = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Component Force System (EMV Engine pattern)
-- Force object components every frame to allow position writes to stick.
-- Key insight: set_ForceDynamicMesh(true) makes static meshes moveable.
-- ═══════════════════════════════════════════════════════════════════════════

local forced_state = {
    go = nil,
    mesh = nil,           -- via.render.Mesh
    colliders = nil,      -- via.physics.Colliders
    char_ctrl = nil,      -- via.physics.CharacterController
    ik_leg = nil,          -- via.motion.IkLeg
    shapes = {},           -- shape transform matrices
    original = {},         -- original values to restore
    active = false,
}

-- Called once on grab: set up forced components
local function force_grab_start(go)
    forced_state.go = go
    forced_state.original = {}
    forced_state.shapes = {}
    forced_state.active = true

    -- via.render.Mesh: make static mesh dynamic
    pcall(function()
        local rt = sdk.typeof("via.render.Mesh")
        if not rt then return end
        local mesh = go:call("getComponent(System.Type)", rt)
        if not mesh then return end
        forced_state.mesh = mesh
        -- Save originals
        pcall(function() forced_state.original.force_dyn = mesh:call("get_ForceDynamicMesh") end)
        pcall(function() forced_state.original.static_mesh = mesh:call("get_StaticMesh") end)
        -- Force dynamic
        pcall(function() mesh:call("set_ForceDynamicMesh", true) end)
        pcall(function() mesh:call("set_StaticMesh", false) end)
        log.info("[GravityGun] Mesh: ForceDynamic=true, Static=false")
    end)

    -- via.physics.Colliders: make non-static
    pcall(function()
        local rt = sdk.typeof("via.physics.Colliders")
        if not rt then return end
        local col = go:call("getComponent(System.Type)", rt)
        if not col then return end
        forced_state.colliders = col
        pcall(function() forced_state.original.col_static = col:call("get_Static") end)
        pcall(function() forced_state.original.col_enabled = col:call("get_Enabled") end)
        pcall(function() col:call("set_Static", false) end)
        pcall(function() col:call("set_Enabled", true) end)
        -- Collect shapes for transform matrix syncing
        pcall(function()
            local n = col:call("get_NumColliders") or 0
            for i = 0, n - 1 do
                pcall(function()
                    local c = col:call("getColliders", i)
                    if c then
                        local shape = c:call("get_TransformedShape") or c:call("get_Shape")
                        if shape then table.insert(forced_state.shapes, shape) end
                    end
                end)
            end
        end)
        log.info("[GravityGun] Colliders: Static=false, shapes=" .. #forced_state.shapes)
    end)

    -- via.physics.CharacterController
    pcall(function()
        local rt = sdk.typeof("via.physics.CharacterController")
        if not rt then return end
        forced_state.char_ctrl = go:call("getComponent(System.Type)", rt)
    end)

    -- via.motion.IkLeg: disable
    pcall(function()
        local rt = sdk.typeof("via.motion.IkLeg")
        if not rt then return end
        local ik = go:call("getComponent(System.Type)", rt)
        if not ik then return end
        forced_state.ik_leg = ik
        pcall(function() forced_state.original.ik_enabled = ik:call("get_Enabled") end)
        pcall(function() ik:call("set_Enabled", false) end)
    end)

    log.info("[GravityGun] Force system activated")
end

-- Called every frame while grabbing: keep forcing values
local function force_grab_tick()
    if not forced_state.active then return end

    -- Colliders: force non-static + update every frame (EMV pattern)
    if forced_state.colliders then
        pcall(function() forced_state.colliders:call("set_Static", false) end)
        pcall(function() forced_state.colliders:call("set_Enabled", true) end)
        pcall(function() forced_state.colliders:call("updatePose") end)
        pcall(function() forced_state.colliders:call("updateNotify") end)
        pcall(function() forced_state.colliders:call("onDirty") end)
    end

    -- CharacterController: warp every frame
    if forced_state.char_ctrl then
        pcall(function() forced_state.char_ctrl:call("warp") end)
    end
end

-- Called once on release: restore originals
local function force_grab_end()
    if not forced_state.active then return end

    -- Restore mesh
    if forced_state.mesh then
        if forced_state.original.force_dyn ~= nil then
            pcall(function() forced_state.mesh:call("set_ForceDynamicMesh", forced_state.original.force_dyn) end)
        end
        if forced_state.original.static_mesh ~= nil then
            pcall(function() forced_state.mesh:call("set_StaticMesh", forced_state.original.static_mesh) end)
        end
    end

    -- Restore colliders
    if forced_state.colliders then
        if forced_state.original.col_static ~= nil then
            pcall(function() forced_state.colliders:call("set_Static", forced_state.original.col_static) end)
        end
    end

    -- Restore IkLeg
    if forced_state.ik_leg and forced_state.original.ik_enabled then
        pcall(function() forced_state.ik_leg:call("set_Enabled", forced_state.original.ik_enabled) end)
    end

    forced_state.active = false
    forced_state.go = nil
    forced_state.mesh = nil
    forced_state.colliders = nil
    forced_state.char_ctrl = nil
    forced_state.ik_leg = nil
    forced_state.shapes = {}
    forced_state.original = {}
    log.info("[GravityGun] Force system deactivated")
end

--- Try to grab the object under the crosshair
local function try_grab()
    local cam_pos = get_camera_position()
    local cam_fwd = get_camera_forward()
    if not cam_pos or not cam_fwd then
        set_error("No camera available")
        state.status = "No Camera"
        return false
    end

    state.status = "Raycasting..."

    local hit = do_raycast(cam_pos, cam_fwd, C.gg_ray_distance)
    if not hit then
        set_error("No object found in crosshair")
        state.status = "No Target"
        return false
    end

    -- Extract GameObject from hit result
    local go = nil
    local hit_pos = nil
    local hit_name = ""

    if hit.go then
        -- From our manual proximity check
        go = hit.go
        hit_pos = hit.pos
        hit_name = hit.name or ""
    else
        -- From native raycast — try to extract GO
        pcall(function()
            if type(hit) == "userdata" then
                -- Could be a RaycastHit result
                local col = hit:call("get_Collider") or hit:get_field("Collider")
                if col then
                    go = col:call("get_GameObject")
                end
                local p = hit:call("get_Point") or hit:get_field("Point")
                if p then hit_pos = p end
            end
        end)
        if go then
            pcall(function() hit_name = tostring(go:call("get_Name") or "Object") end)
        end
    end

    if not go then
        set_error("Raycast hit but no GameObject extracted")
        state.status = "No GO"
        return false
    end

    -- Get transform
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        set_error("Target has no Transform")
        state.status = "No XF"
        return false
    end

    -- Read current object position
    local obj_pos = read_position(xf)
    if not obj_pos then
        set_error("Cannot read target position")
        state.status = "Read Fail"
        return false
    end

    -- Success — set up grab state
    state.target_go = go
    state.target_xf = xf
    state.target_name = hit_name
    state.grab_distance = vec_dist(cam_pos, obj_pos)
    state.grab_distance = math.max(C.gg_grab_dist_min,
        math.min(state.grab_distance, C.gg_grab_dist_max))
    state.grab_rotation = read_rotation(xf)
    state.is_grabbing = true
    state.grab_count = state.grab_count + 1
    grabbed_transforms[xf] = true  -- register with hook system

    -- Activate EMV-style force system (ForceDynamicMesh, Colliders, etc.)
    force_grab_start(go)

    state.status = "Grabbing: " .. hit_name
    if toast then toast("Grabbed: " .. hit_name, 0xFF44FF88) end
    log.info("[GravityGun] Grabbed: " .. hit_name
        .. " dist=" .. string.format("%.1f", state.grab_distance))

    return true
end

--- Release the grabbed object (optionally with throw)
local function release(do_throw)
    if not state.is_grabbing then return end

    local name = state.target_name

    if do_throw and state.target_xf then
        -- Apply throw impulse: push object forward along camera look direction
        local cam_fwd = get_camera_forward()
        if cam_fwd then
            local throw_vec = vec_scale(cam_fwd, C.gg_throw_force)
            local cur_pos = read_position(state.target_xf)
            if cur_pos then
                local throw_pos = vec_add(cur_pos, throw_vec)
                -- Use deferred_call pattern for safety if available
                local ok = write_position(state.target_xf, throw_pos)
                if ok then
                    state.throw_count = state.throw_count + 1
                    if toast then toast("Threw: " .. name, 0xFFFF8844) end
                    log.info("[GravityGun] Threw: " .. name)
                end
            end
        end
    else
        if toast then toast("Released: " .. name, 0xFF88DDFF) end
    end

    -- Unregister from hook system
    if state.target_xf then
        grabbed_transforms[state.target_xf] = nil
    end
    -- Deactivate force system (restore originals)
    force_grab_end()
    -- Clear grab state
    state.target_go = nil
    state.target_xf = nil
    state.target_name = ""
    state.grab_offset = nil
    state.grab_rotation = nil
    state.is_grabbing = false
    state.status = "Idle"
end

--- Validate that grabbed target is still valid
local function validate_target()
    if not state.is_grabbing then return true end
    if not state.target_xf then
        release(false)
        return false
    end
    -- Check if GO is still a valid managed object
    local ok = pcall(function()
        if not sdk.is_managed_object(state.target_go) then
            error("stale")
        end
        -- Verify we can still read position
        local p = read_position(state.target_xf)
        if not p then error("no pos") end
    end)
    if not ok then
        set_error("Target became invalid")
        release(false)
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Input Handling (Edge Detection)
-- ═══════════════════════════════════════════════════════════════════════════

local function is_key_down(vk)
    if not vk or vk == 0 then return false end
    local ok, d = pcall(function() return reframework:is_key_down(vk) end)
    return ok and d
end

local function process_input()
    -- Middle mouse: click-to-toggle (click once to grab, click again to release)
    local mmb_down = is_key_down(C.gg_key_grab)
    local mmb_just_pressed = mmb_down and not state.mmb_was_down
    state.mmb_was_down = mmb_down

    if mmb_just_pressed then
        if not state.is_grabbing then
            try_grab()
        else
            release(false)  -- release without throw on click
        end
    end

    -- Distance adjustment (Numpad +/-)
    local plus_down = is_key_down(C.gg_key_dist_up)
    if plus_down and not state.plus_was_down and state.is_grabbing then
        state.grab_distance = math.min(state.grab_distance + C.gg_grab_dist_step, C.gg_grab_dist_max)
    end
    state.plus_was_down = plus_down

    local minus_down = is_key_down(C.gg_key_dist_down)
    if minus_down and not state.minus_was_down and state.is_grabbing then
        state.grab_distance = math.max(state.grab_distance - C.gg_grab_dist_step, C.gg_grab_dist_min)
    end
    state.minus_was_down = minus_down

    -- Mode cycle (Z key)
    local z_down = is_key_down(C.gg_key_mode)
    if z_down and not state.z_was_down then
        C.gg_grab_mode = (C.gg_grab_mode == 1) and 2 or 1
        local mode_name = C.gg_grab_mode == 1 and "Position Only" or "Position + Rotation"
        if toast then toast("Grab Mode: " .. mode_name, 0xFF44DDFF) end
    end
    state.z_was_down = z_down
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Per-Frame Update (move grabbed object to follow camera aim)
-- ═══════════════════════════════════════════════════════════════════════════

local last_update = os.clock()

local debug_before_pos = nil
local debug_after_pos = nil
local debug_target_pos = nil

local function update_grabbed_object()
    if not state.is_grabbing then return end
    if not validate_target() then return end

    local now = os.clock()
    local dt = now - last_update
    last_update = now
    if dt < 0 or dt > 0.25 then dt = 1 / 60 end

    local cam_pos = get_camera_position()
    local cam_fwd = get_camera_forward()
    if not cam_pos or not cam_fwd then return end

    -- Target position: camera_pos + forward * grab_distance
    local target_pos = vec_add(cam_pos, vec_scale(cam_fwd, state.grab_distance))
    debug_target_pos = target_pos

    -- Read current object position
    local cur_pos = read_position(state.target_xf)
    if not cur_pos then
        release(false)
        return
    end
    debug_before_pos = cur_pos

    -- Lerp toward target position for smooth movement
    local lerp_t = math.min(1.0, C.gg_lerp_speed * dt)
    local new_pos = vec_lerp(cur_pos, target_pos, lerp_t)

    -- Write position (EMV style: also use xf:call for compatibility)
    local ok
    with_writing(function()
        ok = pcall(function() state.target_xf:call("set_Position", new_pos) end)
        if not ok then
            ok = write_position(state.target_xf, new_pos)
        else
            write_method_used = "emv_call"
        end
    end)
    if not ok then
        set_error("Failed to write position")
        release(false)
        return
    end

    -- Sync physics shape matrices (EMV pattern: shapes follow transform)
    if forced_state.active and #forced_state.shapes > 0 then
        pcall(function()
            local mat = state.target_xf:call("get_WorldMatrix")
            if mat then
                for _, shape in ipairs(forced_state.shapes) do
                    pcall(function()
                        local shape_mat = shape:call("get_TransformMatrix")
                        if shape_mat then
                            shape_mat[3] = mat[3]
                            shape:call("set_TransformMatrix", shape_mat)
                        end
                    end)
                end
            end
        end)
    end

    -- Force components every frame (EMV pattern)
    force_grab_tick()

    -- Readback to verify write actually took effect
    local verify_pos = read_position(state.target_xf)
    debug_after_pos = verify_pos

    -- Optionally sync rotation to camera
    if C.gg_grab_mode == 2 then
        local cam_rot = get_camera_rotation()
        if cam_rot then
            with_writing(function()
                pcall(function() state.target_xf:call("set_LocalRotation", cam_rot) end)
            end)
        end
    end

    state.status = "Holding: " .. state.target_name
        .. " [" .. string.format("%.1fm", state.grab_distance) .. "]"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Passive Raycast (update crosshair target name when not grabbing)
-- ═══════════════════════════════════════════════════════════════════════════

local function update_passive_ray()
    if state.is_grabbing then return end
    local now = os.clock()
    -- Only raycast every 0.2s to save perf
    if now - state.last_ray_time < 0.2 then return end
    state.last_ray_time = now

    local cam_pos = get_camera_position()
    local cam_fwd = get_camera_forward()
    if not cam_pos or not cam_fwd then
        state.last_ray_hit = nil
        return
    end

    local hit = do_raycast(cam_pos, cam_fwd, C.gg_ray_distance)
    if hit then
        state.last_ray_hit = hit
        if hit.name and hit.name ~= "" then
            state.status = "Target: " .. hit.name
                .. " [" .. string.format("%.1fm", hit.distance or 0) .. "]"
        else
            state.status = "Target found"
        end
    else
        state.last_ray_hit = nil
        state.status = "Idle"
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.init()
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.init()
    -- Merge config defaults
    for k, v in pairs(CONFIG_DEFAULTS) do
        if C[k] == nil then
            C[k] = v
        end
    end

    -- Initialize transform method handles
    if not init_transform_methods() then
        log.warn("[GravityGun] Could not cache via.Transform methods — will use fallbacks")
    end

    log.info("[GravityGun] Module initialized")
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.update()
-- Called every frame from re.on_pre_application_entry("LateUpdateBehavior")
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.update()
    if not C.gravity_gun_enabled then
        -- If we were grabbing, release cleanly
        if state.is_grabbing then
            release(false)
        end
        return
    end

    clear_error()
    process_input()
    update_grabbed_object()
    update_passive_ray()
end

-- Auto-release grabs on scene transitions to prevent dangling pointers
re.on_pre_application_entry("BeginRendering", function()
    if state.is_grabbing then
        release(false)
        if log then log.info("[GG] Auto-released grab on scene transition") end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.render_ui()
-- Called from re.on_draw_ui inside a tree node or tab
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.render_ui()
    -- Master toggle
    local changed_en, new_en = imgui.checkbox("Enable Gravity Gun", C.gravity_gun_enabled)
    if changed_en then C.gravity_gun_enabled = new_en end

    if not C.gravity_gun_enabled then
        imgui.text_colored("Disabled", 0xFF888888)
        return
    end

    imgui.separator()

    -- Status
    local status_color = state.is_grabbing and 0xFF44FF88 or 0xFFCCCCCC
    imgui.text_colored("Status: " .. state.status, status_color)

    -- Error display
    if state.error_msg then
        imgui.text_colored("⚠ " .. state.error_msg, 0xFFFF6666)
    end

    imgui.separator()

    -- Grab mode
    local mode_name = C.gg_grab_mode == 1 and "Position Only" or "Position + Rotation"
    imgui.text("Grab Mode: " .. mode_name .. "  (Z to cycle)")

    -- Stats
    imgui.text(string.format("Grabs: %d  |  Throws: %d", state.grab_count, state.throw_count))

    if state.is_grabbing then
        imgui.text(string.format("Object: %s", state.target_name))
        imgui.text(string.format("Distance: %.1f m", state.grab_distance))
        imgui.text_colored("Write: " .. write_method_used, 0xFFFFAA44)
        -- Position verification
        if debug_before_pos then
            imgui.text(string.format("Before: %.1f, %.1f, %.1f", debug_before_pos.x, debug_before_pos.y, debug_before_pos.z))
        end
        if debug_after_pos then
            imgui.text(string.format("After:  %.1f, %.1f, %.1f", debug_after_pos.x, debug_after_pos.y, debug_after_pos.z))
        end
        if debug_target_pos then
            imgui.text(string.format("Target: %.1f, %.1f, %.1f", debug_target_pos.x, debug_target_pos.y, debug_target_pos.z))
        end
        -- Check if write took effect
        if debug_before_pos and debug_after_pos then
            local moved = math.abs(debug_before_pos.x - debug_after_pos.x) > 0.01
                or math.abs(debug_before_pos.y - debug_after_pos.y) > 0.01
                or math.abs(debug_before_pos.z - debug_after_pos.z) > 0.01
            if moved then
                imgui.text_colored("WRITE VERIFIED", 0xFF44FF88)
            else
                imgui.text_colored("WRITE IGNORED BY ENGINE", 0xFF4444FF)
            end
        end
    end

    -- Debug diagnostics
    imgui.text_colored("xf_type: " .. tostring(xf_type ~= nil) .. "  m_set_pos: " .. tostring(m_xf_set_pos ~= nil), 0xFF999999)

    imgui.separator()
    imgui.text("Settings")

    -- Throw force
    local ch_tf, v_tf = imgui.drag_float("Throw Force", C.gg_throw_force, 0.5, 1.0, 100.0)
    if ch_tf then C.gg_throw_force = v_tf end

    -- Lerp speed
    local ch_ls, v_ls = imgui.drag_float("Follow Speed", C.gg_lerp_speed, 0.5, 1.0, 50.0)
    if ch_ls then C.gg_lerp_speed = v_ls end

    -- Ray distance
    local ch_rd, v_rd = imgui.drag_float("Max Ray Dist", C.gg_ray_distance, 1.0, 10.0, 500.0)
    if ch_rd then C.gg_ray_distance = v_rd end

    -- Distance step
    local ch_ds, v_ds = imgui.drag_float("Dist Step (+/-)", C.gg_grab_dist_step, 0.1, 0.1, 5.0)
    if ch_ds then C.gg_grab_dist_step = v_ds end

    -- Debug viz toggle
    local ch_dbg, v_dbg = imgui.checkbox("Show Debug Viz", C.gg_show_debug)
    if ch_dbg then C.gg_show_debug = v_dbg end

    imgui.separator()
    imgui.text_colored("Controls:", 0xFF88AACC)
    imgui.text("  Middle Mouse — Grab/Throw")
    imgui.text("  Numpad +/-   — Adjust distance")
    imgui.text("  Z            — Cycle grab mode")

    -- Emergency release button
    if state.is_grabbing then
        imgui.separator()
        if imgui.button("Force Release") then
            release(false)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.render_world()
-- Called from re.on_frame for 3D debug visualization
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.render_world()
    if not C.gravity_gun_enabled or not C.gg_show_debug then return end

    -- Draw grab line when holding
    if state.is_grabbing and state.target_xf then
        pcall(function()
            local cam_pos = get_camera_position()
            local obj_pos = read_position(state.target_xf)
            if not cam_pos or not obj_pos then return end

            -- World-to-screen for both points
            local draw_list = imgui.get_background_draw_list()
            if not draw_list then return end

            -- Convert world positions to screen
            local ok1, sp1 = pcall(function()
                return draw.world_to_screen(cam_pos)
            end)
            local ok2, sp2 = pcall(function()
                return draw.world_to_screen(obj_pos)
            end)

            if ok1 and sp1 and ok2 and sp2 then
                draw_list:add_line(sp1, sp2, 0xFF44FF88, 2.0)
                draw_list:add_circle_filled(sp2, 6.0, 0xFF44FF88)
            end
        end)
    end

    -- Draw crosshair highlight on passive target
    if not state.is_grabbing and state.last_ray_hit and state.last_ray_hit.pos then
        pcall(function()
            local draw_list = imgui.get_background_draw_list()
            if not draw_list then return end
            local ok_s, sp = pcall(function()
                return draw.world_to_screen(state.last_ray_hit.pos)
            end)
            if ok_s and sp then
                draw_list:add_circle(sp, 12.0, 0xFFFFCC44, 20, 2.0)
                draw_list:add_circle(sp, 4.0, 0xFFFFCC44, 12, 1.5)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.grab_object(go)
-- Grab a specific GameObject by reference (called from Object Explorer etc.)
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.grab_object(go)
    if not go then return false end

    -- Release current grab if any
    if state.is_grabbing then release(false) end

    -- Enable gravity gun if not already enabled
    C.gravity_gun_enabled = true

    -- Get transform
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    if not xf then
        set_error("Target has no Transform")
        return false
    end

    -- Read current position
    local obj_pos = read_position(xf)
    if not obj_pos then
        set_error("Cannot read target position")
        return false
    end

    -- Get camera position for distance calculation
    local cam_pos = get_camera_position()
    local dist = 5.0  -- default distance
    if cam_pos then
        dist = vec_dist(cam_pos, obj_pos)
        dist = math.max(C.gg_grab_dist_min, math.min(dist, C.gg_grab_dist_max))
    end

    -- Get name
    local hit_name = ""
    pcall(function() hit_name = tostring(go:call("get_Name") or "Object") end)

    -- Set up grab state
    state.target_go = go
    state.target_xf = xf
    state.target_name = hit_name
    state.grab_distance = dist
    state.grab_rotation = read_rotation(xf)
    state.is_grabbing = true
    state.grab_count = state.grab_count + 1
    grabbed_transforms[xf] = true

    -- Activate force system
    force_grab_start(go)

    state.status = "Grabbing: " .. hit_name
    if toast then toast("Grabbed: " .. hit_name, 0xFF44FF88) end
    log.info("[GravityGun] grab_object: " .. hit_name)
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Public API: GravityGun.get_state() — for external debug/status queries
-- ═══════════════════════════════════════════════════════════════════════════

function GravityGun.get_state()
    return {
        is_grabbing   = state.is_grabbing,
        target_name   = state.target_name,
        grab_distance = state.grab_distance,
        grab_mode     = C.gg_grab_mode,
        status        = state.status,
        error         = state.error_msg,
        grab_count    = state.grab_count,
        throw_count   = state.throw_count,
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Export to Trainer Table
-- ═══════════════════════════════════════════════════════════════════════════

T.GravityGun = GravityGun

-- Auto-init on load
GravityGun.init()

log.info("[Trainer] Gravity Gun module loaded")

return GravityGun
