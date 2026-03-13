--[[
    spawner_tab.lua — Spawner Tab UI
    EMV Engine Module (Phase 4)

    Spawn objects from prefab paths or create empty GameObjects.
]]

local SpawnerTab = {}
local CoreFunctions, GameObjectSystem, ImguiHelpers

function SpawnerTab.setup(deps)
    CoreFunctions = deps.CoreFunctions; GameObjectSystem = deps.GameObjectSystem; ImguiHelpers = deps.ImguiHelpers
end

local state = {
    pfb_path     = "",
    spawn_name   = "EMV_Object",
    spawn_pos    = {x = 0, y = 0, z = 0},
    use_camera   = true,
    comp_input   = "",
    components   = {},
    log_messages = {},
}

local function add_log(msg)
    state.log_messages[#state.log_messages + 1] = {text = msg, time = os.clock()}
    while #state.log_messages > 20 do table.remove(state.log_messages, 1) end
end

function SpawnerTab.render()
    -- ═══════════════════════════════════════════════════════════════════════
    -- Spawn from Prefab
    -- ═══════════════════════════════════════════════════════════════════════
    imgui.text_colored("Spawn from Prefab", 0xFF44FF88)
    imgui.separator()

    local pc, np = imgui.input_text("PFB Path##pfb_path", state.pfb_path, 512)
    if pc then state.pfb_path = np end
    imgui.text_colored("Example: enemy/em0000/prefab/em0000.pfb", 0xFF888888)

    imgui.spacing()
    local cc, cv = imgui.checkbox("Spawn at Camera##use_cam", state.use_camera)
    if cc then state.use_camera = cv end

    if not state.use_camera then
        local xc, nx = imgui.drag_float("X##sp_x", state.spawn_pos.x, 0.1)
        if xc then state.spawn_pos.x = nx end
        imgui.same_line()
        local yc, ny = imgui.drag_float("Y##sp_y", state.spawn_pos.y, 0.1)
        if yc then state.spawn_pos.y = ny end
        imgui.same_line()
        local zc, nz = imgui.drag_float("Z##sp_z", state.spawn_pos.z, 0.1)
        if zc then state.spawn_pos.z = nz end
    end

    imgui.spacing()
    if imgui.button("Spawn Prefab##sp_pfb", 200, 30) then
        if state.pfb_path ~= "" then
            local pos = SpawnerTab._get_spawn_pos()
            local ok, err = pcall(function()
                local go = GameObjectSystem.spawn_gameobj(state.pfb_path, pos)
                if go then
                    add_log("Spawned: " .. state.pfb_path)
                else
                    add_log("FAILED: Could not spawn " .. state.pfb_path)
                end
            end)
            if not ok then add_log("ERROR: " .. tostring(err)) end
        else
            add_log("Enter a prefab path first")
        end
    end

    imgui.spacing()
    imgui.spacing()

    -- ═══════════════════════════════════════════════════════════════════════
    -- Create Empty GameObject
    -- ═══════════════════════════════════════════════════════════════════════
    imgui.text_colored("Create Empty GameObject", 0xFF44FF88)
    imgui.separator()

    local nc, nn = imgui.input_text("Name##go_name", state.spawn_name, 128)
    if nc then state.spawn_name = nn end

    -- Component list
    local ci, cn = imgui.input_text("Add Component##comp_add", state.comp_input, 256)
    if ci then state.comp_input = cn end
    imgui.same_line()
    if imgui.small_button("+##add_comp") and state.comp_input ~= "" then
        state.components[#state.components + 1] = state.comp_input
        state.comp_input = ""
    end

    if #state.components > 0 then
        imgui.text_colored("Components to add:", 0xFFAADDFF)
        local to_remove = nil
        for i, comp_name in ipairs(state.components) do
            imgui.text("  " .. comp_name)
            imgui.same_line()
            if imgui.small_button("x##rm_" .. i) then to_remove = i end
        end
        if to_remove then table.remove(state.components, to_remove) end
    end

    imgui.spacing()
    if imgui.button("Create##sp_empty", 200, 30) then
        local pos = SpawnerTab._get_spawn_pos()
        local ok, err = pcall(function()
            local go, xform = GameObjectSystem.create_gameobj(
                state.spawn_name, state.components, {position = pos}
            )
            if go then
                add_log("Created: " .. state.spawn_name)
            else
                add_log("FAILED: Could not create " .. state.spawn_name)
            end
        end)
        if not ok then add_log("ERROR: " .. tostring(err)) end
    end

    imgui.spacing()
    imgui.spacing()

    -- ═══════════════════════════════════════════════════════════════════════
    -- Spawned Objects List
    -- ═══════════════════════════════════════════════════════════════════════
    imgui.text_colored("Active Spawned Objects", 0xFF44FF88)
    imgui.separator()

    local spawned = GameObjectSystem and GameObjectSystem.spawned_objects or {}
    local count, to_del = 0, nil
    for name, entry in pairs(spawned) do
        count = count + 1
        local valid = entry.gameobj and pcall(function() return sdk.is_managed_object(entry.gameobj) end)
        if valid then
            imgui.text_colored("  " .. name, 0xFF00FF88)
            imgui.same_line()
            if imgui.small_button("Delete##del_" .. name) then to_del = name end
        else
            imgui.text_colored("  " .. name .. " (invalid)", 0xFF666666)
        end
    end
    if to_del then
        GameObjectSystem.delete_spawned(to_del)
        add_log("Deleted: " .. to_del)
    end
    if count == 0 then imgui.text_colored("  (none)", 0xFF888888) end

    -- ═══════════════════════════════════════════════════════════════════════
    -- Log
    -- ═══════════════════════════════════════════════════════════════════════
    imgui.spacing()
    imgui.separator()
    imgui.text_colored("Log", 0xFF888888)
    local now = os.clock()
    for i = #state.log_messages, math.max(1, #state.log_messages - 5), -1 do
        local msg = state.log_messages[i]
        if msg then
            local age = now - msg.time
            local color = age < 2 and 0xFFFFFFFF or 0xFF888888
            imgui.text_colored("  " .. msg.text, color)
        end
    end
end

function SpawnerTab._get_spawn_pos()
    if not state.use_camera then
        return Vector3f.new(state.spawn_pos.x, state.spawn_pos.y, state.spawn_pos.z)
    end
    -- Camera position
    local pos = nil
    pcall(function()
        local view = sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"),
            "get_MainView")
        if view then
            local cam = view:call("get_PrimaryCamera")
            if cam then
                local cgo = cam:call("get_GameObject()")
                if cgo then
                    local cxf = cgo:call("get_Transform()")
                    if cxf then pos = cxf:call("get_Position") end
                end
            end
        end
    end)
    return pos or Vector3f.new(0, 0, 0)
end

return SpawnerTab
