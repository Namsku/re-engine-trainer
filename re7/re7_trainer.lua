--[[
    RE7 Trainer v2.0 — by namsku
    Hooks based on proven RE7 methods from community trainers
]]

local TITLE = "RE7 Trainer v2.0 by namsku"
local CFG_FILE = "re7_trainer_v2.json"

if reframework and reframework.get_game_name and reframework:get_game_name() ~= "re7" then
    return
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Config
-- ═══════════════════════════════════════════════════════════════════════════
local C = {
    godmode = false, inf_ammo = false, inf_health = false,
    move_speed_mult = 1.0, enemy_insta_kill = false,
    change_enemy_speed = false, enemy_speed_mult = 1.0,
    player_scale = 1.0, game_speed_on = false, game_speed = 1.0,
    noclip = false, noclip_speed = 0.4,
    show_dev_overlay = true, enemy_panel = true,
    enemy_esp = true, item_esp = true, spawn_esp = true,
    show_damage_numbers = true,
    show_bars = true, show_pct = true, hide_dead = true, dist_color = true,
    esp_range = 50.0, esp_font = 18, panel_rows = 8,
    panel_font = 16, panel_w = 460, panel_bar_w = 150, panel_bar_h = 8,
}

local function cfg_save() pcall(function() json.dump_file(CFG_FILE, C) end) end
local function cfg_load()
    pcall(function()
        local t = json.load_file(CFG_FILE)
        if t then for k,v in pairs(t) do if C[k] ~= nil then C[k] = v end end end
    end)
end
cfg_load()

-- ═══════════════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════════════
local R = {
    tick = 0, toasts = {}, enemies = {}, items = {}, spawners = {},
    player_hp = 0, player_max_hp = 0,
    player_pos = nil, player_rot = nil, scene_name = "", chapter = "",
    loaded_scene = "",  -- from HarawataUtil / MapManager
    da_score = 0, rank = 0, difficulty = 0, area_name = "", room_id = 0, map_cat = 0, map_level = 0,
    dev_overlay_bottom = 0, damage_numbers = {},
}

local function toast(msg, dur)
    R.toasts[#R.toasts+1] = { text=msg, time=os.clock(), dur=dur or 3 }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SDK Helpers
-- ═══════════════════════════════════════════════════════════════════════════
local has_d2d = (d2d ~= nil)

local known_types = {}
local function get_type(name)
    if not known_types[name] then known_types[name] = sdk.typeof(name) end
    return known_types[name]
end

local function getComponent(go, type_name)
    if not go then return nil end
    local t = get_type(type_name)
    if not t then return nil end
    return go:call("getComponent(System.Type)", t)
end

local function getLocalPlayer()
    local om = sdk.get_managed_singleton("app.ObjectManager")
    return om and om:get_field("PlayerObj") or nil
end

local function get_scene()
    local ok, s = pcall(function()
        return sdk.call_native_func(
            sdk.get_native_singleton("via.SceneManager"),
            sdk.find_type_definition("via.SceneManager"),
            "get_CurrentScene()")
    end)
    return ok and s or nil
end

local function find_components(type_name)
    local scene = get_scene()
    if not scene then return nil, 0 end
    local td = sdk.find_type_definition(type_name)
    if not td then return nil, 0 end
    local comps = nil
    pcall(function() comps = scene:call("findComponents(System.Type)", td:get_runtime_type()) end)
    if not comps then return nil, 0 end
    local ok, n = pcall(comps.call, comps, "get_Count")
    return comps, (ok and n or 0)
end

-- HP access: DamageController → HealthInfo → Health/MaxHealth
local function get_hp(dc)
    if not dc then return nil, nil end
    local hp, mhp
    pcall(function()
        local hi = dc:get_field("HealthInfo")
        if hi then hp = hi:get_field("Health"); mhp = hi:get_field("MaxHealth") end
    end)
    return hp, mhp
end

-- Quaternion → Euler
local function quat_to_euler(q)
    if not q then return nil end
    local x,y,z,w = q.x or 0, q.y or 0, q.z or 0, q.w or 0
    local pitch = math.atan(2*(w*x+y*z), 1-2*(x*x+y*y))
    local siny = math.max(-1, math.min(1, 2*(w*y-z*x)))
    local yaw = math.asin(siny)
    local roll = math.atan(2*(w*z+x*y), 1-2*(y*y+z*z))
    return { x=math.deg(pitch), y=math.deg(yaw), z=math.deg(roll) }
end

local function dist3(a, b)
    if not a or not b then return 999 end
    local dx,dy,dz = (a.x or 0)-(b.x or 0), (a.y or 0)-(b.y or 0), (a.z or 0)-(b.z or 0)
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Player access
-- ═══════════════════════════════════════════════════════════════════════════
local function get_player_pos()
    local p = getLocalPlayer()
    if not p then return nil end
    local pos
    pcall(function() pos = p:get_Transform():get_Position() end)
    return pos
end

local function get_camera_rot()
    local rot
    -- Try camera rotation first
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local td = sdk.find_type_definition("via.SceneManager")
        local scene = sdk.call_native_func(sm, td, "get_CurrentScene()")
        if not scene then return end
        local mv = scene:call("get_MainView")
        if not mv then return end
        local cam = mv:call("get_PrimaryCamera")
        if not cam then return end
        local go = cam:call("get_GameObject")
        if not go then return end
        local xf = go:call("get_Transform")
        if not xf then return end
        local q = xf:call("get_Rotation")
        if q then rot = quat_to_euler(q) end
    end)
    -- Fallback: player transform rotation
    if not rot then
        pcall(function()
            local p = getLocalPlayer()
            if not p then return end
            local xf = p:call("get_Transform")
            if not xf then return end
            local q = xf:call("get_Rotation")
            if q then rot = quat_to_euler(q) end
        end)
    end
    return rot
end

local function get_player_hp()
    local p = getLocalPlayer()
    if not p then return 0, 0 end
    local hp, mhp = 0, 0
    pcall(function()
        local dc = getComponent(p, "app.DamageController")
        if dc then hp, mhp = get_hp(dc) end
    end)
    return hp or 0, mhp or 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Enemy scanner
-- ═══════════════════════════════════════════════════════════════════════════
local ENEMY_NAMES = {
    Em4000="Molded", Em4100="Four-Legged Molded", Em4200="Fat Molded",
    Em3000="Jack Baker", Em3001="Jack (Boss)", Em3002="Jack (Final)",
    Em3100="Marguerite", Em3600="Eveline", Em2000="Mia",
    Em5400="Molded (DLC)", Em5510="Bug", Em5520="Swarm Bug",
    Em8000="Jack (Swamp)", Em8100="Lucas",
}

local function enemy_name(go)
    if not go then return "Enemy" end
    local n = "Enemy"
    pcall(function()
        local raw = tostring(go:call("get_Name"))
        for code, friendly in pairs(ENEMY_NAMES) do
            if raw:find(code) then n = friendly; return end
        end
        n = raw
    end)
    return n
end

local function scan_enemies()
    local results = {}
    local ppos = R.player_pos
    -- RE7 uses EnemyActionController (confirmed via hooks), not EnemyOrder (RE9)
    local enemy_types = {"app.EnemyActionController", "app.EnemyCharaController", "app.EnemyController"}
    for _, tname in ipairs(enemy_types) do
        pcall(function()
            local comps, n = find_components(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n-1, 50) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local go = c:call("get_GameObject")
                    if not go then return end
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    -- Dedup by guid
                    for _, existing in ipairs(results) do
                        if existing.go == go then return end
                    end
                    local hp, mhp = 0, 1
                    pcall(function()
                        local dc = getComponent(go, "app.DamageController")
                        if dc then local h,m = get_hp(dc); hp = h or 0; mhp = m or 1 end
                    end)
                    results[#results+1] = {
                        name=enemy_name(go), hp=hp, mhp=mhp,
                        dead=(hp<=0), dist=dist3(pos,ppos), pos=pos, go=go
                    }
                end)
            end
        end)
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Item scanner — scene-based (RE7-compatible)
-- ═══════════════════════════════════════════════════════════════════════════
local ITEM_NAME_PATTERNS = {
    "^sm%d+",           -- RE7 item naming: sm0000_00 etc.
    "^wp%d+",           -- weapons: wp0000 etc.
    "Pickup", "^Key_", "^Herb", "^Ammo", "^Weapon", "^Grenade",
    "^Coin", "^Steroid", "^Stabilizer", "^Treasure", "^Tape",
    "^Backpack", "^MedicineBall", "^Antique", "^Chem", "^Serum",
    "^Repair", "^Burner", "^Shotgun", "^Handgun", "^Machinegun",
    "^Magnum", "^Knife", "^Bomb", "^Separating", "KitchenKnife",
}
local ITEM_BLACKLIST = {
    "ObjectType", "Template", "Guid", "Manager", "Controller",
    "System", "Root", "Camera", "Light", "Trigger", "Collider",
    "Generator", "Spawn", "GUI", "UI_", "Effect", "env_",
    "NavMesh", "Folder", "Group", "EventTrigger",
}

local function scan_items()
    local results = {}
    local ppos = R.player_pos
    -- Try component-based scanning with multiple possible RE7 types
    local item_types = {
        "app.InteractableItem", "app.PickupGimmick", "app.GimmickPickupItem",
        "app.GimmickItem", "app.ItemBase", "app.PickupItem",
        "app.InteractItemController", "app.ItemCore",
    }
    local seen = {}
    for _, tname in ipairs(item_types) do
        pcall(function()
            local comps, n = find_components(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n-1, 60) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local go = c:call("get_GameObject")
                    if not go then return end
                    local id = tostring(go:get_address())
                    if seen[id] then return end
                    seen[id] = true
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    local name = "Item"
                    pcall(function() name = tostring(go:call("get_Name") or "Item") end)
                    results[#results+1] = { name=name, pos=pos, dist=dist3(pos, ppos), go=go }
                end)
            end
        end)
    end
    -- Fallback: if no components found, scan ObjectManager for items by name
    if #results == 0 then
        pcall(function()
            local scene = sdk.call_native_func(
                sdk.get_native_singleton("via.SceneManager"),
                sdk.find_type_definition("via.SceneManager"),
                "get_CurrentScene()")
            if not scene then return end
            local xf = scene:call("get_FirstTransform")
            local count = 0
            while xf and count < 500 do
                count = count + 1
                pcall(function()
                    local go = xf:call("get_GameObject")
                    if not go then return end
                    local gname = tostring(go:call("get_Name") or "")
                    -- Skip names that are too long/garbage or match blacklist
                    if #gname > 40 or #gname < 2 then return end
                    for _, bl in ipairs(ITEM_BLACKLIST) do
                        if gname:find(bl) then return end
                    end
                    for _, pat in ipairs(ITEM_NAME_PATTERNS) do
                        if gname:find(pat) then
                            local id = tostring(go:get_address())
                            if seen[id] then return end
                            seen[id] = true
                            local pos = xf:call("get_Position")
                            if not pos then return end
                            results[#results+1] = { name=gname, pos=pos, dist=dist3(pos, ppos), go=go }
                            return
                        end
                    end
                end)
                xf = xf:call("get_Next")
            end
        end)
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawn scanner — scene-based (RE7-compatible)
-- ═══════════════════════════════════════════════════════════════════════════
local SPAWN_PATTERNS = {"Spawn", "Generator", "Emitter", "Em_"}

local function scan_spawners()
    local results = {}
    local ppos = R.player_pos
    local seen = {}
    -- Try component types
    local spawn_types = {"app.EnemyGenerator", "app.SpawnParam", "app.EnemySpawnController"}
    for _, tname in ipairs(spawn_types) do
        pcall(function()
            local comps, n = find_components(tname)
            if not comps or n <= 0 then return end
            for i = 0, math.min(n-1, 30) do
                pcall(function()
                    local c = comps:call("get_Item", i)
                    if not c then return end
                    local go = c:call("get_GameObject")
                    if not go then return end
                    local id = tostring(go:get_address())
                    if seen[id] then return end
                    seen[id] = true
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    local name = "Spawner"
                    pcall(function() name = tostring(go:call("get_Name") or "Spawner") end)
                    results[#results+1] = { name=name, pos=pos, dist=dist3(pos, ppos) }
                end)
            end
        end)
    end
    -- Fallback: name-based
    if #results == 0 then
        pcall(function()
            local scene = sdk.call_native_func(
                sdk.get_native_singleton("via.SceneManager"),
                sdk.find_type_definition("via.SceneManager"),
                "get_CurrentScene()")
            if not scene then return end
            local xf = scene:call("get_FirstTransform")
            local count = 0
            while xf and count < 500 do
                count = count + 1
                pcall(function()
                    local go = xf:call("get_GameObject")
                    if not go then return end
                    local gname = tostring(go:call("get_Name") or "")
                    for _, pat in ipairs(SPAWN_PATTERNS) do
                        if gname:find(pat) then
                            local id = tostring(go:get_address())
                            if seen[id] then return end
                            seen[id] = true
                            local pos = xf:call("get_Position")
                            if not pos then return end
                            results[#results+1] = { name=gname, pos=pos, dist=dist3(pos, ppos) }
                            return
                        end
                    end
                end)
                xf = xf:call("get_Next")
            end
        end)
    end
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Items data
-- ═══════════════════════════════════════════════════════════════════════════
local ItemIds = {
    "Bar","ChainSaw","CircularSaw","HandAxe","Knife","MiaKnife","Burner","GrenadeLauncher",
    "Handgun_Albert","Handgun_Albert_Reward","Handgun_G17","Handgun_M19","Handgun_MPM",
    "MachineGun","Magnum","Shotgun_DB","Shotgun_M37","BlueBlaster","HyperBlaster","RedBlaster",
    "LiquidBomb","UnlimitedAmmo","AcidBulletS","BurnerBullet","FlameBulletS","HandgunBullet",
    "HandgunBulletL","MachineGunBullet","MagnumBullet","ShotgunBullet","EyeDrops","Herb",
    "RemedyL","RemedyM","AlphaGrass","BookDefence01","BookDefence02","Depressant","Stimulant",
    "Coin","GoodLuckCoinA","GoodLuckCoinB","GoodLuckCoinC","GoodLuckCoinD","GoodLuckCoinE",
    "Alcohol","AlloyClay","ChemicalL","ChemicalM","ChemicalS","Flower","Gunpowder","Magnesium",
    "RepairKit","SaveTape",
}

local function addAllItemsToItemBox()
    pcall(function()
        local inv = getComponent(getLocalPlayer(), "app.Inventory")
        if not inv then return end
        local box = inv:get_field("<ItemBoxData>k__BackingField")
        if not box then return end
        for _, id in ipairs(ItemIds) do
            pcall(function()
                box:call("addItem(System.String, System.Int32, app.WeaponGun.WeaponGunSaveData)", id, 100, nil)
            end)
        end
    end)
end

local function setMaxInventory()
    pcall(function()
        local inv = getComponent(getLocalPlayer(), "app.Inventory")
        if inv then inv:call("setExtendLv", 2) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOKS (proven methods from community trainers)
-- ═══════════════════════════════════════════════════════════════════════════

-- God Mode: PlayerDamageController.get_isEnableDamage → false
pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.PlayerDamageController"):get_method("get_isEnableDamage"),
        nil,
        function(retval)
            if C.godmode then return false else return retval end
        end
    )
    if log then log.info("[RE7] Hooked PlayerDamageController.get_isEnableDamage") end
end)

-- Player Speed: PlayerMovement.getMoveSpeed → multiply
pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.PlayerMovement"):get_method("getMoveSpeed"),
        nil,
        function(retval)
            local orig = sdk.to_float(retval)
            return sdk.float_to_ptr(orig * C.move_speed_mult)
        end
    )
    if log then log.info("[RE7] Hooked PlayerMovement.getMoveSpeed") end
end)

-- Infinite Ammo: WeaponGun.set_loadNum → SKIP
pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.WeaponGun"):get_method("set_loadNum"),
        function(args)
            if C.inf_ammo then return sdk.PreHookResult.SKIP_ORIGINAL end
        end, nil
    )
    if log then log.info("[RE7] Hooked WeaponGun.set_loadNum") end
end)

-- Enemy Insta Kill: EnemyActionController.calcDamageRate → ×100000
pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.EnemyActionController"):get_method("calcDamageRate"),
        nil,
        function(retval)
            if C.enemy_insta_kill then
                return sdk.float_to_ptr(sdk.to_float(retval) * 100000)
            end
            return retval
        end
    )
    if log then log.info("[RE7] Hooked EnemyActionController.calcDamageRate") end
end)

-- Enemy Speed: EnemyActionController.get_latestAnimationSpeedRateForRank → multiply
pcall(function()
    sdk.hook(
        sdk.find_type_definition("app.EnemyActionController"):get_method("get_latestAnimationSpeedRateForRank"),
        nil,
        function(retval)
            if C.change_enemy_speed then
                return sdk.float_to_ptr(sdk.to_float(retval) * C.enemy_speed_mult)
            end
            return retval
        end
    )
    if log then log.info("[RE7] Hooked EnemyActionController.get_latestAnimationSpeedRateForRank") end
end)

-- Damage Numbers: EnemyActionController.giveDamage / giveDie
pcall(function()
    local eac_td = sdk.find_type_definition("app.EnemyActionController")
    local di_td = sdk.find_type_definition("app.Collision.HitController.DamageInfo")
    local dmg_field = di_td:get_field("Damage")
    local get_pos = di_td:get_method("get_Position")
    local get_scale = di_td:get_method("get_DamageScale")

    local function on_damage(args)
        if not C.show_damage_numbers then return end
        pcall(function()
            local info = sdk.to_managed_object(args[3])
            if not info then return end
            local dmg = dmg_field:get_data(info)
            if not dmg or dmg == 0 then return end
            local scale = get_scale:call(info)
            if not scale or scale == 0 then return end
            local pos = get_pos:call(info)
            if not pos then return end
            R.damage_numbers[#R.damage_numbers+1] = {
                text = string.format("%.0f", math.abs(dmg / scale)),
                pos = pos, time = os.clock(), dur = 0.8,
                vx = (math.random()-0.5)*60, vy = -40 - math.random()*40,
            }
        end)
    end

    sdk.hook(eac_td:get_method("giveDamage"), function(args) on_damage(args) end, function(r) return r end)
    sdk.hook(eac_td:get_method("giveDie"), function(args) on_damage(args) end, function(r) return r end)
    if log then log.info("[RE7] Hooked EnemyActionController.giveDamage/giveDie for damage numbers") end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Noclip (proven: CharacterController.warp + WASD)
-- ═══════════════════════════════════════════════════════════════════════════
local function do_noclip()
    if not C.noclip then return end
    local player = getLocalPlayer()
    if not player then return end
    pcall(function()
        local xf = player:get_Transform()
        local pos = xf:get_Position()
        local spd = C.noclip_speed
        if reframework:is_key_down(0x57) then pos.x = pos.x - spd end -- W
        if reframework:is_key_down(0x53) then pos.x = pos.x + spd end -- S
        if reframework:is_key_down(0x44) then pos.z = pos.z - spd end -- D
        if reframework:is_key_down(0x41) then pos.z = pos.z + spd end -- A
        if reframework:is_key_down(0x20) then pos.y = pos.y + spd end -- Space
        if reframework:is_key_down(0x10) then pos.y = pos.y - spd end -- Shift
        local cc = getComponent(player, "via.physics.CharacterController")
        if cc then cc:call("warp") end
        xf:set_Position(pos)
        if cc then cc:call("warp") end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Load EMV Engine
-- ═══════════════════════════════════════════════════════════════════════════
local my_dir = ""
pcall(function()
    local info = debug.getinfo(1, "S")
    if info and info.source then
        my_dir = info.source:gsub("^@", ""):match("(.+[\\/])") or ""
    end
end)

local emv_fn = loadfile(my_dir .. "re7_trainer/emv_engine/init.lua")
if emv_fn then pcall(emv_fn, T) end
local EMV = _G.EMV or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- Overlays — RE9 Style (draw API, ABGR colors)
-- ═══════════════════════════════════════════════════════════════════════════

local has_draw_api = (draw ~= nil)

-- D2D uses ARGB (0xAARRGGBB), draw API uses ABGR (0xAABBGGRR) — swap R/B
local function argb(col)
    local a = (col >> 24) & 0xFF
    local r = (col >> 16) & 0xFF
    local g = (col >>  8) & 0xFF
    local b = col & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

-- Pre-computed ABGR colors (matching RE9 D2D ARGB originals)
local DC = {
    DEV_BG       = argb(0xCC0A0A1E),    -- dark navy panel
    DEV_ACCENT   = argb(0xDD44FF88),    -- green left strip
    PANEL_BG     = argb(0x69000000),    -- semi-transparent black
    BAR_FILL     = argb(0xFF76DCA7),    -- green HP bar
    BAR_EMPTY    = argb(0xFFB8B8B8),    -- gray empty bar
    BAR_TRACK    = argb(0xFF222233),    -- dark bar background
    SEP          = argb(0x60FFFFFF),    -- separator line
    ALT_ROW      = argb(0x12FFFFFF),    -- alternating row bg
    BORDER       = argb(0x30FFFFFF),    -- bar border
    TEXT         = argb(0xFFE8E8E8),    -- panel text
    TEXT_WHITE   = argb(0xFFE0E0E0),    -- dev text
    TEXT_GRAY    = argb(0xFFAAAAAA),    -- muted text
    TEXT_GREEN   = argb(0xFF44FF88),    -- DEV header
    TEXT_YELLOW  = argb(0xFFFFCC44),    -- scene/rank
    TEXT_CYAN    = argb(0xFF44FFFF),    -- noclip
    TEXT_BLUE    = argb(0xFF88CCFF),    -- features
    NAME_DEFAULT = argb(0xFFDDDDDD),    -- enemy name
    NAME_CLOSE   = argb(0xFF7777FF),    -- <5m
    NAME_MID     = argb(0xFF66CCFF),    -- <15m
    HP_GOOD      = argb(0xFFBBBBBB),    -- >50% HP text
    HP_LOW       = argb(0xFFFFAA44),    -- <50% HP text
    HP_CRIT      = argb(0xFFFF6666),    -- <25% HP text
    HUD_BG       = argb(0xBB1A1A2E),    -- HUD strip bg
    HUD_LINE     = argb(0x44444466),    -- HUD strip line
    HUD_TEXT     = argb(0xDD88CCFF),    -- HUD strip text
    SHADOW       = argb(0xCC000000),    -- text shadow
}

-- HP gradient: green → yellow → red (in ABGR for draw API)
local function hp_gradient(ratio)
    local r_val, g_val
    if ratio > 0.5 then
        r_val = math.floor((1.0 - ratio) * 2 * 255)
        g_val = 255
    else
        r_val = 255
        g_val = math.floor(ratio * 2 * 255)
    end
    -- ABGR: 0xAABBGGRR
    return 0xFF000000 + (r_val * 0x10000) + (g_val * 0x100) + r_val
end

-- ── Dev Overlay ── (exact copy of RE9 render_dev_overlay, ABGR colors)
local function render_dev_overlay()
    if not C.show_dev_overlay then return end
    if not has_draw_api then return end

    local pos = R.player_pos
    local rot = R.player_rot

    local info = {}
    info[#info + 1] = " DEV"
    if pos then
        info[#info + 1] = string.format(" Pos:  %.2f,  %.2f,  %.2f", pos.x, pos.y, pos.z)
    end
    if rot then
        info[#info + 1] = string.format(" Rot:  P %.1f  Y %.1f  R %.1f", rot.x, rot.y, rot.z)
    end
    if R.loaded_scene ~= "" then
        info[#info + 1] = " Scene:  " .. R.loaded_scene
    end
    if R.chapter ~= "" then
        info[#info + 1] = " Chapter:  " .. R.chapter
    end
    if R.area_name ~= "" then
        info[#info + 1] = " Area:  " .. R.area_name
    end
    info[#info + 1] = string.format(" DA Score:  %.0f   Rank: %d", R.da_score, R.rank)
    info[#info + 1] = string.format(" Diff: %d  Room: %d  Area: %d/%d", R.difficulty, R.room_id, R.map_cat, R.map_level)
    if C.noclip then
        info[#info + 1] = "NC:  (active)"
    end

    local x, y = 24, 10
    local line_h = 20
    local pad = 6
    local panel_h = pad * 2 + #info * line_h

    draw.filled_rect(x - pad, y - pad, 360, panel_h, DC.DEV_BG)
    draw.filled_rect(x - pad, y - pad, 3, panel_h, DC.DEV_ACCENT)
    R.dev_overlay_bottom = y - pad + panel_h + 8

    for i, line in ipairs(info) do
        local col = (i == 1) and DC.TEXT_GREEN or DC.TEXT_WHITE
        if line:sub(1, 6) == " Scene" then col = DC.TEXT_YELLOW end
        if line:sub(1, 5) == " Area" then col = DC.TEXT_GRAY end
        if line:sub(1, 8) == " Chapter" then col = DC.TEXT_YELLOW end
        if line:sub(1, 4) == " DA " then col = DC.TEXT_CYAN end
        if line:sub(1, 5) == " Diff" then col = DC.TEXT_GRAY end
        if line:sub(1, 2) == "NC" then col = DC.TEXT_CYAN end
        draw.text(line, x, y, col)
        y = y + line_h
    end
end

-- ── Enemy Panel ── (exact copy of RE9 draw_enemy_panel, ABGR colors)
local function render_enemy_panel()
    if not C.enemy_panel then return end
    if not has_draw_api then return end

    local x0 = C.panel_x or 24
    local y0 = C.panel_y or 10
    if C.show_dev_overlay and R.dev_overlay_bottom and y0 < R.dev_overlay_bottom then
        y0 = R.dev_overlay_bottom
    end
    local w = C.panel_w or 480
    local pad = 8
    local line_h = (C.panel_font or 16) + 6
    local bar_w = C.panel_bar_w or 150
    local bar_h = C.panel_bar_h or 8
    local bar_gap = 4

    local nearby = {}
    for _, e in ipairs(R.enemies) do
        if C.hide_dead and (e.dead or e.hp <= 0) then
        elseif e.dist <= C.esp_range then
            nearby[#nearby + 1] = e
        end
    end
    local rows = math.min(#nearby, C.panel_rows)

    local entry_h = line_h + (C.show_bars and (bar_h + bar_gap) or 0)
    local rank_lines = 1
    local sep_h = 6
    local panel_h = pad + line_h + (C.show_bars and (bar_h + bar_gap) or 0)
                  + (rank_lines * line_h)
                  + sep_h + line_h
                  + (rows > 0 and sep_h or 0)
                  + (rows * entry_h) + pad

    draw.filled_rect(x0 - pad, y0 - pad, w + pad * 2, panel_h, DC.PANEL_BG)
    local x, y = x0, y0

    -- Player HP header
    local hp_str = R.player_max_hp > 0 and string.format("%d/%d", math.max(0, math.ceil(R.player_hp)), math.max(1, math.ceil(R.player_max_hp))) or "---"
    draw.text("Ethan - HP " .. hp_str, x, y, DC.TEXT)
    y = y + line_h

    if C.show_bars and R.player_max_hp > 0 then
        local r = math.max(0, math.min(1, R.player_hp / R.player_max_hp))
        local bx = x + 16
        draw.filled_rect(bx, y, bar_w, bar_h, DC.BAR_EMPTY)
        draw.filled_rect(bx, y, math.floor(bar_w * r), bar_h, DC.BAR_FILL)
        y = y + bar_h + bar_gap
    end

    -- Rank (below Ethan HP)
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GameManager")
        if gm then
            draw.text("Rank: " .. tostring(gm:call("getGameRank")) .. " / 9", x, y, DC.TEXT)
            y = y + line_h
        end
    end)

    y = y + 2; draw.filled_rect(x, y, w - pad, 1, DC.SEP); y = y + 4

    draw.text(string.format("Enemies: %d", #nearby), x, y, DC.TEXT_GRAY)
    y = y + line_h

    if rows > 0 then
        y = y + 2; draw.filled_rect(x, y, w - pad, 1, DC.SEP); y = y + 4
    end

    for i = 1, rows do
        local e = nearby[i]
        local hp_cur = math.max(0, math.ceil(e.hp or 0))
        local hp_max = math.max(1, math.ceil(e.mhp or 1))
        local ratio  = hp_max > 0 and math.max(0, math.min(1, hp_cur / hp_max)) or 0

        -- Alternating row background
        if i % 2 == 0 then
            draw.filled_rect(x0 - pad, y - 2, w + pad * 2, entry_h + 2, DC.ALT_ROW)
        end

        -- Name (left) + HP + distance (right)
        local name_col = DC.NAME_DEFAULT
        if C.dist_color then
            if e.dist < 5 then name_col = DC.NAME_CLOSE
            elseif e.dist < 15 then name_col = DC.NAME_MID end
        end

        local display_name = e.name
        if #display_name > 12 then display_name = display_name:sub(1, 11) .. "…" end

        local pct_str = ""
        if C.show_pct and hp_max > 0 then pct_str = string.format("  %d%%", math.floor(ratio * 100)) end
        local dist_str = string.format("%.0fm", e.dist)

        -- Left: name
        draw.text(display_name, x, y, name_col)
        -- Right: HP values + distance
        local hp_info = string.format("%d / %d%s   %s", hp_cur, hp_max, pct_str, dist_str)
        local hp_col = DC.HP_GOOD
        if ratio < 0.25 then hp_col = DC.HP_CRIT
        elseif ratio < 0.5 then hp_col = DC.HP_LOW end
        draw.text(hp_info, x + 120, y, hp_col)
        y = y + line_h

        -- HP bar with gradient fill
        if C.show_bars and hp_max > 0 then
            local bx = x + 4
            draw.filled_rect(bx, y, bar_w, bar_h, DC.BAR_TRACK)
            local fill_col = hp_gradient(ratio)
            draw.filled_rect(bx, y, math.floor(bar_w * ratio), bar_h, fill_col)
            draw.filled_rect(bx, y, bar_w, 1, DC.BORDER)
            draw.filled_rect(bx, y + bar_h - 1, bar_w, 1, DC.BORDER)
            y = y + bar_h + bar_gap
        end
    end
end

-- ── HUD Strip (top-right, active features) ──
local function render_hud_strip()
    if not has_draw_api then return end
    local tags = {}
    if C.godmode then tags[#tags+1]="GOD" end
    if C.inf_ammo then tags[#tags+1]="∞AMMO" end
    if C.enemy_insta_kill then tags[#tags+1]="OHK" end
    if C.noclip then tags[#tags+1]="NOCLIP" end
    if C.move_speed_mult ~= 1.0 then tags[#tags+1]=string.format("%.1fx", C.move_speed_mult) end
    if C.game_speed_on then tags[#tags+1]=string.format("G:%.1fx", C.game_speed) end
    if C.change_enemy_speed then tags[#tags+1]=string.format("ESPD:%.1fx", C.enemy_speed_mult) end
    if #tags == 0 then return end
    local text = table.concat(tags, "  ·  ")
    local tw = #text * 7.5 + 40
    local sw = 1920  -- fallback screen width
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local scene = sdk.call_native_func(sm, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
        local mv = scene:call("get_MainView")
        local sz = mv:call("get_Size")
        if sz then sw = sz.w end
    end)
    local hx = sw - tw - 16
    local hy = 16
    draw.filled_rect(hx, hy, tw, 24, 0xBB1A1A2E)
    draw.filled_rect(hx, hy + 24, tw, 1, 0x44444466)
    draw.text(text, hx + 10, hy + 4, 0xDD88CCFF)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Colors (RE9 style)
-- ═══════════════════════════════════════════════════════════════════════════

local CLR = {
    ON        = 0xFF44FF88,    -- green: active toggle
    OFF       = 0xFFEEEEFF,    -- light: inactive toggle
    CAT       = 0xFFFFDD88,    -- gold: section header
    HEAD      = 0xFFEEEEFF,    -- section headers
    MUTED     = 0xFF999999,    -- dim text
    WHITE     = 0xFFEEEEFF,    -- default text
    ACCENT    = 0xFFFFDD88,    -- gold highlights
}

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Helpers (RE9 style)
-- ═══════════════════════════════════════════════════════════════════════════

local function section(text, color)
    imgui.spacing()
    imgui.spacing()
    imgui.push_style_color(27, color or CLR.CAT) -- ImGuiCol_Separator
    imgui.separator()
    imgui.pop_style_color(1)
    imgui.text_colored("  " .. text, color or CLR.CAT)
    imgui.spacing()
end

local function hdr(text)
    imgui.spacing()
    imgui.spacing()
    imgui.text_colored(text, CLR.HEAD)
    imgui.separator()
    imgui.spacing()
end

local function tog(label, key, tip)
    local v = C[key]
    imgui.push_style_color(0, v and CLR.ON or CLR.OFF)
    local ch, nv = imgui.checkbox(label, v)
    imgui.pop_style_color(1)
    if tip and imgui.is_item_hovered then pcall(function() imgui.set_tooltip(tip) end) end
    if ch then
        C[key] = nv
        pcall(cfg_save)
        toast(nv and (label .. " ON") or (label .. " off"))
    end
end

local function hp_bar(cur, mx, w)
    if not cur or not mx or mx <= 0 then imgui.text_colored("HP: ---", CLR.MUTED); return end
    local r = math.max(0, math.min(1, cur / mx))
    imgui.progress_bar(r, w or 200, 16, ("%d / %d"):format(math.ceil(cur), math.ceil(mx)))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Player Tab
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_player()
    -- ── Health ──
    section("Health", CLR.CAT)
    tog("God Mode", "godmode", "You'll no longer take damage with this")
    imgui.text("Health:")
    imgui.same_line()
    hp_bar(R.player_hp, R.player_max_hp, 200)

    -- ── Movement ──
    section("Movement", CLR.CAT)
    tog("Noclip", "noclip", "Move wherever you want (WASD + Space/Shift)")
    if C.noclip then
        imgui.same_line(); imgui.text_colored("ACTIVE", CLR.ON)
        local ch, v = imgui.slider_float("Speed##nc", C.noclip_speed, 0.1, 2.0, "%.2f")
        if ch then C.noclip_speed = v; cfg_save() end
    end

    imgui.spacing()
    imgui.text_colored("Movement Speed", CLR.WHITE)
    local presets = { {1.0, "1x"}, {1.5, "1.5x"}, {2.0, "2x"}, {3.0, "3x"}, {5.0, "5x"} }
    for i, p in ipairs(presets) do
        if i > 1 then imgui.same_line() end
        if imgui.button(p[2] .. "##spd") then
            C.move_speed_mult = p[1]; pcall(cfg_save)
        end
    end
    local ch_s, vs = imgui.slider_float("Speed##ps", C.move_speed_mult, 0.1, 100.0, "%.2fx")
    if ch_s then C.move_speed_mult = vs; pcall(cfg_save) end

    -- ── Combat ──
    section("Combat", CLR.CAT)
    tog("Infinite Ammo", "inf_ammo", "Ammo count never decreases")
    tog("Enemy Insta Kill", "enemy_insta_kill", "Instantly kill enemies when damaging them")

    imgui.spacing()
    imgui.text_colored("Enemy Speed", CLR.WHITE)
    tog("Change Enemy Speed", "change_enemy_speed", "This won't work for all enemies and bosses!")
    if C.change_enemy_speed then
        local ch, v = imgui.slider_float("Speed##es", C.enemy_speed_mult, 0.1, 10.0, "%.2fx")
        if ch then C.enemy_speed_mult = v; pcall(cfg_save) end
        if imgui.button("Reset##es") then C.enemy_speed_mult = 1.0; pcall(cfg_save) end
    end

    -- ── Game Speed ──
    section("Game Speed", CLR.CAT)
    tog("Game Speed Override", "game_speed_on")
    if C.game_speed_on then
        local sp_presets = { {0.25, "0.25x"}, {0.5, "0.5x"}, {1.0, "1x"}, {2.0, "2x"}, {3.0, "3x"} }
        for i, p in ipairs(sp_presets) do
            if i > 1 then imgui.same_line() end
            if imgui.button(p[2] .. "##gs") then C.game_speed = p[1]; pcall(cfg_save) end
        end
        local ch, v = imgui.slider_float("Speed##game", C.game_speed, 0.1, 5.0, "%.2fx")
        if ch then C.game_speed = v; pcall(cfg_save) end
    end

    -- ── Scale ──
    section("Scale", CLR.CAT)
    local ch_sc, vsc = imgui.slider_float("Player Scale##sc", C.player_scale, 0.1, 100.0, "%.2fx")
    if ch_sc then
        C.player_scale = vsc; pcall(cfg_save)
        pcall(function() getLocalPlayer():get_Transform():set_LocalScale(Vector3f.new(vsc,vsc,vsc)) end)
    end
    if imgui.button("Reset Scale##sc") then
        C.player_scale = 1.0; pcall(cfg_save)
        pcall(function() getLocalPlayer():get_Transform():set_LocalScale(Vector3f.new(1,1,1)) end)
    end

    -- ── Items ──
    section("Items", CLR.CAT)
    if imgui.button("Unlock All Items (Item Box)") then addAllItemsToItemBox(); toast("Items added to box") end
    imgui.same_line()
    if imgui.button("Max Inventory") then setMaxInventory(); toast("Inventory maxed") end

    -- ── Stats ──
    section("Stats", CLR.CAT)
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GameManager")
        if gm then imgui.text_colored("Rank: " .. tostring(gm:call("getGameRank")) .. " / 9", CLR.WHITE) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Objects Tab
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_objects()
    if EMV.render_objects_tab then
        pcall(EMV.render_objects_tab)
    else
        imgui.text_colored("Objects Tab not loaded", 0xFFFF4444)
        if imgui.tree_node("EMV Debug") then
            for k, _ in pairs(EMV) do imgui.text("  " .. tostring(k)) end
            imgui.tree_pop()
        end
    end
end

local function ui_inspector()
    if EMV.render_method_inspector then
        pcall(EMV.render_method_inspector)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF4444)
    end
end

local function ui_spawner()
    if EMV.render_spawner_tab then
        pcall(EMV.render_spawner_tab)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF4444)
    end
end

local function ui_viewer()
    if EMV.render_viewer_tab then
        pcall(EMV.render_viewer_tab)
    else
        imgui.text_colored("EMV Engine not loaded", 0xFFFF4444)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Overlay Tab
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_overlay()
    section("Overlays", CLR.CAT)
    tog("Dev Overlay (top-left)", "show_dev_overlay")
    tog("Enemy Panel", "enemy_panel")

    section("3D ESP", CLR.CAT)
    tog("Enemy ESP", "enemy_esp")
    tog("Item ESP", "item_esp")
    tog("Spawn ESP", "spawn_esp")
    tog("Damage Numbers", "show_damage_numbers")

    section("Display Options", CLR.CAT)
    tog("Show HP Bars", "show_bars")
    tog("Show %", "show_pct")
    tog("Hide Dead", "hide_dead")
    tog("Distance Colors", "dist_color")

    section("Panel Settings", CLR.CAT)
    local ch, v
    ch, v = imgui.drag_int("Panel Rows", C.panel_rows, 1, 1, 20)
    if ch then C.panel_rows = v; cfg_save() end

    ch, v = imgui.drag_float("ESP Range", C.esp_range, 1.0, 5, 200, "%.0f")
    if ch then C.esp_range = v; cfg_save() end

    ch, v = imgui.drag_int("ESP Font", C.esp_font, 1, 8, 48)
    if ch then C.esp_font = v; cfg_save() end

    ch, v = imgui.drag_int("Panel Font", C.panel_font, 1, 8, 32)
    if ch then C.panel_font = v; cfg_save() end

    ch, v = imgui.drag_int("Panel Width", C.panel_w, 5, 200, 800)
    if ch then C.panel_w = v; cfg_save() end

    imgui.spacing()
    if imgui.button("Save") then cfg_save(); toast("Saved") end
    imgui.same_line()
    if imgui.button("Reload") then cfg_load(); toast("Reloaded") end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Main Window (RE9 style)
-- ═══════════════════════════════════════════════════════════════════════════

local TAB_DEFS = {
    { name = "Player",    fn = ui_player },
    { name = "Objects",   fn = ui_objects },
    { name = "Inspector", fn = ui_inspector },
    { name = "Spawner",   fn = ui_spawner },
    { name = "Viewer",    fn = ui_viewer },
    { name = "Overlay",   fn = ui_overlay },
}

local trainer_visible = true

re.on_draw_ui(function()
    local changed
    changed, trainer_visible = imgui.checkbox(TITLE, trainer_visible)
    if not trainer_visible then return end

    if imgui.begin_window(TITLE .. "###trainer_main", true, 0) then
        -- ── Status Bar ──
        local active = 0
        for _, k in ipairs({"godmode","inf_ammo","enemy_insta_kill","noclip","game_speed_on","change_enemy_speed","show_damage_numbers","enemy_esp","item_esp","spawn_esp"}) do
            if C[k] then active = active + 1 end
        end

        -- Player HP inline
        if R.player_max_hp > 0 then
            local ratio = math.max(0, math.min(1, R.player_hp / R.player_max_hp))
            local hp_col
            if ratio > 0.6 then hp_col = 0xFF44FF88
            elseif ratio > 0.3 then hp_col = 0xFF44DDFF
            else hp_col = 0xFF4444FF end
            imgui.text_colored(("HP %d/%d"):format(math.ceil(R.player_hp), math.ceil(R.player_max_hp)), hp_col)
            imgui.same_line()
        end

        if active > 0 then
            imgui.text_colored(("%d active"):format(active), CLR.ON)
        else
            imgui.text_colored("idle", 0xFF777777)
        end

        if #R.enemies > 0 then
            imgui.same_line()
            imgui.text_colored(("%d enemies"):format(#R.enemies), 0xFFFFAA44)
        end

        if R.loaded_scene ~= "" then
            imgui.same_line()
            imgui.text_colored("  " .. R.loaded_scene, 0xFFFFDD88)
        elseif R.scene_name ~= "" then
            imgui.same_line()
            imgui.text_colored("  " .. R.scene_name, 0xFF777777)
        end

        imgui.separator()

        -- ── Tab Buttons (RE9 4-color style) ──
        for i, tab in ipairs(TAB_DEFS) do
            if i > 1 then imgui.same_line() end
            local is_active = (cur_tab == i)
            if is_active then
                imgui.push_style_color(21, 0xFF44FF88)  -- Button
                imgui.push_style_color(22, 0xFF44FF88)  -- ButtonHovered
                imgui.push_style_color(23, 0xFF44FF88)  -- ButtonActive
                imgui.push_style_color(0, 0xFF1A1A2E)   -- Text (dark on green)
            else
                imgui.push_style_color(21, 0xFF333344)  -- Button
                imgui.push_style_color(22, 0xFF444466)  -- ButtonHovered
                imgui.push_style_color(23, 0xFF555577)  -- ButtonActive
                imgui.push_style_color(0, 0xFFAAAAAA)   -- Text
            end
            if imgui.button(tab.name .. "##tab" .. i) then cur_tab = i end
            imgui.pop_style_color(4)
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- ── Draw selected tab ──
        local sel = TAB_DEFS[cur_tab]
        if sel and sel.fn then pcall(sel.fn) end

        imgui.end_window()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Draw API Overlays (re.on_frame — RE9 style)
-- ═══════════════════════════════════════════════════════════════════════════
re.on_frame(function()
    if not draw then return end
    pcall(render_dev_overlay)
    pcall(render_enemy_panel)
    pcall(render_hud_strip)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 3D ESP + Damage Numbers (draw.world_to_screen — works without D2D)
-- ═══════════════════════════════════════════════════════════════════════════
re.on_frame(function()
    if not draw then return end

    -- 3D ESP: Enemies
    if C.enemy_esp then
        for _, e in ipairs(R.enemies) do
            if e.dist <= C.esp_range and e.pos and not (C.hide_dead and e.dead) then
                local wp = Vector3f.new(e.pos.x, e.pos.y + 1.9, e.pos.z)
                local sp = draw.world_to_screen(wp)
                if sp then
                    local r = e.mhp > 0 and e.hp/e.mhp or 0
                    -- ABGR for draw API: red-ish for enemies
                    local col = r > 0.5 and 0xFF44FF44 or (r > 0.25 and 0xFF44CCFF or 0xFF4444FF)
                    draw.text(e.name, sp.x+1, sp.y+1, 0xCC000000)
                    draw.text(e.name, sp.x, sp.y, col)
                    local info = string.format("%d/%d  %.0fm", math.ceil(e.hp), math.ceil(e.mhp), e.dist)
                    draw.text(info, sp.x+1, sp.y+17, 0xCC000000)
                    draw.text(info, sp.x, sp.y+16, 0xFFBBBBBB)
                end
            end
        end
    end

    -- 3D ESP: Items
    if C.item_esp then
        for _, it in ipairs(R.items) do
            if it.dist <= C.esp_range and it.pos then
                local sp = draw.world_to_screen(it.pos)
                if sp then
                    -- Green for items
                    draw.text(it.name, sp.x+1, sp.y+1, 0xCC000000)
                    draw.text(it.name, sp.x, sp.y, 0xFF44FF44)
                    draw.text(string.format("%.0fm", it.dist), sp.x+1, sp.y+17, 0xCC000000)
                    draw.text(string.format("%.0fm", it.dist), sp.x, sp.y+16, 0xFF88CC88)
                end
            end
        end
    end

    -- 3D ESP: Spawners
    if C.spawn_esp then
        for _, s in ipairs(R.spawners) do
            if s.dist <= C.esp_range and s.pos then
                local sp = draw.world_to_screen(s.pos)
                if sp then
                    draw.text(s.name, sp.x+1, sp.y+1, DC.SHADOW)
                    draw.text(s.name, sp.x, sp.y, DC.TEXT_YELLOW)
                    draw.text(string.format("%.0fm", s.dist), sp.x+1, sp.y+17, DC.SHADOW)
                    draw.text(string.format("%.0fm", s.dist), sp.x, sp.y+16, DC.TEXT_GRAY)
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- Objects Tab 3D Overlay (reads EMV._overlay_objects, LIVE positions)
    -- ═══════════════════════════════════════════════════════════════════
    pcall(function()
        local cfg = _G.EMV and _G.EMV._overlay_cfg
        if not cfg or not cfg.enabled then return end
        local objs = _G.EMV._overlay_objects
        if not objs or #objs == 0 then return end

        local pp = R.player_pos
        for _, obj in ipairs(objs) do
            -- Read LIVE position from Transform each frame
            local wx, wy, wz = obj.x, obj.y, obj.z
            if obj.gameobj then
                pcall(function()
                    local xf = obj.gameobj:call("get_Transform")
                    if xf then
                        local p = xf:call("get_Position")
                        if p then wx, wy, wz = p.x, p.y, p.z end
                    end
                end)
            end
            if not wx then goto cont end

            local wp = Vector3f.new(wx, wy, wz)
            local sp = draw.world_to_screen(wp)
            if sp then
                local sx, sy = sp.x, sp.y
                local live_dist = pp and math.sqrt((wx-pp.x)^2 + (wy-pp.y)^2 + (wz-pp.z)^2) or obj.dist

                -- Name
                local name = obj.name or "?"
                if #name > 24 then name = name:sub(1, 23) .. "…" end
                draw.text(name, sx + 1, sy + 1, DC.SHADOW)
                draw.text(name, sx, sy, DC.TEXT)

                -- Distance
                if live_dist then
                    local ds = string.format("%.1fm", live_dist)
                    draw.text(ds, sx + 1, sy + 17, DC.SHADOW)
                    draw.text(ds, sx, sy + 16, DC.TEXT_GRAY)
                end

                -- GUID (yellow)
                if obj.guid then
                    local gs = #obj.guid > 12 and obj.guid:sub(1, 11) .. "…" or obj.guid
                    draw.text(gs, sx + 1, sy + 33, DC.SHADOW)
                    draw.text(gs, sx, sy + 32, DC.TEXT_YELLOW)
                end

                -- Folder path (cyan)
                if obj.folder_path then
                    local ps = obj.folder_path
                    if #ps > 30 then ps = "…" .. ps:sub(-29) end
                    local py = obj.guid and sy + 48 or sy + 32
                    draw.text(ps, sx + 1, py + 1, DC.SHADOW)
                    draw.text(ps, sx, py, DC.TEXT_CYAN)
                end
            end
            ::cont::
        end
    end)

    -- Damage numbers
    if C.show_damage_numbers and #R.damage_numbers > 0 then
        local now = os.clock()
        for _, dn in ipairs(R.damage_numbers) do
            local elapsed = now - dn.time
            if elapsed < dn.dur and elapsed >= 0 then
                local prog = elapsed / dn.dur
                local alpha = prog < 0.2 and (prog/0.2) or math.max(0, 1 - (prog-0.7)/0.3)
                local sp = draw.world_to_screen(dn.pos)
                if sp then
                    local sx = sp.x + dn.vx * prog
                    local sy = sp.y + dn.vy * prog
                    local a = math.floor(alpha * 255)
                    draw.text(dn.text, sx+1, sy+1, a * 0x1000000)
                    draw.text(dn.text, sx, sy, a * 0x1000000 + 0x00F7FFF9)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Main frame loop
-- ═══════════════════════════════════════════════════════════════════════════
re.on_frame(function()
    R.tick = R.tick + 1
    -- EMV Engine per-frame hooks
    if EMV.process_on_frame_calls then pcall(EMV.process_on_frame_calls) end
    if EMV.process_deferred_calls then pcall(EMV.process_deferred_calls) end
    if EMV.ObjectCache then pcall(EMV.ObjectCache.sweep, EMV.ObjectCache) end
    -- EMV Objects overlay background scan (self-throttled by scan_interval)
    if EMV.objects_background_update then pcall(EMV.objects_background_update) end

    -- Noclip every frame
    if C.noclip then pcall(do_noclip) end

    -- Scan every 15 frames
    if R.tick % 15 == 0 then
        pcall(function() R.player_pos = get_player_pos() end)
        pcall(function() R.player_rot = get_camera_rot() end)
        pcall(function()
            local s = get_scene()
            R.scene_name = s and tostring(s:call("get_Name") or "") or ""
        end)
        R.player_hp, R.player_max_hp = get_player_hp()
        -- GameManager fields: Chapter, DA Score, Rank, Difficulty
        pcall(function()
            local gm = sdk.get_managed_singleton("app.GameManager")
            if not gm then return end
            local ch = gm:get_field("_CurrentChapter")
            R.chapter = ch ~= nil and tostring(ch) or ""
            pcall(function() R.da_score = gm:get_field("RankPoint") or 0 end)
            pcall(function() R.rank = gm:call("getGameRank") or 0 end)
            pcall(function() R.difficulty = gm:get_field("GameDifficulty") or 0 end)
        end)
        -- HarawataUtil: try getCurrentChapterName (RE7 codename utility)
        pcall(function()
            local scene_str = nil
            -- Approach 1: singleton
            pcall(function()
                local hu = sdk.get_managed_singleton("app.HarawataUtil")
                if hu then
                    local name = hu:call("getCurrentChapterName")
                    if name and tostring(name) ~= "" then scene_str = tostring(name) end
                end
            end)
            -- Approach 2: static call via type definition
            if not scene_str then
                pcall(function()
                    local td = sdk.find_type_definition("app.HarawataUtil")
                    if td then
                        local method = td:get_method("getCurrentChapterName")
                        if method then
                            local name = method:call(nil)
                            if name and tostring(name) ~= "" then scene_str = tostring(name) end
                        end
                    end
                end)
            end
            R.loaded_scene = scene_str or ""
        end)
        -- MapManager fields: Area Name, Room ID, Scene Name
        pcall(function()
            local mm = sdk.get_managed_singleton("app.MapManager")
            if not mm then return end
            pcall(function()
                local name = mm:call("getAreaName")
                R.area_name = name and tostring(name) or ""
            end)
            -- Try additional scene name methods on MapManager
            if R.loaded_scene == "" then
                pcall(function()
                    local name = mm:call("getCurrentSceneName")
                    if name and tostring(name) ~= "" then R.loaded_scene = tostring(name) end
                end)
            end
            if R.loaded_scene == "" then
                pcall(function()
                    local name = mm:call("getMapName")
                    if name and tostring(name) ~= "" then R.loaded_scene = tostring(name) end
                end)
            end
            if R.loaded_scene == "" then
                pcall(function()
                    local name = mm:call("getSceneName")
                    if name and tostring(name) ~= "" then R.loaded_scene = tostring(name) end
                end)
            end
            pcall(function() R.room_id = mm:call("getRoomID") or 0 end)
            pcall(function() R.map_cat = mm:call("getMapCategory") or 0 end)
            pcall(function() R.map_level = mm:call("getMapLevel") or 0 end)
        end)
        pcall(function() R.enemies = scan_enemies() or {} end)
        pcall(function() R.items = scan_items() or {} end)
        pcall(function() R.spawners = scan_spawners() or {} end)
    end

    -- Game speed
    if C.game_speed_on and R.tick % 10 == 0 then
        pcall(function() sdk.find_type_definition("via.Application"):get_method("set_GlobalSpeed"):call(nil, C.game_speed) end)
    end

    -- Cleanup toasts
    local now = os.clock()
    local live = {}
    for _, t in ipairs(R.toasts) do if now - t.time < t.dur then live[#live+1] = t end end
    R.toasts = live

    -- Cleanup damage numbers
    local live_dn = {}
    for _, dn in ipairs(R.damage_numbers) do if now - dn.time < dn.dur then live_dn[#live_dn+1] = dn end end
    R.damage_numbers = live_dn
end)

-- ═══════════════════════════════════════════════════════════════════════════
if log then log.info("[RE7] Trainer v2.0 loaded") end
toast("RE7 Trainer v2.0 loaded!", 5.0)
