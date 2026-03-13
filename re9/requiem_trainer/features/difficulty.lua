-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Difficulty Sub-Module
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast = T.mgr, T.toast
local DIFFICULTY_IDS = {"ID0010", "ID0020", "ID0030", "ID0040"}
local DIFFICULTY_NAMES = {
    ID0010 = "Casual", ID0020 = "Modern", ID0030 = "Classic", ID0040 = "Insanity",
}

local _diff_state = {
    current = nil,  -- string key like "ID0030"
    rows = {},      -- {key, name, value}
    scanned = false,
}

local function difficulty_scan()
    _diff_state.rows = {}
    pcall(function()
        local td = sdk.find_type_definition("app.GameDifficultyID")
        if not td then return end
        for _, key in ipairs(DIFFICULTY_IDS) do
            pcall(function()
                local f = td:get_field(key)
                if f and f:is_static() then
                    local v = f:get_data(nil)
                    _diff_state.rows[#_diff_state.rows + 1] = {
                        key = key,
                        name = DIFFICULTY_NAMES[key] or key,
                        value = v,
                    }
                end
            end)
        end
    end)
    -- Read current difficulty via GameDifficultyManager (correct singleton)
    pcall(function()
        local diff_mgr = mgr("app.GameDifficultyManager")
        if not diff_mgr then return end
        local diff = nil
        pcall(function() diff = diff_mgr:call("get_DifficultyID()") end)
        if not diff then pcall(function() diff = diff_mgr:call("get_DifficultyID") end) end
        if not diff then pcall(function() diff = diff_mgr:get_field("_DifficultyID") end) end
        if diff then
            local ok2, s = pcall(function() return tostring(diff:call("ToString()") or diff) end)
            if ok2 and s then _diff_state.current = s end
        end
    end)
    _diff_state.scanned = true
end

local function difficulty_apply(row)
    if not row or not row.key then toast("Invalid difficulty", 0xFFFF6666); return end
    local ok = false
    local enum_val = nil
    pcall(function()
        local td = sdk.find_type_definition("app.GameDifficultyID")
        if not td then return end
        local f = td:get_field(row.key)
        if not f then return end
        enum_val = f:get_data(nil)
    end)
    if enum_val == nil then toast("Could not resolve difficulty enum", 0xFFFF6666); return end

    -- Use app.GameDifficultyManager (correct singleton)
    pcall(function()
        local diff_mgr = mgr("app.GameDifficultyManager")
        if not diff_mgr then toast("GameDifficultyManager not found — load a save first", 0xFFFF6666); return end
        -- Try direct setter (primary approach)
        pcall(function() diff_mgr:call("set_DifficultyID(app.GameDifficultyID)", enum_val); ok = true end)
        if not ok then pcall(function() diff_mgr:call("set_DifficultyID", enum_val); ok = true end) end
        -- Try overwrite method (fallback)
        if not ok then pcall(function() diff_mgr:call("setOverwriteDifficultyData(app.GameDifficultyID)", enum_val); ok = true end) end
        if not ok then pcall(function() diff_mgr:call("setOverwriteDifficultyData", enum_val); ok = true end) end
        -- Last resort: direct field write
        if not ok then
            pcall(function()
                local bf = diff_mgr:get_type_definition():get_field("_DifficultyID")
                if bf then
                    local off = bf:get_offset_from_base()
                    if off and off > 0 then
                        diff_mgr:write_dword(off, enum_val)
                        ok = true
                    end
                end
            end)
        end
    end)
    if ok then
        _diff_state.current = row.key
        toast("Difficulty → " .. row.name, 0xFF44DDFF)
    else
        toast("Difficulty change failed — no compatible API found", 0xFFFF6666)
    end
end

pcall(difficulty_scan)

-- Exports
T._diff_state = _diff_state
T.difficulty_scan = difficulty_scan
T.difficulty_apply = difficulty_apply

log.info("[Trainer] Difficulty sub-module loaded")
