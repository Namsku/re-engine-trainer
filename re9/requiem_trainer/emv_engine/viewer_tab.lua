--[[
    viewer_tab.lua — Viewer Tab UI
    EMV Engine Module (Phase 4)

    Auto-discovers AnimObjects (anything with Motion or Mesh),
    shows transform, animation, materials, and full inspector.
]]

local ViewerTab = {}
local CoreFunctions, GameObjectSystem, ControlPanel, ImguiHelpers

function ViewerTab.setup(deps)
    CoreFunctions = deps.CoreFunctions; GameObjectSystem = deps.GameObjectSystem
    ControlPanel = deps.ControlPanel; ImguiHelpers = deps.ImguiHelpers
end

local state = {
    scan_results   = {},
    selected_name  = "",
    selected_anim  = nil,
    filter_text    = "",
    last_scan      = 0,
    needs_rescan   = true,
}

function ViewerTab.render()
    -- ── Auto-scan for viewable objects ──
    local now = os.clock()
    if state.needs_rescan or (now - state.last_scan) > 5.0 then
        ViewerTab._scan_viewable()
        state.needs_rescan = false
        state.last_scan = now
    end

    -- ── Object Selector ──
    imgui.text_colored(("Viewable Objects: %d"):format(#state.scan_results), 0xFF44FF88)
    imgui.same_line()
    if imgui.small_button("Refresh##vw_refresh") then state.needs_rescan = true end

    local fc, nf = imgui.input_text("Filter##vw_filter", state.filter_text, 256)
    if fc then state.filter_text = nf end

    imgui.separator()

    -- Quick buttons
    if imgui.small_button("Player##vw_pl") then
        pcall(function()
            local p = CoreFunctions.get_player()
            if p then
                local xform = nil
                pcall(function() xform = p:call("get_Transform()") end)
                if xform then
                    state.selected_anim = GameObjectSystem.get_anim_object(xform)
                    state.selected_name = state.selected_anim and state.selected_anim.name or "Player"
                end
            end
        end)
    end
    imgui.same_line()
    imgui.text_colored(state.selected_name ~= "" and ("Selected: " .. state.selected_name) or "Select an object below", 0xFF888888)

    imgui.spacing()

    -- ── Object list ──
    local filter_lower = state.filter_text:lower()
    local shown = 0
    for i, entry in ipairs(state.scan_results) do
        if shown >= 100 then break end
        local name = entry.name or "?"
        local show = filter_lower == "" or name:lower():find(filter_lower, 1, true)

        if show then
            shown = shown + 1
            local is_selected = (state.selected_name == name)
            local color = is_selected and 0xFF44FF88 or 0xFFCCCCCC

            imgui.push_style_color(0, color)
            if imgui.selectable(name .. "##vw_sel_" .. i, is_selected) then
                state.selected_name = name
                state.selected_anim = entry.anim_obj
            end
            imgui.pop_style_color(1)
        end
    end

    imgui.spacing()
    imgui.separator()

    -- ── Selected object details ──
    if not state.selected_anim or not state.selected_anim:isValid() then
        imgui.text_colored("Select an object from the list above", 0xFF888888)
        return
    end

    local anim = state.selected_anim

    -- Transform
    if imgui.collapsing_header("Transform##vw_xf") then
        local pos = anim:getPosition()
        if pos then
            imgui.text_colored(("Position: %.2f, %.2f, %.2f"):format(pos.x, pos.y, pos.z), 0xFF88AACC)
            local changed, nx, ny, nz = imgui.drag_float3("Pos##vw_pos", pos.x, pos.y, pos.z, 0.1)
            if changed then
                pcall(function() anim:setPosition(Vector3f.new(nx, ny, nz)) end)
            end
        end
    end

    -- Animation
    if anim.motion and imgui.collapsing_header("Animation##vw_anim") then
        for li, fsm in pairs(anim.layers) do
            local info = anim:getAnimInfo(li)
            if info then
                imgui.text_colored(("Layer %d: %s"):format(li, info.name), 0xFFAAFFAA)
                imgui.text(("  Speed: %.2f  Weight: %.2f  Frame: %.0f"):format(
                    info.speed or 0, info.weight or 0, info.time or 0))

                local sc, ns = imgui.drag_float("Speed##as" .. li, info.speed or 1.0, 0.01, 0, 10)
                if sc then pcall(function() fsm:call("set_Speed", ns) end) end
            end
        end
    end

    -- Materials
    if anim.mesh and imgui.collapsing_header("Materials##vw_mats") then
        ControlPanel.show_imgui_mats(anim)
    end

    -- Components
    if #anim.components > 0 and imgui.collapsing_header("Components (" .. #anim.components .. ")##vw_comps") then
        for _, comp in ipairs(anim.components) do
            pcall(function()
                local tdef = comp:get_type_definition()
                if tdef then imgui.text_colored("  " .. tdef:get_full_name(), 0xFFAADDFF) end
            end)
        end
    end

    -- Full Inspector
    if imgui.collapsing_header("Full Inspector##vw_insp") then
        if anim.gameobj then
            pcall(function()
                ControlPanel.managed_object_control_panel(anim.gameobj, "vw_panel")
            end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Scan for viewable objects (things with Motion or Mesh)
-- ═══════════════════════════════════════════════════════════════════════════

function ViewerTab._scan_viewable()
    local results = {}
    local seen = {}

    local types_to_scan = {"via.motion.Motion", "via.render.Mesh"}

    for _, type_name in ipairs(types_to_scan) do
        pcall(function()
            local found = sdk.find_managed_objects(type_name) or {}
            for _, comp in ipairs(found) do
                if #results >= 200 then break end
                pcall(function()
                    local go = comp:call("get_GameObject()")
                    if not go then return end
                    local addr = go:get_address()
                    if seen[addr] then return end
                    seen[addr] = true

                    local xform = go:call("get_Transform()")
                    if not xform then return end

                    local anim_obj = GameObjectSystem.get_anim_object(xform)
                    if anim_obj then
                        results[#results + 1] = {
                            name     = anim_obj.name or "?",
                            anim_obj = anim_obj,
                        }
                    end
                end)
            end
        end)
    end

    -- Sort alphabetically
    table.sort(results, function(a, b) return (a.name or "") < (b.name or "") end)
    state.scan_results = results
end

return ViewerTab
