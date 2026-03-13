--[[
    init.lua — EMV Engine Entry Point

    Loads all sub-modules in dependency order, wires cross-references,
    detects RE9, and exposes the public EMV global table.

    Load via: local emv_fn = loadfile(dir .. "emv_engine/init.lua"); if emv_fn then emv_fn(T) end

    ─────────────────────────────────────────────────────────────────
    Credits:
      Inspired by and based on the architecture of EMV Engine
      (Enhanced Model Viewer) by alphaZomega.
      Original: https://github.com/alphazolam/EMV-Engine

      This is a ground-up reimplementation for RE9, restructured as
      modular components with dependency injection. API names such as
      find, findc, search, sort, deferred_call, binsert, orderedPairs,
      and the ObjectCache/DeferredCalls patterns originate from the
      original EMV Engine design.
    ─────────────────────────────────────────────────────────────────
]]

local T = ...

-- ═══════════════════════════════════════════════════════════════════════════
-- Module Directory Resolution
-- ═══════════════════════════════════════════════════════════════════════════

local dir = nil
pcall(function()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        local source = info.source:gsub("^@", "")
        dir = source:match("(.+[\\/])") or ""
    end
end)
if not dir then dir = "reframework/autorun/requiem_trainer/emv_engine/" end

local function load_module(name)
    local path = dir .. name .. ".lua"
    local fn, err = loadfile(path)
    if not fn then
        if log then log.error(("[EMV] Failed to load %s: %s"):format(name, tostring(err))) end
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        if log then log.error(("[EMV] Error executing %s: %s"):format(name, tostring(result))) end
        return nil
    end
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Load Modules (dependency order)
-- ═══════════════════════════════════════════════════════════════════════════

-- Phase 1: Foundation
local RE9_OFFSETS        = load_module("re9_offsets")
local SafeMemory         = load_module("safe_memory")
local ObjectCache_class  = load_module("object_cache")
local CollectionIterator = load_module("collection_iterator")
local TableUtils         = load_module("table_utils")

if not RE9_OFFSETS or not SafeMemory then
    if log then log.error("[EMV] CRITICAL: Foundation modules failed. EMV disabled.") end
    return
end

local ObjectCacheInstance = nil
if ObjectCache_class then
    ObjectCacheInstance = ObjectCache_class:new({name="emv_main", max_size=500, default_ttl=30})
end

-- Phase 2: Core
local CoreFunctions    = load_module("core_functions")
local DeferredCalls    = load_module("deferred_calls")
local GameObjectSystem = load_module("gameobject_system")
local Serialization    = load_module("serialization")
local ImguiHelpers     = load_module("imgui_helpers")
local ControlPanel     = load_module("control_panel")

-- Phase 3: Type Database (RSZ)
local TypeDB           = load_module("type_db")
if TypeDB then
    TypeDB.setup(dir)
end

-- Phase 4: UI Tabs
local ObjectsTab       = load_module("objects_tab")
local SpawnerTab       = load_module("spawner_tab")
local ViewerTab        = load_module("viewer_tab")
local MethodInspector  = load_module("method_inspector")
local ObjectExplorer   = load_module("object_explorer")

-- ═══════════════════════════════════════════════════════════════════════════
-- Wire Dependencies
-- ═══════════════════════════════════════════════════════════════════════════

local deps = {
    RE9_OFFSETS=RE9_OFFSETS, SafeMemory=SafeMemory, ObjectCache=ObjectCacheInstance,
    CollectionIterator=CollectionIterator, TableUtils=TableUtils,
    CoreFunctions=CoreFunctions, DeferredCalls=DeferredCalls,
    GameObjectSystem=GameObjectSystem, Serialization=Serialization,
    ImguiHelpers=ImguiHelpers, ControlPanel=ControlPanel,
    ObjectExplorer=ObjectExplorer, TypeDB=TypeDB,
}

local modules_with_setup = {CoreFunctions, DeferredCalls, GameObjectSystem, Serialization,
    ImguiHelpers, ControlPanel, ObjectExplorer, ObjectsTab, SpawnerTab, ViewerTab, MethodInspector}
for _, mod in ipairs(modules_with_setup) do
    if mod and mod.setup then mod.setup(deps) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Game Detection
-- ═══════════════════════════════════════════════════════════════════════════

if CoreFunctions then
    CoreFunctions.detect_game()
    CoreFunctions.init_scene()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Public EMV Table
-- ═══════════════════════════════════════════════════════════════════════════

_G.EMV = {}

-- Foundation
EMV.RE9_OFFSETS = RE9_OFFSETS; EMV.SafeMemory = SafeMemory
EMV.ObjectCache = ObjectCacheInstance; EMV.CollectionIterator = CollectionIterator
EMV.TableUtils = TableUtils

-- Core shortcuts
if CoreFunctions then
    for _, fn_name in ipairs({"is_valid_obj","is_only_my_ref","can_index","get_valid",
        "get_GameObject","get_player","get_scene","find","findc","search","sort",
        "lua_get_components","lua_find_component","delete_component",
        "create_resource","add_resource_to_cache","add_pfb_to_cache",
        "check_key_released","update_mouse_state","get_mouse_device","Hotkey",
        "generate_statics","hashing_method","mat4_to_trs","trs_to_mat4","get_trs"}) do
        EMV[fn_name] = CoreFunctions[fn_name]
    end
    EMV.static_objs = CoreFunctions.static_objs; EMV.RSCache = CoreFunctions.RSCache; EMV.RN = CoreFunctions.RN
end

-- Deferred calls
if DeferredCalls then
    EMV.deferred_call = DeferredCalls.deferred_call
    EMV.process_deferred_calls = DeferredCalls.process_deferred_calls
    EMV.process_on_frame_calls = DeferredCalls.process_on_frame_calls
    EMV.queue_deferred_call = DeferredCalls.queue; EMV.queue_on_frame_call = DeferredCalls.queue_on_frame
    EMV.unfreeze = DeferredCalls.unfreeze
end

-- GameObject system
if GameObjectSystem then
    EMV.GameObject = GameObjectSystem.GameObject; EMV.AnimObject = GameObjectSystem.AnimObject
    EMV.get_anim_object = GameObjectSystem.get_anim_object
    EMV.create_gameobj = GameObjectSystem.create_gameobj; EMV.spawn_gameobj = GameObjectSystem.spawn_gameobj
    EMV.delete_spawned = GameObjectSystem.delete_spawned; EMV.clone = GameObjectSystem.clone
    EMV.get_children = GameObjectSystem.get_children
    EMV.held_transforms = GameObjectSystem.held_transforms; EMV.spawned_objects = GameObjectSystem.spawned_objects
end

-- Serialization
if Serialization then
    EMV.jsonify_table = Serialization.jsonify_table; EMV.obj_to_json = Serialization.obj_to_json
    EMV.save_json = Serialization.save_json; EMV.load_json = Serialization.load_json
end

-- UI helpers
if ImguiHelpers then
    EMV.tooltip = ImguiHelpers.tooltip; EMV.tree_node_colored = ImguiHelpers.tree_node_colored
    EMV.button_w_hotkey = ImguiHelpers.button_w_hotkey; EMV.editable_table_field = ImguiHelpers.editable_table_field
    EMV.ImguiTable = ImguiHelpers.ImguiTable; EMV.read_imgui_pairs_table = ImguiHelpers.read_imgui_pairs_table
end

-- Control panel
if ControlPanel then
    EMV.managed_object_control_panel = ControlPanel.managed_object_control_panel
    EMV.create_REMgdObj = ControlPanel.create_REMgdObj; EMV.get_fields_and_methods = ControlPanel.get_fields_and_methods
    EMV.show_imgui_mats = ControlPanel.show_imgui_mats; EMV.read_field = ControlPanel.read_field
end

-- Table utilities
if TableUtils then
    EMV.merge_tables = TableUtils.merge_tables; EMV.deep_copy = TableUtils.deep_copy
    EMV.qsort = TableUtils.qsort; EMV.orderedPairs = TableUtils.orderedPairs
    EMV.binsert = TableUtils.binsert; EMV.isArray = TableUtils.isArray
    EMV.vector_to_table = TableUtils.vector_to_table; EMV.run_command = TableUtils.run_command
end

-- UI tabs
if ObjectsTab then EMV.render_objects_tab = ObjectsTab.render end
if SpawnerTab then EMV.render_spawner_tab = SpawnerTab.render end
if ViewerTab  then EMV.render_viewer_tab  = ViewerTab.render end
if MethodInspector then EMV.render_method_inspector = MethodInspector.render end

-- ═══════════════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════════════

re.on_script_reset(function()
    if log then log.info("[EMV] Script reset — cleaning up") end
    pcall(function() if ObjectCacheInstance then ObjectCacheInstance:clear() end end)
    pcall(function() if DeferredCalls then DeferredCalls.clear() end end)
    pcall(function() if GameObjectSystem then GameObjectSystem.clear() end end)
    _G.EMV = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Finalize
-- ═══════════════════════════════════════════════════════════════════════════



local symbol_count = 0
for _ in pairs(EMV) do symbol_count = symbol_count + 1 end

if log then
    log.info(("[EMV] Engine initialized — %d symbols, game=%s, isRE9=%s"):format(
        symbol_count, tostring(_G.game_name or "?"), tostring(_G.isRE9 or false)))
end

return EMV
