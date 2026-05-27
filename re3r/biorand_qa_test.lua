-- Biorand RE3R Trainer QA Test Runner
-- Programmatically dry-runs all UI draw and callback functions

print("==================================================")
print("Biorand RE3R Trainer QA Test Runner Starting...")
print("==================================================")

-- Vector mocks
Vector2f = {
    new = function(x, y) return { x = x or 0, y = y or 0 } end
}
Vector3f = {
    new = function(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end
}
Vector4f = {
    new = function(x, y, z, w) return { x = x or 0, y = y or 0, z = z or 0, w = w or 0 } end
}

-- reframework mock
reframework = {
    get_game_name = function() return "re3" end,
    is_key_down = function(self, vk) return false end
}

-- json mock
json = {
    dump_string = function(t) return "{}" end,
    load_string = function(s) return {} end
}

-- log mock
log = {
    info = function(s) print("[INFO] " .. tostring(s)) end,
    warn = function(s) print("[WARN] " .. tostring(s)) end,
    error = function(s) print("[ERROR] " .. tostring(s)) end,
    debug = function(s) print("[DEBUG] " .. tostring(s)) end
}

-- re callback registry
local callbacks = {
    draw_ui = nil,
    frame = nil,
    script_reset = nil,
    config_save = nil,
    app_entry = {}
}

re = {
    on_draw_ui = function(cb) callbacks.draw_ui = cb end,
    on_frame = function(cb) callbacks.frame = cb end,
    on_script_reset = function(cb) callbacks.script_reset = cb end,
    on_config_save = function(cb) callbacks.config_save = cb end,
    on_application_entry = function(name, cb) callbacks.app_entry[name] = cb end
}

-- sdk mock
local mock_object = {}
function mock_object:call(method, ...)
    if method == "get_DrawSelf" then return true end
    if method == "get_GameObject" then return mock_object end
    if method == "get_Parent" then return nil end
    if method == "get_Transform" then return mock_object end
    if method == "get_ChildCount" then return 0 end
    if method == "get_Child" then return nil end
    if method == "get_Next" then return nil end
    if method == "get_Position" then return Vector3f.new(1, 2, 3) end
    if method == "get_LocalPosition" then return Vector3f.new(0, 0, 0) end
    if method == "get_LocalRotation" then return Vector4f.new(0, 0, 0, 1) end
    if method == "get_LocalScale" then return Vector3f.new(1, 1, 1) end
    return nil
end
function mock_object:get_type_definition()
    return {
        get_full_name = function() return "MockType" end,
        get_name = function() return "MockType" end,
        get_fields = function() return {} end
    }
end

sdk = {
    find_type_definition = function(name)
        return {
            get_method = function(self, mname) return {} end
        }
    end,
    get_native_singleton = function(name) return mock_object end,
    typeof = function(name) return {} end,
    get_managed_singleton = function(name) return mock_object end,
    call_native_func = function(obj, td, name, ...)
        if name == "get_MainView" then return mock_object end
        if name == "get_WindowSize" then return { w = 1920, h = 1080 } end
        return mock_object
    end
}

-- d2d mock
d2d = {
    Font = {
        new = function(name, size, bold) return {} end
    },
    register = function(on_draw, on_init) end
}

-- ImGui Mock builder
local function create_imgui_mock(has_child_funcs)
    local imgui_mock = {
        checkbox = function(label, active) return true, not active end,
        button = function(label) return true end,
        small_button = function(label) return true end,
        text = function(text) end,
        text_colored = function(text, color) end,
        separator = function() end,
        spacing = function() end,
        same_line = function() end,
        begin_window = function(name, open, flags) return true end,
        end_window = function() end,
        begin_group = function() end,
        end_group = function() end,
        tree_node = function(label) return true end,
        tree_pop = function() end,
        input_text = function(label, text, size) return true, text end,
        drag_float = function(label, val, speed, min, max, fmt) return true, val end,
        drag_int = function(label, val, speed, min, max) return true, val end,
        begin_table = function(id, cols, flags, size, outer_size) return true end,
        end_table = function() end,
        table_setup_column = function(name, flags, init_width, user_id) end,
        table_headers_row = function() end,
        table_next_row = function() end,
        table_next_column = function() end,
        set_clipboard_text = function(text) end,
        set_next_window_size = function(size, cond) end,
        set_next_item_open = function(open, cond) end,
        push_item_width = function(w) end,
        pop_item_width = function() end,
        push_style_color = function(idx, col) end,
        pop_style_color = function(count) end,
        get_window_size = function() return { x = 1000, y = 600 } end
    }

    if has_child_funcs then
        imgui_mock.begin_child = function(id, size, border) return true end
        imgui_mock.end_child = function() end
    end

    return imgui_mock
end

-- Function to run the QA validation loop
local function run_test_suite(imgui_instance, mode_name)
    print("\n--- Running test suite under Mode: " .. mode_name .. " ---")
    imgui = imgui_instance

    -- Call script reset to initialize state
    if callbacks.script_reset then
        local ok, err = pcall(callbacks.script_reset)
        if not ok then
            error("script_reset crashed: " .. tostring(err))
        end
    end

    -- Inject some mock data to exercise the UI paths
    state.enemies = {
        { go_name = "Zombie", dist = 5, active = true, dead = false }
    }
    state.spawn_groups = {
        { bt_state = "Spawned", all_dead = false, is_vanished = false, is_spawned = true }
    }
    state.items = {
        { go_name = "Handgun Ammo", dist = 10, active = true }
    }
    state.objects = {
        { go_name = "Gimmick_Box", dist = 2, active = true, go_guid = "MOCK_GUID_1", tags = {"BOX"} }
    }
    state.dev.map_id = 12

    -- Loop through each tab in the trainer
    for tab_idx = 1, #TABS do
        local tab = TABS[tab_idx]
        print("Exercising Tab: " .. tab.name)
        state.ui_tab = tab_idx

        -- Trigger UI Draw Callback
        if callbacks.draw_ui then
            local ok, err = pcall(callbacks.draw_ui)
            if not ok then
                error("draw_ui crashed on tab " .. tab.name .. ": " .. tostring(err))
            end
        end
    end

    -- Exercise Selected Object Inspector
    print("Exercising Selected Object Inspector (Enemy)...")
    state.sel_type = "enemy"
    state.sel_data = state.enemies[1]
    if callbacks.draw_ui then
        local ok, err = pcall(callbacks.draw_ui)
        if not ok then
            error("draw_ui crashed with selected enemy: " .. tostring(err))
        end
    end

    print("Exercising Selected Object Inspector (Generic GameObject)...")
    state.sel_type = "go"
    state.sel_data = state.objects[1]
    -- Mock the live GO reference
    state.objects[1]._go_ref = mock_object
    if callbacks.draw_ui then
        local ok, err = pcall(callbacks.draw_ui)
        if not ok then
            error("draw_ui crashed with selected GameObject: " .. tostring(err))
        end
    end

    -- Exercise Frame Update Callback
    print("Exercising on_frame Callback...")
    if callbacks.frame then
        local ok, err = pcall(callbacks.frame)
        if not ok then
            error("on_frame crashed: " .. tostring(err))
        end
    end

    -- Exercise Config Save Callback
    print("Exercising on_config_save Callback...")
    if callbacks.config_save then
        local ok, err = pcall(callbacks.config_save)
        if not ok then
            error("on_config_save crashed: " .. tostring(err))
        end
    end
end

-- Load the actual trainer script in memory and make local 'state' and 'TABS' global
local trainer_file = "E:\\Projects\\Mods\\Biorand\\re3r\\lua\\re3r\\biorand_re3r_trainer.lua"
local f = io.open(trainer_file, "r")
if not f then
    error("Failed to open trainer file: " .. trainer_file)
end
local content = f:read("*all")
f:close()

content = content:gsub("local state = {", "state = {")
content = content:gsub("local TABS%s*%-%-%s*forward declaration", "TABS = nil -- forward declaration")

local chunk, err = (load or loadstring)(content, trainer_file)
if not chunk then
    error("Failed to compile trainer script in memory: " .. tostring(err))
end

-- Execute top-level script loading with default full ImGui mocks
imgui = create_imgui_mock(true)
local ok, err = pcall(chunk)
if not ok then
    error("Crashed during top-level trainer load: " .. tostring(err))
end

-- Run Scenario A (Full support)
run_test_suite(create_imgui_mock(true), "SCENARIO A (Full ImGui Support)")

-- Run Scenario B (Degraded support - no begin_child/end_child!)
run_test_suite(create_imgui_mock(false), "SCENARIO B (Degraded Older ImGui Support)")

print("\n==================================================")
print("All QA checks passed successfully under both scenarios!")
print("==================================================")
