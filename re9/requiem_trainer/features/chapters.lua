-- ═══════════════════════════════════════════════════════════════════════════
-- Requiem Trainer — Chapters Sub-Module
-- Chapter detection, MurmurHash, progress cache, jumping, LevelFlowController
-- ═══════════════════════════════════════════════════════════════════════════

local T = ... or _G.__REQUIEM_T
local C, R = T.C, T.R
local mgr, toast, get_scene = T.mgr, T.toast, T.get_scene
local cfg_save = T.cfg_save
local CHAPTER_NAMES = {
    ["Chap1_01"]   = "Chapter 1-1",
    ["Chap1_10"]   = "Chapter 1-10",
    ["Chap3_01"]   = "Chapter 3-1",
    ["Chap3_02"]   = "Chapter 3-2",
    ["Chap3_03"]   = "Chapter 3-3",
    ["Chap3_04"]   = "Chapter 3-4 [MARIE'S DOLL]",
    ["Chap3_05"]   = "Chapter 3-5",
    ["Chap3_10"]   = "Chapter 3-10",
    ["Chap3_20"]   = "Chapter 3-20",
    ["Chap3_24"]   = "Chapter 3-24",
    ["Chap3_40"]   = "Chapter 3-40",
    ["Chap4_10"]   = "Chapter 4-10",
    ["Chap4_20"]   = "Chapter 4-20",
    ["Chap4_30"]   = "Chapter 4-30",
    ["Chap4_40"]   = "Chapter 4-40",
    ["Chap4_50"]   = "Chapter 4-50",
    ["Chap5_02"]   = "Chapter 5-2",
    ["Chap5_03"]   = "Chapter 5-3 [TRUE ENDING]",
    ["Chap5_04"]   = "Chapter 5-4 [NORMAL ENDING]",
    ["Chap5_05"]   = "Chapter 5-5",
    ["Chap5_10"]   = "Chapter 5-10",
}

-- Build sorted scene name list + display list
local chapter_scene_names = {}
for scene, _ in pairs(CHAPTER_NAMES) do
    chapter_scene_names[#chapter_scene_names + 1] = scene
end
table.sort(chapter_scene_names)

local chapter_list = {}
for i, scene in ipairs(chapter_scene_names) do
    chapter_list[i] = CHAPTER_NAMES[scene] .. "  [" .. scene .. "]"
end

-- Chapter UI state
local chapter_ui = {
    selected_index = 1,
    jump_status = "",
    jump_status_color = 0xFFFFFFFF,
    runtime_scenes = nil,
    progress_discovered = false,
    progress_target_value = 0,
}

local progress_selected_index = 1
local progress_value_index = 1

-- ═══════════════════════════════════════════════════════════════════════════
-- MurmurHash2 — matches game's internal hash for progress names
-- ═══════════════════════════════════════════════════════════════════════════

local band, bxor, rshift, lshift
if bit then
    band = bit.band; bxor = bit.bxor; rshift = bit.rshift; lshift = bit.lshift
else
    band = load("return function(a,b) return a & b end")()
    bxor = load("return function(a,b) return a ~ b end")()
    rshift = load("return function(a,b) return a >> b end")()
    lshift = load("return function(a,b) return a << b end")()
end

local function mul32(a, b)
    return band(a * b, 0xFFFFFFFF)
end

local function murmur_hash2(str, seed)
    seed = seed or 0xFFFFFFFF
    local len = #str
    local m = 0x5BD1E995
    local h = bxor(seed, len)

    local i = 1
    while i + 3 <= len do
        local k = str:byte(i) + str:byte(i+1) * 0x100 + str:byte(i+2) * 0x10000 + str:byte(i+3) * 0x1000000
        k = mul32(k, m)
        k = bxor(k, rshift(k, 24))
        k = mul32(k, m)
        h = mul32(h, m)
        h = bxor(h, k)
        i = i + 4
    end

    local rem = len - i + 1
    if rem >= 3 then h = bxor(h, lshift(str:byte(i+2), 16)) end
    if rem >= 2 then h = bxor(h, lshift(str:byte(i+1), 8)) end
    if rem >= 1 then
        h = bxor(h, str:byte(i))
        h = mul32(h, m)
    end

    h = bxor(h, rshift(h, 13))
    h = mul32(h, m)
    h = bxor(h, rshift(h, 15))

    return band(h, 0xFFFFFFFF)
end

local function compute_hash(name)
    if not name or name == "" then return nil end
    local ok, result = pcall(murmur_hash2, name)
    if ok then return result end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Progress Cache — persisted to JSON
-- ═══════════════════════════════════════════════════════════════════════════

local PROGRESS_CACHE_FILE = "re9_progress_cache.json"
local chapter_progress_cache = {}
local progress_hook_installed = false
local progress_value_hook_installed = false

-- Load existing cache
pcall(function()
    local data = json.load_file(PROGRESS_CACHE_FILE)
    if data then
        chapter_progress_cache = data
        for _, entries in pairs(chapter_progress_cache) do
            for _, e in ipairs(entries) do
                if not e.values then e.values = {} end
            end
        end
    end
end)

local function save_progress_cache()
    pcall(function() json.dump_file(PROGRESS_CACHE_FILE, chapter_progress_cache) end)
end

-- Hash lookup table for fast reverse lookups
local progress_hash_lookup = {}
local function rebuild_hash_lookup()
    progress_hash_lookup = {}
    for scene, entries in pairs(chapter_progress_cache) do
        for idx, entry in ipairs(entries) do
            if entry.hash then
                progress_hash_lookup[entry.hash] = { scene = scene, idx = idx }
            end
        end
    end
end

-- Fix any entries missing hashes on startup
do
    local fixed = 0
    for _, entries in pairs(chapter_progress_cache) do
        for _, e in ipairs(entries) do
            if not e.hash and e.name then
                e.hash = compute_hash(e.name)
                if e.hash then fixed = fixed + 1 end
            end
        end
    end
    if fixed > 0 then
        save_progress_cache()
        log.info("[Trainer] Recomputed " .. fixed .. " missing hashes in progress cache")
    end
end
rebuild_hash_lookup()

local function cache_progress_name(scene_name, prog_name)
    if not scene_name or not prog_name or prog_name == "" then return end
    if not chapter_progress_cache[scene_name] then
        chapter_progress_cache[scene_name] = {}
    end
    for _, existing in ipairs(chapter_progress_cache[scene_name]) do
        if existing.name == prog_name then return end
    end
    local hash = compute_hash(prog_name)
    table.insert(chapter_progress_cache[scene_name], { name = prog_name, hash = hash, values = {} })
    save_progress_cache()
    rebuild_hash_lookup()
    log.info("[Trainer] Discovered progress name: " .. scene_name .. " -> " .. prog_name
        .. (hash and (" hash=0x" .. string.format("%X", hash)) or ""))
end

local function cache_progress_value(hash, value)
    if not hash or not value then return end
    local lookup = progress_hash_lookup[hash]
    if not lookup then return end
    local entry = chapter_progress_cache[lookup.scene] and chapter_progress_cache[lookup.scene][lookup.idx]
    if not entry then return end
    if not entry.values then entry.values = {} end
    for _, v in ipairs(entry.values) do
        if v == value then return end
    end
    table.insert(entry.values, value)
    table.sort(entry.values)
    save_progress_cache()
    log.info("[Trainer] Discovered progress value: " .. entry.name .. " = " .. tostring(value))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Progress Hooks — capture progress names and values during gameplay
-- ═══════════════════════════════════════════════════════════════════════════

local function install_progress_value_hook()
    if progress_value_hook_installed then return end
    pcall(function()
        local lfm_td = sdk.find_type_definition("app.LevelFlowManager")
        if not lfm_td then return end
        local method = lfm_td:get_method("requestChangeProgressiveNumber")
        if not method then return end

        sdk.hook(method,
            function(args)
                pcall(function()
                    local hash = sdk.to_int64(args[3]) & 0xFFFFFFFF
                    local value = sdk.to_int64(args[4]) & 0xFFFFFFFF
                    if value >= 0x80000000 then value = value - 0x100000000 end
                    cache_progress_value(hash, value)
                end)
            end,
            function(retval) return retval end
        )
        progress_value_hook_installed = true
        log.info("[Trainer] Installed requestChangeProgressiveNumber hook for value capture")
    end)
end

local function install_progress_hook()
    if progress_hook_installed then return end
    pcall(function()
        local lfm_td = sdk.find_type_definition("app.LevelFlowManager")
        if not lfm_td then return end

        local reg_m = lfm_td:get_method("registerProgressiveNumber")
        if not reg_m then return end

        sdk.hook(reg_m,
            function(args)
                pcall(function()
                    local user_data = sdk.to_managed_object(args[3])
                    if not user_data then return end

                    local name_list = user_data:get_field("_NameList")
                    if not name_list then return end

                    local count = name_list:call("get_Length") or 0

                    local scene = "unknown"
                    pcall(function()
                        local flow_mgr = mgr("app.MainGameFlowManager")
                        if flow_mgr then
                            local ctrl = flow_mgr:get_field("_CurrentController")
                            if ctrl then
                                scene = ctrl:get_field("_CurrentMainSceneName") or "unknown"
                            end
                        end
                    end)

                    for i = 0, count - 1 do
                        pcall(function()
                            local name = name_list:call("Get", i)
                            if name then
                                cache_progress_name(scene, tostring(name))
                            end
                        end)
                    end
                end)
            end,
            function(retval) return retval end
        )
        progress_hook_installed = true
        log.info("[Trainer] Installed registerProgressiveNumber hook for progress discovery")
    end)
end

-- Install hooks immediately
install_progress_hook()
install_progress_value_hook()

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlowCatalog Discovery — bulk discover progress names from catalog
-- ═══════════════════════════════════════════════════════════════════════════

local function find_level_flow_catalog()
    local catalog = nil
    pcall(function()
        local scene_mgr = sdk.get_native_singleton("via.SceneManager")
        if not scene_mgr then return end
        local scene_mgr_td = sdk.find_type_definition("via.SceneManager")
        if not scene_mgr_td then return end
        local main_scene = sdk.call_native_func(scene_mgr, scene_mgr_td, "get_MainScene")
        if not main_scene then return end
        local catalog_td = sdk.find_type_definition("app.LevelFlowCatalog")
        if not catalog_td then return end
        local rt = catalog_td:get_runtime_type()
        if not rt then return end
        local found = main_scene:call("findComponents(System.Type)", rt)
        if found then
            local count = found:call("get_Count") or 0
            if count > 0 then
                catalog = found:call("get_Item", 0)
            end
        end
    end)
    return catalog
end

local function discover_all_progress_names()
    local results = { all_names = {}, by_scene = {}, errors = {} }

    local catalog = find_level_flow_catalog()
    if not catalog then
        table.insert(results.errors, "LevelFlowCatalog not found via SceneManager")
        pcall(function() json.dump_file("re9_progress_discovery.json", results) end)
        return results
    end

    local holder = catalog:get_field("_ProgressiveNoUserData")
    if not holder then
        table.insert(results.errors, "_ProgressiveNoUserData is nil")
        pcall(function() json.dump_file("re9_progress_discovery.json", results) end)
        return results
    end

    local lists_to_try = { "_CatalogDataList", "_RegistratedItems" }
    for _, field_name in ipairs(lists_to_try) do
        pcall(function()
            local data_list = holder:get_field(field_name)
            if not data_list then return end

            local count = 0
            pcall(function() count = data_list:call("get_Count") end)
            if count == 0 then
                pcall(function() count = data_list:call("get_Length") end)
            end
            if count == 0 then return end

            results[field_name .. "_count"] = count

            for i = 0, count - 1 do
                pcall(function()
                    local item = nil
                    pcall(function() item = data_list:call("get_Item", i) end)
                    if not item then
                        pcall(function() item = data_list:call("Get", i) end)
                    end
                    if not item then return end

                    local name_list = item:get_field("_NameList")
                    if not name_list then return end

                    local ncount = 0
                    pcall(function() ncount = name_list:call("get_Length") end)
                    if ncount == 0 then
                        pcall(function() ncount = name_list:call("get_Count") end)
                    end

                    for j = 0, ncount - 1 do
                        pcall(function()
                            local name = nil
                            pcall(function() name = name_list:call("Get", j) end)
                            if not name then
                                pcall(function() name = name_list:call("get_Item", j) end)
                            end
                            if name then
                                local name_str = tostring(name)
                                table.insert(results.all_names, name_str)

                                -- Extract scene name from progress name (e.g. "Chap3_04_xxx" -> "Chap3_04")
                                local scene = name_str:match("^(Chap%d+_%d+)")
                                if scene then
                                    if not results.by_scene[scene] then
                                        results.by_scene[scene] = {}
                                    end
                                    table.insert(results.by_scene[scene], name_str)
                                    cache_progress_name(scene, name_str)
                                end
                            end
                        end)
                    end
                end)
            end
        end)

        if #results.all_names > 0 then break end
    end

    rebuild_hash_lookup()

    -- Also read current progress values from LevelFlowManager dictionary
    pcall(function()
        local level_mgr = mgr("app.LevelFlowManager")
        if not level_mgr then return end
        local prog_list = level_mgr:get_field("_ProgressiveNumberList")
        if not prog_list then return end
        local count = prog_list:call("get_Count")
        if not count or count == 0 then return end
        local keys = prog_list:call("get_Keys")
        local values = prog_list:call("get_Values")
        if not keys or not values then return end
        results.current_dict_count = count
        local dict_hashes = {}
        for i = 0, count - 1 do
            pcall(function()
                local hash = keys:call("get_Item", i)
                local value = values:call("get_Item", i)
                if hash and value then
                    cache_progress_value(hash, value)
                    dict_hashes[hash] = value
                end
            end)
        end

        -- Verify our computed hashes match the game's dict
        results.hash_verification = {}
        for _, name in ipairs(results.all_names) do
            local computed = compute_hash(name)
            if computed then
                local matched = dict_hashes[computed]
                if matched ~= nil then
                    table.insert(results.hash_verification, {
                        name = name,
                        hash = string.format("0x%08X", computed),
                        dict_value = matched,
                        status = "MATCH"
                    })
                end
            end
        end
    end)

    log.info("[Trainer] Progress discovery: " .. #results.all_names .. " names from catalog")
    pcall(function() json.dump_file("re9_progress_discovery.json", results) end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Runtime Scene Discovery — reads _GameScenes keys from controller
-- ═══════════════════════════════════════════════════════════════════════════

local function discover_runtime_scenes()
    if chapter_ui.runtime_scenes then return end
    pcall(function()
        local flow_mgr = mgr("app.MainGameFlowManager")
        if not flow_mgr then return end
        local controller = flow_mgr:get_field("_CurrentController")
        if not controller then return end
        local game_scenes = controller:get_field("_GameScenes")
        if not game_scenes then return end
        local entries = game_scenes:call("get_Keys")
        if not entries then return end
        local count = entries:call("get_Count")
        if not count or count == 0 then return end
        local scenes = {}
        for i = 0, count - 1 do
            local key = entries:call("get_Item", i)
            if key and type(key) == "string" then
                table.insert(scenes, key)
            end
        end
        table.sort(scenes)
        chapter_ui.runtime_scenes = scenes
        -- Merge runtime scenes into chapter names
        for _, scene in ipairs(scenes) do
            if not CHAPTER_NAMES[scene] then
                CHAPTER_NAMES[scene] = scene
            end
        end
        -- Rebuild sorted lists
        chapter_scene_names = {}
        for scene, _ in pairs(CHAPTER_NAMES) do
            table.insert(chapter_scene_names, scene)
        end
        table.sort(chapter_scene_names)
        chapter_list = {}
        for i, scene in ipairs(chapter_scene_names) do
            chapter_list[i] = CHAPTER_NAMES[scene] .. "  [" .. scene .. "]"
        end
        log.info("[Trainer] Discovered " .. #scenes .. " runtime scenes from _GameScenes")
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LevelFlowController Scanner — find all GOs with app.LevelFlowController
-- and read their current state / BehaviorTree active node
-- ═══════════════════════════════════════════════════════════════════════════

local _lfc_type = nil
local _bhvt_type = nil
pcall(function() _lfc_type = sdk.typeof("app.LevelFlowController") end)
pcall(function() _bhvt_type = sdk.typeof("via.behaviortree.BehaviorTree") end)

local function scan_level_flow_controllers()
    local results = {}
    pcall(function()
        local scene = get_scene()
        if not scene then return end

        -- Find all app.LevelFlowController components
        if not _lfc_type then return end
        local lfc_td = sdk.find_type_definition("app.LevelFlowController")
        if not lfc_td then return end
        local comps = scene:call("findComponents(System.Type)", lfc_td:get_runtime_type())
        if not comps then return end
        local ok_c, comp_count = pcall(comps.call, comps, "get_Count")
        if not ok_c or not comp_count or comp_count <= 0 then return end

        for i = 0, math.min(comp_count - 1, 50) do
            pcall(function()
                local lfc = comps:call("get_Item", i)
                if not lfc then return end
                local go = lfc:call("get_GameObject")
                if not go then return end
                local go_name = tostring(go:call("get_Name") or "?")

                -- Get position from transform
                local pos = nil
                pcall(function()
                    local xf = go:call("get_Transform")
                    if xf then pos = xf:call("get_Position") end
                end)

                local entry = {
                    go_name = go_name,
                    pos = pos,
                    fields = {},
                    bt_node = nil,
                    bt_nodes = {},
                }

                -- Probe LevelFlowController fields and methods for state info
                pcall(function()
                    local td = lfc:get_type_definition()
                    if not td then return end
                    -- Try reading fields
                    local field_names = {
                        "_CurrentState", "_State", "_CurrentNode", "_CurrentNodeName",
                        "_Progress", "_CurrentProgress", "_FlowState", "_Phase",
                    }
                    for _, fname in ipairs(field_names) do
                        pcall(function()
                            local val = lfc:get_field(fname)
                            if val ~= nil then
                                entry.fields[fname] = tostring(val)
                            end
                        end)
                    end
                    -- Try calling no-arg getters
                    local method_names = {
                        "get_CurrentState", "get_State", "get_CurrentNodeName",
                        "get_CurrentNode", "get_Progress", "get_FlowState",
                        "get_Phase", "get_IsFinished", "get_IsRunning",
                        "getCurrentNodeName", "GetCurrentState",
                    }
                    for _, mname in ipairs(method_names) do
                        pcall(function()
                            local m = td:get_method(mname)
                            if m and m:get_num_params() == 0 then
                                local val = m:call(nil, lfc)
                                if val == nil then
                                    val = lfc:call(mname)
                                end
                                if val ~= nil then
                                    entry.fields[mname .. "()"] = tostring(val)
                                end
                            end
                        end)
                    end
                end)

                -- Read sibling BehaviorTree's current node
                if _bhvt_type then
                    pcall(function()
                        local bt = go:call("getComponent(System.Type)", _bhvt_type)
                        if not bt then return end
                        -- Try multiple approaches to get the current BT node
                        pcall(function()
                            local node = bt:call("getCurrentNode", 0)
                            if node then
                                local name = node:call("get_FullName")
                                if name then entry.bt_node = tostring(name) end
                            end
                        end)
                        -- Try alternate: get_CurrentNodeName
                        if not entry.bt_node then
                            pcall(function()
                                local name = bt:call("getCurrentNodeName", 0)
                                if name then entry.bt_node = tostring(name) end
                            end)
                        end
                        -- Try: getTreeUserVariables for node tracking
                        pcall(function()
                            local tree_obj = bt:call("get_TreeObject")
                            if not tree_obj then return end
                            -- Get current node from tree
                            pcall(function()
                                local cur = tree_obj:call("get_CurrentNode")
                                if cur then
                                    local n = cur:call("get_Name") or cur:call("get_FullName")
                                    if n and not entry.bt_node then
                                        entry.bt_node = tostring(n)
                                    end
                                end
                            end)
                        end)
                        -- Dump all active node names from layers
                        pcall(function()
                            local layer_count = bt:call("getLayerCount")
                            if not layer_count then return end
                            for li = 0, math.min(layer_count - 1, 5) do
                                pcall(function()
                                    local node = bt:call("getCurrentNode", li)
                                    if node then
                                        local name = nil
                                        pcall(function() name = node:call("get_FullName") end)
                                        if not name then pcall(function() name = node:call("get_Name") end) end
                                        if name then
                                            entry.bt_nodes[#entry.bt_nodes + 1] = "L" .. li .. ": " .. tostring(name)
                                            if li == 0 and not entry.bt_node then
                                                entry.bt_node = tostring(name)
                                            end
                                        end
                                    end
                                end)
                            end
                        end)
                    end)
                end

                results[#results + 1] = entry
            end)
        end
    end)
    R.level_flow_controllers = results
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Chapter Info Update — reads scene, scenario time, level progress
-- ═══════════════════════════════════════════════════════════════════════════


local chapter_info = {
    scene_name = "Unknown",
    scenario_time = "Unknown",
    level_progress = "Unknown",
    level_progress_name = nil,
    level_progress_no = nil,
    is_main_game = false,
}

local function scan_chapter()
    local ok, err = pcall(function()
        local flow_mgr = mgr("app.MainGameFlowManager")
        if not flow_mgr then
            chapter_info.scene_name = "(no FlowManager)"
            return
        end
        pcall(function() chapter_info.is_main_game = flow_mgr:call("IsMainGame") end)
        local controller = flow_mgr:get_field("_CurrentController")
        if not controller then
            chapter_info.scene_name = "(no controller)"
            return
        end
        local scene_name = controller:get_field("_CurrentMainSceneName")
        chapter_info.scene_name = scene_name or "(nil)"
    end)
    if not ok then
        chapter_info.scene_name = "(error: " .. tostring(err) .. ")"
    end

    -- Scenario time kind name
    pcall(function()
        local time_mgr = mgr("app.ScenarioTimeManager")
        if not time_mgr then return end
        local current_kind = time_mgr:call("get_CurrentKind")
        if not current_kind then return end
        local name = current_kind:get_field("_Name")
        if name then chapter_info.scenario_time = name end
    end)

    -- Level progress from LevelFlowManager
    pcall(function()
        local level_mgr = mgr("app.LevelFlowManager")
        if not level_mgr then return end
        local progress_name = level_mgr:call("getDyingProgressName")
        local progress_no = level_mgr:call("getDyingProgressNo")
        if progress_name and progress_name ~= "" then
            chapter_info.level_progress = progress_name
            chapter_info.level_progress_name = progress_name
            chapter_info.level_progress_no = progress_no
            if progress_no then
                chapter_info.level_progress = chapter_info.level_progress .. " (#" .. tostring(progress_no) .. ")"
            end
            -- Cache to progress cache
            local scene = chapter_info.scene_name
            if scene and scene ~= "Unknown" and scene ~= "(nil)" and not scene:find("^%(") then
                cache_progress_name(scene, progress_name)
                if progress_no then
                    local hash = compute_hash(progress_name)
                    if hash then cache_progress_value(hash, progress_no) end
                end
            end
        end
    end)

    -- Also set R.chapter_info for backwards compat
    R.chapter_info = {
        scene = chapter_info.scene_name,
        chapter_name = CHAPTER_NAMES[chapter_info.scene_name] or nil,
        progress = chapter_info.level_progress_no,
        scenario_time = chapter_info.scenario_time,
        is_main_game = chapter_info.is_main_game,
        level_progress = chapter_info.level_progress,
        level_progress_name = chapter_info.level_progress_name,
    }
    return R.chapter_info
end

local function get_friendly_name(scene_name)
    if not scene_name then return "Unknown" end
    return CHAPTER_NAMES[scene_name] or scene_name
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Jump Continuation — monitors transition, optionally sets progress
-- ═══════════════════════════════════════════════════════════════════════════

local jump_cont = {
    active = false,
    target_scene = nil,
    state = nil,
    frame_count = 0,
    last_running = nil,
    saw_scene_flow = false,
    progress_hash = nil,
    progress_value = nil,
}

local function process_jump_continuation()
    if not jump_cont.active then return end
    jump_cont.frame_count = jump_cont.frame_count + 1
    local f = jump_cont.frame_count

    local stm = mgr("app.SceneTransitionManager")
    local is_running = false
    if stm then pcall(function() is_running = stm:call("get_IsRunningTransition") end) end

    if jump_cont.state == "wait_transition" then
        if is_running then jump_cont.saw_scene_flow = true end

        -- Log transition state changes
        if is_running ~= jump_cont.last_running then
            log.info("[Trainer] JUMP-CONT[f:" .. f .. "]: IsRunningTransition=" .. tostring(is_running))
            jump_cont.last_running = is_running
        end

        -- Transition completed → set progress if requested
        if not is_running and jump_cont.saw_scene_flow then
            log.info("[Trainer] JUMP-CONT[f:" .. f .. "]: transition complete — in gameplay")

            -- Optionally set progress value after landing
            if jump_cont.progress_hash then
                pcall(function()
                    local level_mgr = mgr("app.LevelFlowManager")
                    if level_mgr then
                        level_mgr:call("requestChangeProgressiveNumber",
                            jump_cont.progress_hash, jump_cont.progress_value or 1)
                        log.info("[Trainer] JUMP-CONT: set progress hash="
                            .. string.format("0x%X", jump_cont.progress_hash)
                            .. " value=" .. tostring(jump_cont.progress_value))
                    end
                end)
                chapter_ui.jump_status = "Jumped to " .. (jump_cont.target_scene or "?")
                    .. " (progress set)"
            else
                chapter_ui.jump_status = "Jumped to " .. (jump_cont.target_scene or "?")
            end
            chapter_ui.jump_status_color = 0xFF00FF00
            jump_cont.active = false

            -- Cleanup override
            pcall(function()
                local fm = mgr("app.MainGameFlowManager")
                if fm then fm:call("resetOverrideNextJumpScene") end
            end)
            return
        end

        -- Timeout after 60 seconds (3600 frames at 60fps)
        if f > 3600 then
            log.info("[Trainer] JUMP-CONT: timeout (running=" .. tostring(is_running)
                .. " saw_flow=" .. tostring(jump_cont.saw_scene_flow) .. ")")
            chapter_ui.jump_status = "Jump timeout"
            chapter_ui.jump_status_color = 0xFFFF8800
            jump_cont.active = false
            pcall(function()
                local fm = mgr("app.MainGameFlowManager")
                if fm then fm:call("resetOverrideNextJumpScene") end
            end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Jump To Chapter — with optional progress entry
-- ═══════════════════════════════════════════════════════════════════════════

local function jump_to_chapter(scene_name, progress_entry)
    -- Cancel any previous jump
    if jump_cont.active then
        log.info("[Trainer] JUMP: cancelling previous jump")
        jump_cont.active = false
        pcall(function()
            local fm = mgr("app.MainGameFlowManager")
            if fm then fm:call("resetOverrideNextJumpScene") end
        end)
    end

    local flow_mgr = mgr("app.MainGameFlowManager")
    if not flow_mgr then return false, "MainGameFlowManager not found" end

    local stm = mgr("app.SceneTransitionManager")
    if not stm then return false, "SceneTransitionManager not found" end

    -- Check if transition is already running
    local already_running = false
    pcall(function() already_running = stm:call("get_IsRunningTransition") end)
    if already_running then
        log.info("[Trainer] JUMP: transition already running, aborting")
        return false, "Transition already in progress"
    end

    log.info("[Trainer] JUMP: target=" .. scene_name
        .. (progress_entry and (" progress=" .. progress_entry.name) or ""))

    -- Step 1: Set override scene on MainGameFlowManager
    local ok_override, err_override = pcall(function()
        flow_mgr:call("setOverrideNextJumpScene", scene_name)
    end)
    if not ok_override then
        log.info("[Trainer] JUMP: setOverrideNextJumpScene failed: " .. tostring(err_override))
        return false, "setOverrideNextJumpScene failed"
    end
    log.info("[Trainer] JUMP: setOverrideNextJumpScene(" .. scene_name .. ")")

    -- Step 2: Request jump on SceneTransitionManager with false
    local ok_jump, err_jump = pcall(function()
        stm:call("requestMainGameJump(System.Boolean)", false)
    end)
    if not ok_jump then
        log.info("[Trainer] JUMP: requestMainGameJump(false) failed: " .. tostring(err_jump))
        return false, "requestMainGameJump failed: " .. tostring(err_jump)
    end
    log.info("[Trainer] JUMP: requestMainGameJump(false) called on SceneTransitionManager")

    -- Start continuation monitoring
    jump_cont.active = true
    jump_cont.target_scene = scene_name
    jump_cont.state = "wait_transition"
    jump_cont.frame_count = 0
    jump_cont.last_running = nil
    jump_cont.saw_scene_flow = false

    -- Store progress entry for post-transition
    if progress_entry and progress_entry.hash and progress_entry.value then
        jump_cont.progress_hash = progress_entry.hash
        jump_cont.progress_value = progress_entry.value
        log.info("[Trainer] JUMP: will set progress " .. progress_entry.name
            .. " (hash=0x" .. string.format("%X", progress_entry.hash)
            .. " value=" .. tostring(progress_entry.value) .. ") after transition")
    else
        jump_cont.progress_hash = nil
        jump_cont.progress_value = nil
    end

    return true, "Jump to " .. scene_name .. " initiated"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Return to Title
-- ═══════════════════════════════════════════════════════════════════════════

local function return_to_title()
    pcall(function()
        jump_cont.active = false
        local stm = mgr("app.SceneTransitionManager")
        if stm then
            stm:call("requestTitleSceneJump", false)
            log.info("[Trainer] Requested title scene jump")
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Exports
-- ═══════════════════════════════════════════════════════════════════════════

T.scan_chapter = scan_chapter
T.scan_level_flow_controllers = scan_level_flow_controllers
T.get_chapter_list = nil  -- replaced by chapter_list/chapter_scene_names
T.jump_to_chapter = jump_to_chapter
T.process_jump_continuation = process_jump_continuation
T.return_to_title = return_to_title
T.discover_all_progress_names = discover_all_progress_names
T.discover_runtime_scenes = discover_runtime_scenes
T.get_friendly_name = get_friendly_name
T.chapter_info = chapter_info
T.chapter_ui = chapter_ui
T.chapter_list = chapter_list
T.chapter_scene_names = chapter_scene_names
T.chapter_progress_cache = chapter_progress_cache
T.progress_selected_index = progress_selected_index
T.progress_value_index = progress_value_index
T.jump_cont = jump_cont
T.CHAPTER_NAMES = CHAPTER_NAMES

log.info("[Trainer] Chapters sub-module loaded")
