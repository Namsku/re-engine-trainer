-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — NoClip Sub-Module
-- Camera-relative movement, anti-death/fall hooks, transform manipulation
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local pctx, php, toast = T.pctx, T.php, T.toast
local nc = {
    pos = nil,          -- current noclip position (Vector3f)
    rot = nil,          -- current quaternion
    transform = nil,    -- player via.Transform
    cc = nil,           -- CharacterController
    hooks_installed = false,
    hook_count = 0,
    active = false,     -- is noclip movement active this frame
}

-- via.Transform method handles (native call trap workaround)
local xf_type    = sdk.find_type_definition("via.Transform")
local m_xf_get_pos = xf_type and xf_type:get_method("get_Position")
local m_xf_set_pos = xf_type and xf_type:get_method("set_Position")
local m_xf_get_rot = xf_type and xf_type:get_method("get_Rotation")
local m_xf_set_rot = xf_type and xf_type:get_method("set_Rotation")

local function nc_call_handle(handle, ...)
    if not handle then return nil, false end
    local ok, result = pcall(function(...) return handle:call(...) end, ...)
    return result, ok
end

-- Get camera rotation quaternion (WorldMatrix approach - most reliable)
local function nc_get_camera_rotation()
    local cam = nil
    pcall(function() cam = sdk.get_primary_camera() end)
    if not cam then return nil end

    -- Primary: WorldMatrix → quaternion
    local ok_m, matrix = pcall(function() return cam:call("get_WorldMatrix") end)
    if ok_m and matrix then
        local ok_q, quat = pcall(function() return matrix:to_quat() end)
        if ok_q and quat then return quat end
    end

    -- Fallback: camera GameObject → Transform → get_Rotation
    pcall(function()
        local go = cam:call("get_GameObject")
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local rot, ok2 = nc_call_handle(m_xf_get_rot, xf)
        if ok2 and rot then return rot end
    end)
    return nil
end

-- Get camera position (WorldMatrix row 3)
local function nc_get_camera_position()
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

-- Quaternion helpers
local function nc_quat_yaw(q)
    if not q then return 0 end
    local siny = 2 * (q.w * q.y + q.x * q.z)
    local cosy = 1 - 2 * (q.y * q.y + q.x * q.x)
    return math.atan(siny, cosy)
end

local function nc_quat_from_yaw(yaw)
    local h = yaw * 0.5
    return Vector4f.new(0, math.sin(h), 0, math.cos(h))
end

local function nc_quat_rotate(q, v)
    if not q then return v end
    local ux, uy, uz, s = q.x, q.y, q.z, q.w
    local dot_uv = ux*v.x + uy*v.y + uz*v.z
    local dot_uu = ux*ux + uy*uy + uz*uz
    local cx = uy*v.z - uz*v.y
    local cy = uz*v.x - ux*v.z
    local cz = ux*v.y - uy*v.x
    return Vector3f.new(
        2*dot_uv*ux + (s*s - dot_uu)*v.x + 2*s*cx,
        2*dot_uv*uy + (s*s - dot_uu)*v.y + 2*s*cy,
        2*dot_uv*uz + (s*s - dot_uu)*v.z + 2*s*cz
    )
end

local function nc_vec_len(v) return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) end
local function nc_vec_norm(v)
    local l = nc_vec_len(v)
    if l < 0.00001 then return Vector3f.new(0,0,0) end
    return Vector3f.new(v.x/l, v.y/l, v.z/l)
end

-- Resolve player transform from context
local function nc_resolve()
    nc.transform = nil
    nc.cc = nil
    local ctx = pctx()
    if not ctx then return false end

    -- Transform via body gameobject
    pcall(function()
        local go = ctx:call("get_BodyGameObject")
        if go then nc.transform = go:call("get_Transform") end
    end)
    if not nc.transform then
        pcall(function() nc.transform = ctx:call("get_Transform") end)
    end

    -- Character controller
    pcall(function()
        local updater = ctx:call("get_Updater")
        if updater then nc.cc = updater:call("get_CharacterController") end
    end)
    if not nc.cc then
        pcall(function() nc.cc = ctx:call("get_CharacterController") end)
    end

    return nc.transform ~= nil
end

-- Read current position from transform
local function nc_get_pos()
    if not nc.transform then return nil end
    local pos, ok = nc_call_handle(m_xf_get_pos, nc.transform)
    if ok and pos then return pos end
    -- Fallback
    local ok2, p = pcall(function() return nc.transform:get_Position() end)
    if ok2 and p then return p end
    return nil
end

-- Write position
local function nc_set_pos(pos)
    if not nc.transform or not pos then return false end
    -- Warp character controller first to prevent rubber-banding
    if nc.cc then pcall(function() nc.cc:call("warp") end) end
    local _, ok1 = nc_call_handle(m_xf_set_pos, nc.transform, pos)
    if not ok1 then
        pcall(function() nc.transform:set_position(pos, true) end)
    end
    if nc.cc then pcall(function() nc.cc:call("warp") end) end
    return true
end

-- Write rotation (yaw only, upright)
local function nc_set_rot(rot)
    if not nc.transform or not rot then return false end
    local _, ok = nc_call_handle(m_xf_set_rot, nc.transform, rot)
    return ok
end

-- ── Anti-Death Guard Hooks ──
local PREHOOK_CONTINUE = sdk.PreHookResult.CALL_ORIGINAL
local PREHOOK_SKIP     = sdk.PreHookResult.SKIP_ORIGINAL

local function nc_should_block_death()
    return C.noclip and C.noclip_anti_death
end

local function nc_should_block_fall()
    return C.noclip and C.noclip_no_fall
end

local function nc_install_hook(type_name, method_names, skip_fn, label)
    local td = sdk.find_type_definition(type_name)
    if not td then return false end
    local m = nil
    for _, name in ipairs(method_names) do
        pcall(function() m = td:get_method(name) end)
        if m then break end
    end
    if not m then
        -- Scan all methods for partial match
        pcall(function()
            local methods = td:get_methods()
            if not methods then return end
            for _, method in ipairs(methods) do
                local actual = tostring(method:get_name() or "")
                for _, candidate in ipairs(method_names) do
                    local c = candidate:gsub("%(.*", "")
                    if c ~= "" and actual:find(c, 1, true) == 1 then
                        m = method
                        return
                    end
                end
            end
        end)
    end
    if not m then return false end
    local ok = pcall(function()
        sdk.hook(m,
            function() return skip_fn() and PREHOOK_SKIP or PREHOOK_CONTINUE end,
            function(rv) return rv end)
    end)
    if ok then
        nc.hook_count = nc.hook_count + 1
        log.info("[NoClip] Hook: " .. label .. " -> " .. type_name)
    end
    return ok
end

local function nc_install_hooks()
    if nc.hooks_installed then return end
    nc.hooks_installed = true

    -- Death/game-over blocks
    local death_hooks = {
        {"app.PlayerUpdaterBase",   {"updateDeadRequest", "onDead", "checkExecuteDeadActionOnDead", "selectDeadAction", "execSafeProcFallLimit"}},
        {"app.CharacterManager",    {"requestGameOver"}},
        {"app.GameOverManager",     {"requestGameOver", "transitPhase"}},
    }
    for _, h in ipairs(death_hooks) do
        for _, mn in ipairs(h[2]) do
            nc_install_hook(h[1], {mn .. "()", mn}, nc_should_block_death, h[1] .. "." .. mn)
        end
    end

    -- Death setter blocks
    local setter_hooks = {
        {"app.CharacterManager",    {"set_RequestedGameOver", "set_RequestedGameOverIsFade", "set_IsGameOvered"}},
        {"app.PlayerContext",       {"set_IsDeadStatic"}},
        {"app.PlayerDeadBodyDriver", {"set_IsDeadRelease", "updateCheckDeadSpace", "updateDeadSpaceRayPermit"}},
    }
    for _, h in ipairs(setter_hooks) do
        for _, mn in ipairs(h[2]) do
            nc_install_hook(h[1], {mn .. "(System.Boolean)", mn .. "()", mn}, nc_should_block_death, h[1] .. "." .. mn)
        end
    end

    -- Fall system blocks
    local fall_hooks = {
        {"app.PlayerUpdaterBase",                 {"set_RequestedFallingHash", "set_RequestedLandingHash"}},
        {"app.PlayerEnvironmentProcessDriver",    {"setLandingAction", "onUpdateScanPhase", "landingPlayerProcess", "isPreventFall", "isSkipPreventFall", "checkSafeAreaFallEnd"}},
        {"app.PlayerStanceDriver",                {"updateHandUpMotion", "isEnableHandUpChangeAction"}},
        {"anim.AnimFallGroundChecker",            {"updateAnimation", "checkFallGround", "checkFallGroundCore"}},
        {"app.EnvironmentProcessDriver",          {"updateFallInfo", "detectGroundForAutoFallAction", "updateClimbStep"}},
    }
    for _, h in ipairs(fall_hooks) do
        for _, mn in ipairs(h[2]) do
            nc_install_hook(h[1], {mn .. "()", mn}, nc_should_block_fall, h[1] .. "." .. mn)
        end
    end

    log.info("[NoClip] Installed " .. nc.hook_count .. " guard hooks")
end

-- ── Suppress fall system fields ──
local function nc_suppress_fall()
    if not C.noclip_no_fall then return end
    local ctx = pctx()
    if not ctx then return end

    -- Common: reset fall state
    pcall(function()
        local common = ctx:call("get_Common")
        if not common then return end
        pcall(function() common:call("set_FallType", 0) end)
        pcall(function() common:call("set_IsDamageContinueState", false) end)
        pcall(function() common:call("set_IsFastGameOver", false) end)
    end)

    -- Updater: clear death triggers
    pcall(function()
        local updater = ctx:call("get_Updater")
        if not updater then return end
        pcall(function() updater:set_field("_IsDeadTrigger", false) end)
        pcall(function() updater:call("set_RequestedFallingHash", 0) end)
        pcall(function() updater:call("set_RequestedLandingHash", 0) end)
        pcall(function() updater:call("offAnimation") end)

        -- Null anim fall checker to prevent fall pose
        pcall(function() updater:call("set_AnimFallGroundChecker", nil) end)
    end)

    -- Environment: zero out fall parameters
    pcall(function()
        local updater = ctx:call("get_Updater")
        if not updater then return end
        local env = updater:get_field("<EnvironmentProcessDriver>k__BackingField")
        if not env then return end
        pcall(function() env:call("preventFall") end)
        pcall(function() env:call("stopFreeFallCtrl") end)
        pcall(function() env:call("set_FallDamage", 0) end)
        pcall(function() env:call("set_FallHeight", 0.0) end)
        pcall(function() env:call("set_PrevFallHeight", 0.0) end)
        pcall(function() env:call("set_HeightKeepGround", 100000.0) end)
        pcall(function() env:call("set_HeightPreventFall", 100000.0) end)
        pcall(function() env:call("set_IsDisableGravityUntilMotionEnd", true) end)
    end)
end

-- ── Main noclip tick (called every frame) ──
local nc_last_tick = os.clock()

local function noclip_tick()
    -- Install hooks once
    nc_install_hooks()

    if not C.noclip then
        -- Track real position when not active
        if nc.transform then
            local p = nc_get_pos()
            if p then nc.pos = p end
        end
        nc.active = false
        return
    end

    nc.active = true
    local now = os.clock()
    local dt = now - nc_last_tick
    nc_last_tick = now
    if dt < 0 or dt > 0.25 then dt = 1/60 end

    -- Resolve context if needed
    if not nc.transform then
        if not nc_resolve() then return end
    end

    -- Initialize position
    if not nc.pos then
        nc.pos = nc_get_pos()
        if not nc.pos then return end
    end

    -- Get camera rotation for steering
    local cam_rot = nc_get_camera_rotation()
    if cam_rot then nc.rot = cam_rot end

    -- WASD input
    local function kd(vk) return reframework:is_key_down(vk) end
    local mx = (kd(0x41) and 1 or 0) - (kd(0x44) and 1 or 0)  -- A/D
    local mz = (kd(0x57) and 1 or 0) - (kd(0x53) and 1 or 0)  -- W/S
    local my = (kd(0x45) and 1 or 0) - ((kd(0x51) or kd(0x43)) and 1 or 0)  -- E / Q,C

    local speed = C.noclip_speed
    local vert_speed = C.noclip_vert_speed
    if kd(0x10) then  -- Shift
        speed = speed * C.noclip_boost
        vert_speed = vert_speed * C.noclip_boost
    elseif kd(0x11) then  -- Ctrl
        speed = speed * C.noclip_slow
        vert_speed = vert_speed * C.noclip_slow
    end

    -- Camera-relative horizontal movement
    local move_yaw = nc_quat_yaw(nc.rot) + math.rad(C.noclip_yaw_offset)
    local move_rot = nc_quat_from_yaw(move_yaw)
    local local_move = Vector3f.new(mx, 0, mz)
    local horizontal = nc_quat_rotate(move_rot, local_move)
    horizontal = Vector3f.new(horizontal.x, 0, horizontal.z)  -- flatten
    if nc_vec_len(horizontal) > 0.00001 then
        horizontal = nc_vec_norm(horizontal)
    end

    local delta_h = Vector3f.new(horizontal.x * speed * dt, 0, horizontal.z * speed * dt)
    local delta_v = Vector3f.new(0, my * vert_speed * dt, 0)
    local delta = Vector3f.new(delta_h.x + delta_v.x, delta_h.y + delta_v.y, delta_h.z + delta_v.z)

    if nc_vec_len(delta) > 0.000001 then
        nc.pos = Vector3f.new(nc.pos.x + delta.x, nc.pos.y + delta.y, nc.pos.z + delta.z)
    end

    -- Apply position
    nc_set_pos(nc.pos)

    -- Sync character rotation to camera yaw (optional)
    if C.noclip_sync_rotation and nc.rot then
        local yaw = nc_quat_yaw(nc.rot) + math.rad(C.noclip_yaw_offset)
        nc_set_rot(nc_quat_from_yaw(yaw))
    end

    -- Suppress fall system
    nc_suppress_fall()

    -- Make player invincible while noclipping
    if C.noclip_anti_death then
        pcall(function()
            local h = php()
            if h then
                h:call("set_Invincible", true)
            end
        end)
    end
end

local function noclip_on()
    if not nc_resolve() then
        toast("NoClip: no player context", 0xFFFF6666)
        return
    end
    nc.pos = nc_get_pos()
    nc.rot = nc_get_camera_rotation() or nil
    nc_last_tick = os.clock()
    C.noclip = true
    toast("NoClip ON", 0xFF44FF88)
end

local function noclip_off()
    C.noclip = false
    nc.active = false
    -- Restore invincibility state
    if not C.god_mode then
        pcall(function()
            local h = php()
            if h then h:call("set_Invincible", false) end
        end)
    end
    toast("NoClip OFF", 0xFFFF6666)
end

-- Also export the camera rotation getter for rendering.lua
local function get_camera_rotation_euler()
    local q = nc_get_camera_rotation()
    if not q then return nil end
    -- Quaternion to Euler (degrees)
    local sinp = 2 * (q.w * q.x + q.y * q.z)
    local cosp = 1 - 2 * (q.x * q.x + q.y * q.y)
    local pitch = math.deg(math.atan(sinp, cosp))
    local siny = 2 * (q.w * q.y - q.z * q.x)
    if math.abs(siny) >= 1 then siny = siny > 0 and 1 or -1 end
    local yaw = math.deg(math.asin(siny))
    local sinr = 2 * (q.w * q.z + q.x * q.y)
    local cosr = 1 - 2 * (q.y * q.y + q.z * q.z)
    local roll = math.deg(math.atan(sinr, cosr))
    return { x = pitch, y = yaw, z = roll }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Exports
-- ═══════════════════════════════════════════════════════════════════════════

T.noclip_tick = noclip_tick
T.noclip_on = noclip_on
T.noclip_off = noclip_off
T.get_camera_rotation_euler = get_camera_rotation_euler
T.nc_state = nc

log.info("[Trainer] NoClip sub-module loaded")
