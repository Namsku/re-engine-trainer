-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Features Module
-- God mode, arsenal, speed, enemies, saves, items, etc.
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast, php, pctx, ppos, pxf, hp_vals = T.mgr, T.toast, T.php, T.pctx, T.ppos, T.pxf, T.hp_vals
local get_scene = T.get_scene
local scan_enemies, get_kind_name = T.scan_enemies, T.get_kind_name
local cfg_save, cfg_flush = T.cfg_save, T.cfg_flush
local dist3 = T.dist3

-- ═══════════════════════════════════════════════════════════════════════════
-- God Mode
-- ═══════════════════════════════════════════════════════════════════════════

local function god_on()
    local h = php()
    if not h then return end
    R.hp_ref = h
    -- Set all invincibility flags (competitor approach)
    pcall(h.call, h, "set_Invincible", true)
    pcall(h.call, h, "set_NoDamage", true)
    pcall(h.call, h, "set_NoDeath", true)
    pcall(h.call, h, "setNoDieCharacter", true)
    -- Restore HP to max
    pcall(function()
        local c = h:call("get_CurrentHitPoint")
        local m = h:call("get_CurrentMaximumHitPoint")
        if c and m and m > 0 and c < m then
            local ok = pcall(h.call, h, "resetHitPoint", m)
            if not ok then
                -- Fallback: use recovery
                local delta = m - c
                if delta > 0 then
                    pcall(h.call, h, "recovery", delta, 0)
                end
            end
        end
    end)
end

local function god_off()
    local h = R.hp_ref or php()
    if not h then return end
    pcall(h.call, h, "set_Invincible", false)
    pcall(h.call, h, "set_NoDamage", false)
    pcall(h.call, h, "set_NoDeath", false)
    pcall(h.call, h, "setNoDieCharacter", false)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player Speed (motion layer + MovementDriver hook)
-- ═══════════════════════════════════════════════════════════════════════════

local _motion_type = sdk.typeof("via.motion.Motion")  -- cached at load time

local function get_player_layer()
    local ctx = pctx()
    if not ctx then return nil end
    local go = ctx:call("get_GameObject")
    if not go then return nil end
    local mot = _motion_type and go:call("getComponent(System.Type)", _motion_type)
    if not mot then return nil end
    return mot:call("getLayer", 0)
end

local function get_motion_type()
    local layer = get_player_layer()
    if not layer then return nil end
    local node = layer:call("get_HighestWeightMotionNode")
    if not node then return nil end
    local name = node:call("get_MotionName")
    if not name then return nil end
    local lower = name:lower()
    if lower:find("attack") or lower:find("finish") or lower:find("execution") then return nil end
    if lower:find("walk") then return "walk" end
    if lower:find("run")  then return "run"  end
    return nil
end


local function set_layer_speed(spd)
    local layer = get_player_layer()
    if layer then pcall(layer.call, layer, "set_Speed", spd) end
end

local function reset_speed()
    R.speed_factor = 1.0
    R.speed_reset_frames = 10
    set_layer_speed(1.0)
end

-- Hook MovementDriver.getMoveSpeed to multiply actual movement velocity
pcall(function()
    local td = sdk.find_type_definition("app.MovementDriver")
    local m = td and td:get_method("getMoveSpeed")
    if m then
        sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(ret)
            if not C.player_speed_on or R.speed_factor == 1.0 then return ret end
            local v = sdk.to_float(ret)
            return v and sdk.float_to_ptr(v * R.speed_factor) or ret
        end)
        log.info("[Trainer] MovementDriver.getMoveSpeed hook installed")
    else
        log.warn("[Trainer] Could not find app.MovementDriver:getMoveSpeed")
    end
end)

-- LateUpdateBehavior: set speed every frame based on current motion
re.on_pre_application_entry("LateUpdateBehavior", function()
    -- Gravity Gun tick (must run regardless of player speed state)
    if T.GravityGun then pcall(T.GravityGun.update) end

    if not C.player_speed_on then
        if R.speed_factor ~= 1.0 then reset_speed() end
        if R.speed_reset_frames > 0 then
            set_layer_speed(1.0)
            R.speed_reset_frames = R.speed_reset_frames - 1
        end
        return
    end
    local ok, move_type = pcall(get_motion_type)
    if not ok then return end
    if move_type then
        local spd = (move_type == "walk") and C.walk_speed or C.run_speed
        R.speed_factor = spd
        set_layer_speed(spd)
    else
        reset_speed()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Arsenal (Infinite Ammo / Melee)
-- ═══════════════════════════════════════════════════════════════════════════

local function arsenal_tick()
    local im = mgr("app.ItemManager")
    if not im then return end
    if C.inf_ammo then
        pcall(function() im:set_field("_InfinityGun", true) end)
        pcall(function() im:set_field("_InfinityRocketLauncher", true) end)
    end
    if C.inf_melee or C.inf_durability then
        pcall(function() im:set_field("_InfinityAxe", true) end)
        pcall(function() im:set_field("_InfinityAxeHandle", true) end)
    end
end

local function arsenal_off()
    local im = mgr("app.ItemManager")
    if not im then return end
    pcall(function() im:set_field("_InfinityGun", false) end)
    pcall(function() im:set_field("_InfinityRocketLauncher", false) end)
    pcall(function() im:set_field("_InfinityAxe", false) end)
    pcall(function() im:set_field("_InfinityAxeHandle", false) end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy Control
-- ═══════════════════════════════════════════════════════════════════════════

local function kill_all()
    local targets = #R.enemies > 0 and R.enemies or scan_enemies()
    local n = 0
    for _, e in ipairs(targets) do
        pcall(function()
            local h = e.ctx:call("get_HitPoint")
            if h and h:call("get_IsEnable") then h:call("set_CurrentHitPoint", 0); n = n + 1 end
        end)
    end
    log.info(("[Trainer] Killed %d"):format(n))
end

local function freeze_enemies()
    for _, e in ipairs(R.enemies) do
        pcall(function()
            local go = e.ctx:call("get_GameObject")
            if go then
                local mot = go:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion"))
                if mot then
                    local l = mot:call("getLayer", 0)
                    if l then l:call("set_Speed", C.motion_freeze and 0.0 or 1.0) end
                end
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Position / Bookmark
-- ═══════════════════════════════════════════════════════════════════════════

local function pos_freeze()
    if not C.freeze_x and not C.freeze_y and not C.freeze_z then return end
    local xf = pxf()
    if not xf then return end
    local cur = ppos()
    if not cur then return end
    if not R.frozen_pos then R.frozen_pos = cur; return end
    local nx = C.freeze_x and R.frozen_pos.x or cur.x
    local ny = C.freeze_y and R.frozen_pos.y or cur.y
    local nz = C.freeze_z and R.frozen_pos.z or cur.z
    if not C.freeze_x then R.frozen_pos.x = cur.x end
    if not C.freeze_y then R.frozen_pos.y = cur.y end
    if not C.freeze_z then R.frozen_pos.z = cur.z end
    pcall(function() xf:call("set_Position", Vector3f.new(nx, ny, nz)) end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Game Speed
-- ═══════════════════════════════════════════════════════════════════════════

local _gs_set = nil
pcall(function()
    local td = sdk.find_type_definition("via.Application")
    if td then _gs_set = td:get_method("set_GlobalSpeed") end
end)

local function game_speed_tick()
    if not _gs_set then return end
    if C.game_speed_on then
        pcall(_gs_set.call, _gs_set, nil, C.game_speed)
    else
        pcall(_gs_set.call, _gs_set, nil, 1.0)
    end
end

local function game_speed_revert() end

-- ═══════════════════════════════════════════════════════════════════════════
-- Auto-Skip Cutscenes
-- ═══════════════════════════════════════════════════════════════════════════

local function skip_cutscene()
    -- Always probe cutscene state so the UI can show live status
    local playing, skippable = false, false
    pcall(function()
        local m = mgr("app.TimelineEventMediator")
        if not m then return end
        playing   = m:call("get_IsPlayingCutScene") or false
        skippable = m:call("get_IsSkippable") or false
        if C.skip_cutscenes and playing and skippable then
            m:call("skip", m)
            R.skip_count = (R.skip_count or 0) + 1
            toast("Cutscene skipped (" .. R.skip_count .. ")", 0xFFFFCC44)
        end
    end)
    R.cutscene_playing   = playing
    R.cutscene_skippable = skippable
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Save Slots
-- ═══════════════════════════════════════════════════════════════════════════

local SaveTypes = {}

local function init_save()
    if SaveTypes.ready then return true end
    pcall(function()
        SaveTypes.idx_td = sdk.find_type_definition("app.SaveSlotIndex")
        SaveTypes.null_td = sdk.find_type_definition("System.Nullable`1<app.SavedataSaveRequestArgs>")
        SaveTypes.load_null_td = sdk.find_type_definition("System.Nullable`1<app.SavedataLoadRequestArgs>")
        local svc_td = sdk.find_type_definition("app.SaveServiceManager")
        if svc_td then
            SaveTypes.req_save = svc_td:get_method("requestSave(app.SaveSlotIndex, System.Nullable`1<app.SavedataSaveRequestArgs>)")
            local methods = svc_td:get_methods()
            if methods then
                for _, m in ipairs(methods) do
                    local mname = m:get_name()
                    if mname and mname:lower():find("load") then end
                end
            end
            local load_candidates = {
                "requestLoad(app.SaveSlotIndex, System.Nullable`1<app.SavedataLoadRequestArgs>)",
                "requestLoad(app.SaveSlotIndex)",
                "loadSavedata(System.Int32, System.Int32)",
                "loadSavedata(app.SaveSlotCategory, System.Int32)",
            }
            for _, sig in ipairs(load_candidates) do
                local m = svc_td:get_method(sig)
                if m then
                    local np = m:get_num_params()
                    SaveTypes.req_load = m
                    SaveTypes.load_src = "SSM." .. sig
                    SaveTypes.load_param_count = np
                    break
                end
            end
            if not SaveTypes.req_load then
                local m = svc_td:get_method("requestLoad")
                if m then
                    local np = m:get_num_params()
                    SaveTypes.req_load = m
                    SaveTypes.load_src = "SSM.requestLoad"
                    SaveTypes.load_param_count = np
                end
            end
        end
        if not SaveTypes.req_load then
            local flow_td = sdk.find_type_definition("app.SaveLoadFlowManager")
            if flow_td then
                local fc = {
                    "requestLoad(app.SaveSlotIndex)",
                    "load(app.SaveSlotIndex)",
                    "loadSavedata(System.Int32, System.Int32)",
                }
                for _, sig in ipairs(fc) do
                    local m = flow_td:get_method(sig)
                    if m then
                        local np = m:get_num_params()
                        SaveTypes.req_load = m
                        SaveTypes.load_src = "SLFM." .. sig
                        SaveTypes.load_param_count = np
                        break
                    end
                end
                if not SaveTypes.req_load then
                    for _, name in ipairs({"requestLoad", "load", "loadSavedata"}) do
                        local m = flow_td:get_method(name)
                        if m then
                            local np = m:get_num_params()
                            SaveTypes.req_load = m
                            SaveTypes.load_src = "SLFM." .. name
                            SaveTypes.load_param_count = np
                            break
                        end
                    end
                end
            end
        end
        if SaveTypes.load_src then
            local np = SaveTypes.load_param_count or "?"
            R.load_method = SaveTypes.load_src .. " [params=" .. tostring(np) .. "]"
        end
    end)
    SaveTypes.ready = SaveTypes.idx_td ~= nil
    return SaveTypes.ready
end

local function refresh_saves()
    if not init_save() then R.save_slots = {}; return end
    local svc = mgr("app.SaveServiceManager")
    if not svc then R.save_slots = {}; return end
    local slots = {}
    local make_method = nil
    pcall(function()
        local model_td = sdk.find_type_definition("app.GuiSaveLoadModel")
        if model_td then
            make_method = model_td:get_method("makeSaveData(app.SaveSlotCategory, System.Int32)")
                or model_td:get_method("makeSaveData")
        end
    end)
    pcall(function()
        local dets = svc:enumerateSaveSlotDetails()
        if not dets then return end
        local cnt = dets:call("get_Count")
        if not cnt or cnt <= 0 then return end
        for i = 0, cnt - 1 do
            pcall(function()
                local d = dets:call("get_Item", i)
                if not d then return end
                local cat = tonumber(d:get_SlotCategory())
                local off = tonumber(d:get_SlotOffset())
                local save_date = ""
                pcall(function()
                    local md = sdk.to_valuetype(d:get_Metadata(), "app.SaveSlotMetadata")
                    if md then save_date = tostring(md._Detail or "") end
                end)
                local difficulty, objective, datetime, ng_plus, auto_sv = "?", "", save_date, nil, nil
                if make_method then
                    pcall(function()
                        local sd = make_method:call(nil, cat, off)
                        if not sd then return end
                        pcall(function()
                            local dm = sd:get_DifficultyMessage()
                            if dm then difficulty = tostring(dm:get_Message() or "?") end
                        end)
                        pcall(function()
                            local om = sd:get_ObjectiveMessage()
                            if om then objective = tostring(om:get_Message() or "") end
                        end)
                        pcall(function()
                            local dt = sd:get_DataTime()
                            if dt then datetime = tostring(dt:ToString() or save_date) end
                        end)
                        pcall(function() ng_plus = sd:get_IsNewGamePlus() end)
                        pcall(function() auto_sv = sd:get_IsAutoSave() end)
                    end)
                end
                slots[#slots + 1] = {
                    cat = cat, off = off,
                    difficulty = difficulty, objective = objective,
                    datetime = datetime, ng_plus = ng_plus, auto_save = auto_sv,
                }
            end)
        end
    end)
    R.save_slots = slots
    R.save_time = os.date("%H:%M:%S")
end

local function do_save(cat, off)
    if not SaveTypes.req_save or not SaveTypes.idx_td then return false end
    local svc = mgr("app.SaveServiceManager")
    if not svc then return false end
    local ok, busy = pcall(svc.get_IsBusy, svc)
    if ok and busy then return false end
    local idx = ValueType.new(SaveTypes.idx_td)
    idx._Category = cat
    idx._SlotOffset = off
    local null = ValueType.new(SaveTypes.null_td)
    pcall(SaveTypes.req_save.call, SaveTypes.req_save, svc, idx, null)
    return true
end

local function do_load(cat, off)
    if not SaveTypes.req_load then return false end
    if not SaveTypes.idx_td then return false end
    local target = nil
    local src = SaveTypes.load_src or ""
    if src:find("^SSM") then
        target = mgr("app.SaveServiceManager")
    elseif src:find("^SLFM") then
        target = mgr("app.SaveLoadFlowManager")
    else
        target = mgr("app.SaveServiceManager") or mgr("app.SaveLoadFlowManager")
    end
    if not target then return false end
    pcall(function()
        local busy = target:call("get_IsBusy")
        if busy then log.info("[Trainer] Save service busy, waiting...") end
    end)
    local idx = ValueType.new(SaveTypes.idx_td)
    idx._Category = cat
    idx._SlotOffset = off
    local np = SaveTypes.load_param_count or 1
    local ok, err
    if np >= 2 and SaveTypes.load_null_td then
        local null_arg = ValueType.new(SaveTypes.load_null_td)
        ok, err = pcall(SaveTypes.req_load.call, SaveTypes.req_load, target, idx, null_arg)
    else
        ok, err = pcall(SaveTypes.req_load.call, SaveTypes.req_load, target, idx)
    end
    if ok then
        log.info("[Trainer] Load triggered via " .. tostring(src) .. " (cat=" .. cat .. ", off=" .. off .. ")")
        -- Thaaaef approach: after load, request scene jump to actually reload
        R._load_pending = { cat = cat, frame = (R.tick or 0) + 30 }
        return true
    else
        log.warn("[Trainer] Load call failed: " .. tostring(err))
        return false
    end
end

-- Scene jump after load (called from frame loop)
local function load_scene_jump_tick()
    if not R._load_pending then return end
    if (R.tick or 0) < R._load_pending.frame then return end
    local cat = R._load_pending.cat
    R._load_pending = nil
    pcall(function()
        local stm = mgr("app.SceneTransitionManager")
        if not stm then
            log.warn("[Trainer] SceneTransitionManager not found for scene jump")
            return
        end
        -- Try requestMainGameJump with SaveSlotCategory
        local stm_td = sdk.find_type_definition("app.SceneTransitionManager")
        if not stm_td then return end
        local jump_m = stm_td:get_method("requestMainGameJump(app.SaveSlotCategory)")
            or stm_td:get_method("requestMainGameJump(System.Boolean)")
            or stm_td:get_method("requestMainGameJump")
        if jump_m then
            log.info("[Trainer] Triggering scene jump via " .. tostring(jump_m:get_name()))
            pcall(jump_m.call, jump_m, stm, cat)
        else
            log.warn("[Trainer] No requestMainGameJump method found")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Scan
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_items()
    local items = {}
    local im = mgr("app.ItemManager")
    if not im then return items end
    pcall(function()
        local db = im:get_field("_ContextDB")
        if not db then return end
        local cnt = db:call("get_Count")
        if not cnt or cnt <= 0 then return end
        local entries = db:call("get_Entries")
        if not entries then return end
        for i = 0, cnt - 1 do
            pcall(function()
                local e = entries[i]
                if not e then return end
                local v = e.value
                if not v then return end
                local item = {id = i, name = "Item", count = 0, max = 99, ctx = v}
                pcall(function() item.id = tonumber(v:call("get_ItemId")) or i end)
                pcall(function() item.name = tostring(v:call("get_Name") or ("Item_" .. item.id)) end)
                pcall(function() item.count = tonumber(v:call("get_Stack")) or tonumber(v:call("get_Num")) or 0 end)
                pcall(function() item.max = tonumber(v:call("get_MaxStack")) or tonumber(v:call("get_StackMax")) or 99 end)
                items[#items + 1] = item
            end)
        end
    end)
    if #items == 0 then
        pcall(function()
            local list = im:call("get_ItemList")
            if not list then return end
            local cnt = list:call("get_Count")
            if not cnt or cnt <= 0 then return end
            for i = 0, cnt - 1 do
                pcall(function()
                    local v = list:call("get_Item", i)
                    if not v then return end
                    local item = {id = i, name = "Item", count = 0, max = 99, ctx = v}
                    pcall(function() item.id = tonumber(v:call("get_ItemId")) or i end)
                    pcall(function() item.name = tostring(v:call("get_Name") or ("Item_" .. item.id)) end)
                    pcall(function() item.count = tonumber(v:call("get_Stack")) or tonumber(v:call("get_Num")) or 0 end)
                    pcall(function() item.max = tonumber(v:call("get_MaxStack")) or tonumber(v:call("get_StackMax")) or 99 end)
                    items[#items + 1] = item
                end)
            end
        end)
    end
    return items
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Speedrunner / Overlay helpers
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_area_name()
    pcall(function()
        local make_td = sdk.find_type_definition("app.GuiSaveLoadModel")
        if not make_td then return end
        local make_m = make_td:get_method("makeSaveData(app.SaveSlotCategory, System.Int32)")
        if not make_m then return end
        local sd = make_m:call(nil, 0, 0)
        if not sd then return end
        pcall(function()
            local am = sd:get_AreaMessageID()
            if am then
                local msg_td = sdk.find_type_definition("app.MessageManager")
                if msg_td then
                    local get_msg = msg_td:get_method("getMessage(System.Guid)")
                    if get_msg then
                        local msg_mgr = mgr("app.MessageManager")
                        if msg_mgr then
                            local text = get_msg:call(msg_mgr, am)
                            if text and text ~= "" then R.area_name = text; return end
                        end
                    end
                end
            end
        end)
        pcall(function()
            local om = sd:get_ObjectiveMessage()
            if om then
                local msg = om:get_Message()
                if msg and msg ~= "" then R.area_name = msg end
            end
        end)
    end)
end

local function scan_igt()
    pcall(function()
        local clock = mgr("app.GameClock")
        if not clock then return end
        local timers = clock:get_field("_Timers")
        if not timers then return end
        local timer = timers:get_element(0)
        if not timer then return end
        local ticks = timer:get_field("_ElapsedTime")
        if not ticks or ticks <= 0 then return end
        local total_sec = ticks / 1000000
        local h = math.floor(total_sec / 3600)
        local m = math.floor((total_sec % 3600) / 60)
        local s = math.floor(total_sec % 60)
        R.igt_text = string.format("%02d:%02d:%02d", h, m, s)
    end)
end

local function track_death_position()
    if not C.death_warp then return end
    pcall(function()
        local ctx = pctx()
        if not ctx then return end
        local dead = ctx:call("get_IsDead")
        if dead then
            local pos = ppos()
            if pos then R.death_pos = { x = pos.x, y = pos.y, z = pos.z } end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Remote Storage
-- ═══════════════════════════════════════════════════════════════════════════

local remote_storage_latch = false

local function toggle_remote_storage()
    pcall(function()
        local gm = mgr("app.GuiManager")
        if not gm then toast("GuiManager not found", 0xFFFF6666); return end
        local item_box = gm:call("get_ItemBox")
        if not item_box then toast("Item Box not ready", 0xFFFF6666); return end
        if item_box:get_Active() then
            item_box:close()
        else
            local setting_td = sdk.find_type_definition("app.GuiItemBoxOpenSetting")
            if not setting_td then return end
            local setting = setting_td:create_instance()
            if setting then item_box:call("open(app.GuiItemBoxOpenSetting)", setting) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Hotkeys
-- ═══════════════════════════════════════════════════════════════════════════

local function hotkeys()
    if not R.hk_prev then R.hk_prev = {} end
    local function is_down(vk)
        if not vk or vk == 0 then return false end
        local ok, d = pcall(function() return reframework:is_key_down(vk) end)
        return ok and d
    end
    local function just_pressed(vk)
        if not vk or vk == 0 then return false end
        local down = is_down(vk)
        local was = R.hk_prev[vk] or false
        R.hk_prev[vk] = down
        return down and not was
    end
    if T.hk_listening then return end
    if just_pressed(0x42) then
        local p = ppos()
        if p then R.bookmark = p; toast("Bookmark Set", 0xFF44FF88) end
    end
    if just_pressed(0x4E) and R.bookmark then
        pcall(function()
            local xf = pxf()
            if xf then xf:call("set_Position", Vector3f.new(R.bookmark.x, R.bookmark.y, R.bookmark.z)) end
        end)
        toast("Warped to Bookmark", 0xFF88DDFF)
    end
    local function hk_toggle(cfg_key, feature_key, off_fn, display_name)
        local vk = C[cfg_key]
        if just_pressed(vk) then
            C[feature_key] = not C[feature_key]
            if not C[feature_key] and off_fn then pcall(off_fn) end
            pcall(cfg_save)
            local name = display_name or feature_key
            local state = C[feature_key] and "ON" or "OFF"
            toast(name .. " " .. state, C[feature_key] and 0xFF44FF88 or 0xFFFF6666)
        end
    end
    if just_pressed(C.hk_god) then
        C.god_mode = not C.god_mode
        C.stealth = C.god_mode
        if not C.god_mode then pcall(god_off) end
        pcall(cfg_save)
        toast("God Mode " .. (C.god_mode and "ON" or "OFF"), C.god_mode and 0xFF44FF88 or 0xFFFF6666)
    end
    hk_toggle("hk_speed",     "player_speed_on", reset_speed,       "Player Speed")
    hk_toggle("hk_overlay",   "enemy_panel",     nil,               "Enemy Overlay")
    hk_toggle("hk_freeze",    "motion_freeze",   freeze_enemies,    "Enemy Freeze")
    hk_toggle("hk_gamespeed", "game_speed_on",   game_speed_revert, "Game Speed")
    hk_toggle("hk_skip",      "skip_cutscenes",  nil,               "Auto-Skip Cutscenes")
    -- Per-slot hotkeys (checked BEFORE Quick Save/Load to avoid conflicts)
    local slot_handled = {}  -- track VKs consumed by per-slot bindings
    if C.slot_bindings then
        for key, bind in pairs(C.slot_bindings) do
            pcall(function()
                local cat, off = key:match("(%d+)_(%d+)")
                cat = tonumber(cat); off = tonumber(off)
                if not cat or not off then return end
                if bind.save and bind.save > 0 and just_pressed(bind.save) then
                    slot_handled[bind.save] = true
                    local ok = false
                    pcall(function() if init_save() then ok = do_save(cat, off) end end)
                    if ok then toast("Saved slot " .. off, 0xFF44BB44)
                    else toast("Save slot " .. off .. " failed", 0xFFFF6666) end
                end
                if bind.load and bind.load > 0 and just_pressed(bind.load) then
                    slot_handled[bind.load] = true
                    local ok = false
                    pcall(function() if init_save() then ok = do_load(cat, off) end end)
                    if ok then toast("Loading slot " .. off .. "...", 0xFF4488DD)
                    else toast("Load slot " .. off .. " failed", 0xFFFF6666) end
                end
            end)
        end
    end
    -- Quick Save/Load (skip if already handled by per-slot binding)
    if not slot_handled[C.hk_save] and just_pressed(C.hk_save) then
        local off = C.quick_save_slot or 0
        local save_ok = false
        pcall(function() if init_save() then save_ok = do_save(3, off) end end)
        if save_ok then toast("\xF0\x9F\x92\xBE Quick Saved (slot " .. off .. ")", 0xFF44BB44)
        else toast("Save failed - try from pause menu", 0xFFFF6666) end
    end
    if not slot_handled[C.hk_load] and just_pressed(C.hk_load) then
        local off = C.quick_load_slot or 0
        local load_ok = false
        pcall(function() if init_save() then load_ok = do_load(3, off) end end)
        if load_ok then toast("\xF0\x9F\x94\x84 Loading slot " .. off .. "...", 0xFF4488DD)
        else toast("Load failed", 0xFFFF6666) end
    end
end

-- NoClip system moved to features/noclip.lua
-- Chapter system moved to features/chapters.lua
-- ═══════════════════════════════════════════════════════════════════════════
-- Playtime Modifier
-- ═══════════════════════════════════════════════════════════════════════════

-- RE Engine uses 10M ticks per second (100-nanosecond intervals)
local TICKS_PER_SECOND = 10000000

local function seconds_to_ticks(s) return math.floor(s * TICKS_PER_SECOND) end
local function ticks_to_seconds(t) return (t or 0) / TICKS_PER_SECOND end

local function format_time(total_secs)
    total_secs = math.max(0, math.floor(total_secs))
    local h = math.floor(total_secs / 3600)
    local m = math.floor((total_secs % 3600) / 60)
    local s = total_secs % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function get_game_timers()
    local results = {}
    pcall(function()
        local gc = mgr("app.GameClock")
        if not gc then return end
        local timer_list = gc:get_field("_TimerList")
        if not timer_list then return end
        local count = timer_list:call("get_Count")
        if not count or count <= 0 then return end
        for i = 0, count - 1 do
            pcall(function()
                local timer = timer_list:call("get_Item", i)
                if timer then
                    local et = timer:get_field("_ElapsedTime") or 0
                    results[#results + 1] = {
                        index = i,
                        timer = timer,
                        elapsed_ticks = et,
                        elapsed_secs  = ticks_to_seconds(et),
                        name = (i == 0 and "Main" or i == 1 and "Play" or i == 2 and "Total"
                                or "Timer" .. i),
                    }
                end
            end)
        end
    end)
    return results
end

local function apply_playtime()
    local total_secs = C.playtime_hours * 3600 + C.playtime_minutes * 60 + C.playtime_seconds
    local ticks = seconds_to_ticks(total_secs)
    local timers = get_game_timers()
    for _, t in ipairs(timers) do
        if t.index <= 2 then
            pcall(function() t.timer:set_field("_ElapsedTime", ticks) end)
        else
            pcall(function() t.timer:set_field("_ElapsedTime", 0) end)
        end
    end
    -- Also set SubGame1Manager clear time
    pcall(function()
        local sgm = mgr("app.SubGame1Manager")
        if sgm then
            pcall(function() sgm:set_field("_ClearMinutes", C.playtime_hours * 60 + C.playtime_minutes) end)
            pcall(function() sgm:set_field("_ClearSeconds", C.playtime_seconds) end)
            for _, fn in ipairs({"_BestTotalTime", "<BestTotalTime>k__BackingField"}) do
                pcall(function() sgm:set_field(fn, ticks) end)
            end
        end
    end)
    toast(string.format("Playtime set to %s", format_time(total_secs)), 0xFF44DDFF)
end

local function freeze_playtime_tick()
    if not C.playtime_freeze then return end
    local total_secs = C.playtime_hours * 3600 + C.playtime_minutes * 60 + C.playtime_seconds
    local ticks = seconds_to_ticks(total_secs)
    pcall(function()
        local gc = mgr("app.GameClock")
        if not gc then return end
        local timer_list = gc:get_field("_TimerList")
        if not timer_list then return end
        local count = timer_list:call("get_Count")
        if not count or count <= 0 then return end
        for i = 0, math.min(count - 1, 2) do
            pcall(function()
                local timer = timer_list:call("get_Item", i)
                if timer then timer:set_field("_ElapsedTime", ticks) end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Credit / CP Modifier
-- ═══════════════════════════════════════════════════════════════════════════

local function apply_cp()
    local done = false
    pcall(function()
        local am = mgr("app.AchievementManager")
        if am then
            local ok = pcall(function() am:set_field("_TotalClearPoint", C.cp_value) end)
            if ok then done = true; log.info("[Trainer] CP set via AchievementManager") end
        end
    end)
    if not done then
        for _, mn in ipairs({"app.RecordManager", "app.BonusManager", "app.GameDataManager"}) do
            pcall(function()
                local m = mgr(mn)
                if m then
                    for _, fn in ipairs({"_TotalClearPoint", "_ClearPoint", "_ReceivedClearPoint"}) do
                        local ok = pcall(function() m:set_field(fn, C.cp_value) end)
                        if ok then done = true; return end
                    end
                end
            end)
            if done then break end
        end
    end
    if done then toast(string.format("CP set to %d", C.cp_value), 0xFF88FF44)
    else toast("CP update failed", 0xFFFF6666) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Challenges Unlocker (via AchievementManager synergy list)
-- ═══════════════════════════════════════════════════════════════════════════

local function get_synergy_list()
    local list, count = nil, 0
    pcall(function()
        local am = mgr("app.AchievementManager")
        if not am then return end
        -- Reference uses _ContextViewList (not _SynergyList)
        local sl = am:get_field("_ContextViewList")
        if not sl then
            -- Fallback to get_size array
            sl = am:get_field("_SynergyList")
        end
        if not sl then return end
        local c = 0
        pcall(function() c = sl:get_size() end)
        if c <= 0 then pcall(function() c = sl:call("get_Count") end) end
        if c > 0 then list = sl; count = c end
    end)
    return list, count
end

local function get_challenge_element(list, i)
    -- _ContextViewList uses get_element, _SynergyList uses get_Item
    local e = nil
    pcall(function() e = list:get_element(i) end)
    if not e then pcall(function() e = list:call("get_Item", i) end) end
    return e
end

local function get_challenges_info()
    local info = {total = 0, done = 0, active = 0, entries = {}}
    local sl, sc = get_synergy_list()
    if not sl or sc <= 0 then return info end
    info.total = sc
    for i = 0, sc - 1 do
        pcall(function()
            local e = get_challenge_element(sl, i)
            if not e then return end
            local completed = false
            pcall(function() completed = e:get_field("_Completed") or false end)
            local progress = 0
            pcall(function() progress = e:get_field("_ProgressCount") or 0 end)
            local name = "Challenge " .. i
            pcall(function()
                local data = e:get_field("_Data")
                if data then
                    local bonus_id = data:get_field("_BonusID")
                    local s = bonus_id and bonus_id:call("ToString") or nil
                    if s and s ~= "" then name = tostring(s) end
                end
            end)
            -- Fallback name discovery
            if name == "Challenge " .. i then
                pcall(function()
                    local id = e:get_field("_SynergyID")
                    if id then
                        local s = id:call("ToString()")
                        if s and s ~= "" then name = tostring(s) end
                    end
                end)
            end
            if completed then info.done = info.done + 1
            elseif progress > 0 then info.active = info.active + 1 end
            info.entries[#info.entries + 1] = {
                index = i, name = name, completed = completed, progress = progress, element = e,
            }
        end)
    end
    return info
end

local function challenge_system_save()
    pcall(function()
        local am = mgr("app.AchievementManager")
        if not am then return end
        -- Try primary save method, then fallback
        local ok = pcall(function() am:call("requestSystemSave") end)
        if not ok then
            pcall(function() am:call("executeAchievementSystemSave") end)
        end
    end)
end

local function unlock_challenges(mode, target_index)
    -- mode: 1 = complete all, 2 = reset all, 3 = toggle individual
    local sl, sc = get_synergy_list()
    if not sl or sc <= 0 then toast("No challenges found", 0xFFFF6666); return end
    local count = 0
    for i = 0, sc - 1 do
        pcall(function()
            local e = get_challenge_element(sl, i)
            if not e then return end
            if mode == 3 and i ~= target_index then return end
            if mode == 1 then
                -- Unlock: set both progress and completed (reference approach)
                pcall(function() e:set_field("_ProgressCount", 1) end)
                pcall(function() e:set_field("_Completed", true) end)
                count = count + 1
            elseif mode == 2 then
                -- Reset: clear both
                pcall(function() e:set_field("_ProgressCount", 0) end)
                pcall(function() e:set_field("_Completed", false) end)
                count = count + 1
            elseif mode == 3 then
                -- Toggle individual
                local is_done = e:get_field("_Completed")
                pcall(function() e:set_field("_ProgressCount", is_done and 0 or 1) end)
                pcall(function() e:set_field("_Completed", not is_done) end)
                count = count + 1
            end
        end)
    end
    -- Persist changes via system save
    challenge_system_save()
    if mode == 1 then toast(string.format("Completed %d challenges", count), 0xFF44FF88)
    elseif mode == 2 then toast(string.format("Reset %d challenges", count), 0xFFFF8844)
    else toast("Challenge toggled", 0xFF44DDFF) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Camera Pan / Offset
-- ═══════════════════════════════════════════════════════════════════════════

local _cam_state = {
    native_offset = nil,   -- {x, y, z} original game values
    active_param  = nil,   -- current TPSCameraPositionCalc _Param object
    hooks_installed = false,
}

local function cam_register_param(param)
    if not param then return end
    local ok = pcall(function() return param:get_type_definition() end)
    if not ok then return end
    local offset = param:get_field("_Offset")
    if not offset then return end
    -- Only capture native offset once per param
    if not _cam_state.native_offset or _cam_state.active_param ~= param then
        _cam_state.native_offset = {x = offset.x, y = offset.y, z = offset.z}
    end
    _cam_state.active_param = param
end

local function cam_apply()
    if not _cam_state.active_param or not _cam_state.native_offset then return end
    pcall(function()
        local ok = pcall(function() return _cam_state.active_param:get_type_definition() end)
        if not ok then _cam_state.active_param = nil; return end
        local offset = _cam_state.active_param:get_field("_Offset")
        if not offset then return end
        local nat = _cam_state.native_offset
        if C.camera_pan_enabled then
            offset.x = nat.x + C.camera_pan_x
            offset.y = nat.y + C.camera_pan_y
            offset.z = nat.z + C.camera_offset_z
        else
            offset.x = nat.x
            offset.y = nat.y
            offset.z = nat.z
        end
        _cam_state.active_param:set_field("_Offset", offset)
    end)
end

local function cam_reset()
    C.camera_pan_x = 0.0
    C.camera_pan_y = 0.0
    C.camera_offset_z = 0.0
    cam_apply()
end

local function install_camera_hooks()
    if _cam_state.hooks_installed then return end
    local calc_type = sdk.find_type_definition("app.TPSCameraPositionCalc")
    if not calc_type then return end
    local hooked = {}
    for _, method in ipairs(calc_type:get_methods()) do
        local name = method:get_name()
        local low = name and name:lower() or ""
        if not hooked[name] and (low == "setup" or low == "update" or low == "lateupdate"
            or low:find("calc", 1, true) or low:find("execute", 1, true)) then
            pcall(function()
                sdk.hook(method, function(args)
                    pcall(function()
                        local this = sdk.to_managed_object(args[2])
                        if this then
                            local param = this:get_field("_Param")
                            if param then cam_register_param(param) end
                        end
                    end)
                end, function(retval)
                    cam_apply()
                    return retval
                end)
                hooked[name] = true
            end)
        end
    end
    _cam_state.hooks_installed = true
    log.info("[Trainer] Camera pan/offset hooks installed")
end

pcall(install_camera_hooks)

-- ═══════════════════════════════════════════════════════════════════════════
-- Item Spawner
-- ═══════════════════════════════════════════════════════════════════════════

local _itemdb = {
    items = {},       -- {id, name, caption, category, base_cap, id_text, can_add}
    categories = {"All"},
    cat_map = {},
    built = false,
    search = "",
    sel_cat = "All",
    last_check = 0,
}

-- Build item catalog (lazy — retries until ItemManager is available)
local function _itemdb_try_build()
    if _itemdb.built then return true end
    local now = os.clock()
    if now - _itemdb.last_check < 2 then return false end
    _itemdb.last_check = now
    local ok = pcall(function()
        local ItemID_td = sdk.find_type_definition("app.ItemID")
        local ItemCat_td = sdk.find_type_definition("app.ItemCategory")
        local msg_td = sdk.find_type_definition("via.gui.message")
        local msg_get = msg_td and msg_td:get_method("get")
        local im = mgr("app.ItemManager")
        if not ItemID_td or not im then error("not ready") end
        -- Verify ItemCatalog is accessible
        local cat = im:get_field("_ItemCatalog")
        if not cat then error("no catalog") end

        -- Build category map (only once)
        if #_itemdb.categories <= 1 and ItemCat_td then
            for _, f in ipairs(ItemCat_td:get_fields()) do
                if f:is_static() and f:get_type() == ItemCat_td then
                    local v = f:get_data(nil)
                    _itemdb.cat_map[v] = f:get_name()
                    _itemdb.categories[#_itemdb.categories + 1] = f:get_name()
                end
            end
        end

        -- Scan all ItemID fields
        for _, f in ipairs(ItemID_td:get_fields()) do
            if f:is_static() and f:get_type() == ItemID_td then
                pcall(function()
                    local id = f:get_data(nil)
                    -- Get item name from catalog
                    local det = cat:call("getValue", id, nil)
                    if not det then return end
                    local nm = ""
                    if msg_get then
                        local raw = msg_get:call(nil, det._NameMessageId)
                        if raw then nm = tostring(raw):gsub("<[^>]+>", "") end
                    end
                    if nm == "" then nm = f:get_name() end
                    -- Skip rejected/invalid items
                    if nm:sub(1, 1) == "#" then return end
                    local cap = ""
                    pcall(function()
                        if msg_get then
                            local raw = msg_get:call(nil, det._CaptionMessageId)
                            if raw then cap = tostring(raw):gsub("<[^>]+>", "") end
                        end
                    end)
                    local base_cap = 1
                    pcall(function() base_cap = det._SlotCapacityData._BaseCapacity end)
                    _itemdb.items[#_itemdb.items + 1] = {
                        id = id,
                        name = nm,
                        caption = cap,
                        category = _itemdb.cat_map[det._ItemCategory] or "Other",
                        base_cap = base_cap or 1,
                        id_text = f:get_name(),
                        can_add = true,
                    }
                end)
            end
        end
        if #_itemdb.items > 0 then
            _itemdb.built = true
            log.info(("[Trainer] Item catalog: %d items loaded"):format(#_itemdb.items))
        else
            error("no items found")
        end
    end)
    return ok
end

-- Try initial build (will silently fail if game not loaded yet)
_itemdb_try_build()

local _ie_getInv = nil
local _ie_AcqOpt = nil
local _ie_StockEvt = nil
pcall(function()
    _ie_getInv = sdk.find_type_definition("app.GuiUtil"):get_method("getInventory")
    _ie_AcqOpt = sdk.find_type_definition("app.Inventory.AcquireItemOptions"):get_field("Default"):get_data(nil)
    _ie_StockEvt = sdk.find_type_definition("app.ItemStockChangedEventType"):get_field("Default"):get_data(nil)
end)

local function item_spawn_add(item, count)
    pcall(function()
        local inv = _ie_getInv:call(nil)
        if not inv then toast("Inventory not found", 0xFFFF6666); return end
        local d = nil
        if item.base_cap > 1 then
            d = sdk.create_instance("app.ItemStockData"):add_ref()
            d:call(".ctor(app.ItemID, System.Int32)", item.id, count or item.base_cap)
        else
            local lt_td = sdk.find_type_definition("app.ItemLoadingType")
            local lt_a = lt_td and lt_td:get_field("TypeA"):get_data(nil)
            d = sdk.create_instance("app.LoadableItemData"):add_ref()
            d:call(".ctor(app.ItemID, System.Int32, app.ItemLoadingType)", item.id, 1000, lt_a)
        end
        if d then
            inv:call("mergeOrAdd(app.ItemAmountData, System.Boolean, app.Inventory.AcquireItemOptions, app.ItemStockChangedEventType)",
                d, true, _ie_AcqOpt, _ie_StockEvt)
            toast("Added: " .. item.name, 0xFF44FF88)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Perspective Switcher (1P ↔ 3P)
-- ═══════════════════════════════════════════════════════════════════════════

local function get_current_view_mode()
    -- Returns the perspective state (0=TPS, 1=FPS) using SwitchPlayerViewChecker
    local mode = nil
    pcall(function()
        local cm = mgr("app.CharacterManager")
        if not cm then return end
        local checker = cm:get_field("<SwitchPlayerViewChecker>k__BackingField")
        if not checker then return end
        -- Try Leon first (_cp_A000PersonType), then Grace (_cp_A100PersonType)
        mode = checker:get_field("_cp_A000PersonType")
        if mode == nil then
            mode = checker:get_field("_cp_A100PersonType")
        end
    end)
    return mode
end

local function toggle_perspective()
    -- Based on reference trainer: toggle _cp_A000PersonType on SwitchPlayerViewChecker
    local toggled = false
    pcall(function()
        local cm = mgr("app.CharacterManager")
        if not cm then return end
        local checker = cm:get_field("<SwitchPlayerViewChecker>k__BackingField")
        if not checker then return end
        -- Toggle Leon perspective
        local leon_mode = checker:get_field("_cp_A000PersonType")
        if leon_mode ~= nil then
            checker:set_field("_cp_A000PersonType", leon_mode == 1 and 0 or 1)
            toggled = true
        end
        -- Also toggle Grace perspective
        local grace_mode = checker:get_field("_cp_A100PersonType")
        if grace_mode ~= nil then
            checker:set_field("_cp_A100PersonType", grace_mode == 1 and 0 or 1)
        end
    end)
    if toggled then
        toast("Perspective toggled", 0xFF44DDFF)
    else
        toast("Could not toggle perspective", 0xFFFF6666)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Costumes moved to features/costumes.lua
-- Difficulty moved to features/difficulty.lua

T.god_off = god_off
T.reset_speed = reset_speed
T.arsenal_tick = arsenal_tick
T.arsenal_off = arsenal_off
T.kill_all = kill_all
T.freeze_enemies = freeze_enemies
T.pos_freeze = pos_freeze
T.game_speed_tick = game_speed_tick
T.game_speed_revert = game_speed_revert
T.skip_cutscene = skip_cutscene
T.init_save = init_save
T.refresh_saves = refresh_saves
T.do_save = do_save
T.do_load = do_load
T.load_scene_jump_tick = load_scene_jump_tick
T.scan_items = scan_items
T.scan_area_name = scan_area_name
T.scan_igt = scan_igt
T.track_death_position = track_death_position
T.remote_storage_latch = remote_storage_latch
T.toggle_remote_storage = toggle_remote_storage
T.hotkeys = hotkeys
T.SaveTypes = SaveTypes
-- noclip exports moved to features/noclip.lua
-- chapter exports moved to features/chapters.lua
-- Phase 3: Competitor gap features
T.get_game_timers = get_game_timers
T.apply_playtime = apply_playtime
T.freeze_playtime_tick = freeze_playtime_tick
T.format_time = format_time
T.ticks_to_seconds = ticks_to_seconds
T.apply_cp = apply_cp
T.get_challenges_info = get_challenges_info
T.unlock_challenges = unlock_challenges
T.cam_apply = cam_apply
T.cam_reset = cam_reset
T._cam_state = _cam_state
-- Phase 2: Complex features
T._itemdb = _itemdb
T.item_spawn_add = item_spawn_add
T.itemdb_try_build = _itemdb_try_build
T.toggle_perspective = toggle_perspective
T.get_current_view_mode = get_current_view_mode
-- costume exports moved to features/costumes.lua
-- difficulty exports moved to features/difficulty.lua

-- Item Indicator moved to features/item_indicator.lua


log.info("[Trainer] Features core module loaded")

