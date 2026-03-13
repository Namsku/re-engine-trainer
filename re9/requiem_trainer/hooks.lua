-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Hooks Module
-- All SDK hook installations
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R

local function install_hooks()
    if R.hooks_ok then return end

    -- God mode: block damage to player + capture damage numbers
    local hp_td = sdk.find_type_definition("app.HitPoint")
    if hp_td then
        for _, mname in ipairs({"addDamageHitPoint", "invalidateHitPoint", "decreaseMaxHitPoint", "addDamageReactionHP"}) do
            pcall(function()
                local m = hp_td:get_method(mname)
                if not m then return end
                sdk.hook(m,
                    function(args)
                        if not C.god_mode or not R.hp_ref or not args[2] then return sdk.PreHookResult.CALL_ORIGINAL end
                        local i = sdk.to_int64(args[2])
                        local g = sdk.to_int64(R.hp_ref:get_address())
                        if i and g and i == g then return sdk.PreHookResult.SKIP_ORIGINAL end
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end,
                    function(rv) return rv end)
            end)
        end
    end

    -- OHK + Headshot Boost: multiply damage factor
    pcall(function()
        local td = sdk.find_type_definition("app.EnemyAttackDamageDriver")
        if not td then return end
        local m = td:get_method("calcBodyPartsRate")
        if not m then return end
        local shared_info, shared_factor, shared_head = nil, nil, nil
        sdk.hook(m,
            function(args)
                shared_info, shared_factor, shared_head = nil, nil, nil
                if not C.ohk and not C.headshot_boost_on then return end
                pcall(function()
                    local di = sdk.to_managed_object(args[3])
                    if di then
                        local d = di:call("get_Damage")
                        if d and d > 0 then
                            shared_info = di
                            shared_factor = di:call("get_DamageFactor")
                            if C.headshot_boost_on and not C.ohk then
                                local cfg_obj = sdk.to_managed_object(args[4])
                                if cfg_obj then
                                    shared_head = cfg_obj:call("getBodyPartDamageFactor", 1)
                                end
                            end
                        end
                    end
                end)
                return sdk.PreHookResult.CALL_ORIGINAL
            end,
            function(rv)
                pcall(function()
                    if not shared_info or not shared_factor then
                        shared_info, shared_factor, shared_head = nil, nil, nil
                        return
                    end
                    if C.ohk then
                        shared_info:set_field("_DamageFactor", (shared_info:call("get_DamageFactor") or 1) * 9999.0)
                    elseif C.headshot_boost_on and shared_head and shared_head > 0 then
                        local factor_after = shared_info:call("get_DamageFactor")
                        if factor_after and shared_factor ~= 0 then
                            local ratio = factor_after / shared_factor
                            if math.abs(ratio - shared_head) < 0.01 then
                                shared_info:set_field("_DamageFactor", factor_after * C.headshot_mult)
                            end
                        end
                    end
                    shared_info, shared_factor, shared_head = nil, nil, nil
                end)
                return rv
            end)
        log.info("[Trainer] OHK + Headshot Boost hook installed")
    end)

    -- No reload
    pcall(function()
        local td = sdk.find_type_definition("app.PlayerEquipment")
        if not td then return end
        local m = td:get_method("consumeLoading(System.Int32)") or td:get_method("consumeLoading")
        if not m then return end
        sdk.hook(m, function(args)
            if C.no_reload then return sdk.PreHookResult.SKIP_ORIGINAL end
            return sdk.PreHookResult.CALL_ORIGINAL
        end, nil)
        log.info("[Trainer] No reload hook installed")
    end)

    -- Infinite grenades + Infinite injector
    pcall(function()
        local td = sdk.find_type_definition("app.Inventory")
        if not td then return end
        local m1 = td:get_method("consumeStock(app.ItemID, System.Int32, app.ItemStockChangedEventType)")
        local m2 = td:get_method("consumeStock(app.Inventory.PanelKey, System.Int32, app.ItemStockChangedEventType)")
        local hook_fn = function(args)
            if C.inf_grenades then return sdk.PreHookResult.SKIP_ORIGINAL end
            if C.inf_injector then
                local should_skip = false
                pcall(function()
                    local item_id = sdk.to_managed_object(args[3])
                    if item_id then
                        local ok, name = pcall(function()
                            return item_id:call("get_Name()") or item_id:call("ToString()")
                        end)
                        if ok and name == "it99_50_001" then should_skip = true end
                    end
                end)
                if should_skip then return sdk.PreHookResult.SKIP_ORIGINAL end
            end
            return sdk.PreHookResult.CALL_ORIGINAL
        end
        if m1 then sdk.hook(m1, hook_fn, nil) end
        if m2 then sdk.hook(m2, hook_fn, nil) end
        log.info("[Trainer] Grenade + Injector hooks installed")
    end)

    -- No recoil
    pcall(function()
        local classes = {
            {"app.CameraRecoilController", {"addRecoil", "updateRecoil"}},
            {"app.CameraAimShakeController", {"onUpdate"}},
        }
        for _, entry in ipairs(classes) do
            local td = sdk.find_type_definition(entry[1])
            if td then
                for _, meth in ipairs(td:get_methods()) do
                    local mn = meth:get_name()
                    for _, target in ipairs(entry[2]) do
                        if mn and mn:lower():find(target:lower()) then
                            pcall(function()
                                sdk.hook(meth,
                                    function(args) if C.no_recoil then return sdk.PreHookResult.SKIP_ORIGINAL end; return sdk.PreHookResult.CALL_ORIGINAL end,
                                    function(rv) return rv end)
                            end)
                            break
                        end
                    end
                end
            end
        end
    end)

    -- Highlight items
    pcall(function()
        local td = sdk.find_type_definition("app.InteractActionItemPickup")
        if not td then return end
        local m = td:get_method("isInteractable")
        if not m then return end
        sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv)
            if C.highlight then return sdk.to_ptr(1) end
            return rv
        end)
    end)

    -- Auto Parry
    pcall(function()
        local pd_type = sdk.find_type_definition("app.PlayerAttackDamageDriver")
        if not pd_type then return end
        local cp_m = pd_type:get_method("checkParry(app.HitController.DamageInfo)") or pd_type:get_method("checkParry")
        if cp_m then
            sdk.hook(cp_m, function(args)
                if not C.auto_parry then return sdk.PreHookResult.CALL_ORIGINAL end
                pcall(function()
                    local di = sdk.to_managed_object(args[3])
                    if di then
                        pcall(di.call, di, "offFlag(app.HitController.DamageInfo.AttackDamageFlagEnum)", 262144)
                        pcall(di.call, di, "onFlag(app.HitController.DamageInfo.AttackDamageFlagEnum)", 32)
                        pcall(di.call, di, "onFlag(app.HitController.DamageInfo.AttackDamageFlagEnum)", 8192)
                    end
                end)
                return sdk.PreHookResult.CALL_ORIGINAL
            end, function(retval)
                return retval
            end)
        end
        local ops_m = pd_type:get_method("onParrySuccess(app.HitController.DamageInfo)") or pd_type:get_method("onParrySuccess")
        if ops_m then
            sdk.hook(ops_m, function(args)
                R.parry_count = (R.parry_count or 0) + 1
                return sdk.PreHookResult.CALL_ORIGINAL
            end, nil)
        end
    end)

    -- Stealth Mode
    pcall(function()
        local ts_type = sdk.find_type_definition("app.TargetSensor")
        if ts_type then
            for _, name in ipairs({"checkSightSensor", "checkPeripherelSightSensor", "checkHearingSensor", "checkTouchSensor", "checkFlashLightSensor", "checkLightDetection"}) do
                local m = ts_type:get_method(name)
                if m then
                    sdk.hook(m, function(args)
                        if C.stealth then return sdk.PreHookResult.SKIP_ORIGINAL end
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end, function(rv) return rv end)
                end
            end
        end
        local fsc_type = sdk.find_type_definition("app.FindStateController")
        if fsc_type then
            for _, name in ipairs({"onSightTarget", "onAroundSightTarget", "onFlashLightSensed", "OnHearSound", "OnTouchTarget", "requestFind", "find", "forceFindOnSpawn", "beVigilant"}) do
                local m = fsc_type:get_method(name)
                if m then
                    sdk.hook(m, function(args)
                        if C.stealth then return sdk.PreHookResult.SKIP_ORIGINAL end
                        return sdk.PreHookResult.CALL_ORIGINAL
                    end, function(rv) return rv end)
                end
            end
            local update_m = fsc_type:get_method("update")
            if update_m then
                sdk.hook(update_m, function(args)
                    if not C.stealth then return sdk.PreHookResult.CALL_ORIGINAL end
                    pcall(function()
                        local this = sdk.to_managed_object(args[2])
                        if this then
                            pcall(this.set_field, this, "<AttentionGauge>k__BackingField", 0.0)
                            pcall(this.set_field, this, "<State>k__BackingField", 0)
                            pcall(this.set_field, this, "<FindingTimer>k__BackingField", 0.0)
                            pcall(this.set_field, this, "<TargetNormalSightedFrame>k__BackingField", false)
                            pcall(this.set_field, this, "<TargetAroundSightedFrame>k__BackingField", false)
                            pcall(this.set_field, this, "<HeardSoundToBeFoundFrame>k__BackingField", false)
                            pcall(this.set_field, this, "<TouchTargetFrame>k__BackingField", false)
                            pcall(this.set_field, this, "<FlashLightSensedFrame>k__BackingField", false)
                        end
                    end)
                end, function(rv) return rv end)
            end
        end
        local ssd_type = sdk.find_type_definition("app.SensedSoundDetectionManager")
        if ssd_type then
            local m = ssd_type:get_method("requestSoundDetection")
            if m then
                sdk.hook(m, function(args)
                    if C.stealth then return sdk.PreHookResult.SKIP_ORIGINAL end
                    return sdk.PreHookResult.CALL_ORIGINAL
                end, function(rv) return rv end)
            end
        end
    end)

    -- FOV Control
    pcall(function()
        local fov_t = sdk.find_type_definition("app.PlayerCameraFOVCalc")
        if not fov_t then return end
        local getfov_m = fov_t:get_method("getFOV")
        if not getfov_m then return end
        sdk.hook(getfov_m,
            function(args)
                if not C.fov_enabled then return sdk.PreHookResult.CALL_ORIGINAL end
                pcall(function()
                    local this = sdk.to_managed_object(args[2])
                    if this then
                        local ok, fov_id = pcall(this.call, this, "getCameraFOVID")
                        if ok and fov_id then
                            R.fov_mode = fov_id:call("get_Mode") or 0
                            R.fov_type = fov_id:call("get_Type") or 0
                        end
                    end
                end)
                return sdk.PreHookResult.CALL_ORIGINAL
            end,
            function(retval)
                if not C.fov_enabled then return retval end
                local is_fps = (R.fov_mode or 0) == 1
                local is_ads = (R.fov_type or 0) == 1
                local target = 0.0
                if is_fps and is_ads then target = C.fov_fps_ads
                elseif is_fps then target = C.fov_fps_def
                elseif is_ads then target = C.fov_tps_ads
                else target = C.fov_tps_def end
                if target > 0.0 then return sdk.float_to_ptr(target) end
                return retval
            end)
        log.info("[Trainer] FOV hook installed")
    end)

    -- Free Crafting
    pcall(function()
        local gcr_type = sdk.find_type_definition("app.GuiCraftRecipe")
        if gcr_type then
            local craft_hooks = {
                {"get_IsCraftable", 1}, {"get_IsAcquired", 1},
                {"get_CanCharacterCraft", 1}, {"get_FailType", 0},
            }
            for _, entry in ipairs(craft_hooks) do
                local m = gcr_type:get_method(entry[1])
                if m then
                    local force_val = entry[2]
                    sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv)
                        -- Free Craft: override all; Unlock Recipes: only override get_IsAcquired
                        if C.free_craft then return sdk.to_ptr(force_val) end
                        if entry[1] == "get_IsAcquired" and C.unlock_recipes then return sdk.to_ptr(1) end
                        return rv
                    end)
                end
            end
        end
        local mat_type = sdk.find_type_definition("app.GuiCraftRecipeMaterial")
        if mat_type then
            local m = mat_type:get_method("get_IsEnough")
            if m then
                sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv)
                    if C.free_craft then return sdk.to_ptr(1) end
                    return rv
                end)
            end
        end
        local inv_unit = sdk.find_type_definition("app.GuiInventoryController.Unit")
        if inv_unit then
            local m = inv_unit:get_method("get_IsInventoryFull")
            if m then
                sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv)
                    if C.free_craft then return sdk.to_ptr(0) end
                    return rv
                end)
            end
        end
    end)

    -- Super Accuracy
    pcall(function()
        local gun_t = sdk.find_type_definition("app.PlayerGun")
        if not gun_t then return end
        local m = gun_t:get_method("updateReticleFit")
        if not m then return end
        sdk.hook(m, function(args)
            if C.super_accuracy then
                local gun = sdk.to_managed_object(args[2])
                if gun then gun:set_field("_CurrentReticleFitPoint", 100.0) end
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
            return sdk.PreHookResult.CALL_ORIGINAL
        end, function(rv) return rv end)
        log.info("[Trainer] Super Accuracy hook installed")
    end)

    -- Highlight Items & Interactables
    pcall(function()
        local util_t = sdk.find_type_definition("app.InteractUtil")
        if util_t then
            local m = util_t:get_method("isIconPositionInDistance")
            if m then sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.highlight_items then return sdk.to_ptr(1) end; return rv end) end
        end
        local key_t = sdk.find_type_definition("app.InteractTriggerKeyInput")
        if key_t then
            local m = key_t:get_method("isDrawIconDisplay")
            if m then sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.highlight_items then return sdk.to_ptr(1) end; return rv end) end
        end
        local screen_t = sdk.find_type_definition("app.InteractTriggerInScreen")
        if screen_t then
            local m = screen_t:get_method("isInnerScreen")
            if m then sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.highlight_items then return sdk.to_ptr(1) end; return rv end) end
        end
        log.info("[Trainer] Highlight Items hooks installed")
    end)

    -- Unlock All Crafting Recipes (merged into Free Craft hooks above for get_IsAcquired)
    pcall(function()
        local im_t = sdk.find_type_definition("app.ItemManager")
        if im_t then
            local m = im_t:get_method("isSealCraftRecipe")
            if m then sdk.hook(m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.unlock_recipes then return sdk.to_ptr(0) end; return rv end) end
            local m2 = im_t:get_method("isOpenedCraftRecipeSection")
            if m2 then sdk.hook(m2, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.unlock_recipes then return sdk.to_ptr(1) end; return rv end) end
        end
        log.info("[Trainer] Unlock Recipes hooks installed")
    end)

    -- Unlimited Saves
    pcall(function()
        local beh_t = sdk.find_type_definition("app.SaveServiceManagerBehaviorApp")
        if not beh_t then return end
        local add_m = beh_t:get_method("addManualSaveCount")
        if add_m then sdk.hook(add_m, function(args) if C.unlimited_saves then return sdk.PreHookResult.SKIP_ORIGINAL end; return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) return rv end) end
        local sub_m = beh_t:get_method("subManualSaveCount")
        if sub_m then sdk.hook(sub_m, function(args) if C.unlimited_saves then return sdk.PreHookResult.SKIP_ORIGINAL end; return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) return rv end) end
        local get_m = beh_t:get_method("get_ManualSaveCount")
        if get_m then sdk.hook(get_m, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(rv) if C.unlimited_saves then return sdk.to_ptr(0) end; return rv end) end
        log.info("[Trainer] Unlimited Saves hooks installed")
    end)

    -- Show All Items on Map
    pcall(function()
        local map_type = sdk.find_type_definition("app.structure.MapIconStatus")
        if not map_type then return end
        local method = map_type:get_method("get_IsDiscovered")
        if not method then return end
        sdk.hook(method, function(args) return sdk.PreHookResult.CALL_ORIGINAL end, function(retval)
            if C.map_reveal then return sdk.to_ptr(1) end
            return retval
        end)
        log.info("[Trainer] Map Reveal hook installed")
    end)

    -- No Sway (camera shake suppression)
    pcall(function()
        local cs_type = sdk.find_type_definition("app.CameraSystem")
        if not cs_type then return end
        for _, mname in ipairs({"addCameraShakeRequest", "clearCameraShakeForce"}) do
            local m = cs_type:get_method(mname)
            if m then
                sdk.hook(m, function(args)
                    if C.no_sway or C.no_recoil then return sdk.PreHookResult.SKIP_ORIGINAL end
                    return sdk.PreHookResult.CALL_ORIGINAL
                end, function(rv) return rv end)
            end
        end
        log.info("[Trainer] No Sway hooks installed")
    end)

    R.hooks_ok = true
    log.info("[Trainer] All hooks installed")
end

-- Export
T.install_hooks = install_hooks

log.info("[Trainer] Hooks module loaded")
