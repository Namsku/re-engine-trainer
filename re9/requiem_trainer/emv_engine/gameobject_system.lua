--[[
    gameobject_system.lua — GameObject / AnimObject Class System
    EMV Engine Module (Phase 2)

    Wraps via.GameObject and via.Transform with EMV's inspection/manipulation API.

    Based on EMV Engine by alphaZomega (https://github.com/alphazolam/EMV-Engine)
    Reimplemented for RE9 with modular architecture.
]]

local GameObjectSystem = {}

local RE9_OFFSETS, SafeMemory, ObjectCache, CoreFunctions, CollectionIterator, TableUtils, DeferredCalls

function GameObjectSystem.setup(deps)
    RE9_OFFSETS = deps.RE9_OFFSETS; SafeMemory = deps.SafeMemory
    ObjectCache = deps.ObjectCache; CoreFunctions = deps.CoreFunctions
    CollectionIterator = deps.CollectionIterator; TableUtils = deps.TableUtils
    DeferredCalls = deps.DeferredCalls
end

local held_transforms = {}
local spawned_objects = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- GameObject Class
-- ═══════════════════════════════════════════════════════════════════════════

local GameObject = {}
GameObject.__index = GameObject

function GameObject:new(args)
    args = args or {}
    local o = setmetatable({}, GameObject)
    o.gameobj = args.gameobj; o.xform = args.xform
    o.name = args.name or ""; o.components = {}; o.components_named = {}
    o.is_valid = false; o.display_name = ""

    if o.gameobj and not o.xform then
        pcall(function() o.xform = o.gameobj:call("get_Transform()") end)
    elseif o.xform and not o.gameobj then
        o.gameobj = CoreFunctions.get_GameObject(o.xform)
    end
    if o.gameobj and not args.name then
        pcall(function() o.name = o.gameobj:call("get_Name()") or "" end)
    end
    o.display_name = o.name

    if o.xform then
        o.components = CoreFunctions.lua_get_components(o.xform)
        for _, comp in ipairs(o.components) do
            pcall(function()
                local tdef = comp:get_type_definition()
                if tdef then o.components_named[tdef:get_full_name()] = comp end
            end)
        end
    end
    o.is_valid = o.gameobj ~= nil and sdk.is_managed_object(o.gameobj)
    return o
end

function GameObject:getComponent(type_name) return self.components_named[type_name] end
function GameObject:isValid()
    if not self.gameobj then return false end
    return sdk.is_managed_object(self.gameobj)
end
function GameObject:getPosition()
    if not self.xform then return nil end
    local pos; pcall(function() pos = self.xform:call("get_Position") end); return pos
end
function GameObject:setPosition(pos)
    if self.xform and pos then pcall(function() self.xform:call("set_Position", pos) end) end
end
function GameObject:getRotation()
    if not self.xform then return nil end
    local rot; pcall(function() rot = self.xform:call("get_Rotation") end); return rot
end
function GameObject:getChildren() return GameObjectSystem.get_children(self.xform) end

GameObjectSystem.GameObject = GameObject

-- ═══════════════════════════════════════════════════════════════════════════
-- AnimObject (extends GameObject)
-- ═══════════════════════════════════════════════════════════════════════════

local AnimObject = setmetatable({}, {__index = GameObject})
AnimObject.__index = AnimObject

function AnimObject:new_AnimObject(args)
    local go = GameObject.new(self, args)
    local o = setmetatable(go, AnimObject)
    o.motion = args.motion or o.components_named["via.motion.Motion"]
    o.mesh = args.mesh or o.components_named["via.render.Mesh"]
    o.mpaths = {}; o.materials = {}; o.layers = {}; o.layer_count = 0
    if o.motion then pcall(function()
        for i = 0, 16 do
            local l = o.motion:call("getMotionFsm2Layer", i)
            if l then o.layers[i] = l; o.layer_count = i else break end
        end
    end) end
    if o.mesh then pcall(function()
        local mat_count = o.mesh:call("get_MaterialNum") or 0
        for i = 0, mat_count - 1 do
            pcall(function()
                o.mpaths[i] = o.mesh:call("getMaterialName", i)
                o.materials[i] = o.mesh:call("getMaterial", i)
            end)
        end
    end) end
    o.cog_name = args.cog_name or (_G.isRE9 and "root" or "COG")
    return o
end

function AnimObject:getAnimInfo(layer_idx)
    layer_idx = layer_idx or 0
    if not self.motion then return nil end
    local info; pcall(function()
        local fsm = self.motion:call("getMotionFsm2Layer", layer_idx)
        if fsm then
            info = {
                name = fsm:call("get_CurrentStateName") or "",
                speed = fsm:call("get_Speed") or 1.0,
                weight = fsm:call("get_Weight") or 1.0,
                time = fsm:call("get_Frame") or 0,
            }
        end
    end); return info
end

GameObjectSystem.AnimObject = AnimObject

-- ═══════════════════════════════════════════════════════════════════════════
-- AnimObject Cache
-- ═══════════════════════════════════════════════════════════════════════════

function GameObjectSystem.get_anim_object(gameobj_or_xform, args)
    if not gameobj_or_xform then return nil end
    local xform, gameobj
    pcall(function()
        local tdef = gameobj_or_xform:get_type_definition()
        local fn = tdef and tdef:get_full_name() or ""
        if fn:find("[Tt]ransform") then
            xform = gameobj_or_xform; gameobj = CoreFunctions.get_GameObject(xform)
        else
            gameobj = gameobj_or_xform; xform = gameobj:call("get_Transform()")
        end
    end)
    if not xform then return nil end
    local cached = held_transforms[xform]
    if cached and cached:isValid() then return cached end
    args = args or {}; args.gameobj = gameobj; args.xform = xform
    local anim_obj = AnimObject:new_AnimObject(args)
    held_transforms[xform] = anim_obj
    return anim_obj
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawning / Creation
-- ═══════════════════════════════════════════════════════════════════════════

function GameObjectSystem.create_gameobj(name, components, args)
    args = args or {}; local gameobj, xform
    pcall(function()
        local folder = args.folder
        if not folder and CoreFunctions.static_objs.scene and _G.isRE9 then
            folder = CoreFunctions.static_objs.scene:call("findFolder", "SpawnedPrefabs")
                or CoreFunctions.static_objs.scene:call("findFolder", "Spawned")
        end
        gameobj = sdk.call_native_func(CoreFunctions.static_objs.scene,
            sdk.find_type_definition("via.Scene"), "createGameObject(System.String)", name)
        if not gameobj then return end
        gameobj:add_ref()
        xform = gameobj:call("get_Transform()")
        if folder and xform then pcall(function() xform:call("set_Parent", folder) end) end
        if components then
            for _, cn in ipairs(components) do
                pcall(function() gameobj:call("createComponent(System.Type)", sdk.typeof(cn)) end)
            end
        end
        if args.position and xform then pcall(function() xform:call("set_Position", args.position) end) end
    end)
    if gameobj and name then
        spawned_objects[name] = {gameobj=gameobj, xform=xform, time=os.clock()}
    end
    return gameobj, xform
end

function GameObjectSystem.spawn_gameobj(pfb_path, position, folder)
    if not pfb_path then return nil end
    local gameobj
    pcall(function()
        local pfb = CoreFunctions.create_resource(pfb_path, "via.Prefab")
        if not pfb then return end
        gameobj = pfb:call("instantiate(via.vec3)", position or Vector3f.new(0,0,0))
        if gameobj then
            gameobj:add_ref()
            local name = ""; pcall(function() name = gameobj:call("get_Name()") or pfb_path end)
            spawned_objects[name] = {gameobj=gameobj, time=os.clock(), pfb_path=pfb_path}
            pcall(function() spawned_objects[name].xform = gameobj:call("get_Transform()") end)
        end
    end)
    return gameobj
end

function GameObjectSystem.delete_spawned(name_or_obj)
    local gameobj, key
    if type(name_or_obj) == "string" then
        key = name_or_obj; local entry = spawned_objects[key]
        if entry then gameobj = entry.gameobj end
    else
        gameobj = name_or_obj
        for k, v in pairs(spawned_objects) do
            if v.gameobj == gameobj then key = k; break end
        end
    end
    if gameobj and sdk.is_managed_object(gameobj) then
        pcall(function() gameobj:call("destroy", gameobj) end)
    end
    if key then spawned_objects[key] = nil end
end

function GameObjectSystem.clone(instance, type_override)
    if not instance or not sdk.is_managed_object(instance) then return nil end
    local cloned; pcall(function()
        local tdef = type_override or instance:get_type_definition()
        if not tdef then return end
        cloned = tdef:create_instance()
        if not cloned then return end; cloned:add_ref()
        local fields = tdef:get_fields()
        if fields then for _, field in ipairs(fields) do
            if not field:is_static() then pcall(function()
                local val = instance:get_field(field:get_name())
                if val ~= nil then cloned:set_field(field:get_name(), val) end
            end) end
        end end
    end); return cloned
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Transform Hierarchy
-- ═══════════════════════════════════════════════════════════════════════════

function GameObjectSystem.get_children(xform)
    local children = {}
    if not xform or not sdk.is_managed_object(xform) then return children end
    pcall(function()
        local child = xform:call("get_Child")
        local i = 0
        while child and sdk.is_managed_object(child) and i < 512 do
            children[#children + 1] = child
            child = child:call("get_Next"); i = i + 1
        end
    end)
    return children
end

function GameObjectSystem.clear()
    for _, entry in pairs(spawned_objects) do
        if entry.gameobj and sdk.is_managed_object(entry.gameobj) then
            pcall(function() entry.gameobj:release() end)
        end
    end
    spawned_objects = {}; held_transforms = {}
end

GameObjectSystem.held_transforms = held_transforms
GameObjectSystem.spawned_objects = spawned_objects

return GameObjectSystem
