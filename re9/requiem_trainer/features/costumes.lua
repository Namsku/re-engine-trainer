-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Costumes Sub-Module
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast = T.mgr, T.toast
local COSTUME_NAMES = {
    Grace = {
        bo99_00_100 = "Default", bo99_00_101 = "Jacket", bo99_00_102 = "FBI",
        bo99_00_103 = "Noir", bo99_00_104 = "Apocalypse", bo99_00_105 = "Dimitrescu",
        bo99_00_106 = "Default",
    },
    Leon = {
        bo99_00_000 = "Default", bo99_00_001 = "Jacket", bo99_00_002 = "R.P.D.",
        bo99_00_003 = "Film Noir", bo99_00_004 = "Apocalypse", bo99_00_005 = "RE4",
        bo99_00_006 = "Default",
    },
}

local _costume_state = {
    players = {},   -- {leon = {label, costumes, selected, current_name, special_ctx, updater}, grace = ...}
    status = "Not scanned yet",
    last_scan = 0,
}

local function costume_display_name(label, raw)
    local m = COSTUME_NAMES[label]
    return (m and m[raw]) or raw or "Unknown"
end

local function costume_scan_players()
    local result = {leon = nil, grace = nil}
    pcall(function()
        local cm = mgr("app.CharacterManager")
        if not cm then _costume_state.status = "CharacterManager not found"; return end

        -- Get player contexts
        local contexts = {}
        pcall(function()
            local fast = cm:call("get_PlayerContextFast") or cm:get_field("<PlayerContextFast>k__BackingField")
            if fast then contexts[#contexts + 1] = fast end
        end)
        pcall(function()
            local plist = cm:get_field("<PlayerContextList>k__BackingField")
            if plist then
                local count = plist:call("get_Count") or 0
                for i = 0, count - 1 do
                    pcall(function() contexts[#contexts + 1] = plist:call("get_Item", i) end)
                end
            end
        end)

        for _, ctx in ipairs(contexts) do
            pcall(function()
                local updater = ctx:get_field("<Updater>k__BackingField")
                    or ctx:get_field("<CharacterUpdaterBase>k__BackingField")
                if not updater then return end
                local tname = updater:get_type_definition():get_full_name() or ""
                local label = tname:find("A000") and "Leon" or (tname:find("A100") and "Grace" or nil)
                if not label then return end
                local key = label:lower()
                if result[key] then return end

                -- Get costumes from updater configuration
                local costumes = {}
                pcall(function()
                    local cfg = updater:get_field("<Configuration>k__BackingField")
                    local cc = cfg and cfg:get_field("_PlayerCostumeConfiguration")
                    local cs = cc and cc:get_field("_CostumeSetting")
                    local arr = cs and cs:get_field("_DataArray")
                    if not arr then return end
                    local elems = arr:get_elements()
                    if elems then
                        for _, d in ipairs(elems) do
                            pcall(function()
                                local raw = tostring(d:get_field("_BonusIDName") or "?")
                                costumes[#costumes + 1] = {
                                    name = raw,
                                    display = costume_display_name(label, raw),
                                    data = d,
                                    bonus_id = d:call("get_BonusID"),
                                }
                            end)
                        end
                    end
                end)

                -- Get current costume
                local current = "Unknown"
                pcall(function()
                    local cur = updater:get_field("<CurrentCostumeSetting>k__BackingField")
                    if cur then current = tostring(cur:get_field("_BonusIDName") or "Unknown") end
                end)

                -- Find selected index
                local sel = 1
                for i, c in ipairs(costumes) do
                    if c.name == current then sel = i; break end
                end

                result[key] = {
                    label = label, updater = updater, costumes = costumes,
                    selected = sel, current_name = current,
                }
            end)
        end

        -- Also get BonusManager special contexts for costume IDs
        pcall(function()
            local bm = mgr("app.BonusManager")
            if not bm then return end
            local dict = bm:get_field("_SpecialConfigContextDic")
            if not dict then return end
            local entries = dict:get_field("_entries")
            local count = dict:get_field("_count") or 0
            if not entries or count <= 0 then return end
            for i = 0, count - 1 do
                pcall(function()
                    local e = entries:get_element(i)
                    if not e or (e.hashCode and e.hashCode < 0) then return end
                    local ctx_val = e.value
                    if not ctx_val then return end
                    local actual = ctx_val:get_field("_Value") or ctx_val
                    -- Store for apply
                    for _, key in ipairs({"leon", "grace"}) do
                        if result[key] then result[key].special_ctx = actual end
                    end
                end)
            end
        end)
    end)
    _costume_state.players = result
    _costume_state.last_scan = os.clock()
    local leon_c = result.leon and #result.leon.costumes or 0
    local grace_c = result.grace and #result.grace.costumes or 0
    _costume_state.status = string.format("Leon: %d costumes / Grace: %d costumes", leon_c, grace_c)
end

local function costume_apply(player_info)
    if not player_info then toast("Player not available", 0xFFFF6666); return end
    local entry = player_info.costumes[player_info.selected]
    if not entry then toast("No costume selected", 0xFFFF6666); return end
    local ok = false

    -- Safe set_field helper matching reference trainer: validate field exists first
    local function safe_set_field(obj, name, val)
        if not obj then return false end
        local td = obj:get_type_definition()
        if td and td:get_field(name) then
            local s = pcall(obj.set_field, obj, name, val)
            return s
        end
        return false
    end

    -- Apply via updater
    if player_info.updater and entry.data then
        local updater = player_info.updater
        -- Try direct field write (safe — won't error if field doesn't exist)
        if safe_set_field(updater, "_CurrentCostumeSetting_k__BackingField", entry.data) then
            ok = true
        end
        -- Try setter methods (these are what actually apply the costume)
        pcall(function()
            updater:call("set_CurrentCostumeSetting(app.PlayerCostumeSettingUserData.Data)", entry.data)
            ok = true
        end)
        if not ok then
            pcall(function()
                updater:call("set_CurrentCostumeSetting", entry.data)
                ok = true
            end)
        end
    end
    -- Apply via special context
    if entry.bonus_id and player_info.special_ctx then
        pcall(function()
            player_info.special_ctx:call("setSelectedID(app.BonusID)", entry.bonus_id)
            ok = true
        end)
        if not ok then
            pcall(function()
                player_info.special_ctx:call("setSelectedID", entry.bonus_id)
                ok = true
            end)
        end
    end
    if ok then
        player_info.current_name = entry.name
        -- Refresh GUI (reference trainer approach: just pcall it)
        pcall(function()
            local gm = mgr("app.GuiManager")
            if gm then gm:call("updatePlayerInfo") end
        end)
        toast(player_info.label .. " → " .. entry.display .. " (load a save to see)", 0xFF44FF88)
    else
        toast("Costume change failed", 0xFFFF6666)
    end
end

-- Exports
T._costume_state = _costume_state
T.costume_scan_players = costume_scan_players
T.costume_apply = costume_apply
T.costume_display_name = costume_display_name
T.COSTUME_NAMES = COSTUME_NAMES

log.info("[Trainer] Costumes sub-module loaded")
