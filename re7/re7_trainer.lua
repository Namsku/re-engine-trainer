--[[
    RE7 Trainer v3.0 — by namsku
    UI ported from Biorand RE3R Trainer v3.0
    Hooks based on proven RE7 methods from community trainers
]]

local TITLE    = "Biorand RE7 Trainer v3.0"
local CFG_FILE = "re7_trainer_v3.json"

if reframework and reframework.get_game_name and reframework:get_game_name() ~= "re7" then
    return
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Config
-- ═══════════════════════════════════════════════════════════════════════════
local C = {
    -- Game cheats
    godmode = false, inf_ammo = false,
    move_speed_mult = 1.0, enemy_insta_kill = false,
    change_enemy_speed = false, enemy_speed_mult = 1.0,
    player_scale = 1.0, game_speed_on = false, game_speed = 1.0,
    noclip = false, noclip_speed = 0.4,
    show_damage_numbers = true,
    -- Overlays
    show_dev_overlay = true, enemy_panel = true, show_spawn_overlay = true,
    show_chapter_overlay = true,
    -- ESP
    enemy_esp = true, item_esp = true, spawn_esp = true, show_object_esp = false,
    enemy_esp_range = 50.0, item_esp_range = 50.0, object_esp_range = 20.0,
    hide_dead = true, dist_color = true,
    -- Colors (ARGB 0xAARRGGBB)
    col_enemy_name = 0xFFFFFFFF,
    col_item_name  = 0xFF55FF99,
    col_spawn_name = 0xFFFFAA44,
    -- Font / panel
    font_size = 16, esp_font = 18,
    panel_rows = 8, panel_font = 16, panel_w = 460, panel_bar_w = 150, panel_bar_h = 8,
    show_bars = true, show_pct = true,
    -- Scanner
    scan_interval = 45,
}

local PERSIST_KEYS = {}
for k in pairs(C) do PERSIST_KEYS[#PERSIST_KEYS + 1] = k end

local function cfg_save()
    if not json then return end
    local data = {}
    for _, k in ipairs(PERSIST_KEYS) do data[k] = C[k] end
    pcall(json.dump_file, CFG_FILE, data)
end

local function cfg_load()
    if not json then return end
    local ok, t = pcall(json.load_file, CFG_FILE)
    if ok and type(t) == "table" then
        for _, k in ipairs(PERSIST_KEYS) do
            if t[k] ~= nil and type(t[k]) == type(C[k]) then C[k] = t[k] end
        end
    end
end
cfg_load()
re.on_config_save(cfg_save)

-- ═══════════════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════════════
local R = {
    tick = 0, enemies = {}, items = {}, spawners = {}, objects = {},
    player_hp = 0, player_max_hp = 0,
    player_pos = nil, player_rot = nil, scene_name = "", chapter = "",
    loaded_scene = "",
    da_score = 0, rank = 0, difficulty = 0, area_name = "", room_id = 0, map_cat = 0, map_level = 0,
    _chapter_no = 0, _chapter_time = 0,
    dev_overlay_bottom = 0, damage_numbers = {},
    -- Selection (RE3R inspector style)
    sel_type = nil, sel_data = nil,
    -- UI state
    ui_tab = 1,
    -- Status flash shown in dev overlay
    status_msg = "", status_until = 0,
    -- Screen size (updated each scan cycle)
    sw = 1920, sh = 1080,
}

local function toast(msg, dur)
    R.status_msg   = tostring(msg)
    R.status_until = R.tick + math.floor((dur or 3) * 60)
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
    local td = sdk.find_type_definition(type_name)
    if not td then return nil end
    local ok, c = pcall(function()
        return go:call("getComponent(System.Type)", td:get_runtime_type())
    end)
    return ok and c or nil
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

local function clamp_text(text, max_chars)
    local s = tostring(text or "")
    if #s <= max_chars then return s end
    return s:sub(1, max_chars - 3) .. "..."
end

local function get_window_size()
    local mv = nil
    pcall(function()
        local sm = sdk.get_native_singleton("via.SceneManager")
        local td = sdk.find_type_definition("via.SceneManager")
        local scene = sdk.call_native_func(sm, td, "get_CurrentScene()")
        if not scene then return end
        mv = scene:call("get_MainView")
    end)
    if not mv then return nil end
    local sz = nil
    pcall(function() sz = mv:call("get_WindowSize") end)
    if not sz then pcall(function() sz = mv:call("get_Size") end) end
    return sz
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
-- GUID Extraction (RE3R style — parses "Name@guid]" from ToString())
-- ═══════════════════════════════════════════════════════════════════════════
local function extract_guid(go)
    if not go then return nil end
    local ok, ts = pcall(go.call, go, "ToString()")
    if ok and ts then
        local guid = tostring(ts):match("@([%x%-]+)%]$")
        if guid and guid ~= "" then return guid end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Constants / lookup tables
-- ═══════════════════════════════════════════════════════════════════════════
local DIFFICULTY_NAMES = { [0]="Easy", [1]="Normal", [2]="Madhouse", [3]="Easy" }
local OVERLAY_PANEL_W  = 500   -- shared width for all right-side D2D panels

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

local function enemy_display_name(go)
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

local _eac_rt = nil
local function get_eac_rt()
    if not _eac_rt then
        local td = sdk.find_type_definition("app.EnemyActionController")
        _eac_rt = td and td:get_runtime_type()
    end
    return _eac_rt
end

local GOAL_NAMES = {
    Discovery   = "Alert",   Wander      = "Patrol",  Appear    = "Appear",
    Release     = "Idle",    UnDiscovery = "Search",  Destination = "Moving",
    ClosedRoute = "Blocked", Mimicry     = "Lurk",    ExtraWait   = "Wait",
}

local function enemy_state_str(eac)
    if not eac then return "" end
    local parts = {}

    pcall(function()
        local think = eac:get_field("<myThink>k__BackingField")
        if not think then return end

        -- Current AI goal from GoalUpdater
        local gu   = think:get_field("GoalUpdater")
        local arb  = gu and gu:get_field("Basic")
        local node = arb and arb:get_field("CurrentGoalNode")
        local goal = node and node:get_field("Value")
        if goal then
            local gname = goal:get_type_definition():get_name()
            parts[#parts+1] = GOAL_NAMES[gname] or gname
        end

        -- Attack status from Em4000Status (or any EnemyStatus subtype)
        local status = think:get_field("<myStatus>k__BackingField")
        if status then
            local ok, isAtk = pcall(function() return status:get_field("<IsAttack>k__BackingField") end)
            if ok and isAtk == true then parts[#parts+1] = "ATTACK" end
        end
    end)

    -- Damage reaction flag on the EAC itself
    local ok, hasDmg = pcall(function() return eac:get_field("<hasDamage>k__BackingField") end)
    if ok and hasDmg == true then parts[#parts+1] = "HIT" end

    return table.concat(parts, " · ")
end

local function scan_enemies()
    local result = {}
    local ppos = R.player_pos
    local om = sdk.get_managed_singleton("app.ObjectManager")
    if not om then return result end
    local mo = om:get_field("ManagedObjects")
    if not mo then return result end

    local bucket = nil
    pcall(function() bucket = mo:call("get_Item", 1) end)
    if not bucket then return result end
    local cnt = 0
    pcall(function() cnt = bucket:call("get_Count") or 0 end)

    local eac_rt = get_eac_rt()

    for i = 0, cnt - 1 do
        pcall(function()
            local go = bucket:call("get_Item", i)
            if not go then return end
            local go_name = tostring(go:call("get_Name") or "?")
            local xf = go:call("get_Transform")
            local pos = xf and xf:call("get_Position")
            if not pos then return end

            -- Skip pooled/unspawned enemies sitting at world origin
            if pos.x == 0 and pos.y == 0 and pos.z == 0 then return end

            local hp, mhp, state_str = 0, 0, ""
            pcall(function()
                if not eac_rt then return end
                local eac = go:call("getComponent(System.Type)", eac_rt)
                if not eac then return end
                state_str = enemy_state_str(eac)
                local mdc = eac:get_field("MyDamageController")
                if mdc then
                    local hi = mdc:get_field("HealthInfo")
                    if hi then
                        hp  = hi:get_field("Health")    or 0
                        mhp = hi:get_field("MaxHealth") or 0
                    end
                end
            end)

            local guid = extract_guid(go)
            result[#result+1] = {
                name      = enemy_display_name(go),
                go_name   = go_name,
                go_guid   = guid,
                guid      = guid,
                hp        = hp,
                mhp       = mhp,
                dead      = (hp <= 0 and mhp > 0),
                state     = state_str,
                dist      = dist3(pos, ppos),
                pos       = pos,
                go        = go,
            }
        end)
    end
    table.sort(result, function(a, b) return a.dist < b.dist end)
    return result
end

-- Item name: only actual collectibles (not examine-only interactables)
local function is_collectible_name(name)
    -- Must be a sm* object with a collectible suffix/keyword
    if not name:match("^sm%d") then return false end
    -- Exclude body parts and event props
    if name:find("Ethan") or name:find("_Event") or name:find("_Action")
       or name:find("_Push") or name:find("Dynamic") or name:find("cloth")
       or name:find("Glass") or name:find("Wall") or name:find("LampShade")
       or name:find("EntranceDoor") or name:find("Dresser") or name:find("Shelf")
       or name:find("Clock") or name:find("CupBoard") or name:find("Drawer")
       or name:find("Window") or name:find("Chain") or name:find("Pot")
       or name:find("Faucet") or name:find("Refrigerator") or name:find("InteractTxt")
       or name:find("Props") or name:find("Lighted") then
        return false
    end
    -- Accept known collectible keywords
    return name:find("DetailSearch") or name:find("Coin") or name:find("Videotape")
        or name:find("_Map") or name:find("Picture") or name:find("Fuse")
        or name:find("VoiceRecorder") or name:find("Key") or name:find("Herb")
        or name:find("Tape") or name:find("Diary") or name:find("Document")
        or name:find("Photo") or name:find("Steroids") or name:find("Serum")
        or name:find("Antidote") or name:find("Repair") or name:find("Flower")
        or name:find("Mushroom") or name:find("Necklace") or name:find("Treasure")
end

local function scan_items()
    local result = {}
    local ppos = R.player_pos
    local om = sdk.get_managed_singleton("app.ObjectManager")
    if not om then return result end
    local mo = om:get_field("ManagedObjects")
    if not mo then return result end

    local seen = {}

    local function add_bucket(idx, filter)
        pcall(function()
            local bucket = mo:call("get_Item", idx)
            if not bucket then return end
            local cnt = bucket:call("get_Count") or 0
            for i = 0, cnt - 1 do
                pcall(function()
                    local go = bucket:call("get_Item", i)
                    if not go then return end
                    local addr = tostring(go:get_address())
                    if seen[addr] then return end
                    local name = tostring(go:call("get_Name") or "")
                    if filter and not is_collectible_name(name) then return end
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    seen[addr] = true
                    local guid = extract_guid(go)
                    result[#result+1] = { go_name=name, go_guid=guid, guid=guid,
                                          pos=pos, dist=dist3(pos, ppos), go=go }
                end)
            end
        end)
    end

    add_bucket(3, false)  -- dedicated items bucket — take all
    add_bucket(4, true)   -- props bucket — collectibles only, deduplicated

    table.sort(result, function(a, b) return a.dist < b.dist end)
    return result
end

-- Spawner name filter: bucket 5 has em* game objects (enemy spawn points / triggers)
local function is_spawner_name(name)
    return (name:match("^em%d") or name:match("^Em%d")) and true or false
end

local function scan_spawners()
    local result = {}
    local ppos = R.player_pos
    local om = sdk.get_managed_singleton("app.ObjectManager")
    if not om then return result end
    local mo = om:get_field("ManagedObjects")
    if not mo then return result end

    pcall(function()
        local bucket = mo:call("get_Item", 5)
        if not bucket then return end
        local cnt = bucket:call("get_Count") or 0
        for i = 0, cnt - 1 do
            pcall(function()
                local go = bucket:call("get_Item", i)
                if not go then return end
                local name = tostring(go:call("get_Name") or "")
                if not is_spawner_name(name) then return end
                local xf = go:call("get_Transform")
                local pos = xf and xf:call("get_Position")
                if not pos then return end
                local guid = extract_guid(go)
                local em_code = name:match("^[Ee]m(%d+)") or "?"
                result[#result+1] = { go_name=name, go_guid=guid, guid=guid,
                                      pos=pos, dist=dist3(pos, ppos), go=go,
                                      em_code=em_code }
            end)
        end
    end)

    table.sort(result, function(a, b) return a.dist < b.dist end)
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- All-Objects Scanner (uses ObjectManager buckets)
-- ═══════════════════════════════════════════════════════════════════════════

local function scan_all_objects()
    local om = sdk.get_managed_singleton("app.ObjectManager")
    if not om then R.objects = {}; return end
    local mo = om:get_field("ManagedObjects")
    if not mo then R.objects = {}; return end

    local eac_rt = get_eac_rt()
    local raw = {}

    local outer_cnt = 0
    pcall(function() outer_cnt = mo:call("get_Count") or 0 end)

    for bi = 0, outer_cnt - 1 do
        pcall(function()
            local bucket = mo:call("get_Item", bi)
            if not bucket then return end
            local cnt = bucket:call("get_Count") or 0
            for j = 0, cnt - 1 do
                pcall(function()
                    local go = bucket:call("get_Item", j)
                    if not go then return end
                    local xf = go:call("get_Transform")
                    local pos = xf and xf:call("get_Position")
                    if not pos then return end
                    local d = dist3({x=pos.x,y=pos.y,z=pos.z}, R.player_pos)
                    raw[#raw+1] = { go=go, pos=pos, d=d, bucket=bi }
                end)
            end
        end)
    end

    table.sort(raw, function(a, b) return a.d < b.d end)

    local results = {}
    for i = 1, math.min(#raw, 300) do
        pcall(function()
            local r = raw[i]
            local go = r.go
            local name = tostring(go:call("get_Name") or "")
            local guid = extract_guid(go)
            -- Tag by bucket
            local bucket_tags = { [0]="Player",[1]="Enemy",[2]="Weapon",[3]="Item",
                                   [4]="Prop",[5]="Trigger",[6]="VFX",[7]="Camera" }
            local tags = { bucket_tags[r.bucket] or ("B"..r.bucket) }
            results[#results+1] = {
                go_name  = name,
                go_guid  = guid,
                active   = true,
                pos      = { x=r.pos.x, y=r.pos.y, z=r.pos.z },
                dist     = r.d,
                tags     = tags,
                _go_ref  = go,
            }
        end)
    end
    R.objects = results
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
local _noclip_cc_was_disabled = false

local function do_noclip()
    local player = getLocalPlayer()
    if not player then return end

    local cc = getComponent(player, "via.physics.CharacterController")

    -- When noclip turns off, restore the CharacterController
    if not C.noclip then
        if _noclip_cc_was_disabled and cc then
            pcall(function() cc:call("set_Enabled", true) end)
            _noclip_cc_was_disabled = false
        end
        return
    end

    pcall(function()
        -- Suppress wall collision by disabling the CC each frame while noclip is on
        if cc then
            pcall(function() cc:call("set_Enabled", false) end)
            _noclip_cc_was_disabled = true
        end

        local xf  = player:get_Transform()
        local pos = xf:get_Position()
        local spd = C.noclip_speed
        local fwd = xf:call("get_Forward")
        local rgt = xf:call("get_Right")
        if reframework:is_key_down(0x57) then -- W: forward
            pos.x = pos.x + fwd.x * spd; pos.z = pos.z + fwd.z * spd
        end
        if reframework:is_key_down(0x53) then -- S: backward
            pos.x = pos.x - fwd.x * spd; pos.z = pos.z - fwd.z * spd
        end
        if reframework:is_key_down(0x44) then -- D: right
            pos.x = pos.x + rgt.x * spd; pos.z = pos.z + rgt.z * spd
        end
        if reframework:is_key_down(0x41) then -- A: left
            pos.x = pos.x - rgt.x * spd; pos.z = pos.z - rgt.z * spd
        end
        if reframework:is_key_down(0x20) then pos.y = pos.y + spd end -- Space: up
        if reframework:is_key_down(0x10) then pos.y = pos.y - spd end -- Shift: down
        xf:set_Position(pos)
    end)
end


-- ═══════════════════════════════════════════════════════════════════════════
-- D2D Font Management (RE3R style)
-- ═══════════════════════════════════════════════════════════════════════════
local _overlay_font_regular = nil
local _overlay_font_bold    = nil

local function get_overlay_font(bold)
    if not d2d then return nil end
    if bold then
        if not _overlay_font_bold then
            pcall(function() _overlay_font_bold = d2d.Font.new("Consolas", 18, true) end)
        end
        return _overlay_font_bold
    end
    if not _overlay_font_regular then
        pcall(function() _overlay_font_regular = d2d.Font.new("Consolas", 18, false) end)
    end
    return _overlay_font_regular
end

local function reset_overlay_fonts() _overlay_font_regular = nil; _overlay_font_bold = nil end

local _esp_fonts = {}
local function get_esp_font(sz, bold)
    local key = tostring(sz) .. (bold and "B" or "R")
    if not _esp_fonts[key] then
        if d2d then pcall(function() _esp_fonts[key] = d2d.Font.new("Consolas", sz, bold or false) end) end
    end
    return _esp_fonts[key]
end
local function reset_esp_fonts() _esp_fonts = {} end

-- ── D2D Draw Helpers (ARGB colors; draw API fallback for non-D2D environments) ──
local function d2d_text(font, text, x, y, col)
    if d2d and font then
        pcall(d2d.text, font, text, x+1, y+1, 0xCC000000)
        pcall(d2d.text, font, text, x, y, col)
    elseif draw then
        pcall(draw.text, text, x+1, y+1, 0xCC000000)
        pcall(draw.text, text, x, y, col)
    end
end

local function d2d_fill_rect(x, y, w, h, col)
    if d2d then pcall(d2d.fill_rect, x, y, w, h, col)
    elseif draw then pcall(draw.filled_rect, x, y, w, h, col) end
end

local _has_w2s = (draw ~= nil) and (draw.world_to_screen ~= nil)
local function world_to_screen(pos, y_off)
    if not _has_w2s or not pos then return nil end
    local ok, sp = pcall(draw.world_to_screen, Vector3f.new(pos.x, pos.y+(y_off or 0), pos.z))
    if not ok or not sp then return nil end
    if sp.x ~= sp.x or sp.y ~= sp.y then return nil end
    return sp
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Dev Overlay (RE3R KV-panel style — "BIORAND RE7", lime accent bar)
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_dev_overlay()
    if not C.show_dev_overlay then return end

    local LH=20; local PAD=14; local VX=92; local PANEL_W=420; local DIV_H=9; local TITLE_H=LH+4
    local lime=0xFF44FF88; local cyan=0xFF88DDFF; local yellow=0xFFFFCC44
    local grey=0xFF888888; local white=0xFFFFFFFF; local dkgrey=0xFF444444
    local hf = get_overlay_font(true)
    local vf = get_overlay_font(false)

    local rows = {}
    local function kv(label, value, vcol)
        local vs = tostring(value ~= nil and value or "")
        if vs == "" or vs == "nil" then return end
        rows[#rows+1] = { t="kv", label=label, value=vs, vcol=vcol or white }
    end
    local function div()
        if #rows > 0 and rows[#rows].t ~= "div" then rows[#rows+1] = {t="div"} end
    end

    -- Player
    local hp, mhp = R.player_hp, R.player_max_hp
    if hp and hp > 0 then
        local hpc = hp > 100 and lime or (hp > 50 and 0xFFFFAA44 or 0xFFFF5555)
        kv("HP", string.format("%.0f / %.0f", hp, mhp > 0 and mhp or hp), hpc)
    end
    if C.noclip then kv("NC", "ACTIVE", cyan) end
    -- World
    div()
    if R.loaded_scene ~= "" then kv("Scene", R.loaded_scene, yellow)
    elseif R.scene_name ~= "" then kv("Scene", R.scene_name, yellow) end
    if R.chapter ~= "" then kv("Chapter", R.chapter, cyan) end
    if R.area_name ~= "" then kv("Area", R.area_name, grey) end
    if R.rank > 0 then kv("Rank", R.rank, cyan) end
    if R.difficulty > 0 then kv("Diff", R.difficulty, grey) end
    -- Position
    div()
    local pos = R.player_pos
    if pos then
        kv("X", string.format("%.3f", pos.x), white)
        kv("Y", string.format("%.3f", pos.y), white)
        kv("Z", string.format("%.3f", pos.z), white)
    else kv("Pos", "(unavail)", dkgrey) end
    if R.player_rot then kv("Yaw", string.format("%.1f\xC2\xB0", R.player_rot.y), white) end
    -- Counts
    div()
    kv("Enemies", #R.enemies, white)
    kv("Items",   #R.items,   white)
    kv("Spawns",  #R.spawners, white)
    -- Status flash
    if R.status_msg ~= "" and R.tick < R.status_until then div(); kv(">>", R.status_msg, lime) end
    -- Trim trailing div
    if #rows > 0 and rows[#rows].t == "div" then rows[#rows] = nil end

    local total_h = 6 + TITLE_H
    for _, r in ipairs(rows) do total_h = total_h + (r.t=="div" and DIV_H or LH) end
    total_h = total_h + PAD

    local x, y = 30, 80
    d2d_fill_rect(x, y, PANEL_W, total_h, 0xCC000000)
    d2d_fill_rect(x, y, 4, total_h, lime)

    local cx = x + PAD
    local ty = y + 6
    d2d_text(hf, "BIORAND RE7", cx, ty, lime)
    ty = ty + TITLE_H

    for _, r in ipairs(rows) do
        if r.t == "div" then
            d2d_fill_rect(cx, ty + DIV_H//2, PANEL_W-PAD*2, 1, 0xFF2A2A2A)
            ty = ty + DIV_H
        else
            d2d_text(vf, r.label,     cx,      ty, grey)
            d2d_text(vf, r.value,     cx + VX, ty, r.vcol)
            ty = ty + LH
        end
    end
    R.dev_overlay_bottom = y + total_h + 8
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Right-side Overlays — shared helpers
-- ═══════════════════════════════════════════════════════════════════════════
local function right_panel_x()
    local sw = 1920
    if d2d then pcall(function() sw = select(1, d2d.surface_size()) end) end
    return sw - OVERLAY_PANEL_W - 20
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Spawn Overlay (top-right)
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_spawn_overlay()
    if not C.show_spawn_overlay then return end
    local entries = R.spawners
    if not entries or #entries == 0 then return end

    local visible  = math.min(#entries, 16)
    local PAD      = 14
    local LH       = 20
    local DIST_W   = 44
    local lime     = 0xFF44FF88
    local grey     = 0xFF888888
    local hf       = get_overlay_font(true)
    local vf       = get_overlay_font(false)

    local header_h = LH * 3 + 10
    local height   = header_h + (visible * LH) + 8
    local x        = right_panel_x()
    local y        = 80

    d2d_fill_rect(x, y, OVERLAY_PANEL_W, height, 0xCC000000)
    d2d_fill_rect(x, y, 4, height, lime)

    local cy = y + 6
    local cx = x + PAD
    d2d_text(hf, "Enemy Spawners", cx, cy, lime)
    cy = cy + LH
    d2d_text(vf, string.format("total: %d  (showing: %d)", #entries, visible), cx, cy, grey)
    cy = cy + LH

    d2d_text(vf, "Dist",  cx,          cy, grey)
    d2d_text(vf, "Name",  cx+DIST_W,   cy, grey)
    cy = cy + LH + 2

    for i = 1, visible do
        local e = entries[i]
        d2d_text(vf, string.format("%dm", math.floor(e.dist+0.5)), cx,        cy, grey)
        d2d_text(vf, clamp_text(e.go_name, 48),                    cx+DIST_W, cy, C.col_spawn_name)
        cy = cy + LH
    end
    return height + 10
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Chapter Flow Overlay (right side, below spawn overlay)
-- ═══════════════════════════════════════════════════════════════════════════
local function draw_chapter_overlay(offset_y)
    if not C.show_chapter_overlay then return end

    local PAD     = 14
    local LH      = 20
    local DIV_H   = 7
    local LABEL_W = 86
    local lime    = 0xFF44FF88
    local cyan    = 0xFF88DDFF
    local yellow  = 0xFFFFCC44
    local grey    = 0xFF888888
    local white   = 0xFFFFFFFF
    local hf      = get_overlay_font(true)
    local vf      = get_overlay_font(false)

    local rows = {}
    local function kv(label, value, vcol)
        rows[#rows+1] = { t="kv", label=label, value=tostring(value or ""), vcol=vcol or white }
    end
    local function div() rows[#rows+1] = { t="div" } end

    -- Chapter / location
    kv("Chapter",  R.chapter ~= "" and R.chapter or "?", yellow)
    kv("Room",     R.room_id > 0 and ("#"..R.room_id) or "?", grey)
    kv("Diff",     DIFFICULTY_NAMES[R.difficulty] or tostring(R.difficulty), cyan)
    div()

    -- Game flow state
    if R.prev_flow_name ~= "" then
        kv("Prev Flow", R.prev_flow_name, 0xFF7788AA)
    end
    if R.flow_name ~= "" then
        kv("Flow", R.flow_name, 0xFFAADDFF)
    end
    local battle_col = R.flow_battle_ended and lime or 0xFFFF6666
    local event_col  = R.flow_event_ended  and lime or 0xFFFFAA44
    kv("Battle", R.flow_battle_ended and "Ended" or "Active", battle_col)
    kv("Event",  R.flow_event_ended  and "Ended" or "Active", event_col)
    if R.loading_progress < 100 then
        kv("Loading", string.format("%d%%", R.loading_progress), 0xFFFFDD44)
    end
    div()

    -- Rank / time
    local rank = R.rank or 0
    local rc   = rank >= 7 and lime or (rank >= 4 and yellow or white)
    kv("Rank",    string.format("%d/9  (%d pts)", rank, math.floor(R.da_score or 0)), rc)
    local secs = R._chapter_time or 0
    kv("Ch.Time", string.format("%d:%02d", math.floor(secs/60), math.floor(secs%60)), grey)
    div()

    -- Live scene summary
    local alive, dead_e = 0, 0
    for _, e in ipairs(R.enemies) do
        if e.dead then dead_e = dead_e + 1 else alive = alive + 1 end
    end
    local ecol = alive > 0 and 0xFFFF6666 or lime
    kv("Enemies",  string.format("%d alive  %d dead", alive, dead_e), ecol)
    kv("Items",    string.format("%d in scene", #R.items), 0xFF55FF99)
    kv("Triggers", string.format("%d triggers", #R.spawners), 0xFFFFAA44)

    -- Trim trailing div
    while #rows > 0 and rows[#rows].t == "div" do rows[#rows] = nil end
    if #rows == 0 then return nil end

    local total_h = 6 + LH
    for _, r in ipairs(rows) do
        total_h = total_h + (r.t == "div" and DIV_H or LH)
    end
    total_h = total_h + PAD

    local x = right_panel_x()
    local y = 80 + (offset_y or 0)

    d2d_fill_rect(x, y, OVERLAY_PANEL_W, total_h, 0xCC000000)
    d2d_fill_rect(x, y, 4, total_h, cyan)

    local cx = x + PAD
    local ty = y + 6
    d2d_text(hf, "Chapter Flow", cx, ty, cyan)
    ty = ty + LH

    for _, r in ipairs(rows) do
        if r.t == "div" then
            d2d_fill_rect(cx, ty + DIV_H//2, OVERLAY_PANEL_W - PAD*2, 1, 0xFF2A2A2A)
            ty = ty + DIV_H
        else
            d2d_text(vf, r.label, cx,             ty, grey)
            d2d_text(vf, r.value, cx + LABEL_W,   ty, r.vcol)
            ty = ty + LH
        end
    end
    return total_h + 10
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ESP Rendering (RE3R style — bg box, selection border, colored dot)
-- ═══════════════════════════════════════════════════════════════════════════
local function render_esp_enemies()
    if not C.enemy_esp then return end
    if not _has_w2s then return end
    local font_big = get_esp_font(C.font_size, true)
    local font_sm  = get_esp_font(math.max(11, C.font_size-4), false)
    local lh = C.font_size + 3
    local sel_id = R.sel_type == "enemy" and R.sel_data and (R.sel_data.guid or R.sel_data.go_guid)

    for _, e in ipairs(R.enemies) do
        if e.dist > C.enemy_esp_range then break end
        if C.hide_dead and e.dead then goto next_e end
        if not e.pos then goto next_e end
        local sp = world_to_screen(e.pos, 1.8)
        if sp then
            local is_sel = sel_id and (e.guid == sel_id or e.go_guid == sel_id)
            local name_col = is_sel and 0xFFFFFF44 or C.col_enemy_name
            local r = e.mhp > 0 and (e.hp / e.mhp) or 0
            local hp_col = r > 0.5 and 0xFF44FF88 or (r > 0.25 and 0xFFFFAA44 or 0xFFFF5555)
            -- State color: red for ATTACK, yellow for HIT, cyan otherwise
            local st = e.state or ""
            local st_col = 0xFF88FFCC
            if st:find("ATTACK") then st_col = 0xFFFF5555
            elseif st:find("HIT")    then st_col = 0xFFFFDD44 end
            local lines = {
                { text=e.name,                                    col=name_col },
                { text=(st ~= "") and st or nil,                  col=st_col   },
                { text=string.format("HP %.0f/%.0f", e.hp, e.mhp), col=hp_col },
                { text=string.format("%.1fm", e.dist),            col=0xFFAAAAAA },
            }
            -- strip nil/empty lines
            local clean = {}
            for _, ln in ipairs(lines) do if ln.text and ln.text ~= "" then clean[#clean+1] = ln end end
            lines = clean

            local total_h = #lines * lh
            local max_w = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * C.font_size * 0.52
                if w > max_w then max_w = w end
            end
            local draw_y = sp.y - total_h
            local bx = sp.x - max_w*0.5 - 4; local by = draw_y - 2
            d2d_fill_rect(bx, by, max_w+8, total_h+4, 0xAA000000)
            if is_sel then
                local bw = max_w+8; local bh = total_h+4
                d2d_fill_rect(bx,      by,      bw, 2,  0xFFFFFF44)
                d2d_fill_rect(bx,      by+bh-2, bw, 2,  0xFFFFFF44)
                d2d_fill_rect(bx,      by,      2,  bh, 0xFFFFFF44)
                d2d_fill_rect(bx+bw-2, by,      2,  bh, 0xFFFFFF44)
            end
            for i, ln in ipairs(lines) do
                local f  = (i==1) and font_big or (font_sm or font_big)
                local tw = #ln.text * C.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw*0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x-2, sp.y-2, 4, 4, 0xFFFF5555)
        end
        ::next_e::
    end
end

local function render_esp_items()
    if not C.item_esp then return end
    if not _has_w2s then return end
    local font_big = get_esp_font(C.font_size, true)
    local font_sm  = get_esp_font(math.max(11, C.font_size-4), false)
    local lh = C.font_size + 3
    for _, it in ipairs(R.items) do
        if it.dist > C.item_esp_range then break end
        if not it.pos then goto next_i end
        local sp = world_to_screen(it.pos, 0.5)
        if sp then
            local lines = {
                { text=it.go_name or "?",               col=C.col_item_name },
                { text=string.format("%.1fm", it.dist),  col=0xFFAAAAAA     },
            }
            local total_h = #lines * lh
            local max_w = 0
            for _, ln in ipairs(lines) do
                local w = #ln.text * C.font_size * 0.52
                if w > max_w then max_w = w end
            end
            local draw_y = sp.y - total_h
            local bx = sp.x - max_w*0.5 - 4
            d2d_fill_rect(bx, draw_y - 2, max_w + 8, total_h + 4, 0xAA000000)
            for i, ln in ipairs(lines) do
                local f  = (i==1) and font_big or (font_sm or font_big)
                local tw = #ln.text * C.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw*0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x-2, sp.y-2, 4, 4, 0xFF55FF99)
        end
        ::next_i::
    end
end

local function render_esp_spawners()
    if not C.spawn_esp then return end
    if not _has_w2s then return end
    local font_big = get_esp_font(C.font_size, true)
    local font_sm  = get_esp_font(math.max(11, C.font_size-4), false)
    local lh = C.font_size + 3
    for _, s in ipairs(R.spawners) do
        if s.dist > C.enemy_esp_range then break end
        if not s.pos then goto next_s end
        local sp = world_to_screen(s.pos, 0.5)
        if sp then
            local lines = {
                { text=s.go_name or "?", col=C.col_spawn_name },
                { text=string.format("%.1fm", s.dist),   col=0xFFAAAAAA },
            }
            local draw_y = sp.y - #lines * lh
            for i, ln in ipairs(lines) do
                local f  = (i==1) and font_big or (font_sm or font_big)
                local tw = #ln.text * C.font_size * 0.52
                d2d_text(f, ln.text, sp.x - tw*0.5, draw_y, ln.col)
                draw_y = draw_y + lh
            end
            d2d_fill_rect(sp.x-2, sp.y-2, 4, 4, 0xFFFFAA44)
        end
        ::next_s::
    end
end

local function render_esp_objects()
    if not C.show_object_esp then return end
    if not _has_w2s then return end
    local font = get_esp_font(math.max(11, C.font_size - 2), false)
    local lh   = (C.font_size - 2) + 3
    for _, obj in ipairs(R.objects) do
        if obj.dist > C.object_esp_range then break end
        if not obj.pos then goto next_obj end
        local sp = world_to_screen(obj.pos, 0.5)
        if sp then
            local tag  = obj.tags and #obj.tags > 0 and obj.tags[1] or ""
            local name = obj.go_name or "?"
            local tag_col = 0xFF88FFCC
            if tag == "Enemy"  then tag_col = 0xFFFF6666
            elseif tag == "Item"   then tag_col = 0xFF55FF99
            elseif tag == "Weapon" then tag_col = 0xFFFFAA44
            end
            d2d_text(font, name, sp.x+1, sp.y+1, 0xCC000000)
            d2d_text(font, name, sp.x,   sp.y,   0xFFCCCCCC)
            if tag ~= "" then
                local tw = #("[" .. tag .. "]") * (C.font_size-2) * 0.52
                d2d_text(font, "["..tag.."]", sp.x+1, sp.y+lh+1, 0xCC000000)
                d2d_text(font, "["..tag.."]", sp.x,   sp.y+lh,   tag_col)
            end
            d2d_fill_rect(sp.x-2, sp.y-2, 4, 4, 0xFF88FFCC)
        end
        ::next_obj::
    end
end

local function render_selected_go_highlight()
    if R.sel_type ~= "go" then return end
    local data = R.sel_data
    if not data then return end
    local pos = nil
    local go = data._go_ref
    if go then
        pcall(function()
            local xf = go:call("get_Transform")
            if xf then local p = xf:call("get_Position"); if p then pos = p end end
        end)
    end
    if not pos and data.pos then pos = Vector3f.new(data.pos.x, data.pos.y, data.pos.z) end
    if not pos then return end
    pcall(draw.capsule, Vector3f.new(pos.x, pos.y+0.9, pos.z), 0.35, 1.8, 0xFFFFFF44)
    pcall(draw.world_text, data.go_name or "?", Vector3f.new(pos.x, pos.y+2.4, pos.z), 0xFFFFFF44)
    pcall(draw.sphere, pos, 0.06, 0xFFFF4444)
end

-- ── Enemy Panel (D2D — matches dev/chapter overlay style) ──
local function hp_gradient_argb(ratio)
    local r_val, g_val
    if ratio > 0.5 then
        r_val = math.floor((1.0 - ratio) * 2 * 255)
        g_val = 255
    else
        r_val = 255
        g_val = math.floor(ratio * 2 * 255)
    end
    return 0xFF000000 | (r_val * 0x10000) | (g_val * 0x100)
end

local function draw_enemy_panel()
    if not C.enemy_panel then return end
    if not d2d then return end

    local LH      = 20
    local PAD     = 14
    local DIV_H   = 7
    local BAR_H   = 6
    local BAR_GAP = 3
    local PANEL_W = 420
    local VX      = 92
    local STATE_H = LH - 2
    local lime    = 0xFF44FF88
    local cyan    = 0xFF88DDFF
    local yellow  = 0xFFFFCC44
    local grey    = 0xFF888888
    local white   = 0xFFFFFFFF
    local red     = 0xFFFF6666
    local orange  = 0xFFFFAA44
    local hf      = get_overlay_font(true)
    local vf      = get_overlay_font(false)

    local nearby = {}
    for _, e in ipairs(R.enemies) do
        if C.hide_dead and e.dead then
        elseif e.dist <= C.enemy_esp_range then
            nearby[#nearby + 1] = e
        end
    end
    local rows = math.min(#nearby, C.panel_rows)

    local entry_heights = {}
    for i = 1, rows do
        local e = nearby[i]
        local has_state = (e.state and e.state ~= "") or ((not e.dead) and e.hp <= 0)
        entry_heights[i] = LH + BAR_H + BAR_GAP + (has_state and STATE_H or 0) + 3
    end
    local total_entries_h = 0
    for _, h in ipairs(entry_heights) do total_entries_h = total_entries_h + h end

    local TITLE_H  = LH + 4
    local header_h = TITLE_H
                   + LH + BAR_H + BAR_GAP
                   + DIV_H
                   + LH
                   + LH
                   + DIV_H
                   + LH
                   + (rows > 0 and DIV_H or 0)
    local total_h = 6 + header_h + total_entries_h + PAD

    local x = 30
    local y = (C.show_dev_overlay and R.dev_overlay_bottom and R.dev_overlay_bottom > 80)
              and R.dev_overlay_bottom or 80

    local bar_w = PANEL_W - PAD * 2 - 4

    d2d_fill_rect(x, y, PANEL_W, total_h, 0xCC000000)
    d2d_fill_rect(x, y, 4, total_h, lime)

    local cx = x + PAD
    local ty = y + 6

    d2d_text(hf, "ENEMY PANEL", cx, ty, lime)
    ty = ty + TITLE_H

    local player_ratio = R.player_max_hp > 0
                         and math.max(0, math.min(1, R.player_hp / R.player_max_hp)) or 0
    local php_col = player_ratio > 0.5 and lime or (player_ratio > 0.25 and orange or red)
    local hp_str  = R.player_max_hp > 0
        and string.format("%d / %d", math.max(0, math.ceil(R.player_hp)), math.max(1, math.ceil(R.player_max_hp)))
        or "---"
    d2d_text(vf, "Ethan", cx,      ty, grey)
    d2d_text(vf, hp_str,  cx + VX, ty, php_col)
    ty = ty + LH
    d2d_fill_rect(cx, ty, bar_w, BAR_H, 0xFF111122)
    if R.player_max_hp > 0 then
        d2d_fill_rect(cx, ty, math.max(1, math.floor(bar_w * player_ratio)), BAR_H, hp_gradient_argb(player_ratio))
    end
    ty = ty + BAR_H + BAR_GAP

    d2d_fill_rect(cx, ty + DIV_H//2, PANEL_W - PAD*2, 1, 0xFF2A2A2A); ty = ty + DIV_H

    local rank     = R.rank or 0
    local rank_col = rank >= 7 and lime or (rank >= 4 and yellow or white)
    d2d_text(vf, "Rank",    cx,      ty, grey)
    d2d_text(vf, string.format("%d / 9  (%d pts)", rank, math.floor(R.da_score or 0)), cx + VX, ty, rank_col)
    ty = ty + LH

    local chap_str = (R.chapter and R.chapter ~= "") and R.chapter or "?"
    d2d_text(vf, "Chapter", cx,      ty, grey)
    d2d_text(vf, chap_str,  cx + VX, ty, cyan)
    ty = ty + LH

    d2d_fill_rect(cx, ty + DIV_H//2, PANEL_W - PAD*2, 1, 0xFF2A2A2A); ty = ty + DIV_H

    local alive = 0
    for _, e in ipairs(nearby) do
        if not e.dead then alive = alive + 1 end
    end
    local count_col = alive > 0 and red or lime
    d2d_text(vf, string.format("%d alive  /  %d total", alive, #nearby), cx, ty, count_col)
    ty = ty + LH

    if rows > 0 then
        d2d_fill_rect(cx, ty + DIV_H//2, PANEL_W - PAD*2, 1, 0xFF2A2A2A); ty = ty + DIV_H
    end

    for i = 1, rows do
        local e       = nearby[i]
        local hp_cur  = math.max(0, math.ceil(e.hp or 0))
        local hp_max  = math.max(1, math.ceil(e.mhp or 1))
        local ratio   = hp_max > 0 and math.max(0, math.min(1, hp_cur / hp_max)) or 0
        local is_dead   = e.dead                          -- game's own flag
        local zero_live = (not e.dead) and e.hp <= 0     -- 0 HP but not flagged dead

        if i % 2 == 0 then
            d2d_fill_rect(x + 4, ty - 1, PANEL_W - 4, entry_heights[i] + 1, 0x0CFFFFFF)
        end

        -- Name color: grey=dead, magenta=0hp-but-alive anomaly, dist tint otherwise
        local name_col = is_dead and grey or white
        if zero_live then
            name_col = 0xFFFF88FF   -- magenta: 0 HP yet not dead
        elseif C.dist_color and not is_dead then
            if e.dist < 5 then name_col = 0xFF8888FF
            elseif e.dist < 15 then name_col = cyan end
        end

        local display_name = e.name
        if #display_name > 14 then display_name = display_name:sub(1, 13) .. "…" end

        local hp_col = is_dead and grey
                     or (ratio < 0.25 and red or (ratio < 0.5 and orange or lime))
        if zero_live then hp_col = 0xFFFF88FF end
        local pct_str  = hp_max > 0 and string.format("%d%%", math.floor(ratio * 100)) or "--"
        local dist_str = string.format("%.0fm", e.dist)

        d2d_text(vf, display_name,                                        cx,       ty, name_col)
        d2d_text(vf, string.format("%d/%d  %s", hp_cur, hp_max, pct_str), cx + 155, ty, hp_col)
        d2d_text(vf, dist_str,                                             cx + 320, ty, grey)
        ty = ty + LH

        d2d_fill_rect(cx, ty, bar_w, BAR_H, 0xFF111122)
        if not is_dead and hp_max > 0 then
            d2d_fill_rect(cx, ty, math.max(1, math.floor(bar_w * ratio)), BAR_H,
                zero_live and 0xFFFF88FF or hp_gradient_argb(ratio))
        end
        ty = ty + BAR_H + BAR_GAP

        local st = e.state or ""
        if zero_live and st == "" then st = "0HP?" end  -- flag it even without a state
        if st ~= "" then
            local st_col = zero_live and 0xFFFF88FF or 0xFF88FFCC
            d2d_text(vf, st, cx + 4, ty, st_col)
            ty = ty + STATE_H
        end
        ty = ty + 3
    end
end

-- ── D2D Registration ──
if d2d then
    d2d.register(
        function() reset_overlay_fonts(); reset_esp_fonts() end,
        function()
            -- Right-side panels stack downward
            local spawn_h = 0
            pcall(function() spawn_h = draw_spawn_overlay() or 0 end)
            local ch_h = 0
            pcall(function() ch_h = draw_chapter_overlay(spawn_h) or 0 end)
            -- Left-side overlays (dev first so enemy panel can read dev_overlay_bottom)
            pcall(draw_dev_overlay)
            pcall(draw_enemy_panel)
            -- World-space ESP
            pcall(render_esp_enemies)
            pcall(render_esp_items)
            pcall(render_esp_spawners)
            pcall(render_esp_objects)
            pcall(render_selected_go_highlight)
        end)
end

-- ── B-Key Export (RE3R style — append enemies to extra_enemies.csv) ──
local _b_was_down = false
local CSV_PATH = "reframework/data/extra_enemies.csv"

local function export_enemies_csv()
    local exists = io.open(CSV_PATH, "r")
    if exists then exists:close() end
    local f = io.open(CSV_PATH, "a")
    if not f then toast("CSV write failed: " .. CSV_PATH, 4); return end
    if not exists then f:write("GUID,Name,HP,MaxHP,X,Y,Z\n") end
    local written = 0
    for _, e in ipairs(R.enemies) do
        if e.dist <= C.enemy_esp_range then
            local guid = e.guid or "00000000-0000-0000-0000-000000000000"
            local px = e.pos and string.format("%.3f", e.pos.x) or "0"
            local py = e.pos and string.format("%.3f", e.pos.y) or "0"
            local pz = e.pos and string.format("%.3f", e.pos.z) or "0"
            f:write(string.format("%s,%s,%.0f,%.0f,%s,%s,%s\n",
                guid, e.go_name or "unknown", e.hp or 0, e.mhp or 0, px, py, pz))
            written = written + 1
        end
    end
    f:close()
    toast(string.format("[B] Exported %d enemies", written), 4)
    if log then log.info("[RE7] Exported " .. written .. " enemies to " .. CSV_PATH) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Draw API Overlays (ABGR — HUD strip)
-- ═══════════════════════════════════════════════════════════════════════════

local has_draw_api = (draw ~= nil)

local function argb(col)
    local a = (col >> 24) & 0xFF
    local r = (col >> 16) & 0xFF
    local g = (col >>  8) & 0xFF
    local b = col & 0xFF
    return (a << 24) | (b << 16) | (g << 8) | r
end

local DC = {
    HUD_BG      = argb(0xBB1A1A2E),
    HUD_LINE    = argb(0x44444466),
    HUD_TEXT    = argb(0xDD88CCFF),
    SHADOW      = argb(0xCC000000),
    TEXT_YELLOW = argb(0xFFFFCC44),
    TEXT_GRAY   = argb(0xFFAAAAAA),
}

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
-- ImGui Helpers (RE3R style)
-- ═══════════════════════════════════════════════════════════════════════════

-- REFramework imgui uses ABGR; our colors are ARGB. Convert before imgui calls.
local function to_imgui(c)
    return (c & 0xFF000000) | ((c & 0x000000FF) << 16) | (c & 0x0000FF00) | ((c >> 16) & 0xFF)
end

local function colored_header(text, col)
    imgui.push_style_color(0, to_imgui(col or 0xFFFFDD88))
    imgui.separator()
    imgui.text(text)
    imgui.pop_style_color(1)
    imgui.spacing()
end

local COLOR_PRESETS = {
    { "White",  0xFFFFFFFF }, { "Red",    0xFFFF5555 }, { "Green",  0xFF55FF99 },
    { "Yellow", 0xFFFFDD55 }, { "Cyan",   0xFF44EEFF }, { "Orange", 0xFFFFAA44 },
    { "Purple", 0xFFCC88FF }, { "Blue",   0xFF88AAFF },
}

local function color_picker_row(label, config_key)
    imgui.text_colored(label, to_imgui(0xFFAAAAAA))
    for _, p in ipairs(COLOR_PRESETS) do
        imgui.same_line()
        local sel = (C[config_key] == p[2])
        imgui.push_style_color(0,  to_imgui(p[2]))
        imgui.push_style_color(21, sel and 0xFF2A3A2A or 0xFF1A1A2E)
        imgui.push_style_color(22, sel and 0xFF4A5A4A or 0xFF2A2A3E)
        if imgui.small_button(p[1] .. "##cp_" .. config_key) then C[config_key] = p[2] end
        imgui.pop_style_color(3)
    end
end

-- section / tog / hp_bar (used by Player tab, color-safe via ABGR)
local function section(text, col)
    imgui.spacing(); imgui.spacing()
    imgui.push_style_color(27, to_imgui(col or 0xFFFFDD88))
    imgui.separator(); imgui.pop_style_color(1)
    imgui.text_colored("  " .. text, to_imgui(col or 0xFFFFDD88))
    imgui.spacing()
end

local function tog(label, key, tip)
    local v = C[key]
    local on_col  = to_imgui(0xFF44FF88)
    local off_col = to_imgui(0xFFEEEEFF)
    imgui.push_style_color(0, v and on_col or off_col)
    local ch, nv = imgui.checkbox(label, v)
    imgui.pop_style_color(1)
    if tip then pcall(function() if imgui.is_item_hovered() then imgui.set_tooltip(tip) end end) end
    if ch then C[key] = nv; pcall(cfg_save); toast(nv and (label.." ON") or (label.." off")) end
end

local function hp_bar(cur, mx, w)
    if not cur or not mx or mx <= 0 then
        imgui.text_colored("HP: ---", to_imgui(0xFF999999)); return
    end
    local r = math.max(0, math.min(1, cur/mx))
    imgui.progress_bar(r, w or 200, 16, ("%d / %d"):format(math.ceil(cur), math.ceil(mx)))
end

-- Inspector field helpers
local function vi_copyable(label, value, uid)
    imgui.text_colored(label, to_imgui(0xFF888888)); imgui.same_line()
    imgui.text(tostring(value or "")); imgui.same_line()
    if imgui.small_button("C##vic_"..tostring(uid)) then
        imgui.set_clipboard_text(tostring(value or ""))
    end
end

local function vi_field(label, value, col)
    imgui.text_colored(label, to_imgui(0xFF888888)); imgui.same_line()
    imgui.text_colored(tostring(value or ""), to_imgui(col or 0xFFE0E0E0))
end

local function vi_bool(label, val, col_true, col_false)
    imgui.text_colored(label, to_imgui(0xFF888888)); imgui.same_line()
    if val then imgui.text_colored("YES", to_imgui(col_true  or 0xFF44FF88))
    else        imgui.text_colored("NO",  to_imgui(col_false or 0xFFFF5555)) end
end

local function vi_section(title) colored_header(title, 0xFF44CCFF) end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Player Tab
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- Inspector Views + Selection (RE3R style)
-- ═══════════════════════════════════════════════════════════════════════════

local select_obj  -- forward declaration

local function view_enemy(e)
    local ac = e.dead and to_imgui(0xFFFF5555) or to_imgui(0xFF44FF88)
    imgui.text_colored(e.go_name or e.name or "?", to_imgui(0xFFFFFFFF)); imgui.same_line()
    imgui.text_colored(e.dead and "[DEAD]" or "[ALIVE]", ac)
    vi_section("IDENTITY")
    vi_copyable("GUID:", e.guid or "-", "e_guid")
    vi_section("COMBAT")
    local r = (e.mhp or 1) > 0 and (e.hp or 0)/(e.mhp or 1) or 0
    local hc = r > 0.5 and 0xFF44FF88 or (r > 0.25 and 0xFFFFAA44 or 0xFFFF5555)
    vi_field("HP:", string.format("%.0f / %.0f", e.hp or 0, e.mhp or 0), hc)
    imgui.push_style_color(8, to_imgui(hc)); imgui.push_style_color(9, to_imgui(0xFF333333))
    imgui.progress_bar(math.max(0,math.min(1,r)), Vector2f.new(-1,8), "")
    imgui.pop_style_color(2)
    vi_bool("Dead:", e.dead, 0xFFFF5555, 0xFF44FF88)
    vi_section("POSITION")
    if e.pos then
        vi_field("X:", string.format("%.3f", e.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", e.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", e.pos.z), 0xFFE0E0E0)
    end
    vi_field("Dist:", string.format("%.1f m", e.dist or 0), 0xFFAAAAAA)
end

local function view_item(it)
    imgui.text_colored(it.go_name or "?", to_imgui(0xFF44EEFF))
    vi_section("IDENTITY")
    vi_copyable("GUID:", it.guid or "-", "it_guid")
    vi_section("POSITION")
    if it.pos then
        vi_field("X:", string.format("%.3f", it.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", it.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", it.pos.z), 0xFFE0E0E0)
    end
    vi_field("Dist:", string.format("%.1f m", it.dist or 0), 0xFFAAAAAA)
end

local function view_spawner(s)
    imgui.text_colored(s.go_name or "?", to_imgui(0xFFFFAA44))
    vi_section("IDENTITY")
    vi_copyable("GUID:", s.guid or "-", "sp_guid")
    vi_section("POSITION")
    if s.pos then
        vi_field("X:", string.format("%.3f", s.pos.x), 0xFFE0E0E0)
        vi_field("Y:", string.format("%.3f", s.pos.y), 0xFFE0E0E0)
        vi_field("Z:", string.format("%.3f", s.pos.z), 0xFFE0E0E0)
    end
    vi_field("Dist:", string.format("%.1f m", s.dist or 0), 0xFFAAAAAA)
end

-- Generic GO inspector (component fields viewer)
local _go_inspector_filter = ""
local _via_comp_rt = nil
local function get_via_comp_rt()
    if not _via_comp_rt then
        local td = sdk.find_type_definition("via.Component")
        _via_comp_rt = td and td:get_runtime_type()
    end
    return _via_comp_rt
end

local function view_generic_go(data)
    local go = data._go_ref
    imgui.text_colored(data.go_name or "?", to_imgui(data.active and 0xFFFFFFFF or 0xFF888888))
    imgui.same_line()
    imgui.text_colored(data.active and "[ACTIVE]" or "[INACTIVE]",
        to_imgui(data.active and 0xFF44FF88 or 0xFF555555))
    vi_copyable("GUID:", data.go_guid or "-", "vgo_guid")
    if data.tags and #data.tags > 0 then
        vi_field("Tags:", table.concat(data.tags, "  "), 0xFF88FFCC)
    end
    if data.pos then
        vi_field("Pos:", string.format("%.2f, %.2f, %.2f  (%.1f m)",
            data.pos.x, data.pos.y, data.pos.z, data.dist or 0), 0xFFAAAAAA)
    end
    imgui.spacing()
    if not go then
        imgui.text_colored("  (live GO reference lost — rescan objects)", to_imgui(0xFF888888)); return
    end
    -- Field filter
    local fc; fc, _go_inspector_filter = imgui.input_text("Filter##gofltr", _go_inspector_filter, 128)
    local filter_lo = _go_inspector_filter:lower()
    imgui.spacing()
    -- Component list (scrollable)
    if imgui.begin_child("go_comps##vgo", Vector2f.new(-1, 0), true) then
        local comps = {}
        pcall(function()
            local rt = get_via_comp_rt()
            if not rt then return end
            local list = go:call("getComponents(System.Type)", rt)
            if not list then return end
            local n = 0; pcall(function() n = list:call("get_Count") end)
            for i = 0, n-1 do
                local c = nil; pcall(function() c = list:call("get_Item", i) end)
                if c then comps[#comps+1] = c end
            end
        end)
        for ci, comp in ipairs(comps) do
            local ctype_short = "unknown"
            pcall(function()
                local td = comp:get_type_definition()
                if td then ctype_short = td:get_name() or "unknown" end
            end)
            imgui.push_style_color(0, to_imgui(0xFF44CCFF))
            if ci == 1 then imgui.set_next_item_open(true, 2) end
            local open = imgui.tree_node(string.format("[%d]  %s##cn%d", ci, ctype_short, ci))
            imgui.pop_style_color(1)
            if open then
                pcall(function()
                    local td = comp:get_type_definition()
                    if not td then imgui.tree_pop(); return end
                    local fields = td:get_fields(); if not fields then imgui.tree_pop(); return end
                    local n = 0
                    pcall(function() n = #fields end)
                    if n == 0 then pcall(function() n = fields.Length or 300 end) end
                    for fi_i = 0, n-1 do
                        local fi = fields[fi_i]; if fi == nil then break end
                        local fname = "?"; pcall(function() fname = tostring(fi:get_name()) end)
                        if filter_lo ~= "" and not fname:lower():find(filter_lo, 1, true) then goto nf end
                        local fval_str, fval_col = "?", 0xFFE0E0E0
                        pcall(function()
                            local v = fi:get_data(comp)
                            if v == nil then fval_str="nil"; fval_col=0xFF555555
                            elseif type(v)=="boolean" then
                                fval_str = v and "true" or "false"
                                fval_col = v and 0xFF44FF88 or 0xFFFF5555
                            elseif type(v)=="number" then
                                fval_str = v~=math.floor(v) and string.format("%.5g",v) or tostring(math.floor(v))
                                fval_col = 0xFFFFCC88
                            else fval_str = tostring(v) end
                        end)
                        imgui.text_colored("  "..fname, to_imgui(0xFFCCCCCC)); imgui.same_line()
                        imgui.text_colored(fval_str, to_imgui(fval_col))
                        ::nf::
                    end
                end)
                imgui.tree_pop(); imgui.spacing()
            end
        end
        imgui.end_child()
    end
end

select_obj = function(obj_type, data)
    R.sel_type = obj_type
    R.sel_data = {}
    for k, v in pairs(data) do R.sel_data[k] = v end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Enemies (RE3R style table)
-- ═══════════════════════════════════════════════════════════════════════════
local function ui_enemies()
    local ch
    ch, C.enemy_esp          = imgui.checkbox("Show Enemy ESP", C.enemy_esp)
    ch, C.enemy_esp_range    = imgui.drag_float("Range##er", C.enemy_esp_range, 0.5, 5, 200, "%.1f m")
    ch, C.hide_dead          = imgui.checkbox("Hide Dead", C.hide_dead)
    color_picker_row("Name Color:", "col_enemy_name")

    colored_header(string.format("Enemies — %d total", #R.enemies), 0xFFFFDD88)

    if imgui.begin_table("enemy_tbl", 9, 513, Vector2f.new(0,0), 0) then
        imgui.table_setup_column(">",     16, 28,  0)
        imgui.table_setup_column("Dist",  16, 56,  0)
        imgui.table_setup_column("Name",  0,  1,   0)
        imgui.table_setup_column("GUID",  16, 260, 0)
        imgui.table_setup_column("HP",    16, 80,  0)
        imgui.table_setup_column("State", 16, 70,  0)
        imgui.table_setup_column("Dead",  16, 40,  0)
        imgui.table_setup_column("Dist3D",16, 60,  0)
        imgui.table_setup_column("Pos",   16, 180, 0)
        imgui.table_headers_row()

        for i, e in ipairs(R.enemies) do
            if C.hide_dead and e.dead then goto skip_en end
            imgui.table_next_row()
            local r    = (e.mhp or 0) > 0 and (e.hp or 0) / e.mhp or 0
            local rc   = to_imgui(e.dead and 0xFFFF5555 or 0xFF44FF88)
            local hpc  = to_imgui(r > 0.5 and 0xFF44FF88 or (r > 0.25 and 0xFFFFAA44 or 0xFFFF5555))

            imgui.table_next_column()
            if imgui.small_button(">##se_"..i) then select_obj("enemy", e) end

            imgui.table_next_column()
            imgui.text_colored(string.format("%.0fm", e.dist), rc)

            imgui.table_next_column()
            imgui.text_colored(e.name or e.go_name or "?", rc)

            imgui.table_next_column()
            local gs = e.guid or ""
            imgui.push_item_width(250)
            imgui.input_text("##eg_"..i, gs, 2048)
            imgui.pop_item_width(); imgui.same_line()
            if imgui.small_button("C##ec_"..i) then imgui.set_clipboard_text(gs) end

            imgui.table_next_column()
            if (e.mhp or 0) > 0 then
                imgui.push_style_color(8, hpc); imgui.push_style_color(9, to_imgui(0xFF333333))
                imgui.progress_bar(math.max(0,math.min(1,r)), Vector2f.new(74, 10), "")
                imgui.pop_style_color(2)
                imgui.same_line()
            end
            imgui.text_colored(e.hp and string.format("%.0f",e.hp) or "-", hpc)

            imgui.table_next_column()
            local state_col = (e.state and e.state ~= "") and to_imgui(0xFF88FFCC) or to_imgui(0xFF555555)
            imgui.text_colored(e.state or "-", state_col)

            imgui.table_next_column()
            imgui.text_colored(e.dead and "Y" or "N", rc)

            imgui.table_next_column()
            imgui.text_colored(string.format("%.1f", e.dist), to_imgui(0xFFAAAAAA))

            imgui.table_next_column()
            if e.pos then imgui.text(string.format("%.1f,%.1f,%.1f", e.pos.x,e.pos.y,e.pos.z)) end

            ::skip_en::
        end
        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Spawners
-- ═══════════════════════════════════════════════════════════════════════════
local function ui_spawners()
    local ch
    ch, C.spawn_esp         = imgui.checkbox("Show Spawn ESP", C.spawn_esp)
    ch, C.show_spawn_overlay = imgui.checkbox("Show Spawn Overlay (D2D)", C.show_spawn_overlay)
    color_picker_row("Name Color:", "col_spawn_name")

    colored_header(string.format("Spawners — %d total", #R.spawners), 0xFFFFDD88)

    if imgui.begin_table("spawn_tbl", 6, 513, Vector2f.new(0,0), 0) then
        imgui.table_setup_column(">",    16, 28,  0)
        imgui.table_setup_column("Dist", 16, 56,  0)
        imgui.table_setup_column("Em",   16, 55,  0)
        imgui.table_setup_column("Name", 0,  1,   0)
        imgui.table_setup_column("GUID", 16, 270, 0)
        imgui.table_setup_column("Pos",  16, 170, 0)
        imgui.table_headers_row()

        for i, s in ipairs(R.spawners) do
            imgui.table_next_row()
            imgui.table_next_column()
            if imgui.small_button(">##ss_"..i) then select_obj("spawner", s) end

            imgui.table_next_column()
            imgui.text(string.format("%.0fm", s.dist))

            imgui.table_next_column()
            imgui.text_colored(s.em_code or "?", to_imgui(0xFFAAAAAA))

            imgui.table_next_column()
            imgui.text_colored(s.go_name or "?", to_imgui(C.col_spawn_name))

            imgui.table_next_column()
            local gs = s.guid or ""
            imgui.push_item_width(260)
            imgui.input_text("##sg_"..i, gs, 2048)
            imgui.pop_item_width(); imgui.same_line()
            if imgui.small_button("C##sc_"..i) then imgui.set_clipboard_text(gs) end

            imgui.table_next_column()
            if s.pos then imgui.text(string.format("%.1f,%.1f,%.1f", s.pos.x,s.pos.y,s.pos.z)) end
        end
        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Items
-- ═══════════════════════════════════════════════════════════════════════════
local function ui_items()
    local ch
    ch, C.item_esp       = imgui.checkbox("Show Item ESP", C.item_esp)
    ch, C.item_esp_range = imgui.drag_float("Range##ir", C.item_esp_range, 0.5, 5, 200, "%.1f m")
    color_picker_row("Name Color:", "col_item_name")

    colored_header(string.format("Items — %d total", #R.items), 0xFFFFDD88)

    if imgui.begin_table("item_tbl", 6, 513, Vector2f.new(0,0), 0) then
        imgui.table_setup_column(">",    16, 28,  0)
        imgui.table_setup_column("Dist", 16, 56,  0)
        imgui.table_setup_column("Type", 16, 75,  0)
        imgui.table_setup_column("Name", 0,  1,   0)
        imgui.table_setup_column("GUID", 16, 260, 0)
        imgui.table_setup_column("Pos",  16, 180, 0)
        imgui.table_headers_row()

        for i, it in ipairs(R.items) do
            imgui.table_next_row()
            imgui.table_next_column()
            if imgui.small_button(">##si_"..i) then select_obj("item", it) end

            imgui.table_next_column()
            imgui.text(string.format("%.0fm", it.dist))

            imgui.table_next_column()
            -- Derive item type from name keywords
            local nm = it.go_name or ""
            local itype, itcol
            if nm:find("Key") or nm:find("Fuse") or nm:find("Lock") then
                itype="Key"; itcol=0xFFFFDD44
            elseif nm:find("Tape") or nm:find("Video") or nm:find("Diary")
                   or nm:find("Document") or nm:find("Photo") or nm:find("Picture") then
                itype="Note"; itcol=0xFF88DDFF
            elseif nm:find("Herb") or nm:find("Remedy") or nm:find("Serum")
                   or nm:find("Steroids") or nm:find("Antidote") then
                itype="Heal"; itcol=0xFF55FF99
            elseif nm:find("Coin") then
                itype="Coin"; itcol=0xFFFFAA44
            elseif nm:find("Map") then
                itype="Map"; itcol=0xFF44EEFF
            elseif nm:find("DetailSearch") then
                itype="Search"; itcol=0xFFCCCCCC
            else
                itype="Misc"; itcol=0xFF888888
            end
            imgui.text_colored(itype, to_imgui(itcol))

            imgui.table_next_column()
            imgui.text_colored(nm, to_imgui(C.col_item_name))

            imgui.table_next_column()
            local gs = it.guid or ""
            imgui.push_item_width(250)
            imgui.input_text("##ig_"..i, gs, 2048)
            imgui.pop_item_width(); imgui.same_line()
            if imgui.small_button("C##ic_"..i) then imgui.set_clipboard_text(gs) end

            imgui.table_next_column()
            if it.pos then imgui.text(string.format("%.1f,%.1f,%.1f", it.pos.x,it.pos.y,it.pos.z)) end
        end
        imgui.end_table()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Tab: Scene Objects (RE3R style — all GOs sorted by distance)
-- ═══════════════════════════════════════════════════════════════════════════
local _obj_filter = ""

local function ui_scene_objects()
    local ch
    ch, C.show_object_esp = imgui.checkbox("Show Objects ESP", C.show_object_esp)
    if C.show_object_esp then
        ch, C.object_esp_range = imgui.drag_float("Range##obr", C.object_esp_range, 0.5, 2, 100, "%.1f m")
    end
    imgui.spacing()
    imgui.text_colored(string.format("  %d GOs loaded (300 closest)", #R.objects), to_imgui(0xFF88DDFF))
    local fc; fc, _obj_filter = imgui.input_text("Filter##objf", _obj_filter, 128)
    imgui.spacing()
    local filter_lo = _obj_filter:lower()

    if imgui.begin_table("obj_tbl", 6, 513, Vector2f.new(0,0), 0) then
        imgui.table_setup_column(">",      16, 28,  0)
        imgui.table_setup_column("Tags",   16, 100, 0)
        imgui.table_setup_column("Name",   0,  1,   0)
        imgui.table_setup_column("GUID",   16, 270, 0)
        imgui.table_setup_column("Active", 16, 50,  0)
        imgui.table_setup_column("Dist",   16, 50,  0)
        imgui.table_headers_row()
        local shown = 0
        for i, obj in ipairs(R.objects) do
            if filter_lo == "" or obj.go_name:lower():find(filter_lo, 1, true) then
                imgui.table_next_row()
                imgui.table_next_column()
                if imgui.small_button(">##osel_"..i) then select_obj("go", obj) end
                imgui.table_next_column()
                local tag_str = #obj.tags > 0 and table.concat(obj.tags, " ") or ""
                imgui.text_colored(tag_str, to_imgui(#obj.tags > 0 and 0xFF88FFCC or 0xFF555555))
                imgui.table_next_column()
                imgui.text_colored(obj.go_name, to_imgui(obj.active and 0xFFFFFFFF or 0xFF888888))
                imgui.table_next_column()
                local gs = obj.go_guid or ""
                imgui.push_item_width(260)
                imgui.input_text("##oguid_"..i, gs, 2048)
                imgui.pop_item_width(); imgui.same_line()
                if imgui.small_button("C##oc_"..i) then imgui.set_clipboard_text(gs) end
                imgui.table_next_column()
                imgui.text_colored(obj.active and "Y" or "N",
                    to_imgui(obj.active and 0xFF44FF88 or 0xFF555555))
                imgui.table_next_column()
                imgui.text(string.format("%.0fm", obj.dist))
                shown = shown + 1; if shown >= 200 then break end
            end
        end
        imgui.end_table()
    end
end

-- Inspector tab content (floating window uses this too)
local function ui_object()
    if not R.sel_data then
        imgui.spacing(); imgui.text_colored("  No object selected.", to_imgui(0xFF888888)); imgui.spacing()
        imgui.text_colored("  Click  >  next to any row.", to_imgui(0xFF555555)); return
    end
    local tp  = R.sel_type or "?"
    local obj = R.sel_data
    local badges = { enemy="ENEMY", spawner="SPAWNER", item="ITEM", go="GAME OBJECT" }
    imgui.text_colored("[ "..(badges[tp] or tp).." ]", to_imgui(0xFF44EEFF)); imgui.same_line()
    if imgui.small_button("Close") then R.sel_type=nil; R.sel_data=nil; return end
    imgui.separator(); imgui.spacing()
    if     tp=="enemy"   then pcall(view_enemy,      obj)
    elseif tp=="spawner" then pcall(view_spawner,    obj)
    elseif tp=="item"    then pcall(view_item,       obj)
    elseif tp=="go"      then pcall(view_generic_go, obj) end
end

local function ui_player()
    -- ── Health ──
    section("Health")
    tog("God Mode", "godmode", "You'll no longer take damage with this")
    imgui.text("Health:")
    imgui.same_line()
    hp_bar(R.player_hp, R.player_max_hp, 200)

    -- ── Movement ──
    section("Movement")
    tog("Noclip", "noclip", "Move wherever you want (WASD + Space/Shift)")
    if C.noclip then
        imgui.same_line(); imgui.text_colored("ACTIVE", to_imgui(0xFF44FF88))
        local ch, v = imgui.slider_float("Speed##nc", C.noclip_speed, 0.1, 2.0, "%.2f")
        if ch then C.noclip_speed = v; cfg_save() end
    end

    imgui.spacing()
    imgui.text_colored("Movement Speed", to_imgui(0xFFEEEEFF))
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
    section("Combat")
    tog("Infinite Ammo", "inf_ammo", "Ammo count never decreases")
    tog("Enemy Insta Kill", "enemy_insta_kill", "Instantly kill enemies when damaging them")

    imgui.spacing()
    imgui.text_colored("Enemy Speed", to_imgui(0xFFEEEEFF))
    tog("Change Enemy Speed", "change_enemy_speed", "This won't work for all enemies and bosses!")
    if C.change_enemy_speed then
        local ch, v = imgui.slider_float("Speed##es", C.enemy_speed_mult, 0.1, 10.0, "%.2fx")
        if ch then C.enemy_speed_mult = v; pcall(cfg_save) end
        if imgui.button("Reset##es") then C.enemy_speed_mult = 1.0; pcall(cfg_save) end
    end

    -- ── Game Speed ──
    section("Game Speed")
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
    section("Scale")
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
    section("Items")
    if imgui.button("Unlock All Items (Item Box)") then addAllItemsToItemBox(); toast("Items added to box") end
    imgui.same_line()
    if imgui.button("Max Inventory") then setMaxInventory(); toast("Inventory maxed") end

    -- ── Stats ──
    section("Stats")
    pcall(function()
        local gm = sdk.get_managed_singleton("app.GameManager")
        if gm then imgui.text_colored("Rank: " .. tostring(gm:call("getGameRank")) .. " / 9", to_imgui(0xFFEEEEFF)) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Settings Tab
-- ═══════════════════════════════════════════════════════════════════════════

local function ui_settings()
    section("Overlays")
    tog("Dev Overlay (top-left)", "show_dev_overlay")
    tog("Enemy Panel (bottom-left)", "enemy_panel")
    tog("Spawn Panel (top-right)", "show_spawn_overlay")
    tog("Chapter Flow (top-right, below spawn)", "show_chapter_overlay")

    section("3D ESP")
    tog("Enemy ESP", "enemy_esp")
    tog("Item ESP", "item_esp")
    tog("Spawn ESP", "spawn_esp")
    tog("Object ESP", "show_object_esp")
    tog("Damage Numbers", "show_damage_numbers")

    section("Display Options")
    tog("Show HP Bars", "show_bars")
    tog("Show %", "show_pct")
    tog("Hide Dead", "hide_dead")
    tog("Distance Colors", "dist_color")

    section("Ranges")
    local ch, v
    ch, v = imgui.drag_float("Enemy ESP Range##er", C.enemy_esp_range, 1.0, 5, 300, "%.0fm")
    if ch then C.enemy_esp_range = v; cfg_save() end
    ch, v = imgui.drag_float("Item ESP Range##ir", C.item_esp_range, 1.0, 5, 300, "%.0fm")
    if ch then C.item_esp_range = v; cfg_save() end
    ch, v = imgui.drag_float("Object ESP Range##or", C.object_esp_range, 1.0, 5, 100, "%.0fm")
    if ch then C.object_esp_range = v; cfg_save() end

    section("Panel Settings")
    ch, v = imgui.drag_int("Panel Rows##pr", C.panel_rows, 1, 1, 20)
    if ch then C.panel_rows = v; cfg_save() end
    ch, v = imgui.drag_int("ESP Font Size##ef", C.esp_font, 1, 8, 48)
    if ch then C.esp_font = v; reset_esp_fonts(); cfg_save() end
    ch, v = imgui.drag_int("Panel Font Size##pf", C.panel_font, 1, 8, 32)
    if ch then C.panel_font = v; reset_overlay_fonts(); cfg_save() end
    ch, v = imgui.drag_int("Panel Width##pw", C.panel_w, 5, 200, 800)
    if ch then C.panel_w = v; cfg_save() end
    ch, v = imgui.drag_int("UI Font Size##uf", C.font_size, 1, 8, 32)
    if ch then C.font_size = v; reset_overlay_fonts(); cfg_save() end

    section("Scanner")
    ch, v = imgui.drag_int("Scan Interval (frames)##si", C.scan_interval, 1, 10, 300)
    if ch then C.scan_interval = v; cfg_save() end

    section("Colors")
    color_picker_row("Enemy Name", "col_enemy_name")
    color_picker_row("Item Name",  "col_item_name")
    color_picker_row("Spawn Name", "col_spawn_name")

    section("Export")
    imgui.text_colored("Press B in-game to export enemy list to CSV", to_imgui(0xFFAAAAAA))
    imgui.text_colored("Output: reframework/data/extra_enemies.csv", to_imgui(0xFF777777))

    imgui.spacing()
    if imgui.button("Save Config") then cfg_save(); toast("Config saved") end
    imgui.same_line()
    if imgui.button("Reload Config") then cfg_load(); toast("Config reloaded") end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UI — Main Window
-- ═══════════════════════════════════════════════════════════════════════════

local TAB_DEFS = {
    { name = "Enemies",  fn = ui_enemies },
    { name = "Spawners", fn = ui_spawners },
    { name = "Items",    fn = ui_items },
    { name = "Player",   fn = ui_player },
    { name = "Objects",  fn = ui_scene_objects },
    { name = "Settings", fn = ui_settings },
}

local trainer_visible = true

re.on_draw_ui(function()
    local changed
    changed, trainer_visible = imgui.checkbox(TITLE, trainer_visible)
    if not trainer_visible then return end

    if imgui.begin_window(TITLE .. "###trainer_main", true, 0) then
        -- ── Status Bar ──
        local active = 0
        for _, k in ipairs({"godmode","inf_ammo","enemy_insta_kill","noclip","game_speed_on","change_enemy_speed"}) do
            if C[k] then active = active + 1 end
        end

        -- Player HP inline
        if R.player_max_hp > 0 then
            local ratio = math.max(0, math.min(1, R.player_hp / R.player_max_hp))
            local hp_col
            if ratio > 0.6 then hp_col = to_imgui(0xFF44FF88)
            elseif ratio > 0.3 then hp_col = to_imgui(0xFF44DDFF)
            else hp_col = to_imgui(0xFFFF5555) end
            imgui.text_colored(("HP %d/%d"):format(math.ceil(R.player_hp), math.ceil(R.player_max_hp)), hp_col)
            imgui.same_line()
        end

        if active > 0 then
            imgui.text_colored(("%d active"):format(active), to_imgui(0xFF44FF88))
        else
            imgui.text_colored("idle", to_imgui(0xFF666666))
        end

        imgui.same_line()
        imgui.text_colored(("%dE"):format(#R.enemies),  to_imgui(0xFFFF6666))
        imgui.same_line()
        imgui.text_colored(("%dS"):format(#R.spawners), to_imgui(0xFFFFAA44))
        imgui.same_line()
        imgui.text_colored(("%dI"):format(#R.items),    to_imgui(0xFF55FF99))

        if R.loaded_scene ~= "" then
            imgui.same_line()
            imgui.text_colored("  " .. R.loaded_scene, to_imgui(0xFFFFDD88))
        elseif R.scene_name ~= "" then
            imgui.same_line()
            imgui.text_colored("  " .. R.scene_name, to_imgui(0xFF777777))
        end

        imgui.separator()

        -- ── Tab Buttons ──
        for i, tab in ipairs(TAB_DEFS) do
            if i > 1 then imgui.same_line() end
            local is_active = (R.ui_tab == i)
            if is_active then
                imgui.push_style_color(21, to_imgui(0xFF44FF88))
                imgui.push_style_color(22, to_imgui(0xFF44FF88))
                imgui.push_style_color(23, to_imgui(0xFF44FF88))
                imgui.push_style_color(0,  to_imgui(0xFF1A1A2E))
            else
                imgui.push_style_color(21, to_imgui(0xFF333344))
                imgui.push_style_color(22, to_imgui(0xFF444466))
                imgui.push_style_color(23, to_imgui(0xFF555577))
                imgui.push_style_color(0,  to_imgui(0xFFAAAAAA))
            end
            if imgui.button(tab.name .. "##tab" .. i) then R.ui_tab = i end
            imgui.pop_style_color(4)
        end

        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        -- ── Draw selected tab ──
        local sel = TAB_DEFS[R.ui_tab]
        if sel and sel.fn then pcall(sel.fn) end

        imgui.end_window()
    end

    -- ── Floating Inspector ──
    if R.sel_data ~= nil then
        if imgui.begin_window("Inspector###re7_insp", true, 0) then
            pcall(ui_object)
            imgui.end_window()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Draw API Overlays + B-key export
-- ═══════════════════════════════════════════════════════════════════════════
re.on_frame(function()
    if not draw then return end
    pcall(render_hud_strip)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 3D ESP + Damage Numbers (draw.world_to_screen — works without D2D)
-- ═══════════════════════════════════════════════════════════════════════════
re.on_frame(function()
    if not draw then return end

    -- ESP is rendered by the D2D callbacks (render_esp_enemies/items/spawners)

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

    -- Noclip every frame
    if C.noclip then pcall(do_noclip) end

    -- B key rising-edge export
    local b_down = reframework:is_key_down(0x42)
    if b_down and not _b_was_down then pcall(export_enemies_csv) end
    _b_was_down = b_down

    -- Screen size via d2d (get_window_size returns nil on RE7)
    if R.tick % 120 == 0 and d2d then
        pcall(function() R.sw, R.sh = d2d.surface_size() end)
    end

    -- Periodic scans
    local interval = C.scan_interval or 45
    if R.tick % interval == 0 then
        pcall(function() R.player_pos = get_player_pos() end)
        pcall(function() R.player_rot = get_camera_rot() end)
        pcall(function()
            local s = get_scene()
            R.scene_name = s and tostring(s:call("get_Name") or "") or ""
        end)
        R.player_hp, R.player_max_hp = get_player_hp()
        -- GameManager fields: Chapter, DA Score, Rank, Difficulty, PlayTime
        pcall(function()
            local gm = sdk.get_managed_singleton("app.GameManager")
            if not gm then return end
            local ch = gm:get_field("_CurrentChapter")
            R._chapter_no = ch or 0
            local chdisp = ""
            pcall(function() chdisp = tostring(gm:call("getChapterName", ch) or "") end)
            R.chapter = (chdisp ~= "" and chdisp ~= "nil") and chdisp or ("Ch?"..tostring(ch or ""))
            pcall(function() R.da_score = gm:get_field("RankPoint") or 0 end)
            pcall(function() R.rank = gm:call("getGameRank") or 0 end)
            pcall(function() R.difficulty = gm:get_field("GameDifficulty") or 0 end)
            pcall(function() R._chapter_time = gm:get_field("ChapterPlayTime") or 0 end)
            pcall(function() R.loading_progress = gm:get_field("<LoadingProgress>k__BackingField") or 100 end)
        end)
        -- GameFlowFsmManager: current flow name + battle/event state
        pcall(function()
            local gf = sdk.get_managed_singleton("app.GameFlowFsmManager")
            if not gf then return end
            local flow_id = gf:get_field("<CurrentMainGameFlow>k__BackingField") or 0
            R.flow_id = flow_id
            local names = gf:get_field("GameFlowName")
            if names then
                local ok, name = pcall(function() return tostring(names:call("get_Item", flow_id) or "") end)
                local new_name = (ok and name ~= "" and name ~= "nil") and name or ""
                if new_name ~= R.flow_name and R.flow_name ~= "" then
                    R.prev_flow_name = R.flow_name
                end
                R.flow_name = new_name
            end
            R.flow_battle_ended = gf:call("isBattleEnded") == true
            R.flow_event_ended  = gf:call("isEventEnded")  == true
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

    -- Slower scan: all scene objects (expensive)
    if R.tick % 150 == 0 then
        pcall(scan_all_objects)
    end

    -- Game speed
    if C.game_speed_on and R.tick % 10 == 0 then
        pcall(function() sdk.find_type_definition("via.Application"):get_method("set_GlobalSpeed"):call(nil, C.game_speed) end)
    end

    -- Cleanup damage numbers
    local now = os.clock()
    local live_dn = {}
    for _, dn in ipairs(R.damage_numbers) do if now - dn.time < dn.dur then live_dn[#live_dn+1] = dn end end
    R.damage_numbers = live_dn
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- Script Reset
-- ═══════════════════════════════════════════════════════════════════════════
re.on_script_reset(function()
    R.tick = 0
    R.enemies = {}; R.items = {}; R.spawners = {}; R.objects = {}
    R.player_hp = 0; R.player_max_hp = 0
    R.player_pos = nil; R.player_rot = nil
    R.scene_name = ""; R.loaded_scene = ""; R.chapter = ""
    R.area_name = ""; R.room_id = 0; R.map_cat = 0; R.map_level = 0
    R.da_score = 0; R.rank = 0; R.difficulty = 0
    R._chapter_no = 0; R._chapter_time = 0
    R.flow_name = ""; R.flow_id = 0; R.prev_flow_name = ""
    R.flow_battle_ended = false; R.flow_event_ended = false
    R.loading_progress = 100
    R.dev_overlay_bottom = 0; R.damage_numbers = {}
    R.sel_type = nil; R.sel_data = nil
    R.status_msg = ""; R.status_until = 0
    _b_was_down = false
    _eac_rt = nil
    reset_overlay_fonts()
    reset_esp_fonts()
end)

-- ═══════════════════════════════════════════════════════════════════════════
if log then log.info("[RE7] Trainer v3.0 loaded") end
toast("RE7 Trainer v3.0 loaded!", 5.0)
