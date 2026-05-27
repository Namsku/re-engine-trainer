-- BioRand object explorer for RE9.
-- Ported from the RE4R BioRand object window and adapted to RE9 types.

---@diagnostic disable: lowercase-global

local LOG_PREFIX = "[BioRandObjectExplorer] "
local CFG_FILE = "biorand_object_explorer.json"
local component_cache = {}

local cfg = {
    show_objects = true,
    show_levelflow_overlay = true,
    show_enemy_spawn_overlay = true,
    auto_refresh = true,
    include_meshes = false,
    precise_mode = false,
    filter = "",
    required_component = "",
    max_distance = 25.0,
    max_results = 40,
    scan_interval = 0.75,
}

local PERSIST_KEYS = {}
for key, _ in pairs(cfg) do
    PERSIST_KEYS[#PERSIST_KEYS + 1] = key
end

local state = {
    items = {},
    levelflows = {},
    levelflow_state_history = {},
    selected = nil,
    selected_key = nil,
    deferred = {},
    key_down = {},
    spawn_index = 0,
    spawned_objects = {},
    pinned_addresses = {},
    force_refresh = true,
    last_scan = 0,
    last_error = nil,
    levelflow_last_scan = 0,
    levelflow_force_refresh = true,
    levelflow_scene_address = 0,
    enemy_spawn_entries = {},
    enemy_spawn_metrics = nil,
    enemy_spawn_recent_despawns = {},
    enemy_spawn_active_by_guid = {},
    enemy_spawn_last_scan = 0,
    enemy_spawn_force_refresh = true,
    enemy_spawn_scene_address = 0,
    enemy_spawn_summary_log = nil,
    status_message = nil,
    status_message_until = 0,
    last_spawned_address = nil,
    spawn_template = nil,
    warned_gizmo = false,
    scene_address = 0,
}

local transform_td = sdk.find_type_definition("via.Transform")
local game_object_td = sdk.find_type_definition("via.GameObject")
local game_object_create_method = game_object_td and game_object_td:get_method("create(System.String)")
local set_position_method = transform_td and transform_td:get_method("set_Position")
local set_rotation_method = transform_td and transform_td:get_method("set_Rotation")
local set_local_position_method = transform_td and transform_td:get_method("set_LocalPosition")
local set_local_euler_method = transform_td and transform_td:get_method("set_LocalEulerAngle")
local scene_manager = sdk.get_native_singleton("via.SceneManager")
local scene_manager_td = sdk.find_type_definition("via.SceneManager")
local scene_td = sdk.find_type_definition("via.Scene")
local mesh_td = sdk.find_type_definition("via.render.Mesh")
local mesh_rt = sdk.typeof("via.render.Mesh")
local rigidbody_set_rt = sdk.typeof("via.dynamics.RigidBodySet")
local colliders_rt = sdk.typeof("via.physics.Colliders")
local character_controller_rt = sdk.typeof("via.physics.CharacterController")
local gimmick_dynamic_prefab_controller_rt = sdk.typeof("app.GimmickDynamicPrefabController")
local dynamics_prop_object_rt = sdk.typeof("app.DynamicsPropObject")
local level_flow_controller_td = sdk.find_type_definition("app.LevelFlowController")
local level_flow_controller_rt = level_flow_controller_td and level_flow_controller_td:get_runtime_type()
local behavior_tree_rt = sdk.typeof("via.behaviortree.BehaviorTree")
local message_td = sdk.find_type_definition("via.gui.message")
local message_get_method = message_td and message_td:get_method("get")
local LEVELFLOW_SCAN_INTERVAL = 0.25
local LEVELFLOW_HIGHLIGHT_WINDOW = 5.0
local LEVELFLOW_NAME_MAX_CHARS = 36
local ENEMY_SPAWN_SCAN_INTERVAL = 0.25
local ENEMY_SPAWN_RECENT_DESPAWN_WINDOW = 30.0
local ENEMY_SPAWN_OVERLAY_LIMIT = 10
local ENEMY_SPAWN_NAME_MAX_CHARS = 44
local ENEMY_POOL_NAME_MAX_CHARS = 24
local ENEMY_LABEL_MAX_CHARS = 22

local ENEMY_NAMES = {
    cp_B000 = "Zombie",
    cp_B001 = "Nurse",
    cp_B002 = "Chef",
    cp_B003 = "Singers",
    cp_B004 = "Cleaner",
    cp_B006 = "Silent",
    cp_B007 = "Lighter",
    cp_B050 = "Ghoul",
    cp_B051 = "Chainsaw Man",
    cp_B052 = "Blister",
    cp_B053 = "Harpon",
    cp_B060 = "Zombie",
    cp_B070 = "Zombie",
    cp_B600 = "Licker",
    cp_B700 = "Titan Spinner",
    cp_C100 = "Chunk",
    cp_C600 = "Elite Guards",
    cp_6010 = "The Commander",
    cp_C700 = "Spider",
    cp_B800 = "The Girl",
    cp_B801 = "The Girl",
    cp_B802 = "The Girl",
    cp_B803 = "The Girl",
    cp_B804 = "The Girl",
    cp_B805 = "The Girl",
}

local apply_position
local apply_local_euler
local destroy_game_object
local overlay_font_regular
local overlay_font_bold

local function log_info(message)
    if log and log.info then
        log.info(LOG_PREFIX .. message)
    end
end

local function log_warn(message)
    if log and log.warn then
        log.warn(LOG_PREFIX .. message)
    end
end

local function log_debug(message)
    if log and log.debug then
        log.debug(LOG_PREFIX .. message)
    end
end

local function log_error(message)
    if log and log.error then
        log.error(LOG_PREFIX .. message)
    end
    state.last_error = tostring(message)
end

local function show_status_message(message)
    state.status_message = tostring(message)
    state.status_message_until = os.clock() + 3.0
end

local function cfg_load()
    if not json then
        return
    end

    local data = nil
    local ok, err = pcall(function()
        data = json.load_file(CFG_FILE)
    end)
    if not ok then
        log_warn("Config load failed: " .. tostring(err))
        return
    end
    if type(data) ~= "table" then
        return
    end

    for _, key in ipairs(PERSIST_KEYS) do
        if data[key] ~= nil and type(data[key]) == type(cfg[key]) then
            cfg[key] = data[key]
        end
    end
end

local function cfg_save()
    if not json then
        return
    end

    local data = {}
    for _, key in ipairs(PERSIST_KEYS) do
        data[key] = cfg[key]
    end

    local ok, err = pcall(json.dump_file, CFG_FILE, data)
    if not ok then
        log_warn("Config save failed: " .. tostring(err))
    end
end

local function defer(callback)
    state.deferred[#state.deferred + 1] = callback
end

local function process_deferred()
    if #state.deferred == 0 then
        return
    end

    local queue = state.deferred
    state.deferred = {}
    for _, callback in ipairs(queue) do
        local ok, err = pcall(callback)
        if not ok then
            log_warn("Deferred update failed: " .. tostring(err))
        end
    end
end

local function is_key_down(vk)
    if not vk or vk == 0 then
        return false
    end

    local ok, down = pcall(function()
        return reframework:is_key_down(vk)
    end)
    return ok and down
end

local function key_just_pressed(name, vk)
    local down = is_key_down(vk)
    local was_down = state.key_down[name] == true
    state.key_down[name] = down
    return down and not was_down
end

local function any_key_just_pressed(name, keys)
    local down = false
    for _, vk in ipairs(keys) do
        if is_key_down(vk) then
            down = true
            break
        end
    end

    local was_down = state.key_down[name] == true
    state.key_down[name] = down
    return down and not was_down
end

local function vec_add(a, b)
    return Vector3f.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function vec_scale(v, scalar)
    return Vector3f.new(v.x * scalar, v.y * scalar, v.z * scalar)
end

local function vec_normalize_flat(v, fallback)
    if not v then
        return fallback
    end

    local x = v.x or 0
    local z = v.z or 0
    local magnitude = math.sqrt(x * x + z * z)
    if magnitude < 0.0001 then
        return fallback
    end
    return Vector3f.new(x / magnitude, 0, z / magnitude)
end

local function normalize_display_number(value, epsilon)
    local n = tonumber(value) or 0
    local limit = epsilon or 0.005
    if math.abs(n) < limit then
        return 0
    end
    return n
end

local function format_triplet(x, y, z)
    return string.format(
        "%.2f, %.2f, %.2f",
        normalize_display_number(x),
        normalize_display_number(y),
        normalize_display_number(z))
end

local function is_main_levelflow_name(name)
    return name == "Main" or (name and name:find("_Main", 1, true) ~= nil)
end

local function clamp_overlay_name(name)
    local text = tostring(name or "?")
    if #text <= LEVELFLOW_NAME_MAX_CHARS then
        return text
    end
    return text:sub(1, LEVELFLOW_NAME_MAX_CHARS - 3) .. "..."
end

local function clamp_text(text, max_chars)
    local value = tostring(text or "")
    local limit = math.max(4, tonumber(max_chars) or 4)
    if #value <= limit then
        return value
    end
    return value:sub(1, limit - 3) .. "..."
end

local function get_level_flow_state_text(game_object)
    if not game_object or not behavior_tree_rt then
        return nil
    end

    local behavior_tree = nil
    pcall(function()
        behavior_tree = game_object:call("getComponent(System.Type)", behavior_tree_rt)
    end)
    if not behavior_tree then
        return nil
    end

    local state_value = nil
    pcall(function()
        state_value = behavior_tree:call("getCurrentNodeName", 0)
    end)
    if state_value == nil then
        return nil
    end

    local text = tostring(state_value)
    if text == "" then
        return nil
    end
    return text
end

local function round_to_step(value, step)
    local n = tonumber(value) or 0
    local s = math.abs(tonumber(step) or 0)
    if s < 0.000001 then
        return n
    end
    if n >= 0 then
        return math.floor((n / s) + 0.5) * s
    end
    return math.ceil((n / s) - 0.5) * s
end

local function get_overlay_font(size, bold)
    if not d2d then
        return nil
    end

    if bold then
        if not overlay_font_bold then
            pcall(function()
                overlay_font_bold = d2d.Font.new("Consolas", size, true)
            end)
        end
        return overlay_font_bold
    end

    if not overlay_font_regular then
        pcall(function()
            overlay_font_regular = d2d.Font.new("Consolas", size, false)
        end)
    end
    return overlay_font_regular
end

local function calculate_yaw_towards(from_position, to_position)
    if not from_position or not to_position then
        return 0
    end

    local dx = (to_position.x or 0) - (from_position.x or 0)
    local dz = (to_position.z or 0) - (from_position.z or 0)
    return math.deg(math.atan(dx, dz))
end

local function is_biorand_name(name)
    return name and name:lower():find("biorand", 1, true) ~= nil
end

local function get_scene()
    if not scene_manager or not scene_manager_td then
        return nil
    end

    local scene = nil
    pcall(function()
        scene = sdk.call_native_func(scene_manager, scene_manager_td, "get_CurrentScene")
    end)
    return scene
end

local function get_window_size()
    if not scene_manager or not scene_manager_td then
        return nil
    end

    local main_view = nil
    pcall(function()
        main_view = sdk.call_native_func(scene_manager, scene_manager_td, "get_MainView")
    end)
    if not main_view then
        return nil
    end

    local size = nil
    pcall(function()
        size = main_view:call("get_WindowSize")
    end)
    return size
end

local function get_transform_position(xf)
    if not xf then
        return nil
    end

    local position = nil
    pcall(function()
        position = xf:call("get_Position")
    end)
    return position
end

local function get_observer_position()
    local position = nil

    pcall(function()
        local character_manager = sdk.get_managed_singleton("app.CharacterManager")
        if not character_manager then
            return
        end

        local player_context = character_manager:call("getPlayerContextRef")
        if not player_context then
            player_context = character_manager:call("get_PlayerContextFast")
        end
        if not player_context then
            return
        end

        local game_object = player_context:call("get_GameObject")
        if not game_object then
            return
        end

        local xf = game_object:call("get_Transform")
        position = get_transform_position(xf)
    end)

    if position then
        return position
    end

    pcall(function()
        local camera = sdk.get_primary_camera()
        if not camera then
            return
        end

        local game_object = camera:call("get_GameObject")
        if not game_object then
            return
        end

        local xf = game_object:call("get_Transform")
        position = get_transform_position(xf)
    end)

    return position
end

local function get_camera_position()
    local position = nil

    pcall(function()
        local camera = sdk.get_primary_camera()
        if not camera then
            return
        end

        local camera_object = camera:call("get_GameObject")
        if not camera_object then
            return
        end

        local xf = camera_object:call("get_Transform")
        position = get_transform_position(xf)
    end)

    return position
end

local function get_camera_basis()
    local right = nil
    local up = nil
    local forward = nil

    pcall(function()
        local camera = sdk.get_primary_camera()
        if not camera then
            return
        end

        local matrix = camera:call("get_WorldMatrix")
        if not matrix then
            return
        end

        local row0 = matrix[0]
        local row1 = matrix[1]
        local row2 = matrix[2]
        if row0 then
            right = Vector3f.new(row0.x, row0.y, row0.z)
        end
        if row1 then
            up = Vector3f.new(row1.x, row1.y, row1.z)
        end
        if row2 then
            forward = Vector3f.new(-row2.x, -row2.y, -row2.z)
        end
    end)

    return right, up, forward
end

local function get_default_placement_position()
    local observer_position = get_camera_position() or get_observer_position() or Vector3f.new(0, 0, 0)
    local _, _, forward = get_camera_basis()
    forward = forward or Vector3f.new(0, 0, 1)
    local spawn_position = vec_add(observer_position, vec_scale(forward, 1.25))
    spawn_position = Vector3f.new(spawn_position.x, spawn_position.y - 0.25, spawn_position.z)
    return observer_position, spawn_position
end

local function snap_placement_position(position)
    if not position then
        return Vector3f.new(0, 0, 0)
    end
    return Vector3f.new(
        normalize_display_number(round_to_step(position.x, 0.1)),
        normalize_display_number(round_to_step(position.y, 0.1)),
        normalize_display_number(round_to_step(position.z, 0.1)))
end

local function snap_placement_yaw(yaw_deg)
    return normalize_display_number(round_to_step(yaw_deg, 22.5))
end

local function distance(a, b)
    if not a or not b then
        return nil
    end

    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function managed_call(obj, method_name, ...)
    if not obj or not method_name then
        return nil
    end

    local ok, result = pcall(obj.call, obj, method_name, ...)
    if ok then
        return result
    end
    return nil
end

local function managed_field(obj, field_name)
    if not obj or not field_name then
        return nil
    end

    local ok, result = pcall(obj.get_field, obj, field_name)
    if ok then
        return result
    end
    return nil
end

local function value_to_text(value)
    if value == nil then
        return nil
    end
    local value_type = type(value)
    if value_type == "string" or value_type == "number" or value_type == "boolean" then
        return tostring(value)
    end

    local text = managed_call(value, "ToString()")
    if text ~= nil then
        return tostring(text)
    end
    return tostring(value)
end

local function context_id_to_guid_text(context_id)
    if not context_id then
        return nil
    end

    local text = value_to_text(context_id)
    if text and text ~= "" then
        return text
    end
    local raw_id = managed_call(context_id, "get_RawID") or managed_field(context_id, "_RawID")
    return value_to_text(raw_id)
end

local function get_game_object_name(game_object, fallback)
    local name = managed_call(game_object, "get_Name")
    if name ~= nil then
        return tostring(name)
    end
    return fallback or "?"
end

local function get_game_object_position(game_object)
    if not game_object then
        return nil
    end

    local xf = managed_call(game_object, "get_Transform")
    if not xf then
        return nil
    end
    return get_transform_position(xf)
end

local function friendly_enemy_name(raw_kind)
    if not raw_kind or raw_kind == "" then
        return "Enemy"
    end
    return ENEMY_NAMES[raw_kind] or raw_kind
end

local function should_include_enemy_spawn(raw_kind, spawn_name)
    if spawn_name and tostring(spawn_name):find("SpawnLevelPlayerCreateController", 1, true) then
        return false
    end
    if not raw_kind or raw_kind == "" then
        return false
    end
    if raw_kind:sub(1, 3) ~= "cp_" then
        return false
    end
    return raw_kind:sub(4, 4) ~= "A"
end

local function format_spawn_hp(entry)
    if entry.hp ~= nil and entry.max_hp ~= nil then
        return string.format("%d/%d", math.ceil(entry.hp), math.ceil(entry.max_hp))
    end
    return "-"
end

local function format_spawn_position(position)
    if not position then
        return "-, -, -"
    end
    return format_triplet(position.x, position.y, position.z)
end

local function read_spawn_control_flags(spawn_control)
    return {
        initial_spawn_permitted = managed_call(spawn_control, "get_InitialSpawnPermitted")
            or managed_field(spawn_control, "_InitialSpawnPermitted") == true,
        has_permitted_spawn = managed_call(spawn_control, "get_HasPermittedSpawn")
            or managed_field(spawn_control, "<HasPermittedSpawn>k__BackingField") == true,
        has_rejected_resume = managed_call(spawn_control, "get_HasRejectedResumeRequest")
            or managed_field(spawn_control, "<HasRejectedResumeRequest>k__BackingField") == true,
        has_completed_spawn = managed_call(spawn_control, "get_HasCompletedSpawn")
            or managed_field(spawn_control, "<HasCompletedSpawn>k__BackingField") == true,
        dead_count = tonumber(managed_call(spawn_control, "get_DeadCount")
            or managed_field(spawn_control, "<DeadCount>k__BackingField")) or 0,
        fall_dead_count = tonumber(managed_call(spawn_control, "get_FallDeadCount")
            or managed_field(spawn_control, "<FallDeadCount>k__BackingField")) or 0,
        requested_spawn = managed_field(spawn_control, "_RequestedSpawn") == true,
        waiting_cutscene_reset = managed_field(spawn_control, "_IsWaitingSpawnForCutSceneReset") == true,
        chapter_init_requested = managed_field(spawn_control, "_IsChapterInitSpawnRequested") == true,
        invalidate_after_suspend = managed_field(spawn_control, "_InvalidateAfterSuspend") == true,
        requested_dead_body_suspend = managed_field(spawn_control, "_RequestedDeadBodySuspend") == true,
        requested_dead_body_resume = managed_field(spawn_control, "_RequestedDeadBodyResume") == true,
    }
end

local function get_enemy_label(raw_kind)
    local friendly_name = friendly_enemy_name(raw_kind)
    if not raw_kind or raw_kind == friendly_name then
        return friendly_name
    end
    return string.format("%s [%s]", friendly_name, raw_kind)
end

local function build_spawn_state_summary(entry)
    local parts = {}
    if entry.active then
        parts[#parts + 1] = "active"
    elseif entry.recently_despawned then
        parts[#parts + 1] = "despawned"
    end
    if entry.has_rejected_resume then
        parts[#parts + 1] = "resume-rejected"
    end
    if entry.waiting_cutscene_reset then
        parts[#parts + 1] = "cutscene-reset"
    end
    if entry.requested_spawn and not entry.has_completed_spawn then
        parts[#parts + 1] = "requested"
    end
    if entry.has_completed_spawn and not entry.active then
        parts[#parts + 1] = "completed"
    end
    if entry.has_permitted_spawn and not entry.active and not entry.has_completed_spawn then
        parts[#parts + 1] = "permitted"
    end
    if entry.initial_spawn_permitted then
        parts[#parts + 1] = "initial"
    end
    if entry.invalidate_after_suspend then
        parts[#parts + 1] = "invalidate-on-suspend"
    end
    if entry.chapter_init_requested then
        parts[#parts + 1] = "chapter-init"
    end
    if entry.requested_dead_body_suspend then
        parts[#parts + 1] = "dead-body-suspend"
    end
    if entry.requested_dead_body_resume then
        parts[#parts + 1] = "dead-body-resume"
    end
    if entry.dead_count > 0 then
        parts[#parts + 1] = string.format("dead=%d", entry.dead_count)
    end
    if entry.fall_dead_count > 0 then
        parts[#parts + 1] = string.format("fall-dead=%d", entry.fall_dead_count)
    end
    if #parts == 0 then
        return "idle"
    end
    return table.concat(parts, ", ")
end

local function build_active_spawn_lookup(character_manager)
    local result = {}
    local active_contexts = managed_call(character_manager, "getSpawnedEnemyContextRefList")
    if not active_contexts then
        active_contexts = managed_call(character_manager, "get_EnemyContextList")
    end
    if not active_contexts then
        return result
    end

    local count = tonumber(managed_call(active_contexts, "get_Count")) or 0
    for index = 0, count - 1 do
        local context = managed_call(active_contexts, "get_Item", index)
        local game_object = context and managed_call(context, "get_GameObject") or nil
        if context and game_object then
            local spawn_data = managed_call(context, "get_SpawnData")
            local spawn_control = spawn_data and managed_call(spawn_data, "get_SpawnControl") or nil
            local spawn_guid = context_id_to_guid_text(managed_call(context, "get_ID"))
                or context_id_to_guid_text(spawn_data and managed_call(spawn_data, "get_ContextID"))
            if spawn_guid then
                local hp_object = managed_call(context, "get_HitPoint")
                local position = managed_call(context, "get_Position") or get_game_object_position(game_object)
                result[spawn_guid] = {
                    guid = spawn_guid,
                    context = context,
                    spawn_data = spawn_data,
                    spawn_control = spawn_control,
                    position = position,
                    hp = tonumber(hp_object and managed_call(hp_object, "get_CurrentHitPoint")) or nil,
                    max_hp = tonumber(hp_object and managed_call(hp_object, "get_CurrentMaximumHitPoint")) or nil,
                    pool_name = get_game_object_name(game_object),
                    raw_kind = value_to_text(managed_call(context, "get_KindID"))
                        or value_to_text(spawn_data and managed_call(spawn_data, "get_KindID")),
                }
            end
        end
    end

    return result
end

local function collect_spawn_data_entries(character_manager)
    local results = {}
    local spawn_db = managed_call(character_manager, "get_CharacterSpawnDataDB")
    if not spawn_db then
        return results
    end

    local entry_array = managed_field(spawn_db, "_entries")
    if not entry_array then
        return results
    end

    local length = tonumber(managed_call(entry_array, "get_Length")) or 0
    for index = 0, length - 1 do
        local slot = managed_call(entry_array, "GetValue", index)
        if slot then
            local spawn_data = managed_field(slot, "value")
            local slot_key = managed_field(slot, "key")
            if spawn_data and slot_key then
                results[#results + 1] = {
                    spawn_data = spawn_data,
                    context_id = slot_key,
                }
            end
        end
    end

    return results
end

local function collect_enemy_pool_metrics(character_manager)
    local metrics = {
        total = 0,
        used = 0,
        spare = 0,
        reserved = 0,
        orphaned = 0,
    }

    local character_pool = managed_call(character_manager, "get_CharacterPool")
    if not character_pool then
        return metrics
    end

    local count = tonumber(managed_call(character_pool, "get_Count")) or 0
    for index = 0, count - 1 do
        local pool_info = managed_call(character_pool, "get_Item", index)
        local updater = pool_info and managed_call(pool_info, "get_Updater") or nil
        local updater_type = updater and updater:get_type_definition() and updater:get_type_definition():get_full_name() or
        ""
        if updater_type ~= "app.Cp_A000Updater" then
            local used = managed_call(pool_info, "get_Used") == true
            local reserved = managed_call(pool_info, "get_Reserved") == true
            local context = updater and managed_call(updater, "get_Context") or nil
            local game_object = context and managed_call(context, "get_GameObject") or nil

            metrics.total = metrics.total + 1
            if used then
                metrics.used = metrics.used + 1
                if not context or not game_object then
                    metrics.orphaned = metrics.orphaned + 1
                end
            elseif reserved then
                metrics.reserved = metrics.reserved + 1
            else
                metrics.spare = metrics.spare + 1
            end
        end
    end

    return metrics
end

local function build_enemy_spawn_entry(spawn_data, context_id, active_lookup, observer_position, despawn_cache, now)
    local spawn_control = managed_call(spawn_data, "get_SpawnControl")
    local spawn_guid = context_id_to_guid_text(context_id or managed_call(spawn_data, "get_ContextID"))
    if not spawn_guid then
        return nil
    end

    local active_entry = active_lookup[spawn_guid]
    local recent_entry = despawn_cache[spawn_guid]
    local spawn_object = spawn_control and managed_call(spawn_control, "get_GameObject") or nil
    local spawn_name = get_game_object_name(spawn_object, nil)
    local spawn_position = get_game_object_position(spawn_object) or managed_call(spawn_data, "get_Position")
    local flags = read_spawn_control_flags(spawn_control)
    local raw_kind = value_to_text(managed_call(spawn_data, "get_KindID"))
        or value_to_text(active_entry and active_entry.raw_kind)
    if not should_include_enemy_spawn(raw_kind, spawn_name) then
        return nil
    end
    local position = active_entry and active_entry.position or spawn_position
    local hp = active_entry and active_entry.hp or nil
    local max_hp = active_entry and active_entry.max_hp or nil
    local pool_name = active_entry and active_entry.pool_name or nil
    local recently_despawned = false

    if recent_entry and (now - recent_entry.despawned_at) <= ENEMY_SPAWN_RECENT_DESPAWN_WINDOW then
        recently_despawned = true
        if not active_entry then
            position = recent_entry.position or position
            hp = recent_entry.hp or hp
            max_hp = recent_entry.max_hp or max_hp
            pool_name = recent_entry.pool_name or pool_name
        end
    end

    return {
        guid = spawn_guid,
        spawn_name = spawn_name or raw_kind or "Spawn",
        raw_kind = raw_kind,
        enemy_label = get_enemy_label(raw_kind),
        position = position,
        spawn_position = spawn_position,
        distance = distance(position or spawn_position, observer_position) or 0,
        hp = hp,
        max_hp = max_hp,
        pool_name = pool_name,
        active = active_entry ~= nil,
        recently_despawned = recently_despawned,
        initial_spawn_permitted = flags.initial_spawn_permitted,
        has_permitted_spawn = flags.has_permitted_spawn,
        has_rejected_resume = flags.has_rejected_resume,
        has_completed_spawn = flags.has_completed_spawn,
        dead_count = flags.dead_count,
        fall_dead_count = flags.fall_dead_count,
        requested_spawn = flags.requested_spawn,
        waiting_cutscene_reset = flags.waiting_cutscene_reset,
        chapter_init_requested = flags.chapter_init_requested,
        invalidate_after_suspend = flags.invalidate_after_suspend,
        requested_dead_body_suspend = flags.requested_dead_body_suspend,
        requested_dead_body_resume = flags.requested_dead_body_resume,
    }
end

local function refresh_enemy_spawn_overlay()
    local now = os.clock()
    local scene = get_scene()
    if not scene then
        state.enemy_spawn_entries = {}
        state.enemy_spawn_metrics = nil
        state.enemy_spawn_recent_despawns = {}
        state.enemy_spawn_active_by_guid = {}
        state.enemy_spawn_last_scan = now
        return
    end

    local scene_address = 0
    pcall(function()
        scene_address = scene:get_address()
    end)
    if state.enemy_spawn_scene_address ~= scene_address then
        state.enemy_spawn_scene_address = scene_address
        state.enemy_spawn_recent_despawns = {}
        state.enemy_spawn_active_by_guid = {}
        log_debug("Enemy spawn overlay scene changed; cleared cached spawn state.")
    end

    local character_manager = sdk.get_managed_singleton("app.CharacterManager")
    if not character_manager then
        state.enemy_spawn_entries = {}
        state.enemy_spawn_metrics = nil
        state.enemy_spawn_last_scan = now
        return
    end

    local observer_position = get_observer_position()
    local active_lookup = build_active_spawn_lookup(character_manager)
    local previous_active = state.enemy_spawn_active_by_guid or {}
    local despawn_cache = state.enemy_spawn_recent_despawns or {}

    for guid, entry in pairs(previous_active) do
        if not active_lookup[guid] then
            despawn_cache[guid] = {
                despawned_at = now,
                position = entry.position,
                hp = entry.hp,
                max_hp = entry.max_hp,
                pool_name = entry.pool_name,
            }
        end
    end

    for guid, _ in pairs(active_lookup) do
        despawn_cache[guid] = nil
    end

    for guid, entry in pairs(despawn_cache) do
        if not entry or (now - entry.despawned_at) > ENEMY_SPAWN_RECENT_DESPAWN_WINDOW then
            despawn_cache[guid] = nil
        end
    end

    local items = {}
    local seen_guids = {}
    for _, spawn_entry in ipairs(collect_spawn_data_entries(character_manager)) do
        local item = build_enemy_spawn_entry(
            spawn_entry.spawn_data,
            spawn_entry.context_id,
            active_lookup,
            observer_position,
            despawn_cache,
            now)
        if item then
            seen_guids[item.guid] = true
            items[#items + 1] = item
        end
    end

    for guid, active_entry in pairs(active_lookup) do
        if not seen_guids[guid] and active_entry.spawn_data then
            local item = build_enemy_spawn_entry(
                active_entry.spawn_data,
                managed_call(active_entry.spawn_data, "get_ContextID"),
                active_lookup,
                observer_position,
                despawn_cache,
                now)
            if item then
                items[#items + 1] = item
            end
        end
    end

    table.sort(items, function(a, b)
        if a.distance == b.distance then
            return tostring(a.spawn_name or "") < tostring(b.spawn_name or "")
        end
        return a.distance < b.distance
    end)

    local metrics = {
        total_spawns = #items,
        active_spawns = 0,
        inactive_spawns = 0,
        recent_despawns = 0,
        rejected_resume = 0,
        requested = 0,
        completed = 0,
        permitted = 0,
        waiting_cutscene = 0,
        pool = collect_enemy_pool_metrics(character_manager),
    }

    for _, item in ipairs(items) do
        if item.active then
            metrics.active_spawns = metrics.active_spawns + 1
        else
            metrics.inactive_spawns = metrics.inactive_spawns + 1
        end
        if item.recently_despawned then
            metrics.recent_despawns = metrics.recent_despawns + 1
        end
        if item.has_rejected_resume then
            metrics.rejected_resume = metrics.rejected_resume + 1
        end
        if item.requested_spawn then
            metrics.requested = metrics.requested + 1
        end
        if item.has_completed_spawn then
            metrics.completed = metrics.completed + 1
        end
        if item.has_permitted_spawn then
            metrics.permitted = metrics.permitted + 1
        end
        if item.waiting_cutscene_reset then
            metrics.waiting_cutscene = metrics.waiting_cutscene + 1
        end
    end

    local summary_log = string.format(
        "Enemy spawn overlay: spawns=%d active=%d inactive=%d pool_spare=%d pool_used=%d pool_orphaned=%d rejected=%d requested=%d completed=%d",
        metrics.total_spawns,
        metrics.active_spawns,
        metrics.inactive_spawns,
        metrics.pool.spare,
        metrics.pool.used,
        metrics.pool.orphaned,
        metrics.rejected_resume,
        metrics.requested,
        metrics.completed)
    if state.enemy_spawn_summary_log ~= summary_log then
        state.enemy_spawn_summary_log = summary_log
        log_debug(summary_log)
    end

    state.enemy_spawn_entries = items
    state.enemy_spawn_metrics = metrics
    state.enemy_spawn_recent_despawns = despawn_cache
    state.enemy_spawn_active_by_guid = active_lookup
    state.enemy_spawn_last_scan = now
end

local function maybe_refresh_enemy_spawn_overlay()
    if not cfg.show_enemy_spawn_overlay then
        return
    end

    if state.enemy_spawn_force_refresh then
        state.enemy_spawn_force_refresh = false
        refresh_enemy_spawn_overlay()
        return
    end

    if (os.clock() - state.enemy_spawn_last_scan) >= ENEMY_SPAWN_SCAN_INTERVAL then
        refresh_enemy_spawn_overlay()
    end
end

local function copy_to_clipboard(text)
    if not text or text == "" then
        return false
    end

    local copied = false
    pcall(function()
        if sdk and sdk.copy_to_clipboard then
            sdk.copy_to_clipboard(text)
            copied = true
        end
    end)
    if copied then
        return true
    end

    pcall(function()
        if imgui and imgui.set_clipboard then
            imgui.set_clipboard(text)
            copied = true
        end
    end)
    return copied
end

local function extract_guid(go)
    if not go then
        return ""
    end

    local guid = ""
    pcall(function()
        local text = go:call("ToString()")
        if text then
            guid = tostring(text):match("@([%x%-]+)%]$") or ""
        end
    end)
    return guid
end

local function get_component_names(go)
    local address = 0
    pcall(function()
        address = go:get_address()
    end)
    if address ~= 0 and component_cache[address] then
        return component_cache[address]
    end

    local names = {}
    local seen = {}

    pcall(function()
        local components = go:call("get_Components")
        if not components then
            return
        end

        local elements = components:get_elements()
        if not elements then
            return
        end

        for _, component in ipairs(elements) do
            if not component then
                goto continue
            end

            local td = component:get_type_definition()
            if not td then
                goto continue
            end

            local name = td:get_full_name()
            if name and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end

            ::continue::
        end
    end)

    if #names == 0 then
        local count = 0
        pcall(function()
            count = go:call("get_ComponentCount") or 0
        end)

        for i = 0, math.min(count - 1, 31) do
            pcall(function()
                local component = go:call("getComponent(System.Int32)", i)
                if not component then
                    return
                end

                local td = component:get_type_definition()
                if not td then
                    return
                end

                local name = td:get_full_name()
                if name and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end)
        end
    end

    if address ~= 0 then
        component_cache[address] = names
    end
    return names
end

local function get_component(go, component_type)
    if not go or not component_type then
        return nil
    end

    local component = nil
    pcall(function()
        component = go:call("getComponent(System.Type)", component_type)
    end)
    return component
end

local EXCLUDED_GIMMICK_COMPONENTS = {
    ["app.GmSituationInteractable"] = true,
    ["app.GmMotionV2"] = true,
}

local function classify_object(name, component_names)
    local include = false
    local kind = nil

    for _, component_name in ipairs(component_names) do
        if component_name == "app.ItemCore" then
            include = true
            kind = kind or "Item"
        elseif component_name == "app.ItemSpawner" then
            include = true
            kind = kind or "Spawner"
        elseif component_name == "app.GimmickCore" then
            include = true
            if not kind or kind == "Gimmick" then
                kind = "Gimmick"
            end
        elseif component_name:match("^app%.Gm") then
            include = true
            if not EXCLUDED_GIMMICK_COMPONENTS[component_name] then
                kind = component_name:gsub("^app%.", "")
            else
                if not kind or kind == "Gimmick" then
                    kind = "Gimmick"
                end
            end
        elseif cfg.include_meshes and component_name == "via.render.Mesh" then
            include = true
            kind = kind or "Mesh"
        elseif cfg.include_meshes and component_name == "via.render.Light" then
            include = true
            kind = kind or "Light"
        elseif cfg.include_meshes and component_name == "via.Camera" then
            include = true
            kind = kind or "Camera"
        end
    end

    if not include and name and name:sub(1, 2) == "Gm" then
        include = true
        if not kind or kind == "Gimmick" then
            kind = "Gimmick"
        end
    end

    if not include and is_biorand_name(name) then
        include = true
        kind = kind or "PlacedMesh"
    end

    return include, kind or "Object"
end

local function matches_filter(entry)
    local filter = cfg.filter
    if not filter or filter == "" then
        return true
    end

    local query = filter:lower()
    return entry.name:lower():find(query, 1, true)
        or entry.kind:lower():find(query, 1, true)
        or entry.guid:lower():find(query, 1, true)
        or entry.components:lower():find(query, 1, true)
end

local function matches_required_component(entry)
    local required_component = cfg.required_component
    if not required_component or required_component == "" then
        return true
    end

    return entry.components:lower():find(required_component:lower(), 1, true)
end

local function build_entry(go, xf, observer_position, options)
    options = options or {}
    if not go or not xf then
        return nil
    end

    local address = 0
    pcall(function()
        address = go:get_address()
    end)
    if address == 0 then
        return nil
    end

    local position = get_transform_position(xf)
    if not position then
        return nil
    end

    local object_name = "?"
    pcall(function()
        object_name = tostring(go:call("get_Name") or "?")
    end)

    local component_names = get_component_names(go)
    for _, hint in ipairs(options.component_hints or {}) do
        component_names[#component_names + 1] = hint
    end
    local include, kind = classify_object(object_name, component_names)
    local component_blob = table.concat(component_names, " ")
    if cfg.required_component ~= "" and component_blob:lower():find(cfg.required_component:lower(), 1, true) then
        include = true
    end
    if options.force_include then
        include = true
    end
    if not include then
        return nil
    end

    if options.kind then
        kind = options.kind
    end

    if options.display_name and options.display_name ~= "" then
        object_name = options.display_name .. " (" .. object_name .. ")"
    end

    local is_biorand_object = is_biorand_name(object_name)
    local object_distance = distance(position, observer_position) or 0
    if not options.ignore_distance and not is_biorand_object and cfg.max_distance > 0 and object_distance > cfg.max_distance then
        return nil
    end

    local entry = {
        key = string.format("%X", address),
        address = address,
        game_object = go,
        transform = xf,
        name = object_name,
        kind = kind,
        source = options.source or "Scene",
        guid = extract_guid(go),
        x = position.x,
        y = position.y,
        z = position.z,
        distance = object_distance,
        components = component_blob,
    }

    if not matches_filter(entry) then
        return nil
    end
    if not matches_required_component(entry) then
        return nil
    end

    return entry
end

local function append_item_entries(items, seen, observer_position)
    local item_manager = sdk.get_managed_singleton("app.ItemManager")
    if not item_manager then
        return
    end

    local validate_items = item_manager:get_field("_ValidateCheckItems")
    if not validate_items then
        return
    end

    local count = 0
    pcall(function()
        count = validate_items:call("get_Count") or 0
    end)

    for i = 0, math.min(count - 1, 500) do
        pcall(function()
            local item = validate_items:call("get_Item", i)
            if not item then
                return
            end

            local go = item:call("get_GameObject")
            if not go then
                return
            end

            local address = go:get_address()
            if seen[address] then
                return
            end

            local xf = go:call("get_Transform")
            if not xf then
                return
            end

            local display_name = nil
            pcall(function()
                local item_id = item:call("get_ItemID")
                if not item_id then
                    return
                end

                local catalog = item_manager:get_field("_ItemCatalog")
                if not catalog then
                    return
                end

                local detail = catalog:call("getValue", item_id, nil)
                if not detail then
                    return
                end

                local message_id = detail:get_field("_NameMessageId")
                if not message_id or not message_get_method then
                    return
                end

                local text = message_get_method:call(nil, message_id)
                if text then
                    display_name = tostring(text):gsub("<[^>]+>", "")
                end
            end)

            local entry = build_entry(go, xf, observer_position, {
                force_include = true,
                kind = "Item",
                display_name = display_name,
                component_hints = { "app.ItemCore" },
                source = "ItemManager",
            })
            if entry then
                seen[address] = true
                items[#items + 1] = entry
            end
        end)
    end
end

local function append_gimmick_entries(items, seen, observer_position)
    local gimmick_manager = sdk.get_managed_singleton("app.GimmickManager")
    if not gimmick_manager then
        return
    end

    local gimmick_db = gimmick_manager:get_field("_GimmickCoreDB")
    if not gimmick_db then
        return
    end

    local entries = gimmick_db:get_field("_entries")
    if not entries then
        return
    end

    local size = 0
    pcall(function()
        size = entries:call("get_size") or 0
    end)

    for i = 0, math.min(size - 1, 500) do
        pcall(function()
            local entry_data = entries:call("get_element", i)
            if not entry_data then
                return
            end

            local core = entry_data:get_field("value")
            if not core then
                return
            end

            local go = core:call("get_GameObject")
            if not go then
                return
            end

            local address = go:get_address()
            if seen[address] then
                return
            end

            local xf = go:call("get_Transform")
            if not xf then
                return
            end

            local entry = build_entry(go, xf, observer_position, {
                force_include = true,
                component_hints = { "app.GimmickCore" },
                source = "GimmickManager",
            })
            if entry then
                local is_done = nil
                pcall(function()
                    is_done = core:get_field("_IsDone")
                end)
                if is_done then
                    entry.name = entry.name .. " [DONE]"
                end
                seen[address] = true
                items[#items + 1] = entry
            end
        end)
    end
end

local function append_spawned_entries(items, seen, observer_position)
    for address, spawned in pairs(state.spawned_objects) do
        local go = spawned.game_object
        if not go or not sdk.is_managed_object(go) then
            state.spawned_objects[address] = nil
            state.pinned_addresses[address] = nil
            if state.last_spawned_address == address then
                state.last_spawned_address = nil
            end
        else
            local xf = nil
            pcall(function()
                xf = go:call("get_Transform")
            end)
            if not xf then
                state.spawned_objects[address] = nil
                state.pinned_addresses[address] = nil
                if state.last_spawned_address == address then
                    state.last_spawned_address = nil
                end
            elseif not seen[address] then
                local entry = build_entry(go, xf, observer_position, {
                    force_include = true,
                    ignore_distance = true,
                    kind = spawned.kind or "PlacedMesh",
                    source = spawned.source or "Spawned",
                    display_name = spawned.display_name or "Placed Mesh",
                })
                if entry then
                    seen[address] = true
                    items[#items + 1] = entry
                end
            end
        end
    end
end

local function refresh_objects()
    local scene = get_scene()
    if not scene then
        state.items = {}
        state.selected = nil
        state.last_error = "No active scene."
        return
    end

    local observer_position = get_observer_position()
    local items = {}
    local seen = {}
    local transform = nil
    local scene_address = 0

    pcall(function()
        scene_address = scene:get_address()
    end)
    if state.scene_address ~= scene_address then
        component_cache = {}
        state.scene_address = scene_address
        state.spawn_template = nil
    end

    append_item_entries(items, seen, observer_position)
    append_gimmick_entries(items, seen, observer_position)
    append_spawned_entries(items, seen, observer_position)

    pcall(function()
        transform = scene:call("get_FirstTransform")
    end)

    local walked = 0
    while transform and walked < 8000 do
        walked = walked + 1

        pcall(function()
            local go = transform:call("get_GameObject")
            if not go then
                return
            end

            local address = go:get_address()
            if seen[address] then
                return
            end
            seen[address] = true

            local entry = build_entry(go, transform, observer_position)
            if entry then
                if is_biorand_name(entry.name) then
                    state.spawned_objects[address] = {
                        game_object = go,
                        kind = entry.kind or "PlacedMesh",
                        source = "Scene",
                        display_name = entry.name,
                    }
                    state.pinned_addresses[address] = true
                end
                items[#items + 1] = entry
            end
        end)

        local next_transform = nil
        pcall(function()
            next_transform = transform:call("get_Next")
        end)
        transform = next_transform
    end

    table.sort(items, function(a, b)
        local a_pinned = state.pinned_addresses[a.address] == true
        local b_pinned = state.pinned_addresses[b.address] == true
        if a_pinned ~= b_pinned then
            return a_pinned
        end
        if a.distance == b.distance then
            return a.name < b.name
        end
        return a.distance < b.distance
    end)

    if #items > cfg.max_results then
        local trimmed = {}
        for i = 1, cfg.max_results do
            trimmed[#trimmed + 1] = items[i]
        end
        items = trimmed
    end

    state.items = items
    state.last_scan = os.clock()
    state.last_error = nil

    local selected = nil
    if state.selected_key then
        for _, item in ipairs(items) do
            if item.key == state.selected_key then
                selected = item
                break
            end
        end
    end
    if not selected then
        state.selected_key = nil
    end
    state.selected = selected
end

local function maybe_refresh()
    if not cfg.show_objects then
        return
    end

    if state.force_refresh then
        state.force_refresh = false
        refresh_objects()
        return
    end

    if not cfg.auto_refresh then
        return
    end

    if (os.clock() - state.last_scan) >= cfg.scan_interval then
        refresh_objects()
    end
end

local function refresh_level_flows()
    local now = os.clock()
    local scene = get_scene()
    if not scene then
        state.levelflows = {}
        state.levelflow_state_history = {}
        state.levelflow_last_scan = now
        return
    end

    local scene_address = 0
    pcall(function()
        scene_address = scene:get_address()
    end)
    if state.levelflow_scene_address ~= scene_address then
        state.levelflow_scene_address = scene_address
        state.levelflow_state_history = {}
        log_debug("Level flow overlay scene changed; cleared cached states.")
    end

    if not level_flow_controller_rt then
        state.levelflows = {}
        state.levelflow_last_scan = now
        return
    end

    local components = nil
    pcall(function()
        components = scene:call("findComponents(System.Type)", level_flow_controller_rt)
    end)
    if not components then
        state.levelflows = {}
        state.levelflow_last_scan = now
        return
    end

    local count = 0
    pcall(function()
        count = components:call("get_Count") or 0
    end)

    local items = {}
    local history = {}
    for i = 0, count - 1 do
        pcall(function()
            local controller = components:call("get_Item", i)
            if not controller then
                return
            end

            local game_object = controller:call("get_GameObject")
            if not game_object then
                return
            end

            local name = tostring(game_object:call("get_Name") or "?")
            local address = 0
            pcall(function()
                address = game_object:get_address()
            end)

            local state_text = get_level_flow_state_text(game_object)
            local previous = state.levelflow_state_history[address]
            local changed_at = previous and previous.changed_at or 0
            if previous and previous.state_text ~= state_text then
                changed_at = now
                log_debug(string.format(
                    "Level flow state changed: %s (%s -> %s)",
                    name,
                    tostring(previous.state_text or "-"),
                    tostring(state_text or "-")))
            end

            history[address] = {
                state_text = state_text,
                changed_at = changed_at,
            }
            items[#items + 1] = {
                name = name,
                state_text = state_text or "-",
                changed_at = changed_at,
            }
        end)
    end

    table.sort(items, function(a, b)
        local a_main = is_main_levelflow_name(a.name)
        local b_main = is_main_levelflow_name(b.name)
        if a_main ~= b_main then
            return a_main
        end
        local a_name = tostring(a.name or ""):lower()
        local b_name = tostring(b.name or ""):lower()
        if a_name == b_name then
            return tostring(a.state_text or "") < tostring(b.state_text or "")
        end
        return a_name < b_name
    end)

    state.levelflows = items
    state.levelflow_state_history = history
    state.levelflow_last_scan = now
end

local function maybe_refresh_level_flows()
    if not cfg.show_levelflow_overlay then
        return
    end

    if state.levelflow_force_refresh then
        state.levelflow_force_refresh = false
        refresh_level_flows()
        return
    end

    if (os.clock() - state.levelflow_last_scan) >= LEVELFLOW_SCAN_INTERVAL then
        refresh_level_flows()
    end
end

local function call_transform_method(xf, method_name, method, value)
    if method then
        local ok, err = pcall(method.call, method, xf, value)
        if ok then
            return true
        end
        log_warn(method_name .. " failed: " .. tostring(err))
    end

    if transform_td then
        local ok, err = pcall(sdk.call_native_func, xf, transform_td, method_name, value)
        if ok then
            return true
        end
        log_warn(method_name .. " native call failed: " .. tostring(err))
    end

    return false
end

local function force_mesh_on_go(go)
    local mesh = get_component(go, mesh_rt)
    if not mesh then
        return
    end

    pcall(function() mesh:call("set_ForceWarp", true) end)
    pcall(function() mesh:call("set_ForceDynamicMesh", true) end)
    pcall(function() mesh:call("set_StaticMesh", false) end)
end

local function prepare_game_object_for_move(go)
    if not go then
        return
    end

    force_mesh_on_go(go)

    local rigidbody_set = get_component(go, rigidbody_set_rt)
    if rigidbody_set then
        pcall(function() rigidbody_set:call("set_Enabled", false) end)
    end

    local gimmick_controller = get_component(go, gimmick_dynamic_prefab_controller_rt)
    if gimmick_controller then
        pcall(function() gimmick_controller:call("set_Enabled", false) end)
    end

    local dynamics_prop = get_component(go, dynamics_prop_object_rt)
    if dynamics_prop then
        pcall(function() dynamics_prop:call("set_Enabled", false) end)
    end

    local colliders = get_component(go, colliders_rt)
    if colliders then
        pcall(function() colliders:call("set_Static", false) end)
        pcall(function() colliders:call("updatePose") end)
    end

    local character_controller = get_component(go, character_controller_rt)
    if character_controller then
        pcall(function() character_controller:call("warp") end)
    end
end

local function prepare_transform_tree_for_move(xf, depth)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local child_go = child:call("get_GameObject")
            if child_go then
                prepare_game_object_for_move(child_go)
            end
        end)

        prepare_transform_tree_for_move(child, depth + 1)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function refresh_child_transforms(xf, depth)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local local_position = child:call("get_LocalPosition")
            if local_position then
                call_transform_method(child, "set_LocalPosition", set_local_position_method, local_position)
            end
        end)

        refresh_child_transforms(child, depth + 1)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function move_direct_children_by_delta(xf, dx, dy, dz)
    if not xf then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 50 do
        count = count + 1

        pcall(function()
            local child_position = child:call("get_Position")
            if child_position then
                call_transform_method(
                    child,
                    "set_Position",
                    set_position_method,
                    Vector3f.new(child_position.x + dx, child_position.y + dy, child_position.z + dz))
            end

            local local_position = child:call("get_LocalPosition")
            if local_position then
                call_transform_method(child, "set_LocalPosition", set_local_position_method, local_position)
            end
        end)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function collect_mesh_descendants(xf, depth, out)
    if not xf or depth > 5 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 100 do
        count = count + 1

        pcall(function()
            local child_go = child:call("get_GameObject")
            if child_go and get_component(child_go, mesh_rt) then
                local child_position = get_transform_position(child)
                if child_position then
                    out[#out + 1] = {
                        xf = child,
                        go = child_go,
                        x = child_position.x,
                        y = child_position.y,
                        z = child_position.z,
                    }
                end
            end
        end)

        collect_mesh_descendants(child, depth + 1, out)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function collect_mesh_child_entries(xf, depth, out)
    if not xf or depth > 20 or #out >= 256 then
        return
    end

    local child = nil
    pcall(function()
        child = xf:call("get_Child")
    end)

    local count = 0
    while child and count < 100 and #out < 256 do
        count = count + 1

        pcall(function()
            local child_go = child:call("get_GameObject")
            local child_mesh = child_go and get_component(child_go, mesh_rt) or nil
            if child_go and child_mesh then
                local child_name = "?"
                pcall(function()
                    child_name = tostring(child_go:call("get_Name") or "?")
                end)
                out[#out + 1] = {
                    go = child_go,
                    xf = child,
                    mesh = child_mesh,
                    name = child_name,
                    depth = depth + 1,
                }
            end
        end)

        collect_mesh_child_entries(child, depth + 1, out)

        local next_child = nil
        pcall(function()
            next_child = child:call("get_Next")
        end)
        child = next_child
    end
end

local function copy_component_fields(template_component, target_component)
    if not template_component or not target_component then
        return false
    end

    local ok_tdef, tdef = pcall(function()
        return template_component:get_type_definition()
    end)
    if not ok_tdef or not tdef then
        return false
    end

    local ok_fields, fields = pcall(function()
        return tdef:get_fields()
    end)
    if not ok_fields or not fields then
        return false
    end

    local copied = false
    for _, field in ipairs(fields) do
        pcall(function()
            if not field:is_static() then
                local field_name = field:get_name()
                local value = template_component:get_field(field_name)
                if value ~= nil then
                    target_component:set_field(field_name, value)
                    copied = true
                end
            end
        end)
    end

    return copied
end

local function find_mesh_template_in_object(go, xf)
    if not go or not xf then
        return nil, nil, nil
    end

    local direct_mesh = get_component(go, mesh_rt)
    if direct_mesh then
        return go, xf, direct_mesh
    end

    local mesh_children = {}
    collect_mesh_child_entries(xf, 0, mesh_children)
    if #mesh_children == 0 then
        return nil, nil, nil
    end

    return mesh_children[1].go, mesh_children[1].xf, mesh_children[1].mesh
end

local function get_active_spawn_template()
    local template = state.spawn_template
    if template and template.scene_address == state.scene_address then
        local template_go = template.game_object
        local template_xf = template.transform
        local template_mesh = template.mesh_component
        if sdk.is_managed_object(template_go) and sdk.is_managed_object(template_xf) and sdk.is_managed_object(template_mesh) then
            return template_go, template_xf, template_mesh
        end
        state.spawn_template = nil
    end

    return nil, nil, nil
end

local function set_spawn_template_from_selected()
    local entry = state.selected
    if not entry or not entry.game_object or not entry.transform then
        log_warn("Spawn template ignored: no selected object")
        return false
    end

    local template_go, template_xf, template_mesh = find_mesh_template_in_object(entry.game_object, entry.transform)
    if not template_mesh then
        log_warn("Spawn template ignored: selected object has no mesh descendants")
        return false
    end

    local mesh_name = "?"
    pcall(function()
        mesh_name = tostring(template_go:call("get_Name") or "?")
    end)
    state.spawn_template = {
        scene_address = state.scene_address,
        game_object = template_go,
        transform = template_xf,
        mesh_component = template_mesh,
        source_name = entry.name,
        mesh_name = mesh_name,
    }
    log_info("Spawn template set from " .. tostring(entry.name) .. " using mesh " .. tostring(mesh_name))
    show_status_message("Copied Gimmick Mesh")
    return true
end

local function format_transform_csv(xf)
    if not xf then
        return nil
    end

    local position = nil
    local euler = nil

    pcall(function()
        position = xf:call("get_Position")
    end)
    pcall(function()
        euler = xf:call("get_LocalEulerAngle")
    end)

    if not position or not euler then
        return nil
    end

    return string.format(
        "%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f",
        normalize_display_number(position.x),
        normalize_display_number(position.y),
        normalize_display_number(position.z),
        normalize_display_number(math.deg(euler.x or 0)),
        normalize_display_number(math.deg(euler.y or 0)),
        normalize_display_number(math.deg(euler.z or 0))
    )
end

local function copy_selected_transform(entry)
    if not entry or not entry.transform then
        return false
    end

    local text = format_transform_csv(entry.transform)
    if not text then
        return false
    end

    if copy_to_clipboard(text) then
        log_info("Copied placement CSV for " .. tostring(entry.name))
        show_status_message("Copied CSV to clipboard")
        return true
    end
    return false
end

local function safe_field_string(obj, field_name)
    local value = nil
    local ok = pcall(function()
        value = obj:get_field(field_name)
    end)
    if not ok then
        return "<error>"
    end
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function get_object_type_name(obj)
    if not obj then
        return "nil"
    end

    local type_name = nil
    pcall(function()
        local td = obj:get_type_definition()
        if td then
            type_name = td:get_full_name()
        end
    end)
    return tostring(type_name or "<unknown>")
end

local function object_to_string(obj)
    if obj == nil then
        return "nil"
    end

    local text = nil
    pcall(function()
        text = obj:call("ToString()")
    end)
    if text == nil then
        text = tostring(obj)
    end
    return tostring(text)
end

local function log_mesh_debug(label, go, mesh_component)
    if not go then
        log_info(label .. " go=nil")
        return
    end

    local name = "?"
    local position = nil
    pcall(function()
        name = tostring(go:call("get_Name") or "?")
    end)
    pcall(function()
        local xf = go:call("get_Transform")
        if xf then
            position = xf:call("get_Position")
        end
    end)

    local parts = {
        "name=" .. name,
        "components=" .. table.concat(get_component_names(go), ","),
    }

    if position then
        parts[#parts + 1] = string.format("pos=%.3f,%.3f,%.3f", position.x or 0, position.y or 0, position.z or 0)
    end

    if mesh_component then
        parts[#parts + 1] = "mesh_component=" .. tostring(mesh_component)
        parts[#parts + 1] = "Enabled=" .. safe_field_string(mesh_component, "Enabled")
        parts[#parts + 1] = "Mesh=" .. safe_field_string(mesh_component, "Mesh")
        parts[#parts + 1] = "Material=" .. safe_field_string(mesh_component, "Material")
        parts[#parts + 1] = "StaticMesh=" .. safe_field_string(mesh_component, "StaticMesh")
        parts[#parts + 1] = "SharedSkeleton=" .. safe_field_string(mesh_component, "SharedSkeleton")
        parts[#parts + 1] = "SharedSkeletonGameObject=" .. safe_field_string(mesh_component, "SharedSkeletonGameObject")
        parts[#parts + 1] = "DrawDefault=" .. safe_field_string(mesh_component, "DrawDefault")
        parts[#parts + 1] = "DrawShadowCast=" .. safe_field_string(mesh_component, "DrawShadowCast")
        local ok_mat_num, mat_num = pcall(function()
            return mesh_component:call("get_MaterialNum")
        end)
        if ok_mat_num then
            parts[#parts + 1] = "MaterialNum=" .. tostring(mat_num)
        end
    else
        parts[#parts + 1] = "mesh_component=nil"
    end

    log_info(label .. " " .. table.concat(parts, " | "))
end

local function copy_property_via_methods(source, target, property_name)
    local ok_get, value = pcall(function()
        return source:call("get_" .. property_name)
    end)
    if not ok_get or value == nil then
        return false
    end

    local ok_set = pcall(function()
        target:call("set_" .. property_name, value)
    end)
    return ok_set
end

local function copy_property_via_named_methods(source, target, getter_name, setter_name)
    local ok_get, value = pcall(function()
        return source:call(getter_name)
    end)
    if not ok_get or value == nil then
        return false
    end

    local ok_set = pcall(function()
        target:call(setter_name, value)
    end)
    return ok_set
end

local function copy_mesh_material_slots(source, target)
    local ok_count, count = pcall(function()
        return source:call("get_MaterialNum")
    end)
    if not ok_count or not count then
        return 0, 0
    end

    local copied = 0
    pcall(function()
        target:call("set_MaterialNum", count)
    end)

    for i = 0, count - 1 do
        local ok_mat, material = pcall(function()
            return source:call("getMaterial", i)
        end)
        if ok_mat and material then
            local ok_set = pcall(function()
                target:call("setMaterial", i, material)
            end)
            if ok_set then
                copied = copied + 1
            end
        end

        local ok_name, material_name = pcall(function()
            return source:call("getMaterialName", i)
        end)
        if ok_name and material_name then
            pcall(function()
                target:call("setMaterialName", i, material_name)
            end)
        end
    end

    return copied, count
end

local function copy_mesh_component(source, target)
    copy_component_fields(source, target)

    local copied_properties = {}
    for _, property_name in ipairs({
        "Mesh",
        "Material",
        "Enabled",
        "StaticMesh",
        "SharedSkeleton",
        "DrawDefault",
        "DrawShadowCast",
        "LodLevel",
    }) do
        if copy_property_via_methods(source, target, property_name) then
            copied_properties[#copied_properties + 1] = property_name
        end
    end

    if copy_property_via_named_methods(source, target, "getMesh", "setMesh") then
        copied_properties[#copied_properties + 1] = "Mesh(getMesh/setMesh)"
    end
    if copy_property_via_named_methods(source, target, "getMaterial", "setMaterial") then
        copied_properties[#copied_properties + 1] = "Material(getMaterial/setMaterial)"
    end

    local copied_materials, total_materials = copy_mesh_material_slots(source, target)
    local updated = pcall(function()
        target:call("update")
    end)

    log_info(string.format(
        "Spawn mesh method copy: props=%s materials=%d/%d update=%s",
        (#copied_properties > 0 and table.concat(copied_properties, ",") or "<none>"),
        copied_materials,
        total_materials,
        tostring(updated)
    ))
end

local function get_parent_name(xf)
    local parent = nil
    pcall(function()
        parent = xf:call("get_Parent")
    end)
    if not parent then
        return nil
    end

    local name = "?"
    pcall(function()
        local parent_go = parent:call("get_GameObject")
        if parent_go then
            name = tostring(parent_go:call("get_Name") or "?")
        end
    end)
    return name
end

local function detach_transform_from_parent(xf)
    if not xf then
        return
    end

    local parent_before = get_parent_name(xf)
    if parent_before then
        log_info("Spawn parent before detach: " .. tostring(parent_before))
    else
        log_info("Spawn parent before detach: <nil>")
    end

    pcall(function()
        xf:call("set_Parent", nil)
    end)

    local parent_after = get_parent_name(xf)
    if parent_after then
        log_info("Spawn parent after detach: " .. tostring(parent_after))
    else
        log_info("Spawn parent after detach: <nil>")
    end
end

local function create_game_object(name, component_type_names)
    if not game_object_create_method then
        log_error("Spawn failed: via.GameObject.create(System.String) not found")
        return nil, nil
    end

    local game_object = nil
    local transform = nil

    pcall(function()
        game_object = game_object_create_method:call(nil, name)
        if not game_object then
            log_error("Spawn failed: via.GameObject.create(System.String) returned nil")
            return
        end

        pcall(function()
            game_object:add_ref()
        end)

        game_object:call(".ctor")
        transform = game_object:call("get_Transform")

        for _, component_type_name in ipairs(component_type_names or {}) do
            local component_td = sdk.find_type_definition(component_type_name)
            if component_td then
                local component = game_object:call("createComponent(System.Type)", component_td:get_runtime_type())
                if component then
                    pcall(function()
                        component:add_ref()
                    end)
                    component:call(".ctor()")
                else
                    log_warn("Spawn warning: createComponent returned nil for " .. component_type_name)
                end
            else
                log_warn("Spawn warning: type definition not found for " .. component_type_name)
            end
        end
    end)

    return game_object, transform
end

destroy_game_object = function(go)
    if not go or not sdk.is_managed_object(go) then
        return false
    end

    local ok = pcall(function()
        go:call("destroy", go)
    end)
    return ok
end

local function destroy_all_biorand_objects()
    local targets = {}
    local seen = {}

    for address, spawned in pairs(state.spawned_objects) do
        local go = spawned.game_object
        if go and sdk.is_managed_object(go) and not seen[address] then
            seen[address] = true
            targets[#targets + 1] = {
                address = address,
                game_object = go,
            }
        end
    end

    local scene = get_scene()
    if scene then
        local transform = nil
        pcall(function()
            transform = scene:call("get_FirstTransform")
        end)

        local walked = 0
        while transform and walked < 12000 do
            walked = walked + 1

            pcall(function()
                local go = transform:call("get_GameObject")
                if not go then
                    return
                end

                local address = go:get_address()
                local name = tostring(go:call("get_Name") or "")
                if address ~= 0 and not seen[address] and is_biorand_name(name) then
                    seen[address] = true
                    targets[#targets + 1] = {
                        address = address,
                        game_object = go,
                    }
                end
            end)

            local next_transform = nil
            pcall(function()
                next_transform = transform:call("get_Next")
            end)
            transform = next_transform
        end
    end

    local removed = 0
    for _, target in ipairs(targets) do
        local ok = pcall(function()
            target.game_object:call("destroy", target.game_object)
        end)
        if ok then
            removed = removed + 1
        end
        if state.last_spawned_address == target.address then
            state.last_spawned_address = nil
        end
        state.spawned_objects[target.address] = nil
        state.pinned_addresses[target.address] = nil
    end

    state.selected = nil
    state.selected_key = nil
    state.force_refresh = true
    log_info("Removed " .. tostring(removed) .. " BioRand placed meshes")
end

local function build_spawned_entry_from_record(address, spawned)
    if not spawned or not spawned.game_object or not sdk.is_managed_object(spawned.game_object) then
        return nil
    end

    local go = spawned.game_object
    local xf = nil
    pcall(function()
        xf = go:call("get_Transform")
    end)
    if not xf then
        return nil
    end

    local entry = build_entry(go, xf, get_observer_position(), {
        force_include = true,
        ignore_distance = true,
        kind = spawned.kind or "PlacedMesh",
        source = spawned.source or "Spawned",
        display_name = spawned.display_name or "Placed Mesh",
    })
    if entry then
        return entry
    end

    local position = get_transform_position(xf) or Vector3f.new(0, 0, 0)
    return {
        key = string.format("%X", address),
        address = address,
        game_object = go,
        transform = xf,
        name = tostring(go:call("get_Name") or spawned.display_name or "Placed Mesh"),
        kind = spawned.kind or "PlacedMesh",
        source = spawned.source or "Spawned",
        guid = "",
        x = position.x or 0,
        y = position.y or 0,
        z = position.z or 0,
        distance = 0,
        components = "",
    }
end

local function select_entry(entry)
    if not entry then
        state.selected = nil
        state.selected_key = nil
        return false
    end

    state.selected = entry
    state.selected_key = entry.key
    return true
end

local function select_last_spawned_object()
    local address = state.last_spawned_address
    if not address then
        log_warn("No last placed object is available")
        return false
    end

    local spawned = state.spawned_objects[address]
    local entry = build_spawned_entry_from_record(address, spawned)
    if not entry then
        state.spawned_objects[address] = nil
        state.pinned_addresses[address] = nil
        if state.last_spawned_address == address then
            state.last_spawned_address = nil
        end
        log_warn("Last placed object is no longer valid")
        return false
    end

    select_entry(entry)
    log_info("Selected last placed object: " .. tostring(entry.name))
    return true
end

local function destroy_selected_object()
    local entry = state.selected
    if not entry or not entry.game_object then
        log_warn("Delete ignored: no selected object")
        return false
    end

    local address = entry.address
    local is_spawned = address and state.spawned_objects[address] ~= nil
    if not is_spawned and not is_biorand_name(entry.name) then
        log_warn("Delete ignored: selected object is not a BioRand placed object")
        return false
    end

    local ok = pcall(function()
        entry.game_object:call("destroy", entry.game_object)
    end)
    if not ok then
        log_warn("Delete failed for " .. tostring(entry.name))
        return false
    end

    state.spawned_objects[address] = nil
    state.pinned_addresses[address] = nil
    if state.last_spawned_address == address then
        state.last_spawned_address = nil
    end
    select_entry(nil)
    state.force_refresh = true
    log_info("Deleted " .. tostring(entry.name))
    return true
end

local function get_cycle_entries()
    local entries = {}

    if #state.items > 0 then
        for _, item in ipairs(state.items) do
            entries[#entries + 1] = item
        end
    end

    if #entries > 0 then
        return entries
    end

    local spawned_entries = {}
    for address, spawned in pairs(state.spawned_objects) do
        local entry = build_spawned_entry_from_record(address, spawned)
        if entry then
            spawned_entries[#spawned_entries + 1] = {
                entry = entry,
                order = spawned.order or 0,
            }
        end
    end

    table.sort(spawned_entries, function(a, b)
        if a.order == b.order then
            return a.entry.name < b.entry.name
        end
        return a.order < b.order
    end)

    for _, item in ipairs(spawned_entries) do
        entries[#entries + 1] = item.entry
    end
    return entries
end

local function cycle_selected_entry(direction)
    local entries = get_cycle_entries()
    if #entries == 0 then
        log_warn("Cycle ignored: no selectable objects")
        return false
    end

    local index = 1
    if state.selected_key then
        for i, entry in ipairs(entries) do
            if entry.key == state.selected_key then
                index = i
                break
            end
        end
    end

    if direction < 0 then
        index = ((index - 2) % #entries) + 1
    else
        index = (index % #entries) + 1
    end

    local entry = entries[index]
    select_entry(entry)
    log_info("Selected " .. tostring(entry.name))
    return true
end

local function move_selected_to_placement_point()
    local entry = state.selected
    if not entry or not entry.transform then
        log_warn("Placement move ignored: no selected object")
        return false
    end

    local observer_position, raw_spawn_position = get_default_placement_position()
    local spawn_position = snap_placement_position(raw_spawn_position)
    local facing_yaw = snap_placement_yaw(calculate_yaw_towards(spawn_position, observer_position))
    defer(function()
        if apply_position(entry.transform, spawn_position.x, spawn_position.y, spawn_position.z, entry.game_object) then
            apply_local_euler(entry.transform, 0, facing_yaw, 0, entry.game_object)
            log_info(string.format("Moved %s to %.3f, %.3f, %.3f", entry.name, spawn_position.x, spawn_position.y,
                spawn_position.z))
        end
    end)
    return true
end

local function toggle_precise_mode()
    cfg.precise_mode = not cfg.precise_mode
    cfg_save()
    log_info("Placement mode: " .. (cfg.precise_mode and "Precise" or "Normal"))
end

local function spawn_placeable_object()
    local template_root = nil
    local template_go, template_xf, template_mesh = get_active_spawn_template()
    if not template_mesh then
        log_warn("Spawn ignored: no template set. Select an object and press Numpad * first")
        return nil
    end

    local observer_position, raw_spawn_position = get_default_placement_position()
    local spawn_position = snap_placement_position(raw_spawn_position)

    state.spawn_index = state.spawn_index + 1
    local object_name = string.format("BioRand_PlacedMesh_%03d", state.spawn_index)

    local game_object, transform = create_game_object(object_name, { "via.render.Mesh" })
    local mesh_component = nil

    if not game_object then
        destroy_game_object(template_root)
        return nil
    end
    if not transform then
        log_error("Spawn failed: created object has no transform")
        destroy_game_object(template_root)
        return nil
    end

    detach_transform_from_parent(transform)
    pcall(function()
        transform:set_position(spawn_position, true)
    end)
    local facing_yaw = snap_placement_yaw(calculate_yaw_towards(spawn_position, observer_position))

    mesh_component = get_component(game_object, mesh_rt)
    if mesh_component then
        log_info("Using selected spawn template: " ..
            tostring(state.spawn_template and state.spawn_template.mesh_name or "?"))
        log_mesh_debug("Template mesh debug:", template_go, template_mesh)
        copy_mesh_component(template_mesh, mesh_component)
        log_mesh_debug("Spawned mesh debug:", game_object, mesh_component)
    else
        log_error("Spawn failed: could not create via.render.Mesh on spawned object")
        destroy_game_object(template_root)
        return nil
    end
    destroy_game_object(template_root)

    local entry = build_entry(game_object, transform, get_observer_position(), {
        force_include = true,
        ignore_distance = true,
        kind = "PlacedMesh",
        source = "Spawned",
        display_name = "Placed Mesh",
    })
    if not entry then
        local position = get_transform_position(transform) or spawn_position
        entry = {
            key = string.format("%X", game_object:get_address()),
            address = game_object:get_address(),
            game_object = game_object,
            transform = transform,
            name = object_name,
            kind = "PlacedMesh",
            source = "Spawned",
            guid = "",
            x = position.x,
            y = position.y,
            z = position.z,
            distance = 0,
            components = mesh_component and "via.render.Mesh" or "",
        }
    end

    select_entry(entry)
    state.spawned_objects[entry.address] = {
        game_object = game_object,
        kind = entry.kind,
        source = entry.source,
        display_name = "Placed Mesh",
        order = state.spawn_index,
    }
    state.last_spawned_address = entry.address
    state.pinned_addresses[entry.address] = true
    state.force_refresh = true
    defer(function()
        if apply_local_euler(transform, 0, facing_yaw, 0, game_object) then
            log_info(string.format("Applied spawn facing yaw %.2f to %s", facing_yaw, object_name))
        end
    end)
    log_info(string.format("Spawned %s at %.3f, %.3f, %.3f", object_name, spawn_position.x, spawn_position.y,
        spawn_position.z))
    return entry
end

local function nudge_selected_object(dx, dy, dz)
    local entry = state.selected
    if not entry or not entry.transform then
        return false
    end

    local position = get_transform_position(entry.transform)
    if not position then
        return false
    end

    local moved = apply_position(
        entry.transform,
        position.x + dx,
        position.y + dy,
        position.z + dz,
        entry.game_object
    )
    if moved then
        entry.x = position.x + dx
        entry.y = position.y + dy
        entry.z = position.z + dz
        if entry.distance then
            entry.distance = distance(position, get_observer_position()) or entry.distance
        end
    end
    return moved
end

local function rotate_selected_yaw(delta_yaw_deg)
    local entry = state.selected
    if not entry or not entry.transform then
        return false
    end

    local local_euler = nil
    pcall(function()
        local_euler = entry.transform:call("get_LocalEulerAngle")
    end)
    if not local_euler then
        return false
    end

    local pitch = math.deg(local_euler.x or 0)
    local yaw = math.deg(local_euler.y or 0)
    local roll = math.deg(local_euler.z or 0)
    return apply_local_euler(entry.transform, pitch, yaw + delta_yaw_deg, roll, entry.game_object)
end

local function sync_mesh_descendants(descendants, dx, dy, dz)
    for _, descendant in ipairs(descendants) do
        local expected_x = descendant.x + dx
        local expected_y = descendant.y + dy
        local expected_z = descendant.z + dz

        local current = get_transform_position(descendant.xf)
        local needs_move = true
        if current then
            local delta = math.abs(current.x - expected_x) + math.abs(current.y - expected_y) +
                math.abs(current.z - expected_z)
            needs_move = delta > 0.01
        end

        if needs_move then
            prepare_game_object_for_move(descendant.go)
            call_transform_method(
                descendant.xf,
                "set_Position",
                set_position_method,
                Vector3f.new(expected_x, expected_y, expected_z))
        end
    end
end

apply_position = function(xf, x, y, z, go)
    if not xf then
        return false
    end

    local current_position = get_transform_position(xf)
    local mesh_descendants = {}
    if go then
        collect_mesh_descendants(xf, 0, mesh_descendants)
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local changed = call_transform_method(xf, "set_Position", set_position_method, Vector3f.new(x, y, z))
    if changed and go then
        if current_position then
            local dx = x - current_position.x
            local dy = y - current_position.y
            local dz = z - current_position.z
            move_direct_children_by_delta(xf, dx, dy, dz)
            sync_mesh_descendants(mesh_descendants, dx, dy, dz)
        end
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function apply_rotation_quat(xf, quat, go)
    if not xf or not quat then
        return false
    end

    if go then
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local changed = call_transform_method(xf, "set_Rotation", set_rotation_method, quat)
    if changed and go then
        refresh_child_transforms(xf, 0)
    end
    return changed
end

apply_local_euler = function(xf, pitch_deg, yaw_deg, roll_deg, go)
    if not xf then
        return false
    end

    if go then
        prepare_game_object_for_move(go)
        prepare_transform_tree_for_move(xf, 0)
    end

    local euler = Vector3f.new(math.rad(pitch_deg), math.rad(yaw_deg), math.rad(roll_deg))
    local changed = call_transform_method(xf, "set_LocalEulerAngle", set_local_euler_method, euler)
    if changed and go then
        refresh_child_transforms(xf, 0)
    end
    return changed
end

local function get_matrix_position(matrix)
    local position = nil
    pcall(function()
        position = matrix[3]
    end)
    if not position or position.x == nil then
        return nil
    end
    return position
end

local function draw_selected_gizmo(entry)
    if not entry or not draw or not draw.gizmo then
        return
    end

    local matrix = nil
    pcall(function()
        matrix = entry.transform:call("get_WorldMatrix")
    end)
    if not matrix then
        return
    end

    local ok, changed, new_matrix = pcall(draw.gizmo, entry.address, matrix)
    if not ok then
        if not state.warned_gizmo then
            state.warned_gizmo = true
            log_warn("draw.gizmo failed: " .. tostring(changed))
        end
        return
    end

    if not changed or not new_matrix then
        return
    end

    local new_position = get_matrix_position(new_matrix)
    local new_rotation = nil
    pcall(function()
        new_rotation = new_matrix:to_quat()
    end)

    defer(function()
        if new_position then
            apply_position(entry.transform, new_position.x, new_position.y, new_position.z, entry.game_object)
        end
        if new_rotation then
            apply_rotation_quat(entry.transform, new_rotation, entry.game_object)
        end
    end)
end

local function draw_object_table()
    imgui.text(string.format("Results: %d", #state.items))
    imgui.same_line()
    if imgui.button("Refresh##bio_objects") then
        state.force_refresh = true
    end

    if state.last_error then
        imgui.text_colored(state.last_error, 0xFF6666FF)
    end

    if imgui.begin_table("biorand_object_table", 8, 0, Vector2f.new(0, 0), 0) then
        imgui.table_setup_column("X", 16, 32, 0)
        imgui.table_setup_column("Kind", 16, 240, 0)
        imgui.table_setup_column("Guid", 16, 420, 0)
        imgui.table_setup_column("Dist", 16, 56, 0)
        imgui.table_setup_column("Name", 0, 1, 0)
        imgui.table_setup_column("X", 16, 72, 0)
        imgui.table_setup_column("Y", 16, 72, 0)
        imgui.table_setup_column("Z", 16, 72, 0)
        imgui.table_headers_row()

        for _, item in ipairs(state.items) do
            imgui.table_next_row()

            imgui.table_next_column()
            imgui.push_id("pick_" .. item.key)
            local is_selected = state.selected_key == item.key
            local changed, new_value = imgui.checkbox("", is_selected)
            imgui.pop_id()
            if changed then
                if new_value then
                    state.selected_key = item.key
                    state.selected = item
                else
                    state.selected_key = nil
                    state.selected = nil
                end
            end

            imgui.table_next_column()
            imgui.text(item.kind)

            imgui.table_next_column()
            imgui.push_item_width(400)
            if item.guid ~= "" then
                imgui.input_text("##guid_" .. item.key, item.guid, 2048)
            else
                imgui.input_text("##guid_" .. item.key, "0x" .. item.key, 2048)
            end
            imgui.pop_item_width()

            imgui.table_next_column()
            imgui.text(string.format("%.1f", item.distance or 0))

            imgui.table_next_column()
            imgui.text(item.name)

            imgui.table_next_column()
            imgui.text(string.format("%.1f", item.x))

            imgui.table_next_column()
            imgui.text(string.format("%.1f", item.y))

            imgui.table_next_column()
            imgui.text(string.format("%.1f", item.z))
        end

        imgui.end_table()
    end
end

local function draw_selected_editor()
    imgui.separator()
    imgui.text_colored("Selected Object Editor", 0xFF88DDFF)

    local entry = state.selected
    if not entry then
        imgui.text("Select an object from the table to edit its position.")
        return
    end

    local xf = entry.transform
    local position = get_transform_position(xf)
    if not position then
        imgui.text_colored("Selected object no longer has a readable transform.", 0xFF6666FF)
        return
    end

    imgui.text("Target: " .. entry.name)
    imgui.text("Kind: " .. entry.kind)
    imgui.text("Source: " .. (entry.source or "Scene"))
    if entry.guid ~= "" then
        imgui.text("Guid: " .. entry.guid)
        imgui.same_line()
        if imgui.button("Copy GUID##selected_copy_guid") then
            copy_to_clipboard(entry.guid)
        end
    else
        imgui.text("Address: 0x" .. entry.key)
    end
    imgui.text(string.format("Distance: %.2fm", entry.distance or 0))

    local changed_x, new_x = imgui.drag_float("X##selected_x", position.x, 0.05, -99999, 99999, "%.3f")
    local changed_y, new_y = imgui.drag_float("Y##selected_y", position.y, 0.05, -99999, 99999, "%.3f")
    local changed_z, new_z = imgui.drag_float("Z##selected_z", position.z, 0.05, -99999, 99999, "%.3f")

    if changed_x or changed_y or changed_z then
        local target_x = changed_x and new_x or position.x
        local target_y = changed_y and new_y or position.y
        local target_z = changed_z and new_z or position.z
        defer(function()
            if apply_position(xf, target_x, target_y, target_z, entry.game_object) then
                log_info(string.format("Moved %s to %.3f, %.3f, %.3f", entry.name, target_x, target_y, target_z))
            end
        end)
    end

    if imgui.button("Copy x,y,z,pitch,yaw,roll##selected_copy_transform") then
        copy_selected_transform(entry)
    end
    imgui.same_line()
    imgui.text(
        "Numpad * set template. Numpad + spawn. Numpad / mode. Numpad . move to front. Enter copy. - delete. 4/8/6/2 move. 1/3 Y. 7/9 rotate. ,/. cycle.")

    local local_euler = nil
    pcall(function()
        local_euler = xf:call("get_LocalEulerAngle")
    end)
    if local_euler then
        local pitch = math.deg(local_euler.x or 0)
        local yaw = math.deg(local_euler.y or 0)
        local roll = math.deg(local_euler.z or 0)

        local changed_pitch, new_pitch = imgui.drag_float("Pitch##selected_pitch", pitch, 1.0, -360.0, 360.0, "%.1f")
        local changed_yaw, new_yaw = imgui.drag_float("Yaw##selected_yaw", yaw, 1.0, -360.0, 360.0, "%.1f")
        local changed_roll, new_roll = imgui.drag_float("Roll##selected_roll", roll, 1.0, -360.0, 360.0, "%.1f")

        if changed_pitch or changed_yaw or changed_roll then
            local target_pitch = changed_pitch and new_pitch or pitch
            local target_yaw = changed_yaw and new_yaw or yaw
            local target_roll = changed_roll and new_roll or roll
            defer(function()
                if apply_local_euler(xf, target_pitch, target_yaw, target_roll, entry.game_object) then
                    log_info(string.format("Rotated %s to %.1f, %.1f, %.1f", entry.name, target_pitch, target_yaw,
                        target_roll))
                end
            end)
        end

        if imgui.button("Reset Rotation##selected_reset_rotation") then
            defer(function()
                if apply_local_euler(xf, 0, 0, 0, entry.game_object) then
                    log_info("Reset rotation for " .. entry.name)
                end
            end)
        end
    end

    local component_names = get_component_names(entry.game_object)
    if #component_names > 0 and imgui.button("Copy Components##selected_copy_components") then
        copy_to_clipboard(table.concat(component_names, "\n"))
    end
    if imgui.tree_node("Components##selected_components") then
        if #component_names == 0 then
            imgui.text("(No components found on this GameObject)")
        else
            for _, component_name in ipairs(component_names) do
                imgui.text(component_name)
            end
        end
        imgui.tree_pop()
    end
end

local function draw_selected_status_overlay()
    local entry = state.selected
    if not entry or not entry.transform then
        return
    end

    local position = get_transform_position(entry.transform)
    local local_euler = nil
    pcall(function()
        local_euler = entry.transform:call("get_LocalEulerAngle")
    end)
    if not position or not local_euler then
        return
    end

    local x = 30
    local width = 520
    local height = 172
    local size = get_window_size()
    local y = (size and size.h) and (size.h - height - 30) or 598
    local bg = 0xCC000000
    local lime = 0xFF00FF00
    local white = 0xFFFFFFFF
    local header_font = get_overlay_font(18, true)
    local value_font = get_overlay_font(18, false)
    local pos_text = format_triplet(position.x, position.y, position.z)
    local rot_text = format_triplet(
        math.deg(local_euler.x or 0),
        math.deg(local_euler.y or 0),
        math.deg(local_euler.z or 0))
    local mode_text = cfg.precise_mode and "Precise Mode" or "Normal Mode"
    local title_text = string.format("Selected Object [%s]", mode_text)
    local guid_text = entry.guid
    if not guid_text or guid_text == "" then
        guid_text = "-"
    end
    local kind_text = entry.kind
    if not kind_text or kind_text == "" then
        kind_text = "-"
    end

    if d2d and header_font and value_font then
        pcall(d2d.fill_rect, x, y, width, height, bg)
        pcall(d2d.fill_rect, x, y, 4, height, lime)
        pcall(d2d.text, header_font, title_text, x + 14, y + 10, lime)
        pcall(d2d.text, header_font, "Name", x + 14, y + 36, lime)
        pcall(d2d.text, value_font, tostring(entry.name or "<unnamed>"), x + 90, y + 36, white)
        pcall(d2d.text, header_font, "Pos", x + 14, y + 62, lime)
        pcall(d2d.text, value_font, pos_text, x + 90, y + 62, white)
        pcall(d2d.text, header_font, "Rot", x + 14, y + 88, lime)
        pcall(d2d.text, value_font, rot_text, x + 90, y + 88, white)
        pcall(d2d.text, header_font, "Guid", x + 14, y + 114, lime)
        pcall(d2d.text, value_font, guid_text, x + 90, y + 114, white)
        pcall(d2d.text, header_font, "Kind", x + 14, y + 140, lime)
        pcall(d2d.text, value_font, kind_text, x + 90, y + 140, white)
        if state.status_message and state.status_message_until and state.status_message_until > os.clock() then
            if size and size.w and size.h then
                local msg_w = 320
                local msg_h = 36
                local msg_x = (size.w - msg_w) / 2
                local msg_y = size.h - msg_h - 30
                pcall(d2d.fill_rect, msg_x, msg_y, msg_w, msg_h, bg)
                pcall(d2d.fill_rect, msg_x, msg_y, 4, msg_h, lime)
                pcall(d2d.text, header_font, state.status_message, msg_x + 14, msg_y + 8, white)
            end
        end
        return
    end

    if draw then
        pcall(draw.filled_rect, x, y, width, height, bg)
        pcall(draw.filled_rect, x, y, 4, height, lime)
        pcall(draw.text, title_text, x + 14, y + 10, lime)
        pcall(draw.text, "Name", x + 14, y + 36, lime)
        pcall(draw.text, tostring(entry.name or "<unnamed>"), x + 90, y + 36, white)
        pcall(draw.text, "Pos", x + 14, y + 62, lime)
        pcall(draw.text, pos_text, x + 90, y + 62, white)
        pcall(draw.text, "Rot", x + 14, y + 88, lime)
        pcall(draw.text, rot_text, x + 90, y + 88, white)
        pcall(draw.text, "Guid", x + 14, y + 114, lime)
        pcall(draw.text, guid_text, x + 90, y + 114, white)
        pcall(draw.text, "Kind", x + 14, y + 140, lime)
        pcall(draw.text, kind_text, x + 90, y + 140, white)
        if state.status_message and state.status_message_until and state.status_message_until > os.clock() then
            if size and size.w and size.h then
                local msg_w = 320
                local msg_h = 36
                local msg_x = (size.w - msg_w) / 2
                local msg_y = size.h - msg_h - 30
                pcall(draw.filled_rect, msg_x, msg_y, msg_w, msg_h, bg)
                pcall(draw.filled_rect, msg_x, msg_y, 4, msg_h, lime)
                pcall(draw.text, state.status_message, msg_x + 14, msg_y + 8, white)
            end
        end
    end
end

local function draw_key_shortcuts_overlay()
    local entry = state.selected
    if not entry or not entry.transform then
        return
    end

    local size = get_window_size()
    if not size or not size.w or not size.h then
        return
    end

    local width = 444
    local height = 303
    local x = size.w - width - 30
    local y = size.h - height - 30
    local bg = 0xCC000000
    local lime = 0xFF00FF00
    local white = 0xFFFFFFFF
    local grey = 0xFFCCCCCC
    local key_bg = 0xFF2A2A2A

    local header_font = get_overlay_font(18, true)
    local main_font = get_overlay_font(14, true)
    local sub_font = get_overlay_font(10, false)

    if d2d and header_font and main_font and sub_font then
        pcall(d2d.fill_rect, x, y, width, height, bg)
        pcall(d2d.fill_rect, x, y, 4, height, lime)
        pcall(d2d.text, header_font, "HOTKEYS [NUMPAD]", x + 14, y + 10, lime)

        local x_start = x + 154
        local y_start = y + 42

        local NUMPAD_KEYS = {
            -- Row 0
            { col = 0, row = 0, w = 65, h = 45, main = "Num", sub = "" },
            { col = 1, row = 0, w = 65, h = 45, main = "/", sub = "Mode" },
            { col = 2, row = 0, w = 65, h = 45, main = "*", sub = "Copy" },
            { col = 3, row = 0, w = 65, h = 45, main = "-", sub = "Del" },
            -- Row 1
            { col = 0, row = 1, w = 65, h = 45, main = "7", sub = "Rot L" },
            { col = 1, row = 1, w = 65, h = 45, main = "8", sub = "Fwd" },
            { col = 2, row = 1, w = 65, h = 45, main = "9", sub = "Rot R" },
            -- Row 2
            { col = 0, row = 2, w = 65, h = 45, main = "4", sub = "Left" },
            { col = 1, row = 2, w = 65, h = 45, main = "5", sub = "" },
            { col = 2, row = 2, w = 65, h = 45, main = "6", sub = "Right" },
            -- Row 3
            { col = 0, row = 3, w = 65, h = 45, main = "1", sub = "Y Down" },
            { col = 1, row = 3, w = 65, h = 45, main = "2", sub = "Back" },
            { col = 2, row = 3, w = 65, h = 45, main = "3", sub = "Y Up" },
            -- Row 4
            { col = 0, row = 4, w = 136, h = 45, main = "0", sub = "" },
            { col = 2, row = 4, w = 65, h = 45, main = ".", sub = "Front" },

            -- Right Columns / Spanned Keys
            { col = 3, row = 1, w = 65, h = 96, main = "+", sub = "Paste" },
            { col = 3, row = 3, w = 65, h = 96, main = "Enter", sub = "CSV" },

            -- Left Columns (Col -2 and Col -1, side-by-side left of the 1 key)
            { col = -2, row = 3, w = 65, h = 45, main = "<", sub = "Prev" },
            { col = -1, row = 3, w = 65, h = 45, main = ">", sub = "Next" },
        }

        for _, key in ipairs(NUMPAD_KEYS) do
            local key_x = x_start + key.col * 71
            local key_y = y_start + key.row * 51
            pcall(d2d.fill_rect, key_x, key_y, key.w, key.h, key_bg)
            pcall(d2d.text, main_font, key.main, key_x + 6, key_y + 4, lime)
            if key.sub ~= "" then
                local sub_y = key_y + 24
                if key.h > 45 then
                    sub_y = key_y + key.h - 18
                end
                pcall(d2d.text, sub_font, key.sub, key_x + 6, sub_y, grey)
            end
        end
        return
    end

    if draw then
        pcall(draw.filled_rect, x, y, width, height, bg)
        pcall(draw.filled_rect, x, y, 4, height, lime)
        pcall(draw.text, "HOTKEYS [NUMPAD]", x + 14, y + 10, lime)

        local x_start = x + 154
        local y_start = y + 42

        local NUMPAD_KEYS = {
            -- Row 0
            { col = 0, row = 0, w = 65, h = 45, main = "Num", sub = "" },
            { col = 1, row = 0, w = 65, h = 45, main = "/", sub = "Mode" },
            { col = 2, row = 0, w = 65, h = 45, main = "*", sub = "Copy" },
            { col = 3, row = 0, w = 65, h = 45, main = "-", sub = "Del" },
            -- Row 1
            { col = 0, row = 1, w = 65, h = 45, main = "7", sub = "Rot L" },
            { col = 1, row = 1, w = 65, h = 45, main = "8", sub = "Fwd" },
            { col = 2, row = 1, w = 65, h = 45, main = "9", sub = "Rot R" },
            -- Row 2
            { col = 0, row = 2, w = 65, h = 45, main = "4", sub = "Left" },
            { col = 1, row = 2, w = 65, h = 45, main = "5", sub = "" },
            { col = 2, row = 2, w = 65, h = 45, main = "6", sub = "Right" },
            -- Row 3
            { col = 0, row = 3, w = 65, h = 45, main = "1", sub = "Y Down" },
            { col = 1, row = 3, w = 65, h = 45, main = "2", sub = "Back" },
            { col = 2, row = 3, w = 65, h = 45, main = "3", sub = "Y Up" },
            -- Row 4
            { col = 0, row = 4, w = 136, h = 45, main = "0", sub = "" },
            { col = 2, row = 4, w = 65, h = 45, main = ".", sub = "Front" },

            -- Right Columns / Spanned Keys
            { col = 3, row = 1, w = 65, h = 96, main = "+", sub = "Paste" },
            { col = 3, row = 3, w = 65, h = 96, main = "Enter", sub = "CSV" },

            -- Left Columns (Col -2 and Col -1, side-by-side left of the 1 key)
            { col = -2, row = 3, w = 65, h = 45, main = "<", sub = "Prev" },
            { col = -1, row = 3, w = 65, h = 45, main = ">", sub = "Next" },
        }

        for _, key in ipairs(NUMPAD_KEYS) do
            local key_x = x_start + key.col * 71
            local key_y = y_start + key.row * 51
            pcall(draw.filled_rect, key_x, key_y, key.w, key.h, key_bg)
            pcall(draw.text, key.main, key_x + 6, key_y + 4, lime)
            if key.sub ~= "" then
                local sub_y = key_y + 24
                if key.h > 45 then
                    sub_y = key_y + key.h - 18
                end
                pcall(draw.text, key.sub, key_x + 6, sub_y, grey)
            end
        end
    end
end

local function should_show_levelflow_item(item)
    if not item then
        return false
    end

    local state_text = tostring(item.state_text or "-")
    return state_text ~= "-" and state_text ~= "0"
end

local function build_levelflow_overlay_layout()
    if not cfg.show_levelflow_overlay then
        return nil
    end

    local items = state.levelflows
    if not items or #items == 0 then
        return nil
    end

    local visible_items = {}
    local name_width = 4
    for _, item in ipairs(items) do
        if should_show_levelflow_item(item) then
            visible_items[#visible_items + 1] = item

            local display_name = clamp_overlay_name(item.name)
            if #display_name > name_width then
                name_width = #display_name
            end
        end
    end

    if #visible_items == 0 then
        return nil
    end

    local row_height = 22
    local width = math.max(380, 52 + ((name_width + 7) * 10))
    local height = 40 + (#visible_items * row_height)
    local x = 30
    local y = 80
    if cfg.show_enemy_spawn_overlay and state.enemy_spawn_metrics then
        local visible_count = math.min(#(state.enemy_spawn_entries or {}), ENEMY_SPAWN_OVERLAY_LIMIT)
        local enemy_overlay_height = 22 + (5 * 22) + (visible_count * 22) + 18
        y = y + enemy_overlay_height + 16
    end

    local size = get_window_size()
    if size and size.w and size.w > (width + 60) then
        x = math.max(30, size.w - width - 30)
    end

    local rows = {}
    for _, item in ipairs(visible_items) do
        local changed_recently = item.changed_at > 0 and
            ((os.clock() - item.changed_at) < LEVELFLOW_HIGHLIGHT_WINDOW)
        rows[#rows + 1] = {
            color = changed_recently and 0xFF00FF00 or 0xFFFFFFFF,
            line = string.format(
                "%-" .. name_width .. "s %5s",
                clamp_overlay_name(item.name),
                tostring(item.state_text or "-")),
        }
    end

    return {
        x = x,
        y = y,
        width = width,
        height = height,
        row_height = row_height,
        rows = rows,
    }
end

local function render_levelflow_overlay(layout, fill_rect, draw_header, draw_rows)
    local bg = 0xCC000000
    local lime = 0xFF00FF00

    fill_rect(layout.x, layout.y, layout.width, layout.height, bg)
    fill_rect(layout.x, layout.y, 4, layout.height, lime)
    draw_header(layout, lime)

    for index, row in ipairs(layout.rows) do
        draw_rows(layout, index, row)
    end
end

local function draw_levelflow_overlay()
    local layout = build_levelflow_overlay_layout()
    if not layout then
        return
    end
    local header_font = get_overlay_font(18, true)
    local value_font = get_overlay_font(18, false)

    if d2d and header_font and value_font then
        pcall(render_levelflow_overlay, layout, d2d.fill_rect,
            function(current_layout, header_color)
                d2d.text(header_font, "Active LevelFlows", current_layout.x + 14, current_layout.y + 10, header_color)
            end,
            function(current_layout, index, row)
                local row_y = current_layout.y + 14 + (index * current_layout.row_height)
                d2d.text(value_font, row.line, current_layout.x + 14, row_y, row.color or 0xFFFFFFFF)
            end)
        return
    end

    if draw then
        pcall(render_levelflow_overlay, layout, draw.filled_rect,
            function(current_layout, header_color)
                draw.text("Active LevelFlows", current_layout.x + 14, current_layout.y + 10, header_color)
            end,
            function(current_layout, index, row)
                local row_y = current_layout.y + 14 + (index * current_layout.row_height)
                draw.text(row.line, current_layout.x + 14, row_y, row.color or 0xFFFFFFFF)
            end)
    end
end

local function build_enemy_spawn_overlay_rows()
    if not cfg.show_enemy_spawn_overlay then
        return nil
    end

    local metrics = state.enemy_spawn_metrics
    if not metrics then
        return nil
    end

    local items = state.enemy_spawn_entries or {}
    local visible_count = math.min(#items, ENEMY_SPAWN_OVERLAY_LIMIT)
    local lines = {
        "Enemy Spawns",
        string.format(
            "Spawns %d total | %d active | %d inactive | %d recent despawns",
            metrics.total_spawns or 0,
            metrics.active_spawns or 0,
            metrics.inactive_spawns or 0,
            metrics.recent_despawns or 0),
        string.format(
            "Pools %d total | %d spare | %d used | %d reserved | %d orphaned",
            metrics.pool and metrics.pool.total or 0,
            metrics.pool and metrics.pool.spare or 0,
            metrics.pool and metrics.pool.used or 0,
            metrics.pool and metrics.pool.reserved or 0,
            metrics.pool and metrics.pool.orphaned or 0),
        string.format(
            "Flags permitted %d | requested %d | completed %d | rejected resume %d | cutscene %d",
            metrics.permitted or 0,
            metrics.requested or 0,
            metrics.completed or 0,
            metrics.rejected_resume or 0,
            metrics.waiting_cutscene or 0),
        string.format(
            "%4s %-22s %-11s %-36s %-24s %-20s %s",
            "Dist",
            "Enemy",
            "HP",
            "GUID",
            "Pool",
            "Pos",
            "State"),
    }
    local row_data = {}
    local max_line_length = 0

    for _, line in ipairs(lines) do
        if #line > max_line_length then
            max_line_length = #line
        end
    end

    for index = 1, visible_count do
        local item = items[index]
        local row_line = string.format(
            "%3dm %-22s %-11s %-36s %-24s %-20s %s",
            math.floor((item.distance or 0) + 0.5),
            clamp_text(item.enemy_label, ENEMY_LABEL_MAX_CHARS),
            format_spawn_hp(item),
            tostring(item.guid or "-"),
            clamp_text(item.pool_name or "-", ENEMY_POOL_NAME_MAX_CHARS),
            format_spawn_position(item.position or item.spawn_position),
            build_spawn_state_summary(item))

        if #row_line > max_line_length then
            max_line_length = #row_line
        end

        row_data[#row_data + 1] = {
            color = item.active and 0xFF44FF88 or (item.recently_despawned and 0xFF6666FF or 0xFFFFFFFF),
            line = row_line,
        }
    end

    local width = math.max(760, 42 + (max_line_length * 9))
    local line_height = 22
    local height = 22 + (#lines * line_height) + (#row_data * line_height) + 18
    local x = 30
    local y = 80
    local size = get_window_size()
    if size and size.w then
        width = math.min(width, math.max(420, size.w - 60))
        x = math.max(30, size.w - width - 30)
        if size.h and (y + height + 30) > size.h then
            y = math.max(30, size.h - height - 30)
        end
    end

    return {
        lines = lines,
        row_data = row_data,
        items = items,
        visible_count = visible_count,
        x = x,
        y = y,
        width = width,
        height = height,
        line_height = line_height,
    }
end

local function draw_enemy_spawn_overlay()
    local layout = build_enemy_spawn_overlay_rows()
    if not layout then
        return
    end

    local bg = 0xCC000000
    local lime = 0xFF00FF00
    local white = 0xFFFFFFFF
    local line_height = layout.line_height or 22
    local header_font = get_overlay_font(18, true)
    local value_font = get_overlay_font(18, false)

    if d2d and header_font and value_font then
        pcall(d2d.fill_rect, layout.x, layout.y, layout.width, layout.height, bg)
        pcall(d2d.fill_rect, layout.x, layout.y, 4, layout.height, lime)
        pcall(d2d.text, header_font, layout.lines[1], layout.x + 14, layout.y + 10, lime)
        for line_index = 2, #layout.lines do
            pcall(d2d.text, value_font, layout.lines[line_index], layout.x + 14,
                layout.y + 10 + ((line_index - 1) * line_height), white)
        end
        local draw_y = layout.y + 10 + (#layout.lines * line_height)
        for _, row in ipairs(layout.row_data) do
            pcall(d2d.text, value_font, row.line, layout.x + 14, draw_y, row.color)
            draw_y = draw_y + line_height
        end
        return
    end

    if draw then
        pcall(draw.filled_rect, layout.x, layout.y, layout.width, layout.height, bg)
        pcall(draw.filled_rect, layout.x, layout.y, 4, layout.height, lime)
        pcall(draw.text, layout.lines[1], layout.x + 14, layout.y + 10, lime)
        for line_index = 2, #layout.lines do
            pcall(draw.text, layout.lines[line_index], layout.x + 14,
                layout.y + 10 + ((line_index - 1) * line_height), white)
        end
        local draw_y = layout.y + 10 + (#layout.lines * line_height)
        for _, row in ipairs(layout.row_data) do
            pcall(draw.text, row.line, layout.x + 14, draw_y, row.color)
            draw_y = draw_y + line_height
        end
    end
end

local function draw_enemy_spawn_overlay_window()
    local layout = build_enemy_spawn_overlay_rows()
    if not layout then
        return
    end

    pcall(function()
        imgui.set_next_window_pos(Vector2f.new(layout.x, layout.y), 1)
    end)
    pcall(function()
        imgui.set_next_window_size(Vector2f.new(layout.width, layout.height), 1)
    end)

    if imgui.begin_window("BioRand Enemy Spawns###biorand_enemy_spawns", true, 0) then
        imgui.text_colored(layout.lines[1], 0xFF44FF88)
        for line_index = 2, (#layout.lines - 1) do
            imgui.text(layout.lines[line_index])
        end
        imgui.separator()
        if imgui.begin_table("biorand_enemy_spawn_table", 7, 0, Vector2f.new(0, 0), 0) then
            imgui.table_setup_column("Dist", 16, 56, 0)
            imgui.table_setup_column("Enemy", 16, 160, 0)
            imgui.table_setup_column("HP", 16, 92, 0)
            imgui.table_setup_column("GUID", 16, 300, 0)
            imgui.table_setup_column("Pool", 16, 160, 0)
            imgui.table_setup_column("Pos", 16, 170, 0)
            imgui.table_setup_column("State", 0, 1, 0)
            imgui.table_headers_row()

            for index = 1, layout.visible_count do
                local item = layout.items[index]
                local row_color = item.active and 0xFF44FF88 or (item.recently_despawned and 0xFF6666FF or 0xFFFFFFFF)
                imgui.table_next_row()

                imgui.table_next_column()
                imgui.text_colored(string.format("%dm", math.floor((item.distance or 0) + 0.5)), row_color)

                imgui.table_next_column()
                imgui.text_colored(clamp_text(item.enemy_label, ENEMY_LABEL_MAX_CHARS), row_color)

                imgui.table_next_column()
                imgui.text_colored(format_spawn_hp(item), row_color)

                imgui.table_next_column()
                imgui.text_colored(tostring(item.guid or "-"), row_color)

                imgui.table_next_column()
                imgui.text_colored(clamp_text(item.pool_name or "-", ENEMY_POOL_NAME_MAX_CHARS), row_color)

                imgui.table_next_column()
                imgui.text_colored(format_spawn_position(item.position or item.spawn_position), row_color)

                imgui.table_next_column()
                imgui.text_colored(build_spawn_state_summary(item), row_color)
            end

            imgui.end_table()
        end
        imgui.end_window()
    end
end

local function process_spawn_input()
    if key_just_pressed("set_spawn_template", 0x6A) then
        set_spawn_template_from_selected()
    end
    if key_just_pressed("spawn_add", 0x6B) then
        log_info("Spawn hotkey pressed: Numpad +")
        spawn_placeable_object()
    end
    if key_just_pressed("toggle_precise_mode", 0x6F) then
        toggle_precise_mode()
    end
    if any_key_just_pressed("move_selected_to_front", { 0x6E, 0x2E }) then
        move_selected_to_placement_point()
    end
    if key_just_pressed("cycle_selected_prev", 0xBC) then
        cycle_selected_entry(-1)
    end
    if key_just_pressed("cycle_selected_next", 0xBE) then
        cycle_selected_entry(1)
    end
    if key_just_pressed("copy_selected_csv", 0x0D) then
        if state.selected then
            copy_selected_transform(state.selected)
        else
            log_warn("Copy ignored: no selected object")
        end
    end
    if key_just_pressed("delete_selected", 0x6D) then
        destroy_selected_object()
    end

    local right, _, forward = get_camera_basis()
    right = vec_normalize_flat(right, Vector3f.new(1, 0, 0))
    forward = vec_normalize_flat(forward, Vector3f.new(0, 0, 1))

    local step = cfg.precise_mode and 0.01 or 0.05
    local rotation_step = cfg.precise_mode and 1.0 or 22.5
    if state.selected then
        if key_just_pressed("nudge_left", 0x64) then
            defer(function()
                nudge_selected_object(-right.x * step, 0, -right.z * step)
            end)
        end
        if key_just_pressed("nudge_up", 0x68) then
            defer(function()
                nudge_selected_object(forward.x * step, 0, forward.z * step)
            end)
        end
        if key_just_pressed("nudge_right", 0x66) then
            defer(function()
                nudge_selected_object(right.x * step, 0, right.z * step)
            end)
        end
        if key_just_pressed("nudge_down", 0x62) then
            defer(function()
                nudge_selected_object(-forward.x * step, 0, -forward.z * step)
            end)
        end
        if key_just_pressed("nudge_y_down", 0x61) then
            defer(function()
                nudge_selected_object(0, -step, 0)
            end)
        end
        if key_just_pressed("nudge_y_up", 0x63) then
            defer(function()
                nudge_selected_object(0, step, 0)
            end)
        end
        if key_just_pressed("rotate_left", 0x67) then
            defer(function()
                rotate_selected_yaw(-rotation_step)
            end)
        end
        if key_just_pressed("rotate_right", 0x69) then
            defer(function()
                rotate_selected_yaw(rotation_step)
            end)
        end
    end
end

local function render_window()
    if not cfg.show_objects then
        return
    end

    if imgui.begin_window("BioRand Object Explorer", true, 0) then
        local changed = false

        local auto_changed, auto_value = imgui.checkbox("Auto refresh", cfg.auto_refresh)
        if auto_changed then
            cfg.auto_refresh = auto_value
            changed = true
        end

        local filter_changed, filter_value = imgui.input_text("Filter##bio_filter", cfg.filter, 256)
        if filter_changed then
            cfg.filter = filter_value
            changed = true
        end

        local component_changed, component_value = imgui.input_text("Required Component##bio_component",
            cfg.required_component, 256)
        if component_changed then
            cfg.required_component = component_value
            changed = true
        end
        imgui.text_colored("Filter examples: app.ItemCore, app.GimmickCore, via.render.Mesh", 0xFFAAAAAA)

        local distance_changed, distance_value = imgui.drag_float("Max Dist##bio_dist", cfg.max_distance, 1.0, 0.0,
            5000.0, "%.1f")
        if distance_changed then
            cfg.max_distance = math.max(0.0, distance_value)
            changed = true
        end
        imgui.same_line()
        imgui.text("(0 = all)")

        local results_changed, results_value = imgui.drag_int("Max Results##bio_results", cfg.max_results, 1, 10, 200)
        if results_changed then
            cfg.max_results = math.max(10, results_value)
            changed = true
        end

        local interval_changed, interval_value = imgui.drag_float("Scan Interval##bio_interval", cfg.scan_interval, 0.01,
            0.05, 10.0, "%.2f")
        if interval_changed then
            cfg.scan_interval = math.max(0.05, interval_value)
            changed = true
        end

        if changed then
            state.force_refresh = true
            cfg_save()
        end

        if imgui.button("Remove all BioRand placed meshes##bio_remove_all") then
            destroy_all_biorand_objects()
        end

        draw_object_table()
        draw_selected_editor()
    end
    imgui.end_window()
end

re.on_application_entry("UpdateMotion", function()
    process_deferred()
end)

re.on_frame(function()
    process_spawn_input()
    draw_selected_gizmo(state.selected)
    if cfg.show_objects then
        maybe_refresh()
    end
    maybe_refresh_level_flows()
    maybe_refresh_enemy_spawn_overlay()
end)

re.on_draw_ui(function()
    if imgui.collapsing_header("BioRand") then
        local changed, value = imgui.checkbox("Show object explorer", cfg.show_objects)
        if changed then
            cfg.show_objects = value
            state.force_refresh = true
            cfg_save()
        end
        if cfg.show_objects then
            imgui.text_colored(
                "RE9 object browser using app.ItemCore, app.GimmickCore, app.ItemSpawner, and via.render.Mesh.",
                0xFFAAAAAA)
        end

        local levelflow_changed, levelflow_value = imgui.checkbox("Show levelflow overlay", cfg.show_levelflow_overlay)
        if levelflow_changed then
            cfg.show_levelflow_overlay = levelflow_value
            state.levelflow_force_refresh = true
            cfg_save()
        end
        if cfg.show_levelflow_overlay then
            imgui.text_colored(
                "Shows active scene levelflows and their current state IDs. Green rows changed within the last minute.",
                0xFFAAAAAA)
        end

        local enemy_spawn_changed, enemy_spawn_value = imgui.checkbox("Show enemy spawn overlay",
            cfg.show_enemy_spawn_overlay)
        if enemy_spawn_changed then
            cfg.show_enemy_spawn_overlay = enemy_spawn_value
            state.enemy_spawn_force_refresh = true
            cfg_save()
        end
        if cfg.show_enemy_spawn_overlay then
            imgui.text_colored(
                "Shows nearest enemy spawn points, pool usage, recent despawns, and spawn-control flags.",
                0xFFAAAAAA)
        end
    end

    render_window()
    draw_enemy_spawn_overlay_window()
end)

if d2d then
    d2d.register(function() end, function()
        pcall(draw_levelflow_overlay)
        pcall(draw_selected_status_overlay)
        pcall(draw_key_shortcuts_overlay)
    end)
end

re.on_script_reset(function()
    state.items = {}
    state.levelflows = {}
    state.levelflow_state_history = {}
    state.selected = nil
    state.selected_key = nil
    state.deferred = {}
    state.spawned_objects = {}
    state.pinned_addresses = {}
    state.levelflow_last_scan = 0
    state.levelflow_force_refresh = true
    state.levelflow_scene_address = 0
    state.enemy_spawn_entries = {}
    state.enemy_spawn_metrics = nil
    state.enemy_spawn_recent_despawns = {}
    state.enemy_spawn_active_by_guid = {}
    state.enemy_spawn_last_scan = 0
    state.enemy_spawn_force_refresh = true
    state.enemy_spawn_scene_address = 0
    state.enemy_spawn_summary_log = nil
    state.last_spawned_address = nil
    overlay_font_regular = nil
    overlay_font_bold = nil
    component_cache = {}
end)

cfg_load()
log_info("Loaded.")
