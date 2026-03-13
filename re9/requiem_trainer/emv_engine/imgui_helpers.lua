--[[
    imgui_helpers.lua — ImGui Utility Functions
    EMV Engine Module (Phase 2)

    Reusable ImGui widgets for the EMV control panel and UI tabs.
]]

local ImguiHelpers = {}
local CoreFunctions, DeferredCalls

function ImguiHelpers.setup(deps)
    CoreFunctions = deps.CoreFunctions; DeferredCalls = deps.DeferredCalls
end

function ImguiHelpers.tooltip(msg, delay)
    if not msg then return end
    if imgui.is_item_hovered() then imgui.set_tooltip(msg) end
end

function ImguiHelpers.tree_node_colored(key, white, color, clr_value)
    if color or clr_value then imgui.push_style_color(0, clr_value or color) end
    local expanded = imgui.tree_node(key)
    if color or clr_value then imgui.pop_style_color(1) end
    return expanded
end

function ImguiHelpers.colored_header(label, color)
    if color then imgui.push_style_color(0, color) end
    local expanded = imgui.collapsing_header(label)
    if color then imgui.pop_style_color(1) end
    return expanded
end

function ImguiHelpers.button_w_hotkey(btn_txt, keyname, dfcall, args)
    local label = btn_txt
    if keyname and keyname ~= "" and keyname ~= "None" then label = btn_txt .. " [" .. keyname .. "]" end
    local pressed = imgui.button(label)
    if args and args.tooltip then ImguiHelpers.tooltip(args.tooltip) end
    return pressed
end

function ImguiHelpers.editable_table_field(key, value, owner, display, args)
    args = args or {}; local label = display or tostring(key)
    local vtype = type(value); local changed, new_val = false, value
    if args.readonly then imgui.text(label .. ": " .. tostring(value)); return value, false end
    if vtype == "boolean" then
        local ret, val = imgui.checkbox(label, value)
        if ret then new_val = val; changed = true end
    elseif vtype == "number" then
        local ret, val = imgui.drag_float(label, value, args.step or 0.01)
        if ret then new_val = val; changed = true end
    elseif vtype == "string" then
        local ret, val = imgui.input_text(label, value, 256)
        if ret then new_val = val; changed = true end
    else imgui.text(label .. ": " .. tostring(value)) end
    if changed and owner then owner[key] = new_val end
    return new_val, changed
end

function ImguiHelpers.kv_line(label, value, color)
    imgui.text(label .. ": "); imgui.same_line()
    if color then imgui.text_colored(tostring(value), color) else imgui.text(tostring(value)) end
end

function ImguiHelpers.labeled_separator(text)
    imgui.spacing(); imgui.separator()
    if text then imgui.text_colored(text, 0xFF888888) end; imgui.spacing()
end

function ImguiHelpers.read_imgui_pairs_table(tbl, key, args)
    if type(tbl) ~= "table" then return tbl end
    if ImguiHelpers.tree_node_colored(key or "Data", nil, 0xFFCCCCCC) then
        for k, v in pairs(tbl) do
            if type(v) ~= "function" then ImguiHelpers.editable_table_field(k, v, tbl, nil, args) end
        end; imgui.tree_pop()
    end; return tbl
end

local ImguiTable = {}; ImguiTable.__index = ImguiTable
function ImguiTable:new(args)
    args = args or {}; return setmetatable({name=args.name or "table", headers=args.headers or {}, widths=args.column_widths or {}, rows={}}, ImguiTable)
end
function ImguiTable:update(rows) self.rows = rows or {} end
function ImguiTable:render()
    local n = #self.headers; if n == 0 then return end
    if imgui.begin_table(self.name, n, 1+2+4+64+128) then
        for i, h in ipairs(self.headers) do imgui.table_setup_column(h, 0, self.widths[i] or 0) end
        imgui.table_headers_row()
        for _, row in ipairs(self.rows) do imgui.table_next_row()
            for _, cell in ipairs(row) do imgui.table_next_column(); imgui.text(tostring(cell)) end
        end; imgui.end_table()
    end
end
ImguiHelpers.ImguiTable = ImguiTable

return ImguiHelpers
