--[[
    object_explorer.lua — Full Object Explorer (EMV Engine style)
    EMV Engine Module

    Rich object inspector with RSZ type database integration.
    Features:
    - Transform grid with Position/Rotation/Scale (world + local)
    - Type-aware field rendering using rszre9.json type definitions
    - Enum dropdowns with named values from re9_enums.json
    - Vector editors (Vec2/Vec3/Vec4/Float3/Float4)
    - Recursive sub-object navigation with cycle detection
    - Component list with per-component inspector + Enabled toggle
    - Method call buttons (0-param methods)
    - Per-component Update/auto-refresh controls
    - Field search filter
]]

local ObjectExplorer = {}
local ControlPanel, CoreFunctions, TypeDB

function ObjectExplorer.setup(deps)
    ControlPanel = deps.ControlPanel
    CoreFunctions = deps.CoreFunctions
    TypeDB = deps.TypeDB
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Metadata cache (type → fields/methods/properties from TDB)
-- ═══════════════════════════════════════════════════════════════════════════

local type_cache = {}

local function get_type_meta(td)
    if not td then return nil end
    local name = td:get_full_name()
    if type_cache[name] then return type_cache[name] end

    local meta = { fields = {}, methods = {}, props = {}, name = name }

    pcall(function()
        local fields = td:get_fields()
        if fields then
            for _, f in ipairs(fields) do
                if not f:is_static() then
                    local ft = f:get_type()
                    meta.fields[#meta.fields + 1] = {
                        name = f:get_name(),
                        type_name = ft and ft:get_full_name() or "?",
                        type_def = ft,
                    }
                end
            end
        end
    end)

    pcall(function()
        local methods = td:get_methods()
        if methods then
            for _, m in ipairs(methods) do
                local mn = m:get_name()
                if mn and not mn:find("^__") then
                    local rt = m:get_return_type()
                    local num_params = m:get_num_params() or 0
                    local rtn = rt and rt:get_full_name() or "void"
                    meta.methods[#meta.methods + 1] = {
                        name = mn,
                        return_type = rtn,
                        num_params = num_params,
                        method = m,
                    }
                    if mn:sub(1, 4) == "get_" and num_params == 0 then
                        meta.props[#meta.props + 1] = {
                            name = mn:sub(5),
                            getter = mn,
                            type_name = rtn,
                        }
                    end
                end
            end
        end
    end)

    type_cache[name] = meta
    return meta
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform Inspector (grid layout)
-- ═══════════════════════════════════════════════════════════════════════════

local function draw_vec3_row(label, vec, setter, uid)
    if not vec then return end
    imgui.text_colored(label, 0xFF888888)
    imgui.same_line()
    local changed, nv = imgui.drag_float3("##" .. uid, {vec.x, vec.y, vec.z}, 0.01)
    if changed and setter then
        pcall(function() setter(Vector3f.new(nv[1], nv[2], nv[3])) end)
    end
end

local function draw_vec4_row(label, x, y, z, w, uid)
    imgui.text_colored(label, 0xFF888888)
    imgui.same_line()
    imgui.drag_float4("##" .. uid, {x, y, z, w}, 0.01)
end

local function draw_transform_inspector(xf, uid, go)
    if not xf then return end
    uid = uid or "xf"
    if not imgui.tree_node("Transform##xf_" .. uid) then return end

    -- Position (world, editable)
    pcall(function()
        local wp = xf:call("get_Position")
        if wp then
            draw_vec3_row("Position    ", wp,
                function(v) xf:call("set_Position", v) end, "pos_" .. uid)
        end
    end)

    -- Rotation quaternion
    pcall(function()
        local r = xf:call("get_Rotation")
        if r then draw_vec4_row("Rotation    ", r.x, r.y, r.z, r.w, "rot_" .. uid) end
    end)

    -- Scale
    pcall(function()
        local s = xf:call("get_Scale")
        if s then draw_vec3_row("Scale       ", s, nil, "scl_" .. uid) end
    end)

    -- Local Euler Angles (editable)
    pcall(function()
        local le = xf:call("get_LocalEulerAngle")
        if le then
            draw_vec3_row("LocalEuler  ", le,
                function(v) xf:call("set_LocalEulerAngle", v) end, "le_" .. uid)
        end
    end)

    -- Local Position (editable)
    pcall(function()
        local lp = xf:call("get_LocalPosition")
        if lp then
            draw_vec3_row("LocalPos    ", lp,
                function(v) xf:call("set_LocalPosition", v) end, "lp_" .. uid)
        end
    end)

    -- Local Rotation
    pcall(function()
        local lr = xf:call("get_LocalRotation")
        if lr then
            draw_vec4_row("LocalRot    ", lr.x, lr.y, lr.z, lr.w, "lr_" .. uid)
        end
    end)

    -- Local Scale (editable)
    pcall(function()
        local ls = xf:call("get_LocalScale")
        if ls then
            draw_vec3_row("LocalScale  ", ls,
                function(v) xf:call("set_LocalScale", v) end, "ls_" .. uid)
        end
    end)

    -- WorldMatrix / LocalMatrix
    pcall(function()
        local wm = xf:call("get_WorldMatrix")
        if wm then
            if imgui.tree_node("WorldMatrix##wm_" .. uid) then
                local displayed = false
                pcall(function()
                    for r = 0, 3 do
                        local row = wm[r]
                        if row then
                            imgui.text(string.format("[%d] %.4f  %.4f  %.4f  %.4f",
                                r, row.x or row[0] or 0, row.y or row[1] or 0,
                                row.z or row[2] or 0, row.w or row[3] or 0))
                            displayed = true
                        end
                    end
                end)
                if not displayed then imgui.text(tostring(wm)) end
                imgui.tree_pop()
            end
        end
    end)
    pcall(function()
        local lm = xf:call("get_LocalMatrix")
        if lm then
            if imgui.tree_node("LocalMatrix##lm_" .. uid) then
                local displayed = false
                pcall(function()
                    for r = 0, 3 do
                        local row = lm[r]
                        if row then
                            imgui.text(string.format("[%d] %.4f  %.4f  %.4f  %.4f",
                                r, row.x or row[0] or 0, row.y or row[1] or 0,
                                row.z or row[2] or 0, row.w or row[3] or 0))
                            displayed = true
                        end
                    end
                end)
                if not displayed then imgui.text(tostring(lm)) end
                imgui.tree_pop()
            end
        end
    end)

    -- Parent link
    pcall(function()
        local root = xf:call("get_Parent")
        if root then
            local rgo = root:call("get_GameObject")
            local rname = rgo and tostring(rgo:call("get_Name")) or "?"
            if imgui.tree_node(("Parent: %s##root_%s"):format(rname, uid)) then
                draw_transform_inspector(root, uid .. "_root")
                imgui.tree_pop()
            end
        end
    end)

    imgui.tree_pop()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Cycle detection
-- ═══════════════════════════════════════════════════════════════════════════

local _visited = {}

local function visit_push(obj)
    local addr = 0
    pcall(function() addr = obj:get_address() end)
    if addr == 0 then return false end
    if _visited[addr] then return false end
    _visited[addr] = true
    return true
end

local function visit_pop(obj)
    pcall(function() _visited[obj:get_address()] = nil end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Type-aware field rendering
-- ═══════════════════════════════════════════════════════════════════════════

local MAX_DEPTH = 6

-- Primitive types that are always safe to read eagerly
local SAFE_TYPES = {
    ["System.Boolean"] = true, ["System.Byte"] = true, ["System.SByte"] = true,
    ["System.Int16"] = true, ["System.UInt16"] = true,
    ["System.Int32"] = true, ["System.UInt32"] = true,
    ["System.Int64"] = true, ["System.UInt64"] = true,
    ["System.Single"] = true, ["System.Double"] = true,
    ["System.String"] = true, ["System.Char"] = true,
}

-- RSZ type → render kind mapping
local RSZ_RENDER_MAP = {
    S8 = "int", U8 = "int", S16 = "int", U16 = "int",
    S32 = "int", U32 = "int", S64 = "int", U64 = "int",
    F32 = "float", F64 = "float",
    Bool = "bool", String = "string",
    Vec2 = "vec2", Vec3 = "vec3", Vec4 = "vec4",
    Float2 = "vec2", Float3 = "vec3", Float4 = "vec4",
    Color = "color", Guid = "guid",
    Object = "object", UserData = "object",
    Resource = "resource",
}

-- Per-component refresh state
local _component_state = {} -- uid → { auto_update, last_values, field_filter }

local function get_comp_state(uid)
    if not _component_state[uid] then
        _component_state[uid] = {
            auto_update = false,
            field_filter = "",
            needs_update = true,
            cached_values = {},
        }
    end
    return _component_state[uid]
end

--- Render a typed field using RSZ type info + enum support
local function render_typed_field(obj, field_def, uid, depth)
    depth = depth or 0
    if depth > MAX_DEPTH then
        imgui.text_colored(field_def.name .. " (max depth)", 0xFF666666)
        return
    end

    local fname = field_def.name
    local rsz_type = field_def.type or "?"
    local orig_type = field_def.orig or ""
    local is_array = field_def.array
    local render_kind = RSZ_RENDER_MAP[rsz_type] or "unknown"

    -- Check if this is an enum by original_type
    local is_enum = false
    if TypeDB and orig_type ~= "" then
        is_enum = TypeDB.is_enum(orig_type)
    end

    -- For arrays, show as expandable list
    if is_array then
        imgui.text_colored("[" .. rsz_type .. "[ ]]", 0xFFBB88FF)
        imgui.same_line()
        if imgui.tree_node(fname .. "##arr_" .. uid) then
            -- Try to read array via get_field
            local arr_val = nil
            pcall(function() arr_val = obj:get_field(fname) end)
            if arr_val and type(arr_val) == "userdata" then
                local count = 0
                pcall(function() count = arr_val:call("get_Count") or arr_val:call("get_Length") or 0 end)
                imgui.text_colored(("  Count: %d"):format(count), 0xFF888888)
                if count > 0 and count <= 100 then
                    for idx = 0, math.min(count - 1, 49) do
                        pcall(function()
                            local elem = arr_val:call("get_Item", idx)
                            if elem ~= nil then
                                imgui.text(("  [%d] = %s"):format(idx, tostring(elem)))
                            end
                        end)
                    end
                    if count > 50 then
                        imgui.text_colored(("  ... +%d more"):format(count - 50), 0xFF888888)
                    end
                end
            else
                imgui.text_colored("  (could not read array)", 0xFFFF6666)
            end
            imgui.tree_pop()
        end
        return
    end

    -- ── Enum rendering ──
    if is_enum and (render_kind == "int" or rsz_type == "S32" or rsz_type == "U32") then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        if val == nil then
            imgui.text_colored(orig_type, 0xFFBB88FF)
            imgui.same_line()
            imgui.text(fname .. " = nil")
            return
        end

        local enum_name = TypeDB.get_enum_name(orig_type, val)
        local display = enum_name and (enum_name .. " (" .. tostring(val) .. ")") or tostring(val)

        imgui.text_colored(orig_type, 0xFFBB88FF)
        imgui.same_line()

        -- Try combo dropdown
        local names, values = TypeDB.get_enum_combo_data(orig_type)
        if names and #names > 0 and #names <= 100 then
            -- Find current index
            local cur_idx = 1
            for i, v in ipairs(values) do
                if v == val then cur_idx = i; break end
            end
            local changed, new_idx = imgui.combo(fname .. "##" .. uid, cur_idx, names)
            if changed and values[new_idx] then
                pcall(obj.set_field, obj, fname, values[new_idx])
            end
        else
            -- Too many values or no combo data — show as text + drag
            local c, nv = imgui.drag_int(fname .. " [" .. display .. "]##" .. uid, math.floor(val), 1)
            if c then pcall(obj.set_field, obj, fname, nv) end
        end
        return
    end

    -- ── Primitive rendering ──
    if render_kind == "bool" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFF88CCFF)
        imgui.same_line()
        if val ~= nil then
            local c, nv = imgui.checkbox(fname .. "##" .. uid, val)
            if c then pcall(obj.set_field, obj, fname, nv) end
        else
            imgui.text(fname .. " = nil")
        end
        return
    end

    if render_kind == "int" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFF88CCFF)
        imgui.same_line()
        if val ~= nil then
            local c, nv = imgui.drag_int(fname .. "##" .. uid, math.floor(val), 1)
            if c then pcall(obj.set_field, obj, fname, nv) end
        else
            imgui.text(fname .. " = nil")
        end
        return
    end

    if render_kind == "float" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFF88CCFF)
        imgui.same_line()
        if val ~= nil then
            local c, nv = imgui.drag_float(fname .. "##" .. uid, val, 0.01)
            if c then pcall(obj.set_field, obj, fname, nv) end
        else
            imgui.text(fname .. " = nil")
        end
        return
    end

    if render_kind == "string" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFF88CCFF)
        imgui.same_line()
        if val ~= nil then
            local c, nv = imgui.input_text(fname .. "##" .. uid, tostring(val), 256)
            if c then pcall(obj.set_field, obj, fname, nv) end
        else
            imgui.text(fname .. " = nil")
        end
        return
    end

    -- ── Vector rendering ──
    if render_kind == "vec2" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFFFFCC88)
        imgui.same_line()
        if val and val.x ~= nil then
            imgui.drag_float2(fname .. "##" .. uid, {val.x, val.y}, 0.01)
        else
            imgui.text(fname .. " = " .. tostring(val))
        end
        return
    end

    if render_kind == "vec3" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFFFFCC88)
        imgui.same_line()
        if val and val.x ~= nil then
            imgui.drag_float3(fname .. "##" .. uid, {val.x, val.y, val.z or 0}, 0.01)
        else
            imgui.text(fname .. " = " .. tostring(val))
        end
        return
    end

    if render_kind == "vec4" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored(rsz_type, 0xFFFFCC88)
        imgui.same_line()
        if val and val.x ~= nil then
            imgui.drag_float4(fname .. "##" .. uid, {val.x, val.y, val.z or 0, val.w or 0}, 0.01)
        else
            imgui.text(fname .. " = " .. tostring(val))
        end
        return
    end

    -- ── Color rendering ──
    if render_kind == "color" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored("Color", 0xFFFFCC88)
        imgui.same_line()
        if val ~= nil then
            imgui.text(fname .. " = " .. tostring(val))
        else
            imgui.text(fname .. " = nil")
        end
        return
    end

    -- ── GUID rendering ──
    if render_kind == "guid" then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        imgui.text_colored("Guid", 0xFF88AACC)
        imgui.same_line()
        imgui.text(fname .. " = " .. tostring(val or "nil"))
        return
    end

    -- ── Object reference rendering (lazy) ──
    if render_kind == "object" then
        imgui.text_colored(orig_type ~= "" and orig_type or rsz_type, 0xFFAADDFF)
        imgui.same_line()
        if not imgui.tree_node(fname .. "##" .. uid) then return end

        local val = nil
        local read_ok = pcall(function() val = obj:get_field(fname) end)
        if not read_ok or val == nil then
            imgui.text_colored("(nil or read error)", 0xFFFF6666)
            imgui.tree_pop()
            return
        end

        if type(val) == "userdata" then
            local is_managed = false
            pcall(function() is_managed = sdk.is_managed_object(val) end)
            if is_managed then
                local sub_addr = 0
                pcall(function() sub_addr = val:get_address() end)
                if _visited[sub_addr] then
                    imgui.text_colored("→ (cycle)", 0xFFFF8844)
                else
                    pcall(function() val:add_ref() end)
                    ObjectExplorer.inspect_object(val, uid .. "." .. fname, depth + 1)
                end
            else
                -- Value type
                local desc = nil
                pcall(function()
                    if val.x ~= nil then
                        if val.w ~= nil then
                            desc = ("(%.3f, %.3f, %.3f, %.3f)"):format(val.x, val.y, val.z, val.w)
                        elseif val.z ~= nil then
                            desc = ("(%.3f, %.3f, %.3f)"):format(val.x, val.y, val.z)
                        else
                            desc = ("(%.2f, %.2f)"):format(val.x, val.y)
                        end
                    end
                end)
                imgui.text(desc or tostring(val))
            end
        else
            imgui.text(tostring(val))
        end
        imgui.tree_pop()
        return
    end

    -- ── Fallback: use original TDB field rendering ──
    render_tdb_field(obj, fname, orig_type ~= "" and orig_type or rsz_type, uid, depth)
end

--- Fallback TDB-based field renderer (for types not in RSZ database)
function render_tdb_field(obj, fname, ftype_name, uid, depth)
    depth = depth or 0
    if depth > MAX_DEPTH then
        imgui.text_colored(fname .. " (max depth)", 0xFF666666)
        return
    end

    if SAFE_TYPES[ftype_name] then
        local val = nil
        pcall(function() val = obj:get_field(fname) end)
        if val == nil then
            imgui.text_colored(ftype_name, 0xFF888888)
            imgui.same_line()
            imgui.text(fname .. " = nil")
            return
        end
        local vtype = type(val)
        if vtype == "boolean" then
            imgui.text_colored(ftype_name, 0xFF888888)
            imgui.same_line()
            local c, nv = imgui.checkbox(fname .. "##" .. uid, val)
            if c then pcall(obj.set_field, obj, fname, nv) end
        elseif vtype == "number" then
            imgui.text_colored(ftype_name, 0xFF888888)
            imgui.same_line()
            if ftype_name:find("Int") or ftype_name:find("Byte") or ftype_name:find("UInt") then
                local c, nv = imgui.drag_int(fname .. "##" .. uid, math.floor(val), 1)
                if c then pcall(obj.set_field, obj, fname, nv) end
            else
                local c, nv = imgui.drag_float(fname .. "##" .. uid, val, 0.01)
                if c then pcall(obj.set_field, obj, fname, nv) end
            end
        elseif vtype == "string" then
            imgui.text_colored(ftype_name, 0xFF888888)
            imgui.same_line()
            local c, nv = imgui.input_text(fname .. "##" .. uid, val, 256)
            if c then pcall(obj.set_field, obj, fname, nv) end
        else
            imgui.text_colored(ftype_name, 0xFF888888)
            imgui.same_line()
            imgui.text(fname .. " = " .. tostring(val))
        end
        return
    end

    -- Non-safe types: lazy read only when user expands
    imgui.text_colored(ftype_name, 0xFF888888)
    imgui.same_line()
    if not imgui.tree_node(fname .. "##" .. uid) then return end

    local val = nil
    local read_ok = pcall(function() val = obj:get_field(fname) end)
    if not read_ok or val == nil then
        imgui.text_colored("(nil or read error)", 0xFFFF6666)
        imgui.tree_pop()
        return
    end

    local vtype = type(val)
    if vtype == "userdata" then
        local is_managed = false
        pcall(function() is_managed = sdk.is_managed_object(val) end)
        if is_managed then
            local sub_addr = 0
            pcall(function() sub_addr = val:get_address() end)
            if _visited[sub_addr] then
                imgui.text_colored("→ (cycle)", 0xFFFF8844)
            else
                pcall(function() val:add_ref() end)
                ObjectExplorer.inspect_object(val, uid .. "." .. fname, depth + 1)
            end
        else
            local desc = nil
            pcall(function()
                if val.x ~= nil then
                    if val.w ~= nil then
                        desc = ("(%.3f, %.3f, %.3f, %.3f)"):format(val.x, val.y, val.z, val.w)
                    elseif val.z ~= nil then
                        desc = ("(%.3f, %.3f, %.3f)"):format(val.x, val.y, val.z)
                    else
                        desc = ("(%.2f, %.2f)"):format(val.x, val.y)
                    end
                end
            end)
            imgui.text(desc or "(value)")
        end
    elseif vtype == "number" then
        imgui.text(tostring(val))
    elseif vtype == "boolean" then
        imgui.text(tostring(val))
    else
        local s = tostring(val)
        if s:find(": %x%x%x%x%x%x%x%x") then s = "(value)" end
        imgui.text(s)
    end
    imgui.tree_pop()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Object Inspector (recursive) — now with RSZ type integration
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectExplorer.inspect_object(obj, uid, depth)
    depth = depth or 0
    uid = uid or "exp"
    if not obj then imgui.text_colored("nil", 0xFF6666FF); return end

    local is_managed = false
    pcall(function() is_managed = sdk.is_managed_object(obj) end)
    if not is_managed then imgui.text_colored("Invalid managed object", 0xFF6666FF); return end

    local td = nil
    pcall(function() td = obj:get_type_definition() end)
    if not td then imgui.text_colored("No type definition", 0xFF6666FF); return end

    local type_name = td:get_full_name()
    local addr = 0
    pcall(function() addr = obj:get_address() end)

    -- Header with address
    imgui.text_colored(type_name, 0xFF00B4D8)
    imgui.same_line()
    imgui.text_colored(("@ 0x%X"):format(addr), 0xFF666666)

    -- Track visited
    local pushed = visit_push(obj)
    local meta = get_type_meta(td)
    if not meta then
        if pushed then visit_pop(obj) end
        return
    end

    -- Component state (update/filter controls)
    local cstate = get_comp_state(uid)

    -- Update + auto-update controls
    if imgui.small_button("Update##upd_" .. uid) then
        cstate.needs_update = true
    end
    imgui.same_line()
    local _, auto = imgui.checkbox("Auto##auto_" .. uid, cstate.auto_update)
    cstate.auto_update = auto
    if auto then cstate.needs_update = true end

    -- Field search filter
    imgui.same_line()
    local _, filt = imgui.input_text("Filter##filt_" .. uid, cstate.field_filter, 128)
    cstate.field_filter = filt
    local filter_lower = filt:lower()

    -- ─── RSZ-typed Fields (if TypeDB available) ───
    local rsz_fields = nil
    if TypeDB and TypeDB.is_loaded() then
        rsz_fields = TypeDB.get_all_fields(type_name)
    end

    if rsz_fields and #rsz_fields > 0 then
        -- Show RSZ-typed fields
        local shown = 0
        local total = #rsz_fields
        if imgui.tree_node(("RSZ Fields (%d)##rsz_%s"):format(total, uid)) then
            for i, fdef in ipairs(rsz_fields) do
                -- Apply filter
                if filter_lower == "" or fdef.name:lower():find(filter_lower, 1, true) then
                    shown = shown + 1
                    pcall(render_typed_field, obj, fdef, uid .. "_rsz" .. i, depth)
                end
            end
            if shown == 0 and filter_lower ~= "" then
                imgui.text_colored("No fields matching '" .. filt .. "'", 0xFF888888)
            end
            imgui.tree_pop()
        end
    end

    -- ─── TDB Fields (runtime introspection fallback) ───
    if #meta.fields > 0 then
        local label = rsz_fields and #rsz_fields > 0
            and ("TDB Fields (%d)##fld_%s"):format(#meta.fields, uid)
            or ("Fields (%d)##fld_%s"):format(#meta.fields, uid)

        if imgui.tree_node(label) then
            for i, fi in ipairs(meta.fields) do
                if filter_lower == "" or fi.name:lower():find(filter_lower, 1, true) then
                    pcall(render_tdb_field, obj, fi.name, fi.type_name, uid .. "_f" .. i, depth)
                end
            end
            imgui.tree_pop()
        end
    end

    -- ─── Properties (getter results — lazy) ───
    if #meta.props > 0 then
        if imgui.tree_node(("Properties (%d)##prop_%s"):format(#meta.props, uid)) then
            for i, p in ipairs(meta.props) do
                if filter_lower == "" or p.name:lower():find(filter_lower, 1, true) then
                    imgui.text_colored(p.type_name, 0xFF888888)
                    imgui.same_line()
                    if imgui.tree_node(p.name .. "##prop_" .. uid .. "_" .. i) then
                        pcall(function()
                            local val = obj:call(p.getter)
                            if val == nil then
                                imgui.text("nil")
                            elseif type(val) == "userdata" then
                                local is_sub = false
                                pcall(function() is_sub = sdk.is_managed_object(val) end)
                                if is_sub then
                                    local paddr = 0
                                    pcall(function() paddr = val:get_address() end)
                                    if _visited[paddr] then
                                        imgui.text_colored("→ (cycle)", 0xFFFF8844)
                                    else
                                        pcall(function() val:add_ref() end)
                                        ObjectExplorer.inspect_object(val, uid .. "_p" .. i, depth + 1)
                                    end
                                else
                                    local desc = nil
                                    pcall(function()
                                        if val.x ~= nil then
                                            if val.w ~= nil then
                                                desc = ("(%.3f, %.3f, %.3f, %.3f)"):format(val.x, val.y, val.z, val.w)
                                            elseif val.z ~= nil then
                                                desc = ("(%.3f, %.3f, %.3f)"):format(val.x, val.y, val.z)
                                            else
                                                desc = ("(%.2f, %.2f)"):format(val.x, val.y)
                                            end
                                        end
                                    end)
                                    imgui.text(desc or "(value)")
                                end
                            else
                                imgui.text(tostring(val))
                            end
                        end)
                        imgui.tree_pop()
                    end
                end
            end
            imgui.tree_pop()
        end
    end

    -- ─── Methods (0-param callable) ───
    local callable = {}
    for _, m in ipairs(meta.methods) do
        if m.num_params == 0 then callable[#callable + 1] = m end
    end
    if #callable > 0 then
        if imgui.tree_node(("Methods (%d callable)##mtd_%s"):format(#callable, uid)) then
            for _, m in ipairs(callable) do
                pcall(function()
                    if imgui.small_button(m.name .. "()##" .. uid .. "_" .. m.name) then
                        local ok, result = pcall(obj.call, obj, m.name)
                        if ok then _G._explorer_last_result = result end
                    end
                    imgui.same_line()
                    imgui.text_colored("→ " .. m.return_type, 0xFF888888)
                end)
            end
            imgui.tree_pop()
        end
    end

    -- All methods (view-only)
    if #meta.methods > #callable then
        if imgui.tree_node(("All Methods (%d)##allmtd_%s"):format(#meta.methods, uid)) then
            for _, m in ipairs(meta.methods) do
                pcall(function()
                    local ps = ""
                    if m.num_params > 0 then
                        pcall(function()
                            local params = m.method:get_params()
                            if params and #params > 0 then
                                local pp = {}
                                for _, p in ipairs(params) do
                                    local pt = p:get_type()
                                    pp[#pp+1] = (pt and pt:get_full_name() or "?") .. " " .. (p:get_name() or "")
                                end
                                ps = table.concat(pp, ", ")
                            end
                        end)
                    end
                    imgui.text_colored(m.return_type .. " " .. m.name .. "(" .. ps .. ")", 0xFFAAAADD)
                end)
            end
            imgui.tree_pop()
        end
    end

    if pushed then visit_pop(obj) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Full GameObject Explorer (main entry point)
-- ═══════════════════════════════════════════════════════════════════════════

function ObjectExplorer.explore_gameobj(go, uid)
    _visited = {}
    uid = uid or "go"
    if not go then imgui.text_colored("nil GameObject", 0xFF6666FF); return end

    local name = "?"
    pcall(function() name = tostring(go:call("get_Name")) end)
    local addr = 0
    pcall(function() addr = go:get_address() end)

    -- Header
    imgui.text_colored("[Object Explorer]", 0xFF44FF88)
    imgui.same_line()
    imgui.text_colored(name, 0xFFFFFFFF)
    imgui.same_line()
    imgui.text_colored(("@ 0x%X"):format(addr), 0xFF666666)

    -- ── Key Properties (always visible, with Copy buttons) ──
    -- Name
    imgui.text_colored("Name:", 0xFF888888)
    imgui.same_line()
    imgui.text(name)
    imgui.same_line()
    if imgui.small_button("Copy##cpname_" .. uid) then
        pcall(function() imgui.set_clipboard(name) end)
    end

    -- Tag
    pcall(function()
        local tag = go:call("get_Tag")
        if tag and tag ~= "" then
            imgui.text_colored("Tag:", 0xFF888888)
            imgui.same_line()
            imgui.text(tostring(tag))
            imgui.same_line()
            if imgui.small_button("Copy##cptag_" .. uid) then
                pcall(function() imgui.set_clipboard(tostring(tag)) end)
            end
        end
    end)

    -- GUID
    local guid_str = nil
    pcall(function()
        local s = go:call("ToString()")
        if s then guid_str = tostring(s):match("@([%x%-]+)%]$") end
    end)
    if guid_str then
        imgui.text_colored("GUID:", 0xFFFFCC44)
        imgui.same_line()
        imgui.text(guid_str)
        imgui.same_line()
        if imgui.small_button("Copy##cpguid_" .. uid) then
            pcall(function() imgui.set_clipboard(guid_str) end)
        end
    end

    -- Folder path
    local folder_str = nil
    pcall(function()
        local folder = go:call("get_Folder")
        if folder then
            local ts = folder:call("ToString()")
            if ts then
                local p = tostring(ts):match("%[(.+)%]$")
                if p then folder_str = p end
            end
            if not folder_str then
                local fpath = folder:call("get_Path")
                if fpath and fpath ~= "" then
                    folder_str = fpath .. "/" .. name
                end
            end
        end
    end)
    if folder_str then
        imgui.text_colored("Folder:", 0xFF88CCFF)
        imgui.same_line()
        imgui.text(folder_str)
        imgui.same_line()
        if imgui.small_button("Copy##cpfolder_" .. uid) then
            pcall(function() imgui.set_clipboard(folder_str) end)
        end
    end

    -- Enabled / Destroy
    pcall(function()
        local en = go:call("get_DrawSelf")
        local c, nv = imgui.checkbox("Enabled##goen_" .. uid, en)
        if c then pcall(go.call, go, "set_DrawSelf", nv) end
    end)
    imgui.same_line()
    if imgui.button("Destroy##dst_" .. uid) then
        pcall(function() go:call("destroy", go) end)
    end

    imgui.separator()

    -- Transform section
    local xf = nil
    pcall(function() xf = go:call("get_Transform") end)
    draw_transform_inspector(xf, uid, go)

    -- Components
    local cnt = 0
    pcall(function() cnt = go:call("get_ComponentCount") or 0 end)
    if cnt > 0 then
        for ci = 0, math.min(cnt - 1, 30) do
            pcall(function()
                local comp = go:call("getComponent(System.Int32)", ci)
                if not comp then return end
                local ctd = comp:get_type_definition()
                if not ctd then return end
                local cname = ctd:get_full_name()
                local caddr = comp:get_address()

                if cname == "via.Transform" then return end

                -- Color-code component name based on RSZ type availability
                local has_rsz = TypeDB and TypeDB.is_loaded() and TypeDB.get_type(cname)
                local label_color = has_rsz and 0xFF88FF88 or 0xFFFFFFFF

                if imgui.tree_node(("%d. %s##comp_%s_%d"):format(ci + 1, cname, uid, ci)) then
                    imgui.text_colored(("  [0x%X]"):format(caddr), 0xFF888888)
                    if has_rsz then
                        imgui.same_line()
                        imgui.text_colored("[RSZ]", 0xFF88FF88)
                    end

                    -- Enabled toggle
                    pcall(function()
                        local en = comp:call("get_Enabled")
                        local ec, ev = imgui.checkbox("Enabled##cen_" .. uid .. "_" .. ci, en)
                        if ec then pcall(comp.call, comp, "set_Enabled", ev) end
                    end)

                    -- Full inspection
                    ObjectExplorer.inspect_object(comp, uid .. "_comp" .. ci)

                    imgui.tree_pop()
                end
            end)
        end
    end

    -- GameObject properties
    if imgui.tree_node("GameObject##gopr_" .. uid) then
        ObjectExplorer.inspect_object(go, uid .. "_go")
        imgui.tree_pop()
    end
end

return ObjectExplorer
