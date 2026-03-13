--[[
    method_inspector.lua — Hooked Method Inspector
    EMV Engine Module

    Inspired by alphaZomega's HookedMethodInspector.
    Hook any SDK method by typing its signature, capture args and return values,
    see which RE Engine module triggered the call, re-invoke methods, and inject
    pre/post hook code.
]]

local MethodInspector = {}
local ControlPanel

function MethodInspector.setup(deps)
    ControlPanel = deps.ControlPanel
end

-- ═══════════════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════════════

local tics = 0
local hook_method_text = ""
local already_hooked = {}
local hooked_methods = {}  -- name -> method_tbl
local prev_hooks = {}      -- list of previously hooked method names
local prev_hook_idx = 1

-- ═══════════════════════════════════════════════════════════════════════════
-- RE Engine module timing detection (subset of important modules)
-- ═══════════════════════════════════════════════════════════════════════════

local module_names = {
    "Update", "UpdateScene", "UpdateHID", "UpdateMotionFrame",
    "UpdateBehavior", "UpdateBehaviorTree", "UpdateFSM", "UpdateMotion",
    "UpdateTimeline", "UpdatePhysicsCharacterController", "UpdateDynamics",
    "UpdateNavigation", "UpdateGUI", "UpdateSound", "UpdateEffect",
    "UpdatePuppet", "LateUpdateBehavior", "BeginRendering", "EndRendering",
    "BeginPhysics", "EndPhysics", "BeginDynamics", "EndDynamics",
    "LockScene", "UnlockScene", "PrepareRendering", "WaitRendering",
    "PreupdateBehavior", "PreupdateBehaviorTree", "PreupdateFSM",
    "PreupdateTimeline", "UpdateNetwork",
}

local timings = {}
local timings_installed = false

local function setup_module_timings()
    if timings_installed then return end
    timings_installed = true
    for i, module_name in ipairs(module_names) do
        timings[i] = { name = module_name }
        pcall(function()
            re.on_pre_application_entry(module_name, function()
                timings[i].entry_time = os.clock()
                timings[i].frame = tics
            end)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Argument conversion (adapted from alphaZomega's HookedMethodInspector)
-- ═══════════════════════════════════════════════════════════════════════════

local function convert_ptr(arg, td_name)
    local output
    local is_float = td_name and (td_name == "System.Single")
    if not pcall(function()
        local mobj = sdk.to_managed_object(arg)
        output = (mobj and mobj:add_ref()) or (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
    end) then
        output = (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
    end
    if td_name and not is_float and tonumber(output) then
        pcall(function()
            local vt = sdk.to_valuetype(output, td_name)
            if vt and vt.mValue ~= nil then
                output = vt.mValue
            else
                output = vt and (((vt["ToString"] and vt:call("ToString()")) or vt) or vt) or output
            end
        end)
    end
    return output
end

local function get_args(args, param_valuetypes)
    local result = {}
    local mobj_idx
    for i, arg in ipairs(args) do
        result[i] = convert_ptr(arg, mobj_idx and param_valuetypes[i - mobj_idx])
        mobj_idx = mobj_idx or (param_valuetypes and type(result[i]) == "userdata" and i)
    end
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Method signature parser
-- ═══════════════════════════════════════════════════════════════════════════

local function parse_method_text(text)
    if not text or text == "" then return nil end
    -- Support formats:
    --   "app.ItemManager:getItem(System.Int32)"
    --   "app.ItemManager.getItem(System.Int32)"
    --   "via.Transform:set_Parent(via.Transform)"

    local type_name, method_name

    -- Try TypeName:MethodName or TypeName.MethodName
    type_name, method_name = text:match("^([%w%.]+)[:%.]([%w_]+%b())")
    if not type_name then
        type_name, method_name = text:match("^([%w%.]+)[:%.]([%w_]+)")
    end
    if not type_name or not method_name then return nil end

    local td = sdk.find_type_definition(type_name)
    if not td then return nil, "Type not found: " .. type_name end

    local method = td:get_method(method_name)
    if not method then return nil, "Method not found: " .. method_name .. " on " .. type_name end

    return method, type_name .. "." .. method_name
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Frame update: match hooked call timings to RE Engine modules
-- (Lazy — only installed when first method is hooked)
-- ═══════════════════════════════════════════════════════════════════════════

local frame_callback_installed = false

local function install_frame_callback()
    if frame_callback_installed then return end
    frame_callback_installed = true
    re.on_frame(function()
        pcall(function()
            tics = tics + 1
            for _, method_tbl in pairs(hooked_methods) do
                if method_tbl.timing then
                    for i, timing_tbl in ipairs(timings) do
                        if timing_tbl.entry_time and timing_tbl.frame == method_tbl.frame
                           and timing_tbl.entry_time >= method_tbl.timing then
                            local mod_tbl = method_tbl.module_tables[i - 1] or {
                                name = timings[i - 1] and timings[i - 1].name or "Unknown",
                                calls = 0,
                            }
                            method_tbl.module_tables[i - 1] = mod_tbl
                            mod_tbl.calls = mod_tbl.calls + 1
                            mod_tbl.timing = method_tbl.timing
                            if method_tbl.enabled then
                                mod_tbl.args = method_tbl.args
                                mod_tbl.retval = method_tbl.retval
                            end
                            if not method_tbl.pause_most_recent then
                                method_tbl.most_recent_module = mod_tbl
                            end
                            break
                        end
                    end
                end
            end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Hook a method
-- ═══════════════════════════════════════════════════════════════════════════

local function hook_method(method, display_name)
    if already_hooked[method] then return "Already hooked" end
    already_hooked[method] = true

    setup_module_timings()
    install_frame_callback()

    local ret_type = method:get_return_type()
    local tbl = {
        method = method,
        name = display_name,
        call_count = 0,
        enabled = true,
        frame = 0,
        timing = nil,
        args = nil,
        retval = nil,
        module_tables = {},
        most_recent_module = nil,
        param_names = {},
        param_typenames = {},
        param_valuetypes = {},
        my_typename = method:get_declaring_type():get_full_name(),
        is_static = method:is_static(),
        retval_typename = nil,
        retval_vtypename = nil,
        by_first_call = false,
        pause_most_recent = false,
        pre_code = "",
        post_code = "",
        use_pre_code = false,
        use_post_code = false,
        error_txt_pre = nil,
        error_txt_post = nil,
    }

    -- Param info
    pcall(function()
        local param_types = method:get_param_types()
        tbl.param_names = method:get_param_names() or {}
        if param_types then
            for i, pt in ipairs(param_types) do
                local td_name = pt:get_full_name()
                tbl.param_typenames[i] = td_name
                tbl.param_valuetypes[i] = pt:is_value_type() and not pt:is_a("System.Enum")
                    and not td_name:find("System.U?Int") and td_name or nil
            end
        end
    end)

    -- Return type
    pcall(function()
        if ret_type and not ret_type:is_a("System.Void") then
            tbl.retval_typename = ret_type:get_full_name()
            tbl.retval_vtypename = ret_type:is_value_type() and not ret_type:is_a("System.Enum")
                and not tbl.retval_typename:find("System.U?Int") and tbl.retval_typename or nil
        end
    end)

    -- Install hook
    sdk.hook(method,
        function(args)
            tbl.call_count = tbl.call_count + 1
            -- Pre-hook code
            if tbl.use_pre_code and tbl.pre_code ~= "" then
                local ok, out = pcall(load(tbl.pre_code))
                tbl.error_txt_pre = not ok and out or nil
                if ok and out == 1 then
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end
            end
            if not (tbl.by_first_call and tbl.frame == tics) then
                tbl.frame = tics
                tbl.timing = os.clock()
                if tbl.enabled then
                    tbl.raw_args = args
                    tbl.args = get_args(args, tbl.param_valuetypes)
                end
            end
        end,
        function(retval)
            -- Post-hook code
            if tbl.use_post_code and tbl.post_code ~= "" then
                _G.retval = retval
                local ok, out = pcall(load(tbl.post_code))
                _G.retval = nil
                tbl.error_txt_post = not ok and ("Error: " .. tostring(out)) or nil
                if ok and out ~= nil then retval = out end
            end
            if tbl.enabled and not (tbl.by_first_call and tbl.frame == tics) then
                tbl.retval = convert_ptr(retval, tbl.retval_vtypename)
            end
            return retval
        end
    )

    hooked_methods[display_name] = tbl
    -- Add to prev hooks if not already there
    local found = false
    for _, ph in ipairs(prev_hooks) do
        if ph == display_name then found = true; break end
    end
    if not found then
        prev_hooks[#prev_hooks + 1] = display_name
        table.sort(prev_hooks)
    end

    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Render a single arg value (recursive inspector for managed objects)
-- ═══════════════════════════════════════════════════════════════════════════

local function render_arg_value(value, label, uid)
    if value == nil then
        imgui.text_colored((label or "") .. " = nil", 0xFF888888)
    elseif type(value) == "boolean" then
        imgui.text((label or "") .. " = " .. tostring(value))
    elseif type(value) == "number" then
        imgui.text((label or "") .. " = " .. tostring(value))
    elseif type(value) == "string" then
        imgui.text((label or "") .. " = \"" .. value .. "\"")
    elseif type(value) == "userdata" then
        if ControlPanel and ControlPanel.managed_object_control_panel then
            if sdk.is_managed_object(value) then
                if imgui.tree_node((label or "obj") .. "##arg_" .. (uid or "")) then
                    pcall(ControlPanel.managed_object_control_panel, value, "arg_" .. (uid or ""))
                    imgui.tree_pop()
                end
            else
                -- Value type (Vector3f, Quaternion, etc.)
                local desc = tostring(value)
                pcall(function()
                    if value.x ~= nil then
                        if value.w ~= nil then
                            desc = string.format("(%.3f, %.3f, %.3f, %.3f)", value.x, value.y, value.z, value.w)
                        elseif value.z ~= nil then
                            desc = string.format("(%.3f, %.3f, %.3f)", value.x, value.y, value.z)
                        else
                            desc = string.format("(%.3f, %.3f)", value.x, value.y)
                        end
                    end
                end)
                imgui.text((label or "") .. " = " .. desc)
            end
        else
            local desc = tostring(value)
            pcall(function() desc = "[0x" .. string.format("%X", value:get_address()) .. "]" end)
            imgui.text((label or "") .. " = " .. desc)
        end
    else
        imgui.text((label or "") .. " = " .. tostring(value))
    end
end


-- ═══════════════════════════════════════════════════════════════════════════
-- ImGui UI
-- ═══════════════════════════════════════════════════════════════════════════

local hook_error = nil

function MethodInspector.render()
    -- Method input
    local submitted = imgui.button("Hook Method##mi_hook")
    imgui.same_line()
    imgui.push_item_width(500)
    local tc, nt = imgui.input_text("##mi_method", hook_method_text, 512)
    if tc then hook_method_text = nt end
    imgui.pop_item_width()

    imgui.text_colored("Format: TypeName:MethodName(ParamType) or TypeName.MethodName", 0xFF888888)

    -- Previous hooks combo
    if #prev_hooks > 0 then
        local cc, ci = imgui.combo("Previous##mi_prev", prev_hook_idx, prev_hooks)
        if cc then
            prev_hook_idx = ci
            hook_method_text = prev_hooks[ci] or hook_method_text
        end
    end

    if hook_error then
        imgui.text_colored(hook_error, 0xFF4444FF)
    end

    -- Submit hook
    if submitted and hook_method_text ~= "" then
        hook_error = nil
        local method, name_or_err = parse_method_text(hook_method_text)
        if method then
            local err = hook_method(method, name_or_err)
            if err then hook_error = err end
        else
            hook_error = name_or_err or "Failed to parse method"
        end
    end

    imgui.separator()
    imgui.spacing()

    -- Hooked methods list
    local sorted_names = {}
    for name in pairs(hooked_methods) do sorted_names[#sorted_names + 1] = name end
    table.sort(sorted_names)

    for _, name in ipairs(sorted_names) do
        local tbl = hooked_methods[name]
        local header = name .. (tbl.is_static and " [STATIC]" or "")
            .. " (" .. tbl.call_count .. " calls)"

        if imgui.tree_node(header .. "##mi_" .. name) then
            -- Controls
            local ec, ev = imgui.checkbox("Collect Args##mi_en_" .. name, tbl.enabled)
            if ec then tbl.enabled = ev end

            imgui.same_line()
            if imgui.button("Clear##mi_clr_" .. name) then
                tbl.call_count = 0
                tbl.timing = nil
                tbl.module_tables = {}
                tbl.most_recent_module = nil
                tbl.args = nil
                tbl.retval = nil
            end

            local fc, fv = imgui.checkbox("First call only##mi_fc_" .. name, tbl.by_first_call)
            if fc then tbl.by_first_call = fv end

            -- Timing info
            if tbl.timing then
                imgui.text("Last called: " .. string.format("%.4f", tbl.timing)
                    .. " (" .. string.format("%.6f", os.clock() - tbl.timing) .. "s ago)")

                -- Most recent module
                if tbl.most_recent_module then
                    imgui.spacing()
                    imgui.text_colored("Most recent module: " .. (tbl.most_recent_module.name or "?")
                        .. " (" .. tbl.most_recent_module.calls .. " calls)", 0xFFAAFFFF)

                    local pc, pv = imgui.checkbox("Pause updating##mi_pause_" .. name, tbl.pause_most_recent)
                    if pc then tbl.pause_most_recent = pv end
                end

                -- Args display
                if tbl.args and #tbl.args > 0 then
                    imgui.spacing()
                    if imgui.tree_node("Arguments (" .. #tbl.args .. ")##mi_args_" .. name) then
                        for i, arg in ipairs(tbl.args) do
                            local param_label = ""
                            local pi = i - 1  -- first arg is typically 'this'
                            if pi == 0 then
                                param_label = tbl.my_typename .. " (this)"
                            elseif tbl.param_typenames[pi] then
                                param_label = tbl.param_typenames[pi]
                                if tbl.param_names[pi] then
                                    param_label = param_label .. " " .. tbl.param_names[pi]
                                end
                            end
                            imgui.text_colored("args[" .. i .. "]: ", 0xFF888888)
                            if param_label ~= "" then
                                imgui.same_line()
                                imgui.text_colored(param_label, pi == 0 and 0xFFAAFFFF or 0xFFE0853D)
                            end
                            imgui.indent()
                            render_arg_value(arg, nil, name .. "_a" .. i)
                            imgui.unindent()
                        end
                        imgui.tree_pop()
                    end
                end

                -- Return value
                if tbl.retval_typename then
                    if imgui.tree_node("Return: " .. tbl.retval_typename .. "##mi_ret_" .. name) then
                        render_arg_value(tbl.retval, "retval", name .. "_ret")
                        imgui.tree_pop()
                    end
                end

                -- Module breakdown
                local mod_count = 0
                for _ in pairs(tbl.module_tables) do mod_count = mod_count + 1 end
                if mod_count > 0 then
                    if imgui.tree_node("Module Breakdown (" .. mod_count .. ")##mi_mods_" .. name) then
                        for idx, mod_tbl in pairs(tbl.module_tables) do
                            imgui.text(mod_tbl.name .. ": " .. mod_tbl.calls .. " calls")
                        end
                        imgui.tree_pop()
                    end
                end
            else
                imgui.text_colored("Not called yet", 0xFF888888)
            end

            -- Hook Editor
            if imgui.tree_node("Hook Editor##mi_editor_" .. name) then
                local pc, pv = imgui.checkbox("Use pre-function hook##mi_pre_" .. name, tbl.use_pre_code)
                if pc then tbl.use_pre_code = pv end
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Return 1 from your code to skip the original call")
                end

                imgui.push_item_width(600)
                local cc1, cv1 = imgui.input_text_multiline("Pre-hook code##mi_prec_" .. name, tbl.pre_code, 2000)
                if cc1 then tbl.pre_code = cv1; tbl.use_pre_code = false end
                imgui.pop_item_width()

                if tbl.error_txt_pre then
                    imgui.text_colored(tbl.error_txt_pre, 0xFF4444FF)
                end

                imgui.spacing()

                local pc2, pv2 = imgui.checkbox("Use post-function hook##mi_post_" .. name, tbl.use_post_code)
                if pc2 then tbl.use_post_code = pv2 end
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Return a value to override the return value")
                end

                imgui.push_item_width(600)
                local cc2, cv2 = imgui.input_text_multiline("Post-hook code##mi_postc_" .. name, tbl.post_code, 2000)
                if cc2 then tbl.post_code = cv2; tbl.use_post_code = false end
                imgui.pop_item_width()

                if tbl.error_txt_post then
                    imgui.text_colored(tbl.error_txt_post, 0xFF4444FF)
                end

                imgui.tree_pop()
            end

            imgui.tree_pop()
        end
    end

    if #sorted_names == 0 then
        imgui.text_colored("No methods hooked yet. Type a method signature above and click Hook.", 0xFF888888)
    end
end

return MethodInspector
