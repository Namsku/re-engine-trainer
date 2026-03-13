--[[
    control_panel.lua — Managed Object Inspector / Control Panel
    EMV Engine Module (Phase 2)

    Recursive type-introspection inspector with editable fields,
    method call buttons, and material editors.
]]

local ControlPanel = {}
local RE9_OFFSETS, SafeMemory, ObjectCache, CoreFunctions, ImguiHelpers, Serialization, DeferredCalls, TableUtils

function ControlPanel.setup(deps)
    RE9_OFFSETS = deps.RE9_OFFSETS; SafeMemory = deps.SafeMemory
    ObjectCache = deps.ObjectCache; CoreFunctions = deps.CoreFunctions
    ImguiHelpers = deps.ImguiHelpers; Serialization = deps.Serialization
    DeferredCalls = deps.DeferredCalls; TableUtils = deps.TableUtils
end

local metadata_methods = {}

function ControlPanel.get_fields_and_methods(typedef)
    if type(typedef) == "string" then typedef = sdk.find_type_definition(typedef) end
    if not typedef then return {fields={}, methods={}, props={}} end
    local type_name = typedef:get_full_name()
    if metadata_methods[type_name] then return metadata_methods[type_name] end
    local meta = {fields={}, methods={}, props={}}
    pcall(function()
        local fields = typedef:get_fields()
        if fields then for _, f in ipairs(fields) do
            if not f:is_static() then
                local ft = f:get_type()
                if ft then meta.fields[#meta.fields+1] = {name=f:get_name(), type_name=ft:get_full_name()} end
            end
        end end
        local methods = typedef:get_methods()
        if methods then for _, m in ipairs(methods) do
            local mn = m:get_name()
            if mn and not mn:find("^__") then
                local rt = m:get_return_type()
                meta.methods[#meta.methods+1] = {name=mn, return_type=rt and rt:get_full_name() or "void", num_params=m:get_num_params() or 0}
                if mn:sub(1,4) == "get_" and (m:get_num_params() or 0) == 0 then
                    meta.props[#meta.props+1] = {name=mn:sub(5), getter=mn, type_name=rt and rt:get_full_name() or "unknown"}
                end
            end
        end end
    end)
    metadata_methods[type_name] = meta; return meta
end

function ControlPanel.create_REMgdObj(obj)
    if not obj or not sdk.is_managed_object(obj) then return nil end
    local data = {}
    pcall(function()
        local tdef = obj:get_type_definition()
        if not tdef then return end
        data.type_name = tdef:get_full_name(); data.obj = obj
        data.meta = ControlPanel.get_fields_and_methods(tdef); data.field_data = {}; data.prop_data = {}
        for _, fi in ipairs(data.meta.fields) do
            pcall(function() data.field_data[fi.name] = {value=obj:get_field(fi.name), type=fi.type_name, info=fi} end)
        end
        for _, p in ipairs(data.meta.props) do
            pcall(function() data.prop_data[p.name] = {value=obj:call(p.getter), type=p.type_name} end)
        end
    end)
    return data
end

function ControlPanel.read_field(obj, field_info, vardata)
    if not obj or not field_info then return nil end
    local value; pcall(function() value = obj:get_field(field_info.name) end)
    if vardata and vardata.freeze and vardata.cvalue ~= nil then
        pcall(function() obj:set_field(field_info.name, vardata.cvalue) end); return vardata.cvalue
    end
    if vardata then vardata.cvalue = value end; return value
end

function ControlPanel.managed_object_control_panel(obj, key, args)
    if not obj then imgui.text_colored("nil object", 0xFF6666FF); return end
    if not sdk.is_managed_object(obj) then imgui.text_colored("Invalid", 0xFF6666FF); return end
    key = key or tostring(obj)
    local data = ControlPanel.create_REMgdObj(obj)
    if not data then imgui.text_colored("Failed to inspect", 0xFF6666FF); return end
    imgui.text_colored(data.type_name or "Unknown", 0xFF00B4D8); imgui.same_line()
    imgui.text_colored(("  [0x%X]"):format(obj:get_address()), 0xFF888888); imgui.separator()

    if #data.meta.fields > 0 and imgui.tree_node("Fields (" .. #data.meta.fields .. ")##" .. key) then
        for _, fi in ipairs(data.meta.fields) do
            local fd = data.field_data[fi.name]
            if fd then ControlPanel._render_field(obj, fi.name, fd, key) end
        end; imgui.tree_pop()
    end
    if #data.meta.props > 0 and imgui.tree_node("Properties (" .. #data.meta.props .. ")##" .. key) then
        for _, p in ipairs(data.meta.props) do
            local pd = data.prop_data[p.name]
            if pd then imgui.text_colored(p.name, 0xFFAAFFAA); imgui.same_line(); imgui.text(": " .. tostring(pd.value)) end
        end; imgui.tree_pop()
    end
    if #data.meta.methods > 0 and imgui.tree_node("Methods (" .. #data.meta.methods .. ")##" .. key) then
        for _, m in ipairs(data.meta.methods) do
            if m.num_params == 0 then
                if imgui.small_button(m.name .. "()##" .. key) then
                    pcall(function() obj:call(m.name) end)
                end; imgui.same_line(); imgui.text_colored("→ " .. m.return_type, 0xFF888888)
            end
        end; imgui.tree_pop()
    end
end

function ControlPanel._render_field(obj, fname, fdata, key)
    local value, tn = fdata.value, fdata.type or "unknown"
    imgui.text_colored(tn, 0xFF888888); imgui.same_line()
    if value == nil then imgui.text(fname .. " = nil"); return end
    local vtype = type(value); local uid = fname .. "##" .. key
    if vtype == "boolean" then
        local c, nv = imgui.checkbox(uid, value); if c then pcall(function() obj:set_field(fname, nv) end) end
    elseif vtype == "number" then
        if tn:find("Int") or tn:find("Byte") then
            local c, nv = imgui.drag_int(uid, value, 1.0); if c then pcall(function() obj:set_field(fname, nv) end) end
        else
            local c, nv = imgui.drag_float(uid, value, 0.01); if c then pcall(function() obj:set_field(fname, nv) end) end
        end
    elseif vtype == "userdata" and sdk.is_managed_object(value) then
        if imgui.tree_node(fname .. " →##" .. key) then ControlPanel.managed_object_control_panel(value, key.."."..fname); imgui.tree_pop() end
    else imgui.text(fname .. " = " .. tostring(value)) end
end

function ControlPanel.show_imgui_mats(anim_object)
    if not anim_object or not anim_object.mesh then imgui.text_colored("No mesh", 0xFF6666FF); return end
    if imgui.tree_node("Materials##mats") then
        for idx, name in pairs(anim_object.mpaths) do
            if imgui.tree_node(("[%d] %s##mat"):format(idx, name)) then
                local mat = anim_object.materials[idx]
                if mat then pcall(function()
                    local nv = mat:call("get_VariableNum") or 0
                    for vi = 0, nv-1 do pcall(function()
                        local vn = mat:call("getVariableName", vi) or ""
                        imgui.text(vn)
                    end) end
                end) else imgui.text_colored("Not loaded", 0xFF888888) end
                imgui.tree_pop()
            end
        end; imgui.tree_pop()
    end
end

return ControlPanel
