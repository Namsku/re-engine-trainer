--[[
    re9_offsets.lua — Centralized Offset Registry for RE9
    EMV Engine Module (Phase 1)

    All hardcoded byte offsets (0x10, 0x18, etc.) from the original EMV Engine
    are replaced with named lookups through this registry.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
]]

local RE9_OFFSETS = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- Offset Table
-- ═══════════════════════════════════════════════════════════════════════════

RE9_OFFSETS.offsets = {
    -- GameObject / Component chain
    gameobject_base      = 0x10,   -- Component → owning GameObject
    component_next       = 0x18,   -- Component → next component in chain (RE8 was 0x10)
    retype_super         = 0x10,   -- RE type → super (parent type) pointer

    -- Resource holder
    resource_ptr         = 0x10,   -- ResourceHolder → resource pointer

    -- Transform
    transform_joint_base = 0x80,   -- Transform → joints array base
    transform_joint_stride = 0x50, -- Per-joint stride

    -- Character / Player
    player_hitpoint      = 0x58,   -- BaseActor → HitPoint component
    player_inventory     = 0x68,   -- BaseActor → Inventory component

    -- Camera
    camera_fov           = 0x44,   -- Camera → FOV field

    -- Motion
    motion_fsm_offset    = 0x30,   -- Motion → MotionFsm2 reference
}

-- ═══════════════════════════════════════════════════════════════════════════
-- Safe Accessor
-- ═══════════════════════════════════════════════════════════════════════════

--- Retrieve an offset by name. Returns 0x0 if not found (safe fallback).
--- @param name string   Offset name (e.g. "gameobject_base")
--- @return number       Offset value, or 0x0 on failure
function RE9_OFFSETS.get(name)
    local val = RE9_OFFSETS.offsets[name]
    if val == nil then
        if log then
            log.warn("[EMV] RE9_OFFSETS: unknown offset '" .. tostring(name) .. "', returning 0x0")
        end
        return 0x0
    end
    return val
end

--- Dump all offsets to the log (debug helper).
function RE9_OFFSETS.dump()
    if not log then return end
    log.info("[EMV] RE9 Offset Registry:")
    for name, val in pairs(RE9_OFFSETS.offsets) do
        log.info(("  %-28s = 0x%X"):format(name, val))
    end
end

return RE9_OFFSETS
